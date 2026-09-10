create table public.form_occurrence_metrics (
  occurrence_id uuid primary key references public.form_occurrences(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  eligible_count bigint not null default 0,
  responded_count bigint not null default 0,
  pending_count bigint not null default 0,
  updated_at timestamptz not null default now(),
  constraint form_occurrence_metrics_counts_ck check (
    eligible_count >= 0 and responded_count >= 0 and pending_count >= 0
    and responded_count + pending_count <= eligible_count
  )
);

create table public.form_scope_metrics (
  occurrence_id uuid not null references public.form_occurrences(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  scope_kind text not null,
  scope_id uuid not null,
  eligible_count bigint not null default 0,
  responded_count bigint not null default 0,
  pending_count bigint not null default 0,
  updated_at timestamptz not null default now(),
  primary key(occurrence_id, scope_kind, scope_id),
  constraint form_scope_metrics_kind_ck check (scope_kind in ('institution', 'unit', 'group', 'activity', 'profile')),
  constraint form_scope_metrics_counts_ck check (
    eligible_count >= 0 and responded_count >= 0 and pending_count >= 0
    and responded_count + pending_count <= eligible_count
  )
);

create table public.form_file_jobs (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  form_id uuid not null references public.forms(id) on delete cascade,
  occurrence_id uuid references public.form_occurrences(id) on delete cascade,
  requested_by_person_id uuid not null references public.people(id) on delete restrict,
  request_id uuid not null,
  export_kind text not null,
  state text not null default 'pending',
  progress numeric(5,4) not null default 0,
  artifact_path text,
  artifact_byte_length bigint,
  manifest_jsonb jsonb not null default '{}'::jsonb,
  error_code text,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  expires_at timestamptz not null default (now() + interval '24 hours'),
  constraint form_file_jobs_kind_ck check (export_kind in ('csv', 'xlsx', 'zip', 'anonymous_participation')),
  constraint form_file_jobs_state_ck check (state in ('pending', 'processing', 'succeeded', 'partial', 'failed', 'expired')),
  constraint form_file_jobs_progress_ck check (progress between 0 and 1),
  constraint form_file_jobs_artifact_ck check (artifact_path is null or artifact_path ~ '^[0-9a-f]{2}/[0-9a-f-]{36}$'),
  unique(requested_by_person_id, request_id, export_kind)
);

create table app_private.form_worker_jobs (
  id uuid primary key default gen_random_uuid(),
  job_kind text not null,
  aggregate_id uuid,
  payload_jsonb jsonb not null default '{}'::jsonb,
  state text not null default 'pending',
  attempts integer not null default 0,
  available_at timestamptz not null default now(),
  lease_owner text,
  lease_expires_at timestamptz,
  progress_jsonb jsonb not null default '{}'::jsonb,
  last_error_code text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint form_worker_jobs_kind_ck check (job_kind in (
    'generate_occurrences', 'reconcile_audience', 'materialize_metrics', 'enqueue_reminders',
    'export_csv', 'export_xlsx', 'export_zip', 'export_anonymous_participation',
    'finalize_asset', 'cleanup_uploads', 'cleanup_artifacts'
  )),
  constraint form_worker_jobs_state_ck check (state in ('pending', 'processing', 'succeeded', 'failed')),
  constraint form_worker_jobs_attempts_ck check (attempts between 0 and 20)
);

create table app_private.form_multipart_uploads (
  id uuid primary key default gen_random_uuid(),
  file_job_id uuid not null unique references public.form_file_jobs(id) on delete cascade,
  worker_job_id uuid not null references app_private.form_worker_jobs(id) on delete restrict,
  bucket_id text not null,
  object_path text not null,
  upload_id text not null,
  state text not null default 'initiated',
  next_part_number integer not null default 1,
  uploaded_bytes bigint not null default 0,
  initiated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  aborted_at timestamptz,
  constraint form_multipart_uploads_bucket_ck check (bucket_id = 'coelo-forms-private'),
  constraint form_multipart_uploads_path_ck check (object_path ~ '^[0-9a-f]{2}/[0-9a-f-]{36}$'),
  constraint form_multipart_uploads_upload_id_ck check (
    length(btrim(upload_id)) between 1 and 1024 and upload_id !~ '[[:cntrl:]]'
  ),
  constraint form_multipart_uploads_state_ck check (
    state in ('initiated', 'uploading', 'completed', 'aborted')
  ),
  constraint form_multipart_uploads_progress_ck check (
    next_part_number between 1 and 10001 and uploaded_bytes >= 0
  ),
  constraint form_multipart_uploads_terminal_ck check (
    (state = 'completed') = (completed_at is not null)
    and (state = 'aborted') = (aborted_at is not null)
  ),
  unique(bucket_id, object_path, upload_id)
);

create table app_private.form_multipart_parts (
  multipart_upload_id uuid not null references app_private.form_multipart_uploads(id) on delete cascade,
  part_number integer not null,
  etag text not null,
  byte_length bigint not null,
  checksum_sha256 text not null,
  recorded_at timestamptz not null default now(),
  primary key(multipart_upload_id, part_number),
  constraint form_multipart_parts_number_ck check (part_number between 1 and 10000),
  constraint form_multipart_parts_etag_ck check (
    length(btrim(etag)) between 1 and 1024 and etag !~ '[[:cntrl:]]'
  ),
  constraint form_multipart_parts_bytes_ck check (byte_length > 0),
  constraint form_multipart_parts_checksum_ck check (checksum_sha256 ~ '^[0-9a-f]{64}$')
);

create unique index form_worker_jobs_dedupe_uidx
  on app_private.form_worker_jobs(job_kind, aggregate_id)
  where state in ('pending', 'processing');
create index form_worker_jobs_claim_idx
  on app_private.form_worker_jobs(available_at, created_at, id)
  where state in ('pending', 'failed');
create index form_multipart_uploads_worker_idx
  on app_private.form_multipart_uploads(worker_job_id, state, updated_at);
create index form_occurrence_metrics_institution_idx on public.form_occurrence_metrics(institution_id, occurrence_id);
create index form_scope_metrics_scope_idx on public.form_scope_metrics(institution_id, scope_kind, scope_id, occurrence_id);
create index form_file_jobs_form_cursor_idx on public.form_file_jobs(form_id, created_at desc, id desc);
create index form_file_jobs_cleanup_idx on public.form_file_jobs(expires_at, id)
  where state in ('succeeded', 'partial', 'failed');

alter table public.context_notification_recipients
  add column if not exists delivery_state text not null default 'pending',
  add column if not exists delivery_attempts integer not null default 0,
  add column if not exists last_delivery_error_code text,
  add column if not exists delivered_at timestamptz;

create or replace function app_private.form_claim_worker_job(
  p_worker_id text,
  p_lease_seconds integer default 60,
  p_job_kinds text[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare job_row app_private.form_worker_jobs;
begin
  if nullif(btrim(p_worker_id), '') is null or p_lease_seconds not between 10 and 600 then
    raise invalid_parameter_value using message = 'valid worker id and lease required';
  end if;
  update app_private.form_worker_jobs job
     set state = 'processing',
         attempts = attempts + 1,
         lease_owner = p_worker_id,
         lease_expires_at = now() + make_interval(secs => p_lease_seconds)
   where job.id = (
     select candidate.id
       from app_private.form_worker_jobs candidate
      where (
        (candidate.state in ('pending', 'failed') and candidate.available_at <= now())
        or (candidate.state = 'processing' and candidate.lease_expires_at < now())
      )
        and (p_job_kinds is null or candidate.job_kind = any(p_job_kinds))
      order by candidate.available_at, candidate.created_at, candidate.id
      limit 1
      for update skip locked
   )
  returning * into job_row;
  if job_row.id is null then return null; end if;
  return jsonb_build_object(
    'id', job_row.id,
    'job_kind', job_row.job_kind,
    'aggregate_id', job_row.aggregate_id,
    'payload', job_row.payload_jsonb,
    'progress', job_row.progress_jsonb,
    'attempts', job_row.attempts,
    'created_at', job_row.created_at,
    'lease_expires_at', job_row.lease_expires_at
  );
end;
$$;

create or replace function app_private.form_finish_worker_job(
  p_job_id uuid,
  p_worker_id text,
  p_progress jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update app_private.form_worker_jobs
     set state = 'succeeded', progress_jsonb = p_progress,
         completed_at = now(), lease_owner = null, lease_expires_at = null
   where id = p_job_id and state = 'processing' and lease_owner = p_worker_id
     and lease_expires_at >= now();
  if not found then raise serialization_failure using message = 'worker lease unavailable'; end if;
end;
$$;

create or replace function app_private.form_fail_worker_job(
  p_job_id uuid,
  p_worker_id text,
  p_error_code text,
  p_retry_after_seconds integer default 60,
  p_progress jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update app_private.form_worker_jobs
     set state = 'failed', last_error_code = left(p_error_code, 100),
         progress_jsonb = p_progress,
         available_at = now() + make_interval(secs => least(greatest(p_retry_after_seconds, 1), 86400)),
         lease_owner = null, lease_expires_at = null
   where id = p_job_id and state = 'processing' and lease_owner = p_worker_id;
  if not found then raise serialization_failure using message = 'worker lease unavailable'; end if;
end;
$$;

create or replace function app_private.form_finalize_asset_for_worker(
  p_asset_id uuid,
  p_actual_byte_length bigint,
  p_actual_mime_type text,
  p_actual_checksum_sha256 text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare asset_row public.form_assets;
begin
  select * into asset_row from public.form_assets where id = p_asset_id for update;
  if asset_row.id is null or asset_row.state <> 'uploaded' or asset_row.expires_at <= now() then
    raise no_data_found using message = 'form asset unavailable';
  end if;
  if p_actual_byte_length <> asset_row.expected_byte_length
     or p_actual_mime_type <> asset_row.mime_type
     or lower(p_actual_checksum_sha256) <> asset_row.expected_checksum_sha256 then
    update public.form_assets
       set state = 'discarded', discarded_at = now()
     where id = asset_row.id returning * into asset_row;
    return jsonb_build_object(
      'id', asset_row.id, 'item_id', asset_row.item_id,
      'mime_type', asset_row.mime_type, 'byte_length', null,
      'state', asset_row.state, 'error_code', 'form_asset_verification_mismatch'
    );
  end if;
  update public.form_assets
     set state = 'finalized', actual_byte_length = p_actual_byte_length,
         actual_checksum_sha256 = lower(p_actual_checksum_sha256), finalized_at = now()
   where id = asset_row.id returning * into asset_row;
  return jsonb_build_object(
    'id', asset_row.id, 'item_id', asset_row.item_id, 'mime_type', asset_row.mime_type,
    'byte_length', asset_row.actual_byte_length, 'state', asset_row.state
  );
end;
$$;

create or replace function app_private.form_rebuild_occurrence_metrics(p_occurrence_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.form_occurrence_metrics(
    occurrence_id, institution_id, eligible_count, responded_count, pending_count, updated_at
  )
  select occurrence_row.id,
         occurrence_row.institution_id,
         count(*) filter (where participation.eligibility_state = 'eligible'),
         count(*) filter (where participation.eligibility_state = 'eligible' and participation.response_state = 'responded'),
         count(*) filter (where participation.eligibility_state = 'eligible' and participation.response_state <> 'responded'),
         now()
    from public.form_occurrences occurrence_row
    left join public.form_participations participation on participation.occurrence_id = occurrence_row.id
   where occurrence_row.id = p_occurrence_id
   group by occurrence_row.id, occurrence_row.institution_id
  on conflict(occurrence_id) do update set
    eligible_count = excluded.eligible_count,
    responded_count = excluded.responded_count,
    pending_count = excluded.pending_count,
    updated_at = excluded.updated_at;
$$;

create or replace function app_private.form_require_owner(p_actor uuid, p_capability text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app_private.has_platform_permission(p_capability)
     or not exists(
       select 1
         from public.platform_memberships membership
         join public.platform_roles role_row on role_row.id = membership.role_id
        where membership.person_id = p_actor
          and membership.status = 'active'
          and membership.revoked_at is null
          and role_row.code = 'owner'
     ) then
    raise insufficient_privilege using message = 'Owner role and capability required';
  end if;
end;
$$;

create or replace function app_private.form_generate_occurrences(
  p_schedule_id uuid,
  p_horizon_days integer default 90
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare inserted_count integer;
begin
  if p_horizon_days not between 1 and 366 then
    raise invalid_parameter_value using message = 'occurrence horizon must be between 1 and 366 days';
  end if;
  with schedule_context as (
    select schedule.*,
           application.form_id,
           application.institution_id,
           application.opens_for_days,
           form_row.published_version_id
      from public.form_schedules schedule
     join public.form_applications application on application.id = schedule.application_id
      join public.forms form_row on form_row.id = application.form_id
     where schedule.id = p_schedule_id
       and schedule.status = 'active'
       and application.status = 'active'
       and form_row.status = 'published'
       and form_row.published_version_id is not null
  ), calendar_days as (
    select context.*,
           day_value::date as local_date,
           day_value::date + context.starts_at_local::time as scheduled_local
      from schedule_context context
      cross join lateral generate_series(
        context.starts_at_local::date,
        least(
          context.starts_at_local::date + p_horizon_days,
          coalesce(context.ends_on, context.starts_at_local::date + p_horizon_days)
        ),
        interval '1 day'
      ) day_value
  ), recurring as (
    select calendar.*
      from calendar_days calendar
     where case calendar.recurrence_kind
       when 'once' then calendar.local_date = calendar.starts_at_local::date
       when 'daily' then (calendar.local_date - calendar.starts_at_local::date)
                         % calendar.interval_value = 0
       when 'weekly' then (
         ((calendar.local_date - calendar.starts_at_local::date) / 7)
           % calendar.interval_value = 0
         and extract(isodow from calendar.local_date)::smallint = any(calendar.weekdays)
       )
       when 'monthly' then (
         ((extract(year from calendar.local_date)::integer
             - extract(year from calendar.starts_at_local)::integer) * 12
           + extract(month from calendar.local_date)::integer
             - extract(month from calendar.starts_at_local)::integer) % calendar.interval_value = 0
         and calendar.local_date = case when calendar.monthly_last_day
           then (date_trunc('month', calendar.local_date) + interval '1 month - 1 day')::date
           else make_date(
             extract(year from calendar.local_date)::integer,
             extract(month from calendar.local_date)::integer,
             least(
               calendar.monthly_day,
               extract(day from date_trunc('month', calendar.local_date)
                 + interval '1 month - 1 day')::integer
             )
           ) end
       )
       else false end
  ), numbered as (
    select recurring.*,
           row_number() over(order by recurring.scheduled_local) as occurrence_ordinal
      from recurring
  )
  insert into public.form_occurrences(
    application_id, schedule_id, institution_id, form_id, form_version_id,
    scheduled_local, time_zone, opens_at, closes_at, status
  )
  select numbered.application_id,
         numbered.id,
         numbered.institution_id,
         numbered.form_id,
         numbered.published_version_id,
         numbered.scheduled_local,
         numbered.time_zone,
         numbered.scheduled_local at time zone numbered.time_zone,
         (numbered.scheduled_local + make_interval(days => numbered.opens_for_days))
           at time zone numbered.time_zone,
         case
           when now() >= (numbered.scheduled_local + make_interval(days => numbered.opens_for_days))
                          at time zone numbered.time_zone then 'closed'
           when now() >= numbered.scheduled_local at time zone numbered.time_zone then 'open'
           else 'scheduled'
         end
    from numbered
   where numbered.end_kind <> 'count'
      or numbered.occurrence_ordinal <= numbered.occurrence_count
  on conflict(schedule_id, scheduled_local, time_zone) do nothing;
  get diagnostics inserted_count = row_count;

  update public.form_occurrences occurrence_row
     set status = case when now() >= occurrence_row.closes_at then 'closed' else 'open' end,
         opened_at = case when occurrence_row.opened_at is null and now() >= occurrence_row.opens_at
                          then now() else occurrence_row.opened_at end,
         closed_at = case when occurrence_row.closed_at is null and now() >= occurrence_row.closes_at
                          then now() else occurrence_row.closed_at end
   where occurrence_row.schedule_id = p_schedule_id
     and occurrence_row.status in ('scheduled', 'open')
     and now() >= occurrence_row.opens_at;
  return inserted_count;
end;
$$;

create or replace function app_private.form_generate_due_occurrences(p_horizon_days integer default 90)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare schedule_id uuid;
declare generated integer := 0;
begin
  for schedule_id in
    select schedule.id
      from public.form_schedules schedule
      join public.form_applications application on application.id = schedule.application_id
     where application.status = 'active'
     order by schedule.id
  loop
    generated := generated + app_private.form_generate_occurrences(schedule_id, p_horizon_days);
  end loop;
  return generated;
end;
$$;

create or replace function app_private.form_resolve_person_audience(p_application_id uuid)
returns table(person_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  with application_context as (
    select application.id, application.institution_id
      from public.form_applications application
     where application.id = p_application_id and application.status = 'active'
  ), rules as (
    select rule.*
      from public.form_audience_rules rule
      join application_context context on context.id = rule.application_id
  ), raw_matches as (
    select rule.rule_mode, membership.person_id, rule.filter_jsonb
      from rules rule
      join application_context context on true
      join public.institution_memberships membership
        on membership.institution_id = context.institution_id
       and membership.status = 'active' and membership.revoked_at is null
     where rule.rule_kind = 'institution' and rule.target_id = context.institution_id
    union all
    select rule.rule_mode, membership.person_id, rule.filter_jsonb
      from rules rule
      join application_context context on true
      join public.institution_memberships membership
        on membership.institution_id = context.institution_id
       and membership.status = 'active' and membership.revoked_at is null
     where rule.rule_kind = 'unit'
       and (
         membership.scope_unit_id = rule.target_id
         or exists (
           select 1 from public.institution_role_assignments assignment
            where assignment.membership_id = membership.id
              and assignment.status = 'active'
              and (assignment.starts_at is null or assignment.starts_at <= now())
              and (assignment.expires_at is null or assignment.expires_at > now())
              and assignment.scope_unit_id = rule.target_id
         )
       )
    union all
    select rule.rule_mode, membership.person_id, rule.filter_jsonb
      from rules rule
      join application_context context on true
      join public.institution_memberships membership
        on membership.institution_id = context.institution_id
       and membership.status = 'active' and membership.revoked_at is null
     where rule.rule_kind = 'group'
       and (
         membership.scope_group_id = rule.target_id
         or exists (
           select 1 from public.institution_role_assignments assignment
            where assignment.membership_id = membership.id
              and assignment.status = 'active'
              and (assignment.starts_at is null or assignment.starts_at <= now())
              and (assignment.expires_at is null or assignment.expires_at > now())
              and assignment.scope_group_id = rule.target_id
         )
       )
    union all
    select rule.rule_mode, assignment.person_id, rule.filter_jsonb
      from rules rule
      join public.activity_group_links activity_link
        on activity_link.activity_id = rule.target_id and activity_link.status = 'active'
      join public.activity_group_assignments assignment
        on assignment.activity_group_link_id = activity_link.id
       and assignment.status = 'active' and assignment.revoked_at is null
     where rule.rule_kind = 'activity'
    union all
    select rule.rule_mode, membership.person_id, rule.filter_jsonb
      from rules rule
      join application_context context on true
      join public.institution_role_assignments assignment
        on assignment.role_id = rule.target_id and assignment.status = 'active'
       and (assignment.starts_at is null or assignment.starts_at <= now())
       and (assignment.expires_at is null or assignment.expires_at > now())
      join public.institution_memberships membership
        on membership.id = assignment.membership_id
       and membership.institution_id = context.institution_id
       and membership.status = 'active' and membership.revoked_at is null
     where rule.rule_kind = 'profile'
    union all
    select rule.rule_mode, rule.target_id, rule.filter_jsonb
      from rules rule
      join application_context context on true
     where rule.rule_kind in ('person', 'guardian', 'teacher', 'employee')
       and (
         exists (
           select 1 from public.institution_memberships membership
            where membership.person_id = rule.target_id
              and membership.institution_id = context.institution_id
              and membership.status = 'active' and membership.revoked_at is null
         )
         or exists (
           select 1
             from public.guardian_links guardian
             join public.child_contexts child_context
               on child_context.child_person_id = guardian.child_person_id
              and child_context.institution_id = context.institution_id
              and child_context.status = 'active'
            where guardian.guardian_person_id = rule.target_id
              and guardian.status = 'active' and guardian.revoked_at is null
         )
       )
  ), filtered as (
    select match.rule_mode, match.person_id
      from raw_matches match
      join public.people person on person.id = match.person_id and person.deleted_at is null
     where (not (match.filter_jsonb ? 'status')
            or person.status::text = match.filter_jsonb ->> 'status')
       and (not (match.filter_jsonb ? 'membership_status') or exists (
         select 1 from public.institution_memberships membership
          join application_context context on context.institution_id = membership.institution_id
         where membership.person_id = match.person_id
           and membership.status::text = match.filter_jsonb ->> 'membership_status'
       ))
       and (not (match.filter_jsonb ? 'profile_codes') or exists (
         select 1
           from public.institution_memberships membership
           join application_context context on context.institution_id = membership.institution_id
           join public.institution_role_assignments assignment on assignment.membership_id = membership.id
           join public.institution_roles role_row on role_row.id = assignment.role_id
          where membership.person_id = match.person_id
            and assignment.status = 'active'
            and role_row.code in (
              select jsonb_array_elements_text(match.filter_jsonb -> 'profile_codes')
            )
       ))
  )
  select filtered.person_id
    from filtered
   group by filtered.person_id
  having bool_or(filtered.rule_mode = 'include')
     and not bool_or(filtered.rule_mode = 'exclude');
$$;

create or replace function app_private.form_resolve_child_audience(p_application_id uuid)
returns table(child_context_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  with application_context as (
    select application.id, application.institution_id
      from public.form_applications application
     where application.id = p_application_id and application.status = 'active'
  ), rules as (
    select rule.*
      from public.form_audience_rules rule
      join application_context context on context.id = rule.application_id
  ), raw_matches as (
    select rule.rule_mode, child_context.id as child_context_id, rule.filter_jsonb
      from rules rule
      join application_context context on true
      join public.child_contexts child_context
        on child_context.institution_id = context.institution_id
       and child_context.status = 'active'
     where rule.rule_kind = 'institution' and rule.target_id = context.institution_id
    union all
    select rule.rule_mode, child_unit.child_context_id, rule.filter_jsonb
      from rules rule
      join public.child_unit_links child_unit
        on child_unit.unit_id = rule.target_id and child_unit.status = 'active'
      join public.child_contexts child_context
        on child_context.id = child_unit.child_context_id and child_context.status = 'active'
     where rule.rule_kind = 'unit'
    union all
    select rule.rule_mode, child_unit.child_context_id, rule.filter_jsonb
      from rules rule
      join public.child_group_links child_group
        on child_group.group_id = rule.target_id and child_group.status = 'active'
       and (child_group.starts_at is null or child_group.starts_at <= now())
       and (child_group.ends_at is null or child_group.ends_at > now())
      join public.child_unit_links child_unit
        on child_unit.id = child_group.child_unit_link_id and child_unit.status = 'active'
     where rule.rule_kind = 'group'
    union all
    select rule.rule_mode, child_unit.child_context_id, rule.filter_jsonb
      from rules rule
      join public.activity_group_links activity_link
        on activity_link.activity_id = rule.target_id and activity_link.status = 'active'
       and activity_link.starts_at <= now()
       and (activity_link.ends_at is null or activity_link.ends_at > now())
      join public.child_group_links child_group
        on child_group.group_id = activity_link.group_id and child_group.status = 'active'
      join public.child_unit_links child_unit
        on child_unit.id = child_group.child_unit_link_id and child_unit.status = 'active'
      left join public.activity_group_participants selected
        on selected.activity_group_link_id = activity_link.id
       and selected.child_group_link_id = child_group.id
       and selected.status = 'active' and selected.removed_at is null
     where rule.rule_kind = 'activity'
       and (activity_link.participation_mode = 'all' or selected.id is not null)
    union all
    select rule.rule_mode, child_context.id, rule.filter_jsonb
      from rules rule
      join application_context context on true
      join public.child_contexts child_context
        on child_context.institution_id = context.institution_id
       and child_context.status = 'active'
     where rule.rule_kind in ('person', 'guardian')
       and (
         child_context.child_person_id = rule.target_id
         or exists (
           select 1 from public.guardian_links guardian
            where guardian.child_person_id = child_context.child_person_id
              and guardian.guardian_person_id = rule.target_id
              and guardian.status = 'active' and guardian.revoked_at is null
         )
       )
  ), filtered as (
    select match.rule_mode, match.child_context_id
      from raw_matches match
      join public.child_contexts child_context on child_context.id = match.child_context_id
     where not (match.filter_jsonb ? 'status')
        or child_context.status::text = match.filter_jsonb ->> 'status'
  )
  select filtered.child_context_id
    from filtered
   group by filtered.child_context_id
  having bool_or(filtered.rule_mode = 'include')
     and not bool_or(filtered.rule_mode = 'exclude');
$$;

create or replace function app_private.form_reconcile_occurrence_audience(p_occurrence_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare occurrence_row public.form_occurrences;
declare response_unit text;
declare changed_count integer := 0;
declare affected integer := 0;
begin
  select occurrence.* into occurrence_row
    from public.form_occurrences occurrence
   where occurrence.id = p_occurrence_id for update;
  if occurrence_row.id is null then
    raise no_data_found using message = 'form occurrence unavailable';
  end if;
  if occurrence_row.status in ('closed', 'cancelled') then return 0; end if;
  select form_row.response_unit into response_unit
    from public.forms form_row where form_row.id = occurrence_row.form_id;

  if response_unit = 'person' then
    update public.form_participations participation
       set eligibility_state = 'ineligible', lost_eligibility_at = coalesce(lost_eligibility_at, now())
     where participation.occurrence_id = occurrence_row.id
       and participation.eligibility_state = 'eligible'
       and not exists (
         select 1 from app_private.form_resolve_person_audience(occurrence_row.application_id) resolved
          where resolved.person_id = participation.person_id
       );
    get diagnostics affected = row_count;
    changed_count := changed_count + affected;

    insert into public.form_participations as current_participation(
      occurrence_id, institution_id, person_id, response_unit_key,
      eligibility_state, lost_eligibility_at
    )
    select occurrence_row.id, occurrence_row.institution_id, resolved.person_id,
           'person:' || resolved.person_id::text, 'eligible', null
      from app_private.form_resolve_person_audience(occurrence_row.application_id) resolved
    on conflict(occurrence_id, response_unit_key) do update set
      person_id = excluded.person_id,
      eligibility_state = 'eligible',
      lost_eligibility_at = null
    where current_participation.eligibility_state <> 'eligible'
       or current_participation.person_id is distinct from excluded.person_id;
    get diagnostics affected = row_count;
    changed_count := changed_count + affected;
  elsif response_unit = 'child_family_context' then
    update public.form_participations participation
       set eligibility_state = 'ineligible', lost_eligibility_at = coalesce(lost_eligibility_at, now())
     where participation.occurrence_id = occurrence_row.id
       and participation.eligibility_state = 'eligible'
       and not exists (
         select 1 from app_private.form_resolve_child_audience(occurrence_row.application_id) resolved
          where resolved.child_context_id = participation.child_context_id
       );
    get diagnostics affected = row_count;
    changed_count := changed_count + affected;

    insert into public.form_participations as current_participation(
      occurrence_id, institution_id, child_context_id, response_unit_key,
      eligibility_state, lost_eligibility_at
    )
    select occurrence_row.id, occurrence_row.institution_id, resolved.child_context_id,
           'child:' || resolved.child_context_id::text, 'eligible', null
      from app_private.form_resolve_child_audience(occurrence_row.application_id) resolved
    on conflict(occurrence_id, response_unit_key) do update set
      child_context_id = excluded.child_context_id,
      eligibility_state = 'eligible',
      lost_eligibility_at = null
    where current_participation.eligibility_state <> 'eligible'
       or current_participation.child_context_id is distinct from excluded.child_context_id;
    get diagnostics affected = row_count;
    changed_count := changed_count + affected;
  else
    raise check_violation using message = 'unsupported form response unit';
  end if;

  delete from public.form_participation_responders responder
   using public.form_participations participation
   where responder.participation_id = participation.id
     and participation.occurrence_id = occurrence_row.id;

  insert into public.form_participation_responders(participation_id, person_id, institution_id)
  select distinct participation.id, guardian.guardian_person_id, occurrence_row.institution_id
    from public.form_participations participation
    join public.child_contexts child_context on child_context.id = participation.child_context_id
    join public.guardian_links guardian
      on guardian.child_person_id = child_context.child_person_id
     and guardian.status = 'active' and guardian.revoked_at is null
    join public.guardian_context_permissions permission
      on permission.guardian_link_id = guardian.id
     and permission.child_context_id = child_context.id
     and permission.status = 'active' and permission.can_view
     and (permission.starts_at is null or permission.starts_at <= now())
     and (permission.expires_at is null or permission.expires_at > now())
   where participation.occurrence_id = occurrence_row.id
     and participation.eligibility_state = 'eligible'
  on conflict(participation_id, person_id) do nothing;

  perform app_private.form_rebuild_occurrence_metrics(occurrence_row.id);
  return changed_count;
end;
$$;

create or replace function app_private.form_reconcile_due_audiences()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare occurrence_id uuid;
declare changed integer := 0;
begin
  for occurrence_id in
    select occurrence.id from public.form_occurrences occurrence
     where occurrence.status in ('scheduled', 'open') order by occurrence.id
  loop
    changed := changed + app_private.form_reconcile_occurrence_audience(occurrence_id);
  end loop;
  return changed;
end;
$$;

create unique index form_notification_event_dedupe_uidx
  on public.context_notification_events(event_code, object_type, object_id, deliver_at)
  where event_code like 'forms.%';

create or replace function app_private.form_enqueue_due_reminders(
  p_horizon interval default interval '24 hours'
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare inserted_count integer := 0;
begin
  if p_horizon <= interval '0 seconds' or p_horizon > interval '7 days' then
    raise invalid_parameter_value using message = 'reminder horizon must be between zero and seven days';
  end if;
  with reminder_times as (
    select occurrence.id as occurrence_id, occurrence.institution_id, occurrence.form_id,
           reminder.reminder_kind,
           case reminder.reminder_kind
             when 'on_open' then occurrence.opens_at
             when 'before_close' then occurrence.closes_at - make_interval(days => reminder.amount)
           end as deliver_at
      from public.form_occurrences occurrence
      join public.form_schedules schedule on schedule.id = occurrence.schedule_id
      join public.form_schedule_reminders reminder on reminder.schedule_id = schedule.id
     where occurrence.status in ('scheduled', 'open')
       and reminder.reminder_kind in ('on_open', 'before_close')
    union all
    select occurrence.id, occurrence.institution_id, occurrence.form_id,
           reminder.reminder_kind, generated.deliver_at
      from public.form_occurrences occurrence
      join public.form_schedules schedule on schedule.id = occurrence.schedule_id
      join public.form_schedule_reminders reminder on reminder.schedule_id = schedule.id
      cross join lateral generate_series(
        occurrence.opens_at + make_interval(days => reminder.amount),
        occurrence.closes_at - interval '1 second',
        make_interval(days => reminder.amount)
      ) generated(deliver_at)
     where occurrence.status in ('scheduled', 'open') and reminder.reminder_kind = 'every_days'
  ), inserted as (
    insert into public.context_notification_events(
      institution_id, event_code, object_type, object_id, payload_json, deliver_at
    )
    select reminder.institution_id,
           'forms.reminder.' || reminder.reminder_kind,
           'form_occurrence', reminder.occurrence_id,
           jsonb_build_object('form_id', reminder.form_id, 'occurrence_id', reminder.occurrence_id),
           reminder.deliver_at
      from reminder_times reminder
     where reminder.deliver_at between now() - interval '5 minutes' and now() + p_horizon
    on conflict do nothing
    returning id
  )
  select count(*) into inserted_count from inserted;

  insert into public.context_notification_recipients(event_id, person_id)
  select distinct event.id,
         coalesce(participation.person_id, responder.person_id)
    from public.context_notification_events event
    join public.form_occurrences occurrence on occurrence.id = event.object_id
    join public.form_participations participation on participation.occurrence_id = occurrence.id
    left join public.form_participation_responders responder
      on responder.participation_id = participation.id
   where event.event_code like 'forms.reminder.%'
     and event.deliver_at between now() - interval '5 minutes' and now() + p_horizon
     and participation.eligibility_state = 'eligible'
     and participation.response_state in ('pending', 'draft')
     and coalesce(participation.person_id, responder.person_id) is not null
  on conflict(event_id, person_id) do nothing;

  update public.context_notification_recipients recipient
     set delivery_state = 'cancelled'
    from public.context_notification_events event
   where event.id = recipient.event_id
     and event.event_code like 'forms.reminder.%'
     and recipient.delivery_state in ('pending', 'failed')
     and not exists (
       select 1
         from public.form_participations participation
         left join public.form_participation_responders responder
           on responder.participation_id = participation.id
        where participation.occurrence_id = event.object_id
          and participation.eligibility_state = 'eligible'
          and participation.response_state in ('pending', 'draft')
          and coalesce(participation.person_id, responder.person_id) = recipient.person_id
     );
  return inserted_count;
end;
$$;

create or replace function app_private.form_run_periodic_maintenance()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare generated integer;
declare reconciled integer;
begin
  generated := app_private.form_generate_due_occurrences(90);
  reconciled := app_private.form_reconcile_due_audiences();
  return jsonb_build_object(
    'generated_occurrences', generated,
    'reconciled_participations', reconciled
  );
end;
$$;

create or replace function app_private.form_request_export(
  p_request_id uuid,
  p_expected_version bigint,
  p_payload jsonb,
  p_anonymous_participation boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor(
  case when p_anonymous_participation
       then 'forms.anonymous_participation.export'
       else 'forms.responses.export' end
);
declare form_row public.forms;
declare job_row public.form_file_jobs;
declare replay jsonb;
declare command_name text := case when p_anonymous_participation
  then 'form_request_anonymous_participation_export' else 'form_request_export' end;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['form_id','occurrence_id','kind','justification'], 'form export'
  );
  replay := app_private.form_begin_command(
    p_request_id, actor, command_name, p_expected_version, p_payload
  );
  if replay is not null then return replay; end if;
  select * into form_row from public.forms where id = (p_payload ->> 'form_id')::uuid;
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if form_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  if p_anonymous_participation then
    perform app_private.form_require_owner(actor, 'forms.anonymous_participation.export');
    if char_length(btrim(coalesce(p_payload ->> 'justification', ''))) < 10 then
      raise invalid_parameter_value using message = 'auditable justification required';
    end if;
  end if;
  insert into public.form_file_jobs(
    institution_id, form_id, occurrence_id, requested_by_person_id, request_id, export_kind,
    manifest_jsonb
  ) values (
    form_row.institution_id, form_row.id, (p_payload ->> 'occurrence_id')::uuid,
    actor, p_request_id,
    case when p_anonymous_participation then 'anonymous_participation' else p_payload ->> 'kind' end,
    case when p_anonymous_participation
         then jsonb_build_object('justification', btrim(p_payload ->> 'justification'))
         else '{}'::jsonb end
  ) returning * into job_row;
  insert into app_private.form_worker_jobs(job_kind, aggregate_id, payload_jsonb)
  values (
    case job_row.export_kind
      when 'csv' then 'export_csv'
      when 'xlsx' then 'export_xlsx'
      when 'zip' then 'export_zip'
      else 'export_anonymous_participation'
    end,
    job_row.id,
    jsonb_build_object('file_job_id', job_row.id)
  );
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id,
    outcome, reason, after_json
  ) values (
    actor, auth.jwt() ->> 'aal', command_name, 'form_file_job', job_row.id,
    form_row.institution_id, 'success',
    case when p_anonymous_participation then btrim(p_payload ->> 'justification') else null end,
    jsonb_build_object('form_id', form_row.id, 'export_kind', job_row.export_kind)
  );
  return app_private.form_complete_command(p_request_id, jsonb_build_object(
    'id', job_row.id, 'status', job_row.state, 'progress', job_row.progress,
    'download_path', null, 'error_code', null
  ));
end;
$$;

create or replace function app_private.form_list_file_jobs(p_query jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.responses.export');
declare page_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 25), 1), 100);
declare cursor_created timestamptz := (p_query ->> 'cursor_created_at')::timestamptz;
declare cursor_id uuid := (p_query ->> 'cursor_id')::uuid;
begin
  perform app_private.form_assert_payload_keys(
    p_query, array['form_id','cursor_created_at','cursor_id','limit'], 'form file jobs query'
  );
  return (
    with page as (
      select job.* from public.form_file_jobs job
       where job.form_id = (p_query ->> 'form_id')::uuid
         and job.requested_by_person_id = actor
         and (cursor_created is null or (job.created_at, job.id) < (cursor_created, cursor_id))
       order by job.created_at desc, job.id desc limit page_limit + 1
    ), visible as (select * from page limit page_limit)
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'status', state, 'progress', progress,
        'download_path', case when state in ('succeeded','partial') and expires_at > now()
                              then artifact_path else null end,
        'error_code', error_code, 'expires_at', expires_at
      ) order by created_at desc, id desc), '[]'::jsonb),
      'has_more', (select count(*) > page_limit from page),
      'next_cursor', (select jsonb_build_object('created_at', created_at, 'id', id)
                        from visible order by created_at, id limit 1)
    ) from visible
  );
end;
$$;

create or replace function app_private.form_anonymous_participation_lookup(p_query jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.anonymous_participation.read');
declare result jsonb;
begin
  perform app_private.form_assert_payload_keys(
    p_query, array['form_id','occurrence_id','justification','cursor_name','cursor_id','limit'],
    'anonymous participation query'
  );
  perform app_private.form_require_owner(actor, 'forms.anonymous_participation.read');
  if char_length(btrim(coalesce(p_query ->> 'justification', ''))) < 10 then
    raise invalid_parameter_value using message = 'auditable justification required';
  end if;
  if not exists(
    select 1 from public.forms where id = (p_query ->> 'form_id')::uuid and identity_mode = 'anonymous'
  ) then
    raise no_data_found using message = 'anonymous form unavailable';
  end if;
  result := app_private.form_list_monitor_people(p_query);
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id,
    outcome, reason, after_json
  )
  select actor, auth.jwt() ->> 'aal', 'forms.anonymous_participation.read', 'form', form_row.id,
         form_row.institution_id, 'success', btrim(p_query ->> 'justification'),
         jsonb_build_object('occurrence_id', p_query ->> 'occurrence_id')
    from public.forms form_row where form_row.id = (p_query ->> 'form_id')::uuid;
  return result;
end;
$$;

create or replace function app_private.form_worker_export_snapshot(
  p_file_job_id uuid,
  p_after_id uuid default null,
  p_limit integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare file_job public.form_file_jobs;
declare page_limit integer := least(greatest(coalesce(p_limit, 100), 1), 500);
begin
  select * into file_job
    from public.form_file_jobs
   where id = p_file_job_id
     and state in ('pending', 'processing')
     and expires_at > now();
  if file_job.id is null then
    raise no_data_found using message = 'form export job unavailable';
  end if;

  if file_job.export_kind = 'anonymous_participation' then
    return (
      with page as (
        select participation.id,
               coalesce(person_row.display_name, responder_row.display_name, '') as display_name,
               coalesce(membership_row.role_code, '') as profile_code,
               participation.response_unit_key as context_label,
               participation.response_state
          from public.form_participations participation
          join public.form_occurrences occurrence on occurrence.id = participation.occurrence_id
          left join public.people person_row on person_row.id = participation.person_id
          left join lateral (
            select responder_person.display_name, responder.person_id
              from public.form_participation_responders responder
              join public.people responder_person on responder_person.id = responder.person_id
             where responder.participation_id = participation.id
             order by responder.person_id
             limit 1
          ) responder_row on true
          left join lateral (
            select membership.role_code
              from public.institution_memberships membership
             where membership.person_id = coalesce(participation.person_id, responder_row.person_id)
               and membership.institution_id = participation.institution_id
               and membership.status = 'active'
             order by membership.id
             limit 1
          ) membership_row on true
         where occurrence.form_id = file_job.form_id
           and (file_job.occurrence_id is null or participation.occurrence_id = file_job.occurrence_id)
           and (p_after_id is null or participation.id > p_after_id)
         order by participation.id
         limit page_limit + 1
      ), visible as (select * from page limit page_limit)
      select jsonb_build_object(
        'kind', 'anonymous_participation',
        'rows', coalesce(jsonb_agg(jsonb_build_object(
          'Pessoa', display_name,
          'Perfil', coalesce(profile_code, ''),
          'Contexto', context_label,
          'Respondeu', case when response_state = 'responded' then 'Sim' else 'Não' end
        ) order by id), '[]'::jsonb),
        'has_more', (select count(*) > page_limit from page),
        'next_cursor', (select id from visible order by id desc limit 1)
      ) from visible
    );
  end if;

  return (
    with page as (
      select response.*
        from public.form_responses response
       where response.form_id = file_job.form_id
         and response.status = 'submitted'
         and (file_job.occurrence_id is null or response.occurrence_id = file_job.occurrence_id)
         and (p_after_id is null or response.id > p_after_id)
       order by response.id
       limit page_limit + 1
    ), visible as (
      select * from page limit page_limit
    ), submissions as (
      select response.id,
             jsonb_build_object(
               'responseId', response.id,
               'occurrenceId', response.occurrence_id,
               'versionId', response.form_version_id,
               'metadata', jsonb_build_object(
                 'form_id', response.form_id,
                 'identity_mode', response.identity_mode,
                 'respondent', case when response.identity_mode = 'identified'
                   then person_row.display_name else '' end,
                 'submitted_at', case when response.identity_mode = 'identified'
                   then response.submitted_at::text else '' end
               ),
               'answers', coalesce((
                 select jsonb_agg(jsonb_build_object(
                   'itemId', item.id,
                   'question', item.label,
                   'multiValued', item.kind in ('multiple_choice', 'photo', 'gallery'),
                   'values', case
                     when item.kind in ('single_choice', 'multiple_choice') then coalesce((
                       select jsonb_agg(option_row.label order by answer_option.position, option_row.position)
                         from public.form_answer_options answer_option
                         join public.form_question_options option_row on option_row.id = answer_option.option_id
                        where answer_option.answer_id = answer.id
                     ), '[]'::jsonb)
                     when item.kind in ('photo', 'gallery') then coalesce((
                       select jsonb_agg('/forms/media/' || asset.id::text order by answer_asset.position)
                         from public.form_answer_assets answer_asset
                         join public.form_assets asset on asset.id = answer_asset.asset_id
                        where answer_asset.answer_id = answer.id and asset.state = 'finalized'
                     ), '[]'::jsonb)
                     else jsonb_build_array(case answer.answer_kind
                       when 'short_text' then answer.text_value
                       when 'integer' then answer.integer_value::text
                       when 'decimal' then answer.decimal_value::text
                       when 'money' then answer.money_minor_units::text
                       when 'date' then answer.date_value::text
                       when 'yes_no' then case when answer.yes_no_value then 'Sim' else 'Não' end
                       when 'scale' then answer.scale_value::text
                       else '' end)
                   end
                 ) order by section.position, item.position, item.id)
                   from public.form_answers answer
                   join public.form_items item on item.id = answer.item_id
                   join public.form_sections section on section.id = item.section_id
                  where answer.response_id = response.id
               ), '[]'::jsonb)
             ) as payload
        from visible response
        left join public.people person_row on person_row.id = response.respondent_person_id
    )
    select jsonb_build_object(
      'kind', file_job.export_kind,
      'submissions', coalesce(jsonb_agg(payload order by id), '[]'::jsonb),
      'media', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'asset_id', media.asset_id,
          'storage_path', media.storage_path,
          'mime_type', media.mime_type
        ) order by media.asset_id), '[]'::jsonb)
          from (
            select distinct asset.id as asset_id, asset.storage_path, asset.mime_type
              from visible response_row
              join public.form_answers answer on answer.response_id = response_row.id
              join public.form_answer_assets answer_asset on answer_asset.answer_id = answer.id
              join public.form_assets asset on asset.id = answer_asset.asset_id
             where asset.state = 'finalized'
          ) media
      ),
      'has_more', (select count(*) > page_limit from page),
      'next_cursor', (select id from visible order by id desc limit 1)
    ) from submissions
  );
end;
$$;

create or replace function public.form_request_export(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_request_export($1, $2, $3, false) $$;
create or replace function public.form_request_anonymous_participation_export(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_request_export($1, $2, $3, true) $$;
create or replace function public.form_list_file_jobs(p_query jsonb)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.form_list_file_jobs($1) $$;
create or replace function public.form_anonymous_participation_lookup(p_query jsonb)
returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_anonymous_participation_lookup($1) $$;
create or replace function public.form_worker_claim(
  p_worker_id text, p_lease_seconds integer default 60, p_job_kinds text[] default null
)
returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_claim_worker_job($1, $2, $3) $$;
create or replace function public.form_worker_finish(p_job_id uuid, p_worker_id text, p_progress jsonb)
returns void language sql security definer set search_path = ''
as $$ select app_private.form_finish_worker_job($1, $2, $3) $$;
create or replace function public.form_worker_fail(
  p_job_id uuid, p_worker_id text, p_error_code text, p_retry_after_seconds integer, p_progress jsonb
) returns void language sql security definer set search_path = ''
as $$ select app_private.form_fail_worker_job($1, $2, $3, $4, $5) $$;
create or replace function public.form_worker_finalize_asset(
  p_asset_id uuid, p_actual_byte_length bigint, p_actual_mime_type text, p_actual_checksum_sha256 text
) returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_finalize_asset_for_worker($1, $2, $3, $4) $$;
create or replace function public.form_worker_export_snapshot(
  p_file_job_id uuid, p_after_id uuid default null, p_limit integer default 100
) returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.form_worker_export_snapshot($1, $2, $3) $$;
create or replace function public.form_worker_generate_due_occurrences(p_horizon_days integer default 90)
returns integer language sql security definer set search_path = ''
as $$ select app_private.form_generate_due_occurrences($1) $$;
create or replace function public.form_worker_generate_occurrences(
  p_schedule_id uuid, p_horizon_days integer default 90
)
returns integer language sql security definer set search_path = ''
as $$ select app_private.form_generate_occurrences($1, $2) $$;
create or replace function public.form_worker_reconcile_audience(p_occurrence_id uuid)
returns integer language sql security definer set search_path = ''
as $$ select app_private.form_reconcile_occurrence_audience($1) $$;
create or replace function public.form_worker_rebuild_metrics(p_occurrence_id uuid)
returns void language sql security definer set search_path = ''
as $$ select app_private.form_rebuild_occurrence_metrics($1) $$;
create or replace function public.form_worker_enqueue_reminders(
  p_horizon_seconds integer default 86400
)
returns integer language plpgsql security definer set search_path = ''
as $$
begin
  if p_horizon_seconds not between 60 and 604800 then
    raise invalid_parameter_value using message = 'reminder horizon seconds out of range';
  end if;
  return app_private.form_enqueue_due_reminders(make_interval(secs => p_horizon_seconds));
end;
$$;

do $$
declare table_name text;
begin
  foreach table_name in array array['form_occurrence_metrics', 'form_scope_metrics', 'form_file_jobs'] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
    execute format('revoke all on table public.%I from public, anon, authenticated', table_name);
  end loop;
end $$;

revoke all on table app_private.form_worker_jobs from public, anon, authenticated;
revoke all on function app_private.form_claim_worker_job(text, integer, text[]) from public, anon, authenticated;
revoke all on function app_private.form_finish_worker_job(uuid, text, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_fail_worker_job(uuid, text, text, integer, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_finalize_asset_for_worker(uuid, bigint, text, text) from public, anon, authenticated;
revoke all on function app_private.form_rebuild_occurrence_metrics(uuid) from public, anon, authenticated;
revoke all on function app_private.form_require_owner(uuid, text) from public, anon, authenticated;
revoke all on function app_private.form_request_export(uuid, bigint, jsonb, boolean) from public, anon, authenticated;
revoke all on function app_private.form_list_file_jobs(jsonb) from public, anon, authenticated;
revoke all on function app_private.form_anonymous_participation_lookup(jsonb) from public, anon, authenticated;
revoke all on function app_private.form_worker_export_snapshot(uuid, uuid, integer) from public, anon, authenticated;
revoke all on function app_private.form_generate_occurrences(uuid, integer) from public, anon, authenticated;
revoke all on function app_private.form_generate_due_occurrences(integer) from public, anon, authenticated;
revoke all on function app_private.form_resolve_person_audience(uuid) from public, anon, authenticated;
revoke all on function app_private.form_resolve_child_audience(uuid) from public, anon, authenticated;
revoke all on function app_private.form_reconcile_occurrence_audience(uuid) from public, anon, authenticated;
revoke all on function app_private.form_reconcile_due_audiences() from public, anon, authenticated;
revoke all on function app_private.form_enqueue_due_reminders(interval) from public, anon, authenticated;
revoke all on function app_private.form_run_periodic_maintenance() from public, anon, authenticated;
revoke all on function public.form_request_export(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_request_anonymous_participation_export(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_list_file_jobs(jsonb) from public, anon;
revoke all on function public.form_anonymous_participation_lookup(jsonb) from public, anon;
grant execute on function public.form_request_export(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_request_anonymous_participation_export(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_list_file_jobs(jsonb) to authenticated;
grant execute on function public.form_anonymous_participation_lookup(jsonb) to authenticated;
grant execute on function app_private.form_claim_worker_job(text, integer, text[]) to service_role;
grant execute on function app_private.form_finish_worker_job(uuid, text, jsonb) to service_role;
grant execute on function app_private.form_fail_worker_job(uuid, text, text, integer, jsonb) to service_role;
grant execute on function app_private.form_finalize_asset_for_worker(uuid, bigint, text, text) to service_role;
revoke all on function public.form_worker_claim(text, integer, text[]) from public, anon, authenticated;
revoke all on function public.form_worker_finish(uuid, text, jsonb) from public, anon, authenticated;
revoke all on function public.form_worker_fail(uuid, text, text, integer, jsonb) from public, anon, authenticated;
revoke all on function public.form_worker_finalize_asset(uuid, bigint, text, text) from public, anon, authenticated;
revoke all on function public.form_worker_export_snapshot(uuid, uuid, integer) from public, anon, authenticated;
revoke all on function public.form_worker_generate_due_occurrences(integer) from public, anon, authenticated;
revoke all on function public.form_worker_generate_occurrences(uuid, integer) from public, anon, authenticated;
revoke all on function public.form_worker_reconcile_audience(uuid) from public, anon, authenticated;
revoke all on function public.form_worker_rebuild_metrics(uuid) from public, anon, authenticated;
revoke all on function public.form_worker_enqueue_reminders(integer) from public, anon, authenticated;
grant execute on function public.form_worker_claim(text, integer, text[]) to service_role;
grant execute on function public.form_worker_finish(uuid, text, jsonb) to service_role;
grant execute on function public.form_worker_fail(uuid, text, text, integer, jsonb) to service_role;
grant execute on function public.form_worker_finalize_asset(uuid, bigint, text, text) to service_role;
grant execute on function public.form_worker_export_snapshot(uuid, uuid, integer) to service_role;
grant execute on function public.form_worker_generate_due_occurrences(integer) to service_role;
grant execute on function public.form_worker_generate_occurrences(uuid, integer) to service_role;
grant execute on function public.form_worker_reconcile_audience(uuid) to service_role;
grant execute on function public.form_worker_rebuild_metrics(uuid) to service_role;
grant execute on function public.form_worker_enqueue_reminders(integer) to service_role;
