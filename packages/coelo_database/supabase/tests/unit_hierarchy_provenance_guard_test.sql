begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select ok(
  to_regprocedure('app_private.assert_unit_hierarchy_contract()') is not null,
  'private unit hierarchy provenance guard exists'
);

select ok(
  not coalesce((
    select procedure_record.prosecdef
    from pg_proc procedure_record
    where procedure_record.oid =
      to_regprocedure('app_private.assert_unit_hierarchy_contract()')
  ), true),
  'unit hierarchy provenance guard is security invoker'
);

select ok(
  coalesce((
    select 'search_path=""' = any(procedure_record.proconfig)
    from pg_proc procedure_record
    where procedure_record.oid =
      to_regprocedure('app_private.assert_unit_hierarchy_contract()')
  ), false),
  'unit hierarchy provenance guard pins an empty search path'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.assert_unit_hierarchy_contract()',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'app_private.assert_unit_hierarchy_contract()',
    'execute'
  )
  and not has_function_privilege(
    'service_role',
    'app_private.assert_unit_hierarchy_contract()',
    'execute'
  ),
  'client and service roles cannot execute the private provenance guard'
);

select lives_ok(
  'select app_private.assert_unit_hierarchy_contract()',
  'accepted shared institution type hierarchy passes the provenance guard'
);

select is(
  app_private.assert_unit_hierarchy_contract(),
  jsonb_build_object(
    'catalog', 'institution_types',
    'column', 'institution_type_id',
    'contract', 'shared-institution-type'
  ),
  'provenance guard reports the accepted canonical hierarchy contract'
);

select * from finish();
rollback;
