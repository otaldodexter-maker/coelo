begin;

create extension if not exists pgtap with schema extensions;

select plan(21);

select has_table('public', 'meal_plans', 'meal plans aggregate exists');
select has_column('public', 'meal_plans', 'status', 'meal plans have lifecycle status');
select has_column('public', 'meal_plans', 'recurrence', 'meal plans persist recurrence');
select has_column('public', 'meal_plans', 'menu', 'meal plans persist structured meals');
select has_column('public', 'meal_plans', 'priority', 'meal plans require explicit priority');

select has_function('public', 'meal_plan_list', array['jsonb'], 'directory RPC exists');
select has_function('public', 'meal_plan_get', array['uuid'], 'detail RPC exists');
select has_function(
  'public', 'meal_plan_create_or_update_draft',
  array['text', 'jsonb', 'uuid', 'integer'], 'draft command exists');
select has_function(
  'public', 'meal_plan_submit_for_review',
  array['text', 'uuid', 'integer'], 'review command exists');
select has_function(
  'public', 'meal_plan_publish',
  array['text', 'uuid', 'integer'], 'publish command exists');
select has_function(
  'public', 'meal_plan_conflicts_check',
  array['text', 'text', 'date', 'date', 'jsonb', 'jsonb'],
  'conflict check RPC exists');
select has_function(
  'public', 'meal_plan_effective_snapshot', array['jsonb'],
  'effective inheritance snapshot RPC exists');

select ok(
  (select c.relrowsecurity and c.relforcerowsecurity
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'meal_plans'),
  'meal plans enable and force RLS');

select ok(
  exists (
    select 1 from pg_indexes
     where schemaname = 'public'
       and indexname = 'meal_plans_tenant_status_period_idx')
  and exists (
    select 1 from pg_indexes
     where schemaname = 'public'
       and indexname = 'meal_plans_scope_period_idx'),
  'directory and overlap indexes exist');

select ok(
  not has_table_privilege('anon', 'public.meal_plans', 'SELECT')
  and not has_function_privilege(
    'anon', 'public.meal_plan_list(jsonb)', 'EXECUTE')
  and not has_function_privilege(
    'anon', 'public.meal_plan_publish(text,uuid,integer)', 'EXECUTE'),
  'anonymous clients cannot read or invoke meal plan RPCs');

select ok(
  has_table_privilege('authenticated', 'public.meal_plans', 'SELECT')
  and has_function_privilege(
    'authenticated', 'public.meal_plan_list(jsonb)', 'EXECUTE')
  and has_function_privilege(
    'authenticated', 'public.meal_plan_publish(text,uuid,integer)', 'EXECUTE'),
  'authenticated clients use the intentional RLS and RPC surface');

select ok(
  (select bool_and(not p.prosecdef)
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'meal_plan_list', 'meal_plan_get',
        'meal_plan_create_or_update_draft',
        'meal_plan_submit_for_review', 'meal_plan_publish',
        'meal_plan_conflicts_check', 'meal_plan_effective_snapshot')),
  'public meal plan RPCs execute as invoker under RLS');

select ok(
  (select bool_and(
      coalesce(pg_get_expr(pol.polqual, pol.polrelid), '')
        like '%meal_plan_scope_allowed%')
     from pg_policy pol
     join pg_class c on c.oid = pol.polrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'meal_plans'),
  'every meal plan policy validates tenant and institution scope');

select ok(
  pg_get_functiondef(
    'public.meal_plan_publish(text,uuid,integer)'::regprocedure)
      like '%pending_conflicts%'
  and pg_get_functiondef(
    'public.meal_plan_publish(text,uuid,integer)'::regprocedure)
      like '%priority=plan.priority%'
  and pg_get_functiondef(
    'public.meal_plan_publish(text,uuid,integer)'::regprocedure)
      like '%unresolved conflict%'
  and pg_get_functiondef(
    'public.meal_plan_publish(text,uuid,integer)'::regprocedure)
      like '%status=''published''%',
  'publication blocks equal-priority overlaps before lifecycle transition');

select ok(
  pg_get_functiondef(
    'public.meal_plan_submit_for_review(text,uuid,integer)'::regprocedure)
      like '%status = ''inReview''%'
  and pg_get_functiondef(
    'public.meal_plan_create_or_update_draft(text,jsonb,uuid,integer)'::regprocedure)
      like '%status=''draft''%',
  'draft and review lifecycle transitions are explicit');

set local role anon;
select throws_ok(
  $$select public.meal_plan_list('{}'::jsonb)$$,
  '42501', null, 'anonymous callers cannot enumerate meal plans');

reset role;
select * from finish();
rollback;
