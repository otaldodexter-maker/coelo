begin;

select plan(16);
select has_column('public', 'people', 'mobile_phone', 'people store mobile phone for account profile');
select has_table('public', 'account_email_change_requests', 'email change requests exist');
select has_table('public', 'account_profile_command_receipts', 'account receipts exist');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.account_email_change_requests'::regclass), 'email requests RLS is active');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.account_profile_command_receipts'::regclass), 'account receipts RLS is active');
select function_returns('public', 'superadmin_account_profile_get', array[]::text[], 'jsonb', 'account profile get returns jsonb');
select function_returns('public', 'superadmin_account_profile_save', array['uuid','text','text','text','text','text'], 'jsonb', 'account profile save returns jsonb');
select function_returns('public', 'superadmin_account_email_change_cancel', array['uuid'], 'jsonb', 'email cancellation returns jsonb');
select is(has_table_privilege('anon', 'public.account_email_change_requests', 'select'), false, 'anon cannot read email requests');
select is(has_table_privilege('authenticated', 'public.account_email_change_requests', 'select'), false, 'authenticated cannot read email requests directly');
select is(has_table_privilege('authenticated', 'public.account_profile_command_receipts', 'select'), false, 'authenticated cannot read account receipts directly');
select is(has_function_privilege('anon', 'public.superadmin_account_profile_get()', 'execute'), false, 'anon cannot call account profile');
select is(has_function_privilege('authenticated', 'public.superadmin_account_profile_get()', 'execute'), true, 'authenticated can call account profile through authorization');
select is(has_function_privilege('authenticated', 'public.superadmin_account_profile_save(uuid,text,text,text,text,text)', 'execute'), true, 'authenticated can save account profile through authorization');
select is(has_function_privilege('authenticated', 'public.superadmin_account_email_change_cancel(uuid)', 'execute'), true, 'authenticated can cancel email change through authorization');
select ok((select pg_get_functiondef('public.superadmin_account_profile_save(uuid,text,text,text,text,text)'::regprocedure) not like '%auth.admin%'), 'profile save does not expose service role admin API');

select * from finish();
rollback;
