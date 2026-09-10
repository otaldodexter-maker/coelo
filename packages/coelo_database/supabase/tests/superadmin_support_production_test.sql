begin;

select plan(23);

select has_column('public', 'support_sessions', 'subject', 'support sessions have subject');
select has_column('public', 'support_sessions', 'ticket_status', 'support sessions have product status');
select has_column('public', 'support_sessions', 'revision', 'support sessions have optimistic revision');
select is((select is_nullable from information_schema.columns where table_schema='public' and table_name='support_sessions' and column_name='institution_id'), 'YES', 'internal support can be created without institution scope');
select has_table('public', 'support_command_receipts', 'support command receipts exist');
select row_security_active('public.support_sessions'::regclass, 'support sessions RLS is active');
select row_security_active('public.support_messages'::regclass, 'support messages RLS is active');
select row_security_active('audit.support_session_actions'::regclass, 'support actions RLS is active');
select row_security_active('public.support_command_receipts'::regclass, 'support receipts RLS is active');
select function_returns('public', 'superadmin_support_list', array['text','text[]','text[]','text[]','uuid[]','boolean','integer','integer'], 'jsonb', 'support list returns jsonb');
select function_returns('public', 'superadmin_support_get', array['uuid'], 'jsonb', 'support detail returns jsonb');
select function_returns('public', 'superadmin_support_create', array['uuid','uuid','uuid','text','text','text','text','text','text'], 'jsonb', 'support create returns jsonb');
select function_returns('public', 'superadmin_support_reply', array['uuid','uuid','text','bigint'], 'jsonb', 'support reply returns jsonb');
select function_returns('public', 'superadmin_support_set_status', array['uuid','uuid','text','bigint'], 'jsonb', 'support status returns jsonb');
select is(has_table_privilege('anon', 'public.support_sessions', 'select'), false, 'anon cannot read support sessions directly');
select is(has_table_privilege('authenticated', 'public.support_sessions', 'select'), false, 'authenticated cannot read support sessions directly');
select is(has_table_privilege('authenticated', 'public.support_messages', 'insert'), false, 'authenticated cannot write support messages directly');
select is(has_table_privilege('authenticated', 'audit.support_session_actions', 'select'), false, 'authenticated cannot read support actions directly');
select is(has_table_privilege('authenticated', 'public.support_command_receipts', 'select'), false, 'authenticated cannot read support receipts directly');
select is(has_function_privilege('anon', 'public.superadmin_support_list(text,text[],text[],text[],uuid[],boolean,integer,integer)', 'execute'), false, 'anon cannot call support list');
select is(has_function_privilege('authenticated', 'public.superadmin_support_list(text,text[],text[],text[],uuid[],boolean,integer,integer)', 'execute'), true, 'authenticated can call support list through authorization');
select is(has_function_privilege('authenticated', 'public.superadmin_support_create(uuid,uuid,uuid,text,text,text,text,text,text)', 'execute'), true, 'authenticated can call support create through authorization');
select is(has_function_privilege('authenticated', 'public.superadmin_support_set_status(uuid,uuid,text,bigint)', 'execute'), true, 'authenticated can call support status through authorization');

select * from finish();
rollback;
