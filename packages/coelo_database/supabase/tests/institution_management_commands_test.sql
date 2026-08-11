begin;

create extension if not exists pgtap with schema extensions;

select plan(30);

select results_eq(
  $$
    select code, risk_level, requires_mfa, status::text
    from public.platform_permissions
    where code = 'institution.update'
  $$,
  $$ values ('institution.update'::text, 'high'::text, true, 'active'::text) $$,
  'institution.update is an active high-risk MFA permission'
);

select results_eq(
  $$
    select role_record.code
    from public.platform_role_permissions grant_record
    join public.platform_roles role_record on role_record.id = grant_record.role_id
    join public.platform_permissions permission_record
      on permission_record.id = grant_record.permission_id
    where permission_record.code = 'institution.update'
      and grant_record.effect = 'allow'
      and grant_record.status = 'active'
    order by role_record.code
  $$,
  $$ values ('operations'::text), ('owner'::text) $$,
  'only owner and operations receive institution.update'
);

select has_column(
  'public', 'institutions', 'management_version',
  'institutions have an optimistic concurrency version'
);

select col_type_is(
  'public', 'institutions', 'management_version', 'bigint',
  'management_version uses bigint'
);

select ok(
  exists (
    select 1 from pg_constraint constraint_record
    where constraint_record.conrelid = 'public.institutions'::regclass
      and constraint_record.contype = 'c'
      and pg_get_constraintdef(constraint_record.oid) like '%management_version%'
  )
  and to_regclass('public.institution_subscriptions_latest_idx') is not null,
  'management_version is constrained and latest subscription is indexed'
);

select has_table(
  'app_private', 'institution_management_command_receipts',
  'institution command receipts are private'
);

select ok(
  exists (
    select 1 from pg_constraint constraint_record
    where constraint_record.conrelid =
      'app_private.institution_management_command_receipts'::regclass
      and constraint_record.contype = 'p'
  )
  and exists (
    select 1 from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'institution_management_command_receipts'
      and column_name = 'request_hash'
  )
  and not exists (
    select 1 from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'institution_management_command_receipts'
      and column_name in ('request_json', 'result_json')
  ),
  'receipts use a request hash and contain no full request or result JSON'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.institution_management_command_receipts',
    'SELECT'
  )
  and not has_function_privilege(
    'authenticated',
    'app_private.get_institution_for_superadmin(uuid)', 'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'app_private.create_institution_for_superadmin(uuid,jsonb)', 'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'app_private.update_institution_for_superadmin(uuid,uuid,bigint,jsonb)',
    'EXECUTE'
  ),
  'authenticated cannot read receipts or execute private commands'
);

select has_function(
  'public', 'get_institution_for_superadmin', array['uuid'],
  'read RPC has the approved signature'
);

select has_function(
  'public', 'create_institution_for_superadmin', array['uuid', 'jsonb'],
  'create RPC requires request_id and payload'
);

select has_function(
  'public', 'update_institution_for_superadmin',
  array['uuid', 'uuid', 'bigint', 'jsonb'],
  'update RPC requires request_id, institution, expected_version and payload'
);

select ok(
  (
    select bool_and(procedure.prosecdef)
      and bool_and(procedure.proconfig @> array['search_path=""'])
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'get_institution_for_superadmin',
        'create_institution_for_superadmin',
        'update_institution_for_superadmin'
      )
  ),
  'public RPCs are hardened definer gateways with empty search_path'
);

select ok(
  (
    select count(*) = 3
      and bool_and(procedure.prosecdef)
      and bool_and(procedure.proconfig @> array['search_path=""'])
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'app_private'
      and procedure.proname in (
        'get_institution_for_superadmin',
        'create_institution_for_superadmin',
        'update_institution_for_superadmin'
      )
  ),
  'privileged implementations are private definers with empty search_path'
);

select ok(
  pg_get_functiondef(
    'app_private.get_institution_for_superadmin(uuid)'::regprocedure
  ) like '%platform.read%'
  and pg_get_functiondef(
    'app_private.get_institution_for_superadmin(uuid)'::regprocedure
  ) like '%auth.uid()%'
  and pg_get_functiondef(
    'app_private.get_institution_for_superadmin(uuid)'::regprocedure
  ) like '%current_person_id()%'
  ,
  'read implementation verifies identity and platform.read'
);

select ok(
  pg_get_functiondef(
    'app_private.create_institution_for_superadmin(uuid,jsonb)'::regprocedure
  ) like '%institution.activate%'
  and pg_get_functiondef(
    'app_private.create_institution_for_superadmin(uuid,jsonb)'::regprocedure
  ) like '%has_mfa_aal2()%'
  and pg_get_functiondef(
    'app_private.create_institution_for_superadmin(uuid,jsonb)'::regprocedure
  ) like '%pg_advisory_xact_lock%'
  and pg_get_functiondef(
    'app_private.create_institution_for_superadmin(uuid,jsonb)'::regprocedure
  ) like '%institution.status.change%'
  and pg_get_functiondef(
    'app_private.create_institution_for_superadmin(uuid,jsonb)'::regprocedure
  ) like '%institution_management_request_hash%'
  ,
  'create enforces permission, MFA, protected status and hashed idempotency'
);

select ok(
  pg_get_functiondef(
    'app_private.update_institution_for_superadmin(uuid,uuid,bigint,jsonb)'::regprocedure
  ) like '%institution.update%'
  and pg_get_functiondef(
    'app_private.update_institution_for_superadmin(uuid,uuid,bigint,jsonb)'::regprocedure
  ) like '%institution.status.change%'
  and pg_get_functiondef(
    'app_private.update_institution_for_superadmin(uuid,uuid,bigint,jsonb)'::regprocedure
  ) like '%plan.change%'
  and pg_get_functiondef(
    'app_private.update_institution_for_superadmin(uuid,uuid,bigint,jsonb)'::regprocedure
  ) like '%for update%'
  ,
  'update enforces granular permissions and row locking'
);

