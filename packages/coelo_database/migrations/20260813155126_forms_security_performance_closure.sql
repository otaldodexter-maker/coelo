create or replace function app_private.block_published_form_definition_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare version_id uuid;
begin
  if tg_table_name = 'form_versions' then
    if tg_op = 'DELETE' and old.state <> 'working' then
      raise insufficient_privilege using message = 'published form version is immutable';
    end if;
    if tg_op = 'UPDATE' then
      if old.form_id <> new.form_id
         or old.version_number <> new.version_number
         or old.created_by_person_id <> new.created_by_person_id
         or old.created_at <> new.created_at
         or not (
           (old.state = 'working' and new.state = 'published' and new.published_at is not null)
           or (old.state = 'published' and new.state = 'superseded' and new.published_at = old.published_at)
         ) then
        raise insufficient_privilege using message = 'published form version is immutable';
      end if;
    end if;
    return coalesce(new, old);
  end if;
  version_id := coalesce(new.form_version_id, old.form_version_id);
  if exists(select 1 from public.form_versions where id = version_id and state <> 'working') then
    raise insufficient_privilege using message = 'published form version is immutable';
  end if;
  return coalesce(new, old);
end;
$$;

create trigger form_versions_immutable
before update or delete on public.form_versions
for each row execute function app_private.block_published_form_definition_mutation();
create trigger form_sections_published_immutable
before insert or update or delete on public.form_sections
for each row execute function app_private.block_published_form_definition_mutation();
create trigger form_items_published_immutable
before insert or update or delete on public.form_items
for each row execute function app_private.block_published_form_definition_mutation();
create trigger form_options_published_immutable
before insert or update or delete on public.form_question_options
for each row execute function app_private.block_published_form_definition_mutation();
create trigger form_conditions_published_immutable
before insert or update or delete on public.form_question_conditions
for each row execute function app_private.block_published_form_definition_mutation();
create trigger form_item_assets_published_immutable
before insert or update or delete on public.form_item_assets
for each row execute function app_private.block_published_form_definition_mutation();

create or replace function app_private.block_form_identity_mode_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.first_published_at is not null and new.identity_mode <> old.identity_mode then
    raise check_violation using message = 'identity mode is immutable after first publication';
  end if;
  return new;
end;
$$;

create trigger forms_identity_mode_immutable
before update of identity_mode on public.forms
for each row execute function app_private.block_form_identity_mode_change();

