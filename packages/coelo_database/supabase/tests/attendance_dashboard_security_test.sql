begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

select has_function(
  'public', 'attendance_dashboard_access', array[]::text[],
  'dashboard access is resolved by the backend'
);
select has_function(
  'public', 'attendance_dashboard_read',
  array['date','date','text','uuid','uuid','uuid','uuid','uuid','text','text[]','uuid','text','boolean','integer','integer','text'],
  'dashboard snapshot has a typed server-side contract'
);
select has_function(
  'public', 'attendance_dashboard_ranking_page',
  array['date','date','uuid','uuid','uuid','uuid','uuid','text','text','integer','integer'],
  'full ranking remains paginated server side'
);
select has_function(
  'public', 'attendance_dashboard_request_export',
  array['uuid','text','text','jsonb'],
  'attendance export creates an audited server job'
);
select ok(
  exists(select 1 from public.platform_permissions where code='attendance.export' and status='active'),
  'attendance export uses an explicit capability'
);
select ok(
  not exists(
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname like 'attendance_dashboard_%'
      and has_function_privilege('anon',p.oid,'EXECUTE')
  ),
  'anonymous callers cannot execute dashboard RPCs'
);
select ok(
  not has_function_privilege('authenticated','app_private.attendance_dashboard_read(date,date,text,uuid,uuid,uuid,uuid,uuid,text,text[],uuid,text,boolean,integer,integer,text)','EXECUTE'),
  'authenticated callers cannot bypass the public wrapper'
);
select ok(
  pg_get_functiondef('app_private.attendance_dashboard_read(date,date,text,uuid,uuid,uuid,uuid,uuid,text,text[],uuid,text,boolean,integer,integer,text)'::regprocedure)
    like '%can_access_attendance_child%',
  'every dashboard session is restricted through the attendance authorization helper'
);
select ok(
  pg_get_functiondef('app_private.attendance_dashboard_read(date,date,text,uuid,uuid,uuid,uuid,uuid,text,text[],uuid,text,boolean,integer,integer,text)'::regprocedure)
    like '%closed%'
  and pg_get_functiondef('app_private.attendance_dashboard_read(date,date,text,uuid,uuid,uuid,uuid,uuid,text,text[],uuid,text,boolean,integer,integer,text)'::regprocedure)
    like '%corrected%'
  and pg_get_functiondef('app_private.attendance_dashboard_read(date,date,text,uuid,uuid,uuid,uuid,uuid,text,text[],uuid,text,boolean,integer,integer,text)'::regprocedure)
    like '%record.status=''active''%',
  'presence only uses official closed or corrected calls'
);
select ok(
  exists(select 1 from pg_indexes where schemaname='public' and indexname='attendance_sessions_dashboard_scope_date_idx')
  and exists(select 1 from pg_indexes where schemaname='public' and indexname='attendance_records_dashboard_active_idx'),
  'dashboard filters and official records have supporting indexes'
);
select ok(
  has_function_privilege('authenticated','public.attendance_dashboard_access()','EXECUTE')
  and has_function_privilege('authenticated','public.attendance_dashboard_read(date,date,text,uuid,uuid,uuid,uuid,uuid,text,text[],uuid,text,boolean,integer,integer,text)','EXECUTE'),
  'only public wrappers are granted to authenticated callers'
);
select ok(
  pg_get_functiondef('app_private.attendance_dashboard_read(date,date,text,uuid,uuid,uuid,uuid,uuid,text,text[],uuid,text,boolean,integer,integer,text)'::regprocedure)
    like '%record.child_context_id%can_access_attendance_child%',
  'guardian aggregates authorize each child record instead of the whole class'
);
select ok(
  pg_get_functiondef('app_private.attendance_dashboard_ranking_page(date,date,uuid,uuid,uuid,uuid,uuid,text,text,integer,integer)'::regprocedure)
    like '%scope_name=''guardian''%'
  and pg_get_functiondef('app_private.attendance_dashboard_ranking_page(date,date,uuid,uuid,uuid,uuid,uuid,text,text,integer,integer)'::regprocedure)
    like '%p_kind<>''students''%',
  'guardian cannot request institutional or professional rankings'
);
select ok(
  pg_get_functiondef('app_private.attendance_dashboard_request_export(uuid,text,text,jsonb)'::regprocedure)
    like '%access_payload%can_export%'
  and pg_get_functiondef('app_private.attendance_dashboard_request_export(uuid,text,text,jsonb)'::regprocedure)
    like '%scope_name=''unit''%unit_id is distinct from%',
  'unit export uses its resolved backend capability and fixed unit scope'
);
select ok(
  pg_get_functiondef('app_private.attendance_dashboard_request_export(uuid,text,text,jsonb)'::regprocedure)
    like '%unknown attendance export filter%'
  and pg_get_functiondef('app_private.attendance_dashboard_request_export(uuid,text,text,jsonb)'::regprocedure)
    like '%attendance export group mismatch%'
  and pg_get_functiondef('app_private.attendance_dashboard_request_export(uuid,text,text,jsonb)'::regprocedure)
    like '%child outside attendance export scope%',
  'export rejects unknown, cross-hierarchy and unauthorized child filters'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000099',true);
select throws_ok(
  $$select public.attendance_dashboard_access()$$,
  '42501','authentication required',
  'an unmapped authenticated user cannot discover attendance scope'
);
reset role;

insert into auth.users(id,aud,role,email,created_at,updated_at) values
  ('90000000-0000-4000-8000-000000000001','authenticated','authenticated','attendance-assignment@test.invalid',now(),now()),
  ('90000000-0000-4000-8000-000000000002','authenticated','authenticated','attendance-unit@test.invalid',now(),now());
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('90100000-0000-4000-8000-000000000001','adult','Attendance','Assignment','Attendance Assignment','active'),
  ('90100000-0000-4000-8000-000000000002','adult','Attendance','Unit','Attendance Unit','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
  ('90100000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001','active'),
  ('90100000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000002','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('91000000-0000-4000-8000-000000000001','Attendance Real','Attendance Real','attendance-real','active');
insert into public.units(id,institution_id,name,slug,unit_type_id,unit_type_other_description,handle) values
  ('92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','Attendance Unit','attendance-unit',
   (select id from public.unit_types where status='active' order by id limit 1),'Unidade de teste','attendance.unit');
insert into public.groups(id,institution_id,unit_id,name,group_type,status) values
  ('93000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','Assigned group','class','active'),
  ('93000000-0000-4000-8000-000000000099','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','Unassigned group','class','active');
insert into public.activity_definitions(
  id,institution_id,name,origin_scope_kind,created_by_person_id,handle_stem,status
) values
  ('94000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','Assigned activity','institution','90100000-0000-4000-8000-000000000002','assigned-activity','active'),
  ('94000000-0000-4000-8000-000000000099','91000000-0000-4000-8000-000000000001','Unassigned activity','institution','90100000-0000-4000-8000-000000000002','unassigned-activity','active');
insert into public.activity_unit_links(activity_id,institution_id,unit_id,linked_by_person_id,status) values
  ('94000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','90100000-0000-4000-8000-000000000002','active'),
  ('94000000-0000-4000-8000-000000000099','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','90100000-0000-4000-8000-000000000002','active');
insert into public.activity_group_links(
  id,activity_id,institution_id,unit_id,group_id,linked_by_person_id,status
) values
  ('94100000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001','90100000-0000-4000-8000-000000000002','active'),
  ('94100000-0000-4000-8000-000000000099','94000000-0000-4000-8000-000000000099','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000099','90100000-0000-4000-8000-000000000002','inactive');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind,scope_unit_id,scope_group_id) values
  ('95000000-0000-4000-8000-000000000001','90100000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','attendance-assignment','active','group','92000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001'),
  ('95000000-0000-4000-8000-000000000002','90100000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000001','attendance-unit','active','unit','92000000-0000-4000-8000-000000000001',null);
insert into public.institution_roles(id,institution_id,code,name,status,is_system,max_scope_kind) values
  ('95100000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','attendance-assignment','Attendance assignment','active',false,'group'),
  ('95100000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000001','attendance-unit','Attendance unit','active',false,'unit');
insert into public.institution_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.institution_roles role_record
cross join public.institution_permissions permission_record
where role_record.id in(
    '95100000-0000-4000-8000-000000000001','95100000-0000-4000-8000-000000000002'
  ) and permission_record.code in('attendance.read','attendance.export');
insert into public.institution_role_assignments(
  membership_id,role_id,scope_kind,scope_unit_id,scope_group_id,status
) values
  ('95000000-0000-4000-8000-000000000001','95100000-0000-4000-8000-000000000001','group','92000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001','active'),
  ('95000000-0000-4000-8000-000000000002','95100000-0000-4000-8000-000000000002','unit','92000000-0000-4000-8000-000000000001',null,'active');
insert into public.activity_group_assignments(
  activity_group_link_id,institution_id,person_id,membership_id,assignment_role,assigned_by_person_id,status,revoked_at
) values
  ('94100000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','90100000-0000-4000-8000-000000000001','95000000-0000-4000-8000-000000000001','instructor','90100000-0000-4000-8000-000000000002','active',null),
  ('94100000-0000-4000-8000-000000000099','91000000-0000-4000-8000-000000000001','90100000-0000-4000-8000-000000000001','95000000-0000-4000-8000-000000000001','instructor','90100000-0000-4000-8000-000000000002','inactive',now());

select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
select is(
  app_private.attendance_dashboard_access(),
  jsonb_build_object(
    'scope','assignments','can_read',true,'can_create_call',false,'can_export',true,
    'institution_id','91000000-0000-4000-8000-000000000001'::uuid,'unit_id',null,
    'assigned_group_ids',jsonb_build_array('93000000-0000-4000-8000-000000000001'),
    'assigned_activity_ids',jsonb_build_array('94000000-0000-4000-8000-000000000001'),
    'child_ids','[]'::jsonb
  ),
  'real assignment access only returns active coherent canonical assignments'
);

create function pg_temp.attendance_export_filters(p_group uuid,p_activity uuid)
returns jsonb language sql as $$select jsonb_build_object(
  'period_start',current_date-7,'period_end',current_date,'granularity','daily',
  'institution_id','91000000-0000-4000-8000-000000000001',
  'unit_id','92000000-0000-4000-8000-000000000001','group_id',p_group,
  'activity_id',p_activity,'child_id',null,'search','','statuses','[]'::jsonb,
  'responsible_id',null,'sort','date','descending',true,'page',1,'page_size',20,
  'ranking_direction','highest'
)$$;
create function pg_temp.assignment_export_guard(p_group uuid,p_activity uuid)
returns text language plpgsql as $$begin
  perform app_private.attendance_dashboard_request_export(
    gen_random_uuid(),'table','csv',pg_temp.attendance_export_filters(p_group,p_activity));
  return 'allowed';
exception when insufficient_privilege then return 'denied';
end$$;

select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select lives_ok(
  $$select app_private.attendance_dashboard_request_export(
    gen_random_uuid(),'table','csv',pg_temp.attendance_export_filters(null,null))$$,
  'real unit-scoped export accepts its fixed institution and unit'
);

select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);

select is(pg_temp.assignment_export_guard(null,null),'denied',
  'assignment export without group or activity is denied');
select is(pg_temp.assignment_export_guard(
  '93000000-0000-4000-8000-000000000001',null),'allowed',
  'assigned group passes the assignment scope guard');
select is(pg_temp.assignment_export_guard(
  null,'94000000-0000-4000-8000-000000000001'),'allowed',
  'assigned activity passes the assignment scope guard');
select is(pg_temp.assignment_export_guard(
  '93000000-0000-4000-8000-000000000099','94000000-0000-4000-8000-000000000001'),'denied',
  'unassigned group is denied even with an assigned activity');
select is(pg_temp.assignment_export_guard(
  '93000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000099'),'denied',
  'unassigned activity is denied even with an assigned group');
select is(pg_temp.assignment_export_guard(
  '93000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000001'),'allowed',
  'assigned group and assigned activity pass together');

select * from finish();
rollback;
