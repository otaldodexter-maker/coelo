begin; create extension if not exists pgtap with schema extensions; select plan(13);
-- Synthetic tenant and identity fixtures. Everything rolls back.
insert into public.institution_types(id,code,name,status) values
 ('8d200000-0000-4000-8000-000000000001','assessment-v2','Assessment v2','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('8d200000-0000-4000-8000-000000000010','Assessment Tenant A','assessment-v2-a','active','8d200000-0000-4000-8000-000000000001'),
 ('8d200000-0000-4000-8000-000000000020','Assessment Tenant B','assessment-v2-b','active','8d200000-0000-4000-8000-000000000001');
-- Forma de producao: units.unit_type_id -> public.unit_types e handle NOT NULL.
insert into public.unit_types(id,code,name,status) values ('7c0000f0-0000-4000-8000-000000000901','superadmin-assessments-v2-test-u0','Tipo de unidade da fixture','active');
insert into public.units(id,institution_id,unit_type_id,name,slug,status,handle) values
 ('8d200000-0000-4000-8000-000000000011','8d200000-0000-4000-8000-000000000010','7c0000f0-0000-4000-8000-000000000901','Unidade A','assessment-v2-a-unit','active','u.000000000011'),
 ('8d200000-0000-4000-8000-000000000021','8d200000-0000-4000-8000-000000000020','7c0000f0-0000-4000-8000-000000000901','Unidade B','assessment-v2-b-unit','active','u.000000000021');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('8d200000-0000-4000-8000-000000000601','adult','Fixture','Creator','Fixture Creator','active'),
 ('8d200000-0000-4000-8000-000000000602','adult','People','Only','People Only','active'),
 ('8d200000-0000-4000-8000-000000000603','child','Aluno','Sintético','Aluno Sintético','active');

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
where role_record.code='owner' and permission_record.code in('activities.read','activities.manage','activities.create')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

-- Producao (cadeia de Atividades v2, 180020/180030) guarda a proveniencia do ator:
-- inserir definicoes de atividade direto exige o marcador interno com um contexto
-- valido, e o criador people-based fica nulo.
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8d200000-0000-4000-8000-000000000101','session_id','8d200000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8d200000-0000-4000-8000-000000000301','internal_auth_link_id','8d200000-0000-4000-8000-000000000401',
 'internal_membership_id','8d200000-0000-4000-8000-000000000501','auth_user_id','8d200000-0000-4000-8000-000000000101',
 'session_id','8d200000-0000-4000-8000-000000000201','permission_code','activities.create','action_code','create',
 'correlation_id',gen_random_uuid())::text,true);
insert into public.activity_definitions(
 id,institution_id,name,origin_scope_kind,created_by_person_id,status,handle_stem) values
 ('8d200000-0000-4000-8000-000000000701','8d200000-0000-4000-8000-000000000010','Activity A','institution',null,'active','assessment-activity-a'),
 ('8d200000-0000-4000-8000-000000000702','8d200000-0000-4000-8000-000000000020','Activity B','institution',null,'active','assessment-activity-b');
insert into public.groups(id,institution_id,unit_id,name,status) values
 ('8d200000-0000-4000-8000-000000000711','8d200000-0000-4000-8000-000000000010','8d200000-0000-4000-8000-000000000011','Turma A','active');
insert into public.activity_unit_links(
 id,activity_id,institution_id,unit_id,linked_by_person_id,status
) values (
 '8d200000-0000-4000-8000-000000000710','8d200000-0000-4000-8000-000000000701',
 '8d200000-0000-4000-8000-000000000010','8d200000-0000-4000-8000-000000000011',null,'active');
insert into public.activity_group_links(
 id,activity_id,institution_id,unit_id,group_id,linked_by_person_id,status
) values (
 '8d200000-0000-4000-8000-000000000712','8d200000-0000-4000-8000-000000000701',
 '8d200000-0000-4000-8000-000000000010','8d200000-0000-4000-8000-000000000011',
 '8d200000-0000-4000-8000-000000000711',null,'active');

