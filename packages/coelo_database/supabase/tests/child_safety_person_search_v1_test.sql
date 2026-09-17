-- Somente replay LOCAL descartavel. Fixtures sinteticas com rollback. Nenhuma conta real.
-- Prova da migration 20260917160000_child_safety_person_search_v1 (R15 Bloco C2, ADR 0041 B5,
-- owner.r12-17): leitor unico de pessoa autorizada com deteccao de tipo, minimo por tipo,
-- escopo do ator, resultado minimizado (CPF nunca), criancas vinculadas do escopo,
-- limite de taxa (PT422) e auditoria sem o texto buscado.
begin;
create extension if not exists pgtap with schema extensions;
select plan(33);

-- Estrutura e grants.
select ok(to_regprocedure('public.superadmin_person_search_v1(text)') is not null,
  'wrapper publico superadmin_person_search_v1(text) existe');
select ok((select prosecdef and coalesce(array_to_string(proconfig,','),'')='search_path=""'
  from pg_proc where oid='app_private.superadmin_person_search_v1(text)'::regprocedure),
  'funcao privada e security definer com search_path vazio');
select ok(has_function_privilege('authenticated','public.superadmin_person_search_v1(text)','execute'),
  'authenticated executa o wrapper publico');
select ok(not has_function_privilege('anon','public.superadmin_person_search_v1(text)','execute'),
  'anon nao executa o wrapper publico');
select ok((select relrowsecurity and relforcerowsecurity from pg_class
  where oid='app_private.person_search_hits'::regclass),
  'tabela de limite de taxa tem RLS habilitada e forcada');
select ok(not has_table_privilege('authenticated','app_private.person_search_hits','select'),
  'authenticated nao le a tabela de limite de taxa');

