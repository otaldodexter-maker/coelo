begin;
create extension if not exists pgtap with schema extensions;
select plan(52);

select results_eq(
  $$
    select code
    from public.platform_permissions
    where code like 'people.%'
    order by code
  $$,
  $$
    values
      ('people.child_contexts.manage'::text),
      ('people.create'::text),
      ('people.memberships.manage'::text),
      ('people.read'::text),
      ('people.update'::text)
  $$,
  'people permissions are granular and cataloged'
);
select results_eq(
  $$
    select distinct role.code
    from public.platform_roles role
    join public.platform_role_permissions role_permission
      on role_permission.role_id = role.id
    join public.platform_permissions permission
      on permission.id = role_permission.permission_id
    where permission.code like 'people.%'
      and role_permission.status = 'active'
      and role_permission.effect = 'allow'
    order by role.code
  $$,
  $$ values ('owner'::text) $$,
  'only Owner receives people permissions initially'
);
select ok(
  (
    select count(*) = 5 and bool_and(requires_mfa)
    from public.platform_permissions
    where code like 'people.%'
  ),
  'all people permissions require MFA'
);

select has_function(
  'public', 'superadmin_people_list',
  array[
    'text', 'person_type[]', 'record_status[]', 'uuid[]', 'uuid[]', 'uuid[]',
    'text[]', 'text[]', 'text', 'boolean', 'integer', 'integer'
  ],
  'directory list RPC matches the Flutter repository'
);
select has_function(
  'public', 'superadmin_people_filter_options', array[]::text[],
  'filter options RPC matches the Flutter repository'
);
select has_function(
  'public', 'superadmin_people_detail', array['uuid'],
  'person detail RPC matches the Flutter repository'
);
select has_function(
  'public', 'superadmin_people_create_draft', array['jsonb'],
  'draft create RPC matches the Flutter repository'
);
select has_function(
  'public', 'superadmin_people_update', array['jsonb'],
  'concurrent update RPC matches the Flutter repository'
);
select ok(
  not exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'list_superadmin_people',
        'get_superadmin_person',
        'create_superadmin_person_draft',
        'update_superadmin_person'
      )
  ),
  'legacy helpers are private rather than redundant public RPCs'
);

select function_privs_are(
  'public', 'superadmin_people_list',
  array[
    'text', 'person_type[]', 'record_status[]', 'uuid[]', 'uuid[]', 'uuid[]',
    'text[]', 'text[]', 'text', 'boolean', 'integer', 'integer'
  ],
  'authenticated', array['EXECUTE'],
  'authenticated can execute list RPC'
);
select function_privs_are(
  'public', 'superadmin_people_filter_options', array[]::text[],
  'authenticated', array['EXECUTE'],
  'authenticated can execute filter options RPC'
);
select function_privs_are(
  'public', 'superadmin_people_detail', array['uuid'],
  'authenticated', array['EXECUTE'],
  'authenticated can execute detail RPC'
);
select function_privs_are(
  'public', 'superadmin_people_create_draft', array['jsonb'],
  'authenticated', array['EXECUTE'],
  'authenticated can execute create RPC'
);
select function_privs_are(
  'public', 'superadmin_people_update', array['jsonb'],
  'authenticated', array['EXECUTE'],
  'authenticated can execute update RPC'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.superadmin_people_list(text,public.person_type[],public.record_status[],uuid[],uuid[],uuid[],text[],text[],text,boolean,integer,integer)',
    'EXECUTE'
  ),
  'anonymous cannot list people'
);
select ok(
  not has_function_privilege(
    'anon', 'public.superadmin_people_create_draft(jsonb)', 'EXECUTE'
  ),
  'anonymous cannot create people'
);
select ok(
  not has_function_privilege(
    'anon', 'public.superadmin_people_update(jsonb)', 'EXECUTE'
  ),
  'anonymous cannot update people'
);