create or replace function app_private.validate_form_tenant_links()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'form_applications' and not exists(
    select 1 from public.forms form_row
    where form_row.id = new.form_id and form_row.institution_id = new.institution_id
  ) then
    raise check_violation using message = 'form application tenant mismatch';
  elsif tg_table_name = 'form_audience_rules' and (
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
  elsif tg_table_name = 'form_occurrences' and not exists(
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
  elsif tg_table_name = 'form_responses' and not exists(
    select 1 from public.form_occurrences occurrence_row
    where occurrence_row.id = new.occurrence_id
      and occurrence_row.institution_id = new.institution_id
      and occurrence_row.form_id = new.form_id
      and occurrence_row.form_version_id = new.form_version_id
  ) then
    raise check_violation using message = 'form response tenant or version mismatch';
  elsif tg_table_name = 'form_answers' and not exists(
    select 1
      from public.form_responses response_row
      join public.form_items item_row on item_row.id = new.item_id
     where response_row.id = new.response_id
       and response_row.form_version_id = new.form_version_id
       and item_row.form_version_id = new.form_version_id
  ) then
    raise check_violation using message = 'form answer version mismatch';
  elsif tg_table_name = 'form_participations' and (
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
  elsif tg_table_name = 'form_participation_responders' and not exists(
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
  elsif tg_table_name = 'form_assets' and not exists(
    select 1
      from public.form_occurrences occurrence
      join public.form_items item on item.id = new.item_id
     where occurrence.id = new.occurrence_id
       and occurrence.institution_id = new.institution_id
       and item.form_version_id = occurrence.form_version_id
  ) then
    raise check_violation using message = 'form asset tenant or version mismatch';
  elsif tg_table_name = 'form_file_jobs' and not exists(
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
end;
$$;

create trigger form_applications_tenant_validate
before insert or update on public.form_applications
for each row execute function app_private.validate_form_tenant_links();
create trigger form_audience_rules_tenant_validate
before insert or update on public.form_audience_rules
for each row execute function app_private.validate_form_tenant_links();
create trigger form_occurrences_tenant_validate
before insert or update on public.form_occurrences
for each row execute function app_private.validate_form_tenant_links();
create trigger form_responses_tenant_validate
before insert or update on public.form_responses
for each row execute function app_private.validate_form_tenant_links();
create trigger form_answers_version_validate
before insert or update on public.form_answers
for each row execute function app_private.validate_form_tenant_links();
create trigger form_participations_tenant_validate
before insert or update on public.form_participations
for each row execute function app_private.validate_form_tenant_links();
create trigger form_participation_responders_tenant_validate
before insert or update on public.form_participation_responders
for each row execute function app_private.validate_form_tenant_links();
create trigger form_assets_tenant_validate
before insert or update on public.form_assets
for each row execute function app_private.validate_form_tenant_links();
create trigger form_file_jobs_tenant_validate
before insert or update on public.form_file_jobs
for each row execute function app_private.validate_form_tenant_links();

create or replace function public.form_media_authorize_for_worker(
  p_asset_id uuid,
  p_actor_person_id uuid,
  p_edit_secret text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare asset_row public.form_assets;
begin
  select * into asset_row from public.form_assets
   where id = p_asset_id and state in ('uploaded', 'finalized');
  if asset_row.id is null or not (
    (asset_row.prepared_by_person_id = p_actor_person_id)
    or (
      asset_row.prepared_by_person_id is null
      and app_private.form_verify_anonymous_edit_secret(
        p_edit_secret, asset_row.anonymous_upload_secret_hash
      )
    )
    or (asset_row.state = 'finalized'
      and exists (
        select 1 from public.form_answer_assets answer_asset
         where answer_asset.asset_id = asset_row.id
      )
      and app_private.audit_actor_has_permission(
        p_actor_person_id, 'forms.responses.read', asset_row.institution_id, false
      ))
  ) then
    raise no_data_found using message = 'form asset unavailable';
  end if;
  return jsonb_build_object(
    'asset_id', asset_row.id, 'storage_path', asset_row.storage_path,
    'mime_type', asset_row.mime_type, 'byte_length', asset_row.actual_byte_length,
    'state', asset_row.state
  );
end;
$$;

alter table public.context_notification_recipients
  add column if not exists delivery_lease_owner text,
  add column if not exists delivery_lease_expires_at timestamptz,
  add column if not exists next_delivery_attempt_at timestamptz not null default now(),
  add constraint context_notification_recipients_delivery_state_ck
  check (delivery_state in ('pending', 'processing', 'delivered', 'failed', 'cancelled')),
  add constraint context_notification_recipients_delivery_attempts_ck
  check (delivery_attempts between 0 and 20);

create index context_notification_recipients_forms_delivery_idx
  on public.context_notification_recipients(next_delivery_attempt_at, created_at, event_id, person_id)
  where delivery_state in ('pending', 'failed', 'processing');

create or replace function app_private.form_claim_notification_delivery(
  p_worker_id text,
  p_lease_seconds integer default 60
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare recipient_row public.context_notification_recipients;
declare event_row public.context_notification_events;
begin
  if nullif(btrim(p_worker_id), '') is null or p_lease_seconds not between 10 and 600 then
    raise invalid_parameter_value using message = 'valid notification worker lease required';
  end if;
  update public.context_notification_recipients recipient
     set delivery_state = 'failed',
         last_delivery_error_code = 'delivery_attempts_exhausted',
         delivery_lease_owner = null,
         delivery_lease_expires_at = null
    from public.context_notification_events event
   where event.id = recipient.event_id
     and event.event_code like 'forms.reminder.%'
     and recipient.delivery_state = 'processing'
     and recipient.delivery_attempts >= 20
     and recipient.delivery_lease_expires_at < now();
  update public.context_notification_recipients recipient
     set delivery_state = 'processing',
         delivery_attempts = delivery_attempts + 1,
         delivery_lease_owner = p_worker_id,
         delivery_lease_expires_at = now() + make_interval(secs => p_lease_seconds)
   where (recipient.event_id, recipient.person_id) = (
     select candidate.event_id, candidate.person_id
       from public.context_notification_recipients candidate
       join public.context_notification_events event on event.id = candidate.event_id
      where event.event_code like 'forms.reminder.%'
        and event.deliver_at <= now()
        and candidate.delivery_attempts < 20
        and (
          (candidate.delivery_state in ('pending', 'failed')
            and candidate.next_delivery_attempt_at <= now())
          or (candidate.delivery_state = 'processing'
            and candidate.delivery_lease_expires_at < now())
        )
      order by candidate.next_delivery_attempt_at, candidate.created_at,
               candidate.event_id, candidate.person_id
      limit 1 for update of candidate skip locked
   )
  returning * into recipient_row;
  if recipient_row.event_id is null then return null; end if;
  select * into event_row from public.context_notification_events
   where id = recipient_row.event_id;
  return jsonb_build_object(
    'event_id', event_row.id,
    'person_id', recipient_row.person_id,
    'event_code', event_row.event_code,
    'payload', event_row.payload_json,
    'attempt', recipient_row.delivery_attempts
  );
end;
$$;

create or replace function app_private.form_complete_notification_delivery(
  p_event_id uuid,
  p_person_id uuid,
  p_worker_id text,
  p_delivered boolean,
  p_error_code text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not coalesce(p_delivered, false) and nullif(btrim(p_error_code), '') is null then
    raise invalid_parameter_value using message = 'notification delivery error required';
  end if;
  update public.context_notification_recipients
     set delivery_state = case when p_delivered then 'delivered' else 'failed' end,
         delivered_at = case when p_delivered then now() else null end,
         last_delivery_error_code = case when p_delivered then null else left(p_error_code, 100) end,
         next_delivery_attempt_at = case when p_delivered then next_delivery_attempt_at
           else now() + make_interval(secs => least(3600, (30 * power(2, least(delivery_attempts, 7)))::integer)) end,
         delivery_lease_owner = null,
         delivery_lease_expires_at = null
   where event_id = p_event_id and person_id = p_person_id
     and delivery_state = 'processing'
     and delivery_lease_owner = p_worker_id
     and delivery_lease_expires_at >= now();
  if not found then raise serialization_failure using message = 'notification delivery lease unavailable'; end if;
end;
$$;

create or replace function public.form_worker_claim_notification(text, integer default 60)
returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_claim_notification_delivery($1, $2) $$;
create or replace function public.form_worker_complete_notification(uuid, uuid, text, boolean, text default null)
returns void language sql security definer set search_path = ''
as $$ select app_private.form_complete_notification_delivery($1, $2, $3, $4, $5) $$;

revoke update on table public.context_notification_recipients from authenticated;
grant update(read_at) on table public.context_notification_recipients to authenticated;
revoke all on function app_private.form_claim_notification_delivery(text, integer) from public, anon, authenticated;
revoke all on function app_private.form_complete_notification_delivery(uuid, uuid, text, boolean, text) from public, anon, authenticated;
revoke all on function public.form_worker_claim_notification(text, integer) from public, anon, authenticated;
revoke all on function public.form_worker_complete_notification(uuid, uuid, text, boolean, text) from public, anon, authenticated;
grant execute on function public.form_worker_claim_notification(text, integer) to service_role;
grant execute on function public.form_worker_complete_notification(uuid, uuid, text, boolean, text) to service_role;

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'forms', 'form_versions', 'form_sections', 'form_items', 'form_question_options',
    'form_question_conditions', 'form_item_assets', 'form_applications', 'form_audience_rules',
    'form_schedules', 'form_schedule_reminders', 'form_occurrences', 'form_participations',
    'form_participation_responders', 'form_responses', 'form_answers', 'form_answer_options',
    'form_assets', 'form_answer_assets', 'form_response_revisions', 'form_occurrence_metrics',
    'form_scope_metrics', 'form_file_jobs'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
    execute format('revoke all on table public.%I from public, anon, authenticated', table_name);
  end loop;
end $$;

revoke all on function app_private.block_published_form_definition_mutation() from public, anon, authenticated;
revoke all on function app_private.block_form_identity_mode_change() from public, anon, authenticated;
revoke all on function app_private.validate_form_tenant_links() from public, anon, authenticated;
revoke all on function public.form_media_authorize_for_worker(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.form_media_authorize_for_worker(uuid, uuid, text) to service_role;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

create or replace function app_private.form_dispatch_operations_worker()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare worker_url text;
declare bearer_token text;
declare request_id bigint;
begin
  select decrypted_secret into worker_url
    from vault.decrypted_secrets where name = 'forms_worker_url' limit 1;
  select decrypted_secret into bearer_token
    from vault.decrypted_secrets where name = 'forms_worker_bearer_token' limit 1;
  if nullif(worker_url, '') is null or nullif(bearer_token, '') is null then
    return null;
  end if;
  select net.http_post(
    url := worker_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || bearer_token
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 5000
  ) into request_id;
  return request_id;
end;
$$;

select cron.schedule(
  'coelo-forms-occurrences',
  '*/5 * * * *',
  $cron$select app_private.form_run_periodic_maintenance();$cron$
);
select cron.schedule(
  'coelo-forms-reminders',
  '2-59/5 * * * *',
  $cron$select app_private.form_enqueue_due_reminders(interval '24 hours');$cron$
);
select cron.schedule(
  'coelo-forms-worker-dispatch',
  '* * * * *',
  $cron$select app_private.form_dispatch_operations_worker();$cron$
);

revoke all on function app_private.form_dispatch_operations_worker() from public, anon, authenticated;

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
   where id = p_job_id and state = 'processing' and lease_owner = p_worker_id
     and lease_expires_at >= now();
  if not found then raise serialization_failure using message = 'worker lease unavailable'; end if;
end;
$$;

create or replace function app_private.form_worker_begin_export(
  p_job_id uuid,
  p_worker_id text,
  p_file_job_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare worker_job app_private.form_worker_jobs;
begin
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id
     and job_kind in ('export_csv', 'export_xlsx', 'export_zip', 'export_anonymous_participation')
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise serialization_failure using message = 'worker lease unavailable';
  end if;
  update public.form_file_jobs
     set state = 'processing', started_at = coalesce(started_at, now()), progress = greatest(progress, 0.05),
         error_code = null
   where id = p_file_job_id and state in ('pending', 'processing', 'failed') and expires_at > now();
  if not found then
    raise no_data_found using message = 'form export job unavailable';
  end if;
end;
$$;

create or replace function app_private.form_worker_complete_export(
  p_job_id uuid,
  p_worker_id text,
  p_file_job_id uuid,
  p_artifact_path text,
  p_artifact_byte_length bigint,
  p_manifest jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare worker_job app_private.form_worker_jobs;
begin
  if p_artifact_path is null or p_artifact_path !~ '^[0-9a-f]{2}/[0-9a-f-]{36}$'
     or p_artifact_byte_length is null or p_artifact_byte_length < 1
     or p_manifest is null or jsonb_typeof(p_manifest) <> 'object' then
    raise invalid_parameter_value using message = 'invalid export artifact';
  end if;
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id
     and job_kind in ('export_csv', 'export_xlsx', 'export_zip', 'export_anonymous_participation')
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise serialization_failure using message = 'worker lease unavailable';
  end if;
  update public.form_file_jobs
     set state = 'succeeded', progress = 1, artifact_path = p_artifact_path,
         artifact_byte_length = p_artifact_byte_length, manifest_jsonb = p_manifest,
         completed_at = now(), error_code = null
   where id = p_file_job_id and state = 'processing' and expires_at > now();
  if not found then
    raise no_data_found using message = 'form export job unavailable';
  end if;
  update app_private.form_worker_jobs
     set state = 'succeeded', progress_jsonb = jsonb_build_object('completed', true),
         completed_at = now(), lease_owner = null, lease_expires_at = null
   where id = worker_job.id;
end;
$$;

create or replace function app_private.form_worker_fail_export(
  p_job_id uuid,
  p_worker_id text,
  p_file_job_id uuid,
  p_error_code text,
  p_retry_after_seconds integer default 60
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare worker_job app_private.form_worker_jobs;
declare file_state text;
begin
  if nullif(btrim(p_error_code), '') is null then
    raise invalid_parameter_value using message = 'export error code required';
  end if;
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id
     and job_kind in ('export_csv', 'export_xlsx', 'export_zip', 'export_anonymous_participation')
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise serialization_failure using message = 'worker lease unavailable';
  end if;
  update public.form_file_jobs
     set state = case when expires_at <= now() then 'expired' else 'failed' end,
         error_code = left(p_error_code, 100)
   where id = p_file_job_id and state in ('pending', 'processing')
   returning state into file_state;
  if file_state is null then
    raise no_data_found using message = 'form export job unavailable';
  end if;
  update app_private.form_worker_jobs
     set state = case when file_state = 'expired' then 'succeeded' else 'failed' end,
         last_error_code = left(p_error_code, 100),
         progress_jsonb = jsonb_build_object('completed', false),
         available_at = now() + make_interval(secs => least(greatest(p_retry_after_seconds, 1), 86400)),
         completed_at = case when file_state = 'expired' then now() else null end,
         lease_owner = null, lease_expires_at = null
   where id = worker_job.id;
end;
$$;

create or replace function app_private.form_worker_cleanup_snapshot(
  p_job_id uuid,
  p_worker_id text,
  p_limit integer default 100
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare worker_job app_private.form_worker_jobs;
declare page_limit integer := least(greatest(coalesce(p_limit, 100), 1), 200);
declare result jsonb;
begin
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and job_kind in ('cleanup_uploads', 'cleanup_artifacts')
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise serialization_failure using message = 'worker lease unavailable';
  end if;
  if worker_job.job_kind = 'cleanup_uploads' then
    select jsonb_build_object(
      'kind', worker_job.job_kind,
      'items', coalesce(jsonb_agg(jsonb_build_object('id', id, 'storage_path', storage_path)), '[]'::jsonb)
    ) into result
      from (
        select id, storage_path from public.form_assets
         where (state in ('prepared', 'uploaded') and expires_at <= now())
            or (state = 'discarded' and discarded_at is not null)
         order by expires_at, id limit page_limit
      ) candidate;
  else
    select jsonb_build_object(
      'kind', worker_job.job_kind,
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'id', id,
        'storage_path', storage_path,
        'multipart_bucket', multipart_bucket,
        'multipart_path', multipart_path,
        'multipart_upload_id', multipart_upload_id
      )), '[]'::jsonb)
    ) into result
      from (
        select file_job.id, file_job.artifact_path as storage_path,
               multipart.bucket_id as multipart_bucket,
               multipart.object_path as multipart_path,
               multipart.upload_id as multipart_upload_id
          from public.form_file_jobs file_job
          left join app_private.form_multipart_uploads multipart
            on multipart.file_job_id = file_job.id
           and multipart.state in ('initiated', 'uploading')
         where file_job.state in ('pending', 'succeeded', 'partial', 'failed')
           and file_job.expires_at <= now()
         order by file_job.expires_at, file_job.id limit page_limit
      ) candidate;
  end if;
  return result;
end;
$$;

create or replace function app_private.form_worker_complete_cleanup(
  p_job_id uuid,
  p_worker_id text,
  p_item_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare worker_job app_private.form_worker_jobs;
declare completed_count integer;
declare requested_count integer := coalesce(cardinality(p_item_ids), 0);
begin
  if p_item_ids is null or requested_count > 200
     or requested_count <> (
       select count(distinct item_id) from unnest(p_item_ids) as items(item_id)
     ) then
    raise invalid_parameter_value using message = 'invalid cleanup items';
  end if;
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and job_kind in ('cleanup_uploads', 'cleanup_artifacts')
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise serialization_failure using message = 'worker lease unavailable';
  end if;
  if worker_job.job_kind = 'cleanup_uploads' then
    update public.form_assets
       set state = 'expired'
     where id = any(p_item_ids) and (
       (state in ('prepared', 'uploaded') and expires_at <= now())
       or (state = 'discarded' and discarded_at is not null)
     );
  else
    update app_private.form_multipart_uploads multipart
       set state = 'aborted', aborted_at = now(), updated_at = now()
      where multipart.file_job_id = any(p_item_ids)
        and multipart.state in ('initiated', 'uploading')
        and exists (
          select 1 from public.form_file_jobs file_job
           where file_job.id = multipart.file_job_id
             and file_job.expires_at <= now()
        );
    update public.form_file_jobs
       set state = 'expired', artifact_path = null, artifact_byte_length = null
     where id = any(p_item_ids) and state in ('pending', 'succeeded', 'partial', 'failed') and expires_at <= now();
  end if;
  get diagnostics completed_count = row_count;
  if completed_count <> requested_count then
    raise serialization_failure using message = 'cleanup items unavailable';
  end if;
  update app_private.form_worker_jobs
     set state = 'succeeded', progress_jsonb = jsonb_build_object('completed', true, 'items', completed_count),
         completed_at = now(), lease_owner = null, lease_expires_at = null
   where id = worker_job.id;
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
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('coelo-forms-cleanup-uploads'));
  if not exists(
    select 1 from app_private.form_worker_jobs
     where job_kind = 'cleanup_uploads' and state in ('pending', 'processing')
  ) then
    insert into app_private.form_worker_jobs(job_kind) values ('cleanup_uploads');
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('coelo-forms-cleanup-artifacts'));
  if not exists(
    select 1 from app_private.form_worker_jobs
     where job_kind = 'cleanup_artifacts' and state in ('pending', 'processing')
  ) then
    insert into app_private.form_worker_jobs(job_kind) values ('cleanup_artifacts');
  end if;
  return jsonb_build_object(
    'generated_occurrences', generated,
    'reconciled_participations', reconciled
  );
end;
$$;

create or replace function app_private.form_worker_multipart_snapshot(
  p_job_id uuid,
  p_worker_id text,
  p_file_job_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare worker_job app_private.form_worker_jobs;
declare upload_row app_private.form_multipart_uploads;
begin
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id and job_kind = 'export_zip'
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now();
  if worker_job.id is null then
    raise serialization_failure using message = 'worker lease unavailable';
  end if;
  select * into upload_row from app_private.form_multipart_uploads
   where file_job_id = p_file_job_id and worker_job_id = p_job_id and state <> 'aborted';
  if upload_row.id is null then return null; end if;
  return jsonb_build_object(
    'bucket_id', upload_row.bucket_id,
    'object_path', upload_row.object_path,
    'upload_id', upload_row.upload_id,
    'state', upload_row.state,
    'next_part_number', upload_row.next_part_number,
    'uploaded_bytes', upload_row.uploaded_bytes,
    'parts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'part_number', part.part_number,
        'etag', part.etag,
        'byte_length', part.byte_length,
        'checksum_sha256', part.checksum_sha256
      ) order by part.part_number)
      from app_private.form_multipart_parts part
      where part.multipart_upload_id = upload_row.id
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function app_private.form_worker_begin_multipart(
  p_job_id uuid,
  p_worker_id text,
  p_file_job_id uuid,
  p_bucket_id text,
  p_object_path text,
  p_upload_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare worker_job app_private.form_worker_jobs;
declare file_job public.form_file_jobs;
declare upload_row app_private.form_multipart_uploads;
begin
  if p_bucket_id <> 'coelo-forms-private'
     or p_object_path is null or p_object_path !~ '^[0-9a-f]{2}/[0-9a-f-]{36}$'
     or nullif(btrim(p_upload_id), '') is null or length(p_upload_id) > 1024
     or p_upload_id ~ '[[:cntrl:]]' then
    raise invalid_parameter_value using message = 'invalid multipart upload';
  end if;
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id and job_kind = 'export_zip'
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise serialization_failure using message = 'worker lease unavailable';
  end if;
  select * into file_job from public.form_file_jobs
   where id = p_file_job_id and export_kind = 'zip' and state = 'processing' and expires_at > now()
   for update;
  if file_job.id is null then
    raise no_data_found using message = 'form export job unavailable';
  end if;
  select * into upload_row from app_private.form_multipart_uploads
   where file_job_id = p_file_job_id for update;
  if upload_row.id is null then
    insert into app_private.form_multipart_uploads(
      file_job_id, worker_job_id, bucket_id, object_path, upload_id
    ) values (
      p_file_job_id, p_job_id, p_bucket_id, p_object_path, p_upload_id
    ) returning * into upload_row;
  elsif upload_row.worker_job_id <> p_job_id
     or upload_row.bucket_id <> p_bucket_id
     or upload_row.object_path <> p_object_path
     or upload_row.upload_id <> p_upload_id then
    raise serialization_failure using message = 'multipart upload already initialized';
  end if;
  update app_private.form_worker_jobs
     set progress_jsonb = progress_jsonb || jsonb_build_object(
       'multipart_upload_id', upload_row.id,
       'next_part_number', upload_row.next_part_number,
       'uploaded_bytes', upload_row.uploaded_bytes
     )
   where id = worker_job.id;
  return jsonb_build_object(
    'multipart_upload_id', upload_row.id,
    'state', upload_row.state,
    'next_part_number', upload_row.next_part_number,
    'uploaded_bytes', upload_row.uploaded_bytes
  );
end;
$$;

create or replace function app_private.form_worker_record_multipart_part(
  p_job_id uuid,
  p_worker_id text,
  p_file_job_id uuid,
  p_upload_id text,
  p_part_number integer,
  p_etag text,
  p_byte_length bigint,
  p_checksum_sha256 text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare worker_job app_private.form_worker_jobs;
declare upload_row app_private.form_multipart_uploads;
declare part_row app_private.form_multipart_parts;
begin
  if p_part_number not between 1 and 10000
     or nullif(btrim(p_etag), '') is null or length(p_etag) > 1024 or p_etag ~ '[[:cntrl:]]'
     or p_byte_length is null or p_byte_length < 1
     or p_checksum_sha256 is null or p_checksum_sha256 !~ '^[0-9a-f]{64}$' then
    raise invalid_parameter_value using message = 'invalid multipart part';
  end if;
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id and job_kind = 'export_zip'
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise serialization_failure using message = 'worker lease unavailable';
  end if;
  select * into upload_row from app_private.form_multipart_uploads
   where file_job_id = p_file_job_id and worker_job_id = p_job_id and upload_id = p_upload_id
   for update;
  if upload_row.id is null or upload_row.state not in ('initiated', 'uploading') then
    raise no_data_found using message = 'multipart upload unavailable';
  end if;
  select * into part_row from app_private.form_multipart_parts
   where multipart_upload_id = upload_row.id and part_number = p_part_number;
  if part_row.multipart_upload_id is not null then
    if part_row.etag <> p_etag or part_row.byte_length <> p_byte_length
       or part_row.checksum_sha256 <> p_checksum_sha256 then
      raise serialization_failure using message = 'multipart part replay mismatch';
    end if;
  else
    if p_part_number <> upload_row.next_part_number then
      raise serialization_failure using message = 'multipart part out of sequence';
    end if;
    insert into app_private.form_multipart_parts(
      multipart_upload_id, part_number, etag, byte_length, checksum_sha256
    ) values (
      upload_row.id, p_part_number, p_etag, p_byte_length, p_checksum_sha256
    );
    update app_private.form_multipart_uploads
       set state = 'uploading', next_part_number = next_part_number + 1,
           uploaded_bytes = uploaded_bytes + p_byte_length, updated_at = now()
     where id = upload_row.id
     returning * into upload_row;
  end if;
  update app_private.form_worker_jobs
     set progress_jsonb = progress_jsonb || jsonb_build_object(
       'multipart_upload_id', upload_row.id,
       'next_part_number', upload_row.next_part_number,
       'uploaded_bytes', upload_row.uploaded_bytes
     )
   where id = worker_job.id;
  update public.form_file_jobs set progress = greatest(progress, 0.1)
   where id = p_file_job_id;
  return jsonb_build_object(
    'multipart_upload_id', upload_row.id,
    'state', upload_row.state,
    'next_part_number', upload_row.next_part_number,
    'uploaded_bytes', upload_row.uploaded_bytes
  );
end;
$$;

create or replace function app_private.form_worker_complete_multipart(
  p_job_id uuid,
  p_worker_id text,
  p_file_job_id uuid,
  p_upload_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare worker_job app_private.form_worker_jobs;
declare upload_row app_private.form_multipart_uploads;
begin
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id and job_kind = 'export_zip'
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise serialization_failure using message = 'worker lease unavailable';
  end if;
  select * into upload_row from app_private.form_multipart_uploads
   where file_job_id = p_file_job_id and worker_job_id = p_job_id and upload_id = p_upload_id
   for update;
  if upload_row.id is null or upload_row.state = 'aborted' then
    raise no_data_found using message = 'multipart upload unavailable';
  end if;
  if upload_row.state <> 'completed' then
    if not exists(
      select 1 from app_private.form_multipart_parts
       where multipart_upload_id = upload_row.id
    ) then
      raise check_violation using message = 'multipart upload has no parts';
    end if;
    update app_private.form_multipart_uploads
       set state = 'completed', completed_at = now(), updated_at = now()
     where id = upload_row.id
     returning * into upload_row;
  end if;
  update app_private.form_worker_jobs
     set progress_jsonb = progress_jsonb || jsonb_build_object(
       'multipart_upload_id', upload_row.id,
       'multipart_completed', true,
       'uploaded_bytes', upload_row.uploaded_bytes
     )
   where id = worker_job.id;
  update public.form_file_jobs set progress = greatest(progress, 0.95)
   where id = p_file_job_id;
  return jsonb_build_object(
    'multipart_upload_id', upload_row.id,
    'state', upload_row.state,
    'part_count', upload_row.next_part_number - 1,
    'uploaded_bytes', upload_row.uploaded_bytes
  );
end;
$$;

create or replace function app_private.form_worker_abort_multipart(
  p_job_id uuid,
  p_worker_id text,
  p_file_job_id uuid,
  p_upload_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare worker_job app_private.form_worker_jobs;
declare upload_row app_private.form_multipart_uploads;
begin
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id and job_kind = 'export_zip'
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise serialization_failure using message = 'worker lease unavailable';
  end if;
  select * into upload_row from app_private.form_multipart_uploads
   where file_job_id = p_file_job_id and worker_job_id = p_job_id and upload_id = p_upload_id
   for update;
  if upload_row.id is null or upload_row.state = 'completed' then
    raise no_data_found using message = 'multipart upload unavailable';
  end if;
  if upload_row.state <> 'aborted' then
    update app_private.form_multipart_uploads
       set state = 'aborted', aborted_at = now(), updated_at = now()
     where id = upload_row.id
     returning * into upload_row;
  end if;
  update app_private.form_worker_jobs
     set progress_jsonb = progress_jsonb || jsonb_build_object(
       'multipart_upload_id', upload_row.id,
       'multipart_aborted', true,
       'uploaded_bytes', upload_row.uploaded_bytes
     )
   where id = worker_job.id;
  return jsonb_build_object(
    'multipart_upload_id', upload_row.id,
    'state', upload_row.state,
    'uploaded_bytes', upload_row.uploaded_bytes
  );
end;
$$;

create or replace function public.form_worker_begin_export(uuid, text, uuid)
returns void language sql security definer set search_path = ''
as $$ select app_private.form_worker_begin_export($1, $2, $3) $$;
create or replace function public.form_worker_complete_export(uuid, text, uuid, text, bigint, jsonb)
returns void language sql security definer set search_path = ''
as $$ select app_private.form_worker_complete_export($1, $2, $3, $4, $5, $6) $$;
create or replace function public.form_worker_fail_export(uuid, text, uuid, text, integer)
returns void language sql security definer set search_path = ''
as $$ select app_private.form_worker_fail_export($1, $2, $3, $4, $5) $$;
create or replace function public.form_worker_cleanup_snapshot(uuid, text, integer default 100)
returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_worker_cleanup_snapshot($1, $2, $3) $$;
create or replace function public.form_worker_complete_cleanup(uuid, text, uuid[])
returns void language sql security definer set search_path = ''
as $$ select app_private.form_worker_complete_cleanup($1, $2, $3) $$;
create or replace function public.form_worker_begin_multipart(
  p_job_id uuid, p_worker_id text, p_file_job_id uuid,
  p_bucket_id text, p_object_path text, p_upload_id text
)
returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_worker_begin_multipart($1, $2, $3, $4, $5, $6) $$;
create or replace function public.form_worker_multipart_snapshot(
  p_job_id uuid, p_worker_id text, p_file_job_id uuid
)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.form_worker_multipart_snapshot($1, $2, $3) $$;
create or replace function public.form_worker_record_multipart_part(
  p_job_id uuid, p_worker_id text, p_file_job_id uuid, p_upload_id text,
  p_part_number integer, p_etag text, p_byte_length bigint, p_checksum_sha256 text
)
returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_worker_record_multipart_part($1, $2, $3, $4, $5, $6, $7, $8) $$;
create or replace function public.form_worker_complete_multipart(
  p_job_id uuid, p_worker_id text, p_file_job_id uuid, p_upload_id text
)
returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_worker_complete_multipart($1, $2, $3, $4) $$;
create or replace function public.form_worker_abort_multipart(
  p_job_id uuid, p_worker_id text, p_file_job_id uuid, p_upload_id text
)
returns jsonb language sql security definer set search_path = ''
as $$ select app_private.form_worker_abort_multipart($1, $2, $3, $4) $$;

revoke all on function app_private.form_fail_worker_job(uuid, text, text, integer, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_worker_begin_export(uuid, text, uuid) from public, anon, authenticated;
revoke all on function app_private.form_worker_complete_export(uuid, text, uuid, text, bigint, jsonb) from public, anon, authenticated;
revoke all on function app_private.form_worker_fail_export(uuid, text, uuid, text, integer) from public, anon, authenticated;
revoke all on function app_private.form_worker_cleanup_snapshot(uuid, text, integer) from public, anon, authenticated;
revoke all on function app_private.form_worker_complete_cleanup(uuid, text, uuid[]) from public, anon, authenticated;
revoke all on function public.form_worker_begin_export(uuid, text, uuid) from public, anon, authenticated;
revoke all on function public.form_worker_complete_export(uuid, text, uuid, text, bigint, jsonb) from public, anon, authenticated;
revoke all on function public.form_worker_fail_export(uuid, text, uuid, text, integer) from public, anon, authenticated;
revoke all on function public.form_worker_cleanup_snapshot(uuid, text, integer) from public, anon, authenticated;
revoke all on function public.form_worker_complete_cleanup(uuid, text, uuid[]) from public, anon, authenticated;
grant execute on function public.form_worker_begin_export(uuid, text, uuid) to service_role;
grant execute on function public.form_worker_complete_export(uuid, text, uuid, text, bigint, jsonb) to service_role;
grant execute on function public.form_worker_fail_export(uuid, text, uuid, text, integer) to service_role;
grant execute on function public.form_worker_cleanup_snapshot(uuid, text, integer) to service_role;
grant execute on function public.form_worker_complete_cleanup(uuid, text, uuid[]) to service_role;
revoke all on table app_private.form_multipart_uploads from public, anon, authenticated;
revoke all on table app_private.form_multipart_parts from public, anon, authenticated;
revoke all on function app_private.form_worker_multipart_snapshot(uuid, text, uuid) from public, anon, authenticated;
revoke all on function app_private.form_worker_begin_multipart(uuid, text, uuid, text, text, text) from public, anon, authenticated;
revoke all on function app_private.form_worker_record_multipart_part(uuid, text, uuid, text, integer, text, bigint, text) from public, anon, authenticated;
revoke all on function app_private.form_worker_complete_multipart(uuid, text, uuid, text) from public, anon, authenticated;
revoke all on function app_private.form_worker_abort_multipart(uuid, text, uuid, text) from public, anon, authenticated;
revoke all on function public.form_worker_begin_multipart(uuid, text, uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.form_worker_record_multipart_part(uuid, text, uuid, text, integer, text, bigint, text) from public, anon, authenticated;
revoke all on function public.form_worker_complete_multipart(uuid, text, uuid, text) from public, anon, authenticated;
revoke all on function public.form_worker_abort_multipart(uuid, text, uuid, text) from public, anon, authenticated;
revoke all on function public.form_worker_multipart_snapshot(uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.form_worker_begin_multipart(uuid, text, uuid, text, text, text) to service_role;
grant execute on function public.form_worker_record_multipart_part(uuid, text, uuid, text, integer, text, bigint, text) to service_role;
grant execute on function public.form_worker_complete_multipart(uuid, text, uuid, text) to service_role;
grant execute on function public.form_worker_abort_multipart(uuid, text, uuid, text) to service_role;
grant execute on function public.form_worker_multipart_snapshot(uuid, text, uuid) to service_role;
