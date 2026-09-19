-- Prova pgTAP da migration 20260919100000_staff_access_v1 (Etapa 3 F7, ADR 0035 / ADR 0045 item 3).
-- Fixture sintetica com rollback total (prefixo f7): instituicao A (SP) com unidade A1 em
-- America/Manaus e turma; instituicao B. Educadora E tem vinculo teacher em A (turma), teacher em B
-- e uma membership 'guardian' em A (familia). Admin D administra A na unidade A1
-- (institution_admin, escopo unit); admin X administra B. Cobre: sem configuracao, janelas
-- multiplas e cruzando meia-noite, fuso da unidade, limites inclusivos da vigencia, precedencia,
-- superficie, popup ligado/desligado, PT409, ator sem escopo, vinculo de familia recusado,
-- auditoria e o aceite: E bloqueada em A segue livre em B e na familia; A negada pelo servidor.
begin;
create extension if not exists pgtap with schema extensions;
select plan(68);

create function pg_temp.f7(n integer) returns uuid language sql immutable as $$
  select ('f7000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.f7(integer) to authenticated;
create function pg_temp.as_user(n integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', pg_temp.f7(n)::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.f7(n)::text, 'role', 'authenticated', 'aal', 'aal1')::text, true);
end $$;

-- estrutura -------------------------------------------------------------------------------------
select has_table('public','staff_access_rules','staff_access_rules exists');
select has_table('public','staff_leaves','staff_leaves exists');
select ok((select relforcerowsecurity and relrowsecurity from pg_class where oid='public.staff_access_rules'::regclass),'rules force RLS');
select ok((select relforcerowsecurity and relrowsecurity from pg_class where oid='public.staff_leaves'::regclass),'leaves force RLS');
select ok(not has_table_privilege('anon','public.staff_access_rules','SELECT') and not has_table_privilege('authenticated','public.staff_access_rules','INSERT'),'rules: no anon read, no client write');
select ok(exists(select 1 from public.institution_permissions where code='staff_access.manage' and status='active'),'staff_access.manage exists');
select ok(exists(select 1 from public.institution_role_permissions rp join public.institution_roles r on r.id=rp.role_id
  join public.institution_permissions p on p.id=rp.permission_id where r.code='institution_admin' and r.is_system and p.code='staff_access.manage' and rp.status='active'),
  'institution_admin has staff_access.manage');
select ok((select bool_and(has_function_privilege('authenticated',p.oid,'execute') and not has_function_privilege('anon',p.oid,'execute'))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
  and p.proname in ('staff_access_list_v1','staff_access_rule_get_v1','staff_access_rule_save_v1','staff_leaves_list_v1','staff_leave_save_v1','staff_access_check_v1','list_my_principal_contexts')),
  'RPCs: authenticated only');
select ok((select bool_and(not has_function_privilege('authenticated',p.oid,'execute') and not has_function_privilege('anon',p.oid,'execute'))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_private' and p.proname like 'staff_access%' and p.proname<>'staff_access_can_manage'),
  'helpers: no client grant (can_manage is the policy predicate, like has_context_permission)');
select ok(position('staff_access_blocked' in pg_get_functiondef('app_private.has_context_permission(uuid,text,uuid,uuid,uuid,uuid,boolean)'::regprocedure))>0,
  'has_context_permission consults staff_access_blocked');
select ok(position('staff_access_blocked' in pg_get_functiondef('app_private.has_active_institution_membership(uuid)'::regprocedure))>0,
  'has_active_institution_membership consults staff_access_blocked');
select ok(position('40001' in pg_get_functiondef('public.staff_access_rule_save_v1(uuid,bigint,jsonb)'::regprocedure))=0
  and position('PT409' in pg_get_functiondef('public.staff_access_rule_save_v1(uuid,bigint,jsonb)'::regprocedure))>0,'stale version = PT409, never 40001');

-- fixture ---------------------------------------------------------------------------------------
insert into public.institution_types(id,code,name,status) values (pg_temp.f7(1),'f7-type','F7 type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.f7(2),'f7-unit','F7 unit','active');
insert into public.people(id,person_type,first_name,last_name,display_name)
select 'c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema'
where not exists (select 1 from public.people where id='c0e10000-0000-4000-8000-000000000001');
insert into public.institutions(id,institution_type_id,public_name,slug,status,timezone) values
 (pg_temp.f7(10),pg_temp.f7(1),'F7 Instituicao A','f7-a','active','America/Sao_Paulo'),
 (pg_temp.f7(20),pg_temp.f7(1),'F7 Instituicao B','f7-b','active','America/Sao_Paulo'),
 (pg_temp.f7(30),pg_temp.f7(1),'F7 Instituicao C','f7-c','active','America/Sao_Paulo');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status,timezone) values
 (pg_temp.f7(11),pg_temp.f7(10),'F7 Unidade A1','f7-unidade-a1','f7unidade.a1',pg_temp.f7(2),'active','America/Manaus');
insert into public.groups(id,institution_id,unit_id,name,status) values
 (pg_temp.f7(12),pg_temp.f7(10),pg_temp.f7(11),'F7 Turma A1','active');

-- 101 educadora E; 102 admin D (A, unidade A1); 103 admin X (B); 104 outra educadora F (A)
insert into auth.users(id) values (pg_temp.f7(101)),(pg_temp.f7(102)),(pg_temp.f7(103)),(pg_temp.f7(104));
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.f7(201),'adult','F7','Educadora E','F7 Educadora E','active'),
 (pg_temp.f7(202),'adult','F7','Admin D','F7 Admin D','active'),
 (pg_temp.f7(203),'adult','F7','Admin X','F7 Admin X','active'),
 (pg_temp.f7(204),'adult','F7','Educadora F','F7 Educadora F','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.f7(201),pg_temp.f7(101),'active'),(pg_temp.f7(202),pg_temp.f7(102),'active'),
 (pg_temp.f7(203),pg_temp.f7(103),'active'),(pg_temp.f7(204),pg_temp.f7(104),'active');
-- 301 E teacher em A (turma A1); 302 E teacher em B; 303 E guardian em C (familia); 304 D admin A (unit A1);
-- 305 X admin B; 306 F teacher em A (institution)
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind,scope_unit_id,scope_group_id) values
 (pg_temp.f7(301),pg_temp.f7(201),pg_temp.f7(10),'teacher','active','group',pg_temp.f7(11),pg_temp.f7(12)),
 (pg_temp.f7(302),pg_temp.f7(201),pg_temp.f7(20),'teacher','active','institution',null,null),
 (pg_temp.f7(303),pg_temp.f7(201),pg_temp.f7(30),'guardian','active','institution',null,null),
 (pg_temp.f7(304),pg_temp.f7(202),pg_temp.f7(10),'institution_admin','active','unit',pg_temp.f7(11),null),
 (pg_temp.f7(305),pg_temp.f7(203),pg_temp.f7(20),'institution_admin','active','institution',null,null),
 (pg_temp.f7(306),pg_temp.f7(204),pg_temp.f7(10),'teacher','active','institution',null,null),
 (pg_temp.f7(307),pg_temp.f7(202),pg_temp.f7(30),'institution_admin','active','institution',null,null);
-- familia em A sem membership (spec 070): E e responsavel da crianca 401 com contexto em A
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.f7(401),'child','F7','Crianca','F7 Crianca','active');
insert into public.family_relationship_types(code,name) values ('mother','Mae') on conflict (code) do nothing;
insert into public.child_contexts(id,child_person_id,institution_id,status) values (pg_temp.f7(411),pg_temp.f7(401),pg_temp.f7(10),'active');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,relationship_type_id,status)
select pg_temp.f7(421),pg_temp.f7(201),pg_temp.f7(401),'mother',t.id,'active' from public.family_relationship_types t where t.code='mother';
insert into public.guardian_context_permissions(guardian_link_id,child_context_id,can_view,can_message,can_react,status)
values (pg_temp.f7(421),pg_temp.f7(411),true,true,true,'active');
-- papeis: E e F com o papel de sistema teacher (tem people.read? usamos institution_reader p/ leitura), D e X institution_admin
insert into public.institution_role_assignments(membership_id,role_id,scope_kind,scope_unit_id,scope_group_id)
select pg_temp.f7(301),r.id,'group',pg_temp.f7(11),pg_temp.f7(12) from public.institution_roles r where r.code='institution_admin' and r.is_system;
insert into public.institution_role_assignments(membership_id,role_id,scope_kind)
select pg_temp.f7(302),r.id,'institution' from public.institution_roles r where r.code='institution_admin' and r.is_system;
insert into public.institution_role_assignments(membership_id,role_id,scope_kind,scope_unit_id)
select pg_temp.f7(304),r.id,'unit',pg_temp.f7(11) from public.institution_roles r where r.code='institution_admin' and r.is_system;
insert into public.institution_role_assignments(membership_id,role_id,scope_kind)
select pg_temp.f7(305),r.id,'institution' from public.institution_roles r where r.code='institution_admin' and r.is_system;
insert into public.institution_role_assignments(membership_id,role_id,scope_kind)
select pg_temp.f7(307),r.id,'institution' from public.institution_roles r where r.code='institution_admin' and r.is_system;

