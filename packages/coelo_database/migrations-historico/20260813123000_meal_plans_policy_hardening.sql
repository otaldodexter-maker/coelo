-- Keep read and write policies disjoint so Supabase does not evaluate
-- multiple permissive policies for SELECT on meal_plans.

drop policy if exists meal_plans_write on public.meal_plans;
create policy meal_plans_write on public.meal_plans
  for insert to authenticated
  with check (app_private.has_platform_permission('meal_plans.manage'));

drop policy if exists meal_plans_update on public.meal_plans;
create policy meal_plans_update on public.meal_plans
  for update to authenticated
  using (app_private.has_platform_permission('meal_plans.manage'))
  with check (app_private.has_platform_permission('meal_plans.manage'));

drop policy if exists meal_plans_delete on public.meal_plans;
create policy meal_plans_delete on public.meal_plans
  for delete to authenticated
  using (app_private.has_platform_permission('meal_plans.manage'));