-- Catalogos sinteticos (forma canonica de producao).
insert into public.platform_permissions(code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status,module_label,screen_label,action_label)
values ('child_safety.read','child_safety','directory','read','C15 read','high',false,'active','Seguranca da crianca','Directory','Ver')
on conflict do nothing;
insert into public.institution_types(id,code,name,status) values
('c1500000-0000-4000-8000-000000000001','c15-type','C15 type','active');
insert into public.unit_types(id,code,name,status) values
('c1500000-0000-4000-8000-000000000002','c15-unit','C15 unit','active');
insert into public.institutions(id,public_name,slug,institution_type_id) values
('c1501000-0000-4000-8000-000000000001','C15 synthetic A','c15-a','c1500000-0000-4000-8000-000000000001'),
('c1501000-0000-4000-8000-000000000002','C15 synthetic B','c15-b','c1500000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,unit_type_id,name,slug,handle) values
('c1502000-0000-4000-8000-000000000001','c1501000-0000-4000-8000-000000000001','c1500000-0000-4000-8000-000000000002','C15 unit A1','a1','c15unita1'),
('c1502000-0000-4000-8000-000000000002','c1501000-0000-4000-8000-000000000002','c1500000-0000-4000-8000-000000000002','C15 unit B1','b1','c15unitb1');
insert into public.people(id,person_type,first_name,last_name,display_name)
values ('c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema')
on conflict do nothing;
insert into public.people(id,person_type,first_name,last_name,display_name,mobile_phone) values
('c1503000-0000-4000-8000-000000000001','adult','Ana','Maria','Ana Maria C15','+55 11 99999-1234'),
('c1503000-0000-4000-8000-000000000002','adult','Bruno','Beta','Bruno Beta C15','+55 11 98888-5678'),
('c1503000-0000-4000-8000-000000000003','adult','Carla','Autorizada','Carla Autorizada C15',null),
('c1503000-0000-4000-8000-000000000004','adult','Ator','Escopado','Ator Escopado C15',null),
('c1503000-0000-4000-8000-000000000005','adult','Ator','Global','Ator Global C15',null),
('c1503000-0000-4000-8000-000000000006','adult','Ator','SemPermissao','Ator Sem Permissao C15',null),
('c1503000-0000-4000-8000-000000000011','child','Ana','Crianca','Ana Crianca C15',null),
('c1503000-0000-4000-8000-000000000012','child','Bia','Crianca','Bia Crianca C15',null);
insert into public.family_relationship_types(id,code,name) values
('c1505000-0000-4000-8000-000000000001','c15_mother','C15 mother');
-- Ana Maria e responsavel por Ana Crianca (instituicao A) e Bia Crianca (instituicao B);
-- Bruno so por Bia (B); Carla e pessoa autorizada em A sem vinculo de responsavel.
insert into public.child_contexts(id,child_person_id,institution_id) values
('c1504000-0000-4000-8000-000000000001','c1503000-0000-4000-8000-000000000011','c1501000-0000-4000-8000-000000000001'),
('c1504000-0000-4000-8000-000000000002','c1503000-0000-4000-8000-000000000012','c1501000-0000-4000-8000-000000000002');
insert into public.child_unit_links(child_context_id,unit_id,status,accepted_by,accepted_at) values
('c1504000-0000-4000-8000-000000000001','c1502000-0000-4000-8000-000000000001','active','c1503000-0000-4000-8000-000000000001',now()),
('c1504000-0000-4000-8000-000000000002','c1502000-0000-4000-8000-000000000002','active','c1503000-0000-4000-8000-000000000002',now());
insert into public.guardian_links(guardian_person_id,child_person_id,relation_type,relationship_type_id) values
('c1503000-0000-4000-8000-000000000001','c1503000-0000-4000-8000-000000000011','mother','c1505000-0000-4000-8000-000000000001'),
('c1503000-0000-4000-8000-000000000001','c1503000-0000-4000-8000-000000000012','mother','c1505000-0000-4000-8000-000000000001'),
('c1503000-0000-4000-8000-000000000002','c1503000-0000-4000-8000-000000000012','father','c1505000-0000-4000-8000-000000000001');
insert into public.authorized_people(id,institution_id,display_name,person_id) values
('c1506000-0000-4000-8000-000000000001','c1501000-0000-4000-8000-000000000001','Carla Autorizada C15','c1503000-0000-4000-8000-000000000003');
-- O gatilho de pessoas ja gera um handle; a fixture so o torna previsivel.
update public.person_handles set normalized_handle='ana.maria.c15'
where person_id='c1503000-0000-4000-8000-000000000001' and status='active';
insert into public.person_contacts(person_id,contact_type,normalized_value_hash,masked_value) values
('c1503000-0000-4000-8000-000000000001','email',
 encode(extensions.digest(convert_to('ana.maria.c15@invalid.test','UTF8'),'sha256'),'hex'),'a***@invalid.test');
-- CPF: apenas HMAC (chave do vault; semeada localmente se ausente). 111.444.777-35 e um CPF valido de exemplo.
select case when not exists(select 1 from vault.secrets where name='coelo_person_identity_hmac_v1')
  then vault.create_secret('c15-local-only-hmac-key','coelo_person_identity_hmac_v1') end;
insert into app_private.person_identity_identifiers(person_id,identifier_kind,normalized_value_hmac,hmac_key_version,masked_value)
values ('c1503000-0000-4000-8000-000000000001','cpf',app_private.person_identity_hmac_v1('11144477735'),1,'***.***.***-35');

-- Atores do realm de pessoas: escopado em A, global (plataforma) e sem permissao.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
('c1508000-0000-4000-8000-000000000001','authenticated','authenticated','c15-scoped@invalid.test',now(),now(),now(),'{}','{}'),
('c1508000-0000-4000-8000-000000000002','authenticated','authenticated','c15-global@invalid.test',now(),now(),now(),'{}','{}'),
('c1508000-0000-4000-8000-000000000003','authenticated','authenticated','c15-none@invalid.test',now(),now(),now(),'{}','{}');
insert into public.person_auth_links(person_id,auth_user_id) values
('c1503000-0000-4000-8000-000000000004','c1508000-0000-4000-8000-000000000001'),
('c1503000-0000-4000-8000-000000000005','c1508000-0000-4000-8000-000000000002'),
('c1503000-0000-4000-8000-000000000006','c1508000-0000-4000-8000-000000000003');
insert into public.platform_roles(id,code,name,max_scope_kind) values
('c150b000-0000-4000-8000-000000000001','c15_safety_reader','C15 synthetic reader','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect)
select 'c150b000-0000-4000-8000-000000000001',id,'allow' from public.platform_permissions where code='child_safety.read';
insert into public.platform_memberships(person_id,role_id,status,scope_kind,scope_institution_id) values
('c1503000-0000-4000-8000-000000000004','c150b000-0000-4000-8000-000000000001','active','institution','c1501000-0000-4000-8000-000000000001'),
('c1503000-0000-4000-8000-000000000005','c150b000-0000-4000-8000-000000000001','active','platform',null);

-- Ator escopado em A.
select set_config('request.jwt.claims',jsonb_build_object('sub','c1508000-0000-4000-8000-000000000001',
  'session_id','c150f000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;

-- Minimos por tipo.
select throws_ok($$select public.superadmin_person_search_v1('An')$$,'22023',
  'person search needs more characters','nome com 2 caracteres e recusado');
select throws_ok($$select public.superadmin_person_search_v1('@an')$$,'22023',
  'person search needs more characters','@handle com 2 caracteres e recusado');
select throws_ok($$select public.superadmin_person_search_v1('123')$$,'22023',
  'person search needs more characters','3 digitos sao recusados');
select throws_ok($$select public.superadmin_person_search_v1(repeat('a',121))$$,'22023',
  'invalid person search','consulta acima de 120 caracteres e recusada');

-- Nome, @handle, e-mail exato, celular (4 digitos, com mascara) e CPF completo (com mascara).
select set_config('test.c15_name',public.superadmin_person_search_v1('ana mar')::text,true);
select is(current_setting('test.c15_name')::jsonb->>'kind','name','texto livre e detectado como nome');
select is((select jsonb_array_length(current_setting('test.c15_name')::jsonb->'results')),1,
  'nome encontra a responsavel do escopo');
select is(current_setting('test.c15_name')::jsonb#>>'{results,0,display_name}','Ana Maria C15',
  'resultado traz o nome de exibicao');
select is(current_setting('test.c15_name')::jsonb#>>'{results,0,initials}','AM','resultado traz as iniciais');
select is(current_setting('test.c15_name')::jsonb#>>'{results,0,handle}','@ana.maria.c15','resultado traz o @handle');
select is(current_setting('test.c15_name')::jsonb#>>'{results,0,phone_last4}','1234',
  'resultado traz so os ultimos 4 digitos do celular');
select ok(current_setting('test.c15_name') !~ '99999' and current_setting('test.c15_name') !~ '11144477735'
  and current_setting('test.c15_name') !~ '444.777' and current_setting('test.c15_name') !~ 'cpf'
  and current_setting('test.c15_name') !~ 'invalid.test',
  'payload nao contem celular inteiro, CPF (nem mascarado) ou e-mail');
select is((select jsonb_array_length(current_setting('test.c15_name')::jsonb#>'{results,0,children}')),1,
  'responsavel lista so a crianca vinculada dentro do escopo do ator (Bia, da instituicao B, fica fora)');
select is(current_setting('test.c15_name')::jsonb#>>'{results,0,children,0,child_context_id}',
  'c1504000-0000-4000-8000-000000000001','crianca listada traz o contexto e a unidade para preencher o wizard');

select is((public.superadmin_person_search_v1('@ana.ma')->'results'->0->>'matched_by'),'handle',
  '@prefixo encontra pelo handle');
select is((public.superadmin_person_search_v1('Ana.Maria.C15@invalid.test')->'results'->0->>'matched_by'),'email',
  'e-mail completo (qualquer caixa) encontra pelo hash');
select is((select jsonb_array_length(public.superadmin_person_search_v1('ana@invalid.test')->'results')),0,
  'prefixo de e-mail nao encontra (e-mail so existe como hash)');
select is((public.superadmin_person_search_v1('99-1234')->'results'->0->>'matched_by'),'phone',
  '4 digitos com mascara encontram pelo celular');
select is((public.superadmin_person_search_v1('111.444.777-35')->'results'->0->>'matched_by'),'document',
  'CPF completo com mascara encontra pelo HMAC, marcado como documento');
select is((select jsonb_array_length(public.superadmin_person_search_v1('111.444')->'results')),0,
  'CPF parcial nao encontra por CPF (tratado como digitos de celular)');

-- Escopo do ator: Bruno so tem presenca na instituicao B.
select is((select jsonb_array_length(public.superadmin_person_search_v1('Bruno')->'results')),0,
  'pessoa fora do escopo do ator nao aparece (cross-tenant vazio)');
select is((public.superadmin_person_search_v1('Carla Aut')->'results'->0->>'display_name'),'Carla Autorizada C15',
  'pessoa autorizada da instituicao do escopo aparece mesmo sem vinculo de responsavel');
reset role;

-- Ator global ve Bruno e as duas criancas de Ana Maria.
select set_config('request.jwt.claims',jsonb_build_object('sub','c1508000-0000-4000-8000-000000000002',
  'session_id','c150f000-0000-4000-8000-000000000002','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select is((select jsonb_array_length(public.superadmin_person_search_v1('Bruno')->'results')),1,
  'ator de plataforma ve a pessoa da instituicao B');
select is((select jsonb_array_length(public.superadmin_person_search_v1('Ana Maria')->'results'->0->'children')),2,
  'ator de plataforma ve as duas criancas vinculadas');
reset role;

-- Limite de taxa: 30 buscas na janela; a 31a responde PT422 e nao grava nova linha.
insert into app_private.person_search_hits(actor_person_id)
select 'c1503000-0000-4000-8000-000000000004' from generate_series(1,29);
select set_config('request.jwt.claims',jsonb_build_object('sub','c1508000-0000-4000-8000-000000000001',
  'session_id','c150f000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok($$select public.superadmin_person_search_v1('Ana Maria')$$,'PT422',
  'person search rate limit','31a busca no minuto responde PT422 (PERSON_SEARCH_RATE_LIMIT)');
reset role;

-- Auditoria: uma linha por busca bem-sucedida, sem o texto buscado.
select is((select count(*)::int from audit.audit_logs where actor_person_id='c1503000-0000-4000-8000-000000000004'
  and action_code='child_safety.person_search' and outcome='success'),9,
  'cada busca bem-sucedida do ator escopado gerou uma linha de auditoria (9)');
select is((select count(*)::int from audit.audit_logs where action_code='child_safety.person_search'
  and (coalesce(after_json::text,'') ilike '%ana%' or coalesce(reason,'') ilike '%ana%')),0,
  'auditoria nao guarda o texto buscado');

-- Ator sem child_safety.read: 42501.
select set_config('request.jwt.claims',jsonb_build_object('sub','c1508000-0000-4000-8000-000000000003',
  'session_id','c150f000-0000-4000-8000-000000000003','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok($$select public.superadmin_person_search_v1('Ana Maria')$$,'42501',
  'child safety capability required','ator sem child_safety.read e negado');
reset role;

select * from finish();
rollback;
