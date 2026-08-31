begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

-- This is deliberately an independent fixture.  It uses the spec-039 internal
-- Auth realm, rather than a people/profile shortcut, so every denial exercises
-- the same session/link/membership path as a real Superadmin command.
select has_function('public','superadmin_activity_publish_v2',array['uuid','uuid','bigint'],
  'publish gateway exists for the internal hardening matrix');
select has_function('public','superadmin_activity_set_permissions_v2',
  array['uuid','uuid','bigint','jsonb','jsonb','jsonb'],
  'permissions gateway exists for the internal hardening matrix');

insert into public.institution_types(id,code,name,status) values
 ('74000000-0000-4000-8000-000000000001','activities-v2-hardening','Activities v2 hardening','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('74000000-0000-4000-8000-000000000010','Hardening Tenant A','activities-v2-hardening-a','active','74000000-0000-4000-8000-000000000001'),
 ('74000000-0000-4000-8000-000000000020','Hardening Tenant B','activities-v2-hardening-b','active','74000000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,institution_type_id,name,slug,status) values
 ('74000000-0000-4000-8000-000000000011','74000000-0000-4000-8000-000000000010','74000000-0000-4000-8000-000000000001','A Norte','activities-v2-hardening-a-norte','active'),
 ('74000000-0000-4000-8000-000000000012','74000000-0000-4000-8000-000000000010','74000000-0000-4000-8000-000000000001','A Sul','activities-v2-hardening-a-sul','active'),
 ('74000000-0000-4000-8000-000000000021','74000000-0000-4000-8000-000000000020','74000000-0000-4000-8000-000000000001','B Única','activities-v2-hardening-b-unica','active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 ('74000000-0000-4000-8000-000000000013','74000000-0000-4000-8000-000000000010','74000000-0000-4000-8000-000000000011','Turma Norte','active'),
 ('74000000-0000-4000-8000-000000000014','74000000-0000-4000-8000-000000000010','74000000-0000-4000-8000-000000000012','Turma Sul','active'),
 ('74000000-0000-4000-8000-000000000022','74000000-0000-4000-8000-000000000020','74000000-0000-4000-8000-000000000021','Turma B','active');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('74000000-0000-4000-8000-000000000031','adult','Instrutor','Um','Instrutor Um','active'),
 ('74000000-0000-4000-8000-000000000032','adult','Instrutor','Dois','Instrutor Dois','active'),
 ('74000000-0000-4000-8000-000000000033','adult','Admin','Atividade','Admin Atividade','active'),
 ('74000000-0000-4000-8000-000000000034','child','Criança','Um','Criança Um','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind,revoked_at) values
 ('74000000-0000-4000-8000-000000000041','74000000-0000-4000-8000-000000000031','74000000-0000-4000-8000-000000000010','teacher','active','institution',null),
 ('74000000-0000-4000-8000-000000000042','74000000-0000-4000-8000-000000000032','74000000-0000-4000-8000-000000000010','teacher','active','institution',null),
 ('74000000-0000-4000-8000-000000000043','74000000-0000-4000-8000-000000000033','74000000-0000-4000-8000-000000000010','staff','active','institution',null);
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 ('74000000-0000-4000-8000-000000000051','74000000-0000-4000-8000-000000000034','74000000-0000-4000-8000-000000000010','active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
 ('74000000-0000-4000-8000-000000000061','74000000-0000-4000-8000-000000000051','74000000-0000-4000-8000-000000000011','active','74000000-0000-4000-8000-000000000031',now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status,starts_at) values
 ('74000000-0000-4000-8000-000000000071','74000000-0000-4000-8000-000000000061','74000000-0000-4000-8000-000000000013','active',now()-interval '1 day');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('74000000-0000-4000-8000-000000000081','authenticated','authenticated','hardening-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('74000000-0000-4000-8000-000000000082','authenticated','authenticated','hardening-operator@invalid.test',now(),now(),now(),'{}','{}'),
 ('74000000-0000-4000-8000-000000000083','authenticated','authenticated','hardening-session-only@invalid.test',now(),now(),now(),'{}','{}'),
 ('74000000-0000-4000-8000-000000000084','authenticated','authenticated','hardening-owner-sentinel@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('74000000-0000-4000-8000-000000000091','74000000-0000-4000-8000-000000000081',now(),now(),'aal2',now()+interval '1 hour'),
 ('74000000-0000-4000-8000-000000000092','74000000-0000-4000-8000-000000000081',now(),now(),'aal1',now()+interval '1 hour'),
 ('74000000-0000-4000-8000-000000000093','74000000-0000-4000-8000-000000000082',now(),now(),'aal1',now()+interval '1 hour'),
 ('74000000-0000-4000-8000-000000000094','74000000-0000-4000-8000-000000000083',now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('74000000-0000-4000-8000-000000000101'),('74000000-0000-4000-8000-000000000102'),
 ('74000000-0000-4000-8000-000000000103'),('74000000-0000-4000-8000-000000000104');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('74000000-0000-4000-8000-000000000111','74000000-0000-4000-8000-000000000101','74000000-0000-4000-8000-000000000081'),
 ('74000000-0000-4000-8000-000000000112','74000000-0000-4000-8000-000000000102','74000000-0000-4000-8000-000000000082'),
 ('74000000-0000-4000-8000-000000000113','74000000-0000-4000-8000-000000000103','74000000-0000-4000-8000-000000000083'),
 ('74000000-0000-4000-8000-000000000114','74000000-0000-4000-8000-000000000104','74000000-0000-4000-8000-000000000084');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('74000000-0000-4000-8000-000000000121'::uuid,'74000000-0000-4000-8000-000000000101'::uuid,'owner','platform',null::uuid),
 ('74000000-0000-4000-8000-000000000122'::uuid,'74000000-0000-4000-8000-000000000102'::uuid,'operations','institution','74000000-0000-4000-8000-000000000010'::uuid),
 ('74000000-0000-4000-8000-000000000124'::uuid,'74000000-0000-4000-8000-000000000104'::uuid,'owner','platform',null::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code in('owner','operations') and permission_record.code in(
 'activities.read','activities.create','activities.manage','activities.link_units','activities.link_groups','activities.assign_people','activities.manage_permissions')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
update public.platform_permissions set requires_mfa=false where code='activities.read';

create temporary table hardening_results(label text primary key,body jsonb not null);
select set_config('request.jwt.claims',jsonb_build_object('sub','74000000-0000-4000-8000-000000000081','session_id','74000000-0000-4000-8000-000000000091','aal','aal2','role','authenticated')::text,true);
insert into hardening_results select 'create_b',public.superadmin_activity_create_v2(
 '74000000-0000-4000-8000-000000000200',jsonb_build_object(
 'institution_id','74000000-0000-4000-8000-000000000020','name','Tenant B command','description','foreign probe fixture',
 'taxonomy_id',(select id from public.activity_taxonomies where code='robotica' and status='active' limit 1),
 'icon_key','science','initials','TB','unit_ids',jsonb_build_array('74000000-0000-4000-8000-000000000021')));
insert into hardening_results select 'create',public.superadmin_activity_create_v2(
 '74000000-0000-4000-8000-000000000201',jsonb_build_object(
 'institution_id','74000000-0000-4000-8000-000000000010','name','Activity hardening','description','fixture real',
 'taxonomy_id',(select id from public.activity_taxonomies where code='robotica' and status='active' limit 1),
 'icon_key','science','initials','AH','unit_ids',jsonb_build_array('74000000-0000-4000-8000-000000000011')));
insert into hardening_results select 'groups',public.superadmin_activity_set_groups_v2(
 '74000000-0000-4000-8000-000000000202',(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),1,
 array['74000000-0000-4000-8000-000000000013'::uuid],jsonb_build_object('74000000-0000-4000-8000-000000000013','selected'));
insert into hardening_results select 'participants',public.superadmin_activity_set_participants_v2(
 '74000000-0000-4000-8000-000000000203',(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),2,
 jsonb_build_array(jsonb_build_object('group_id','74000000-0000-4000-8000-000000000013','child_group_link_id','74000000-0000-4000-8000-000000000071','belongs',true)));
insert into hardening_results select 'professionals',public.superadmin_activity_set_professionals_v2(
 '74000000-0000-4000-8000-000000000204',(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),3,
 jsonb_build_array(
  jsonb_build_object('membership_id','74000000-0000-4000-8000-000000000041','role','instructor','group_id','74000000-0000-4000-8000-000000000013'),
  jsonb_build_object('membership_id','74000000-0000-4000-8000-000000000043','role','activity_admin','group_id',null)));
with codes as(select value#>>'{}' code from jsonb_array_elements('["chat","now","happens","moments","attendance"]'))
insert into hardening_results select 'permissions',public.superadmin_activity_set_permissions_v2(
 '74000000-0000-4000-8000-000000000205',(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),4,
 (select jsonb_object_agg(code,null) from codes),'[]',jsonb_build_array(
  jsonb_build_object('membership_id','74000000-0000-4000-8000-000000000041','role','instructor','group_id','74000000-0000-4000-8000-000000000013','actions',(select jsonb_object_agg(code,'both') from codes)),
  jsonb_build_object('membership_id','74000000-0000-4000-8000-000000000043','role','activity_admin','group_id',null,'actions',(select jsonb_object_agg(code,'view') from codes))));
select ok((select bool_and((body->>'ok')::boolean) from hardening_results)
 and (select count(*)=1 and bool_and(log_record.payload_contract_version=2 and log_record.actor_kind='superadmin_internal'
      and log_record.after_json=pg_catalog.jsonb_build_object('status',receipt.resulting_status,'management_version',receipt.resulting_version,'counts',receipt.result_counts)
      and app_private.audit_entry_matches_digest(log_record))
   from app_private.superadmin_internal_activity_command_receipts receipt join audit.audit_logs log_record on log_record.correlation_id=receipt.correlation_id
   where receipt.request_id='74000000-0000-4000-8000-000000000201')
 and app_private.audit_mask_payload(jsonb_build_object('counts',jsonb_build_object('units',2,'groups',-1,'participants',1.5,'professionals','2','pii','secret'),'email','pii@invalid.test'))
     =jsonb_build_object('counts',jsonb_build_object('units',2)),
 'real spec-039 owner builds snapshots with a minimized, valid v2 audit matching its receipt');

-- Reload is the external contract: both kinds of professional must retain the
-- exact five action values, not merely an assignment row.
insert into hardening_results select 'detail_permissions',public.superadmin_activity_detail_v2(
 (select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),array['permissions']);
select ok((select jsonb_array_length(body#>'{data,permissions,professional_actions}')=2
 and (select count(*) from jsonb_array_elements(body#>'{data,permissions,professional_actions}') x
      where x->>'role'='instructor' and x->'actions'=(select jsonb_object_agg(value#>>'{}','both') from jsonb_array_elements('["chat","now","happens","moments","attendance"]')))=1
 and (select count(*) from jsonb_array_elements(body#>'{data,permissions,professional_actions}') x
      where x->>'role'='activity_admin' and x->'actions'=(select jsonb_object_agg(value#>>'{}','view') from jsonb_array_elements('["chat","now","happens","moments","attendance"]')))=1
 from hardening_results where label='detail_permissions'),
 'permission detail reload preserves five exact instructor and activity-admin values');

insert into hardening_results select 'clear_admin',public.superadmin_activity_set_professionals_v2(
 '74000000-0000-4000-8000-000000000206',(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),5,
 jsonb_build_array(jsonb_build_object('membership_id','74000000-0000-4000-8000-000000000041','role','instructor','group_id','74000000-0000-4000-8000-000000000013')));
select ok((select (body->>'ok')::boolean from hardening_results where label='clear_admin')
 and not exists(select 1 from public.activity_admin_assignments where activity_id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create') and status='active')
 and not exists(select 1 from public.activity_admin_capability_actions a join public.activity_admin_assignments aa on aa.id=a.activity_admin_assignment_id where aa.activity_id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create') and aa.status='active'),
 'clearing activity admins revokes the active assignment and its effective actions');
insert into hardening_results select 'reassign',public.superadmin_activity_set_professionals_v2(
 '74000000-0000-4000-8000-000000000207',(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),6,
 jsonb_build_array(
  jsonb_build_object('membership_id','74000000-0000-4000-8000-000000000042','role','instructor','group_id','74000000-0000-4000-8000-000000000013'),
  jsonb_build_object('membership_id','74000000-0000-4000-8000-000000000043','role','activity_admin','group_id',null)));
select ok((select (body->>'ok')::boolean from hardening_results where label='reassign')
 and not exists(select 1 from public.activity_assignment_capability_actions a join public.activity_group_assignments x on x.id=a.assignment_id where x.membership_id='74000000-0000-4000-8000-000000000042' and x.status='active')
 and not exists(select 1 from public.activity_admin_capability_actions a join public.activity_admin_assignments x on x.id=a.activity_admin_assignment_id where x.membership_id='74000000-0000-4000-8000-000000000043' and x.status='active'),
 'a newly assigned instructor or activity admin inherits zero historical actions');
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object('internal_identity_id','74000000-0000-4000-8000-000000000101','internal_auth_link_id','74000000-0000-4000-8000-000000000111','internal_membership_id','74000000-0000-4000-8000-000000000121','auth_user_id','74000000-0000-4000-8000-000000000081','session_id','74000000-0000-4000-8000-000000000091','permission_code','activities.manage','action_code','manage','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_assignment_capability_actions(assignment_id,capability_id,can_view,can_edit,changed_by_person_id)
select assignment.id,capability.id,true,true,null from public.activity_group_assignments assignment
join public.activity_group_links group_link on group_link.id=assignment.activity_group_link_id
cross join public.activity_capabilities capability
where group_link.activity_id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create')
 and assignment.membership_id='74000000-0000-4000-8000-000000000042' and assignment.status='active'
 and capability.code in('chat','now','happens','moments','attendance');
insert into public.activity_admin_capability_actions(activity_admin_assignment_id,capability_id,can_view,can_edit,changed_by_person_id)
select assignment.id,capability.id,true,true,null from public.activity_admin_assignments assignment
cross join public.activity_capabilities capability
where assignment.activity_id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create')
 and assignment.membership_id='74000000-0000-4000-8000-000000000043' and assignment.status='active'
 and capability.code in('chat','now','happens','moments','attendance');

insert into hardening_results select 'unknown_false',public.superadmin_activity_set_participants_v2(
 '74000000-0000-4000-8000-000000000208',(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),7,
 jsonb_build_array(jsonb_build_object('group_id','74000000-0000-4000-8000-000000000013','child_group_link_id','74000000-0000-4000-8000-000000000071','belongs',true),jsonb_build_object('group_id','74000000-0000-4000-8000-ffffffffffff','child_group_link_id','74000000-0000-4000-8000-eeeeeeeeeeee','belongs',false)));
select ok((select (body->>'ok')::boolean from hardening_results where label='unknown_false')
 and not exists(select 1 from public.activity_group_participants where child_group_link_id='74000000-0000-4000-8000-eeeeeeeeeeee'),
 'an unknown belongs=false participant is a tombstone-free snapshot no-op');

-- Payload validation is fail-closed before version or relation mutation.
insert into hardening_results select 'bad_create_keys',public.superadmin_activity_create_v2(gen_random_uuid(),jsonb_build_object('institution_id','74000000-0000-4000-8000-000000000010','name','bad','taxonomy_id',(select id from public.activity_taxonomies where code='robotica' limit 1),'unit_ids',jsonb_build_array('74000000-0000-4000-8000-000000000011'),'origin_scope_kind','unit'));
insert into hardening_results select 'duplicate_groups',public.superadmin_activity_set_groups_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),8,array['74000000-0000-4000-8000-000000000013'::uuid,'74000000-0000-4000-8000-000000000013'::uuid],jsonb_build_object('74000000-0000-4000-8000-000000000013','selected'));
insert into hardening_results select 'duplicate_professionals',public.superadmin_activity_set_professionals_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),8,jsonb_build_array(jsonb_build_object('membership_id','74000000-0000-4000-8000-000000000042','role','instructor','group_id','74000000-0000-4000-8000-000000000013'),jsonb_build_object('membership_id','74000000-0000-4000-8000-000000000042','role','instructor','group_id','74000000-0000-4000-8000-000000000013')));
insert into hardening_results select 'too_many_units',public.superadmin_activity_set_units_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),8,(select array_agg('74000000-0000-4000-8000-000000000011'::uuid) from generate_series(1,101)));
insert into hardening_results select 'random_form_institution',public.superadmin_activity_form_options_v2('74000000-0000-4000-8000-ffffffffffff',array['taxonomy'],null,10);
insert into hardening_results select 'random_create_institution',public.superadmin_activity_create_v2('74000000-0000-4000-8000-000000000282',jsonb_build_object('institution_id','74000000-0000-4000-8000-ffffffffffff','name','Random institution','taxonomy_id',(select id from public.activity_taxonomies where code='robotica' limit 1),'initials','RI','unit_ids',jsonb_build_array('74000000-0000-4000-8000-000000000011')));
select ok((select bool_and((body->>'ok')::boolean=false and body#>>'{error,code}'='ACTIVITY_INVALID_INPUT') from hardening_results where label in('bad_create_keys','duplicate_groups','duplicate_professionals','too_many_units'))
 and (select bool_and((body->>'ok')::boolean=false and body#>>'{error,code}'='SAI_PERMISSION_DENIED') from hardening_results where label in('random_form_institution','random_create_institution'))
 and not exists(select 1 from app_private.superadmin_internal_activity_command_receipts where request_id='74000000-0000-4000-8000-000000000282'),
 'strict payloads fail closed and unknown institution probes return sanitized envelopes without receipts');

-- Non-Owner AAL1 is allowed only when the active capability does not require
-- MFA; Owner remains AAL2-only regardless of the capability setting.
select set_config('request.jwt.claims',jsonb_build_object('sub','74000000-0000-4000-8000-000000000082','session_id','74000000-0000-4000-8000-000000000093','aal','aal1','role','authenticated')::text,true);
insert into hardening_results select 'operator_aal1_read',public.superadmin_activity_directory_v2(jsonb_build_object('institution_id','74000000-0000-4000-8000-000000000010'),10,0,'name',true);
select set_config('request.jwt.claims',jsonb_build_object('sub','74000000-0000-4000-8000-000000000081','session_id','74000000-0000-4000-8000-000000000092','aal','aal1','role','authenticated')::text,true);
insert into hardening_results select 'owner_aal1_read',public.superadmin_activity_directory_v2('{}',10,0,'name',true);
select ok((select (body->>'ok')::boolean from hardening_results where label='operator_aal1_read')
 and (select body#>>'{error,code}'='SAI_MFA_REQUIRED' from hardening_results where label='owner_aal1_read'),
 'non-Owner AAL1 uses a non-MFA active capability while Owner AAL1 remains denied');

-- Resume the Owner's AAL2 session for lifecycle and replay probes.
select set_config('request.jwt.claims',jsonb_build_object('sub','74000000-0000-4000-8000-000000000081','session_id','74000000-0000-4000-8000-000000000091','aal','aal2','role','authenticated')::text,true);
insert into hardening_results select 'first_update',public.superadmin_activity_update_v2('74000000-0000-4000-8000-000000000209',(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),8,jsonb_build_object('name','Replay source'));
insert into hardening_results select 'same_actor_hash_conflict',public.superadmin_activity_update_v2('74000000-0000-4000-8000-000000000209',(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),8,jsonb_build_object('name','Different hash'));
select set_config('request.jwt.claims',jsonb_build_object('sub','74000000-0000-4000-8000-000000000082','session_id','74000000-0000-4000-8000-000000000093','aal','aal2','role','authenticated')::text,true);
insert into hardening_results select 'other_actor_receipt',public.superadmin_activity_update_v2('74000000-0000-4000-8000-000000000209',(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),8,jsonb_build_object('name','Replay source'));
select set_config('request.jwt.claims',jsonb_build_object('sub','74000000-0000-4000-8000-000000000081','session_id','74000000-0000-4000-8000-000000000091','aal','aal2','role','authenticated')::text,true);
update auth.sessions set not_after=now()-interval '1 minute' where id='74000000-0000-4000-8000-000000000091';
insert into hardening_results select 'replay_after_session_revoke',public.superadmin_activity_update_v2('74000000-0000-4000-8000-000000000209',(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),8,jsonb_build_object('name','Replay source'));
update auth.sessions set not_after=now()+interval '1 hour' where id='74000000-0000-4000-8000-000000000091';
update app_private.superadmin_internal_auth_links set status='suspended',suspended_at=now(),version=version+1 where id='74000000-0000-4000-8000-000000000111';
insert into hardening_results select 'suspended_link',public.superadmin_activity_directory_v2('{}',10,0,'name',true);
insert into hardening_results select 'replay_after_link_revoke',public.superadmin_activity_update_v2('74000000-0000-4000-8000-000000000209',(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),8,jsonb_build_object('name','Replay source'));
update app_private.superadmin_internal_auth_links set status='active',suspended_at=null,version=version+1 where id='74000000-0000-4000-8000-000000000111';
update app_private.superadmin_internal_auth_links set status='revoked',revoked_at=now(),version=version+1 where id='74000000-0000-4000-8000-000000000113';
select set_config('request.jwt.claims',jsonb_build_object('sub','74000000-0000-4000-8000-000000000083','session_id','74000000-0000-4000-8000-000000000094','aal','aal2','role','authenticated')::text,true);
insert into hardening_results select 'revoked_link',public.superadmin_activity_directory_v2('{}',10,0,'name',true);
select set_config('request.jwt.claims',jsonb_build_object('sub','74000000-0000-4000-8000-000000000081','session_id','74000000-0000-4000-8000-000000000091','aal','aal2','role','authenticated')::text,true);
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now(),version=version+1 where id='74000000-0000-4000-8000-000000000121';
insert into hardening_results select 'revoked_membership',public.superadmin_activity_directory_v2('{}',10,0,'name',true);
insert into hardening_results select 'replay_after_membership_revoke',public.superadmin_activity_update_v2('74000000-0000-4000-8000-000000000209',(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),8,jsonb_build_object('name','Replay source'));
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '74000000-0000-4000-8000-000000000125','74000000-0000-4000-8000-000000000101',id,'platform'
from public.platform_roles where code='owner';
update public.platform_permissions set status='inactive' where code='activities.manage';
insert into hardening_results select 'inactive_capability',public.superadmin_activity_update_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),8,jsonb_build_object('name','Denied capability'));
insert into hardening_results select 'replay_after_capability_revoke',public.superadmin_activity_update_v2('74000000-0000-4000-8000-000000000209',(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),8,jsonb_build_object('name','Replay source'));
update public.platform_permissions set status='active' where code='activities.manage';
select set_config('request.jwt.claims',jsonb_build_object('sub','74000000-0000-4000-8000-000000000082','session_id','74000000-0000-4000-8000-000000000093','aal','aal1','role','authenticated')::text,true);
update public.platform_roles set status='inactive' where code='operations';
insert into hardening_results select 'inactive_role',public.superadmin_activity_directory_v2('{}',10,0,'name',true);
update public.platform_roles set status='active' where code='operations';
select set_config('request.jwt.claims',jsonb_build_object('sub','74000000-0000-4000-8000-000000000081','session_id','74000000-0000-4000-8000-000000000091','aal','aal2','role','authenticated')::text,true);
select ok((select body#>>'{error,code}'='SAI_SESSION_INVALID' from hardening_results where label='replay_after_session_revoke')
 and (select body#>>'{error,code}' in('SAI_INTERNAL_CONTEXT_DENIED','SAI_PERMISSION_DENIED') from hardening_results where label='suspended_link')
 and (select body#>>'{error,code}' in('SAI_INTERNAL_CONTEXT_DENIED','SAI_PERMISSION_DENIED') from hardening_results where label='revoked_link')
 and (select body#>>'{error,code}' in('SAI_INTERNAL_CONTEXT_DENIED','SAI_PERMISSION_DENIED') from hardening_results where label='replay_after_link_revoke')
 and (select body#>>'{error,code}'='SAI_MEMBERSHIP_REVOKED' from hardening_results where label='revoked_membership')
 and (select body#>>'{error,code}' in('SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED') from hardening_results where label='replay_after_membership_revoke')
 and (select body#>>'{error,code}'='SAI_PERMISSION_DENIED' from hardening_results where label='inactive_capability')
 and (select body#>>'{error,code}'='SAI_PERMISSION_DENIED' from hardening_results where label='replay_after_capability_revoke')
 and (select body#>>'{error,code}'='SAI_PERMISSION_DENIED' from hardening_results where label='inactive_role')
 and (select body#>>'{error,code}'='SAI_CONCURRENT_CHANGE' from hardening_results where label='same_actor_hash_conflict')
 and (select body#>>'{error,code}'='SAI_PERMISSION_DENIED' from hardening_results where label='other_actor_receipt')
 and (select count(*)=1 from app_private.superadmin_internal_activity_command_receipts where request_id='74000000-0000-4000-8000-000000000209')
 and (select management_version=9 from public.activity_definitions where id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'))
 and (select count(*)=1 from audit.audit_logs where correlation_id=(select (body#>>'{error,correlation_id}')::uuid from hardening_results where label='same_actor_hash_conflict') and outcome='denied')
 and (select count(*)=1 from audit.audit_logs where correlation_id=(select (body#>>'{error,correlation_id}')::uuid from hardening_results where label='other_actor_receipt') and outcome='denied'),
 'session, auth-link, membership, role and capability lifecycle are all revalidated before a replay');

-- An actor scoped to A must not distinguish an existing B command from a random
-- UUID, even when a receipt for the target command already exists.
select set_config('request.jwt.claims',jsonb_build_object('sub','74000000-0000-4000-8000-000000000082','session_id','74000000-0000-4000-8000-000000000093','aal','aal2','role','authenticated')::text,true);
insert into hardening_results select 'tenant_b_existing',public.superadmin_activity_update_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create_b'),1,jsonb_build_object('name','B probe'));
insert into hardening_results select 'random_probe',public.superadmin_activity_update_v2(gen_random_uuid(),'74000000-0000-4000-8000-ffffffffffff',1,jsonb_build_object('name','random'));
select is((select body#>>'{error,code}' from hardening_results where label='tenant_b_existing'),(select body#>>'{error,code}' from hardening_results where label='random_probe'),
 'existing foreign command and random UUID are externally indistinguishable');

-- Publish matrix: every incomplete or contradictory draft remains a draft and
-- returns one stable state failure.  Direct fixture changes use the validated
-- marker so the test does not sidestep the v2 actor guard.
select set_config('request.jwt.claims',jsonb_build_object('sub','74000000-0000-4000-8000-000000000081','session_id','74000000-0000-4000-8000-000000000091','aal','aal2','role','authenticated')::text,true);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object('internal_identity_id','74000000-0000-4000-8000-000000000101','internal_auth_link_id','74000000-0000-4000-8000-000000000111','internal_membership_id','74000000-0000-4000-8000-000000000125','auth_user_id','74000000-0000-4000-8000-000000000081','session_id','74000000-0000-4000-8000-000000000091','permission_code','activities.manage','action_code','manage','correlation_id',gen_random_uuid())::text,true);
update public.activity_definitions set taxonomy_id=null where id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create');
insert into hardening_results select 'publish_no_taxonomy',public.superadmin_activity_publish_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),9);
update public.activity_definitions set taxonomy_id=(select id from public.activity_taxonomies where code='robotica' limit 1) where id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create');
update public.activity_unit_links set status='inactive' where activity_id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create');
insert into hardening_results select 'publish_no_units',public.superadmin_activity_publish_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),9);
update public.activity_unit_links set status='active' where activity_id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create');
update public.activity_group_links set status='inactive' where activity_id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create');
insert into hardening_results select 'publish_no_groups',public.superadmin_activity_publish_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),9);
update public.activity_group_links set status='active' where activity_id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create');
update public.activity_definitions set origin_scope_kind='unit',origin_unit_id='74000000-0000-4000-8000-000000000012' where id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create');
insert into hardening_results select 'publish_bad_origin',public.superadmin_activity_publish_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),9);
update public.activity_definitions set origin_scope_kind='institution',origin_unit_id=null where id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create');
update public.child_group_links set status='inactive' where id='74000000-0000-4000-8000-000000000071';
insert into hardening_results select 'publish_broken_participant_chain',public.superadmin_activity_publish_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),9);
update public.child_group_links set status='active' where id='74000000-0000-4000-8000-000000000071';
update public.institution_memberships set status='suspended' where id='74000000-0000-4000-8000-000000000042';
insert into hardening_results select 'detail_stale_professional',public.superadmin_activity_detail_v2((select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),array['professionals','permissions']);
insert into hardening_results select 'publish_broken_professional_chain',public.superadmin_activity_publish_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),9);
update public.institution_memberships set status='active' where id='74000000-0000-4000-8000-000000000042';
delete from public.activity_assignment_capability_actions where assignment_id in(select assignment.id from public.activity_group_assignments assignment where assignment.membership_id='74000000-0000-4000-8000-000000000042' and assignment.status='active') and capability_id=(select id from public.activity_capabilities where code='chat');
insert into hardening_results select 'publish_missing_actions',public.superadmin_activity_publish_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),9);
insert into public.activity_assignment_capability_actions(assignment_id,capability_id,can_view,can_edit,changed_by_person_id) select assignment.id,capability.id,true,true,null from public.activity_group_assignments assignment cross join public.activity_capabilities capability where assignment.membership_id='74000000-0000-4000-8000-000000000042' and assignment.status='active' and capability.code='chat';
select ok(not exists(select 1 from hardening_results where label like 'publish_%' and body#>>'{error,code}'<>'ACTIVITY_INVALID_STATE')
 and (select not exists(select 1 from jsonb_array_elements(body#>'{data,professionals}') item where item->>'membership_id'='74000000-0000-4000-8000-000000000042')
      and not exists(select 1 from jsonb_array_elements(body#>'{data,permissions,professional_actions}') item where item->>'membership_id'='74000000-0000-4000-8000-000000000042') from hardening_results where label='detail_stale_professional')
 and (select status='draft' from public.activity_definitions where id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create')),
 'publish rejects taxonomy, units, groups, hierarchy/origin, broken participant/professional chains and exact-action failures without activation');

-- Required policy and explicit none is a contradiction; clearing the admin
-- action must also keep publish closed, and a non-draft never republishes.
with codes as(select value#>>'{}' code from jsonb_array_elements('["chat","now","happens","moments","attendance"]'))
insert into hardening_results select 'required_none',public.superadmin_activity_set_permissions_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),9,(select jsonb_object_agg(code,case when code='chat' then 'required' else null end) from codes),'[]',jsonb_build_array(jsonb_build_object('membership_id','74000000-0000-4000-8000-000000000042','role','instructor','group_id','74000000-0000-4000-8000-000000000013','actions',(select jsonb_object_agg(code,case when code='chat' then 'none' else 'both' end) from codes))));
select ok((select body#>>'{error,code}'='ACTIVITY_INVALID_INPUT' from hardening_results where label='required_none')
 and (select management_version=9 from public.activity_definitions where id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create')),
 'required-policy contradiction is rejected before changing the activity snapshot');
set local session_replication_role='replica';
insert into public.activity_capability_policies(activity_id,institution_id,capability_id,policy_mode,changed_by_person_id)
select (select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),'74000000-0000-4000-8000-000000000010',id,'required',null from public.activity_capabilities where code='chat';
insert into public.activity_group_capability_settings(activity_group_link_id,capability_id,is_enabled,changed_by_person_id)
select link.id,capability.id,false,null from public.activity_group_links link cross join public.activity_capabilities capability where link.activity_id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create') and capability.code='chat';
set local session_replication_role='origin';
insert into hardening_results select 'publish_policy_setting_conflict',public.superadmin_activity_publish_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),9);
set local session_replication_role='replica';
delete from public.activity_group_capability_settings where activity_group_link_id in(select id from public.activity_group_links where activity_id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'));
delete from public.activity_capability_policies where activity_id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create');
set local session_replication_role='origin';
select is((select body#>>'{error,code}' from hardening_results where label='publish_policy_setting_conflict'),'ACTIVITY_INVALID_STATE',
 'publish rejects a required policy contradicted by a disabled group setting');
update public.activity_definitions set status='active' where id=(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create');
insert into hardening_results select 'publish_non_draft',public.superadmin_activity_publish_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from hardening_results where label='create'),9);
select is((select body#>>'{error,code}' from hardening_results where label='publish_non_draft'),'ACTIVITY_INVALID_STATE','non-draft cannot be published again');

-- Negative activity calls have the same audit guarantee as spec 039: validated
-- session before internal identification is v3 auth_session; identified actors
-- retain the typed internal actor and no mutation receipt.
select set_config('request.jwt.claims',jsonb_build_object('sub','74000000-0000-4000-8000-000000000083','session_id','74000000-0000-4000-8000-000000000094','aal','aal2','role','authenticated')::text,true);
insert into hardening_results select 'session_only_denial',public.superadmin_activity_create_v2('74000000-0000-4000-8000-000000000280','{}');
select set_config('request.jwt.claims',jsonb_build_object('sub','74000000-0000-4000-8000-000000000081','session_id','74000000-0000-4000-8000-000000000091','aal','aal2','role','authenticated')::text,true);
update public.platform_permissions set status='inactive' where code='activities.create';
insert into hardening_results select 'identified_denial',public.superadmin_activity_create_v2('74000000-0000-4000-8000-000000000281','{}');
update public.platform_permissions set status='active' where code='activities.create';
select ok((select count(*)=1 from audit.audit_logs log_record where log_record.correlation_id=(select (body#>>'{error,correlation_id}')::uuid from hardening_results where label='session_only_denial') and log_record.actor_kind='auth_session' and log_record.outcome='denied' and log_record.actor_internal_identity_id is null and octet_length(log_record.session_id_hash)=32),
 'validated session-only denial appends one strict v3 auth_session audit');
select ok((select count(*)=1 from audit.audit_logs log_record where log_record.correlation_id=(select (body#>>'{error,correlation_id}')::uuid from hardening_results where label='identified_denial') and log_record.actor_kind='superadmin_internal' and log_record.outcome='denied' and log_record.actor_internal_identity_id='74000000-0000-4000-8000-000000000101'::uuid and log_record.actor_internal_auth_link_id='74000000-0000-4000-8000-000000000111'::uuid and log_record.actor_internal_membership_id='74000000-0000-4000-8000-000000000125'::uuid)
 and not exists(select 1 from app_private.superadmin_internal_activity_command_receipts receipt where receipt.request_id in('74000000-0000-4000-8000-000000000280','74000000-0000-4000-8000-000000000281')),
 'identified internal denial appends one typed v2 audit without a command receipt');

select * from finish();
rollback;