-- sem configuracao = liberado ---------------------------------------------------------------------
select is((select allowed from app_private.staff_access_evaluate(pg_temp.f7(301),'web',now())),true,'no configuration: allowed');
select is(app_private.staff_access_state(pg_temp.f7(301)),'free','no configuration: state free');
select is(app_private.staff_access_timezone(pg_temp.f7(301)),'America/Manaus','timezone comes from the unit of the group');
select is(app_private.staff_access_timezone(pg_temp.f7(302)),'America/Sao_Paulo','timezone falls back to the institution');

-- D (admin da unidade A1) configura horario de E em A -----------------------------------------------
select pg_temp.as_user(102);
set local role authenticated;
select lives_ok($$select public.staff_access_rule_save_v1(pg_temp.f7(301),null,jsonb_build_object(
  'surfaces',jsonb_build_array('web'),
  'windows',jsonb_build_array(
     jsonb_build_object('weekday',1,'start','08:00','end','18:00'),
     jsonb_build_object('weekday',2,'start','08:00','end','18:00'),
     jsonb_build_object('weekday',3,'start','08:00','end','12:00'),
     jsonb_build_object('weekday',3,'start','14:00','end','18:00'),
     jsonb_build_object('weekday',4,'start','08:00','end','18:00'),
     jsonb_build_object('weekday',5,'start','08:00','end','18:00'),
     jsonb_build_object('weekday',5,'start','22:00','end','02:00')),
  'popup_enabled',false))$$,'unit admin saves the schedule rule');
