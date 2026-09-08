-- Nominal local catalog probe only: AuthOnly47; selected and run by the replay owner.
-- No candidate migration, capability bootstrap or privilege repair is part of this probe.
begin;
reset role;

create extension if not exists pgtap with schema extensions;

select plan(3);
select is(current_user::text, 'postgres', 'legacy ACL probe runs as postgres');
select ok(
  current_setting('server_version_num')::integer between 170000 and 179999,
  'legacy ACL probe runs on PostgreSQL 17'
);
select ok(
  to_regclass('public.activity_locations') is not null,
  'legacy activity_locations table exists'
);

select diag(
  jsonb_build_object(
    'current_user', current_user,
    'server_version_num', current_setting('server_version_num')::integer,
    'relation', 'public.activity_locations',
    'acl', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'grantee', coalesce(r.rolname::text, 'PUBLIC'),
          'privilege_type', a.privilege_type,
          'is_grantable', a.is_grantable
        )
        order by coalesce(r.rolname::text, 'PUBLIC'), a.privilege_type, a.is_grantable
      )
      from pg_catalog.pg_class c
      cross join lateral pg_catalog.aclexplode(
        coalesce(c.relacl, pg_catalog.acldefault('r', c.relowner))
      ) a
      left join pg_catalog.pg_roles r on r.oid = a.grantee
      where c.oid = to_regclass('public.activity_locations')
        and a.grantee <> c.relowner
    ), '[]'::jsonb)
  )::text
);

select diag(
  jsonb_build_object(
    'functions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'schema', n.nspname,
          'name', p.proname,
          'identity_arguments', pg_catalog.pg_get_function_identity_arguments(p.oid),
          'owner', pg_catalog.pg_get_userbyid(p.proowner),
          'prosecdef', p.prosecdef,
          'proconfig', p.proconfig,
          'authenticated_execute',
            pg_catalog.has_function_privilege('authenticated', p.oid, 'EXECUTE'),
          'public_acl', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'privilege_type', a.privilege_type,
                'is_grantable', a.is_grantable
              )
              order by a.privilege_type, a.is_grantable
            )
            from pg_catalog.aclexplode(
              coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
            ) a
            where a.grantee = 0
          ), '[]'::jsonb)
        )
        order by n.nspname, p.proname,
          pg_catalog.pg_get_function_identity_arguments(p.oid)
      )
      from pg_catalog.pg_proc p
      join pg_catalog.pg_namespace n on n.oid = p.pronamespace
      where (n.nspname = 'public' and p.proname = 'superadmin_access_profiles_list')
        or (n.nspname = 'app_private' and p.proname = 'superadmin_access_profiles_cursor')
    ), '[]'::jsonb)
  )::text
);

select * from finish();
rollback;
