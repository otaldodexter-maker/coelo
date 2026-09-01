begin;

select plan(23);

select has_function('public', 'superadmin_chat_inbox_v2',
  array['timestamp with time zone','uuid','integer','text','boolean']);
select has_function('public', 'superadmin_chat_thread_v2',
  array['uuid','timestamp with time zone','uuid','integer']);
select has_function('public', 'superadmin_chat_unread_total_v2', array[]::text[]);
select has_function('public', 'superadmin_chat_send_message_v2',
  array['uuid','text','uuid']);
select has_function('public', 'superadmin_chat_mark_read_v2', array['uuid','uuid']);
select has_function('public', 'superadmin_chat_realtime_refresh_v2', array['uuid']);

select has_table('app_private', 'superadmin_internal_chat_receipts');
select has_table('app_private', 'superadmin_internal_chat_command_receipts');
select col_is_null('public', 'messages', 'author_person_id');
select col_not_null('public', 'messages', 'author_kind');

select is(
  (select requires_mfa from public.platform_permissions where code='chat.internal.read'),
  false,
  'reading internal chat does not itself require aal2'
);
select is(
  (select requires_mfa from public.platform_permissions where code='chat.internal.send'),
  true,
  'sending internal chat requires aal2'
);

select ok(not has_table_privilege('anon','public.messages','select'),
  'anon cannot select messages');
select ok(not has_table_privilege('authenticated','app_private.superadmin_internal_chat_receipts','select'),
  'internal read receipts are RPC-only');

select ok(not has_function_privilege('anon',
  'public.superadmin_chat_inbox_v2(timestamptz,uuid,integer,text,boolean)','execute'),
  'anon cannot list internal chat');
select ok(has_function_privilege('authenticated',
  'public.superadmin_chat_inbox_v2(timestamptz,uuid,integer,text,boolean)','execute'),
  'authenticated can invoke the guarded inbox gateway');
select ok(not has_function_privilege('public',
  'public.superadmin_chat_send_message_v2(uuid,text,uuid)','execute'),
  'PUBLIC cannot send internal messages');
select ok(has_function_privilege('authenticated',
  'public.superadmin_chat_send_message_v2(uuid,text,uuid)','execute'),
  'authenticated can invoke the guarded send gateway');

select like(
  pg_get_functiondef('public.superadmin_chat_inbox_v2(timestamptz,uuid,integer,text,boolean)'::regprocedure),
  '%require_superadmin_internal_context%',
  'inbox recomputes internal authorization server-side'
);
select like(
  pg_get_functiondef('public.superadmin_chat_send_message_v2(uuid,text,uuid)'::regprocedure),
  '%chat.internal.send%',
  'send checks the dedicated mutation capability'
);
select like(
  pg_get_functiondef('public.superadmin_chat_send_message_v2(uuid,text,uuid)'::regprocedure),
  '%superadmin_internal_chat_command_receipts%',
  'send is idempotent'
);
select like(
  pg_get_functiondef('public.superadmin_chat_inbox_v2(timestamptz,uuid,integer,text,boolean)'::regprocedure),
  '%has_more%',
  'inbox exposes has_more'
);
select like(
  pg_get_functiondef('public.superadmin_chat_inbox_v2(timestamptz,uuid,integer,text,boolean)'::regprocedure),
  '%total%',
  'inbox exposes total'
);
select like(
  pg_get_functiondef('public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer)'::regprocedure),
  '%scope_institution_id%',
  'thread enforces institution scope'
);

select * from finish();
rollback;
