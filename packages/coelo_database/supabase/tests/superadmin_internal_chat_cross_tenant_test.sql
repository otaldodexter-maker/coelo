-- Prova extra (nao bloqueante): negativa cross-tenant por RPC do chat interno.
-- Fixture identica a chat-internal-production-fixture.sql (instituicao A
-- 9f040000-...-0010 com profissional e responsavel) mais a instituicao B.
-- Um Owner escopado a B chama as 12 RPCs contra a conversa de A: toda leitura
-- e escrita responde CHAT_NOT_FOUND (nao enumera) e nada muda em A; o mesmo
-- Owner escopado a A alcanca a conversa. Owner de plataforma ve as duas.
begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

insert into public.institution_types(id,code,name,status) values
 ('9f040000-0000-4000-8000-000000000001','qa-r04-cross','QA R04 cross tenant','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9f040000-0000-4000-8000-000000000010','QA R04 Instituicao Sintetica','qa-r04-chat','active','9f040000-0000-4000-8000-000000000001'),
 ('9f040000-0000-4000-8000-000000000020','QA R04 Outra Instituicao','qa-r04-outra','active','9f040000-0000-4000-8000-000000000001');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9f040000-0000-4000-8000-000000000061','adult','QA R04','Profissional','QA R04 Profissional','active'),
 ('9f040000-0000-4000-8000-000000000062','adult','QA R04','Responsavel','QA R04 Responsavel','active'),
 ('9f040000-0000-4000-8000-000000000064','child','QA R04','Crianca','QA R04 Crianca','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code) values
 ('9f040000-0000-4000-8000-000000000071','9f040000-0000-4000-8000-000000000061','9f040000-0000-4000-8000-000000000010','teacher');
insert into public.family_relationship_types(id,code,name) values
 ('9f040000-0000-4000-8000-000000000090','qa_r04_responsavel','QA R04 Responsavel');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,relationship_type_id) values
 ('9f040000-0000-4000-8000-000000000081','9f040000-0000-4000-8000-000000000062','9f040000-0000-4000-8000-000000000064','responsavel','9f040000-0000-4000-8000-000000000090');
insert into public.child_contexts(id,child_person_id,institution_id) values
 ('9f040000-0000-4000-8000-000000000091','9f040000-0000-4000-8000-000000000064','9f040000-0000-4000-8000-000000000010');

