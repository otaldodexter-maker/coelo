begin;

create or replace function app_private.meal_plan_scope_allowed(
  p_tenant_id uuid,
  p_institution_id uuid
) returns boolean
language sql
stable
security definer
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
      and (p_tenant_id is null or p_institution_id is null or p_tenant_id = p_institution_id)
  );
$$;

create or replace function public.meal_plan_list(p_query jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
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
  with visible as (
    select plan.* from public.meal_plans plan
    where app_private.meal_plan_scope_allowed(plan.tenant_id, plan.institution_id)
      and (q = '' or plan.name ilike '%' || q || '%')
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
  )
  select count(*) into total_count from visible;
  with visible as (
    select plan.* from public.meal_plans plan
    where app_private.meal_plan_scope_allowed(plan.tenant_id, plan.institution_id)
      and (q = '' or plan.name ilike '%' || q || '%')
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
  )
  select coalesce(jsonb_agg(public.meal_plan_json(visible) order by visible.updated_at desc), '[]'::jsonb)
    into result from visible offset page_number * page_size limit page_size;
  return jsonb_build_object('items', result, 'total', total_count, 'limit', page_size, 'offset', page_number * page_size);
end;
$$;

create or replace function public.meal_plan_get(p_meal_plan_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare plan public.meal_plans;
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.read') then raise insufficient_privilege; end if;
  select * into plan from public.meal_plans candidate
    where candidate.id = p_meal_plan_id
      and app_private.meal_plan_scope_allowed(candidate.tenant_id, candidate.institution_id);
  if not found then raise no_data_found using message = 'meal plan not found'; end if;
  return public.meal_plan_json(plan);
end;
$$;

create or replace function public.meal_plan_create_or_update_draft(
  p_request_id text, p_payload jsonb, p_meal_plan_id uuid default null, p_expected_revision integer default 0
) returns jsonb language plpgsql security definer set search_path = public as $$
declare plan public.meal_plans; institution_id uuid := nullif(p_payload ->> 'institutionId', '')::uuid; tenant_id uuid;
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.manage') then raise insufficient_privilege; end if;
  tenant_id := case when institution_id is not null then institution_id else nullif(p_payload ->> 'tenantId', '')::uuid end;
  if institution_id is null and tenant_id is null then raise invalid_parameter_value using message = 'meal plan tenant or institution is required'; end if;
  if not app_private.meal_plan_scope_allowed(tenant_id, institution_id) then raise insufficient_privilege; end if;
  if p_meal_plan_id is null then
    insert into public.meal_plans(tenant_id, institution_id, unit_id, class_id, person_id, name, source_type, scope_level, scope_id, start_date, end_date, recurrence, menu, allergens, alerts, attachments_meta, priority, is_draft, requires_review, created_by, updated_by)
    values (tenant_id, institution_id, nullif(p_payload ->> 'unitId', '')::uuid, nullif(p_payload ->> 'classId', '')::uuid, nullif(p_payload ->> 'personId', '')::uuid, btrim(p_payload ->> 'name'), coalesce(p_payload ->> 'sourceType', 'global'), coalesce(p_payload ->> 'scopeLevel', 'global'), coalesce(p_payload ->> 'scopeId', ''), (p_payload ->> 'startDate')::date, (p_payload ->> 'endDate')::date, coalesce(p_payload -> 'recurrence', '{}'::jsonb), coalesce(p_payload -> 'menu', '[]'::jsonb), coalesce(p_payload -> 'allergens', '[]'::jsonb), coalesce(p_payload -> 'alerts', '[]'::jsonb), coalesce(p_payload -> 'attachments', '[]'::jsonb), coalesce((p_payload ->> 'priority')::integer, 0), true, false, app_private.current_person_id(), app_private.current_person_id()) returning * into plan;
  else
    update public.meal_plans set name=btrim(p_payload ->> 'name'), source_type=coalesce(p_payload ->> 'sourceType', source_type), scope_level=coalesce(p_payload ->> 'scopeLevel', scope_level), scope_id=coalesce(p_payload ->> 'scopeId', scope_id), start_date=(p_payload ->> 'startDate')::date, end_date=(p_payload ->> 'endDate')::date, recurrence=coalesce(p_payload -> 'recurrence', recurrence), menu=coalesce(p_payload -> 'menu', menu), allergens=coalesce(p_payload -> 'allergens', allergens), alerts=coalesce(p_payload -> 'alerts', alerts), attachments_meta=coalesce(p_payload -> 'attachments', attachments_meta), priority=coalesce((p_payload ->> 'priority')::integer, priority), status='draft', is_draft=true, requires_review=false, conflict_state=false, revision=revision+1, updated_by=app_private.current_person_id(), updated_at=now()
      where id=p_meal_plan_id and revision=p_expected_revision and app_private.meal_plan_scope_allowed(tenant_id, institution_id) returning * into plan;
    if not found then raise exception 'meal plan revision or scope conflict' using errcode='P0003'; end if;
  end if;
  return public.meal_plan_json(plan);
end;
$$;

create or replace function public.meal_plan_effective_snapshot(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare plan public.meal_plans;
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.read') then raise insufficient_privilege; end if;
  select * into plan from public.meal_plans candidate
    where app_private.meal_plan_scope_allowed(candidate.tenant_id, nullif(p_payload ->> 'institutionId', '')::uuid)
      and candidate.start_date <= (p_payload ->> 'endDate')::date and candidate.end_date >= (p_payload ->> 'startDate')::date
      and (candidate.scope_level = coalesce(p_payload ->> 'scopeLevel', 'global') or candidate.scope_level = 'global')
    order by case candidate.scope_level when 'person' then 5 when 'classLevel' then 4 when 'unit' then 3 when 'institution' then 2 else 1 end desc, candidate.priority desc
    limit 1;
  if not found then raise no_data_found using message='effective meal plan not found'; end if;
  return public.meal_plan_json(plan);
end;
$$;

create or replace function public.meal_plan_conflicts_check(
  p_scope_level text, p_scope_id text, p_start_date date, p_end_date date, p_recurrence jsonb default '{}', p_menu jsonb default '[]'
) returns jsonb language plpgsql security definer set search_path = public as $$
declare conflicts jsonb; candidate_meal_types text[] := array(select jsonb_array_elements_text(coalesce((select jsonb_agg(item ->> 'mealType') from jsonb_array_elements(p_menu) item), '[]'::jsonb)));
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.read') then raise insufficient_privilege; end if;
  select coalesce(jsonb_agg(jsonb_build_object('conflictType','overlap','scopeLevel',plan.scope_level,'scopeId',nullif(plan.scope_id,''),'dateRange',plan.start_date::text||'/'||plan.end_date::text,'mealType',menu_item ->> 'mealType','overlapWithIds',jsonb_build_array(plan.id),'requiredAction',case when plan.priority = coalesce((p_recurrence ->> 'priority')::integer,0) then 'prioritize' else 'rewrite' end)), '[]'::jsonb) into conflicts
  from public.meal_plans plan cross join lateral jsonb_array_elements(coalesce(plan.menu,'[]'::jsonb)) menu_item
  where app_private.meal_plan_scope_allowed(plan.tenant_id, nullif(plan.institution_id::text,'')::uuid)
    and plan.scope_level=p_scope_level and plan.scope_id=p_scope_id and plan.start_date<=p_end_date and plan.end_date>=p_start_date and plan.status in ('inReview','scheduled','published','updated')
    and menu_item ->> 'mealType' = any(candidate_meal_types);
  return jsonb_build_object('conflicts', conflicts);
end;
$$;

create or replace function public.meal_plan_publish(p_request_id text, p_meal_plan_id uuid, p_expected_revision integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare plan public.meal_plans; pending_conflicts integer;
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.publish') then raise insufficient_privilege; end if;
  select * into plan from public.meal_plans candidate where candidate.id=p_meal_plan_id and app_private.meal_plan_scope_allowed(candidate.tenant_id,candidate.institution_id) for update;
  if not found then raise no_data_found using message='meal plan not found'; end if;
  select count(*) into pending_conflicts from public.meal_plans other_plan where app_private.meal_plan_scope_allowed(other_plan.tenant_id,other_plan.institution_id) and other_plan.id<>plan.id and other_plan.scope_level=plan.scope_level and other_plan.scope_id=plan.scope_id and other_plan.start_date<=plan.end_date and other_plan.end_date>=plan.start_date and other_plan.priority=plan.priority and other_plan.status in ('inReview','scheduled','published','updated');
  if plan.conflict_state or pending_conflicts>0 then raise exception 'meal plan has unresolved conflict' using errcode='P0003'; end if;
  if plan.revision<>p_expected_revision or plan.status not in ('inReview','updated') then raise exception 'meal plan revision or status conflict' using errcode='P0003'; end if;
  update public.meal_plans set status='published',is_draft=false,requires_review=false,revision=revision+1,updated_by=app_private.current_person_id(),updated_at=now() where id=plan.id returning * into plan;
  return public.meal_plan_json(plan);
end;
$$;

commit;
