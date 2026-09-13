-- R11: qualify child rows under #variable_conflict use_variable.
-- Keep receipt, actor, tenant and optimistic-version checks unchanged.
create or replace function app_private.assessment_v2_save_configuration(
  request_id uuid, configuration_id uuid, expected_version bigint, payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
-- Correcao R04: as consultas qualificam colunas por alias e usam as variaveis
-- institution_id/unit_id/activity_id sem qualificar; sem esta diretiva o
-- Postgres 17 aborta com 'column reference is ambiguous'.
#variable_conflict use_variable
declare
  ctx app_private.superadmin_internal_context; saved public.activity_assessment_configurations%rowtype;
  institution_id uuid; unit_id uuid; activity_id uuid; request_hash bytea; replay jsonb;
  instrument jsonb; concept jsonb; category jsonb; competency jsonb; period jsonb;
  v_category_id uuid; v_competency_id uuid; instrument_total numeric;
begin
  if payload is null or jsonb_typeof(payload) <> 'object'
    or exists (select 1 from jsonb_object_keys(payload) k where k not in (
      'activity_id','institution_id','unit_id','periodicity','result_scale_kind',
      'scale_options','concepts','periods','allow_final_override','instruments','categories'))
    or not (payload ?& array['activity_id','institution_id','periodicity','result_scale_kind',
      'scale_options','periods','allow_final_override','instruments','categories'])
    or jsonb_typeof(payload->'scale_options') <> 'object'
    or jsonb_typeof(payload->'periods') <> 'array'
    or jsonb_typeof(payload->'instruments') <> 'array'
    or jsonb_typeof(payload->'categories') <> 'array'
    or coalesce(jsonb_typeof(payload->'concepts'), 'array') <> 'array'
    or jsonb_array_length(payload->'periods') not between 1 and 12
    or jsonb_array_length(payload->'instruments') not between 1 and 30
    or jsonb_array_length(payload->'categories') > 30 then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;
  begin
    activity_id := (payload->>'activity_id')::uuid;
    institution_id := (payload->>'institution_id')::uuid;
    unit_id := nullif(payload->>'unit_id', '')::uuid;
  exception when others then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
  end;
  select * into strict ctx
  from app_private.assessment_v2_require_context('activities.manage', institution_id);
  if not exists (select 1 from public.activity_definitions a
    where a.id = activity_id and a.institution_id = institution_id
      and a.status in ('draft','active'))
    or (unit_id is not null and not exists (select 1 from public.units u
      where u.id = unit_id and u.institution_id = institution_id and u.status = 'active'))
    or payload->>'periodicity' not in ('bimonthly','trimester','semester','annual')
    or payload->>'result_scale_kind' not in (
      'numeric_0_10','numeric_0_100','concept','numeric_1_5','binary','stars_0_5') then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_REFERENCE';
  end if;
  request_hash := app_private.assessment_v2_hash(jsonb_build_object(
    'configuration_id', configuration_id, 'expected_version', expected_version, 'payload', payload));
  replay := app_private.assessment_v2_replay(ctx, request_id, 'configuration.save', request_hash);
  if replay is not null then return replay; end if;

  if configuration_id is null then
    if expected_version <> 0 then raise serialization_failure using detail = 'SAI_CONCURRENT_CHANGE'; end if;
    insert into public.activity_assessment_configurations(
      activity_id, institution_id, unit_id, periodicity, result_scale_kind,
      scale_options, allow_final_override)
    values (activity_id, institution_id, unit_id, payload->>'periodicity',
      payload->>'result_scale_kind', payload->'scale_options',
      coalesce((payload->>'allow_final_override')::boolean, false))
    returning * into saved;
  else
    select * into saved from public.activity_assessment_configurations c
    where c.id = configuration_id and c.institution_id = institution_id for update;
    if not found then raise no_data_found using detail = 'ASSESSMENT_NOT_FOUND'; end if;
    if saved.management_version <> expected_version then
      raise serialization_failure using detail = 'SAI_CONCURRENT_CHANGE';
    end if;
    if saved.status <> 'draft' or saved.activity_id <> activity_id
      or saved.unit_id is distinct from unit_id then
      raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
    end if;
    update public.activity_assessment_configurations c set
      periodicity = payload->>'periodicity', result_scale_kind = payload->>'result_scale_kind',
      scale_options = payload->'scale_options',
      allow_final_override = coalesce((payload->>'allow_final_override')::boolean, false),
      management_version = c.management_version + 1, updated_at = now()
    where c.id = saved.id returning * into saved;
    delete from public.assessment_instruments item where item.configuration_id = saved.id;
    delete from public.assessment_categories item where item.configuration_id = saved.id;
    delete from public.assessment_scale_concepts item where item.configuration_id = saved.id;
    delete from public.assessment_periods item where item.configuration_id = saved.id;
  end if;

  for instrument in select value from jsonb_array_elements(payload->'instruments') loop
    if jsonb_typeof(instrument) <> 'object'
      or not (instrument ?& array['name','weight','sort_order'])
      or exists (select 1 from jsonb_object_keys(instrument) k
        where k not in ('name','weight','sort_order')) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_instruments(configuration_id, name, weight, sort_order)
    values (saved.id, btrim(instrument->>'name'), (instrument->>'weight')::numeric,
      (instrument->>'sort_order')::integer);
  end loop;
  select sum(i.weight) into instrument_total from public.assessment_instruments i
  where i.configuration_id = saved.id;
  if instrument_total <> 100 then
    raise check_violation using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;

  for concept in select value from jsonb_array_elements(coalesce(payload->'concepts','[]'::jsonb)) loop
    if jsonb_typeof(concept) <> 'object' or not (concept ?& array['code','label','sort_order']) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_scale_concepts(configuration_id, code, label, sort_order)
    values (saved.id, btrim(concept->>'code'), btrim(concept->>'label'),
      (concept->>'sort_order')::integer);
  end loop;
  if saved.result_scale_kind = 'concept'
    and not exists (select 1 from public.assessment_scale_concepts s where s.configuration_id = saved.id) then
    raise check_violation using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;

  for category in select value from jsonb_array_elements(payload->'categories') loop
    if jsonb_typeof(category) <> 'object' or not (category ?& array['name','competencies'])
      or jsonb_typeof(category->'competencies') <> 'array' then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_categories(configuration_id, name, sort_order)
    values (saved.id, btrim(category->>'name'),
      coalesce((category->>'sort_order')::integer,
        (select count(*) from public.assessment_categories c where c.configuration_id = saved.id)))
    returning id into v_category_id;
    for competency in select value from jsonb_array_elements(category->'competencies') loop
      insert into public.assessment_competencies(category_id, configuration_id, name, sort_order)
      values (v_category_id, saved.id, btrim(competency->>'name'),
        coalesce((competency->>'sort_order')::integer, 0))
      returning id into v_competency_id;
      insert into public.assessment_configuration_competencies(configuration_id, competency_id, sort_order)
      values (saved.id, v_competency_id, coalesce((competency->>'sort_order')::integer, 0));
    end loop;
  end loop;

  for period in select value from jsonb_array_elements(payload->'periods') loop
    if jsonb_typeof(period) <> 'object'
      or not (period ?& array['name','ordinal','academic_year','starts_on','ends_on',
        'entry_closes_at','family_release_at']) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    if not exists (select 1 from pg_catalog.pg_timezone_names z
      where z.name = coalesce(nullif(period->>'timezone',''), 'America/Sao_Paulo')) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_periods(
      configuration_id, institution_id, unit_id, name, periodicity, ordinal,
      academic_year, starts_on, ends_on, entry_closes_at, family_release_at,
      timezone, status)
    values (saved.id, saved.institution_id, saved.unit_id, btrim(period->>'name'),
      saved.periodicity, (period->>'ordinal')::smallint, (period->>'academic_year')::integer,
      (period->>'starts_on')::date, (period->>'ends_on')::date,
      (period->>'entry_closes_at')::timestamptz, (period->>'family_release_at')::timestamptz,
      coalesce(nullif(period->>'timezone',''), 'America/Sao_Paulo'), 'draft');
  end loop;
  return app_private.assessment_v2_finish(ctx, request_id, saved.institution_id,
    saved.id, 'configuration.save', request_hash, saved.management_version,
    saved.status, null);
end $$;
