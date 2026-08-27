begin;

-- Audit remains private. Browser clients can only use the guarded public RPCs.
drop policy if exists audit_logs_audit_read on audit.audit_logs;
alter table audit.audit_logs enable row level security;
alter table audit.audit_logs force row level security;
revoke all on table audit.audit_logs from public, anon, authenticated;

insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status,
  module_label,screen_label,action_label
) values
  ('audit.read','audit','logs','read','Ler a trilha de auditoria dentro do escopo autorizado.','high',false,'active','Auditoria','Logs','Ver'),
  ('audit.export','audit','logs','export','Exportar a trilha de auditoria dentro do escopo autorizado.','critical',true,'active','Auditoria','Logs','Exportar')
on conflict(code) do update set
  description=excluded.description,risk_level=excluded.risk_level,
  requires_mfa=excluded.requires_mfa,status='active',module_label=excluded.module_label,
  screen_label=excluded.screen_label,action_label=excluded.action_label,updated_at=now();

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code in('owner','auditor')
  and permission_record.code in('audit.read','audit.export')
on conflict(role_id,permission_id) do update set
  effect='allow',status='active',revoked_at=null;

create sequence if not exists audit.audit_log_chain_position_seq;

alter table audit.audit_logs
  add column if not exists actor_role_code text,
  add column if not exists correlation_id uuid,
  add column if not exists origin text,
  add column if not exists context_kind text,
  add column if not exists context_id uuid,
  add column if not exists payload_contract_version smallint,
  add column if not exists chain_position bigint,
  add column if not exists previous_hash bytea,
  add column if not exists entry_hash bytea;

alter table audit.audit_logs
  alter column correlation_id set default gen_random_uuid(),
  alter column origin set default 'database',
  alter column chain_position set default nextval('audit.audit_log_chain_position_seq');

update audit.audit_logs
set correlation_id=coalesce(correlation_id,gen_random_uuid()),
    origin=coalesce(origin,'database'),
    context_kind=coalesce(context_kind,case when institution_id is null then 'global' else 'institution' end),
    context_id=coalesce(context_id,institution_id),
    chain_position=coalesce(chain_position,nextval('audit.audit_log_chain_position_seq'))
where correlation_id is null or origin is null or context_kind is null or chain_position is null;

select setval(
  'audit.audit_log_chain_position_seq',
  greatest(coalesce((select max(chain_position) from audit.audit_logs),0)+1,1),
  false
);

alter table audit.audit_logs
  alter column correlation_id set not null,
  alter column origin set not null,
  alter column context_kind set not null,
  alter column chain_position set not null;

alter table audit.audit_logs
  drop constraint if exists audit_logs_origin_check,
  add constraint audit_logs_origin_check
    check(origin in('database','edge_function','system','admin_ui','import')),
  drop constraint if exists audit_logs_context_kind_check,
  add constraint audit_logs_context_kind_check
    check(context_kind in('global','institution','unit','group','activity','child')),
  drop constraint if exists audit_logs_context_pair_check,
  add constraint audit_logs_context_pair_check check(
    (context_kind='global' and institution_id is null and context_id is null)
    or (context_kind<>'global' and institution_id is not null and context_id is not null)
  ),
  drop constraint if exists audit_logs_payload_contract_version_check,
  add constraint audit_logs_payload_contract_version_check
    check(payload_contract_version is null or payload_contract_version=1),
  drop constraint if exists audit_logs_chain_position_key,
  add constraint audit_logs_chain_position_key unique(chain_position),
  drop constraint if exists audit_logs_previous_hash_length_check,
  add constraint audit_logs_previous_hash_length_check
    check(previous_hash is null or octet_length(previous_hash)=32),
  drop constraint if exists audit_logs_entry_hash_length_check,
  add constraint audit_logs_entry_hash_length_check
    check(entry_hash is null or octet_length(entry_hash)=32);

create or replace function app_private.audit_mask_payload(p_value jsonb)
returns jsonb
language plpgsql
immutable
security invoker
set search_path=''
as $$
declare
  result jsonb:='{}'::jsonb;
  item record;
begin
  if p_value is null then return null; end if;
  if jsonb_typeof(p_value)<>'object' then return null; end if;
  for item in select * from jsonb_each(p_value) loop
    if item.key in('id','scope_id','institution_id','unit_id','group_id','child_context_id','activity_id')
      and (jsonb_typeof(item.value)='null' or
        (jsonb_typeof(item.value)='string' and trim(both '"' from item.value::text)
          ~*'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')) then
      result:=result||jsonb_build_object(item.key,item.value);
    elsif item.key in('status','role_code','scope_kind','format','state')
      and jsonb_typeof(item.value)='string'
      and trim(both '"' from item.value::text)~'^[A-Za-z0-9][A-Za-z0-9._:-]{0,79}$' then
      result:=result||jsonb_build_object(item.key,item.value);
    elsif item.key in('version','management_version','row_count','valid_count','rejected_count',
        'created_count','updated_count','linked_count','ignored_count')
      and jsonb_typeof(item.value)='number' then
      result:=result||jsonb_build_object(item.key,item.value);
    elsif item.key in('pii_included','replayed') and jsonb_typeof(item.value)='boolean' then
      result:=result||jsonb_build_object(item.key,item.value);
    elsif item.key in('created_at','updated_at') and jsonb_typeof(item.value)='string'
      and trim(both '"' from item.value::text)
        ~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.+-]{8,35}Z?$' then
      result:=result||jsonb_build_object(item.key,item.value);
    end if;
  end loop;
  return result;
end;
$$;

create or replace function app_private.audit_minimize_payload(p_action_code text,p_value jsonb)
returns jsonb
language sql
immutable
security invoker
set search_path=''
as $$
  select case when p_value is null then null when p_action_code like 'audit.export.%' then
    coalesce((select jsonb_object_agg(item.key,item.value)
      from jsonb_each(app_private.audit_mask_payload(p_value)) item
      where item.key in('format','state','row_count','pii_included')),'{}'::jsonb)
  else app_private.audit_mask_payload(p_value) end
$$;

create or replace function app_private.audit_entry_digest(
  p_chain_position bigint,p_previous_hash bytea,p_id uuid,p_actor_person_id uuid,
  p_actor_role_code text,p_correlation_id uuid,p_origin text,p_context_kind text,
  p_context_id uuid,p_action_code text,p_object_type text,p_object_id uuid,
  p_institution_id uuid,p_outcome public.audit_outcome,p_reason text,
  p_before_json jsonb,p_after_json jsonb,p_occurred_at timestamptz
)
returns bytea
language sql
immutable
security invoker
set search_path=''
as $$
  select extensions.digest(pg_catalog.convert_to(jsonb_build_object(
    'chain_position',p_chain_position,
    'previous_hash',case when p_previous_hash is null then null else encode(p_previous_hash,'hex') end,
    'id',p_id,'actor_person_id',p_actor_person_id,'actor_role_code',p_actor_role_code,
    'correlation_id',p_correlation_id,'origin',p_origin,'context_kind',p_context_kind,
    'context_id',p_context_id,'action_code',p_action_code,'object_type',p_object_type,
    'object_id',p_object_id,'institution_id',p_institution_id,'outcome',p_outcome,
    'reason',p_reason,'before',p_before_json,'after',p_after_json,'occurred_at',p_occurred_at
  )::text,'UTF8'),'sha256')
$$;

