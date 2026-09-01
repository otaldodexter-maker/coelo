begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

select has_function('public','superadmin_chat_inbox_v2',
 array['timestamp with time zone','uuid','integer','text','boolean']);
select has_function('public','superadmin_chat_thread_v2',
 array['uuid','timestamp with time zone','uuid','integer']);
select has_function('public','superadmin_chat_send_message_v2',array['uuid','text','uuid']);

insert into public.institution_types(id,code,name,status) values
 ('9c100000-0000-4000-8000-000000000001','internal-chat-v2','Internal chat v2','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9c100000-0000-4000-8000-000000000010','Colégio Horizonte','chat-v2-a','active','9c100000-0000-4000-8000-000000000001'),
 ('9c100000-0000-4000-8000-000000000020','Escola Aurora','chat-v2-b','active','9c100000-0000-4000-8000-000000000001');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9c100000-0000-4000-8000-000000000060','adult','Marina','Souza','Marina Souza','active');
insert into public.conversations(id,institution_id,scope_kind,conversation_type,title,status) values
 ('9c100000-0000-4000-8000-000000000701','9c100000-0000-4000-8000-000000000010','institution','institution','Famílias - Horizonte','active'),
 ('9c100000-0000-4000-8000-000000000702','9c100000-0000-4000-8000-000000000020','institution','institution','Famílias - Aurora','active');
