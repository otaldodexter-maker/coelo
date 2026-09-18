-- Prova pgTAP da migration 20260918123000_qa_r15_attendance_group_fixture_v1
-- (R16 Sessao RESERVA, D4 / owner.r12-08): fixture privada que da a uma turma sintetica
-- >=2 criancas ativas com vinculo de unidade ATIVO (o que a tela nao faz) e vinculo de turma.
-- Fixture com rollback total; cobre grants, fail-closed, criacao, idempotencia e a derivacao
-- de participantes que superadmin_attendance_create_call usa (vinculos ativos).
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

create function pg_temp.fx_id(n integer) returns uuid language sql immutable as $$
  select ('8f3c0000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;

select has_function('app_private','seed_qa_r15_attendance_group_fixture_v1',array['uuid','uuid','uuid','text[]','uuid'],'fixture function exists');
select ok((select not has_function_privilege('authenticated',p.oid,'execute') and not has_function_privilege('anon',p.oid,'execute')
    and not has_function_privilege('service_role',p.oid,'execute')
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='app_private' and p.proname='seed_qa_r15_attendance_group_fixture_v1'),'no client grant');
select ok((select p.prosecdef and coalesce(array_to_string(p.proconfig,','),'')='search_path=""'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='app_private' and p.proname='seed_qa_r15_attendance_group_fixture_v1'),'security definer, empty search_path');

-- Fixture: instituicao sintetica (slug qa-r04-*), outra nao sintetica, unidades, turmas
insert into public.institution_types(id,code,name,status) values (pg_temp.fx_id(1),'fx-type','FX type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.fx_id(2),'fx-unit','FX unit','active');
insert into public.people(id,person_type,first_name,last_name,display_name)
select 'c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema'
where not exists (select 1 from public.people where id='c0e10000-0000-4000-8000-000000000001');
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 (pg_temp.fx_id(10),pg_temp.fx_id(1),'QA R04 FX','qa-r04-fx','active'),
 (pg_temp.fx_id(20),pg_temp.fx_id(1),'Real FX','real-fx','active');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status) values
 (pg_temp.fx_id(11),pg_temp.fx_id(10),'Unidade QA FX','fx-unidade-qa','fxunidade.qa',pg_temp.fx_id(2),'active'),
 (pg_temp.fx_id(21),pg_temp.fx_id(20),'Unidade Real','fx-unidade-real','fxunidade.real',pg_temp.fx_id(2),'active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 (pg_temp.fx_id(12),pg_temp.fx_id(10),pg_temp.fx_id(11),'Turma QA FX','active'),
 (pg_temp.fx_id(13),pg_temp.fx_id(10),pg_temp.fx_id(11),'Turma sem prefixo','active'),
 (pg_temp.fx_id(22),pg_temp.fx_id(20),pg_temp.fx_id(21),'Turma QA Real','active');

-- Fail-closed
select throws_ok($$select app_private.seed_qa_r15_attendance_group_fixture_v1(pg_temp.fx_id(20),pg_temp.fx_id(21),pg_temp.fx_id(22))$$,
  'P0002','qa_institution_missing_or_not_synthetic','non-synthetic institution is refused');
select throws_ok($$select app_private.seed_qa_r15_attendance_group_fixture_v1(pg_temp.fx_id(10),pg_temp.fx_id(11),pg_temp.fx_id(13))$$,
  'P0002','qa_group_missing_or_not_synthetic','group without QA in the name is refused');
select throws_ok($$select app_private.seed_qa_r15_attendance_group_fixture_v1(pg_temp.fx_id(10),pg_temp.fx_id(21),pg_temp.fx_id(12))$$,
  'P0002','qa_unit_missing','unit of another institution is refused');
select throws_ok($$select app_private.seed_qa_r15_attendance_group_fixture_v1(pg_temp.fx_id(10),pg_temp.fx_id(11),pg_temp.fx_id(12),array['Maria Real'])$$,
  '22023','qa_child_name_not_synthetic','child name without QA R15 prefix is refused');
select is((select count(*) from public.people where display_name like 'QA R15 Crianca%' and person_type='child'
  and exists (select 1 from public.child_contexts c where c.child_person_id=people.id and c.institution_id=pg_temp.fx_id(10))),0::bigint,
  'refusals wrote nothing');

-- Criacao
create temporary table fx_run1 as select app_private.seed_qa_r15_attendance_group_fixture_v1(pg_temp.fx_id(10),pg_temp.fx_id(11),pg_temp.fx_id(12)) as r;
select is((select (r->>'people_created')::int from fx_run1),2,'two children created');
select is((select (r->>'active_children_in_group')::int from fx_run1),2,'two active children in the group');
select ok((select bool_and(p.status='active' and p.person_type='child' and p.date_of_birth is not null)
  from public.people p where p.display_name in ('QA R15 Crianca 3','QA R15 Crianca 4')),'children are active with date of birth');
select ok((select bool_and(l.status='active' and l.accepted_by='c0e10000-0000-4000-8000-000000000001' and l.accepted_at is not null)
  from public.child_unit_links l join public.child_contexts c on c.id=l.child_context_id
  join public.people p on p.id=c.child_person_id where p.display_name like 'QA R15 Crianca %' and l.unit_id=pg_temp.fx_id(11)),
  'unit links are active and accepted by the technical person');

-- Derivacao de participantes igual a superadmin_attendance_create_call
select is((select count(*) from public.child_group_links child_group
  join public.child_unit_links child_unit on child_unit.id = child_group.child_unit_link_id
  join public.child_contexts child_context on child_context.id = child_unit.child_context_id
  where child_group.group_id = pg_temp.fx_id(12) and child_group.status = 'active'
    and child_unit.unit_id = pg_temp.fx_id(11) and child_unit.status = 'active'
    and child_context.status = 'active' and child_context.institution_id = pg_temp.fx_id(10)),2::bigint,
  'attendance would derive 2 expected participants');

-- Idempotencia
create temporary table fx_run2 as select app_private.seed_qa_r15_attendance_group_fixture_v1(pg_temp.fx_id(10),pg_temp.fx_id(11),pg_temp.fx_id(12)) as r;
select is((select (r->>'people_created')::int + (r->>'contexts_created')::int + (r->>'unit_links_created')::int + (r->>'group_links_created')::int from fx_run2),0,
  'second run creates nothing');
select is((select (r->>'people_existing')::int from fx_run2),2,'second run finds both children');
select is((select count(*) from public.people where display_name in ('QA R15 Crianca 3','QA R15 Crianca 4') and person_type='child'),2::bigint,
  'no duplicate people after two runs');

select * from finish();
rollback;
