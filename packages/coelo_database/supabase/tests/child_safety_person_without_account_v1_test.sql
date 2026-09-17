-- Somente replay LOCAL descartavel. Fixtures sinteticas com rollback. Nenhuma conta real.
-- Prova da migration 20260917170000_child_safety_person_without_account_v1 (R15 Bloco C2,
-- ADR 0041 B6, owner.r12-18): pessoa autorizada sem conta com CPF como chave de dedupe
-- (HMAC, nunca em claro), documento em R2 privado (RLS forcada, descritor sem URL,
-- finalize por bilhete e service_role), escopo do ator e ramo authorized_person_id em
-- child_safety_request_authorization (exige documento ready).
begin;
create extension if not exists pgtap with schema extensions;
select plan(40);

-- Estrutura e grants.
select ok((select relrowsecurity and relforcerowsecurity from pg_class
  where oid='public.authorized_person_documents'::regclass),
  'authorized_person_documents tem RLS habilitada e forcada');
select ok(not has_table_privilege('authenticated','public.authorized_person_documents','select')
  and not has_table_privilege('anon','public.authorized_person_documents','select'),
  'nenhum papel do navegador le authorized_person_documents (deny-by-default)');
select is((select count(*)::int from pg_policies where schemaname='public' and tablename='authorized_person_documents'),0,
  'sem policies: acesso so por RPC');
select ok(has_function_privilege('authenticated','public.child_safety_register_person_without_account_v1(uuid,jsonb)','execute')
  and has_function_privilege('authenticated','public.child_safety_person_document_prepare_v1(uuid,uuid,text,bigint)','execute')
  and has_function_privilege('authenticated','public.child_safety_person_document_read_v1(uuid)','execute'),
  'authenticated executa registro, prepare e leitura');
select ok(not has_function_privilege('anon','public.child_safety_register_person_without_account_v1(uuid,jsonb)','execute'),
  'anon nao executa o registro');
select ok(not has_function_privilege('authenticated','public.child_safety_person_document_finalize_v1(uuid,uuid,bigint,text,text)','execute')
  and has_function_privilege('service_role','public.child_safety_person_document_finalize_v1(uuid,uuid,bigint,text,text)','execute'),
  'finalize e exclusivo do service_role (gateway)');
select ok(has_function_privilege('authenticated','public.child_safety_request_authorization(uuid,jsonb)','execute')
  and has_function_privilege('authenticated','app_private.child_safety_request_authorization(uuid,jsonb)','execute'),
  'grants de child_safety_request_authorization preservados');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='app_private' and p.proname='child_safety_request_authorization'
    and p.prosrc like '%PERSON_DOCUMENT_REQUIRED%'),1,
  'request_authorization tem o ramo de pessoa sem conta');

-- Catalogos sinteticos.
insert into public.platform_permissions(code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status,module_label,screen_label,action_label)
values ('child_safety.read','child_safety','directory','read','C16 read','high',false,'active','Seguranca da crianca','Directory','Ver'),
       ('child_safety.manage','child_safety','manage','manage','C16 manage','high',false,'active','Seguranca da crianca','Manage','Gerenciar')
