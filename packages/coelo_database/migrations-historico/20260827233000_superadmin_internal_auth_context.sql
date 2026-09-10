begin;

do $preflight$
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using message='superadmin internal auth migration must run as postgres';
  end if;
end
$preflight$;

create type app_private.superadmin_internal_auth_link_status
  as enum ('active','suspended','revoked');
create type app_private.superadmin_internal_membership_status
  as enum ('active','suspended','revoked');
create type app_private.superadmin_internal_scope_kind
  as enum ('platform','institution');

create table app_private.superadmin_internal_identities(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  created_by_internal_identity_id uuid references app_private.superadmin_internal_identities(id)
);

create index superadmin_internal_identities_created_by_idx
  on app_private.superadmin_internal_identities(created_by_internal_identity_id)
  where created_by_internal_identity_id is not null;

create table app_private.superadmin_internal_auth_links(
  id uuid primary key default gen_random_uuid(),
  internal_identity_id uuid not null references app_private.superadmin_internal_identities(id),
  auth_user_id uuid not null unique references auth.users(id),
  status app_private.superadmin_internal_auth_link_status not null default 'active',
  created_at timestamptz not null default now(),
  suspended_at timestamptz,
  revoked_at timestamptz,
  changed_by_internal_identity_id uuid references app_private.superadmin_internal_identities(id),
  version bigint not null default 1 check(version>0),
  constraint superadmin_internal_auth_links_lifecycle_check check(
    (status='active' and suspended_at is null and revoked_at is null) or
    (status='suspended' and suspended_at is not null and revoked_at is null) or
    (status='revoked' and revoked_at is not null)
  )
);

create unique index superadmin_internal_auth_links_active_identity_uidx
  on app_private.superadmin_internal_auth_links(internal_identity_id)
  where status='active';
create index superadmin_internal_auth_links_identity_status_idx
  on app_private.superadmin_internal_auth_links(internal_identity_id,status);
create index superadmin_internal_auth_links_changed_by_idx
  on app_private.superadmin_internal_auth_links(changed_by_internal_identity_id)
  where changed_by_internal_identity_id is not null;

create table app_private.superadmin_internal_memberships(
  id uuid primary key default gen_random_uuid(),
  internal_identity_id uuid not null references app_private.superadmin_internal_identities(id),
  platform_role_id uuid not null references public.platform_roles(id),
  scope_kind app_private.superadmin_internal_scope_kind not null,
  scope_institution_id uuid references public.institutions(id),
  status app_private.superadmin_internal_membership_status not null default 'active',
  created_at timestamptz not null default now(),
  suspended_at timestamptz,
  revoked_at timestamptz,
  changed_by_internal_identity_id uuid references app_private.superadmin_internal_identities(id),
  version bigint not null default 1 check(version>0),
  constraint superadmin_internal_memberships_scope_check check(
    (scope_kind='platform' and scope_institution_id is null) or
    (scope_kind='institution' and scope_institution_id is not null)
  ),
  constraint superadmin_internal_memberships_lifecycle_check check(
    (status='active' and suspended_at is null and revoked_at is null) or
    (status='suspended' and suspended_at is not null and revoked_at is null) or
    (status='revoked' and revoked_at is not null)
  )
);

create unique index superadmin_internal_memberships_active_identity_uidx
  on app_private.superadmin_internal_memberships(internal_identity_id)
  where status='active';
create index superadmin_internal_memberships_identity_status_idx
  on app_private.superadmin_internal_memberships(internal_identity_id,status);
create index superadmin_internal_memberships_scope_idx
  on app_private.superadmin_internal_memberships(scope_kind,scope_institution_id,status);
create index superadmin_internal_memberships_institution_idx
  on app_private.superadmin_internal_memberships(scope_institution_id)
  where scope_institution_id is not null;
create index superadmin_internal_memberships_role_idx
  on app_private.superadmin_internal_memberships(platform_role_id);
create index superadmin_internal_memberships_changed_by_idx
  on app_private.superadmin_internal_memberships(changed_by_internal_identity_id)
  where changed_by_internal_identity_id is not null;

alter table app_private.superadmin_internal_identities enable row level security;
alter table app_private.superadmin_internal_identities force row level security;
alter table app_private.superadmin_internal_auth_links enable row level security;
alter table app_private.superadmin_internal_auth_links force row level security;
alter table app_private.superadmin_internal_memberships enable row level security;
alter table app_private.superadmin_internal_memberships force row level security;

revoke all on app_private.superadmin_internal_identities from public,anon,authenticated,service_role;
revoke all on app_private.superadmin_internal_auth_links from public,anon,authenticated,service_role;
revoke all on app_private.superadmin_internal_memberships from public,anon,authenticated,service_role;
revoke usage on type app_private.superadmin_internal_auth_link_status from public,anon,authenticated,service_role;
revoke usage on type app_private.superadmin_internal_membership_status from public,anon,authenticated,service_role;
revoke usage on type app_private.superadmin_internal_scope_kind from public,anon,authenticated,service_role;

do $preflight$
begin
  if exists(
    select 1 from public.person_auth_links global_link
    join app_private.superadmin_internal_auth_links internal_link
      on internal_link.auth_user_id=global_link.auth_user_id
  ) then
    raise exception using errcode='23505',message='auth realm intersection exists';
  end if;
end
$preflight$;

create function app_private.guard_superadmin_internal_auth_realm()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('coelo.auth.realm:'||new.auth_user_id::text,0));
  if exists(select 1 from public.person_auth_links where auth_user_id=new.auth_user_id) then
    raise unique_violation using message='auth user already belongs to another realm';
  end if;
  return new;
end
$$;

create function app_private.guard_person_auth_link_internal_realm()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('coelo.auth.realm:'||new.auth_user_id::text,0));
  if exists(select 1 from app_private.superadmin_internal_auth_links where auth_user_id=new.auth_user_id) then
    raise unique_violation using message='auth user already belongs to another realm';
  end if;
  return new;
end
$$;

create trigger superadmin_internal_auth_links_realm_guard
before insert or update of auth_user_id on app_private.superadmin_internal_auth_links
for each row execute function app_private.guard_superadmin_internal_auth_realm();
create trigger person_auth_links_internal_realm_guard
before insert or update of auth_user_id on public.person_auth_links
for each row execute function app_private.guard_person_auth_link_internal_realm();

revoke all on function app_private.guard_superadmin_internal_auth_realm()
  from public,anon,authenticated,service_role;
revoke all on function app_private.guard_person_auth_link_internal_realm()
  from public,anon,authenticated,service_role;

create function app_private.guard_superadmin_internal_auth_link_lifecycle()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='DELETE' then
    raise object_not_in_prerequisite_state using message='internal auth link history is append-only';
  end if;
  if new.id is distinct from old.id or new.created_at is distinct from old.created_at
    or new.internal_identity_id is distinct from old.internal_identity_id
    or new.auth_user_id is distinct from old.auth_user_id then
    raise object_not_in_prerequisite_state using message='internal auth link identity is immutable';
  end if;
  if old.status='revoked' and new is distinct from old then
    raise object_not_in_prerequisite_state using message='revoked internal access is terminal';
  end if;
  if new is distinct from old and new.version<>old.version+1 then
    raise serialization_failure using message='internal auth link version mismatch';
  end if;
  return new;
