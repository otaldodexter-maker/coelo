-- Prova do pacote 20260910140000: fixar conversa e bandeira de cor voltam ao
-- Chat, agora persistidas por identidade interna e devolvidas pela inbox.
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

select has_table('app_private', 'superadmin_internal_chat_preferences',
  'the preference lives with the other internal chat state');
select has_function('public', 'superadmin_chat_set_pinned_v2', array['uuid', 'boolean'],
  'pinning is an explicit command');
select has_function('public', 'superadmin_chat_set_flag_v2', array['uuid', 'text'],
  'flagging is an explicit command');
select ok(
  not has_table_privilege('authenticated',
    'app_private.superadmin_internal_chat_preferences', 'select')
  and has_function_privilege('authenticated',
    'public.superadmin_chat_set_pinned_v2(uuid,boolean)', 'execute')
  and not has_function_privilege('anon',
    'public.superadmin_chat_set_pinned_v2(uuid,boolean)', 'execute'),
  'preference state has no direct client path and the command is authenticated only');

insert into public.institution_types(id, code, name, status) values
 ('9d100000-0000-4000-8000-000000000001', 'internal-chat-pref', 'Internal chat preferences', 'active');
insert into public.institutions(id, public_name, slug, status, institution_type_id) values
 ('9d100000-0000-4000-8000-000000000010', 'Colegio Horizonte', 'chat-pref-a', 'active', '9d100000-0000-4000-8000-000000000001'),
 ('9d100000-0000-4000-8000-000000000020', 'Escola Aurora', 'chat-pref-b', 'active', '9d100000-0000-4000-8000-000000000001');
insert into public.people(id, person_type, first_name, last_name, display_name, status) values
 ('9d100000-0000-4000-8000-000000000060', 'adult', 'Marina', 'Souza', 'Marina Souza', 'active');
insert into public.conversations(id, institution_id, scope_kind, conversation_type, title, status) values
 ('9d100000-0000-4000-8000-000000000701', '9d100000-0000-4000-8000-000000000010', 'institution', 'institution', 'Familias - Horizonte', 'active'),
 ('9d100000-0000-4000-8000-000000000702', '9d100000-0000-4000-8000-000000000020', 'institution', 'institution', 'Familias - Aurora', 'active');
-- A conversa 702 e mais recente, entao sem fixar ela vem primeiro para o Owner.
insert into public.messages(id, conversation_id, author_person_id, body_text, message_type, created_at) values
 ('9d100000-0000-4000-8000-000000000801', '9d100000-0000-4000-8000-000000000701', '9d100000-0000-4000-8000-000000000060', 'Bom dia, Horizonte!', 'text', now() - interval '2 hours'),
 ('9d100000-0000-4000-8000-000000000802', '9d100000-0000-4000-8000-000000000702', '9d100000-0000-4000-8000-000000000060', 'Bom dia, Aurora!', 'text', now());

insert into auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
 ('9d100000-0000-4000-8000-000000000101', 'authenticated', 'authenticated', 'chat-pref-owner@invalid.test', now(), now(), now(), '{}', '{}'),
 ('9d100000-0000-4000-8000-000000000102', 'authenticated', 'authenticated', 'chat-pref-scoped@invalid.test', now(), now(), now(), '{}', '{}');
insert into auth.sessions(id, user_id, created_at, updated_at, aal, not_after) values
 ('9d100000-0000-4000-8000-000000000201', '9d100000-0000-4000-8000-000000000101', now(), now(), 'aal2', now() + interval '1 hour'),
 ('9d100000-0000-4000-8000-000000000202', '9d100000-0000-4000-8000-000000000102', now(), now(), 'aal1', now() + interval '1 hour');
-- 20260909173000 passou a exigir uma prova de autenticacao por senha na sessao:
-- sem a linha de AMR, require_superadmin_internal_context recusa com
-- SAI_SESSION_INVALID antes de qualquer regra do chat.
insert into auth.mfa_amr_claims(id, session_id, authentication_method, created_at, updated_at) values
 (gen_random_uuid(), '9d100000-0000-4000-8000-000000000201', 'password', now(), now()),
 (gen_random_uuid(), '9d100000-0000-4000-8000-000000000202', 'password', now(), now());
insert into app_private.superadmin_internal_identities(id) values
 ('9d100000-0000-4000-8000-000000000301'), ('9d100000-0000-4000-8000-000000000302');