select ok(
  (
    select bool_and(procedure.prosecdef)
       and bool_and(procedure.proconfig @> array['search_path=""'])
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'superadmin_people_list',
        'superadmin_people_filter_options',
        'superadmin_people_detail',
        'superadmin_people_create_draft',
        'superadmin_people_update'
      )
  ),
  'all public people RPCs are definer functions with empty search_path'
);
select ok(
  pg_get_functiondef(
    'app_private.assert_people_permission(text)'::regprocedure
  ) like '%has_mfa_aal2%',
  'people RPC authorization enforces AAL2'
);

select policies_are(
  'public', 'people',
  array['people_self_read'],
  'people direct SELECT remains self-only'
);
select policies_are(
  'public', 'person_profile_details',
  array['person_profile_self_read'],
  'profile details remain self-only'
);
select policies_are(
  'public', 'person_professional_details',
  array['person_professional_self_read'],
  'professional details remain self-only'
);
select policies_are(
  'public', 'person_education_details',
  array['person_education_self_read'],
  'education details remain self-only'
);
select policies_are(
  'public', 'person_addresses',
  array['person_addresses_self_read'],
  'addresses remain self-only'
);
select policies_are(
  'public', 'person_contacts',
  array['person_contacts_self_read'],
  'contacts remain self-only'
);
select ok(
  pg_get_viewdef('public.person_directory'::regclass, true)
    like '%current_person_id()%',
  'legacy directory view remains self-only'
);
select ok(
  not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'platform_memberships', 'institution_memberships',
        'institution_roles', 'institution_permissions',
        'institution_role_permissions', 'institution_role_assignments',
        'guardian_links', 'child_contexts', 'child_unit_links',
        'child_group_links', 'guardian_context_permissions',
        'child_unit_access_requests',
        'child_unit_access_request_children', 'invitations'
      )
      and coalesce(qual, '') like '%platform.read%'
  ),
  'contextual identity tables no longer expose platform.read'
);
select ok(
  not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'platform_memberships', 'institution_memberships',
        'institution_roles', 'institution_permissions',
        'institution_role_permissions', 'institution_role_assignments',
        'guardian_links', 'child_contexts', 'child_unit_links',
        'child_group_links', 'guardian_context_permissions',
        'child_unit_access_requests',
        'child_unit_access_request_children', 'invitations'
      )
      and coalesce(qual, '') like '%people.read%'
  ),
  'people.read never authorizes direct contextual table enumeration'
);
select ok(
  (
    select count(*) = 3
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'child_contexts', 'child_unit_links', 'child_group_links'
      )
      and coalesce(qual, '') like '%guardian_context_permissions%'
      and coalesce(qual, '') like '%can_view%'
      and coalesce(qual, '') like '%expires_at%'
  ),
  'guardian child reads require active scoped can_view permission'
);
select ok(
  (
    select qual like '%child_contexts.child_person_id%'
      and qual not like '%guardian_link.child_person_id = guardian_link.child_person_id%'
    from pg_policies
    where schemaname = 'public'
      and tablename = 'child_contexts'
      and policyname = 'child_contexts_guardian_context_read'
  )
  and (
    select qual like '%child_unit_links.child_context_id%'
      and qual not like '%child_context.id = guardian_permission.child_context_id%'
    from pg_policies
    where schemaname = 'public'
      and tablename = 'child_unit_links'
      and policyname = 'child_unit_links_guardian_context_read'
  )
  and (
    select qual like '%child_group_links.child_unit_link_id%'
    from pg_policies
    where schemaname = 'public'
      and tablename = 'child_group_links'
      and policyname = 'child_group_links_guardian_context_read'
  ),
  'guardian policies correlate permission to the exact selected row'
);

select has_index(
  'public', 'people', 'people_directory_sort_idx',
  'directory ordering is indexed'
);
select has_index(
  'public', 'institution_memberships',
  'institution_memberships_people_directory_idx',
  'institution and role filters are indexed'
);
select has_index(
  'public', 'institution_role_assignments',
  'institution_role_assignments_people_directory_idx',
  'unit and group role filters are indexed'
);
select has_index(
  'public', 'child_contexts',
  'child_contexts_people_directory_idx',
  'child institution filters are indexed'
);