end
$$;

create function app_private.guard_superadmin_internal_membership_lifecycle()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='DELETE' then
    raise object_not_in_prerequisite_state using message='internal membership history is append-only';
  end if;
  if new.id is distinct from old.id or new.created_at is distinct from old.created_at
    or new.internal_identity_id is distinct from old.internal_identity_id then
    raise object_not_in_prerequisite_state using message='internal membership identity is immutable';
  end if;
  if old.status='revoked' and new is distinct from old then
    raise object_not_in_prerequisite_state using message='revoked internal access is terminal';
  end if;
  if new is distinct from old and new.version<>old.version+1 then
    raise serialization_failure using message='internal membership version mismatch';
  end if;
  return new;
end
$$;

create trigger superadmin_internal_auth_links_lifecycle_guard
before update or delete on app_private.superadmin_internal_auth_links
for each row execute function app_private.guard_superadmin_internal_auth_link_lifecycle();
create trigger superadmin_internal_memberships_lifecycle_guard
before update or delete on app_private.superadmin_internal_memberships
for each row execute function app_private.guard_superadmin_internal_membership_lifecycle();

create function app_private.guard_superadmin_internal_membership_scope()
returns trigger language plpgsql security definer set search_path='' as $$
declare maximum_scope text;
begin
  select role_record.max_scope_kind into maximum_scope
  from public.platform_roles role_record where role_record.id=new.platform_role_id;
  if maximum_scope is null
    or app_private.access_scope_rank(new.scope_kind::text)>
       app_private.access_scope_rank(maximum_scope) then
    raise check_violation using message='internal membership scope exceeds role maximum';
  end if;
  return new;
end
$$;

create trigger superadmin_internal_memberships_scope_guard
before insert or update of platform_role_id,scope_kind,scope_institution_id
on app_private.superadmin_internal_memberships
for each row execute function app_private.guard_superadmin_internal_membership_scope();

create function app_private.guard_superadmin_internal_last_owner()
returns trigger language plpgsql security definer set search_path='' as $$
declare old_is_owner boolean; new_is_owner boolean:=false;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('coelo.superadmin.last-owner',0));
  select role_record.code='owner' and old.scope_kind='platform' and old.status='active'
    into old_is_owner from public.platform_roles role_record
    where role_record.id=old.platform_role_id;
  if tg_op='UPDATE' then
    select role_record.code='owner' and new.scope_kind='platform' and new.status='active'
      into new_is_owner from public.platform_roles role_record
      where role_record.id=new.platform_role_id;
  end if;
  if coalesce(old_is_owner,false) and not coalesce(new_is_owner,false)
    and not exists(
      select 1 from app_private.superadmin_internal_memberships membership
      join public.platform_roles role_record on role_record.id=membership.platform_role_id
      join app_private.superadmin_internal_auth_links auth_link
        on auth_link.internal_identity_id=membership.internal_identity_id
       and auth_link.status='active'
      where membership.id<>old.id and membership.status='active'
        and membership.scope_kind='platform' and role_record.code='owner'
        and role_record.status='active') then
    raise object_not_in_prerequisite_state using
      message='last active platform owner is protected',detail='SAI_LAST_OWNER_PROTECTED';
  end if;
  return case when tg_op='DELETE' then old else new end;
end
$$;

create function app_private.guard_superadmin_internal_owner_auth_link()
returns trigger language plpgsql security definer set search_path='' as $$
declare removes_owner_access boolean;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('coelo.superadmin.last-owner',0));
  removes_owner_access:=old.status='active' and
    (tg_op='DELETE' or new.status<>'active' or
      new.internal_identity_id is distinct from old.internal_identity_id or
      new.auth_user_id is distinct from old.auth_user_id);
  if removes_owner_access and exists(
      select 1 from app_private.superadmin_internal_memberships membership
      join public.platform_roles role_record on role_record.id=membership.platform_role_id
      where membership.internal_identity_id=old.internal_identity_id
        and membership.status='active' and membership.scope_kind='platform'
        and role_record.code='owner' and role_record.status='active')
    and not exists(
      select 1 from app_private.superadmin_internal_memberships membership
      join public.platform_roles role_record on role_record.id=membership.platform_role_id
      join app_private.superadmin_internal_auth_links auth_link
        on auth_link.internal_identity_id=membership.internal_identity_id
       and auth_link.status='active' and auth_link.id<>old.id
      where membership.status='active' and membership.scope_kind='platform'
        and role_record.code='owner' and role_record.status='active') then
    raise object_not_in_prerequisite_state using
      message='last active platform owner is protected',detail='SAI_LAST_OWNER_PROTECTED';
  end if;
  return case when tg_op='DELETE' then old else new end;
end
$$;

create function app_private.guard_superadmin_internal_owner_role()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if old.code='owner' then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('coelo.superadmin.last-owner',0));
  end if;
  if old.code='owner' and (tg_op='DELETE' or new.code<>'owner' or new.status<>'active'
      or new.max_scope_kind<>'platform')
    and exists(
      select 1 from app_private.superadmin_internal_memberships membership
      join app_private.superadmin_internal_auth_links auth_link
        on auth_link.internal_identity_id=membership.internal_identity_id
       and auth_link.status='active'
      where membership.platform_role_id=old.id and membership.status='active'
        and membership.scope_kind='platform') then
    raise object_not_in_prerequisite_state using
      message='active internal owner role is protected',detail='SAI_LAST_OWNER_PROTECTED';
  end if;
  return case when tg_op='DELETE' then old else new end;
end
$$;

create trigger superadmin_internal_memberships_last_owner_guard
before update of status,platform_role_id,scope_kind or delete
on app_private.superadmin_internal_memberships
for each row execute function app_private.guard_superadmin_internal_last_owner();
create trigger superadmin_internal_auth_links_last_owner_guard
before update of status,internal_identity_id,auth_user_id or delete
on app_private.superadmin_internal_auth_links
for each row execute function app_private.guard_superadmin_internal_owner_auth_link();
create trigger platform_roles_internal_owner_guard
before update of code,status,max_scope_kind or delete on public.platform_roles
for each row execute function app_private.guard_superadmin_internal_owner_role();

revoke all on function app_private.guard_superadmin_internal_auth_link_lifecycle()
  from public,anon,authenticated,service_role;
revoke all on function app_private.guard_superadmin_internal_membership_lifecycle()
  from public,anon,authenticated,service_role;
revoke all on function app_private.guard_superadmin_internal_membership_scope()
  from public,anon,authenticated,service_role;
revoke all on function app_private.guard_superadmin_internal_last_owner()
  from public,anon,authenticated,service_role;
revoke all on function app_private.guard_superadmin_internal_owner_auth_link()
  from public,anon,authenticated,service_role;
revoke all on function app_private.guard_superadmin_internal_owner_role()
  from public,anon,authenticated,service_role;

alter table audit.audit_logs
  add column hash_version smallint not null default 1,
  add column actor_kind text,
  add column actor_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id),
  add column actor_internal_auth_link_id uuid
    references app_private.superadmin_internal_auth_links(id),
  add column actor_internal_membership_id uuid
    references app_private.superadmin_internal_memberships(id),
  add column session_id_hash bytea,
  add column permission_code text,
  add column reason_code text;

