begin;

select plan(43);

select is(
  app_private.parse_chat_realtime_topic(
    'chat:conversation:cf000000-0000-4000-8000-000000000001'
  ),
  'cf000000-0000-4000-8000-000000000001'::uuid,
  'canonical lowercase conversation topic parses'
);
select is(app_private.parse_chat_realtime_topic(null), null::uuid, 'null topic fails closed');
select is(app_private.parse_chat_realtime_topic(''), null::uuid, 'empty topic fails closed');
select is(app_private.parse_chat_realtime_topic('   '), null::uuid, 'blank topic fails closed');
select is(app_private.parse_chat_realtime_topic('chat:conversation:'), null::uuid, 'truncated topic fails closed');
select is(app_private.parse_chat_realtime_topic('chat:conversation:not-a-uuid'), null::uuid, 'invalid UUID fails closed');
select is(
  app_private.parse_chat_realtime_topic('chat:conversation:00000000-0000-0000-0000-000000000000'),
  null::uuid,
  'nil UUID fails closed'
);
select is(
  app_private.parse_chat_realtime_topic('CHAT:CONVERSATION:cf000000-0000-4000-8000-000000000001'),
  null::uuid,
  'noncanonical prefix case fails closed'
);
select is(
  app_private.parse_chat_realtime_topic('chat:conversation:CF000000-0000-4000-8000-000000000001'),
  null::uuid,
  'uppercase UUID fails closed'
);
select is(
  app_private.parse_chat_realtime_topic('chat:conversation:cf000000-0000-4000-8000-000000000001:extra'),
  null::uuid,
  'topic suffix fails closed'
);
select is(
  app_private.parse_chat_realtime_topic('prefix:chat:conversation:cf000000-0000-4000-8000-000000000001'),
  null::uuid,
  'topic prefix fails closed'
);

