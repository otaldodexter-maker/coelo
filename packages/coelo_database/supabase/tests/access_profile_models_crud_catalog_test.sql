begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

select has_column('public','access_profile_templates','created_by_internal_identity_id',
  'models record the isolated internal actor');
select has_table('app_private','access_profile_model_command_receipts',
  'model receipts live in the internal realm');
select results_eq(
  $$select count(*)::bigint from public.platform_permissions
    where screen_code='access_profile_models' and status='active'$$,
  array[18::bigint],'six model actions exist for each application domain');
select results_eq(
  $$select count(*)::bigint from public.platform_role_permissions grant_record
    join public.platform_roles role_record on role_record.id=grant_record.role_id
    join public.platform_permissions permission_record on permission_record.id=grant_record.permission_id
    where permission_record.screen_code='access_profile_models'
      and grant_record.status='active' and grant_record.revoked_at is null
      and role_record.code<>'owner'$$,
  array[0::bigint],'model actions are granted only to Owner by default');

select has_function('public','superadmin_access_profile_model_detail',array['uuid'],'detail RPC exists');
select has_function('public','superadmin_access_profile_models_cursor',
  array['text','text','text','text','integer','text','uuid'],'cursor RPC exists');
select has_function('public','superadmin_access_profile_model_create',array['uuid','jsonb'],'create RPC exists');
select has_function('public','superadmin_access_profile_model_update',array['uuid','jsonb'],'update RPC exists');
select has_function('public','superadmin_access_profile_model_delete',array['uuid','uuid','bigint','text'],'delete RPC exists');
select has_function('public','superadmin_access_profile_model_duplicate',array['uuid','jsonb'],'duplicate RPC exists');
select has_function('public','superadmin_access_profile_models_export',array['text'],'export RPC exists');
select has_function('public','superadmin_access_profile_models_import_preview',array['text','jsonb'],'preview RPC exists');
select has_function('public','superadmin_access_profile_models_import_confirm',array['uuid','text','jsonb','text'],'import RPC exists');
select has_function('public','superadmin_access_permission_catalog',array[]::text[],'catalog RPC exists');

select ok(lower(pg_get_functiondef(
    'app_private.access_profile_require_model_action(text,text,boolean)'::regprocedure))
    like '%require_superadmin_internal_context%'
  and lower(pg_get_functiondef(
    'app_private.access_profile_require_model_action(text,text,boolean)'::regprocedure))
    not like '%current_person_id%',
  'authorization is rooted only in the isolated internal realm');
select ok(lower(pg_get_functiondef(
    'app_private.access_profile_model_internal_can_delegate(uuid,text,text)'::regprocedure))
    not like '%has_platform_permission%'
  and lower(pg_get_functiondef(
    'app_private.access_profile_model_audit_success(uuid,text,text,uuid)'::regprocedure))
    not like '%actor_person_id%',
  'delegation and audit never fall back to legacy people');
select is((select count(*)::bigint from pg_class c where c.oid in(
    'public.access_profile_templates'::regclass,
    'public.access_profile_template_platform_permissions'::regclass,
    'public.access_profile_template_institution_permissions'::regclass,
    'public.access_profile_template_principal_capabilities'::regclass,
    'app_private.access_profile_model_command_receipts'::regclass)
    and c.relrowsecurity and c.relforcerowsecurity),5::bigint,
  'all model persistence has enabled and forced RLS');
select is((select count(*)::bigint from (values
    ('public.access_profile_templates'::regclass),
    ('public.access_profile_template_platform_permissions'::regclass),
    ('public.access_profile_template_institution_permissions'::regclass),
    ('public.access_profile_template_principal_capabilities'::regclass),
    ('app_private.access_profile_model_command_receipts'::regclass)) t(oid)
    cross join (values('authenticated'),('service_role')) r(name)
    where has_table_privilege(name,oid,'SELECT,INSERT,UPDATE,DELETE')),0::bigint,
  'clients and service role have no direct model persistence bypass');
select is((select count(*)::bigint from (values
    ('app_private.access_profile_require_model_action(text,text,boolean)'::regprocedure),
    ('app_private.access_profile_model_replay_internal(uuid,uuid,text,jsonb)'::regprocedure),
    ('app_private.access_profile_model_call(text,jsonb)'::regprocedure)) h(oid)
    cross join (values('public'),('anon'),('authenticated'),('service_role')) r(name)
    where has_function_privilege(name,oid,'EXECUTE')),0::bigint,
  'private model helpers deny every client and service role');
