-- 20260911130500_meal_plan_scope_rules_object_v1.sql
-- Rodada 6, frente principal-chat-sistema. Gate medido na rota real (11/09,
-- capturas 11 e 23 de r06-principal-chat-sistema): o assistente de Cardapios
-- envia scopeRules como objeto ({institutionIds, unitIds, groupIds,
-- activityIds, includedPersonIds, excludedPersonIds, ...}); a RPC
-- meal_plan_create_or_update_draft_unreceipted iterava esse valor com
-- jsonb_array_elements ("cannot extract elements from an object") e, se o
-- cliente mandasse lista, a check meal_plans_scope_rules_array_check (que
-- exige objeto) derrubava a gravacao. Nenhum formato passava: create/edit/
-- publish de cardapio nunca funcionaram em producao.
-- Correcao: dois helpers puros e a funcao _unreceipted recriada com o corpo da
-- baseline (que o 190000 renomeou) trocando so os tres pontos de scopeRules:
--   * meal_plan_scope_rules_object(v): objeto passa; lista vira objeto por
--     nivel (institutionIds/unitIds/...); nulo vira '{}'.
--   * meal_plan_scope_rules_array(v, institution_id): lista passa; objeto vira
--     lista de regras {scopeLevel, scopeId, institutionId, unitId, classId,
--     activityId, personId} para meal_plan_scopes.
-- O wrapper com recibo (190000) continua chamando a _unreceipted. Forward-only.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if to_regprocedure('public.meal_plan_create_or_update_draft_unreceipted(text,jsonb,uuid,integer)') is null then
    raise object_not_in_prerequisite_state using message = 'pacote 20260910190000 e prerequisito';
  end if;
end
$preflight$;

