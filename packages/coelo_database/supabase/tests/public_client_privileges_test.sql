begin;
select plan(5);

select is(
  (
    select count(*)
    from information_schema.role_table_grants
    where table_schema = 'public'
      and grantee in ('anon', 'authenticated')
      and privilege_type in ('TRUNCATE', 'REFERENCES', 'TRIGGER')
  ),
  0::bigint,
  'Data API roles have no structural table privileges'
);

select ok(
  has_table_privilege('authenticated', 'public.activity_permission_profiles', 'SELECT'),
  'authenticated keeps an explicitly approved read grant'
);

select ok(
  has_table_privilege('authenticated', 'public.activity_permission_profiles', 'INSERT'),
  'authenticated keeps an explicitly approved create grant'
);

select ok(
  not has_table_privilege('authenticated', 'public.units', 'TRUNCATE'),
  'authenticated cannot truncate units and bypass RLS'
);

select ok(
  not has_table_privilege('anon', 'public.units', 'TRIGGER'),
  'anonymous callers cannot create triggers on units'
);

select * from finish();
rollback;
