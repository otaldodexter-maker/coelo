begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('coelo.superadmin.internal.auth.aal-policy', 0)
);

do $preflight$
declare
  function_record record;
  function_definition text;
begin
  if current_user <> 'postgres' then
    raise exception using
      errcode = '42501',
      message = 'internal auth AAL policy migration must run as postgres';
  end if;

  select procedure_record.*,
    pg_catalog.pg_get_functiondef(procedure_record.oid) as definition
  into function_record
  from pg_catalog.pg_proc procedure_record
  where procedure_record.oid = pg_catalog.to_regprocedure(
    'app_private.require_superadmin_internal_context(text)'
  );

  if function_record.oid is null then
    raise exception using errcode = 'P0001',
      message = 'internal auth context gateway is missing';
  end if;

  function_definition := function_record.definition;
  if pg_catalog.pg_get_userbyid(function_record.proowner) <> 'postgres'
     or not function_record.prosecdef
     or function_record.provolatile <> 's'
     or not (coalesce(function_record.proconfig, array[]::text[])
       @> array['search_path=""']::text[]) then
    raise exception using errcode = 'P0001',
      message = 'internal auth context gateway security metadata drift';
  end if;

  if function_definition !~
       'role_record\.code\s*=\s*''owner''\s+or\s+permission_record\.requires_mfa'
     or pg_catalog.strpos(function_definition, 'SAI_MFA_REQUIRED') = 0 then
    raise exception using errcode = 'P0001',
      message = 'internal auth context AAL baseline drift';
  end if;

  if pg_catalog.has_function_privilege(
       'anon', 'app_private.require_superadmin_internal_context(text)', 'EXECUTE')
     or pg_catalog.has_function_privilege(
       'authenticated', 'app_private.require_superadmin_internal_context(text)', 'EXECUTE')
     or pg_catalog.has_function_privilege(
       'service_role', 'app_private.require_superadmin_internal_context(text)', 'EXECUTE') then
    raise exception using errcode = 'P0001',
      message = 'internal auth context gateway ACL drift';
  end if;
end
$preflight$;

create or replace function app_private.require_superadmin_internal_context(
  p_permission_code text
)
returns setof app_private.superadmin_internal_context
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_auth_user_id uuid;
  current_session_id uuid;
  jwt_session_id text;
  jwt_aal text;
  link_record record;
  membership_record record;
  role_record record;
  permission_record record;
  grant_effect public.permission_effect;