insert into public.child_contexts(id,child_person_id,institution_id,status) values
 ('8d200000-0000-4000-8000-000000000720','8d200000-0000-4000-8000-000000000603','8d200000-0000-4000-8000-000000000010','active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
 ('8d200000-0000-4000-8000-000000000721','8d200000-0000-4000-8000-000000000720','8d200000-0000-4000-8000-000000000011','active','8d200000-0000-4000-8000-000000000601',now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status) values
 ('8d200000-0000-4000-8000-000000000722','8d200000-0000-4000-8000-000000000721','8d200000-0000-4000-8000-000000000711','active');
insert into public.activity_group_participants(
 id,activity_group_link_id,child_group_link_id,status,added_by_person_id
) values (
 '8d200000-0000-4000-8000-000000000723','8d200000-0000-4000-8000-000000000712',
 '8d200000-0000-4000-8000-000000000722','active',null);
select set_config('app_private.activity_v2_internal_marker','',true);

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8d200000-0000-4000-8000-000000000101','session_id','8d200000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);

create temporary table r11_payload as select '{"activity_id": "8d200000-0000-4000-8000-000000000701", "institution_id": "8d200000-0000-4000-8000-000000000010", "unit_id": "8d200000-0000-4000-8000-000000000011", "periodicity": "annual", "result_scale_kind": "numeric_0_10", "scale_options": {"step": 0.01}, "concepts": [], "periods": [{"name": "R08 sint\u00c3\u00a9tico", "ordinal": 1, "academic_year": 2026, "starts_on": "2026-09-12", "ends_on": "2026-12-31", "entry_closes_at": "2026-12-31T23:00:00.000Z", "family_release_at": "2026-12-31T23:00:00.000Z", "timezone": "America/Sao_Paulo", "status": "draft"}], "allow_final_override": false, "instruments": [{"name": "Instrumento R08", "weight": 100, "sort_order": 0}], "categories": []}'::jsonb as value;


