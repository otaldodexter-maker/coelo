-- Functions are private by default; public RPC access is granted explicitly.
begin;

do $guard$
begin
  if current_user <> 'postgres' then
    raise exception using
      errcode = '42501',
      message = 'function privilege hardening must run as postgres';
  end if;
end
$guard$;

alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema app_private
  revoke execute on functions from public, anon, authenticated;

revoke all on function app_private.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)
  from public, anon, authenticated;
revoke all on function app_private.superadmin_group_export_prepare(uuid)
  from public, anon, authenticated;
revoke all on function app_private.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)
  from public, anon, authenticated;
revoke all on function app_private.superadmin_file_job_fail(uuid,text)
  from public, anon, authenticated;

revoke all on function public.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.superadmin_group_export_prepare(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)
  from public, anon, authenticated, service_role;
revoke all on function public.superadmin_file_job_fail(uuid,text)
  from public, anon, authenticated, service_role;

do $acl$
declare
  unexpected record;
begin
  for unexpected in
    with targets(procedure_oid, allowed_grantee) as (
      values
        ('app_private.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)'::regprocedure::oid, null::oid),
        ('app_private.superadmin_group_export_prepare(uuid)'::regprocedure::oid, null::oid),
        ('app_private.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)'::regprocedure::oid, null::oid),
        ('app_private.superadmin_file_job_fail(uuid,text)'::regprocedure::oid, null::oid),
        ('public.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)'::regprocedure::oid, 'authenticated'::regrole::oid),
        ('public.superadmin_group_export_prepare(uuid)'::regprocedure::oid, 'authenticated'::regrole::oid),
        ('public.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)'::regprocedure::oid, 'service_role'::regrole::oid),
        ('public.superadmin_file_job_fail(uuid,text)'::regprocedure::oid, 'service_role'::regrole::oid)
    )
    select p.oid::regprocedure as procedure_name, r.rolname
    from targets t
    join pg_catalog.pg_proc p on p.oid = t.procedure_oid
    cross join lateral pg_catalog.aclexplode(
      coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
    ) a
    join pg_catalog.pg_roles r on r.oid = a.grantee
    where a.privilege_type = 'EXECUTE'
      and a.grantee <> p.proowner
      and a.grantee is distinct from t.allowed_grantee
  loop
    execute pg_catalog.format(
      'revoke execute on function %s from %I',
      unexpected.procedure_name,
      unexpected.rolname
    );
  end loop;
end
$acl$;

grant execute on function public.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)
  to authenticated;
grant execute on function public.superadmin_group_export_prepare(uuid)
  to authenticated;
grant execute on function public.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)
  to service_role;
grant execute on function public.superadmin_file_job_fail(uuid,text)
  to service_role;

commit;
