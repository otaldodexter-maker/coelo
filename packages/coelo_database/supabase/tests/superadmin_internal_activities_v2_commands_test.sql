begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

select has_function('public','superadmin_activity_create_v2',array['uuid','jsonb'],'create v2 exists');
select has_function('public','superadmin_activity_update_v2',array['uuid','uuid','bigint','jsonb'],'update v2 exists');
select has_function('public','superadmin_activity_publish_v2',array['uuid','uuid','bigint'],'publish v2 exists');
select has_function('public','superadmin_activity_set_units_v2',array['uuid','uuid','bigint','uuid[]'],'set units v2 exists');
select has_function('public','superadmin_activity_set_groups_v2',array['uuid','uuid','bigint','uuid[]','jsonb'],'set groups v2 exists');

insert into public.institution_types(id,code,name,status) values
 ('8b100000-0000-4000-8000-000000000001','activities-v2-command','Activities v2 command','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('8b100000-0000-4000-8000-000000000010','Command Tenant A','activities-v2-command-a','active','8b100000-0000-4000-8000-000000000001'),
 ('8b100000-0000-4000-8000-000000000020','Command Tenant B','activities-v2-command-b','active','8b100000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,institution_type_id,name,slug,status) values
 ('8b100000-0000-4000-8000-000000000011','8b100000-0000-4000-8000-000000000010','8b100000-0000-4000-8000-000000000001','A Norte','activities-v2-command-a-norte','active'),
 ('8b100000-0000-4000-8000-000000000012','8b100000-0000-4000-8000-000000000010','8b100000-0000-4000-8000-000000000001','A Sul','activities-v2-command-a-sul','active'),
 ('8b100000-0000-4000-8000-000000000015','8b100000-0000-4000-8000-000000000010','8b100000-0000-4000-8000-000000000001','A Leste não vinculada','activities-v2-command-a-leste','active'),
 ('8b100000-0000-4000-8000-000000000021','8b100000-0000-4000-8000-000000000020','8b100000-0000-4000-8000-000000000001','B Única','activities-v2-command-b-unica','active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 ('8b100000-0000-4000-8000-000000000013','8b100000-0000-4000-8000-000000000010','8b100000-0000-4000-8000-000000000011','Turma A Norte','active'),
 ('8b100000-0000-4000-8000-000000000014','8b100000-0000-4000-8000-000000000010','8b100000-0000-4000-8000-000000000012','Turma A Sul','active'),
 ('8b100000-0000-4000-8000-000000000016','8b100000-0000-4000-8000-000000000010','8b100000-0000-4000-8000-000000000015','Turma A Leste não vinculada','active'),
 ('8b100000-0000-4000-8000-000000000022','8b100000-0000-4000-8000-000000000020','8b100000-0000-4000-8000-000000000021','Turma B','active');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('8b100000-0000-4000-8000-000000000101','authenticated','authenticated','command-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('8b100000-0000-4000-8000-000000000102','authenticated','authenticated','command-scoped@invalid.test',now(),now(),now(),'{}','{}'),
 ('8b100000-0000-4000-8000-000000000103','authenticated','authenticated','command-revoked@invalid.test',now(),now(),now(),'{}','{}'),
 ('8b100000-0000-4000-8000-000000000104','authenticated','authenticated','command-people@invalid.test',now(),now(),now(),'{}','{}'),
 ('8b100000-0000-4000-8000-000000000105','authenticated','authenticated','command-denied@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('8b100000-0000-4000-8000-000000000201','8b100000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('8b100000-0000-4000-8000-000000000202','8b100000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour'),
 ('8b100000-0000-4000-8000-000000000203','8b100000-0000-4000-8000-000000000103',now(),now(),'aal2',now()+interval '1 hour'),
 ('8b100000-0000-4000-8000-000000000204','8b100000-0000-4000-8000-000000000104',now(),now(),'aal2',now()+interval '1 hour'),
 ('8b100000-0000-4000-8000-000000000205','8b100000-0000-4000-8000-000000000105',now(),now(),'aal2',now()+interval '1 hour'),
 ('8b100000-0000-4000-8000-000000000209','8b100000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('8b100000-0000-4000-8000-000000000301'),('8b100000-0000-4000-8000-000000000302'),
 ('8b100000-0000-4000-8000-000000000303'),('8b100000-0000-4000-8000-000000000305');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('8b100000-0000-4000-8000-000000000401','8b100000-0000-4000-8000-000000000301','8b100000-0000-4000-8000-000000000101'),
 ('8b100000-0000-4000-8000-000000000402','8b100000-0000-4000-8000-000000000302','8b100000-0000-4000-8000-000000000102'),
 ('8b100000-0000-4000-8000-000000000403','8b100000-0000-4000-8000-000000000303','8b100000-0000-4000-8000-000000000103'),
 ('8b100000-0000-4000-8000-000000000405','8b100000-0000-4000-8000-000000000305','8b100000-0000-4000-8000-000000000105');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('8b100000-0000-4000-8000-000000000501'::uuid,'8b100000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('8b100000-0000-4000-8000-000000000502'::uuid,'8b100000-0000-4000-8000-000000000302'::uuid,'operations','institution','8b100000-0000-4000-8000-000000000010'::uuid),
 ('8b100000-0000-4000-8000-000000000503'::uuid,'8b100000-0000-4000-8000-000000000303'::uuid,'operations','institution','8b100000-0000-4000-8000-000000000010'::uuid),
 ('8b100000-0000-4000-8000-000000000505'::uuid,'8b100000-0000-4000-8000-000000000305'::uuid,'content','platform',null::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now(),version=2 where id='8b100000-0000-4000-8000-000000000503';
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('8b100000-0000-4000-8000-000000000601','adult','People','Only','People Only','active'),
 ('8b100000-0000-4000-8000-000000000602','adult','Instrutora','Sintética','Instrutora Sintética','active'),
 ('8b100000-0000-4000-8000-000000000603','adult','Admin','Sintético','Admin Sintético','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('8b100000-0000-4000-8000-000000000601','8b100000-0000-4000-8000-000000000104','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status) values
 ('8b100000-0000-4000-8000-000000000611','8b100000-0000-4000-8000-000000000602','8b100000-0000-4000-8000-000000000010','teacher','active'),
 ('8b100000-0000-4000-8000-000000000612','8b100000-0000-4000-8000-000000000603','8b100000-0000-4000-8000-000000000010','staff','active');

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,
 case when role_record.code='content' and permission_record.code='activities.create' then 'deny'::public.permission_effect else 'allow'::public.permission_effect end,'active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code in('owner','operations','content') and permission_record.code in(
 'activities.read','activities.create','activities.manage','activities.link_units','activities.link_groups','activities.assign_people','activities.manage_permissions')
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;

create temporary table command_results(label text primary key,body jsonb not null);
select set_config('request.jwt.claims',jsonb_build_object('sub','8b100000-0000-4000-8000-000000000101','session_id','8b100000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);
insert into command_results
select 'create',public.superadmin_activity_create_v2('8b100000-0000-4000-8000-000000000801',jsonb_build_object(
 'institution_id','8b100000-0000-4000-8000-000000000010','name','Robótica faseada','description','Contrato sintético',
 'taxonomy_id',(select id from public.activity_taxonomies where code='robotica' and status='active' limit 1),
 'icon_key','science','initials','RF','unit_ids',jsonb_build_array('8b100000-0000-4000-8000-000000000011')));
insert into command_results
select 'create_replay',public.superadmin_activity_create_v2('8b100000-0000-4000-8000-000000000801',jsonb_build_object(
 'institution_id','8b100000-0000-4000-8000-000000000010','name','Robótica faseada','description','Contrato sintético',
 'taxonomy_id',(select id from public.activity_taxonomies where code='robotica' and status='active' limit 1),
 'icon_key','science','initials','RF','unit_ids',jsonb_build_array('8b100000-0000-4000-8000-000000000011')));
insert into command_results
select 'create_hash_conflict',public.superadmin_activity_create_v2('8b100000-0000-4000-8000-000000000801',jsonb_build_object(
 'institution_id','8b100000-0000-4000-8000-000000000010','name','Payload divergente','taxonomy_id',(select id from public.activity_taxonomies where code='robotica' limit 1),
 'initials','PD','unit_ids',jsonb_build_array('8b100000-0000-4000-8000-000000000011')));
insert into command_results
select 'update',public.superadmin_activity_update_v2('8b100000-0000-4000-8000-000000000802',(select (body#>>'{data,activity_id}')::uuid from command_results where label='create'),1,
 '{"name":"Robótica avançada","description":"Atualizada","icon_key":"science","initials":"RA"}');
insert into command_results
select 'update_stale',public.superadmin_activity_update_v2('8b100000-0000-4000-8000-000000000803',(select (body#>>'{data,activity_id}')::uuid from command_results where label='create'),1,'{"name":"Stale"}');
insert into command_results
select 'set_units',public.superadmin_activity_set_units_v2('8b100000-0000-4000-8000-000000000804',(select (body#>>'{data,activity_id}')::uuid from command_results where label='create'),2,
 array['8b100000-0000-4000-8000-000000000011','8b100000-0000-4000-8000-000000000012']::uuid[]);
insert into command_results
select 'set_units_cross',public.superadmin_activity_set_units_v2('8b100000-0000-4000-8000-000000000805',(select (body#>>'{data,activity_id}')::uuid from command_results where label='create'),3,
 array['8b100000-0000-4000-8000-000000000021']::uuid[]);
insert into command_results
select 'set_groups',public.superadmin_activity_set_groups_v2('8b100000-0000-4000-8000-000000000806',(select (body#>>'{data,activity_id}')::uuid from command_results where label='create'),3,
 array['8b100000-0000-4000-8000-000000000013']::uuid[],jsonb_build_object('8b100000-0000-4000-8000-000000000013','all'));
insert into command_results
select 'set_groups_sibling',public.superadmin_activity_set_groups_v2('8b100000-0000-4000-8000-000000000807',(select (body#>>'{data,activity_id}')::uuid from command_results where label='create'),4,
 array['8b100000-0000-4000-8000-000000000016']::uuid[],jsonb_build_object('8b100000-0000-4000-8000-000000000016','all'));
insert into command_results
select 'random_update',public.superadmin_activity_update_v2(gen_random_uuid(),'8b100000-0000-4000-8000-ffffffffffff',1,'{"name":"Random"}');
insert into command_results
select 'invalid_create',public.superadmin_activity_create_v2(gen_random_uuid(),'{"institution_id":"8b100000-0000-4000-8000-000000000010","name":"Sem unidade","unit_ids":[],"forbidden":true}');

-- Build the explicit publish preconditions without invoking the other Task-3
-- snapshots: this file owns only the five core command contracts.
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8b100000-0000-4000-8000-000000000301','internal_auth_link_id','8b100000-0000-4000-8000-000000000401','internal_membership_id','8b100000-0000-4000-8000-000000000501','auth_user_id','8b100000-0000-4000-8000-000000000101','session_id','8b100000-0000-4000-8000-000000000201','permission_code','activities.assign_people','action_code','assign_people','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_group_assignments(id,activity_group_link_id,institution_id,person_id,membership_id,assignment_role,assigned_by_person_id)
select '8b100000-0000-4000-8000-000000000901',link.id,'8b100000-0000-4000-8000-000000000010','8b100000-0000-4000-8000-000000000602','8b100000-0000-4000-8000-000000000611','instructor',null
from public.activity_group_links link where link.activity_id=(select (body#>>'{data,activity_id}')::uuid from command_results where label='create') and link.group_id='8b100000-0000-4000-8000-000000000013';
insert into public.activity_admin_assignments(id,activity_id,institution_id,person_id,membership_id,assigned_by_person_id)
select '8b100000-0000-4000-8000-000000000902',(body#>>'{data,activity_id}')::uuid,'8b100000-0000-4000-8000-000000000010','8b100000-0000-4000-8000-000000000603','8b100000-0000-4000-8000-000000000612',null
from command_results where label='create';
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8b100000-0000-4000-8000-000000000301','internal_auth_link_id','8b100000-0000-4000-8000-000000000401','internal_membership_id','8b100000-0000-4000-8000-000000000501','auth_user_id','8b100000-0000-4000-8000-000000000101','session_id','8b100000-0000-4000-8000-000000000201','permission_code','activities.manage_permissions','action_code','manage_permissions','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_capability_policies(activity_id,institution_id,capability_id,policy_mode,changed_by_person_id)
select (select (body#>>'{data,activity_id}')::uuid from command_results where label='create'),'8b100000-0000-4000-8000-000000000010',capability.id,'required',null
from public.activity_capabilities capability where capability.code in('chat','now','happens','moments','attendance');
insert into public.activity_assignment_capability_actions(assignment_id,capability_id,can_view,can_edit,changed_by_person_id)
select '8b100000-0000-4000-8000-000000000901',capability.id,true,true,null from public.activity_capabilities capability where capability.code in('chat','now','happens','moments','attendance');
insert into public.activity_admin_capability_actions(activity_admin_assignment_id,capability_id,can_view,can_edit,changed_by_person_id)
select '8b100000-0000-4000-8000-000000000902',capability.id,true,true,null from public.activity_capabilities capability where capability.code in('chat','now','happens','moments','attendance');
insert into command_results
select 'publish',public.superadmin_activity_publish_v2('8b100000-0000-4000-8000-000000000808',(select (body#>>'{data,activity_id}')::uuid from command_results where label='create'),4);

-- Negative actor matrix uses the same real Auth/session/context path.
select set_config('request.jwt.claims','{}',true);
insert into command_results values('anonymous',public.superadmin_activity_create_v2(gen_random_uuid(),'{}'));
select set_config('request.jwt.claims',jsonb_build_object('sub','8b100000-0000-4000-8000-000000000101','session_id','8b100000-0000-4000-8000-000000000209','aal','aal1','role','authenticated')::text,true);
insert into command_results values('aal1',public.superadmin_activity_create_v2(gen_random_uuid(),'{}'));
select set_config('request.jwt.claims',jsonb_build_object('sub','8b100000-0000-4000-8000-000000000103','session_id','8b100000-0000-4000-8000-000000000203','aal','aal2','role','authenticated')::text,true);
insert into command_results values('revoked',public.superadmin_activity_create_v2(gen_random_uuid(),'{}'));
select set_config('request.jwt.claims',jsonb_build_object('sub','8b100000-0000-4000-8000-000000000104','session_id','8b100000-0000-4000-8000-000000000204','aal','aal2','role','authenticated')::text,true);
insert into command_results values('people_only',public.superadmin_activity_create_v2(gen_random_uuid(),'{}'));
select set_config('request.jwt.claims',jsonb_build_object('sub','8b100000-0000-4000-8000-000000000105','session_id','8b100000-0000-4000-8000-000000000205','aal','aal2','role','authenticated')::text,true);
insert into command_results values('cap_denied',public.superadmin_activity_create_v2(gen_random_uuid(),'{}'));
select set_config('request.jwt.claims',jsonb_build_object('sub','8b100000-0000-4000-8000-000000000102','session_id','8b100000-0000-4000-8000-000000000202','aal','aal2','role','authenticated')::text,true);
insert into command_results values('scoped_cross_tenant',public.superadmin_activity_create_v2(gen_random_uuid(),'{"institution_id":"8b100000-0000-4000-8000-000000000020","name":"Cross tenant","taxonomy_id":"8b100000-0000-4000-8000-ffffffffffff","initials":"CT","unit_ids":["8b100000-0000-4000-8000-000000000021"]}'));

select ok((select body#>>'{ok}'='true' and body#>>'{data,status}'='draft' and body#>>'{data,management_version}'='1' from command_results where label='create'),'create persists a valid draft at version 1');
select ok((select body#>>'{data,replayed}'='true' and body#>>'{data,activity_id}'=(select body#>>'{data,activity_id}' from command_results where label='create') from command_results where label='create_replay'),'same request and hash replay the stored result');
select is((select body#>>'{error,code}' from command_results where label='create_hash_conflict'),'SAI_CONCURRENT_CHANGE','same request with a different hash conflicts');
select ok((select body#>>'{ok}'='true' and body#>>'{data,management_version}'='2' from command_results where label='update'),'update increments version exactly once');
select ok((select name='Robótica avançada' and description='Atualizada' and management_version=5 from public.activity_definitions where id=(select (body#>>'{data,activity_id}')::uuid from command_results where label='create')),'accepted command chain persists normalized fields and final version');
select is((select body#>>'{error,code}' from command_results where label='update_stale'),'SAI_CONCURRENT_CHANGE','stale expected version is rejected');
select ok((select body#>>'{ok}'='true' and body#>>'{data,management_version}'='3' from command_results where label='set_units') and (select count(*)=2 from public.activity_unit_links where activity_id=(select (body#>>'{data,activity_id}')::uuid from command_results where label='create') and status='active'),'set_units atomically replaces the active unit snapshot');
select is((select body#>>'{error,code}' from command_results where label='set_units_cross'),'ACTIVITY_INVALID_REFERENCE','tenant B unit is rejected');
select ok((select body#>>'{ok}'='true' and body#>>'{data,management_version}'='4' from command_results where label='set_groups') and (select count(*)=1 from public.activity_group_links where activity_id=(select (body#>>'{data,activity_id}')::uuid from command_results where label='create') and status='active'),'set_groups atomically writes the authorized group snapshot');
select is((select body#>>'{error,code}' from command_results where label='set_groups_sibling'),'ACTIVITY_INVALID_REFERENCE','group in an unselected sibling unit is rejected');
select is((select body#>>'{error,code}' from command_results where label='random_update'),'ACTIVITY_NOT_FOUND','random activity UUID is non-enumerating');
select is((select body#>>'{error,code}' from command_results where label='invalid_create'),'ACTIVITY_INVALID_INPUT','unknown keys and empty units are rejected');
select ok((select body#>>'{ok}'='true' and body#>>'{data,status}'='active' and body#>>'{data,management_version}'='5' from command_results where label='publish'),'publish succeeds only after explicit structural and professional prerequisites');
select ok((select count(*)=5 and count(distinct request_id)=5 and bool_and(octet_length(request_hash)=32) from app_private.superadmin_internal_activity_command_receipts where activity_id=(select (body#>>'{data,activity_id}')::uuid from command_results where label='create')),'five accepted commands create one minimized receipt each');
select ok((select count(*)=5 from audit.audit_logs log_record join app_private.superadmin_internal_activity_command_receipts receipt on receipt.correlation_id=log_record.correlation_id where receipt.activity_id=(select (body#>>'{data,activity_id}')::uuid from command_results where label='create') and log_record.outcome='success'),'each non-replay command appends exactly one correlated domain audit');
select ok((select count(*)=1 from app_private.superadmin_internal_activity_command_receipts where request_id='8b100000-0000-4000-8000-000000000801') and (select count(*)=1 from audit.audit_logs where correlation_id=(select correlation_id from app_private.superadmin_internal_activity_command_receipts where request_id='8b100000-0000-4000-8000-000000000801')),'replay creates neither a second receipt nor a second audit');
select is((select body#>>'{error,code}' from command_results where label='anonymous'),'SAI_AUTH_REQUIRED','missing Auth fails closed');
select is((select body#>>'{error,code}' from command_results where label='aal1'),'SAI_MFA_REQUIRED','Owner AAL1 fails closed');
select is((select body#>>'{error,code}' from command_results where label='revoked'),'SAI_MEMBERSHIP_REVOKED','revoked membership fails closed');
select is((select body#>>'{error,code}' from command_results where label='people_only'),'SAI_INTERNAL_CONTEXT_DENIED','people-only cross-app actor cannot invoke internal commands');
select is((select body#>>'{error,code}' from command_results where label='cap_denied'),'SAI_PERMISSION_DENIED','explicit capability deny fails closed');
select is((select body#>>'{error,code}' from command_results where label='scoped_cross_tenant'),'SAI_PERMISSION_DENIED','institution-scoped actor cannot create in tenant B');
select ok(not exists(select 1 from command_results where (select array_agg(key order by key) from jsonb_object_keys(body) key)<>array['data','error','ok']::text[]),'every command returns the stable top-level envelope');

select * from finish();
rollback;
