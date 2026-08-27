begin;
select plan(12);

select is(
  current_user,
  'postgres',
  'function migrations execute as the postgres creator role'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc p
    where p.oid in (
      'app_private.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)'::regprocedure,
      'app_private.superadmin_group_export_prepare(uuid)'::regprocedure,
      'app_private.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)'::regprocedure,
      'app_private.superadmin_file_job_fail(uuid,text)'::regprocedure,
      'public.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)'::regprocedure,
      'public.superadmin_group_export_prepare(uuid)'::regprocedure,
      'public.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)'::regprocedure,
      'public.superadmin_file_job_fail(uuid,text)'::regprocedure
    )
      and p.proowner <> 'postgres'::regrole
  ),
  'the eight guarded functions are owned by postgres'
);

select ok(
  not has_function_privilege('anon', 'public.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)', 'EXECUTE'),
  'anonymous callers cannot apply group imports'
);
select ok(
  has_function_privilege('authenticated', 'public.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)', 'EXECUTE'),
  'authenticated callers can reach the guarded group import gateway'
);
select ok(
  not has_function_privilege('authenticated', 'public.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)', 'EXECUTE'),
  'authenticated callers cannot complete group exports'
);
select ok(
  has_function_privilege('service_role', 'public.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)', 'EXECUTE'),
  'service role can complete group exports'
);
select ok(
  not has_function_privilege('authenticated', 'public.superadmin_file_job_fail(uuid,text)', 'EXECUTE'),
  'authenticated callers cannot mark file jobs failed'
);
select ok(
  has_function_privilege('service_role', 'public.superadmin_file_job_fail(uuid,text)', 'EXECUTE'),
  'service role can mark file jobs failed'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_default_acl d
    cross join lateral pg_catalog.aclexplode(d.defaclacl) a
    where d.defaclrole = 'postgres'::regrole
      and d.defaclobjtype = 'f'
      and d.defaclnamespace = 0
      and a.grantee = 0
      and a.privilege_type = 'EXECUTE'
  ),
  'new postgres-owned functions do not grant execute to PUBLIC by default'
);

create function public.default_execute_probe()
returns integer language sql set search_path = '' as $$ select 1 $$;
create function app_private.default_execute_probe()
returns integer language sql set search_path = '' as $$ select 1 $$;

select ok(
  not has_function_privilege('anon', 'public.default_execute_probe()', 'EXECUTE')
    and not has_function_privilege('authenticated', 'public.default_execute_probe()', 'EXECUTE')
    and not has_function_privilege('service_role', 'public.default_execute_probe()', 'EXECUTE')
    and not exists (
      select 1
      from pg_catalog.pg_proc p
      cross join lateral pg_catalog.aclexplode(
        coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
      ) a
      where p.oid = 'public.default_execute_probe()'::regprocedure
        and a.grantee = 0
        and a.privilege_type = 'EXECUTE'
    ),
  'new public functions deny execute until a role is explicitly granted'
);
select ok(
  not has_function_privilege('anon', 'app_private.default_execute_probe()', 'EXECUTE')
    and not has_function_privilege('authenticated', 'app_private.default_execute_probe()', 'EXECUTE')
    and not has_function_privilege('service_role', 'app_private.default_execute_probe()', 'EXECUTE')
    and not exists (
      select 1
      from pg_catalog.pg_proc p
      cross join lateral pg_catalog.aclexplode(
        coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
      ) a
      where p.oid = 'app_private.default_execute_probe()'::regprocedure
        and a.grantee = 0
        and a.privilege_type = 'EXECUTE'
    ),
  'new private functions deny execute until a role is explicitly granted'
);

select ok(
  not exists (
    with targets(procedure_oid) as (
      values
        ('app_private.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)'::regprocedure::oid),
        ('app_private.superadmin_group_export_prepare(uuid)'::regprocedure::oid),
        ('app_private.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)'::regprocedure::oid),
        ('app_private.superadmin_file_job_fail(uuid,text)'::regprocedure::oid),
        ('public.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)'::regprocedure::oid),
        ('public.superadmin_group_export_prepare(uuid)'::regprocedure::oid),
        ('public.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)'::regprocedure::oid),
        ('public.superadmin_file_job_fail(uuid,text)'::regprocedure::oid)
    ),
    expected(procedure_oid, grantee) as (
      values
        ('public.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)'::regprocedure::oid, 'authenticated'::regrole::oid),
        ('public.superadmin_group_export_prepare(uuid)'::regprocedure::oid, 'authenticated'::regrole::oid),
        ('public.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)'::regprocedure::oid, 'service_role'::regrole::oid),
        ('public.superadmin_file_job_fail(uuid,text)'::regprocedure::oid, 'service_role'::regrole::oid)
    ),
    actual as (
      select p.oid as procedure_oid, a.grantee
      from targets t
      join pg_catalog.pg_proc p on p.oid = t.procedure_oid
      cross join lateral pg_catalog.aclexplode(
        coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
      ) a
      where a.privilege_type = 'EXECUTE'
        and a.grantee <> p.proowner
    ),
    differences as (
      (select * from actual except select * from expected)
      union all
      (select * from expected except select * from actual)
    )
    select 1 from differences
  ),
  'group import and export function ACLs match the exact non-owner allowlist'
);

select * from finish();
rollback;
