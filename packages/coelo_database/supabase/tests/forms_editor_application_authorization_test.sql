begin;

create extension if not exists pgtap with schema extensions;
select plan(5);

insert into auth.users(id, aud, role, email, created_at, updated_at) values
  ('86000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'forms-editor-reader@test.invalid', now(), now()),
  ('86000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'forms-editor-app-manager@test.invalid', now(), now());

insert into public.people(id, person_type, first_name, last_name, display_name, status) values
  ('86100000-0000-4000-8000-000000000001', 'adult', 'Editor', 'Reader', 'Editor Reader', 'active'),
  ('86100000-0000-4000-8000-000000000002', 'adult', 'Application', 'Manager', 'Application Manager', 'active');

insert into public.person_auth_links(person_id, auth_user_id, status) values
  ('86100000-0000-4000-8000-000000000001', '86000000-0000-4000-8000-000000000001', 'active'),
  ('86100000-0000-4000-8000-000000000002', '86000000-0000-4000-8000-000000000002', 'active');

insert into public.platform_roles(id, code, name, status, is_system) values
  ('86200000-0000-4000-8000-000000000001', 'forms_editor_reader_only', 'Forms editor reader only', 'active', true),
  ('86200000-0000-4000-8000-000000000002', 'forms_editor_application_manager', 'Forms editor application manager', 'active', true);

insert into public.platform_role_permissions(role_id, permission_id, effect)
select '86200000-0000-4000-8000-000000000001', permission.id, 'allow'
  from public.platform_permissions permission
 where permission.code = 'forms.read';

insert into public.platform_role_permissions(role_id, permission_id, effect)
select '86200000-0000-4000-8000-000000000002', permission.id, 'allow'
  from public.platform_permissions permission
 where permission.code in ('forms.manage', 'forms.manage_applications');

insert into public.platform_memberships(person_id, role_id, status, scope_kind, mfa_required) values
  ('86100000-0000-4000-8000-000000000001', '86200000-0000-4000-8000-000000000001', 'active', 'platform', false),
  ('86100000-0000-4000-8000-000000000002', '86200000-0000-4000-8000-000000000002', 'active', 'platform', false);

insert into public.institutions(id, public_name, legal_name, slug, status) values
  ('86300000-0000-4000-8000-000000000001', 'Forms Editor A', 'Forms Editor A', 'forms-editor-a', 'active'),
  ('86300000-0000-4000-8000-000000000002', 'Forms Editor B', 'Forms Editor B', 'forms-editor-b', 'active');

insert into public.forms(
  id, institution_id, kind, identity_mode, response_unit, title,
  created_by_person_id, updated_by_person_id
) values (
  '86400000-0000-4000-8000-000000000001',
  '86300000-0000-4000-8000-000000000001',
  'form', 'identified', 'person', 'Capability-scoped editor',
  '86100000-0000-4000-8000-000000000002',
  '86100000-0000-4000-8000-000000000002'
);

insert into public.form_applications(
  id, form_id, institution_id, name, created_by_person_id
) values (
  '86500000-0000-4000-8000-000000000001',
  '86400000-0000-4000-8000-000000000001',
  '86300000-0000-4000-8000-000000000001',
  'Authorized application',
  '86100000-0000-4000-8000-000000000002'
);

alter table public.form_applications disable trigger form_applications_tenant_validate;
insert into public.form_applications(
  id, form_id, institution_id, name, created_by_person_id, updated_at
) values (
  '86500000-0000-4000-8000-000000000002',
  '86400000-0000-4000-8000-000000000001',
  '86300000-0000-4000-8000-000000000002',
  'Forged cross-institution application',
  '86100000-0000-4000-8000-000000000002',
  now() + interval '1 hour'
);
alter table public.form_applications enable trigger form_applications_tenant_validate;

set local role authenticated;
select set_config('request.jwt.claim.sub', '86000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"86000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}', true);

select ok(
  public.form_get_editor('86400000-0000-4000-8000-000000000001') -> 'definition' is not null,
  'forms.read keeps the definition projection available'
);
select ok(
  public.form_get_editor('86400000-0000-4000-8000-000000000001') -> 'application' = 'null'::jsonb,
  'forms.read alone cannot observe application configuration'
);

select set_config('request.jwt.claim.sub', '86000000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claims', '{"sub":"86000000-0000-4000-8000-000000000002","aal":"aal1","role":"authenticated"}', true);

select ok(
  public.form_get_editor('86400000-0000-4000-8000-000000000001') -> 'definition' is not null,
  'forms.manage without forms.read keeps the definition projection available'
);
select is(
  public.form_get_editor('86400000-0000-4000-8000-000000000001') -> 'application' ->> 'id',
  '86500000-0000-4000-8000-000000000001',
  'forms.manage_applications reveals the same-institution application projection'
);

select throws_ok(
  $$
    select public.form_save_application(
      '86500000-0000-4000-8000-000000000003',
      0,
      jsonb_build_object(
        'id', '86500000-0000-4000-8000-000000000003',
        'form_id', '86400000-0000-4000-8000-000000000001',
        'institution_id', '86300000-0000-4000-8000-000000000002',
        'name', 'Forged target',
        'status', 'active',
        'opens_for_days', 7,
        'rules', '[]'::jsonb
      )
    )
  $$,
  '22023',
  'form and institution must match',
  'save application rejects a client-forged form and institution pairing'
);

reset role;
select * from finish();
rollback;
