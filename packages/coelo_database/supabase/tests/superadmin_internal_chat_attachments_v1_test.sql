-- chat.attach: prepare -> authorize_finalize -> finalize (service_role) -> thread com anexo
-- -> authorize_read; negativa cross-tenant; expiracao; limites; grants.
begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

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

set local role authenticated;
insert into att values('prepare',public.superadmin_chat_attachment_prepare_v1('9f050000-0000-4000-8000-000000000902',
  (select conversation_id from ids),'boletim.pdf','application/pdf',12345,repeat('a',64)));
reset role;
select is((select body->>'ok' from att where label='prepare'),'true','prepare aceito pelo papel authenticated');
select ok((select body#>>'{data,object_key}' ~ ('^tenants/9f050000-0000-4000-8000-000000000010/chat/conversation/'||(select conversation_id from ids)::text||'/attachment/[0-9a-f-]{36}/original/[0-9a-f-]{36}[.]pdf$')
  and body#>>'{data,bucket}'='coelo-media-prod' and body#>>'{data,upload_status}'='pending' and (body#>>'{data,finalize_ticket}') is not null
  from att where label='prepare'),'object_key opaco versionado, bucket privado e ticket');
create temporary table att_ids as select (body#>>'{data,attachment_id}')::uuid attachment_id,(body#>>'{data,message_id}')::uuid message_id,
  (body#>>'{data,finalize_ticket}')::uuid ticket from att where label='prepare';
grant select on att_ids to authenticated, service_role;
select is((select status::text from public.messages where id=(select message_id from att_ids)),'draft','mensagem nasce em draft');
insert into att values('thread0',public.superadmin_chat_thread_v2((select conversation_id from ids),null,null,50));
select is((select jsonb_array_length(body->'data'->'items') from att where label='thread0'),0,'thread nao mostra a mensagem pendente');

-- replay e mismatch
insert into att values('replay',public.superadmin_chat_attachment_prepare_v1('9f050000-0000-4000-8000-000000000902',
  (select conversation_id from ids),'boletim.pdf','application/pdf',12345,repeat('a',64)));
select ok((select body->>'ok'='true' and (body#>>'{data,attachment_id}')::uuid=(select attachment_id from att_ids) from att where label='replay'),
  'mesmo request_id devolve o mesmo anexo');
insert into att values('mismatch',public.superadmin_chat_attachment_prepare_v1('9f050000-0000-4000-8000-000000000902',
  (select conversation_id from ids),'outro.pdf','application/pdf',12345,repeat('a',64)));
select is((select body#>>'{error,code}' from att where label='mismatch'),'CHAT_REPLAY_MISMATCH','request_id com outro arquivo e recusado');

-- limites
insert into att values
 ('big',public.superadmin_chat_attachment_prepare_v1(gen_random_uuid(),(select conversation_id from ids),'grande.png','image/png',4194305,repeat('b',64))),
 ('mime',public.superadmin_chat_attachment_prepare_v1(gen_random_uuid(),(select conversation_id from ids),'video.mp4','video/mp4',100,repeat('b',64))),
 ('sha',public.superadmin_chat_attachment_prepare_v1(gen_random_uuid(),(select conversation_id from ids),'x.jpg','image/jpeg',100,'zz')),
 ('name',public.superadmin_chat_attachment_prepare_v1(gen_random_uuid(),(select conversation_id from ids),'../x.jpg','image/jpeg',100,repeat('b',64)));
select ok((select bool_and(body#>>'{error,code}'='CHAT_ATTACHMENT_INVALID' and (body#>>'{error,http_status}')::int=422) from att where label in ('big','mime','sha','name')),
  'imagem acima de 4 MiB, video, sha invalido e nome com travessia sao CHAT_ATTACHMENT_INVALID 422');

-- leitura antes de pronto
insert into att values('read_early',public.superadmin_chat_attachment_authorize_read_v1((select attachment_id from att_ids)));
select is((select body#>>'{error,code}' from att where label='read_early'),'CHAT_NOT_FOUND','anexo pendente nao e legivel (mensagem draft)');

-- 3. cross-tenant: owner escopado a B
select set_config('request.jwt.claims',jsonb_build_object('sub','9f050000-0000-4000-8000-000000000103','session_id','9f050000-0000-4000-8000-000000000203','aal','aal1','role','authenticated')::text,true);
insert into att values
 ('b_prepare',public.superadmin_chat_attachment_prepare_v1(gen_random_uuid(),(select conversation_id from ids),'b.pdf','application/pdf',10,repeat('c',64))),
 ('b_auth',public.superadmin_chat_attachment_authorize_finalize_v1((select attachment_id from att_ids))),
 ('b_read',public.superadmin_chat_attachment_authorize_read_v1((select attachment_id from att_ids)));
select ok((select bool_and(body#>>'{error,code}'='CHAT_NOT_FOUND') from att where label in ('b_prepare','b_auth','b_read')),
  'outro tenant: prepare, authorize_finalize e authorize_read respondem CHAT_NOT_FOUND');

-- 4. authorize_finalize pelo dono e finalize pelo service_role
select set_config('request.jwt.claims',jsonb_build_object('sub','9f050000-0000-4000-8000-000000000102','session_id','9f050000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
insert into att values('auth_fin',public.superadmin_chat_attachment_authorize_finalize_v1((select attachment_id from att_ids)));
select ok((select body->>'ok'='true' and (body#>>'{data,finalize_ticket}')::uuid=(select ticket from att_ids) from att where label='auth_fin'),
  'dono do ticket recebe o ticket de finalizacao');

-- finalize como authenticated e negado no privilegio
set local role authenticated;
select throws_like($$select public.superadmin_chat_attachment_finalize_v1('9f050000-0000-4000-8000-000000000001',gen_random_uuid(),1,repeat('a',64))$$,
  '%permission denied%','authenticated nao executa finalize');
reset role;

-- finalize com medidas erradas -> mismatch, anexo failed
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
insert into att values('fin_bad',public.superadmin_chat_attachment_finalize_v1((select attachment_id from att_ids),(select ticket from att_ids),12345,repeat('f',64)));
reset role;
select is((select body#>>'{error,code}' from att where label='fin_bad'),'CHAT_ATTACHMENT_MISMATCH','sha diferente do anunciado e CHAT_ATTACHMENT_MISMATCH');
select is((select upload_status from public.chat_attachment_metadata where id=(select attachment_id from att_ids)),'failed','anexo com mismatch vira failed');
select is((select status::text from public.messages where id=(select message_id from att_ids)),'archived','mensagem do anexo falho fica archived');

-- novo anexo, finalize correto
select set_config('request.jwt.claims',jsonb_build_object('sub','9f050000-0000-4000-8000-000000000102','session_id','9f050000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
insert into att values('prepare2',public.superadmin_chat_attachment_prepare_v1('9f050000-0000-4000-8000-000000000903',
  (select conversation_id from ids),'foto.jpg','image/jpeg',2048,repeat('d',64)));
create temporary table att2 as select (body#>>'{data,attachment_id}')::uuid attachment_id,(body#>>'{data,message_id}')::uuid message_id,
  (body#>>'{data,finalize_ticket}')::uuid ticket from att where label='prepare2';
grant select on att2 to authenticated, service_role;
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
insert into att values('fin_ok',public.superadmin_chat_attachment_finalize_v1((select attachment_id from att2),(select ticket from att2),2048,repeat('d',64)));
insert into att values('fin_again',public.superadmin_chat_attachment_finalize_v1((select attachment_id from att2),(select ticket from att2),2048,repeat('d',64)));
reset role;
select is((select body#>>'{data,upload_status}' from att where label='fin_ok'),'ready','finalize com medidas iguais deixa o anexo ready');
select is((select body#>>'{error,code}' from att where label='fin_again'),'CHAT_ATTACHMENT_TICKET_INVALID','ticket nao e reutilizavel');
select is((select status::text from public.messages where id=(select message_id from att2)),'active','mensagem vira active');

-- thread mostra o anexo; authorize_read funciona; outro tenant nao le
select set_config('request.jwt.claims',jsonb_build_object('sub','9f050000-0000-4000-8000-000000000102','session_id','9f050000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
insert into att values('thread1',public.superadmin_chat_thread_v2((select conversation_id from ids),null,null,50));
select ok((select jsonb_array_length(body->'data'->'items')=1 and body#>>'{data,items,0,attachments,0,file_name}'='foto.jpg'
  and body#>>'{data,items,0,attachments,0,upload_status}'='ready' and body#>>'{data,items,0,message_type}'='attachment'
  from att where label='thread1'),'thread lista a mensagem de anexo pronta com attachments[]');
set local role authenticated;
insert into att values('read_ok',public.superadmin_chat_attachment_authorize_read_v1((select attachment_id from att2)));
reset role;
select ok((select body->>'ok'='true' and body#>>'{data,object_key}' like 'tenants/%' and body#>>'{data,content_type}'='image/jpeg'
  and (body#>>'{data,ttl_seconds}')::int=300 from att where label='read_ok'),'authorize_read devolve a chave para o gateway assinar o GET');
select set_config('request.jwt.claims',jsonb_build_object('sub','9f050000-0000-4000-8000-000000000103','session_id','9f050000-0000-4000-8000-000000000203','aal','aal1','role','authenticated')::text,true);
insert into att values('b_read2',public.superadmin_chat_attachment_authorize_read_v1((select attachment_id from att2)));
select is((select body#>>'{error,code}' from att where label='b_read2'),'CHAT_NOT_FOUND','outro tenant nao le o anexo pronto');

-- 5. expiracao
select set_config('request.jwt.claims',jsonb_build_object('sub','9f050000-0000-4000-8000-000000000102','session_id','9f050000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
insert into att values('prepare3',public.superadmin_chat_attachment_prepare_v1('9f050000-0000-4000-8000-000000000904',
  (select conversation_id from ids),'velho.pdf','application/pdf',10,repeat('e',64)));
update app_private.superadmin_internal_chat_attachment_tickets set expires_at=now()-interval '1 minute'
  where attachment_id=(select (body#>>'{data,attachment_id}')::uuid from att where label='prepare3');
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
insert into att values('expire',public.superadmin_chat_attachment_expire_v1(100));
reset role;
select is((select (body#>>'{data,expired}')::int from att where label='expire'),1,'expire marca o pendente vencido');
select is((select upload_status from public.chat_attachment_metadata where id=(select (body#>>'{data,attachment_id}')::uuid from att where label='prepare3')),
  'failed','anexo vencido vira failed');
select set_config('request.jwt.claims',jsonb_build_object('sub','9f050000-0000-4000-8000-000000000102','session_id','9f050000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
insert into att values('auth_expired',public.superadmin_chat_attachment_authorize_finalize_v1((select (body#>>'{data,attachment_id}')::uuid from att where label='prepare3')));
select is((select body#>>'{error,code}' from att where label='auth_expired'),'CHAT_ATTACHMENT_TICKET_INVALID','ticket vencido nao autoriza finalizacao');

-- 6. auditoria
select ok((select count(*)>=4 from audit.audit_logs where action_code in ('chat.attachment.prepare','chat.attachment.finalize','chat.attachment.read')
  and institution_id='9f050000-0000-4000-8000-000000000010' and outcome='success'),'prepare, finalize e read auditados');
select ok(exists (select 1 from audit.audit_logs where action_code like 'chat.attachment.%' and outcome='denied' and reason_code='CHAT_NOT_FOUND'),
  'negativas cross-tenant auditadas');

select * from finish();
rollback;
