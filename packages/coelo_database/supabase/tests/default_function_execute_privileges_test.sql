begin;
select plan(8);

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
    join pg_catalog.pg_namespace n on n.oid = d.defaclnamespace
    cross join lateral pg_catalog.aclexplode(d.defaclacl) a
    where d.defaclrole = 'postgres'::regrole
      and d.defaclobjtype = 'f'
      and n.nspname in ('public', 'app_private')
      and a.grantee = 0
      and a.privilege_type = 'EXECUTE'
  ),
  'new public and private functions do not grant execute to PUBLIC by default'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    cross join lateral pg_catalog.aclexplode(
      coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
    ) a
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
      and a.grantee = 0
      and a.privilege_type = 'EXECUTE'
  ),
  'group import and export functions have no PUBLIC execute grant'
);

select * from finish();
rollback;
