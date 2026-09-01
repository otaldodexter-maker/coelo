begin;
select plan(9);

select function_privs_are(
  'app_private',
  'superadmin_import_export_upload_contract',
  array['uuid'],
  'postgres',
  array['EXECUTE'],
  'upload contract remains private'
);
select function_privs_are(
  'app_private',
  'superadmin_retry_unit_import',
  array['uuid', 'uuid'],
  'postgres',
  array['EXECUTE'],
  'unit retry remains private'
);
select function_privs_are(
  'app_private',
  'superadmin_retry_import_export_job',
  array['uuid', 'uuid'],
  'postgres',
  array['EXECUTE'],
  'hub retry remains private'
);

select ok(
  pg_get_functiondef('app_private.superadmin_import_export_upload_contract(uuid)'::regprocedure)
    like '%assert_unit_file_access%units.import%',
  'upload revalidates units.import at execution time'
);
select ok(
  lower(pg_get_functiondef('app_private.superadmin_retry_unit_import(uuid,uuid)'::regprocedure))
    like '%p_request_id is null%',
  'unit retry rejects a null request_id'
);
select ok(
  lower(pg_get_functiondef('app_private.superadmin_retry_import_export_job(uuid,uuid)'::regprocedure))
    like '%p_request_id is null%',
  'hub retry rejects a null request_id'
);
select ok(
  pg_get_functiondef('app_private.superadmin_retry_unit_import(uuid,uuid)'::regprocedure)
    like '%pg_advisory_xact_lock%',
  'unit retry serializes equal idempotency keys'
);
select ok(
  pg_get_functiondef('app_private.superadmin_retry_unit_import(uuid,uuid)'::regprocedure)
    like '%retry_request_id%',
  'unit retry persists and replays its idempotency key'
);
select ok(
  pg_get_functiondef('app_private.superadmin_retry_unit_import(uuid,uuid)'::regprocedure)
    like '%unit import is not retryable%',
  'unit retry rejects non-terminal states'
);

select * from finish();
rollback;
