-- Prova pgTAP da migration 20260918170000_qa_r15_care_staff_fixture_v1 (R16 Sessao RESERVA, lote 83,
-- owner.r12-33): fixture privada de equipe humana (admin da unidade + educadora da turma) para observar o
-- sino de Medicacao em producao. Rollback total; cobre grants, fail-closed, criacao, idempotencia e o
-- efeito esperado: os dois viram destinatarios de medication_notification_recipients_v2.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

create function pg_temp.st_id(n integer) returns uuid language sql immutable as $$
  select ('8f4c0000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;

select has_function('app_private','seed_qa_r15_care_staff_fixture_v1',array['uuid','uuid','uuid','text','text'],'fixture exists');
select ok((select not has_function_privilege('authenticated',p.oid,'execute') and not has_function_privilege('anon',p.oid,'execute')
    and not has_function_privilege('service_role',p.oid,'execute')
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_private' and p.proname='seed_qa_r15_care_staff_fixture_v1'),'no client grant');
select ok((select p.prosecdef and coalesce(array_to_string(p.proconfig,','),'')='search_path=""'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_private' and p.proname='seed_qa_r15_care_staff_fixture_v1'),'security definer, empty search_path');

insert into public.institution_types(id,code,name,status) values (pg_temp.st_id(1),'st-type','ST type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.st_id(2),'st-unit','ST unit','active');
insert into public.people(id,person_type,first_name,last_name,display_name)
select 'c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema'
where not exists (select 1 from public.people where id='c0e10000-0000-4000-8000-000000000001');
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 (pg_temp.st_id(10),pg_temp.st_id(1),'QA R04 ST','qa-r04-st','active'),
 (pg_temp.st_id(20),pg_temp.st_id(1),'Real ST','real-st','active');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status) values
 (pg_temp.st_id(11),pg_temp.st_id(10),'Unidade QA ST','st-unidade-qa','stunidade.qa',pg_temp.st_id(2),'active'),
 (pg_temp.st_id(21),pg_temp.st_id(20),'Unidade Real','st-unidade-real','stunidade.real',pg_temp.st_id(2),'active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 (pg_temp.st_id(12),pg_temp.st_id(10),pg_temp.st_id(11),'Turma QA ST','active'),
 (pg_temp.st_id(22),pg_temp.st_id(20),pg_temp.st_id(21),'Turma Real','active');
insert into public.people(id,person_type,first_name,last_name,display_name,status,date_of_birth) values
 (pg_temp.st_id(301),'child','Crianca','ST','Crianca ST','active',date '2020-01-01');
insert into public.child_contexts(id,child_person_id,institution_id,status) values (pg_temp.st_id(311),pg_temp.st_id(301),pg_temp.st_id(10),'active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
 (pg_temp.st_id(321),pg_temp.st_id(311),pg_temp.st_id(11),'active','c0e10000-0000-4000-8000-000000000001',now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status) values (pg_temp.st_id(331),pg_temp.st_id(321),pg_temp.st_id(12),'active');

-- fail-closed
select throws_ok($$select app_private.seed_qa_r15_care_staff_fixture_v1(pg_temp.st_id(20),pg_temp.st_id(21),pg_temp.st_id(22))$$,
  'P0002','qa_institution_missing_or_not_synthetic','non-synthetic institution is refused');
select throws_ok($$select app_private.seed_qa_r15_care_staff_fixture_v1(pg_temp.st_id(10),pg_temp.st_id(11),pg_temp.st_id(22))$$,
  'P0002','qa_group_missing_or_not_synthetic','group of another unit is refused');
select throws_ok($$select app_private.seed_qa_r15_care_staff_fixture_v1(pg_temp.st_id(10),pg_temp.st_id(11),pg_temp.st_id(12),'Maria Real','QA R15 X')$$,
  '22023','qa_staff_name_not_synthetic','name without QA R15 prefix is refused');
select is((select count(*) from public.people where display_name in ('QA R15 Admin Unidade','QA R15 Educadora Turma')),0::bigint,'refusals wrote nothing');

-- criacao
create temporary table st_run1 as select app_private.seed_qa_r15_care_staff_fixture_v1(pg_temp.st_id(10),pg_temp.st_id(11),pg_temp.st_id(12)) as r;
select is((select (r->>'people_created')::int from st_run1),2,'two adults created');
select is((select (r->>'memberships_created')::int from st_run1),2,'two memberships created');
select ok((select bool_and(p.person_type='adult' and p.status='active') from public.people p
  where p.display_name in ('QA R15 Admin Unidade','QA R15 Educadora Turma')),'staff are active adults');

-- efeito: ambos sao destinatarios do sino de Medicacao (ator = pessoa tecnica)
create temporary table st_recipients as
  select r from app_private.medication_notification_recipients_v2(pg_temp.st_id(10),pg_temp.st_id(11),pg_temp.st_id(311),'c0e10000-0000-4000-8000-000000000001') r;
select ok(exists(select 1 from st_recipients r join public.people p on p.id=r.r where p.display_name='QA R15 Admin Unidade'),'unit admin becomes a medication recipient');
select ok(exists(select 1 from st_recipients r join public.people p on p.id=r.r where p.display_name='QA R15 Educadora Turma'),'group educator becomes a medication recipient');

-- idempotencia
create temporary table st_run2 as select app_private.seed_qa_r15_care_staff_fixture_v1(pg_temp.st_id(10),pg_temp.st_id(11),pg_temp.st_id(12)) as r;
select is((select (r->>'people_created')::int + (r->>'memberships_created')::int from st_run2),0,'second run creates nothing');
select is((select count(*) from public.institution_memberships m join public.people p on p.id=m.person_id
  where p.display_name in ('QA R15 Admin Unidade','QA R15 Educadora Turma')),2::bigint,'no duplicate memberships');

select * from finish();
rollback;
