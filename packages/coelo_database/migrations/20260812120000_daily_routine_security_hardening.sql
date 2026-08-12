-- Close authorization and conditional-answer gaps in daily routine commands.

create or replace function app_private.routine_field_visible(
  p_child_entry_id uuid,
  p_field_id uuid
) returns boolean language sql stable security definer set search_path='' as $$
  select not exists (
    select 1 from public.routine_field_conditions c where c.target_field_id = p_field_id
  ) or exists (
    select 1
    from public.routine_field_conditions c
    join public.routine_answers parent_answer
      on parent_answer.child_entry_id = p_child_entry_id
     and parent_answer.field_id = c.source_field_id
    left join public.routine_field_options option_row on option_row.id = c.source_option_id
    where c.target_field_id = p_field_id
      and app_private.routine_field_visible(p_child_entry_id, c.source_field_id)
      and (
        (c.boolean_value is not null and parent_answer.value_json = to_jsonb(c.boolean_value))
        or (c.source_option_id is not null and (
          (jsonb_typeof(parent_answer.value_json) = 'string'
            and parent_answer.value_json #>> '{}' = option_row.value_code)
          or (jsonb_typeof(parent_answer.value_json) = 'array'
            and parent_answer.value_json ? option_row.value_code)
        ))
      )
  )
$$;

create or replace function app_private.validate_routine_launch_answers(
  p_launch_id uuid,
  p_require_visible_required boolean
) returns void language plpgsql security definer set search_path='' as $$
begin
  if exists (
    select 1
    from public.routine_child_entries e
    join public.routine_launches l on l.id = e.launch_id
    join public.routine_application_revisions r on r.id = l.application_revision_id
    join public.routine_fields f on f.model_version_id = r.source_model_version_id
    join public.routine_answers a on a.child_entry_id = e.id and a.field_id = f.id
    where e.launch_id = p_launch_id
      and a.value_json is not null
      and not app_private.routine_field_visible(e.id, f.id)
  ) then
    raise check_violation using message = 'routine answer hidden by condition';
  end if;

  if p_require_visible_required and exists (
    select 1
    from public.routine_child_entries e
    join public.routine_launches l on l.id = e.launch_id
    join public.routine_application_revisions r on r.id = l.application_revision_id
    join public.routine_fields f on f.model_version_id = r.source_model_version_id and f.is_required
    where e.launch_id = p_launch_id
      and app_private.routine_field_visible(e.id, f.id)
      and not exists (
        select 1 from public.routine_answers a
        where a.child_entry_id = e.id and a.field_id = f.id and a.value_json is not null
      )
  ) then
    raise check_violation using message = 'required routine answers missing';
  end if;
end $$;

create or replace function app_private.validate_routine_answer()
returns trigger language plpgsql security definer set search_path='' as $$
declare field_row public.routine_fields; invalid_item boolean;
begin
  select f into field_row
  from public.routine_child_entries e
  join public.routine_launches l on l.id = e.launch_id
  join public.routine_application_revisions r on r.id = l.application_revision_id
  join public.routine_fields f on f.model_version_id = r.source_model_version_id
  where e.id = new.child_entry_id and f.id = new.field_id;
  if field_row.id is null then raise check_violation using message = 'routine answer field mismatch'; end if;
  if new.value_json is null then return new; end if;
  if (field_row.field_kind in ('short_text','long_text') and jsonb_typeof(new.value_json) <> 'string')
    or (field_row.field_kind = 'number' and jsonb_typeof(new.value_json) <> 'number')
    or (field_row.field_kind = 'boolean' and jsonb_typeof(new.value_json) <> 'boolean')
    or (field_row.field_kind = 'single_choice' and jsonb_typeof(new.value_json) <> 'string')
    or (field_row.field_kind = 'multiple_choice' and jsonb_typeof(new.value_json) <> 'array') then
    raise check_violation using message = 'routine answer type mismatch';
  end if;
  if field_row.field_kind = 'short_text' and char_length(new.value_json #>> '{}') > 240
    or field_row.field_kind = 'long_text' and char_length(new.value_json #>> '{}') > 4000 then
    raise check_violation using message = 'routine answer exceeds maximum length';
  end if;
  if field_row.field_kind = 'number' and ((field_row.min_value is not null and (new.value_json #>> '{}')::numeric < field_row.min_value)
    or (field_row.max_value is not null and (new.value_json #>> '{}')::numeric > field_row.max_value)) then
    raise check_violation using message = 'routine answer outside numeric limits';
  end if;
  if field_row.field_kind = 'single_choice' and not exists (
    select 1 from public.routine_field_options o where o.field_id = field_row.id and o.value_code = new.value_json #>> '{}'
  ) then raise check_violation using message = 'routine answer option mismatch'; end if;
  if field_row.field_kind = 'multiple_choice' then
    select exists(select 1 from jsonb_array_elements(new.value_json) item where jsonb_typeof(item) <> 'string'
      or not exists(select 1 from public.routine_field_options o where o.field_id = field_row.id and o.value_code = item #>> '{}'))
      into invalid_item;
    if invalid_item or jsonb_array_length(new.value_json) <> (select count(distinct item #>> '{}') from jsonb_array_elements(new.value_json) item) then
      raise check_violation using message = 'routine answer option mismatch';
    end if;
  end if;
  return new;
end $$;

create or replace function app_private.superadmin_routine_model_detail(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  select to_jsonb(m) || jsonb_build_object('definition', app_private.routine_definition_json(v.id)) into result
  from public.routine_models m
  left join public.routine_model_versions v on v.model_id = m.id and v.version_no = m.current_version
  where m.id = p_id and app_private.routine_scope_allowed('routine.read',m.institution_id,m.origin_unit_id,null);
  if result is null then raise insufficient_privilege using message = 'routine.read required'; end if;
  return result;
end $$;

create or replace function app_private.superadmin_routine_application_detail(p_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  select to_jsonb(a) || jsonb_build_object('revision',to_jsonb(r),'assignees',coalesce((select jsonb_agg(to_jsonb(x))
    from public.routine_application_assignees x where x.application_id=a.id),'[]'::jsonb)) into result
  from public.routine_applications a left join lateral(select * from public.routine_application_revisions x
    where x.application_id=a.id order by x.revision_no desc limit 1) r on true
  where a.id = p_id and app_private.routine_scope_allowed('routine.read',a.institution_id,a.unit_id,a.group_id);
  if result is null then raise insufficient_privilege using message = 'routine.read required'; end if;
  return result;
end $$;

create or replace function app_private.superadmin_routine_launch_detail(p_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  select to_jsonb(l) || jsonb_build_object('children',coalesce((select jsonb_agg(to_jsonb(e)||jsonb_build_object(
    'answers',coalesce((select jsonb_agg(to_jsonb(a)) from public.routine_answers a where a.child_entry_id=e.id),'[]'::jsonb)))
    from public.routine_child_entries e where e.launch_id=l.id),'[]'::jsonb)) into result
  from public.routine_launches l
  where l.id = p_id and app_private.routine_scope_allowed('routine.read',l.institution_id,l.unit_id,l.group_id);
  if result is null then raise insufficient_privilege using message = 'routine.read required'; end if;
  return result;
end $$;

create or replace function app_private.superadmin_routine_publish_launch(uuid,uuid,bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_private.current_person_id(); launch_row public.routine_launches; response jsonb;
begin
  if actor is null then raise insufficient_privilege using message='authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended($2::text,0));
  response:=app_private.routine_receipt($1,actor,'publish_launch'); if response is not null then return response; end if;
  select l.* into launch_row from public.routine_launches l where l.id=$2
    and app_private.routine_scope_allowed('routine.publish',l.institution_id,l.unit_id,l.group_id) for update;
  if launch_row.id is null then raise insufficient_privilege using message='routine.publish required'; end if;
  if not app_private.has_mfa_aal2() then raise insufficient_privilege using message='MFA AAL2 required'; end if;
  if launch_row.management_version<>$3 or launch_row.status<>'draft' then raise serialization_failure using message='expected_version mismatch'; end if;
  perform app_private.validate_routine_launch_answers($2,true);
  update public.routine_launches set status='published',published_at=now(),updated_at=now(),management_version=management_version+1 where id=$2 returning * into launch_row;
  update public.routine_child_entries set status='published',updated_at=now() where launch_id=$2;
  response:=jsonb_build_object('id',$2,'management_version',launch_row.management_version,'status','published');
  insert into app_private.routine_command_receipts values($1,actor,'publish_launch',$2,response,now());
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
  values(actor,auth.jwt()->>'aal','routine.launch.publish','routine_launch',$2,launch_row.institution_id,'success',response);
  return response;
end $$;

create or replace function app_private.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_private.current_person_id(); launch_row public.routine_launches; before_state jsonb; after_state jsonb; response jsonb; item jsonb; next_revision integer; supplied integer;
begin
  if actor is null then raise insufficient_privilege using message='authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended($2::text,0));
  response:=app_private.routine_receipt($1,actor,'correct_launch'); if response is not null then return response; end if;
  select l.* into launch_row from public.routine_launches l where l.id=$2
    and app_private.routine_scope_allowed('routine.correct',l.institution_id,l.unit_id,l.group_id) for update;
  if launch_row.id is null then raise insufficient_privilege using message='routine.correct required'; end if;
  if not app_private.has_mfa_aal2() then raise insufficient_privilege using message='MFA AAL2 required'; end if;
  if btrim(coalesce($4,''))='' then raise check_violation using message='correction reason required'; end if;
  if jsonb_typeof($5) <> 'array' or jsonb_array_length($5) not between 1 and 500 then raise invalid_parameter_value using message='invalid routine correction payload'; end if;
  supplied := jsonb_array_length($5);
  if supplied <> (select count(distinct item->>'answer_id') from jsonb_array_elements($5) item where item ? 'answer_id')
    or supplied <> (select count(*) from public.routine_answers a join public.routine_child_entries e on e.id=a.child_entry_id
      where e.launch_id=$2 and a.id in (select (item->>'answer_id')::uuid from jsonb_array_elements($5) item)) then
    raise check_violation using message='routine correction answer mismatch';
  end if;
  if launch_row.management_version<>$3 or launch_row.status not in ('published','corrected') then raise serialization_failure using message='expected_version mismatch'; end if;
  select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]') into before_state from public.routine_answers a join public.routine_child_entries e on e.id=a.child_entry_id where e.launch_id=$2;
  for item in select value from jsonb_array_elements($5) loop
    update public.routine_answers a set value_json=item->'value',answered_by_person_id=actor,answered_at=now()
    from public.routine_child_entries e where a.id=(item->>'answer_id')::uuid and e.id=a.child_entry_id and e.launch_id=$2;
  end loop;
  perform app_private.validate_routine_launch_answers($2,true);
  select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]') into after_state from public.routine_answers a join public.routine_child_entries e on e.id=a.child_entry_id where e.launch_id=$2;
  select coalesce(max(revision_no),0)+1 into next_revision from public.routine_launch_revisions where launch_id=$2;
  insert into public.routine_launch_revisions(launch_id,revision_no,reason,before_json,after_json,changed_by_person_id) values($2,next_revision,btrim($4),before_state,after_state,actor);
  update public.routine_launches set status='corrected',corrected_at=now(),updated_at=now(),management_version=management_version+1 where id=$2 returning * into launch_row;
  response:=jsonb_build_object('id',$2,'management_version',launch_row.management_version,'status','corrected','revision',next_revision);
  insert into app_private.routine_command_receipts values($1,actor,'correct_launch',$2,response,now());
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,reason,before_json,after_json) values(actor,auth.jwt()->>'aal','routine.launch.correct','routine_launch',$2,launch_row.institution_id,'success',btrim($4),before_state,after_state);
  return response;
end $$;

create or replace function public.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb)
returns jsonb language sql security definer set search_path='' as $$
  select app_private.superadmin_routine_correct_launch($1,$2,$3,$4,$5)
$$;

revoke all on function app_private.routine_field_visible(uuid,uuid) from public,anon,authenticated;
revoke all on function app_private.validate_routine_launch_answers(uuid,boolean) from public,anon,authenticated;
grant execute on function app_private.routine_field_visible(uuid,uuid) to service_role;
grant execute on function app_private.validate_routine_launch_answers(uuid,boolean) to service_role;

create or replace function app_private.superadmin_routine_save_launch_draft(uuid,uuid,bigint,jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_private.current_person_id(); aggregate_id uuid:=coalesce($2,gen_random_uuid()); launch_row public.routine_launches;
  response jsonb; child_row jsonb; answer_row jsonb; entry_id uuid;
begin
  if actor is null then raise insufficient_privilege using message='authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text,0));
  response:=app_private.routine_receipt($1,actor,'save_launch_draft'); if response is not null then return response; end if;
  select l.* into launch_row from public.routine_launches l where l.id=aggregate_id
    and app_private.routine_scope_allowed('routine.record',l.institution_id,l.unit_id,l.group_id) for update;
  if $2 is not null and launch_row.id is null then raise insufficient_privilege using message='routine.record required'; end if;
  if launch_row.id is null then
    if $3<>0 then raise serialization_failure using message='expected_version mismatch'; end if;
    perform app_private.require_routine_scope('routine.record',($4->>'institution_id')::uuid,($4->>'unit_id')::uuid,($4->>'group_id')::uuid,false);
    insert into public.routine_launches(id,institution_id,unit_id,group_id,activity_id,application_id,application_revision_id,service_date,author_membership_id)
    values(aggregate_id,($4->>'institution_id')::uuid,($4->>'unit_id')::uuid,($4->>'group_id')::uuid,($4->>'activity_id')::uuid,
      ($4->>'application_id')::uuid,($4->>'application_revision_id')::uuid,($4->>'service_date')::date,($4->>'author_membership_id')::uuid)
    returning * into launch_row;
  else
    if launch_row.management_version<>$3 or launch_row.status<>'draft' then raise serialization_failure using message='expected_version mismatch'; end if;
    update public.routine_launches set management_version=management_version+1,updated_at=now() where id=aggregate_id returning * into launch_row;
  end if;
  for child_row in select value from jsonb_array_elements(coalesce($4->'children','[]')) loop
    entry_id:=coalesce((child_row->>'entry_id')::uuid,gen_random_uuid());
    insert into public.routine_child_entries(id,launch_id,child_context_id,child_group_link_id,status)
    values(entry_id,aggregate_id,(child_row->>'child_context_id')::uuid,(child_row->>'child_group_link_id')::uuid,coalesce(child_row->>'status','draft'))
    on conflict(launch_id,child_context_id) do update set status=excluded.status,updated_at=now() returning id into entry_id;
    for answer_row in select value from jsonb_array_elements(coalesce(child_row->'answers','[]')) loop
      insert into public.routine_answers(child_entry_id,field_id,value_json,answered_by_person_id)
      values(entry_id,(answer_row->>'field_id')::uuid,answer_row->'value',actor)
      on conflict(child_entry_id,field_id) do update set value_json=excluded.value_json,answered_by_person_id=excluded.answered_by_person_id,answered_at=now();
    end loop;
  end loop;
  perform app_private.validate_routine_launch_answers(aggregate_id,false);
  response:=jsonb_build_object('id',aggregate_id,'management_version',launch_row.management_version,'status',launch_row.status);
  insert into app_private.routine_command_receipts values($1,actor,'save_launch_draft',aggregate_id,response,now());
  return response;
end $$;
