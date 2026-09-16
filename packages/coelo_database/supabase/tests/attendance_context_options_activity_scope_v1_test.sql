-- Prova pgTAP da migration 20260916154500_attendance_context_options_activity_scope_v1
-- (R14 Sessao 8, ADR 0041 D3 / owner.r12-05): a lista `activities` de
-- superadmin_attendance_context_options usa o mesmo escopo de `groups`.
-- Fixture sintetica com rollback total; executa a RPC publica como authenticated.
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);
create function pg_temp.as_id(n integer) returns uuid language sql immutable as $$
  select ('8f190000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.as_id(integer) to authenticated;

select ok((select prosecdef and coalesce(array_to_string(proconfig,','),'')='search_path=""'
  from pg_proc where oid='app_private.superadmin_attendance_context_options(date)'::regprocedure),
  'context options preserva security definer e search_path vazio');
select ok(has_function_privilege('authenticated','public.superadmin_attendance_context_options(date)','execute')
  and not has_function_privilege('authenticated','app_private.superadmin_attendance_context_options(date)','execute'),
  'authenticated executa o wrapper publico e nao a funcao privada');

-- Catalogos: tipo de instituicao e tipo de unidade sinteticos.
insert into public.institution_types(id,code,name,status) values (pg_temp.as_id(1),'as-type','AS type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.as_id(2),'as-unit','AS unit','active');
-- A: instituicao ativa (elegivel). C: instituicao em draft (fora das listas). D: unidade inativa.
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 (pg_temp.as_id(10),pg_temp.as_id(1),'AS Ativa','as-ativa','active'),
 (pg_temp.as_id(30),pg_temp.as_id(1),'AS Draft','as-draft','draft');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status) values
 (pg_temp.as_id(11),pg_temp.as_id(10),'Unidade A1','unidade-as-a1','unidade.as.a1',pg_temp.as_id(2),'active'),
 (pg_temp.as_id(14),pg_temp.as_id(10),'Unidade A2 inativa','unidade-as-a2','unidade.as.a2',pg_temp.as_id(2),'inactive'),
 (pg_temp.as_id(31),pg_temp.as_id(30),'Unidade C1','unidade-as-c1','unidade.as.c1',pg_temp.as_id(2),'active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 (pg_temp.as_id(12),pg_temp.as_id(10),pg_temp.as_id(11),'Turma A1','active'),
 (pg_temp.as_id(15),pg_temp.as_id(10),pg_temp.as_id(14),'Turma A2','active'),
 (pg_temp.as_id(32),pg_temp.as_id(30),pg_temp.as_id(31),'Turma C1','active');
-- A baseline de producao possui a pessoa tecnica Coelo, usada pelo trigger global de
-- follows como follower/target; a fixture a semeia antes de qualquer pessoa ativa.
insert into public.people(id,person_type,first_name,last_name,display_name)
select 'c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema'
where not exists (select 1 from public.people where id='c0e10000-0000-4000-8000-000000000001');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.as_id(221),'adult','AS','Owner','AS owner','active');
-- Ator: owner de plataforma com attendance.read/manage (pessoa 221, usuario 121).
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 (pg_temp.as_id(121),'authenticated','authenticated','as-121@invalid.test',now(),now(),now(),'{}','{}');
insert into public.person_auth_links(person_id,auth_user_id,status) values (pg_temp.as_id(221),pg_temp.as_id(121),'active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select pg_temp.as_id(221),r.id,'active','platform',false from public.platform_roles r where r.code='owner';
-- Catalogo de permissao de plataforma (20260910220400); idempotente para espelhos restaurados so com schema.
insert into public.platform_permissions(code,module_code,module_label,screen_code,screen_label,action_code,action_label,description,risk_level,requires_mfa) values
 ('attendance.read','attendance','Assiduidade','attendance_calls','Chamadas','read','Ver','Visualizar chamadas e presencas no escopo autorizado.','high',false),
 ('attendance.manage','attendance','Assiduidade','attendance_calls','Chamadas','manage','Gerenciar','Abrir, marcar, corrigir e concluir chamadas no escopo autorizado.','high',false)
on conflict (code) do nothing;
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow'::public.permission_effect,'active' from public.platform_roles r cross join public.platform_permissions p
where r.code='owner' and p.code in('attendance.read','attendance.manage')
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;

-- As tabelas de atividade exigem proveniencia do ator (created_by/linked_by = current_person_id()).
select set_config('request.jwt.claims','{"sub":"8f190000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
insert into public.activity_definitions(id,institution_id,name,origin_scope_kind,created_by_person_id,handle_stem,status) values
 (pg_temp.as_id(40),pg_temp.as_id(10),'Atividade A elegivel','institution',pg_temp.as_id(221),'atividade-as-a','active'),
 (pg_temp.as_id(41),pg_temp.as_id(10),'Atividade A2 unidade inativa','institution',pg_temp.as_id(221),'atividade-as-a2','active'),
 (pg_temp.as_id(50),pg_temp.as_id(30),'Atividade C draft','institution',pg_temp.as_id(221),'atividade-as-c','active');
insert into public.activity_unit_links(activity_id,institution_id,unit_id,linked_by_person_id,status) values
 (pg_temp.as_id(40),pg_temp.as_id(10),pg_temp.as_id(11),pg_temp.as_id(221),'active'),
 (pg_temp.as_id(41),pg_temp.as_id(10),pg_temp.as_id(14),pg_temp.as_id(221),'active'),
 (pg_temp.as_id(50),pg_temp.as_id(30),pg_temp.as_id(31),pg_temp.as_id(221),'active');
insert into public.activity_group_links(id,activity_id,institution_id,unit_id,group_id,linked_by_person_id,status,starts_at) values
 (pg_temp.as_id(60),pg_temp.as_id(40),pg_temp.as_id(10),pg_temp.as_id(11),pg_temp.as_id(12),pg_temp.as_id(221),'active',now()-interval '1 day'),
 (pg_temp.as_id(61),pg_temp.as_id(41),pg_temp.as_id(10),pg_temp.as_id(14),pg_temp.as_id(15),pg_temp.as_id(221),'active',now()-interval '1 day'),
 (pg_temp.as_id(62),pg_temp.as_id(50),pg_temp.as_id(30),pg_temp.as_id(31),pg_temp.as_id(32),pg_temp.as_id(221),'active',now()-interval '1 day');


create temporary table as_results(key text primary key,value jsonb not null);
grant select,insert,update on as_results to authenticated;
select set_config('request.jwt.claims','{"sub":"8f190000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into as_results values('options',public.superadmin_attendance_context_options(current_date));
reset role;

-- Elegivel: atividade A aparece com institution/unit/group presentes nas listas.
select ok((select value->'activities' @> jsonb_build_array(jsonb_build_object('id',pg_temp.as_id(40),'name','Atividade A elegivel',
  'institution_id',pg_temp.as_id(10),'unit_id',pg_temp.as_id(11),'group_id',pg_temp.as_id(12),'attendance_required',true))
  from as_results where key='options'),'atividade da instituicao ativa e oferecida');
select ok((select value->'institutions' @> jsonb_build_array(jsonb_build_object('id',pg_temp.as_id(10),'name','AS Ativa')) from as_results where key='options'),
  'a instituicao da atividade elegivel esta em institutions');
select ok((select value->'units' @> jsonb_build_array(jsonb_build_object('id',pg_temp.as_id(11),'name','Unidade A1','institution_id',pg_temp.as_id(10))) from as_results where key='options'),
  'a unidade da atividade elegivel esta em units');
select ok((select value->'groups' @> jsonb_build_array(jsonb_build_object('id',pg_temp.as_id(12),'name','Turma A1','institution_id',pg_temp.as_id(10),'unit_id',pg_temp.as_id(11))) from as_results where key='options'),
  'a turma da atividade elegivel esta em groups');
-- Fora do escopo: instituicao draft nao aparece em nenhuma lista, inclusive activities.
select is((select count(*) from as_results, jsonb_array_elements(value->'activities') a where key='options' and a->>'id'=pg_temp.as_id(50)::text),0::bigint,
  'atividade de instituicao draft nao e oferecida');
select is((select count(*) from as_results, jsonb_array_elements(value->'groups') g where key='options' and g->>'id'=pg_temp.as_id(32)::text),0::bigint,
  'turma de instituicao draft nao e oferecida (referencia do escopo)');
-- Unidade inativa: atividade some junto com a turma.
select is((select count(*) from as_results, jsonb_array_elements(value->'activities') a where key='options' and a->>'id'=pg_temp.as_id(41)::text),0::bigint,
  'atividade de unidade inativa nao e oferecida');
select is((select count(*) from as_results, jsonb_array_elements(value->'groups') g where key='options' and g->>'id'=pg_temp.as_id(15)::text),0::bigint,
  'turma de unidade inativa nao e oferecida (referencia do escopo)');
-- Invariante: todo escopo de activities existe nas outras listas.
select is((select count(*) from as_results r, jsonb_array_elements(r.value->'activities') a where r.key='options'
  and (not exists(select 1 from jsonb_array_elements(r.value->'institutions') i where i->>'id'=a->>'institution_id')
    or not exists(select 1 from jsonb_array_elements(r.value->'units') u where u->>'id'=a->>'unit_id')
    or not exists(select 1 from jsonb_array_elements(r.value->'groups') g where g->>'id'=a->>'group_id'))),0::bigint,
  'nenhuma atividade oferecida tem escopo ausente de institutions/units/groups');

select * from finish();
rollback;
