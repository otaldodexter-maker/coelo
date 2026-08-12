begin;
select plan(17);

select has_function(
  'public', 'superadmin_search_activity_professionals',
  array['uuid', 'text', 'integer'],
  'professional search RPC exists'
);
select function_privs_are(
  'public', 'superadmin_search_activity_professionals',
  array['uuid', 'text', 'integer'], 'anon', array[]::text[],
  'anonymous has no professional search privilege'
);
select function_privs_are(
  'public', 'superadmin_search_activity_professionals',
  array['uuid', 'text', 'integer'], 'authenticated', array['EXECUTE'],
  'authenticated can invoke the guarded RPC'
);
select ok(
  pg_get_functiondef(
    'app_private.superadmin_search_activity_professionals(uuid,text,integer)'::regprocedure
  ) like '%membership.institution_id = p_institution_id%',
  'query starts from the requested institution scope'
);
select ok(
  pg_get_functiondef(
    'app_private.superadmin_search_activity_professionals(uuid,text,integer)'::regprocedure
  ) not like '%normalized_value_hash%'
  and pg_get_functiondef(
    'app_private.superadmin_search_activity_professionals(uuid,text,integer)'::regprocedure
  ) not like '%normalized_value_hmac%'
  and pg_get_functiondef(
    'app_private.superadmin_search_activity_professionals(uuid,text,integer)'::regprocedure
  ) not like '%auth.users%',
  'RPC does not guess contact digests or query Auth identities'
);

set local role authenticated;
select throws_ok(
  $call$select public.superadmin_search_activity_professionals(
    '31000000-0000-4000-8000-000000000001', '@prof', 20
  )$call$,
  '42501', 'unauthorized',
  'unmapped callers cannot search professionals'
);
reset role;

-- Test only this RPC's authorization and scoping; helper replacements are
-- transaction-local because the test ends with rollback.
create or replace function app_private.current_person_id()
returns uuid language sql stable security definer set search_path = ''
as $$select '31000000-0000-4000-8000-000000000099'::uuid$$;
create or replace function app_private.has_platform_permission(permission_code text)
returns boolean language sql stable security definer set search_path = ''
as $$select permission_code = 'activities.assign_people'$$;
create or replace function app_private.has_mfa_aal2()
returns boolean language sql stable security definer set search_path = ''
as $$select true$$;

insert into public.institutions(id, public_name, slug, status)
values
  ('31000000-0000-4000-8000-000000000001', 'Institution A', 'search-a', 'active'),
  ('31000000-0000-4000-8000-000000000002', 'Institution B', 'search-b', 'active');
insert into public.people(id, person_type, first_name, last_name, display_name)
values
  ('31000000-0000-4000-8000-000000000011', 'adult', 'Ana', 'Instrutora', 'Ana Instrutora'),
  ('31000000-0000-4000-8000-000000000012', 'adult', 'Bia', 'Instrutora', 'Bia Instrutora'),
  ('31000000-0000-4000-8000-000000000013', 'child', 'Caio', 'Aluno', 'Caio Aluno');
insert into public.institution_memberships(id, person_id, institution_id, role_code)
values
  ('31000000-0000-4000-8000-000000000021', '31000000-0000-4000-8000-000000000011', '31000000-0000-4000-8000-000000000001', 'instructor'),
  ('31000000-0000-4000-8000-000000000022', '31000000-0000-4000-8000-000000000012', '31000000-0000-4000-8000-000000000002', 'instructor'),
  ('31000000-0000-4000-8000-000000000023', '31000000-0000-4000-8000-000000000013', '31000000-0000-4000-8000-000000000001', 'student');
insert into public.person_handles(person_id, normalized_handle)
values
  ('31000000-0000-4000-8000-000000000011', 'prof.ana'),
  ('31000000-0000-4000-8000-000000000012', 'prof.bia'),
  ('31000000-0000-4000-8000-000000000013', 'prof.caio');

set local role authenticated;
select set_config('request.jwt.claim.sub', '31000000-0000-4000-8000-000000000099', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"31000000-0000-4000-8000-000000000099","aal":"aal2","role":"authenticated"}',
  true
);

reset role;
create or replace function app_private.has_platform_permission(permission_code text)
returns boolean language sql stable security definer set search_path = ''
as $$select false$$;
set local role authenticated;
select throws_ok(
  $call$select public.superadmin_search_activity_professionals(
    '31000000-0000-4000-8000-000000000001', '@prof', 20
  )$call$,
  '42501', 'unauthorized',
  'missing activities.assign_people denies lookup'
);
reset role;
create or replace function app_private.has_platform_permission(permission_code text)
returns boolean language sql stable security definer set search_path = ''
as $$select permission_code = 'activities.assign_people'$$;
create or replace function app_private.has_mfa_aal2()
returns boolean language sql stable security definer set search_path = ''
as $$select false$$;
set local role authenticated;
select throws_ok(
  $call$select public.superadmin_search_activity_professionals(
    '31000000-0000-4000-8000-000000000001', '@prof', 20
  )$call$,
  '42501', 'mfa_required',
  'AAL1 denies professional lookup'
);
reset role;
create or replace function app_private.has_mfa_aal2()
returns boolean language sql stable security definer set search_path = ''
as $$select true$$;
set local role authenticated;

select is(
  jsonb_array_length(public.superadmin_search_activity_professionals(
    '31000000-0000-4000-8000-000000000001', '@prof', 20
  )->'items'), 1,
  'handle lookup returns only adult members of institution A'
);
select is(
  public.superadmin_search_activity_professionals(
    '31000000-0000-4000-8000-000000000001', '@prof', 20
  )#>>'{items,0,person_id}',
  '31000000-0000-4000-8000-000000000011',
  'handle lookup returns institution A professional'
);
select is(
  public.superadmin_search_activity_professionals(
    '31000000-0000-4000-8000-000000000002', 'Bia', 20
  )#>>'{items,0,person_id}',
  '31000000-0000-4000-8000-000000000012',
  'name lookup works inside institution B'
);
select unlike(
  public.superadmin_search_activity_professionals(
    '31000000-0000-4000-8000-000000000001', '@prof', 20
  )::text,
  '(email|phone|cpf|normalized_value)',
  'response contains no contact or identifier material'
);
select throws_ok(
  $call$select public.superadmin_search_activity_professionals(
    '31000000-0000-4000-8000-000000000001', 'ana@example.test', 20
  )$call$,
  '0A000', 'identity_lookup_not_configured',
  'email lookup fails closed without a canonical digest command'
);
select throws_ok(
  $call$select public.superadmin_search_activity_professionals(
    '31000000-0000-4000-8000-000000000001', '52998224725', 20
  )$call$,
  '0A000', 'identity_lookup_not_configured',
  'CPF lookup fails closed without a keyed lookup command'
);
select throws_ok(
  $call$select public.superadmin_search_activity_professionals(
    '31000000-0000-4000-8000-000000000001', '+5511999990000', 20
  )$call$,
  '0A000', 'identity_lookup_not_configured',
  'phone lookup fails closed without a canonical digest command'
);
select throws_ok(
  $call$select public.superadmin_search_activity_professionals(
    '31000000-0000-4000-8000-000000000001', '@a', 20
  )$call$,
  '22023', 'invalid_query',
  'short queries are rejected'
);
select throws_ok(
  $call$select public.superadmin_search_activity_professionals(
    '31000000-0000-4000-8000-000000000001', '@prof', 51
  )$call$,
  '22023', 'invalid_limit',
  'oversized limits are rejected'
);
reset role;

select * from finish();
rollback;
