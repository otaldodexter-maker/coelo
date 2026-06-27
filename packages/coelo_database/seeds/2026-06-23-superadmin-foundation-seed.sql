-- Superadmin Foundation v1 seed
-- Owner MFA/login final will be completed in a later step.

insert into public.people (
  id, person_type, first_name, last_name, display_name, legal_name, date_of_birth, status
)
values (
  '00000000-0000-0000-0000-000000000001',
  'adult',
  'Adriel',
  'da Silva Barbosa Coelho',
  'Owner Coelo',
  'Adriel Coelo',
  '1992-07-24',
  'active'
)
on conflict (id) do nothing;

insert into public.platform_memberships (
  id, person_id, role_id, status, scope_kind, scope_institution_id, mfa_required
)
select
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  pr.id,
  'active',
  'platform',
  null,
  true
from public.platform_roles pr
where pr.code = 'owner'
on conflict (id) do nothing;
