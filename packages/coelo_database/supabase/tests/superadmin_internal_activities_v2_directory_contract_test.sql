begin;
create extension if not exists pgtap with schema extensions;
select no_plan();


-- Genuine spec-039 fixtures. Everything is synthetic and rolled back.
insert into public.institution_types(id,code,name,status) values
 ('8a200000-0000-4000-8000-000000000001','activities-v2-directory','Activities v2 read','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('8a200000-0000-4000-8000-000000000010','Tenant A','activities-v2-directory-a','active','8a200000-0000-4000-8000-000000000001'),
 ('8a200000-0000-4000-8000-000000000020','Tenant B','activities-v2-directory-b','active','8a200000-0000-4000-8000-000000000001');
-- Forma de producao: units.unit_type_id -> public.unit_types e handle NOT NULL
-- (a coluna institution_type_id nao existe em producao).
insert into public.unit_types(id,code,name,status) values
 ('8a2000f0-0000-4000-8000-000000000901','activities-v2-directory-contract-test-u0','Tipo de unidade da fixture','active');
insert into public.units(id,institution_id,unit_type_id,name,slug,status,handle) values
 ('8a200000-0000-4000-8000-000000000011','8a200000-0000-4000-8000-000000000010','8a2000f0-0000-4000-8000-000000000901','A Norte','activities-v2-directory-a-norte','active','activities.v2.directory.a.norte'),
 ('8a200000-0000-4000-8000-000000000012','8a200000-0000-4000-8000-000000000010','8a2000f0-0000-4000-8000-000000000901','A Sul','activities-v2-directory-a-sul','active','activities.v2.directory.a.sul'),
 ('8a200000-0000-4000-8000-000000000021','8a200000-0000-4000-8000-000000000020','8a2000f0-0000-4000-8000-000000000901','B Única','activities-v2-directory-b-unica','active','activities.v2.directory.b.unica');
insert into public.groups(id,institution_id,unit_id,name,status) values
 ('8a200000-0000-4000-8000-000000000013','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000011','Turma A1','active'),
 ('8a200000-0000-4000-8000-000000000014','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000012','Turma A2 irmã','active'),
 ('8a200000-0000-4000-8000-000000000015','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000011','Turma A3','active'),
 ('8a200000-0000-4000-8000-000000000016','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000012','Turma A4','active'),
 ('8a200000-0000-4000-8000-000000000017','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000012','Turma A5 sem atividade','active'),
 ('8a200000-0000-4000-8000-000000000022','8a200000-0000-4000-8000-000000000020','8a200000-0000-4000-8000-000000000021','Turma B','active');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('8a200000-0000-4000-8000-000000000101','authenticated','authenticated','read-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a200000-0000-4000-8000-000000000102','authenticated','authenticated','read-scoped@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a200000-0000-4000-8000-000000000103','authenticated','authenticated','read-aal1@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a200000-0000-4000-8000-000000000104','authenticated','authenticated','read-revoked@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a200000-0000-4000-8000-000000000105','authenticated','authenticated','read-people-only@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a200000-0000-4000-8000-000000000106','authenticated','authenticated','read-denied-cap@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('8a200000-0000-4000-8000-000000000201','8a200000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a200000-0000-4000-8000-000000000202','8a200000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a200000-0000-4000-8000-000000000203','8a200000-0000-4000-8000-000000000103',now(),now(),'aal1',now()+interval '1 hour'),
 ('8a200000-0000-4000-8000-000000000204','8a200000-0000-4000-8000-000000000104',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a200000-0000-4000-8000-000000000205','8a200000-0000-4000-8000-000000000105',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a200000-0000-4000-8000-000000000206','8a200000-0000-4000-8000-000000000106',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a200000-0000-4000-8000-000000000209','8a200000-0000-4000-8000-000000000101',now(),now(),'aal2',now()-interval '1 minute');
insert into app_private.superadmin_internal_identities(id) values
 ('8a200000-0000-4000-8000-000000000301'),('8a200000-0000-4000-8000-000000000302'),
 ('8a200000-0000-4000-8000-000000000303'),('8a200000-0000-4000-8000-000000000304'),
 ('8a200000-0000-4000-8000-000000000306');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('8a200000-0000-4000-8000-000000000401','8a200000-0000-4000-8000-000000000301','8a200000-0000-4000-8000-000000000101'),
 ('8a200000-0000-4000-8000-000000000402','8a200000-0000-4000-8000-000000000302','8a200000-0000-4000-8000-000000000102'),
 ('8a200000-0000-4000-8000-000000000403','8a200000-0000-4000-8000-000000000303','8a200000-0000-4000-8000-000000000103'),
 ('8a200000-0000-4000-8000-000000000404','8a200000-0000-4000-8000-000000000304','8a200000-0000-4000-8000-000000000104'),
 ('8a200000-0000-4000-8000-000000000406','8a200000-0000-4000-8000-000000000306','8a200000-0000-4000-8000-000000000106');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('8a200000-0000-4000-8000-000000000501'::uuid,'8a200000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('8a200000-0000-4000-8000-000000000502'::uuid,'8a200000-0000-4000-8000-000000000302'::uuid,'operations','institution','8a200000-0000-4000-8000-000000000010'::uuid),
 ('8a200000-0000-4000-8000-000000000503'::uuid,'8a200000-0000-4000-8000-000000000303'::uuid,'owner','platform',null::uuid),
 ('8a200000-0000-4000-8000-000000000504'::uuid,'8a200000-0000-4000-8000-000000000304'::uuid,'operations','institution','8a200000-0000-4000-8000-000000000010'::uuid),
 ('8a200000-0000-4000-8000-000000000506'::uuid,'8a200000-0000-4000-8000-000000000306'::uuid,'content','platform',null::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now(),version=2 where id='8a200000-0000-4000-8000-000000000504';
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('8a200000-0000-4000-8000-000000000601','adult','People','Only','People Only','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('8a200000-0000-4000-8000-000000000601','8a200000-0000-4000-8000-000000000105','active');

-- Explicit grants/deny keep the test independent from profile seed drift.
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,
 case when role_record.code='content' and permission_record.code='activities.read' then 'deny'::public.permission_effect else 'allow'::public.permission_effect end,'active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code in('owner','operations','content') and permission_record.code in(
 'activities.read','activities.assign_people','activities.manage_permissions','activities.manage','activities.link_units','activities.link_groups')
 and not(role_record.code='operations' and permission_record.code in(
   'activities.assign_people','activities.manage_permissions'))
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;
delete from public.platform_role_permissions role_permission
using public.platform_roles role_record,public.platform_permissions permission_record
where role_permission.role_id=role_record.id
  and role_permission.permission_id=permission_record.id
  and role_record.code='operations'
  and permission_record.code in('activities.assign_people','activities.manage_permissions');

-- Seed one activity in each tenant through a genuine validated internal marker.
select set_config('request.jwt.claims',jsonb_build_object('sub','8a200000-0000-4000-8000-000000000101','session_id','8a200000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a200000-0000-4000-8000-000000000301','internal_auth_link_id','8a200000-0000-4000-8000-000000000401','internal_membership_id','8a200000-0000-4000-8000-000000000501',
 'auth_user_id','8a200000-0000-4000-8000-000000000101','session_id','8a200000-0000-4000-8000-000000000201','permission_code','activities.manage','action_code','manage','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_definitions(id,institution_id,name,description,handle_stem,origin_scope_kind,distribution_scope,created_by_person_id,status,management_version) values
 ('8a200000-0000-4000-8000-000000000701','8a200000-0000-4000-8000-000000000010','Robótica A','Somente tenant A','robotica-a-v2','institution','institution_standard',null,'draft',1),
 ('8a200000-0000-4000-8000-000000000702','8a200000-0000-4000-8000-000000000020','Robótica B','Somente tenant B','robotica-b-v2','institution','institution_standard',null,'draft',1);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a200000-0000-4000-8000-000000000301','internal_auth_link_id','8a200000-0000-4000-8000-000000000401','internal_membership_id','8a200000-0000-4000-8000-000000000501','auth_user_id','8a200000-0000-4000-8000-000000000101','session_id','8a200000-0000-4000-8000-000000000201','permission_code','activities.link_units','action_code','link_units','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_unit_links(id,activity_id,institution_id,unit_id,linked_by_person_id) values
 ('8a200000-0000-4000-8000-000000000711','8a200000-0000-4000-8000-000000000701','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000011',null),
 ('8a200000-0000-4000-8000-000000000713','8a200000-0000-4000-8000-000000000701','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000012',null),
 ('8a200000-0000-4000-8000-000000000721','8a200000-0000-4000-8000-000000000702','8a200000-0000-4000-8000-000000000020','8a200000-0000-4000-8000-000000000021',null);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a200000-0000-4000-8000-000000000301','internal_auth_link_id','8a200000-0000-4000-8000-000000000401','internal_membership_id','8a200000-0000-4000-8000-000000000501','auth_user_id','8a200000-0000-4000-8000-000000000101','session_id','8a200000-0000-4000-8000-000000000201','permission_code','activities.link_groups','action_code','link_groups','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_group_links(id,activity_id,institution_id,unit_id,group_id,linked_by_person_id,participation_mode) values
 ('8a200000-0000-4000-8000-000000000712','8a200000-0000-4000-8000-000000000701','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000011','8a200000-0000-4000-8000-000000000013',null,'all'),
 ('8a200000-0000-4000-8000-000000000714','8a200000-0000-4000-8000-000000000701','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000011','8a200000-0000-4000-8000-000000000015',null,'all'),
 ('8a200000-0000-4000-8000-000000000715','8a200000-0000-4000-8000-000000000701','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000012','8a200000-0000-4000-8000-000000000016',null,'all'),
 ('8a200000-0000-4000-8000-000000000722','8a200000-0000-4000-8000-000000000702','8a200000-0000-4000-8000-000000000020','8a200000-0000-4000-8000-000000000021','8a200000-0000-4000-8000-000000000022',null,'all');


-- A second activity in A exercises multiselects, ties and unit-origin projection.
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a200000-0000-4000-8000-000000000301','internal_auth_link_id','8a200000-0000-4000-8000-000000000401','internal_membership_id','8a200000-0000-4000-8000-000000000501',
 'auth_user_id','8a200000-0000-4000-8000-000000000101','session_id','8a200000-0000-4000-8000-000000000201','permission_code','activities.manage','action_code','manage','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_definitions(id,institution_id,name,description,handle_stem,
 origin_scope_kind,origin_unit_id,distribution_scope,governance_kind,created_by_person_id,status,management_version)
values ('8a200000-0000-4000-8000-000000000703','8a200000-0000-4000-8000-000000000010',
 'Robótica Local A','Descrição exclusiva para busca','robotica-a-local-v2','unit',
 '8a200000-0000-4000-8000-000000000012','unit_local','mandatory',null,'active',3);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a200000-0000-4000-8000-000000000301','internal_auth_link_id','8a200000-0000-4000-8000-000000000401','internal_membership_id','8a200000-0000-4000-8000-000000000501',
 'auth_user_id','8a200000-0000-4000-8000-000000000101','session_id','8a200000-0000-4000-8000-000000000201','permission_code','activities.link_units','action_code','link_units','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_unit_links(id,activity_id,institution_id,unit_id,linked_by_person_id)
values ('8a200000-0000-4000-8000-000000000731','8a200000-0000-4000-8000-000000000703',
 '8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000012',null);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a200000-0000-4000-8000-000000000301','internal_auth_link_id','8a200000-0000-4000-8000-000000000401','internal_membership_id','8a200000-0000-4000-8000-000000000501',
 'auth_user_id','8a200000-0000-4000-8000-000000000101','session_id','8a200000-0000-4000-8000-000000000201','permission_code','activities.link_groups','action_code','link_groups','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_group_links(id,activity_id,institution_id,unit_id,group_id,linked_by_person_id,participation_mode)
values ('8a200000-0000-4000-8000-000000000732','8a200000-0000-4000-8000-000000000703',
 '8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000012',
 '8a200000-0000-4000-8000-000000000014',null,'all');

-- A reader must not need write permissions merely to obtain directory filters.
delete from public.platform_role_permissions rp using public.platform_roles r, public.platform_permissions p
where rp.role_id=r.id and rp.permission_id=p.id and r.code='operations'
 and p.code in ('activities.manage','activities.link_units','activities.link_groups');
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8a200000-0000-4000-8000-000000000102','session_id','8a200000-0000-4000-8000-000000000202',
 'aal','aal2','role','authenticated')::text,true);

select has_function('public','superadmin_activity_filter_options_v2',array[]::text[],'nominal read-only filter options exist');
select ok(not coalesce(has_function_privilege('anon',to_regprocedure('public.superadmin_activity_filter_options_v2()'),'EXECUTE'),true),'anon has no filter RPC execute');
select ok(not coalesce(has_function_privilege('service_role',to_regprocedure('public.superadmin_activity_filter_options_v2()'),'EXECUTE'),true),'service role has no implicit filter RPC execute');
select ok(coalesce(has_function_privilege('authenticated',to_regprocedure('public.superadmin_activity_filter_options_v2()'),'EXECUTE'),false),'authenticated may enter authorized wrapper');
select ok(not has_function_privilege('anon','public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean)','EXECUTE'),'anon has no directory RPC execute');
select ok(not has_function_privilege('service_role','public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean)','EXECUTE'),'service role has no directory RPC execute');
select ok(has_function_privilege('authenticated','public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean)','EXECUTE'),'authenticated may enter directory wrapper');

-- A missing new RPC must produce TAP failures without hiding projection REDs.
-- This temporary invoker helper does not fabricate an API or grant RPC privileges.
create function pg_temp.directory_filter_options_result() returns jsonb language plpgsql as $$
declare result jsonb;
begin
 if to_regprocedure('public.superadmin_activity_filter_options_v2()') is null then return null; end if;
 execute 'select public.superadmin_activity_filter_options_v2()' into result;
 return result;
end $$;
grant execute on function pg_temp.directory_filter_options_result() to authenticated;

create temporary table directory_contract_results(label text primary key,body jsonb);
grant select, insert on table directory_contract_results to authenticated;
set local role authenticated;
insert into directory_contract_results values ('scoped_sql_role',to_jsonb(current_user::text));
insert into directory_contract_results values
 ('page',public.superadmin_activity_directory_v2('{}',11,0,'name',true)),
 ('options',pg_temp.directory_filter_options_result()),
 ('client_default',public.superadmin_activity_directory_v2('{"search":"","institution_ids":[],"unit_ids":[],"group_ids":[],"statuses":[],"origins":[]}',11,0,'name',true)),
 ('legacy',public.superadmin_activity_directory_v2('{"institution_id":"8a200000-0000-4000-8000-000000000010"}',24,0,'name',true)),
 ('description',public.superadmin_activity_directory_v2('{"search":"exclusiva"}',11,0,'name',true)),
 ('both',public.superadmin_activity_directory_v2('{"institution_ids":["8a200000-0000-4000-8000-000000000010","8a200000-0000-4000-8000-000000000020"],"statuses":["draft","active"],"origins":["institution","unit"],"unit_ids":["8a200000-0000-4000-8000-000000000011","8a200000-0000-4000-8000-000000000012"],"group_ids":["8a200000-0000-4000-8000-000000000013","8a200000-0000-4000-8000-000000000014"]}',11,0,'name',true)),
 ('and',public.superadmin_activity_directory_v2('{"unit_ids":["8a200000-0000-4000-8000-000000000011"],"group_ids":["8a200000-0000-4000-8000-000000000014"]}',11,0,'name',true)),
 ('tenant_b',public.superadmin_activity_directory_v2('{"institution_ids":["8a200000-0000-4000-8000-000000000020"]}',11,0,'name',true)),
 ('origin',public.superadmin_activity_directory_v2('{"origins":["unit"]}',11,0,'name',true)),
 ('active',public.superadmin_activity_directory_v2('{"statuses":["active"]}',11,0,'name',true)),
 ('unit_only',public.superadmin_activity_directory_v2('{"unit_ids":["8a200000-0000-4000-8000-000000000012"]}',11,0,'name',true)),
 ('unit_selective',public.superadmin_activity_directory_v2('{"unit_ids":["8a200000-0000-4000-8000-000000000011"]}',11,0,'name',true)),
 ('group_only',public.superadmin_activity_directory_v2('{"group_ids":["8a200000-0000-4000-8000-000000000013"]}',11,0,'name',true)),
 ('unit_b',public.superadmin_activity_directory_v2('{"unit_ids":["8a200000-0000-4000-8000-000000000021"]}',11,0,'name',true)),
 ('group_b',public.superadmin_activity_directory_v2('{"group_ids":["8a200000-0000-4000-8000-000000000022"]}',11,0,'name',true)),
 ('first',public.superadmin_activity_directory_v2('{}',1,0,'created_at',false)),
 ('second',public.superadmin_activity_directory_v2('{}',1,1,'created_at',false)),
 ('name_desc',public.superadmin_activity_directory_v2('{}',11,0,'name',false)),
 ('beyond',public.superadmin_activity_directory_v2('{}',1,9,'name',true)),
 ('wildcard',public.superadmin_activity_directory_v2('{"search":"%"}',11,0,'name',true));
reset role;

select is((select body#>>'{}' from directory_contract_results where label='scoped_sql_role'),'authenticated','scoped directory calls use authenticated SQL role');

select is((select body#>>'{data,total}' from directory_contract_results where label='page'),'2','scoped reader lists both activities in A');
select is((select body#>>'{data,total}' from directory_contract_results where label='client_default'),'2','exact initial client payload treats empty arrays as no filters');
select ok((select body#>>'{ok}'='true' from directory_contract_results where label='options'),'read-only actor obtains options without mutation permissions');
select ok((select jsonb_array_length(body#>'{data,institutions}')=1 and jsonb_array_length(body#>'{data,units}')=2 and jsonb_array_length(body#>'{data,groups}')=5 from directory_contract_results where label='options'),'filter options preserve all structures in authorized institution');
select ok((select body#>'{data,groups}' @> '[{"id":"8a200000-0000-4000-8000-000000000017","label":"Turma A5 sem atividade","parent_id":"8a200000-0000-4000-8000-000000000012"}]'::jsonb
 from directory_contract_results where label='options'),'options include an authorized group without any activity link');
select is((select body#>>'{data,units,0,parent_id}' from directory_contract_results where label='options'),'8a200000-0000-4000-8000-000000000010','unit option carries institution parent');
select is((select body#>>'{data,groups,0,parent_id}' from directory_contract_results where label='options'),'8a200000-0000-4000-8000-000000000011','group option carries unit parent');
select ok((select body#>'{data,institutions}' @> '[{"id":"8a200000-0000-4000-8000-000000000010","label":"Tenant A"}]'::jsonb
 and body#>'{data,units}' @> '[{"id":"8a200000-0000-4000-8000-000000000012","label":"A Sul","parent_id":"8a200000-0000-4000-8000-000000000010"}]'::jsonb
 and body#>'{data,groups}' @> '[{"id":"8a200000-0000-4000-8000-000000000014","label":"Turma A2 irmã","parent_id":"8a200000-0000-4000-8000-000000000012"}]'::jsonb
 from directory_contract_results where label='options'),'filter IDs and labels come from the real hierarchy');
select ok(not exists(select 1 from directory_contract_results where body::text like '%8a200000-0000-4000-8000-000000000020%' or body::text like '%8a200000-0000-4000-8000-000000000702%'),'neither directory nor options disclose tenant B');
select is((select body#>>'{data,total}' from directory_contract_results where label='legacy'),'2','legacy scalar filter remains compatible');
select is((select body#>>'{data,limit}' from directory_contract_results where label='legacy'),'24','legacy pagination remains compatible');
select is((select body#>>'{data,items,0,id}' from directory_contract_results where label='description'),'8a200000-0000-4000-8000-000000000703','search matches description');
select is((select body#>>'{data,total}' from directory_contract_results where label='both'),'2','arrays OR within dimensions and preserve scoped tenant');
select is((select body#>>'{data,total}' from directory_contract_results where label='and'),'0','dimensions combine with AND');
select is((select body#>>'{data,total}' from directory_contract_results where label='tenant_b'),'0','cross-tenant filter only narrows');
select is((select body#>>'{data,total}' from directory_contract_results where label='origin'),'1','origin filter is real');
select is((select body#>>'{data,items,0,id}' from directory_contract_results where label='active'),'8a200000-0000-4000-8000-000000000703','status filter excludes draft activity');
select is((select body#>>'{data,total}' from directory_contract_results where label='active'),'1','status filter is selective');
select is((select body#>>'{data,total}' from directory_contract_results where label='unit_only'),'2','unit array returns both activities linked to A Sul without duplication');
select is((select body#>>'{data,total}' from directory_contract_results where label='unit_selective'),'1','unit array alone excludes an activity from another unit');
select is((select body#>>'{data,items,0,id}' from directory_contract_results where label='unit_selective'),'8a200000-0000-4000-8000-000000000701','selective unit filter returns the actually linked activity');
select is((select body#>>'{data,items,0,id}' from directory_contract_results where label='group_only'),'8a200000-0000-4000-8000-000000000701','group array alone is selective');
select is((select body#>>'{data,total}' from directory_contract_results where label='group_only'),'1','group filter excludes the other activity');
select is(body#>>'{data,total}','0','cross-tenant structural filter narrows: '||label) from directory_contract_results where label in ('unit_b','group_b');
select is((select body#>>'{data,items,0,id}' from directory_contract_results where label='first'),'8a200000-0000-4000-8000-000000000701','first tie is stable by id');
select is((select body#>>'{data,items,0,id}' from directory_contract_results where label='second'),'8a200000-0000-4000-8000-000000000703','next offset does not repeat equal timestamps');
select is(body#>>'{data,total}','2','total is independent of limit/offset: '||label)
 from directory_contract_results where label in ('first','second','beyond') order by label;
select is(body#>>'{data,limit}','1','requested limit is preserved: '||label)
 from directory_contract_results where label in ('first','second','beyond') order by label;
select is((select body#>>'{data,offset}' from directory_contract_results where label='second'),'1','second page reports actual offset');
select is((select body#>>'{data,offset}' from directory_contract_results where label='beyond'),'9','out-of-range page preserves requested offset');
select is(jsonb_array_length(body#>'{data,items}'),1,'limited page has exactly one distinct activity: '||label)
 from directory_contract_results where label in ('first','second') order by label;
select is((select jsonb_array_length(body#>'{data,items}') from directory_contract_results where label='beyond'),0,'offset beyond total returns empty items');
select is((select body#>>'{data,items,0,id}' from directory_contract_results where label='page'),'8a200000-0000-4000-8000-000000000701','name ASC starts with Robótica A');
select is((select body#>>'{data,items,0,id}' from directory_contract_results where label='name_desc'),'8a200000-0000-4000-8000-000000000703','name DESC starts with Robótica Local A');
select ok((select body#>>'{data,items,0,active_unit_count}'='2'
 and body#>>'{data,items,0,active_group_count}'='3'
 and jsonb_array_length(body#>'{data,items,0,linked_units}')=2
 and jsonb_array_length(body#>'{data,items,0,linked_groups}')=3
 from directory_contract_results where label='first'),'two-unit three-group fixture does not multiply aggregates');
select is((select body#>>'{data,total}' from directory_contract_results where label='wildcard'),'0','search wildcards are literal input');

select ok((select body#>'{data,items,0}' ?& array['id','activity_id','institution_id','institution_name','name','status','description','origin_scope_kind',
 'distribution_scope','governance_kind','handle_stem','canonical_handle','management_version',
 'active_unit_count','active_group_count','unit_count','group_count','linked_units','linked_groups',
 'icon_key','initials','created_at','updated_at'] from directory_contract_results where label='description'),'complete allowlisted client projection with legacy aliases');
select ok((select body#>>'{data,items,0,origin_scope_kind}'='unit'
 and body#>>'{data,items,0,distribution_scope}'='unit_local'
 and body#>>'{data,items,0,governance_kind}'='mandatory'
 and body#>>'{data,items,0,management_version}'='3'
 from directory_contract_results where label='description'),'origin distribution governance and version are not fabricated');
select ok((select body#>>'{data,items,0,active_unit_count}'='1'
 and body#>>'{data,items,0,active_group_count}'='1'
 and body#>>'{data,items,0,linked_units,0,name}'='A Sul'
 and body#>>'{data,items,0,linked_groups,0,name}'='Turma A2 irmã'
 and body#>>'{data,items,0,linked_groups,0,unit_name}'='A Sul'
 from directory_contract_results where label='description'),'linked context arrays match counts and actual names');
select ok((select body#>'{data,items,0}' @> jsonb_build_object(
 'id',a.id,'activity_id',a.id,'institution_id',a.institution_id,'institution_name','Tenant A',
 'name',a.name,'status',a.status,'handle_stem',a.handle_stem,'canonical_handle',a.canonical_handle,
 'created_at',a.created_at,'updated_at',a.updated_at,
 'management_version',3,'active_unit_count',1,'unit_count',1,'active_group_count',1,'group_count',1)
 from directory_contract_results r cross join public.activity_definitions a
 where r.label='description' and a.id='8a200000-0000-4000-8000-000000000703'),
 'required identities strings numeric counts and aliases exactly match the source');
select ok((select body#>'{data,items,0,linked_units}' @> '[{"id":"8a200000-0000-4000-8000-000000000012","institution_id":"8a200000-0000-4000-8000-000000000010"}]'::jsonb
 and body#>'{data,items,0,linked_groups}' @> '[{"id":"8a200000-0000-4000-8000-000000000014","unit_id":"8a200000-0000-4000-8000-000000000012"}]'::jsonb
 and jsonb_array_length(body#>'{data,items,0,linked_units}')=1
 and jsonb_array_length(body#>'{data,items,0,linked_groups}')=1
 from directory_contract_results where label='description'),'linked context IDs are canonical rather than link-row IDs');
select is((select body#>>'{data,items,0,distribution_scope}' from directory_contract_results where label='first'),'institution_standard','institutional distribution is preserved');
select ok(not exists(select 1 from directory_contract_results where body::text ~ 'created_by_person_id|auth_user_id|internal_identity|@invalid.test|storage_path|location_names'),'no actor identifiers, contact data or unrelated locations');

-- Invalid input never falls back to a broader query.
set local role authenticated;
insert into directory_contract_results values ('invalid_sql_role',to_jsonb(current_user::text));
insert into directory_contract_results(label,body)
select 'invalid:'||label,public.superadmin_activity_directory_v2(input,11,0,'name',true)
from (values
 ('non-object','[]'::jsonb),('unknown','{"unexpected":true}'::jsonb),
 ('array-null','{"institution_ids":null}'::jsonb),('not-array','{"unit_ids":"x"}'::jsonb),
 ('member-not-string','{"group_ids":[1]}'::jsonb),('invalid-uuid','{"institution_ids":["invalid"]}'::jsonb),
 ('unknown-status','{"statuses":["invented"]}'::jsonb),('unknown-origin','{"origins":["platform"]}'::jsonb),
 ('scalar-status','{"status":"invented"}'::jsonb),('search-type','{"search":123}'::jsonb),
 ('ambiguous','{"institution_id":"8a200000-0000-4000-8000-000000000010","institution_ids":[]}'::jsonb),
 ('duplicate','{"statuses":["active","active"]}'::jsonb),
 ('oversized',jsonb_build_object('unit_ids',(select jsonb_agg('8a200000-0000-4000-8000-'||lpad(n::text,12,'0')) from generate_series(1,101) n))),
 ('search-too-long',jsonb_build_object('search',repeat('x',121)))
) invalid(label,input) order by label;
reset role;
select is((select body#>>'{}' from directory_contract_results where label='invalid_sql_role'),'authenticated','invalid-input calls use authenticated SQL role');
select is(body#>>'{error,code}','ACTIVITY_INVALID_INPUT','invalid filters rejected: '||label)
from directory_contract_results where label like 'invalid:%' order by label;

-- The current foundation defers MFA enforcement, but still validates AAL.
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8a200000-0000-4000-8000-000000000103','session_id','8a200000-0000-4000-8000-000000000203',
 'aal','aal1','role','authenticated')::text,true);
insert into directory_contract_results values
 ('aal1_sql_role',to_jsonb(current_user::text)),
 ('aal1_directory',public.superadmin_activity_directory_v2('{}',11,0,'name',true)),
 ('aal1_options',pg_temp.directory_filter_options_result());
reset role;
select is((select body#>>'{}' from directory_contract_results where label='aal1_sql_role'),'authenticated','AAL1 positive calls use authenticated SQL role');
select is((select body->>'ok' from directory_contract_results where label='aal1_directory'),'true','current MVP AAL1 policy is preserved under authenticated');
select is((select body->>'ok' from directory_contract_results where label='aal1_options'),'true','filters preserve current MVP AAL1 policy under authenticated');

-- Separate statements guarantee claims are applied before each RPC.
create temporary table directory_denials(label text, expected text, directory jsonb, options jsonb);
grant select, insert on table directory_denials to authenticated;
set local role authenticated;
insert into directory_contract_results values ('negative_sql_role',to_jsonb(current_user::text));
do $$
declare fixture record;
begin
 for fixture in select * from (values
   ('expired',101,209,'aal2','SAI_SESSION_INVALID'),
   ('invalid-aal',103,203,'aal3','SAI_SESSION_INVALID'),
   ('revoked',104,204,'aal2','SAI_MEMBERSHIP_REVOKED'),
   ('people-only',105,205,'aal2','SAI_INTERNAL_CONTEXT_DENIED'),
   ('capability',106,206,'aal2','SAI_PERMISSION_DENIED')
 ) denied(label,user_suffix,session_suffix,aal,expected) loop
  perform set_config('request.jwt.claims',jsonb_build_object(
   'sub','8a200000-0000-4000-8000-'||lpad(fixture.user_suffix::text,12,'0'),
   'session_id','8a200000-0000-4000-8000-'||lpad(fixture.session_suffix::text,12,'0'),
   'aal',fixture.aal,'role','authenticated')::text,true);
  insert into directory_denials values(fixture.label,fixture.expected,
   public.superadmin_activity_directory_v2('{}',11,0,'name',true),
   pg_temp.directory_filter_options_result());
 end loop;
end $$;
reset role;
select is((select body#>>'{}' from directory_contract_results where label='negative_sql_role'),'authenticated','all negative calls use authenticated SQL role');
select is(directory#>>'{error,code}',expected,'directory denies '||label)
from directory_denials order by label;
select is(options#>>'{error,code}',expected,'filter options deny '||label)
from directory_denials order by label;

set local role authenticated;
select set_config('request.jwt.claims','{}',true);
insert into directory_contract_results values
 ('anonymous_sql_role',to_jsonb(current_user::text)),
 ('anonymous_options',pg_temp.directory_filter_options_result());
reset role;
select is((select body#>>'{}' from directory_contract_results where label='anonymous_sql_role'),'authenticated','request without claims still uses authenticated transport role');
select is((select body#>>'{error,code}' from directory_contract_results where label='anonymous_options'),'SAI_AUTH_REQUIRED','anonymous request cannot retrieve options');
select ok(exists(select 1 from audit.audit_logs where permission_code='activities.read'
 and action_code='activity.filter_options' and outcome='denied'
 and actor_internal_identity_id in ('8a200000-0000-4000-8000-000000000304','8a200000-0000-4000-8000-000000000306')),
 'identified denials preserve minimized audit');

-- A01 follow-up: keep all original 89 assertions and exercise read-success
-- audit plus fail-stop behavior when the actual append is unavailable.
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8a200000-0000-4000-8000-000000000102','session_id','8a200000-0000-4000-8000-000000000202',
 'aal','aal2','role','authenticated')::text,true);
insert into directory_contract_results values
 ('audit_success_sql_role',to_jsonb(current_user::text)),
 ('audit_directory',public.superadmin_activity_directory_v2('{}',11,0,'name',true)),
 ('audit_options',pg_temp.directory_filter_options_result());
reset role;
select is((select body#>>'{}' from directory_contract_results where label='audit_success_sql_role'),
 'authenticated','success audit calls use authenticated SQL role');
select ok(r.body->>'ok'='true' and exists (
 select 1 from audit.audit_logs a
 where a.correlation_id::text=r.body#>>'{data,correlation_id}'
   and a.action_code=case r.label when 'audit_directory' then 'activity.directory' else 'activity.filter_options' end
   and a.permission_code='activities.read' and a.outcome='success'
   and a.actor_kind='superadmin_internal'
   and a.actor_internal_identity_id='8a200000-0000-4000-8000-000000000302'
   and a.actor_internal_auth_link_id='8a200000-0000-4000-8000-000000000402'
   and a.actor_internal_membership_id='8a200000-0000-4000-8000-000000000502'
   and a.institution_id='8a200000-0000-4000-8000-000000000010'
   and a.session_id_hash is not null), 'successful read has correlated internal audit: '||r.label)
from directory_contract_results r where label in ('audit_directory','audit_options') order by label;
select ok(exists (
 select 1 from audit.audit_logs a
 where a.correlation_id::text=r.body#>>'{data,correlation_id}'
   and a.after_json = jsonb_build_object('row_count',case r.label when 'audit_directory' then 2 else 8 end)
   and a.object_id is null
   and a.before_json is null
   and a.after_json::text !~ 'Tenant|Robótica|Turma|request.jwt|auth_user|session_id|description|search'),
 'successful read audit contains only minimized counts: '||r.label)
from directory_contract_results r where label in ('audit_directory','audit_options') order by label;

create function pg_temp.reject_activity_read_success_audit() returns trigger
language plpgsql as $$
begin
 if new.permission_code='activities.read' and new.outcome='success'
   and new.action_code in ('activity.directory','activity.filter_options') then
   raise exception using errcode='P0001',message='A01_AUDIT_FAILURE';
 end if;
 return new;
end $$;
create trigger a01_reject_activity_read_success_audit before insert on audit.audit_logs
for each row execute function pg_temp.reject_activity_read_success_audit();

set local role authenticated;
insert into directory_contract_results values ('audit_failure_sql_role',to_jsonb(current_user::text));
do $$
declare action text; response jsonb;
begin
 foreach action in array array['directory','options'] loop
  begin
   response := case action when 'directory' then public.superadmin_activity_directory_v2('{}',11,0,'name',true)
     else pg_temp.directory_filter_options_result() end;
   insert into directory_contract_results values ('audit_failure_'||action,response);
  exception when others then
   insert into directory_contract_results values ('audit_failure_'||action,
     jsonb_build_object('raised',sqlstate,'message',sqlerrm,'data',null));
  end;
 end loop;
end $$;
reset role;
select is((select body#>>'{}' from directory_contract_results where label='audit_failure_sql_role'),
 'authenticated','append-failure calls use authenticated SQL role');
select is(body,jsonb_build_object('raised','P0001','message','A01_AUDIT_FAILURE','data',null),
 'append failure propagates without a data or success envelope: '||label)
from directory_contract_results where label in ('audit_failure_directory','audit_failure_options') order by label;
drop trigger a01_reject_activity_read_success_audit on audit.audit_logs;

select * from finish();
rollback;
