-- Nominal READ-only regression; execute only in the coordinated disposable replay.
-- Requires internal Auth MVP, model CRUD/catalog 171731 and named wrappers 193000.
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data) values
  ('f1000000-0000-4000-8000-000000000001','authenticated','authenticated',
   'model-read-owner@invalid.test',now(),now(),now(),'{}','{}'),
  ('f1000000-0000-4000-8000-000000000002','authenticated','authenticated',
   'model-read-global@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('f2000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
  ('f2000000-0000-4000-8000-000000000002','f1000000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
  ('f3000000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
  ('f4000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select 'f5000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001',id,'platform'
from public.platform_roles where code='owner';
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('f6000000-0000-4000-8000-000000000002','adult','Pessoa','Sintética','Pessoa Sintética','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
  ('f6000000-0000-4000-8000-000000000002','f1000000-0000-4000-8000-000000000002','active');
insert into public.access_profile_templates(id,domain,code,name,max_scope_kind,is_system,status) values
  ('f7000000-0000-4000-8000-000000000001','platform','read_test_platform','Read nominal platform','platform',false,'active'),
  ('f7000000-0000-4000-8000-000000000002','institution','read_test_institution','Read nominal institution','institution',false,'active'),
  ('f7000000-0000-4000-8000-000000000003','principal','read_test_principal','Read nominal principal','child_context',false,'active');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','f1000000-0000-4000-8000-000000000001',
  'session_id','f2000000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.models_read_actor',current_user,true);
select set_config('test.models_read_details',jsonb_build_array(
  public.superadmin_access_profile_model_detail('f7000000-0000-4000-8000-000000000001')#>>'{data,id}',
  public.superadmin_access_profile_model_detail('f7000000-0000-4000-8000-000000000002')#>>'{data,id}',
  public.superadmin_access_profile_model_detail('f7000000-0000-4000-8000-000000000003')#>>'{data,id}')::text,true);
select set_config('test.models_read_lists',jsonb_build_array(
  public.superadmin_access_profile_models_cursor('Read nominal','platform',null,null,25,null,null)#>>'{data,items,0,id}',
  public.superadmin_access_profile_models_cursor('Read nominal','institution',null,null,25,null,null)#>>'{data,items,0,id}',
  public.superadmin_access_profile_models_cursor('Read nominal','principal',null,null,25,null,null)#>>'{data,items,0,id}')::text,true);
select set_config('test.models_read_catalog',public.superadmin_access_permission_catalog()::text,true);
reset role;
select is(current_setting('test.models_read_actor'),'authenticated','READ calls execute as authenticated, not the fixture owner');
select is(current_setting('test.models_read_details')::jsonb,
  '["f7000000-0000-4000-8000-000000000001","f7000000-0000-4000-8000-000000000002","f7000000-0000-4000-8000-000000000003"]'::jsonb,
  'internal Owner without people reads each domain at AAL1');
select is(current_setting('test.models_read_lists')::jsonb,current_setting('test.models_read_details')::jsonb,
  'cursor readers preserve all three authorized domains');
select is(current_setting('test.models_read_catalog')::jsonb->>'ok','true','internal Owner reads the permission catalog');

-- Same identified actor, but a session that does not exist.
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','f1000000-0000-4000-8000-000000000001',
  'session_id','f2000000-0000-4000-8000-000000000099',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.models_read_invalid_detail',jsonb_build_array(
  public.superadmin_access_profile_model_detail('f7000000-0000-4000-8000-000000000001')#>>'{error,code}',
  public.superadmin_access_profile_model_detail('f7000000-0000-4000-8000-000000000099')#>>'{error,code}')::text,true);
select set_config('test.models_read_invalid_other',jsonb_build_array(
  public.superadmin_access_profile_models_cursor(null,'platform',null,null,25,null,null)#>>'{error,code}',
  public.superadmin_access_permission_catalog()#>>'{error,code}')::text,true);
reset role;
select is(current_setting('test.models_read_invalid_detail')::jsonb,'["SAI_SESSION_INVALID","SAI_SESSION_INVALID"]'::jsonb,
  'invalid session is rejected before existing or unknown model lookup');
select is(current_setting('test.models_read_invalid_other')::jsonb,'["SAI_SESSION_INVALID","SAI_SESSION_INVALID"]'::jsonb,
  'invalid session cannot read list or catalog');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','f1000000-0000-4000-8000-000000000002',
  'session_id','f2000000-0000-4000-8000-000000000002',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.models_read_global_detail',jsonb_build_array(
  public.superadmin_access_profile_model_detail('f7000000-0000-4000-8000-000000000001')#>>'{error,code}',
  public.superadmin_access_profile_model_detail('f7000000-0000-4000-8000-000000000099')#>>'{error,code}')::text,true);
select set_config('test.models_read_global_other',jsonb_build_array(
  public.superadmin_access_profile_models_cursor(null,'platform',null,null,25,null,null)#>>'{error,code}',
  public.superadmin_access_permission_catalog()#>>'{error,code}')::text,true);
reset role;
select is(current_setting('test.models_read_global_detail')::jsonb,'["SAI_INTERNAL_CONTEXT_DENIED","SAI_INTERNAL_CONTEXT_DENIED"]'::jsonb,
  'global person is rejected before existing or unknown model lookup');
select is(current_setting('test.models_read_global_other')::jsonb,'["SAI_INTERNAL_CONTEXT_DENIED","SAI_INTERNAL_CONTEXT_DENIED"]'::jsonb,
  'global person cannot read list or catalog');

-- Deny one domain only: the new preliminary gate must not replace this check.
update public.platform_role_permissions grants set effect='deny'
from public.platform_roles roles,public.platform_permissions permissions
where grants.role_id=roles.id and grants.permission_id=permissions.id
  and roles.code='owner' and permissions.code='institution.role_models.read';
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','f1000000-0000-4000-8000-000000000001',
  'session_id','f2000000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.models_read_domain_denied',jsonb_build_array(
  public.superadmin_access_profile_model_detail('f7000000-0000-4000-8000-000000000002')#>>'{error,code}',
  public.superadmin_access_profile_models_cursor(null,'institution',null,null,25,null,null)#>>'{error,code}')::text,true);
select set_config('test.models_read_platform_still_allowed',public.superadmin_access_profile_model_detail('f7000000-0000-4000-8000-000000000001')::text,true);
reset role;
select is(current_setting('test.models_read_domain_denied')::jsonb,'["SAI_PERMISSION_DENIED","SAI_PERMISSION_DENIED"]'::jsonb,
  'domain read capability remains mandatory for detail and list');
select is(current_setting('test.models_read_platform_still_allowed')::jsonb->>'ok','true',
  'denial of institution model read does not revoke platform model read');
select ok(exists(select 1 from audit.audit_logs
  where actor_internal_identity_id='f3000000-0000-4000-8000-000000000001'
    and action_code='superadmin.access-profile-models.detail' and outcome='denied'
    and actor_person_id is null),
  'identified internal READ denial is audited without a people actor');

-- Domain-only Owner: no platform.read and no other model READ capability.
update public.platform_role_permissions grants
set effect=case when permissions.code='institution.role_models.read'
  then 'allow'::public.permission_effect else 'deny'::public.permission_effect end
from public.platform_roles roles,public.platform_permissions permissions
where grants.role_id=roles.id and grants.permission_id=permissions.id
  and roles.code='owner' and permissions.code in(
    'platform.read','platform.role_models.read',
    'institution.role_models.read','principal.role_models.read');
set local role authenticated;
select set_config('test.models_institution_only_allowed',jsonb_build_array(
  public.superadmin_access_profile_model_detail('f7000000-0000-4000-8000-000000000002')#>>'{data,id}',
  public.superadmin_access_profile_models_cursor('Read nominal','institution',null,null,25,null,null)#>>'{data,items,0,id}')::text,true);
select set_config('test.models_institution_only_denied',jsonb_build_array(
  public.superadmin_access_profile_model_detail('f7000000-0000-4000-8000-000000000001')#>>'{error,code}',
  public.superadmin_access_permission_catalog()#>>'{error,code}')::text,true);
select set_config('test.models_institution_only_actor',current_user,true);
reset role;
select is(current_setting('test.models_institution_only_actor'),'authenticated',
  'institution-only control executes as authenticated');
select is(current_setting('test.models_institution_only_allowed')::jsonb,
  '["f7000000-0000-4000-8000-000000000002","f7000000-0000-4000-8000-000000000002"]'::jsonb,
  'institution list/detail preserve domain-only capability without platform.read');
select is(current_setting('test.models_institution_only_denied')::jsonb,
  '["SAI_PERMISSION_DENIED","SAI_PERMISSION_DENIED"]'::jsonb,
  'institution-only capability does not grant platform detail or catalog');

-- Domain-only Owner: no platform.read and no other model READ capability.
update public.platform_role_permissions grants
set effect=case when permissions.code='principal.role_models.read'
  then 'allow'::public.permission_effect else 'deny'::public.permission_effect end
from public.platform_roles roles,public.platform_permissions permissions
where grants.role_id=roles.id and grants.permission_id=permissions.id
  and roles.code='owner' and permissions.code in(
    'platform.read','platform.role_models.read',
    'institution.role_models.read','principal.role_models.read');
set local role authenticated;
select set_config('test.models_principal_only_allowed',jsonb_build_array(
  public.superadmin_access_profile_model_detail('f7000000-0000-4000-8000-000000000003')#>>'{data,id}',
  public.superadmin_access_profile_models_cursor('Read nominal','principal',null,null,25,null,null)#>>'{data,items,0,id}')::text,true);
select set_config('test.models_principal_only_denied',jsonb_build_array(
  public.superadmin_access_profile_model_detail('f7000000-0000-4000-8000-000000000001')#>>'{error,code}',
  public.superadmin_access_permission_catalog()#>>'{error,code}')::text,true);
select set_config('test.models_principal_only_actor',current_user,true);
reset role;
select is(current_setting('test.models_principal_only_actor'),'authenticated',
  'principal-only control executes as authenticated');
select is(current_setting('test.models_principal_only_allowed')::jsonb,
  '["f7000000-0000-4000-8000-000000000003","f7000000-0000-4000-8000-000000000003"]'::jsonb,
  'principal list/detail preserve domain-only capability without platform.read');
select is(current_setting('test.models_principal_only_denied')::jsonb,
  '["SAI_PERMISSION_DENIED","SAI_PERMISSION_DENIED"]'::jsonb,
  'principal-only capability does not grant platform detail or catalog');

select * from finish();
rollback;
