-- Meal plans: scoped, reviewable and conflict-aware operational menus.
-- Direct table access is deny-by-default; clients use the authenticated RPCs below.

create table if not exists public.meal_plans (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  institution_id uuid references public.institutions(id) on delete cascade,
  unit_id uuid references public.units(id) on delete cascade,
  class_id uuid references public.groups(id) on delete cascade,
  person_id uuid references public.people(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 240),
  status text not null default 'draft' check (status in ('draft', 'inReview', 'scheduled', 'published', 'updated', 'closed', 'archived')),
  source_type text not null default 'global' check (source_type in ('global', 'institution', 'unit', 'classLevel', 'person', 'exception')),
  scope_level text not null default 'global' check (scope_level in ('global', 'institution', 'unit', 'classLevel', 'person')),
  scope_id text not null default '',
  start_date date not null,
  end_date date not null,
  recurrence jsonb not null default '{"kind":"singleWeek","excludedDates":[]}'::jsonb,
  menu jsonb not null default '[]'::jsonb,
  allergens jsonb not null default '[]'::jsonb,
  alerts jsonb not null default '[]'::jsonb,
  attachments_meta jsonb not null default '[]'::jsonb,
  priority integer not null default 0 check (priority >= 0),
  conflict_state boolean not null default false,
  revision integer not null default 1 check (revision > 0),
  is_draft boolean not null default true,
  requires_review boolean not null default false,
  inheritance_origin_id uuid references public.meal_plans(id) on delete set null,
  created_by uuid references public.people(id),
  updated_by uuid references public.people(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date),
  check ((scope_level = 'global' and scope_id = '') or scope_id <> '')
);

create index if not exists meal_plans_tenant_status_period_idx
  on public.meal_plans(tenant_id, status, start_date, end_date);
create index if not exists meal_plans_scope_period_idx
  on public.meal_plans(tenant_id, scope_level, scope_id, start_date, end_date);
create index if not exists meal_plans_filters_idx
  on public.meal_plans(tenant_id, institution_id, unit_id, class_id, person_id, priority);
create index if not exists meal_plans_review_conflict_idx
  on public.meal_plans(tenant_id, requires_review, conflict_state, updated_at desc);

alter table public.meal_plans enable row level security;
alter table public.meal_plans force row level security;

drop policy if exists meal_plans_read on public.meal_plans;
create policy meal_plans_read on public.meal_plans
  for select to authenticated
  using (app_private.has_platform_permission('meal_plans.read'));

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

insert into public.platform_permissions(code, module_code, module_label, screen_code, screen_label, action_code, action_label, description, risk_level, requires_mfa, status)
values
  ('meal_plans.read', 'meal_plans', 'Cardápios', 'directory', 'Diretório', 'read', 'Ler', 'Ler diretório de cardápios', 'normal', false, 'active'),
  ('meal_plans.manage', 'meal_plans', 'Cardápios', 'directory', 'Diretório', 'manage', 'Gerenciar', 'Criar e editar cardápios', 'high', false, 'active'),
  ('meal_plans.publish', 'meal_plans', 'Cardápios', 'directory', 'Diretório', 'publish', 'Publicar', 'Enviar e publicar cardápios', 'high', false, 'active')
on conflict (code) do nothing;

create or replace function public.meal_plan_json(plan public.meal_plans)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', plan.id,
    'tenantId', plan.tenant_id,
    'institutionId', plan.institution_id,
    'unitId', plan.unit_id,
    'classId', plan.class_id,
    'personId', plan.person_id,
    'name', plan.name,
    'status', plan.status,
    'sourceType', plan.source_type,
    'scopeLevel', plan.scope_level,
    'scopeId', plan.scope_id,
    'startDate', plan.start_date,
    'endDate', plan.end_date,
    'recurrence', plan.recurrence,
    'menu', plan.menu,
    'allergens', plan.allergens,
    'alerts', plan.alerts,
    'attachmentsMeta', plan.attachments_meta,
    'priority', plan.priority,
    'hasConflict', plan.conflict_state,
    'revision', plan.revision,
    'isDraft', plan.is_draft,
    'requiresReview', plan.requires_review,
    'createdBy', plan.created_by,
    'updatedBy', plan.updated_by,
    'inheritanceOriginId', plan.inheritance_origin_id
  );
