begin;

create extension if not exists pgtap with schema extensions;

select plan(6);

select ok(
  pg_get_functiondef('app_private.superadmin_routine_save_application(uuid,uuid,bigint,jsonb)'::regprocedure)
    ~ 'where id = aggregate_id\\s+and app_private\\.routine_scope_allowed\\(''routine\\.manage_applications''',
  'application update reads by id only inside the authorized scope'
);

select ok(
  pg_get_functiondef('app_private.superadmin_routine_save_application(uuid,uuid,bigint,jsonb)'::regprocedure)
    ~ 'require_routine_scope\\(\\s*''routine\\.manage_applications''',
  'application create authorizes the requested scope before insertion'
);

select ok(
  pg_get_functiondef('app_private.superadmin_routine_save_application(uuid,uuid,bigint,jsonb)'::regprocedure)
    like '%raise no_data_found using message = ''routine application unavailable''%',
  'cross-scope application updates receive an opaque denial'
);

select ok(
  pg_get_functiondef('app_private.superadmin_routine_revert_application(uuid,uuid,bigint)'::regprocedure)
    ~ 'where id=\\$2\\s+and app_private\\.routine_scope_allowed\\(''routine\\.manage_applications''',
  'application revert reads by id only inside the authorized scope'
);

select ok(
  pg_get_functiondef('app_private.superadmin_routine_revert_application(uuid,uuid,bigint)'::regprocedure)
    like '%raise no_data_found using message=''routine application unavailable''%',
  'cross-scope application reverts receive an opaque denial'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.superadmin_routine_save_application(uuid,uuid,bigint,jsonb)',
    'EXECUTE'
  ) and not has_function_privilege(
    'anon',
    'public.superadmin_routine_revert_application(uuid,uuid,bigint)',
    'EXECUTE'
  ),
  'anonymous callers cannot invoke application commands'
);

select * from finish();
rollback;