begin;

create extension if not exists pgtap with schema extensions;

select plan(34);

select has_table('public', 'routine_models', 'routine model identity');
select has_table('public', 'routine_model_versions', 'immutable routine model versions');
select has_table('public', 'routine_sections', 'ordered routine sections');
select has_table('public', 'routine_fields', 'typed routine fields');
select has_table('public', 'routine_field_options', 'ordered choice options');
select has_table('public', 'routine_field_conditions', 'conditional branches');
select has_table('public', 'routine_applications', 'applied and inherited routines');
select has_table('public', 'routine_application_revisions', 'effective application snapshots');
select has_table('public', 'routine_application_assignees', 'contextual responsible memberships');
select has_table('public', 'routine_launches', 'daily launches');
select has_table('public', 'routine_child_entries', 'child-scoped entries');
select has_table('public', 'routine_answers', 'typed launch answers');
select has_table('public', 'routine_launch_revisions', 'post-publication correction history');
select has_table('app_private', 'routine_command_receipts', 'idempotency receipts');

select results_eq(
  $$select count(*)::bigint from public.platform_permissions
      where code in ('routine.read','routine.manage_models','routine.manage_applications',
        'routine.record','routine.publish','routine.correct','routine.import','routine.export')
        and status='active'$$,
  array[8::bigint],
  'routine capabilities exist'
);

select ok(
  (select requires_mfa from public.platform_permissions where code='routine.publish')
  and (select requires_mfa from public.platform_permissions where code='routine.correct')
  and (select requires_mfa from public.platform_permissions where code='routine.import')
  and (select requires_mfa from public.platform_permissions where code='routine.export'),
  'high impact routine capabilities require MFA'
);

select has_function('public', 'superadmin_routine_directory',
  array['text','text','text','uuid','uuid','uuid','integer','integer'],
  'directory filters and paginates server-side');
select has_function('public', 'superadmin_routine_model_detail', array['uuid'],
  'aggregate hydration is authorized');
select has_function('public', 'superadmin_routine_save_model',
  array['uuid','uuid','bigint','jsonb'], 'model command is idempotent and versioned');
select has_function('public', 'superadmin_routine_save_application',
  array['uuid','uuid','bigint','jsonb'], 'application command is idempotent and versioned');
select has_function('public', 'superadmin_routine_save_launch_draft',
  array['uuid','uuid','bigint','jsonb'], 'launch draft command is versioned');
select has_function('public', 'superadmin_routine_publish_launch',
  array['uuid','uuid','bigint'], 'launch publication is explicit');
select has_function('public', 'superadmin_routine_correct_launch',
  array['uuid','uuid','bigint','text','jsonb'], 'published launch corrections require reason');

select ok(
  (select bool_and(c.relrowsecurity and c.relforcerowsecurity)
   from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public'
     and c.relkind in ('r', 'p')
     and c.relname like 'routine_%'),
  'all exposed routine tables force RLS'
);

select ok(
  not has_table_privilege('anon','public.routine_models','SELECT')
  and not has_table_privilege('authenticated','public.routine_models','INSERT')
  and not has_table_privilege('authenticated','public.routine_launches','UPDATE'),
  'browser roles have no direct aggregate writes and anon has no reads'
);

select ok(
  not has_function_privilege('anon',
    'public.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)','EXECUTE')
  and has_function_privilege('authenticated',
    'public.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)','EXECUTE'),
  'commands are authenticated-only'
);

select ok(
  pg_get_functiondef('app_private.validate_routine_definition(uuid)'::regprocedure)
    like '%maximum conditional depth is 4%'
  and pg_get_functiondef('app_private.validate_routine_definition(uuid)'::regprocedure)
    like '%conditional cycle%',
  'definition validator rejects deep or cyclic branches'
);

select ok(
  pg_get_functiondef(
    'app_private.superadmin_routine_publish_launch(uuid,uuid,bigint)'::regprocedure)
    like '%MFA AAL2 required%'
  and pg_get_functiondef(
    'app_private.superadmin_routine_publish_launch(uuid,uuid,bigint)'::regprocedure)
    like '%routine.publish required%',
  'publication recalculates capability and MFA server-side'
);

select ok(
  pg_get_functiondef(
    'app_private.validate_routine_application_hierarchy()'::regprocedure)
    like '%routine application hierarchy mismatch%'
  and pg_get_functiondef(
    'app_private.superadmin_routine_save_application(uuid,uuid,bigint,jsonb)'::regprocedure)
    like '%routine_command_receipts%',
  'application derives hierarchy and prevents replay'
);

select ok(
  pg_get_functiondef(
    'app_private.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)'::regprocedure)
    like '%routine_scope_allowed%'
  and pg_get_functiondef(
    'app_private.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)'::regprocedure)
    like '%routine model unavailable%',
  'model command authorizes the stored or requested scope without revealing it'
);

select ok(
  pg_get_functiondef(
    'app_private.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)'::regprocedure)
    like '%before_json%'
  and pg_get_functiondef(
    'app_private.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)'::regprocedure)
    like '%after_json%',
  'model command audits before and after aggregate state'
);
select ok(
  exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='daily_routine_effective_applications'
      and c.relkind='v' and coalesce((c.reloptions @> array['security_invoker=true']),false)
  ),
  'effective application view is security invoker'
);

set local role anon;
select throws_ok(
  $call$select public.superadmin_routine_model_detail(
    '10000000-0000-4000-8000-000000000001'::uuid)$call$,
  '42501', null, 'anonymous cannot probe routine ids'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000099',true);
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000099","aal":"aal2","role":"authenticated"}',true);
select throws_ok(
  $call$select public.superadmin_routine_directory(
    'model','',null,null,null,null,20,0)$call$,
  '42501','authentication required',
  'unmapped authenticated subject cannot enumerate routines'
);

reset role;
select * from finish();
rollback;