select function_privs_are(
  'public', 'get_institution_for_superadmin', array['uuid'],
  'authenticated', array['EXECUTE'],
  'authenticated can execute read RPC'
);

select function_privs_are(
  'public', 'create_institution_for_superadmin', array['uuid', 'jsonb'],
  'authenticated', array['EXECUTE'],
  'authenticated can execute create RPC'
);

select function_privs_are(
  'public', 'update_institution_for_superadmin',
  array['uuid', 'uuid', 'bigint', 'jsonb'],
  'authenticated', array['EXECUTE'],
  'authenticated can execute update RPC'
);

select ok(
  not has_function_privilege(
    'anon', 'public.get_institution_for_superadmin(uuid)', 'EXECUTE'
  ),
  'anon cannot read institution management records'
);

select ok(
  not has_function_privilege(
    'anon', 'public.create_institution_for_superadmin(uuid,jsonb)', 'EXECUTE'
  ),
  'anon cannot create institutions'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.update_institution_for_superadmin(uuid,uuid,bigint,jsonb)',
    'EXECUTE'
  ),
  'anon cannot update institutions'
);

select ok(
  not exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    cross join lateral aclexplode(
      coalesce(procedure.proacl, acldefault('f', procedure.proowner))
    ) privilege
    where namespace.nspname = 'public'
      and procedure.proname in (
        'get_institution_for_superadmin',
        'create_institution_for_superadmin',
        'update_institution_for_superadmin'
      )
      and privilege.grantee = 0
      and privilege.privilege_type = 'EXECUTE'
  ),
  'PUBLIC has no execute privilege on institution RPCs'
);

select ok(
  not has_table_privilege('authenticated', 'public.institutions', 'INSERT')
  and not has_table_privilege('authenticated', 'public.institutions', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.institution_addresses', 'INSERT')
  and not has_table_privilege('authenticated', 'public.institution_addresses', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.institution_contacts', 'INSERT')
  and not has_table_privilege('authenticated', 'public.institution_contacts', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.institution_branding', 'INSERT')
  and not has_table_privilege('authenticated', 'public.institution_branding', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.institution_subscriptions', 'INSERT')
  and not has_table_privilege('authenticated', 'public.institution_subscriptions', 'UPDATE')
  ,
  'authenticated receives no direct institution write grants'
);

select ok(
  pg_get_functiondef(
    'app_private.update_institution_for_superadmin(uuid,uuid,bigint,jsonb)'::regprocedure
  ) like '%management_version%'
  and pg_get_functiondef(
    'app_private.update_institution_for_superadmin(uuid,uuid,bigint,jsonb)'::regprocedure
  ) like '%institution_management_command_receipts%'
  ,
  'update uses versioning and private receipts'
);

select ok(
  to_regprocedure(
    'app_private.has_scoped_platform_permission(text,uuid)'
  ) is not null
  and has_function_privilege(
    'authenticated',
    'app_private.has_scoped_platform_permission(text,uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'app_private.has_scoped_platform_permission(text,uuid)',
    'EXECUTE'
  ),
  'scoped permission helper is callable only by authenticated RLS'
);

select ok(
  pg_get_functiondef(
    'app_private.get_institution_for_superadmin(uuid)'::regprocedure
  ) like '%has_scoped_platform_permission%'
  and pg_get_functiondef(
    'app_private.create_institution_for_superadmin(uuid,jsonb)'::regprocedure
  ) like '%has_scoped_platform_permission%'
  and pg_get_functiondef(
    'app_private.update_institution_for_superadmin(uuid,uuid,bigint,jsonb)'::regprocedure
  ) like '%has_scoped_platform_permission%',
  'all institution commands enforce membership scope server-side'
);

select ok(
  pg_get_functiondef(
    'app_private.assert_institution_management_payload(jsonb,boolean)'::regprocedure
  ) like '%profile_links exceeds the limit%'
  and pg_get_functiondef(
    'app_private.assert_institution_management_payload(jsonb,boolean)'::regprocedure
  ) like '%invalid profile_link%',
  'branding links are structurally and size validated server-side'
);

select ok(
  not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and policyname in (
        'institutions_platform_read',
        'institution_addresses_platform_read',
        'institution_contacts_platform_read',
        'institution_branding_platform_read',
        'institution_subscriptions_platform_read',
        'units_platform_read',
        'groups_platform_read'
      )
  )
  and (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and policyname in (
        'institutions_scoped_platform_read',
        'institution_addresses_scoped_platform_read',
        'institution_contacts_scoped_platform_read',
        'institution_branding_scoped_platform_read',
        'institution_subscriptions_scoped_platform_read',
        'units_scoped_platform_read',
        'groups_scoped_platform_read'
      )
  ) = 7,
  'directory base tables use only scoped platform read policies'
);

select ok(
  pg_get_functiondef(
    'app_private.has_scoped_platform_permission(text,uuid)'::regprocedure
  ) ilike '%membership.revoked_at is null%'
  and pg_get_functiondef(
    'app_private.has_scoped_platform_permission(text,uuid)'::regprocedure
  ) ilike '%membership.mfa_required%'
  and pg_get_functiondef(
    'app_private.has_scoped_platform_permission(text,uuid)'::regprocedure
  ) ilike '%role_permission.revoked_at is null%',
  'scoped permission rejects revoked membership/grants and enforces membership MFA'
);

select * from finish();
rollback;