begin
  current_auth_user_id := auth.uid();
  if current_auth_user_id is null then
    raise insufficient_privilege using message = 'internal authorization denied',
      detail = 'SAI_AUTH_REQUIRED';
  end if;

  jwt_session_id := auth.jwt() ->> 'session_id';
  begin
    current_session_id := jwt_session_id::uuid;
  exception when others then
    raise insufficient_privilege using message = 'internal authorization denied',
      detail = 'SAI_SESSION_INVALID';
  end;

  if not exists (
    select 1 from auth.sessions session_record
    where session_record.id = current_session_id
      and session_record.user_id = current_auth_user_id
      and (session_record.not_after is null
        or session_record.not_after > pg_catalog.now())
  ) then
    raise insufficient_privilege using message = 'internal authorization denied',
      detail = 'SAI_SESSION_INVALID';
  end if;

  if not exists (
    select 1 from auth.users auth_user
    where auth_user.id = current_auth_user_id
      and auth_user.email_confirmed_at is not null
  ) then
    raise insufficient_privilege using message = 'internal authorization denied',
      detail = 'SAI_INTERNAL_CONTEXT_DENIED';
  end if;

  jwt_aal := auth.jwt() ->> 'aal';
  if jwt_aal not in ('aal1', 'aal2') then
    raise insufficient_privilege using message = 'internal authorization denied',
      detail = 'SAI_SESSION_INVALID';
  end if;

  select auth_link.* into link_record
  from app_private.superadmin_internal_auth_links auth_link
  where auth_link.auth_user_id = current_auth_user_id
  order by auth_link.created_at desc
  limit 1;

  if link_record.id is null then
    raise insufficient_privilege using message = 'internal authorization denied',
      detail = 'SAI_INTERNAL_CONTEXT_DENIED';
  elsif link_record.status <> 'active' then
    raise insufficient_privilege using message = 'internal authorization denied',
      detail = 'SAI_INTERNAL_CONTEXT_DENIED';
  end if;

  select membership.* into membership_record
  from app_private.superadmin_internal_memberships membership
  where membership.internal_identity_id = link_record.internal_identity_id
  order by (membership.status = 'active') desc, membership.created_at desc
  limit 1;

  if membership_record.id is null then
    raise insufficient_privilege using message = 'internal authorization denied',
      detail = 'SAI_INTERNAL_CONTEXT_DENIED';
  elsif membership_record.status = 'suspended' then
    raise insufficient_privilege using message = 'internal authorization denied',
      detail = 'SAI_MEMBERSHIP_SUSPENDED';
  elsif membership_record.status = 'revoked' then
    raise insufficient_privilege using message = 'internal authorization denied',
      detail = 'SAI_MEMBERSHIP_REVOKED';
  end if;

  select role_item.* into role_record
  from public.platform_roles role_item
  where role_item.id = membership_record.platform_role_id
    and role_item.status = 'active';

  if role_record.id is null
     or app_private.access_scope_rank(membership_record.scope_kind::text)
       > app_private.access_scope_rank(role_record.max_scope_kind) then
    raise insufficient_privilege using message = 'internal authorization denied',
      detail = 'SAI_PERMISSION_DENIED';
  end if;

  select permission_item.* into permission_record
  from public.platform_permissions permission_item
  where permission_item.code = p_permission_code
    and permission_item.status = 'active';

  if permission_record.id is null then
    raise insufficient_privilege using message = 'internal authorization denied',
      detail = 'SAI_PERMISSION_DENIED';
  end if;

  select role_permission.effect into grant_effect
  from public.platform_role_permissions role_permission
  where role_permission.role_id = role_record.id
    and role_permission.permission_id = permission_record.id
    and role_permission.status = 'active'
    and role_permission.revoked_at is null;

  if grant_effect is distinct from 'allow'::public.permission_effect then
    raise insufficient_privilege using message = 'internal authorization denied',
      detail = 'SAI_PERMISSION_DENIED';
  end if;

  return query select
    link_record.internal_identity_id,
    link_record.id,
    membership_record.id,
    current_auth_user_id,
    current_session_id,
    role_record.id,
    role_record.code,
    membership_record.scope_kind::text,
    membership_record.scope_institution_id,
    null::uuid,
    jwt_aal,
    p_permission_code,
    permission_record.requires_mfa;
end
$$;

alter function app_private.require_superadmin_internal_context(text)
  owner to postgres;

revoke all on function app_private.require_superadmin_internal_context(text)
  from public, anon, authenticated, service_role;

do $postconditions$
declare
  function_record record;
  function_definition text;
begin
  select procedure_record.*,
    pg_catalog.pg_get_functiondef(procedure_record.oid) as definition
  into strict function_record
  from pg_catalog.pg_proc procedure_record
  where procedure_record.oid = pg_catalog.to_regprocedure(
    'app_private.require_superadmin_internal_context(text)'
  );

  function_definition := function_record.definition;
  if pg_catalog.strpos(function_definition, 'SAI_MFA_REQUIRED') <> 0
     or pg_catalog.strpos(function_definition, 'auth.sessions') = 0
     or pg_catalog.strpos(function_definition, 'auth.users') = 0
     or pg_catalog.strpos(function_definition, 'platform_role_permissions') = 0
     or pg_catalog.strpos(function_definition, 'permission_record.requires_mfa') = 0 then
    raise exception using errcode = 'P0001',
      message = 'internal auth AAL policy postcondition failed';
  end if;

  if pg_catalog.pg_get_userbyid(function_record.proowner) <> 'postgres'
     or not function_record.prosecdef
     or function_record.provolatile <> 's'
     or not (coalesce(function_record.proconfig, array[]::text[])
       @> array['search_path=""']::text[]) then
    raise exception using errcode = 'P0001',
      message = 'internal auth gateway metadata postcondition failed';
  end if;

  if pg_catalog.has_function_privilege(
       'anon', 'app_private.require_superadmin_internal_context(text)', 'EXECUTE')
     or pg_catalog.has_function_privilege(
       'authenticated', 'app_private.require_superadmin_internal_context(text)', 'EXECUTE')
     or pg_catalog.has_function_privilege(
       'service_role', 'app_private.require_superadmin_internal_context(text)', 'EXECUTE') then
    raise exception using errcode = 'P0001',
      message = 'internal auth gateway ACL postcondition failed';
  end if;
end
$postconditions$;

commit;
