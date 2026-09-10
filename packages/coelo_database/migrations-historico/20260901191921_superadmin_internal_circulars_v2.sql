-- Forward-only ADR-0019/spec-039 gateway for internal Superadmin Circulars.
-- The people-realm RPCs remain independent for Principal; this surface never
-- manufactures a public.people row for an internal employee.
begin;

do $preflight$
begin
  if current_user <> 'postgres'
    or to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regclass('public.circulars') is null
    or to_regclass('public.circular_revisions') is null then
    raise object_not_in_prerequisite_state using
      message = 'superadmin internal circulars prerequisites missing';
  end if;
end
$preflight$;

alter table public.circulars
  alter column author_person_id drop not null,
  alter column author_membership_id drop not null,
  add column if not exists author_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id),
  add column if not exists author_internal_membership_id uuid
    references app_private.superadmin_internal_memberships(id),
  add column if not exists responses_closed_by_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id);

alter table public.circulars
  drop constraint if exists circulars_actor_realm_ck,
  add constraint circulars_actor_realm_ck check (
    (author_person_id is not null and author_membership_id is not null
      and author_internal_identity_id is null and author_internal_membership_id is null)
    or
    (author_person_id is null and author_membership_id is null
      and author_internal_identity_id is not null and author_internal_membership_id is not null)
  ) not valid;
alter table public.circulars validate constraint circulars_actor_realm_ck;

alter table public.circular_revisions
  alter column created_by_person_id drop not null,
  add column if not exists created_by_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id);
alter table public.circular_revisions
  drop constraint if exists circular_revisions_actor_realm_ck,
  add constraint circular_revisions_actor_realm_ck check (
    (created_by_person_id is not null) <> (created_by_internal_identity_id is not null)
  ) not valid;
alter table public.circular_revisions validate constraint circular_revisions_actor_realm_ck;

alter table app_private.circular_audit
  alter column actor_person_id drop not null,
  add column if not exists actor_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id);
alter table app_private.circular_audit
  drop constraint if exists circular_audit_actor_realm_ck,
  add constraint circular_audit_actor_realm_ck check (
    (actor_person_id is not null) <> (actor_internal_identity_id is not null)
  ) not valid;
alter table app_private.circular_audit validate constraint circular_audit_actor_realm_ck;

create index if not exists circulars_internal_author_idx
  on public.circulars(author_internal_identity_id, updated_at desc)
  where author_internal_identity_id is not null and deleted_at is null;
create index if not exists circulars_internal_membership_fk_idx
  on public.circulars(author_internal_membership_id)
  where author_internal_membership_id is not null;
create index if not exists circulars_closed_internal_fk_idx
  on public.circulars(responses_closed_by_internal_identity_id)
  where responses_closed_by_internal_identity_id is not null;
create index if not exists circular_revisions_internal_author_fk_idx
  on public.circular_revisions(created_by_internal_identity_id)
  where created_by_internal_identity_id is not null;
create index if not exists circulars_internal_directory_idx
  on public.circulars(institution_id, updated_at desc, id desc)
  where deleted_at is null;

create table if not exists app_private.superadmin_circular_command_receipts(
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id),
  request_id uuid not null,
  action_code text not null check (action_code in ('save','publish','close')),
  request_hash bytea not null check (octet_length(request_hash) = 32),
  result_json jsonb not null,
  created_at timestamptz not null default now(),
  primary key(internal_identity_id, request_id, action_code)
);
alter table app_private.superadmin_circular_command_receipts enable row level security;
alter table app_private.superadmin_circular_command_receipts force row level security;

do $tables$
declare table_name text;
begin
  foreach table_name in array array[
    'circulars','circular_revisions','circular_blocks','circular_questions',
    'circular_question_options','circular_audience_rules','circular_media_assets',
    'circular_media_links','circular_response_sessions','circular_response_revisions',
    'circular_answers','circular_answer_options'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
    execute format('revoke all on table public.%I from public, anon, authenticated, service_role', table_name);
  end loop;
end
$tables$;
revoke all on table app_private.circular_audit,
  app_private.superadmin_circular_command_receipts
from public, anon, authenticated, service_role;

insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status
) values
 ('circulars.read','communication','circulars','read',
  'Ler Circulares administrativas no escopo autorizado.','normal',false,'active'),
 ('circulars.manage','communication','circulars','manage',
  'Criar, alterar e encerrar Circulares administrativas.','high',true,'active'),
 ('circulars.publish','communication','circulars','publish',
  'Publicar ou agendar Circulares administrativas.','critical',true,'active')
