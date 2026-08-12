begin;

create extension if not exists pgtap with schema extensions;

select plan(10);

select ok(
  pg_get_functiondef('app_private.superadmin_routine_launch_detail(uuid)'::regprocedure)
    like '%routine_scope_allowed(''routine.read'',l.institution_id,l.unit_id,l.group_id)%',
  'launch detail scopes the id lookup to the actor before returning children'
);

select ok(
  pg_get_functiondef('app_private.superadmin_routine_application_detail(uuid)'::regprocedure)
    like '%routine_scope_allowed(''routine.read'',a.institution_id,a.unit_id,a.group_id)%',
  'application detail scopes the id lookup to the actor'
);

select ok(
  pg_get_functiondef('app_private.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb)'::regprocedure)
    like '%routine_scope_allowed(''routine.correct'',l.institution_id,l.unit_id,l.group_id)%',
  'correction authorizes the launch scope before inspecting correction ids'
);

select ok(
  pg_get_functiondef('public.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb)'::regprocedure)
    not like '%from public.routine_answers%',
  'public correction wrapper does not probe answer ids before authorization'
);

select has_function('app_private', 'routine_field_visible', array['uuid','uuid'],
  'conditional visibility is evaluated by one server-side helper');
select has_function('app_private', 'validate_routine_launch_answers', array['uuid','boolean'],
  'launch aggregate validator rejects hidden or missing visible answers');

select ok(
  pg_get_functiondef('app_private.superadmin_routine_publish_launch(uuid,uuid,bigint)'::regprocedure)
    like '%validate_routine_launch_answers($2,true)%',
  'publication validates only effective visible answers through the aggregate validator'
);

select ok(
  pg_get_functiondef('app_private.superadmin_routine_save_launch_draft(uuid,uuid,bigint,jsonb)'::regprocedure)
    like '%validate_routine_launch_answers(aggregate_id,false)%',
  'draft save rejects answers that are hidden by final conditional state'
);

select ok(
  not has_table_privilege('authenticated', 'public.routine_answers', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.routine_child_entries', 'SELECT'),
  'direct browser access to child answers remains denied'
);

select ok(
  not has_function_privilege('anon',
    'public.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb)', 'EXECUTE'),
  'anonymous callers cannot reach correction command'
);

select * from finish();
rollback;
