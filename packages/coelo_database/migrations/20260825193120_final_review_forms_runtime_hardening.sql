-- Final Revisao Supabase: forward-only runtime/lint hardening.
-- Public signatures and existing privileges are preserved.

CREATE INDEX IF NOT EXISTS form_file_download_tokens_actor_person_idx
  ON app_private.form_file_download_tokens(actor_person_id);

CREATE OR REPLACE FUNCTION app_private.validate_form_tenant_links()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if tg_table_name = 'form_applications' then
    if not exists(
    select 1 from public.forms form_row
    where form_row.id = new.form_id and form_row.institution_id = new.institution_id
  ) then
      raise check_violation using message = 'form application tenant mismatch';
    end if;
    return new;
  end if;
  if tg_table_name = 'form_audience_rules' then
    if (
    not exists(
      select 1 from public.form_applications application
       where application.id = new.application_id
         and application.institution_id = new.institution_id
    )
    or not case new.rule_kind
      when 'institution' then new.target_id = new.institution_id
      when 'unit' then exists(
        select 1 from public.units unit_row
         where unit_row.id = new.target_id and unit_row.institution_id = new.institution_id
      )
      when 'group' then exists(
        select 1 from public.groups group_row
         where group_row.id = new.target_id and group_row.institution_id = new.institution_id
      )
      when 'activity' then exists(
        select 1 from public.activity_definitions activity
         where activity.id = new.target_id and activity.institution_id = new.institution_id
      )
      when 'profile' then exists(
        select 1
          from public.institution_role_assignments assignment
          join public.institution_memberships membership on membership.id = assignment.membership_id
         where assignment.role_id = new.target_id
           and membership.institution_id = new.institution_id
      )
      else exists(
        select 1 from public.institution_memberships membership
         where membership.person_id = new.target_id
           and membership.institution_id = new.institution_id
        union all
        select 1
          from public.guardian_links guardian
          join public.child_contexts child_context
            on child_context.child_person_id = guardian.child_person_id
         where guardian.guardian_person_id = new.target_id
           and child_context.institution_id = new.institution_id
        union all
        select 1 from public.child_contexts child_context
         where child_context.child_person_id = new.target_id
           and child_context.institution_id = new.institution_id
      )
    end
  ) then
      raise check_violation using message = 'audience rule target tenant mismatch';
    end if;
    return new;
  end if;
  if tg_table_name = 'form_occurrences' then
    if not exists(
    select 1
      from public.form_applications application_row
      join public.forms form_row on form_row.id = application_row.form_id
      join public.form_versions version_row on version_row.id = new.form_version_id
      join public.form_schedules schedule_row on schedule_row.id = new.schedule_id
     where application_row.id = new.application_id
       and application_row.form_id = new.form_id
       and application_row.institution_id = new.institution_id
       and form_row.institution_id = new.institution_id
       and version_row.form_id = new.form_id
       and schedule_row.application_id = new.application_id
  ) then
      raise check_violation using message = 'form occurrence tenant or version mismatch';
    end if;
    return new;
  end if;
  if tg_table_name = 'form_responses' then
    if not exists(
    select 1 from public.form_occurrences occurrence_row
    where occurrence_row.id = new.occurrence_id
      and occurrence_row.institution_id = new.institution_id
      and occurrence_row.form_id = new.form_id
      and occurrence_row.form_version_id = new.form_version_id
  ) then
      raise check_violation using message = 'form response tenant or version mismatch';
    end if;
    return new;
  end if;
  if tg_table_name = 'form_answers' then
    if not exists(
    select 1
      from public.form_responses response_row
      join public.form_items item_row on item_row.id = new.item_id
     where response_row.id = new.response_id
       and response_row.form_version_id = new.form_version_id
       and item_row.form_version_id = new.form_version_id
  ) then
      raise check_violation using message = 'form answer version mismatch';
    end if;
    return new;
  end if;
  if tg_table_name = 'form_participations' then
    if (
    not exists(
      select 1 from public.form_occurrences occurrence
       where occurrence.id = new.occurrence_id
         and occurrence.institution_id = new.institution_id
    )
    or (new.child_context_id is not null and not exists(
      select 1 from public.child_contexts child_context
       where child_context.id = new.child_context_id
         and child_context.institution_id = new.institution_id
    ))
    or (new.person_id is not null and not exists(
      select 1 from public.institution_memberships membership
       where membership.person_id = new.person_id
         and membership.institution_id = new.institution_id
      union all
      select 1 from public.child_contexts child_context
       where child_context.child_person_id = new.person_id
         and child_context.institution_id = new.institution_id
      union all
      select 1
        from public.guardian_links guardian
        join public.child_contexts child_context
          on child_context.child_person_id = guardian.child_person_id
       where guardian.guardian_person_id = new.person_id
         and child_context.institution_id = new.institution_id
    ))
  ) then
      raise check_violation using message = 'form participation tenant mismatch';
    end if;
    return new;
  end if;
  if tg_table_name = 'form_participation_responders' then
    if not exists(
    select 1
      from public.form_participations participation
      join public.child_contexts child_context on child_context.id = participation.child_context_id
      join public.guardian_links guardian
        on guardian.child_person_id = child_context.child_person_id
       and guardian.guardian_person_id = new.person_id
      join public.guardian_context_permissions permission
        on permission.guardian_link_id = guardian.id
       and permission.child_context_id = child_context.id
     where participation.id = new.participation_id
       and participation.institution_id = new.institution_id
       and guardian.status = 'active' and guardian.revoked_at is null
       and permission.status = 'active' and permission.can_view
       and (permission.starts_at is null or permission.starts_at <= now())
       and (permission.expires_at is null or permission.expires_at > now())
  ) then
      raise check_violation using message = 'form participation responder tenant mismatch';
    end if;
    return new;
  end if;
  if tg_table_name = 'form_assets' then
    if not exists(
    select 1
      from public.form_occurrences occurrence
      join public.form_items item on item.id = new.item_id
     where occurrence.id = new.occurrence_id
       and occurrence.institution_id = new.institution_id
       and item.form_version_id = occurrence.form_version_id
  ) then
      raise check_violation using message = 'form asset tenant or version mismatch';
    end if;
    return new;
  end if;
  if tg_table_name = 'form_file_jobs' then
    if not exists(
    select 1 from public.forms form_row
     where form_row.id = new.form_id and form_row.institution_id = new.institution_id
       and (new.occurrence_id is null or exists(
         select 1 from public.form_occurrences occurrence
          where occurrence.id = new.occurrence_id
            and occurrence.form_id = new.form_id
            and occurrence.institution_id = new.institution_id
       ))
  ) then
      raise check_violation using message = 'form file job tenant mismatch';
    end if;
    return new;
  end if;
  return new;
