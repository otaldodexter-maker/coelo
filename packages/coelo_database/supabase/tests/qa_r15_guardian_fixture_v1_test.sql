-- Somente replay LOCAL descartavel. Fixtures sinteticas com rollback. Nenhuma conta real.
-- Prova da migration 20260917110000_qa_r15_guardian_fixture_v1 (R15 B'/AP-1, ADR 0042 E2):
-- a funcao privada app_private.seed_qa_r15_guardian_fixture_v1 liga a conta Auth do
-- responsavel sintetico a pessoa, ativa a pessoa, cria guardian_links e
-- guardian_context_permissions para as duas criancas e aceita os child_unit_links pendentes;
-- e idempotente por e-mail e fail-closed (conta ausente, realm interno, pessoa/contexto fora
-- do prefixo QA R15). O espelho e schema + catalogo: a massa QA R15 e recriada aqui com os
-- mesmos ids de producao (evidencia r15-bloco-b/massa-qa-r15-20260917.md), e auth.users so
-- recebe insert neste replay local (em producao a conta vem da Auth Admin do Owner).
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

-- 1-4. Estrutura e exposicao.
select has_function('app_private', 'seed_qa_r15_guardian_fixture_v1',
  array['text','uuid','uuid[]','uuid','uuid','text'], 'fixture privada existe com a assinatura esperada');
select ok((select prosecdef and coalesce(array_to_string(proconfig,','),'')='search_path=""'
  from pg_proc where oid='app_private.seed_qa_r15_guardian_fixture_v1(text,uuid,uuid[],uuid,uuid,text)'::regprocedure),
  'security definer com search_path vazio');
select is((select pg_get_userbyid(proowner) from pg_proc
  where oid='app_private.seed_qa_r15_guardian_fixture_v1(text,uuid,uuid[],uuid,uuid,text)'::regprocedure),
  'postgres', 'dona da fixture e postgres');
select ok(not has_function_privilege('anon','app_private.seed_qa_r15_guardian_fixture_v1(text,uuid,uuid[],uuid,uuid,text)','execute')
  and not has_function_privilege('authenticated','app_private.seed_qa_r15_guardian_fixture_v1(text,uuid,uuid[],uuid,uuid,text)','execute')
  and not has_function_privilege('service_role','app_private.seed_qa_r15_guardian_fixture_v1(text,uuid,uuid[],uuid,uuid,text)','execute'),
  'anon, authenticated e service_role nao executam a fixture (invisivel ao PostgREST)');

-- Massa sintetica com os ids de producao (instituicao/unidade/turma/pessoas/contextos).
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
 'd0c40000-0000-4000-8000-000000000002','Turma QA R04 Estrutura (editada)','turmaqar04estrutura','active');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