insert into public.messages(id,conversation_id,author_person_id,body_text,message_type) values
 ('9c100000-0000-4000-8000-000000000801','9c100000-0000-4000-8000-000000000701','9c100000-0000-4000-8000-000000000060','Bom dia, Horizonte!','text'),
 ('9c100000-0000-4000-8000-000000000802','9c100000-0000-4000-8000-000000000702','9c100000-0000-4000-8000-000000000060','Bom dia, Aurora!','text');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9c100000-0000-4000-8000-000000000101','authenticated','authenticated','chat-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c100000-0000-4000-8000-000000000102','authenticated','authenticated','chat-scoped@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c100000-0000-4000-8000-000000000103','authenticated','authenticated','chat-owner-aal1@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c100000-0000-4000-8000-000000000104','authenticated','authenticated','chat-revoked@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9c100000-0000-4000-8000-000000000201','9c100000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('9c100000-0000-4000-8000-000000000202','9c100000-0000-4000-8000-000000000102',now(),now(),'aal1',now()+interval '1 hour'),
 ('9c100000-0000-4000-8000-000000000203','9c100000-0000-4000-8000-000000000103',now(),now(),'aal1',now()+interval '1 hour'),
 ('9c100000-0000-4000-8000-000000000204','9c100000-0000-4000-8000-000000000104',now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('9c100000-0000-4000-8000-000000000301'),('9c100000-0000-4000-8000-000000000302'),
 ('9c100000-0000-4000-8000-000000000303'),('9c100000-0000-4000-8000-000000000304');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9c100000-0000-4000-8000-000000000401','9c100000-0000-4000-8000-000000000301','9c100000-0000-4000-8000-000000000101'),
 ('9c100000-0000-4000-8000-000000000402','9c100000-0000-4000-8000-000000000302','9c100000-0000-4000-8000-000000000102'),
 ('9c100000-0000-4000-8000-000000000403','9c100000-0000-4000-8000-000000000303','9c100000-0000-4000-8000-000000000103'),
 ('9c100000-0000-4000-8000-000000000404','9c100000-0000-4000-8000-000000000304','9c100000-0000-4000-8000-000000000104');
insert into app_private.superadmin_internal_memberships(
 id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,
 fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from(values
 ('9c100000-0000-4000-8000-000000000501'::uuid,'9c100000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('9c100000-0000-4000-8000-000000000502'::uuid,'9c100000-0000-4000-8000-000000000302'::uuid,'operations','institution','9c100000-0000-4000-8000-000000000010'::uuid),
 ('9c100000-0000-4000-8000-000000000503'::uuid,'9c100000-0000-4000-8000-000000000303'::uuid,'owner','platform',null::uuid),
 ('9c100000-0000-4000-8000-000000000504'::uuid,'9c100000-0000-4000-8000-000000000304'::uuid,'operations','institution','9c100000-0000-4000-8000-000000000010'::uuid)
)fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now(),version=2
 where id='9c100000-0000-4000-8000-000000000504';

create temporary table chat_results(label text primary key,body jsonb not null);

select set_config('request.jwt.claims',jsonb_build_object('sub','9c100000-0000-4000-8000-000000000101','session_id','9c100000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);
insert into chat_results values
 ('owner_inbox',public.superadmin_chat_inbox_v2(null,null,1,null,false)),
 ('owner_thread',public.superadmin_chat_thread_v2('9c100000-0000-4000-8000-000000000701',null,null,50)),
 ('owner_send',public.superadmin_chat_send_message_v2('9c100000-0000-4000-8000-000000000701','Aviso da equipe Coelo','9c100000-0000-4000-8000-000000000901')),
 ('owner_replay',public.superadmin_chat_send_message_v2('9c100000-0000-4000-8000-000000000701','Aviso da equipe Coelo','9c100000-0000-4000-8000-000000000901')),
 ('owner_mismatch',public.superadmin_chat_send_message_v2('9c100000-0000-4000-8000-000000000701','Outro texto','9c100000-0000-4000-8000-000000000901')),
 ('owner_read',public.superadmin_chat_mark_read_v2('9c100000-0000-4000-8000-000000000701','9c100000-0000-4000-8000-000000000801')),
 ('owner_unread',public.superadmin_chat_unread_total_v2());

select set_config('request.jwt.claims',jsonb_build_object('sub','9c100000-0000-4000-8000-000000000102','session_id','9c100000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
insert into chat_results values
 ('scoped_inbox',public.superadmin_chat_inbox_v2(null,null,30,null,false)),
 ('scoped_cross_tenant',public.superadmin_chat_thread_v2('9c100000-0000-4000-8000-000000000702',null,null,50)),
 ('scoped_send_denied',public.superadmin_chat_send_message_v2('9c100000-0000-4000-8000-000000000701','Não autorizado','9c100000-0000-4000-8000-000000000902'));

select set_config('request.jwt.claims',jsonb_build_object('sub','9c100000-0000-4000-8000-000000000103','session_id','9c100000-0000-4000-8000-000000000203','aal','aal1','role','authenticated')::text,true);
insert into chat_results values
 ('owner_aal1_send',public.superadmin_chat_send_message_v2('9c100000-0000-4000-8000-000000000701','Sem segundo fator','9c100000-0000-4000-8000-000000000903'));

select set_config('request.jwt.claims',jsonb_build_object('sub','9c100000-0000-4000-8000-000000000104','session_id','9c100000-0000-4000-8000-000000000204','aal','aal2','role','authenticated')::text,true);
insert into chat_results values('revoked',public.superadmin_chat_inbox_v2(null,null,30,null,false));

select ok((select body#>>'{ok}'='true' and body#>>'{data,total}'='2'
 and body#>>'{data,has_more}'='true' and jsonb_array_length(body#>'{data,items}')=1
 from chat_results where label='owner_inbox'),'owner inbox returns bounded page, total and has_more');
select ok((select body#>>'{ok}'='true' and body#>>'{data,total}'='1'
 from chat_results where label='owner_thread'),'authorized thread returns its message');
select ok((select body#>>'{ok}'='true' and body#>>'{data,author_name}'='Equipe Coelo'
 from chat_results where label='owner_send'),'aal2 owner sends as the internal realm');
select is((select body#>>'{data,message_id}' from chat_results where label='owner_replay'),
 (select body#>>'{data,message_id}' from chat_results where label='owner_send'),'same request id replays one message');
select is((select body#>>'{error,code}' from chat_results where label='owner_mismatch'),
 'CHAT_REPLAY_MISMATCH','request replay mismatch is rejected');
select is((select count(*) from public.messages where body_text='Aviso da equipe Coelo'),1::bigint,
 'idempotent send persists exactly once');
select ok((select author_person_id is null and author_kind='superadmin_internal'
 and author_internal_identity_id='9c100000-0000-4000-8000-000000000301'
 from public.messages where body_text='Aviso da equipe Coelo'),'message preserves internal actor provenance without people alias');
select ok((select body#>>'{data,updated_count}'='1' from chat_results where label='owner_read'),
 'mark read persists the internal receipt');
select is((select body#>>'{data,total_unread}' from chat_results where label='owner_unread'),'1',
 'unread total reflects read persistence across tenants');
select ok((select body#>>'{data,total}'='1' and position('Aurora' in body::text)=0
 from chat_results where label='scoped_inbox'),'institution scope cannot leak another tenant');
select is((select body#>>'{error,code}' from chat_results where label='scoped_cross_tenant'),
 'CHAT_NOT_FOUND','cross-tenant id is non-enumerating');
select is((select body#>>'{error,code}' from chat_results where label='scoped_send_denied'),
 'SAI_PERMISSION_DENIED','read-only role cannot send');
select is((select body#>>'{error,code}' from chat_results where label='owner_aal1_send'),
 'SAI_MFA_REQUIRED','owner mutation requires aal2');
select is((select body#>>'{error,code}' from chat_results where label='revoked'),
 'SAI_MEMBERSHIP_REVOKED','revoked membership is denied immediately');
select ok(not has_table_privilege('authenticated','app_private.superadmin_internal_chat_receipts','select')
 and not has_table_privilege('authenticated','app_private.superadmin_internal_chat_command_receipts','select'),
 'internal receipt and idempotency state have no direct client path');
select ok(has_function_privilege('authenticated','public.superadmin_chat_inbox_v2(timestamptz,uuid,integer,text,boolean)','execute')
 and not has_function_privilege('anon','public.superadmin_chat_inbox_v2(timestamptz,uuid,integer,text,boolean)','execute'),
 'only authenticated can invoke the guarded gateway');
select ok(not exists(select 1 from chat_results where
 (select array_agg(key order by key) from jsonb_object_keys(body)key)<>array['data','error','ok']::text[]),
 'all responses use the spec-039 envelope');

select * from finish();
rollback;
