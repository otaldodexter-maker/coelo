begin;

create extension if not exists pgtap with schema extensions;

select plan(3);

select ok(
  pg_get_functiondef('app_private.validate_routine_application_hierarchy()'::regprocedure)
    like '%parent_row.source_model_version_id <> new.source_model_version_id%'
  and pg_get_functiondef('app_private.validate_routine_application_hierarchy()'::regprocedure)
    like '%routine application inheritance mismatch%',
  'a child application must inherit the parent source-model version'
);

select ok(
  pg_get_functiondef('app_private.validate_routine_application_hierarchy()'::regprocedure)
    like '%model_row.origin_unit_id is distinct from new.unit_id%',
  'a unit-origin model cannot be applied outside its unit'
);

select ok(
  pg_get_functiondef('app_private.validate_routine_assignee()'::regprocedure)
    like '%membership_row.scope_unit_id is distinct from application_row.unit_id%'
  and pg_get_functiondef('app_private.validate_routine_assignee()'::regprocedure)
    like '%membership_row.scope_group_id is distinct from application_row.group_id%'
  and pg_get_functiondef('app_private.validate_routine_assignee()'::regprocedure)
    like '%status = ''active''%',
  'assignees require active memberships at the application scope'
);

select * from finish();
rollback;
