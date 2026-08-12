-- Keep model writes inside the actor's effective institution/unit scope.
-- This replaces the first command implementation, which only checked a
-- global capability before reading or creating an aggregate.

create or replace function app_private.superadmin_routine_save_model(
  p_request_id uuid,
  p_model_id uuid,
  p_expected_version bigint,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.current_person_id();
  aggregate_id uuid := coalesce(p_model_id, gen_random_uuid());
  model_row public.routine_models%rowtype;
  requested_institution_id uuid;
  requested_origin_scope_kind text;
  requested_origin_unit_id uuid;
  version_id uuid;
  next_version integer;
  response jsonb;
  before_state jsonb;
  after_state jsonb;
  section jsonb;
  field jsonb;
  option_row jsonb;
  condition_row jsonb;
  section_id uuid;
  field_id uuid;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  if jsonb_typeof(p_payload) <> 'object' then
    raise invalid_parameter_value using message = 'invalid routine model payload';
  end if;

  -- Lock first, then authorize the *stored* scope.  An unauthorized update
  -- deliberately has the same opaque outcome as an absent aggregate.
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text, 0));
  select * into model_row
  from public.routine_models
  where id = aggregate_id
  for update;

  if model_row.id is not null then
    if not app_private.routine_scope_allowed(
      'routine.manage_models',
      model_row.institution_id,
      model_row.origin_unit_id,
      null
    ) then
      raise no_data_found using message = 'routine model unavailable';
    end if;
    if model_row.management_version <> p_expected_version then
      raise serialization_failure using message = 'expected_version mismatch';
    end if;
    if model_row.is_system then
      raise insufficient_privilege using message = 'system routine model is immutable';
    end if;
    before_state := to_jsonb(model_row);
  else
    if p_expected_version <> 0 then
      raise serialization_failure using message = 'expected_version mismatch';
    end if;
    requested_institution_id := nullif(p_payload->>'institution_id', '')::uuid;
    requested_origin_scope_kind := coalesce(nullif(p_payload->>'origin_scope_kind', ''), 'institution');
    requested_origin_unit_id := nullif(p_payload->>'origin_unit_id', '')::uuid;
    if requested_institution_id is null
       or requested_origin_scope_kind not in ('institution', 'unit')
       or (requested_origin_scope_kind = 'institution' and requested_origin_unit_id is not null)
       or (requested_origin_scope_kind = 'unit' and requested_origin_unit_id is null)
       or not app_private.routine_scope_allowed(
         'routine.manage_models',
         requested_institution_id,
         requested_origin_unit_id,
         null
       ) then
      raise no_data_found using message = 'routine model unavailable';
    end if;
  end if;

  response := app_private.routine_receipt(p_request_id, actor, 'save_model');
  if response is not null then
    return response;
  end if;

  if model_row.id is null then
    insert into public.routine_models(
      id, institution_id, origin_scope_kind, origin_unit_id, name, description,
      status, created_by_person_id
    ) values (
      aggregate_id, requested_institution_id, requested_origin_scope_kind,
      requested_origin_unit_id, btrim(p_payload->>'name'),
      coalesce(p_payload->>'description', ''), coalesce(p_payload->>'status', 'draft'), actor
    ) returning * into model_row;
  else
    update public.routine_models
    set name = btrim(p_payload->>'name'),
        description = coalesce(p_payload->>'description', ''),
        status = coalesce(p_payload->>'status', status),
        management_version = management_version + 1,
        updated_at = now()
    where id = aggregate_id
    returning * into model_row;
  end if;

  next_version := model_row.current_version + 1;
  insert into public.routine_model_versions(
    model_id, version_no, governance_kind, status, valid_from, valid_until,
    created_by_person_id, published_at
  ) values (
    aggregate_id, next_version, coalesce(p_payload->>'governance_kind', 'optional'),
    case when p_payload->>'status' = 'active' then 'published' else 'draft' end,
    (p_payload->>'valid_from')::date, (p_payload->>'valid_until')::date, actor,
    case when p_payload->>'status' = 'active' then now() end
  ) returning id into version_id;

  for section in select value from jsonb_array_elements(coalesce(p_payload->'sections', '[]')) loop
    section_id := coalesce((section->>'id')::uuid, gen_random_uuid());
    insert into public.routine_sections
    values (section_id, version_id, btrim(section->>'name'), coalesce((section->>'order')::integer, 0), now());
    for field in select value from jsonb_array_elements(coalesce(section->'fields', '[]')) loop
      field_id := coalesce((field->>'id')::uuid, gen_random_uuid());
      insert into public.routine_fields(
        id, model_version_id, section_id, label, field_kind, is_required,
        initial_value, min_value, max_value, sort_order
      ) values (
        field_id, version_id, section_id, btrim(field->>'label'), field->>'kind',
        coalesce((field->>'required')::boolean, false), field->'initial_value',
        (field->>'min_value')::numeric, (field->>'max_value')::numeric,
        coalesce((field->>'order')::integer, 0)
      );
      for option_row in select value from jsonb_array_elements(coalesce(field->'options', '[]')) loop
        insert into public.routine_field_options
        values (
          coalesce((option_row->>'id')::uuid, gen_random_uuid()), version_id, field_id,
          btrim(option_row->>'label'), option_row->>'value',
          coalesce((option_row->>'order')::integer, 0)
        );
      end loop;
    end loop;
  end loop;

  for condition_row in select value from jsonb_array_elements(coalesce(p_payload->'conditions', '[]')) loop
    insert into public.routine_field_conditions(
      model_version_id, source_field_id, source_option_id, boolean_value, target_field_id
    ) values (
      version_id, (condition_row->>'source_field_id')::uuid,
      nullif(condition_row->>'source_option_id', '')::uuid,
      (condition_row->>'boolean_value')::boolean,
      (condition_row->>'target_field_id')::uuid
    );
  end loop;

  perform app_private.validate_routine_definition(version_id);
  update public.routine_models
  set current_version = next_version
  where id = aggregate_id
  returning * into model_row;

  response := jsonb_build_object(
    'id', aggregate_id,
    'management_version', model_row.management_version,
    'model_version_id', version_id,
    'version', next_version
  );
  after_state := to_jsonb(model_row) || jsonb_build_object(
    'model_version_id', version_id,
    'version', next_version
  );
  insert into app_private.routine_command_receipts
  values (p_request_id, actor, 'save_model', aggregate_id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, before_json, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'routine.model.save', 'routine_model', aggregate_id,
    model_row.institution_id, 'success', before_state, after_state
  );
  return response;
end $$;

revoke all on function app_private.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)
from public, anon, authenticated;
