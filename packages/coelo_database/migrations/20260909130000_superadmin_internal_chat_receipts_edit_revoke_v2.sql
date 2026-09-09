-- E2 R02 L02 - Chat interno do Superadmin: projecao de recibos, edicao e revogacao.
--
-- `superadmin_chat_mark_read_v2` ja persistia recibos em
-- app_private.superadmin_internal_chat_receipts, mas `superadmin_chat_thread_v2`
-- nao devolvia nenhum estado de recibo, entao a UI nao tinha o que renderizar.
-- Esta migration projeta o recibo de cada mensagem e acrescenta as duas acoes
-- que faltavam no realm interno: editar e revogar a propria mensagem.
--
-- Forward-only. Nenhum grant novo a tabela; toda leitura/escrita continua
-- passando pelas RPCs security definer que recomputam o escopo autorizado.

begin;

do $$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='internal chat migration must run as postgres';
  end if;
  if to_regprocedure('public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer)') is null
     or to_regprocedure('app_private.superadmin_chat_success(jsonb)') is null
     or to_regclass('app_private.superadmin_internal_chat_receipts') is null
     or to_regclass('app_private.superadmin_internal_chat_command_receipts') is null
     or to_regclass('public.message_receipts') is null
     or to_regclass('public.conversation_participants') is null then
    raise exception using errcode='55000',
      message='internal chat v2 baseline is unavailable';
  end if;
end
$$;

-- 1. Permissao dedicada as acoes de gestao da propria mensagem.
insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status,updated_at
) values
 ('chat.internal.manage','communication','chat','manage',
  'Editar e revogar mensagens proprias enviadas pelo realm interno do Superadmin.',
  'critical',true,'active',now())
on conflict(code) do update set module_code=excluded.module_code,screen_code=excluded.screen_code,
 action_code=excluded.action_code,description=excluded.description,risk_level=excluded.risk_level,
 requires_mfa=excluded.requires_mfa,status='active',updated_at=now();

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='owner' and permission_record.code='chat.internal.manage'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

-- 2. Trilha de edicao do realm interno. `public.message_edits` referencia
-- public.people e por isso nao serve a um autor interno, que nao tem pessoa.
create table if not exists app_private.superadmin_internal_chat_message_edits(
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  old_body_text text,
  new_body_text text,
  edited_at timestamptz not null default now()
);
create index if not exists superadmin_internal_chat_message_edits_message_idx
  on app_private.superadmin_internal_chat_message_edits(message_id,edited_at desc);

alter table app_private.superadmin_internal_chat_message_edits enable row level security;
alter table app_private.superadmin_internal_chat_message_edits force row level security;
revoke all on table app_private.superadmin_internal_chat_message_edits
  from public,anon,authenticated,service_role;

