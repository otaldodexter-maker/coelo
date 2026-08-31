begin;

create extension if not exists pgtap with schema extensions;

select plan(13);

select has_index(
  'public',
  'institution_member_permission_overrides',
  'institution_member_permission_overrides_active_scope_uidx',
  'active institution overrides have one canonical row per capability and scope'
);

select is(
  (
    select count(*)::bigint
    from pg_catalog.pg_indexes
    where schemaname = 'public'
      and tablename = 'institution_member_permission_overrides'
      and indexname = 'institution_member_permission_overrides_active_scope_uidx'
      and lower(indexdef) not like '%permission_code, effect,%'
      and lower(indexdef) like '%where%status = ''active''%revoked_at is null%'
  ),
  1::bigint,
  'canonical active-override uniqueness does not allow simultaneous allow and deny rows'
);

select ok(
  lower(pg_catalog.pg_get_functiondef(
    'app_private.superadmin_access_profile_assignment_link(uuid,jsonb)'::regprocedure
  )) like '%template_record.domain%principal%',
  'assignment link qualifies the Principal template domain column'
);

select ok(
  lower(pg_catalog.pg_get_functiondef(
    'app_private.superadmin_access_profile_capability_catalog(text,uuid,uuid)'::regprocedure
  )) like '%left join lateral%resolve_institution_assignment_override_effect%assignment_override%',
  'institution capability effects are reduced before JSON aggregation'
);

select is(
  (
    select count(*)::bigint
    from (values
      ('anon'::name),
      ('authenticated'::name)
    ) role_record(role_name)
    cross join (values
      ('app_private.superadmin_access_profile_assignment_link(uuid,jsonb)'::regprocedure),
      ('app_private.superadmin_access_profile_capability_catalog(text,uuid,uuid)'::regprocedure),
      ('app_private.resolve_institution_assignment_override_effect(uuid,text,text,uuid,uuid)'::regprocedure)
    ) function_record(function_oid)
    where has_function_privilege(role_record.role_name, function_record.function_oid, 'EXECUTE')
  ),
  0::bigint,
  'client roles cannot execute private access-profile helpers directly'
);

select is(
  (
    select count(*)::bigint
    from pg_catalog.pg_constraint constraint_record
    where constraint_record.conrelid = 'public.institution_member_permission_overrides'::regclass
      and constraint_record.conname = 'institution_member_permission_overrides_nonzero_scope_check'
      and constraint_record.contype = 'c'
  ),
  1::bigint,
  'the UUID used only as an index sentinel cannot be persisted as a real scope'
);

select is(
  (
    select count(*)::bigint
    from pg_catalog.pg_proc procedure
    where procedure.oid in (
      'public.superadmin_access_profile_capability_catalog(text,uuid,uuid)'::regprocedure,
      'public.superadmin_access_profile_assignment_link(uuid,jsonb)'::regprocedure
    )
      and procedure.prosecdef
      and pg_catalog.pg_get_userbyid(procedure.proowner) = 'postgres'
  ),
  2::bigint,
  'the two nominal public gateways are postgres-owned SECURITY DEFINER functions'
);

select is(
  (
    select count(*)::bigint
    from pg_catalog.pg_proc procedure
    where procedure.oid in (
      'public.superadmin_access_profile_capability_catalog(text,uuid,uuid)'::regprocedure,
      'public.superadmin_access_profile_assignment_link(uuid,jsonb)'::regprocedure
    )
      and array_to_string(procedure.proconfig, ',') like 'search_path=%'
      and array_to_string(procedure.proconfig, ',') not like '%public%'
  ),
  2::bigint,
  'the two nominal gateways use an empty search path'
);

select is(
  (
    select count(*)::bigint
    from (values
      ('public.superadmin_access_profile_capability_catalog(text,uuid,uuid)'::regprocedure),
      ('public.superadmin_access_profile_assignment_link(uuid,jsonb)'::regprocedure)
    ) function_record(function_oid)
    where has_function_privilege('authenticated', function_record.function_oid, 'EXECUTE')
  ),
  2::bigint,
  'authenticated can execute only the two nominal public gateways'
);

