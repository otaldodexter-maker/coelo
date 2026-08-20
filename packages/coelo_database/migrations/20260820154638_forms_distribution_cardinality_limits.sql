alter table public.form_audience_rules
  drop constraint if exists form_audience_rules_application_id_key;

alter table public.form_audience_rules
  add constraint form_audience_rules_application_position_uk
    unique (application_id, position);

alter table public.form_schedule_reminders
  add constraint form_schedule_reminders_kind_uk
    unique (schedule_id, reminder_kind),
  add constraint form_schedule_reminders_position_uk
    unique (schedule_id, position);

create or replace function app_private.form_assert_application_payload_limits(p_payload jsonb)
returns void
language plpgsql
immutable
security definer
set search_path = ''
as $$
begin
  if jsonb_typeof(p_payload -> 'rules') <> 'array' then
    raise invalid_parameter_value using message = 'application rules must be an array';
  end if;
  if jsonb_array_length(p_payload -> 'rules') > 50 then
    raise check_violation using message = 'maximum 50 form audience rules';
  end if;
end;
$$;

create or replace function app_private.form_assert_schedule_payload_limits(p_payload jsonb)
returns void
language plpgsql
immutable
security definer
set search_path = ''
as $$
declare reminders jsonb := coalesce(p_payload -> 'reminders', '[]'::jsonb);
begin
  if jsonb_typeof(reminders) <> 'array' then
    raise invalid_parameter_value using message = 'schedule reminders must be an array';
  end if;
  if jsonb_array_length(reminders) > 3 then
    raise check_violation using message = 'maximum 3 form schedule reminders';
  end if;
end;
$$;

create or replace function app_private.form_assert_schedule_capacity(
  p_application_id uuid,
  p_schedule_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (
    select count(*)
      from public.form_schedules schedule
     where schedule.application_id = p_application_id
       and schedule.status = 'active'
       and schedule.id <> p_schedule_id
  ) >= 20 then
    raise check_violation using message = 'maximum 20 active form schedules per application';
  end if;
end;
$$;

create or replace function app_private.validate_form_distribution_cardinality()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'form_audience_rules' and (
    select count(*) from public.form_audience_rules rule
     where rule.application_id = new.application_id and rule.id <> new.id
  ) >= 50 then
    raise check_violation using message = 'maximum 50 form audience rules';
  elsif tg_table_name = 'form_schedules' and new.status = 'active' and (
    select count(*) from public.form_schedules schedule
     where schedule.application_id = new.application_id
       and schedule.status = 'active' and schedule.id <> new.id
  ) >= 20 then
    raise check_violation using message = 'maximum 20 active form schedules per application';
  elsif tg_table_name = 'form_schedule_reminders' and (
    select count(*) from public.form_schedule_reminders reminder
     where reminder.schedule_id = new.schedule_id and reminder.id <> new.id
  ) >= 3 then
    raise check_violation using message = 'maximum 3 form schedule reminders';
  end if;
  return new;
end;
$$;

create trigger form_distribution_cardinality_validate
before insert or update on public.form_audience_rules
for each row execute function app_private.validate_form_distribution_cardinality();
create trigger form_distribution_cardinality_validate
before insert or update on public.form_schedules
for each row execute function app_private.validate_form_distribution_cardinality();
create trigger form_distribution_cardinality_validate
before insert or update on public.form_schedule_reminders
for each row execute function app_private.validate_form_distribution_cardinality();

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
        from (
          select source_rule.* from public.form_audience_rules source_rule
           where source_rule.application_id = application.id
           order by source_rule.position, source_rule.id
           limit 50
        ) rule
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
            from (
              select source_reminder.* from public.form_schedule_reminders source_reminder
               where source_reminder.schedule_id = schedule.id
               order by source_reminder.position, source_reminder.id
               limit 3
            ) reminder
        ), '[]'::jsonb)
      ) order by schedule.starts_at_local, schedule.id)
        from (
          select source_schedule.* from public.form_schedules source_schedule
           where source_schedule.application_id = application.id
             and source_schedule.status = 'active'
           order by source_schedule.starts_at_local, source_schedule.id
           limit 20
        ) schedule
    ), '[]'::jsonb)
  )
    from public.form_applications application
   where application.id = p_application_id;
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
declare target_application_id uuid := (p_payload ->> 'application_id')::uuid;
begin
  perform app_private.form_assert_payload_keys(
    p_payload,
    array['schedule_id','application_id','time_zone','starts_at_local','recurrence_kind','interval','weekdays',
          'monthly_day','monthly_last_day','end_kind','ends_on','occurrence_count','reminders'],
    'form schedule'
  );
  perform app_private.form_assert_schedule_payload_limits(p_payload);
  if not exists(select 1 from pg_timezone_names where name = p_payload ->> 'time_zone') then
    raise invalid_parameter_value using message = 'unknown IANA timezone';
  end if;
  replay := app_private.form_begin_command(p_request_id, actor, 'form_save_schedule', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  perform pg_advisory_xact_lock(hashtextextended(target_application_id::text, 12));
  select * into schedule_row from public.form_schedules
   where id = target_schedule_id for update;
  if schedule_row.id is not null and schedule_row.application_id <> target_application_id then
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
  perform app_private.form_assert_schedule_capacity(target_application_id, target_schedule_id);
  insert into public.form_schedules(
    id, application_id, time_zone, starts_at_local, recurrence_kind, interval_value, weekdays,
    monthly_day, monthly_last_day, end_kind, ends_on, occurrence_count
  ) values (
    target_schedule_id, target_application_id, p_payload ->> 'time_zone',
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

revoke all on function app_private.form_assert_application_payload_limits(jsonb)
  from public, anon, authenticated, service_role;
revoke all on function app_private.form_assert_schedule_payload_limits(jsonb)
  from public, anon, authenticated, service_role;
revoke all on function app_private.form_assert_schedule_capacity(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function app_private.validate_form_distribution_cardinality()
  from public, anon, authenticated, service_role;
revoke all on function app_private.form_application_projection(uuid)
  from public, anon, authenticated;
revoke all on function app_private.form_save_application(uuid, bigint, jsonb)
  from public, anon, authenticated;
revoke all on function app_private.form_save_schedule(uuid, bigint, jsonb)
  from public, anon, authenticated;