end;
$function$;

-- Keep each trigger shape in its own PL/pgSQL statement. Referencing NEW fields
-- from another table is unsafe even behind an AND/ELSIF condition because SQL
-- expression evaluation does not guarantee short-circuiting.
CREATE OR REPLACE FUNCTION app_private.validate_form_distribution_cardinality()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if tg_table_name = 'form_audience_rules' then
    if (
      select count(*) from public.form_audience_rules rule
       where rule.application_id = new.application_id and rule.id <> new.id
    ) >= 50 then
      raise check_violation using message = 'maximum 50 form audience rules';
    end if;
    return new;
  end if;

  if tg_table_name = 'form_schedules' then
    if new.status = 'active' and (
      select count(*) from public.form_schedules schedule
       where schedule.application_id = new.application_id
         and schedule.status = 'active' and schedule.id <> new.id
    ) >= 20 then
      raise check_violation using message = 'maximum 20 active form schedules per application';
    end if;
    return new;
  end if;

  if tg_table_name = 'form_schedule_reminders' then
    if (
      select count(*) from public.form_schedule_reminders reminder
       where reminder.schedule_id = new.schedule_id and reminder.id <> new.id
    ) >= 3 then
      raise check_violation using message = 'maximum 3 form schedule reminders';
    end if;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION app_private.form_replace_response_answers(p_response form_responses, p_answers jsonb, p_edit_secret text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
<<vars>>
declare answer_json jsonb;
declare option_id_text text;
declare asset_id_text text;
declare answer_id uuid;
declare item_row public.form_items;
declare answer_kind text;
declare answer_count integer;
declare configured_min numeric;
declare configured_max numeric;
declare configured_date_min date;
declare configured_date_max date;
begin
  if jsonb_typeof(p_answers) <> 'array' or jsonb_array_length(p_answers) > 200 then
    raise invalid_parameter_value using message = 'answers must be an array with at most 200 items';
  end if;
  delete from public.form_answers where response_id = p_response.id;
  for answer_json in select value from jsonb_array_elements(p_answers) loop
    perform app_private.form_assert_payload_keys(
      answer_json,
      array[
        'item_id','kind','text_value','integer_value','decimal_value','money_minor_units',
        'date_value','yes_no_value','scale_value','option_ids','asset_ids'
      ],
      'form answer'
    );
    select * into item_row
      from public.form_items
     where id = (answer_json ->> 'item_id')::uuid
       and form_version_id = p_response.form_version_id;
    if item_row.id is null or item_row.kind = 'information' then
      raise invalid_parameter_value using message = 'answer item unavailable';
    end if;
    answer_kind := answer_json ->> 'kind';
    if answer_kind <> item_row.kind then
      raise invalid_parameter_value using message = 'answer kind mismatch';
    end if;
    if answer_kind = 'short_text'
       and char_length(coalesce(answer_json ->> 'text_value', ''))
           > coalesce((item_row.config_jsonb ->> 'max_length')::integer, 1000) then
      raise check_violation using message = 'short text answer exceeds maximum length';
    elsif answer_kind in ('integer', 'decimal', 'money') then
      configured_min := (item_row.config_jsonb ->> 'min_value')::numeric;
      configured_max := (item_row.config_jsonb ->> 'max_value')::numeric;
      if (answer_kind = 'integer' and (
            (answer_json ->> 'integer_value')::numeric < coalesce(configured_min, '-Infinity'::numeric)
            or (answer_json ->> 'integer_value')::numeric > coalesce(configured_max, 'Infinity'::numeric)
          )) or (answer_kind = 'decimal' and (
            (answer_json ->> 'decimal_value')::numeric < coalesce(configured_min, '-Infinity'::numeric)
            or (answer_json ->> 'decimal_value')::numeric > coalesce(configured_max, 'Infinity'::numeric)
          )) or (answer_kind = 'money' and (
            (answer_json ->> 'money_minor_units')::numeric < coalesce(configured_min, '-Infinity'::numeric)
            or (answer_json ->> 'money_minor_units')::numeric > coalesce(configured_max, 'Infinity'::numeric)
          )) then
        raise check_violation using message = 'numeric form answer is out of range';
      end if;
    elsif answer_kind = 'date' then
      configured_date_min := (item_row.config_jsonb ->> 'min_value')::date;
      configured_date_max := (item_row.config_jsonb ->> 'max_value')::date;
      if (answer_json ->> 'date_value')::date < coalesce(configured_date_min, '-infinity'::date)
         or (answer_json ->> 'date_value')::date > coalesce(configured_date_max, 'infinity'::date) then
        raise check_violation using message = 'date form answer is out of range';
      end if;
    elsif answer_kind = 'scale' and (
      (answer_json ->> 'scale_value')::integer < coalesce((item_row.config_jsonb ->> 'scale_min')::integer, 1)
      or (answer_json ->> 'scale_value')::integer > coalesce((item_row.config_jsonb ->> 'scale_max')::integer, 10)
    ) then
      raise check_violation using message = 'scale form answer is out of range';
    end if;
    insert into public.form_answers(
      response_id, form_version_id, item_id, answer_kind, text_value, integer_value,
      decimal_value, money_minor_units, date_value, yes_no_value, scale_value
    ) values (
      p_response.id, p_response.form_version_id, item_row.id, answer_kind,
      answer_json ->> 'text_value', (answer_json ->> 'integer_value')::bigint,
      (answer_json ->> 'decimal_value')::numeric, (answer_json ->> 'money_minor_units')::bigint,
      (answer_json ->> 'date_value')::date, (answer_json ->> 'yes_no_value')::boolean,
      (answer_json ->> 'scale_value')::integer
    ) returning id into answer_id;

    if answer_kind in ('single_choice', 'multiple_choice') then
      if jsonb_typeof(coalesce(answer_json -> 'option_ids', '[]'::jsonb)) <> 'array'
         or exists(
           select 1 from jsonb_array_elements(answer_json -> 'option_ids') option_id
            where jsonb_typeof(option_id) <> 'string'
         ) then
        raise invalid_parameter_value using message = 'invalid answer options';
      end if;
      answer_count := jsonb_array_length(coalesce(answer_json -> 'option_ids', '[]'::jsonb));
      if answer_count <> (select count(distinct option_id)
                            from jsonb_array_elements_text(answer_json -> 'option_ids') option_id) then
        raise invalid_parameter_value using message = 'form answer option ids must be unique';
      end if;
      if (answer_kind = 'single_choice' and answer_count <> 1)
         or (answer_kind = 'multiple_choice' and answer_count not between
           coalesce((item_row.config_jsonb ->> 'min_selections')::integer, 1)
           and coalesce((item_row.config_jsonb ->> 'max_selections')::integer, 50)) then
        raise check_violation using message = 'multiple choice selection count is out of range';
      end if;
      for option_id_text in select value #>> '{}' from jsonb_array_elements(answer_json -> 'option_ids') loop
        if not exists(
          select 1 from public.form_question_options
          where id = option_id_text::uuid and item_id = item_row.id
        ) then
          raise invalid_parameter_value using message = 'answer option unavailable';
        end if;
        insert into public.form_answer_options(answer_id, option_id, position)
        values (
          answer_id,
          option_id_text::uuid,
          (select count(*) from public.form_answer_options where form_answer_options.answer_id = vars.answer_id)
        );
      end loop;
    elsif answer_kind in ('photo', 'gallery') then
      if jsonb_typeof(coalesce(answer_json -> 'asset_ids', '[]'::jsonb)) <> 'array'
         or exists(
           select 1 from jsonb_array_elements(answer_json -> 'asset_ids') asset_id
            where jsonb_typeof(asset_id) <> 'string'
         ) then
        raise invalid_parameter_value using message = 'invalid answer assets';
      end if;
      answer_count := jsonb_array_length(coalesce(answer_json -> 'asset_ids', '[]'::jsonb));
      if (answer_kind = 'photo' and answer_count <> 1)
         or (answer_kind = 'gallery' and answer_count not between
           coalesce((item_row.config_jsonb ->> 'min_images')::integer, 1)
           and coalesce((item_row.config_jsonb ->> 'max_images')::integer, 5)) then
        raise check_violation using message = 'form answer asset count is out of range';
      end if;
      for asset_id_text in select value #>> '{}' from jsonb_array_elements(answer_json -> 'asset_ids') loop
        if not exists(
          select 1 from public.form_assets asset
          where asset.id = asset_id_text::uuid and asset.item_id = item_row.id
            and asset.occurrence_id = p_response.occurrence_id and asset.state = 'finalized'
            and (
              (p_response.identity_mode = 'identified'
                and asset.prepared_by_person_id = p_response.respondent_person_id)
              or (p_response.identity_mode = 'anonymous'
                and asset.prepared_by_person_id is null
                and app_private.form_verify_anonymous_edit_secret(
                  p_edit_secret, asset.anonymous_upload_secret_hash
                ))
            )
        ) then
          raise invalid_parameter_value using message = 'answer asset unavailable';
        end if;
        insert into public.form_answer_assets(answer_id, asset_id, position)
        values (
          answer_id,
          asset_id_text::uuid,
          (select count(*) from public.form_answer_assets where form_answer_assets.answer_id = vars.answer_id)
        );
      end loop;
    end if;
  end loop;

  if exists (
    select 1
      from public.form_answers target_answer
     where target_answer.response_id = p_response.id
       and exists (
         select 1 from public.form_question_conditions condition_row
         where condition_row.target_item_id = target_answer.item_id
       )
       and not exists (
         select 1
           from public.form_question_conditions condition_row
           join public.form_answers source_answer
             on source_answer.response_id = p_response.id
            and source_answer.item_id = condition_row.source_item_id
          where condition_row.target_item_id = target_answer.item_id
            and (
              (condition_row.condition_kind = 'yes_no'
               and source_answer.yes_no_value = condition_row.expected_yes_no)
              or (condition_row.condition_kind = 'choice' and exists(
                select 1 from public.form_answer_options selected_option
                where selected_option.answer_id = source_answer.id
                  and selected_option.option_id = condition_row.source_option_id
              ))
            )
       )
  ) then
    raise check_violation using message = 'hidden form answers are not accepted';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION app_private.form_mutate_response(p_command text, p_request_id uuid, p_expected_version bigint, p_payload jsonb, p_submit boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid := app_private.require_forms_actor('forms.respond');
declare response_row public.form_responses;
declare occurrence_row public.form_occurrences;
declare participation_row public.form_participations;
declare replay jsonb;
declare revision_number integer;
declare result jsonb;
declare expected_action text;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['response_id','participation_id','edit_secret','answers'], 'form response mutation'
  );
  select * into response_row from public.form_responses
   where id = (p_payload ->> 'response_id')::uuid for update;
  if response_row.id is null then raise no_data_found using message = 'form response unavailable'; end if;
  perform app_private.form_assert_response_actor(response_row, actor, p_payload ->> 'edit_secret');
  if response_row.identity_mode = 'identified' then
    replay := app_private.form_begin_command(
      p_request_id, actor, p_command, p_expected_version, p_payload
    );
    if replay is not null then return replay; end if;
  else
    expected_action := case when p_submit then 'submitted'
      when p_command = 'form_edit_response' then 'edited' else 'draft_saved' end;
    if response_row.management_version = p_expected_version + 1
       and exists (
         select 1 from public.form_response_revisions revision
          where revision.response_id = response_row.id
            and revision.action = expected_action
            and revision.answers_snapshot = p_payload -> 'answers'
       ) then
      return app_private.form_response_draft_projection(response_row.id);
    end if;
  end if;
  if response_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  select * into occurrence_row from public.form_occurrences
   where id = response_row.occurrence_id for update;
  if occurrence_row.status <> 'open' or now() not between occurrence_row.opens_at and occurrence_row.closes_at then
    raise no_data_found using message = 'form occurrence unavailable';
  end if;
  select participation.* into participation_row
    from public.form_participations participation
   where participation.id = (p_payload ->> 'participation_id')::uuid
     and participation.occurrence_id = response_row.occurrence_id
     and participation.eligibility_state = 'eligible'
     and (
       participation.person_id = actor
       or exists(select 1 from public.form_participation_responders responder
                 where responder.participation_id = participation.id and responder.person_id = actor)
     )
   for update;
  if participation_row.id is null then
    raise no_data_found using message = 'form participation unavailable';
  end if;
  if p_submit and response_row.status <> 'draft' then
    raise check_violation using message = 'only a draft response can be submitted';
  end if;
  if p_command = 'form_edit_response' and response_row.status <> 'submitted' then
    raise check_violation using message = 'only a submitted response can be edited';
  end if;
  if p_command = 'form_save_response_draft' and response_row.status <> 'draft' then
    raise check_violation using message = 'only a draft response can be saved';
  end if;
  perform app_private.form_replace_response_answers(
    response_row, p_payload -> 'answers', p_payload ->> 'edit_secret'
  );
  if p_submit then
    perform app_private.form_assert_required_response_answers(response_row);
    if participation_row.response_state = 'responded' then
      raise no_data_found using message = 'form participation unavailable';
    end if;
    update public.form_responses
       set status = 'submitted', submitted_at = now(), updated_at = now(),
           management_version = management_version + 1
     where id = response_row.id returning * into response_row;
    update public.form_participations
       set response_state = 'responded', responded_at = now()
     where id = participation_row.id;
    perform app_private.form_rebuild_occurrence_metrics(response_row.occurrence_id);
  else
    update public.form_responses
       set updated_at = now(), management_version = management_version + 1
     where id = response_row.id returning * into response_row;
  end if;
  select coalesce(max(revision_row.revision_number), 0) + 1 into revision_number
    from public.form_response_revisions revision_row where revision_row.response_id = response_row.id;
  insert into public.form_response_revisions(
    response_id, revision_number, action, answers_snapshot, changed_by_person_id
  ) values (
    response_row.id, revision_number,
    case when p_submit then 'submitted'
         when p_command = 'form_edit_response' then 'edited'
         else 'draft_saved' end,
    p_payload -> 'answers', case when response_row.identity_mode = 'identified' then actor else null end
  );
  result := app_private.form_response_draft_projection(response_row.id);
  if response_row.identity_mode = 'anonymous' then return result; end if;
  return app_private.form_complete_command(p_request_id, result);
end;
$function$;

CREATE OR REPLACE FUNCTION app_private.form_list_monitor_hierarchy(p_query jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid := app_private.require_forms_actor('forms.monitor');
declare form_row public.forms;
declare requested_scope_kind text;
declare wanted_scope_kind text;
declare page_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 25), 1), 100);
declare cursor_label text := p_query ->> 'cursor_label';
declare cursor_id uuid := (p_query ->> 'cursor_id')::uuid;
begin
  perform app_private.form_assert_payload_keys(
    p_query, array['form_id','application_id','occurrence_id','starts_on_or_after','ends_on_or_before',
                    'scope_id','cursor_label','cursor_id','limit'],
    'form monitor hierarchy query'
  );
  select * into form_row from public.forms where id = (p_query ->> 'form_id')::uuid;
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;

  if p_query ->> 'scope_id' is not null then
    select metric.scope_kind into requested_scope_kind
      from public.form_scope_metrics metric
      join public.form_occurrences occurrence on occurrence.id = metric.occurrence_id
     where occurrence.form_id = form_row.id and metric.scope_id = (p_query ->> 'scope_id')::uuid
     limit 1;
    if requested_scope_kind is null then
      raise no_data_found using message = 'monitor scope unavailable';
    end if;
  end if;
  wanted_scope_kind := case
    when requested_scope_kind is null then 'institution'
    when requested_scope_kind = 'institution' then 'unit'
    when requested_scope_kind = 'unit' then 'group'
    when requested_scope_kind = 'group' then 'activity'
    when requested_scope_kind = 'activity' then 'profile'
    else null
  end;
  if wanted_scope_kind is null then
    return jsonb_build_object('items', '[]'::jsonb, 'has_more', false, 'next_cursor', null);
  end if;

  return (
    with scopes as (
      select metric.scope_id, metric.scope_kind,
             case metric.scope_kind
               when 'institution' then (select coalesce(institution.trade_name, institution.legal_name, '') from public.institutions institution where institution.id = metric.scope_id)
               when 'unit' then (select unit.name from public.units unit where unit.id = metric.scope_id and unit.institution_id = form_row.institution_id)
               when 'group' then (select group_row.name from public.groups group_row where group_row.id = metric.scope_id and group_row.institution_id = form_row.institution_id)
               when 'activity' then (select activity.name from public.activity_definitions activity where activity.id = metric.scope_id and activity.institution_id = form_row.institution_id)
               when 'profile' then (select role_row.name from public.institution_roles role_row where role_row.id = metric.scope_id and role_row.institution_id = form_row.institution_id)
             end as label,
             sum(metric.eligible_count)::bigint as eligible_count,
             sum(metric.responded_count)::bigint as responded_count,
             sum(metric.pending_count)::bigint as pending_count
        from public.form_scope_metrics metric
        join public.form_occurrences occurrence on occurrence.id = metric.occurrence_id
       where occurrence.form_id = form_row.id and metric.institution_id = form_row.institution_id
         and metric.scope_kind = wanted_scope_kind
         and (
           requested_scope_kind is null
           or requested_scope_kind = 'institution'
           or (requested_scope_kind = 'unit' and exists(
             select 1 from public.groups group_row
              where group_row.id = metric.scope_id
                and group_row.unit_id = (p_query ->> 'scope_id')::uuid
                and group_row.institution_id = form_row.institution_id
           ))
           or (requested_scope_kind = 'group' and exists(
             select 1 from public.activity_group_links activity_link
              where activity_link.activity_id = metric.scope_id
                and activity_link.group_id = (p_query ->> 'scope_id')::uuid
                and activity_link.institution_id = form_row.institution_id
                and activity_link.status = 'active'
           ))
           or requested_scope_kind = 'activity'
         )
         and ((p_query ->> 'application_id') is null or occurrence.application_id = (p_query ->> 'application_id')::uuid)
         and ((p_query ->> 'occurrence_id') is null or occurrence.id = (p_query ->> 'occurrence_id')::uuid)
         and ((p_query ->> 'starts_on_or_after') is null or occurrence.opens_at::date >= (p_query ->> 'starts_on_or_after')::date)
         and ((p_query ->> 'ends_on_or_before') is null or occurrence.closes_at::date <= (p_query ->> 'ends_on_or_before')::date)
       group by metric.scope_id, metric.scope_kind
    ), page as (
      select * from scopes
       where label is not null
         and (cursor_label is null or (lower(label), scope_id) > (lower(cursor_label), cursor_id))
       order by lower(label), scope_id limit page_limit + 1
    ), visible as (select * from page limit page_limit)
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'scope_id', scope_id, 'scope_kind', scope_kind, 'label', label,
        'eligible_count', eligible_count, 'responded_count', responded_count, 'pending_count', pending_count
      ) order by lower(label), scope_id), '[]'::jsonb),
      'has_more', (select count(*) > page_limit from page),
      'next_cursor', (select jsonb_build_object('label', label, 'id', scope_id)
                        from visible order by lower(label) desc, scope_id desc limit 1)
    ) from visible
  );