$$;

create or replace function public.meal_plan_list(p_query jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  q text := coalesce(p_query ->> 'search', '');
  page_number integer := greatest(coalesce((p_query ->> 'page')::integer, 0), 0);
  page_size integer := least(greatest(coalesce((p_query ->> 'pageSize')::integer, 12), 1), 100);
  total_count integer;
  result jsonb;
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.read') then
    raise insufficient_privilege using message = 'meal plans read permission required';
  end if;

  select count(*) into total_count
  from public.meal_plans plan
  where (q = '' or plan.name ilike '%' || q || '%')
    and (p_query ->> 'institutionId' is null or plan.institution_id::text = p_query ->> 'institutionId')
    and (p_query ->> 'unitId' is null or plan.unit_id::text = p_query ->> 'unitId')
    and (p_query ->> 'classId' is null or plan.class_id::text = p_query ->> 'classId')
    and (p_query ->> 'personId' is null or plan.person_id::text = p_query ->> 'personId')
    and (p_query ->> 'periodStart' is null or plan.end_date >= (p_query ->> 'periodStart')::date)
    and (p_query ->> 'periodEnd' is null or plan.start_date <= (p_query ->> 'periodEnd')::date)
    and (jsonb_array_length(coalesce(p_query -> 'statuses', '[]'::jsonb)) = 0 or plan.status in (select jsonb_array_elements_text(p_query -> 'statuses')))
    and (jsonb_array_length(coalesce(p_query -> 'sources', '[]'::jsonb)) = 0 or plan.source_type in (select jsonb_array_elements_text(p_query -> 'sources')))
    and (p_query ->> 'hasConflict' is null or plan.conflict_state = (p_query ->> 'hasConflict')::boolean)
    and (p_query ->> 'requiresReview' is null or plan.requires_review = (p_query ->> 'requiresReview')::boolean);

  select coalesce(jsonb_agg(public.meal_plan_json(plan) order by plan.updated_at desc), '[]'::jsonb)
    into result
  from public.meal_plans plan
  where (q = '' or plan.name ilike '%' || q || '%')
    and (p_query ->> 'institutionId' is null or plan.institution_id::text = p_query ->> 'institutionId')
    and (p_query ->> 'unitId' is null or plan.unit_id::text = p_query ->> 'unitId')
    and (p_query ->> 'classId' is null or plan.class_id::text = p_query ->> 'classId')
    and (p_query ->> 'personId' is null or plan.person_id::text = p_query ->> 'personId')
    and (p_query ->> 'periodStart' is null or plan.end_date >= (p_query ->> 'periodStart')::date)
    and (p_query ->> 'periodEnd' is null or plan.start_date <= (p_query ->> 'periodEnd')::date)
    and (jsonb_array_length(coalesce(p_query -> 'statuses', '[]'::jsonb)) = 0 or plan.status in (select jsonb_array_elements_text(p_query -> 'statuses')))
    and (jsonb_array_length(coalesce(p_query -> 'sources', '[]'::jsonb)) = 0 or plan.source_type in (select jsonb_array_elements_text(p_query -> 'sources')))
    and (p_query ->> 'hasConflict' is null or plan.conflict_state = (p_query ->> 'hasConflict')::boolean)
    and (p_query ->> 'requiresReview' is null or plan.requires_review = (p_query ->> 'requiresReview')::boolean)
  offset page_number * page_size limit page_size;

  return jsonb_build_object('items', result, 'total', total_count, 'limit', page_size, 'offset', page_number * page_size);
end;
$$;

create or replace function public.meal_plan_get(p_meal_plan_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare plan public.meal_plans;
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.read') then
    raise insufficient_privilege using message = 'meal plans read permission required';
  end if;
  select * into plan from public.meal_plans where id = p_meal_plan_id;
  if not found then raise no_data_found using message = 'meal plan not found'; end if;
  return public.meal_plan_json(plan);
end;
$$;

create or replace function public.meal_plan_conflicts_check(
  p_scope_level text,
  p_scope_id text,
  p_start_date date,
  p_end_date date,
  p_recurrence jsonb default '{}'::jsonb,
  p_menu jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare conflicts jsonb;
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.read') then
    raise insufficient_privilege using message = 'meal plans read permission required';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'conflictType', 'overlap',
    'scopeLevel', plan.scope_level,
    'scopeId', nullif(plan.scope_id, ''),
    'dateRange', plan.start_date::text || '/' || plan.end_date::text,
    'mealType', coalesce(menu_item ->> 'mealType', ''),
    'overlapWithIds', jsonb_build_array(plan.id),
    'requiredAction', case when plan.priority = candidate.priority then 'prioritize' else 'rewrite' end
  )), '[]'::jsonb)
  into conflicts
  from public.meal_plans plan
  cross join lateral jsonb_array_elements(coalesce(plan.menu, '[]'::jsonb)) as menu_item
  cross join lateral (select coalesce((p_menu -> 0 ->> 'mealType'), '') as meal_type, 0 as priority) candidate
  where plan.scope_level = p_scope_level
    and plan.scope_id = p_scope_id
    and plan.start_date <= p_end_date
    and plan.end_date >= p_start_date
    and plan.status in ('inReview', 'scheduled', 'published', 'updated')
    and menu_item ->> 'mealType' = candidate.meal_type;
  return jsonb_build_object('conflicts', conflicts);
