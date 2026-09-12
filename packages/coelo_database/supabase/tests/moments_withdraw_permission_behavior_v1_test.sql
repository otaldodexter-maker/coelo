-- Behavioral complement for candidate 20260912140550.
-- Uses the real system role templates; the fixture never grants remove.
begin;

create extension if not exists pgtap with schema extensions;
select plan(11);

insert into public.institution_types (id, code, name, status) values
  ('9d580000-0000-4000-8000-000000000001', 'moments-withdraw-test', 'Moments withdrawal test', 'active');
insert into public.institutions (id, public_name, slug, status, institution_type_id) values
  ('9d580000-0000-4000-8000-00000000000a', 'Moments withdrawal A', 'moments-withdraw-a', 'active', '9d580000-0000-4000-8000-000000000001'),
  ('9d580000-0000-4000-8000-00000000000b', 'Moments withdrawal B', 'moments-withdraw-b', 'active', '9d580000-0000-4000-8000-000000000001');

insert into public.people (id, person_type, first_name, last_name, display_name, status) values
  ('9d580000-0000-4000-8000-000000000101', 'adult', 'Admin', 'Author', 'Admin Author', 'active'),
  ('9d580000-0000-4000-8000-000000000102', 'adult', 'Admin', 'Other', 'Admin Other', 'active'),
  ('9d580000-0000-4000-8000-000000000103', 'adult', 'Reader', 'Author', 'Reader Author', 'active'),
  ('9d580000-0000-4000-8000-000000000104', 'adult', 'Admin', 'Other Scope', 'Admin Other Scope', 'active');
insert into auth.users (
  id, aud, role, email, email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
) values
  ('9d580000-0000-4000-8000-000000000201', 'authenticated', 'authenticated', 'moments-admin-author@invalid.test', now(), now(), now(), '{}', '{}'),
  ('9d580000-0000-4000-8000-000000000202', 'authenticated', 'authenticated', 'moments-admin-other@invalid.test', now(), now(), now(), '{}', '{}'),
  ('9d580000-0000-4000-8000-000000000203', 'authenticated', 'authenticated', 'moments-reader-author@invalid.test', now(), now(), now(), '{}', '{}'),
  ('9d580000-0000-4000-8000-000000000204', 'authenticated', 'authenticated', 'moments-admin-scope@invalid.test', now(), now(), now(), '{}', '{}');
insert into auth.sessions (id, user_id, created_at, updated_at, aal, not_after) values
  ('9d580000-0000-4000-8000-000000000301', '9d580000-0000-4000-8000-000000000201', now(), now(), 'aal1', now() + interval '1 hour'),
  ('9d580000-0000-4000-8000-000000000302', '9d580000-0000-4000-8000-000000000202', now(), now(), 'aal1', now() + interval '1 hour'),
  ('9d580000-0000-4000-8000-000000000303', '9d580000-0000-4000-8000-000000000203', now(), now(), 'aal1', now() + interval '1 hour'),
  ('9d580000-0000-4000-8000-000000000304', '9d580000-0000-4000-8000-000000000204', now(), now(), 'aal1', now() + interval '1 hour');
insert into public.person_auth_links (person_id, auth_user_id, status) values
  ('9d580000-0000-4000-8000-000000000101', '9d580000-0000-4000-8000-000000000201', 'active'),
  ('9d580000-0000-4000-8000-000000000102', '9d580000-0000-4000-8000-000000000202', 'active'),
  ('9d580000-0000-4000-8000-000000000103', '9d580000-0000-4000-8000-000000000203', 'active'),
  ('9d580000-0000-4000-8000-000000000104', '9d580000-0000-4000-8000-000000000204', 'active');

insert into public.institution_memberships (
  id, person_id, institution_id, role_code, status, scope_kind
) values
  ('9d580000-0000-4000-8000-000000000401', '9d580000-0000-4000-8000-000000000101', '9d580000-0000-4000-8000-00000000000a', 'owner', 'active', 'institution'),
  ('9d580000-0000-4000-8000-000000000402', '9d580000-0000-4000-8000-000000000102', '9d580000-0000-4000-8000-00000000000a', 'owner', 'active', 'institution'),
  ('9d580000-0000-4000-8000-000000000403', '9d580000-0000-4000-8000-000000000103', '9d580000-0000-4000-8000-00000000000a', 'professional', 'active', 'institution'),
  ('9d580000-0000-4000-8000-000000000404', '9d580000-0000-4000-8000-000000000104', '9d580000-0000-4000-8000-00000000000b', 'owner', 'active', 'institution');
insert into public.institution_role_assignments (membership_id, role_id, scope_kind, status)
select fixture.membership_id, role_record.id, 'institution', 'active'
from (values
  ('9d580000-0000-4000-8000-000000000401'::uuid, 'institution_admin'),
  ('9d580000-0000-4000-8000-000000000402'::uuid, 'institution_admin'),
  ('9d580000-0000-4000-8000-000000000403'::uuid, 'institution_reader'),
  ('9d580000-0000-4000-8000-000000000404'::uuid, 'institution_admin')
) fixture(membership_id, role_code)
join public.institution_roles role_record
  on role_record.code = fixture.role_code
 and role_record.institution_id is null
 and role_record.is_system
 and role_record.status = 'active';

