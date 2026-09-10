-- Prova de contrato da migration 20260910130000_meal_plans_owner_permission_grants_v1
-- sobre a baseline de producao (ADR 0034, Decisao 8/P12): o papel owner recebe as
-- tres capacidades de Cardapios e o papel de operacao recebe somente leitura.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select has_function('app_private', 'has_platform_permission', 'app_private.has_platform_permission existe');

select ok(exists (select 1 from public.platform_permissions where code = 'meal_plans.read'), 'meal_plans.read esta no catalogo');
select ok(exists (select 1 from public.platform_permissions where code = 'meal_plans.manage'), 'meal_plans.manage esta no catalogo');
select ok(exists (select 1 from public.platform_permissions where code = 'meal_plans.publish'), 'meal_plans.publish esta no catalogo');

select is(
  (select count(*)::int from public.platform_role_permissions rp
     join public.platform_roles r on r.id = rp.role_id
     join public.platform_permissions p on p.id = rp.permission_id
    where r.code = 'owner' and p.code in ('meal_plans.read', 'meal_plans.manage', 'meal_plans.publish')),
  3, 'owner tem read, manage e publish de Cardapios');

select ok(
  not exists (select 1 from public.platform_role_permissions rp
     join public.platform_roles r on r.id = rp.role_id
     join public.platform_permissions p on p.id = rp.permission_id
    where r.code <> 'owner' and p.code in ('meal_plans.manage', 'meal_plans.publish')),
  'nenhum papel alem do owner gerencia ou publica Cardapios');

select * from finish();
rollback;
