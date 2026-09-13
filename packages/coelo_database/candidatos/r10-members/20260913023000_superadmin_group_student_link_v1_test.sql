-- RED before the paired candidate: no group-scoped adapter exists.
-- GREEN proves the adapter delegates to the canonical student-link command.
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

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

select * from finish();
rollback;