insert into public.moments_publications (
  id, institution_id, author_person_id, author_membership_id, caption,
  status, management_version, published_at
) values
  ('9d580000-0000-4000-8000-000000000501', '9d580000-0000-4000-8000-00000000000a', '9d580000-0000-4000-8000-000000000101', '9d580000-0000-4000-8000-000000000401', 'Admin author publication', 'published', 1, now()),
  ('9d580000-0000-4000-8000-000000000502', '9d580000-0000-4000-8000-00000000000a', '9d580000-0000-4000-8000-000000000103', '9d580000-0000-4000-8000-000000000403', 'Reader author publication', 'published', 1, now() - interval '1 second');
insert into public.moments_publication_audiences (
  publication_id, audience_kind, institution_id
) values
  ('9d580000-0000-4000-8000-000000000501', 'school_staff', '9d580000-0000-4000-8000-00000000000a'),
  ('9d580000-0000-4000-8000-000000000502', 'school_staff', '9d580000-0000-4000-8000-00000000000a');

select is(
  (
    select count(*)::bigint
    from public.institution_role_permissions role_permission
    join public.institution_roles role_record on role_record.id = role_permission.role_id
    join public.institution_permissions permission_record on permission_record.id = role_permission.permission_id
    where role_record.code = 'institution_admin' and role_record.is_system
      and role_record.institution_id is null and role_record.status = 'active'
      and permission_record.code = 'moments.publications.remove'
      and role_permission.effect = 'allow' and role_permission.status = 'active'
      and role_permission.revoked_at is null
  ), 1::bigint,
  'the real institution_admin template carries one active withdrawal grant'
);
select ok(
  not exists (
    select 1
    from public.institution_role_permissions role_permission
    join public.institution_roles role_record on role_record.id = role_permission.role_id
    join public.institution_permissions permission_record on permission_record.id = role_permission.permission_id
    where role_record.code = 'institution_reader' and role_record.is_system
      and role_record.institution_id is null
      and permission_record.code = 'moments.publications.remove'
      and role_permission.effect = 'allow' and role_permission.status = 'active'
      and role_permission.revoked_at is null
  ), 'the fixture does not grant withdrawal to the reader template'
);

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', '9d580000-0000-4000-8000-000000000201',
  'session_id', '9d580000-0000-4000-8000-000000000301',
  'aal', 'aal1', 'role', 'authenticated')::text, true);
select is(
  (select can_withdraw from public.list_visible_moments(
    '9d580000-0000-4000-8000-00000000000a', null, null, 20, null
  ) where publication_id = '9d580000-0000-4000-8000-000000000501'),
  true, 'admin author receives a truthful can_withdraw hint'
);
select lives_ok(
  $$select public.withdraw_moment(
    '9d580000-0000-4000-8000-000000000601',
    '9d580000-0000-4000-8000-000000000501', null, 'behavioral proof'
  )$$,
  'admin author withdraws through the command using the real template grant'
);
select lives_ok(
  $$select public.withdraw_moment(
    '9d580000-0000-4000-8000-000000000601',
    '9d580000-0000-4000-8000-000000000501', null, 'behavioral proof'
  )$$,
  'identical withdrawal request replays without a second mutation'
);
select is(
  (select count(*)::bigint from public.list_visible_moments(
    '9d580000-0000-4000-8000-00000000000a', null, null, 20, null
  ) where publication_id = '9d580000-0000-4000-8000-000000000501'),
  0::bigint, 'withdrawn publication leaves the visible feed'
);
select ok(
  exists (
    select 1 from app_private.moments_publication_audit
    where publication_id = '9d580000-0000-4000-8000-000000000501'
      and event_code = 'publication_withdrawn'
  ), 'successful withdrawal remains audited'
);

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', '9d580000-0000-4000-8000-000000000202',
  'session_id', '9d580000-0000-4000-8000-000000000302',
  'aal', 'aal1', 'role', 'authenticated')::text, true);
select throws_ok(
  $$select public.withdraw_moment(
    '9d580000-0000-4000-8000-000000000602',
    '9d580000-0000-4000-8000-000000000501', null, 'must fail'
  )$$,
  '42501', 'publication_not_authorized',
  'another administrator cannot withdraw a publication they did not author'
);

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', '9d580000-0000-4000-8000-000000000203',
  'session_id', '9d580000-0000-4000-8000-000000000303',
  'aal', 'aal1', 'role', 'authenticated')::text, true);
select is(
  (select can_withdraw from public.list_visible_moments(
    '9d580000-0000-4000-8000-00000000000a', null, null, 20, null
  ) where publication_id = '9d580000-0000-4000-8000-000000000502'),
  false, 'reader author receives can_withdraw false without remove capability'
);
select throws_ok(
  $$select public.withdraw_moment(
    '9d580000-0000-4000-8000-000000000603',
    '9d580000-0000-4000-8000-000000000502', null, 'must fail'
  )$$,
  '42501', 'moments_permission_denied',
  'reader author cannot bypass the removal capability'
);

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', '9d580000-0000-4000-8000-000000000204',
  'session_id', '9d580000-0000-4000-8000-000000000304',
  'aal', 'aal1', 'role', 'authenticated')::text, true);
select throws_ok(
  $$select public.withdraw_moment(
    '9d580000-0000-4000-8000-000000000604',
    '9d580000-0000-4000-8000-000000000502', null, 'must fail'
  )$$,
  '42501', 'moments_permission_denied',
  'administrator from another institution cannot withdraw across scope'
);

select set_config('request.jwt.claims', '', true);
select * from finish();
rollback;
