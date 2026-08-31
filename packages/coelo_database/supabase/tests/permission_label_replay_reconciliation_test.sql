begin;

create extension if not exists pgtap with schema extensions;

select plan(9);

select has_column(
  'public',
  'platform_role_permissions',
  'updated_at',
  'platform role grants expose the timestamp required by historical upserts'
);

select is(
  (
    select count(*)::bigint
    from public.platform_permissions
    where module_label = '__replay_legacy__'
       or screen_label = '__replay_legacy__'
       or action_label = '__replay_legacy__'
  ),
  0::bigint,
  'platform permission labels contain no replay sentinel'
);

select is(
  (
    select count(*)::bigint
    from public.institution_permissions
    where module_label = '__replay_legacy__'
       or screen_label = '__replay_legacy__'
       or action_label = '__replay_legacy__'
  ),
  0::bigint,
  'institution permission labels contain no replay sentinel'
);

select is(
  (
    select count(*)::bigint
    from information_schema.columns
    where table_schema = 'public'
      and table_name in ('platform_permissions', 'institution_permissions')
      and column_name in ('module_label', 'screen_label', 'action_label')
      and column_default is not null
  ),
  0::bigint,
  'all six replay-only label defaults are removed'
);

select is(
  (
    select count(*)::bigint
    from public.platform_permissions
    where (code = 'platform.roles.export' and module_label = 'Superadmin'
           and screen_label = 'Perfis e permissões' and action_label = 'Exportar')
       or (code = 'platform.roles.import' and module_label = 'Superadmin'
           and screen_label = 'Perfis e permissões' and action_label = 'Importar')
       or (code = 'institution.roles.export' and module_label = 'Instituições'
           and screen_label = 'Perfis e permissões' and action_label = 'Exportar')
       or (code = 'institution.roles.import' and module_label = 'Instituições'
           and screen_label = 'Perfis e permissões' and action_label = 'Importar')
  ),
  4::bigint,
  'approved permission entries retain their exact Portuguese labels'
);

select is(
  (
    select count(*)::bigint
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'platform_role_permissions'
      and column_name = 'updated_at'
      and data_type = 'timestamp with time zone'
      and is_nullable = 'NO'
      and column_default = 'now()'
  ),
  1::bigint,
  'platform role grant timestamp has the complete canonical contract'
);

select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc procedure
    cross join lateral pg_catalog.aclexplode(
      coalesce(procedure.proacl, pg_catalog.acldefault('f', procedure.proowner))
    ) privilege
    where procedure.oid = 'app_private.assert_permission_label_replay_contract()'::regprocedure
      and privilege.grantee = 0
      and privilege.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute the replay contract validator'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.assert_permission_label_replay_contract()',
    'EXECUTE'
  ),
  'authenticated cannot execute the replay contract validator'
);

alter table public.platform_permissions
  alter column module_label set default 'unexpected';

select throws_ok(
  $$select app_private.assert_permission_label_replay_contract()$$,
  '55000',
  'unexpected permission label replay contract',
  'validator fails closed when a label default drifts'
);

alter table public.platform_permissions
  alter column module_label drop default;

select * from finish();

rollback;
