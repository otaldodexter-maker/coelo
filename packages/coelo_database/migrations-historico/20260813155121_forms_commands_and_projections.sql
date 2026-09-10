create table app_private.form_command_receipts (
  request_id uuid primary key,
  actor_person_id uuid not null references public.people(id) on delete restrict,
  command_name text not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  expected_version bigint not null,
  result_jsonb jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

revoke all on table app_private.form_command_receipts from public, anon, authenticated;

create or replace function app_private.form_escape_like(p_value text)
returns text
language sql
immutable
security definer
set search_path = ''
as $$
  select replace(replace(replace(p_value, '\', '\\'), '%', '\%'), '_', '\_');
$$;

create or replace function app_private.require_forms_actor(p_capability text)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid;
begin
  actor := app_private.current_person_id();
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  if not app_private.has_platform_permission(p_capability) then
    raise insufficient_privilege using message = p_capability || ' required';
  end if;
  return actor;
end;
$$;

create or replace function app_private.form_assert_payload_keys(
  p_payload jsonb,
  p_allowed text[],
  p_context text
)
returns void
language plpgsql
immutable
security definer
set search_path = ''
as $$
declare unknown_keys text[];
begin
  if jsonb_typeof(p_payload) <> 'object' then
    raise invalid_parameter_value using message = p_context || ' must be an object';
  end if;
  select array_agg(key order by key) into unknown_keys
    from jsonb_object_keys(p_payload) key
   where not key = any(p_allowed);
  if unknown_keys is not null then
    raise invalid_parameter_value using message = p_context || ' contains unknown keys';
  end if;
end;
$$;

create or replace function app_private.form_begin_command(
  p_request_id uuid,
  p_actor uuid,
  p_command text,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  receipt app_private.form_command_receipts;
  request_hash bytea := extensions.digest(
    pg_catalog.convert_to(p_command || ':' || p_expected_version::text || ':' || p_payload::text, 'UTF8'),
    'sha256'
  );
begin
  if p_request_id is null or p_expected_version < 0 then
    raise invalid_parameter_value using message = 'request_id and non-negative expected_version required';
  end if;
  select * into receipt
    from app_private.form_command_receipts
   where request_id = p_request_id
   for update;
  if receipt.request_id is not null then
    if receipt.actor_person_id <> p_actor
       or receipt.command_name <> p_command
       or receipt.request_hash <> request_hash
       or receipt.expected_version <> p_expected_version then
      raise unique_violation using message = 'form command replay mismatch';
    end if;
    if receipt.completed_at is null then
      raise serialization_failure using message = 'form command is already in progress';
    end if;
    return receipt.result_jsonb;
  end if;
  insert into app_private.form_command_receipts(
    request_id, actor_person_id, command_name, request_hash, expected_version
  ) values (p_request_id, p_actor, p_command, request_hash, p_expected_version);
  return null;
end;
$$;

create or replace function app_private.form_complete_command(p_request_id uuid, p_result jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  update app_private.form_command_receipts
     set result_jsonb = p_result, completed_at = now()
   where request_id = p_request_id and completed_at is null;
  if not found then
    raise serialization_failure using message = 'form command receipt unavailable';
  end if;
  return p_result;
end;
$$;

create or replace function app_private.form_definition_projection(p_form_id uuid, p_version_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', form_row.id,
    'institution_id', form_row.institution_id,
    'kind', form_row.kind,
    'identity_mode', form_row.identity_mode,
    'response_unit', form_row.response_unit,
    'title', form_row.title,
    'description', form_row.description,
    'status', form_row.status,
    'management_version', form_row.management_version,
    'sections', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', section_row.id,
        'title', section_row.title,
        'description', section_row.description,
        'position', section_row.position,
        'items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', item_row.id,
            'kind', item_row.kind,
            'label', item_row.label,
            'help_text', item_row.help_text,
            'position', item_row.position,
            'is_required', item_row.is_required,
            'config', item_row.config_jsonb,
            'options', coalesce((
              select jsonb_agg(jsonb_build_object(
                'id', option_row.id, 'label', option_row.label, 'position', option_row.position
              ) order by option_row.position, option_row.id)
              from public.form_question_options option_row
              where option_row.item_id = item_row.id
            ), '[]'::jsonb),
            'conditions', coalesce((
              select jsonb_agg(jsonb_build_object(
                'source_item_id', grouped.source_item_id,
                'kind', grouped.condition_kind,
                'expected_yes_no', grouped.expected_yes_no,
                'option_ids', grouped.option_ids
              ) order by grouped.source_item_id, grouped.condition_kind)
              from (
                select condition_row.source_item_id,
                       condition_row.condition_kind,
                       condition_row.expected_yes_no,
                       coalesce(jsonb_agg(condition_row.source_option_id)
                         filter (where condition_row.source_option_id is not null), '[]'::jsonb) as option_ids
                  from public.form_question_conditions condition_row
                 where condition_row.target_item_id = item_row.id
                 group by condition_row.source_item_id, condition_row.condition_kind,
                          condition_row.expected_yes_no
              ) grouped
            ), '[]'::jsonb)
          ) order by item_row.position, item_row.id)
          from public.form_items item_row
          where item_row.section_id = section_row.id
        ), '[]'::jsonb)
      ) order by section_row.position, section_row.id)
      from public.form_sections section_row
      where section_row.form_version_id = coalesce(
        p_version_id, form_row.working_version_id, form_row.published_version_id
      )
    ), '[]'::jsonb)
  )
  from public.forms form_row
  where form_row.id = p_form_id;
$$;

create or replace function app_private.form_definition_projection(p_form_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$ select app_private.form_definition_projection($1, null) $$;

create or replace function app_private.form_application_projection(p_application_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', application.id,
    'form_id', application.form_id,
    'institution_id', application.institution_id,
    'name', application.name,
    'status', application.status,
    'opens_for_days', application.opens_for_days,
    'management_version', application.management_version,
    'audience_rules', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', rule.id, 'kind', rule.rule_kind, 'mode', rule.rule_mode, 'target_id', rule.target_id
      ) order by rule.position, rule.id)
        from public.form_audience_rules rule where rule.application_id = application.id
    ), '[]'::jsonb),
    'schedules', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', schedule.id,
        'status', schedule.status,
        'management_version', schedule.management_version,
        'starts_at_local', schedule.starts_at_local,
        'time_zone', schedule.time_zone,
        'recurrence', jsonb_build_object(
          'kind', schedule.recurrence_kind,
          'interval', schedule.interval_value,
          'weekdays', to_jsonb(schedule.weekdays),
          'day', schedule.monthly_day,
          'use_last_day', schedule.monthly_last_day
        ),
        'end', jsonb_build_object(
          'kind', schedule.end_kind,
          'date', schedule.ends_on,
          'count', schedule.occurrence_count
        ),
        'reminders', coalesce((
          select jsonb_agg(jsonb_build_object('kind', reminder.reminder_kind, 'amount', reminder.amount)
                           order by reminder.position, reminder.id)
            from public.form_schedule_reminders reminder where reminder.schedule_id = schedule.id
        ), '[]'::jsonb)
      ) order by schedule.starts_at_local, schedule.id)
        from public.form_schedules schedule
       where schedule.application_id = application.id
         and schedule.status = 'active'
    ), '[]'::jsonb)
  )
    from public.form_applications application
   where application.id = p_application_id;
$$;

