-- Prova pgTAP da migration 20260919220000_staff_access_profile_v1 (horario de uso no PERFIL).
-- Fixture sintetica com rollback total (prefixo f8): instituicao A (SP) com unidade A1 (Manaus),
-- perfil "F8 Educador" da instituicao A (max_scope unit) com permissao people.read; educadora E com
-- vinculo teacher em A (unidade A1, perfil F8 Educador) e teacher em B; admin D administra A.
-- Cobre: herança (perfil -> vinculo), regra propria fora do padrao, voltar ao padrao (clear),
-- regra propria igual conta como padrao, popup do perfil, list source filter, PT409, perfil global
-- recusado, ator sem escopo, auditoria e enforcement em has_context_permission.
begin;
create extension if not exists pgtap with schema extensions;
select plan(39);

create function pg_temp.f8(n integer) returns uuid language sql immutable as $$
  select ('f8000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.f8(integer) to authenticated;
create function pg_temp.as_user(n integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', pg_temp.f8(n)::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.f8(n)::text, 'role', 'authenticated', 'aal', 'aal1')::text, true);
end $$;

-- estrutura -------------------------------------------------------------------------------------
select has_table('public','staff_access_profile_rules','staff_access_profile_rules exists');
select ok((select relforcerowsecurity and relrowsecurity from pg_class where oid='public.staff_access_profile_rules'::regclass),'profile rules force RLS');
select ok(not has_table_privilege('anon','public.staff_access_profile_rules','SELECT') and not has_table_privilege('authenticated','public.staff_access_profile_rules','INSERT'),'profile rules: no anon read, no client write');
select ok((select bool_and(has_function_privilege('authenticated',p.oid,'execute') and not has_function_privilege('anon',p.oid,'execute'))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
  and p.proname in ('staff_access_profile_rule_get_v1','staff_access_profile_rule_save_v1','staff_access_list_v1')),'RPCs: authenticated only');
select ok(position('40001' in pg_get_functiondef('public.staff_access_profile_rule_save_v1(uuid,bigint,jsonb)'::regprocedure))=0
  and position('PT409' in pg_get_functiondef('public.staff_access_profile_rule_save_v1(uuid,bigint,jsonb)'::regprocedure))>0,'stale version = PT409, never 40001');
select ok(position('staff_access_effective_rule' in pg_get_functiondef('app_private.staff_access_evaluate(uuid,text,timestamptz)'::regprocedure))>0,'evaluate reads the effective rule (single resolver)');

-- fixture ---------------------------------------------------------------------------------------
insert into public.institution_types(id,code,name,status) values (pg_temp.f8(1),'f8-type','F8 type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.f8(2),'f8-unit','F8 unit','active');
insert into public.people(id,person_type,first_name,last_name,display_name)
select 'c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema'
where not exists (select 1 from public.people where id='c0e10000-0000-4000-8000-000000000001');
insert into public.institutions(id,institution_type_id,public_name,slug,status,timezone) values
 (pg_temp.f8(10),pg_temp.f8(1),'F8 Instituicao A','f8-a','active','America/Sao_Paulo'),
 (pg_temp.f8(20),pg_temp.f8(1),'F8 Instituicao B','f8-b','active','America/Sao_Paulo');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status,timezone) values
 (pg_temp.f8(11),pg_temp.f8(10),'F8 Unidade A1','f8-unidade-a1','f8unidade.a1',pg_temp.f8(2),'active','America/Manaus');
-- perfil da instituicao A
insert into public.institution_roles(id,institution_id,code,name,status,max_scope_kind) values
 (pg_temp.f8(50),pg_temp.f8(10),'f8_educador','F8 Educador','active','unit');
insert into public.institution_role_permissions(role_id,permission_id,effect,status)
select pg_temp.f8(50),p.id,'allow','active' from public.institution_permissions p where p.code='people.read';

insert into auth.users(id) values (pg_temp.f8(101)),(pg_temp.f8(102)),(pg_temp.f8(103));
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.f8(201),'adult','F8','Educadora E','F8 Educadora E','active'),
 (pg_temp.f8(202),'adult','F8','Admin D','F8 Admin D','active'),
 (pg_temp.f8(203),'adult','F8','Admin X','F8 Admin X','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.f8(201),pg_temp.f8(101),'active'),(pg_temp.f8(202),pg_temp.f8(102),'active'),(pg_temp.f8(203),pg_temp.f8(103),'active');
-- 301 E teacher em A (unidade A1, perfil F8 Educador); 302 E teacher em B; 304 D admin A; 305 X admin B
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind,scope_unit_id,scope_group_id) values
 (pg_temp.f8(301),pg_temp.f8(201),pg_temp.f8(10),'teacher','active','unit',pg_temp.f8(11),null),
 (pg_temp.f8(302),pg_temp.f8(201),pg_temp.f8(20),'teacher','active','institution',null,null),
 (pg_temp.f8(304),pg_temp.f8(202),pg_temp.f8(10),'institution_admin','active','institution',null,null),
 (pg_temp.f8(305),pg_temp.f8(203),pg_temp.f8(20),'institution_admin','active','institution',null,null);
insert into public.institution_role_assignments(membership_id,role_id,scope_kind,scope_unit_id) values (pg_temp.f8(301),pg_temp.f8(50),'unit',pg_temp.f8(11));
insert into public.institution_role_assignments(membership_id,role_id,scope_kind)
select pg_temp.f8(304),r.id,'institution' from public.institution_roles r where r.code='institution_admin' and r.is_system;
insert into public.institution_role_assignments(membership_id,role_id,scope_kind)
select pg_temp.f8(305),r.id,'institution' from public.institution_roles r where r.code='institution_admin' and r.is_system;

-- sem configuracao ------------------------------------------------------------------------------
select is((select source from app_private.staff_access_effective_rule(pg_temp.f8(301))),'none','no rule anywhere: source none');
select is((select allowed from app_private.staff_access_evaluate(pg_temp.f8(301),'web','2026-09-23 17:00:00+00')),true,'no configuration: allowed');

-- D define horario no PERFIL (seg-sex 08-18 Manaus); E herda ------------------------------------
select pg_temp.as_user(102);
set local role authenticated;
select throws_ok($$select public.staff_access_profile_rule_save_v1((select id from public.institution_roles where code='institution_admin' and is_system and institution_id is null),null,jsonb_build_object('surfaces',jsonb_build_array('web')))$$,
  '22023',null,'global system profile never receives a schedule');
select lives_ok($$select public.staff_access_profile_rule_save_v1(pg_temp.f8(50),null,jsonb_build_object(
  'surfaces',jsonb_build_array('web','mobile_web','tablet_web','installed_app'),
  'windows',(select jsonb_agg(jsonb_build_object('weekday',d,'start','08:00','end','18:00')) from generate_series(1,5) d),
  'popup_enabled',true))$$,'admin saves the profile schedule');
select is((public.staff_access_profile_rule_get_v1(pg_temp.f8(50))->'rule'->>'version')::int,1,'profile rule version 1');
select is((public.staff_access_profile_rule_get_v1(pg_temp.f8(50))->>'membership_count')::int,1,'profile counts the linked vinculo');
select throws_ok($$select public.staff_access_profile_rule_save_v1(pg_temp.f8(50),9,jsonb_build_object('surfaces',jsonb_build_array('web')))$$,'PT409',null,'profile stale version -> PT409');
select is((select i->>'source' from jsonb_array_elements(public.staff_access_list_v1(null,null,null,null,1,20)->'items') i where i->>'membership_id'=pg_temp.f8(301)::text),'profile','directory: E inherits from the profile');
select is((select i->>'profile_name' from jsonb_array_elements(public.staff_access_list_v1(null,null,null,null,1,20)->'items') i where i->>'membership_id'=pg_temp.f8(301)::text),'F8 Educador','directory names the profile');
select is((select (public.staff_access_list_v1(null,null,null,null,1,20,array['profile'])->>'total_count')::int),1,'source filter profile');
select is((select (public.staff_access_list_v1(null,null,null,null,1,20,array['none'])->>'total_count')::int),1,'source filter none (D himself)');
reset role;
-- quarta 2026-09-23 10:00 Manaus = 14:00Z dentro; 19:00 Manaus = 23:00Z fora
select is((select allowed from app_private.staff_access_evaluate(pg_temp.f8(301),'web','2026-09-23 14:00:00+00')),true,'inherited: inside the window');
select is((select reason from app_private.staff_access_evaluate(pg_temp.f8(301),'web','2026-09-23 23:00:00+00')),'schedule','inherited: outside the window denied');
select is((select allowed from app_private.staff_access_evaluate(pg_temp.f8(302),'web','2026-09-23 23:00:00+00')),true,'vinculo in B untouched');
select is((public.staff_access_check_v1(pg_temp.f8(301),'web','2026-09-23 23:00:00+00')->'popup')->>'kind','schedule','popup comes from the profile rule');
select ok(app_private.staff_access_state(pg_temp.f8(301)) in ('schedule','blocked_now'),'state reflects the inherited rule (schedule, or blocked_now depending on the clock)');

-- D altera so o vinculo de E: fora do padrao; voltar ao padrao = clear ----------------------------
select pg_temp.as_user(102);
set local role authenticated;
select lives_ok($$select public.staff_access_rule_save_v1(pg_temp.f8(301),null,jsonb_build_object(
  'surfaces',jsonb_build_array('web'),
  'windows',jsonb_build_array(jsonb_build_object('weekday',3,'start','08:00','end','12:00')),'popup_enabled',false))$$,'own rule saved on the vinculo');
select is((select i->>'source' from jsonb_array_elements(public.staff_access_list_v1(null,null,null,null,1,20)->'items') i where i->>'membership_id'=pg_temp.f8(301)::text),'own','directory: E is now outside the profile standard');
select is((select (public.staff_access_list_v1(null,null,null,null,1,20,array['own'])->>'total_count')::int),1,'source filter own');
select is((public.staff_access_profile_rule_get_v1(pg_temp.f8(50))->>'own_rule_count')::int,1,'profile counts vinculos outside the standard');
reset role;
-- quarta 14:00 Manaus = 18:00Z: dentro do perfil, fora da regra propria -> a propria prevalece
select is((select reason from app_private.staff_access_evaluate(pg_temp.f8(301),'web','2026-09-23 18:00:00+00')),'schedule','own rule prevails over the profile');
select pg_temp.as_user(102);
set local role authenticated;
select lives_ok($$select public.staff_access_rule_save_v1(pg_temp.f8(301),1,jsonb_build_object('clear',true))$$,'back to the profile standard (clear)');
select is((select i->>'source' from jsonb_array_elements(public.staff_access_list_v1(null,null,null,null,1,20)->'items') i where i->>'membership_id'=pg_temp.f8(301)::text),'profile','directory: inherits again');
-- regra propria identica a do perfil conta como padrao
select lives_ok($$select public.staff_access_rule_save_v1(pg_temp.f8(301),null,(public.staff_access_profile_rule_get_v1(pg_temp.f8(50))->'rule') - 'id' - 'role_id' - 'role_name' - 'institution_id' - 'version' - 'updated_at')$$,'own rule equal to the profile');
reset role;
select is((select source from app_private.staff_access_effective_rule(pg_temp.f8(301))),'profile','identical own rule counts as the profile standard');
select pg_temp.as_user(102);
set local role authenticated;
select lives_ok($$select public.staff_access_rule_save_v1(pg_temp.f8(301),1,jsonb_build_object('clear',true))$$,'cleared again');
reset role;
select is((select allowed from app_private.staff_access_evaluate(pg_temp.f8(301),'web','2026-09-23 18:00:00+00')),true,'inherits again: inside the profile window');

-- ator sem escopo ---------------------------------------------------------------------------------
select pg_temp.as_user(103);
set local role authenticated;
select throws_ok($$select public.staff_access_profile_rule_save_v1(pg_temp.f8(50),1,jsonb_build_object('surfaces',jsonb_build_array('web')))$$,'42501',null,'admin of B cannot configure a profile of A');
select throws_ok($$select public.staff_access_profile_rule_get_v1(pg_temp.f8(50))$$,'42501',null,'admin of B cannot read a profile rule of A');
reset role;

-- enforcement: E fora do horario herdado e negada pelo servidor -----------------------------------
select pg_temp.as_user(102);
set local role authenticated;
select lives_ok($$select public.staff_access_profile_rule_save_v1(pg_temp.f8(50),1,jsonb_build_object(
  'surfaces',jsonb_build_array('web'),'windows',jsonb_build_array(jsonb_build_object('weekday',1,'start','03:00','end','03:01')),'popup_enabled',true))$$,'profile rule that never matches now');
reset role;
select pg_temp.as_user(101);
set local role authenticated;
select is(app_private.has_context_permission(pg_temp.f8(10),'people.read',pg_temp.f8(11),null,null,null,false),false,'E denied in A by the inherited profile rule');
select is((select access_reason from public.list_my_principal_contexts() where membership_id=pg_temp.f8(301)),'schedule','context A marked schedule');
reset role;
select ok((select count(*) from audit.audit_logs where object_type='staff_access_profile_rule' and institution_id=pg_temp.f8(10))>=2,'audit trail for profile rules');

select * from finish();
rollback;