select ok(
  pg_get_functiondef(
    'public.superadmin_people_list(text,public.person_type[],public.record_status[],uuid[],uuid[],uuid[],text[],text[],text,boolean,integer,integer)'::regprocedure
  ) like '%p_limit not in (8, 11, 20, 50, 100)%',
  'list accepts responsive and selectable page sizes'
);
select ok(
  pg_get_functiondef(
    'public.superadmin_people_list(text,public.person_type[],public.record_status[],uuid[],uuid[],uuid[],text[],text[],text,boolean,integer,integer)'::regprocedure
  ) like all(array[
    '%p_institution_ids%', '%p_unit_ids%', '%p_group_ids%',
    '%p_contextual_roles%', '%p_auth_links%'
  ]),
  'list keeps all multiselect filters server-side'
);
select ok(
  pg_get_functiondef(
    'public.superadmin_people_list(text,public.person_type[],public.record_status[],uuid[],uuid[],uuid[],text[],text[],text,boolean,integer,integer)'::regprocedure
  ) like all(array[
    '%p_sort = ''display_name''%', '%p_sort = ''type''%',
    '%p_sort = ''status''%', '%p_sort = ''institution_name''%',
    '%p_sort = ''unit_name''%', '%p_sort = ''group_name''%',
    '%p_sort = ''contextual_role''%', '%p_sort = ''auth_link''%'
  ]),
  'all eight directory sort keys are implemented in SQL'
);
select ok(
  pg_get_functiondef(
    'public.superadmin_people_list(text,public.person_type[],public.record_status[],uuid[],uuid[],uuid[],text[],text[],text,boolean,integer,integer)'::regprocedure
  ) not like all(array[
    '%''first_name''%', '%''last_name''%', '%''legal_name''%',
    '%''platform_membership_summary''%', '%''guardian_links_summary''%'
  ]),
  'list payload excludes detail-only and sensitive identity fields'
);
select ok(
  pg_get_functiondef(
    'public.superadmin_people_filter_options()'::regprocedure
  ) like all(array[
    '%''institution_id'', unit.institution_id%',
    '%''institution_id'', group_row.institution_id%',
    '%''unit_id'', group_row.unit_id%',
    '%''institution_id'', role.institution_id%'
  ]),
  'dependent filter options include their parent identifiers'
);
select ok(
  pg_get_functiondef(
    'public.superadmin_people_create_draft(jsonb)'::regprocedure
  ) not like '%auth.users%',
  'draft creation never creates Auth users'
);
select ok(
  not (
    pg_get_functiondef(
      'public.superadmin_people_update(jsonb)'::regprocedure
    ) like any(array[
      '%date_of_birth%', '%person_contacts%', '%person_auth_links%',
      '%platform_memberships%', '%cpf%', '%photo%'
    ])
  ),
  'editing excludes unapproved and read-only identity surfaces'
);
select ok(
  pg_get_functiondef(
    'app_private.create_superadmin_person_draft(public.person_type,text,text,text,text,jsonb)'::regprocedure
  ) like '%institution_role_assignments%'
  and pg_get_functiondef(
    'app_private.update_superadmin_person(uuid,timestamptz,jsonb,jsonb)'::regprocedure
  ) like '%institution_role_assignments%',
  'adult membership writes canonical role assignments'
);
select ok(
  pg_get_functiondef(
    'app_private.update_superadmin_person(uuid,timestamptz,jsonb,jsonb)'::regprocedure
  ) like '%child_unit_link_id%'
  and pg_get_functiondef(
    'app_private.update_superadmin_person(uuid,timestamptz,jsonb,jsonb)'::regprocedure
  ) like '%insert into public.child_group_links%',
  'child context update preserves unit id and creates an optional group link'
);
select ok(
  pg_get_functiondef(
    'app_private.update_superadmin_person(uuid,timestamptz,jsonb,jsonb)'::regprocedure
  ) like
    '%on conflict on constraint child_unit_links_child_context_id_unit_id_key%'
  and pg_get_functiondef(
    'app_private.update_superadmin_person(uuid,timestamptz,jsonb,jsonb)'::regprocedure
  ) like
    '%on conflict on constraint child_group_links_child_unit_link_id_group_id_key%',
  'child add reactivates canonical unit and group links'
);
select ok(
  pg_get_functiondef(
    'public.superadmin_people_create_draft(jsonb)'::regprocedure
  ) like '%child_contexts%'
  and pg_get_functiondef(
    'public.superadmin_people_update(jsonb)'::regprocedure
  ) like '%child_context_changes%',
  'public RPCs accept the Flutter child context contract'
);
select ok(
  pg_get_functiondef(
    'app_private.update_superadmin_person(uuid,timestamptz,jsonb,jsonb)'::regprocedure
  ) like '%assignment_id%'
  and pg_get_functiondef(
    'app_private.update_superadmin_person(uuid,timestamptz,jsonb,jsonb)'::regprocedure
  ) like '%where target.id = assignment.id%',
  'adult updates target a single canonical role assignment'
);
select ok(
  pg_get_functiondef(
    'app_private.create_superadmin_person_draft(public.person_type,text,text,text,text,jsonb)'::regprocedure
  ) like '%audit.audit_logs%'
  and pg_get_functiondef(
    'app_private.update_superadmin_person(uuid,timestamptz,jsonb,jsonb)'::regprocedure
  ) like '%audit.audit_logs%',
  'mutating RPCs write minimized audit events'
);
select ok(
  pg_get_functiondef(
    'app_private.create_superadmin_person_draft(public.person_type,text,text,text,text,jsonb)'::regprocedure
  ) like '%people.membership.context.add%'
  and pg_get_functiondef(
    'app_private.create_superadmin_person_draft(public.person_type,text,text,text,text,jsonb)'::regprocedure
  ) like '%people.child_context.context.add%',
  'draft creation audits each contextual binding individually'
);
select ok(
  pg_get_functiondef(
    'public.superadmin_people_update(jsonb)'::regprocedure
  ) like '%expected_updated_at%'
  and pg_get_functiondef(
    'app_private.update_superadmin_person(uuid,timestamptz,jsonb,jsonb)'::regprocedure
  ) like '%serialization_failure%',
  'repository update RPC delegates optimistic timestamp concurrency'
);
select ok(
  (
    select count(distinct trigger_name) = 5
    from information_schema.triggers
    where event_object_schema = 'public'
      and trigger_name in (
        'institution_memberships_touch_person',
        'institution_role_assignments_touch_person',
        'child_contexts_touch_person',
        'child_unit_links_touch_person',
        'child_group_links_touch_person'
      )
  ),
  'context mutations propagate optimistic concurrency to people.updated_at'
);
select ok(
  pg_get_functiondef(
    'app_private.superadmin_person_payload(uuid)'::regprocedure
  ) like '%child_context.status = ''active''%'
  and pg_get_functiondef(
    'app_private.superadmin_person_payload(uuid)'::regprocedure
  ) like '%unit_link.revoked_at is null%'
  and pg_get_functiondef(
    'app_private.superadmin_person_payload(uuid)'::regprocedure
  ) like '%group_link.status = ''active''%',
  'detail payload includes only active child contexts and links'
);
select ok(
  pg_get_functiondef(
    'app_private.update_superadmin_person(uuid,timestamptz,jsonb,jsonb)'::regprocedure
  ) like '%platform_permission_membership_id(%'
  and pg_get_functiondef(
    'app_private.create_superadmin_person_draft(public.person_type,text,text,text,text,jsonb)'::regprocedure
  ) like '%platform_permission_membership_id(%',
  'audit actors use the membership that grants each people permission'
);

select * from finish();
rollback;
