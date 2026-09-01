begin;

create extension if not exists pgtap with schema extensions;

select plan(35);

select has_column('public','platform_permissions','application_code',
  'platform permissions identify the Superadmin application');
select has_column('public','institution_permissions','application_code',
  'institution permissions identify the Admin application');
select has_column('public','guardian_permission_capabilities','application_code',
  'guardian capabilities identify the Principal application');

select results_eq(
  $$select count(*)::bigint from public.platform_permissions
    where screen_code='access_profile_models'
      and action_code in ('read','create','update','delete','import','export')
      and status='active'$$,
  array[18::bigint],
  'six real model actions exist for each of the three application domains'
);

select results_eq(
  $$select count(*)::bigint
    from public.platform_role_permissions grant_record
    join public.platform_roles role_record on role_record.id=grant_record.role_id
    join public.platform_permissions permission_record on permission_record.id=grant_record.permission_id
    where permission_record.screen_code='access_profile_models'
      and grant_record.status='active' and grant_record.revoked_at is null
      and role_record.code<>'owner'$$,
  array[0::bigint],
  'new model actions are granted only to Owner by default'
);

select has_function('public','superadmin_access_profile_model_detail',array['uuid'],
  'model detail RPC exists');
select has_function('public','superadmin_access_profile_model_create',array['uuid','jsonb'],
  'model create RPC exists');
select has_function('public','superadmin_access_profile_model_update',array['uuid','jsonb'],
  'model update RPC exists');
select has_function('public','superadmin_access_profile_model_delete',array['uuid','uuid','bigint','text'],
  'model delete RPC exists');
select has_function('public','superadmin_access_profile_model_duplicate',array['uuid','jsonb'],
  'model duplicate RPC exists');
select has_function('public','superadmin_access_profile_models_export',array['text'],
  'model export RPC exists');
select has_function('public','superadmin_access_profile_models_import_preview',array['text','jsonb'],
  'model import preview RPC exists');
select has_function('public','superadmin_access_profile_models_import_confirm',array['uuid','text','jsonb','text'],
  'model import confirmation RPC exists');
select has_function('public','superadmin_access_permission_catalog',array[]::text[],
  'cross-application action catalog RPC exists');

select ok(
  lower(pg_catalog.pg_get_functiondef(
    'app_private.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)'::regprocedure
  )) like '%access_profile_require_model_action%read%',
  'the existing model list is now authorized by the explicit read action'
);

select is(
  (select count(*)::bigint from pg_catalog.pg_class table_record
    where table_record.oid in (
      'public.access_profile_templates'::regclass,
      'public.access_profile_template_platform_permissions'::regclass,
      'public.access_profile_template_institution_permissions'::regclass,
      'public.access_profile_template_principal_capabilities'::regclass
    ) and table_record.relrowsecurity and table_record.relforcerowsecurity),
  4::bigint,
  'all model tables preserve enabled and forced RLS'
);

select is(
  (select count(*)::bigint
    from (values
      ('public.access_profile_templates'::regclass),
      ('public.access_profile_template_platform_permissions'::regclass),
      ('public.access_profile_template_institution_permissions'::regclass),
      ('public.access_profile_template_principal_capabilities'::regclass)
    ) table_record(table_oid)
    where has_table_privilege('authenticated',table_record.table_oid,'SELECT,INSERT,UPDATE,DELETE')),
  0::bigint,
  'authenticated clients have no direct CRUD grant on model tables'
);

select is(
  (select count(*)::bigint
    from (values
      ('app_private.access_profile_require_model_action(text,text,boolean)'::regprocedure),
      ('app_private.access_profile_model_detail(uuid,boolean)'::regprocedure),
      ('app_private.access_profile_model_create_internal(uuid,jsonb)'::regprocedure),
      ('app_private.superadmin_access_profile_model_create(uuid,jsonb)'::regprocedure),
      ('app_private.superadmin_access_profile_model_update(uuid,jsonb)'::regprocedure),
      ('app_private.superadmin_access_profile_model_delete(uuid,uuid,bigint,text)'::regprocedure),
      ('app_private.superadmin_access_profile_model_duplicate(uuid,jsonb)'::regprocedure),
      ('app_private.superadmin_access_profile_models_export(text)'::regprocedure),
      ('app_private.superadmin_access_profile_models_import_preview(text,jsonb)'::regprocedure),
      ('app_private.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text)'::regprocedure),
      ('app_private.superadmin_access_permission_catalog()'::regprocedure)
    ) function_record(function_oid)
    where has_function_privilege('authenticated',function_record.function_oid,'EXECUTE')),
  0::bigint,
  'authenticated clients cannot execute private model helpers'
);

