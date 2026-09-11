-- Chat interno do Superadmin: Criar grupo (ADR 0034, P8: entra no MVP).
--
-- Um grupo e uma conversa contextual (conversation_type='group') de UMA
-- instituicao, com participantes do realm de pessoas (profissionais com
-- vinculo ativo na instituicao ou responsaveis com crianca ativa nela),
-- criada pelo realm interno do Superadmin. O criador interno nao vira
-- participante: o realm interno le e escreve pelo escopo da membership, como
-- nas demais RPCs v2. Escopo (instituicao/unidade/turma/atividade) segue o
-- trigger validate_chat_context_row de producao, revalidado aqui antes do
-- insert para devolver CHAT_INVALID_INPUT em vez de erro generico.
-- Exige 20260910240200 (chat.internal.manage e o envelope com CHAT_MEMBER_INVALID).
begin;

do $$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='internal chat migration must run as postgres';
  end if;
  if to_regprocedure('public.superadmin_chat_inbox_v2(timestamptz,uuid,integer,text,boolean)') is null
     or to_regprocedure('app_private.superadmin_chat_success(jsonb)') is null
     or to_regprocedure('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)') is null
     or to_regclass('public.conversation_participants') is null
     or to_regclass('public.institution_memberships') is null
     or to_regclass('public.guardian_links') is null
     or to_regclass('public.child_contexts') is null
     or to_regclass('public.activity_group_links') is null
     or not exists(select 1 from public.platform_permissions where code='chat.internal.manage') then
    raise exception using errcode='55000',
      message='internal chat manage baseline is unavailable';
  end if;
end
$$;

update public.platform_permissions
set description='Criar grupos e editar ou revogar mensagens proprias pelo realm interno do Superadmin.',
    updated_at=now()
where code='chat.internal.manage';

