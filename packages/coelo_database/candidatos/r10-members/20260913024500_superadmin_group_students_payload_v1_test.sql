begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select has_function(
  'app_private','superadmin_group_students_payload',array['uuid'],
  'private group student projection exists'
);
select ok(
  not has_function_privilege(
    'authenticated','app_private.superadmin_group_students_payload(uuid)','EXECUTE'
  ), 'clients cannot call the student projection directly'
);

insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('f6700000-0000-4000-8000-000000000001','adult','R10','Reader','R10 reader','active'),
  ('f6700000-0000-4000-8000-000000000002','child','R10','Child','R10 child','active'),
  ('f6700000-0000-4000-8000-000000000003','child','R10','Foreign','R10 foreign child','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('f6800000-0000-4000-8000-000000000001','R10 Read A','R10 Read A','r10-read-a','active'),
  ('f6800000-0000-4000-8000-000000000002','R10 Read B','R10 Read B','r10-read-b','active');
insert into public.unit_types(id,code,name,status) values
  ('f6810000-0000-4000-8000-000000000001','r10-read-unit','R10 read unit','active');
insert into public.units(id,institution_id,name,slug,status,unit_type_id,handle) values
  ('f6820000-0000-4000-8000-000000000001','f6800000-0000-4000-8000-000000000001','R10 Read Unit A','r10-read-unit-a','active','f6810000-0000-4000-8000-000000000001','r10.read.unit.a'),
  ('f6820000-0000-4000-8000-000000000002','f6800000-0000-4000-8000-000000000002','R10 Read Unit B','r10-read-unit-b','active','f6810000-0000-4000-8000-000000000001','r10.read.unit.b');
insert into public.groups(id,institution_id,unit_id,name,handle,status) values
  ('f6830000-0000-4000-8000-000000000001','f6800000-0000-4000-8000-000000000001','f6820000-0000-4000-8000-000000000001','R10 Read Group A','r10.read.group.a','active'),
  ('f6830000-0000-4000-8000-000000000002','f6800000-0000-4000-8000-000000000002','f6820000-0000-4000-8000-000000000002','R10 Read Group B','r10.read.group.b','active');
insert into public.child_contexts(id,child_person_id,institution_id,status) values
  ('f6840000-0000-4000-8000-000000000001','f6700000-0000-4000-8000-000000000002','f6800000-0000-4000-8000-000000000001','active'),
  ('f6840000-0000-4000-8000-000000000002','f6700000-0000-4000-8000-000000000003','f6800000-0000-4000-8000-000000000002','active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
  ('f6850000-0000-4000-8000-000000000001','f6840000-0000-4000-8000-000000000001','f6820000-0000-4000-8000-000000000001','active','f6700000-0000-4000-8000-000000000001',now()),
  ('f6850000-0000-4000-8000-000000000002','f6840000-0000-4000-8000-000000000002','f6820000-0000-4000-8000-000000000002','active','f6700000-0000-4000-8000-000000000001',now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status) values
  ('f6860000-0000-4000-8000-000000000001','f6850000-0000-4000-8000-000000000001','f6830000-0000-4000-8000-000000000001','active'),
  ('f6860000-0000-4000-8000-000000000002','f6850000-0000-4000-8000-000000000002','f6830000-0000-4000-8000-000000000002','active');

create or replace function app_private.current_person_id() returns uuid
language sql stable security definer set search_path='' as $$
  select 'f6700000-0000-4000-8000-000000000001'::uuid
$$;
create or replace function app_private.has_platform_permission(permission_code text)
returns boolean language sql stable security definer set search_path='' as $$
  select permission_code='groups.read'
    and current_setting('test.r10_group_read',true)='true'
$$;
select set_config('request.jwt.claims','{"sub":"f6700000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('test.r10_group_read','true',true);
set local role authenticated;
select is(
  public.superadmin_group_get('f6830000-0000-4000-8000-000000000001')#>>'{students,0,person_id}',
  'f6700000-0000-4000-8000-000000000002',
  'authorized group reload returns the linked child person id'
);
select is(
  public.superadmin_group_get('f6830000-0000-4000-8000-000000000001')#>>'{students,0,child_context_id}',
  'f6840000-0000-4000-8000-000000000001',
  'authorized group reload returns the child context id'
);
select is(
  jsonb_array_length(public.superadmin_group_get('f6830000-0000-4000-8000-000000000001')->'students'),
  1, 'group A projection excludes the foreign tenant child'
);
select set_config('test.r10_group_read','false',true);
select throws_ok(
  $$select public.superadmin_group_get('f6830000-0000-4000-8000-000000000001')$$,
  '42501','groups.read required','reader without groups.read receives no child data'
);
reset role;
select * from finish();
rollback;