on conflict(code) do update set
  module_code=excluded.module_code,screen_code=excluded.screen_code,
  action_code=excluded.action_code,description=excluded.description,
  risk_level=excluded.risk_level,requires_mfa=excluded.requires_mfa,status='active';

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id, permission_record.id, 'allow'::public.permission_effect, 'active'
from public.platform_roles role_record
join public.platform_permissions permission_record on permission_record.code='circulars.read'
where role_record.code in ('owner','content','operations')
on conflict(role_id,permission_id) do update set
  effect='allow',status='active',revoked_at=null;

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id, permission_record.id, 'allow'::public.permission_effect, 'active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on permission_record.code in ('circulars.manage','circulars.publish')
where role_record.code='owner'
on conflict(role_id,permission_id) do update set
  effect='allow',status='active',revoked_at=null;

create or replace function app_private.superadmin_circular_context(
  p_permission_code text,p_institution_id uuid default null
) returns app_private.superadmin_internal_context
language plpgsql stable security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; resolved uuid:=p_institution_id;
begin
  select * into strict ctx
  from app_private.require_superadmin_internal_context(p_permission_code);
  if ctx.scope_kind='institution' then
    if resolved is null then resolved:=ctx.scope_institution_id; end if;
    if resolved is distinct from ctx.scope_institution_id then
      raise insufficient_privilege using message='circular scope denied',detail='SAI_PERMISSION_DENIED';
    end if;
  end if;
  if resolved is not null and not exists(
    select 1 from public.institutions institution_record where institution_record.id=resolved
  ) then
    raise insufficient_privilege using message='circular scope denied',detail='SAI_PERMISSION_DENIED';
  end if;
  ctx.resolved_institution_id:=resolved;
  return ctx;
end
$$;

create or replace function app_private.superadmin_circular_error(
  p_code text,p_correlation_id uuid
) returns jsonb language sql immutable security definer set search_path='' as $$
  select case when p_code like 'SAI_%' then
    app_private.superadmin_internal_error_envelope(p_code,p_correlation_id)
  else jsonb_build_object('ok',false,'data',null,'error',jsonb_build_object(
    'code',case when p_code in ('CIRCULAR_INVALID_INPUT','CIRCULAR_NOT_FOUND',
      'CIRCULAR_CONFLICT','CIRCULAR_INVALID_STATE','CIRCULAR_MEDIA_BLOCKED')
      then p_code else 'CIRCULAR_INTERNAL_ERROR' end,
    'message',case
      when p_code='CIRCULAR_NOT_FOUND' then 'Circular não encontrada.'
      when p_code='CIRCULAR_CONFLICT' then 'A Circular foi alterada. Recarregue e tente novamente.'
      when p_code='CIRCULAR_MEDIA_BLOCKED' then 'A mídia ainda não está disponível.'
      when p_code in ('CIRCULAR_INVALID_INPUT','CIRCULAR_INVALID_STATE') then 'Revise os dados da Circular.'
      else 'Não foi possível concluir a operação.' end,
    'correlation_id',p_correlation_id,
    'http_status',case when p_code='CIRCULAR_NOT_FOUND' then 404
      when p_code='CIRCULAR_CONFLICT' then 409
      when p_code like 'CIRCULAR_%' then 422 else 500 end)) end
$$;

create or replace function app_private.superadmin_circular_audit(
  p_ctx app_private.superadmin_internal_context,p_action text,p_resource uuid,
  p_outcome text,p_reason text,p_correlation uuid
) returns void language plpgsql volatile security definer set search_path='' as $$
begin
  perform app_private.audit_append_superadmin_internal(
    p_ctx.internal_identity_id,p_ctx.internal_auth_link_id,p_ctx.internal_membership_id,
    p_ctx.session_id,p_ctx.permission_code,p_ctx.aal,p_action,
    p_outcome::public.audit_outcome,left(p_reason,120),p_correlation,
    p_ctx.resolved_institution_id,'circular',p_resource);
end
$$;