create or replace function app_private.audit_mask_reason(p_value text)
returns text
language sql
immutable
security invoker
set search_path=''
as $$
  select case
    when p_value is null then null
    when p_value ~ '^[a-z0-9][a-z0-9._-]{0,119}$' then p_value
    else '[redacted]'
  end
$$;

-- Existing rows may predate the minimized payload contract. Sanitize them in
-- place before rebuilding integrity evidence so secrets do not remain at rest.
update audit.audit_logs
set reason=app_private.audit_mask_reason(reason),
    before_json=app_private.audit_minimize_payload(action_code,before_json),
    after_json=app_private.audit_minimize_payload(action_code,after_json),
    payload_contract_version=1;

alter table audit.audit_logs alter column payload_contract_version set not null;

do $$
declare
  item record;
  prior_hash bytea;
begin
  for item in select * from audit.audit_logs order by chain_position loop
    update audit.audit_logs set
      previous_hash=prior_hash,
      entry_hash=app_private.audit_entry_digest(
        item.chain_position,prior_hash,item.id,item.actor_person_id,item.actor_role_code,
        item.correlation_id,item.origin,item.context_kind,item.context_id,item.action_code,
        item.object_type,item.object_id,item.institution_id,item.outcome,item.reason,
        item.before_json,item.after_json,item.occurred_at
      )
    where id=item.id
    returning entry_hash into prior_hash;
  end loop;
end $$;

alter table audit.audit_logs alter column entry_hash set not null;
alter table audit.audit_logs alter column chain_position drop default;

create or replace function app_private.audit_guard_append_only()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  expected_institution uuid;
  prior_hash bytea;
begin
  if tg_op in('UPDATE','DELETE') then
    raise object_not_in_prerequisite_state using message='audit logs are append-only';
  end if;

  new.origin:=coalesce(new.origin,'database');
  new.correlation_id:=coalesce(new.correlation_id,gen_random_uuid());
  new.context_kind:=coalesce(new.context_kind,case when new.institution_id is null then 'global' else 'institution' end);
  new.context_id:=coalesce(new.context_id,case when new.context_kind='institution' then new.institution_id else null end);
  new.reason:=app_private.audit_mask_reason(new.reason);
  new.actor_role_code:=case when new.actor_person_id is null then 'system' else coalesce((
    select role_record.code from public.platform_memberships membership
    join public.platform_roles role_record on role_record.id=membership.role_id
    where membership.person_id=new.actor_person_id and membership.status='active'
      and membership.revoked_at is null and role_record.status='active'
    order by case membership.scope_kind when 'platform' then 0 else 1 end,membership.created_at
    limit 1
  ),(
    select membership.role_code from public.institution_memberships membership
    where membership.person_id=new.actor_person_id
      and (new.institution_id is null or membership.institution_id=new.institution_id)
      and membership.status='active' and membership.revoked_at is null
    order by membership.created_at limit 1
  )) end;

  if new.origin not in('database','edge_function','system','admin_ui','import')
    or new.action_code !~ '^[a-z0-9][a-z0-9._-]{0,119}$'
    or new.context_kind not in('global','institution','unit','group','activity','child') then
    raise invalid_parameter_value using message='invalid audit origin or context';
  end if;

  if new.context_kind='global' then
    if new.institution_id is not null or new.context_id is not null then
      raise invalid_parameter_value using message='invalid audit origin or context';
    end if;
  elsif new.context_kind='institution' then
    expected_institution:=new.context_id;
  elsif new.context_kind='unit' then
    select institution_id into expected_institution from public.units where id=new.context_id;
  elsif new.context_kind='group' then
    select institution_id into expected_institution from public.groups where id=new.context_id;
  elsif new.context_kind='activity' then
    select institution_id into expected_institution from public.activity_definitions where id=new.context_id;
  elsif new.context_kind='child' then
    select institution_id into expected_institution from public.child_contexts where id=new.context_id;
  end if;
  if new.context_kind<>'global'
    and (expected_institution is null or expected_institution is distinct from new.institution_id) then
    raise invalid_parameter_value using message='invalid audit origin or context';
  end if;

  -- The database owns minimization. A caller cannot opt out by omitting or
  -- changing the contract version.
  new.before_json:=app_private.audit_minimize_payload(new.action_code,new.before_json);
  new.after_json:=app_private.audit_minimize_payload(new.action_code,new.after_json);
  new.payload_contract_version:=1;

  perform pg_advisory_xact_lock(hashtextextended('audit.audit_logs.chain',0));
  new.chain_position:=nextval('audit.audit_log_chain_position_seq');
  select entry_hash into prior_hash from audit.audit_logs order by chain_position desc limit 1;
  new.previous_hash:=prior_hash;
  new.entry_hash:=app_private.audit_entry_digest(
    new.chain_position,new.previous_hash,new.id,new.actor_person_id,new.actor_role_code,
    new.correlation_id,new.origin,new.context_kind,new.context_id,new.action_code,
    new.object_type,new.object_id,new.institution_id,new.outcome,new.reason,
    new.before_json,new.after_json,new.occurred_at
  );
  return new;
end;
$$;

drop trigger if exists audit_logs_append_only on audit.audit_logs;
create trigger audit_logs_append_only
before insert or update or delete on audit.audit_logs
for each row execute function app_private.audit_guard_append_only();

create index if not exists audit_logs_cursor_idx
  on audit.audit_logs(occurred_at desc,id desc);
create index if not exists audit_logs_context_cursor_idx
  on audit.audit_logs(institution_id,context_kind,context_id,occurred_at desc,id desc);
create index if not exists audit_logs_correlation_idx
  on audit.audit_logs(correlation_id,occurred_at desc);
create index if not exists audit_logs_action_outcome_cursor_idx
  on audit.audit_logs(action_code,outcome,occurred_at desc,id desc);
create index if not exists audit_logs_institution_cursor_idx
  on audit.audit_logs(institution_id,occurred_at desc,id desc);
create index if not exists audit_logs_actor_cursor_idx
  on audit.audit_logs(actor_person_id,occurred_at desc,id desc);

create or replace function app_private.audit_actor_has_permission(
  p_actor_person_id uuid,p_permission_code text,p_institution_id uuid default null,
  p_any_scope boolean default false
)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  with memberships as (
    select membership.id,membership.role_id
    from public.platform_memberships membership
    join public.platform_roles role_record on role_record.id=membership.role_id
    where membership.person_id=p_actor_person_id
      and membership.status='active' and membership.revoked_at is null
      and role_record.status='active'
      and (
        p_any_scope
        or (p_institution_id is null and membership.scope_kind='platform' and membership.scope_institution_id is null)
        or (p_institution_id is not null and (
          (membership.scope_kind='platform' and membership.scope_institution_id is null)
          or (membership.scope_kind='institution' and membership.scope_institution_id=p_institution_id)
        ))
      )
  ), target as (
    select id from public.platform_permissions where code=p_permission_code and status='active'
  ), effects as (
    select grant_record.effect from memberships
    join public.platform_role_permissions grant_record on grant_record.role_id=memberships.role_id
      and grant_record.status='active' and grant_record.revoked_at is null
    join target on target.id=grant_record.permission_id
    union all
    select override_record.effect from memberships
    join public.platform_member_permission_overrides override_record on override_record.membership_id=memberships.id
      and override_record.status='active'
      and (override_record.starts_at is null or override_record.starts_at<=now())
      and (override_record.expires_at is null or override_record.expires_at>now())
    join target on target.id=override_record.permission_id
  )
  select exists(select 1 from effects where effect='allow')
    and not exists(select 1 from effects where effect='deny')
$$;

