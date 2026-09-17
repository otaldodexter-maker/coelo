-- R15 E3 (ADR 0042): varios anexos por mensagem. prepare_v2 em lote -> finalize_v2
-- por irmaos -> discard -> thread so com ready; 11o recusado (422); lote 67
-- preservado; cross-tenant; idempotencia; expiracao sensivel a irmaos; grants; auditoria.
begin;
create extension if not exists pgtap with schema extensions;
select plan(51);

-- fixture (mesma forma da suite v1)
insert into public.institution_types(id,code,name,status) values
 ('9f150000-0000-4000-8000-000000000001','qa-r15-batch','QA R15 batch','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9f150000-0000-4000-8000-000000000010','QA R15 A','qa-r15-batch-a','active','9f150000-0000-4000-8000-000000000001'),
 ('9f150000-0000-4000-8000-000000000020','QA R15 B','qa-r15-batch-b','active','9f150000-0000-4000-8000-000000000001');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9f150000-0000-4000-8000-000000000061','adult','QA R15','Profissional','QA R15 Profissional','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code) values
 ('9f150000-0000-4000-8000-000000000071','9f150000-0000-4000-8000-000000000061','9f150000-0000-4000-8000-000000000010','teacher');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f150000-0000-4000-8000-000000000102','authenticated','authenticated','batch-owner-a@invalid.test',now(),now(),now(),'{}','{}'),
 ('9f150000-0000-4000-8000-000000000103','authenticated','authenticated','batch-owner-b@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9f150000-0000-4000-8000-000000000202','9f150000-0000-4000-8000-000000000102',now(),now(),'aal1',now()+interval '1 hour'),
 ('9f150000-0000-4000-8000-000000000203','9f150000-0000-4000-8000-000000000103',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('9f150000-0000-4000-8000-000000000302'),('9f150000-0000-4000-8000-000000000303');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f150000-0000-4000-8000-000000000402','9f150000-0000-4000-8000-000000000302','9f150000-0000-4000-8000-000000000102'),
 ('9f150000-0000-4000-8000-000000000403','9f150000-0000-4000-8000-000000000303','9f150000-0000-4000-8000-000000000103');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select f.id,f.identity_id,r.id,'institution'::app_private.superadmin_internal_scope_kind,f.institution_id
from (values
 ('9f150000-0000-4000-8000-000000000502'::uuid,'9f150000-0000-4000-8000-000000000302'::uuid,'9f150000-0000-4000-8000-000000000010'::uuid),
 ('9f150000-0000-4000-8000-000000000503'::uuid,'9f150000-0000-4000-8000-000000000303'::uuid,'9f150000-0000-4000-8000-000000000020'::uuid)
) f(id,identity_id,institution_id) join public.platform_roles r on r.code='owner';

create temporary table att(label text primary key, body jsonb not null);
grant select,insert on att to authenticated, service_role;

create or replace function pg_temp.item(p_name text, p_type text, p_size bigint, p_sha text) returns jsonb
language sql immutable as $$ select jsonb_build_object('file_name',p_name,'content_type',p_type,'byte_size',p_size,'sha256',p_sha) $$;
create or replace function pg_temp.as_owner_a() returns void language sql as $$
  select set_config('request.jwt.claims',jsonb_build_object('sub','9f150000-0000-4000-8000-000000000102','session_id','9f150000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true) $$;
create or replace function pg_temp.as_owner_b() returns void language sql as $$
  select set_config('request.jwt.claims',jsonb_build_object('sub','9f150000-0000-4000-8000-000000000103','session_id','9f150000-0000-4000-8000-000000000203','aal','aal1','role','authenticated')::text,true) $$;
create or replace function pg_temp.as_service() returns void language sql as $$
  select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true) $$;
grant execute on function pg_temp.item(text,text,bigint,text) to authenticated, service_role;

-- 1. grants
select ok(has_function_privilege('authenticated','public.superadmin_chat_attachment_prepare_v2(uuid,uuid,jsonb,text)','execute')
  and has_function_privilege('authenticated','public.superadmin_chat_attachment_discard_v1(uuid)','execute')
  and not has_function_privilege('authenticated','public.superadmin_chat_attachment_finalize_v2(uuid,uuid,bigint,text)','execute')
  and has_function_privilege('service_role','public.superadmin_chat_attachment_finalize_v2(uuid,uuid,bigint,text)','execute')
  and not has_function_privilege('service_role','public.superadmin_chat_attachment_prepare_v2(uuid,uuid,jsonb,text)','execute')
  and not has_function_privilege('anon','public.superadmin_chat_attachment_prepare_v2(uuid,uuid,jsonb,text)','execute')
  and not has_function_privilege('anon','public.superadmin_chat_attachment_discard_v1(uuid)','execute'),
  'authenticated prepara/descarta; service_role finaliza; anon nada');
select ok(not has_function_privilege('authenticated','app_private.superadmin_chat_attachment_list_v2(uuid)','execute')
  and not has_function_privilege('authenticated','app_private.superadmin_chat_message_settle_v2(uuid)','execute')
  and not has_function_privilege('service_role','app_private.superadmin_chat_message_settle_v2(uuid)','execute'),
  'helpers privados sem grant a cliente');
select is((select (body#>>'{error,http_status}')::int from (select app_private.superadmin_chat_error('CHAT_ATTACHMENT_DISCARD_INVALID',gen_random_uuid()) body) e),
  409,'CHAT_ATTACHMENT_DISCARD_INVALID e 409 no envelope');

-- 2. owner A cria a conversa e prepara um lote de 3
select pg_temp.as_owner_a();
insert into att values('create',public.superadmin_chat_create_group_v2('9f150000-0000-4000-8000-000000000901',
  '9f150000-0000-4000-8000-000000000010','Grupo lote',array['9f150000-0000-4000-8000-000000000061']::uuid[]));
create temporary table ids as select (body#>>'{data,conversation_id}')::uuid conversation_id from att where label='create';
grant select on ids to authenticated, service_role;
select is((select body->>'ok' from att where label='create'),'true','grupo criado');

set local role authenticated;
insert into att values('batch3',public.superadmin_chat_attachment_prepare_v2('9f150000-0000-4000-8000-000000000902',
  (select conversation_id from ids),
  jsonb_build_array(pg_temp.item('a.jpg','image/jpeg',100,repeat('a',64)),
                    pg_temp.item('b.png','image/png',200,repeat('b',64)),
                    pg_temp.item('c.pdf','application/pdf',300,repeat('c',64))), null));
reset role;
select is((select body->>'ok' from att where label='batch3'),'true','lote de 3 aceito pelo papel authenticated');
create temporary table b3 as
  select (body#>>'{data,message_id}')::uuid message_id,
    (item->>'attachment_id')::uuid attachment_id,(item->>'finalize_ticket')::uuid ticket,
    (item->>'index')::int idx,item->>'file_name' file_name,item->>'object_key' object_key
  from att, jsonb_array_elements(body#>'{data,items}') item where label='batch3';
grant select on b3 to authenticated, service_role;
select is((select count(*) from b3),3::bigint,'3 itens no envelope');
select is((select count(distinct message_id) from b3),1::bigint,'os 3 anexos apontam para UMA mensagem');
select is((select status::text from public.messages where id=(select message_id from b3 limit 1)),'draft','a mensagem nasce em draft');
select is((select body_text from public.messages where id=(select message_id from b3 limit 1)),'3 anexos','sem legenda, o corpo e "N anexos"');
select ok((select bool_and(object_key ~ ('^tenants/9f150000-0000-4000-8000-000000000010/chat/conversation/'||(select conversation_id from ids)::text||'/attachment/'||attachment_id::text||'/original/[0-9a-f-]{36}[.](jpg|png|pdf)$')) from b3),
  'object_key opaco por anexo no tenant da conversa');
select is((select count(distinct ticket) from b3),3::bigint,'um finalize_ticket por anexo');
select is((select count(*) from app_private.superadmin_internal_chat_attachment_tickets t where t.attachment_id in (select attachment_id from b3)
  and t.request_id=extensions.uuid_generate_v5('9f150000-0000-4000-8000-000000000902','chat-attachment-item:'||(select idx from b3 b where b.attachment_id=t.attachment_id)::text)),
  3::bigint,'request_id por item derivado (uuid v5) do request_id do lote');
select is((select body#>>'{data,message_status}' from att where label='batch3'),'draft','envelope informa message_status draft');
select is((select array_agg(idx order by idx) from b3),array[0,1,2],'itens indexados na ordem enviada');
insert into att values('thread0',public.superadmin_chat_thread_v2((select conversation_id from ids),null,null,50));
select is((select jsonb_array_length(body->'data'->'items') from att where label='thread0'),0,'thread nao mostra a mensagem em draft');

-- 3. idempotencia do prepare
insert into att values('replay',public.superadmin_chat_attachment_prepare_v2('9f150000-0000-4000-8000-000000000902',
  (select conversation_id from ids),
  jsonb_build_array(pg_temp.item('a.jpg','image/jpeg',100,repeat('a',64)),
                    pg_temp.item('b.png','image/png',200,repeat('b',64)),
                    pg_temp.item('c.pdf','application/pdf',300,repeat('c',64))), null));
select ok((select body->>'ok'='true' and (body#>>'{data,replayed}')::boolean and (body#>>'{data,message_id}')::uuid=(select message_id from b3 limit 1)
  and (select array_agg((i->>'attachment_id')::uuid order by (i->>'index')::int) from jsonb_array_elements(body#>'{data,items}') i)
      =(select array_agg(attachment_id order by idx) from b3) from att where label='replay'),
  'mesmo request_id e mesmo lote devolvem a mesma mensagem e os mesmos anexos');
select is((select count(*) from public.messages where conversation_id=(select conversation_id from ids) and message_type='attachment'),1::bigint,'replay nao cria mensagem nova');
insert into att values('mismatch',public.superadmin_chat_attachment_prepare_v2('9f150000-0000-4000-8000-000000000902',
  (select conversation_id from ids), jsonb_build_array(pg_temp.item('outro.jpg','image/jpeg',100,repeat('a',64))), null));
select is((select body#>>'{error,code}' from att where label='mismatch'),'CHAT_REPLAY_MISMATCH','mesmo request_id com lote diferente e recusado');

-- 4. limites: 11 itens, lote 67 (pendentes por autor/conversa), entrada invalida
insert into att values('eleven',public.superadmin_chat_attachment_prepare_v2(gen_random_uuid(),(select conversation_id from ids),
  (select jsonb_agg(pg_temp.item('f'||n||'.jpg','image/jpeg',10,repeat('d',64))) from generate_series(1,11) n), null));
select ok((select body#>>'{error,code}'='CHAT_ATTACHMENT_LIMIT' and (body#>>'{error,http_status}')::int=422 from att where label='eleven'),
  '11o anexo do lote e CHAT_ATTACHMENT_LIMIT 422');
select is((select count(*) from public.messages where conversation_id=(select conversation_id from ids) and message_type='attachment'),1::bigint,'lote recusado nao cria mensagem nem anexos');
insert into att values('eight',public.superadmin_chat_attachment_prepare_v2(gen_random_uuid(),(select conversation_id from ids),
  (select jsonb_agg(pg_temp.item('g'||n||'.jpg','image/jpeg',10,repeat('e',64))) from generate_series(1,8) n), null));
select is((select body#>>'{error,code}' from att where label='eight'),'CHAT_ATTACHMENT_LIMIT','3 pendentes + lote de 8 estoura o teto do lote 67');
insert into att values('seven',public.superadmin_chat_attachment_prepare_v2('9f150000-0000-4000-8000-000000000903',(select conversation_id from ids),
  (select jsonb_agg(pg_temp.item('h'||n||'.jpg','image/jpeg',10,repeat('e',64))) from generate_series(1,7) n), 'legenda do lote'));
select ok((select body->>'ok'='true' and jsonb_array_length(body#>'{data,items}')=7 and body#>>'{data,body_text}'='legenda do lote' from att where label='seven'),
  '3 pendentes + lote de 7 = 10 e aceito, com legenda no corpo');
insert into att values
 ('empty',public.superadmin_chat_attachment_prepare_v2(gen_random_uuid(),(select conversation_id from ids),'[]'::jsonb,null)),
 ('notarray',public.superadmin_chat_attachment_prepare_v2(gen_random_uuid(),(select conversation_id from ids),'{}'::jsonb,null)),
 ('longbody',public.superadmin_chat_attachment_prepare_v2(gen_random_uuid(),(select conversation_id from ids),jsonb_build_array(pg_temp.item('x.jpg','image/jpeg',10,repeat('f',64))),repeat('x',4001)));
select ok((select bool_and(body#>>'{error,code}'='CHAT_INVALID_INPUT') from att where label in ('empty','notarray','longbody')),'lote vazio, nao-array e legenda >4000 sao CHAT_INVALID_INPUT');
insert into att values
 ('badsha',public.superadmin_chat_attachment_prepare_v2(gen_random_uuid(),(select conversation_id from ids),jsonb_build_array(pg_temp.item('x.jpg','image/jpeg',10,repeat('f',64)),pg_temp.item('y.jpg','image/jpeg',10,'zz')),null)),
 ('badmime',public.superadmin_chat_attachment_prepare_v2(gen_random_uuid(),(select conversation_id from ids),jsonb_build_array(pg_temp.item('x.exe','application/octet-stream',10,repeat('f',64))),null)),
 ('big',public.superadmin_chat_attachment_prepare_v2(gen_random_uuid(),(select conversation_id from ids),jsonb_build_array(pg_temp.item('x.jpg','image/jpeg',4194305,repeat('f',64))),null));
select ok((select bool_and(body#>>'{error,code}'='CHAT_ATTACHMENT_INVALID' and (body#>>'{error,http_status}')::int=422) from att where label in ('badsha','badmime','big')),
  'um item invalido derruba o lote inteiro com CHAT_ATTACHMENT_INVALID 422');

-- 5. cross-tenant: owner B nao prepara, nao descarta e nao autoriza finalizacao na conversa de A
select pg_temp.as_owner_b();
insert into att values
 ('b_prepare',public.superadmin_chat_attachment_prepare_v2(gen_random_uuid(),(select conversation_id from ids),jsonb_build_array(pg_temp.item('b.pdf','application/pdf',10,repeat('9',64))),null)),
 ('b_discard',public.superadmin_chat_attachment_discard_v1((select attachment_id from b3 where idx=0))),
 ('b_auth',public.superadmin_chat_attachment_authorize_finalize_v1((select attachment_id from b3 where idx=0)));
select ok((select bool_and(body#>>'{error,code}'='CHAT_NOT_FOUND' and (body#>>'{error,http_status}')::int=404) from att where label in ('b_prepare','b_discard','b_auth')),
  'outro tenant: prepare_v2, discard e authorize_finalize respondem CHAT_NOT_FOUND');
select is((select upload_status from public.chat_attachment_metadata where id=(select attachment_id from b3 where idx=0)),'pending','negativa cross-tenant nao muta o anexo');

-- 6. finalize_v2: papel, irmaos e mismatch
set local role authenticated;
select throws_like($$select public.superadmin_chat_attachment_finalize_v2('9f150000-0000-4000-8000-000000000001',gen_random_uuid(),1,repeat('a',64))$$,
  '%permission denied%','authenticated nao executa finalize_v2');
reset role;
select pg_temp.as_service();
set local role service_role;
insert into att values('fin0',public.superadmin_chat_attachment_finalize_v2((select attachment_id from b3 where idx=0),(select ticket from b3 where idx=0),100,repeat('a',64)));
reset role;
select ok((select body->>'ok'='true' and body#>>'{data,upload_status}'='ready' and body#>>'{data,message_status}'='draft'
  and jsonb_array_length(body#>'{data,attachments}')=3 from att where label='fin0'),
  'primeiro anexo ready: mensagem continua draft (irmaos pendentes) e o envelope lista os 3');
select is((select status::text from public.messages where id=(select message_id from b3 limit 1)),'draft','mensagem segue draft com irmaos pendentes');
set local role service_role;
insert into att values('fin1_bad',public.superadmin_chat_attachment_finalize_v2((select attachment_id from b3 where idx=1),(select ticket from b3 where idx=1),200,repeat('f',64)));
insert into att values('fin0_again',public.superadmin_chat_attachment_finalize_v2((select attachment_id from b3 where idx=0),(select ticket from b3 where idx=0),100,repeat('a',64)));
reset role;
select is((select body#>>'{error,code}' from att where label='fin1_bad'),'CHAT_ATTACHMENT_MISMATCH','sha diferente e CHAT_ATTACHMENT_MISMATCH');
select is((select upload_status from public.chat_attachment_metadata where id=(select attachment_id from b3 where idx=1)),'failed','anexo com mismatch vira failed');
select is((select status::text from public.messages where id=(select message_id from b3 limit 1)),'draft','mismatch de um irmao NAO arquiva a mensagem');
select is((select body#>>'{error,code}' from att where label='fin0_again'),'CHAT_ATTACHMENT_TICKET_INVALID','ticket de finalizacao nao e reutilizavel');
set local role service_role;
insert into att values('fin2',public.superadmin_chat_attachment_finalize_v2((select attachment_id from b3 where idx=2),(select ticket from b3 where idx=2),300,repeat('c',64)));
reset role;
select ok((select body->>'ok'='true' and body#>>'{data,message_status}'='draft' from att where label='fin2'),
  'todos terminaram mas um falhou: mensagem espera o autor (draft)');

-- 7. discard do anexo falho publica a mensagem; thread mostra so os ready
select pg_temp.as_owner_a();
set local role authenticated;
insert into att values('discard1',public.superadmin_chat_attachment_discard_v1((select attachment_id from b3 where idx=1)));
reset role;
select ok((select body->>'ok'='true' and body#>>'{data,previous_status}'='failed' and body#>>'{data,upload_status}'='deleted'
  and body#>>'{data,message_status}'='active' from att where label='discard1'),
  'descartar o anexo falho publica a mensagem (active) e devolve object_key do descartado');
select is((select status::text from public.messages where id=(select message_id from b3 limit 1)),'active','mensagem publicada apos o descarte');
insert into att values('thread1',public.superadmin_chat_thread_v2((select conversation_id from ids),null,null,50));
select ok((select jsonb_array_length(body->'data'->'items')=1 and jsonb_array_length(body#>'{data,items,0,attachments}')=2
  and body#>>'{data,items,0,message_type}'='attachment' and body#>>'{data,items,0,body_text}'='3 anexos'
  and (select array_agg(a->>'file_name' order by a->>'file_name') from jsonb_array_elements(body#>'{data,items,0,attachments}') a)=array['a.jpg','c.pdf']
  and (select bool_and(a->>'asset_id'=a->>'id' and a->>'upload_status'='ready') from jsonb_array_elements(body#>'{data,items,0,attachments}') a)
  from att where label='thread1'),'thread_v2 lista UMA mensagem com os 2 anexos ready (asset_id = id) e sem o descartado');
set local role authenticated;
insert into att values('discard_active',public.superadmin_chat_attachment_discard_v1((select attachment_id from b3 where idx=0)));
insert into att values('read_ok',public.superadmin_chat_attachment_authorize_read_v1((select attachment_id from b3 where idx=0)));
insert into att values('read_deleted',public.superadmin_chat_attachment_authorize_read_v1((select attachment_id from b3 where idx=1)));
reset role;
select is((select body#>>'{error,code}' from att where label='discard_active'),'CHAT_ATTACHMENT_DISCARD_INVALID','mensagem publicada nao aceita descarte');
select is((select body->>'ok' from att where label='read_ok'),'true','authorize_read do anexo ready da mensagem publicada');
select is((select body#>>'{error,code}' from att where label='read_deleted'),'CHAT_ATTACHMENT_NOT_READY','anexo descartado nao e legivel');
select pg_temp.as_owner_b();
insert into att values('b_read',public.superadmin_chat_attachment_authorize_read_v1((select attachment_id from b3 where idx=0)));
select is((select body#>>'{error,code}' from att where label='b_read'),'CHAT_NOT_FOUND','outro tenant nao le o anexo pronto');

-- 8. descartar todos antes de finalizar arquiva a mensagem
select pg_temp.as_owner_a();
insert into att values('batch2',public.superadmin_chat_attachment_prepare_v2('9f150000-0000-4000-8000-000000000904',(select conversation_id from ids),
  jsonb_build_array(pg_temp.item('p.jpg','image/jpeg',10,repeat('1',64)),pg_temp.item('q.jpg','image/jpeg',10,repeat('2',64))),null));
create temporary table b2 as
  select (body#>>'{data,message_id}')::uuid message_id,(item->>'attachment_id')::uuid attachment_id,(item->>'index')::int idx
  from att, jsonb_array_elements(body#>'{data,items}') item where label='batch2';
grant select on b2 to authenticated, service_role;
set local role authenticated;
insert into att values('d2a',public.superadmin_chat_attachment_discard_v1((select attachment_id from b2 where idx=0)));
insert into att values('d2b',public.superadmin_chat_attachment_discard_v1((select attachment_id from b2 where idx=1)));
insert into att values('auth_after_discard',public.superadmin_chat_attachment_authorize_finalize_v1((select attachment_id from b2 where idx=1)));
reset role;
select ok((select (select body#>>'{data,message_status}' from att where label='d2a')='draft'
  and (select body#>>'{data,message_status}' from att where label='d2b')='archived'),
  'descartar o primeiro mantem draft; descartar o ultimo arquiva a mensagem');
select is((select body#>>'{error,code}' from att where label='auth_after_discard'),'CHAT_ATTACHMENT_TICKET_INVALID','ticket do anexo descartado esta consumido');

-- 9. expiracao sensivel a irmaos
insert into att values('batch_exp',public.superadmin_chat_attachment_prepare_v2('9f150000-0000-4000-8000-000000000905',(select conversation_id from ids),
  jsonb_build_array(pg_temp.item('r.jpg','image/jpeg',10,repeat('3',64)),pg_temp.item('s.jpg','image/jpeg',10,repeat('4',64))),null));
create temporary table bx as
  select (body#>>'{data,message_id}')::uuid message_id,(item->>'attachment_id')::uuid attachment_id,(item->>'finalize_ticket')::uuid ticket,(item->>'index')::int idx
  from att, jsonb_array_elements(body#>'{data,items}') item where label='batch_exp';
grant select on bx to authenticated, service_role;
select pg_temp.as_service();
set local role service_role;
insert into att values('finx0',public.superadmin_chat_attachment_finalize_v2((select attachment_id from bx where idx=0),(select ticket from bx where idx=0),10,repeat('3',64)));
reset role;
update app_private.superadmin_internal_chat_attachment_tickets set expires_at=now()-interval '1 minute' where attachment_id=(select attachment_id from bx where idx=1);
set local role service_role;
insert into att values('expire',public.superadmin_chat_attachment_expire_v1(100));
reset role;
select is((select (body#>>'{data,expired}')::int from att where label='expire'),1,'expire marca o pendente vencido');
select ok((select upload_status='failed' from public.chat_attachment_metadata where id=(select attachment_id from bx where idx=1))
  and (select status::text='draft' from public.messages where id=(select message_id from bx limit 1)),
  'irmao vencido vira failed e a mensagem com um ready continua draft (espera o autor)');
select pg_temp.as_owner_a();
set local role authenticated;
insert into att values('discard_exp',public.superadmin_chat_attachment_discard_v1((select attachment_id from bx where idx=1)));
reset role;
select is((select body#>>'{data,message_status}' from att where label='discard_exp'),'active','descartar o vencido publica a mensagem com o irmao ready');
-- lote de 1 vencido sem ready -> archived
insert into att values('batch_one',public.superadmin_chat_attachment_prepare_v2('9f150000-0000-4000-8000-000000000906',(select conversation_id from ids),
  jsonb_build_array(pg_temp.item('t.jpg','image/jpeg',10,repeat('5',64))),null));
update app_private.superadmin_internal_chat_attachment_tickets set expires_at=now()-interval '1 minute'
  where attachment_id=(select (body#>>'{data,items,0,attachment_id}')::uuid from att where label='batch_one');
select pg_temp.as_service();
set local role service_role;
insert into att values('expire2',public.superadmin_chat_attachment_expire_v1(100));
reset role;
select is((select status::text from public.messages where id=(select (body#>>'{data,message_id}')::uuid from att where label='batch_one')),'archived','lote de 1 vencido sem ready e arquivado');

-- 10. auditoria
select ok((select count(*)>=12 from audit.audit_logs where action_code='chat.attachment.prepare' and outcome='success'
  and institution_id='9f150000-0000-4000-8000-000000000010'),'prepare auditado por anexo (3+7+2+2+1 = 15 >= 12)');
select ok((select count(*)>=3 from audit.audit_logs where action_code='chat.attachment.finalize' and outcome='success' and institution_id='9f150000-0000-4000-8000-000000000010')
  and exists (select 1 from audit.audit_logs where action_code='chat.attachment.finalize' and outcome='failed' and reason_code='CHAT_ATTACHMENT_MISMATCH'),
  'finalize sucesso e mismatch auditados');
select ok((select count(*)>=4 from audit.audit_logs where action_code='chat.attachment.discard' and outcome='success' and institution_id='9f150000-0000-4000-8000-000000000010'),
  'discard auditado');
select ok(exists (select 1 from audit.audit_logs where action_code in ('chat.attachment.prepare','chat.attachment.discard') and outcome='denied' and reason_code='CHAT_NOT_FOUND'),
  'negativas cross-tenant auditadas');

select * from finish();
rollback;
