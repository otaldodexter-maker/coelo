-- Prova pgTAP da migration 20260918120000_medication_in_app_notifications_v2
-- (R16 Sessao RESERVA, ADR 0042 E7 = b / owner.r12-33 + divida recipients-bug):
-- o responsavel recebe plano atualizado e dose registrada; memberships de
-- familia (guardian/student) nunca contam como equipe nem educador, nem no
-- leitor de Medicacao nem no leitor de cuidado (child_care_notification_recipients_v1).
-- Fixture sintetica com rollback total (mesma da v1, mais: 228 responsavel com
-- membership 'guardian' de escopo unit SEM guardian_link; 229 'student' com
-- escopo group; 224 responsavel por guardian_link, tambem com membership
-- 'guardian' na turma - o caso real de qa-r15-responsavel se o candidato de
-- membership for aplicado).
begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

create function pg_temp.mn_id(n integer) returns uuid language sql immutable as $$
  select ('8f2c0000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.mn_id(integer) to authenticated;

select has_function('app_private','medication_notification_recipients_v2',array['uuid','uuid','uuid','uuid'],'recipients v2 exists');
select has_function('app_private','medication_notification_recipients_v1',array['uuid','uuid','uuid','uuid'],'recipients v1 preserved');
select has_function('app_private','child_care_notification_recipients_v1',array['uuid','uuid','uuid','uuid'],'care recipients v1 exists');
select has_trigger('public','medication_plan_versions','medication_plan_versions_notify_v1','version trigger intact');
select has_trigger('public','medication_plan_evidence','medication_plan_evidence_notify_v1','evidence trigger intact');
select ok((select bool_and(not has_function_privilege('authenticated',p.oid,'execute') and not has_function_privilege('anon',p.oid,'execute')
    and not has_function_privilege('service_role',p.oid,'execute'))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='app_private' and p.proname in ('medication_notification_recipients_v2','medication_notify_v1','child_care_notification_recipients_v1')),
  'v2 helpers have no client grant');
select ok((select bool_and(p.prosecdef and coalesce(array_to_string(p.proconfig,','),'')='search_path=""')
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='app_private' and p.proname in ('medication_notification_recipients_v2','medication_notify_v1','child_care_notification_recipients_v1')),
  'v2 helpers are security definer with empty search_path');
select ok(position('medication_notification_recipients_v2' in
  pg_get_functiondef('app_private.medication_notify_v1(public.medication_plans,text,text,uuid,jsonb,uuid)'::regprocedure)) > 0,
  'medication_notify_v1 uses recipients v2');

-- ---------------------------------------------------------------------------
-- Fixture
-- ---------------------------------------------------------------------------
insert into public.institution_types(id,code,name,status) values (pg_temp.mn_id(1),'mn2-type','MN2 type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.mn_id(2),'mn2-unit','MN2 unit','active');
insert into public.family_relationship_types(code,name) values ('mother','Mae') on conflict (code) do nothing;
insert into public.people(id,person_type,first_name,last_name,display_name)
select 'c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema'
where not exists (select 1 from public.people where id='c0e10000-0000-4000-8000-000000000001');
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 (pg_temp.mn_id(10),pg_temp.mn_id(1),'MN2 A','mn2-a','active');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status) values
 (pg_temp.mn_id(11),pg_temp.mn_id(10),'Unidade A1','mn2-unidade-a1','mn2unidade.a1',pg_temp.mn_id(2),'active'),
 (pg_temp.mn_id(14),pg_temp.mn_id(10),'Unidade A2','mn2-unidade-a2','mn2unidade.a2',pg_temp.mn_id(2),'active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 (pg_temp.mn_id(12),pg_temp.mn_id(10),pg_temp.mn_id(11),'Turma A1','active'),
 (pg_temp.mn_id(15),pg_temp.mn_id(10),pg_temp.mn_id(14),'Turma A2','active');

-- 221 ator; 222 admin da unidade A1; 223 educador da turma A1; 224 responsavel (guardian_link
-- + membership 'guardian' na turma A1); 225 admin A2; 226 educador A2; 227 representante legal;
-- 228 membership 'guardian' de escopo unit A1 SEM guardian_link; 229 membership 'student' na turma A1.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select pg_temp.mn_id(n),'authenticated','authenticated','mn2-'||n||'@invalid.test',now(),now(),now(),'{}','{}' from unnest(array[122,124,128]) n;
insert into public.people(id,person_type,first_name,last_name,display_name,status)
select pg_temp.mn_id(n),'adult','MN2','Adulto','MN2 adulto '||n,'active' from unnest(array[221,222,223,224,225,226,227,228,229]) n;
insert into public.person_auth_links(person_id,auth_user_id,status)
select pg_temp.mn_id(n+100),pg_temp.mn_id(n),'active' from unnest(array[122,124,128]) n;
insert into public.institution_memberships(id,person_id,institution_id,role_code,scope_kind,scope_unit_id,scope_group_id,status) values
 (pg_temp.mn_id(41),pg_temp.mn_id(222),pg_temp.mn_id(10),'mn_admin','unit',pg_temp.mn_id(11),null,'active'),
 (pg_temp.mn_id(42),pg_temp.mn_id(223),pg_temp.mn_id(10),'mn_teacher','group',pg_temp.mn_id(11),pg_temp.mn_id(12),'active'),
 (pg_temp.mn_id(43),pg_temp.mn_id(225),pg_temp.mn_id(10),'mn_admin','unit',pg_temp.mn_id(14),null,'active'),
 (pg_temp.mn_id(44),pg_temp.mn_id(226),pg_temp.mn_id(10),'mn_teacher','group',pg_temp.mn_id(14),pg_temp.mn_id(15),'active'),
 (pg_temp.mn_id(45),pg_temp.mn_id(227),pg_temp.mn_id(10),'legal_representative','institution',null,null,'active'),
 (pg_temp.mn_id(46),pg_temp.mn_id(221),pg_temp.mn_id(10),'mn_admin','institution',null,null,'active'),
 (pg_temp.mn_id(47),pg_temp.mn_id(224),pg_temp.mn_id(10),'guardian','group',pg_temp.mn_id(11),pg_temp.mn_id(12),'active'),
 (pg_temp.mn_id(48),pg_temp.mn_id(228),pg_temp.mn_id(10),'guardian','unit',pg_temp.mn_id(11),null,'active'),
 (pg_temp.mn_id(49),pg_temp.mn_id(229),pg_temp.mn_id(10),'student','group',pg_temp.mn_id(11),pg_temp.mn_id(12),'active');

insert into public.people(id,person_type,first_name,last_name,display_name,status,date_of_birth) values
 (pg_temp.mn_id(301),'child','Crianca','MN2','Crianca MN2','active',date '2020-01-01');
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 (pg_temp.mn_id(311),pg_temp.mn_id(301),pg_temp.mn_id(10),'active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
 (pg_temp.mn_id(321),pg_temp.mn_id(311),pg_temp.mn_id(11),'active',pg_temp.mn_id(221),now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status) values
 (pg_temp.mn_id(331),pg_temp.mn_id(321),pg_temp.mn_id(12),'active');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,relationship_type_id,status)
select pg_temp.mn_id(341),pg_temp.mn_id(224),pg_temp.mn_id(301),'mother',t.id,'active' from public.family_relationship_types t where t.code='mother';

insert into public.medication_plans(id,institution_id,child_context_id,scope_kind,status,created_by_person_id) values
 (pg_temp.mn_id(500),pg_temp.mn_id(10),pg_temp.mn_id(311),'institution','draft',pg_temp.mn_id(221));
insert into public.medication_plan_versions(id,plan_id,version,medication_name,dose_amount,dose_unit,administration_route,reason,valid_from,timezone,created_by_person_id) values
 (pg_temp.mn_id(501),pg_temp.mn_id(500),1,'Paracetamol',10,'ml','oral','Febre',current_date,'America/Sao_Paulo',pg_temp.mn_id(221));
update public.medication_plans set current_version_id=pg_temp.mn_id(501) where id=pg_temp.mn_id(500);

-- ---------------------------------------------------------------------------
-- Destinatarios de Medicacao v2
-- ---------------------------------------------------------------------------
create temporary table mn2_recipients as
  select r from app_private.medication_notification_recipients_v2(pg_temp.mn_id(10),pg_temp.mn_id(11),pg_temp.mn_id(311),pg_temp.mn_id(221)) r;
select ok(exists(select 1 from mn2_recipients where r=pg_temp.mn_id(222)),'unit admin is a recipient');
select ok(exists(select 1 from mn2_recipients where r=pg_temp.mn_id(223)),'group educator is a recipient');
select ok(exists(select 1 from mn2_recipients where r=pg_temp.mn_id(224)),'E7=b: guardian by guardian_link is a recipient');
select ok(not exists(select 1 from mn2_recipients where r=pg_temp.mn_id(228)),'recipients-bug: guardian-role membership without link is not staff');
select ok(not exists(select 1 from mn2_recipients where r=pg_temp.mn_id(229)),'recipients-bug: student-role membership in the group is not an educator');
select ok(not exists(select 1 from mn2_recipients where r=pg_temp.mn_id(221)),'the actor never notifies itself');
select ok(not exists(select 1 from mn2_recipients where r in (pg_temp.mn_id(225),pg_temp.mn_id(226),pg_temp.mn_id(227))),
  'other unit staff and the legal representative are not recipients');
select is((select count(*) from mn2_recipients),3::bigint,'exactly admin, educator and guardian');

-- recipients-bug tambem no leitor de cuidado (plano criado / status)
create temporary table mn2_care as
  select r from app_private.child_care_notification_recipients_v1(pg_temp.mn_id(10),pg_temp.mn_id(11),pg_temp.mn_id(311),pg_temp.mn_id(221)) r;
select ok((select array_agg(r order by r) from mn2_care) = array[pg_temp.mn_id(222),pg_temp.mn_id(223),pg_temp.mn_id(224)],
  'care recipients: admin, educator and guardian; family memberships are not staff');

-- ---------------------------------------------------------------------------
-- Eventos: plano atualizado e dose alcancam o responsavel
-- ---------------------------------------------------------------------------
insert into public.medication_plan_versions(id,plan_id,version,medication_name,dose_amount,dose_unit,administration_route,reason,valid_from,timezone,created_by_person_id) values
 (pg_temp.mn_id(502),pg_temp.mn_id(500),2,'Paracetamol',12,'ml','oral','Febre',current_date,'America/Sao_Paulo',pg_temp.mn_id(221));
update public.medication_plans set current_version_id=pg_temp.mn_id(502) where id=pg_temp.mn_id(500);
select is((select count(*) from public.context_notification_events where object_id=pg_temp.mn_id(500) and event_code='medication.plan.updated'),1::bigint,
  'version 2 emits one plan.updated');
select ok((select array_agg(r.person_id order by r.person_id) from public.context_notification_recipients r
  join public.context_notification_events e on e.id=r.event_id where e.object_id=pg_temp.mn_id(500) and e.event_code='medication.plan.updated')
  = array[pg_temp.mn_id(222),pg_temp.mn_id(223),pg_temp.mn_id(224)],'plan.updated reaches admin, educator and guardian');

insert into public.medication_plan_evidence(id,plan_id,plan_version_id,occurred_at,outcome,recorded_by_person_id) values
 (pg_temp.mn_id(601),pg_temp.mn_id(500),pg_temp.mn_id(502),now(),'administered',pg_temp.mn_id(223));
select ok((select array_agg(r.person_id order by r.person_id) from public.context_notification_recipients r
  join public.context_notification_events e on e.id=r.event_id where e.object_id=pg_temp.mn_id(601))
  = array[pg_temp.mn_id(221),pg_temp.mn_id(222),pg_temp.mn_id(224)],'dose by the educator reaches admins and guardian, not herself');
select ok((select e.payload_json ?& array['outcome','occurred_at','plan_id','plan_version_id'] and not (e.payload_json ? 'reason')
  from public.context_notification_events e where e.object_id=pg_temp.mn_id(601)),'dose payload unchanged (no free text)');

-- ---------------------------------------------------------------------------
-- Politicas: notify_other_guardians=false exclui o responsavel; notify_unit=false exclui a equipe; not_tracked silencia
-- ---------------------------------------------------------------------------
insert into public.unit_care_policies(unit_id,institution_id,notify_other_guardians) values (pg_temp.mn_id(11),pg_temp.mn_id(10),false);
select ok((select array_agg(r order by r) from app_private.medication_notification_recipients_v2(pg_temp.mn_id(10),pg_temp.mn_id(11),pg_temp.mn_id(311),pg_temp.mn_id(221)) r)
  = array[pg_temp.mn_id(222),pg_temp.mn_id(223)],'notify_other_guardians=false keeps only staff');
update public.unit_care_policies set notify_other_guardians=true, notify_unit=false where unit_id=pg_temp.mn_id(11);
select ok((select array_agg(r order by r) from app_private.medication_notification_recipients_v2(pg_temp.mn_id(10),pg_temp.mn_id(11),pg_temp.mn_id(311),pg_temp.mn_id(221)) r)
  = array[pg_temp.mn_id(223),pg_temp.mn_id(224)],'notify_unit=false keeps educator and guardian');
update public.unit_care_policies set notify_unit=true, medication_mode='not_tracked' where unit_id=pg_temp.mn_id(11);
insert into public.medication_plan_evidence(id,plan_id,plan_version_id,occurred_at,outcome,recorded_by_person_id) values
 (pg_temp.mn_id(603),pg_temp.mn_id(500),pg_temp.mn_id(502),now(),'administered',pg_temp.mn_id(223));
select is((select count(*) from public.context_notification_events where object_id=pg_temp.mn_id(603)),0::bigint,'not_tracked silences');
delete from public.unit_care_policies where unit_id=pg_temp.mn_id(11);

-- ---------------------------------------------------------------------------
-- Leitura pelo sino: o responsavel ve (policies); a membership 'guardian' sem vinculo nao ve
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"8f2c0000-0000-4000-8000-000000000124","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select is((select count(*) from public.context_notification_recipients r join public.context_notification_events e on e.id=r.event_id
  where e.event_code in ('medication.plan.updated','medication.dose.recorded')),2::bigint,
  'guardian sees plan.updated and the dose in the bell');
reset role;
select set_config('request.jwt.claims','{"sub":"8f2c0000-0000-4000-8000-000000000128","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select is((select count(*) from public.context_notification_recipients r),0::bigint,'guardian-role membership without link sees nothing');
reset role;
select set_config('request.jwt.claims','{"sub":"8f2c0000-0000-4000-8000-000000000122","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select is((select count(*) from public.context_notification_recipients r join public.context_notification_events e on e.id=r.event_id
  where e.event_code in ('medication.plan.updated','medication.dose.recorded')),2::bigint,'unit admin still sees both');
reset role;

select * from finish();
rollback;