-- 3. Codigos de erro das novas acoes.
create or replace function app_private.superadmin_chat_error(p_code text,p_correlation_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select pg_catalog.jsonb_build_object('ok',false,'data',null,'error',
    pg_catalog.jsonb_build_object(
      'code',case when p_code in(
        'CHAT_INVALID_INPUT','CHAT_NOT_FOUND','CHAT_READ_ONLY','CHAT_REPLAY_MISMATCH',
        'CHAT_NOT_AUTHOR','CHAT_EDIT_WINDOW_CLOSED','CHAT_ALREADY_REVOKED',
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
        'SAI_MFA_REQUIRED') then p_code else 'SAI_INTERNAL_ERROR' end,
      'message',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 'Autenticação necessária.'
        when p_code='SAI_MFA_REQUIRED' then 'Confirme o segundo fator.'
        when p_code='CHAT_INVALID_INPUT' then 'Revise os dados enviados.'
        when p_code='CHAT_NOT_FOUND' then 'Conversa não encontrada.'
        when p_code='CHAT_READ_ONLY' then 'Esta conversa é somente leitura.'
        when p_code='CHAT_REPLAY_MISMATCH' then 'A solicitação já foi usada com outros dados.'
        when p_code='CHAT_NOT_AUTHOR' then 'Só o autor pode alterar esta mensagem.'
        when p_code='CHAT_EDIT_WINDOW_CLOSED' then 'O prazo de edição desta mensagem terminou.'
        when p_code='CHAT_ALREADY_REVOKED' then 'Esta mensagem já foi revogada.'
        when p_code like 'SAI_%DENIED' or p_code like 'SAI_MEMBERSHIP_%' then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code in('CHAT_INVALID_INPUT') then 422
        when p_code='CHAT_NOT_FOUND' then 404
        when p_code in('CHAT_READ_ONLY','CHAT_REPLAY_MISMATCH','CHAT_EDIT_WINDOW_CLOSED',
          'CHAT_ALREADY_REVOKED') then 409
        when p_code in('CHAT_NOT_AUTHOR','SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
        else 500 end,
      'correlation_id',p_correlation_id))
$$;

-- 4. Recibo por mensagem, calculado no servidor.
-- Mensagem recebida: o recibo e o do proprio leitor interno.
-- Mensagem enviada: contagem de destinatarios ativos do realm contextual.
create or replace function app_private.superadmin_chat_message_receipt(
  p_message_id uuid,p_conversation_id uuid,p_is_mine boolean,p_internal_identity_id uuid
) returns jsonb language sql stable security definer set search_path='' as $$
  select pg_catalog.jsonb_build_object(
    'is_mine',p_is_mine,
    'delivered_at',case when p_is_mine then null else own.delivered_at end,
    'read_at',case when p_is_mine then null else own.read_at end,
    'recipient_count',case when p_is_mine then outbound.recipient_count else 0 end,
    'delivered_count',case when p_is_mine then outbound.delivered_count else 0 end,
    'read_count',case when p_is_mine then outbound.read_count else 0 end)
  from (
    select
      (select count(*) from public.conversation_participants participant
        where participant.conversation_id=p_conversation_id
          and participant.status='active' and participant.left_at is null) recipient_count,
      (select count(*) from public.message_receipts receipt
        join public.conversation_participants participant
          on participant.person_id=receipt.person_id
         and participant.conversation_id=p_conversation_id
         and participant.status='active' and participant.left_at is null
        where receipt.message_id=p_message_id and receipt.delivered_at is not null) delivered_count,
      (select count(*) from public.message_receipts receipt
        join public.conversation_participants participant
          on participant.person_id=receipt.person_id
         and participant.conversation_id=p_conversation_id
         and participant.status='active' and participant.left_at is null
        where receipt.message_id=p_message_id and receipt.read_at is not null) read_count
  ) outbound
  left join (select receipt.delivered_at,receipt.read_at
        from app_private.superadmin_internal_chat_receipts receipt
        where receipt.message_id=p_message_id
          and receipt.internal_identity_id=p_internal_identity_id) own on true
$$;

-- 5. Thread com recibo e marca de edicao projetados.
create or replace function public.superadmin_chat_thread_v2(
 p_conversation_id uuid,p_cursor_created_at timestamptz default null,
 p_cursor_message_id uuid default null,p_limit integer default 50
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 result jsonb; code text; institution uuid;
begin begin
 select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.read');
 if p_conversation_id is null or p_limit is null or p_limit not between 1 and 100
   or (p_cursor_created_at is null)<>(p_cursor_message_id is null) then
  raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
 select institution_id into institution from public.conversations where id=p_conversation_id
  and (ctx.scope_kind<>'institution' or institution_id=ctx.scope_institution_id);
 if institution is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
 with filtered as(select message_row.* from public.messages message_row
   where message_row.conversation_id=p_conversation_id and message_row.status='active'
    and message_row.deleted_at is null and (p_cursor_created_at is null
      or (message_row.created_at,message_row.id)<(p_cursor_created_at,p_cursor_message_id))),
 page as(select * from filtered order by created_at desc,id desc limit p_limit+1)
 select jsonb_build_object(
  'items',coalesce((select jsonb_agg(jsonb_build_object(
    'message_id',item.id,'body_text',coalesce(item.body_text,''),'message_type',item.message_type,
    'created_at',item.created_at,'updated_at',item.updated_at,
    'author_name',case when item.author_kind='superadmin_internal' then 'Equipe Coelo'
      else coalesce((select person.display_name from public.people person where person.id=item.author_person_id),'') end,
    'is_mine',item.author_internal_identity_id=ctx.internal_identity_id,
    'edited_at',(select max(edit.edited_at) from app_private.superadmin_internal_chat_message_edits edit
      where edit.message_id=item.id),
    'can_manage',coalesce(item.author_internal_identity_id=ctx.internal_identity_id,false),
    'receipt',app_private.superadmin_chat_message_receipt(item.id,p_conversation_id,
      coalesce(item.author_internal_identity_id=ctx.internal_identity_id,false),ctx.internal_identity_id),
    'attachments',coalesce((select jsonb_agg(jsonb_build_object('id',attachment.id,
      'file_name',attachment.file_name,'content_type',attachment.content_type,
      'byte_size',attachment.byte_size,'sha256',attachment.sha256,
      'upload_status',attachment.upload_status) order by attachment.created_at)
      from public.chat_attachment_metadata attachment where attachment.message_id=item.id),'[]'::jsonb))
    order by item.created_at desc,item.id desc) from(select * from page limit p_limit)item),'[]'::jsonb),
  'total',(select count(*) from public.messages message_row where message_row.conversation_id=p_conversation_id
    and message_row.status='active' and message_row.deleted_at is null),
  'has_more',(select count(*)>p_limit from page),
  'next_cursor',case when (select count(*) from page)>p_limit then
    (select jsonb_build_object('timestamp',item.created_at,'id',item.id)
     from(select * from page limit p_limit)item order by item.created_at,item.id limit 1) else null end
 ) into result;
 return app_private.superadmin_chat_success(result);
exception when others then get stacked diagnostics code=pg_exception_detail;
 code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 perform app_private.audit_superadmin_internal_denial_if_identified(
  'chat.internal.read','chat.thread',code,correlation,institution);
 return app_private.superadmin_chat_error(code,correlation); end $$;

-- 6. Editar a propria mensagem interna, dentro da janela permitida.
create or replace function public.superadmin_chat_edit_message_v2(
 p_conversation_id uuid,p_message_id uuid,p_body_text text,p_request_id uuid
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 normalized_body text:=nullif(btrim(p_body_text),''); institution uuid; read_only boolean;
 request_hash bytea; prior record; target public.messages%rowtype; previous_body text; code text;
begin begin
 select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.manage');
 if p_conversation_id is null or p_message_id is null or p_request_id is null
   or normalized_body is null or length(normalized_body)>4000 then
  raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
 select institution_id,is_read_only into institution,read_only from public.conversations
  where id=p_conversation_id and status='active'
   and (ctx.scope_kind<>'institution' or institution_id=ctx.scope_institution_id) for share;
 if institution is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
 if read_only then raise object_not_in_prerequisite_state using detail='CHAT_READ_ONLY'; end if;
 perform pg_advisory_xact_lock(hashtextextended(ctx.internal_identity_id::text||p_request_id::text,0));
 request_hash:=extensions.digest(convert_to(jsonb_build_object('op','edit',
   'message_id',p_message_id,'body_text',normalized_body)::text,'UTF8'),'sha256');
 select * into prior from app_private.superadmin_internal_chat_command_receipts receipt
  where receipt.internal_identity_id=ctx.internal_identity_id and receipt.request_id=p_request_id for update;
 if prior.request_id is not null then
  if prior.request_hash<>request_hash then raise unique_violation using detail='CHAT_REPLAY_MISMATCH'; end if;
  select * into target from public.messages where id=prior.message_id;
 else
  select * into target from public.messages
   where id=p_message_id and conversation_id=p_conversation_id for update;
  if target.id is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
  if target.author_kind<>'superadmin_internal'
    or target.author_internal_identity_id is distinct from ctx.internal_identity_id then
   raise insufficient_privilege using detail='CHAT_NOT_AUTHOR'; end if;
  if target.status<>'active' or target.deleted_at is not null then
   raise object_not_in_prerequisite_state using detail='CHAT_ALREADY_REVOKED'; end if;
  if target.created_at < now()-interval '15 minutes' then
   raise object_not_in_prerequisite_state using detail='CHAT_EDIT_WINDOW_CLOSED'; end if;
  previous_body:=target.body_text;
  update public.messages set body_text=normalized_body,updated_at=now()
   where id=target.id returning * into target;
  insert into app_private.superadmin_internal_chat_message_edits(
    message_id,internal_identity_id,old_body_text,new_body_text)
  values(target.id,ctx.internal_identity_id,previous_body,normalized_body);
  insert into app_private.superadmin_internal_chat_command_receipts(
    request_id,internal_identity_id,conversation_id,request_hash,message_id)
  values(p_request_id,ctx.internal_identity_id,p_conversation_id,request_hash,target.id);
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
    ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'chat.internal.manage',ctx.aal,'chat.message.edit','success',null,correlation,
    institution,'message',target.id,jsonb_build_object('conversation_id',p_conversation_id));
 end if;
 return app_private.superadmin_chat_success(jsonb_build_object(
  'message_id',target.id,'body_text',coalesce(target.body_text,''),
  'message_type',target.message_type,'created_at',target.created_at,
  'updated_at',target.updated_at,'author_name','Equipe Coelo','is_mine',true,'can_manage',true,
  'edited_at',(select max(edit.edited_at) from app_private.superadmin_internal_chat_message_edits edit
    where edit.message_id=target.id),
  'receipt',app_private.superadmin_chat_message_receipt(target.id,p_conversation_id,true,
    ctx.internal_identity_id),
  'attachments','[]'::jsonb,'replayed',prior.request_id is not null));
exception when others then get stacked diagnostics code=pg_exception_detail;
 code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 perform app_private.audit_superadmin_internal_denial_if_identified(
  'chat.internal.manage','chat.message.edit',code,correlation,institution);
 return app_private.superadmin_chat_error(code,correlation); end $$;

-- 7. Revogar a propria mensagem interna. Revogacao e soft delete auditado:
-- a mensagem sai da thread e do nao lido, e o conteudo original fica retido
-- apenas na trilha privada para auditoria.
create or replace function public.superadmin_chat_revoke_message_v2(
 p_conversation_id uuid,p_message_id uuid,p_request_id uuid
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 institution uuid; request_hash bytea; prior record; target public.messages%rowtype; code text;
begin begin
 select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.manage');
 if p_conversation_id is null or p_message_id is null or p_request_id is null then
  raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
 select institution_id into institution from public.conversations where id=p_conversation_id
   and (ctx.scope_kind<>'institution' or institution_id=ctx.scope_institution_id);
 if institution is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
 perform pg_advisory_xact_lock(hashtextextended(ctx.internal_identity_id::text||p_request_id::text,0));
 request_hash:=extensions.digest(convert_to(jsonb_build_object('op','revoke',
   'message_id',p_message_id)::text,'UTF8'),'sha256');
 select * into prior from app_private.superadmin_internal_chat_command_receipts receipt
  where receipt.internal_identity_id=ctx.internal_identity_id and receipt.request_id=p_request_id for update;
 if prior.request_id is not null then
  if prior.request_hash<>request_hash then raise unique_violation using detail='CHAT_REPLAY_MISMATCH'; end if;
  select * into target from public.messages where id=prior.message_id;
 else
  select * into target from public.messages
   where id=p_message_id and conversation_id=p_conversation_id for update;
  if target.id is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
  if target.author_kind<>'superadmin_internal'
    or target.author_internal_identity_id is distinct from ctx.internal_identity_id then
   raise insufficient_privilege using detail='CHAT_NOT_AUTHOR'; end if;
  if target.status<>'active' or target.deleted_at is not null then
   raise object_not_in_prerequisite_state using detail='CHAT_ALREADY_REVOKED'; end if;
  update public.messages set status='archived',deleted_at=now(),updated_at=now()
   where id=target.id returning * into target;
  insert into app_private.superadmin_internal_chat_command_receipts(
    request_id,internal_identity_id,conversation_id,request_hash,message_id)
  values(p_request_id,ctx.internal_identity_id,p_conversation_id,request_hash,target.id);
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
    ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'chat.internal.manage',ctx.aal,'chat.message.revoke','success',null,correlation,
    institution,'message',target.id,jsonb_build_object('conversation_id',p_conversation_id));
 end if;
 return app_private.superadmin_chat_success(jsonb_build_object(
  'message_id',target.id,'revoked_at',target.deleted_at,
  'replayed',prior.request_id is not null));
exception when others then get stacked diagnostics code=pg_exception_detail;
 code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 perform app_private.audit_superadmin_internal_denial_if_identified(
  'chat.internal.manage','chat.message.revoke',code,correlation,institution);
 return app_private.superadmin_chat_error(code,correlation); end $$;

do $$declare p regprocedure; begin foreach p in array array[
 'app_private.superadmin_chat_error(text,uuid)'::regprocedure,
 'app_private.superadmin_chat_message_receipt(uuid,uuid,boolean,uuid)'::regprocedure,
 'public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer)'::regprocedure,
 'public.superadmin_chat_edit_message_v2(uuid,uuid,text,uuid)'::regprocedure,
 'public.superadmin_chat_revoke_message_v2(uuid,uuid,uuid)'::regprocedure
] loop execute format('alter function %s owner to postgres',p);
 execute format('revoke all on function %s from public,anon,authenticated,service_role',p); end loop; end $$;

grant execute on function public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer) to authenticated;
grant execute on function public.superadmin_chat_edit_message_v2(uuid,uuid,text,uuid) to authenticated;
grant execute on function public.superadmin_chat_revoke_message_v2(uuid,uuid,uuid) to authenticated;

commit;
