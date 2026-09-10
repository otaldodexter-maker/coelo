-- Prova do pacote 20260910120000: apagar imagem de cardapio exige a revisao
-- lida pelo cliente. A forma legada de dois argumentos, que preenchia sozinha a
-- revisao esperada e por isso nunca detectava conflito, deixa de existir.
begin;

create extension if not exists pgtap with schema extensions;

select plan(6);

select hasnt_function(
  'public', 'meal_plan_request_image_delete', array['uuid', 'uuid'],
  'the legacy two-argument delete is no longer exposed to clients');
select hasnt_function(
  'app_private', 'meal_plan_request_image_delete', array['uuid', 'uuid'],
  'the legacy two-argument delete is gone from the private schema too');
select ok(
  has_function_privilege('authenticated',
    'public.meal_plan_request_image_delete(uuid,uuid,integer)', 'EXECUTE')
  and not has_function_privilege('anon',
    'public.meal_plan_request_image_delete(uuid,uuid,integer)', 'EXECUTE')
  and not has_function_privilege('authenticated',
    'app_private.meal_plan_request_image_delete(uuid,uuid,integer)', 'EXECUTE'),
  'only the revisioned delete stays reachable, and only through public');

insert into auth.users(id, aud, role, email, created_at, updated_at) values
  ('9b000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'meal-rev-a@test.invalid', now(), now()),
  ('9b000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'meal-rev-b@test.invalid', now(), now());
insert into public.people(id, person_type, first_name, last_name, display_name, status) values
  ('9b100000-0000-4000-8000-000000000001', 'adult', 'Meal', 'Rev A', 'Meal Rev A', 'active'),
  ('9b100000-0000-4000-8000-000000000002', 'adult', 'Meal', 'Rev B', 'Meal Rev B', 'active');
insert into public.person_auth_links(person_id, auth_user_id, status) values
  ('9b100000-0000-4000-8000-000000000001', '9b000000-0000-4000-8000-000000000001', 'active'),
  ('9b100000-0000-4000-8000-000000000002', '9b000000-0000-4000-8000-000000000002', 'active');
insert into public.institutions(id, public_name, legal_name, slug, status) values
  ('9b200000-0000-4000-8000-000000000001', 'Meal Rev Institution A', 'Meal Rev Institution A', 'meal-rev-a', 'active'),
  ('9b200000-0000-4000-8000-000000000002', 'Meal Rev Institution B', 'Meal Rev Institution B', 'meal-rev-b', 'active');
insert into public.platform_memberships(
  person_id, role_id, status, scope_kind, scope_institution_id, mfa_required
)
-- O ator A e Owner de plataforma. app_private.has_platform_permission so
-- enxerga membership com scope_kind='platform' e instituicao nula, entao um
-- Owner de instituicao nao teria meal_plans.manage nem apos a concessao.
select '9b100000-0000-4000-8000-000000000001', id, 'active', 'platform',
  null, false
from public.platform_roles where code = 'owner';
insert into public.platform_memberships(
  person_id, role_id, status, scope_kind, scope_institution_id, mfa_required
)
select '9b100000-0000-4000-8000-000000000002', id, 'active', 'institution',
  '9b200000-0000-4000-8000-000000000002', false
from public.platform_roles where code = 'owner';
insert into public.meal_plans(
  id, tenant_id, institution_id, name, status, source_type, scope_level,
  scope_id, start_date, end_date, created_by, updated_by
) values (
  '9b300000-0000-4000-8000-000000000001', '9b200000-0000-4000-8000-000000000001',
  '9b200000-0000-4000-8000-000000000001', 'Meal Rev A', 'draft', 'institution',
  'institution', '9b200000-0000-4000-8000-000000000001', current_date, current_date,
  '9b100000-0000-4000-8000-000000000001', '9b100000-0000-4000-8000-000000000001'
);
insert into public.meal_plan_image_assets(
  id, tenant_id, institution_id, resource_kind, meal_plan_id, storage_path,
  mime_type, size_bytes, checksum_sha256, status, created_by, activated_at
) values (
  '9b400000-0000-4000-8000-000000000001',
  '9b200000-0000-4000-8000-000000000001',
  '9b200000-0000-4000-8000-000000000001', 'meal_plan',
  '9b300000-0000-4000-8000-000000000001',
  'meal-plans/9b300000-0000-4000-8000-000000000001/9b400000-0000-4000-8000-000000000001.jpg',
  'image/jpeg', 100, repeat('b', 64), 'active',
  '9b100000-0000-4000-8000-000000000001', now()
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '9b000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"9b000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}', true);

-- O ativo nasce na revisao 1. Uma revisao velha e uma revisao futura sao os dois
-- lados do mesmo defeito: a forma legada aceitaria ambas por reler o banco.
select throws_ok(
  $$select public.meal_plan_request_image_delete(
    '9b400000-0000-4000-8000-000000000001',
    '9b500000-0000-4000-8000-000000000001', 2)$$,
  'P0003', 'meal plan image revision conflict',
  'a stale revision cannot delete the image');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '9b000000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"9b000000-0000-4000-8000-000000000002","aal":"aal1","role":"authenticated"}', true);
select throws_ok(
  $$select public.meal_plan_request_image_delete(
    '9b400000-0000-4000-8000-000000000001',
    '9b500000-0000-4000-8000-000000000002', 1)$$,
  '42501', 'meal plan image delete denied',
  'an institution-scoped actor from another tenant is denied even with the right revision');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '9b000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"9b000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}', true);
select is(
  (public.meal_plan_request_image_delete(
    '9b400000-0000-4000-8000-000000000001',
    '9b500000-0000-4000-8000-000000000003', 1) ->> 'revision'),
  '2',
  'the owner deletes with the revision it read and the asset moves forward');

reset role;
select * from finish();
rollback;