delete from public.activity_group_participants where activity_group_link_id='8d200000-0000-4000-8000-000000000712';
select is(jsonb_array_length(app_private.assessment_v2_initial_students('8d200000-0000-4000-8000-000000000712')),1,'all mode includes eligible child without explicit participant');
create temporary table r11_active as select public.superadmin_assessment_save_configuration(gen_random_uuid(),null,0,value) body from r11_payload;
select public.superadmin_assessment_activate_configuration(gen_random_uuid(),(select (body#>>'{data,id}')::uuid from r11_active),1);
create temporary table r11_book as select public.superadmin_assessment_save_gradebook(gen_random_uuid(),null,0,jsonb_build_object(
 'activity_group_link_id','8d200000-0000-4000-8000-000000000712',
 'period_id',(select id from public.assessment_periods where configuration_id=(select (body#>>'{data,id}')::uuid from r11_active)),
 'configuration_id',(select body#>>'{data,id}' from r11_active),'students','[]'::jsonb),null) body;
update public.assessment_gradebooks set students_payload='[]' where id=(select (body#>>'{data,id}')::uuid from r11_book);
select is(jsonb_array_length(public.superadmin_assessment_gradebook_read((select (body#>>'{data,id}')::uuid from r11_book))#>'{data,students}'),1,'retained empty draft projects eligible child without recreating book');
create temporary table r11_students as select jsonb_build_array(jsonb_build_object(
 'child_context_id','8d200000-0000-4000-8000-000000000720','state','complete',
 'final_numeric_value',8,'instruments',jsonb_build_array(jsonb_build_object(
 'instrument_id',(select id from public.assessment_instruments where configuration_id=(select (body#>>'{data,id}')::uuid from r11_active)),
 'numeric_value',8,'absent',false)),'competencies','[]'::jsonb)) value;
create temporary table r11_book_update as select public.superadmin_assessment_save_gradebook(gen_random_uuid(),(select (body#>>'{data,id}')::uuid from r11_book),1,jsonb_build_object(
 'activity_group_link_id','8d200000-0000-4000-8000-000000000712',
 'period_id',(select id from public.assessment_periods where configuration_id=(select (body#>>'{data,id}')::uuid from r11_active)),
 'configuration_id',(select body#>>'{data,id}' from r11_active),'students',value),null) body from r11_students;
select is((select body->>'ok' from r11_book_update),'true','all-mode grade save succeeds on retained id');
select is(public.superadmin_assessment_gradebook_read((select (body#>>'{data,id}')::uuid from r11_book))#>>'{data,students,0,final_numeric_value}','8','saved grade survives independent read');
select is(public.superadmin_assessment_submit_gradebook(gen_random_uuid(),(select (body#>>'{data,id}')::uuid from r11_book),2,null)#>>'{data,status}','submitted','completed all-mode gradebook submits');
select is(public.superadmin_assessment_review_gradebook(gen_random_uuid(),(select (body#>>'{data,id}')::uuid from r11_book),3,null)#>>'{data,status}','reviewed','submitted gradebook closes review');
select is(public.superadmin_assessment_return_gradebook(gen_random_uuid(),(select (body#>>'{data,id}')::uuid from r11_book),4,'R11 ajuste sintético')#>>'{data,status}','draft','reviewed gradebook reopens with reason');
select is(public.superadmin_assessment_submit_gradebook(gen_random_uuid(),(select (body#>>'{data,id}')::uuid from r11_book),2,null)#>>'{error,code}','SAI_CONCURRENT_CHANGE','old version cannot close reopened gradebook');
update public.activity_group_links set participation_mode='selected' where id='8d200000-0000-4000-8000-000000000712';
select is(jsonb_array_length(app_private.assessment_v2_initial_students('8d200000-0000-4000-8000-000000000712')),0,'selected mode still excludes unselected child');
select throws_ok($$select app_private.assessment_v2_validate_students((select b from public.assessment_gradebooks b where id=(select (body#>>'{data,id}')::uuid from r11_book)),(select value from r11_students))$$,'22023',null,'selected mode rejects grade for unselected child');
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8d200000-0000-4000-8000-000000000301','internal_auth_link_id','8d200000-0000-4000-8000-000000000401',
 'internal_membership_id','8d200000-0000-4000-8000-000000000501','auth_user_id','8d200000-0000-4000-8000-000000000101',
 'session_id','8d200000-0000-4000-8000-000000000201','permission_code','activities.create','action_code','create',
 'correlation_id',gen_random_uuid())::text,true);
insert into public.activity_group_participants(activity_group_link_id,child_group_link_id,status) values ('8d200000-0000-4000-8000-000000000712','8d200000-0000-4000-8000-000000000722','active');
select is(jsonb_array_length(app_private.assessment_v2_initial_students('8d200000-0000-4000-8000-000000000712')),1,'selected active child is included');
update public.child_unit_links set status='inactive' where id='8d200000-0000-4000-8000-000000000721';
select is(jsonb_array_length(app_private.assessment_v2_initial_students('8d200000-0000-4000-8000-000000000712')),0,'inactive hierarchy excluded in selected mode');
update app_private.superadmin_internal_memberships set version=version+1, scope_institution_id='8d200000-0000-4000-8000-000000000020' where id='8d200000-0000-4000-8000-000000000502';
select set_config('request.jwt.claims',jsonb_build_object('sub','8d200000-0000-4000-8000-000000000102','session_id','8d200000-0000-4000-8000-000000000202','aal','aal2','role','authenticated')::text,true);
select ok(public.superadmin_assessment_gradebook_read((select (body#>>'{data,id}')::uuid from r11_book))->'data'='null'::jsonb,'other tenant actor cannot read book or dynamic students');
select * from finish(); rollback;