on conflict do nothing;
insert into public.institution_types(id,code,name,status) values
('c1600000-0000-4000-8000-000000000001','c16-type','C16 type','active');
insert into public.unit_types(id,code,name,status) values
('c1600000-0000-4000-8000-000000000002','c16-unit','C16 unit','active');
insert into public.institutions(id,public_name,slug,institution_type_id) values
('c1601000-0000-4000-8000-000000000001','C16 synthetic A','c16-a','c1600000-0000-4000-8000-000000000001'),
('c1601000-0000-4000-8000-000000000002','C16 synthetic B','c16-b','c1600000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,unit_type_id,name,slug,handle) values
('c1602000-0000-4000-8000-000000000001','c1601000-0000-4000-8000-000000000001','c1600000-0000-4000-8000-000000000002','C16 unit A1','a1','c16unita1'),
('c1602000-0000-4000-8000-000000000002','c1601000-0000-4000-8000-000000000002','c1600000-0000-4000-8000-000000000002','C16 unit B1','b1','c16unitb1');
insert into public.people(id,person_type,first_name,last_name,display_name)
values ('c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema')
on conflict do nothing;
insert into public.people(id,person_type,first_name,last_name,display_name) values
('c1603000-0000-4000-8000-000000000001','adult','Gestor','A','Gestor A C16'),
('c1603000-0000-4000-8000-000000000002','adult','Gestor','B','Gestor B C16'),
('c1603000-0000-4000-8000-000000000003','adult','Leitor','C','Leitor C C16'),
('c1603000-0000-4000-8000-000000000004','adult','Com','Conta','Pessoa Com Conta C16'),
('c1603000-0000-4000-8000-000000000011','child','Ana','Crianca','Ana Crianca C16');
insert into public.family_relationship_types(id,code,name) values
('c1605000-0000-4000-8000-000000000001','c16_uncle','C16 uncle');
insert into public.child_contexts(id,child_person_id,institution_id) values
('c1604000-0000-4000-8000-000000000001','c1603000-0000-4000-8000-000000000011','c1601000-0000-4000-8000-000000000001');
insert into public.child_unit_links(child_context_id,unit_id,status,accepted_by,accepted_at) values
('c1604000-0000-4000-8000-000000000001','c1602000-0000-4000-8000-000000000001','active','c1603000-0000-4000-8000-000000000001',now());
select case when not exists(select 1 from vault.secrets where name='coelo_person_identity_hmac_v1')
  then vault.create_secret('c16-local-only-hmac-key','coelo_person_identity_hmac_v1') end;
-- Pessoa com conta e CPF 529.982.247-25 (valido de exemplo).
insert into app_private.person_identity_identifiers(person_id,identifier_kind,normalized_value_hmac,hmac_key_version,masked_value)
values ('c1603000-0000-4000-8000-000000000004','cpf',app_private.person_identity_hmac_v1('52998224725'),1,'***.***.***-25');

-- Atores (realm de pessoas): gestor escopado em A (manage), gestor escopado em B (manage), leitor (read).
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
('c1608000-0000-4000-8000-000000000001','authenticated','authenticated','c16-a@invalid.test',now(),now(),now(),'{}','{}'),
('c1608000-0000-4000-8000-000000000002','authenticated','authenticated','c16-b@invalid.test',now(),now(),now(),'{}','{}'),
('c1608000-0000-4000-8000-000000000003','authenticated','authenticated','c16-c@invalid.test',now(),now(),now(),'{}','{}');
insert into public.person_auth_links(person_id,auth_user_id) values
('c1603000-0000-4000-8000-000000000001','c1608000-0000-4000-8000-000000000001'),
('c1603000-0000-4000-8000-000000000002','c1608000-0000-4000-8000-000000000002'),
('c1603000-0000-4000-8000-000000000003','c1608000-0000-4000-8000-000000000003');
insert into public.platform_roles(id,code,name,max_scope_kind) values
('c160b000-0000-4000-8000-000000000001','c16_safety_manager','C16 manager','platform'),
('c160b000-0000-4000-8000-000000000002','c16_safety_reader','C16 reader','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect)
select 'c160b000-0000-4000-8000-000000000001',id,'allow' from public.platform_permissions where code in ('child_safety.read','child_safety.manage');
insert into public.platform_role_permissions(role_id,permission_id,effect)
select 'c160b000-0000-4000-8000-000000000002',id,'allow' from public.platform_permissions where code='child_safety.read';
insert into public.platform_memberships(person_id,role_id,status,scope_kind,scope_institution_id) values
('c1603000-0000-4000-8000-000000000001','c160b000-0000-4000-8000-000000000001','active','institution','c1601000-0000-4000-8000-000000000001'),
('c1603000-0000-4000-8000-000000000002','c160b000-0000-4000-8000-000000000001','active','institution','c1601000-0000-4000-8000-000000000002'),
('c1603000-0000-4000-8000-000000000003','c160b000-0000-4000-8000-000000000002','active','platform',null);

-- Gestor A registra.
select set_config('request.jwt.claims',jsonb_build_object('sub','c1608000-0000-4000-8000-000000000001',
  'session_id','c160f000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok($$select public.child_safety_register_person_without_account_v1('c1609000-0000-4000-8000-000000000001',
  '{"child_context_id":"c1604000-0000-4000-8000-000000000001","unit_id":"c1602000-0000-4000-8000-000000000001","full_name":"Tio Sem Conta","cpf":"111.111.111-11"}')$$,
  '22023','invalid person registration','CPF invalido e recusado');
select throws_ok($$select public.child_safety_register_person_without_account_v1('c1609000-0000-4000-8000-000000000002',
  '{"child_context_id":"c1604000-0000-4000-8000-000000000001","unit_id":"c1602000-0000-4000-8000-000000000001","full_name":"Tio Sem Conta","cpf":"529.982.247-25"}')$$,
  '22023','person already has an account','CPF de pessoa com conta e recusado (usar a busca B5)');
select set_config('test.c16_reg',public.child_safety_register_person_without_account_v1('c1609000-0000-4000-8000-000000000003',
  '{"child_context_id":"c1604000-0000-4000-8000-000000000001","unit_id":"c1602000-0000-4000-8000-000000000001","full_name":"Tio  Sem Conta","cpf":"111.444.777-35","mobile_phone":"(11) 98888-7777","email":"Tio@Invalid.Test"}')::text,true);
select is(current_setting('test.c16_reg')::jsonb->>'has_account','false','registro devolve pessoa sem conta');
select is(current_setting('test.c16_reg')::jsonb->>'existing','false','primeiro registro nao e reaproveitamento');
select is(current_setting('test.c16_reg')::jsonb->>'cpf_masked','***.***.***-35','CPF mascarado com os dois ultimos digitos');
select is(current_setting('test.c16_reg')::jsonb->>'document_status','missing','sem documento no registro');
select ok(current_setting('test.c16_reg') !~ '11144477735' and current_setting('test.c16_reg') !~ '444.777'
  and current_setting('test.c16_reg') !~ '98888' and current_setting('test.c16_reg') !~ 'invalid.test',
  'payload do registro nao contem CPF, celular ou e-mail');
select set_config('test.c16_person',current_setting('test.c16_reg')::jsonb->>'authorized_person_id',true);
select is(current_setting('test.c16_reg'),public.child_safety_register_person_without_account_v1('c1609000-0000-4000-8000-000000000003',
  '{"child_context_id":"c1604000-0000-4000-8000-000000000001","unit_id":"c1602000-0000-4000-8000-000000000001","full_name":"Tio  Sem Conta","cpf":"111.444.777-35","mobile_phone":"(11) 98888-7777","email":"Tio@Invalid.Test"}')::text,
  'mesmo request_id devolve o recibo idempotente');
select set_config('test.c16_dup',public.child_safety_register_person_without_account_v1('c1609000-0000-4000-8000-000000000004',
  '{"child_context_id":"c1604000-0000-4000-8000-000000000001","unit_id":"c1602000-0000-4000-8000-000000000001","full_name":"Outro Nome","cpf":"11144477735"}')::text,true);
select is(current_setting('test.c16_dup')::jsonb->>'existing','true','segundo cadastro com o mesmo CPF reaproveita a pessoa (dedupe)');
select is(current_setting('test.c16_dup')::jsonb->>'authorized_person_id',current_setting('test.c16_person'),
  'dedupe devolve o mesmo authorized_person_id');
-- request_authorization sem documento: recusado.
select throws_ok(format($$select public.child_safety_request_authorization('c1609000-0000-4000-8000-000000000010',
  '{"child_context_id":"c1604000-0000-4000-8000-000000000001","unit_id":"c1602000-0000-4000-8000-000000000001","authorized_person_id":"%s","relationship_code":"c16_uncle","capability_codes":["pickup"],"request_reason":"C16 sem documento"}')$$,
  current_setting('test.c16_person')),'22023','person document required',
  'pessoa sem conta sem documento ready nao pode ser autorizada');
-- Prepare do documento.
select set_config('test.c16_prep',public.child_safety_person_document_prepare_v1('c1609000-0000-4000-8000-000000000020',
  current_setting('test.c16_person')::uuid,'image/jpeg',12345)::text,true);
select ok(current_setting('test.c16_prep')::jsonb->>'object_key' ~ ('^tenants/c1601000-0000-4000-8000-000000000001/child_safety/authorized_person/'
  ||current_setting('test.c16_person')||'/identity-document/[0-9a-f-]{36}/original/[0-9a-f-]{36}[.]jpg$'),
  'chave opaca R2 no formato canonico da ADR 0032');
select is(current_setting('test.c16_prep')::jsonb->>'bucket_id','coelo-documents-prod','documento vai para o bucket de documentos');
select ok(current_setting('test.c16_prep') !~ 'http' and current_setting('test.c16_prep') !~ 'signed',
  'descritor de prepare nao contem URL');
select set_config('test.c16_doc',current_setting('test.c16_prep')::jsonb->>'document_id',true);
select set_config('test.c16_ticket',(public.child_safety_person_document_authorize_finalize_v1(current_setting('test.c16_doc')::uuid))->>'finalize_ticket',true);
reset role;

-- Gestor B: nao ve a pessoa de A (prepare e leitura), nem registra no contexto de A por leitura.
select set_config('request.jwt.claims',jsonb_build_object('sub','c1608000-0000-4000-8000-000000000002',
  'session_id','c160f000-0000-4000-8000-000000000002','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok(format($$select public.child_safety_person_document_prepare_v1('c1609000-0000-4000-8000-000000000021','%s','image/png',100)$$,
  current_setting('test.c16_person')),'P0002','child safety record unavailable','prepare cross-tenant e negado');
select throws_ok(format($$select public.child_safety_person_document_authorize_finalize_v1('%s')$$,current_setting('test.c16_doc')),
  'P0002','child safety record unavailable','bilhete de finalize so para o criador');
reset role;
-- Leitor (so child_safety.read, sem manage): nao registra.
select set_config('request.jwt.claims',jsonb_build_object('sub','c1608000-0000-4000-8000-000000000003',
  'session_id','c160f000-0000-4000-8000-000000000003','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok($$select public.child_safety_register_person_without_account_v1('c1609000-0000-4000-8000-000000000005',
  '{"child_context_id":"c1604000-0000-4000-8000-000000000001","unit_id":"c1602000-0000-4000-8000-000000000001","full_name":"Outro","cpf":"11144477735"}')$$,
  'P0002','child safety record unavailable','ator sem gestao do contexto nao registra');
reset role;

-- Finalize: so service_role, so com bilhete valido e bytes iguais ao declarado.
select set_config('request.jwt.claims',jsonb_build_object('sub','c1608000-0000-4000-8000-000000000001',
  'session_id','c160f000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok(format($$select public.child_safety_person_document_finalize_v1('%s','%s',12345,'image/jpeg',repeat('a',64))$$,
  current_setting('test.c16_doc'),current_setting('test.c16_ticket')),'42501',null,'authenticated nao finaliza');
reset role;
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
select throws_ok(format($$select public.child_safety_person_document_finalize_v1('%s','%s',999,'image/jpeg',repeat('a',64))$$,
  current_setting('test.c16_doc'),current_setting('test.c16_ticket')),'23514','uploaded document mismatch',
  'bytes diferentes do declarado sao recusados');
select is((public.child_safety_person_document_finalize_v1(current_setting('test.c16_doc')::uuid,
  current_setting('test.c16_ticket')::uuid,12345,'image/jpeg',repeat('a',64)))->>'status','ready',
  'finalize com bilhete valido marca o documento ready');
select throws_ok(format($$select public.child_safety_person_document_finalize_v1('%s','%s',12345,'image/jpeg',repeat('a',64))$$,
  current_setting('test.c16_doc'),current_setting('test.c16_ticket')),'42501','finalize ticket invalid',
  'bilhete e consumido uma unica vez');
reset role;

-- Com documento ready: autorizacao pendente criada para a pessoa sem conta.
select set_config('request.jwt.claims',jsonb_build_object('sub','c1608000-0000-4000-8000-000000000001',
  'session_id','c160f000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.c16_auth',public.child_safety_request_authorization('c1609000-0000-4000-8000-000000000011',
  format('{"child_context_id":"c1604000-0000-4000-8000-000000000001","unit_id":"c1602000-0000-4000-8000-000000000001","authorized_person_id":"%s","relationship_code":"c16_uncle","capability_codes":["pickup"],"request_reason":"C16 com documento"}',
  current_setting('test.c16_person'))::jsonb)::text,true);
select is(current_setting('test.c16_auth')::jsonb->>'decision_status','pending','autorizacao da pessoa sem conta nasce pendente');
select is((select ap.person_id is null and ap.display_name='Tio Sem Conta' from public.authorized_person_authorizations a
  join public.authorized_people ap on ap.id=a.authorized_person_id
  where a.id=(current_setting('test.c16_auth')::jsonb->>'authorization_id')::uuid),true,
  'autorizacao aponta para a pessoa sem conta (nome normalizado, person_id nulo)');
select throws_ok(format($$select public.child_safety_request_authorization('c1609000-0000-4000-8000-000000000012',
  '{"child_context_id":"c1604000-0000-4000-8000-000000000001","unit_id":"c1602000-0000-4000-8000-000000000001","authorized_person_id":"%s","person_id":"c1603000-0000-4000-8000-000000000004","relationship_code":"c16_uncle","capability_codes":["pickup"],"request_reason":"C16 ambiguo"}')$$,
  current_setting('test.c16_person')),'22023','invalid authorization request','person_id e authorized_person_id juntos sao recusados');
-- Leitura do documento: gestor A ve o descritor (sem URL); superadmin_child_safety_get projeta a pessoa sem conta.
select set_config('test.c16_read',public.child_safety_person_document_read_v1(current_setting('test.c16_doc')::uuid)::text,true);
select is(current_setting('test.c16_read')::jsonb->>'expires_in_seconds','60','descritor de leitura com janela de 60 s');
select ok(current_setting('test.c16_read') !~ 'http','descritor de leitura nao contem URL');
select is((select count(*)::int from jsonb_array_elements(public.superadmin_child_safety_get('c1603000-0000-4000-8000-000000000011')->'authorizations') a
  where a->>'person_id' is null and a->>'name'='Tio Sem Conta'),1,
  'detalhe da crianca lista a autorizacao da pessoa sem conta');
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','c1608000-0000-4000-8000-000000000002',
  'session_id','c160f000-0000-4000-8000-000000000002','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok(format($$select public.child_safety_person_document_read_v1('%s')$$,current_setting('test.c16_doc')),
  'P0002','child safety record unavailable','leitura cross-tenant e negada');
reset role;

-- Persistencia minimizada e auditoria.
select is((select document_ciphertext is null and document_fingerprint is not null and document_last4='7735'
  and contact_phone_last4='7777' and contact_email_masked is not null and contact_email_hash is not null
  from public.authorized_people where id=current_setting('test.c16_person')::uuid),true,
  'pessoa sem conta guarda so HMAC + ultimos 4 do CPF e contato minimizado');
select is((select count(*)::int from public.authorized_people where document_fingerprint=encode(app_private.person_identity_hmac_v1('11144477735'),'hex')
  and institution_id='c1601000-0000-4000-8000-000000000001'),1,'uma unica linha por CPF na instituicao');
select is((select count(*)::int from audit.audit_logs where action_code in ('child_safety.person_without_account.register',
  'child_safety.person_document.prepare','child_safety.person_document.finalize','child_safety.person_document.read')
  and outcome='success'),5,'auditoria: 2 registros (novo + dedupe), prepare, finalize e leitura');
select is((select count(*)::int from audit.audit_logs where action_code like 'child_safety.person_%'
  and coalesce(after_json::text,'') ~ '11144477735'),0,'auditoria nao guarda o CPF');

select * from finish();
rollback;
