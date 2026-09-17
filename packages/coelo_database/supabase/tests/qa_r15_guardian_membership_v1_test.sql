-- Somente replay LOCAL descartavel. Fixtures sinteticas com rollback. Nenhuma conta real.
-- Prova da migration 20260917113000_qa_r15_guardian_membership_v1 (R15 B'/AP-2): sem membership o
-- Principal (list_my_principal_contexts) devolve 0 contextos ao responsavel QA R15 mesmo depois do
-- AP-1; a fixture cria uma membership 'guardian' de escopo group na turma da crianca, idempotente e
-- fail-closed, e o leitor passa a devolver 1 contexto. Reusa a massa e a fixture v1 (AP-1).
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

-- 1-3. Estrutura e exposicao.
select has_function('app_private', 'seed_qa_r15_guardian_membership_v1',
  array['text','uuid','uuid','uuid','text'], 'fixture de membership existe com a assinatura esperada');
select ok((select prosecdef and coalesce(array_to_string(proconfig,','),'')='search_path=""'
  and pg_get_userbyid(proowner)='postgres'
  from pg_proc where oid='app_private.seed_qa_r15_guardian_membership_v1(text,uuid,uuid,uuid,text)'::regprocedure),
  'security definer, search_path vazio, dona postgres');
select ok(not has_function_privilege('anon','app_private.seed_qa_r15_guardian_membership_v1(text,uuid,uuid,uuid,text)','execute')
  and not has_function_privilege('authenticated','app_private.seed_qa_r15_guardian_membership_v1(text,uuid,uuid,uuid,text)','execute')
  and not has_function_privilege('service_role','app_private.seed_qa_r15_guardian_membership_v1(text,uuid,uuid,uuid,text)','execute'),
  'anon, authenticated e service_role nao executam a fixture');

-- Massa sintetica (ids de producao) + AP-1 aplicado.
insert into public.people(id,person_type,first_name,last_name,display_name)
select 'c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema'
where not exists (select 1 from public.people where id='c0e10000-0000-4000-8000-000000000001');
insert into public.institutions(id,public_name,slug,institution_type_id,status) values
('d0c40000-0000-4000-8000-000000000001','QA R04 Cuidado (sintetico)','qa-r04-cuidado-sintetico',
 (select id from public.institution_types where status='active' order by code limit 1),'active');
insert into public.units(id,institution_id,unit_type_id,name,slug,handle,status) values
('d0c40000-0000-4000-8000-000000000002','d0c40000-0000-4000-8000-000000000001',
 (select id from public.unit_types where status='active' order by code limit 1),'Unidade QA R04','unidade-qa-r04','unidadeqar04','active');
insert into public.groups(id,institution_id,unit_id,name,handle,status) values
('368a5cea-2bcf-4fa4-ad1f-18da58694551','d0c40000-0000-4000-8000-000000000001',
 'd0c40000-0000-4000-8000-000000000002','Turma QA R04 Estrutura (editada)','turmaqar04estrutura','active'),
('a9150000-0000-4000-8000-000000000501','d0c40000-0000-4000-8000-000000000001',
 'd0c40000-0000-4000-8000-000000000002','Turma QA R15 sem criancas','turmaqar15vazia','active');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
('da915f98-bfad-49f6-9914-fe57a30584c9','adult','QA R15','Responsavel','QA R15 Responsavel','draft'),
('93457405-a4eb-4273-9579-ef84136a794b','child','QA R15','Crianca 1','QA R15 Crianca 1','active'),
('14d70a25-244f-409f-a164-71d87b491650','child','QA R15','Crianca 2','QA R15 Crianca 2','active');
insert into public.child_contexts(id,child_person_id,institution_id) values
('1a6158fe-6cab-427c-9496-96e4273ab184','93457405-a4eb-4273-9579-ef84136a794b','d0c40000-0000-4000-8000-000000000001'),
('519ef941-3edb-41b6-94c4-55ed4638aefd','14d70a25-244f-409f-a164-71d87b491650','d0c40000-0000-4000-8000-000000000001');
insert into public.child_unit_links(id,child_context_id,unit_id,status) values
('72863003-0000-4000-8000-000000000001','1a6158fe-6cab-427c-9496-96e4273ab184','d0c40000-0000-4000-8000-000000000002','pending'),
('87cc5440-0000-4000-8000-000000000002','519ef941-3edb-41b6-94c4-55ed4638aefd','d0c40000-0000-4000-8000-000000000002','pending');
insert into public.child_group_links(child_unit_link_id,group_id,status) values
('72863003-0000-4000-8000-000000000001','368a5cea-2bcf-4fa4-ad1f-18da58694551','active'),
('87cc5440-0000-4000-8000-000000000002','368a5cea-2bcf-4fa4-ad1f-18da58694551','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
('a9150000-0000-4000-8000-000000000201','authenticated','authenticated','qa-r15-responsavel@coelo.me',now(),now(),now(),'{}','{}'),
('a9150000-0000-4000-8000-000000000202','authenticated','authenticated','qa-r15-educador@coelo.me',now(),now(),now(),'{}','{}');

-- 4. Antes do AP-1, a fixture de membership recusa (sem conta ligada a pessoa).
select throws_ok($$select app_private.seed_qa_r15_guardian_membership_v1()$$,
  'P0002','qa_guardian_person_missing_or_not_synthetic','sem person_auth_link (AP-1) a fixture recusa');
select set_config('test.ap1', app_private.seed_qa_r15_guardian_fixture_v1()::text, true);

-- 5. Achado D1 reproduzido: apos o AP-1 o Principal ainda devolve 0 contextos.
select set_config('request.jwt.claims', jsonb_build_object('sub','a9150000-0000-4000-8000-000000000201',
  'role','authenticated','aal','aal1')::text, true);
set local role authenticated;
select is((select count(*)::int from public.list_my_principal_contexts()),0,
  'antes da membership, list_my_principal_contexts devolve 0 contextos ao responsavel');
reset role;

-- 6-8. Fail-closed.
select throws_ok($$select app_private.seed_qa_r15_guardian_membership_v1('qa-r15-educador@coelo.me')$$,
  'P0002','qa_guardian_person_missing_or_not_synthetic','conta sem pessoa ligada recusa');
select throws_ok($$select app_private.seed_qa_r15_guardian_membership_v1('qa-r15-responsavel@coelo.me',
  'd0c40000-0000-4000-8000-000000000001','d0c40000-0000-4000-8000-000000000002','a9150000-0000-4000-8000-000000000501')$$,
  'P0002','qa_guardian_link_missing_for_group','turma sem crianca do responsavel recusa');
select throws_ok($$select app_private.seed_qa_r15_guardian_membership_v1('qa-r15-responsavel@coelo.me',
  'd0c40000-0000-4000-8000-000000000001','d0c40000-0000-4000-8000-000000000002','368a5cea-2bcf-4fa4-ad1f-18da58694551','Bad Role')$$,
  '22023','invalid_qa_fixture_input','role_code fora do padrao recusa');
select is((select count(*)::int from public.institution_memberships where person_id='da915f98-bfad-49f6-9914-fe57a30584c9'),0,
  'nenhuma negativa gravou membership');

-- 10-13. Caminho feliz.
select set_config('test.ap2_run1', app_private.seed_qa_r15_guardian_membership_v1()::text, true);
select is(current_setting('test.ap2_run1')::jsonb->>'membership','created','1a execucao cria a membership');
select is((select role_code||'/'||scope_kind||'/'||scope_group_id::text||'/'||scope_unit_id::text
  from public.institution_memberships where person_id='da915f98-bfad-49f6-9914-fe57a30584c9'
    and status='active' and revoked_at is null),
  'guardian/group/368a5cea-2bcf-4fa4-ad1f-18da58694551/d0c40000-0000-4000-8000-000000000002',
  'membership guardian de escopo group na turma, com a unidade da turma');
select set_config('request.jwt.claims', jsonb_build_object('sub','a9150000-0000-4000-8000-000000000201',
  'role','authenticated','aal','aal1')::text, true);
set local role authenticated;
select is((select count(*)::int from public.list_my_principal_contexts()),1,
  'depois da membership, list_my_principal_contexts devolve 1 contexto');
select is((select role_code||'/'||scope_kind||'/'||coalesce(group_id::text,'-')||'/'||coalesce(unit_id::text,'-')
  from public.list_my_principal_contexts()),
  'guardian/group/368a5cea-2bcf-4fa4-ad1f-18da58694551/d0c40000-0000-4000-8000-000000000002',
  'o contexto devolvido e o de responsavel na turma e unidade QA R04');
reset role;
select is(app_private.now_viewer_role_class('da915f98-bfad-49f6-9914-fe57a30584c9',
  (select id from public.institution_memberships where person_id='da915f98-bfad-49f6-9914-fe57a30584c9' and status='active'),
  'd0c40000-0000-4000-8000-000000000001','d0c40000-0000-4000-8000-000000000002','368a5cea-2bcf-4fa4-ad1f-18da58694551'),
  'guardian','com a membership, o Agora continua classificando o ator como guardian (sem permissao de equipe)');

-- 15-16. Idempotencia e conflito.
select set_config('test.ap2_run2', app_private.seed_qa_r15_guardian_membership_v1()::text, true);
select is((current_setting('test.ap2_run2')::jsonb->>'membership')||'/'||
  (select count(*)::text from public.institution_memberships where person_id='da915f98-bfad-49f6-9914-fe57a30584c9'),
  'existing/1','2a execucao nao duplica e relata existing');
select throws_ok($$select app_private.seed_qa_r15_guardian_membership_v1('qa-r15-responsavel@coelo.me',
  'd0c40000-0000-4000-8000-000000000001','d0c40000-0000-4000-8000-000000000002','368a5cea-2bcf-4fa4-ad1f-18da58694551','teacher')$$,
  '23505','qa_person_has_other_active_membership','membership ativa divergente nao e sobrescrita');

select * from finish();
rollback;
