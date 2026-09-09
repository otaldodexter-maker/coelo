-- D04 scope filter contract. Disposable local replay only; all data rolls back.
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data) values
  ('d4100000-0000-4000-8000-000000000001','authenticated','authenticated',
   'd04-model-filter@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('d4200000-0000-4000-8000-000000000001','d4100000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
  ('d4300000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
  ('d4400000-0000-4000-8000-000000000001','d4300000-0000-4000-8000-000000000001','d4100000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select 'd4500000-0000-4000-8000-000000000001','d4300000-0000-4000-8000-000000000001',id,'platform'
from public.platform_roles where code='owner';
insert into public.access_profile_templates(id,domain,code,name,max_scope_kind,is_system,status) values
  ('d4700000-0000-4000-8000-000000000001','institution','d04_unit','D04 filter A','unit',false,'active'),
  ('d4700000-0000-4000-8000-000000000002','institution','d04_group','D04 filter B','group',false,'active'),
  ('d4700000-0000-4000-8000-000000000003','institution','d04_institution','D04 filter C','institution',false,'active'),
  ('d4700000-0000-4000-8000-000000000004','institution','d04_unit_inactive','D04 filter D','unit',false,'inactive');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','d4100000-0000-4000-8000-000000000001',
  'session_id','d4200000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.d04_scopes',jsonb_build_object(
  'all',public.superadmin_access_profile_models_cursor('D04 filter','institution',null,null,25,null,null),
  'single',public.superadmin_access_profile_models_cursor('D04 filter','institution',null,'unit',25,null,null),
  'multi',public.superadmin_access_profile_models_cursor('D04 filter','institution',null,'unit,group',25,null,null),
  'active',public.superadmin_access_profile_models_cursor('D04 filter','institution','active','unit,group',25,null,null),
  'first',public.superadmin_access_profile_models_cursor('D04 filter','institution','active','unit,group',1,null,null),
  'next',public.superadmin_access_profile_models_cursor('D04 filter','institution','active','unit,group',1,'D04 filter A','d4700000-0000-4000-8000-000000000001'),
  'empty',public.superadmin_access_profile_models_cursor('D04 filter missing','institution',null,'unit,group',25,null,null),
  'invalid',public.superadmin_access_profile_models_cursor('D04 filter','institution',null,'unit,unknown',25,null,null),
  'wrong_domain',public.superadmin_access_profile_models_cursor('D04 filter','institution',null,'unit,platform',25,null,null),
  'oversize',public.superadmin_access_profile_models_cursor('D04 filter','institution',null,repeat('unit,',1000),25,null,null),
  'duplicate',public.superadmin_access_profile_models_cursor('D04 filter','institution',null,'unit,unit',25,null,null)
)::text,true);
reset role;
select is(current_setting('test.d04_scopes')::jsonb#>>'{all,ok}','true','AAL1 internal Owner can read scoped models');
select is(jsonb_array_length(current_setting('test.d04_scopes')::jsonb#>'{all,data,items}'),4,'null scope retains unfiltered compatibility');
select is(jsonb_array_length(current_setting('test.d04_scopes')::jsonb#>'{single,data,items}'),2,'single scope retains scalar compatibility');
select is(jsonb_array_length(current_setting('test.d04_scopes')::jsonb#>'{multi,data,items}'),3,'multi scope is a union without leaking an unselected scope');
select is(jsonb_array_length(current_setting('test.d04_scopes')::jsonb#>'{active,data,items}'),2,'scope union intersects the status filter');
select is(current_setting('test.d04_scopes')::jsonb#>>'{first,data,next_cursor,id}','d4700000-0000-4000-8000-000000000001','cursor points to the last returned filtered row');
select is(current_setting('test.d04_scopes')::jsonb#>>'{next,data,items,0,id}','d4700000-0000-4000-8000-000000000002','next filtered page returns the other selected scope');
select is(jsonb_array_length(current_setting('test.d04_scopes')::jsonb#>'{empty,data,items}'),0,'search still intersects multiple scopes');
select is(current_setting('test.d04_scopes')::jsonb#>>'{invalid,error,code}','SAI_INVALID_ARGUMENT','unknown scope is rejected');
select is(current_setting('test.d04_scopes')::jsonb#>>'{wrong_domain,error,code}','SAI_INVALID_ARGUMENT','scope from another domain is rejected');
select is(current_setting('test.d04_scopes')::jsonb#>>'{oversize,error,code}','SAI_INVALID_ARGUMENT','scope input is bounded server-side');
select is(jsonb_array_length(current_setting('test.d04_scopes')::jsonb#>'{duplicate,data,items}'),2,'duplicate scopes do not duplicate rows');

update public.platform_role_permissions grants set effect='deny'
from public.platform_roles roles,public.platform_permissions permissions
where grants.role_id=roles.id and grants.permission_id=permissions.id
  and roles.code='owner' and permissions.code='institution.role_models.read';
set local role authenticated;
select set_config('test.d04_denied',public.superadmin_access_profile_models_cursor(
  'D04 filter','institution',null,'unit,group',25,null,null)::text,true);
reset role;
select is(current_setting('test.d04_denied')::jsonb#>>'{error,code}','SAI_PERMISSION_DENIED','multiselect does not bypass domain authorization');
select ok(not has_function_privilege('authenticated',
  'app_private.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)','execute'),
  'private cursor does not become an authenticated entry point');
select ok(exists(select 1 from audit.audit_logs
  where actor_internal_identity_id='d4300000-0000-4000-8000-000000000001'
    and action_code='superadmin.access-profile-models.list' and outcome='denied'),
  'domain denial still uses canonical audit');
select * from finish();
rollback;