end;
$$;

create or replace function public.meal_plan_create_or_update_draft(
  p_request_id text,
  p_payload jsonb,
  p_meal_plan_id uuid default null,
  p_expected_revision integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare plan public.meal_plans;
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.manage') then
    raise insufficient_privilege using message = 'meal plans manage permission required';
  end if;
  if p_meal_plan_id is null then
    insert into public.meal_plans(tenant_id, institution_id, unit_id, class_id, person_id, name, source_type, scope_level, scope_id, start_date, end_date, recurrence, menu, allergens, alerts, attachments_meta, priority, is_draft, requires_review, created_by, updated_by)
    values (coalesce(nullif(p_payload ->> 'tenantId', '')::uuid, nullif(p_payload ->> 'institutionId', '')::uuid), nullif(p_payload ->> 'institutionId', '')::uuid, nullif(p_payload ->> 'unitId', '')::uuid, nullif(p_payload ->> 'classId', '')::uuid, nullif(p_payload ->> 'personId', '')::uuid, btrim(p_payload ->> 'name'), coalesce(p_payload ->> 'sourceType', 'global'), coalesce(p_payload ->> 'scopeLevel', 'global'), coalesce(p_payload ->> 'scopeId', ''), (p_payload ->> 'startDate')::date, (p_payload ->> 'endDate')::date, coalesce(p_payload -> 'recurrence', '{}'::jsonb), coalesce(p_payload -> 'menu', '[]'::jsonb), coalesce(p_payload -> 'allergens', '[]'::jsonb), coalesce(p_payload -> 'alerts', '[]'::jsonb), coalesce(p_payload -> 'attachments', '[]'::jsonb), coalesce((p_payload ->> 'priority')::integer, 0), true, false, app_private.current_person_id(), app_private.current_person_id())
    returning * into plan;
  else
    update public.meal_plans
      set name = btrim(p_payload ->> 'name'), source_type = coalesce(p_payload ->> 'sourceType', source_type), scope_level = coalesce(p_payload ->> 'scopeLevel', scope_level), scope_id = coalesce(p_payload ->> 'scopeId', scope_id), start_date = (p_payload ->> 'startDate')::date, end_date = (p_payload ->> 'endDate')::date, recurrence = coalesce(p_payload -> 'recurrence', recurrence), menu = coalesce(p_payload -> 'menu', menu), allergens = coalesce(p_payload -> 'allergens', allergens), alerts = coalesce(p_payload -> 'alerts', alerts), attachments_meta = coalesce(p_payload -> 'attachments', attachments_meta), priority = coalesce((p_payload ->> 'priority')::integer, priority), status = 'draft', is_draft = true, requires_review = false, conflict_state = false, revision = revision + 1, updated_by = app_private.current_person_id(), updated_at = now()
      where id = p_meal_plan_id and revision = p_expected_revision
      returning * into plan;
    if not found then raise exception 'meal plan revision conflict' using errcode = 'P0003'; end if;
  end if;
  return public.meal_plan_json(plan);
end;
$$;

create or replace function public.meal_plan_submit_for_review(p_request_id text, p_meal_plan_id uuid, p_expected_revision integer)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare plan public.meal_plans;
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.manage') then raise insufficient_privilege; end if;
  update public.meal_plans set status = 'inReview', is_draft = false, requires_review = true, revision = revision + 1, updated_by = app_private.current_person_id(), updated_at = now()
    where id = p_meal_plan_id and revision = p_expected_revision and status = 'draft' returning * into plan;
  if not found then raise exception 'meal plan cannot be submitted' using errcode = 'P0003'; end if;
  return public.meal_plan_json(plan);
end;
$$;

create or replace function public.meal_plan_publish(p_request_id text, p_meal_plan_id uuid, p_expected_revision integer)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare plan public.meal_plans; pending_conflicts integer;
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.publish') then raise insufficient_privilege; end if;
  select * into plan from public.meal_plans where id = p_meal_plan_id for update;
  if not found then raise no_data_found; end if;
  select count(*) into pending_conflicts from public.meal_plans other_plan
    where other_plan.id <> plan.id and other_plan.scope_level = plan.scope_level and other_plan.scope_id = plan.scope_id and other_plan.start_date <= plan.end_date and other_plan.end_date >= plan.start_date and other_plan.priority = plan.priority and other_plan.status in ('inReview', 'scheduled', 'published', 'updated');
  if plan.conflict_state or pending_conflicts > 0 then raise exception 'meal plan has unresolved conflict' using errcode = 'P0003'; end if;
  if plan.revision <> p_expected_revision or plan.status not in ('inReview', 'updated') then raise exception 'meal plan revision or status conflict' using errcode = 'P0003'; end if;
  update public.meal_plans set status = 'published', is_draft = false, requires_review = false, revision = revision + 1, updated_by = app_private.current_person_id(), updated_at = now() where id = plan.id returning * into plan;
  return public.meal_plan_json(plan);
end;
$$;

create or replace function public.meal_plan_effective_snapshot(p_payload jsonb)
returns jsonb
language plpgsql security definer
set search_path = public
as $$
declare plan public.meal_plans;
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.read') then raise insufficient_privilege; end if;
  select * into plan from public.meal_plans candidate
    where candidate.start_date <= (p_payload ->> 'endDate')::date and candidate.end_date >= (p_payload ->> 'startDate')::date
      and (candidate.scope_level = coalesce(p_payload ->> 'scopeLevel', 'global') or candidate.scope_level = 'global')
    order by case candidate.scope_level when 'person' then 5 when 'classLevel' then 4 when 'unit' then 3 when 'institution' then 2 else 1 end desc, candidate.priority desc, candidate.updated_at desc limit 1;
  if not found then raise no_data_found using message = 'effective meal plan not found'; end if;
  return public.meal_plan_json(plan);
end;
$$;

revoke all on table public.meal_plans from anon, authenticated;
revoke all on function public.meal_plan_json(public.meal_plans) from public, anon, authenticated;
revoke all on function public.meal_plan_list(jsonb) from public, anon;
revoke all on function public.meal_plan_get(uuid) from public, anon;
revoke all on function public.meal_plan_conflicts_check(text, text, date, date, jsonb, jsonb) from public, anon;
revoke all on function public.meal_plan_create_or_update_draft(text, jsonb, uuid, integer) from public, anon;
revoke all on function public.meal_plan_submit_for_review(text, uuid, integer) from public, anon;
revoke all on function public.meal_plan_publish(text, uuid, integer) from public, anon;
revoke all on function public.meal_plan_effective_snapshot(jsonb) from public, anon;
grant execute on function public.meal_plan_list(jsonb) to authenticated;
grant execute on function public.meal_plan_get(uuid) to authenticated;
grant execute on function public.meal_plan_conflicts_check(text, text, date, date, jsonb, jsonb) to authenticated;
grant execute on function public.meal_plan_create_or_update_draft(text, jsonb, uuid, integer) to authenticated;
grant execute on function public.meal_plan_submit_for_review(text, uuid, integer) to authenticated;
grant execute on function public.meal_plan_publish(text, uuid, integer) to authenticated;
grant execute on function public.meal_plan_effective_snapshot(jsonb) to authenticated;
