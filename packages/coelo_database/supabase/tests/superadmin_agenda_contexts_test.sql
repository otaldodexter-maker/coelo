begin;

select plan(17);

select function_returns(
  'public',
  'superadmin_agenda_contexts',
  array[]::text[],
  'jsonb',
  'Agenda contexts RPC returns jsonb'
);

select is(
  (select routine_record.security_type
   from information_schema.routines routine_record
   where routine_record.specific_schema = 'public'
     and routine_record.routine_name = 'superadmin_agenda_contexts'),
  'DEFINER',
  'Agenda contexts RPC is SECURITY DEFINER'
);

select ok(
  coalesce(
    (select function_record.proconfig @> array['search_path=']
     from pg_catalog.pg_proc function_record
     where function_record.oid = 'public.superadmin_agenda_contexts()'::regprocedure),
    false
  ),
  'Agenda contexts RPC has an empty search_path'
);

select is(
  (select pg_catalog.pg_get_userbyid(function_record.proowner)
   from pg_catalog.pg_proc function_record
   where function_record.oid = 'public.superadmin_agenda_contexts()'::regprocedure),
  'postgres',
  'Agenda contexts RPC has the expected owner'
);

select ok(
  not exists(
    select 1
    from pg_catalog.pg_proc function_record
    cross join lateral pg_catalog.aclexplode(
      coalesce(
        function_record.proacl,
        pg_catalog.acldefault('f', function_record.proowner)
      )
    ) acl
    where function_record.oid = 'public.superadmin_agenda_contexts()'::regprocedure
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute Agenda contexts RPC'
);
select is(has_function_privilege('anon', 'public.superadmin_agenda_contexts()', 'execute'), false,
  'anon cannot execute Agenda contexts RPC');
select is(has_function_privilege('service_role', 'public.superadmin_agenda_contexts()', 'execute'), false,
  'service_role cannot execute Agenda contexts RPC');
select is(has_function_privilege('authenticated', 'public.superadmin_agenda_contexts()', 'execute'), true,
  'authenticated can execute Agenda contexts RPC');

select ok(
  pg_catalog.pg_get_functiondef('public.superadmin_agenda_contexts()'::regprocedure)
    like '%app_private.assert_agenda_permission(''agenda.read'', false)%',
  'Agenda contexts RPC reuses the Agenda read gate'
);

create or replace function app_private.current_person_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$ select '9a000000-0000-4000-8000-000000000001'::uuid $$;

create or replace function app_private.has_platform_permission(permission_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select permission_code in (
    'agenda.read', 'agenda.create', 'agenda.edit_own', 'agenda.cancel_restore'
  )
$$;

insert into public.people(id, person_type, first_name, last_name, display_name)
values (
  '9a000000-0000-4000-8000-000000000001',
  'adult', 'Agenda', 'Operator', 'Agenda Operator'
);

insert into public.institutions(id, public_name, slug, status) values
  ('9a000000-0000-4000-8000-000000000010', 'Instituição autorizada', 'agenda-context-authorized', 'active'),
  ('9a000000-0000-4000-8000-000000000020', 'Instituição de outro tenant', 'agenda-context-denied', 'active');

insert into public.units(id, institution_id, name, slug, status) values
  ('9a000000-0000-4000-8000-000000000011', '9a000000-0000-4000-8000-000000000010', 'Unidade autorizada', 'agenda-unit-authorized', 'active'),
  ('9a000000-0000-4000-8000-000000000021', '9a000000-0000-4000-8000-000000000020', 'Unidade de outro tenant', 'agenda-unit-denied', 'active');

insert into public.groups(id, institution_id, unit_id, name, group_type, status) values
  ('9a000000-0000-4000-8000-000000000012', '9a000000-0000-4000-8000-000000000010', '9a000000-0000-4000-8000-000000000011', 'Turma autorizada', 'class', 'active'),
  ('9a000000-0000-4000-8000-000000000022', '9a000000-0000-4000-8000-000000000020', '9a000000-0000-4000-8000-000000000021', 'Turma de outro tenant', 'class', 'active');

insert into public.activity_definitions(
  id, institution_id, name, origin_scope_kind, origin_unit_id,
  created_by_person_id, status
) values
  ('9a000000-0000-4000-8000-000000000013', '9a000000-0000-4000-8000-000000000010', 'Atividade autorizada', 'unit', '9a000000-0000-4000-8000-000000000011', '9a000000-0000-4000-8000-000000000001', 'active'),
  ('9a000000-0000-4000-8000-000000000023', '9a000000-0000-4000-8000-000000000020', 'Atividade de outro tenant', 'unit', '9a000000-0000-4000-8000-000000000021', '9a000000-0000-4000-8000-000000000001', 'active');

insert into public.platform_roles(id, code, name, status, max_scope_kind)
values (
  '9a000000-0000-4000-8000-000000000030',
  'agenda_context_test', 'Agenda context test', 'active', 'institution'
);

insert into public.platform_memberships(
  id, person_id, role_id, status, scope_kind, scope_institution_id
) values (
  '9a000000-0000-4000-8000-000000000031',
  '9a000000-0000-4000-8000-000000000001',
  '9a000000-0000-4000-8000-000000000030',
  'active', 'institution', '9a000000-0000-4000-8000-000000000010'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"9a000000-0000-4000-8000-000000000099","aal":"aal1","role":"authenticated"}',
  true
);
set local role authenticated;

create temporary table agenda_context_result as
select public.superadmin_agenda_contexts() as body;

reset role;

select is(
  (select pg_catalog.jsonb_array_length(body -> 'contexts') from agenda_context_result),
  4,
  'authorized institution returns exactly its institution, unit, group and activity'
);

select is(
  (select count(*)::integer
   from agenda_context_result result_record
   cross join lateral pg_catalog.jsonb_array_elements(result_record.body -> 'contexts') item
   where item ->> 'institution_id' = '9a000000-0000-4000-8000-000000000020'),
  0,
  'cross-tenant contexts are not returned'
);

select set_eq(
  $$
    select item ->> 'level'
    from agenda_context_result result_record
    cross join lateral jsonb_array_elements(result_record.body -> 'contexts') item
  $$,
  array['institution', 'unit', 'group', 'activity'],
  'all four Agenda context levels are returned'
);

select is(
  (select item ->> 'parent_id'
   from agenda_context_result result_record
   cross join lateral pg_catalog.jsonb_array_elements(result_record.body -> 'contexts') item
   where item ->> 'id' = '9a000000-0000-4000-8000-000000000012'),
  '9a000000-0000-4000-8000-000000000011',
  'group context is parented by its authorized unit'
);

select is(
  (select body #>> '{capabilities,createAgendaItems}' from agenda_context_result),
  'true',
  'effective allowed capability is returned'
);

select is(
  (select body #>> '{capabilities,publishAgendaItems}' from agenda_context_result),
  'false',
  'effective denied capability is returned without broadening access'
);

create or replace function app_private.has_platform_permission(permission_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select false $$;

set local role authenticated;
select throws_ok(
  'select public.superadmin_agenda_contexts()',
  '42501',
  'agenda_permission_denied',
  'authenticated actor without agenda.read is denied'
);
reset role;

set local role anon;
select throws_ok(
  'select public.superadmin_agenda_contexts()',
  '42501',
  'permission denied for function superadmin_agenda_contexts',
  'anon cannot invoke Agenda contexts RPC'
);
reset role;

select * from finish();
rollback;