create or replace function app_private.form_replace_working_definition(
  p_version_id uuid,
  p_sections jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  section_json jsonb;
  item_json jsonb;
  option_json jsonb;
  condition_json jsonb;
  source_section_id text;
  source_item_id text;
  source_option_id text;
  section_ids jsonb := '{}'::jsonb;
  item_ids jsonb := '{}'::jsonb;
  option_ids jsonb := '{}'::jsonb;
begin
  if jsonb_typeof(p_sections) <> 'array' then
    raise invalid_parameter_value using message = 'sections must be an array';
  end if;
  if jsonb_array_length(p_sections) > 20 then
    raise check_violation using message = 'maximum 20 form sections';
  end if;

  delete from public.form_sections where form_version_id = p_version_id;

  for section_json in select value from jsonb_array_elements(p_sections) loop
    perform app_private.form_assert_payload_keys(
      section_json,
      array['id','title','description','position','items'],
      'form section'
    );
    source_section_id := nullif(section_json ->> 'id', '');
    if source_section_id is null or section_ids ? source_section_id then
      raise invalid_parameter_value using message = 'unique section id required';
    end if;
    section_ids := section_ids || jsonb_build_object(source_section_id, gen_random_uuid()::text);
    if jsonb_typeof(section_json -> 'items') <> 'array' then
      raise invalid_parameter_value using message = 'section items must be an array';
    end if;
    for item_json in select value from jsonb_array_elements(section_json -> 'items') loop
      perform app_private.form_assert_payload_keys(
        item_json,
        array['id','kind','label','help_text','position','is_required','config','options','conditions'],
        'form item'
      );
      source_item_id := nullif(item_json ->> 'id', '');
      if source_item_id is null or item_ids ? source_item_id then
        raise invalid_parameter_value using message = 'unique item id required';
      end if;
      item_ids := item_ids || jsonb_build_object(source_item_id, gen_random_uuid()::text);
      if jsonb_typeof(coalesce(item_json -> 'options', '[]'::jsonb)) <> 'array'
         or jsonb_typeof(coalesce(item_json -> 'conditions', '[]'::jsonb)) <> 'array' then
        raise invalid_parameter_value using message = 'item options and conditions must be arrays';
      end if;
      if jsonb_array_length(coalesce(item_json -> 'options', '[]'::jsonb)) > 50 then
        raise check_violation using message = 'maximum 50 form options per item';
      end if;
      for option_json in select value from jsonb_array_elements(coalesce(item_json -> 'options', '[]'::jsonb)) loop
        perform app_private.form_assert_payload_keys(
          option_json, array['id','label','position'], 'form option'
        );
        source_option_id := nullif(option_json ->> 'id', '');
        if source_option_id is null or option_ids ? source_option_id then
          raise invalid_parameter_value using message = 'unique option id required';
        end if;
        option_ids := option_ids || jsonb_build_object(source_option_id, gen_random_uuid()::text);
      end loop;
    end loop;
  end loop;

  if (select count(*) from jsonb_object_keys(item_ids)) > 200 then
    raise check_violation using message = 'maximum 200 form items';
  end if;

  for section_json in select value from jsonb_array_elements(p_sections) loop
    source_section_id := section_json ->> 'id';
    insert into public.form_sections(id, form_version_id, title, description, position)
    values (
      (section_ids ->> source_section_id)::uuid,
      p_version_id,
      btrim(section_json ->> 'title'),
      nullif(btrim(section_json ->> 'description'), ''),
      (section_json ->> 'position')::integer
    );
    for item_json in select value from jsonb_array_elements(section_json -> 'items') loop
      source_item_id := item_json ->> 'id';
      insert into public.form_items(
        id, form_version_id, section_id, kind, label, help_text, is_required, position, config_jsonb
      ) values (
        (item_ids ->> source_item_id)::uuid,
        p_version_id,
        (section_ids ->> source_section_id)::uuid,
        item_json ->> 'kind',
        btrim(item_json ->> 'label'),
        nullif(btrim(item_json ->> 'help_text'), ''),
        coalesce((item_json ->> 'is_required')::boolean, false),
        (item_json ->> 'position')::integer,
        coalesce(item_json -> 'config', '{}'::jsonb)
      );
      for option_json in select value from jsonb_array_elements(coalesce(item_json -> 'options', '[]'::jsonb)) loop
        source_option_id := option_json ->> 'id';
        insert into public.form_question_options(id, form_version_id, item_id, label, position)
        values (
          (option_ids ->> source_option_id)::uuid,
          p_version_id,
          (item_ids ->> source_item_id)::uuid,
          btrim(option_json ->> 'label'),
          (option_json ->> 'position')::integer
        );
      end loop;
    end loop;
  end loop;

  for section_json in select value from jsonb_array_elements(p_sections) loop
    for item_json in select value from jsonb_array_elements(section_json -> 'items') loop
      source_item_id := item_json ->> 'id';
      for condition_json in select value from jsonb_array_elements(coalesce(item_json -> 'conditions', '[]'::jsonb)) loop
        perform app_private.form_assert_payload_keys(
          condition_json,
          array['source_item_id','kind','expected_yes_no','option_ids'],
          'form condition'
        );
        if not item_ids ? (condition_json ->> 'source_item_id') then
          raise invalid_parameter_value using message = 'condition source item not found';
        end if;
        for source_option_id in
          select value
            from jsonb_array_elements_text(
              case when condition_json ->> 'kind' = 'choice'
                then condition_json -> 'option_ids' else '[null]'::jsonb end
            )
        loop
          if condition_json ->> 'kind' = 'choice' and not option_ids ? source_option_id then
            raise invalid_parameter_value using message = 'condition source option not found';
          end if;
          insert into public.form_question_conditions(
            form_version_id, target_item_id, source_item_id, condition_kind,
            expected_yes_no, source_option_id
          ) values (
            p_version_id,
            (item_ids ->> source_item_id)::uuid,
            (item_ids ->> (condition_json ->> 'source_item_id'))::uuid,
            condition_json ->> 'kind',
            (condition_json ->> 'expected_yes_no')::boolean,
            case when source_option_id is null then null
                 else (option_ids ->> source_option_id)::uuid end
          );
        end loop;
      end loop;
    end loop;
  end loop;
  perform app_private.validate_form_definition(p_version_id);
end;
$$;

create or replace function app_private.form_save_draft(
  p_request_id uuid,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.require_forms_actor('forms.manage');
  target_form_id uuid := coalesce((p_payload ->> 'id')::uuid, gen_random_uuid());
  form_row public.forms;
  version_id uuid;
  version_number integer;
  replay jsonb;
  result jsonb;
  before_state jsonb;
begin
  perform app_private.form_assert_payload_keys(
    p_payload,
    array['id','institution_id','kind','identity_mode','response_unit','title','description','sections'],
    'form draft'
  );
  replay := app_private.form_begin_command(
    p_request_id, actor, 'form_save_draft', p_expected_version, p_payload
  );
  if replay is not null then return replay; end if;

  perform pg_advisory_xact_lock(hashtextextended(target_form_id::text, 0));
  select * into form_row from public.forms where id = target_form_id for update;
  before_state := case when form_row.id is null then null else app_private.form_definition_projection(target_form_id) end;
  if form_row.id is null then
    if p_expected_version <> 0 then
      raise serialization_failure using message = 'expected_version mismatch';
    end if;
    insert into public.forms(
      id, institution_id, kind, identity_mode, response_unit, title, description,
      created_by_person_id, updated_by_person_id
    ) values (
      target_form_id,
      (p_payload ->> 'institution_id')::uuid,
      p_payload ->> 'kind',
      p_payload ->> 'identity_mode',
      p_payload ->> 'response_unit',
      btrim(p_payload ->> 'title'),
      nullif(btrim(p_payload ->> 'description'), ''),
      actor,
      actor
    ) returning * into form_row;
    version_number := 1;
    insert into public.form_versions(form_id, version_number, created_by_person_id)
    values (target_form_id, version_number, actor)
    returning id into version_id;
    update public.forms set working_version_id = version_id where id = target_form_id;
  else
    if form_row.management_version <> p_expected_version then
      raise serialization_failure using message = 'expected_version mismatch';
    end if;
    if form_row.institution_id <> (p_payload ->> 'institution_id')::uuid then
      raise check_violation using message = 'use form_copy_or_move for institution changes';
    end if;
    if form_row.first_published_at is not null
       and form_row.identity_mode <> p_payload ->> 'identity_mode' then
      raise check_violation using message = 'identity mode is immutable after first publication';
    end if;
    version_id := form_row.working_version_id;
    if version_id is null then
      select coalesce(max(version_number), 0) + 1 into version_number
        from public.form_versions where form_id = form_row.id;
      insert into public.form_versions(form_id, version_number, created_by_person_id)
      values (target_form_id, version_number, actor)
      returning id into version_id;
    end if;
    update public.forms
       set institution_id = (p_payload ->> 'institution_id')::uuid,
           kind = p_payload ->> 'kind',
           identity_mode = p_payload ->> 'identity_mode',
           response_unit = p_payload ->> 'response_unit',
           title = btrim(p_payload ->> 'title'),
           description = nullif(btrim(p_payload ->> 'description'), ''),
           working_version_id = version_id,
           management_version = management_version + 1,
           updated_by_person_id = actor,
           updated_at = now()
     where id = target_form_id;
  end if;

  perform app_private.form_replace_working_definition(version_id, p_payload -> 'sections');
  result := app_private.form_definition_projection(target_form_id);
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id,
    outcome, before_json, after_json
  ) values (
    actor, auth.jwt() ->> 'aal', 'forms.draft.save', 'form', target_form_id,
    (p_payload ->> 'institution_id')::uuid, 'success', before_state,
    jsonb_build_object('management_version', result -> 'management_version')
  );
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

create or replace function app_private.form_publish(
  p_request_id uuid,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.require_forms_actor('forms.publish');
  target_form_id uuid;
  form_row public.forms;
  replay jsonb;
  result jsonb;
begin
  perform app_private.form_assert_payload_keys(p_payload, array['form_id'], 'form publish');
  target_form_id := (p_payload ->> 'form_id')::uuid;
  replay := app_private.form_begin_command(
    p_request_id, actor, 'form_publish', p_expected_version, p_payload
  );
  if replay is not null then return replay; end if;
  perform pg_advisory_xact_lock(hashtextextended(target_form_id::text, 0));
  select * into form_row from public.forms where id = target_form_id for update;
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if form_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  if form_row.working_version_id is null then
    raise check_violation using message = 'working version required';
  end if;
  perform app_private.validate_form_definition(form_row.working_version_id);
  update public.form_versions
     set state = 'superseded'
   where id = form_row.published_version_id and state = 'published';
  update public.form_versions
     set state = 'published', published_at = now()
   where id = form_row.working_version_id and state = 'working';
  update public.forms
     set status = 'published',
         published_version_id = working_version_id,
         working_version_id = null,
         first_published_at = coalesce(first_published_at, now()),
         management_version = management_version + 1,
         updated_by_person_id = actor,
         updated_at = now()
   where id = target_form_id;
  update public.form_occurrences
     set form_version_id = form_row.working_version_id,
         management_version = management_version + 1
   where form_occurrences.form_id = target_form_id
     and status = 'scheduled'
     and opens_at > now();
  result := app_private.form_definition_projection(target_form_id);
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id, outcome,
    after_json
  ) values (
    actor, auth.jwt() ->> 'aal', 'forms.publish', 'form', target_form_id,
    form_row.institution_id, 'success', jsonb_build_object('published_version_id', form_row.working_version_id)
  );
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

create or replace function app_private.form_list(p_query jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.read');
declare page_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 25), 1), 100);
declare cursor_updated timestamptz;
declare cursor_id uuid;
begin
  perform app_private.form_assert_payload_keys(
    p_query,
    array['institution_id','search','statuses','operational_statuses','kinds','starts_on_or_after','ends_on_or_before','cursor_updated_at','cursor_id','limit'],
    'form directory query'
  );
  cursor_updated := (p_query ->> 'cursor_updated_at')::timestamptz;
  cursor_id := (p_query ->> 'cursor_id')::uuid;
  return (
    with operational as (
      select form_row.*,
             case
               when form_row.status = 'archived' then 'archived'
               when form_row.status = 'draft' then 'draft'
               when coalesce(occurrence_window.is_active, false) then 'active'
               when coalesce(occurrence_window.is_scheduled, false) then 'scheduled'
               else 'closed'
             end as operational_status
        from public.forms form_row
        left join lateral (
          select bool_or(
                   occurrence_row.status in ('scheduled', 'open')
                   and occurrence_row.opens_at <= now()
                   and occurrence_row.closes_at > now()
                 ) as is_active,
                 bool_or(
                   occurrence_row.status in ('scheduled', 'open')
                   and occurrence_row.opens_at > now()
                 ) as is_scheduled
            from public.form_occurrences occurrence_row
           where occurrence_row.form_id = form_row.id
        ) occurrence_window on true
       where ((p_query ->> 'institution_id') is null
              or form_row.institution_id = (p_query ->> 'institution_id')::uuid)
         and (nullif(p_query ->> 'search', '') is null
              or form_row.title ilike '%' || app_private.form_escape_like(p_query ->> 'search') || '%' escape '\')
         and (coalesce(jsonb_array_length(p_query -> 'statuses'), 0) = 0 or form_row.status in (
           select jsonb_array_elements_text(p_query -> 'statuses')
         ))
         and (coalesce(jsonb_array_length(p_query -> 'kinds'), 0) = 0 or form_row.kind in (
           select jsonb_array_elements_text(p_query -> 'kinds')
         ))
         and ((p_query ->> 'starts_on_or_after') is null or exists (
           select 1 from public.form_occurrences occurrence_row
            where occurrence_row.form_id = form_row.id
              and occurrence_row.opens_at::date >= (p_query ->> 'starts_on_or_after')::date
         ))
         and ((p_query ->> 'ends_on_or_before') is null or exists (
           select 1 from public.form_occurrences occurrence_row
            where occurrence_row.form_id = form_row.id
              and occurrence_row.closes_at::date <= (p_query ->> 'ends_on_or_before')::date
         ))
    ), page as (
      select operational.*
        from operational
       where (coalesce(jsonb_array_length(p_query -> 'operational_statuses'), 0) = 0
              or operational_status in (
                select jsonb_array_elements_text(p_query -> 'operational_statuses')
              ))
         and (cursor_updated is null or (updated_at, id) < (cursor_updated, cursor_id))
       order by updated_at desc, id desc
       limit page_limit + 1
    ), visible as (select * from page limit page_limit)
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'title', title, 'kind', kind, 'status', status,
        'operational_status', operational_status,
        'identity_mode', identity_mode, 'updated_at', updated_at,
        'management_version', management_version
      ) order by updated_at desc, id desc), '[]'::jsonb),
      'has_more', (select count(*) > page_limit from page),
      'next_cursor', (select jsonb_build_object('updated_at', updated_at, 'id', id)
                        from visible order by updated_at, id limit 1)
    ) from visible
  );