select is((select count(*)::int from public.staff_access_rules where membership_id=pg_temp.f7(301)),1,'rule row created (RLS read by the manager)');
select ok((select i->>'state' in ('schedule','blocked_now') from jsonb_array_elements(public.staff_access_list_v1(null,null,null,null,1,20)->'items') i where i->>'membership_id'=pg_temp.f7(301)::text),'directory shows E configured (schedule, or blocked_now depending on the clock)');
select is((select (public.staff_access_list_v1(null,null,null,null,1,20)->>'total_count')::int),3,'directory lists only vinculos under the admin scope (D@A, D@C, E@A; F@A is institution-scoped, outside unit A1)');
select is((select (public.staff_access_list_v1(null,null,null,array[(select i->>'state' from jsonb_array_elements(public.staff_access_list_v1(null,null,null,null,1,20)->'items') i where i->>'membership_id'=pg_temp.f7(301)::text)],1,20)->>'total_count')::int),1,'state filter');
select is((select (public.staff_access_list_v1('Educadora',null,null,null,1,20)->>'total_count')::int),1,'search filter');
reset role;

-- avaliacao com instantes explicitos (fuso da unidade = America/Manaus, UTC-4) -------------------
-- 2026-09-23 e quarta: 10:00 Manaus = 14:00Z -> dentro da janela da manha
select is((select reason from app_private.staff_access_evaluate(pg_temp.f7(301),'web','2026-09-23 14:00:00+00')),null,'wed 10:00 local allowed');
-- 13:00 Manaus = 17:00Z -> intervalo entre as duas janelas de quarta
select is((select reason from app_private.staff_access_evaluate(pg_temp.f7(301),'web','2026-09-23 17:00:00+00')),'schedule','wed 13:00 local denied between two windows');
-- 21:30Z = 17:30 Manaus (dentro) mas 18:30 Sao Paulo (fora): o fuso da unidade decide
select is((select allowed from app_private.staff_access_evaluate(pg_temp.f7(301),'web','2026-09-23 21:30:00+00')),true,'unit timezone (Manaus) governs, not the institution (SP)');
-- sabado 2026-09-26 01:30 Manaus = 05:30Z -> janela de sexta 22:00-02:00
select is((select allowed from app_private.staff_access_evaluate(pg_temp.f7(301),'web','2026-09-26 05:30:00+00')),true,'sat 01:30 local allowed by friday window crossing midnight');
-- sabado 02:30 Manaus = 06:30Z -> fora
select is((select reason from app_private.staff_access_evaluate(pg_temp.f7(301),'web','2026-09-26 06:30:00+00')),'schedule','sat 02:30 local denied');
-- domingo 2026-09-27 01:00 Manaus = 05:00Z -> sabado nao tem janela que cruza
select is((select reason from app_private.staff_access_evaluate(pg_temp.f7(301),'web','2026-09-27 05:00:00+00')),'schedule','sun 01:00 local denied (saturday has no window)');
-- sexta 23:00 Manaus = 2026-09-26 03:00Z -> dentro (inicio da janela que cruza)
select is((select allowed from app_private.staff_access_evaluate(pg_temp.f7(301),'web','2026-09-26 03:00:00+00')),true,'fri 23:00 local allowed');
-- superficie nao liberada, dentro do horario
select is((select reason from app_private.staff_access_evaluate(pg_temp.f7(301),'mobile_web','2026-09-23 14:00:00+00')),'surface','mobile_web denied by surface');
-- outro vinculo da mesma pessoa continua livre
select is((select allowed from app_private.staff_access_evaluate(pg_temp.f7(302),'web','2026-09-23 17:00:00+00')),true,'vinculo B untouched');
select is((select allowed from app_private.staff_access_evaluate(pg_temp.f7(303),'web','2026-09-23 17:00:00+00')),true,'family membership untouched');