end;
$function$;

CREATE OR REPLACE FUNCTION app_private.form_save_application(p_request_id uuid, p_expected_version bigint, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid := app_private.require_forms_actor('forms.manage_applications');
declare application_row public.form_applications;
declare rule_json jsonb;
declare replay jsonb;
declare application_id uuid := coalesce((p_payload ->> 'id')::uuid, gen_random_uuid());
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['id','form_id','institution_id','name','status','opens_for_days','rules'],
    'form application'
  );
  perform app_private.form_assert_application_payload_limits(p_payload);
  replay := app_private.form_begin_command(p_request_id, actor, 'form_save_application', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  perform pg_advisory_xact_lock(hashtextextended(application_id::text, 11));
  select * into application_row from public.form_applications where id = application_id for update;
  if application_row.id is null then
    if p_expected_version <> 0 then raise serialization_failure using message = 'expected_version mismatch'; end if;
    insert into public.form_applications(
      id, form_id, institution_id, name, status, opens_for_days, created_by_person_id
    ) values (
      application_id, (p_payload ->> 'form_id')::uuid, (p_payload ->> 'institution_id')::uuid,
      btrim(p_payload ->> 'name'), coalesce(p_payload ->> 'status', 'active'),
      coalesce((p_payload ->> 'opens_for_days')::integer, 7), actor
    ) returning * into application_row;
  else
    if application_row.management_version <> p_expected_version then
      raise serialization_failure using message = 'expected_version mismatch';
    end if;
    update public.form_applications set name = btrim(p_payload ->> 'name'),
      status = coalesce(p_payload ->> 'status', status),
      opens_for_days = coalesce((p_payload ->> 'opens_for_days')::integer, opens_for_days),
      management_version = management_version + 1, updated_at = now()
    where id = application_id returning * into application_row;
  end if;
  delete from public.form_audience_rules audience_rule where audience_rule.application_id = application_row.id;
  for rule_json in select value from jsonb_array_elements(p_payload -> 'rules') loop
    perform app_private.form_assert_payload_keys(
      rule_json, array['kind','mode','target_id','filter','position'], 'form audience rule'
    );
    insert into public.form_audience_rules(
      application_id, institution_id, rule_kind, rule_mode, target_id, filter_jsonb, position
    ) values (
      application_row.id, application_row.institution_id, rule_json ->> 'kind', rule_json ->> 'mode',
      (rule_json ->> 'target_id')::uuid, coalesce(rule_json -> 'filter', '{}'::jsonb),
      (rule_json ->> 'position')::integer
    );
  end loop;
  return app_private.form_complete_command(
    p_request_id, app_private.form_application_projection(application_row.id)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION app_private.form_authorize_file_job_download(p_file_job_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid := app_private.current_person_id();
declare job_row public.form_file_jobs;
declare raw_token uuid := gen_random_uuid();
declare token_expires_at timestamptz;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  select job.* into job_row
    from public.form_file_jobs job
    join public.forms form_row
      on form_row.id = job.form_id
     and form_row.institution_id = job.institution_id
    join public.institutions institution_row on institution_row.id = job.institution_id
   where job.id = p_file_job_id
     and job.requested_by_person_id = actor
     and job.state in ('succeeded','partial')
     and job.expires_at > now()
     and job.artifact_path is not null
   for update of job;
  if job_row.id is null then return null; end if;
  if not app_private.form_actor_has_export_permission(actor, job_row.export_kind) then
    if job_row.export_kind = 'anonymous_participation' then
      raise insufficient_privilege using
        message = 'Owner role and forms.anonymous_participation.export required';
    end if;
    raise insufficient_privilege using message = 'forms.responses.export required';
  end if;

  token_expires_at := least(job_row.expires_at, now() + interval '2 minutes');
  delete from app_private.form_file_download_tokens token_row
   where token_row.file_job_id = job_row.id
     and token_row.actor_person_id = actor
     and token_row.consumed_at is null;
  insert into app_private.form_file_download_tokens(
    file_job_id, actor_person_id, token_hash, expires_at
  ) values (
    job_row.id, actor, encode(extensions.digest(pg_catalog.convert_to(raw_token::text,'UTF8'),'sha256'),'hex'), token_expires_at
  );
  return jsonb_build_object('download_token', raw_token, 'expires_at', token_expires_at);
end;
$function$;

CREATE OR REPLACE FUNCTION app_private.form_redeem_file_job_download(p_download_token uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
  with consumed as (
    update app_private.form_file_download_tokens token_row
       set consumed_at = now()
     where token_row.token_hash = encode(extensions.digest(pg_catalog.convert_to(p_download_token::text,'UTF8'),'sha256'),'hex')
       and token_row.consumed_at is null
       and token_row.expires_at > now()
     returning token_row.file_job_id, token_row.actor_person_id
  )
  select jsonb_build_object(
    'job_id', job.id,
    'storage_path', job.artifact_path,
    'export_kind', job.export_kind,
    'expires_at', job.expires_at
  )
    into result
    from consumed
    join public.form_file_jobs job
      on job.id = consumed.file_job_id
     and job.requested_by_person_id = consumed.actor_person_id
    join public.forms form_row
      on form_row.id = job.form_id
     and form_row.institution_id = job.institution_id
   where job.state in ('succeeded','partial')
     and job.expires_at > now()
     and job.artifact_path is not null
     and app_private.form_actor_has_export_permission(
       consumed.actor_person_id, job.export_kind
     );
  return result;
end;
$function$;
