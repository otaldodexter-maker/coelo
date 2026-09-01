begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

select has_column('public','activity_templates','unit_id','templates expose unit scope');
select col_type_is('public','activity_templates','unit_id','uuid','unit scope uses uuid');
select has_fk('public','activity_templates','activity_templates_unit_institution_fkey','unit hierarchy has a composite FK');
select has_check('public','activity_templates','activity_templates_scope_kind_check','scope values are constrained');
select has_check('public','activity_templates','activity_templates_scope_hierarchy_check','scope hierarchy is constrained');
select has_index('public','activity_templates','activity_templates_unit_status_name_idx','unit lookup is indexed');
select has_table('app_private','superadmin_internal_activity_template_create_receipts','internal receipts are private');
select ok((select c.relrowsecurity and c.relforcerowsecurity from pg_class c where c.oid='app_private.superadmin_internal_activity_template_create_receipts'::regclass),'receipt RLS is enabled and forced');
select table_privs_are('app_private','superadmin_internal_activity_template_create_receipts','authenticated',array[]::text[],'authenticated has no receipt privileges');
select table_privs_are('public','activity_templates','authenticated',array['SELECT'],'authenticated cannot mutate templates directly');
select has_function('public','superadmin_create_scoped_activity_template',array['uuid','uuid','text','text','uuid','text','uuid'],'scoped command exists');
select function_privs_are('public','superadmin_create_scoped_activity_template',array['uuid','uuid','text','text','uuid','text','uuid'],'authenticated',array['EXECUTE'],'authenticated only executes the gateway');
select function_privs_are('public','superadmin_create_scoped_activity_template',array['uuid','uuid','text','text','uuid','text','uuid'],'anon',array[]::text[],'anon cannot execute the gateway');
select ok(
  pg_get_functiondef('app_private.superadmin_create_scoped_activity_template(uuid,uuid,text,text,uuid,text,uuid)'::regprocedure) like '%require_superadmin_internal_context(''activities.templates.manage'')%'
  and pg_get_functiondef('app_private.superadmin_create_scoped_activity_template(uuid,uuid,text,text,uuid,text,uuid)'::regprocedure) not like '%current_person_id()%'
  and pg_get_functiondef('app_private.superadmin_create_scoped_activity_template(uuid,uuid,text,text,uuid,text,uuid)'::regprocedure) not like '%has_platform_permission(%',
  'command uses only the canonical internal realm');
select ok(
  pg_get_functiondef('app_private.superadmin_activity_template_options(uuid)'::regprocedure) like '%require_superadmin_internal_context(''activities.read'')%'
  and pg_get_functiondef('app_private.superadmin_activity_template_options(uuid)'::regprocedure) like '%ctx.scope_institution_id is distinct from p_institution_id%'
  and pg_get_functiondef('app_private.superadmin_activity_template_options(uuid)'::regprocedure) like '%''unit_id'',template.unit_id%',
  'options revalidate internal scope and include unit targets');