insert into auth.users(id, aud, role, email, created_at, updated_at)
values
  ('ca100000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'chat-realtime-a@coelo.invalid', now(), now()),
  ('ca100000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'chat-realtime-b@coelo.invalid', now(), now());

insert into public.people(id, person_type, first_name, last_name, display_name)
values
  ('cb100000-0000-4000-8000-000000000001', 'adult', 'Realtime', 'A', 'Realtime A'),
  ('cb100000-0000-4000-8000-000000000002', 'adult', 'Realtime', 'B', 'Realtime B');

insert into public.person_auth_links(id, person_id, auth_user_id, status)
values
  ('cc100000-0000-4000-8000-000000000001', 'cb100000-0000-4000-8000-000000000001', 'ca100000-0000-4000-8000-000000000001', 'active'),
  ('cc100000-0000-4000-8000-000000000002', 'cb100000-0000-4000-8000-000000000002', 'ca100000-0000-4000-8000-000000000002', 'active');

insert into public.institutions(id, public_name, legal_name, slug, status)
values
  ('cd100000-0000-4000-8000-000000000001', 'Realtime A', 'Realtime A LTDA', 'chat-realtime-a', 'active'),
  ('cd100000-0000-4000-8000-000000000002', 'Realtime B', 'Realtime B LTDA', 'chat-realtime-b', 'active');

insert into public.institution_memberships(id, person_id, institution_id, role_code, status)
values
  ('ce100000-0000-4000-8000-000000000001', 'cb100000-0000-4000-8000-000000000001', 'cd100000-0000-4000-8000-000000000001', 'teacher', 'active'),
  ('ce100000-0000-4000-8000-000000000002', 'cb100000-0000-4000-8000-000000000002', 'cd100000-0000-4000-8000-000000000002', 'teacher', 'active');

insert into public.conversations(id, institution_id, scope_kind, conversation_type, title, created_by)
values
  ('cf100000-0000-4000-8000-000000000001', 'cd100000-0000-4000-8000-000000000001', 'institution', 'direct', 'Realtime tenant A', 'cb100000-0000-4000-8000-000000000001'),
  ('cf100000-0000-4000-8000-000000000002', 'cd100000-0000-4000-8000-000000000002', 'institution', 'direct', 'Realtime tenant B', 'cb100000-0000-4000-8000-000000000002');

insert into public.conversation_participants(
  id, conversation_id, person_id, membership_id, experience_kind, role_snapshot, status
) values
  ('d0100000-0000-4000-8000-000000000001', 'cf100000-0000-4000-8000-000000000001', 'cb100000-0000-4000-8000-000000000001', 'ce100000-0000-4000-8000-000000000001', 'professional', 'teacher', 'active'),
  ('d0100000-0000-4000-8000-000000000002', 'cf100000-0000-4000-8000-000000000002', 'cb100000-0000-4000-8000-000000000002', 'ce100000-0000-4000-8000-000000000002', 'professional', 'teacher', 'active');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'ca100000-0000-4000-8000-000000000001', true);
select is(
  app_private.can_receive_chat_realtime_broadcast(
    'chat:conversation:cf100000-0000-4000-8000-000000000001'
  ),
  true,
  'authorized professional can receive its conversation invalidation'
);
select is(
  app_private.can_receive_chat_realtime_broadcast(
    'chat:conversation:cf100000-0000-4000-8000-000000000002'
  ),
  false,
  'tenant A cannot receive tenant B invalidation'
);
select is(
  app_private.can_receive_chat_realtime_broadcast('chat:conversation:not-a-uuid'),
  false,
  'malformed topic is denied without leaking an error'
);
reset role;

insert into public.messages(
  id, conversation_id, author_person_id, body_text, message_type, status
) values (
  'd1100000-0000-4000-8000-000000000001',
  'cf100000-0000-4000-8000-000000000001',
  'cb100000-0000-4000-8000-000000000001',
  'Realtime invalidation fixture', 'text', 'active'
);
select is(
  (
    select count(*)
    from realtime.messages
    where topic = 'chat:conversation:cf100000-0000-4000-8000-000000000001'
      and extension = 'broadcast'
      and event = 'invalidate'
  ),
  1::bigint,
  'message mutation emits exactly one private invalidation'
);
select is(
  (
    select count(*)
    from realtime.messages
    where topic = 'chat:conversation:cf100000-0000-4000-8000-000000000001'
      and extension = 'broadcast'
      and event = 'invalidate'
      and payload = '{}'::jsonb
      and private
  ),
  1::bigint,
  'message invalidation has empty payload and private flag'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'ca100000-0000-4000-8000-000000000001', true);
select set_config('realtime.topic', 'chat:conversation:cf100000-0000-4000-8000-000000000001', true);
select is(
  (select count(*) from realtime.messages where extension = 'broadcast'),
  1::bigint,
  'authorized topic passes the realtime.messages SELECT policy'
);
select set_config('realtime.topic', 'chat:conversation:cf100000-0000-4000-8000-000000000002', true);
select is(
  (select count(*) from realtime.messages where extension = 'broadcast'),
  0::bigint,
  'cross-tenant topic is denied by the realtime.messages SELECT policy'
);
select throws_ok(
  $$insert into realtime.messages(topic, extension, payload, event, private)
    values (
      'chat:conversation:cf100000-0000-4000-8000-000000000001',
      'broadcast', '{}'::jsonb, 'invalidate', true
    )$$,
  '42501', null,
  'authenticated cannot publish Broadcast through realtime.messages'
);
reset role;

set local role anon;
select set_config('realtime.topic', 'chat:conversation:cf100000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$insert into realtime.messages(topic, extension, payload, event, private)
    values (
      'chat:conversation:cf100000-0000-4000-8000-000000000001',
      'broadcast', '{}'::jsonb, 'invalidate', true
    )$$,
  '42501', null,
  'anon cannot publish Broadcast through realtime.messages'
);
reset role;

insert into public.message_receipts(
  id, message_id, person_id, read_at
) values (
  'd1200000-0000-4000-8000-000000000001',
  'd1100000-0000-4000-8000-000000000001',
  'cb100000-0000-4000-8000-000000000001', null
);
select is(
  (
    select count(*)
    from realtime.messages
    where topic = 'chat:conversation:cf100000-0000-4000-8000-000000000001'
      and event = 'invalidate'
  ),
  2::bigint,
  'receipt insert emits one additional invalidation'
);
update public.message_receipts
set read_at = read_at
where id = 'd1200000-0000-4000-8000-000000000001';
select is(
  (
    select count(*)
    from realtime.messages
    where topic = 'chat:conversation:cf100000-0000-4000-8000-000000000001'
      and event = 'invalidate'
  ),
  2::bigint,
  'receipt no-op emits zero invalidations'
);
update public.message_receipts
set read_at = now()
where id = 'd1200000-0000-4000-8000-000000000001';
select is(
  (
    select count(*)
    from realtime.messages
    where topic = 'chat:conversation:cf100000-0000-4000-8000-000000000001'
      and event = 'invalidate'
  ),
  3::bigint,
  'receipt state change emits one additional invalidation'
);

insert into public.chat_attachment_metadata(
  id, conversation_id, message_id, provider, object_key, file_name,
  content_type, byte_size, sha256, upload_status, created_by_person_id
) values (
  'd1700000-0000-4000-8000-000000000001',
  'cf100000-0000-4000-8000-000000000001', null,
  'supabase_storage',
  'chat/cf100000-0000-4000-8000-000000000001/d1700000-0000-4000-8000-000000000001.png',
  'realtime.png', 'image/png', 8, repeat('a', 64), 'pending',
  'cb100000-0000-4000-8000-000000000001'
);
update public.chat_attachment_metadata
set upload_status = upload_status
where id = 'd1700000-0000-4000-8000-000000000001';
select is(
  (
    select count(*)
    from realtime.messages
    where topic = 'chat:conversation:cf100000-0000-4000-8000-000000000001'
      and event = 'invalidate'
  ),
  3::bigint,
  'attachment no-op emits zero invalidations'
);
update public.chat_attachment_metadata
set upload_status = 'ready'
where id = 'd1700000-0000-4000-8000-000000000001';
select is(
  (
    select count(*)
    from realtime.messages
    where topic = 'chat:conversation:cf100000-0000-4000-8000-000000000001'
      and event = 'invalidate'
      and payload = '{}'::jsonb
      and private
  ),
  4::bigint,
  'attachment lifecycle change emits one private empty invalidation'
);

savepoint chat_realtime_rollback_probe;
insert into public.messages(
  id, conversation_id, author_person_id, body_text, message_type, status
) values (
  'd1100000-0000-4000-8000-000000000002',
  'cf100000-0000-4000-8000-000000000001',
  'cb100000-0000-4000-8000-000000000001',
  'Rollback probe', 'text', 'active'
);
rollback to savepoint chat_realtime_rollback_probe;
select is(
  (
    select count(*)
    from realtime.messages
    where topic = 'chat:conversation:cf100000-0000-4000-8000-000000000001'
      and event = 'invalidate'
  ),
  4::bigint,
  'rolled back mutation persists zero Broadcast rows'
);
select ok(
  position('exception' in lower(pg_get_functiondef(
    'app_private.emit_chat_realtime_invalidation()'::regprocedure
  ))) > 0
    and position('raise warning' in lower(pg_get_functiondef(
      'app_private.emit_chat_realtime_invalidation()'::regprocedure
    ))) > 0,
  'Realtime failure is observable without aborting the Chat mutation'
);

update public.institution_memberships
set status = 'inactive', revoked_at = now()
where id = 'ce100000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'ca100000-0000-4000-8000-000000000001', true);
select is(
  app_private.can_receive_chat_realtime_broadcast(
    'chat:conversation:cf100000-0000-4000-8000-000000000001'
  ),
  false,
  'revoked membership cannot receive invalidations on a new authorization'
);
reset role;

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'realtime'
      and tablename = 'messages'
      and policyname = 'chat_private_broadcast_receive'
      and cmd = 'SELECT'
      and roles = array['authenticated']::name[]
  ),
  1::bigint,
  'one authenticated SELECT policy protects private chat Broadcast'
);
select is(
  (select count(*) from pg_policies where schemaname = 'realtime' and tablename = 'messages' and cmd = 'INSERT'),
  0::bigint,
  'no client INSERT policy exists on realtime.messages'
);
select is(
  (select count(*) from pg_policies where schemaname = 'realtime' and tablename = 'messages' and ('anon' = any(roles) or 'public' = any(roles))),
  0::bigint,
  'anon and PUBLIC have no realtime.messages policy'
);
select ok(
  position('extension = ''broadcast''' in pg_get_expr(policy.polqual, policy.polrelid)) > 0,
  'receive policy allowlists Broadcast extension'
)
from pg_policy policy
where policy.polname = 'chat_private_broadcast_receive'
  and policy.polrelid = 'realtime.messages'::regclass;