create or replace function app_private.audit_has_permission(
  p_permission_code text,p_institution_id uuid default null,p_any_scope boolean default false
)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select app_private.audit_actor_has_permission(
    app_private.current_person_id(),p_permission_code,p_institution_id,p_any_scope
  )
$$;

create or replace function app_private.audit_authorization_scope(p_actor_person_id uuid,p_permission_code text)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'global',app_private.audit_actor_has_permission(p_actor_person_id,p_permission_code,null,false),
    'institution_ids',coalesce((select jsonb_agg(scope.institution_id order by scope.institution_id)
      from (select distinct membership.scope_institution_id institution_id
        from public.platform_memberships membership
        where membership.person_id=p_actor_person_id and membership.status='active'
          and membership.revoked_at is null and membership.scope_kind='institution'
          and membership.scope_institution_id is not null
          and app_private.audit_actor_has_permission(p_actor_person_id,p_permission_code,
            membership.scope_institution_id,false)) scope),'[]'::jsonb),
    'denied_institution_ids',coalesce((select jsonb_agg(scope.institution_id order by scope.institution_id)
      from (select distinct membership.scope_institution_id institution_id
        from public.platform_memberships membership
        where membership.person_id=p_actor_person_id and membership.status='active'
          and membership.revoked_at is null and membership.scope_kind='institution'
          and membership.scope_institution_id is not null
          and not app_private.audit_actor_has_permission(p_actor_person_id,p_permission_code,
            membership.scope_institution_id,false)) scope),'[]'::jsonb)
  )
$$;

create or replace function app_private.audit_assert_permission(p_permission_code text,p_require_aal2 boolean)
returns uuid
language plpgsql
stable
security definer
set search_path=''
as $$
declare actor uuid:=app_private.current_person_id();v_authorization jsonb;
begin
  if (select auth.uid()) is null or actor is null then
    raise insufficient_privilege using message=case when p_permission_code='audit.read' then 'audit.read required' else 'audit.export and AAL2 required' end;
  end if;
  v_authorization:=app_private.audit_authorization_scope(actor,p_permission_code);
  if (not coalesce((v_authorization->>'global')::boolean,false)
      and jsonb_array_length(coalesce(v_authorization->'institution_ids','[]'::jsonb))=0)
    or (p_require_aal2 and not app_private.has_mfa_aal2()) then
    raise insufficient_privilege using message=case when p_permission_code='audit.read' then 'audit.read required' else 'audit.export and AAL2 required' end;
  end if;
  return actor;
end;
$$;

create or replace function app_private.audit_validate_list_filters(
  p_search text,p_actor_ids uuid[],p_context_kinds text[],p_action_codes text[],
  p_resource_types text[],p_outcomes text[],p_origins text[],
  p_from timestamptz,p_to timestamptz,p_before_occurred_at timestamptz,
  p_before_event_id uuid,p_page_size integer
)
returns void
language plpgsql
immutable
security invoker
set search_path=''
as $$
begin
  if p_page_size not between 1 and 100
    or length(coalesce(p_search,''))>200 or coalesce(p_search,'')~'[[:cntrl:]]'
    or (p_from is not null and p_to is not null and p_from>p_to)
    or ((p_before_occurred_at is null)<>(p_before_event_id is null))
    or coalesce(cardinality(p_action_codes),0)>20
    or coalesce(cardinality(p_actor_ids),0)>50
    or coalesce(cardinality(p_context_kinds),0)>10
    or coalesce(cardinality(p_resource_types),0)>20
    or coalesce(cardinality(p_outcomes),0)>10
    or coalesce(cardinality(p_origins),0)>10
    or exists(select 1 from unnest(coalesce(p_action_codes,'{}')) item where item !~ '^[a-z0-9][a-z0-9._-]{0,119}$')
    or exists(select 1 from unnest(coalesce(p_context_kinds,'{}')) item where item not in('global','institution','unit','group','activity','child'))
    or exists(select 1 from unnest(coalesce(p_resource_types,'{}')) item where item !~ '^[a-z0-9][a-z0-9._-]{0,119}$')
    or exists(select 1 from unnest(coalesce(p_outcomes,'{}')) item where item not in('success','failure','denied'))
    or exists(select 1 from unnest(coalesce(p_origins,'{}')) item where item not in('database','edge_function','system','admin_ui','import')) then
    raise invalid_parameter_value using message='invalid audit list filters';
  end if;
end;
$$;