alter table audit.audit_logs
  drop constraint audit_logs_payload_contract_version_check,
  add constraint audit_logs_payload_contract_version_check
    check(payload_contract_version in(1,2,3)),
  add constraint audit_logs_hash_version_check check(hash_version in(1,2,3)),
  add constraint audit_logs_actor_kind_check
    check(actor_kind is null or actor_kind in('superadmin_internal','auth_session')),
  add constraint audit_logs_internal_actor_check check(
    (hash_version=1 and actor_kind is null
      and actor_internal_identity_id is null
      and actor_internal_auth_link_id is null
      and actor_internal_membership_id is null
      and session_id_hash is null and permission_code is null
      and reason_code is null)
    or
    (hash_version=2 and actor_kind='superadmin_internal'
      and actor_person_id is null and actor_membership_id is null
      and support_session_id is null
      and actor_internal_identity_id is not null
      and actor_internal_auth_link_id is not null
      and actor_internal_membership_id is not null
      and session_id_hash is not null and octet_length(session_id_hash)=32
      and permission_code is not null
      and permission_code ~ '^[a-z0-9][a-z0-9._-]{0,119}$'
      and mfa_aal is not null
      and mfa_aal in('aal1','aal2')
      and (reason_code is null or reason_code ~ '^[A-Z][A-Z0-9_]{0,79}$')
      and (outcome='success' or reason_code is not null))
    or
    (hash_version=3 and actor_kind='auth_session'
      and payload_contract_version=3
      and actor_person_id is null and actor_membership_id is null
      and support_session_id is null
      and actor_internal_identity_id is null
      and actor_internal_auth_link_id is null
      and actor_internal_membership_id is null
      and session_id_hash is not null and octet_length(session_id_hash)=32
      and permission_code is not null
      and permission_code ~ '^[a-z0-9][a-z0-9._-]{0,119}$'
      and mfa_aal is not null and mfa_aal in('aal1','aal2')
      and actor_role_code is null and outcome='denied'
      and reason_code is not null and reason_code ~ '^[A-Z][A-Z0-9_]{0,79}$')
  );

create index audit_logs_internal_identity_cursor_idx
  on audit.audit_logs(actor_internal_identity_id,occurred_at desc,id desc)
  where actor_internal_identity_id is not null;
create index audit_logs_internal_auth_link_idx
  on audit.audit_logs(actor_internal_auth_link_id,occurred_at desc,id desc)
  where actor_internal_auth_link_id is not null;
create index audit_logs_internal_membership_idx
  on audit.audit_logs(actor_internal_membership_id,occurred_at desc,id desc)
  where actor_internal_membership_id is not null;
create index audit_logs_session_hash_idx
  on audit.audit_logs(session_id_hash,occurred_at desc,id desc)
  where session_id_hash is not null;

create function app_private.audit_entry_digest_v2(
  p_hash_version smallint,p_chain_position bigint,p_previous_hash bytea,p_id uuid,
  p_actor_person_id uuid,p_actor_membership_id uuid,p_support_session_id uuid,
  p_actor_kind text,p_actor_internal_identity_id uuid,
  p_actor_internal_auth_link_id uuid,p_actor_internal_membership_id uuid,
  p_session_id_hash bytea,p_permission_code text,p_mfa_aal text,p_reason_code text,
  p_actor_role_code text,p_correlation_id uuid,
  p_origin text,p_context_kind text,p_context_id uuid,p_action_code text,
  p_object_type text,p_object_id uuid,p_institution_id uuid,
  p_outcome public.audit_outcome,p_reason text,p_payload_contract_version smallint,
  p_before_json jsonb,p_after_json jsonb,p_occurred_at timestamptz
) returns bytea language sql immutable security invoker set search_path='' as $$
  select extensions.digest(pg_catalog.convert_to(pg_catalog.jsonb_build_object(
    'hash_version',p_hash_version,'chain_position',p_chain_position,
    'previous_hash',case when p_previous_hash is null then null else pg_catalog.encode(p_previous_hash,'hex') end,
    'id',p_id,'actor_person_id',p_actor_person_id,
    'actor_membership_id',p_actor_membership_id,'support_session_id',p_support_session_id,
    'actor_kind',p_actor_kind,
    'actor_internal_identity_id',p_actor_internal_identity_id,
    'actor_internal_auth_link_id',p_actor_internal_auth_link_id,
    'actor_internal_membership_id',p_actor_internal_membership_id,
    'session_id_hash',pg_catalog.encode(p_session_id_hash,'hex'),
    'permission_code',p_permission_code,'mfa_aal',p_mfa_aal,'reason_code',p_reason_code,
    'actor_role_code',p_actor_role_code,
    'correlation_id',p_correlation_id,'origin',p_origin,'context_kind',p_context_kind,
    'context_id',p_context_id,'action_code',p_action_code,
    'object_type',p_object_type,'object_id',p_object_id,'institution_id',p_institution_id,
    'outcome',p_outcome,'reason',p_reason,
    'payload_contract_version',p_payload_contract_version,'before',p_before_json,
    'after',p_after_json,'occurred_at',p_occurred_at
  )::text,'UTF8'),'sha256')
$$;
create function app_private.audit_entry_digest_v3(
  p_chain_position bigint,p_previous_hash bytea,p_id uuid,
  p_session_id_hash bytea,p_permission_code text,p_mfa_aal text,p_reason_code text,
  p_correlation_id uuid,p_origin text,p_context_kind text,p_context_id uuid,
  p_action_code text,p_object_type text,p_object_id uuid,p_institution_id uuid,
  p_outcome public.audit_outcome,p_payload_contract_version smallint,
  p_before_json jsonb,p_after_json jsonb,p_occurred_at timestamptz
) returns bytea language sql immutable security invoker set search_path='' as $$
  select extensions.digest(pg_catalog.convert_to(pg_catalog.jsonb_build_object(
    'hash_version',3,'chain_position',p_chain_position,
    'previous_hash',case when p_previous_hash is null then null else pg_catalog.encode(p_previous_hash,'hex') end,
    'id',p_id,'actor_kind','auth_session',
    'session_id_hash',pg_catalog.encode(p_session_id_hash,'hex'),
    'permission_code',p_permission_code,'mfa_aal',p_mfa_aal,
    'reason_code',p_reason_code,'correlation_id',p_correlation_id,
    'origin',p_origin,'context_kind',p_context_kind,'context_id',p_context_id,
    'action_code',p_action_code,'object_type',p_object_type,'object_id',p_object_id,
    'institution_id',p_institution_id,'outcome',p_outcome,
    'payload_contract_version',p_payload_contract_version,'before',p_before_json,
    'after',p_after_json,'occurred_at',p_occurred_at
  )::text,'UTF8'),'sha256')
$$;


