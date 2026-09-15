begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select ok(
  to_regprocedure('public.superadmin_account_profile_get()') is not null,
  'Account reader exposes the zero-argument self contract'
);
select ok(
  to_regprocedure('public.superadmin_account_profile_get(uuid)') is null,
  'Account reader has no arbitrary account id parameter'
);
select ok(
  pg_get_functiondef('public.superadmin_account_profile_get()'::regprocedure)
    like '%assert_account_actor%',
  'Account reader asserts the authenticated internal actor'
);
select is(
  has_function_privilege('anon', 'public.superadmin_account_profile_get()', 'execute'),
  false,
  'anonymous users cannot execute the self reader'
);
select is(
  has_function_privilege('authenticated', 'public.superadmin_account_profile_get()', 'execute'),
  true,
  'authenticated users reach only the self reader contract'
);
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', '0f140000-0000-4000-8000-000000000001',
    'role', 'authenticated',
    'aal', 'aal2'
  )::text,
  true
);
select throws_ok(
  $$select public.superadmin_account_profile_get()$$,
  '42501',
  'internal_actor_required',
  'an authenticated user without an internal identity cannot read another account'
);

select * from finish();
rollback;
