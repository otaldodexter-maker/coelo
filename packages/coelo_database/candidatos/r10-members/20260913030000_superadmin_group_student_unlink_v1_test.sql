begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

select has_function(
  'public', 'superadmin_group_student_unlink', array['uuid','uuid','uuid'],
  'Turmas exposes a child-group-link-only unlink command'
);
select ok(
  not has_function_privilege(
    'anon', 'public.superadmin_group_student_unlink(uuid,uuid,uuid)', 'EXECUTE'
  ) and has_function_privilege(
    'authenticated', 'public.superadmin_group_student_unlink(uuid,uuid,uuid)', 'EXECUTE'
  ), 'only authenticated sessions can unlink a student from a group'
);

insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('f6900000-0000-4000-8000-000000000001','adult','R10','Actor','R10 unlink actor','active'),
  ('f6900000-0000-4000-8000-000000000002','child','R10','Child','R10 unlink child','active'),
  ('f6900000-0000-4000-8000-000000000003','child','R10','Foreign','R10 unlink foreign','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('f6910000-0000-4000-8000-000000000001','R10 Unlink A','R10 Unlink A','r10-unlink-a','active'),
  ('f6910000-0000-4000-8000-000000000002','R10 Unlink B','R10 Unlink B','r10-unlink-b','active');
insert into public.unit_types(id,code,name,status) values
  ('f6920000-0000-4000-8000-000000000001','r10-unlink-unit','R10 unlink unit','active');
insert into public.units(id,institution_id,name,slug,status,unit_type_id,handle) values
  ('f6930000-0000-4000-8000-000000000001','f6910000-0000-4000-8000-000000000001','R10 Unlink Unit A','r10-unlink-unit-a','active','f6920000-0000-4000-8000-000000000001','r10.unlink.unit.a'),
  ('f6930000-0000-4000-8000-000000000002','f6910000-0000-4000-8000-000000000002','R10 Unlink Unit B','r10-unlink-unit-b','active','f6920000-0000-4000-8000-000000000001','r10.unlink.unit.b');
insert into public.groups(id,institution_id,unit_id,name,handle,status) values
  ('f6940000-0000-4000-8000-000000000001','f6910000-0000-4000-8000-000000000001','f6930000-0000-4000-8000-000000000001','R10 Unlink Group A','r10.unlink.group.a','active'),
  ('f6940000-0000-4000-8000-000000000002','f6910000-0000-4000-8000-000000000001','f6930000-0000-4000-8000-000000000001','R10 Unlink Group B','r10.unlink.group.b','active'),
  ('f6940000-0000-4000-8000-000000000003','f6910000-0000-4000-8000-000000000002','f6930000-0000-4000-8000-000000000002','R10 Unlink Group Foreign','r10.unlink.group.foreign','active');
insert into public.child_contexts(id,child_person_id,institution_id,status) values
  ('f6950000-0000-4000-8000-000000000001','f6900000-0000-4000-8000-000000000002','f6910000-0000-4000-8000-000000000001','active'),
  ('f6950000-0000-4000-8000-000000000002','f6900000-0000-4000-8000-000000000003','f6910000-0000-4000-8000-000000000002','active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
  ('f6960000-0000-4000-8000-000000000001','f6950000-0000-4000-8000-000000000001','f6930000-0000-4000-8000-000000000001','active','f6900000-0000-4000-8000-000000000001',now()),
  ('f6960000-0000-4000-8000-000000000002','f6950000-0000-4000-8000-000000000002','f6930000-0000-4000-8000-000000000002','active','f6900000-0000-4000-8000-000000000001',now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status) values
  ('f6970000-0000-4000-8000-000000000001','f6960000-0000-4000-8000-000000000001','f6940000-0000-4000-8000-000000000001','active'),
  ('f6970000-0000-4000-8000-000000000002','f6960000-0000-4000-8000-000000000001','f6940000-0000-4000-8000-000000000002','active'),
  ('f6970000-0000-4000-8000-000000000003','f6960000-0000-4000-8000-000000000002','f6940000-0000-4000-8000-000000000003','active');

create or replace function app_private.current_person_id() returns uuid
language sql stable security definer set search_path='' as $$
  select 'f6900000-0000-4000-8000-000000000001'::uuid
$$;
create or replace function app_private.has_context_permission(
  target_institution_id uuid, target_permission_code text, target_unit_id uuid default null,
  target_group_id uuid default null, target_activity_id uuid default null,
  target_child_context_id uuid default null, require_institution_scope boolean default false
) returns boolean language sql stable security definer set search_path='' as $$
  select target_permission_code = 'people.assign_children'
    and current_setting('test.r10_unlink_allow', true) = 'true'
$$;

select set_config('request.jwt.claims','{"sub":"f6900000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('test.r10_unlink_allow','true',true);
set local role authenticated;
select lives_ok(
  $$select public.superadmin_group_student_unlink(
    'f6980000-0000-4000-8000-000000000001',
    'f6950000-0000-4000-8000-000000000001',
    'f6940000-0000-4000-8000-000000000001')$$,
  'authorized unlink inactivates the selected child_group_link'
);
reset role;
select is(
  (select status from public.child_group_links where id='f6970000-0000-4000-8000-000000000001'),
  'inactive', 'selected group A link is inactive'
);
select is(
  (select status from public.child_group_links where id='f6970000-0000-4000-8000-000000000002'),
  'active', 'other group B link stays active'
);
select is(
  (select status from public.child_unit_links where id='f6960000-0000-4000-8000-000000000001'),
  'active', 'unit link stays active after group-only unlink'
);
select ok(exists(
  select 1 from audit.audit_logs
  where action_code='student.unlink' and object_type='child_group_link'
    and object_id='f6970000-0000-4000-8000-000000000001'
    and institution_id='f6910000-0000-4000-8000-000000000001' and outcome='success'
), 'group-only unlink writes its audit record');

set local role authenticated;
select throws_ok(
  $$select public.superadmin_group_student_unlink(
    'f6980000-0000-4000-8000-000000000002',
    'f6950000-0000-4000-8000-000000000002',
    'f6940000-0000-4000-8000-000000000001')$$,
  'P0002','student link unavailable','foreign child context cannot unlink group A'
);
select set_config('test.r10_unlink_allow','false',true);
select throws_ok(
  $$select public.superadmin_group_student_unlink(
    'f6980000-0000-4000-8000-000000000003',
    'f6950000-0000-4000-8000-000000000001',
    'f6940000-0000-4000-8000-000000000002')$$,
  '42501','people.assign_children required','missing capability cannot unlink group B'
);
reset role;
select is(
  (select status from public.child_group_links where id='f6970000-0000-4000-8000-000000000002'),
  'active', 'negative paths preserve the remaining group link'
);
select * from finish();
rollback;