select is(
  (
    select count(*)::bigint
    from (values
      ('public.superadmin_access_profile_capability_catalog(text,uuid,uuid)'::regprocedure),
      ('public.superadmin_access_profile_assignment_link(uuid,jsonb)'::regprocedure)
    ) function_record(function_oid)
    where has_function_privilege('anon', function_record.function_oid, 'EXECUTE')
  ),
  0::bigint,
  'anonymous callers cannot execute the nominal gateways'
);

set local role authenticated;
select throws_ok(
  $$select public.superadmin_access_profile_capability_catalog('platform',null,null)$$,
  '42501',
  'profile management permission required',
  'the capability gateway reaches backend authorization for an unauthenticated session'
);
select throws_ok(
  $$select public.superadmin_access_profile_assignment_link(gen_random_uuid(),'{}'::jsonb)$$,
  '42501',
  'profile management permission required',
  'the assignment gateway reaches backend authorization for an unauthenticated session'
);
reset role;

insert into public.people(id,person_type,first_name,last_name,display_name,status)
values ('98000000-0000-4000-8000-000000000001','adult','Scope','Tester','Scope Tester','active');
insert into public.institution_types(id,code,name,status)
values ('98000000-0000-4000-8000-000000000006','scope-test','Scope Test','active');
insert into public.institutions(id,public_name,legal_name,slug,status,institution_type_id)
values ('98000000-0000-4000-8000-000000000002','Scope Institution','Scope Institution','scope-institution','active',
  '98000000-0000-4000-8000-000000000006');
insert into public.units(id,institution_id,name,slug,status,institution_type_id)
values
  ('98000000-0000-4000-8000-000000000003','98000000-0000-4000-8000-000000000002','Scope A','scope-a','active',
    (select institution_type_id from public.institutions where id='98000000-0000-4000-8000-000000000002')),
  ('98000000-0000-4000-8000-000000000004','98000000-0000-4000-8000-000000000002','Scope B','scope-b','active',
    (select institution_type_id from public.institutions where id='98000000-0000-4000-8000-000000000002'));
insert into public.institution_memberships(
  id,person_id,institution_id,role_code,status,scope_kind
) values (
  '98000000-0000-4000-8000-000000000005','98000000-0000-4000-8000-000000000001',
  '98000000-0000-4000-8000-000000000002','scope-test','active','institution'
);
insert into public.institution_member_permission_overrides(
  membership_id,permission_code,effect,scope_kind,scope_id,reason,status,
  changed_by_person_id,institution_id,scope_unit_id,scope_group_id
) values
  ('98000000-0000-4000-8000-000000000005','permissions.manage','allow','unit',
    '98000000-0000-4000-8000-000000000003','Synthetic sibling scope proof','active',
    '98000000-0000-4000-8000-000000000001','98000000-0000-4000-8000-000000000002',
    '98000000-0000-4000-8000-000000000003',null),
  ('98000000-0000-4000-8000-000000000005','permissions.manage','deny','unit',
    '98000000-0000-4000-8000-000000000004','Synthetic sibling scope proof','active',
    '98000000-0000-4000-8000-000000000001','98000000-0000-4000-8000-000000000002',
    '98000000-0000-4000-8000-000000000004',null);

select results_eq(
  $$select app_private.resolve_institution_assignment_override_effect(
      '98000000-0000-4000-8000-000000000005','permissions.manage','unit',scope_id,null
    )::text
    from (values
      ('98000000-0000-4000-8000-000000000003'::uuid),
      ('98000000-0000-4000-8000-000000000004'::uuid)
    ) scope_record(scope_id)
    order by scope_id$$,
  array['allow'::text,'deny'::text],
  'opposite effects in sibling units remain isolated by the exact assignment scope'
);

select * from finish();

rollback;