create function app_private.audit_entry_matches_digest(p_log audit.audit_logs)
returns boolean language sql stable security invoker set search_path='' as $$
  select case p_log.hash_version
    when 1 then p_log.entry_hash=app_private.audit_entry_digest(
      p_log.chain_position,p_log.previous_hash,p_log.id,p_log.actor_person_id,
      p_log.actor_role_code,p_log.correlation_id,p_log.origin,p_log.context_kind,
      p_log.context_id,p_log.action_code,p_log.object_type,p_log.object_id,
      p_log.institution_id,p_log.outcome,p_log.reason,p_log.before_json,
      p_log.after_json,p_log.occurred_at)
    when 2 then p_log.entry_hash=app_private.audit_entry_digest_v2(
      p_log.hash_version,p_log.chain_position,p_log.previous_hash,p_log.id,
      p_log.actor_person_id,p_log.actor_membership_id,p_log.support_session_id,p_log.actor_kind,
      p_log.actor_internal_identity_id,p_log.actor_internal_auth_link_id,
      p_log.actor_internal_membership_id,p_log.session_id_hash,p_log.permission_code,
      p_log.mfa_aal,p_log.reason_code,p_log.actor_role_code,p_log.correlation_id,
      p_log.origin,p_log.context_kind,p_log.context_id,p_log.action_code,
      p_log.object_type,p_log.object_id,p_log.institution_id,p_log.outcome,
      p_log.reason,p_log.payload_contract_version,p_log.before_json,
      p_log.after_json,p_log.occurred_at)
    when 3 then p_log.entry_hash=app_private.audit_entry_digest_v3(
      p_log.chain_position,p_log.previous_hash,p_log.id,p_log.session_id_hash,
      p_log.permission_code,p_log.mfa_aal,p_log.reason_code,p_log.correlation_id,
      p_log.origin,p_log.context_kind,p_log.context_id,p_log.action_code,
      p_log.object_type,p_log.object_id,p_log.institution_id,p_log.outcome,
      p_log.payload_contract_version,p_log.before_json,p_log.after_json,p_log.occurred_at)
    else false end
$$;

create or replace function app_private.audit_guard_append_only()
returns trigger language plpgsql security definer set search_path='' as $$
declare expected_institution uuid;prior_hash bytea;
begin
  if tg_op in('UPDATE','DELETE') then
    raise object_not_in_prerequisite_state using message='audit logs are append-only';
  end if;
  new.origin:=coalesce(new.origin,'database');
  new.correlation_id:=coalesce(new.correlation_id,gen_random_uuid());
  new.context_kind:=coalesce(new.context_kind,case when new.institution_id is null then 'global' else 'institution' end);
  new.context_id:=coalesce(new.context_id,case when new.context_kind='institution' then new.institution_id else null end);
  if coalesce(new.hash_version,1)=1 then
    new.reason:=app_private.audit_mask_reason(new.reason);
    new.hash_version:=1;
    new.payload_contract_version:=1;
    new.actor_kind:=null;new.actor_internal_identity_id:=null;
    new.actor_internal_auth_link_id:=null;new.actor_internal_membership_id:=null;
    new.session_id_hash:=null;new.permission_code:=null;new.reason_code:=null;
    new.actor_role_code:=case when new.actor_person_id is null then 'system' else coalesce((
      select role_record.code from public.platform_memberships membership
      join public.platform_roles role_record on role_record.id=membership.role_id
      where membership.person_id=new.actor_person_id and membership.status='active'
        and membership.revoked_at is null and role_record.status='active'
      order by case membership.scope_kind when 'platform' then 0 else 1 end,membership.created_at limit 1
    ),(select membership.role_code from public.institution_memberships membership
      where membership.person_id=new.actor_person_id
        and (new.institution_id is null or membership.institution_id=new.institution_id)
        and membership.status='active' and membership.revoked_at is null
      order by membership.created_at limit 1)) end;
  elsif new.hash_version=2 then
    new.hash_version:=2;new.payload_contract_version:=2;
    new.actor_kind:='superadmin_internal';
    new.actor_person_id:=null;new.actor_membership_id:=null;
    new.support_session_id:=null;new.reason:=new.reason_code;
    if not exists(
      select 1 from app_private.superadmin_internal_auth_links auth_link
      join app_private.superadmin_internal_memberships membership
        on membership.id=new.actor_internal_membership_id
       and membership.internal_identity_id=auth_link.internal_identity_id
      where auth_link.id=new.actor_internal_auth_link_id
        and auth_link.internal_identity_id=new.actor_internal_identity_id) then
      raise foreign_key_violation using message='inconsistent internal audit actor';
    end if;
    select role_record.code into new.actor_role_code
      from app_private.superadmin_internal_memberships membership
      join public.platform_roles role_record on role_record.id=membership.platform_role_id
      where membership.id=new.actor_internal_membership_id;
  elsif new.hash_version=3 then
    if new.actor_person_id is not null or new.actor_membership_id is not null
      or new.support_session_id is not null or new.actor_internal_identity_id is not null
      or new.actor_internal_auth_link_id is not null
      or new.actor_internal_membership_id is not null or new.actor_role_code is not null then
      raise invalid_parameter_value using message='auth session audit cannot carry actor identifiers';
    end if;
    new.hash_version:=3;new.payload_contract_version:=3;
    new.actor_kind:='auth_session';new.reason:=new.reason_code;
  else
    raise invalid_parameter_value using message='invalid audit hash version';
  end if;
  if new.origin not in('database','edge_function','system','admin_ui','import')
    or new.action_code !~ '^[a-z0-9][a-z0-9._-]{0,119}$'
    or new.context_kind not in('global','institution','unit','group','activity','child') then
    raise invalid_parameter_value using message='invalid audit origin or context';
  end if;
  if new.context_kind='global' then
    if new.institution_id is not null or new.context_id is not null then
      raise invalid_parameter_value using message='invalid audit origin or context'; end if;
  elsif new.context_kind='institution' then expected_institution:=new.context_id;
  elsif new.context_kind='unit' then select institution_id into expected_institution from public.units where id=new.context_id;
  elsif new.context_kind='group' then select institution_id into expected_institution from public.groups where id=new.context_id;
  elsif new.context_kind='activity' then select institution_id into expected_institution from public.activity_definitions where id=new.context_id;
  elsif new.context_kind='child' then select institution_id into expected_institution from public.child_contexts where id=new.context_id;
  end if;
  if new.context_kind<>'global' and (expected_institution is null or expected_institution is distinct from new.institution_id) then
    raise invalid_parameter_value using message='invalid audit origin or context'; end if;
  new.before_json:=app_private.audit_minimize_payload(new.action_code,new.before_json);
  new.after_json:=app_private.audit_minimize_payload(new.action_code,new.after_json);
  perform pg_advisory_xact_lock(hashtextextended('audit.audit_logs.chain',0));
  new.chain_position:=nextval('audit.audit_log_chain_position_seq');
  select entry_hash into prior_hash from audit.audit_logs order by chain_position desc limit 1;
  new.previous_hash:=prior_hash;
  if new.hash_version=1 then
    new.entry_hash:=app_private.audit_entry_digest(new.chain_position,new.previous_hash,new.id,
      new.actor_person_id,new.actor_role_code,new.correlation_id,new.origin,new.context_kind,
      new.context_id,new.action_code,new.object_type,new.object_id,new.institution_id,new.outcome,
      new.reason,new.before_json,new.after_json,new.occurred_at);
  elsif new.hash_version=2 then
    new.entry_hash:=app_private.audit_entry_digest_v2(new.hash_version,new.chain_position,
      new.previous_hash,new.id,new.actor_person_id,new.actor_membership_id,new.support_session_id,
      new.actor_kind,new.actor_internal_identity_id,new.actor_internal_auth_link_id,
      new.actor_internal_membership_id,new.session_id_hash,new.permission_code,new.mfa_aal,
      new.reason_code,new.actor_role_code,new.correlation_id,new.origin,new.context_kind,
      new.context_id,new.action_code,new.object_type,new.object_id,new.institution_id,
      new.outcome,new.reason,new.payload_contract_version,new.before_json,new.after_json,new.occurred_at);
  elsif new.hash_version=3 then
    new.entry_hash:=app_private.audit_entry_digest_v3(new.chain_position,new.previous_hash,new.id,
      new.session_id_hash,new.permission_code,new.mfa_aal,new.reason_code,new.correlation_id,
      new.origin,new.context_kind,new.context_id,new.action_code,new.object_type,new.object_id,
      new.institution_id,new.outcome,new.payload_contract_version,new.before_json,new.after_json,new.occurred_at);
  else
    raise invalid_parameter_value using message='invalid audit hash version';
  end if;
  return new;
