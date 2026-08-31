begin;

create extension if not exists pgtap with schema extensions;

select plan(4);

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

select * from finish();

rollback;
