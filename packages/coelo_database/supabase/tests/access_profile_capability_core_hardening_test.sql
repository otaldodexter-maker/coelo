begin;

create extension if not exists pgtap with schema extensions;

select plan(5);

select has_index(
  'public',
  'institution_member_permission_overrides',
  'institution_member_permission_overrides_active_scope_uidx',
  'active institution overrides have one canonical row per capability and scope'
);

select is(
  (
    select count(*)::bigint
    from pg_catalog.pg_indexes
    where schemaname = 'public'
      and tablename = 'institution_member_permission_overrides'
      and indexname = 'institution_member_permission_overrides_active_scope_uidx'
      and lower(indexdef) not like '%permission_code, effect,%'
      and lower(indexdef) like '%where%status = ''active''%revoked_at is null%'
  ),
  1::bigint,
  'canonical active-override uniqueness does not allow simultaneous allow and deny rows'
);

select ok(
  lower(pg_catalog.pg_get_functiondef(
    'app_private.superadmin_access_profile_assignment_link(uuid,jsonb)'::regprocedure
  )) like '%template_record.domain%principal%',
  'assignment link qualifies the Principal template domain column'
);

select ok(
  lower(pg_catalog.pg_get_functiondef(
    'app_private.superadmin_access_profile_capability_catalog(text,uuid,uuid)'::regprocedure
  )) like '%left join lateral%assignment_override%',
  'institution capability effects are reduced before JSON aggregation'
);

select is(
  (
    select count(*)::bigint
    from (values
      ('anon'::name),
      ('authenticated'::name)
    ) role_record(role_name)
    cross join (values
      ('app_private.superadmin_access_profile_assignment_link(uuid,jsonb)'::regprocedure),
      ('app_private.superadmin_access_profile_capability_catalog(text,uuid,uuid)'::regprocedure)
    ) function_record(function_oid)
    where has_function_privilege(role_record.role_name, function_record.function_oid, 'EXECUTE')
  ),
  0::bigint,
  'client roles cannot execute private access-profile helpers directly'
);

select * from finish();

rollback;