end
$$;

revoke all on function app_private.audit_entry_digest_v2(smallint,bigint,bytea,uuid,uuid,uuid,uuid,text,uuid,uuid,uuid,bytea,text,text,text,text,uuid,text,text,uuid,text,text,uuid,uuid,public.audit_outcome,text,smallint,jsonb,jsonb,timestamptz)
  from public,anon,authenticated,service_role;
revoke all on function app_private.audit_entry_digest_v3(bigint,bytea,uuid,bytea,text,text,text,uuid,text,text,uuid,text,text,uuid,uuid,public.audit_outcome,smallint,jsonb,jsonb,timestamptz)
  from public,anon,authenticated,service_role;
revoke all on function app_private.audit_entry_matches_digest(audit.audit_logs)
  from public,anon,authenticated,service_role;
revoke all on function app_private.audit_guard_append_only()
  from public,anon,authenticated,service_role;

create function app_private.audit_verify_entry(p_audit_log_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.audit_entry_matches_digest(log_record)
    and log_record.previous_hash is not distinct from (
      select prior.entry_hash from audit.audit_logs prior
      where prior.chain_position<log_record.chain_position
      order by prior.chain_position desc limit 1)
  from audit.audit_logs log_record where log_record.id=p_audit_log_id
$$;

revoke all on function app_private.audit_verify_entry(uuid)
  from public,anon,authenticated,service_role;

create function app_private.audit_append_superadmin_internal(
  p_internal_identity_id uuid,p_internal_auth_link_id uuid,
  p_internal_membership_id uuid,p_session_id uuid,p_permission_code text,
  p_aal text,p_action_code text,p_outcome public.audit_outcome,
  p_reason_code text,p_correlation_id uuid,p_institution_id uuid default null,
  p_object_type text default null,p_object_id uuid default null
) returns uuid language plpgsql volatile security definer set search_path='' as $$
declare event_id uuid:=gen_random_uuid();
begin
  if not exists(
    select 1 from app_private.superadmin_internal_auth_links auth_link
    join app_private.superadmin_internal_memberships membership
      on membership.id=p_internal_membership_id
     and membership.internal_identity_id=auth_link.internal_identity_id
    where auth_link.id=p_internal_auth_link_id
      and auth_link.internal_identity_id=p_internal_identity_id) then
    raise foreign_key_violation using message='inconsistent internal audit actor';
  end if;
  insert into audit.audit_logs(
    id,hash_version,actor_kind,actor_internal_identity_id,
    actor_internal_auth_link_id,actor_internal_membership_id,session_id_hash,
    permission_code,mfa_aal,action_code,object_type,object_id,institution_id,outcome,
    reason_code,correlation_id,origin,context_kind,context_id,occurred_at)
  values(
    event_id,2,'superadmin_internal',p_internal_identity_id,p_internal_auth_link_id,
    p_internal_membership_id,extensions.digest(
      pg_catalog.convert_to(p_session_id::text,'UTF8'),'sha256'),
    p_permission_code,p_aal,p_action_code,p_object_type,p_object_id,p_institution_id,
    p_outcome,p_reason_code,p_correlation_id,'database',
    case when p_institution_id is null then 'global' else 'institution' end,
    p_institution_id,pg_catalog.now());
  return event_id;
end
$$;

revoke all on function app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)
  from public,anon,authenticated,service_role;

create function app_private.audit_append_auth_session_denial(
  p_session_id uuid,p_permission_code text,p_aal text,p_action_code text,
  p_reason_code text,p_correlation_id uuid
) returns uuid language plpgsql volatile security definer set search_path='' as $$
declare event_id uuid:=gen_random_uuid();
begin
  insert into audit.audit_logs(
    id,hash_version,actor_kind,session_id_hash,permission_code,mfa_aal,action_code,
    outcome,reason_code,correlation_id,origin,context_kind,occurred_at)
  values(
    event_id,3,'auth_session',extensions.digest(
      pg_catalog.convert_to(p_session_id::text,'UTF8'),'sha256'),
    p_permission_code,p_aal,p_action_code,'denied',p_reason_code,
    p_correlation_id,'database','global',pg_catalog.now());
  return event_id;
end
$$;

revoke all on function app_private.audit_append_auth_session_denial(uuid,text,text,text,text,uuid)
  from public,anon,authenticated,service_role;

create function app_private.audit_superadmin_internal_denial_if_identified(
  p_permission_code text,p_action_code text,p_reason_code text,
  p_correlation_id uuid,p_institution_id uuid default null
) returns void language plpgsql volatile security definer set search_path='' as $$
declare current_auth_user_id uuid; current_session_id uuid; jwt_aal text;
  auth_link_id uuid; identity_id uuid; membership_id uuid;
begin
  current_auth_user_id:=auth.uid();
  if current_auth_user_id is null then return; end if;
  begin current_session_id:=(auth.jwt()->>'session_id')::uuid;
  exception when others then return; end;
  if not exists(select 1 from auth.sessions session_record
    where session_record.id=current_session_id and session_record.user_id=current_auth_user_id
      and (session_record.not_after is null or session_record.not_after>pg_catalog.now())) then
    return;
  end if;
  jwt_aal:=auth.jwt()->>'aal';
  if jwt_aal not in('aal1','aal2') then return; end if;
  select auth_link.id,auth_link.internal_identity_id into auth_link_id,identity_id
  from app_private.superadmin_internal_auth_links auth_link
  where auth_link.auth_user_id=current_auth_user_id
  order by auth_link.created_at desc limit 1;
  if auth_link_id is null then
    perform app_private.audit_append_auth_session_denial(current_session_id,
      p_permission_code,jwt_aal,p_action_code,p_reason_code,p_correlation_id);
    return;
  end if;
  select membership.id into membership_id
  from app_private.superadmin_internal_memberships membership
  where membership.internal_identity_id=identity_id
  order by (membership.status='active') desc,membership.created_at desc limit 1;
  if membership_id is null then
    perform app_private.audit_append_auth_session_denial(current_session_id,
      p_permission_code,jwt_aal,p_action_code,p_reason_code,p_correlation_id);
    return;
  end if;
  perform app_private.audit_append_superadmin_internal(identity_id,auth_link_id,
    membership_id,current_session_id,p_permission_code,jwt_aal,p_action_code,
    'denied',p_reason_code,p_correlation_id,p_institution_id,
    case when p_institution_id is null then null else 'institution' end,p_institution_id);