('da915f98-bfad-49f6-9914-fe57a30584c9','adult','QA R15','Responsavel','QA R15 Responsavel','draft'),
('93457405-a4eb-4273-9579-ef84136a794b','child','QA R15','Crianca 1','QA R15 Crianca 1','active'),
('14d70a25-244f-409f-a164-71d87b491650','child','QA R15','Crianca 2','QA R15 Crianca 2','active'),
('a9150000-0000-4000-8000-000000000101','adult','QA R15','Outro Adulto','QA R15 Outro Adulto','active'),
('a9150000-0000-4000-8000-000000000102','adult','Maria','Real','Maria Real','active');
insert into public.child_contexts(id,child_person_id,institution_id) values
('1a6158fe-6cab-427c-9496-96e4273ab184','93457405-a4eb-4273-9579-ef84136a794b','d0c40000-0000-4000-8000-000000000001'),
('519ef941-3edb-41b6-94c4-55ed4638aefd','14d70a25-244f-409f-a164-71d87b491650','d0c40000-0000-4000-8000-000000000001');
insert into public.child_unit_links(id,child_context_id,unit_id,status) values
('72863003-0000-4000-8000-000000000001','1a6158fe-6cab-427c-9496-96e4273ab184','d0c40000-0000-4000-8000-000000000002','pending'),
('87cc5440-0000-4000-8000-000000000002','519ef941-3edb-41b6-94c4-55ed4638aefd','d0c40000-0000-4000-8000-000000000002','pending');
insert into public.child_group_links(child_unit_link_id,group_id,status) values
('72863003-0000-4000-8000-000000000001','368a5cea-2bcf-4fa4-ad1f-18da58694551','active'),
('87cc5440-0000-4000-8000-000000000002','368a5cea-2bcf-4fa4-ad1f-18da58694551','active');
-- Contas Auth sinteticas (so neste replay): responsavel, educador (sem vinculos) e uma do realm interno.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
('a9150000-0000-4000-8000-000000000201','authenticated','authenticated','qa-r15-responsavel@coelo.me',now(),now(),now(),'{}','{}'),
('a9150000-0000-4000-8000-000000000202','authenticated','authenticated','qa-r15-educador@coelo.me',now(),now(),now(),'{}','{}'),
('a9150000-0000-4000-8000-000000000203','authenticated','authenticated','qa-r15-interno@coelo.me',now(),now(),now(),'{}','{}');
insert into app_private.superadmin_internal_identities(id) values ('a9150000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
('a9150000-0000-4000-8000-000000000401','a9150000-0000-4000-8000-000000000301','a9150000-0000-4000-8000-000000000203');

-- 5-9. Fail-closed antes de gravar qualquer coisa.
select throws_ok($$select app_private.seed_qa_r15_guardian_fixture_v1('qa-r15-ausente@coelo.me')$$,
  'P0002','qa_auth_user_missing','conta Auth ausente interrompe (no_data_found)');
select throws_ok($$select app_private.seed_qa_r15_guardian_fixture_v1('qa-r15-interno@coelo.me')$$,
  '23505','qa_auth_user_internal_realm','conta do realm interno interrompe (unique_violation)');
select throws_ok($$select app_private.seed_qa_r15_guardian_fixture_v1('qa-r15-responsavel@coelo.me',
  'a9150000-0000-4000-8000-000000000102')$$,
  'P0002','qa_guardian_person_missing_or_not_synthetic','pessoa sem prefixo QA R15 interrompe');
select throws_ok($$select app_private.seed_qa_r15_guardian_fixture_v1('qa-r15-responsavel@coelo.me',
  'da915f98-bfad-49f6-9914-fe57a30584c9', array['00000000-0000-4000-8000-000000000000'::uuid])$$,
  'P0002','qa_child_context_missing_or_not_synthetic','contexto inexistente interrompe');
select throws_ok($$select app_private.seed_qa_r15_guardian_fixture_v1('alguem@coelo.me')$$,
  '22023','invalid_qa_fixture_input','e-mail fora do padrao qa-r15-*@coelo.me interrompe');
select is((select count(*)::int from public.person_auth_links where person_id='da915f98-bfad-49f6-9914-fe57a30584c9')
  + (select count(*)::int from public.guardian_links where guardian_person_id='da915f98-bfad-49f6-9914-fe57a30584c9'),
  0, 'nenhuma negativa gravou vinculo');

-- 11-17. Caminho feliz com os defaults (massa de producao).
select set_config('test.ap1_run1', app_private.seed_qa_r15_guardian_fixture_v1()::text, true);
select is(current_setting('test.ap1_run1')::jsonb->>'person_auth_link','created','1a execucao cria o person_auth_link');
select is((current_setting('test.ap1_run1')::jsonb->>'guardian_links_created')||'/'||
  (current_setting('test.ap1_run1')::jsonb->>'context_permissions_created')||'/'||
  (current_setting('test.ap1_run1')::jsonb->>'unit_links_accepted'),'2/2/2',
  '1a execucao cria 2 guardian_links, 2 permissoes de contexto e aceita 2 vinculos de unidade');
select is((select status::text from public.people where id='da915f98-bfad-49f6-9914-fe57a30584c9'),'active',
  'responsavel passa de draft para active (leitores exigem person.status=active)');
select is((select count(*)::int from public.person_auth_links
  where person_id='da915f98-bfad-49f6-9914-fe57a30584c9' and auth_user_id='a9150000-0000-4000-8000-000000000201'
    and status='active' and revoked_at is null),1,'um person_auth_link ativo pessoa <-> conta');
select is((select count(*)::int from public.guardian_links g join public.family_relationship_types r on r.id=g.relationship_type_id
  where g.guardian_person_id='da915f98-bfad-49f6-9914-fe57a30584c9' and g.status='active' and g.revoked_at is null
    and r.code='other' and g.relation_type='responsavel'
    and g.child_person_id in ('93457405-a4eb-4273-9579-ef84136a794b','14d70a25-244f-409f-a164-71d87b491650')),2,
  'dois guardian_links ativos (tipo other, relation_type responsavel) para as duas criancas');
select is((select count(*)::int from public.guardian_context_permissions gp join public.guardian_links g on g.id=gp.guardian_link_id
  where g.guardian_person_id='da915f98-bfad-49f6-9914-fe57a30584c9' and gp.status='active' and gp.can_view
    and gp.child_context_id in ('1a6158fe-6cab-427c-9496-96e4273ab184','519ef941-3edb-41b6-94c4-55ed4638aefd')),2,
  'duas guardian_context_permissions ativas com can_view');
select is((select count(*)::int from public.child_unit_links l
  where l.child_context_id in ('1a6158fe-6cab-427c-9496-96e4273ab184','519ef941-3edb-41b6-94c4-55ed4638aefd')
    and l.unit_id='d0c40000-0000-4000-8000-000000000002' and l.status='active'
    and l.accepted_by='da915f98-bfad-49f6-9914-fe57a30584c9' and l.accepted_at is not null),2,
  'os dois child_unit_links pendentes ficam active com aceite do responsavel');

-- 18-20. Idempotencia por e-mail.
select set_config('test.ap1_run2', app_private.seed_qa_r15_guardian_fixture_v1()::text, true);
select is((current_setting('test.ap1_run2')::jsonb->>'person_auth_link')||'/'||
  (current_setting('test.ap1_run2')::jsonb->>'guardian_links_created')||'/'||
  (current_setting('test.ap1_run2')::jsonb->>'guardian_links_existing')||'/'||
  (current_setting('test.ap1_run2')::jsonb->>'context_permissions_created')||'/'||
  (current_setting('test.ap1_run2')::jsonb->>'unit_links_accepted')||'/'||
  (current_setting('test.ap1_run2')::jsonb->>'unit_links_already_active'),'existing/0/2/0/0/2',
  '2a execucao nao cria nada e relata o existente');
select is((select count(*)::int from public.person_auth_links where person_id='da915f98-bfad-49f6-9914-fe57a30584c9')
  ||'/'||(select count(*)::int from public.guardian_links where guardian_person_id='da915f98-bfad-49f6-9914-fe57a30584c9')
  ||'/'||(select count(*)::int from public.guardian_context_permissions gp join public.guardian_links g on g.id=gp.guardian_link_id
          where g.guardian_person_id='da915f98-bfad-49f6-9914-fe57a30584c9'),'1/2/2',
  'sem duplicatas apos a 2a execucao');
select is(jsonb_array_length(current_setting('test.ap1_run2')::jsonb->'contexts'),2,
  'retorno lista os dois contextos com guardian_link_id');

-- 21-22. Conflitos de vinculo de conta sao recusados.
select throws_ok($$select app_private.seed_qa_r15_guardian_fixture_v1('qa-r15-responsavel@coelo.me',
  'a9150000-0000-4000-8000-000000000101')$$,
  '23505','qa_auth_user_already_linked_to_other_person','a mesma conta nao e ligada a outra pessoa');
select throws_ok($$select app_private.seed_qa_r15_guardian_fixture_v1('qa-r15-educador@coelo.me',
  'da915f98-bfad-49f6-9914-fe57a30584c9')$$,
  '23505','qa_guardian_person_already_linked_to_other_auth_user','a mesma pessoa nao recebe uma segunda conta');

select * from finish();
rollback;