-- Tres identidades internas: owner de plataforma, owner escopado a A, owner escopado a B.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f040000-0000-4000-8000-000000000101','authenticated','authenticated','cross-platform@invalid.test',now(),now(),now(),'{}','{}'),
 ('9f040000-0000-4000-8000-000000000102','authenticated','authenticated','cross-owner-a@invalid.test',now(),now(),now(),'{}','{}'),
 ('9f040000-0000-4000-8000-000000000103','authenticated','authenticated','cross-owner-b@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9f040000-0000-4000-8000-000000000201','9f040000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour'),
 ('9f040000-0000-4000-8000-000000000202','9f040000-0000-4000-8000-000000000102',now(),now(),'aal1',now()+interval '1 hour'),
 ('9f040000-0000-4000-8000-000000000203','9f040000-0000-4000-8000-000000000103',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('9f040000-0000-4000-8000-000000000301'),('9f040000-0000-4000-8000-000000000302'),('9f040000-0000-4000-8000-000000000303');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f040000-0000-4000-8000-000000000401','9f040000-0000-4000-8000-000000000301','9f040000-0000-4000-8000-000000000101'),
 ('9f040000-0000-4000-8000-000000000402','9f040000-0000-4000-8000-000000000302','9f040000-0000-4000-8000-000000000102'),
 ('9f040000-0000-4000-8000-000000000403','9f040000-0000-4000-8000-000000000303','9f040000-0000-4000-8000-000000000103');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,
 fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from(values
 ('9f040000-0000-4000-8000-000000000501'::uuid,'9f040000-0000-4000-8000-000000000301'::uuid,'platform',null::uuid),
 ('9f040000-0000-4000-8000-000000000502'::uuid,'9f040000-0000-4000-8000-000000000302'::uuid,'institution','9f040000-0000-4000-8000-000000000010'::uuid),
 ('9f040000-0000-4000-8000-000000000503'::uuid,'9f040000-0000-4000-8000-000000000303'::uuid,'institution','9f040000-0000-4000-8000-000000000020'::uuid)
)fixture(id,identity_id,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code='owner';

create temporary table cross_results(label text primary key,body jsonb not null);

-- Owner escopado a A cria o grupo em A e manda uma mensagem.
select set_config('request.jwt.claims',jsonb_build_object('sub','9f040000-0000-4000-8000-000000000102','session_id','9f040000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
insert into cross_results values('a_create',public.superadmin_chat_create_group_v2(
 '9f040000-0000-4000-8000-000000000901','9f040000-0000-4000-8000-000000000010','Grupo de A',
 array['9f040000-0000-4000-8000-000000000061','9f040000-0000-4000-8000-000000000062']::uuid[]));
create temporary table cross_ids as select (body#>>'{data,conversation_id}')::uuid conversation_id from cross_results where label='a_create';
insert into cross_results values('a_send',public.superadmin_chat_send_message_v2(
 (select conversation_id from cross_ids),'Mensagem de A','9f040000-0000-4000-8000-000000000902'));
create temporary table cross_msg as select (body#>>'{data,message_id}')::uuid message_id from cross_results where label='a_send';
insert into cross_results values('a_inbox',public.superadmin_chat_inbox_v2(null,null,30,null,false));

-- Owner escopado a B tenta as 12 RPCs contra a conversa de A.
select set_config('request.jwt.claims',jsonb_build_object('sub','9f040000-0000-4000-8000-000000000103','session_id','9f040000-0000-4000-8000-000000000203','aal','aal1','role','authenticated')::text,true);
insert into cross_results values
 ('b_inbox',public.superadmin_chat_inbox_v2(null,null,30,null,false)),
 ('b_unread',public.superadmin_chat_unread_total_v2()),
 ('b_thread',public.superadmin_chat_thread_v2((select conversation_id from cross_ids),null,null,50)),
 ('b_send',public.superadmin_chat_send_message_v2((select conversation_id from cross_ids),'Intruso de B','9f040000-0000-4000-8000-000000000903')),
 ('b_edit',public.superadmin_chat_edit_message_v2((select conversation_id from cross_ids),(select message_id from cross_msg),'Editado por B','9f040000-0000-4000-8000-000000000904')),
 ('b_revoke',public.superadmin_chat_revoke_message_v2((select conversation_id from cross_ids),(select message_id from cross_msg),'9f040000-0000-4000-8000-000000000905')),
 ('b_mark_read',public.superadmin_chat_mark_read_v2((select conversation_id from cross_ids),(select message_id from cross_msg))),
 ('b_refresh',public.superadmin_chat_realtime_refresh_v2((select conversation_id from cross_ids))),
 ('b_pin',public.superadmin_chat_set_pinned_v2((select conversation_id from cross_ids),true)),
 ('b_flag',public.superadmin_chat_set_flag_v2((select conversation_id from cross_ids),'red')),
 ('b_members',public.superadmin_chat_group_members_v2((select conversation_id from cross_ids))),
 ('b_create_in_a',public.superadmin_chat_create_group_v2('9f040000-0000-4000-8000-000000000906',
   '9f040000-0000-4000-8000-000000000010','Grupo de B dentro de A',
   array['9f040000-0000-4000-8000-000000000061']::uuid[]));

-- Owner de plataforma ve a conversa de A.
select set_config('request.jwt.claims',jsonb_build_object('sub','9f040000-0000-4000-8000-000000000101','session_id','9f040000-0000-4000-8000-000000000201','aal','aal1','role','authenticated')::text,true);
insert into cross_results values('platform_inbox',public.superadmin_chat_inbox_v2(null,null,30,null,false));

select ok((select body#>>'{ok}'='true' from cross_results where label='a_create'),'owner scoped to A creates the group in A');
select ok((select body#>>'{ok}'='true' from cross_results where label='a_send'),'owner scoped to A sends in A');
select ok((select body#>>'{data,total}'='1' from cross_results where label='a_inbox'),'owner scoped to A sees exactly its conversation');

select ok((select body#>>'{ok}'='true' and body#>>'{data,total}'='0' and body#>>'{data,total_unread}'='0'
  from cross_results where label='b_inbox'),'inbox: owner scoped to B sees nothing from A');
select ok((select body#>>'{ok}'='true' and body#>>'{data,total_unread}'='0'
  from cross_results where label='b_unread'),'unread_total: B counts nothing from A');
select is((select body#>>'{error,code}' from cross_results where label='b_thread'),'CHAT_NOT_FOUND','thread: cross-tenant id does not enumerate');
select is((select body#>>'{error,code}' from cross_results where label='b_send'),'CHAT_NOT_FOUND','send: cross-tenant is refused');
select is((select body#>>'{error,code}' from cross_results where label='b_edit'),'CHAT_NOT_FOUND','edit: cross-tenant is refused');
select is((select body#>>'{error,code}' from cross_results where label='b_revoke'),'CHAT_NOT_FOUND','revoke: cross-tenant is refused');
select is((select body#>>'{error,code}' from cross_results where label='b_mark_read'),'CHAT_NOT_FOUND','mark_read: cross-tenant is refused');
select is((select body#>>'{error,code}' from cross_results where label='b_refresh'),'CHAT_NOT_FOUND','realtime_refresh: cross-tenant is refused');
select is((select body#>>'{error,code}' from cross_results where label='b_pin'),'CHAT_NOT_FOUND','set_pinned: cross-tenant is refused');
select is((select body#>>'{error,code}' from cross_results where label='b_flag'),'CHAT_NOT_FOUND','set_flag: cross-tenant is refused');
select is((select body#>>'{error,code}' from cross_results where label='b_members'),'CHAT_NOT_FOUND','group_members: cross-tenant is refused');
select is((select body#>>'{error,code}' from cross_results where label='b_create_in_a'),'CHAT_NOT_FOUND','create_group: B cannot create inside A');

-- Nada mudou em A.
select is((select count(*) from public.messages where conversation_id=(select conversation_id from cross_ids)),1::bigint,'A still has exactly one message');
select ok((select body_text='Mensagem de A' and status='active' and deleted_at is null
  from public.messages where id=(select message_id from cross_msg)),'the message of A is untouched');
select is((select count(*) from app_private.superadmin_internal_chat_preferences
  where conversation_id=(select conversation_id from cross_ids)),0::bigint,'no preference was written by B');
select is((select count(*) from public.conversations where institution_id='9f040000-0000-4000-8000-000000000010'),1::bigint,'no extra conversation was created in A');
select ok((select count(*)>=1 from audit.audit_logs where actor_internal_identity_id='9f040000-0000-4000-8000-000000000303'
  and outcome='denied' and reason_code='CHAT_NOT_FOUND'),'denials of B are audited with the stable code');
select ok((select body#>>'{data,total}'='1' from cross_results where label='platform_inbox'),'platform owner sees the conversation of A');

select * from finish();
rollback;
