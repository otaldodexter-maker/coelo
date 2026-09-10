-- ADR 0019, 2026-09-01 addendum: internal commands accept AAL1 during MVP.
-- Keep the compatible MFA argument and capability metadata for the formal gate.
-- Dependencies: internal Auth phase policy 20260901200206 and model CRUD 171731.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';
select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('coelo.access-profile-model.aal-policy', 0)
);

do $preflight$
declare
  helper record;
  context_body text;
begin
  if current_user <> 'postgres' then
    raise exception using errcode='42501',
      message='model AAL policy migration must run as postgres';
  end if;
  select * into helper from pg_catalog.pg_proc
  where oid=pg_catalog.to_regprocedure(
    'app_private.access_profile_require_model_action(text,text,boolean)');
  if helper.oid is null then
    raise exception using errcode='55000', message='model authorization helper missing';
  end if;
  if pg_catalog.pg_get_userbyid(helper.proowner) <> 'postgres'
    or not helper.prosecdef or helper.provolatile <> 's'
    or helper.proretset or helper.prorettype <> 'uuid'::regtype
    or helper.proconfig is distinct from array['search_path=""']::text[]
    or pg_catalog.pg_get_function_arguments(helper.oid) is distinct from
      'p_domain text, p_action text, p_require_mfa boolean DEFAULT true'
    or exists(select 1 from pg_catalog.aclexplode(
      coalesce(helper.proacl,pg_catalog.acldefault('f',helper.proowner))) acl
      where acl.grantee <> helper.proowner) then
    raise exception using errcode='55000', message='model authorization metadata drift';
  end if;
  -- Exact canonical prosrc from 20260901170731, trimmed and normalized to LF.
  if pg_catalog.md5(pg_catalog.btrim(pg_catalog.replace(
      helper.prosrc,E'\r\n',E'\n'),E' \t\n')) <> 'ebcccdcd557fcaab165a7e2044c74e97' then
    raise exception using errcode='55000', message='model authorization body drift';
  end if;
  select prosrc into context_body from pg_catalog.pg_proc
  where oid=pg_catalog.to_regprocedure(
    'app_private.require_superadmin_internal_context(text)');
  if context_body is null
    or pg_catalog.strpos(context_body,'SAI_MFA_REQUIRED') <> 0
    or pg_catalog.strpos(context_body,'auth.sessions') = 0
    or pg_catalog.strpos(context_body,'platform_role_permissions') = 0 then
    raise exception using errcode='55000', message='internal Auth phase policy missing or changed';
  end if;
end
$preflight$;

create or replace function app_private.access_profile_require_model_action(
  p_domain text,
  p_action text,
  p_require_mfa boolean default true
) returns uuid
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  context_record app_private.superadmin_internal_context;
  permission_code text;
begin
  if p_domain not in ('platform','institution','principal')
    or p_action not in ('read','create','update','delete','import','export') then
    raise invalid_parameter_value using message='unsupported access model action';
  end if;
  permission_code:=p_domain||'.role_models.'||p_action;
  select * into strict context_record
  from app_private.require_superadmin_internal_context(permission_code);
  if context_record.scope_kind<>'platform'
    or context_record.platform_role_code<>'owner' then
    raise insufficient_privilege using
      message='access model permission required',detail='SAI_PERMISSION_DENIED';
  end if;
  return context_record.internal_identity_id;
end
$$;

-- CREATE OR REPLACE preserves the existing owner and private ACL; no new grants.
commit;
