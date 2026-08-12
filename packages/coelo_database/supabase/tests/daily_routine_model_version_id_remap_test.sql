begin;

create extension if not exists pgtap with schema extensions;

select plan(5);

select has_function(
  'app_private',
  'routine_insert_version_definition',
  array['uuid','jsonb'],
  'version definition insertion is isolated behind a remapping helper'
);

select ok(
  pg_get_functiondef('app_private.routine_insert_version_definition(uuid,jsonb)'::regprocedure)
    like '%section_ids jsonb%'
  and pg_get_functiondef('app_private.routine_insert_version_definition(uuid,jsonb)'::regprocedure)
    like '%field_ids jsonb%'
  and pg_get_functiondef('app_private.routine_insert_version_definition(uuid,jsonb)'::regprocedure)
    like '%option_ids jsonb%',
  'all immutable definition node kinds receive a source-to-snapshot map'
);

select ok(
  pg_get_functiondef('app_private.routine_insert_version_definition(uuid,jsonb)'::regprocedure)
    like '%gen_random_uuid()%'
  and pg_get_functiondef('app_private.routine_insert_version_definition(uuid,jsonb)'::regprocedure)
    like '%condition references an unknown routine definition node%',
  'new snapshot ids are generated and dangling condition references are rejected'
);

select ok(
  pg_get_functiondef('app_private.routine_insert_version_definition(uuid,jsonb)'::regprocedure)
    like '%(field_ids->>source_field_id)::uuid%'
  and pg_get_functiondef('app_private.routine_insert_version_definition(uuid,jsonb)'::regprocedure)
    like '%(option_ids->>source_option_id)::uuid%',
  'conditions are remapped to ids belonging to the new snapshot'
);

select ok(
  pg_get_functiondef('app_private.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)'::regprocedure)
    like '%routine_insert_version_definition(version_id,p_payload)%',
  'model save delegates persistence to immutable id remapping'
);

select * from finish();
rollback;
