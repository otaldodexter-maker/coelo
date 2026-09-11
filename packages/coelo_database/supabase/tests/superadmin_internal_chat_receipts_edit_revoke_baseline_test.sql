-- Prova do pacote 20260910240200 (recibos, edicao e revogacao do chat interno
-- sobre a baseline). Sessoes AAL1: MFA fora do MVP (ADR 0034, D12).
begin;
create extension if not exists pgtap with schema extensions;
select plan(36);

-- Estruturais: contrato publico das duas novas acoes do realm interno.
select has_function('public','superadmin_chat_edit_message_v2',
 array['uuid','uuid','text','uuid']);
select has_function('public','superadmin_chat_revoke_message_v2',
 array['uuid','uuid','uuid']);
select has_table('app_private','superadmin_internal_chat_message_edits','internal edit trail exists');
select is((select requires_mfa from public.platform_permissions where code='chat.internal.manage'),
 false,'managing own internal messages requires no second factor in the MVP');
select ok((select exists(select 1 from public.platform_role_permissions role_permission
  join public.platform_roles role_record on role_record.id=role_permission.role_id
  join public.platform_permissions permission_record on permission_record.id=role_permission.permission_id
  where role_record.code='owner' and permission_record.code='chat.internal.manage'
   and role_permission.effect='allow' and role_permission.status='active'
   and role_permission.revoked_at is null)),
 'owner holds the chat.internal.manage capability');
select ok(has_function_privilege('authenticated','public.superadmin_chat_edit_message_v2(uuid,uuid,text,uuid)','execute')
 and not has_function_privilege('anon','public.superadmin_chat_edit_message_v2(uuid,uuid,text,uuid)','execute'),
 'only authenticated can invoke the edit gateway');
select ok(not has_function_privilege('public','public.superadmin_chat_edit_message_v2(uuid,uuid,text,uuid)','execute'),
 'PUBLIC cannot invoke the edit gateway');
select ok(has_function_privilege('authenticated','public.superadmin_chat_revoke_message_v2(uuid,uuid,uuid)','execute')
 and not has_function_privilege('anon','public.superadmin_chat_revoke_message_v2(uuid,uuid,uuid)','execute'),
 'only authenticated can invoke the revoke gateway');
select ok(not has_function_privilege('public','public.superadmin_chat_revoke_message_v2(uuid,uuid,uuid)','execute'),
 'PUBLIC cannot invoke the revoke gateway');
select ok(not has_table_privilege('authenticated','app_private.superadmin_internal_chat_message_edits','select')
 and not has_table_privilege('anon','app_private.superadmin_internal_chat_message_edits','select')
 and (select relrowsecurity and relforcerowsecurity from pg_class
   where oid='app_private.superadmin_internal_chat_message_edits'::regclass),
 'internal edit trail is RPC-only under forced RLS');

-- Fixtures: duas instituicoes, cinco identidades internas e mensagens do realm interno.
insert into public.institution_types(id,code,name,status) values
 ('9c110000-0000-4000-8000-000000000001','internal-chat-manage','Internal chat manage','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9c110000-0000-4000-8000-000000000010','Colégio Horizonte','chat-manage-a','active','9c110000-0000-4000-8000-000000000001'),
 ('9c110000-0000-4000-8000-000000000020','Escola Aurora','chat-manage-b','active','9c110000-0000-4000-8000-000000000001');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9c110000-0000-4000-8000-000000000060','adult','Marina','Souza','Marina Souza','active');
