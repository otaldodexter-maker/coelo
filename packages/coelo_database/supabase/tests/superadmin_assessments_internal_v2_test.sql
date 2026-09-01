begin;
create extension if not exists pgtap with schema extensions;
select plan(47);

select has_table('public','activity_assessment_configurations','assessment configurations exist');
select has_table('public','assessment_instruments','assessment instruments exist');
select has_table('public','assessment_categories','assessment categories exist');
select has_table('public','assessment_competencies','assessment competencies exist');
select has_table('public','assessment_scale_concepts','assessment concepts exist');
select has_table('public','assessment_periods','assessment periods exist');
select has_table('public','assessment_gradebooks','assessment gradebooks exist');
select has_table('app_private','superadmin_internal_assessment_command_receipts','private receipts exist');
select has_table('app_private','superadmin_internal_assessment_events','private events exist');

select ok((select c.relrowsecurity and c.relforcerowsecurity from pg_class c
  where c.oid='public.activity_assessment_configurations'::regclass),'configuration RLS is enabled and forced');
select ok((select c.relrowsecurity and c.relforcerowsecurity from pg_class c
  where c.oid='public.assessment_gradebooks'::regclass),'gradebook RLS is enabled and forced');
select ok((select c.relrowsecurity and c.relforcerowsecurity from pg_class c
  where c.oid='public.assessment_periods'::regclass),'period RLS is enabled and forced');
select ok((select c.relrowsecurity and c.relforcerowsecurity from pg_class c
  where c.oid='app_private.superadmin_internal_assessment_command_receipts'::regclass),'receipt RLS is enabled and forced');
select ok((select c.relrowsecurity and c.relforcerowsecurity from pg_class c
  where c.oid='app_private.superadmin_internal_assessment_events'::regclass),'event RLS is enabled and forced');
select table_privs_are('public','assessment_gradebooks','authenticated',array[]::text[],'authenticated cannot access gradebooks directly');
select table_privs_are('app_private','superadmin_internal_assessment_command_receipts','authenticated',array[]::text[],'authenticated cannot access receipts directly');

select has_function('public','superadmin_assessment_context_options',array[]::text[],'context options RPC exists');
select has_function('public','superadmin_assessment_configuration_read',array['uuid','uuid'],'configuration read RPC exists');
select has_function('public','superadmin_assessment_gradebook_read',array['uuid'],'gradebook read RPC exists');
select has_function('public','superadmin_assessment_closing_queue',array[]::text[],'closing queue RPC exists');
select has_function('public','superadmin_assessment_save_configuration',array['uuid','uuid','bigint','jsonb'],'configuration save RPC exists');
select has_function('public','superadmin_assessment_activate_configuration',array['uuid','uuid','bigint'],'configuration activate RPC exists');
select has_function('public','superadmin_assessment_save_gradebook',array['uuid','uuid','bigint','jsonb','text'],'gradebook save RPC exists');
select has_function('public','superadmin_assessment_submit_gradebook',array['uuid','uuid','bigint','text'],'gradebook submit RPC exists');
select has_function('public','superadmin_assessment_review_gradebook',array['uuid','uuid','bigint','text'],'gradebook review RPC exists');
select has_function('public','superadmin_assessment_return_gradebook',array['uuid','uuid','bigint','text'],'gradebook return RPC exists');
select has_function('public','superadmin_assessment_publish_gradebook',array['uuid','uuid','bigint','text'],'gradebook publish RPC exists');
select has_function('public','superadmin_assessment_schedule_publication',array['uuid','uuid','bigint','timestamp with time zone','text'],'publication schedule RPC exists');

select function_privs_are('public','superadmin_assessment_context_options',array[]::text[],
  'authenticated',array['EXECUTE'],'authenticated only executes read gateway');
select function_privs_are('public','superadmin_assessment_save_configuration',array['uuid','uuid','bigint','jsonb'],
  'authenticated',array['EXECUTE'],'authenticated only executes mutation gateway');
select function_privs_are('public','superadmin_assessment_save_configuration',array['uuid','uuid','bigint','jsonb'],
  'anon',array[]::text[],'anonymous cannot execute mutation gateway');
select ok(pg_get_functiondef('app_private.assessment_v2_require_context(text,uuid)'::regprocedure)
  like '%require_superadmin_internal_context(p_permission_code)%'
  and pg_get_functiondef('app_private.assessment_v2_require_context(text,uuid)'::regprocedure)
    not like '%current_person_id%','assessment gateway uses only internal identity');
select results_eq($$select count(*)::bigint from public.platform_permissions
  where code like 'assessments.%'$$,array[0::bigint],
  'assessment v2 adds no unapproved role capabilities');