end;
$$;

create or replace function app_private.form_get_editor(p_form_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform app_private.require_forms_actor('forms.read');
  if not exists(select 1 from public.forms where id = p_form_id) then
    raise no_data_found using message = 'form unavailable';
  end if;
  return app_private.form_definition_projection(p_form_id);
end;
$$;

create or replace function app_private.form_get_overview(p_form_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare result jsonb;
begin
  perform app_private.require_forms_actor('forms.read');
  select app_private.form_definition_projection(p_form_id) || jsonb_build_object(
    'application_count', (select count(*) from public.form_applications where form_id = p_form_id),
    'occurrence_count', (select count(*) from public.form_occurrences where form_id = p_form_id),
    'response_count', (select count(*) from public.form_responses where form_id = p_form_id)
  ) into result;
  if result is null then raise no_data_found using message = 'form unavailable'; end if;
  return result;
end;
$$;

create or replace function app_private.form_clone(
  p_actor uuid,
  p_source_form_id uuid,
  p_target_institution_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare source_row public.forms;
declare source_projection jsonb;
declare target_form_id uuid := gen_random_uuid();
declare target_version_id uuid;
begin
  select * into source_row from public.forms where id = p_source_form_id;
  if source_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if p_target_institution_id <> source_row.institution_id
     and not app_private.has_platform_permission('forms.transfer_cross_institution') then
    raise insufficient_privilege using message = 'forms.transfer_cross_institution required';
  end if;
  source_projection := app_private.form_definition_projection(source_row.id);
  insert into public.forms(
    id, institution_id, kind, status, identity_mode, response_unit, title, description,
    created_by_person_id, updated_by_person_id
  ) values (
    target_form_id, p_target_institution_id, source_row.kind, 'draft', source_row.identity_mode,
    source_row.response_unit, source_row.title || ' (cópia)', source_row.description, p_actor, p_actor
  );
  insert into public.form_versions(form_id, version_number, created_by_person_id)
  values (target_form_id, 1, p_actor) returning id into target_version_id;
  update public.forms set working_version_id = target_version_id where id = target_form_id;
  perform app_private.form_replace_working_definition(target_version_id, source_projection -> 'sections');
  return target_form_id;
end;
$$;

create or replace function app_private.form_duplicate(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.manage');
declare source_row public.forms;
declare target_id uuid;
declare replay jsonb;
begin
  perform app_private.form_assert_payload_keys(p_payload, array['form_id'], 'form duplicate');
  replay := app_private.form_begin_command(p_request_id, actor, 'form_duplicate', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  select * into source_row from public.forms where id = (p_payload ->> 'form_id')::uuid for share;
  if source_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if source_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  target_id := app_private.form_clone(actor, source_row.id, source_row.institution_id);
  return app_private.form_complete_command(p_request_id, app_private.form_definition_projection(target_id));
end;
$$;

create or replace function app_private.form_copy_or_move(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.manage');
declare source_row public.forms;
declare target_id uuid;
declare replay jsonb;
declare mode text;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['form_id','target_institution_id','mode'], 'form copy or move'
  );
  mode := p_payload ->> 'mode';
  if mode not in ('copy', 'move') then raise invalid_parameter_value using message = 'invalid transfer mode'; end if;
  replay := app_private.form_begin_command(p_request_id, actor, 'form_copy_or_move', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  select * into source_row from public.forms where id = (p_payload ->> 'form_id')::uuid for update;
  if source_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if source_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  if (p_payload ->> 'target_institution_id')::uuid <> source_row.institution_id
     and not app_private.has_platform_permission('forms.transfer_cross_institution') then
    raise insufficient_privilege using message = 'forms.transfer_cross_institution required';
  end if;
  if mode = 'move' and source_row.first_published_at is null
     and not exists(select 1 from public.form_applications where form_id = source_row.id)
     and not exists(select 1 from public.form_responses where form_id = source_row.id) then
    update public.forms
       set institution_id = (p_payload ->> 'target_institution_id')::uuid,
           management_version = management_version + 1,
           updated_by_person_id = actor, updated_at = now()
     where id = source_row.id;
    target_id := source_row.id;
  else
    target_id := app_private.form_clone(
      actor, source_row.id, (p_payload ->> 'target_institution_id')::uuid
    );
  end if;
  return app_private.form_complete_command(p_request_id, app_private.form_definition_projection(target_id));
end;
$$;

create or replace function app_private.form_archive_or_delete(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.manage');
declare form_row public.forms;
declare replay jsonb;
declare deleted boolean := false;
begin
  perform app_private.form_assert_payload_keys(p_payload, array['form_id','action'], 'form archive or delete');
  replay := app_private.form_begin_command(p_request_id, actor, 'form_archive_or_delete', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  select * into form_row from public.forms where id = (p_payload ->> 'form_id')::uuid for update;
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if form_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  if p_payload ->> 'action' = 'delete'
     and form_row.first_published_at is null
     and not exists(select 1 from public.form_applications where form_id = form_row.id)
     and not exists(select 1 from public.form_responses where form_id = form_row.id) then
    delete from public.forms where id = form_row.id;
    deleted := true;
  elsif p_payload ->> 'action' in ('delete', 'archive') then
    update public.forms set status = 'archived', archived_at = now(),
      management_version = management_version + 1, updated_by_person_id = actor, updated_at = now()
    where id = form_row.id;
  else
    raise invalid_parameter_value using message = 'invalid archive action';
  end if;
  return app_private.form_complete_command(
    p_request_id, jsonb_build_object('form_id', form_row.id, 'deleted', deleted)
  );
end;
$$;

create or replace function app_private.form_save_application(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
  replay := app_private.form_begin_command(p_request_id, actor, 'form_save_application', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
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
  if jsonb_typeof(p_payload -> 'rules') <> 'array' then
    raise invalid_parameter_value using message = 'application rules must be an array';
  end if;
  delete from public.form_audience_rules where application_id = application_row.id;
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
$$;

create or replace function app_private.form_save_schedule(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.manage_applications');
declare schedule_row public.form_schedules;
declare replay jsonb;
declare reminder_json jsonb;
declare target_schedule_id uuid := coalesce((p_payload ->> 'schedule_id')::uuid, gen_random_uuid());
begin
  perform app_private.form_assert_payload_keys(
    p_payload,
    array['schedule_id','application_id','time_zone','starts_at_local','recurrence_kind','interval','weekdays',
          'monthly_day','monthly_last_day','end_kind','ends_on','occurrence_count','reminders'],
    'form schedule'
  );
  if not exists(select 1 from pg_timezone_names where name = p_payload ->> 'time_zone') then
    raise invalid_parameter_value using message = 'unknown IANA timezone';
  end if;
  replay := app_private.form_begin_command(p_request_id, actor, 'form_save_schedule', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  select * into schedule_row from public.form_schedules
   where id = target_schedule_id for update;
  if schedule_row.id is not null
     and schedule_row.application_id <> (p_payload ->> 'application_id')::uuid then
    raise no_data_found using message = 'form schedule unavailable';
  end if;
  if schedule_row.id is not null and schedule_row.status <> 'active' then
    raise no_data_found using message = 'form schedule unavailable';
  end if;
  if schedule_row.id is null and p_expected_version <> 0 then
    raise serialization_failure using message = 'expected_version mismatch';
  elsif schedule_row.id is not null and schedule_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  insert into public.form_schedules(
    id, application_id, time_zone, starts_at_local, recurrence_kind, interval_value, weekdays,
    monthly_day, monthly_last_day, end_kind, ends_on, occurrence_count
  ) values (
    target_schedule_id, (p_payload ->> 'application_id')::uuid, p_payload ->> 'time_zone',
    (p_payload ->> 'starts_at_local')::timestamp, p_payload ->> 'recurrence_kind',
    coalesce((p_payload ->> 'interval')::integer, 1),
    coalesce(array(select jsonb_array_elements_text(p_payload -> 'weekdays')::smallint), '{}'),
    (p_payload ->> 'monthly_day')::smallint,
    coalesce((p_payload ->> 'monthly_last_day')::boolean, false),
    coalesce(p_payload ->> 'end_kind', 'never'), (p_payload ->> 'ends_on')::date,
    (p_payload ->> 'occurrence_count')::integer
  ) on conflict(id) do update set
    time_zone = excluded.time_zone, starts_at_local = excluded.starts_at_local,
    recurrence_kind = excluded.recurrence_kind, interval_value = excluded.interval_value,
    weekdays = excluded.weekdays, monthly_day = excluded.monthly_day,
    monthly_last_day = excluded.monthly_last_day, end_kind = excluded.end_kind,
    ends_on = excluded.ends_on, occurrence_count = excluded.occurrence_count,
    management_version = public.form_schedules.management_version + 1, updated_at = now()
  returning * into schedule_row;
  delete from public.form_schedule_reminders where schedule_id = schedule_row.id;
  for reminder_json in select value from jsonb_array_elements(coalesce(p_payload -> 'reminders', '[]'::jsonb)) loop
    perform app_private.form_assert_payload_keys(reminder_json, array['kind','amount','position'], 'form reminder');
    insert into public.form_schedule_reminders(schedule_id, reminder_kind, amount, position)
    values (schedule_row.id, reminder_json ->> 'kind', (reminder_json ->> 'amount')::integer,
            (reminder_json ->> 'position')::integer);
  end loop;
  insert into app_private.form_worker_jobs(job_kind, aggregate_id, payload_jsonb)
  values ('generate_occurrences', schedule_row.id, jsonb_build_object('schedule_id', schedule_row.id))
  on conflict do nothing;
  return app_private.form_complete_command(
    p_request_id, app_private.form_application_projection(schedule_row.application_id)
  );
end;
$$;

create or replace function app_private.form_remove_schedule(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.manage_applications');
declare schedule_row public.form_schedules;
declare replay jsonb;
begin
  perform app_private.form_assert_payload_keys(p_payload, array['schedule_id'], 'remove form schedule');
  replay := app_private.form_begin_command(p_request_id, actor, 'form_remove_schedule', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  select * into schedule_row from public.form_schedules
   where id = (p_payload ->> 'schedule_id')::uuid for update;
  if schedule_row.id is null then raise no_data_found using message = 'form schedule unavailable'; end if;
  if schedule_row.status <> 'active' then raise no_data_found using message = 'form schedule unavailable'; end if;
  if schedule_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  update public.form_schedules
     set status = 'archived', management_version = management_version + 1, updated_at = now()
   where id = schedule_row.id;
  update public.form_occurrences set status = 'cancelled'
   where schedule_id = schedule_row.id and status = 'scheduled';
  return app_private.form_complete_command(
    p_request_id, app_private.form_application_projection(schedule_row.application_id)
  );
end;
$$;

create or replace function app_private.form_list_audience_candidates(p_query jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.manage_applications');
declare page_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 25), 1), 100);
declare candidate_kind text := p_query ->> 'kind';
begin
  perform app_private.form_assert_payload_keys(
    p_query, array['institution_id','kind','search','cursor_label','cursor_id','limit'],
    'form audience candidates query'
  );
  return (
    with candidates as (
      select person.id, person.display_name as label, candidate_kind::text as kind
        from public.people person
        join public.institution_memberships membership on membership.person_id = person.id
       where candidate_kind in ('person','guardian','teacher','employee','profile')
         and membership.institution_id = (p_query ->> 'institution_id')::uuid
         and membership.status = 'active'
         and membership.revoked_at is null
      union all
      select unit_row.id, unit_row.name, 'unit'
        from public.units unit_row
       where candidate_kind = 'unit'
         and unit_row.institution_id = (p_query ->> 'institution_id')::uuid
      union all
      select group_row.id, group_row.name, 'group'
        from public.groups group_row
       where candidate_kind = 'group'
         and group_row.institution_id = (p_query ->> 'institution_id')::uuid
      union all
      select activity_row.id, activity_row.name, 'activity'
        from public.activity_definitions activity_row
       where candidate_kind = 'activity'
         and activity_row.institution_id = (p_query ->> 'institution_id')::uuid
      union all
      select institution_row.id, institution_row.public_name, 'institution'
        from public.institutions institution_row
       where candidate_kind = 'institution'
         and institution_row.id = (p_query ->> 'institution_id')::uuid
    ), filtered as (
      select * from candidates
       where (nullif(p_query ->> 'search', '') is null
              or label ilike '%' || app_private.form_escape_like(p_query ->> 'search') || '%' escape '\')
         and ((p_query ->> 'cursor_label') is null
              or (lower(label), id) > (lower(p_query ->> 'cursor_label'), (p_query ->> 'cursor_id')::uuid))
       order by lower(label), id limit page_limit + 1
    ), visible as (select * from filtered limit page_limit)
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object('id', id, 'label', label, 'kind', kind)
                                  order by lower(label), id), '[]'::jsonb),
      'has_more', (select count(*) > page_limit from filtered),
      'next_cursor', (select jsonb_build_object('label', label, 'id', id)
                        from visible order by lower(label) desc, id desc limit 1)
    ) from visible
  );
end;
$$;

create or replace function app_private.form_get_occurrence_for_response(p_occurrence_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.respond');
declare occurrence_row public.form_occurrences;
declare participation_row public.form_participations;
begin
  select * into occurrence_row from public.form_occurrences where id = p_occurrence_id;
  select participation.* into participation_row
    from public.form_participations participation
   where participation.occurrence_id = p_occurrence_id
     and participation.eligibility_state = 'eligible'
     and (
       participation.person_id = actor
       or exists(select 1 from public.form_participation_responders responder
                 where responder.participation_id = participation.id and responder.person_id = actor)
     ) limit 1;
  if occurrence_row.id is null or participation_row.id is null then
    raise no_data_found using message = 'form occurrence unavailable';
  end if;
  return jsonb_build_object(
    'occurrence', jsonb_build_object(
      'id', occurrence_row.id, 'application_id', occurrence_row.application_id,
      'form_id', occurrence_row.form_id, 'form_version_id', occurrence_row.form_version_id,
      'form_version_number', (select version_number from public.form_versions
                               where id = occurrence_row.form_version_id),
      'opens_at', occurrence_row.opens_at, 'closes_at', occurrence_row.closes_at,
      'status', occurrence_row.status, 'management_version', occurrence_row.management_version
    ),
    'participation_id', participation_row.id,
    'definition', app_private.form_definition_projection(
      occurrence_row.form_id, occurrence_row.form_version_id
    ),
    'can_edit', occurrence_row.status = 'open' and now() between occurrence_row.opens_at and occurrence_row.closes_at
  );
end;
$$;

create or replace function app_private.form_get_monitor(p_query jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.monitor');
begin
  perform app_private.form_assert_payload_keys(
    p_query, array['form_id','application_id','occurrence_id','starts_on_or_after','ends_on_or_before','scope_id'],
    'form monitor query'
  );
  return (
    select jsonb_build_object(
      'eligible_count', coalesce(sum(metric.eligible_count), 0),
      'responded_count', coalesce(sum(metric.responded_count), 0),
      'pending_count', coalesce(sum(metric.pending_count), 0),
      'is_anonymous', form_row.identity_mode = 'anonymous'
    )
      from public.forms form_row
      left join public.form_occurrences occurrence_row on occurrence_row.form_id = form_row.id
       and ((p_query ->> 'application_id') is null or occurrence_row.application_id = (p_query ->> 'application_id')::uuid)
       and ((p_query ->> 'occurrence_id') is null or occurrence_row.id = (p_query ->> 'occurrence_id')::uuid)
       and ((p_query ->> 'starts_on_or_after') is null
            or occurrence_row.opens_at::date >= (p_query ->> 'starts_on_or_after')::date)
       and ((p_query ->> 'ends_on_or_before') is null
            or occurrence_row.closes_at::date <= (p_query ->> 'ends_on_or_before')::date)
      left join public.form_occurrence_metrics metric on metric.occurrence_id = occurrence_row.id
     where form_row.id = (p_query ->> 'form_id')::uuid
     group by form_row.identity_mode
  );
end;
$$;

create or replace function app_private.form_list_monitor_people(p_query jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.monitor');
declare form_row public.forms;
declare page_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 25), 1), 100);
begin
  perform app_private.form_assert_payload_keys(
    p_query, array[
      'form_id','application_id','occurrence_id','starts_on_or_after','ends_on_or_before','scope_id',
      'justification','cursor_name','cursor_id','limit'
    ],
    'form monitor people query'
  );
  select * into form_row from public.forms where id = (p_query ->> 'form_id')::uuid;
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if form_row.identity_mode = 'anonymous' then
    perform app_private.form_require_owner(actor, 'forms.anonymous_participation.read');
    if char_length(btrim(coalesce(p_query ->> 'justification', ''))) < 10 then
      raise invalid_parameter_value using message = 'auditable justification required';
    end if;
  end if;
  return (
    with page as (
      select participation.id, coalesce(person.id, responder_person.id) as person_id,
             coalesce(person.display_name, responder_person.display_name) as display_name,
             membership.role_code as profile_label,
             participation.response_unit_key as context_label,
             participation.response_state = 'responded' as responded
        from public.form_participations participation
        join public.form_occurrences occurrence_row on occurrence_row.id = participation.occurrence_id
        left join public.people person on person.id = participation.person_id
        left join public.form_participation_responders responder on responder.participation_id = participation.id
        left join public.people responder_person on responder_person.id = responder.person_id
        left join public.institution_memberships membership
          on membership.person_id = coalesce(person.id, responder_person.id)
         and membership.institution_id = participation.institution_id and membership.status = 'active'
       where occurrence_row.form_id = form_row.id
         and ((p_query ->> 'application_id') is null
              or occurrence_row.application_id = (p_query ->> 'application_id')::uuid)
         and ((p_query ->> 'occurrence_id') is null or occurrence_row.id = (p_query ->> 'occurrence_id')::uuid)
         and ((p_query ->> 'starts_on_or_after') is null
              or occurrence_row.opens_at::date >= (p_query ->> 'starts_on_or_after')::date)
         and ((p_query ->> 'ends_on_or_before') is null
              or occurrence_row.closes_at::date <= (p_query ->> 'ends_on_or_before')::date)
         and participation.eligibility_state = 'eligible'
         and ((p_query ->> 'cursor_name') is null
              or (lower(coalesce(person.display_name, responder_person.display_name)), participation.id)
                 > (lower(p_query ->> 'cursor_name'), (p_query ->> 'cursor_id')::uuid))
       order by lower(coalesce(person.display_name, responder_person.display_name)), participation.id
       limit page_limit + 1
    ), visible as (select * from page limit page_limit)
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'person_id', person_id, 'display_name', display_name, 'profile_label', profile_label,
        'context_label', context_label, 'responded', responded
      )), '[]'::jsonb),
      'has_more', (select count(*) > page_limit from page),
      'next_cursor', (select jsonb_build_object('name', display_name, 'id', id)
                        from visible order by lower(display_name) desc, id desc limit 1)
    ) from visible
  );
end;
$$;

create or replace function app_private.form_list_responses(p_query jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.responses.read');
declare page_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 25), 1), 100);
declare cursor_submitted timestamptz := (p_query ->> 'cursor_submitted_at')::timestamptz;
declare cursor_id uuid := (p_query ->> 'cursor_id')::uuid;
begin
  perform app_private.form_assert_payload_keys(
    p_query, array['form_id','occurrence_id','cursor_submitted_at','cursor_id','limit'],
    'form responses query'
  );
  return (
    with page as (
      select response.*, person.display_name
        from public.form_responses response
        left join public.people person on person.id = response.respondent_person_id
       where response.form_id = (p_query ->> 'form_id')::uuid and response.status = 'submitted'
         and ((p_query ->> 'occurrence_id') is null or response.occurrence_id = (p_query ->> 'occurrence_id')::uuid)
         and (cursor_submitted is null or (response.submitted_at, response.id) < (cursor_submitted, cursor_id))
       order by response.submitted_at desc, response.id desc limit page_limit + 1
    ), visible as (select * from page limit page_limit)
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'occurrence_id', occurrence_id, 'form_version_id', form_version_id,
        'submitted_at', case when identity_mode = 'identified' then submitted_at else null end,
        'respondent_label', case when identity_mode = 'identified' then display_name else null end
      ) order by submitted_at desc, id desc), '[]'::jsonb),
      'has_more', (select count(*) > page_limit from page),
      'next_cursor', (select jsonb_build_object('submitted_at', submitted_at, 'id', id)
                        from visible order by submitted_at, id limit 1)
    ) from visible
  );