-- vigencia inclusiva e precedencia sobre horario --------------------------------------------------
select pg_temp.as_user(102);
set local role authenticated;
select throws_ok($$select public.staff_access_rule_save_v1(pg_temp.f7(301),7,jsonb_build_object('surfaces',jsonb_build_array('web'),'windows','[]'::jsonb))$$,
  'PT409',null,'stale version -> PT409');
select lives_ok($$select public.staff_access_rule_save_v1(pg_temp.f7(301),1,jsonb_build_object(
  'surfaces',jsonb_build_array('web'),
  'windows',jsonb_build_array(jsonb_build_object('weekday',4,'start','08:00','end','18:00')),
  'valid_from','2026-10-01','valid_until','2026-10-10','popup_enabled',true,'popup_show_validity',true))$$,'update with validity');
select is((select version from public.staff_access_rules where membership_id=pg_temp.f7(301)),2::bigint,'version bumped');
reset role;
-- 2026-09-30 23:30 Manaus = 2026-10-01 03:30Z -> antes do inicio (dia local 30/09)
select is((select reason from app_private.staff_access_evaluate(pg_temp.f7(301),'web','2026-10-01 03:30:00+00')),'validity','day before valid_from denied (local date)');
-- 2026-10-01 quinta 10:00 Manaus = 14:00Z -> primeiro dia, inclusivo, dentro da janela
select is((select allowed from app_private.staff_access_evaluate(pg_temp.f7(301),'web','2026-10-01 14:00:00+00')),true,'valid_from inclusive');
-- 2026-10-10 sabado 10:00 -> dentro da vigencia mas sem janela -> schedule (vigencia passou)
select is((select reason from app_private.staff_access_evaluate(pg_temp.f7(301),'web','2026-10-10 14:00:00+00')),'schedule','valid_until inclusive, then schedule applies');
-- 2026-10-11 domingo -> validity antes de schedule
select is((select reason from app_private.staff_access_evaluate(pg_temp.f7(301),'web','2026-10-11 14:00:00+00')),'validity','validity precedes schedule');
select is(app_private.staff_access_state(pg_temp.f7(301)),'blocked_now','state blocked_now (validity still ahead)');

-- afastamento > tudo; popup ---------------------------------------------------------------------
select pg_temp.as_user(102);
set local role authenticated;
select lives_ok($$select public.staff_leave_save_v1(null,pg_temp.f7(301),null,jsonb_build_object('starts_on','2026-10-01','ends_on','2026-10-03','popup_enabled',false,'internal_note','licenca'))$$,'leave created');
select throws_ok($$select public.staff_leave_save_v1((select id from public.staff_leaves where membership_id=pg_temp.f7(301)),pg_temp.f7(301),9,jsonb_build_object('starts_on','2026-10-01','ends_on','2026-10-03'))$$,
  'PT409',null,'leave stale version -> PT409');
reset role;
select is((select reason from app_private.staff_access_evaluate(pg_temp.f7(301),'web','2026-10-01 14:00:00+00')),'leave','leave precedes validity and schedule');
select is((select popup from (select public.staff_access_check_v1(pg_temp.f7(301),'web','2026-10-01 14:00:00+00') as c) s, jsonb_to_record(s.c) as x(popup jsonb)),null,'popup disabled -> no details') ;
select pg_temp.as_user(102);
set local role authenticated;
select lives_ok($$select public.staff_leave_save_v1((select id from public.staff_leaves where membership_id=pg_temp.f7(301)),null,1,jsonb_build_object('starts_on','2026-10-01','ends_on','2026-10-03','popup_enabled',true))$$,'leave popup enabled');
select is((public.staff_access_check_v1(pg_temp.f7(301),'web','2026-10-01 14:00:00+00')->'popup')->>'leave_until','2026-10-03','popup enabled -> leave dates');
select is(public.staff_access_check_v1(pg_temp.f7(301),'web','2026-10-01 14:00:00+00')->>'code','STAFF_ACCESS_DENIED','denied code');
select is((public.staff_access_check_v1(pg_temp.f7(301),'web','2026-10-11 14:00:00+00')->'popup')->>'valid_until','2026-10-10','rule popup with validity shows dates');
reset role;