-- 1. Idempotencia da criacao (a tabela de recibos de mensagem exige message_id).
create table if not exists app_private.superadmin_internal_chat_group_receipts(
  request_id uuid not null,
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  request_hash bytea not null check(octet_length(request_hash)=32),
  conversation_id uuid not null references public.conversations(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key(internal_identity_id,request_id)
);
alter table app_private.superadmin_internal_chat_group_receipts enable row level security;
alter table app_private.superadmin_internal_chat_group_receipts force row level security;
revoke all on table app_private.superadmin_internal_chat_group_receipts
  from public,anon,authenticated,service_role;

-- 2. Criar grupo.
create or replace function public.superadmin_chat_create_group_v2(
  p_request_id uuid,
  p_institution_id uuid,
  p_title text,
  p_person_ids uuid[],
  p_unit_id uuid default null,
  p_group_id uuid default null,
  p_activity_id uuid default null
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid:=gen_random_uuid();
  normalized_title text:=nullif(btrim(p_title),'');
  members uuid[]:=(select coalesce(array_agg(distinct member_id),array[]::uuid[])
    from unnest(coalesce(p_person_ids,array[]::uuid[])) member_id where member_id is not null);
  scope text;
  institution uuid;
  request_hash bytea;
  prior record;
  created public.conversations%rowtype;
  member_count integer;
  code text;
begin begin
  select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.manage');
  if p_request_id is null or p_institution_id is null or normalized_title is null
     or length(normalized_title)>120 or cardinality(members) not between 1 and 200
     or (p_activity_id is not null and (p_group_id is null or p_unit_id is null))
     or (p_group_id is not null and p_unit_id is null) then
    raise invalid_parameter_value using detail='CHAT_INVALID_INPUT';
  end if;
  -- Escopo de instituicao do ator: outro tenant nao enumera.
  select institution_row.id into institution from public.institutions institution_row
   where institution_row.id=p_institution_id and institution_row.deleted_at is null
     and (ctx.scope_kind<>'institution' or institution_row.id=ctx.scope_institution_id);
  if institution is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
  scope:=case when p_activity_id is not null then 'activity'
              when p_group_id is not null then 'group'
              when p_unit_id is not null then 'unit' else 'institution' end;
  if p_unit_id is not null and not exists(select 1 from public.units unit_row
       where unit_row.id=p_unit_id and unit_row.institution_id=institution) then
    raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
  if p_group_id is not null and not exists(select 1 from public.groups group_row
       where group_row.id=p_group_id and group_row.unit_id=p_unit_id
         and group_row.institution_id=institution) then
    raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
  if p_activity_id is not null and not exists(select 1 from public.activity_group_links link
       where link.activity_id=p_activity_id and link.group_id=p_group_id
         and link.unit_id=p_unit_id and link.institution_id=institution) then
    raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;

  request_hash:=extensions.digest(convert_to(jsonb_build_object('op','create_group',
    'institution_id',institution,'title',normalized_title,'scope',scope,
    'unit_id',p_unit_id,'group_id',p_group_id,'activity_id',p_activity_id,
    'members',(select jsonb_agg(member_id order by member_id) from unnest(members) member_id))::text,'UTF8'),'sha256');
  perform pg_advisory_xact_lock(hashtextextended(ctx.internal_identity_id::text||p_request_id::text,0));
  select * into prior from app_private.superadmin_internal_chat_group_receipts receipt
   where receipt.internal_identity_id=ctx.internal_identity_id and receipt.request_id=p_request_id for update;
  if prior.request_id is not null then
    if prior.request_hash<>request_hash then raise unique_violation using detail='CHAT_REPLAY_MISMATCH'; end if;
    select * into created from public.conversations where id=prior.conversation_id;
  else
    -- Cada membro precisa de vinculo real com a instituicao: profissional
    -- (institution_memberships ativo) ou responsavel (guardian_links ativo de
    -- crianca com child_contexts ativo na instituicao). Nada de pessoa solta.
    if exists(select 1 from unnest(members) member_id
      where not exists(select 1 from public.people person
         where person.id=member_id and person.status='active' and person.deleted_at is null)
        or not (
          exists(select 1 from public.institution_memberships membership
            where membership.person_id=member_id and membership.institution_id=institution
              and membership.status='active' and membership.revoked_at is null)
          or exists(select 1 from public.guardian_links guardian
            join public.child_contexts child_context
              on child_context.child_person_id=guardian.child_person_id
             and child_context.institution_id=institution
             and child_context.status='active' and child_context.archived_at is null
            where guardian.guardian_person_id=member_id
              and guardian.status='active' and guardian.revoked_at is null))) then
      raise check_violation using detail='CHAT_MEMBER_INVALID';
    end if;
    begin
      insert into public.conversations(institution_id,scope_kind,scope_id,conversation_type,title,
        created_by,unit_id,group_id,activity_id)
      values(institution,scope,
        case scope when 'unit' then p_unit_id when 'group' then p_group_id
          when 'activity' then p_activity_id else null end,
        'group',normalized_title,null,p_unit_id,p_group_id,p_activity_id)
      returning * into created;
    exception when raise_exception then
      raise invalid_parameter_value using detail='CHAT_INVALID_INPUT';
    end;
    insert into public.conversation_participants(conversation_id,person_id,membership_id,
      experience_kind,role_snapshot)
    select created.id,member_id,membership.id,
      case when membership.id is null then 'family' else 'professional' end,
      coalesce(nullif(membership.role_code,''),'responsavel')
    from unnest(members) member_id
    left join lateral(select membership_row.id,membership_row.role_code
      from public.institution_memberships membership_row
      where membership_row.person_id=member_id and membership_row.institution_id=institution
        and membership_row.status='active' and membership_row.revoked_at is null
      order by membership_row.created_at desc limit 1) membership on true;
    insert into app_private.superadmin_internal_chat_group_receipts(
      request_id,internal_identity_id,request_hash,conversation_id)
    values(p_request_id,ctx.internal_identity_id,request_hash,created.id);
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
      ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
      'chat.internal.manage',ctx.aal,'chat.group.create','success',null,correlation,
      institution,'conversation',created.id);
  end if;
  select count(*) into member_count from public.conversation_participants participant
   where participant.conversation_id=created.id and participant.status='active' and participant.left_at is null;
  return app_private.superadmin_chat_success(jsonb_build_object(
    'conversation_id',created.id,'title',coalesce(created.title,''),
    'conversation_type',created.conversation_type,'scope_kind',created.scope_kind,
    'institution_id',created.institution_id,'unit_id',created.unit_id,
    'group_id',created.group_id,'activity_id',created.activity_id,
    'member_count',member_count,'created_at',created.created_at,
    'replayed',prior.request_id is not null));
exception when others then get stacked diagnostics code=pg_exception_detail;
  code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
  perform app_private.audit_superadmin_internal_denial_if_identified(
    'chat.internal.manage','chat.group.create',code,correlation,institution);
  return app_private.superadmin_chat_error(code,correlation);
end $$;

-- 3. Participantes de uma conversa (para a tela do grupo e o reload).
create or replace function public.superadmin_chat_group_members_v2(p_conversation_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
  institution uuid; result jsonb; code text;
begin begin
  select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.read');
  if p_conversation_id is null then raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
  select institution_id into institution from public.conversations where id=p_conversation_id
    and (ctx.scope_kind<>'institution' or institution_id=ctx.scope_institution_id);
  if institution is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
  select jsonb_build_object('conversation_id',p_conversation_id,
    'items',coalesce((select jsonb_agg(jsonb_build_object(
      'person_id',participant.person_id,'display_name',person.display_name,
      'experience_kind',participant.experience_kind,'role_snapshot',participant.role_snapshot,
      'joined_at',participant.joined_at) order by person.display_name,participant.person_id)
      from public.conversation_participants participant
      join public.people person on person.id=participant.person_id
      where participant.conversation_id=p_conversation_id
        and participant.status='active' and participant.left_at is null),'[]'::jsonb),
    'total',(select count(*) from public.conversation_participants participant
      where participant.conversation_id=p_conversation_id
        and participant.status='active' and participant.left_at is null)) into result;
  return app_private.superadmin_chat_success(result);
exception when others then get stacked diagnostics code=pg_exception_detail;
  code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
  perform app_private.audit_superadmin_internal_denial_if_identified(
    'chat.internal.read','chat.group.members',code,correlation,institution);
  return app_private.superadmin_chat_error(code,correlation);
end $$;

do $$declare p regprocedure; begin foreach p in array array[
 'public.superadmin_chat_create_group_v2(uuid,uuid,text,uuid[],uuid,uuid,uuid)'::regprocedure,
 'public.superadmin_chat_group_members_v2(uuid)'::regprocedure
] loop execute format('alter function %s owner to postgres',p);
 execute format('revoke all on function %s from public,anon,authenticated,service_role',p); end loop; end $$;

grant execute on function public.superadmin_chat_create_group_v2(uuid,uuid,text,uuid[],uuid,uuid,uuid) to authenticated;
grant execute on function public.superadmin_chat_group_members_v2(uuid) to authenticated;

commit;
