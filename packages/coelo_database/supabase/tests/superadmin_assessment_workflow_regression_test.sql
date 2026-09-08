begin;

create extension if not exists pgtap with schema extensions;
select plan(35);

-- Independent spec-039 fixture. Seed-only trigger bypass is reset before every
-- gateway call; the workflow itself always executes through public RPCs.
set local session_replication_role = 'replica';

insert into public.institution_types(id,code,name,status) values
 ('8e200000-0000-4000-8000-000000000001','assessment-workflow','Assessment workflow','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('8e200000-0000-4000-8000-000000000010','Assessment Workflow A','assessment-workflow-a','active','8e200000-0000-4000-8000-000000000001'),
 ('8e200000-0000-4000-8000-000000000020','Assessment Workflow B','assessment-workflow-b','active','8e200000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,institution_type_id,name,slug,status) values
 ('8e200000-0000-4000-8000-000000000011','8e200000-0000-4000-8000-000000000010','8e200000-0000-4000-8000-000000000001','Unidade A','assessment-workflow-unit-a','active'),
 ('8e200000-0000-4000-8000-000000000021','8e200000-0000-4000-8000-000000000020','8e200000-0000-4000-8000-000000000001','Unidade B','assessment-workflow-unit-b','active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 ('8e200000-0000-4000-8000-000000000012','8e200000-0000-4000-8000-000000000010','8e200000-0000-4000-8000-000000000011','Turma A','active'),
 ('8e200000-0000-4000-8000-000000000022','8e200000-0000-4000-8000-000000000020','8e200000-0000-4000-8000-000000000021','Turma B','active');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('8e200000-0000-4000-8000-000000000031','adult','Operador','A','Operador A','active'),
 ('8e200000-0000-4000-8000-000000000032','adult','Operador','B','Operador B','active'),
 ('8e200000-0000-4000-8000-000000000041','child','Criança','A','Criança A','active'),
 ('8e200000-0000-4000-8000-000000000042','child','Criança','B','Criança B','active');
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 ('8e200000-0000-4000-8000-000000000051','8e200000-0000-4000-8000-000000000041','8e200000-0000-4000-8000-000000000010','active'),
 ('8e200000-0000-4000-8000-000000000052','8e200000-0000-4000-8000-000000000042','8e200000-0000-4000-8000-000000000020','active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
 ('8e200000-0000-4000-8000-000000000061','8e200000-0000-4000-8000-000000000051','8e200000-0000-4000-8000-000000000011','active','8e200000-0000-4000-8000-000000000031',now()),
 ('8e200000-0000-4000-8000-000000000062','8e200000-0000-4000-8000-000000000052','8e200000-0000-4000-8000-000000000021','active','8e200000-0000-4000-8000-000000000032',now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status,starts_at) values
 ('8e200000-0000-4000-8000-000000000071','8e200000-0000-4000-8000-000000000061','8e200000-0000-4000-8000-000000000012','active',now()-interval '1 day'),
 ('8e200000-0000-4000-8000-000000000072','8e200000-0000-4000-8000-000000000062','8e200000-0000-4000-8000-000000000022','active',now()-interval '1 day');

insert into public.activity_definitions(
 id,institution_id,name,origin_scope_kind,created_by_person_id,status,handle_stem,canonical_handle) values
 ('8e200000-0000-4000-8000-000000000101','8e200000-0000-4000-8000-000000000010','Atividade A','institution','8e200000-0000-4000-8000-000000000031','active','assessment-workflow-activity-a','assessment-workflow-activity-a.assessment-workflow-a'),
 ('8e200000-0000-4000-8000-000000000102','8e200000-0000-4000-8000-000000000020','Atividade B','institution','8e200000-0000-4000-8000-000000000032','active','assessment-workflow-activity-b','assessment-workflow-activity-b.assessment-workflow-b');
insert into public.activity_group_links(
 id,activity_id,institution_id,unit_id,group_id,linked_by_person_id,status) values
 ('8e200000-0000-4000-8000-000000000111','8e200000-0000-4000-8000-000000000101','8e200000-0000-4000-8000-000000000010','8e200000-0000-4000-8000-000000000011','8e200000-0000-4000-8000-000000000012','8e200000-0000-4000-8000-000000000031','active'),
 ('8e200000-0000-4000-8000-000000000112','8e200000-0000-4000-8000-000000000102','8e200000-0000-4000-8000-000000000020','8e200000-0000-4000-8000-000000000021','8e200000-0000-4000-8000-000000000022','8e200000-0000-4000-8000-000000000032','active');
insert into public.activity_group_participants(
 id,activity_group_link_id,child_group_link_id,status,added_by_person_id) values
 ('8e200000-0000-4000-8000-000000000121','8e200000-0000-4000-8000-000000000111','8e200000-0000-4000-8000-000000000071','active','8e200000-0000-4000-8000-000000000031'),
 ('8e200000-0000-4000-8000-000000000122','8e200000-0000-4000-8000-000000000112','8e200000-0000-4000-8000-000000000072','active','8e200000-0000-4000-8000-000000000032');

insert into public.activity_assessment_configurations(
 id,activity_id,institution_id,unit_id,periodicity,result_scale_kind,scale_options,status) values
 ('8e200000-0000-4000-8000-000000000201','8e200000-0000-4000-8000-000000000101','8e200000-0000-4000-8000-000000000010','8e200000-0000-4000-8000-000000000011','bimonthly','numeric_0_10','{"step":0.5}','active'),
 ('8e200000-0000-4000-8000-000000000202','8e200000-0000-4000-8000-000000000102','8e200000-0000-4000-8000-000000000020','8e200000-0000-4000-8000-000000000021','bimonthly','numeric_0_10','{"step":0.5}','active');
insert into public.assessment_instruments(id,configuration_id,name,weight,sort_order) values
 ('8e200000-0000-4000-8000-000000000211','8e200000-0000-4000-8000-000000000201','Nota',100,0),
 ('8e200000-0000-4000-8000-000000000212','8e200000-0000-4000-8000-000000000202','Nota',100,0);
insert into public.assessment_periods(
 id,configuration_id,institution_id,unit_id,name,periodicity,ordinal,academic_year,
 starts_on,ends_on,entry_closes_at,family_release_at,status) values
 ('8e200000-0000-4000-8000-000000000221','8e200000-0000-4000-8000-000000000201','8e200000-0000-4000-8000-000000000010','8e200000-0000-4000-8000-000000000011','Período A1','bimonthly',1,2027,'2027-01-01','2027-02-28','2027-03-01T12:00:00Z','2027-03-02T12:00:00Z','open'),
 ('8e200000-0000-4000-8000-000000000222','8e200000-0000-4000-8000-000000000201','8e200000-0000-4000-8000-000000000010','8e200000-0000-4000-8000-000000000011','Período A2','bimonthly',2,2027,'2027-03-01','2027-04-30','2027-05-01T12:00:00Z','2027-05-02T12:00:00Z','open'),
 ('8e200000-0000-4000-8000-000000000223','8e200000-0000-4000-8000-000000000201','8e200000-0000-4000-8000-000000000010','8e200000-0000-4000-8000-000000000011','Período A3','bimonthly',3,2027,'2027-05-01','2027-06-30','2027-07-01T12:00:00Z','2027-07-02T12:00:00Z','open'),
 ('8e200000-0000-4000-8000-000000000224','8e200000-0000-4000-8000-000000000202','8e200000-0000-4000-8000-000000000020','8e200000-0000-4000-8000-000000000021','Período B1','bimonthly',1,2027,'2027-01-01','2027-02-28','2027-03-01T12:00:00Z','2027-03-02T12:00:00Z','open');

-- Foreign reviewed book and same-tenant draft sentinel make queue/IDOR checks
-- independent from the workflow under test.
insert into public.assessment_gradebooks(
 id,institution_id,unit_id,activity_group_link_id,period_id,configuration_id,
 status,management_version,students_payload) values
 ('8e200000-0000-4000-8000-000000000231','8e200000-0000-4000-8000-000000000020','8e200000-0000-4000-8000-000000000021','8e200000-0000-4000-8000-000000000112','8e200000-0000-4000-8000-000000000224','8e200000-0000-4000-8000-000000000202','reviewed',4,'[]'),
 ('8e200000-0000-4000-8000-000000000232','8e200000-0000-4000-8000-000000000010','8e200000-0000-4000-8000-000000000011','8e200000-0000-4000-8000-000000000111','8e200000-0000-4000-8000-000000000223','8e200000-0000-4000-8000-000000000201','draft',1,'[]');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('8e200000-0000-4000-8000-000000000301','authenticated','authenticated','assessment-workflow-a@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('8e200000-0000-4000-8000-000000000311','8e200000-0000-4000-8000-000000000301',now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('8e200000-0000-4000-8000-000000000321');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('8e200000-0000-4000-8000-000000000331','8e200000-0000-4000-8000-000000000321','8e200000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_memberships(
 id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select '8e200000-0000-4000-8000-000000000341',
 '8e200000-0000-4000-8000-000000000321',role_record.id,
 'institution'::app_private.superadmin_internal_scope_kind,
 '8e200000-0000-4000-8000-000000000010'
from public.platform_roles role_record where role_record.code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='owner' and permission_record.code in('activities.read','activities.manage')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

set local session_replication_role = 'origin';
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8e200000-0000-4000-8000-000000000301',
 'session_id','8e200000-0000-4000-8000-000000000311',
 'aal','aal2','role','authenticated')::text,true);

create temporary table assessment_workflow_results(
 label text primary key,
 body jsonb not null
);

insert into assessment_workflow_results values ('create_1',
 public.superadmin_assessment_save_gradebook(
  '8e200000-0000-4000-8000-000000000401',null,0,
  jsonb_build_object(
   'activity_group_link_id','8e200000-0000-4000-8000-000000000111',
   'period_id','8e200000-0000-4000-8000-000000000221',
   'configuration_id','8e200000-0000-4000-8000-000000000201',
   'students','[]'::jsonb),null));
select ok((select body->>'ok'='true' and body#>>'{data,status}'='draft'
 and (body#>>'{data,version}')::bigint=1 from assessment_workflow_results where label='create_1'),
 'create starts one draft gradebook at version 1');
select is((select jsonb_array_length(students_payload) from public.assessment_gradebooks
 where id=(select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1')),
 1,'create derives the participant roster server-side');

insert into assessment_workflow_results values ('create_1_replay',
 public.superadmin_assessment_save_gradebook(
  '8e200000-0000-4000-8000-000000000401',null,0,
  jsonb_build_object(
   'activity_group_link_id','8e200000-0000-4000-8000-000000000111',
   'period_id','8e200000-0000-4000-8000-000000000221',
   'configuration_id','8e200000-0000-4000-8000-000000000201',
   'students','[]'::jsonb),null));
select ok((select (body#>>'{data,replayed}')::boolean from assessment_workflow_results
 where label='create_1_replay'),'same create request replays its receipt');
select is((select count(*) from app_private.superadmin_internal_assessment_command_receipts
 where request_id='8e200000-0000-4000-8000-000000000401'),1::bigint,
 'create replay stores exactly one receipt');

insert into assessment_workflow_results values ('save_1',
 public.superadmin_assessment_save_gradebook(
  '8e200000-0000-4000-8000-000000000402',
  (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1'),1,
  jsonb_build_object(
   'activity_group_link_id','8e200000-0000-4000-8000-000000000111',
   'period_id','8e200000-0000-4000-8000-000000000221',
   'configuration_id','8e200000-0000-4000-8000-000000000201',
   'students',jsonb_build_array(jsonb_build_object(
    'child_context_id','8e200000-0000-4000-8000-000000000051',
    'state','complete','final_numeric_value',8.5,
    'override_reason','','family_comment','Bom progresso','internal_note','Acompanhado',
    'instruments',jsonb_build_array(jsonb_build_object(
     'instrument_id','8e200000-0000-4000-8000-000000000211',
     'numeric_value',8.5,'absent',false)),
    'competencies','[]'::jsonb))),null));
select diag((select body::text from assessment_workflow_results where label='save_1'));
select ok((select body->>'ok'='true' and (body#>>'{data,version}')::bigint=2
 from assessment_workflow_results where label='save_1'),'draft save advances to version 2');
select ok((select students_payload#>>'{0,state}'='complete'
 and (students_payload#>>'{0,suggested_numeric_value}')::numeric=8.5
 from public.assessment_gradebooks
 where id=(select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1')),
 'save persists the resolved student and server-calculated score');

insert into assessment_workflow_results values ('stale_save',
 public.superadmin_assessment_save_gradebook(
  '8e200000-0000-4000-8000-000000000403',
  (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1'),1,
  jsonb_build_object(
   'activity_group_link_id','8e200000-0000-4000-8000-000000000111',
   'period_id','8e200000-0000-4000-8000-000000000221',
   'configuration_id','8e200000-0000-4000-8000-000000000201',
   'students','[]'::jsonb),null));
select is((select body#>>'{error,code}' from assessment_workflow_results where label='stale_save'),
 'SAI_CONCURRENT_CHANGE','stale edit is rejected');
select is((select management_version from public.assessment_gradebooks
 where id=(select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1')),
 2::bigint,'stale edit leaves the aggregate unchanged');

insert into assessment_workflow_results values ('submit_1',
 public.superadmin_assessment_submit_gradebook(
  '8e200000-0000-4000-8000-000000000404',
  (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1'),2,
  'Envio para fechamento'));
select ok((select body#>>'{data,status}'='submitted' and (body#>>'{data,version}')::bigint=3
 from assessment_workflow_results where label='submit_1'),'resolved draft submits at version 3');
select ok((select (public.superadmin_assessment_gradebook_read(
 (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1'))
 #>>'{data,gradebook,status}')='submitted'
 and (public.superadmin_assessment_gradebook_read(
 (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1'))
 #>>'{data,students,0,state}')='complete'),'authoritative read returns submitted state and roster');

insert into assessment_workflow_results values ('return_1',
 public.superadmin_assessment_return_gradebook(
  '8e200000-0000-4000-8000-000000000405',
  (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1'),3,
  'Reabrir para correção'));
select ok((select body#>>'{data,status}'='draft' and (body#>>'{data,version}')::bigint=4
 from assessment_workflow_results where label='return_1'),'return reopens the submitted gradebook as draft');

insert into assessment_workflow_results values ('save_1_again',
 public.superadmin_assessment_save_gradebook(
  '8e200000-0000-4000-8000-000000000406',
  (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1'),4,
  jsonb_build_object(
   'activity_group_link_id','8e200000-0000-4000-8000-000000000111',
   'period_id','8e200000-0000-4000-8000-000000000221',
   'configuration_id','8e200000-0000-4000-8000-000000000201',
   'students',jsonb_build_array(jsonb_build_object(
    'child_context_id','8e200000-0000-4000-8000-000000000051',
    'state','complete','final_numeric_value',9,
    'override_reason','','family_comment','Revisado','internal_note','Corrigido',
    'instruments',jsonb_build_array(jsonb_build_object(
     'instrument_id','8e200000-0000-4000-8000-000000000211',
     'numeric_value',9,'absent',false)),
    'competencies','[]'::jsonb))),
  'Correção após reabertura'));
select ok((select body->>'ok'='true' and (body#>>'{data,version}')::bigint=5
 from assessment_workflow_results where label='save_1_again'),'reopened gradebook accepts an audited correction');

insert into assessment_workflow_results values ('submit_1_again',
 public.superadmin_assessment_submit_gradebook(
  '8e200000-0000-4000-8000-000000000407',
  (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1'),5,
  'Novo envio'));
select ok((select body#>>'{data,status}'='submitted' and (body#>>'{data,version}')::bigint=6
 from assessment_workflow_results where label='submit_1_again'),'reopened gradebook can be submitted again');

insert into assessment_workflow_results values ('review_1',
 public.superadmin_assessment_review_gradebook(
  '8e200000-0000-4000-8000-000000000408',
  (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1'),6,
  'Revisão concluída'));
select ok((select body#>>'{data,status}'='reviewed' and (body#>>'{data,version}')::bigint=7
 from assessment_workflow_results where label='review_1'),'submitted gradebook reviews at version 7');

insert into assessment_workflow_results values ('schedule_1',
 public.superadmin_assessment_schedule_publication(
  '8e200000-0000-4000-8000-000000000409',
  (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1'),7,
  now()+interval '1 day','Publicação programada'));
select ok((select body#>>'{data,status}'='reviewed' and (body#>>'{data,version}')::bigint=8
 from assessment_workflow_results where label='schedule_1'),'reviewed gradebook schedules publication at version 8');
select ok((select publish_scheduled_at > now() from public.assessment_gradebooks
 where id=(select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1')),
 'scheduled timestamp persists');

insert into assessment_workflow_results values ('publish_1',
 public.superadmin_assessment_publish_gradebook(
  '8e200000-0000-4000-8000-000000000410',
  (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1'),8,
  'Publicação aprovada'));
select ok((select body#>>'{data,status}'='published' and (body#>>'{data,version}')::bigint=9
 from assessment_workflow_results where label='publish_1'),'reviewed gradebook publishes at version 9');
select ok((select status='published' and published_at is not null and publish_scheduled_at is null
 from public.assessment_gradebooks
 where id=(select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1')),
 'publication persists and clears the schedule');
select is((select jsonb_array_length(public.superadmin_assessment_gradebook_read(
 (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1'))
 #>'{data,events}')),9,'authoritative detail exposes the immutable workflow history');

insert into assessment_workflow_results values ('schedule_reused',
 public.superadmin_assessment_schedule_publication(
  '8e200000-0000-4000-8000-000000000409',
  (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_1'),7,
  now()+interval '2 days','Payload alterado'));
select is((select body#>>'{error,code}' from assessment_workflow_results where label='schedule_reused'),
 'ASSESSMENT_INVALID_INPUT','same request with changed scheduling intent is rejected');

insert into assessment_workflow_results values ('invalid_draft_review',
 public.superadmin_assessment_review_gradebook(
  '8e200000-0000-4000-8000-000000000411','8e200000-0000-4000-8000-000000000232',1,
  'Estado inválido'));
select is((select body#>>'{error,code}' from assessment_workflow_results where label='invalid_draft_review'),
 'ASSESSMENT_INVALID_STATE','draft cannot skip submission and enter review');
select ok((select status='draft' and management_version=1 from public.assessment_gradebooks
 where id='8e200000-0000-4000-8000-000000000232'),'invalid transition leaves draft unchanged');

-- A second nominal workflow remains reviewed so a late audit/event failure can
-- prove atomic rollback without affecting the published workflow above.
insert into assessment_workflow_results values ('create_2',
 public.superadmin_assessment_save_gradebook(
  '8e200000-0000-4000-8000-000000000420',null,0,
  jsonb_build_object(
   'activity_group_link_id','8e200000-0000-4000-8000-000000000111',
   'period_id','8e200000-0000-4000-8000-000000000222',
   'configuration_id','8e200000-0000-4000-8000-000000000201',
   'students','[]'::jsonb),null));
select ok((select body->>'ok'='true' from assessment_workflow_results where label='create_2'),
 'second gradebook is created for rollback proof');

insert into assessment_workflow_results values ('save_2',
 public.superadmin_assessment_save_gradebook(
  '8e200000-0000-4000-8000-000000000421',
  (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_2'),1,
  jsonb_build_object(
   'activity_group_link_id','8e200000-0000-4000-8000-000000000111',
   'period_id','8e200000-0000-4000-8000-000000000222',
   'configuration_id','8e200000-0000-4000-8000-000000000201',
   'students',jsonb_build_array(jsonb_build_object(
    'child_context_id','8e200000-0000-4000-8000-000000000051',
    'state','absent','override_reason','','family_comment','','internal_note','',
    'instruments','[]'::jsonb,'competencies','[]'::jsonb))),null));
select ok((select body->>'ok'='true' and (body#>>'{data,version}')::bigint=2
 from assessment_workflow_results where label='save_2'),'second gradebook resolves an absent student');

insert into assessment_workflow_results values ('submit_2',
 public.superadmin_assessment_submit_gradebook(
  '8e200000-0000-4000-8000-000000000422',
  (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_2'),2,
  'Envio dois'));
select ok((select body#>>'{data,status}'='submitted' from assessment_workflow_results where label='submit_2'),
 'second gradebook submits');
insert into assessment_workflow_results values ('review_2',
 public.superadmin_assessment_review_gradebook(
  '8e200000-0000-4000-8000-000000000423',
  (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_2'),3,
  'Revisão dois'));
select ok((select body#>>'{data,status}'='reviewed' and (body#>>'{data,version}')::bigint=4
 from assessment_workflow_results where label='review_2'),'second gradebook reaches reviewed version 4');

create function pg_temp.fail_assessment_publish_event()
returns trigger language plpgsql as $$
begin
  if new.event_kind='published' and
     new.gradebook_id=(select (body#>>'{data,id}')::uuid
       from assessment_workflow_results where label='create_2') then
    raise exception 'assessment workflow forced late failure';
  end if;
  return new;
end $$;
create trigger assessment_workflow_fail_publish
before insert on app_private.superadmin_internal_assessment_events
for each row execute function pg_temp.fail_assessment_publish_event();

insert into assessment_workflow_results values ('publish_2_failed',
 public.superadmin_assessment_publish_gradebook(
  '8e200000-0000-4000-8000-000000000424',
  (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_2'),4,
  'Falha tardia'));
select is((select body#>>'{error,code}' from assessment_workflow_results where label='publish_2_failed'),
 'SAI_INTERNAL_ERROR','late event failure is returned as a stable internal error');
select ok((select status='reviewed' and management_version=4 from public.assessment_gradebooks
 where id=(select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_2')),
 'late failure rolls the aggregate status and version back');
select is((select count(*) from app_private.superadmin_internal_assessment_command_receipts
 where request_id='8e200000-0000-4000-8000-000000000424'),0::bigint,
 'late failure leaves no command receipt');
select is((select count(*) from app_private.superadmin_internal_assessment_events
 where gradebook_id=(select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_2')
 and event_kind='published'),0::bigint,'late failure leaves no published event');
drop trigger assessment_workflow_fail_publish on app_private.superadmin_internal_assessment_events;

select ok((select body#>'{data}' = jsonb_build_array(jsonb_build_object(
 'id',(select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_2'),
 'status','reviewed','version',4,'institution_name','Assessment Workflow A',
 'unit_name','Unidade A','group_name','Turma A','activity_name','Atividade A',
 'period_name','Período A2','pending_count',0))
 from (select public.superadmin_assessment_closing_queue() body) queue),
 'closing queue includes reviewed work and excludes drafts, published books, and tenant B');

insert into assessment_workflow_results values ('cross_tenant_publish',
 public.superadmin_assessment_publish_gradebook(
  '8e200000-0000-4000-8000-000000000430','8e200000-0000-4000-8000-000000000231',4,
  'Tentativa B'));
select is((select body#>>'{error,code}' from assessment_workflow_results where label='cross_tenant_publish'),
 'SAI_PERMISSION_DENIED','institution-scoped actor cannot mutate tenant B by ID');
select ok((select status='reviewed' and management_version=4 from public.assessment_gradebooks
 where id='8e200000-0000-4000-8000-000000000231'),'cross-tenant denial leaves tenant B unchanged');

update app_private.superadmin_internal_memberships
set status='revoked',revoked_at=now(),version=version+1
where id='8e200000-0000-4000-8000-000000000341';
select is((select public.superadmin_assessment_gradebook_read(
 (select (body#>>'{data,id}')::uuid from assessment_workflow_results where label='create_2'))
 #>>'{error,code}'),'SAI_MEMBERSHIP_REVOKED','revoked actor loses read access immediately');
select is((select count(*) from app_private.superadmin_internal_assessment_command_receipts
 where request_id='8e200000-0000-4000-8000-000000000430'),0::bigint,
 'denied cross-tenant command never creates a receipt');

select * from finish();
rollback;