-- ator sem escopo / vinculo de familia -----------------------------------------------------------
select pg_temp.as_user(103);
set local role authenticated;
select throws_ok($$select public.staff_access_rule_save_v1(pg_temp.f7(301),2,jsonb_build_object('surfaces',jsonb_build_array('web')))$$,
  '42501',null,'admin of B cannot configure a vinculo of A');
select is((select count(*)::int from jsonb_array_elements(public.staff_access_list_v1(null,null,null,null,1,20)->'items') i where i->>'institution_id'=pg_temp.f7(10)::text),0,'admin of B sees no vinculo of A');
select is((select (public.staff_access_list_v1(null,null,null,null,1,20)->>'total_count')::int),2,'admin of B sees X@B and E@B');
reset role;
select pg_temp.as_user(102);
set local role authenticated;
select throws_ok($$select public.staff_access_rule_save_v1(pg_temp.f7(303),null,jsonb_build_object('surfaces',jsonb_build_array('web')))$$,
  '22023',null,'guardian membership never receives a rule');
reset role;

-- aceite: E bloqueada AGORA em A (afastamento hoje) segue livre em B e na familia --------------------
select pg_temp.as_user(102);
set local role authenticated;
select lives_ok($$select public.staff_leave_save_v1(null,pg_temp.f7(301),null,jsonb_build_object('starts_on',(current_date - 1)::text,'ends_on',(current_date + 1)::text,'popup_enabled',true))$$,'leave covering today');
reset role;
select is(app_private.staff_access_state(pg_temp.f7(301)),'blocked_now','state blocked_now');
select pg_temp.as_user(101);
set local role authenticated;
select is(app_private.has_context_permission(pg_temp.f7(10),'people.read',pg_temp.f7(11),pg_temp.f7(12),null,null,false),false,'E denied in A by the server (has_context_permission)');
select is(app_private.has_context_permission(pg_temp.f7(20),'people.read',null,null,null,null,false),true,'E allowed in B');
select is((select access_blocked from public.list_my_principal_contexts() where membership_id=pg_temp.f7(301)),true,'context A marked blocked, still listed');
select is((select access_reason from public.list_my_principal_contexts() where membership_id=pg_temp.f7(301)),'leave','context A reason leave');
select is((select access_blocked from public.list_my_principal_contexts() where membership_id=pg_temp.f7(302)),false,'context B free');
select is((select access_blocked from public.list_my_principal_contexts() where membership_id=pg_temp.f7(303)),false,'family membership (C) free');
select is((select count(*)::int from public.list_my_principal_contexts()),3,'blocked context still listed (never hidden)');
select is((public.staff_access_check_v1(pg_temp.f7(301),null,null)->>'allowed')::boolean,false,'E can check her own vinculo');
select throws_ok($$select public.staff_access_check_v1(pg_temp.f7(306),null,null)$$,'42501',null,'E cannot check another vinculo');
reset role;
select is((select membership_id from app_private.now_reader_actor(pg_temp.f7(10),'now.publications.read',null,null)),null,'family path in A (guardian_links) still works while the staff vinculo is blocked');

-- remocao do afastamento libera; limpar a regra volta a free; auditoria -----------------------------
select pg_temp.as_user(102);
set local role authenticated;
select lives_ok($$select public.staff_leave_save_v1((select id from public.staff_leaves where membership_id=pg_temp.f7(301) and starts_on=current_date-1),null,1,jsonb_build_object('remove',true))$$,'leave removed');
select lives_ok($$select public.staff_access_rule_save_v1(pg_temp.f7(301),2,jsonb_build_object('clear',true))$$,'rule cleared');
reset role;
select pg_temp.as_user(101);
set local role authenticated;
select is(app_private.has_context_permission(pg_temp.f7(10),'people.read',pg_temp.f7(11),pg_temp.f7(12),null,null,false),true,'E allowed again in A after removal');
reset role;
select ok((select count(*) from audit.audit_logs where object_type='staff_access_rule' and institution_id=pg_temp.f7(10))>=3
  and (select count(*) from audit.audit_logs where object_type='staff_leave' and institution_id=pg_temp.f7(10))>=4,'audit trail for rules and leaves');

select * from finish();
rollback;
