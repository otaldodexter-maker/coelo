begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

select has_function(
  'public','superadmin_group_student_link',array['uuid','uuid','uuid'],
  'Turmas exposes a scoped student-link adapter'
);
select ok(
  not has_function_privilege('anon','public.superadmin_group_student_link(uuid,uuid,uuid)','EXECUTE')
  and has_function_privilege('authenticated','public.superadmin_group_student_link(uuid,uuid,uuid)','EXECUTE'),
  'only authenticated sessions can call the adapter'
);
select ok(
  pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    like '%app_private.superadmin_student_link(%',
  'the adapter delegates the write to the canonical student command'
);
select ok(
  pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    like '%child_context.child_person_id=p_person_id%'
  and pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    like '%child_context.institution_id=group_row.institution_id%',
  'the child context is resolved only inside the group institution'
);
select ok(
  pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    like '%where id=p_group_id and status=''active''%',
  'inactive or foreign group IDs do not become allocation targets'
);
select ok(
  pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    not like '%institution_memberships%'
  and pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    not like '%institution_role_assignments%',
  'student allocation never manufactures a professional membership or profile'
);
select ok(
  pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    not like '%guardian_links%'
  and pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    not like '%guardian_context_permissions%',
  'guardian access remains derived and is not written as a group membership'
);

-- Fixture minima: o adaptador recebe uma crianca real em um contexto ativo e
-- delega a escrita para o comando que cria child_unit_links e child_group_links.
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('f6100000-0000-4000-8000-000000000001','adult','R10','Actor','R10 actor','active'),
  ('f6100000-0000-4000-8000-000000000002','child','R10','Child','R10 child','active'),
  ('f6100000-0000-4000-8000-000000000003','child','R10','Foreign','R10 foreign child','active'),
  ('f6100000-0000-4000-8000-000000000004','child','R10','Other','R10 other child','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('f6200000-0000-4000-8000-000000000001','R10 Institution A','R10 Institution A','r10-members-a','active'),
  ('f6200000-0000-4000-8000-000000000002','R10 Institution B','R10 Institution B','r10-members-b','active');
insert into public.unit_types(id,code,name,status) values
  ('f6250000-0000-4000-8000-000000000001','r10-members-unit','R10 members unit','active');
insert into public.units(id,institution_id,name,slug,status,unit_type_id,handle) values
  ('f6300000-0000-4000-8000-000000000001','f6200000-0000-4000-8000-000000000001','R10 Unit A','r10-members-unit-a','active','f6250000-0000-4000-8000-000000000001','r10.members.unit.a'),
  ('f6300000-0000-4000-8000-000000000002','f6200000-0000-4000-8000-000000000002','R10 Unit B','r10-members-unit-b','active','f6250000-0000-4000-8000-000000000001','r10.members.unit.b');
insert into public.groups(id,institution_id,unit_id,name,handle,status) values
  ('f6400000-0000-4000-8000-000000000001','f6200000-0000-4000-8000-000000000001','f6300000-0000-4000-8000-000000000001','R10 Group A','r10.group.a','active'),
  ('f6400000-0000-4000-8000-000000000002','f6200000-0000-4000-8000-000000000002','f6300000-0000-4000-8000-000000000002','R10 Group B','r10.group.b','active');
insert into public.child_contexts(id,child_person_id,institution_id,status) values
  ('f6500000-0000-4000-8000-000000000001','f6100000-0000-4000-8000-000000000002','f6200000-0000-4000-8000-000000000001','active'),
  ('f6500000-0000-4000-8000-000000000002','f6100000-0000-4000-8000-000000000003','f6200000-0000-4000-8000-000000000002','active'),
  ('f6500000-0000-4000-8000-000000000003','f6100000-0000-4000-8000-000000000004','f6200000-0000-4000-8000-000000000001','active');

-- Sobrescritas locais exercitam o comando autenticado com e sem a capacidade,
-- sem enfraquecer helpers fora desta transacao.
create or replace function app_private.current_person_id() returns uuid
language sql stable security definer set search_path='' as $$
  select 'f6100000-0000-4000-8000-000000000001'::uuid
$$;
create or replace function app_private.has_context_permission(
  target_institution_id uuid, target_permission_code text, target_unit_id uuid default null,
  target_group_id uuid default null, target_activity_id uuid default null,
  target_child_context_id uuid default null, require_institution_scope boolean default false
) returns boolean language sql stable security definer set search_path='' as $$
  select target_permission_code = 'people.assign_children'
    and current_setting('test.r10_members_allow', true) = 'true'
$$;

select set_config('test.r10_members_allow','true',true);
set local role authenticated;
select lives_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000001',
    'f6100000-0000-4000-8000-000000000002',
    'f6400000-0000-4000-8000-000000000001')$$,
  'active child context creates the canonical group link'
);
reset role;
select ok(exists(
  select 1 from public.child_group_links group_link
  join public.child_unit_links unit_link on unit_link.id=group_link.child_unit_link_id
  where group_link.group_id='f6400000-0000-4000-8000-000000000001'
    and group_link.status='active' and unit_link.status='active'
    and unit_link.child_context_id='f6500000-0000-4000-8000-000000000001'
), 'positive write persists active child_unit_link and child_group_link');

set local role authenticated;
select set_config('test.r10_members_allow','false',true);
select throws_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000001',
    'f6100000-0000-4000-8000-000000000002',
    'f6400000-0000-4000-8000-000000000001')$$,
  'P0002','student link unavailable','link receipt replay requires current capability'
);
select set_config('test.r10_members_allow','true',true);
select throws_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000001',
    'f6100000-0000-4000-8000-000000000004',
    'f6400000-0000-4000-8000-000000000001')$$,
  '22023','request id reused for another link target','link receipt cannot be replayed for another child'
);
select throws_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000002',
    'f6100000-0000-4000-8000-000000000003',
    'f6400000-0000-4000-8000-000000000001')$$,
  'P0002','student link unavailable','cross-tenant child cannot be linked to group A'
);
select throws_ok(
  $$select public.superadmin_student_link(
    'f6600000-0000-4000-8000-000000000003',
    'f6500000-0000-4000-8000-000000000001',
    jsonb_build_object('unit_id','f6300000-0000-4000-8000-000000000002','group_id','f6400000-0000-4000-8000-000000000002'))$$,
  'P0002','student link unavailable','canonical delegation rejects an invalid unit/group hierarchy'
);
select set_config('test.r10_members_allow','false',true);
select throws_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000004',
    'f6100000-0000-4000-8000-000000000002',
    'f6400000-0000-4000-8000-000000000001')$$,
  'P0002','student link unavailable','missing capability receives the same opaque denial'
);
select throws_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000005',
    'f6100000-0000-4000-8000-000000000002',
    'f6400000-0000-4000-8000-000000000099')$$,
  'P0002','student link unavailable','missing capability cannot distinguish a nonexistent group'
);
select throws_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000006',
    'f6100000-0000-4000-8000-000000000003',
    'f6400000-0000-4000-8000-000000000001')$$,
  'P0002','student link unavailable','missing capability cannot distinguish a cross-tenant child'
);
reset role;
select is((select count(*)::integer from public.child_group_links),1,
  'negative paths create no cross-tenant, invalid-hierarchy, or unauthorized group link');

select * from finish();
rollback;