-- Real synthetic internal-realm fixtures. Everything rolls back.
insert into public.institution_types(id,code,name,status) values
 ('8c100000-0000-4000-8000-000000000001','template-unit-scope','Template unit scope','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('8c100000-0000-4000-8000-000000000010','Template Tenant A','template-unit-scope-a','active','8c100000-0000-4000-8000-000000000001'),
 ('8c100000-0000-4000-8000-000000000020','Template Tenant B','template-unit-scope-b','active','8c100000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,institution_type_id,name,slug,status) values
 ('8c100000-0000-4000-8000-000000000011','8c100000-0000-4000-8000-000000000010','8c100000-0000-4000-8000-000000000001','Unidade A','template-unit-scope-a-unit','active'),
 ('8c100000-0000-4000-8000-000000000021','8c100000-0000-4000-8000-000000000020','8c100000-0000-4000-8000-000000000001','Unidade B','template-unit-scope-b-unit','active');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('8c100000-0000-4000-8000-000000000101','authenticated','authenticated','template-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('8c100000-0000-4000-8000-000000000102','authenticated','authenticated','template-scoped@invalid.test',now(),now(),now(),'{}','{}'),
 ('8c100000-0000-4000-8000-000000000103','authenticated','authenticated','template-people-only@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('8c100000-0000-4000-8000-000000000201','8c100000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('8c100000-0000-4000-8000-000000000202','8c100000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour'),
 ('8c100000-0000-4000-8000-000000000203','8c100000-0000-4000-8000-000000000103',now(),now(),'aal2',now()+interval '1 hour'),
 ('8c100000-0000-4000-8000-000000000209','8c100000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('8c100000-0000-4000-8000-000000000301'),('8c100000-0000-4000-8000-000000000302');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('8c100000-0000-4000-8000-000000000401','8c100000-0000-4000-8000-000000000301','8c100000-0000-4000-8000-000000000101'),
 ('8c100000-0000-4000-8000-000000000402','8c100000-0000-4000-8000-000000000302','8c100000-0000-4000-8000-000000000102');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('8c100000-0000-4000-8000-000000000501'::uuid,'8c100000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('8c100000-0000-4000-8000-000000000502'::uuid,'8c100000-0000-4000-8000-000000000302'::uuid,'owner','institution','8c100000-0000-4000-8000-000000000010'::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('8c100000-0000-4000-8000-000000000601','adult','People','Only','People Only','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('8c100000-0000-4000-8000-000000000601','8c100000-0000-4000-8000-000000000103','active');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='owner' and permission_record.code in('activities.read','activities.templates.manage')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8c100000-0000-4000-8000-000000000101','session_id','8c100000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);
select lives_ok($call$
 create temporary table created_template as
 select public.superadmin_create_scoped_activity_template(
  '8c100000-0000-4000-8000-000000000010','8c100000-0000-4000-8000-000000000011',
  '  Robótica da unidade  ','  Modelo sintético.  ',
  (select id from public.activity_taxonomies where code='robotica' and taxonomy_kind='subtype' and status='active' limit 1),
  'mandatory','8c100000-0000-4000-8000-000000000801') body
 $call$,'authorized AAL2 internal Owner creates a unit template');
select ok((select body->>'scope_kind'='unit'
 and body->>'institution_id'='8c100000-0000-4000-8000-000000000010'
 and body->>'unit_id'='8c100000-0000-4000-8000-000000000011'
 and body->>'name'='Robótica da unidade' from created_template),'command returns normalized unit scope');
select results_eq($$select count(*)::bigint from public.activity_templates
 where institution_id='8c100000-0000-4000-8000-000000000010'
 and unit_id='8c100000-0000-4000-8000-000000000011'
 and scope_kind='unit' and name='Robótica da unidade'$$,array[1::bigint],'unit template persists once');
select ok((select receipt.internal_identity_id='8c100000-0000-4000-8000-000000000301'
 and audit_record.actor_kind='superadmin_internal'
 and audit_record.actor_internal_identity_id=receipt.internal_identity_id
 and audit_record.actor_person_id is null
 and not(audit_record.after_json?'name') and not(audit_record.after_json?'description')
 from app_private.superadmin_internal_activity_template_create_receipts receipt
 join audit.audit_logs audit_record on audit_record.correlation_id=receipt.correlation_id
 where receipt.request_id='8c100000-0000-4000-8000-000000000801'),
 'receipt and audit preserve internal attribution without template text');
select results_eq($$select public.superadmin_create_scoped_activity_template(
 '8c100000-0000-4000-8000-000000000010','8c100000-0000-4000-8000-000000000011',
 'Robótica da unidade','Modelo sintético.',
 (select id from public.activity_taxonomies where code='robotica' and taxonomy_kind='subtype' and status='active' limit 1),
 'mandatory','8c100000-0000-4000-8000-000000000801')->>'id'$$,
 $$select body->>'id' from created_template$$,'same request returns the same template id');
select results_eq($$select count(*)::bigint from public.activity_templates
 where institution_id='8c100000-0000-4000-8000-000000000010' and name='Robótica da unidade'$$,
 array[1::bigint],'replay does not duplicate the template');
select throws_ok($call$select public.superadmin_create_scoped_activity_template(
 '8c100000-0000-4000-8000-000000000010','8c100000-0000-4000-8000-000000000011',
 'Payload divergente','Modelo sintético.',
 (select id from public.activity_taxonomies where code='robotica' and taxonomy_kind='subtype' and status='active' limit 1),
 'mandatory','8c100000-0000-4000-8000-000000000801')$call$,
 '22023','idempotency key reused','different replay payload is rejected');
select throws_ok($call$select public.superadmin_create_scoped_activity_template(
 '8c100000-0000-4000-8000-000000000010','8c100000-0000-4000-8000-000000000021',
 'Unidade cruzada','',(select id from public.activity_taxonomies where code='robotica' and taxonomy_kind='subtype' and status='active' limit 1),
 'optional','8c100000-0000-4000-8000-000000000802')$call$,
 '22023','invalid activity template request','cross-institution unit id is rejected');
select throws_ok($call$select public.superadmin_create_scoped_activity_template(
 '8c100000-0000-4000-8000-000000000010',null,'Sem governança','',
 (select id from public.activity_taxonomies where code='robotica' and taxonomy_kind='subtype' and status='active' limit 1),
 null,'8c100000-0000-4000-8000-000000000807')$call$,
 '22023','invalid activity template request','null governance is rejected at the command boundary');

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8c100000-0000-4000-8000-000000000102','session_id','8c100000-0000-4000-8000-000000000202',
 'aal','aal2','role','authenticated')::text,true);
select throws_ok($call$select public.superadmin_create_scoped_activity_template(
 '8c100000-0000-4000-8000-000000000020','8c100000-0000-4000-8000-000000000021',
 'Cross tenant','',(select id from public.activity_taxonomies where code='robotica' and taxonomy_kind='subtype' and status='active' limit 1),
 'optional','8c100000-0000-4000-8000-000000000803')$call$,
 '42501','institution scope denied','institution-scoped actor cannot create in another tenant');
select ok((select jsonb_array_length(options->'institutions')=1
 and options#>>'{institutions,0,id}'='8c100000-0000-4000-8000-000000000010'
 and jsonb_array_length(options->'units')=1
 and options#>>'{units,0,id}'='8c100000-0000-4000-8000-000000000011'
 from (select public.superadmin_activity_template_options(null) options) scoped),
 'null options request is reduced to the actor institution');
select throws_ok($$select public.superadmin_activity_template_options('8c100000-0000-4000-8000-000000000020')$$,
 '42501','institution scope denied','scoped options reject another tenant');
select throws_ok($call$select public.superadmin_create_scoped_activity_template(
 '8c100000-0000-4000-8000-000000000010','8c100000-0000-4000-8000-000000000011',
 'Replay estrangeiro','Modelo sintético.',
 (select id from public.activity_taxonomies where code='robotica' and taxonomy_kind='subtype' and status='active' limit 1),
 'mandatory','8c100000-0000-4000-8000-000000000801')$call$,
 '42501','template receipt actor mismatch','another identity cannot replay the receipt');

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8c100000-0000-4000-8000-000000000101','session_id','8c100000-0000-4000-8000-000000000209',
 'aal','aal1','role','authenticated')::text,true);
select throws_ok($call$select public.superadmin_create_scoped_activity_template(
 '8c100000-0000-4000-8000-000000000010',null,'Sem MFA','',
 (select id from public.activity_taxonomies where code='robotica' and taxonomy_kind='subtype' and status='active' limit 1),
 'optional','8c100000-0000-4000-8000-000000000804')$call$,
 '42501','internal authorization denied','AAL1 actor is denied');

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8c100000-0000-4000-8000-000000000103','session_id','8c100000-0000-4000-8000-000000000203',
 'aal','aal2','role','authenticated')::text,true);
select throws_ok($call$select public.superadmin_create_scoped_activity_template(
 '8c100000-0000-4000-8000-000000000010',null,'Realm legado','',
 (select id from public.activity_taxonomies where code='robotica' and taxonomy_kind='subtype' and status='active' limit 1),
 'optional','8c100000-0000-4000-8000-000000000805')$call$,
 '42501','internal authorization denied','people-based credential cannot enter internal command');

select set_config('request.jwt.claims','{}',true);
set local role anon;
select throws_ok($call$select public.superadmin_create_scoped_activity_template(
 '8c100000-0000-4000-8000-000000000010',null,'Anon','',
 (select id from public.activity_taxonomies where code='robotica' and taxonomy_kind='subtype' and status='active' limit 1),
 'optional','8c100000-0000-4000-8000-000000000806')$call$,
 '42501',null,'anonymous role cannot execute the command');
reset role;

select * from finish();
rollback;
