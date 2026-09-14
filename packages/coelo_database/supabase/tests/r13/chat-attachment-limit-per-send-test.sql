-- chat.attach: prepare -> authorize_finalize -> finalize (service_role) -> thread com anexo
-- -> authorize_read; negativa cross-tenant; expiracao; limites; grants.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

-- fixture (mesma forma da prova cross-tenant do chat)
insert into public.institution_types(id,code,name,status) values
 ('9f050000-0000-4000-8000-000000000001','qa-r05-attach','QA R05 attach','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9f050000-0000-4000-8000-000000000010','QA R05 A','qa-r05-attach-a','active','9f050000-0000-4000-8000-000000000001'),
 ('9f050000-0000-4000-8000-000000000020','QA R05 B','qa-r05-attach-b','active','9f050000-0000-4000-8000-000000000001');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9f050000-0000-4000-8000-000000000061','adult','QA R05','Profissional','QA R05 Profissional','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code) values
 ('9f050000-0000-4000-8000-000000000071','9f050000-0000-4000-8000-000000000061','9f050000-0000-4000-8000-000000000010','teacher');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f050000-0000-4000-8000-000000000102','authenticated','authenticated','attach-owner-a@invalid.test',now(),now(),now(),'{}','{}'),
 ('9f050000-0000-4000-8000-000000000103','authenticated','authenticated','attach-owner-b@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9f050000-0000-4000-8000-000000000202','9f050000-0000-4000-8000-000000000102',now(),now(),'aal1',now()+interval '1 hour'),
 ('9f050000-0000-4000-8000-000000000203','9f050000-0000-4000-8000-000000000103',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('9f050000-0000-4000-8000-000000000302'),('9f050000-0000-4000-8000-000000000303');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f050000-0000-4000-8000-000000000402','9f050000-0000-4000-8000-000000000302','9f050000-0000-4000-8000-000000000102'),
 ('9f050000-0000-4000-8000-000000000403','9f050000-0000-4000-8000-000000000303','9f050000-0000-4000-8000-000000000103');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select f.id,f.identity_id,r.id,'institution'::app_private.superadmin_internal_scope_kind,f.institution_id
from (values
 ('9f050000-0000-4000-8000-000000000502'::uuid,'9f050000-0000-4000-8000-000000000302'::uuid,'9f050000-0000-4000-8000-000000000010'::uuid),
 ('9f050000-0000-4000-8000-000000000503'::uuid,'9f050000-0000-4000-8000-000000000303'::uuid,'9f050000-0000-4000-8000-000000000020'::uuid)
) f(id,identity_id,institution_id) join public.platform_roles r on r.code='owner';

create temporary table att(label text primary key, body jsonb not null);
grant select,insert on att to authenticated, service_role;

-- 1. grants
select ok(has_function_privilege('authenticated','public.superadmin_chat_attachment_prepare_v1(uuid,uuid,text,text,bigint,text)','execute')
  and has_function_privilege('authenticated','public.superadmin_chat_attachment_authorize_finalize_v1(uuid)','execute')
  and has_function_privilege('authenticated','public.superadmin_chat_attachment_authorize_read_v1(uuid)','execute')
  and not has_function_privilege('authenticated','public.superadmin_chat_attachment_finalize_v1(uuid,uuid,bigint,text)','execute')
  and has_function_privilege('service_role','public.superadmin_chat_attachment_finalize_v1(uuid,uuid,bigint,text)','execute')
  and has_function_privilege('service_role','public.superadmin_chat_attachment_expire_v1(integer)','execute')
  and not has_function_privilege('anon','public.superadmin_chat_attachment_prepare_v1(uuid,uuid,text,text,bigint,text)','execute'),
  'authenticated prepara/autoriza; service_role finaliza/expira; anon nada');
select ok((select relrowsecurity and relforcerowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='app_private' and c.relname='superadmin_internal_chat_attachment_tickets')
  and not exists (select 1 from information_schema.role_table_grants where table_schema='app_private'
  and table_name='superadmin_internal_chat_attachment_tickets' and grantee in ('PUBLIC','anon','authenticated','service_role')),
  'tabela de tickets com RLS forcada e sem grant a cliente');

-- 2. owner escopado a A cria a conversa e prepara o anexo
select set_config('request.jwt.claims',jsonb_build_object('sub','9f050000-0000-4000-8000-000000000102','session_id','9f050000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
insert into att values('create',public.superadmin_chat_create_group_v2('9f050000-0000-4000-8000-000000000901',
  '9f050000-0000-4000-8000-000000000010','Grupo anexos',array['9f050000-0000-4000-8000-000000000061']::uuid[]));
create temporary table ids as select (body#>>'{data,conversation_id}')::uuid conversation_id from att where label='create';
grant select on ids to authenticated, service_role;
select is((select body->>'ok' from att where label='create'),'true','grupo criado');

-- ADR 0038: 10 anexos por envio. Prepara 10 e o 11o e recusado; finalizar libera vaga.
set local role authenticated;
insert into att select 'p'||g, public.superadmin_chat_attachment_prepare_v1(('9f050000-0000-4000-8000-0000000009'||lpad(g::text,2,'0'))::uuid,
  (select conversation_id from ids),'arquivo'||g||'.pdf','application/pdf',1000+g,substr(repeat(to_hex(g),64),1,64)) from generate_series(10,19) g;
insert into att values('over1',public.superadmin_chat_attachment_prepare_v1('9f050000-0000-4000-8000-000000000920',
  (select conversation_id from ids),'arquivo20.pdf','application/pdf',2000,repeat('0',64)));
reset role;
select is((select count(*) from att where label ~ '^p1[0-9]$' and body->>'ok'='true'),10::bigint,'dez anexos pendentes aceitos');
select is((select body#>>'{error,code}' from att where label='over1'),'CHAT_ATTACHMENT_LIMIT','decimo primeiro anexo pendente recusado');
select is((select (body#>>'{error,http_status}')::int from att where label='over1'),422,'limite responde 422');
-- replay do mesmo request nao conta como novo anexo
set local role authenticated;
insert into att values('replay10',public.superadmin_chat_attachment_prepare_v1('9f050000-0000-4000-8000-000000000910',
  (select conversation_id from ids),'arquivo10.pdf','application/pdf',1010,repeat('a',64)));
reset role;
select is((select body->>'ok' from att where label='replay10'),'true','replay idempotente segue aceito no limite');
-- expirar um ticket (upload abandonado) libera vaga
update app_private.superadmin_internal_chat_attachment_tickets set expires_at = now() - interval '1 minute'
 where attachment_id = (select (body#>>'{data,attachment_id}')::uuid from att where label='p10');
set local role authenticated;
insert into att values('after_expire',public.superadmin_chat_attachment_prepare_v1('9f050000-0000-4000-8000-000000000921',
  (select conversation_id from ids),'arquivo21.pdf','application/pdf',2100,repeat('1',64)));
reset role;
select is((select body->>'ok' from att where label='after_expire'),'true','ticket expirado libera vaga no envio');
select ok((select bool_and(m.status='draft') from public.messages m join public.chat_attachment_metadata a on a.message_id=m.id where m.conversation_id=(select conversation_id from ids)),'anexos pendentes permanecem em draft');
select * from finish(); rollback;