end;
$$;

create or replace function app_private.form_get_response_detail(p_response_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.responses.read');
declare response_row public.form_responses;
begin
  select * into response_row from public.form_responses where id = p_response_id and status = 'submitted';
  if response_row.id is null then raise no_data_found using message = 'form response unavailable'; end if;
  return jsonb_build_object(
    'id', response_row.id, 'occurrence_id', response_row.occurrence_id,
    'form_version_id', response_row.form_version_id,
    'submitted_at', case when response_row.identity_mode = 'identified' then response_row.submitted_at else null end,
    'respondent_label', case when response_row.identity_mode = 'identified'
      then (select display_name from public.people where id = response_row.respondent_person_id) else null end,
    'answers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'item_id', answer.item_id, 'kind', answer.answer_kind,
        'text_value', answer.text_value, 'integer_value', answer.integer_value,
        'decimal_value', answer.decimal_value, 'money_minor_units', answer.money_minor_units,
        'date_value', answer.date_value, 'yes_no_value', answer.yes_no_value,
        'scale_value', answer.scale_value,
        'option_ids', coalesce((select jsonb_agg(selected.option_id order by selected.position)
                                from public.form_answer_options selected where selected.answer_id = answer.id), '[]'::jsonb),
        'asset_ids', coalesce((select jsonb_agg(asset.asset_id order by asset.position)
                               from public.form_answer_assets asset where asset.answer_id = answer.id), '[]'::jsonb)
      ) order by item.position)
      from public.form_answers answer join public.form_items item on item.id = answer.item_id
      where answer.response_id = response_row.id
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function app_private.form_prepare_asset_upload(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.respond');
declare occurrence_row public.form_occurrences;
declare item_row public.form_items;
declare asset_row public.form_assets;
declare replay jsonb;
declare opaque_id uuid := gen_random_uuid();
declare identity_mode text;
declare result jsonb;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['occurrence_id','item_id','mime_type','byte_length','checksum','edit_secret'],
    'prepare form asset'
  );
  if p_expected_version <> 0 then raise serialization_failure using message = 'expected_version mismatch'; end if;
  select * into occurrence_row from public.form_occurrences
   where id = (p_payload ->> 'occurrence_id')::uuid;
  select * into item_row from public.form_items
   where id = (p_payload ->> 'item_id')::uuid
     and form_version_id = occurrence_row.form_version_id and kind in ('photo', 'gallery');
  if occurrence_row.id is null or item_row.id is null or occurrence_row.status <> 'open'
     or now() not between occurrence_row.opens_at and occurrence_row.closes_at
     or not exists(
       select 1 from public.form_participations participation
       where participation.occurrence_id = occurrence_row.id
         and participation.eligibility_state = 'eligible'
         and (participation.person_id = actor or exists(
           select 1 from public.form_participation_responders responder
           where responder.participation_id = participation.id and responder.person_id = actor
         ))
     ) then
    raise no_data_found using message = 'form asset target unavailable';
  end if;
  select form_row.identity_mode into identity_mode
    from public.forms form_row where form_row.id = occurrence_row.form_id;
  -- Serialize the per-respondent/question quota without holding a row lock
  -- across the later Storage request (the Edge function signs only after this
  -- transaction returns).
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      occurrence_row.id::text || ':' || item_row.id::text || ':' ||
      case when identity_mode = 'anonymous'
        then encode(extensions.digest(p_payload ->> 'edit_secret', 'sha256'), 'hex')
        else actor::text end,
      0
    )
  );
  if identity_mode = 'anonymous' then
    if not exists (
      select 1 from public.form_responses response
       where response.occurrence_id = occurrence_row.id
         and response.identity_mode = 'anonymous'
         and response.status = 'draft'
         and app_private.form_verify_anonymous_edit_secret(
           p_payload ->> 'edit_secret', response.anonymous_edit_secret_hash
         )
    ) then
      raise no_data_found using message = 'form asset target unavailable';
    end if;
    select * into asset_row from public.form_assets candidate
     where candidate.occurrence_id = occurrence_row.id
       and candidate.item_id = item_row.id
       and candidate.mime_type = p_payload ->> 'mime_type'
       and candidate.expected_byte_length = (p_payload ->> 'byte_length')::bigint
        and candidate.expected_checksum_sha256 = lower(p_payload ->> 'checksum')
        and candidate.state = 'prepared'
        and candidate.expires_at > now()
       and app_private.form_verify_anonymous_edit_secret(
         p_payload ->> 'edit_secret', candidate.anonymous_upload_secret_hash
       )
     limit 1;
    if asset_row.id is not null then
      return jsonb_build_object(
        'asset_id', asset_row.id, 'storage_path', asset_row.storage_path,
        'expires_at', asset_row.expires_at
      );
    end if;
  else
    replay := app_private.form_begin_command(
      p_request_id, actor, 'form_prepare_asset_upload', p_expected_version, p_payload
    );
    if replay is not null then return replay; end if;
  end if;
  if (select count(*) from public.form_assets candidate
      where candidate.occurrence_id = occurrence_row.id and candidate.item_id = item_row.id
        and candidate.state not in ('discarded','expired')
        and (
          candidate.prepared_by_person_id = actor
          or (identity_mode = 'anonymous' and app_private.form_verify_anonymous_edit_secret(
            p_payload ->> 'edit_secret', candidate.anonymous_upload_secret_hash
          ))
        )) >= 5 then
    raise check_violation using message = 'maximum five images per question';
  end if;
  insert into public.form_assets(
    id, institution_id, occurrence_id, item_id, prepared_by_person_id,
    anonymous_upload_secret_hash, storage_path,
    mime_type, expected_byte_length, expected_checksum_sha256
  ) values (
    opaque_id, occurrence_row.institution_id, occurrence_row.id, item_row.id,
    case when identity_mode = 'identified' then actor else null end,
    case when identity_mode = 'anonymous' then
      app_private.form_hash_anonymous_edit_secret(p_payload ->> 'edit_secret') else null end,
    substr(replace(opaque_id::text, '-', ''), 1, 2) || '/' || opaque_id::text,
    p_payload ->> 'mime_type', (p_payload ->> 'byte_length')::bigint,
    lower(p_payload ->> 'checksum')
  ) returning * into asset_row;
  result := jsonb_build_object(
    'asset_id', asset_row.id, 'storage_path', asset_row.storage_path,
    'expires_at', asset_row.expires_at
  );
  if identity_mode = 'anonymous' then return result; end if;
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