create or replace function app_private.meal_plan_scope_rules_object(p_value jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case
    when p_value is null or jsonb_typeof(p_value) = 'null' then '{}'::jsonb
    when jsonb_typeof(p_value) = 'object' then p_value
    when jsonb_typeof(p_value) = 'array' then jsonb_build_object(
      'institutionIds', coalesce((select jsonb_agg(r ->> 'scopeId') from jsonb_array_elements(p_value) r where r ->> 'scopeLevel' = 'institution'), '[]'::jsonb),
      'unitIds', coalesce((select jsonb_agg(r ->> 'scopeId') from jsonb_array_elements(p_value) r where r ->> 'scopeLevel' = 'unit'), '[]'::jsonb),
      'groupIds', coalesce((select jsonb_agg(r ->> 'scopeId') from jsonb_array_elements(p_value) r where r ->> 'scopeLevel' = 'classLevel'), '[]'::jsonb),
      'activityIds', coalesce((select jsonb_agg(r ->> 'scopeId') from jsonb_array_elements(p_value) r where r ->> 'scopeLevel' = 'activity'), '[]'::jsonb),
      'includedPersonIds', coalesce((select jsonb_agg(r ->> 'scopeId') from jsonb_array_elements(p_value) r where r ->> 'scopeLevel' = 'person'), '[]'::jsonb),
      'excludedPersonIds', '[]'::jsonb)
    else '{}'::jsonb end;
$$;
revoke all on function app_private.meal_plan_scope_rules_object(jsonb) from public, anon, authenticated;

create or replace function app_private.meal_plan_scope_rules_array(p_value jsonb, p_institution_id uuid)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case
    when p_value is null or jsonb_typeof(p_value) = 'null' then '[]'::jsonb
    when jsonb_typeof(p_value) = 'array' then p_value
    when jsonb_typeof(p_value) = 'object' then coalesce((
      select jsonb_agg(rule) from (
        select jsonb_build_object('scopeLevel', 'institution', 'scopeId', id, 'institutionId', id) as rule
          from jsonb_array_elements_text(coalesce(p_value -> 'institutionIds', '[]'::jsonb)) id
        union all
        select jsonb_build_object('scopeLevel', 'unit', 'scopeId', id, 'institutionId', p_institution_id, 'unitId', id)
          from jsonb_array_elements_text(coalesce(p_value -> 'unitIds', '[]'::jsonb)) id
        union all
        select jsonb_build_object('scopeLevel', 'classLevel', 'scopeId', id, 'institutionId', p_institution_id, 'classId', id)
          from jsonb_array_elements_text(coalesce(p_value -> 'groupIds', '[]'::jsonb)) id
        union all
        select jsonb_build_object('scopeLevel', 'activity', 'scopeId', id, 'institutionId', p_institution_id, 'activityId', id)
          from jsonb_array_elements_text(coalesce(p_value -> 'activityIds', '[]'::jsonb)) id
        union all
        select jsonb_build_object('scopeLevel', 'person', 'scopeId', id, 'institutionId', p_institution_id, 'personId', id)
          from jsonb_array_elements_text(coalesce(p_value -> 'includedPersonIds', '[]'::jsonb)) id
      ) rules where rules.rule ->> 'scopeId' <> ''), '[]'::jsonb)
    else '[]'::jsonb end;
$$;
revoke all on function app_private.meal_plan_scope_rules_array(jsonb, uuid) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION "public"."meal_plan_create_or_update_draft_unreceipted"("p_request_id" "text", "p_payload" "jsonb", "p_meal_plan_id" "uuid" DEFAULT NULL::"uuid", "p_expected_revision" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public', 'app_private'
    AS $$
declare
  actor_id uuid := app_private.current_person_id();
  plan public.meal_plans;
  requested_institution_id uuid := nullif(p_payload ->> 'institutionId', '')::uuid;
  requested_tenant_id uuid := coalesce(requested_institution_id, nullif(p_payload ->> 'tenantId', '')::uuid);
  start_date_value date := (p_payload ->> 'startDate')::date;
  end_date_value date := (p_payload ->> 'endDate')::date;
  visibility_value text := coalesce(p_payload ->> 'visibilityMode', 'immediate');
  visible_from_value timestamptz := nullif(p_payload ->> 'visibleFrom', '')::timestamptz;
  source_template uuid := nullif(p_payload ->> 'sourceTemplateId', '')::uuid;
  source_version integer := nullif(p_payload ->> 'sourceTemplateVersion', '')::integer;
  scope_rule jsonb;
  meal_rule jsonb;
  saved_template jsonb;
begin
  if auth.uid() is null or actor_id is null or not app_private.has_platform_permission('meal_plans.manage') then
    raise insufficient_privilege using message = 'meal plans manage permission required';
  end if;
  if requested_tenant_id is null or btrim(coalesce(p_payload ->> 'name', '')) = '' then
    raise invalid_parameter_value using message = 'meal plan tenant and name are required';
  end if;
  if start_date_value is null or end_date_value is null or end_date_value < start_date_value then
    raise invalid_parameter_value using message = 'invalid meal plan period';
  end if;
  if visibility_value not in ('immediate', 'scheduled')
    or (visibility_value = 'immediate' and visible_from_value is not null)
    or (visibility_value = 'scheduled' and visible_from_value is null) then
    raise invalid_parameter_value using message = 'invalid visibility schedule';
  end if;
  if not app_private.meal_plan_scope_allowed(requested_tenant_id, requested_institution_id) then
    raise insufficient_privilege using message = 'meal plan scope is not allowed';
  end if;
  if source_template is not null and not exists (
    select 1 from public.meal_plan_template_versions version_record
    join public.meal_plan_templates template
      on template.id = version_record.template_id and template.tenant_id = version_record.tenant_id
    where version_record.template_id = source_template
      and version_record.tenant_id = requested_tenant_id
      and version_record.version = source_version
      and template.status = 'published'
      and app_private.meal_plan_scope_allowed(template.tenant_id, template.institution_id)
  ) then
    raise invalid_parameter_value using message = 'source template version is not available';
  end if;

  if p_meal_plan_id is null then
    insert into public.meal_plans(
      tenant_id, institution_id, unit_id, class_id, person_id, name, source_type,
      scope_level, scope_id, start_date, end_date, recurrence, excluded_dates,
      exceptions, menu, allergens, alerts, attachments_meta, priority,
      status, conflict_state, revision, is_draft, requires_review,
      plan_variant, audience_segment, visibility_mode, visible_from,
      source_template_id, source_template_version, scope_rules,
      simple_image_meta, simple_image_alt, simple_notes, created_by, updated_by
    ) values (
      requested_tenant_id, requested_institution_id, nullif(p_payload ->> 'unitId', '')::uuid,
      nullif(p_payload ->> 'classId', '')::uuid, nullif(p_payload ->> 'personId', '')::uuid,
      btrim(p_payload ->> 'name'), coalesce(p_payload ->> 'sourceType', 'institution'),
      coalesce(p_payload ->> 'scopeLevel', 'institution'), coalesce(p_payload ->> 'scopeId', requested_institution_id::text),
      start_date_value, end_date_value, coalesce(p_payload -> 'recurrence', '{}'::jsonb),
      coalesce(array(select jsonb_array_elements_text(coalesce(p_payload -> 'excludedDates', '[]'::jsonb))::date), '{}'),
      coalesce(p_payload -> 'exceptions', '[]'::jsonb), coalesce(p_payload -> 'menu', '[]'::jsonb),
      coalesce(p_payload -> 'allergens', '[]'::jsonb), coalesce(p_payload -> 'alerts', '[]'::jsonb),
      coalesce(p_payload -> 'attachments', '[]'::jsonb), coalesce((p_payload ->> 'priority')::integer, 0),
      'draft', false, 1, true, false,
      coalesce(p_payload ->> 'planVariant', 'simple'), coalesce(p_payload ->> 'audienceSegment', 'students'),
      visibility_value, visible_from_value, source_template, source_version,
      app_private.meal_plan_scope_rules_object(p_payload -> 'scopeRules'), coalesce(p_payload -> 'simpleImageMeta', '{}'::jsonb),
      nullif(p_payload ->> 'simpleImageAlt', ''), nullif(p_payload ->> 'simpleNotes', ''), actor_id, actor_id
    ) returning * into plan;
  else
    update public.meal_plans existing set
      institution_id = requested_institution_id,
      unit_id = nullif(p_payload ->> 'unitId', '')::uuid,
      class_id = nullif(p_payload ->> 'classId', '')::uuid,
      person_id = nullif(p_payload ->> 'personId', '')::uuid,
      name = btrim(p_payload ->> 'name'),
      source_type = coalesce(p_payload ->> 'sourceType', existing.source_type),
      scope_level = coalesce(p_payload ->> 'scopeLevel', existing.scope_level),
      scope_id = coalesce(p_payload ->> 'scopeId', existing.scope_id),
      start_date = start_date_value,
      end_date = end_date_value,
      recurrence = coalesce(p_payload -> 'recurrence', existing.recurrence),
      excluded_dates = coalesce(array(select jsonb_array_elements_text(coalesce(p_payload -> 'excludedDates', '[]'::jsonb))::date), '{}'),
      exceptions = coalesce(p_payload -> 'exceptions', existing.exceptions),
      menu = coalesce(p_payload -> 'menu', existing.menu),
      allergens = coalesce(p_payload -> 'allergens', existing.allergens),
      alerts = coalesce(p_payload -> 'alerts', existing.alerts),
      attachments_meta = coalesce(p_payload -> 'attachments', existing.attachments_meta),
      priority = coalesce((p_payload ->> 'priority')::integer, existing.priority),
      status = 'draft', conflict_state = false, is_draft = true, requires_review = false,
      revision = existing.revision + 1,
      plan_variant = coalesce(p_payload ->> 'planVariant', existing.plan_variant),
      audience_segment = coalesce(p_payload ->> 'audienceSegment', existing.audience_segment),
      visibility_mode = visibility_value, visible_from = visible_from_value,
      source_template_id = source_template, source_template_version = source_version,
      scope_rules = case when p_payload ? 'scopeRules' then app_private.meal_plan_scope_rules_object(p_payload -> 'scopeRules') else existing.scope_rules end,
      simple_image_meta = coalesce(p_payload -> 'simpleImageMeta', existing.simple_image_meta),
      simple_image_alt = nullif(p_payload ->> 'simpleImageAlt', ''),
      simple_notes = nullif(p_payload ->> 'simpleNotes', ''),
      updated_by = actor_id, updated_at = now()
    where existing.id = p_meal_plan_id
      and existing.tenant_id = requested_tenant_id
      and existing.revision = p_expected_revision
      and app_private.meal_plan_scope_allowed(existing.tenant_id, existing.institution_id)
    returning existing.* into plan;
    if not found then
      raise exception 'meal plan revision or scope conflict' using errcode = 'P0003';
    end if;
  end if;

  delete from public.meal_plan_scopes where meal_plan_id = plan.id and tenant_id = plan.tenant_id;
  for scope_rule in select value from jsonb_array_elements(app_private.meal_plan_scope_rules_array(p_payload -> 'scopeRules', plan.institution_id)) loop
    insert into public.meal_plan_scopes(
      meal_plan_id, tenant_id, scope_level, scope_id, institution_id, unit_id,
      class_id, activity_id, person_id, priority
    ) values (
      plan.id, plan.tenant_id, scope_rule ->> 'scopeLevel', coalesce(scope_rule ->> 'scopeId', ''),
      nullif(scope_rule ->> 'institutionId', '')::uuid, nullif(scope_rule ->> 'unitId', '')::uuid,
      nullif(scope_rule ->> 'classId', '')::uuid, nullif(scope_rule ->> 'activityId', '')::uuid,
      nullif(scope_rule ->> 'personId', '')::uuid, coalesce((scope_rule ->> 'priority')::integer, plan.priority)
    );
  end loop;

  delete from public.meal_plan_audiences where meal_plan_id = plan.id and tenant_id = plan.tenant_id;
  for scope_rule in select value from jsonb_array_elements(coalesce(p_payload -> 'audienceRules', '[]'::jsonb)) loop
    insert into public.meal_plan_audiences(
      meal_plan_id, tenant_id, audience_segment, selection_mode, target_kind,
      target_id, institution_id, unit_id, class_id, activity_id, person_id,
      effective_from, effective_until, rule, label
    ) values (
      plan.id, plan.tenant_id, coalesce(scope_rule ->> 'audienceSegment', plan.audience_segment),
      coalesce(scope_rule ->> 'selectionMode', 'include'), scope_rule ->> 'targetKind',
      (scope_rule ->> 'targetId')::uuid, plan.institution_id,
      case when scope_rule ->> 'targetKind' = 'unit' then (scope_rule ->> 'targetId')::uuid end,
      case when scope_rule ->> 'targetKind' = 'classLevel' then (scope_rule ->> 'targetId')::uuid end,
      case when scope_rule ->> 'targetKind' = 'activity' then (scope_rule ->> 'targetId')::uuid end,
      case when scope_rule ->> 'targetKind' = 'person' then (scope_rule ->> 'targetId')::uuid end,
      nullif(scope_rule ->> 'effectiveFrom', '')::date, nullif(scope_rule ->> 'effectiveUntil', '')::date,
      coalesce(scope_rule -> 'rule', '{}'::jsonb), nullif(scope_rule ->> 'label', '')
    );
  end loop;

  insert into public.meal_plan_availability(
    meal_plan_id, tenant_id, visibility_mode, visible_from, starts_on, ends_on,
    recurrence, excluded_dates, exception_rules, timezone, updated_at
  ) values (
    plan.id, plan.tenant_id, plan.visibility_mode, plan.visible_from, plan.start_date, plan.end_date,
    plan.recurrence, plan.excluded_dates, plan.exceptions,
    coalesce(nullif(p_payload ->> 'timezone', ''), 'America/Sao_Paulo'), now()
  ) on conflict (meal_plan_id) do update set
    visibility_mode = excluded.visibility_mode, visible_from = excluded.visible_from,
    starts_on = excluded.starts_on, ends_on = excluded.ends_on,
    recurrence = excluded.recurrence, excluded_dates = excluded.excluded_dates,
    exception_rules = excluded.exception_rules, timezone = excluded.timezone, updated_at = now();

  delete from public.meal_plan_meals where meal_plan_id = plan.id and tenant_id = plan.tenant_id;
  for meal_rule in select value from jsonb_array_elements(coalesce(p_payload -> 'menu', '[]'::jsonb)) loop
    insert into public.meal_plan_meals(
      meal_plan_id, tenant_id, meal_type, custom_meal_type, has_time_range,
      starts_at, ends_at, dish_name, dish_details, has_nutrition, portion_grams,
      energy_kcal, protein_g, carbohydrate_g, fat_g, restrictions, image_meta,
      image_alt, weekdays, specific_dates, alternative_group, sort_order
    ) values (
      plan.id, plan.tenant_id, coalesce(meal_rule ->> 'mealType', 'other'),
      nullif(meal_rule ->> 'customMealType', ''), coalesce((meal_rule ->> 'hasTimeRange')::boolean, false),
      nullif(meal_rule ->> 'startsAt', '')::time, nullif(meal_rule ->> 'endsAt', '')::time,
      btrim(coalesce(meal_rule ->> 'dishName', meal_rule ->> 'name', '')),
      nullif(meal_rule ->> 'dishDetails', ''), coalesce((meal_rule ->> 'hasNutrition')::boolean, false),
      nullif(meal_rule ->> 'portionGrams', '')::numeric, nullif(meal_rule ->> 'energyKcal', '')::numeric,
      nullif(meal_rule ->> 'proteinG', '')::numeric, nullif(meal_rule ->> 'carbohydrateG', '')::numeric,
      nullif(meal_rule ->> 'fatG', '')::numeric, coalesce(meal_rule -> 'restrictions', '[]'::jsonb),
      coalesce(meal_rule -> 'imageMeta', '{}'::jsonb), nullif(meal_rule ->> 'imageAlt', ''),
      coalesce(array(select jsonb_array_elements_text(coalesce(meal_rule -> 'weekdays', '[]'::jsonb))::smallint), '{}'),
      coalesce(array(select jsonb_array_elements_text(coalesce(meal_rule -> 'specificDates', '[]'::jsonb))::date), '{}'),
      nullif(meal_rule ->> 'alternativeGroup', ''), coalesce((meal_rule ->> 'sortOrder')::integer, 0)
    );
  end loop;

  if source_template is not null then
    insert into public.meal_plan_template_links(
      meal_plan_id, tenant_id, template_id, template_version, created_by
    ) values (plan.id, plan.tenant_id, source_template, source_version, actor_id)
    on conflict (meal_plan_id) do update set
      template_id = excluded.template_id,
      template_version = excluded.template_version,
      created_by = excluded.created_by,
      created_at = now();
  else
    delete from public.meal_plan_template_links where meal_plan_id = plan.id;
  end if;

  if coalesce((p_payload ->> 'saveAsTemplate')::boolean, false) then
    saved_template := public.meal_plan_template_save(
      null,
      p_payload || jsonb_build_object(
        'name', coalesce(nullif(p_payload ->> 'templateName', ''), plan.name),
        'sourceMealPlanId', plan.id,
        'tenantId', plan.tenant_id,
        'institutionId', plan.institution_id
      ),
      0,
      false
    );
  end if;

  return public.meal_plan_json(plan) || jsonb_build_object('savedTemplate', saved_template);
end;
$$;

revoke all on function public.meal_plan_create_or_update_draft_unreceipted(text, jsonb, uuid, integer) from public, anon, authenticated;

commit;
