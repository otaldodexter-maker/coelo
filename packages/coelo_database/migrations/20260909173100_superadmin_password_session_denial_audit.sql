-- source: D00 r14 real TAP35 failure; 20260901190927 wrappers; D01 Auth successor
-- status: local-candidate; remote application requires nominal authorization
-- generated_at: 2026-09-09
set local lock_timeout = '5s';
set local statement_timeout = '60s';
select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('coelo.superadmin.internal.auth.aal-policy',0));

do $preflight$
declare expected record; actual record;
begin
  if current_user <> 'postgres' then
    raise exception using errcode='42501',message='Auth denial audit migration must run as postgres';
  end if;
  if (select pg_catalog.md5(pg_catalog.replace(prosrc,E'\r\n',E'\n'))
      from pg_catalog.pg_proc where oid=pg_catalog.to_regprocedure(
        'app_private.require_superadmin_internal_context(text)'))
      is distinct from '6b3f7d0a6b374786137ed62ae8cf1c18' then
    raise exception using errcode='P0001',message='password-session context dependency drift';
  end if;
  for expected in select * from (values
    ('public.superadmin_auth_bootstrap_context()','cf411ecb47a0e3e42aeb4ee654f6b079'),
    ('public.superadmin_auth_resolve_institution_context(uuid)','e16a3b61cffba4230c7fb4235da9382d')
  ) baseline(signature,body_md5) loop
    select * into actual from pg_catalog.pg_proc
      where oid=pg_catalog.to_regprocedure(expected.signature);
    if actual.oid is null or
       pg_catalog.md5(pg_catalog.replace(actual.prosrc,E'\r\n',E'\n')) <> expected.body_md5 then
      raise exception using errcode='P0001',message='Auth wrapper exact body baseline drift';
    end if;
    if pg_catalog.pg_get_userbyid(actual.proowner) <> 'postgres'
       or not actual.prosecdef or actual.provolatile <> 'v'
       or actual.prorettype <> 'jsonb'::regtype or actual.proretset
       or not (coalesce(actual.proconfig,array[]::text[]) @> array['search_path=""']::text[]) then
      raise exception using errcode='P0001',message='Auth wrapper metadata drift';
    end if;
    if not pg_catalog.has_function_privilege('authenticated',actual.oid,'EXECUTE')
       or pg_catalog.has_function_privilege('anon',actual.oid,'EXECUTE')
       or pg_catalog.has_function_privilege('service_role',actual.oid,'EXECUTE')
       or exists(select 1 from pg_catalog.aclexplode(coalesce(actual.proacl,
         pg_catalog.acldefault('f',actual.proowner))) acl
         where acl.grantee=0 and acl.privilege_type='EXECUTE') then
      raise exception using errcode='P0001',message='Auth wrapper ACL drift';
    end if;
  end loop;
end
$preflight$;
create or replace function public.superadmin_auth_bootstrap_context()
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
      case when error_code in('SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
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

create or replace function public.superadmin_auth_resolve_institution_context(p_institution_id uuid)
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
      case when error_code in('SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
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

alter function public.superadmin_auth_bootstrap_context() owner to postgres;
alter function public.superadmin_auth_resolve_institution_context(uuid) owner to postgres;
revoke all on function public.superadmin_auth_bootstrap_context() from public,anon,service_role;
revoke all on function public.superadmin_auth_resolve_institution_context(uuid) from public,anon,service_role;
grant execute on function public.superadmin_auth_bootstrap_context() to authenticated;
grant execute on function public.superadmin_auth_resolve_institution_context(uuid) to authenticated;

do $postconditions$
declare expected record; actual record;
begin
  for expected in select * from (values
    ('public.superadmin_auth_bootstrap_context()','5db2c318fb52cb9014392727985bbc32'),
    ('public.superadmin_auth_resolve_institution_context(uuid)','c3948273e90ca59235a1a5f226ec9641')
  ) changed(signature,body_md5) loop
    select * into strict actual from pg_catalog.pg_proc
      where oid=pg_catalog.to_regprocedure(expected.signature);
    if pg_catalog.md5(pg_catalog.replace(actual.prosrc,E'\r\n',E'\n')) <> expected.body_md5
       or pg_catalog.pg_get_userbyid(actual.proowner) <> 'postgres'
       or not actual.prosecdef or actual.provolatile <> 'v'
       or actual.prorettype <> 'jsonb'::regtype or actual.proretset
       or not (coalesce(actual.proconfig,array[]::text[]) @> array['search_path=""']::text[])
       or not pg_catalog.has_function_privilege('authenticated',actual.oid,'EXECUTE')
       or pg_catalog.has_function_privilege('anon',actual.oid,'EXECUTE')
       or pg_catalog.has_function_privilege('service_role',actual.oid,'EXECUTE')
       or exists(select 1 from pg_catalog.aclexplode(coalesce(actual.proacl,
         pg_catalog.acldefault('f',actual.proowner))) acl
         where acl.grantee=0 and acl.privilege_type='EXECUTE') then
      raise exception using errcode='P0001',message='Auth denial audit postcondition failed';
    end if;
  end loop;
end
$postconditions$;