create or replace function app_private.form_finalize_asset_upload(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.respond');
declare asset_row public.form_assets;
declare replay jsonb;
declare result jsonb;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['asset_id','edit_secret'], 'finalize form asset'
  );
  select * into asset_row from public.form_assets
   where id = (p_payload ->> 'asset_id')::uuid for update;
  if asset_row.id is null or not (
       asset_row.prepared_by_person_id = actor
       or (asset_row.prepared_by_person_id is null and app_private.form_verify_anonymous_edit_secret(
         p_payload ->> 'edit_secret', asset_row.anonymous_upload_secret_hash
       ))
     ) or asset_row.state not in ('prepared','uploaded','finalized')
     or asset_row.expires_at <= now() then
    raise no_data_found using message = 'form asset unavailable';
  end if;
  if asset_row.prepared_by_person_id is not null then
    replay := app_private.form_begin_command(
      p_request_id, actor, 'form_finalize_asset_upload', p_expected_version, p_payload
    );
    if replay is not null then return replay; end if;
  end if;
  if p_expected_version <> 0 then raise serialization_failure using message = 'expected_version mismatch'; end if;
  if asset_row.state = 'prepared' then
    update public.form_assets set state = 'uploaded' where id = asset_row.id returning * into asset_row;
  end if;
  result := jsonb_build_object(
    'asset_id', asset_row.id, 'state', asset_row.state
  );
  if asset_row.prepared_by_person_id is null then return result; end if;
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