select is((select count(*)::bigint from (values
    ('public.superadmin_access_profile_model_detail(uuid)'::regprocedure),
    ('public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)'::regprocedure),
    ('public.superadmin_access_profile_model_create(uuid,jsonb)'::regprocedure),
    ('public.superadmin_access_profile_model_update(uuid,jsonb)'::regprocedure),
    ('public.superadmin_access_profile_model_delete(uuid,uuid,bigint,text)'::regprocedure),
    ('public.superadmin_access_profile_model_duplicate(uuid,jsonb)'::regprocedure),
    ('public.superadmin_access_profile_models_export(text)'::regprocedure),
    ('public.superadmin_access_profile_models_import_preview(text,jsonb)'::regprocedure),
    ('public.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text)'::regprocedure),
    ('public.superadmin_access_permission_catalog()'::regprocedure)) rpc(oid)
    where has_function_privilege('authenticated',oid,'EXECUTE')
      and not has_function_privilege('anon',oid,'EXECUTE')
      and not has_function_privilege('service_role',oid,'EXECUTE')),10::bigint,
  'all gateways are authenticated-only');

set local role authenticated;
select is(public.superadmin_access_profile_model_create(gen_random_uuid(),
    '{"domain":"platform","name":"Denied","capabilities":[],"reason":"Denied"}'::jsonb)
    #>>'{error,code}','SAI_AUTH_REQUIRED','anonymous auth context receives a stable envelope');
reset role;

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data)
values('97000000-0000-4000-8000-000000000001','authenticated','authenticated',
  'model-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values('97100000-0000-4000-8000-000000000001','97000000-0000-4000-8000-000000000001',
  now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id)
values('97200000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
values('97300000-0000-4000-8000-000000000001','97200000-0000-4000-8000-000000000001',
  '97000000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind)
select '97400000-0000-4000-8000-000000000001',
  '97200000-0000-4000-8000-000000000001',id,'platform'
from public.platform_roles where code='owner';
create temporary table model_results(key text primary key,result jsonb not null);
grant select,insert on model_results to authenticated;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','97000000-0000-4000-8000-000000000001',
  'session_id','97100000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select is(public.superadmin_access_profile_model_create(gen_random_uuid(),
    '{"domain":"platform","name":"Needs MFA","capabilities":[],"reason":"MFA"}'::jsonb)
    #>>'{error,code}','SAI_MFA_REQUIRED','model mutations require AAL2');
reset role;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','97000000-0000-4000-8000-000000000001',
  'session_id','97100000-0000-4000-8000-000000000001',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into model_results values('created',public.superadmin_access_profile_model_create(
  '97500000-0000-4000-8000-000000000001',jsonb_build_object(
    'domain','platform','name','Operação regional','max_scope_kind','institution',
    'capabilities',jsonb_build_array(jsonb_build_object('code','platform.read','effect','allow')),
    'reason','Teste de criação.')));
select is((select result#>>'{data,model,status}' from model_results where key='created'),
  'active','creation succeeds inside the v2 envelope');
reset role;
select is((select created_by_internal_identity_id::text from public.access_profile_templates
    where id=(select (result#>>'{data,model_id}')::uuid from model_results where key='created')),
  '97200000-0000-4000-8000-000000000001','creation records the internal actor');
set local role authenticated;
select is(public.superadmin_access_profile_model_create(
  '97500000-0000-4000-8000-000000000001',jsonb_build_object(
    'domain','platform','name','Operação regional','max_scope_kind','institution',
    'capabilities',jsonb_build_array(jsonb_build_object('code','platform.read','effect','allow')),
    'reason','Teste de criação.'))#>>'{data,replayed}','true','idempotent replay is actor-bound');
select is(public.superadmin_access_profile_model_update(gen_random_uuid(),jsonb_build_object(
    'id',(select result#>>'{data,model_id}' from model_results where key='created'),
    'name','Stale','expected_version',0,'capabilities','[]'::jsonb,'reason','Stale'))
    #>>'{error,code}','SAI_CONCURRENT_CHANGE','stale writes return the conflict envelope');
select is(public.superadmin_access_profile_models_import_preview('platform',
    jsonb_build_array(jsonb_build_object('name','Unsafe','institution_id',gen_random_uuid(),
      'capabilities','[]'::jsonb)))#>>'{data,rows,0,error_code}',
  'mass_assignment_field','import rejects assignment fields');
select is(public.superadmin_access_profile_models_cursor(
    repeat('x',121),'platform',null,null,25,null,null)#>>'{error,code}',
  'SAI_INVALID_ARGUMENT','oversized search input fails closed');
select ok((public.superadmin_access_permission_catalog()->>'ok')::boolean,
  'catalog uses the success envelope');
select ok(public.superadmin_access_profile_models_export('platform')#>>'{data,csv}'
    like 'format_version,domain,name,description,max_scope_kind,status,capabilities%',
  'export returns the versioned CSV contract');
reset role;

select ok(exists(select 1 from audit.audit_logs
  where actor_kind='superadmin_internal'
    and actor_internal_identity_id='97200000-0000-4000-8000-000000000001'
    and actor_person_id is null and outcome='success'
    and permission_code like '%.role_models.%'),
  'successful operations are audited against the internal actor');

select * from finish();
rollback;
