-- Close the application-command BOLA gap: every update and revert reads inside the authorized scope.

create or replace function app_private.superadmin_routine_save_application(
  p_request_id uuid, p_application_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  actor uuid;
  aggregate_id uuid := coalesce(p_application_id, gen_random_uuid());
  app_row public.routine_applications;
  response jsonb;
  revision_id uuid;
  revision_no integer;
begin
  actor := app_private.require_routine_actor('routine.manage_applications', false);
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text, 0));
  response := app_private.routine_receipt(p_request_id, actor, 'save_application');
  if response is not null then return response; end if;

  if p_application_id is not null then
    select * into app_row
    from public.routine_applications
    where id = aggregate_id
      and app_private.routine_scope_allowed('routine.manage_applications', institution_id, unit_id, group_id)
    for update;
    if app_row.id is null then
      raise no_data_found using message = 'routine application unavailable';
    end if;
  end if;

  if app_row.id is null then
    if p_expected_version <> 0 then
      raise serialization_failure using message = 'expected_version mismatch';
    end if;
    perform app_private.require_routine_scope(
      'routine.manage_applications',
      (p_payload->>'institution_id')::uuid,
      (p_payload->>'unit_id')::uuid,
      (p_payload->>'group_id')::uuid,
      false
    );
    insert into public.routine_applications(
      id,institution_id,unit_id,group_id,activity_id,scope_kind,source_model_version_id,
      parent_application_id,inheritance_mode,visibility,valid_from,valid_until,starts_at,
      ends_at,status,created_by_person_id
    ) values (
      aggregate_id,(p_payload->>'institution_id')::uuid,(p_payload->>'unit_id')::uuid,
      (p_payload->>'group_id')::uuid,(p_payload->>'activity_id')::uuid,p_payload->>'scope_kind',
      (p_payload->>'source_model_version_id')::uuid,(p_payload->>'parent_application_id')::uuid,
      coalesce(p_payload->>'inheritance_mode','inherited'),
      coalesce(p_payload->>'visibility','authorized_guardians'),(p_payload->>'valid_from')::date,
      (p_payload->>'valid_until')::date,(p_payload->>'starts_at')::time,
      (p_payload->>'ends_at')::time,coalesce(p_payload->>'status','draft'),actor
    ) returning * into app_row;
  else
    if app_row.management_version <> p_expected_version then
      raise serialization_failure using message = 'expected_version mismatch';
    end if;
    update public.routine_applications set
      source_model_version_id=(p_payload->>'source_model_version_id')::uuid,
      parent_application_id=(p_payload->>'parent_application_id')::uuid,
      inheritance_mode=coalesce(p_payload->>'inheritance_mode',inheritance_mode),
      visibility=coalesce(p_payload->>'visibility',visibility),
      valid_from=(p_payload->>'valid_from')::date,valid_until=(p_payload->>'valid_until')::date,
      starts_at=(p_payload->>'starts_at')::time,ends_at=(p_payload->>'ends_at')::time,
      status=coalesce(p_payload->>'status',status),management_version=management_version+1,
      updated_at=now()
    where id=aggregate_id returning * into app_row;
  end if;

  select coalesce(max(revision_no),0)+1 into revision_no
  from public.routine_application_revisions where application_id=aggregate_id;
  insert into public.routine_application_revisions(
    application_id,revision_no,source_model_version_id,origin_application_id,effective_definition,created_by_person_id
  ) values (
    aggregate_id,revision_no,app_row.source_model_version_id,
    coalesce(app_row.parent_application_id,aggregate_id),
    app_private.routine_definition_json(app_row.source_model_version_id),actor
  ) returning id into revision_id;
  delete from public.routine_application_assignees where application_id=aggregate_id;
  insert into public.routine_application_assignees(application_id,institution_id,membership_id,responsibility)
  select aggregate_id,app_row.institution_id,(x->>'membership_id')::uuid,coalesce(x->>'responsibility','record')
  from jsonb_array_elements(coalesce(p_payload->'assignees','[]')) x;
  response:=jsonb_build_object('id',aggregate_id,'management_version',app_row.management_version,
    'revision_id',revision_id,'revision',revision_no);
  insert into app_private.routine_command_receipts values(p_request_id,actor,'save_application',aggregate_id,response,now());
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
  values(actor,auth.jwt()->>'aal','routine.application.save','routine_application',aggregate_id,app_row.institution_id,'success',response);
  return response;
end $$;

create or replace function app_private.superadmin_routine_revert_application(uuid,uuid,bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  actor uuid;
  app_row public.routine_applications;
  parent_row public.routine_applications;
  response jsonb;
  revision_no integer;
begin
  actor:=app_private.require_routine_actor('routine.manage_applications',false);
  perform pg_advisory_xact_lock(hashtextextended($2::text,0));
  response:=app_private.routine_receipt($1,actor,'revert_application');
  if response is not null then return response; end if;
  select * into app_row
  from public.routine_applications
  where id=$2
    and app_private.routine_scope_allowed('routine.manage_applications', institution_id, unit_id, group_id)
  for update;
  if app_row.id is null then
    raise no_data_found using message='routine application unavailable';
  end if;
  if app_row.management_version<>$3 or app_row.parent_application_id is null then
    raise serialization_failure using message='expected_version mismatch';
  end if;
  select * into parent_row from public.routine_applications
  where id=app_row.parent_application_id and institution_id=app_row.institution_id;
  if parent_row.id is null then
    raise no_data_found using message='routine application unavailable';
  end if;
  update public.routine_applications set source_model_version_id=parent_row.source_model_version_id,
    inheritance_mode='inherited',management_version=management_version+1,updated_at=now()
  where id=$2 returning * into app_row;
  select coalesce(max(revision_no),0)+1 into revision_no
  from public.routine_application_revisions where application_id=$2;
  insert into public.routine_application_revisions(
    application_id,revision_no,source_model_version_id,origin_application_id,effective_definition,created_by_person_id
  ) values ($2,revision_no,app_row.source_model_version_id,parent_row.id,
    app_private.routine_definition_json(app_row.source_model_version_id),actor);
  response:=jsonb_build_object('id',$2,'management_version',app_row.management_version,'inherited',true);
  insert into app_private.routine_command_receipts values($1,actor,'revert_application',$2,response,now());
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
  values(actor,auth.jwt()->>'aal','routine.application.revert','routine_application',$2,app_row.institution_id,'success',response);
  return response;
end $$;

revoke all on function app_private.superadmin_routine_save_application(uuid,uuid,bigint,jsonb) from public,anon,authenticated;
revoke all on function app_private.superadmin_routine_revert_application(uuid,uuid,bigint) from public,anon,authenticated;