create or replace function app_private.superadmin_circular_denied(
  p_permission text,p_action text,p_code text,p_correlation uuid
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare code text:=case when p_code in (
 'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
 'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED',
 'CIRCULAR_INVALID_INPUT','CIRCULAR_NOT_FOUND','CIRCULAR_CONFLICT',
 'CIRCULAR_INVALID_STATE','CIRCULAR_MEDIA_BLOCKED') then p_code else 'SAI_INTERNAL_ERROR' end;
begin
  perform app_private.audit_superadmin_internal_denial_if_identified(
    p_permission,p_action,code,p_correlation);
  return app_private.superadmin_circular_error(code,p_correlation);
end
$$;

create or replace function app_private.superadmin_circular_validate_scope(
  p_institution uuid,p_unit uuid,p_group uuid,p_activity uuid
) returns void language plpgsql stable security definer set search_path='' as $$
begin
  if p_institution is null
    or (p_unit is not null and not exists(select 1 from public.units u
      where u.id=p_unit and u.institution_id=p_institution))
    or (p_group is not null and not exists(select 1 from public.groups g
      where g.id=p_group and g.institution_id=p_institution and g.unit_id=p_unit))
    or (p_activity is not null and not exists(select 1 from public.activity_definitions a
      where a.id=p_activity and a.institution_id=p_institution)) then
    raise invalid_parameter_value using message='invalid circular scope',detail='CIRCULAR_INVALID_INPUT';
  end if;
end
$$;

create or replace function app_private.superadmin_circular_draft_json(
  p_target public.circulars,p_revision public.circular_revisions
) returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object(
 'id',p_target.id,'version',p_target.management_version,'revision_id',p_revision.id,
 'title',p_revision.title,'status',p_target.status::text,
 'response_policy',p_target.response_policy::text,
 'responses_close_at',p_target.responses_close_at,
 'blocks',(select coalesce(jsonb_agg(case block_record.block_kind
   when 'text' then jsonb_build_object('id',block_record.id,'kind','text','text',block_record.text_content)
   when 'media' then jsonb_build_object('id',block_record.id,'kind','media','asset_ids','[]'::jsonb)
   else jsonb_build_object('id',block_record.id,'kind','question','question',(
     select jsonb_build_object('id',question_record.id,'prompt',question_record.prompt,
       'kind',question_record.question_kind::text,'required',question_record.required,
       'options',(select coalesce(jsonb_agg(jsonb_build_object('id',option_record.id,
         'label',option_record.label) order by option_record.display_order),'[]'::jsonb)
        from public.circular_question_options option_record
        where option_record.question_id=question_record.id))
     from public.circular_questions question_record where question_record.block_id=block_record.id))
   end order by block_record.display_order),'[]'::jsonb)
   from public.circular_blocks block_record where block_record.revision_id=p_revision.id),
 'audiences',(select coalesce(jsonb_agg(distinct audience_record.audience_kind::text),'[]'::jsonb)
   from public.circular_audience_rules audience_record where audience_record.circular_id=p_target.id))
$$;

create or replace function public.superadmin_circular_directory_v2(
 p_institution_id uuid default null,p_search text default null,p_statuses text[] default null,
 p_cursor_updated_at timestamptz default null,p_cursor_id uuid default null,p_limit integer default 25
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 items jsonb; next_record record; code text;
begin
 begin
  ctx:=app_private.superadmin_circular_context('circulars.read',p_institution_id);
  if p_limit not between 1 and 100 or char_length(coalesce(p_search,''))>120
   or ((p_cursor_updated_at is null)<>(p_cursor_id is null))
   or (p_statuses is not null and not (p_statuses <@ array['draft','scheduled','published','closed','archived']::text[])) then
   raise invalid_parameter_value using message='invalid circular query',detail='CIRCULAR_INVALID_INPUT';
  end if;
  with visible as(
   select c.*,coalesce(c.working_revision_id,c.current_revision_id) revision_id
   from public.circulars c where c.deleted_at is null
    and (ctx.resolved_institution_id is null or c.institution_id=ctx.resolved_institution_id)
    and (p_statuses is null or c.status::text=any(p_statuses))
    and (p_cursor_updated_at is null or (c.updated_at,c.id)<(p_cursor_updated_at,p_cursor_id))
  ), page as(
   select v.*,r.title,r.body_text,row_number() over(order by v.updated_at desc,v.id desc) rn
   from visible v join public.circular_revisions r on r.id=v.revision_id
   where p_search is null or r.title ilike '%'||p_search||'%' or r.body_text ilike '%'||p_search||'%'
   order by v.updated_at desc,v.id desc limit p_limit+1
  )
  select coalesce(jsonb_agg(jsonb_build_object(
   'id',p.id,'institution_id',p.institution_id,'title',p.title,
   'excerpt',left(p.body_text,220),'author_name','Equipe Coelo',
   'context_label',institution_record.public_name,'status',p.status::text,
   'effective_at',coalesce(p.publish_at,p.updated_at),'updated_at',p.updated_at,
   'attachment_count',(select count(*) from public.circular_media_links ml where ml.revision_id=p.revision_id),
   'question_count',(select count(*) from public.circular_questions q where q.revision_id=p.revision_id),
   'response_count',(select count(*) from public.circular_response_sessions rs where rs.circular_id=p.id),
   'management_version',p.management_version) order by p.updated_at desc,p.id desc)
   filter(where p.rn<=p_limit),'[]'::jsonb) into items
  from page p join public.institutions institution_record on institution_record.id=p.institution_id;
  select p.updated_at,p.id into next_record from (
   select c.updated_at,c.id,row_number() over(order by c.updated_at desc,c.id desc) rn,
    lead(c.id) over(order by c.updated_at desc,c.id desc) following_id
   from public.circulars c
   join public.circular_revisions r on r.id=coalesce(c.working_revision_id,c.current_revision_id)
   where c.deleted_at is null
    and (ctx.resolved_institution_id is null or c.institution_id=ctx.resolved_institution_id)
    and (p_statuses is null or c.status::text=any(p_statuses))
    and (p_cursor_updated_at is null or (c.updated_at,c.id)<(p_cursor_updated_at,p_cursor_id))
    and (p_search is null or r.title ilike '%'||p_search||'%' or r.body_text ilike '%'||p_search||'%')
   order by c.updated_at desc,c.id desc limit p_limit+1) p
   where p.rn=p_limit and p.following_id is not null;
  return jsonb_build_object('ok',true,'data',jsonb_build_object('items',items,
   'next_cursor_updated_at',case when next_record.id is not null then next_record.updated_at end,
   'next_cursor_id',next_record.id),'error',null);
 exception when others then
  get stacked diagnostics code=pg_exception_detail;
  return app_private.superadmin_circular_denied('circulars.read','directory',code,correlation);
 end;
end
$$;

create or replace function public.superadmin_circular_load_draft_v2(
 p_institution_id uuid,p_unit_id uuid default null,p_group_id uuid default null,p_activity_id uuid default null
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 target public.circulars%rowtype; revision public.circular_revisions%rowtype; code text;
begin begin
 ctx:=app_private.superadmin_circular_context('circulars.manage',p_institution_id);
 perform app_private.superadmin_circular_validate_scope(p_institution_id,p_unit_id,p_group_id,p_activity_id);
 select * into target from public.circulars c where c.institution_id=p_institution_id
  and c.author_internal_identity_id=ctx.internal_identity_id and c.deleted_at is null
  and c.working_revision_id is not null and c.unit_id is not distinct from p_unit_id
  and c.group_id is not distinct from p_group_id and c.activity_id is not distinct from p_activity_id
 order by c.updated_at desc limit 1;
 if target.id is null then return jsonb_build_object('ok',true,'data',null,'error',null); end if;
 select * into revision from public.circular_revisions r where r.id=target.working_revision_id;
 return jsonb_build_object('ok',true,'data',app_private.superadmin_circular_draft_json(target,revision),'error',null);
exception when others then get stacked diagnostics code=pg_exception_detail;
 return app_private.superadmin_circular_denied('circulars.manage','load_draft',code,correlation); end; end
$$;

create or replace function public.superadmin_circular_detail_v2(p_circular_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 target public.circulars%rowtype; revision public.circular_revisions%rowtype; code text;
begin begin
 ctx:=app_private.superadmin_circular_context('circulars.read',null);
 select * into target from public.circulars c where c.id=p_circular_id and c.deleted_at is null
  and (ctx.resolved_institution_id is null or c.institution_id=ctx.resolved_institution_id);
 if target.id is null then raise no_data_found using detail='CIRCULAR_NOT_FOUND'; end if;
 ctx.resolved_institution_id:=target.institution_id;
 select * into revision from public.circular_revisions r where r.id=coalesce(target.working_revision_id,target.current_revision_id);
 return jsonb_build_object('ok',true,'data',jsonb_build_object(
  'revision_id',revision.id,'institution_id',target.institution_id,
  'unit_id',target.unit_id,'group_id',target.group_id,'activity_id',target.activity_id,
  'author_name','Equipe Coelo',
  'context_label',(select i.public_name from public.institutions i where i.id=target.institution_id),
  'effective_at',coalesce(target.publish_at,target.updated_at),'revised_at',target.revised_at,
  'draft',app_private.superadmin_circular_draft_json(target,revision)),'error',null);
exception when others then get stacked diagnostics code=pg_exception_detail;
 return app_private.superadmin_circular_denied('circulars.read','detail',code,correlation); end; end
$$;

create or replace function public.superadmin_circular_save_draft_v2(
 p_request_id uuid,p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_activity_id uuid,p_payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 target public.circulars%rowtype; revision public.circular_revisions%rowtype;
 circular_id uuid:=nullif(p_payload->>'id','')::uuid; expected bigint:=coalesce((p_payload->>'version')::bigint,0);
 block jsonb; question jsonb; option jsonb; audience text; body text:=''; position int; option_position int;
 hash bytea:=extensions.digest(convert_to(coalesce(p_payload,'{}')::text,'UTF8'),'sha256');
 prior record; result jsonb; code text;
begin begin
 ctx:=app_private.superadmin_circular_context('circulars.manage',p_institution_id);
 perform app_private.superadmin_circular_validate_scope(p_institution_id,p_unit_id,p_group_id,p_activity_id);
 select * into prior from app_private.superadmin_circular_command_receipts receipt
  where receipt.internal_identity_id=ctx.internal_identity_id and receipt.request_id=p_request_id and receipt.action_code='save';
 if prior.result_json is not null then
  if prior.request_hash<>hash then raise unique_violation using detail='CIRCULAR_CONFLICT'; end if;
  return jsonb_build_object('ok',true,'data',prior.result_json,'error',null);
 end if;
 if jsonb_typeof(p_payload)<>'object' or char_length(btrim(coalesce(p_payload->>'title',''))) not between 1 and 120
  or p_payload->>'response_policy' not in ('per_person','per_child_any_guardian','per_child_each_guardian','per_staff_member')
  or jsonb_typeof(coalesce(p_payload->'blocks','[]'))<>'array'
  or jsonb_array_length(coalesce(p_payload->'blocks','[]'))>64
  or (select count(*) from jsonb_array_elements(coalesce(p_payload->'blocks','[]')) item
      where item->>'kind'='question')>10
  or jsonb_typeof(coalesce(p_payload->'audiences','[]'))<>'array' then
  raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT';
 end if;
 for block in select value from jsonb_array_elements(coalesce(p_payload->'blocks','[]')) loop
  if block->>'kind'='media' then raise invalid_parameter_value using detail='CIRCULAR_MEDIA_BLOCKED'; end if;
  if block->>'kind'='text' then body:=body||coalesce(block->>'text',''); end if;
  if block->>'kind' not in ('text','question') then raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT'; end if;
 end loop;
 if char_length(body)>10000 then raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT'; end if;
 if circular_id is null then
  insert into public.circulars(institution_id,unit_id,group_id,activity_id,
   author_internal_identity_id,author_internal_membership_id,response_policy,responses_close_at)
  values(p_institution_id,p_unit_id,p_group_id,p_activity_id,ctx.internal_identity_id,
   ctx.internal_membership_id,(p_payload->>'response_policy')::public.circular_response_policy,
   nullif(p_payload->>'responses_close_at','')::timestamptz) returning * into target;
  insert into public.circular_revisions(circular_id,institution_id,revision_number,title,body_text,
   created_by_internal_identity_id) values(target.id,p_institution_id,1,btrim(p_payload->>'title'),body,
   ctx.internal_identity_id) returning * into revision;
 else
  select * into target from public.circulars c where c.id=circular_id and c.institution_id=p_institution_id
   and c.deleted_at is null for update;
  if target.id is null then raise no_data_found using detail='CIRCULAR_NOT_FOUND'; end if;
  if target.management_version<>expected or target.status in ('closed','archived') then
   raise serialization_failure using detail=case when target.management_version<>expected then 'CIRCULAR_CONFLICT' else 'CIRCULAR_INVALID_STATE' end;
  end if;
  if target.working_revision_id is null then
   insert into public.circular_revisions(circular_id,institution_id,revision_number,title,body_text,
    created_by_internal_identity_id) values(target.id,p_institution_id,
    (select coalesce(max(r.revision_number),0)+1 from public.circular_revisions r where r.circular_id=target.id),
    btrim(p_payload->>'title'),body,ctx.internal_identity_id) returning * into revision;
  else
   select * into revision from public.circular_revisions r where r.id=target.working_revision_id and r.status='working';
   if revision.id is null then raise invalid_parameter_value using detail='CIRCULAR_INVALID_STATE'; end if;
   update public.circular_revisions set title=btrim(p_payload->>'title'),body_text=body where id=revision.id;
   delete from public.circular_blocks where revision_id=revision.id;
  end if;
  delete from public.circular_audience_rules where circular_id=target.id;
  update public.circulars set response_policy=(p_payload->>'response_policy')::public.circular_response_policy,
   responses_close_at=nullif(p_payload->>'responses_close_at','')::timestamptz,
   management_version=management_version+1,updated_at=clock_timestamp() where id=target.id returning * into target;
 end if;
 update public.circulars set working_revision_id=revision.id where id=target.id;
 position:=0;
 for block in select value from jsonb_array_elements(coalesce(p_payload->'blocks','[]')) loop
  insert into public.circular_blocks(id,revision_id,block_kind,display_order,text_content)
  values((block->>'id')::uuid,revision.id,(block->>'kind')::public.circular_block_kind,position,
   case when block->>'kind'='text' then coalesce(block->>'text','') end);
  if block->>'kind'='question' then
   question:=coalesce(block->'question',block);
   if char_length(btrim(coalesce(question->>'prompt',''))) not between 1 and 240
    or question->>'kind' not in ('single_choice','multiple_choice')
    or jsonb_array_length(coalesce(question->'options','[]')) not between 2 and 10 then
    raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT';
   end if;
   insert into public.circular_questions(id,revision_id,block_id,question_kind,prompt,required)
   values((question->>'id')::uuid,revision.id,(block->>'id')::uuid,
    (question->>'kind')::public.circular_question_kind,btrim(question->>'prompt'),
    coalesce((question->>'required')::boolean,false));
   option_position:=0;
   for option in select value from jsonb_array_elements(question->'options') loop
    insert into public.circular_question_options(id,question_id,label,display_order)
    values((option->>'id')::uuid,(question->>'id')::uuid,btrim(option->>'label'),option_position);
    option_position:=option_position+1;
   end loop;
  end if;
  position:=position+1;
 end loop;
 for audience in select value from jsonb_array_elements_text(coalesce(p_payload->'audiences','[]')) loop
  if audience not in ('families','students','school_staff','guardians_only') then
   raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT';
  end if;
  insert into public.circular_audience_rules(circular_id,institution_id,audience_kind,scope_kind,
   unit_id,group_id,activity_id) values(target.id,p_institution_id,
   audience::public.circular_audience_kind,
   case when p_activity_id is not null then 'activity' when p_group_id is not null then 'group'
    when p_unit_id is not null then 'unit' else 'institution' end::public.circular_scope_kind,
   case when p_activity_id is null then p_unit_id end,
   case when p_activity_id is null then p_group_id end,p_activity_id);
 end loop;
 result:=jsonb_build_object('id',target.id,'revision_id',revision.id,
  'version',target.management_version,'status',target.status::text);
 insert into app_private.superadmin_circular_command_receipts
  values(ctx.internal_identity_id,p_request_id,'save',hash,result,clock_timestamp());
 insert into app_private.circular_audit(circular_id,revision_id,institution_id,
  actor_internal_identity_id,event_code,detail) values(target.id,revision.id,p_institution_id,
  ctx.internal_identity_id,'internal_draft_saved',jsonb_build_object('version',target.management_version));
 perform app_private.superadmin_circular_audit(ctx,'save',target.id,'success','saved',correlation);
 return jsonb_build_object('ok',true,'data',result,'error',null);
exception when others then get stacked diagnostics code=pg_exception_detail;
 return app_private.superadmin_circular_denied('circulars.manage','save',code,correlation); end; end
$$;

create or replace function public.superadmin_circular_publish_v2(
 p_request_id uuid,p_circular_id uuid,p_expected_version bigint,p_publish_at timestamptz default null
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 target public.circulars%rowtype; revision public.circular_revisions%rowtype; result jsonb; prior record;
 at timestamptz:=coalesce(p_publish_at,clock_timestamp()); code text;
 hash bytea:=extensions.digest(convert_to(p_circular_id::text||p_expected_version::text||coalesce(p_publish_at::text,'now'),'UTF8'),'sha256');
begin begin
 select * into target from public.circulars c where c.id=p_circular_id and c.deleted_at is null for update;
 if target.id is null then raise no_data_found using detail='CIRCULAR_NOT_FOUND'; end if;
 ctx:=app_private.superadmin_circular_context('circulars.publish',target.institution_id);
 select * into prior from app_private.superadmin_circular_command_receipts receipt
  where receipt.internal_identity_id=ctx.internal_identity_id and receipt.request_id=p_request_id and receipt.action_code='publish';
 if prior.result_json is not null then
  if prior.request_hash<>hash then raise unique_violation using detail='CIRCULAR_CONFLICT'; end if;
  return jsonb_build_object('ok',true,'data',prior.result_json,'error',null);
 end if;
 if target.management_version<>p_expected_version then raise serialization_failure using detail='CIRCULAR_CONFLICT'; end if;
 if target.working_revision_id is null or target.status in ('closed','archived')
  or not exists(select 1 from public.circular_audience_rules a where a.circular_id=target.id) then
  raise invalid_parameter_value using detail='CIRCULAR_INVALID_STATE';
 end if;
 if exists(select 1 from public.circular_media_links ml where ml.revision_id=target.working_revision_id) then
  raise invalid_parameter_value using detail='CIRCULAR_MEDIA_BLOCKED';
 end if;
 select * into revision from public.circular_revisions r where r.id=target.working_revision_id and r.status='working';
 update public.circular_revisions set status='superseded' where circular_id=target.id and status='published';
 update public.circular_revisions set status='published',published_at=clock_timestamp() where id=revision.id;
 update public.circulars set status=case when at>clock_timestamp() then 'scheduled' else 'published' end::public.circular_status,
  current_revision_id=revision.id,working_revision_id=null,publish_at=at,
  published_at=case when at<=clock_timestamp() then coalesce(published_at,clock_timestamp()) else published_at end,
  revised_at=case when published_at is not null then clock_timestamp() end,
  management_version=management_version+1,updated_at=clock_timestamp()
 where id=target.id returning * into target;
 result:=jsonb_build_object('id',target.id,'revision_id',revision.id,'version',target.management_version,'status',target.status::text);
 insert into app_private.superadmin_circular_command_receipts values(ctx.internal_identity_id,p_request_id,'publish',hash,result,clock_timestamp());
 insert into app_private.circular_audit(circular_id,revision_id,institution_id,actor_internal_identity_id,event_code,detail)
 values(target.id,revision.id,target.institution_id,ctx.internal_identity_id,'internal_published',jsonb_build_object('publish_at',at));
 perform app_private.superadmin_circular_audit(ctx,'publish',target.id,'success','published',correlation);
 return jsonb_build_object('ok',true,'data',result,'error',null);
exception when others then get stacked diagnostics code=pg_exception_detail;
 return app_private.superadmin_circular_denied('circulars.publish','publish',code,correlation); end; end
$$;

create or replace function public.superadmin_circular_close_v2(
 p_request_id uuid,p_circular_id uuid,p_expected_version bigint
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 target public.circulars%rowtype; result jsonb; prior record; code text;
 hash bytea:=extensions.digest(convert_to(p_circular_id::text||p_expected_version::text,'UTF8'),'sha256');
begin begin
 select * into target from public.circulars c where c.id=p_circular_id and c.deleted_at is null for update;
 if target.id is null then raise no_data_found using detail='CIRCULAR_NOT_FOUND'; end if;
 ctx:=app_private.superadmin_circular_context('circulars.manage',target.institution_id);
 select * into prior from app_private.superadmin_circular_command_receipts receipt
  where receipt.internal_identity_id=ctx.internal_identity_id and receipt.request_id=p_request_id and receipt.action_code='close';
 if prior.result_json is not null then
  if prior.request_hash<>hash then raise unique_violation using detail='CIRCULAR_CONFLICT'; end if;
  return jsonb_build_object('ok',true,'data',prior.result_json,'error',null);
 end if;
 if target.management_version<>p_expected_version then raise serialization_failure using detail='CIRCULAR_CONFLICT'; end if;
 if target.status not in ('published','scheduled') then raise invalid_parameter_value using detail='CIRCULAR_INVALID_STATE'; end if;
 update public.circulars set status='closed',responses_closed_at=clock_timestamp(),responses_closed_by=null,
  responses_closed_by_internal_identity_id=ctx.internal_identity_id,
  management_version=management_version+1,updated_at=clock_timestamp()
 where id=target.id returning * into target;
 result:=jsonb_build_object('id',target.id,'revision_id',target.current_revision_id,
  'version',target.management_version,'status',target.status::text);
 insert into app_private.superadmin_circular_command_receipts values(ctx.internal_identity_id,p_request_id,'close',hash,result,clock_timestamp());
 insert into app_private.circular_audit(circular_id,revision_id,institution_id,actor_internal_identity_id,event_code,detail)
 values(target.id,target.current_revision_id,target.institution_id,ctx.internal_identity_id,'internal_responses_closed','{}');
 perform app_private.superadmin_circular_audit(ctx,'close',target.id,'success','closed',correlation);
 return jsonb_build_object('ok',true,'data',result,'error',null);
exception when others then get stacked diagnostics code=pg_exception_detail;
 return app_private.superadmin_circular_denied('circulars.manage','close',code,correlation); end; end
$$;

create or replace function public.superadmin_circular_response_summary_v2(p_circular_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 target public.circulars%rowtype; code text;
begin begin
 ctx:=app_private.superadmin_circular_context('circulars.read',null);
 select * into target from public.circulars c where c.id=p_circular_id and c.deleted_at is null
  and (ctx.resolved_institution_id is null or c.institution_id=ctx.resolved_institution_id);
 if target.id is null then raise no_data_found using detail='CIRCULAR_NOT_FOUND'; end if;
 return jsonb_build_object('ok',true,'data',jsonb_build_object(
  'response_count',(select count(*) from public.circular_response_sessions s where s.circular_id=target.id),
  'submitted_count',(select count(*) from public.circular_response_sessions s where s.circular_id=target.id and s.status='submitted'),
  'partial_count',(select count(*) from public.circular_response_sessions s where s.circular_id=target.id and s.status='partial'),
  'closed',target.responses_closed_at is not null),'error',null);
exception when others then get stacked diagnostics code=pg_exception_detail;
 return app_private.superadmin_circular_denied('circulars.read','response_summary',code,correlation); end; end
$$;

do $acl$
declare function_record regprocedure;
begin
 for function_record in select procedure_record.oid::regprocedure from pg_proc procedure_record
 join pg_namespace namespace_record on namespace_record.oid=procedure_record.pronamespace
 where (namespace_record.nspname='app_private' and procedure_record.proname like 'superadmin_circular_%')
    or (namespace_record.nspname='public' and procedure_record.proname like 'superadmin_circular_%_v2')
 loop
  execute format('alter function %s owner to postgres',function_record);
  execute format('revoke all on function %s from public, anon, authenticated, service_role',function_record);
 end loop;
end
$acl$;

grant execute on function public.superadmin_circular_directory_v2(uuid,text,text[],timestamptz,uuid,integer) to authenticated;
grant execute on function public.superadmin_circular_load_draft_v2(uuid,uuid,uuid,uuid) to authenticated;
grant execute on function public.superadmin_circular_detail_v2(uuid) to authenticated;
grant execute on function public.superadmin_circular_save_draft_v2(uuid,uuid,uuid,uuid,uuid,jsonb) to authenticated;
grant execute on function public.superadmin_circular_publish_v2(uuid,uuid,bigint,timestamptz) to authenticated;
grant execute on function public.superadmin_circular_close_v2(uuid,uuid,bigint) to authenticated;
grant execute on function public.superadmin_circular_response_summary_v2(uuid) to authenticated;

commit;
