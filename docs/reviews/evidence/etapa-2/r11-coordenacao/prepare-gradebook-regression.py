from pathlib import Path
root=Path('C:/Users/adrie/Documents/Coelo')
source=(root/'packages/coelo_database/candidatos/r11-estrutura/assessment-update-isolation-test.sql').read_text(encoding='utf-8')
fixture=source[:source.index('create temporary table r11_active')].replace('select plan(8)','select plan(13)')
fixture+='''
delete from public.activity_group_participants where activity_group_link_id='8d200000-0000-4000-8000-000000000712';
select is(jsonb_array_length(app_private.assessment_v2_initial_students('8d200000-0000-4000-8000-000000000712')),1,'all mode includes eligible child without explicit participant');
'''
setup=source[source.index('create temporary table r11_active'):source.index('create temporary table r11_draft')]
setup='\n'.join(line for line in setup.splitlines() if not line.startswith('select is('))
sql=fixture+setup+'''
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
insert into public.activity_group_participants(activity_group_link_id,child_group_link_id,status) values ('8d200000-0000-4000-8000-000000000712','8d200000-0000-4000-8000-000000000722','active');
select is(jsonb_array_length(app_private.assessment_v2_initial_students('8d200000-0000-4000-8000-000000000712')),1,'selected active child is included');
update public.child_unit_links set status='inactive' where id='8d200000-0000-4000-8000-000000000721';
select is(jsonb_array_length(app_private.assessment_v2_initial_students('8d200000-0000-4000-8000-000000000712')),0,'inactive hierarchy excluded in selected mode');
update app_private.superadmin_internal_memberships set version=version+1, scope_institution_id='8d200000-0000-4000-8000-000000000020' where id='8d200000-0000-4000-8000-000000000502';
select set_config('request.jwt.claims',jsonb_build_object('sub','8d200000-0000-4000-8000-000000000102','session_id','8d200000-0000-4000-8000-000000000202','aal','aal2','role','authenticated')::text,true);
select ok(public.superadmin_assessment_gradebook_read((select (body#>>'{data,id}')::uuid from r11_book))->'data'='null'::jsonb,'other tenant actor cannot read book or dynamic students');
select * from finish(); rollback;
'''
(root/'packages/coelo_database/candidatos/r11-estrutura/gradebook-all-participants-test.sql').write_text(sql,encoding='utf-8')