select is(
  (select count(*)::bigint
    from (values
      ('public.superadmin_access_profile_model_detail(uuid)'::regprocedure),
      ('public.superadmin_access_profile_model_create(uuid,jsonb)'::regprocedure),
      ('public.superadmin_access_profile_model_update(uuid,jsonb)'::regprocedure),
      ('public.superadmin_access_profile_model_delete(uuid,uuid,bigint,text)'::regprocedure),
      ('public.superadmin_access_profile_model_duplicate(uuid,jsonb)'::regprocedure),
      ('public.superadmin_access_profile_models_export(text)'::regprocedure),
      ('public.superadmin_access_profile_models_import_preview(text,jsonb)'::regprocedure),
      ('public.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text)'::regprocedure),
      ('public.superadmin_access_permission_catalog()'::regprocedure)
    ) function_record(function_oid)
    where has_function_privilege('anon',function_record.function_oid,'EXECUTE')),
  0::bigint,
  'anonymous callers cannot execute model gateways'
);

select is(
  (select count(*)::bigint from pg_catalog.pg_proc procedure
    where procedure.oid in (
      'public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)'::regprocedure,
      'public.superadmin_access_profile_model_detail(uuid)'::regprocedure,
      'public.superadmin_access_profile_model_create(uuid,jsonb)'::regprocedure,
      'public.superadmin_access_profile_model_update(uuid,jsonb)'::regprocedure,
      'public.superadmin_access_profile_model_delete(uuid,uuid,bigint,text)'::regprocedure,
      'public.superadmin_access_profile_model_duplicate(uuid,jsonb)'::regprocedure,
      'public.superadmin_access_profile_models_export(text)'::regprocedure,
      'public.superadmin_access_profile_models_import_preview(text,jsonb)'::regprocedure,
      'public.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text)'::regprocedure,
      'public.superadmin_access_permission_catalog()'::regprocedure
    ) and procedure.prosecdef
      and procedure.proconfig @> array['search_path=']),
  10::bigint,
  'public gateways are SECURITY DEFINER with an empty search path and backend authorization'
);

set local role authenticated;
select throws_ok(
  $$select public.superadmin_access_profile_model_create(gen_random_uuid(),
      '{"domain":"platform","name":"Denied model","capabilities":[]}'::jsonb)$$,
  '42501','access model permission required',
  'an unmapped authenticated subject is denied before model creation'
);
reset role;

insert into auth.users(id,aud,role,email,created_at,updated_at)
values('97000000-0000-4000-8000-000000000001','authenticated','authenticated',
  'access-model-owner@test.invalid',now(),now());
insert into public.people(id,person_type,first_name,last_name,display_name,status)
values('97100000-0000-4000-8000-000000000001','adult','Access','Model Owner',
  'Access Model Owner','active');
insert into public.person_auth_links(person_id,auth_user_id,status)
values('97100000-0000-4000-8000-000000000001',
  '97000000-0000-4000-8000-000000000001','active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select '97100000-0000-4000-8000-000000000001',id,'active','platform',true
from public.platform_roles where code='owner';

create temporary table access_model_results(
  key text primary key,
  result jsonb not null
);
grant select,insert,update on access_model_results to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','97000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims',
  '{"sub":"97000000-0000-4000-8000-000000000001","aal":"aal2","role":"authenticated"}',true);

insert into access_model_results(key,result)
select 'created',public.superadmin_access_profile_model_create(
  '97200000-0000-4000-8000-000000000001',
  jsonb_build_object('domain','platform','name','Operação regional',
    'description','Modelo regional coerente.','max_scope_kind','institution',
    'capabilities',jsonb_build_array(jsonb_build_object('code','platform.read','effect','allow')),
    'reason','Teste de criação do modelo.')
);