create or replace function app_private.form_discard_asset(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.respond');
declare asset_row public.form_assets;
declare replay jsonb;
declare result jsonb;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['asset_id','edit_secret'], 'discard form asset'
  );
  select * into asset_row from public.form_assets where id = (p_payload ->> 'asset_id')::uuid for update;
  if asset_row.id is null or not (
       asset_row.prepared_by_person_id = actor
       or (asset_row.prepared_by_person_id is null and app_private.form_verify_anonymous_edit_secret(
         p_payload ->> 'edit_secret', asset_row.anonymous_upload_secret_hash
       ))
     )
     or exists(select 1 from public.form_answer_assets where asset_id = asset_row.id) then
    raise no_data_found using message = 'form asset unavailable';
  end if;
  if asset_row.prepared_by_person_id is not null then
    replay := app_private.form_begin_command(
      p_request_id, actor, 'form_discard_asset', p_expected_version, p_payload
    );
    if replay is not null then return replay; end if;
  end if;
  update public.form_assets set state = 'discarded', discarded_at = coalesce(discarded_at, now())
   where id = asset_row.id;
  result := jsonb_build_object('asset_id', asset_row.id, 'discarded', true);
  if asset_row.prepared_by_person_id is null then return result; end if;
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

create or replace function public.form_list_audience_candidates(p_query jsonb)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.form_list_audience_candidates($1) $$;
create or replace function public.form_get_occurrence_for_response(p_occurrence_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.form_get_occurrence_for_response($1) $$;
create or replace function public.form_get_monitor(p_query jsonb)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.form_get_monitor($1) $$;
create or replace function public.form_list_monitor_people(p_query jsonb)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.form_list_monitor_people($1) $$;
create or replace function public.form_list_responses(p_query jsonb)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.form_list_responses($1) $$;
create or replace function public.form_get_response_detail(p_response_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.form_get_response_detail($1) $$;
create or replace function public.form_prepare_asset_upload(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_prepare_asset_upload($1, $2, $3) $$;
create or replace function public.form_finalize_asset_upload(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_finalize_asset_upload($1, $2, $3) $$;
create or replace function public.form_discard_asset(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_discard_asset($1, $2, $3) $$;

create or replace function app_private.form_assert_response_actor(
  p_response public.form_responses,
  p_actor uuid,
  p_edit_secret text
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_response.identity_mode = 'identified' then
    if p_response.respondent_person_id <> p_actor then
      raise no_data_found using message = 'form response unavailable';
    end if;
  elsif nullif(p_edit_secret, '') is null
     or not app_private.form_verify_anonymous_edit_secret(
       p_edit_secret, p_response.anonymous_edit_secret_hash
     ) then
    raise no_data_found using message = 'form response unavailable';
  end if;
end;
$$;

create or replace function app_private.form_replace_response_answers(
  p_response public.form_responses,
  p_answers jsonb,
  p_edit_secret text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
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
          (select count(*) from public.form_answer_options where form_answer_options.answer_id = answer_id)
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
          (select count(*) from public.form_answer_assets where form_answer_assets.answer_id = answer_id)
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
$$;

create or replace function app_private.form_assert_required_response_answers(
  p_response public.form_responses
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
      from public.form_items item
     where item.form_version_id = p_response.form_version_id
       and item.is_required
       and (
         not exists (
           select 1 from public.form_question_conditions condition_row
            where condition_row.target_item_id = item.id
         )
         or exists (
           select 1
             from public.form_question_conditions condition_row
             join public.form_answers source_answer
               on source_answer.response_id = p_response.id
              and source_answer.item_id = condition_row.source_item_id
            where condition_row.target_item_id = item.id
              and (
                (condition_row.condition_kind = 'yes_no'
                 and source_answer.yes_no_value = condition_row.expected_yes_no)
                or (condition_row.condition_kind = 'choice' and exists (
                  select 1 from public.form_answer_options selected
                   where selected.answer_id = source_answer.id
                     and selected.option_id = condition_row.source_option_id
                ))
              )
         )
       )
       and not exists (
         select 1
           from public.form_answers answer
          where answer.response_id = p_response.id
            and answer.item_id = item.id
            and case
              when item.kind = 'short_text' then nullif(btrim(answer.text_value), '') is not null
              when item.kind in ('single_choice', 'multiple_choice') then exists (
                select 1 from public.form_answer_options selected where selected.answer_id = answer.id
              )
              when item.kind in ('photo', 'gallery') then exists (
                select 1 from public.form_answer_assets attached where attached.answer_id = answer.id
              )
              else true
            end
       )
  ) then
    raise check_violation using message = 'required visible form answers are missing';
  end if;
end;
$$;

create or replace function app_private.form_response_draft_projection(p_response_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', response.id,
    'occurrence_id', response.occurrence_id,
    'status', response.status,
    'management_version', response.management_version,
    'identity_mode', response.identity_mode,
    'answers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'item_id', answer.item_id,
        'kind', answer.answer_kind,
        'text_value', answer.text_value,
        'integer_value', answer.integer_value,
        'decimal_value', answer.decimal_value,
        'money_minor_units', answer.money_minor_units,
        'date_value', answer.date_value,
        'yes_no_value', answer.yes_no_value,
        'option_ids', coalesce((
          select jsonb_agg(selected.option_id order by selected.position)
            from public.form_answer_options selected where selected.answer_id = answer.id
        ), '[]'::jsonb),
        'scale_value', answer.scale_value,
        'asset_ids', coalesce((
          select jsonb_agg(asset.asset_id order by asset.position)
            from public.form_answer_assets asset where asset.answer_id = answer.id
        ), '[]'::jsonb)
      ) order by item.position)
        from public.form_answers answer
        join public.form_items item on item.id = answer.item_id
       where answer.response_id = response.id
    ), '[]'::jsonb)
  ) from public.form_responses response where response.id = p_response_id;
$$;

create or replace function app_private.form_open_response_draft(
  p_request_id uuid,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.respond');
declare participation_row public.form_participations;
declare occurrence_row public.form_occurrences;
declare response_row public.form_responses;
declare replay jsonb;
declare result jsonb;
declare requested_identity_mode text;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['occurrence_id','participation_id','identity_mode','edit_secret'],
    'open form response draft'
  );
  if p_expected_version <> 0 then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  select * into participation_row
    from public.form_participations
   where id = (p_payload ->> 'participation_id')::uuid
     and occurrence_id = (p_payload ->> 'occurrence_id')::uuid
   for update;
  if participation_row.id is null or participation_row.eligibility_state <> 'eligible'
     or not (
       participation_row.person_id = actor
       or exists(
         select 1 from public.form_participation_responders responder
         where responder.participation_id = participation_row.id and responder.person_id = actor
       )
     ) then
    raise no_data_found using message = 'form occurrence unavailable';
  end if;
  select * into occurrence_row from public.form_occurrences
   where id = participation_row.occurrence_id for update;
  if occurrence_row.status <> 'open' or now() not between occurrence_row.opens_at and occurrence_row.closes_at then
    raise no_data_found using message = 'form occurrence unavailable';
  end if;
  select identity_mode into requested_identity_mode
    from public.forms where id = occurrence_row.form_id;
  if p_payload ->> 'identity_mode' <> requested_identity_mode then
    raise check_violation using message = 'form identity mode mismatch';
  end if;
  if requested_identity_mode = 'identified' then
    replay := app_private.form_begin_command(
      p_request_id, actor, 'form_open_response_draft', p_expected_version, p_payload
    );
    if replay is not null then return replay; end if;
  end if;
  if requested_identity_mode = 'anonymous' then
    if char_length(coalesce(p_payload ->> 'edit_secret', '')) < 43 then
      raise invalid_parameter_value using message = 'anonymous edit secret required';
    end if;
    select * into response_row
      from public.form_responses candidate
     where candidate.occurrence_id = occurrence_row.id
       and candidate.identity_mode = 'anonymous'
       and candidate.status in ('draft', 'submitted')
       and app_private.form_verify_anonymous_edit_secret(
         p_payload ->> 'edit_secret', candidate.anonymous_edit_secret_hash
       )
     limit 1;
    if participation_row.response_state = 'responded' and response_row.id is null then
      raise no_data_found using message = 'form response unavailable';
    end if;
    if response_row.id is null then
      insert into public.form_responses(
        occurrence_id, institution_id, form_id, form_version_id, identity_mode,
        anonymous_edit_secret_hash
      ) values (
        occurrence_row.id, occurrence_row.institution_id, occurrence_row.form_id,
        occurrence_row.form_version_id, 'anonymous',
        app_private.form_hash_anonymous_edit_secret(p_payload ->> 'edit_secret')
      ) returning * into response_row;
    end if;
  else
    select * into response_row from public.form_responses
     where occurrence_id = occurrence_row.id and respondent_person_id = actor
       and status in ('draft', 'submitted')
     for update;
    if participation_row.response_state = 'responded' and response_row.id is null then
      raise no_data_found using message = 'form response unavailable';
    end if;
    if response_row.id is null then
      insert into public.form_responses(
        occurrence_id, institution_id, form_id, form_version_id, identity_mode, respondent_person_id
      ) values (
        occurrence_row.id, occurrence_row.institution_id, occurrence_row.form_id,
        occurrence_row.form_version_id, 'identified', actor
      ) returning * into response_row;
    end if;
  end if;
  update public.form_participations
     set response_state = case when response_row.status = 'submitted' then 'responded' else 'draft' end,
         responded_at = case when response_row.status = 'submitted'
           then coalesce(responded_at, response_row.submitted_at) else responded_at end
   where id = participation_row.id;
  result := app_private.form_response_draft_projection(response_row.id);
  if requested_identity_mode = 'anonymous' then return result; end if;
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

create or replace function app_private.form_mutate_response(
  p_command text,
  p_request_id uuid,
  p_expected_version bigint,
  p_payload jsonb,
  p_submit boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
  select coalesce(max(revision_number), 0) + 1 into revision_number
    from public.form_response_revisions where response_id = response_row.id;
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
$$;

create or replace function public.form_open_response_draft(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_open_response_draft($1, $2, $3) $$;
create or replace function public.form_save_response_draft(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_mutate_response('form_save_response_draft', $1, $2, $3, false) $$;
create or replace function public.form_submit_response(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_mutate_response('form_submit_response', $1, $2, $3, true) $$;
create or replace function public.form_edit_response(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_mutate_response('form_edit_response', $1, $2, $3, false) $$;

create or replace function public.form_save_draft(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_save_draft($1, $2, $3) $$;
create or replace function public.form_publish(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_publish($1, $2, $3) $$;
create or replace function public.form_list(p_query jsonb)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.form_list($1) $$;
create or replace function public.form_get_editor(p_form_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.form_get_editor($1) $$;
create or replace function public.form_get_overview(p_form_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.form_get_overview($1) $$;
create or replace function public.form_duplicate(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_duplicate($1, $2, $3) $$;
create or replace function public.form_copy_or_move(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_copy_or_move($1, $2, $3) $$;
create or replace function public.form_archive_or_delete(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_archive_or_delete($1, $2, $3) $$;
create or replace function public.form_save_application(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_save_application($1, $2, $3) $$;
create or replace function public.form_save_schedule(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_save_schedule($1, $2, $3) $$;
create or replace function public.form_remove_schedule(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_remove_schedule($1, $2, $3) $$;

revoke all on function app_private.require_forms_actor(text) from public, anon, authenticated;
revoke all on function app_private.form_escape_like(text) from public, anon, authenticated;
revoke all on function app_private.form_assert_payload_keys(jsonb, text[], text) from public, anon, authenticated;
revoke all on function app_private.form_begin_command(uuid, uuid, text, bigint, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_complete_command(uuid, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_definition_projection(uuid) from public, anon, authenticated;
revoke all on function app_private.form_definition_projection(uuid, uuid) from public, anon, authenticated;
revoke all on function app_private.form_application_projection(uuid) from public, anon, authenticated;
revoke all on function app_private.form_replace_working_definition(uuid, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_save_draft(uuid, bigint, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_publish(uuid, bigint, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_list(jsonb) from public, anon, authenticated;
revoke all on function app_private.form_get_editor(uuid) from public, anon, authenticated;
revoke all on function app_private.form_get_overview(uuid) from public, anon, authenticated;
revoke all on function app_private.form_clone(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function app_private.form_duplicate(uuid, bigint, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_copy_or_move(uuid, bigint, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_archive_or_delete(uuid, bigint, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_save_application(uuid, bigint, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_save_schedule(uuid, bigint, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_remove_schedule(uuid, bigint, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_list_audience_candidates(jsonb) from public, anon, authenticated;
revoke all on function app_private.form_get_occurrence_for_response(uuid) from public, anon, authenticated;
revoke all on function app_private.form_get_monitor(jsonb) from public, anon, authenticated;
revoke all on function app_private.form_list_monitor_people(jsonb) from public, anon, authenticated;
revoke all on function app_private.form_list_responses(jsonb) from public, anon, authenticated;
revoke all on function app_private.form_get_response_detail(uuid) from public, anon, authenticated;
revoke all on function app_private.form_prepare_asset_upload(uuid, bigint, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_finalize_asset_upload(uuid, bigint, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_discard_asset(uuid, bigint, jsonb) from public, anon, authenticated;

revoke all on function public.form_save_draft(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_publish(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_list(jsonb) from public, anon;
revoke all on function public.form_get_editor(uuid) from public, anon;
revoke all on function public.form_get_overview(uuid) from public, anon;
grant execute on function public.form_save_draft(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_publish(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_list(jsonb) to authenticated;
grant execute on function public.form_get_editor(uuid) to authenticated;
grant execute on function public.form_get_overview(uuid) to authenticated;
revoke all on function public.form_duplicate(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_copy_or_move(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_archive_or_delete(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_save_application(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_save_schedule(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_remove_schedule(uuid, bigint, jsonb) from public, anon;
grant execute on function public.form_duplicate(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_copy_or_move(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_archive_or_delete(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_save_application(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_save_schedule(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_remove_schedule(uuid, bigint, jsonb) to authenticated;
revoke all on function public.form_list_audience_candidates(jsonb) from public, anon;
revoke all on function public.form_get_occurrence_for_response(uuid) from public, anon;
revoke all on function public.form_get_monitor(jsonb) from public, anon;
revoke all on function public.form_list_monitor_people(jsonb) from public, anon;
revoke all on function public.form_list_responses(jsonb) from public, anon;
revoke all on function public.form_get_response_detail(uuid) from public, anon;
grant execute on function public.form_list_audience_candidates(jsonb) to authenticated;
grant execute on function public.form_get_occurrence_for_response(uuid) to authenticated;
grant execute on function public.form_get_monitor(jsonb) to authenticated;
grant execute on function public.form_list_monitor_people(jsonb) to authenticated;
grant execute on function public.form_list_responses(jsonb) to authenticated;
grant execute on function public.form_get_response_detail(uuid) to authenticated;
revoke all on function public.form_prepare_asset_upload(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_finalize_asset_upload(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_discard_asset(uuid, bigint, jsonb) from public, anon;
grant execute on function public.form_prepare_asset_upload(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_finalize_asset_upload(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_discard_asset(uuid, bigint, jsonb) to authenticated;
revoke all on function app_private.form_assert_response_actor(public.form_responses, uuid, text) from public, anon, authenticated;
revoke all on function app_private.form_replace_response_answers(public.form_responses, jsonb, text) from public, anon, authenticated;
revoke all on function app_private.form_assert_required_response_answers(public.form_responses) from public, anon, authenticated;
revoke all on function app_private.form_response_draft_projection(uuid) from public, anon, authenticated;
revoke all on function app_private.form_open_response_draft(uuid, bigint, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_mutate_response(text, uuid, bigint, jsonb, boolean) from public, anon, authenticated;
revoke all on function public.form_open_response_draft(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_save_response_draft(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_submit_response(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_edit_response(uuid, bigint, jsonb) from public, anon;
grant execute on function public.form_open_response_draft(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_save_response_draft(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_submit_response(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_edit_response(uuid, bigint, jsonb) to authenticated;
