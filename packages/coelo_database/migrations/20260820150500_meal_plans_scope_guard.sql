begin;

create or replace function app_private.meal_plan_scope_allowed(
  p_tenant_id uuid,
  p_institution_id uuid
) returns boolean
language sql stable security definer
set search_path = pg_catalog, public, app_private
as $$
  select exists (
    select 1
    from public.platform_memberships membership
    join public.platform_roles role_record on role_record.id = membership.role_id
    where membership.person_id = app_private.current_person_id()
      and membership.status = 'active'
      and membership.revoked_at is null
      and role_record.status = 'active'
      and (
        membership.scope_kind = 'platform'
        or (
          membership.scope_kind = 'institution'
          and membership.scope_institution_id = p_institution_id
        )
      )
      and (
        p_tenant_id is null
        or p_institution_id is null
        or p_tenant_id = p_institution_id
      )
  );
$$;

drop policy if exists meal_plans_read on public.meal_plans;
create policy meal_plans_read on public.meal_plans
  for select using (
    app_private.has_platform_permission('meal_plans.read')
    and app_private.meal_plan_scope_allowed(tenant_id, institution_id)
  );

drop policy if exists meal_plans_write on public.meal_plans;
create policy meal_plans_write on public.meal_plans
  for insert with check (
    app_private.has_platform_permission('meal_plans.manage')
    and app_private.meal_plan_scope_allowed(tenant_id, institution_id)
  );

drop policy if exists meal_plans_update on public.meal_plans;
create policy meal_plans_update on public.meal_plans
  for update using (
    app_private.has_platform_permission('meal_plans.manage')
    and app_private.meal_plan_scope_allowed(tenant_id, institution_id)
  ) with check (
    app_private.has_platform_permission('meal_plans.manage')
    and app_private.meal_plan_scope_allowed(tenant_id, institution_id)
  );

drop policy if exists meal_plans_delete on public.meal_plans;
create policy meal_plans_delete on public.meal_plans
  for delete using (
    app_private.has_platform_permission('meal_plans.manage')
    and app_private.meal_plan_scope_allowed(tenant_id, institution_id)
  );

commit;