create or replace function app_private.audit_list_events_for_superadmin(
  p_search text default null,p_actor_ids uuid[] default null,p_context_kinds text[] default null,
  p_action_codes text[] default null,p_resource_types text[] default null,
  p_outcomes text[] default null,p_origins text[] default null,p_institution_id uuid default null,
  p_from timestamptz default null,p_to timestamptz default null,
  p_cursor_occurred_at timestamptz default null,p_cursor_id uuid default null,p_limit integer default 25
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare result jsonb;actor uuid;v_authorization jsonb;export_authorization jsonb;
begin
  actor:=app_private.audit_assert_permission('audit.read',false);
  v_authorization:=app_private.audit_authorization_scope(actor,'audit.read');
  export_authorization:=app_private.audit_authorization_scope(actor,'audit.export');
  perform app_private.audit_validate_list_filters(p_search,p_actor_ids,p_context_kinds,
    p_action_codes,p_resource_types,p_outcomes,p_origins,p_from,p_to,
    p_cursor_occurred_at,p_cursor_id,p_limit);

  with filtered as materialized (
    select log_record.*,person.display_name,institution.public_name institution_name
    from audit.audit_logs log_record
    left join public.people person on person.id=log_record.actor_person_id
    left join public.institutions institution on institution.id=log_record.institution_id
    where (((v_authorization->>'global')::boolean
        and (log_record.institution_id is null or not((v_authorization->'denied_institution_ids')?log_record.institution_id::text)))
      or (log_record.institution_id is not null and (v_authorization->'institution_ids')?log_record.institution_id::text))
      and (p_institution_id is null or log_record.institution_id=p_institution_id)
      and (p_actor_ids is null or cardinality(p_actor_ids)=0 or log_record.actor_person_id=any(p_actor_ids))
      and (p_context_kinds is null or cardinality(p_context_kinds)=0 or log_record.context_kind=any(p_context_kinds))
      and (p_action_codes is null or cardinality(p_action_codes)=0 or log_record.action_code=any(p_action_codes))
      and (p_resource_types is null or cardinality(p_resource_types)=0 or log_record.object_type=any(p_resource_types))
      and (p_outcomes is null or cardinality(p_outcomes)=0 or
        case log_record.outcome::text when 'failed' then 'failure' else log_record.outcome::text end=any(p_outcomes))
      and (p_origins is null or cardinality(p_origins)=0 or log_record.origin=any(p_origins))
      and (p_from is null or log_record.occurred_at>=p_from)
      and (p_to is null or log_record.occurred_at<=p_to)
      and (nullif(btrim(p_search),'') is null or position(lower(btrim(p_search)) in lower(concat_ws(' ',log_record.action_code,
        log_record.object_type,log_record.object_id::text,log_record.correlation_id::text,
        person.display_name,institution.public_name)))>0)
  ), page_plus_one as (
    select * from filtered
    where p_cursor_occurred_at is null or (occurred_at,id)<(p_cursor_occurred_at,p_cursor_id)
    order by occurred_at desc,id desc limit p_limit+1
  ), visible as (
    select * from page_plus_one order by occurred_at desc,id desc limit p_limit
  )
  select jsonb_build_object(
    'items',coalesce((select jsonb_agg(jsonb_build_object(
      'id',id,
      'actor',jsonb_build_object('id',actor_person_id,
        'display_name',case when actor_person_id is null then 'Sistema'
          else coalesce(display_name,'Ator não disponível') end,'role_code',coalesce(actor_role_code,
          case when actor_person_id is null then 'system' else 'legacy_unknown' end)),
      'institution',case when institution_id is null then null else jsonb_build_object('id',institution_id,'name',institution_name) end,
      'action_code',action_code,'object_type',object_type,'object_id',object_id,
      'outcome',case outcome::text when 'failed' then 'failure' else outcome::text end,
      'correlation_id',correlation_id,'origin',origin,
      'context',jsonb_build_object('kind',context_kind,'id',context_id),'occurred_at',occurred_at
    ) order by occurred_at desc,id desc) from visible),'[]'::jsonb),
    'has_more',(select count(*) from page_plus_one)>p_limit,
    'next_cursor',case when (select count(*) from page_plus_one)>p_limit then
      (select jsonb_build_object('occurred_at',occurred_at,'event_id',id)
       from visible order by occurred_at,id limit 1) else null end,
    'total_count',(select count(*) from filtered),
    'can_export',(coalesce((export_authorization->>'global')::boolean,false)
      or jsonb_array_length(coalesce(export_authorization->'institution_ids','[]'::jsonb))>0)
      and app_private.has_mfa_aal2()
  ) into result;
  return result;
end;
$$;

create or replace function app_private.audit_get_event_for_superadmin(p_event_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare result jsonb;
begin
  perform app_private.audit_assert_permission('audit.read',false);
  if p_event_id is null then raise invalid_parameter_value using message='invalid audit event id'; end if;
  select jsonb_build_object(
    'id',log_record.id,
    'actor',jsonb_build_object('id',log_record.actor_person_id,
      'display_name',case when log_record.actor_person_id is null then 'Sistema'
        else coalesce(person.display_name,'Ator não disponível') end,
      'role_code',coalesce(log_record.actor_role_code,
        case when log_record.actor_person_id is null then 'system' else 'legacy_unknown' end)),
    'institution',case when log_record.institution_id is null then null else jsonb_build_object(
      'id',log_record.institution_id,'name',institution.public_name) end,
    'action_code',log_record.action_code,'object_type',log_record.object_type,'object_id',log_record.object_id,
    'outcome',case log_record.outcome::text when 'failed' then 'failure' else log_record.outcome::text end,
    'reason',app_private.audit_mask_reason(log_record.reason),
    'before',app_private.audit_mask_payload(log_record.before_json),
    'after',app_private.audit_mask_payload(log_record.after_json),
    'correlation_id',log_record.correlation_id,'origin',log_record.origin,
    'context',jsonb_build_object('kind',log_record.context_kind,'id',log_record.context_id),
    'occurred_at',log_record.occurred_at,
    'integrity',jsonb_build_object(
      'position',log_record.chain_position,
      'previous_hash',case when log_record.previous_hash is null then null else encode(log_record.previous_hash,'hex') end,
      'hash',encode(log_record.entry_hash,'hex'),
      'verified',log_record.entry_hash=app_private.audit_entry_digest(
        log_record.chain_position,log_record.previous_hash,log_record.id,log_record.actor_person_id,
        log_record.actor_role_code,log_record.correlation_id,log_record.origin,log_record.context_kind,
        log_record.context_id,log_record.action_code,log_record.object_type,log_record.object_id,
        log_record.institution_id,log_record.outcome,log_record.reason,log_record.before_json,
        log_record.after_json,log_record.occurred_at)
        and log_record.previous_hash is not distinct from (
          select prior.entry_hash from audit.audit_logs prior
          where prior.chain_position<log_record.chain_position
          order by prior.chain_position desc limit 1
        )
    )
  ) into result
  from audit.audit_logs log_record
  left join public.people person on person.id=log_record.actor_person_id
  left join public.institutions institution on institution.id=log_record.institution_id
  where log_record.id=p_event_id
    and app_private.audit_has_permission('audit.read',log_record.institution_id,false);
  return result;
end;
$$;

create or replace function app_private.audit_validate_export_filters(p_filters jsonb)
returns void
language plpgsql
immutable
security invoker
set search_path=''
as $$
declare item text;from_value timestamptz;to_value timestamptz;
begin
  begin
    if p_filters is null or jsonb_typeof(p_filters)<>'object'
      or p_filters-array['search','actor_ids','context_kinds','action_codes','resource_types',
        'outcomes','origins','institution_id','from','to']<>'{}'::jsonb
      or length(coalesce(p_filters->>'search',''))>200
      or coalesce(p_filters->>'search','')~'[[:cntrl:]]' then
      raise invalid_parameter_value;
    end if;
    foreach item in array array['actor_ids','context_kinds','action_codes','resource_types','outcomes','origins'] loop
      if p_filters?item and jsonb_typeof(p_filters->item)<>'array' then raise invalid_parameter_value; end if;
    end loop;
    if coalesce(jsonb_array_length(coalesce(p_filters->'actor_ids','[]')),0)>50
      or coalesce(jsonb_array_length(coalesce(p_filters->'context_kinds','[]')),0)>10
      or coalesce(jsonb_array_length(coalesce(p_filters->'action_codes','[]')),0)>20
      or coalesce(jsonb_array_length(coalesce(p_filters->'resource_types','[]')),0)>20
      or coalesce(jsonb_array_length(coalesce(p_filters->'outcomes','[]')),0)>10
      or coalesce(jsonb_array_length(coalesce(p_filters->'origins','[]')),0)>10 then raise invalid_parameter_value; end if;
    if exists(select 1 from jsonb_array_elements_text(coalesce(p_filters->'actor_ids','[]')) value
      where value!~*'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
      or exists(select 1 from jsonb_array_elements_text(coalesce(p_filters->'context_kinds','[]')) value
        where value not in('global','institution','unit','group','activity','child'))
      or exists(select 1 from jsonb_array_elements_text(coalesce(p_filters->'action_codes','[]')) value
        where value!~'^[a-z0-9][a-z0-9._-]{0,119}$')
      or exists(select 1 from jsonb_array_elements_text(coalesce(p_filters->'resource_types','[]')) value
        where value!~'^[a-z0-9][a-z0-9._-]{0,119}$')
      or exists(select 1 from jsonb_array_elements_text(coalesce(p_filters->'outcomes','[]')) value
        where value not in('success','failure','denied'))
      or exists(select 1 from jsonb_array_elements_text(coalesce(p_filters->'origins','[]')) value
        where value not in('database','edge_function','system','admin_ui','import')) then raise invalid_parameter_value; end if;
    if p_filters?'institution_id' and (p_filters->>'institution_id')!~*'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise invalid_parameter_value; end if;
    if p_filters?'from' then from_value:=(p_filters->>'from')::timestamptz; end if;
    if p_filters?'to' then to_value:=(p_filters->>'to')::timestamptz; end if;
    if from_value is not null and to_value is not null and from_value>to_value then raise invalid_parameter_value; end if;
  exception when others then
    raise invalid_parameter_value using message='invalid audit export request';
  end;
end;
$$;

create or replace function app_private.audit_start_export_for_superadmin(
  p_format text,p_filters jsonb,p_idempotency_key uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare actor uuid;request_hash bytea;job public.import_jobs%rowtype;result jsonb;v_authorization jsonb;
begin
  actor:=app_private.audit_assert_permission('audit.export',true);
  perform app_private.audit_assert_permission('audit.read',false);
  if p_format not in('csv','xlsx') or p_idempotency_key is null then
    raise invalid_parameter_value using message='invalid audit export request';
  end if;
  perform app_private.audit_validate_export_filters(p_filters);
  v_authorization:=jsonb_build_object(
    'read',app_private.audit_authorization_scope(actor,'audit.read'),
    'export',app_private.audit_authorization_scope(actor,'audit.export')
  );
  request_hash:=extensions.digest(convert_to(jsonb_build_object('format',p_format,'filters',p_filters)::text,'UTF8'),'sha256');
  perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key::text,0));
  select * into job from public.import_jobs where request_id=p_idempotency_key;
  if job.id is not null then
    if job.created_by<>actor or job.request_hash<>request_hash or job.target_domain<>'audit_export' then
      raise invalid_parameter_value using message='idempotency key replay mismatch';
    end if;
    if job.processing_state='SUCESSO'
      and app_private.audit_get_export_job_for_superadmin(job.id) is null then
      raise insufficient_privilege using message='audit export unavailable';
    end if;
    return jsonb_build_object('job_id',job.id,'state',job.processing_state,'format',job.source_format,'created_at',job.created_at);
  end if;
  perform pg_advisory_xact_lock(hashtextextended(actor::text||':audit_export',0));
  if (select count(*) from public.import_jobs where created_by=actor
      and target_domain='audit_export' and created_at>now()-interval '1 hour')>=5 then
    raise program_limit_exceeded using message='audit export rate limit exceeded';
  end if;
  insert into public.import_jobs(request_id,request_hash,target_domain,target_table,source_format,
    source_locale,target_locale,status,processing_state,summary,created_by)
  values(p_idempotency_key,request_hash,'audit_export','audit_logs',p_format,'pt-BR','pt-BR',
    'draft','PENDENTE',jsonb_build_object('phase','queued','filters',p_filters,
      'storage_bucket','coelo-operations','retention_expires_at',now()+interval '24 hours',
      'authorization_snapshot',v_authorization,'formula_neutralization',true,'pii_included',true),actor)
  returning * into job;
  insert into public.import_results(import_job_id) values(job.id);
  insert into audit.audit_logs(actor_person_id,actor_role_code,mfa_aal,action_code,object_type,
    object_id,outcome,origin,context_kind,payload_contract_version,after_json)
  values(actor,null,'aal2','audit.export.request','import_job',job.id,'success','admin_ui','global',1,
    jsonb_build_object('format',p_format,'state','PENDENTE','pii_included',true));
  result:=jsonb_build_object('job_id',job.id,'state',job.processing_state,'format',job.source_format,'created_at',job.created_at);
  return result;
end;
$$;

create or replace function app_private.audit_spreadsheet_cell(p_value text)
returns text
language sql
immutable
security invoker
set search_path=''
as $$
  select case when p_value~'^[=+@-]' or p_value~'^[\t\r]' then ''''||p_value else p_value end
$$;

create or replace function app_private.audit_assert_worker()
returns void
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if coalesce((select auth.jwt()->>'role'),
      nullif(current_setting('request.jwt.claim.role',true),''),
      nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'role','') <> 'service_role' then
    raise insufficient_privilege using message='audit worker authorization required';
  end if;
end;
$$;

create table app_private.audit_export_snapshot_rows(
  export_job_id uuid not null references public.import_jobs(id) on delete cascade,
  ordinal bigint not null check(ordinal>0),
  audit_log_id uuid not null references audit.audit_logs(id) on delete restrict,
  row_payload jsonb not null,
  created_at timestamptz not null default now(),
  primary key(export_job_id,ordinal),
  unique(export_job_id,audit_log_id)
);
create index audit_export_snapshot_rows_job_ordinal_idx
  on app_private.audit_export_snapshot_rows(export_job_id,ordinal);
revoke all on app_private.audit_export_snapshot_rows from public,anon,authenticated,service_role;

create table app_private.audit_export_worker_claims(
  export_job_id uuid primary key references public.import_jobs(id) on delete cascade,
  worker_token uuid not null unique,
  lease_until timestamptz not null,
  claimed_at timestamptz not null default now()
);
revoke all on app_private.audit_export_worker_claims from public,anon,authenticated,service_role;

create or replace function app_private.audit_materialize_export_for_worker(
  p_export_job_id uuid,p_worker_token uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare job public.import_jobs%rowtype;filters jsonb;row_count integer;
  read_authorization jsonb;export_authorization jsonb;claim app_private.audit_export_worker_claims%rowtype;
begin
  perform app_private.audit_assert_worker();
  if p_worker_token is null then
    raise invalid_parameter_value using message='invalid audit export worker claim';
  end if;
  select * into job from public.import_jobs where id=p_export_job_id for update;
  if job.id is null or job.target_domain<>'audit_export' then
    raise insufficient_privilege using message='audit export job unavailable';
  end if;
  read_authorization:=app_private.audit_authorization_scope(job.created_by,'audit.read');
  export_authorization:=app_private.audit_authorization_scope(job.created_by,'audit.export');
  if (not coalesce((read_authorization->>'global')::boolean,false)
      and jsonb_array_length(coalesce(read_authorization->'institution_ids','[]'::jsonb))=0)
    or (not coalesce((export_authorization->>'global')::boolean,false)
      and jsonb_array_length(coalesce(export_authorization->'institution_ids','[]'::jsonb))=0) then
    raise insufficient_privilege using message='audit export authorization revoked';
  end if;
  if exists(
    select 1 from app_private.audit_export_snapshot_rows snapshot
    join audit.audit_logs log_record on log_record.id=snapshot.audit_log_id
    where snapshot.export_job_id=job.id
      and (not app_private.audit_actor_has_permission(job.created_by,'audit.read',log_record.institution_id,false)
        or not app_private.audit_actor_has_permission(job.created_by,'audit.export',log_record.institution_id,false))
  ) then
    raise insufficient_privilege using message='audit export authorization revoked';
  end if;
  if job.processing_state='SUCESSO' then
    return jsonb_build_object('job_id',job.id,'row_count',job.summary->'row_count','state','SUCESSO','claimed',false);
  end if;
  if job.processing_state in('ERRO','REJEICAO') then
    raise object_not_in_prerequisite_state using message='audit export job is terminal';
  end if;
  filters:=coalesce(job.summary->'filters','{}'::jsonb);
  select * into claim from app_private.audit_export_worker_claims where export_job_id=job.id for update;
  if job.processing_state='PROCESSANDO' and claim.lease_until>now()
    and claim.worker_token<>p_worker_token then
    return jsonb_build_object('job_id',job.id,'state','PROCESSANDO','claimed',false);
  end if;
  insert into app_private.audit_export_worker_claims(export_job_id,worker_token,lease_until,claimed_at)
  values(job.id,p_worker_token,now()+interval '15 minutes',now())
  on conflict(export_job_id) do update set worker_token=excluded.worker_token,
    lease_until=excluded.lease_until,claimed_at=excluded.claimed_at;
  delete from app_private.audit_export_snapshot_rows where export_job_id=job.id;
  insert into app_private.audit_export_snapshot_rows(export_job_id,ordinal,audit_log_id,row_payload)
  select job.id,row_number() over(order by log_record.occurred_at desc,log_record.id desc),log_record.id,
    jsonb_build_object(
      'id',log_record.id,'occurred_at',log_record.occurred_at,
      'actor_name',person.display_name,'actor_role_code',log_record.actor_role_code,
      'institution_name',institution.public_name,'action_code',log_record.action_code,
       'resource_type',log_record.object_type,'resource_id',log_record.object_id,
      'outcome',case log_record.outcome::text when 'failed' then 'failure' else log_record.outcome::text end,
      'correlation_id',log_record.correlation_id,'origin',log_record.origin,
      'context_kind',log_record.context_kind,'context_id',log_record.context_id
    )
  from audit.audit_logs log_record
  left join public.people person on person.id=log_record.actor_person_id
  left join public.institutions institution on institution.id=log_record.institution_id
  where (((read_authorization->>'global')::boolean
        and (log_record.institution_id is null or not((read_authorization->'denied_institution_ids')?log_record.institution_id::text)))
      or (log_record.institution_id is not null and (read_authorization->'institution_ids')?log_record.institution_id::text))
    and (((export_authorization->>'global')::boolean
        and (log_record.institution_id is null or not((export_authorization->'denied_institution_ids')?log_record.institution_id::text)))
      or (log_record.institution_id is not null and (export_authorization->'institution_ids')?log_record.institution_id::text))
    and (not(filters?'institution_id') or log_record.institution_id=(filters->>'institution_id')::uuid)
    and (not(filters?'actor_ids') or jsonb_array_length(filters->'actor_ids')=0 or (filters->'actor_ids')?log_record.actor_person_id::text)
    and (not(filters?'context_kinds') or jsonb_array_length(filters->'context_kinds')=0 or (filters->'context_kinds')?log_record.context_kind)
    and (not(filters?'action_codes') or jsonb_array_length(filters->'action_codes')=0 or (filters->'action_codes')?log_record.action_code)
    and (not(filters?'resource_types') or jsonb_array_length(filters->'resource_types')=0 or (filters->'resource_types')?log_record.object_type)
    and (not(filters?'outcomes') or jsonb_array_length(filters->'outcomes')=0 or
      (filters->'outcomes')?(case log_record.outcome::text when 'failed' then 'failure' else log_record.outcome::text end))
    and (not(filters?'origins') or jsonb_array_length(filters->'origins')=0 or (filters->'origins')?log_record.origin)
    and (not(filters?'from') or log_record.occurred_at>=(filters->>'from')::timestamptz)
    and (not(filters?'to') or log_record.occurred_at<=(filters->>'to')::timestamptz)
    and (nullif(btrim(filters->>'search'),'') is null or position(lower(btrim(filters->>'search')) in lower(concat_ws(' ',
      log_record.action_code,log_record.object_type,log_record.object_id::text,
      log_record.correlation_id::text,person.display_name,institution.public_name)))>0)
  order by log_record.occurred_at desc,log_record.id desc
  limit 50001;
  get diagnostics row_count=row_count;
  if row_count>50000 then
    raise program_limit_exceeded using message='audit export exceeds maximum row count';
  end if;
  update public.import_jobs set processing_state='PROCESSANDO',status='active',
    started_at=coalesce(started_at,now()),updated_at=now(),
    summary=summary||jsonb_build_object('phase','materialized','row_count',row_count,
      'authorization_revalidated_at',now())
  where id=job.id;
  return jsonb_build_object('job_id',job.id,'row_count',row_count,'state','PROCESSANDO','claimed',true);
end;
$$;

create or replace function app_private.audit_export_page_for_worker(
  p_export_job_id uuid,p_worker_token uuid,p_after_ordinal bigint default null,p_page_size integer default 500
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare items jsonb;last_ordinal bigint;has_more boolean;
begin
  perform app_private.audit_assert_worker();
  if p_page_size not between 1 and 500 or coalesce(p_after_ordinal,0)<0
    or not exists(select 1 from public.import_jobs where id=p_export_job_id and target_domain='audit_export') then
    raise invalid_parameter_value using message='invalid audit export page';
  end if;
  if not exists(select 1 from app_private.audit_export_worker_claims
      where export_job_id=p_export_job_id and worker_token=p_worker_token and lease_until>now()) then
    raise insufficient_privilege using message='audit export worker claim unavailable';
  end if;
  with page as (
    select ordinal,row_payload from app_private.audit_export_snapshot_rows
    where export_job_id=p_export_job_id and ordinal>coalesce(p_after_ordinal,0)
    order by ordinal limit p_page_size
  ) select coalesce(jsonb_agg(row_payload order by ordinal),'[]'::jsonb),max(ordinal)
    into items,last_ordinal from page;
  has_more:=last_ordinal is not null and exists(select 1 from app_private.audit_export_snapshot_rows
    where export_job_id=p_export_job_id and ordinal>last_ordinal);
  return jsonb_build_object('items',items,'has_more',has_more,'next_cursor',
    case when has_more then jsonb_build_object('ordinal',last_ordinal) else null end);
end;
$$;

create or replace function app_private.audit_complete_export_for_worker(
  p_export_job_id uuid,p_worker_token uuid,p_storage_path text,p_file_name text,p_mime_type text,
  p_size_bytes bigint,p_checksum_sha256 text,p_row_count integer
)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare job public.import_jobs%rowtype;expected_mime text;
  read_authorization jsonb;export_authorization jsonb;
begin
  perform app_private.audit_assert_worker();
  select * into job from public.import_jobs where id=p_export_job_id for update;
  expected_mime:=case job.source_format when 'csv' then 'text/csv'
    else 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' end;
  if job.id is null or job.target_domain<>'audit_export' or job.processing_state<>'PROCESSANDO'
    or not exists(select 1 from app_private.audit_export_worker_claims
      where export_job_id=job.id and worker_token=p_worker_token and lease_until>now())
    or p_storage_path !~ ('^exports/audit/'||job.id||'/[0-9a-f-]+\.'||job.source_format||'$')
    or p_mime_type<>expected_mime or p_size_bytes not between 1 and 5242880
    or p_checksum_sha256 !~ '^[0-9a-f]{64}$' or p_row_count<1
    or p_row_count<>(select count(*) from app_private.audit_export_snapshot_rows where export_job_id=job.id)
    or not exists(select 1 from storage.objects object_record
      where object_record.bucket_id='coelo-operations' and object_record.name=p_storage_path) then
    raise invalid_parameter_value using message='invalid audit export artifact';
  end if;
  read_authorization:=app_private.audit_authorization_scope(job.created_by,'audit.read');
  export_authorization:=app_private.audit_authorization_scope(job.created_by,'audit.export');
  if (not coalesce((read_authorization->>'global')::boolean,false)
      and jsonb_array_length(coalesce(read_authorization->'institution_ids','[]'::jsonb))=0)
    or (not coalesce((export_authorization->>'global')::boolean,false)
      and jsonb_array_length(coalesce(export_authorization->'institution_ids','[]'::jsonb))=0)
    or exists(
      select 1 from app_private.audit_export_snapshot_rows snapshot
      join audit.audit_logs log_record on log_record.id=snapshot.audit_log_id
      where snapshot.export_job_id=job.id
        and (not app_private.audit_actor_has_permission(job.created_by,'audit.read',log_record.institution_id,false)
          or not app_private.audit_actor_has_permission(job.created_by,'audit.export',log_record.institution_id,false))
    ) then
    raise insufficient_privilege using message='audit export authorization revoked';
  end if;
  insert into public.import_files(import_job_id,storage_path,file_name,mime_type,size_bytes,
    checksum_sha256,expires_at)
  values(job.id,p_storage_path,left(p_file_name,180),p_mime_type,p_size_bytes,
    p_checksum_sha256,now()+interval '24 hours');
  update public.import_results set completed_at=now() where import_job_id=job.id;
  update public.import_jobs set processing_state='SUCESSO',status='active',finished_at=now(),updated_at=now(),
    summary=summary||jsonb_build_object('phase','complete','storage_path',p_storage_path,
      'row_count',p_row_count,'retention_expires_at',now()+interval '24 hours') where id=job.id;
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,
    origin,context_kind,payload_contract_version,after_json)
  values(job.created_by,'aal2','audit.export.complete','import_job',job.id,'success','edge_function','global',1,
    jsonb_build_object('format',job.source_format,'state','SUCESSO','row_count',p_row_count,'pii_included',true));
  return jsonb_build_object('job_id',job.id,'state','SUCESSO','format',job.source_format,
    'row_count',p_row_count);
end;
$$;

create or replace function app_private.audit_fail_export_for_worker(
  p_export_job_id uuid,p_worker_token uuid,p_error_code text
)
returns void
language plpgsql
volatile
security definer
set search_path=''
as $$
declare job public.import_jobs%rowtype;
begin
  perform app_private.audit_assert_worker();
  select * into job from public.import_jobs where id=p_export_job_id for update;
  if job.id is null or job.target_domain<>'audit_export' or p_error_code!~'^[a-z0-9_]{1,80}$' then
    raise invalid_parameter_value using message='invalid audit export failure';
  end if;
  if job.processing_state in('SUCESSO','REJEICAO','ERRO') then return; end if;
  if job.processing_state<>'PROCESSANDO' or not exists(
    select 1 from app_private.audit_export_worker_claims
    where export_job_id=job.id and worker_token=p_worker_token
  ) then
    raise insufficient_privilege using message='audit export worker claim unavailable';
  end if;
  update public.import_jobs set processing_state='ERRO',status='draft',finished_at=now(),updated_at=now(),
    summary=summary||jsonb_build_object('phase','failed','error_code',p_error_code) where id=job.id;
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,
    origin,context_kind,payload_contract_version,after_json)
  values(job.created_by,'aal2','audit.export.failed','import_job',job.id,'failed','edge_function','global',1,
    jsonb_build_object('state','ERRO'));
end;
$$;

create or replace function app_private.audit_get_export_job_for_superadmin(p_export_job_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid;job public.import_jobs%rowtype;
begin
  actor:=app_private.audit_assert_permission('audit.export',true);
  perform app_private.audit_assert_permission('audit.read',false);
  select * into job from public.import_jobs where id=p_export_job_id and target_domain='audit_export' and created_by=actor;
  if job.id is null then return null; end if;
  if exists(
    select 1 from app_private.audit_export_snapshot_rows snapshot
    join audit.audit_logs log_record on log_record.id=snapshot.audit_log_id
    where snapshot.export_job_id=job.id
      and (not app_private.audit_actor_has_permission(actor,'audit.read',log_record.institution_id,false)
        or not app_private.audit_actor_has_permission(actor,'audit.export',log_record.institution_id,false))
  ) then return null; end if;
  return jsonb_build_object('job_id',job.id,'state',job.processing_state,'format',job.source_format,
    'created_at',job.created_at,'summary',jsonb_strip_nulls(jsonb_build_object(
      'phase',job.summary->>'phase','row_count',job.summary->'row_count',
      'retention_expires_at',job.summary->'retention_expires_at')),
    'error_code',job.summary->>'error_code');
end $$;

create or replace function app_private.audit_authorize_export_download_for_superadmin(
  p_export_job_id uuid
)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid;job public.import_jobs%rowtype;authorized_job jsonb;expires_at timestamptz;
begin
  actor:=app_private.audit_assert_permission('audit.export',true);
  perform app_private.audit_assert_permission('audit.read',false);
  authorized_job:=app_private.audit_get_export_job_for_superadmin(p_export_job_id);
  if authorized_job is null then return null; end if;
  select * into job from public.import_jobs where id=p_export_job_id
    and target_domain='audit_export' and created_by=actor and processing_state='SUCESSO';
  if job.id is null then return null; end if;
  begin
    expires_at:=(job.summary->>'retention_expires_at')::timestamptz;
  exception when others then return null;
  end;
  if expires_at is null or expires_at<=now() or nullif(job.summary->>'storage_path','') is null then
    return null;
  end if;
  return jsonb_build_object('job_id',job.id,'storage_path',job.summary->>'storage_path',
    'format',job.source_format,'row_count',job.summary->'row_count','retention_expires_at',expires_at);
end;
$$;

create or replace function app_private.audit_export_artifact_for_worker(p_export_job_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  perform app_private.audit_assert_worker();
  select jsonb_build_object('storage_path',job.summary->>'storage_path','format',job.source_format,
      'retention_expires_at',job.summary->'retention_expires_at','row_count',job.summary->'row_count')
    into result from public.import_jobs job where job.id=p_export_job_id
      and job.target_domain='audit_export' and job.processing_state='SUCESSO';
  return result;
end;
$$;

create or replace function app_private.audit_expired_artifacts_for_worker(p_limit integer default 10)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  perform app_private.audit_assert_worker();
  if p_limit not between 1 and 25 then
    raise invalid_parameter_value using message='invalid audit cleanup limit';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('job_id',job.id,
      'storage_path',job.summary->>'storage_path') order by job.finished_at),'[]'::jsonb)
    into result
  from (select * from public.import_jobs candidate
    where candidate.target_domain='audit_export' and candidate.processing_state='SUCESSO'
      and (candidate.summary->>'retention_expires_at')::timestamptz<=now()
      and nullif(candidate.summary->>'storage_path','') is not null
    order by candidate.finished_at limit p_limit) job;
  return result;
end;
$$;

create or replace function app_private.audit_expire_export_for_worker(
  p_export_job_id uuid,p_storage_path text
)
returns void language plpgsql volatile security definer set search_path='' as $$
declare job public.import_jobs%rowtype;
begin
  perform app_private.audit_assert_worker();
  select * into job from public.import_jobs where id=p_export_job_id for update;
  if job.id is null or job.target_domain<>'audit_export'
    or job.processing_state<>'SUCESSO'
    or job.summary->>'storage_path' is distinct from p_storage_path
    or (job.summary->>'retention_expires_at')::timestamptz>now()
    or exists(select 1 from storage.objects where bucket_id='coelo-operations' and name=p_storage_path) then
    raise invalid_parameter_value using message='audit export cannot be expired';
  end if;
  -- Deleting the job is the canonical EXPIRADO/not-found state. Cascades erase
  -- import_files, the materialized PII snapshot and the worker claim together.
  delete from public.import_jobs where id=job.id;
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,
    outcome,origin,context_kind,payload_contract_version,after_json)
  values(job.created_by,'aal2','audit.export.expired','import_job',job.id,'success',
    'edge_function','global',1,jsonb_build_object('state','EXPIRADO'));
end;
$$;

create or replace function public.audit_list_events_for_superadmin(
  p_search text default null,p_actor_ids uuid[] default null,p_context_kinds text[] default null,
  p_action_codes text[] default null,p_resource_types text[] default null,
  p_outcomes text[] default null,p_origins text[] default null,p_institution_id uuid default null,
  p_from timestamptz default null,p_to timestamptz default null,
  p_cursor_occurred_at timestamptz default null,p_cursor_id uuid default null,p_limit integer default 25
)
returns jsonb language sql stable security definer set search_path=''
as $$select app_private.audit_list_events_for_superadmin($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)$$;

create or replace function public.audit_get_event_for_superadmin(p_event_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$select app_private.audit_get_event_for_superadmin($1)$$;

create or replace function public.audit_start_export_for_superadmin(
  p_format text,p_filters jsonb,p_idempotency_key uuid
)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.audit_start_export_for_superadmin($1,$2,$3)$$;

create or replace function public.audit_get_export_job_for_superadmin(p_export_job_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$select app_private.audit_get_export_job_for_superadmin($1)$$;
create or replace function public.audit_authorize_export_download_for_superadmin(p_export_job_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$select app_private.audit_authorize_export_download_for_superadmin($1)$$;

create or replace function public.audit_materialize_export_for_worker(p_export_job_id uuid,p_worker_token uuid)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.audit_materialize_export_for_worker($1,$2)$$;
create or replace function public.audit_export_page_for_worker(
  p_export_job_id uuid,p_worker_token uuid,p_after_ordinal bigint default null,p_page_size integer default 500
) returns jsonb language sql stable security definer set search_path=''
as $$select app_private.audit_export_page_for_worker($1,$2,$3,$4)$$;
create or replace function public.audit_complete_export_for_worker(
  p_export_job_id uuid,p_worker_token uuid,p_storage_path text,p_file_name text,p_mime_type text,
  p_size_bytes bigint,p_checksum_sha256 text,p_row_count integer
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.audit_complete_export_for_worker($1,$2,$3,$4,$5,$6,$7,$8)$$;
create or replace function public.audit_fail_export_for_worker(p_export_job_id uuid,p_worker_token uuid,p_error_code text)
returns void language sql volatile security definer set search_path=''
as $$select app_private.audit_fail_export_for_worker($1,$2,$3)$$;
create or replace function public.audit_export_artifact_for_worker(p_export_job_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$select app_private.audit_export_artifact_for_worker($1)$$;
create or replace function public.audit_expired_artifacts_for_worker(p_limit integer default 10)
returns jsonb language sql stable security definer set search_path=''
as $$select app_private.audit_expired_artifacts_for_worker($1)$$;
create or replace function public.audit_expire_export_for_worker(p_export_job_id uuid,p_storage_path text)
returns void language sql volatile security definer set search_path=''
as $$select app_private.audit_expire_export_for_worker($1,$2)$$;

revoke all on function public.audit_list_events_for_superadmin(text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer)
  from public,anon,authenticated,service_role;
revoke all on function public.audit_get_event_for_superadmin(uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.audit_start_export_for_superadmin(text,jsonb,uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.audit_get_export_job_for_superadmin(uuid) from public,anon,authenticated,service_role;
revoke all on function public.audit_authorize_export_download_for_superadmin(uuid) from public,anon,authenticated,service_role;
revoke all on function public.audit_materialize_export_for_worker(uuid,uuid) from public,anon,authenticated,service_role;
revoke all on function public.audit_export_page_for_worker(uuid,uuid,bigint,integer) from public,anon,authenticated,service_role;
revoke all on function public.audit_complete_export_for_worker(uuid,uuid,text,text,text,bigint,text,integer) from public,anon,authenticated,service_role;
revoke all on function public.audit_fail_export_for_worker(uuid,uuid,text) from public,anon,authenticated,service_role;
revoke all on function public.audit_export_artifact_for_worker(uuid) from public,anon,authenticated,service_role;
revoke all on function public.audit_expired_artifacts_for_worker(integer) from public,anon,authenticated,service_role;
revoke all on function public.audit_expire_export_for_worker(uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.audit_list_events_for_superadmin(text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer)
  to authenticated;
grant execute on function public.audit_get_event_for_superadmin(uuid) to authenticated;
grant execute on function public.audit_start_export_for_superadmin(text,jsonb,uuid) to authenticated;
grant execute on function public.audit_get_export_job_for_superadmin(uuid) to authenticated;
grant execute on function public.audit_authorize_export_download_for_superadmin(uuid) to authenticated;
grant execute on function public.audit_materialize_export_for_worker(uuid,uuid) to service_role;
grant execute on function public.audit_export_page_for_worker(uuid,uuid,bigint,integer) to service_role;
grant execute on function public.audit_complete_export_for_worker(uuid,uuid,text,text,text,bigint,text,integer) to service_role;
grant execute on function public.audit_fail_export_for_worker(uuid,uuid,text) to service_role;
grant execute on function public.audit_export_artifact_for_worker(uuid) to service_role;
grant execute on function public.audit_expired_artifacts_for_worker(integer) to service_role;
grant execute on function public.audit_expire_export_for_worker(uuid,text) to service_role;

revoke all on function app_private.audit_mask_payload(jsonb) from public,anon,authenticated;
revoke all on function app_private.audit_minimize_payload(text,jsonb) from public,anon,authenticated;
revoke all on function app_private.audit_mask_reason(text) from public,anon,authenticated;
revoke all on function app_private.audit_entry_digest(bigint,bytea,uuid,uuid,text,uuid,text,text,uuid,text,text,uuid,uuid,public.audit_outcome,text,jsonb,jsonb,timestamptz) from public,anon,authenticated;
revoke all on function app_private.audit_guard_append_only() from public,anon,authenticated;
revoke all on function app_private.audit_has_permission(text,uuid,boolean) from public,anon,authenticated;
revoke all on function app_private.audit_actor_has_permission(uuid,text,uuid,boolean) from public,anon,authenticated;
revoke all on function app_private.audit_authorization_scope(uuid,text) from public,anon,authenticated;
revoke all on function app_private.audit_assert_permission(text,boolean) from public,anon,authenticated;
revoke all on function app_private.audit_validate_list_filters(text,uuid[],text[],text[],text[],text[],text[],timestamptz,timestamptz,timestamptz,uuid,integer) from public,anon,authenticated;
revoke all on function app_private.audit_list_events_for_superadmin(text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer) from public,anon,authenticated;
revoke all on function app_private.audit_get_event_for_superadmin(uuid) from public,anon,authenticated;
revoke all on function app_private.audit_validate_export_filters(jsonb) from public,anon,authenticated;
revoke all on function app_private.audit_start_export_for_superadmin(text,jsonb,uuid) from public,anon,authenticated;
revoke all on function app_private.audit_spreadsheet_cell(text) from public,anon,authenticated;
revoke all on function app_private.audit_assert_worker() from public,anon,authenticated,service_role;
revoke all on function app_private.audit_materialize_export_for_worker(uuid,uuid) from public,anon,authenticated,service_role;
revoke all on function app_private.audit_export_page_for_worker(uuid,uuid,bigint,integer) from public,anon,authenticated,service_role;
revoke all on function app_private.audit_complete_export_for_worker(uuid,uuid,text,text,text,bigint,text,integer) from public,anon,authenticated,service_role;
revoke all on function app_private.audit_fail_export_for_worker(uuid,uuid,text) from public,anon,authenticated,service_role;
revoke all on function app_private.audit_get_export_job_for_superadmin(uuid) from public,anon,authenticated,service_role;
revoke all on function app_private.audit_authorize_export_download_for_superadmin(uuid) from public,anon,authenticated,service_role;
revoke all on function app_private.audit_export_artifact_for_worker(uuid) from public,anon,authenticated,service_role;
revoke all on function app_private.audit_expired_artifacts_for_worker(integer) from public,anon,authenticated,service_role;
revoke all on function app_private.audit_expire_export_for_worker(uuid,text) from public,anon,authenticated,service_role;
grant execute on function app_private.audit_spreadsheet_cell(text) to service_role;

commit;
