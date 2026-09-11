-- Prova pgTAP do pacote 20260910220700: attendance_dashboard_access e
-- superadmin_attendance_context_options (F-R04-FCR-007). Fixture sintetica,
-- rollback total. Executa as RPCs publicas como authenticated.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
create function pg_temp.at_id(n integer) returns uuid language sql immutable as $$
  select ('8f180000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.at_id(integer) to authenticated;

select has_function('public','attendance_dashboard_access',array[]::text[],'public.attendance_dashboard_access exists');
select has_function('public','superadmin_attendance_context_options',array['date'],'public.superadmin_attendance_context_options(date) exists');
select ok(not has_function_privilege('anon','public.attendance_dashboard_access()','execute'),'anon cannot read attendance access');
select ok(not has_function_privilege('anon','public.superadmin_attendance_context_options(date)','execute'),'anon cannot read context options');
select ok(not has_function_privilege('service_role','public.superadmin_attendance_context_options(date)','execute'),'service_role has no direct grant');
select ok(not has_function_privilege('authenticated','app_private.attendance_dashboard_access()','execute'),'authenticated cannot call the app_private access');
select ok(not has_function_privilege('authenticated','app_private.superadmin_attendance_context_options(date)','execute'),'authenticated cannot call the app_private options');
select ok(has_function_privilege('authenticated','public.superadmin_attendance_context_options(date)','execute'),'authenticated can request options through the gateway');

insert into public.institution_types(id,code,name,status) values (pg_temp.at_id(1),'at-type','AT type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 (pg_temp.at_id(10),pg_temp.at_id(1),'AT A','at-a','active'),
 (pg_temp.at_id(20),pg_temp.at_id(1),'AT B','at-b','active');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status)
select pg_temp.at_id(11),pg_temp.at_id(10),'Unidade A1','unidade-a1','unidade.a1',t.id,'active' from public.unit_types t where t.code='sede';
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status)
select pg_temp.at_id(21),pg_temp.at_id(20),'Unidade B1','unidade-b1','unidade.b1',t.id,'active' from public.unit_types t where t.code='sede';
insert into public.groups(id,institution_id,unit_id,name,status) values
 (pg_temp.at_id(12),pg_temp.at_id(10),pg_temp.at_id(11),'Turma A1','active'),
 (pg_temp.at_id(13),pg_temp.at_id(10),pg_temp.at_id(11),'Turma inativa','inactive'),
 (pg_temp.at_id(22),pg_temp.at_id(20),pg_temp.at_id(21),'Turma B1','active');

-- Pessoa 221 (usuario 121): owner de plataforma com attendance.read/manage.
-- Pessoa 222 (usuario 122): sem membership alguma.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select pg_temp.at_id(n),'authenticated','authenticated','at-'||n||'@invalid.test',now(),now(),now(),'{}','{}' from unnest(array[121,122]) n;
insert into public.people(id,person_type,first_name,last_name,display_name,status)
select pg_temp.at_id(n),'adult','AT','Person','AT person '||n,'active' from unnest(array[221,222]) n;
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.at_id(221),pg_temp.at_id(121),'active'),(pg_temp.at_id(222),pg_temp.at_id(122),'active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select pg_temp.at_id(221),r.id,'active','platform',false from public.platform_roles r where r.code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow'::public.permission_effect,'active' from public.platform_roles r cross join public.platform_permissions p
where r.code='owner' and p.code in('attendance.read','attendance.manage')
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;

create temporary table at_results(key text primary key,value jsonb not null);
grant select,insert,update on at_results to authenticated;

-- Owner de plataforma: acesso platform e opcoes de todas as instituicoes ativas.
select set_config('request.jwt.claims','{"sub":"8f180000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into at_results values('access_owner',public.attendance_dashboard_access());
insert into at_results values('options_owner',public.superadmin_attendance_context_options(current_date));
insert into at_results values('options_owner_null',public.superadmin_attendance_context_options(null));
reset role;
select is((select value->>'scope' from at_results where key='access_owner'),'platform','owner resolves to platform scope');
select is((select value->>'can_read' from at_results where key='access_owner'),'true','owner can read');
select is((select value->>'can_create_call' from at_results where key='access_owner'),'true','owner can create calls');
select ok((select (select array_agg(k order by k) from jsonb_object_keys(value) k)
  = array['activities','can_manage','groups','institutions','units']::text[] from at_results where key='options_owner'),'options payload has the five keys the client reads');
select is((select value->>'can_manage' from at_results where key='options_owner'),'true','owner can_manage');
select ok((select value->'institutions' @> jsonb_build_array(jsonb_build_object('id',pg_temp.at_id(10),'name','AT A'))
  and value->'institutions' @> jsonb_build_array(jsonb_build_object('id',pg_temp.at_id(20),'name','AT B')) from at_results where key='options_owner'),'platform sees both institutions');
select ok((select value->'units' @> jsonb_build_array(jsonb_build_object('id',pg_temp.at_id(11),'name','Unidade A1','institution_id',pg_temp.at_id(10))) from at_results where key='options_owner'),'unit carries institution_id');
select ok((select value->'groups' @> jsonb_build_array(jsonb_build_object('id',pg_temp.at_id(12),'name','Turma A1','institution_id',pg_temp.at_id(10),'unit_id',pg_temp.at_id(11))) from at_results where key='options_owner'),'group carries institution_id and unit_id');
select is((select count(*) from at_results, jsonb_array_elements(value->'groups') g where key='options_owner' and g->>'id'=pg_temp.at_id(13)::text),0::bigint,'inactive group is not offered');
select is((select jsonb_typeof(value->'activities') from at_results where key='options_owner'),'array','activities is an array');
select is((select value->'institutions' from at_results where key='options_owner_null'),(select value->'institutions' from at_results where key='options_owner'),'null date falls back to today');

-- Pessoa sem membership: acesso negado (42501) nas duas RPCs.
select set_config('request.jwt.claims','{"sub":"8f180000-0000-4000-8000-000000000122","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select throws_ok('select public.attendance_dashboard_access()','42501',null,'person without attendance permission is denied access');
select throws_ok('select public.superadmin_attendance_context_options(current_date)','42501',null,'person without attendance permission gets no options');
reset role;

-- Sem sessao: negado.
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select throws_ok('select public.attendance_dashboard_access()','42501',null,'no session is denied');
reset role;

-- Membership contextual de instituicao A com attendance.read: escopo institution,
-- opcoes restritas a A (negativa cross-tenant para B).
insert into public.institution_memberships(id,person_id,institution_id,role_code,status) values
 (pg_temp.at_id(322),pg_temp.at_id(222),pg_temp.at_id(10),'staff','active');
create temporary table at_role_seed as
select r.id as role_id from public.institution_roles r where r.institution_id=pg_temp.at_id(10) limit 0;
select * from finish();
rollback;
