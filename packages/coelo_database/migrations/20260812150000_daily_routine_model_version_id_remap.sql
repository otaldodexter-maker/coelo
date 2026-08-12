-- A model version is immutable. Client editor IDs identify payload nodes only;
-- every persisted version gets a fresh, internally remapped definition graph.

create or replace function app_private.routine_insert_version_definition(p_version_id uuid, p_payload jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare
  section_row jsonb; field_row jsonb; option_row jsonb; condition_row jsonb;
  source_section_id text; source_field_id text; source_option_id text;
  section_ids jsonb := '{}'::jsonb; field_ids jsonb := '{}'::jsonb; option_ids jsonb := '{}'::jsonb;
begin
  if jsonb_typeof(coalesce(p_payload->'sections','[]'::jsonb)) <> 'array'
    or jsonb_typeof(coalesce(p_payload->'conditions','[]'::jsonb)) <> 'array' then
    raise invalid_parameter_value using message='routine definition must contain arrays';
  end if;

  -- Map every client node ID first so forward branch references are safe.
  for section_row in select value from jsonb_array_elements(coalesce(p_payload->'sections','[]'::jsonb)) loop
    source_section_id := nullif(section_row->>'id','');
    begin perform source_section_id::uuid; exception when invalid_text_representation then
      raise invalid_parameter_value using message='invalid section id'; end;
    if source_section_id is null then raise invalid_parameter_value using message='section id required'; end if;
    if section_ids ? source_section_id then raise unique_violation using message='duplicate section id in routine definition'; end if;
    section_ids := section_ids || jsonb_build_object(source_section_id,gen_random_uuid()::text);
    if jsonb_typeof(coalesce(section_row->'fields','[]'::jsonb)) <> 'array' then
      raise invalid_parameter_value using message='section fields must be an array'; end if;
    for field_row in select value from jsonb_array_elements(coalesce(section_row->'fields','[]'::jsonb)) loop
      source_field_id := nullif(field_row->>'id','');
      begin perform source_field_id::uuid; exception when invalid_text_representation then
        raise invalid_parameter_value using message='invalid field id'; end;
      if source_field_id is null then raise invalid_parameter_value using message='field id required'; end if;
      if field_ids ? source_field_id then raise unique_violation using message='duplicate field id in routine definition'; end if;
      field_ids := field_ids || jsonb_build_object(source_field_id,gen_random_uuid()::text);
      if jsonb_typeof(coalesce(field_row->'options','[]'::jsonb)) <> 'array' then
        raise invalid_parameter_value using message='field options must be an array'; end if;
      for option_row in select value from jsonb_array_elements(coalesce(field_row->'options','[]'::jsonb)) loop
        source_option_id := nullif(option_row->>'id','');
        begin perform source_option_id::uuid; exception when invalid_text_representation then
          raise invalid_parameter_value using message='invalid option id'; end;
        if source_option_id is null then raise invalid_parameter_value using message='option id required'; end if;
        if option_ids ? source_option_id then raise unique_violation using message='duplicate option id in routine definition'; end if;
        option_ids := option_ids || jsonb_build_object(source_option_id,gen_random_uuid()::text);
      end loop;
    end loop;
  end loop;

  for section_row in select value from jsonb_array_elements(coalesce(p_payload->'sections','[]'::jsonb)) loop
    source_section_id := section_row->>'id';
    insert into public.routine_sections(id,model_version_id,name,sort_order)
    values((section_ids->>source_section_id)::uuid,p_version_id,btrim(section_row->>'name'),coalesce((section_row->>'order')::integer,0));
    for field_row in select value from jsonb_array_elements(coalesce(section_row->'fields','[]'::jsonb)) loop
      source_field_id := field_row->>'id';
      insert into public.routine_fields(id,model_version_id,section_id,label,field_kind,is_required,initial_value,min_value,max_value,sort_order)
      values((field_ids->>source_field_id)::uuid,p_version_id,(section_ids->>source_section_id)::uuid,btrim(field_row->>'label'),
        field_row->>'kind',coalesce((field_row->>'required')::boolean,false),field_row->'initial_value',
        (field_row->>'min_value')::numeric,(field_row->>'max_value')::numeric,coalesce((field_row->>'order')::integer,0));
      for option_row in select value from jsonb_array_elements(coalesce(field_row->'options','[]'::jsonb)) loop
        source_option_id := option_row->>'id';
        insert into public.routine_field_options(id,model_version_id,field_id,label,value_code,sort_order)
        values((option_ids->>source_option_id)::uuid,p_version_id,(field_ids->>source_field_id)::uuid,btrim(option_row->>'label'),
          option_row->>'value',coalesce((option_row->>'order')::integer,0));
      end loop;
    end loop;
  end loop;

  for condition_row in select value from jsonb_array_elements(coalesce(p_payload->'conditions','[]'::jsonb)) loop
    source_field_id := nullif(condition_row->>'source_field_id','');
    source_option_id := nullif(condition_row->>'source_option_id','');
    if source_field_id is null or not (field_ids ? source_field_id)
      or nullif(condition_row->>'target_field_id','') is null or not (field_ids ? (condition_row->>'target_field_id'))
      or (source_option_id is not null and not (option_ids ? source_option_id)) then
      raise invalid_parameter_value using message='condition references an unknown routine definition node';
    end if;
    insert into public.routine_field_conditions(model_version_id,source_field_id,source_option_id,boolean_value,target_field_id)
    values(p_version_id,(field_ids->>source_field_id)::uuid,
      case when source_option_id is null then null else (option_ids->>source_option_id)::uuid end,
      (condition_row->>'boolean_value')::boolean,(field_ids->>(condition_row->>'target_field_id'))::uuid);
  end loop;
end $$;

create or replace function app_private.superadmin_routine_save_model(p_request_id uuid,p_model_id uuid,p_expected_version bigint,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; aggregate_id uuid:=coalesce(p_model_id,gen_random_uuid()); model_row public.routine_models;
 version_id uuid; next_version integer; response jsonb; before_state jsonb; after_state jsonb;
begin
 actor:=app_private.require_routine_actor('routine.manage_models',false);
 perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text,0));
 select * into model_row from public.routine_models where id=aggregate_id for update;
 if model_row.id is null then
  if p_expected_version<>0 then raise serialization_failure using message='expected_version mismatch'; end if;
  if not app_private.routine_scope_allowed('routine.manage_models',(p_payload->>'institution_id')::uuid,(p_payload->>'origin_unit_id')::uuid,null) then
   raise no_data_found using message='routine model unavailable'; end if;
  insert into public.routine_models(id,institution_id,origin_scope_kind,origin_unit_id,name,description,status,created_by_person_id)
  values(aggregate_id,(p_payload->>'institution_id')::uuid,coalesce(p_payload->>'origin_scope_kind','institution'),
   (p_payload->>'origin_unit_id')::uuid,btrim(p_payload->>'name'),coalesce(p_payload->>'description',''),
   coalesce(p_payload->>'status','draft'),actor) returning * into model_row;
 else
  if model_row.management_version<>p_expected_version then raise serialization_failure using message='expected_version mismatch'; end if;
  if model_row.is_system then raise insufficient_privilege using message='system routine model is immutable'; end if;
  if not app_private.routine_scope_allowed('routine.manage_models',model_row.institution_id,model_row.origin_unit_id,null) then
   raise no_data_found using message='routine model unavailable'; end if;
  before_state:=to_jsonb(model_row);
  update public.routine_models set name=btrim(p_payload->>'name'),description=coalesce(p_payload->>'description',''),
   status=coalesce(p_payload->>'status',status),management_version=management_version+1,updated_at=now()
   where id=aggregate_id returning * into model_row;
 end if;
 response:=app_private.routine_receipt(p_request_id,actor,'save_model'); if response is not null then return response; end if;
 next_version:=model_row.current_version+1;
 insert into public.routine_model_versions(model_id,version_no,governance_kind,status,valid_from,valid_until,created_by_person_id,published_at)
 values(aggregate_id,next_version,coalesce(p_payload->>'governance_kind','optional'),
  case when p_payload->>'status'='active' then 'published' else 'draft' end,(p_payload->>'valid_from')::date,
  (p_payload->>'valid_until')::date,actor,case when p_payload->>'status'='active' then now() end) returning id into version_id;
 perform app_private.routine_insert_version_definition(version_id,p_payload);
 perform app_private.validate_routine_definition(version_id);
 update public.routine_models set current_version=next_version where id=aggregate_id returning * into model_row;
 response:=jsonb_build_object('id',aggregate_id,'management_version',model_row.management_version,'model_version_id',version_id,'version',next_version);
 after_state:=to_jsonb(model_row)||jsonb_build_object('model_version_id',version_id,'version',next_version);
 insert into app_private.routine_command_receipts values(p_request_id,actor,'save_model',aggregate_id,response,now());
 insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,before_json,after_json)
 values(actor,auth.jwt()->>'aal','routine.model.save','routine_model',aggregate_id,model_row.institution_id,'success',before_state,after_state);
 return response;
end $$;

revoke all on function app_private.routine_insert_version_definition(uuid,jsonb) from public,anon,authenticated;
grant execute on function app_private.routine_insert_version_definition(uuid,jsonb) to service_role;
revoke all on function app_private.superadmin_routine_save_model(uuid,uuid,bigint,jsonb) from public,anon,authenticated;
grant execute on function app_private.superadmin_routine_save_model(uuid,uuid,bigint,jsonb) to service_role;
