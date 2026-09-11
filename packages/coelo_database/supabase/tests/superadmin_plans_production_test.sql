begin;

select plan(13);

select has_column('public', 'plans', 'description', 'plans has description');
select has_column('public', 'plans', 'revision', 'plans has optimistic revision');
select has_table('public', 'plan_change_receipts', 'plan receipts exist');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.plans'::regclass), 'plans RLS is active');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.plan_entitlements'::regclass), 'entitlements RLS is active');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.plan_change_receipts'::regclass), 'receipts RLS is active');
select function_returns(
  'public', 'superadmin_plans_list', array['text','text','text','integer','integer'], 'jsonb',
  'directory RPC returns jsonb'
);
select function_returns('public', 'superadmin_plan_get', array['uuid'], 'jsonb', 'detail RPC returns jsonb');
select function_returns(
  'public', 'superadmin_plan_save', array['uuid','uuid','bigint','jsonb','text'], 'jsonb',
  'save RPC returns jsonb'
);
select is(
  has_table_privilege('anon', 'public.plans', 'select'), false,
  'anon cannot read plans directly'
);
select is(
  has_table_privilege('authenticated', 'public.plans', 'select'), false,
  'authenticated cannot read plans directly'
);
select is(
  has_table_privilege('authenticated', 'public.plan_entitlements', 'insert'), false,
  'authenticated cannot write entitlements directly'
);
select is(
  has_table_privilege('authenticated', 'public.plan_change_receipts', 'select'), false,
  'receipts are private'
);

select * from finish();
rollback;