insert into app_private.superadmin_internal_auth_links(id, internal_identity_id, auth_user_id) values
 ('9d100000-0000-4000-8000-000000000401', '9d100000-0000-4000-8000-000000000301', '9d100000-0000-4000-8000-000000000101'),
 ('9d100000-0000-4000-8000-000000000402', '9d100000-0000-4000-8000-000000000302', '9d100000-0000-4000-8000-000000000102');
insert into app_private.superadmin_internal_memberships(
 id, internal_identity_id, platform_role_id, scope_kind, scope_institution_id)
select fixture.id, fixture.identity_id, role_record.id,
 fixture.scope_kind::app_private.superadmin_internal_scope_kind, fixture.institution_id
from (values
 ('9d100000-0000-4000-8000-000000000501'::uuid, '9d100000-0000-4000-8000-000000000301'::uuid, 'owner', 'platform', null::uuid),
 ('9d100000-0000-4000-8000-000000000502'::uuid, '9d100000-0000-4000-8000-000000000302'::uuid, 'operations', 'institution', '9d100000-0000-4000-8000-000000000010'::uuid)
) fixture(id, identity_id, role_code, scope_kind, institution_id)
join public.platform_roles role_record on role_record.code = fixture.role_code;

create temporary table chat_preference_results(label text primary key, body jsonb not null);

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', '9d100000-0000-4000-8000-000000000101',
  'session_id', '9d100000-0000-4000-8000-000000000201',
  'aal', 'aal2', 'role', 'authenticated')::text, true);
insert into chat_preference_results values
 ('inbox_before', public.superadmin_chat_inbox_v2(null, null, 30, null, false)),
 ('pin', public.superadmin_chat_set_pinned_v2('9d100000-0000-4000-8000-000000000701', true)),
 ('flag', public.superadmin_chat_set_flag_v2('9d100000-0000-4000-8000-000000000701', 'red')),
 ('flag_invalid', public.superadmin_chat_set_flag_v2('9d100000-0000-4000-8000-000000000701', 'roxo')),
 ('inbox_after', public.superadmin_chat_inbox_v2(null, null, 30, null, false)),
 ('unpin', public.superadmin_chat_set_pinned_v2('9d100000-0000-4000-8000-000000000701', false)),
 ('inbox_unpinned', public.superadmin_chat_inbox_v2(null, null, 30, null, false));

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', '9d100000-0000-4000-8000-000000000102',
  'session_id', '9d100000-0000-4000-8000-000000000202',
  'aal', 'aal1', 'role', 'authenticated')::text, true);
insert into chat_preference_results values
 ('scoped_cross_tenant', public.superadmin_chat_set_pinned_v2('9d100000-0000-4000-8000-000000000702', true)),
 ('scoped_inbox', public.superadmin_chat_inbox_v2(null, null, 30, null, false));

-- Sem preferencia, a conversa mais recente lidera.
select is(
  (select body #>> '{data,items,0,conversation_id}'
   from chat_preference_results where label = 'inbox_before'),
  '9d100000-0000-4000-8000-000000000702',
  'without a preference the inbox is ordered by activity');
select ok(
  (select body #>> '{data,items,0,pinned_at}' is null
     and body #>> '{data,items,0,flag}' = 'none'
   from chat_preference_results where label = 'inbox_before'),
  'the inbox always projects the preference fields, even when empty');
select ok(
  (select body #>> '{data,items,0,conversation_id}' = '9d100000-0000-4000-8000-000000000701'
     and body #>> '{data,items,0,pinned_at}' is not null
     and body #>> '{data,items,0,flag}' = 'red'
   from chat_preference_results where label = 'inbox_after'),
  'the pinned conversation leads the inbox and carries its flag');
select is(
  (select body #>> '{error,code}' from chat_preference_results where label = 'flag_invalid'),
  'CHAT_INVALID_INPUT', 'an unsupported flag is refused by the server');
select is(
  (select body #>> '{error,code}' from chat_preference_results where label = 'scoped_cross_tenant'),
  'CHAT_NOT_FOUND',
  'an institution-scoped actor cannot pin another tenant conversation, and the id does not enumerate');

-- Desfixar devolve a ordem por atividade, e a bandeira sobrevive.
select ok(
  (select body #>> '{data,items,0,conversation_id}' = '9d100000-0000-4000-8000-000000000702'
   from chat_preference_results where label = 'inbox_unpinned')
  and (select count(*) from app_private.superadmin_internal_chat_preferences
       where internal_identity_id = '9d100000-0000-4000-8000-000000000301'
         and flag = 'red' and pinned_at is null) = 1,
  'unpinning restores the activity order and keeps the flag');

reset role;
select * from finish();
rollback;