insert into public.conversations(id,institution_id,scope_kind,conversation_type,title,status) values
 ('9c110000-0000-4000-8000-000000000701','9c110000-0000-4000-8000-000000000010','institution','institution','Famílias - Horizonte','active'),
 ('9c110000-0000-4000-8000-000000000702','9c110000-0000-4000-8000-000000000020','institution','institution','Famílias - Aurora','active');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9c110000-0000-4000-8000-000000000101','authenticated','authenticated','manage-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c110000-0000-4000-8000-000000000102','authenticated','authenticated','manage-operations@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c110000-0000-4000-8000-000000000103','authenticated','authenticated','manage-owner-other@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c110000-0000-4000-8000-000000000106','authenticated','authenticated','manage-owner-scoped@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9c110000-0000-4000-8000-000000000201','9c110000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour'),
 ('9c110000-0000-4000-8000-000000000202','9c110000-0000-4000-8000-000000000102',now(),now(),'aal1',now()+interval '1 hour'),
 ('9c110000-0000-4000-8000-000000000203','9c110000-0000-4000-8000-000000000103',now(),now(),'aal1',now()+interval '1 hour'),
 ('9c110000-0000-4000-8000-000000000206','9c110000-0000-4000-8000-000000000106',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('9c110000-0000-4000-8000-000000000301'),('9c110000-0000-4000-8000-000000000302'),
 ('9c110000-0000-4000-8000-000000000303'),('9c110000-0000-4000-8000-000000000305'),
 ('9c110000-0000-4000-8000-000000000306');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9c110000-0000-4000-8000-000000000401','9c110000-0000-4000-8000-000000000301','9c110000-0000-4000-8000-000000000101'),
 ('9c110000-0000-4000-8000-000000000402','9c110000-0000-4000-8000-000000000302','9c110000-0000-4000-8000-000000000102'),
 ('9c110000-0000-4000-8000-000000000403','9c110000-0000-4000-8000-000000000303','9c110000-0000-4000-8000-000000000103'),
 ('9c110000-0000-4000-8000-000000000406','9c110000-0000-4000-8000-000000000306','9c110000-0000-4000-8000-000000000106');
insert into app_private.superadmin_internal_memberships(
 id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,
 fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from(values
 ('9c110000-0000-4000-8000-000000000501'::uuid,'9c110000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('9c110000-0000-4000-8000-000000000502'::uuid,'9c110000-0000-4000-8000-000000000302'::uuid,'operations','institution','9c110000-0000-4000-8000-000000000010'::uuid),
 ('9c110000-0000-4000-8000-000000000503'::uuid,'9c110000-0000-4000-8000-000000000303'::uuid,'owner','platform',null::uuid),
 ('9c110000-0000-4000-8000-000000000505'::uuid,'9c110000-0000-4000-8000-000000000305'::uuid,'owner','platform',null::uuid),
 ('9c110000-0000-4000-8000-000000000506'::uuid,'9c110000-0000-4000-8000-000000000306'::uuid,'owner','institution','9c110000-0000-4000-8000-000000000010'::uuid)
)fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;

insert into public.messages(id,conversation_id,author_person_id,body_text,message_type) values
 ('9c110000-0000-4000-8000-000000000801','9c110000-0000-4000-8000-000000000701','9c110000-0000-4000-8000-000000000060','Bom dia, Horizonte!','text'),
 ('9c110000-0000-4000-8000-000000000802','9c110000-0000-4000-8000-000000000702','9c110000-0000-4000-8000-000000000060','Bom dia, Aurora!','text');
insert into public.messages(id,conversation_id,author_person_id,body_text,message_type,
 author_kind,author_internal_identity_id,author_internal_membership_id) values
 ('9c110000-0000-4000-8000-000000000810','9c110000-0000-4000-8000-000000000701',null,'Aviso interno original','text',
  'superadmin_internal','9c110000-0000-4000-8000-000000000301','9c110000-0000-4000-8000-000000000501'),
 ('9c110000-0000-4000-8000-000000000811','9c110000-0000-4000-8000-000000000701',null,'Aviso de outra identidade','text',
  'superadmin_internal','9c110000-0000-4000-8000-000000000305','9c110000-0000-4000-8000-000000000505'),
 ('9c110000-0000-4000-8000-000000000812','9c110000-0000-4000-8000-000000000702',null,'Aviso interno da Aurora','text',
  'superadmin_internal','9c110000-0000-4000-8000-000000000301','9c110000-0000-4000-8000-000000000501');
insert into public.messages(id,conversation_id,author_person_id,body_text,message_type,
 author_kind,author_internal_identity_id,author_internal_membership_id,created_at,updated_at) values
 ('9c110000-0000-4000-8000-000000000813','9c110000-0000-4000-8000-000000000701',null,'Aviso interno antigo','text',
  'superadmin_internal','9c110000-0000-4000-8000-000000000301','9c110000-0000-4000-8000-000000000501',
  now()-interval '2 hours',now()-interval '2 hours');

create temporary table chat_results(label text primary key,body jsonb not null);

-- Owner de plataforma (aal1): le a thread, edita, repete a edicao e revoga a propria mensagem.
select set_config('request.jwt.claims',jsonb_build_object('sub','9c110000-0000-4000-8000-000000000101','session_id','9c110000-0000-4000-8000-000000000201','aal','aal1','role','authenticated')::text,true);
insert into chat_results values('thread_before',
 public.superadmin_chat_thread_v2('9c110000-0000-4000-8000-000000000701',null,null,50));
insert into chat_results values('edit_ok',
 public.superadmin_chat_edit_message_v2('9c110000-0000-4000-8000-000000000701',
  '9c110000-0000-4000-8000-000000000810','Aviso interno corrigido','9c110000-0000-4000-8000-000000000901'));
insert into chat_results values('edit_replay',
 public.superadmin_chat_edit_message_v2('9c110000-0000-4000-8000-000000000701',
  '9c110000-0000-4000-8000-000000000810','Aviso interno corrigido','9c110000-0000-4000-8000-000000000901'));
insert into chat_results values('thread_after_edit',
 public.superadmin_chat_thread_v2('9c110000-0000-4000-8000-000000000701',null,null,50));
insert into chat_results values('edit_not_author',
 public.superadmin_chat_edit_message_v2('9c110000-0000-4000-8000-000000000701',
  '9c110000-0000-4000-8000-000000000811','Tentativa de terceiro','9c110000-0000-4000-8000-000000000903'));
insert into chat_results values('edit_window_closed',
 public.superadmin_chat_edit_message_v2('9c110000-0000-4000-8000-000000000701',
  '9c110000-0000-4000-8000-000000000813','Tarde demais','9c110000-0000-4000-8000-000000000910'));

-- Identidade sem chat.internal.manage e outro owner (nao autor) nao alteram nada.
select set_config('request.jwt.claims',jsonb_build_object('sub','9c110000-0000-4000-8000-000000000102','session_id','9c110000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
insert into chat_results values('edit_denied_role',
 public.superadmin_chat_edit_message_v2('9c110000-0000-4000-8000-000000000701',
  '9c110000-0000-4000-8000-000000000810','Sem capacidade','9c110000-0000-4000-8000-000000000906'));
insert into chat_results values('unread_before',public.superadmin_chat_unread_total_v2());

select set_config('request.jwt.claims',jsonb_build_object('sub','9c110000-0000-4000-8000-000000000103','session_id','9c110000-0000-4000-8000-000000000203','aal','aal1','role','authenticated')::text,true);
insert into chat_results values('edit_denied_other_owner',
 public.superadmin_chat_edit_message_v2('9c110000-0000-4000-8000-000000000701',
  '9c110000-0000-4000-8000-000000000810','Outro owner','9c110000-0000-4000-8000-000000000907'));

-- Revogacao pelo autor e nova tentativa com outro request id.
select set_config('request.jwt.claims',jsonb_build_object('sub','9c110000-0000-4000-8000-000000000101','session_id','9c110000-0000-4000-8000-000000000201','aal','aal1','role','authenticated')::text,true);
insert into chat_results values('revoke_ok',
 public.superadmin_chat_revoke_message_v2('9c110000-0000-4000-8000-000000000701',
  '9c110000-0000-4000-8000-000000000810','9c110000-0000-4000-8000-000000000904'));
insert into chat_results values('thread_after_revoke',
 public.superadmin_chat_thread_v2('9c110000-0000-4000-8000-000000000701',null,null,50));
insert into chat_results values('revoke_again',
 public.superadmin_chat_revoke_message_v2('9c110000-0000-4000-8000-000000000701',
  '9c110000-0000-4000-8000-000000000810','9c110000-0000-4000-8000-000000000905'));

select set_config('request.jwt.claims',jsonb_build_object('sub','9c110000-0000-4000-8000-000000000102','session_id','9c110000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
insert into chat_results values('unread_after',public.superadmin_chat_unread_total_v2());

-- Isolamento: owner escopado a instituicao A nao alcanca a mensagem da instituicao B.
select set_config('request.jwt.claims',jsonb_build_object('sub','9c110000-0000-4000-8000-000000000106','session_id','9c110000-0000-4000-8000-000000000206','aal','aal1','role','authenticated')::text,true);
insert into chat_results values('cross_tenant_edit',
 public.superadmin_chat_edit_message_v2('9c110000-0000-4000-8000-000000000702',
  '9c110000-0000-4000-8000-000000000812','Fora do escopo','9c110000-0000-4000-8000-000000000908'));
insert into chat_results values('cross_tenant_revoke',
 public.superadmin_chat_revoke_message_v2('9c110000-0000-4000-8000-000000000702',
  '9c110000-0000-4000-8000-000000000812','9c110000-0000-4000-8000-000000000909'));

-- Projecao nova da thread.
select ok((select bool_and(item ? 'receipt' and item ? 'edited_at' and item ? 'can_manage')
  from chat_results,jsonb_array_elements(body#>'{data,items}')item where label='thread_before'),
 'thread projects receipt, edited_at and can_manage for every message');
select ok((select item->>'edited_at' is null and item->>'can_manage'='true'
   and item#>>'{receipt,is_mine}'='true' and item#>>'{receipt,read_count}'='0'
  from chat_results,jsonb_array_elements(body#>'{data,items}')item
  where label='thread_before' and item->>'message_id'='9c110000-0000-4000-8000-000000000810'),
 'own message starts unedited, manageable and with an outbound receipt');
select ok((select item->>'can_manage'='false' and item#>>'{receipt,is_mine}'='false'
  from chat_results,jsonb_array_elements(body#>'{data,items}')item
  where label='thread_before' and item->>'message_id'='9c110000-0000-4000-8000-000000000801'),
 'message from another author is not manageable and carries an inbound receipt');

-- Edicao da propria mensagem.
select ok((select body#>>'{ok}'='true' and body#>>'{data,body_text}'='Aviso interno corrigido'
   and body#>>'{data,replayed}'='false' and body#>>'{data,edited_at}' is not null
  from chat_results where label='edit_ok'),'author edits own message with aal1 (MFA deferred)');
select is((select body_text from public.messages where id='9c110000-0000-4000-8000-000000000810'),
 'Aviso interno corrigido','edit persists the new body');
select ok((select count(*)=1 from app_private.superadmin_internal_chat_message_edits edit
   where edit.message_id='9c110000-0000-4000-8000-000000000810'
    and edit.internal_identity_id='9c110000-0000-4000-8000-000000000301'
    and edit.old_body_text='Aviso interno original'
    and edit.new_body_text='Aviso interno corrigido'),
 'edit trail records the previous and the new body for the internal author');
select ok((select item->>'edited_at' is not null and item->>'body_text'='Aviso interno corrigido'
  from chat_results,jsonb_array_elements(body#>'{data,items}')item
  where label='thread_after_edit' and item->>'message_id'='9c110000-0000-4000-8000-000000000810'),
 'thread projects edited_at once the message is edited');

-- Idempotencia da edicao.
select ok((select body#>>'{ok}'='true' and body#>>'{data,replayed}'='true'
   and body#>>'{data,message_id}'='9c110000-0000-4000-8000-000000000810'
  from chat_results where label='edit_replay'),'same request id replays the edit');
select is((select count(*) from app_private.superadmin_internal_chat_message_edits
  where message_id='9c110000-0000-4000-8000-000000000810'),1::bigint,
 'replayed edit does not append a second trail row');

-- Autoria e janela de edicao.
select is((select body#>>'{error,code}' from chat_results where label='edit_not_author'),
 'CHAT_NOT_AUTHOR','only the author can edit an internal message');
select is((select body_text from public.messages where id='9c110000-0000-4000-8000-000000000811'),
 'Aviso de outra identidade','denied edit leaves the other author message untouched');
select is((select body#>>'{error,code}' from chat_results where label='edit_window_closed'),
 'CHAT_EDIT_WINDOW_CLOSED','edit window is enforced server-side');

-- Capacidade dedicada e autoria (sem segundo fator no MVP).
select is((select body#>>'{error,code}' from chat_results where label='edit_denied_role'),
 'SAI_PERMISSION_DENIED','role without chat.internal.manage cannot edit');
select is((select body#>>'{error,code}' from chat_results where label='edit_denied_other_owner'),
 'CHAT_NOT_AUTHOR','another owner with the capability still cannot edit a message it did not write');
select is((select count(*) from app_private.superadmin_internal_chat_message_edits
  where new_body_text in('Sem capacidade','Outro owner','Tentativa de terceiro','Tarde demais')),
 0::bigint,'denied edits write no trail row');

-- Revogacao.
select ok((select body#>>'{ok}'='true' and body#>>'{data,revoked_at}' is not null
   and body#>>'{data,replayed}'='false' from chat_results where label='revoke_ok'),
 'author revokes own message with aal1');
select ok((select status='archived' and deleted_at is not null
  from public.messages where id='9c110000-0000-4000-8000-000000000810'),
 'revoke is an audited soft delete, not a hard delete');
select is(((select body#>>'{data,total}' from chat_results where label='thread_before')::integer
  -(select body#>>'{data,total}' from chat_results where label='thread_after_revoke')::integer),
 1,'revoked message leaves the thread total');
select ok(not exists(select 1 from chat_results,jsonb_array_elements(body#>'{data,items}')item
  where label='thread_after_revoke' and item->>'message_id'='9c110000-0000-4000-8000-000000000810'),
 'revoked message is no longer projected in the thread');
select is(((select body#>>'{data,total_unread}' from chat_results where label='unread_before')::integer
  -(select body#>>'{data,total_unread}' from chat_results where label='unread_after')::integer),
 1,'revoked message stops counting as unread for other internal identities');
select is((select body#>>'{error,code}' from chat_results where label='revoke_again'),
 'CHAT_ALREADY_REVOKED','revoking twice is rejected with a stable code');
select ok((select exists(select 1 from audit.audit_logs
 where actor_kind='superadmin_internal' and action_code in('chat.message.edit','chat.message.revoke')
   and actor_internal_identity_id='9c110000-0000-4000-8000-000000000301' and outcome='success')),
 'edit and revoke are audited with the 13-argument internal audit function');

-- Isolamento entre instituicoes.
select is((select body#>>'{error,code}' from chat_results where label='cross_tenant_edit'),
 'CHAT_NOT_FOUND','institution scope cannot edit another tenant message');
select is((select body#>>'{error,code}' from chat_results where label='cross_tenant_revoke'),
 'CHAT_NOT_FOUND','institution scope cannot revoke another tenant message');
select ok((select body_text='Aviso interno da Aurora' and status='active' and deleted_at is null
  from public.messages where id='9c110000-0000-4000-8000-000000000812'),
 'cross-tenant attempts leave the other tenant message intact');

select ok(not exists(select 1 from chat_results where
 (select array_agg(key order by key) from jsonb_object_keys(body)key)<>array['data','error','ok']::text[]),
 'all responses use the spec-039 envelope');

select * from finish();
rollback;