select ok(
  position('can_receive_chat_realtime_broadcast' in pg_get_expr(policy.polqual, policy.polrelid)) > 0,
  'receive policy delegates topic authorization server-side'
)
from pg_policy policy
where policy.polname = 'chat_private_broadcast_receive'
  and policy.polrelid = 'realtime.messages'::regclass;

select is(has_function_privilege('authenticated', 'app_private.can_receive_chat_realtime_broadcast(text)', 'EXECUTE'), true, 'authenticated can execute only the policy wrapper');
select is(has_function_privilege('anon', 'app_private.can_receive_chat_realtime_broadcast(text)', 'EXECUTE'), false, 'anon cannot execute policy wrapper');
select is(has_function_privilege('authenticated', 'app_private.parse_chat_realtime_topic(text)', 'EXECUTE'), false, 'authenticated cannot execute private parser directly');
select is(has_function_privilege('authenticated', 'app_private.emit_chat_realtime_invalidation()', 'EXECUTE'), false, 'authenticated cannot execute emitter');
select is(has_function_privilege('anon', 'app_private.emit_chat_realtime_invalidation()', 'EXECUTE'), false, 'anon cannot execute emitter');

select is(
  (select count(*) from pg_trigger where tgname = 'chat_message_broadcast_invalidation' and not tgisinternal),
  1::bigint,
  'message insert invalidation trigger exists'
);
select is(
  (select count(*) from pg_trigger where tgname = 'chat_receipt_broadcast_invalidation' and not tgisinternal),
  1::bigint,
  'receipt change invalidation trigger exists'
);
select is(
  (select count(*) from pg_trigger where tgname = 'chat_attachment_broadcast_invalidation' and not tgisinternal),
  1::bigint,
  'attachment lifecycle invalidation trigger exists'
);
select ok(
  position('''{}''::jsonb' in pg_get_functiondef('app_private.emit_chat_realtime_invalidation()'::regprocedure)) > 0
    and position('''invalidate''' in pg_get_functiondef('app_private.emit_chat_realtime_invalidation()'::regprocedure)) > 0
    and position('realtime.send' in pg_get_functiondef('app_private.emit_chat_realtime_invalidation()'::regprocedure)) > 0,
  'emitter uses empty payload, fixed event and server-side realtime.send'
);
select is(
  (select count(*) from pg_policies where schemaname = 'realtime' and tablename = 'messages'),
  1::bigint,
  'no Presence, public or additional Realtime policy is introduced'
);

select * from finish();
rollback;