-- Synthetic tenant and identity fixtures. Everything rolls back.
insert into public.institution_types(id,code,name,status) values
 ('8d200000-0000-4000-8000-000000000001','assessment-v2','Assessment v2','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('8d200000-0000-4000-8000-000000000010','Assessment Tenant A','assessment-v2-a','active','8d200000-0000-4000-8000-000000000001'),
 ('8d200000-0000-4000-8000-000000000020','Assessment Tenant B','assessment-v2-b','active','8d200000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,institution_type_id,name,slug,status) values
 ('8d200000-0000-4000-8000-000000000011','8d200000-0000-4000-8000-000000000010','8d200000-0000-4000-8000-000000000001','Unidade A','assessment-v2-a-unit','active'),
 ('8d200000-0000-4000-8000-000000000021','8d200000-0000-4000-8000-000000000020','8d200000-0000-4000-8000-000000000001','Unidade B','assessment-v2-b-unit','active');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('8d200000-0000-4000-8000-000000000601','adult','Fixture','Creator','Fixture Creator','active'),
 ('8d200000-0000-4000-8000-000000000602','adult','People','Only','People Only','active');
insert into public.activity_definitions(
 id,institution_id,name,origin_scope_kind,created_by_person_id,status,handle_stem) values
 ('8d200000-0000-4000-8000-000000000701','8d200000-0000-4000-8000-000000000010','Activity A','institution','8d200000-0000-4000-8000-000000000601','active','assessment-activity-a'),
 ('8d200000-0000-4000-8000-000000000702','8d200000-0000-4000-8000-000000000020','Activity B','institution','8d200000-0000-4000-8000-000000000601','active','assessment-activity-b');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('8d200000-0000-4000-8000-000000000101','authenticated','authenticated','assessment-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('8d200000-0000-4000-8000-000000000102','authenticated','authenticated','assessment-scoped@invalid.test',now(),now(),now(),'{}','{}'),
 ('8d200000-0000-4000-8000-000000000103','authenticated','authenticated','assessment-people@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('8d200000-0000-4000-8000-000000000201','8d200000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('8d200000-0000-4000-8000-000000000202','8d200000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour'),
 ('8d200000-0000-4000-8000-000000000203','8d200000-0000-4000-8000-000000000103',now(),now(),'aal2',now()+interval '1 hour'),
 ('8d200000-0000-4000-8000-000000000209','8d200000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('8d200000-0000-4000-8000-000000000301'),('8d200000-0000-4000-8000-000000000302');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('8d200000-0000-4000-8000-000000000401','8d200000-0000-4000-8000-000000000301','8d200000-0000-4000-8000-000000000101'),
 ('8d200000-0000-4000-8000-000000000402','8d200000-0000-4000-8000-000000000302','8d200000-0000-4000-8000-000000000102');
insert into app_private.superadmin_internal_memberships(
 id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,
 fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('8d200000-0000-4000-8000-000000000501'::uuid,'8d200000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('8d200000-0000-4000-8000-000000000502'::uuid,'8d200000-0000-4000-8000-000000000302'::uuid,'owner','institution','8d200000-0000-4000-8000-000000000010'::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('8d200000-0000-4000-8000-000000000602','8d200000-0000-4000-8000-000000000103','active');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='owner' and permission_record.code in('activities.read','activities.manage')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8d200000-0000-4000-8000-000000000101','session_id','8d200000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);
create temporary table assessment_context_result as
 select public.superadmin_assessment_context_options() body;
select ok((select body->>'ok'='true' from assessment_context_result),
 'AAL2 internal Owner can read assessment context');
select ok((select jsonb_typeof(body#>'{data,assignments}')='array'
  and jsonb_typeof(body#>'{data,periods}')='array' from assessment_context_result),
 'context response uses the stable v2 envelope and collections');

create temporary table assessment_save_result as
select public.superadmin_assessment_save_configuration(
 '8d200000-0000-4000-8000-000000000801',null,0,
 jsonb_build_object(
  'activity_id','8d200000-0000-4000-8000-000000000701',
  'institution_id','8d200000-0000-4000-8000-000000000010',
  'unit_id','8d200000-0000-4000-8000-000000000011',
  'periodicity','bimonthly','result_scale_kind','numeric_0_10',
  'scale_options',jsonb_build_object('step',0.5),'concepts','[]'::jsonb,
  'allow_final_override',false,
  'instruments',jsonb_build_array(jsonb_build_object('name','Prova','weight',100,'sort_order',0)),
  'categories','[]'::jsonb,
  'periods',jsonb_build_array(jsonb_build_object(
    'name','1º período','ordinal',1,'academic_year',2027,
    'starts_on','2027-01-01','ends_on','2027-03-31',
    'entry_closes_at','2027-04-01T12:00:00Z','family_release_at','2027-04-02T12:00:00Z',
    'timezone','America/Sao_Paulo')))) body;
select ok((select body->>'ok'='true' and body#>>'{data,status}'='draft'
  from assessment_save_result),'authorized configuration save succeeds');
select results_eq($$select count(*)::bigint from public.activity_assessment_configurations
  where institution_id='8d200000-0000-4000-8000-000000000010'$$,
  array[1::bigint],'configuration persists once');
select ok((select receipt.internal_identity_id='8d200000-0000-4000-8000-000000000301'
  from app_private.superadmin_internal_assessment_command_receipts receipt
  where receipt.request_id='8d200000-0000-4000-8000-000000000801'),
  'receipt attributes command to internal identity');
select ok((select audit_record.actor_kind='superadmin_internal'
  and audit_record.actor_internal_identity_id='8d200000-0000-4000-8000-000000000301'
  and audit_record.actor_person_id is null
  and not (audit_record.after_json ? 'payload')
  from audit.audit_logs audit_record
  join app_private.superadmin_internal_assessment_command_receipts receipt
    on receipt.correlation_id=audit_record.correlation_id
  where receipt.request_id='8d200000-0000-4000-8000-000000000801'),
  'audit is internal, minimized and never fabricates a person');
select ok((select (public.superadmin_assessment_save_configuration(
 '8d200000-0000-4000-8000-000000000801',null,0,
 jsonb_build_object(
  'activity_id','8d200000-0000-4000-8000-000000000701',
  'institution_id','8d200000-0000-4000-8000-000000000010',
  'unit_id','8d200000-0000-4000-8000-000000000011',
  'periodicity','bimonthly','result_scale_kind','numeric_0_10',
  'scale_options',jsonb_build_object('step',0.5),'concepts','[]'::jsonb,
  'allow_final_override',false,
  'instruments',jsonb_build_array(jsonb_build_object('name','Prova','weight',100,'sort_order',0)),
  'categories','[]'::jsonb,
  'periods',jsonb_build_array(jsonb_build_object(
    'name','1º período','ordinal',1,'academic_year',2027,
    'starts_on','2027-01-01','ends_on','2027-03-31',
    'entry_closes_at','2027-04-01T12:00:00Z','family_release_at','2027-04-02T12:00:00Z',
    'timezone','America/Sao_Paulo'))))#>>'{data,replayed}')::boolean),
  'same request and payload replays');
select results_eq($$select count(*)::bigint from public.activity_assessment_configurations
  where institution_id='8d200000-0000-4000-8000-000000000010'$$,
  array[1::bigint],'replay does not duplicate configuration');
select ok((select public.superadmin_assessment_save_configuration(
 '8d200000-0000-4000-8000-000000000801',null,0,
 jsonb_build_object('different',true))#>>'{error,code}')='ASSESSMENT_INVALID_INPUT',
 'same request with a different payload is rejected');

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8d200000-0000-4000-8000-000000000102','session_id','8d200000-0000-4000-8000-000000000202',
 'aal','aal2','role','authenticated')::text,true);
select ok((select public.superadmin_assessment_save_configuration(
 '8d200000-0000-4000-8000-000000000802',null,0,
 jsonb_build_object(
  'activity_id','8d200000-0000-4000-8000-000000000702',
  'institution_id','8d200000-0000-4000-8000-000000000020',
  'unit_id','8d200000-0000-4000-8000-000000000021',
  'periodicity','bimonthly','result_scale_kind','numeric_0_10',
  'scale_options','{}'::jsonb,'concepts','[]'::jsonb,'allow_final_override',false,
  'instruments',jsonb_build_array(jsonb_build_object('name','Prova','weight',100,'sort_order',0)),
  'categories','[]'::jsonb,
  'periods',jsonb_build_array(jsonb_build_object('name','1º período','ordinal',1,
    'academic_year',2027,'starts_on','2027-01-01','ends_on','2027-03-31',
    'entry_closes_at','2027-04-01T12:00:00Z','family_release_at','2027-04-02T12:00:00Z')))
 )#>>'{error,code}')='SAI_PERMISSION_DENIED','institution-scoped actor is denied cross-tenant');

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8d200000-0000-4000-8000-000000000101','session_id','8d200000-0000-4000-8000-000000000209',
 'aal','aal1','role','authenticated')::text,true);
select ok((select public.superadmin_assessment_context_options()#>>'{error,code}')='SAI_MFA_REQUIRED',
 'Owner AAL1 is denied');

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8d200000-0000-4000-8000-000000000103','session_id','8d200000-0000-4000-8000-000000000203',
 'aal','aal2','role','authenticated')::text,true);
select ok((select public.superadmin_assessment_context_options()#>>'{error,code}')='SAI_INTERNAL_CONTEXT_DENIED',
 'people-only credential cannot enter internal assessment realm');

update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now()
where id='8d200000-0000-4000-8000-000000000502';
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8d200000-0000-4000-8000-000000000102','session_id','8d200000-0000-4000-8000-000000000202',
 'aal','aal2','role','authenticated')::text,true);
select ok((select public.superadmin_assessment_context_options()#>>'{error,code}')='SAI_MEMBERSHIP_REVOKED',
 'revoked internal membership is denied immediately');

select set_config('request.jwt.claims','{}',true);
set local role anon;
select throws_ok($$select public.superadmin_assessment_context_options()$$,
  '42501',null,'anonymous role has no RPC execute grant');
reset role;

select * from finish();
rollback;
