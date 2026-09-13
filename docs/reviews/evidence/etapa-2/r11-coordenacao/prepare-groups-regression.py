from pathlib import Path
root=Path('C:/Users/adrie/Documents/Coelo')
source=(root/'packages/coelo_database/supabase/tests/superadmin_assessments_internal_v2_test.sql').read_text(encoding='utf-8-sig')
fixture=source[source.index('-- Synthetic tenant'):source.index('create temporary table assessment_context_result')]
sql="begin; create extension if not exists pgtap with schema extensions; select plan(10);\n"+fixture
sql+='''
insert into public.groups(id,institution_id,unit_id,name,status) values ('8d200000-0000-4000-8000-000000000719','8d200000-0000-4000-8000-000000000020','8d200000-0000-4000-8000-000000000021','Turma B','active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,scope_institution_id,mfa_required)
select '8d200000-0000-4000-8000-000000000602',id,'active','institution','8d200000-0000-4000-8000-000000000010',false from public.platform_roles where code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r cross join public.platform_permissions p where r.code='owner' and p.code='groups.read'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
select set_config('request.jwt.claims',jsonb_build_object('sub','8d200000-0000-4000-8000-000000000103','session_id','8d200000-0000-4000-8000-000000000203','aal','aal2','role','authenticated')::text,true);
set local role authenticated;
select is(jsonb_array_length(public.superadmin_group_directory()->'items'),1,'scoped actor sees no other tenant group or counters');
select is(public.superadmin_group_directory()#>>'{items,0,student_count}','1','active eligible child counted');
select is(jsonb_array_length(public.superadmin_group_directory()#>'{items,0,activity_ids}'),1,'active unit activity inherited');
select is(public.superadmin_group_directory(p_institution_ids=>array['8d200000-0000-4000-8000-000000000020'::uuid])->'items','[]'::jsonb,'foreign institution filter returns no data');
reset role;
update public.child_unit_links set status='inactive' where id='8d200000-0000-4000-8000-000000000721';
select is(public.superadmin_group_directory()#>>'{items,0,student_count}','0','inactive unit membership excluded');
update public.child_unit_links set status='active' where id='8d200000-0000-4000-8000-000000000721';
update public.activity_unit_links set status='inactive' where id='8d200000-0000-4000-8000-000000000710';
select is(jsonb_array_length(public.superadmin_group_directory()#>'{items,0,activity_ids}'),0,'ended unit activity excluded from inheritance');
update public.groups set inherit_activities=false where id='8d200000-0000-4000-8000-000000000711';
select is(jsonb_array_length(public.superadmin_group_directory()#>'{items,0,activity_ids}'),1,'local active group activity selected when inheritance disabled');
update public.activity_group_links set status='inactive' where id='8d200000-0000-4000-8000-000000000712';
select is(jsonb_array_length(public.superadmin_group_directory()#>'{items,0,activity_ids}'),0,'ended group activity excluded');
update public.child_group_links set status='inactive' where id='8d200000-0000-4000-8000-000000000722';
select is(public.superadmin_group_directory()#>>'{items,0,student_count}','0','inactive group membership excluded');
select set_config('request.jwt.claims','{}',true);
select throws_ok($$select public.superadmin_group_directory()$$,'42501','groups.read required','anonymous actor receives no directory');
select * from finish(); rollback;
'''
(root/'packages/coelo_database/candidatos/r11-estrutura/group-directory-counts-test.sql').write_text(sql,encoding='utf-8')
