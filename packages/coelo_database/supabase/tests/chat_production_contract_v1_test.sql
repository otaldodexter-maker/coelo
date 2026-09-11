-- Prova do pacote 20260910240000: contrato de producao do chat contextual
-- sobre a baseline. Realm de pessoas: participante envia, le e marca; quem
-- nao participa nem tem permissao contextual nao enxerga a conversa.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

select has_table('public', 'chat_attachment_metadata', 'attachment metadata table exists');
select has_table('app_private', 'chat_command_receipts', 'idempotency receipts table exists');
select has_function('app_private', 'can_access_chat_conversation', array['uuid', 'boolean']);
select has_function('public', 'chat_inbox_page',
  array['timestamp with time zone', 'uuid', 'integer', 'text', 'boolean']);
select has_function('public', 'chat_thread_page',
  array['uuid', 'timestamp with time zone', 'uuid', 'integer']);
select has_function('public', 'chat_send_message', array['uuid', 'text', 'uuid', 'uuid[]']);
select has_function('public', 'chat_mark_read', array['uuid', 'uuid']);
select has_function('public', 'chat_realtime_refresh', array['uuid']);
select has_function('public', 'chat_unread_total', array[]::text[]);

select ok(
  not has_table_privilege('anon', 'public.conversations', 'select')
  and not has_table_privilege('anon', 'public.messages', 'select')
  and not has_table_privilege('anon', 'public.message_receipts', 'select')
  and not has_table_privilege('anon', 'public.message_edits', 'select')
  and not has_table_privilege('anon', 'public.chat_attachment_metadata', 'select')
  and not has_table_privilege('authenticated', 'app_private.chat_command_receipts', 'select'),
  'anon has no path to chat tables and idempotency state is server-only');
select ok(
  has_function_privilege('authenticated', 'public.chat_send_message(uuid,text,uuid,uuid[])', 'execute')
  and not has_function_privilege('anon', 'public.chat_send_message(uuid,text,uuid,uuid[])', 'execute')
  and not has_function_privilege('anon', 'public.chat_inbox_page(timestamptz,uuid,integer,text,boolean)', 'execute'),
  'only authenticated can invoke the contextual RPCs');

-- Fixture: uma instituicao, dois participantes (familia), uma pessoa de fora.
insert into public.institution_types(id, code, name, status) values
 ('9e100000-0000-4000-8000-000000000001', 'chat-contract', 'Chat contract', 'active');
insert into public.institutions(id, public_name, slug, status, institution_type_id) values
 ('9e100000-0000-4000-8000-000000000010', 'Colegio Horizonte', 'chat-contract-a', 'active', '9e100000-0000-4000-8000-000000000001');
insert into public.people(id, person_type, first_name, last_name, display_name, status) values
 ('9e100000-0000-4000-8000-000000000061', 'adult', 'Marina', 'Souza', 'Marina Souza', 'active'),
 ('9e100000-0000-4000-8000-000000000062', 'adult', 'Paulo', 'Lima', 'Paulo Lima', 'active'),
 ('9e100000-0000-4000-8000-000000000063', 'adult', 'Rita', 'Nunes', 'Rita Nunes', 'active');
insert into auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
 ('9e100000-0000-4000-8000-000000000101', 'authenticated', 'authenticated', 'chat-marina@invalid.test', now(), now(), now(), '{}', '{}'),
 ('9e100000-0000-4000-8000-000000000102', 'authenticated', 'authenticated', 'chat-paulo@invalid.test', now(), now(), now(), '{}', '{}'),
 ('9e100000-0000-4000-8000-000000000103', 'authenticated', 'authenticated', 'chat-rita@invalid.test', now(), now(), now(), '{}', '{}');
insert into public.person_auth_links(person_id, auth_user_id) values
 ('9e100000-0000-4000-8000-000000000061', '9e100000-0000-4000-8000-000000000101'),
 ('9e100000-0000-4000-8000-000000000062', '9e100000-0000-4000-8000-000000000102'),
 ('9e100000-0000-4000-8000-000000000063', '9e100000-0000-4000-8000-000000000103');
insert into public.conversations(id, institution_id, scope_kind, conversation_type, title, status) values
 ('9e100000-0000-4000-8000-000000000701', '9e100000-0000-4000-8000-000000000010', 'institution', 'institution', 'Familias - Horizonte', 'active');
