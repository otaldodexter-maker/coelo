begin;
create extension if not exists pgtap with schema extensions;
select plan(24);
select has_function('public','superadmin_activity_set_participants_v2',array['uuid','uuid','bigint','jsonb'],'participant snapshot exists');
select has_function('public','superadmin_activity_set_professionals_v2',array['uuid','uuid','bigint','jsonb'],'professional snapshot exists');
select ok(not has_function_privilege('authenticated','public.superadmin_activity_set_participants_v2(uuid,uuid,bigint,jsonb)','execute'),'Task3 exposes no intermediate authenticated grant');
select ok(not has_function_privilege('service_role','public.superadmin_activity_set_professionals_v2(uuid,uuid,bigint,jsonb)','execute'),'service role cannot call professional gateway');

insert into public.institution_types(id,code,name,status) values('73000000-0000-4000-8000-000000000009','activity-v2-rel','Activity v2 relationship','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('73000000-0000-4000-8000-000000000001','Activity Tenant A','activity-v2-a','active','73000000-0000-4000-8000-000000000009'),
 ('73000000-0000-4000-8000-000000000002','Activity Tenant B','activity-v2-b','active','73000000-0000-4000-8000-000000000009');
insert into public.units(id,institution_id,name,slug,status,institution_type_id) values
 ('73000000-0000-4000-8000-000000000011','73000000-0000-4000-8000-000000000001','Unit A','activity-v2-unit-a','active','73000000-0000-4000-8000-000000000009'),
 ('73000000-0000-4000-8000-000000000012','73000000-0000-4000-8000-000000000002','Unit B','activity-v2-unit-b','active','73000000-0000-4000-8000-000000000009');
insert into public.groups(id,institution_id,unit_id,name,group_type,status) values
 ('73000000-0000-4000-8000-000000000021','73000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000011','Group A','class','active'),
 ('73000000-0000-4000-8000-000000000022','73000000-0000-4000-8000-000000000002','73000000-0000-4000-8000-000000000012','Group B','class','active');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('73000000-0000-4000-8000-000000000031','adult','Professional','Alpha','Professional Alpha','active'),
 ('73000000-0000-4000-8000-000000000032','adult','Professional','Bravo','Professional Bravo','active'),
 ('73000000-0000-4000-8000-000000000033','child','Child','Alpha','Child Alpha','active'),
 ('73000000-0000-4000-8000-000000000034','child','Child','Bravo','Child Bravo','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind,revoked_at) values
 ('73000000-0000-4000-8000-000000000041','73000000-0000-4000-8000-000000000031','73000000-0000-4000-8000-000000000001','instructor','active','institution',null),
 ('73000000-0000-4000-8000-000000000042','73000000-0000-4000-8000-000000000032','73000000-0000-4000-8000-000000000002','instructor','active','institution',null);
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 ('73000000-0000-4000-8000-000000000051','73000000-0000-4000-8000-000000000033','73000000-0000-4000-8000-000000000001','active'),
 ('73000000-0000-4000-8000-000000000052','73000000-0000-4000-8000-000000000034','73000000-0000-4000-8000-000000000002','active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
 ('73000000-0000-4000-8000-000000000061','73000000-0000-4000-8000-000000000051','73000000-0000-4000-8000-000000000011','active','73000000-0000-4000-8000-000000000031',now()),
 ('73000000-0000-4000-8000-000000000062','73000000-0000-4000-8000-000000000052','73000000-0000-4000-8000-000000000012','active','73000000-0000-4000-8000-000000000032',now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status,starts_at) values
 ('73000000-0000-4000-8000-000000000071','73000000-0000-4000-8000-000000000061','73000000-0000-4000-8000-000000000021','active',now()-interval '1 day'),
 ('73000000-0000-4000-8000-000000000072','73000000-0000-4000-8000-000000000062','73000000-0000-4000-8000-000000000022','active',now()-interval '1 day');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values('73000000-0000-4000-8000-000000000081','authenticated','authenticated','activity-v2-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values('73000000-0000-4000-8000-000000000082','73000000-0000-4000-8000-000000000081',now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values('73000000-0000-4000-8000-000000000083');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
values('73000000-0000-4000-8000-000000000084','73000000-0000-4000-8000-000000000083','73000000-0000-4000-8000-000000000081');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '73000000-0000-4000-8000-000000000085','73000000-0000-4000-8000-000000000083',id,'platform' from public.platform_roles where code='owner';
select set_config('request.jwt.claims',jsonb_build_object('sub','73000000-0000-4000-8000-000000000081','session_id','73000000-0000-4000-8000-000000000082','aal','aal2','role','authenticated')::text,true);

create temporary table activity_v2_rel_result(kind text primary key,body jsonb);
insert into activity_v2_rel_result values('create',public.superadmin_activity_create_v2('73000000-0000-4000-8000-000000000091',jsonb_build_object('institution_id','73000000-0000-4000-8000-000000000001','name','Synthetic Activity','description','Synthetic only','taxonomy_id',(select id from public.activity_taxonomies where code='musica'),'icon_key','music_note','initials','SA','unit_ids',jsonb_build_array('73000000-0000-4000-8000-000000000011'))));
select ok((select (body->>'ok')::boolean from activity_v2_rel_result where kind='create'),'real internal Owner creates tenant A draft');
insert into activity_v2_rel_result values('groups',public.superadmin_activity_set_groups_v2('73000000-0000-4000-8000-000000000092',(select (body#>>'{data,activity_id}')::uuid from activity_v2_rel_result where kind='create'),1,array['73000000-0000-4000-8000-000000000021'::uuid],jsonb_build_object('73000000-0000-4000-8000-000000000021','selected')));
select ok((select (body->>'ok')::boolean and (body#>>'{data,management_version}')::bigint=2 from activity_v2_rel_result where kind='groups'),'real group snapshot links tenant A selected group');
insert into activity_v2_rel_result values('participants',public.superadmin_activity_set_participants_v2('73000000-0000-4000-8000-000000000093',(select (body#>>'{data,activity_id}')::uuid from activity_v2_rel_result where kind='create'),2,jsonb_build_array(jsonb_build_object('group_id','73000000-0000-4000-8000-000000000021','child_group_link_id','73000000-0000-4000-8000-000000000071','belongs',true))));
select ok((select (body->>'ok')::boolean and (body#>>'{data,management_version}')::bigint=3 from activity_v2_rel_result where kind='participants'),'canonical child snapshot increments once');
select is((select count(*) from public.activity_group_participants where child_group_link_id='73000000-0000-4000-8000-000000000071' and status='active'),1::bigint,'participant persists once');
insert into activity_v2_rel_result values('participants_replay',public.superadmin_activity_set_participants_v2('73000000-0000-4000-8000-000000000093',(select (body#>>'{data,activity_id}')::uuid from activity_v2_rel_result where kind='create'),2,jsonb_build_array(jsonb_build_object('group_id','73000000-0000-4000-8000-000000000021','child_group_link_id','73000000-0000-4000-8000-000000000071','belongs',true))));
select ok((select (body#>>'{data,replayed}')::boolean from activity_v2_rel_result where kind='participants_replay'),'same request replays');
select is((select management_version from public.activity_definitions where id=(select (body#>>'{data,activity_id}')::uuid from activity_v2_rel_result where kind='create')),3::bigint,'replay does not bump version');
select is((select count(*) from app_private.superadmin_internal_activity_command_receipts where request_id='73000000-0000-4000-8000-000000000093'),1::bigint,'replay stores one receipt');
insert into activity_v2_rel_result values('participant_b',public.superadmin_activity_set_participants_v2('73000000-0000-4000-8000-000000000094',(select (body#>>'{data,activity_id}')::uuid from activity_v2_rel_result where kind='create'),3,jsonb_build_array(jsonb_build_object('group_id','73000000-0000-4000-8000-000000000021','child_group_link_id','73000000-0000-4000-8000-000000000072','belongs',true))));
select is((select body#>>'{error,code}' from activity_v2_rel_result where kind='participant_b'),'ACTIVITY_INVALID_INPUT','tenant B child denied');
select is((select count(*) from public.activity_group_participants where child_group_link_id='73000000-0000-4000-8000-000000000072'),0::bigint,'tenant B child not persisted');
insert into activity_v2_rel_result values('professionals',public.superadmin_activity_set_professionals_v2('73000000-0000-4000-8000-000000000095',(select (body#>>'{data,activity_id}')::uuid from activity_v2_rel_result where kind='create'),3,jsonb_build_array(jsonb_build_object('membership_id','73000000-0000-4000-8000-000000000041','role','instructor','group_id','73000000-0000-4000-8000-000000000021'))));
select ok((select (body->>'ok')::boolean and (body#>>'{data,management_version}')::bigint=4 from activity_v2_rel_result where kind='professionals'),'active tenant A adult assigned');
select is((select count(*) from public.activity_group_assignments where membership_id='73000000-0000-4000-8000-000000000041' and status='active'),1::bigint,'instructor persisted');
with codes as(select value#>>'{}' code from jsonb_array_elements('["chat","now","happens","moments","attendance"]'))
insert into activity_v2_rel_result select 'professional_actions',public.superadmin_activity_set_permissions_v2('73000000-0000-4000-8000-000000000099',(select (body#>>'{data,activity_id}')::uuid from activity_v2_rel_result where kind='create'),4,(select jsonb_object_agg(code,null) from codes),'[]',jsonb_build_array(jsonb_build_object('membership_id','73000000-0000-4000-8000-000000000041','role','instructor','group_id','73000000-0000-4000-8000-000000000021','actions',(select jsonb_object_agg(code,'both') from codes))));
insert into activity_v2_rel_result values('professional_b',public.superadmin_activity_set_professionals_v2('73000000-0000-4000-8000-000000000096',(select (body#>>'{data,activity_id}')::uuid from activity_v2_rel_result where kind='create'),5,jsonb_build_array(jsonb_build_object('membership_id','73000000-0000-4000-8000-000000000042','role','instructor','group_id','73000000-0000-4000-8000-000000000021'))));
select is((select body#>>'{error,code}' from activity_v2_rel_result where kind='professional_b'),'ACTIVITY_INVALID_INPUT','tenant B professional denied');
select is((select count(*) from public.activity_group_assignments where membership_id='73000000-0000-4000-8000-000000000042'),0::bigint,'tenant B professional not persisted');
insert into activity_v2_rel_result values('clear',public.superadmin_activity_set_professionals_v2('73000000-0000-4000-8000-000000000097',(select (body#>>'{data,activity_id}')::uuid from activity_v2_rel_result where kind='create'),5,'[]'));
select ok((select (body->>'ok')::boolean from activity_v2_rel_result where kind='clear'),'empty snapshot softly revokes');
select ok((select status<>'active' and revoked_at is not null from public.activity_group_assignments where membership_id='73000000-0000-4000-8000-000000000041'),'revoked assignment preserved');
insert into activity_v2_rel_result values('reactivate',public.superadmin_activity_set_professionals_v2('73000000-0000-4000-8000-000000000098',(select (body#>>'{data,activity_id}')::uuid from activity_v2_rel_result where kind='create'),6,jsonb_build_array(jsonb_build_object('membership_id','73000000-0000-4000-8000-000000000041','role','instructor','group_id','73000000-0000-4000-8000-000000000021'))));
select ok((select (body->>'ok')::boolean from activity_v2_rel_result where kind='reactivate'),'return creates a new assignment instead of reactivating history');
insert into activity_v2_rel_result values('unknown_false',public.superadmin_activity_set_participants_v2('73000000-0000-4000-8000-000000000100',(select (body#>>'{data,activity_id}')::uuid from activity_v2_rel_result where kind='create'),7,jsonb_build_array(jsonb_build_object('group_id','73000000-0000-4000-8000-000000000021','child_group_link_id','73000000-0000-4000-8000-000000000071','belongs',true),jsonb_build_object('group_id','73000000-0000-4000-8000-ffffffffffff','child_group_link_id','73000000-0000-4000-8000-eeeeeeeeeeee','belongs',false))));
select ok((select count(*)=2 and count(*) filter(where status='active')=1 and count(*) filter(where revoked_at is not null)=1 from public.activity_group_assignments where membership_id='73000000-0000-4000-8000-000000000041') and (select count(*)=0 from public.activity_assignment_capability_actions actions join public.activity_group_assignments assignment on assignment.id=actions.assignment_id where assignment.membership_id='73000000-0000-4000-8000-000000000041' and assignment.status='active') and (select count(*)=5 from public.activity_assignment_capability_actions actions join public.activity_group_assignments assignment on assignment.id=actions.assignment_id where assignment.membership_id='73000000-0000-4000-8000-000000000041' and assignment.status<>'active') and (select (body->>'ok')::boolean from activity_v2_rel_result where kind='unknown_false') and not exists(select 1 from public.activity_group_participants where child_group_link_id='73000000-0000-4000-8000-eeeeeeeeeeee'),'new assignment has no historical actions and unknown belongs=false is a tombstone-free no-op');
select set_config('request.jwt.claims',jsonb_build_object('sub','73000000-0000-4000-8000-000000000081','session_id','73000000-0000-4000-8000-000000000082','aal','aal1','role','authenticated')::text,true);
insert into activity_v2_rel_result values('aal1',public.superadmin_activity_set_participants_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from activity_v2_rel_result where kind='create'),8,'[]'));
select is((select body#>>'{error,code}' from activity_v2_rel_result where kind='aal1'),'SAI_MFA_REQUIRED','Owner AAL1 denied');
update auth.sessions set not_after=now()-interval '1 minute' where id='73000000-0000-4000-8000-000000000082';
select set_config('request.jwt.claims',jsonb_build_object('sub','73000000-0000-4000-8000-000000000081','session_id','73000000-0000-4000-8000-000000000082','aal','aal2','role','authenticated')::text,true);
insert into activity_v2_rel_result values('expired',public.superadmin_activity_set_participants_v2(gen_random_uuid(),(select (body#>>'{data,activity_id}')::uuid from activity_v2_rel_result where kind='create'),8,'[]'));
select is((select body#>>'{error,code}' from activity_v2_rel_result where kind='expired'),'SAI_SESSION_INVALID','expired session denied');
select is((select management_version from public.activity_definitions where id=(select (body#>>'{data,activity_id}')::uuid from activity_v2_rel_result where kind='create')),8::bigint,'rejected commands leave version unchanged');
select * from finish();
rollback;