end
$$;

revoke all on function app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)
  from public,anon,authenticated,service_role;

create or replace function app_private.audit_get_event_for_superadmin(p_event_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  perform app_private.audit_assert_permission('audit.read',false);
  if p_event_id is null then
    raise invalid_parameter_value using message='invalid audit event id';
  end if;
  select pg_catalog.jsonb_build_object(
    'id',log_record.id,
    'actor',pg_catalog.jsonb_build_object(
      'kind',coalesce(log_record.actor_kind,
        case when log_record.actor_person_id is null then 'system' else 'person' end),
      'id',coalesce(log_record.actor_internal_identity_id,log_record.actor_person_id),
      'display_name',case when log_record.actor_kind='superadmin_internal' then 'Usuário interno'
        when log_record.actor_kind='auth_session' then 'Sessão autenticada'
        when log_record.actor_person_id is null then 'Sistema'
        else coalesce(person.display_name,'Ator não disponível') end,
      'role_code',case when log_record.actor_kind='auth_session' then null else
        coalesce(log_record.actor_role_code,
          case when log_record.actor_person_id is null then 'system' else 'legacy_unknown' end) end),
    'institution',case when log_record.institution_id is null then null else
      pg_catalog.jsonb_build_object('id',log_record.institution_id,'name',institution.public_name) end,
    'action_code',log_record.action_code,'permission_code',log_record.permission_code,
    'aal',log_record.mfa_aal,'object_type',log_record.object_type,'object_id',log_record.object_id,
    'outcome',case log_record.outcome::text when 'failed' then 'failure' else log_record.outcome::text end,
    'reason',coalesce(log_record.reason_code,app_private.audit_mask_reason(log_record.reason)),
    'before',app_private.audit_mask_payload(log_record.before_json),
    'after',app_private.audit_mask_payload(log_record.after_json),
    'correlation_id',log_record.correlation_id,'origin',log_record.origin,
    'context',pg_catalog.jsonb_build_object('kind',log_record.context_kind,'id',log_record.context_id),
    'occurred_at',log_record.occurred_at,
    'integrity',pg_catalog.jsonb_build_object(
      'version',log_record.hash_version,'position',log_record.chain_position,
      'previous_hash',case when log_record.previous_hash is null then null
        else pg_catalog.encode(log_record.previous_hash,'hex') end,
      'hash',pg_catalog.encode(log_record.entry_hash,'hex'),
      'verified',app_private.audit_verify_entry(log_record.id))) into result
  from audit.audit_logs log_record
  left join public.people person on person.id=log_record.actor_person_id
  left join public.institutions institution on institution.id=log_record.institution_id
  where log_record.id=p_event_id
    and app_private.audit_has_permission('audit.read',log_record.institution_id,false);
  return result;
end
$$;

create or replace function app_private.audit_list_events_for_superadmin(
  p_search text default null,p_actor_ids uuid[] default null,p_context_kinds text[] default null,
  p_action_codes text[] default null,p_resource_types text[] default null,
  p_outcomes text[] default null,p_origins text[] default null,p_institution_id uuid default null,
  p_from timestamptz default null,p_to timestamptz default null,
  p_cursor_occurred_at timestamptz default null,p_cursor_id uuid default null,p_limit integer default 25
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;actor uuid;v_authorization jsonb;export_authorization jsonb;
begin
  actor:=app_private.audit_assert_permission('audit.read',false);
  v_authorization:=app_private.audit_authorization_scope(actor,'audit.read');
  export_authorization:=app_private.audit_authorization_scope(actor,'audit.export');
  perform app_private.audit_validate_list_filters(p_search,p_actor_ids,p_context_kinds,
    p_action_codes,p_resource_types,p_outcomes,p_origins,p_from,p_to,
    p_cursor_occurred_at,p_cursor_id,p_limit);
  with filtered as materialized(
    select log_record.*,person.display_name,institution.public_name institution_name,
      coalesce(log_record.actor_internal_identity_id,log_record.actor_person_id) effective_actor_id,
      case when log_record.actor_kind='superadmin_internal' then 'Usuário interno'
        when log_record.actor_kind='auth_session' then 'Sessão autenticada'
        when log_record.actor_person_id is null then 'Sistema'
        else coalesce(person.display_name,'Ator não disponível') end effective_actor_name
    from audit.audit_logs log_record
    left join public.people person on person.id=log_record.actor_person_id
    left join public.institutions institution on institution.id=log_record.institution_id
    where (((v_authorization->>'global')::boolean and (log_record.institution_id is null
          or not((v_authorization->'denied_institution_ids')?log_record.institution_id::text)))
      or (log_record.institution_id is not null
          and (v_authorization->'institution_ids')?log_record.institution_id::text))
      and (p_institution_id is null or log_record.institution_id=p_institution_id)
      and (p_actor_ids is null or cardinality(p_actor_ids)=0
        or coalesce(log_record.actor_internal_identity_id,log_record.actor_person_id)=any(p_actor_ids))
      and (p_context_kinds is null or cardinality(p_context_kinds)=0 or log_record.context_kind=any(p_context_kinds))
      and (p_action_codes is null or cardinality(p_action_codes)=0 or log_record.action_code=any(p_action_codes))
      and (p_resource_types is null or cardinality(p_resource_types)=0 or log_record.object_type=any(p_resource_types))
      and (p_outcomes is null or cardinality(p_outcomes)=0 or
        case log_record.outcome::text when 'failed' then 'failure' else log_record.outcome::text end=any(p_outcomes))
      and (p_origins is null or cardinality(p_origins)=0 or log_record.origin=any(p_origins))
      and (p_from is null or log_record.occurred_at>=p_from)
      and (p_to is null or log_record.occurred_at<=p_to)
      and (nullif(btrim(p_search),'') is null or position(lower(btrim(p_search)) in lower(concat_ws(' ',
        log_record.action_code,log_record.object_type,log_record.object_id::text,
        log_record.correlation_id::text,case when log_record.actor_kind='superadmin_internal'
          then 'Usuário interno' when log_record.actor_kind='auth_session'
          then 'Sessão autenticada' else person.display_name end,institution.public_name)))>0)
  ),page_plus_one as(
    select * from filtered where p_cursor_occurred_at is null
      or (occurred_at,id)<(p_cursor_occurred_at,p_cursor_id)
    order by occurred_at desc,id desc limit p_limit+1
  ),visible as(select * from page_plus_one order by occurred_at desc,id desc limit p_limit)
  select jsonb_build_object(
    'items',coalesce((select jsonb_agg(jsonb_build_object(
      'id',id,'actor',jsonb_build_object(
        'kind',coalesce(actor_kind,case when actor_person_id is null then 'system' else 'person' end),
        'id',effective_actor_id,'display_name',effective_actor_name,
        'role_code',case when actor_kind='auth_session' then null else coalesce(actor_role_code,
          case when actor_person_id is null then 'system' else 'legacy_unknown' end) end),
      'institution',case when institution_id is null then null else
        jsonb_build_object('id',institution_id,'name',institution_name) end,
      'action_code',action_code,'permission_code',permission_code,'aal',mfa_aal,
      'object_type',object_type,'object_id',object_id,
      'outcome',case outcome::text when 'failed' then 'failure' else outcome::text end,
      'reason_code',reason_code,'correlation_id',correlation_id,'origin',origin,
      'context',jsonb_build_object('kind',context_kind,'id',context_id),'occurred_at',occurred_at
    ) order by occurred_at desc,id desc) from visible),'[]'::jsonb),
    'has_more',(select count(*) from page_plus_one)>p_limit,
    'next_cursor',case when (select count(*) from page_plus_one)>p_limit then
      (select jsonb_build_object('occurred_at',occurred_at,'event_id',id)
       from visible order by occurred_at,id limit 1) else null end,
    'total_count',(select count(*) from filtered),
    'can_export',(coalesce((export_authorization->>'global')::boolean,false)
      or jsonb_array_length(coalesce(export_authorization->'institution_ids','[]'::jsonb))>0)
      and app_private.has_mfa_aal2()) into result;
  return result;
end
$$;

create or replace function app_private.audit_materialize_export_for_worker(
  p_export_job_id uuid,p_worker_token uuid
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare job public.import_jobs%rowtype;filters jsonb;row_count integer;
  read_authorization jsonb;export_authorization jsonb;
  claim app_private.audit_export_worker_claims%rowtype;
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
  if exists(select 1 from app_private.audit_export_snapshot_rows snapshot
    join audit.audit_logs log_record on log_record.id=snapshot.audit_log_id
    where snapshot.export_job_id=job.id
      and (not app_private.audit_actor_has_permission(job.created_by,'audit.read',log_record.institution_id,false)
        or not app_private.audit_actor_has_permission(job.created_by,'audit.export',log_record.institution_id,false))) then
    raise insufficient_privilege using message='audit export authorization revoked';
  end if;
  if job.processing_state='SUCESSO' then
    return jsonb_build_object('job_id',job.id,'row_count',job.summary->'row_count',
      'state','SUCESSO','claimed',false);
  end if;
  if job.processing_state in('ERRO','REJEICAO') then
    raise object_not_in_prerequisite_state using message='audit export job is terminal';
  end if;
  filters:=coalesce(job.summary->'filters','{}'::jsonb);
  select * into claim from app_private.audit_export_worker_claims
    where export_job_id=job.id for update;
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
      'actor_kind',coalesce(log_record.actor_kind,
        case when log_record.actor_person_id is null then 'system' else 'person' end),
      'actor_id',coalesce(log_record.actor_internal_identity_id,log_record.actor_person_id),
      'actor_name',case when log_record.actor_kind='superadmin_internal' then 'Usuário interno'
        when log_record.actor_kind='auth_session' then 'Sessão autenticada'
        when log_record.actor_person_id is null then 'Sistema' else person.display_name end,
      'actor_role_code',log_record.actor_role_code,'permission_code',log_record.permission_code,
      'aal',log_record.mfa_aal,'reason_code',log_record.reason_code,
      'institution_name',institution.public_name,'action_code',log_record.action_code,
      'resource_type',log_record.object_type,'resource_id',log_record.object_id,
      'outcome',case log_record.outcome::text when 'failed' then 'failure' else log_record.outcome::text end,
      'correlation_id',log_record.correlation_id,'origin',log_record.origin,
      'context_kind',log_record.context_kind,'context_id',log_record.context_id)
  from audit.audit_logs log_record
  left join public.people person on person.id=log_record.actor_person_id
  left join public.institutions institution on institution.id=log_record.institution_id
  where (((read_authorization->>'global')::boolean and (log_record.institution_id is null
        or not((read_authorization->'denied_institution_ids')?log_record.institution_id::text)))
      or (log_record.institution_id is not null
        and (read_authorization->'institution_ids')?log_record.institution_id::text))
    and (((export_authorization->>'global')::boolean and (log_record.institution_id is null
        or not((export_authorization->'denied_institution_ids')?log_record.institution_id::text)))
      or (log_record.institution_id is not null
        and (export_authorization->'institution_ids')?log_record.institution_id::text))
    and (not(filters?'institution_id') or log_record.institution_id=(filters->>'institution_id')::uuid)
    and (not(filters?'actor_ids') or jsonb_array_length(filters->'actor_ids')=0
      or (filters->'actor_ids')?coalesce(log_record.actor_internal_identity_id,log_record.actor_person_id)::text)
    and (not(filters?'context_kinds') or jsonb_array_length(filters->'context_kinds')=0
      or (filters->'context_kinds')?log_record.context_kind)
    and (not(filters?'action_codes') or jsonb_array_length(filters->'action_codes')=0
      or (filters->'action_codes')?log_record.action_code)
    and (not(filters?'resource_types') or jsonb_array_length(filters->'resource_types')=0
      or (filters->'resource_types')?log_record.object_type)
    and (not(filters?'outcomes') or jsonb_array_length(filters->'outcomes')=0
      or (filters->'outcomes')?(case log_record.outcome::text when 'failed' then 'failure' else log_record.outcome::text end))
    and (not(filters?'origins') or jsonb_array_length(filters->'origins')=0
      or (filters->'origins')?log_record.origin)
    and (not(filters?'from') or log_record.occurred_at>=(filters->>'from')::timestamptz)
    and (not(filters?'to') or log_record.occurred_at<=(filters->>'to')::timestamptz)
    and (nullif(btrim(filters->>'search'),'') is null or position(lower(btrim(filters->>'search'))
      in lower(concat_ws(' ',log_record.action_code,log_record.object_type,
        log_record.object_id::text,log_record.correlation_id::text,
        case when log_record.actor_kind='superadmin_internal' then 'Usuário interno'
          when log_record.actor_kind='auth_session' then 'Sessão autenticada'
          else person.display_name end,institution.public_name)))>0)
  order by log_record.occurred_at desc,log_record.id desc limit 50001;
  get diagnostics row_count=row_count;
  if row_count>50000 then
    raise program_limit_exceeded using message='audit export exceeds maximum row count';
  end if;
  update public.import_jobs set processing_state='PROCESSANDO',status='active',
    started_at=coalesce(started_at,now()),updated_at=now(),
    summary=summary||jsonb_build_object('phase','materialized','row_count',row_count,
      'authorization_revalidated_at',now()) where id=job.id;
  return jsonb_build_object('job_id',job.id,'row_count',row_count,
    'state','PROCESSANDO','claimed',true);
end
$$;

create type app_private.superadmin_internal_context as(
  internal_identity_id uuid,internal_auth_link_id uuid,internal_membership_id uuid,
  auth_user_id uuid,session_id uuid,platform_role_id uuid,platform_role_code text,
  scope_kind text,scope_institution_id uuid,resolved_institution_id uuid,
  aal text,permission_code text,requires_mfa boolean
);

create function app_private.require_superadmin_internal_context(p_permission_code text)
returns setof app_private.superadmin_internal_context
language plpgsql stable security definer set search_path='' as $$
declare
  current_auth_user_id uuid; current_session_id uuid; jwt_session_id text;
  jwt_aal text; link_record record; membership_record record;
  role_record record; permission_record record; grant_effect public.permission_effect;
begin
  current_auth_user_id:=auth.uid();
  if current_auth_user_id is null then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_AUTH_REQUIRED';
  end if;
  jwt_session_id:=auth.jwt()->>'session_id';
  begin current_session_id:=jwt_session_id::uuid;
  exception when others then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_SESSION_INVALID';
  end;
  if not exists(select 1 from auth.sessions session_record
    where session_record.id=current_session_id
      and session_record.user_id=current_auth_user_id
      and (session_record.not_after is null or session_record.not_after>pg_catalog.now())) then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_SESSION_INVALID';
  end if;
  if not exists(select 1 from auth.users auth_user
    where auth_user.id=current_auth_user_id and auth_user.email_confirmed_at is not null) then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_INTERNAL_CONTEXT_DENIED';
  end if;
  jwt_aal:=auth.jwt()->>'aal';
  if jwt_aal not in('aal1','aal2') then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_SESSION_INVALID';
  end if;
  select auth_link.* into link_record
  from app_private.superadmin_internal_auth_links auth_link
  where auth_link.auth_user_id=current_auth_user_id
  order by auth_link.created_at desc limit 1;
  if link_record.id is null then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_INTERNAL_CONTEXT_DENIED';
  elsif link_record.status<>'active' then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_INTERNAL_CONTEXT_DENIED';
  end if;
  select membership.* into membership_record
  from app_private.superadmin_internal_memberships membership
  where membership.internal_identity_id=link_record.internal_identity_id
  order by (membership.status='active') desc,membership.created_at desc limit 1;
  if membership_record.id is null then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_INTERNAL_CONTEXT_DENIED';
  elsif membership_record.status='suspended' then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_MEMBERSHIP_SUSPENDED';
  elsif membership_record.status='revoked' then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_MEMBERSHIP_REVOKED';
  end if;
  select role_item.* into role_record from public.platform_roles role_item
  where role_item.id=membership_record.platform_role_id and role_item.status='active';
  if role_record.id is null
    or app_private.access_scope_rank(membership_record.scope_kind::text)>
       app_private.access_scope_rank(role_record.max_scope_kind) then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_PERMISSION_DENIED';
  end if;
  select permission_item.* into permission_record from public.platform_permissions permission_item
  where permission_item.code=p_permission_code and permission_item.status='active';
  if permission_record.id is null then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_PERMISSION_DENIED';
  end if;
  select role_permission.effect into grant_effect
  from public.platform_role_permissions role_permission
  where role_permission.role_id=role_record.id
    and role_permission.permission_id=permission_record.id
    and role_permission.status='active' and role_permission.revoked_at is null;
  if grant_effect is distinct from 'allow'::public.permission_effect then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_PERMISSION_DENIED';
  end if;
  if jwt_aal<>'aal2' and (role_record.code='owner' or permission_record.requires_mfa) then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_MFA_REQUIRED';
  end if;
  return query select link_record.internal_identity_id,link_record.id,membership_record.id,
    current_auth_user_id,current_session_id,role_record.id,role_record.code,
    membership_record.scope_kind::text,membership_record.scope_institution_id,null::uuid,
    jwt_aal,p_permission_code,permission_record.requires_mfa;
end
$$;

create function app_private.superadmin_internal_error_envelope(
  p_code text,p_correlation_id uuid
) returns jsonb language sql immutable security invoker set search_path='' as $$
  select pg_catalog.jsonb_build_object('ok',false,'data',null,'error',
    pg_catalog.jsonb_build_object('code',case when p_code in(
      'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED','SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE')
      then p_code else 'SAI_INTERNAL_ERROR' end,
      'message',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 'Autenticação necessária.'
        when p_code='SAI_MFA_REQUIRED' then 'Confirme o segundo fator.'
        when p_code in('SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE') then 'O estado mudou. Recarregue e tente novamente.'
        when p_code like 'SAI_%DENIED' or p_code like 'SAI_MEMBERSHIP_%' then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'correlation_id',p_correlation_id,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code in('SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE') then 409
        when p_code in('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
        else 500 end))
$$;

create function public.superadmin_auth_bootstrap_context()
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
  error_code text; result jsonb;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('platform.read');
    select pg_catalog.jsonb_build_object(
      'internal_identity_id',ctx.internal_identity_id,
      'internal_membership_id',ctx.internal_membership_id,
      'platform_role_code',ctx.platform_role_code,'scope_kind',ctx.scope_kind,
      'scope_institution_id',ctx.scope_institution_id,
      'permission_codes',coalesce((select pg_catalog.jsonb_agg(permission_record.code order by permission_record.code)
        from public.platform_role_permissions grant_record
        join public.platform_permissions permission_record on permission_record.id=grant_record.permission_id
        where grant_record.role_id=ctx.platform_role_id and grant_record.status='active'
          and grant_record.revoked_at is null and grant_record.effect='allow'
          and permission_record.status='active'),'[]'::jsonb),'aal',ctx.aal) into result;
  exception when others then
    get stacked diagnostics error_code=pg_exception_detail;
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'platform.read','superadmin.auth.bootstrap',
      case when error_code in('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
        'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
        then error_code else 'SAI_INTERNAL_ERROR' end,correlation);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
    ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'platform.read',ctx.aal,'superadmin.auth.bootstrap','success',null,correlation);
  return pg_catalog.jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

create function public.superadmin_auth_resolve_institution_context(p_institution_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
  error_code text; result jsonb;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('platform.read');
    if p_institution_id is null or not exists(
      select 1 from public.institutions institution where institution.id=p_institution_id) then
      raise insufficient_privilege using message='institution context denied',detail='SAI_PERMISSION_DENIED';
    end if;
    if ctx.scope_kind='institution' and ctx.scope_institution_id is distinct from p_institution_id then
      raise insufficient_privilege using message='institution context denied',detail='SAI_PERMISSION_DENIED';
    end if;
    ctx.resolved_institution_id:=p_institution_id;
    result:=pg_catalog.jsonb_build_object(
      'internal_identity_id',ctx.internal_identity_id,
      'internal_membership_id',ctx.internal_membership_id,
      'platform_role_code',ctx.platform_role_code,'scope_kind',ctx.scope_kind,
      'scope_institution_id',ctx.scope_institution_id,
      'resolved_institution_id',ctx.resolved_institution_id,'aal',ctx.aal);
  exception when others then
    get stacked diagnostics error_code=pg_exception_detail;
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'platform.read','superadmin.auth.resolve_institution',
      case when error_code in('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
        'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
        then error_code else 'SAI_INTERNAL_ERROR' end,correlation,p_institution_id);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
    ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'platform.read',ctx.aal,'superadmin.auth.resolve_institution','success',null,
    correlation,p_institution_id,'institution',p_institution_id);
  return pg_catalog.jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

revoke all on function app_private.require_superadmin_internal_context(text)
  from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_internal_error_envelope(text,uuid)
  from public,anon,authenticated,service_role;
revoke usage on type app_private.superadmin_internal_context
  from public,anon,authenticated,service_role;
revoke all on function public.superadmin_auth_bootstrap_context()
  from public,anon,authenticated,service_role;
revoke all on function public.superadmin_auth_resolve_institution_context(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_auth_bootstrap_context() to authenticated;
grant execute on function public.superadmin_auth_resolve_institution_context(uuid) to authenticated;

commit;
