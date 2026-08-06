begin;

create extension if not exists pgtap with schema extensions;

select plan(33);

select has_column(
  'public',
  'platform_roles',
  'max_scope_kind',
  'platform roles expose a maximum scope'
);
select has_column(
  'app_private',
  'access_profile_command_receipts',
  'request_json',
  'idempotency receipts bind request ids to the original payload'
);
select has_column(
  'public',
  'platform_roles',
  'version',
  'platform roles support optimistic concurrency'
);
select has_column(
  'public',
  'institution_roles',
  'max_scope_kind',
  'institution roles expose a maximum scope'
);
select has_column(
  'public',
  'institution_roles',
  'version',
  'institution roles support optimistic concurrency'
);

select results_eq(
  $$select count(*)::bigint
      from public.platform_permissions
     where code in ('platform.roles.manage', 'institution.roles.manage')
       and status = 'active'$$,
  array[2::bigint],
  'the two approved profile management permissions exist'
);
select results_eq(
  $$select count(*)::bigint
      from public.platform_role_permissions grant_record
      join public.platform_roles role_record on role_record.id = grant_record.role_id
      join public.platform_permissions permission_record
        on permission_record.id = grant_record.permission_id
     where permission_record.code in (
       'platform.roles.manage',
       'institution.roles.manage'
     )
       and grant_record.effect = 'allow'
       and grant_record.status = 'active'
       and role_record.code <> 'owner'$$,
  array[0::bigint],
  'profile management permissions are initially granted only to Owner'
);

select has_function(
  'public',
  'superadmin_access_profiles_list',
  array['text', 'text', 'text', 'text', 'integer', 'integer'],
  'profile list RPC exists'
);
select has_function(
  'public',
  'superadmin_access_profile_detail',
  array['text', 'uuid'],
  'profile detail RPC exists'
);
select has_function(
  'public',
  'superadmin_access_profile_save',
  array['uuid', 'bigint', 'text', 'jsonb'],
  'profile save RPC exists'
);
select has_function(
  'public',
  'superadmin_access_profile_delete_and_reassign',
  array['uuid', 'text', 'uuid', 'bigint', 'uuid', 'text'],
  'transactional delete and reassign RPC exists'
);
select has_function(
  'public',
  'superadmin_principal_capabilities_summary',
  array[]::text[],
  'Principal capabilities summary RPC exists'
);

select function_returns(
  'public',
  'superadmin_access_profiles_list',
  array['text', 'text', 'text', 'text', 'integer', 'integer'],
  'jsonb',
  'profile list returns a stable JSON contract'
);
select function_returns(
  'public',
  'superadmin_access_profile_detail',
  array['text', 'uuid'],
  'jsonb',
  'profile detail returns a stable JSON contract'
);
select like(
  pg_get_functiondef(
    'public.superadmin_access_profile_detail(text,uuid)'::regprocedure
  ),
  '%if p_domain = ''platform'' then%''screen_code'', permission_record.screen_code%elsif p_domain = ''institution'' then%''screen_code'', permission_record.screen_code%',
  'profile detail exposes explicit screen metadata in both writable domains'
);
select like(
  pg_get_functiondef(
    'public.superadmin_access_profile_detail(text,uuid)'::regprocedure
  ),
  '%if p_domain = ''platform'' then%''action_code'', permission_record.action_code%elsif p_domain = ''institution'' then%''action_code'', permission_record.action_code%',
  'profile detail exposes explicit action metadata in both writable domains'
);
select ok(
  (
    select procedure.prosecdef
       and procedure.provolatile = 's'
       and procedure.proconfig @> array['search_path=pg_catalog, public']
      from pg_proc procedure
     where procedure.oid =
       'public.superadmin_access_profile_detail(text,uuid)'::regprocedure
  ),
  'profile detail remains stable, security definer and search-path constrained'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.superadmin_access_profile_detail(text,uuid)',
    'EXECUTE'
  ),
  'anonymous cannot read access profile details'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.superadmin_access_profile_detail(text,uuid)',
    'EXECUTE'
  ),
  'authenticated can execute the guarded access profile detail RPC'
);
select function_returns(
  'public',
  'superadmin_access_profile_save',
  array['uuid', 'bigint', 'text', 'jsonb'],
  'jsonb',
  'profile save returns the saved aggregate'
);
select function_returns(
  'public',
  'superadmin_access_profile_delete_and_reassign',
  array['uuid', 'text', 'uuid', 'bigint', 'uuid', 'text'],
  'jsonb',
  'delete and reassign returns the command result'
);
select function_returns(
  'public',
  'superadmin_principal_capabilities_summary',
  array[]::text[],
  'jsonb',
  'Principal summary returns a read-only JSON contract'
);

select is(
  position(
    'role_code = ''owner'''
    in pg_get_functiondef(
      'app_private.has_platform_permission(text)'::regprocedure
    )
  ),
  0,
  'platform authorization no longer contains an implicit Owner bypass'
);
select like(
  pg_get_functiondef(
    'app_private.has_platform_permission(text)'::regprocedure
  ),
  '%effect=''deny''%',
  'platform authorization evaluates explicit denies'
);
select like(
  pg_get_functiondef(
    'app_private.has_platform_permission(text)'::regprocedure
  ),
  '%not exists%',
  'platform authorization gives deny precedence'
);
select like(
  pg_get_functiondef(
    'app_private.has_platform_permission(text)'::regprocedure
  ),
  '%scope_kind=''platform''%',
  'platform profile authority requires a global platform membership'
);
select like(
  pg_get_functiondef(
    'public.superadmin_access_profile_save(uuid,bigint,text,jsonb)'::regprocedure
  ),
  '%explicit deny cannot be replaced%',
  'profile save preserves explicit denies'
);

select table_privs_are(
  'app_private',
  'access_profile_command_receipts',
  'authenticated',
  array[]::text[],
  'authenticated clients cannot access command receipts directly'
);
select function_privs_are(
  'public',
  'superadmin_access_profile_save',
  array['uuid', 'bigint', 'text', 'jsonb'],
  'anon',
  array[]::text[],
  'anonymous clients cannot execute profile mutations'
);
select function_privs_are(
  'public',
  'superadmin_access_profile_delete_and_reassign',
  array['uuid', 'text', 'uuid', 'bigint', 'uuid', 'text'],
  'anon',
  array[]::text[],
  'anonymous clients cannot delete profiles'
);
select function_privs_are(
  'public',
  'superadmin_access_profile_save',
  array['uuid', 'bigint', 'text', 'jsonb'],
  'authenticated',
  array['EXECUTE'],
  'authenticated clients can call the guarded save RPC'
);
select function_privs_are(
  'public',
  'superadmin_access_profile_delete_and_reassign',
  array['uuid', 'text', 'uuid', 'bigint', 'uuid', 'text'],
  'authenticated',
  array['EXECUTE'],
  'authenticated clients can call the guarded delete RPC'
);

select results_eq(
  $$select count(*)::bigint
      from public.guardian_permission_capabilities
     where status = 'active'
       and code in (
         'view_context',
         'message',
         'react',
         'manage_authorized_people',
         'manage_attendance_notices'
       )$$,
  array[5::bigint],
  'Principal remains the approved contextual capability catalog'
);

select * from finish();

rollback;