select is((select result#>>'{model,status}' from access_model_results where key='created'),
  'active','custom model creation persists an active model');
select is((select (result#>>'{model,is_system}')::boolean from access_model_results where key='created'),
  false,'custom model creation never accepts a system flag');
select is((select (result#>>'{model,capability_count}')::integer from access_model_results where key='created'),
  1,'custom model creation persists the selected capability snapshot');

select throws_ok(
  format($sql$select public.superadmin_access_profile_model_update(
      '97200000-0000-4000-8000-000000000002',
      jsonb_build_object('id',%L,'name','Stale model','expected_version',0,
        'capabilities','[]'::jsonb,'reason','Stale update'))$sql$,
    (select result->>'model_id' from access_model_results where key='created')),
  '40001','stale access model version',
  'optimistic concurrency rejects a stale model update'
);

insert into access_model_results(key,result)
select 'updated',public.superadmin_access_profile_model_update(
  '97200000-0000-4000-8000-000000000003',
  jsonb_build_object('id',(select result->>'model_id' from access_model_results where key='created'),
    'name','Operação regional revisada','description','Modelo revisado.',
    'expected_version',1,'max_scope_kind','institution',
    'capabilities',jsonb_build_array(jsonb_build_object('code','platform.read','effect','allow')),
    'reason','Teste de edição do modelo.')
);
select is((select (result->>'version')::bigint from access_model_results where key='updated'),
  2::bigint,'model update increments the optimistic version');

select throws_ok(
  $$select public.superadmin_access_profile_model_delete(gen_random_uuid(),
      (select id from public.access_profile_templates where code='platform-owner'),1,'Denied')$$,
  '42501','system access model is protected',
  'system models cannot be deleted'
);

insert into access_model_results(key,result)
select 'duplicated',public.superadmin_access_profile_model_duplicate(
  '97200000-0000-4000-8000-000000000004',
  jsonb_build_object('source_model_id',(select result->>'model_id' from access_model_results where key='created'),
    'name','Cópia regional','reason','Teste de duplicação do modelo.')
);
select is((select result#>>'{model,status}' from access_model_results where key='duplicated'),
  'inactive','a duplicated model starts inactive for explicit review');

insert into access_model_results(key,result)
select 'bad_preview',public.superadmin_access_profile_models_import_preview(
  'platform',jsonb_build_array(jsonb_build_object('name','Imported unsafe',
    'institution_id','97300000-0000-4000-8000-000000000001','capabilities','[]'::jsonb))
);
select is((select result->>'error_count' from access_model_results where key='bad_preview'),
  '1','model import preview rejects assignment and tenant fields');
select is((select result#>>'{rows,0,error_code}' from access_model_results where key='bad_preview'),
  'mass_assignment_field','model import reports a stable mass-assignment error');

insert into access_model_results(key,result)
select 'imported',public.superadmin_access_profile_models_import_confirm(
  '97200000-0000-4000-8000-000000000005','platform',
  jsonb_build_array(jsonb_build_object('name','Modelo importado coerente',
    'description','Criado por importação validada.','max_scope_kind','platform',
    'capabilities',jsonb_build_array(jsonb_build_object('code','platform.read','effect','allow')))),
  'Teste de importação de modelos.');
select is((select (result->>'created_count')::integer from access_model_results where key='imported'),
  1,'model import confirmation creates every validated row');
select is((select model.status::text from public.access_profile_templates model
    where model.id=(select (result#>>'{models,0,id}')::uuid from access_model_results where key='imported')),
  'inactive','imported models remain inactive until explicit review');

insert into access_model_results(key,result)
select 'catalog',public.superadmin_access_permission_catalog();
select results_eq(
  $$select distinct item->>'application_code'
    from access_model_results result_record,
      lateral jsonb_array_elements(result_record.result->'items') item
    where result_record.key='catalog' order by 1$$,
  array['admin'::text,'principal'::text,'superadmin'::text],
  'the action catalog returns all three approved applications explicitly'
);

insert into access_model_results(key,result)
select 'exported',public.superadmin_access_profile_models_export('platform');
select like((select result->>'csv' from access_model_results where key='exported'),
  'format_version,domain,name,description,max_scope_kind,status,capabilities%',
  'model export returns the versioned CSV contract');

insert into access_model_results(key,result)
select 'deleted',public.superadmin_access_profile_model_delete(
  '97200000-0000-4000-8000-000000000006',
  (select (result->>'model_id')::uuid from access_model_results where key='created'),
  2,'Teste de inativação do modelo.'
);
select is((select result->>'status' from access_model_results where key='deleted'),
  'inactive','model deletion is a recoverable soft inactivation');

reset role;

select * from finish();
rollback;