insert into public.conversation_participants(conversation_id, person_id, experience_kind, role_snapshot) values
 ('9e100000-0000-4000-8000-000000000701', '9e100000-0000-4000-8000-000000000061', 'family', 'responsavel'),
 ('9e100000-0000-4000-8000-000000000701', '9e100000-0000-4000-8000-000000000062', 'family', 'responsavel');

create temporary table contract_results(label text primary key, body jsonb not null);
grant all on contract_results to authenticated;

-- Marina envia (e repete o mesmo request id).
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', '9e100000-0000-4000-8000-000000000101', 'role', 'authenticated')::text, true);
insert into contract_results
select 'send', to_jsonb(sent) from public.chat_send_message(
  '9e100000-0000-4000-8000-000000000701', 'Bom dia, familias!',
  '9e100000-0000-4000-8000-000000000901') sent;
insert into contract_results
select 'replay', to_jsonb(sent) from public.chat_send_message(
  '9e100000-0000-4000-8000-000000000701', 'Bom dia, familias!',
  '9e100000-0000-4000-8000-000000000901') sent;
insert into contract_results
select 'inbox_author', jsonb_agg(to_jsonb(row)) from public.chat_inbox_page() row;

-- Paulo ve nao lido, le a thread e marca como lida.
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', '9e100000-0000-4000-8000-000000000102', 'role', 'authenticated')::text, true);
insert into contract_results
select 'unread_before', jsonb_build_object('total_unread', total_unread) from public.chat_unread_total();
insert into contract_results
select 'thread', jsonb_agg(to_jsonb(row)) from public.chat_thread_page(
  '9e100000-0000-4000-8000-000000000701') row;
insert into contract_results
select 'mark_read', to_jsonb(row) from public.chat_mark_read(
  '9e100000-0000-4000-8000-000000000701') row;
insert into contract_results
select 'unread_after', jsonb_build_object('total_unread', total_unread) from public.chat_unread_total();
insert into contract_results
select 'refresh', to_jsonb(row) from public.chat_realtime_refresh(
  '9e100000-0000-4000-8000-000000000701') row;

-- Rita nao participa: nada aparece e o envio e negado.
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', '9e100000-0000-4000-8000-000000000103', 'role', 'authenticated')::text, true);
insert into contract_results
select 'outsider_inbox', coalesce(jsonb_agg(to_jsonb(row)), '[]'::jsonb) from public.chat_inbox_page() row;
insert into contract_results
select 'outsider_thread', coalesce(jsonb_agg(to_jsonb(row)), '[]'::jsonb) from public.chat_thread_page(
  '9e100000-0000-4000-8000-000000000701') row;
select throws_ok(
  $$select * from public.chat_send_message('9e100000-0000-4000-8000-000000000701',
    'Intrusa', '9e100000-0000-4000-8000-000000000902')$$,
  '42501', 'conversation is not writable',
  'a person outside the conversation cannot send');
reset role;

select ok((select body ->> 'replayed' = 'false' and body ->> 'message_id' is not null
  from contract_results where label = 'send'), 'participant sends a message');
select is((select body ->> 'message_id' from contract_results where label = 'replay'),
  (select body ->> 'message_id' from contract_results where label = 'send'),
  'same idempotency key replays the same message');
select is((select count(*) from public.messages where body_text = 'Bom dia, familias!'), 1::bigint,
  'idempotent send persists exactly once');
select ok((select jsonb_array_length(body) = 1 and body #>> '{0,unread_count}' = '0'
  from contract_results where label = 'inbox_author'),
  'author inbox lists the conversation without counting own message as unread');
select is((select body ->> 'total_unread' from contract_results where label = 'unread_before'), '1',
  'recipient sees one unread message');
select ok((select body #>> '{0,author_name}' = 'Marina Souza' and body #>> '{0,is_mine}' = 'false'
  from contract_results where label = 'thread'),
  'thread projects the author display name through the scoped helper');
select ok((select (body ->> 'updated_count')::integer = 1 from contract_results where label = 'mark_read')
  and (select body ->> 'total_unread' from contract_results where label = 'unread_after') = '0'
  and (select body ->> 'unread_count' from contract_results where label = 'refresh') = '0',
  'mark read persists the receipt and clears unread across the readers');
select ok((select jsonb_array_length(body) = 0 from contract_results where label = 'outsider_inbox')
  and (select jsonb_array_length(body) = 0 from contract_results where label = 'outsider_thread'),
  'a person outside the conversation sees nothing');

select * from finish();
rollback;
