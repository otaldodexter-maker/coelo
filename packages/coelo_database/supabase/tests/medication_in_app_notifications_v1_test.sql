-- Prova pgTAP da migration 20260916190000_medication_in_app_notifications_v1
-- (R14 Sessao 10, ADR 0041 B8 / owner.r12-33): sino in-app de Medicacao.
-- Fixture sintetica com rollback total (insercoes diretas nas tabelas, como
-- as RPCs de Medicacao fazem); leitura do sino como authenticated pelas policies.
-- Cobre: grants, destinatarios (admin da unidade e educador da turma sim;
-- responsavel, ator, terceiro e pessoa de outra unidade nao), editar plano
-- (versao 2) -> medication.plan.updated sem duplicar a versao 1, cada dose ->
-- medication.dose.recorded com outcome, not_tracked silencia, notify_unit=false
-- exclui a equipe, e a leitura pela policy so alcanca o destinatario.
begin;
create extension if not exists pgtap with schema extensions;
select plan(29);

create function pg_temp.mn_id(n integer) returns uuid language sql immutable as $$
  select ('8f1c0000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.mn_id(integer) to authenticated;

select has_function('app_private','medication_notification_recipients_v1',array['uuid','uuid','uuid','uuid'],'recipients helper exists');
select has_function('app_private','medication_notify_v1',array['public.medication_plans','text','text','uuid','jsonb','uuid'],'notify helper exists');
select has_trigger('public','medication_plan_versions','medication_plan_versions_notify_v1','version trigger exists');
select has_trigger('public','medication_plan_evidence','medication_plan_evidence_notify_v1','evidence trigger exists');
select ok((select bool_and(not has_function_privilege('authenticated',p.oid,'execute') and not has_function_privilege('anon',p.oid,'execute'))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='app_private' and p.proname in ('medication_notification_recipients_v1','medication_notify_v1',
    'medication_plan_version_notify_v1','medication_plan_evidence_notify_v1')),
  'helpers and trigger functions have no client grant');
select ok((select bool_and(p.prosecdef and coalesce(array_to_string(p.proconfig,','),'')='search_path=""')
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='app_private' and p.proname in ('medication_notification_recipients_v1','medication_notify_v1',
    'medication_plan_version_notify_v1','medication_plan_evidence_notify_v1')),
  'helpers are security definer with empty search_path');

-- ---------------------------------------------------------------------------
-- Fixture: instituicao A, unidades A1 (da crianca) e A2 (outra), turma A1
-- ---------------------------------------------------------------------------
insert into public.institution_types(id,code,name,status) values (pg_temp.mn_id(1),'mn-type','MN type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.mn_id(2),'mn-unit','MN unit','active');
insert into public.family_relationship_types(code,name) values ('mother','Mae') on conflict (code) do nothing;
insert into public.people(id,person_type,first_name,last_name,display_name)
select 'c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema'
where not exists (select 1 from public.people where id='c0e10000-0000-4000-8000-000000000001');
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 (pg_temp.mn_id(10),pg_temp.mn_id(1),'MN A','mn-a','active');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status) values
 (pg_temp.mn_id(11),pg_temp.mn_id(10),'Unidade A1','mn-unidade-a1','mnunidade.a1',pg_temp.mn_id(2),'active'),
 (pg_temp.mn_id(14),pg_temp.mn_id(10),'Unidade A2','mn-unidade-a2','mnunidade.a2',pg_temp.mn_id(2),'active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 (pg_temp.mn_id(12),pg_temp.mn_id(10),pg_temp.mn_id(11),'Turma A1','active'),
 (pg_temp.mn_id(15),pg_temp.mn_id(10),pg_temp.mn_id(14),'Turma A2','active');

-- Adultos: 221 ator (quem edita/registra); 222 admin da unidade A1; 223 educador da
-- turma A1; 224 responsavel; 225 admin da unidade A2; 226 educador da turma A2;
-- 227 representante legal da instituicao.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select pg_temp.mn_id(n),'authenticated','authenticated','mn-'||n||'@invalid.test',now(),now(),now(),'{}','{}' from unnest(array[122,123,125]) n;
insert into public.people(id,person_type,first_name,last_name,display_name,status)
select pg_temp.mn_id(n),'adult','MN','Adulto','MN adulto '||n,'active' from unnest(array[221,222,223,224,225,226,227]) n;
insert into public.person_auth_links(person_id,auth_user_id,status)
select pg_temp.mn_id(n+100),pg_temp.mn_id(n),'active' from unnest(array[122,123,125]) n;
insert into public.institution_memberships(id,person_id,institution_id,role_code,scope_kind,scope_unit_id,scope_group_id,status) values
 (pg_temp.mn_id(41),pg_temp.mn_id(222),pg_temp.mn_id(10),'mn_admin','unit',pg_temp.mn_id(11),null,'active'),
 (pg_temp.mn_id(42),pg_temp.mn_id(223),pg_temp.mn_id(10),'mn_teacher','group',pg_temp.mn_id(11),pg_temp.mn_id(12),'active'),
 (pg_temp.mn_id(43),pg_temp.mn_id(225),pg_temp.mn_id(10),'mn_admin','unit',pg_temp.mn_id(14),null,'active'),
 (pg_temp.mn_id(44),pg_temp.mn_id(226),pg_temp.mn_id(10),'mn_teacher','group',pg_temp.mn_id(14),pg_temp.mn_id(15),'active'),
 (pg_temp.mn_id(45),pg_temp.mn_id(227),pg_temp.mn_id(10),'legal_representative','institution',null,null,'active'),
 (pg_temp.mn_id(46),pg_temp.mn_id(221),pg_temp.mn_id(10),'mn_admin','institution',null,null,'active');

insert into public.people(id,person_type,first_name,last_name,display_name,status,date_of_birth) values
 (pg_temp.mn_id(301),'child','Crianca','MN','Crianca MN','active',date '2020-01-01');
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 (pg_temp.mn_id(311),pg_temp.mn_id(301),pg_temp.mn_id(10),'active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
 (pg_temp.mn_id(321),pg_temp.mn_id(311),pg_temp.mn_id(11),'active',pg_temp.mn_id(221),now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status) values
 (pg_temp.mn_id(331),pg_temp.mn_id(321),pg_temp.mn_id(12),'active');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,relationship_type_id,status)
select pg_temp.mn_id(341),pg_temp.mn_id(224),pg_temp.mn_id(301),'mother',t.id,'active' from public.family_relationship_types t where t.code='mother';

-- Plano no escopo da instituicao (unidade resolvida pela crianca), versao 1.
insert into public.medication_plans(id,institution_id,child_context_id,scope_kind,status,created_by_person_id) values
 (pg_temp.mn_id(500),pg_temp.mn_id(10),pg_temp.mn_id(311),'institution','draft',pg_temp.mn_id(221));
insert into public.medication_plan_versions(id,plan_id,version,medication_name,dose_amount,dose_unit,administration_route,reason,valid_from,timezone,created_by_person_id) values
 (pg_temp.mn_id(501),pg_temp.mn_id(500),1,'Paracetamol',10,'ml','oral','Febre',current_date,'America/Sao_Paulo',pg_temp.mn_id(221));
update public.medication_plans set current_version_id=pg_temp.mn_id(501) where id=pg_temp.mn_id(500);

-- ---------------------------------------------------------------------------
-- Destinatarios (helper privado, como postgres)
-- ---------------------------------------------------------------------------
create temporary table mn_recipients as
  select r from app_private.medication_notification_recipients_v1(pg_temp.mn_id(10),pg_temp.mn_id(11),pg_temp.mn_id(311),pg_temp.mn_id(221)) r;
select ok(exists(select 1 from mn_recipients where r=pg_temp.mn_id(222)),'unit admin of the child unit is a recipient');
select ok(exists(select 1 from mn_recipients where r=pg_temp.mn_id(223)),'group educator of the child group is a recipient');
select ok(not exists(select 1 from mn_recipients where r=pg_temp.mn_id(224)),'guardian is not a recipient (B8 audience)');
select ok(not exists(select 1 from mn_recipients where r=pg_temp.mn_id(221)),'the actor never notifies itself');
select ok(not exists(select 1 from mn_recipients where r=pg_temp.mn_id(225)),'admin of another unit is not a recipient');
select ok(not exists(select 1 from mn_recipients where r=pg_temp.mn_id(226)),'educator of another group is not a recipient');
select ok(not exists(select 1 from mn_recipients where r=pg_temp.mn_id(227)),'legal representative is not a recipient');

-- ---------------------------------------------------------------------------
-- Versao 1 nao duplica; versao 2 (editar) notifica
-- ---------------------------------------------------------------------------
select is((select count(*) from public.context_notification_events where object_id=pg_temp.mn_id(500) and event_code='medication.plan.updated'),0::bigint,
  'version 1 does not emit plan.updated');
insert into public.medication_plan_versions(id,plan_id,version,medication_name,dose_amount,dose_unit,administration_route,reason,valid_from,timezone,created_by_person_id) values
 (pg_temp.mn_id(502),pg_temp.mn_id(500),2,'Paracetamol',12,'ml','oral','Febre',current_date,'America/Sao_Paulo',pg_temp.mn_id(221));
update public.medication_plans set current_version_id=pg_temp.mn_id(502) where id=pg_temp.mn_id(500);
select is((select count(*) from public.context_notification_events where object_id=pg_temp.mn_id(500) and event_code='medication.plan.updated'),1::bigint,
  'editing the plan (version 2) emits one plan.updated event');
select is((select e.payload_json from public.context_notification_events e where e.object_id=pg_temp.mn_id(500) and e.event_code='medication.plan.updated'),
  '{"version": 2}'::jsonb,'plan.updated payload carries only the version (no PII)');
select is((select e.unit_id from public.context_notification_events e where e.object_id=pg_temp.mn_id(500) and e.event_code='medication.plan.updated'),
  pg_temp.mn_id(11),'event unit resolved from the child active unit');
select ok((select array_agg(r.person_id order by r.person_id) from public.context_notification_recipients r
  join public.context_notification_events e on e.id=r.event_id where e.object_id=pg_temp.mn_id(500) and e.event_code='medication.plan.updated')
  = array[pg_temp.mn_id(222),pg_temp.mn_id(223)],'plan.updated reaches exactly the unit admin and the group educator');

-- ---------------------------------------------------------------------------
-- Cada dose registrada notifica
-- ---------------------------------------------------------------------------
insert into public.medication_plan_evidence(id,plan_id,plan_version_id,occurred_at,outcome,recorded_by_person_id) values
 (pg_temp.mn_id(601),pg_temp.mn_id(500),pg_temp.mn_id(502),now(),'administered',pg_temp.mn_id(223));
insert into public.medication_plan_evidence(id,plan_id,plan_version_id,occurred_at,outcome,reason,recorded_by_person_id) values
 (pg_temp.mn_id(602),pg_temp.mn_id(500),pg_temp.mn_id(502),now(),'refused','Criança recusou',pg_temp.mn_id(223));
select is((select count(*) from public.context_notification_events where event_code='medication.dose.recorded' and (payload_json->>'plan_id')::uuid=pg_temp.mn_id(500)),2::bigint,
  'each recorded dose emits one dose.recorded event');
select is((select e.payload_json->>'outcome' from public.context_notification_events e where e.object_id=pg_temp.mn_id(602)),'refused',
  'dose payload carries the outcome');
select ok((select e.payload_json ?& array['outcome','occurred_at','plan_id','plan_version_id'] and not (e.payload_json ? 'note') and not (e.payload_json ? 'reason')
  from public.context_notification_events e where e.object_id=pg_temp.mn_id(602)),'dose payload has no free text');
select ok((select array_agg(r.person_id order by r.person_id) from public.context_notification_recipients r
  join public.context_notification_events e on e.id=r.event_id where e.object_id=pg_temp.mn_id(601))
  = array[pg_temp.mn_id(221),pg_temp.mn_id(222)],'a dose recorded by the educator notifies the institution/unit admins, not the educator herself');

-- ---------------------------------------------------------------------------
-- Politica da unidade: notify_unit=false exclui a equipe; not_tracked silencia
-- ---------------------------------------------------------------------------
insert into public.unit_care_policies(unit_id,institution_id,notify_unit) values (pg_temp.mn_id(11),pg_temp.mn_id(10),false);
select ok((select array_agg(r order by r) from app_private.medication_notification_recipients_v1(pg_temp.mn_id(10),pg_temp.mn_id(11),pg_temp.mn_id(311),pg_temp.mn_id(221)) r)
  = array[pg_temp.mn_id(223)],'notify_unit=false keeps only the educators');
update public.unit_care_policies set medication_mode='not_tracked' where unit_id=pg_temp.mn_id(11);
insert into public.medication_plan_evidence(id,plan_id,plan_version_id,occurred_at,outcome,recorded_by_person_id) values
 (pg_temp.mn_id(603),pg_temp.mn_id(500),pg_temp.mn_id(502),now(),'administered',pg_temp.mn_id(223));
select is((select count(*) from public.context_notification_events where object_id=pg_temp.mn_id(603)),0::bigint,
  'medication_mode=not_tracked silences dose notifications');
delete from public.unit_care_policies where unit_id=pg_temp.mn_id(11);

-- ---------------------------------------------------------------------------
-- Leitura pelo sino (policies): destinatario ve; terceiro nao
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"8f1c0000-0000-4000-8000-000000000122","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select is((select count(*) from public.context_notification_recipients r join public.context_notification_events e on e.id=r.event_id
  where e.event_code in ('medication.plan.updated','medication.dose.recorded')),3::bigint,
  'unit admin sees plan.updated and the two doses in the bell');
select ok((select bool_and(r.read_at is null) from public.context_notification_recipients r),'bell items start unread');
update public.context_notification_recipients set read_at=now() where read_at is null;
select ok((select bool_and(r.read_at is not null) from public.context_notification_recipients r),'recipient marks its own items as read');
reset role;
select set_config('request.jwt.claims','{"sub":"8f1c0000-0000-4000-8000-000000000125","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select is((select count(*) from public.context_notification_recipients r),0::bigint,'admin of another unit sees nothing');
select is((select count(*) from public.context_notification_events e where e.object_id=pg_temp.mn_id(500)),0::bigint,'admin of another unit cannot read the events either');
reset role;

select * from finish();
rollback;
