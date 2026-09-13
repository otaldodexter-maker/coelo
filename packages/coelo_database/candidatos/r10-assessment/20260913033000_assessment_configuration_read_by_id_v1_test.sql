begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

select has_function(
  'public', 'superadmin_assessment_configuration_read_by_id', array['uuid'],
  'configuration read-by-id RPC exists'
);
select function_privs_are(
  'public', 'superadmin_assessment_configuration_read_by_id', array['uuid'],
  'anon', array[]::text[], 'anon cannot execute configuration read-by-id'
);
select function_privs_are(
  'public', 'superadmin_assessment_configuration_read_by_id', array['uuid'],
  'authenticated', array['EXECUTE']::text[], 'authenticated can execute configuration read-by-id'
);
select ok(
  pg_get_functiondef('public.superadmin_assessment_configuration_read_by_id(uuid)'::regprocedure)
    like '%assessment_v2_require_context(''activities.read'', null)%'
  and pg_get_functiondef('public.superadmin_assessment_configuration_read_by_id(uuid)'::regprocedure)
    like '%assessment_v2_require_context(''activities.read'', target_institution)%',
  'read-by-id authenticates globally and reauthorizes the configuration institution'
);
select ok(
  pg_get_functiondef('public.superadmin_assessment_configuration_read_by_id(uuid)'::regprocedure)
    like '%assessment_v2_configuration_snapshot(target_configuration)%'
  and pg_get_functiondef('public.superadmin_assessment_configuration_read_by_id(uuid)'::regprocedure)
    not like '%superadmin_assessment_configuration_read(%',
  'read-by-id returns the requested snapshot and does not fall back to activity/unit selection'
);

select * from finish();
rollback;
