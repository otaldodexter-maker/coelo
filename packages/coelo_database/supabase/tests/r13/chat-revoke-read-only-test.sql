-- Prova do pacote 20260910240200 (recibos, edicao e revogacao do chat interno
-- sobre a baseline). Sessoes AAL1: MFA fora do MVP (ADR 0034, D12).
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

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
-- H06: conversa somente leitura congela o historico; revogar e negado no servidor.
update public.conversations set is_read_only=true where id='9c110000-0000-4000-8000-000000000701';
select set_config('request.jwt.claims',jsonb_build_object('sub','9c110000-0000-4000-8000-000000000101','session_id','9c110000-0000-4000-8000-000000000201','aal','aal1','role','authenticated')::text,true);
insert into chat_results values('revoke_read_only',
 public.superadmin_chat_revoke_message_v2('9c110000-0000-4000-8000-000000000701',
  '9c110000-0000-4000-8000-000000000810','9c110000-0000-4000-8000-000000000924'));
select is((select body#>>'{error,code}' from chat_results where label='revoke_read_only'),'CHAT_READ_ONLY','revoke on read-only conversation returns CHAT_READ_ONLY');
select is((select status::text from public.messages where id='9c110000-0000-4000-8000-000000000810'),'active','message stays active after denied revoke');
update public.conversations set is_read_only=false where id='9c110000-0000-4000-8000-000000000701';
insert into chat_results values('revoke_after_unfreeze',
 public.superadmin_chat_revoke_message_v2('9c110000-0000-4000-8000-000000000701',
  '9c110000-0000-4000-8000-000000000810','9c110000-0000-4000-8000-000000000925'));
select is((select body->>'ok' from chat_results where label='revoke_after_unfreeze'),'true','author still revokes when conversation is writable');
select ok(not has_function_privilege('anon','public.superadmin_chat_revoke_message_v2(uuid,uuid,uuid)','execute'),'anon cannot execute revoke');
select * from finish(); rollback;
