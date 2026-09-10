create table public.form_applications (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references public.forms(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  name text not null,
  status text not null default 'active',
  opens_for_days integer not null default 7,
  management_version bigint not null default 1,
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint form_applications_name_ck check (char_length(btrim(name)) between 1 and 200),
  constraint form_applications_status_ck check (status in ('active', 'paused', 'archived')),
  constraint form_applications_open_days_ck check (opens_for_days between 1 and 365),
  constraint form_applications_version_ck check (management_version > 0)
);

create or replace function app_private.form_audience_filter_valid(p_filter jsonb)
returns boolean
language sql
immutable
security definer
set search_path = ''
as $$
  select jsonb_typeof(p_filter) = 'object'
    and not exists (
      select 1 from jsonb_object_keys(p_filter) key
      where key not in ('status', 'profile_codes', 'membership_status')
    )
    and case when p_filter ? 'status'
      then jsonb_typeof(p_filter -> 'status') = 'string'
        and char_length(p_filter ->> 'status') between 1 and 40
      else true end
    and case when p_filter ? 'membership_status'
      then jsonb_typeof(p_filter -> 'membership_status') = 'string'
        and char_length(p_filter ->> 'membership_status') between 1 and 40
      else true end
    and case when p_filter ? 'profile_codes'
      then jsonb_typeof(p_filter -> 'profile_codes') = 'array'
        and jsonb_array_length(p_filter -> 'profile_codes') between 1 and 50
        and not exists (
          select 1 from jsonb_array_elements(p_filter -> 'profile_codes') value
           where jsonb_typeof(value) <> 'string' or char_length(value #>> '{}') not between 1 and 100
        )
      else true end;
$$;

create table public.form_audience_rules (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null unique references public.form_applications(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  rule_kind text not null,
  rule_mode text not null,
  target_id uuid not null,
  filter_jsonb jsonb not null default '{}'::jsonb,
  position integer not null,
  constraint form_audience_rules_kind_ck check (rule_kind in (
    'institution', 'unit', 'group', 'activity', 'guardian', 'teacher', 'employee', 'profile', 'person'
  )),
  constraint form_audience_rules_mode_ck check (rule_mode in ('include', 'exclude')),
  constraint form_audience_rules_filter_ck check (app_private.form_audience_filter_valid(filter_jsonb)),
  constraint form_audience_rules_position_ck check (position >= 0)
);

create table public.form_schedules (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.form_applications(id) on delete cascade,
  status text not null default 'active',
  time_zone text not null,
  starts_at_local timestamp not null,
  recurrence_kind text not null,
  interval_value integer not null default 1,
  weekdays smallint[] not null default '{}',
  monthly_day smallint,
  monthly_last_day boolean not null default false,
  end_kind text not null default 'never',
  ends_on date,
  occurrence_count integer,
  management_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint form_schedules_timezone_ck check (btrim(time_zone) <> ''),
  constraint form_schedules_status_ck check (status in ('active', 'archived')),
  constraint form_schedules_recurrence_ck check (recurrence_kind in ('once', 'daily', 'weekly', 'monthly')),
  constraint form_schedules_interval_ck check (interval_value between 1 and 365),
  constraint form_schedules_weekdays_ck check (
    weekdays <@ array[1,2,3,4,5,6,7]::smallint[]
    and (recurrence_kind <> 'weekly' or cardinality(weekdays) between 1 and 7)
  ),
  constraint form_schedules_monthly_ck check (
    recurrence_kind <> 'monthly'
    or (monthly_last_day and monthly_day is null)
    or (not monthly_last_day and monthly_day between 1 and 31)
  ),
  constraint form_schedules_end_ck check (
    (end_kind = 'never' and ends_on is null and occurrence_count is null)
    or (end_kind = 'date' and ends_on is not null and occurrence_count is null)
    or (end_kind = 'count' and ends_on is null and occurrence_count between 1 and 10000)
  ),
  constraint form_schedules_version_ck check (management_version > 0)
);

create table public.form_schedule_reminders (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.form_schedules(id) on delete cascade,
  reminder_kind text not null,
  amount integer,
  position integer not null,
  constraint form_schedule_reminders_kind_ck check (reminder_kind in ('on_open', 'before_close', 'every_days')),
  constraint form_schedule_reminders_amount_ck check (
    (reminder_kind = 'on_open' and amount is null)
    or (reminder_kind in ('before_close', 'every_days') and amount between 1 and 365)
  ),
  constraint form_schedule_reminders_position_ck check (position >= 0)
);

create table public.form_occurrences (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.form_applications(id) on delete cascade,
  schedule_id uuid not null references public.form_schedules(id) on delete restrict,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  form_id uuid not null references public.forms(id) on delete cascade,
  form_version_id uuid not null references public.form_versions(id) on delete restrict,
  scheduled_local timestamp not null,
  time_zone text not null,
  opens_at timestamptz not null,
  closes_at timestamptz not null,
  status text not null default 'scheduled',
  management_version bigint not null default 1,
  created_at timestamptz not null default now(),
  opened_at timestamptz,
  closed_at timestamptz,
  constraint form_occurrences_dates_ck check (opens_at < closes_at),
  constraint form_occurrences_status_ck check (status in ('scheduled', 'open', 'closed', 'cancelled')),
  constraint form_occurrences_version_ck check (management_version > 0)
);

create table public.form_participations (
  id uuid primary key default gen_random_uuid(),
  occurrence_id uuid not null references public.form_occurrences(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  person_id uuid references public.people(id) on delete cascade,
  child_context_id uuid references public.child_contexts(id) on delete cascade,
  response_unit_key text not null,
  eligibility_state text not null default 'eligible',
  response_state text not null default 'pending',
  became_eligible_at timestamptz not null default now(),
  lost_eligibility_at timestamptz,
  responded_at timestamptz,
  constraint form_participations_unit_ck check (
    (person_id is not null and child_context_id is null)
    or (person_id is null and child_context_id is not null)
  ),
  constraint form_participations_eligibility_ck check (eligibility_state in ('eligible', 'ineligible')),
  constraint form_participations_response_ck check (response_state in ('pending', 'draft', 'responded')),
  constraint form_participations_key_ck check (char_length(response_unit_key) between 1 and 200),
  unique(occurrence_id, response_unit_key)
);

create table public.form_participation_responders (
  participation_id uuid not null references public.form_participations(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(participation_id, person_id)
);

create unique index form_audience_rules_application_position_uidx
  on public.form_audience_rules(application_id, position);
create unique index form_reminders_schedule_position_uidx
  on public.form_schedule_reminders(schedule_id, position);
create index form_applications_form_id_idx on public.form_applications(form_id);
create index form_applications_institution_status_idx on public.form_applications(institution_id, status, id);
create index form_audience_rules_application_id_idx on public.form_audience_rules(application_id);
create index form_audience_rules_institution_target_idx on public.form_audience_rules(institution_id, rule_kind, target_id);
create index form_schedules_application_id_idx on public.form_schedules(application_id);
create index form_reminders_schedule_id_idx on public.form_schedule_reminders(schedule_id);
create index form_occurrences_application_id_idx on public.form_occurrences(application_id);
create unique index form_occurrences_schedule_local_uidx
  on public.form_occurrences(schedule_id, scheduled_local, time_zone);
create index form_occurrences_schedule_id_idx on public.form_occurrences(schedule_id);
create index form_occurrences_form_id_idx on public.form_occurrences(form_id);
create index form_occurrences_form_window_idx
  on public.form_occurrences(form_id, opens_at, closes_at)
  where status in ('scheduled', 'open');
create index form_occurrences_version_id_idx on public.form_occurrences(form_version_id);
create index form_occurrences_generation_idx on public.form_occurrences(status, opens_at, id)
  where status in ('scheduled', 'open');
create index form_participations_occurrence_state_idx on public.form_participations(occurrence_id, eligibility_state, response_state, id);
create index form_participations_person_id_idx on public.form_participations(person_id) where person_id is not null;
create index form_participations_child_context_id_idx on public.form_participations(child_context_id) where child_context_id is not null;
create index form_participation_responders_person_id_idx on public.form_participation_responders(person_id);

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'form_applications', 'form_audience_rules', 'form_schedules', 'form_schedule_reminders',
    'form_occurrences', 'form_participations', 'form_participation_responders'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
    execute format('revoke all on table public.%I from public, anon, authenticated', table_name);
  end loop;
end $$;

revoke all on function app_private.form_audience_filter_valid(jsonb) from public, anon, authenticated;
