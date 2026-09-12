-- scopeRules como objeto no rascunho de cardapio (pacote 20260911130500, R06
-- principal-chat-sistema). Protege: o payload que o assistente envia (objeto
-- por nivel) grava o rascunho, popula meal_plan_scopes e respeita a check
-- meal_plans_scope_rules_array_check; lista continua aceita; a edicao sem a
-- chave preserva o valor gravado.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users(id, aud, role, email, created_at, updated_at) values
  ('9b000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'scope-owner@test.invalid', now(), now());
insert into public.people(id, person_type, first_name, last_name, display_name, status) values
  ('9b100000-0000-4000-8000-000000000001', 'adult', 'Scope', 'Owner', 'Scope Owner', 'active');
insert into public.person_auth_links(person_id, auth_user_id, status) values
  ('9b100000-0000-4000-8000-000000000001', '9b000000-0000-4000-8000-000000000001', 'active');
insert into public.institutions(id, public_name, legal_name, slug, status) values
  ('9b200000-0000-4000-8000-000000000001', 'Scope Institution', 'Scope Institution', 'scope-rules-a', 'active');
insert into public.platform_memberships(person_id, role_id, status, scope_kind, scope_institution_id, mfa_required)
select '9b100000-0000-4000-8000-000000000001', id, 'active', 'platform', null, false
from public.platform_roles where code = 'owner';

-- 1-2: helpers
select is(app_private.meal_plan_scope_rules_object(null), '{}'::jsonb, 'objeto: nulo vira {}');
select is(
  jsonb_array_length(app_private.meal_plan_scope_rules_array(
    '{"institutionIds":["9b200000-0000-4000-8000-000000000001"],"unitIds":["9b210000-0000-4000-8000-000000000001"],"groupIds":[],"excludedPersonIds":["x"]}'::jsonb,
    '9b200000-0000-4000-8000-000000000001')),
  2, 'array: objeto por nivel vira duas regras (instituicao e unidade); excluidos ficam fora');

create temporary table scope_results(key text primary key, result jsonb not null);
grant select, insert on scope_results to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub', '9b000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"9b000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}', true);

-- 3-6: payload do assistente (objeto) grava e popula meal_plan_scopes
insert into scope_results(key, result)
select 'create', public.meal_plan_create_or_update_draft(
  'scope-rules-create',
  jsonb_build_object(
    'name', 'Cardapio scopeRules objeto',
    'institutionId', '9b200000-0000-4000-8000-000000000001',
    'tenantId', '9b200000-0000-4000-8000-000000000001',
    'scopeLevel', 'institution',
    'scopeId', '9b200000-0000-4000-8000-000000000001',
    'sourceType', 'institution',
    'startDate', current_date::text, 'endDate', (current_date + 6)::text,
    'planVariant', 'complete', 'audienceSegment', 'students',
    'scopeRules', jsonb_build_object(
      'institutionIds', jsonb_build_array('9b200000-0000-4000-8000-000000000001'),
      'unitIds', '[]'::jsonb, 'groupIds', '[]'::jsonb, 'activityIds', '[]'::jsonb,
      'includedPersonIds', '[]'::jsonb, 'excludedPersonIds', '[]'::jsonb,
      'dynamicFutureMembership', true, 'historyPolicy', 'from_membership_start'),
    'menu', '[]'::jsonb
  ), null, 0);
select ok((select result ->> 'id' from scope_results where key = 'create') is not null, 'rascunho criado com scopeRules objeto');

reset role;
select is(
  (select jsonb_typeof(scope_rules) from public.meal_plans where id = (select (result ->> 'id')::uuid from scope_results where key = 'create')),
  'object', 'scope_rules gravado como objeto (check meal_plans_scope_rules_array_check)');
select is(
  (select scope_rules -> 'institutionIds' from public.meal_plans where id = (select (result ->> 'id')::uuid from scope_results where key = 'create')),
  '["9b200000-0000-4000-8000-000000000001"]'::jsonb, 'scope_rules preserva o objeto do cliente');
select is(
  (select count(*)::int from public.meal_plan_scopes where meal_plan_id = (select (result ->> 'id')::uuid from scope_results where key = 'create')),
  1, 'meal_plan_scopes recebe a regra derivada da instituicao');

-- 7-8: edicao com lista continua aceita e converte para objeto
set local role authenticated;
select set_config('request.jwt.claim.sub', '9b000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"9b000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}', true);
insert into scope_results(key, result)
select 'edit', public.meal_plan_create_or_update_draft(
  'scope-rules-edit',
  jsonb_build_object(
    'name', 'Cardapio scopeRules lista',
    'institutionId', '9b200000-0000-4000-8000-000000000001',
    'tenantId', '9b200000-0000-4000-8000-000000000001',
    'scopeLevel', 'institution',
    'scopeId', '9b200000-0000-4000-8000-000000000001',
    'sourceType', 'institution',
    'startDate', current_date::text, 'endDate', (current_date + 6)::text,
    'planVariant', 'complete', 'audienceSegment', 'students',
    'scopeRules', jsonb_build_array(jsonb_build_object('scopeLevel', 'institution', 'scopeId', '9b200000-0000-4000-8000-000000000001', 'institutionId', '9b200000-0000-4000-8000-000000000001')),
    'menu', '[]'::jsonb
  ),
  (select (result ->> 'id')::uuid from scope_results where key = 'create'),
  (select (result ->> 'revision')::int from scope_results where key = 'create'));
reset role;
select is(
  (select jsonb_typeof(scope_rules) from public.meal_plans where id = (select (result ->> 'id')::uuid from scope_results where key = 'create')),
  'object', 'lista do cliente e convertida para objeto na gravacao');
select is(
  (select count(*)::int from public.meal_plan_scopes where meal_plan_id = (select (result ->> 'id')::uuid from scope_results where key = 'create')),
  1, 'meal_plan_scopes reescrito a partir da lista');

-- 9: cliente nao executa os helpers
select ok(
  not has_function_privilege('authenticated', 'app_private.meal_plan_scope_rules_array(jsonb,uuid)', 'execute')
  and not has_function_privilege('anon', 'app_private.meal_plan_scope_rules_object(jsonb)', 'execute'),
  'helpers sem execute para cliente');

select * from finish();
rollback;
