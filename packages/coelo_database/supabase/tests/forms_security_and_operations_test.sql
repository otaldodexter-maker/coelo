begin;

create extension if not exists pgtap with schema extensions;
select plan(70);

select has_table('public', 'form_applications', 'applications exist');
select has_table('public', 'form_audience_rules', 'audience rules are normalized');
select has_table('public', 'form_schedules', 'schedules exist');
select has_table('public', 'form_schedule_reminders', 'reminders exist');
select ok(
  not exists(
    select 1
      from pg_constraint constraint_row
     where constraint_row.conrelid = 'public.form_schedules'::regclass
       and constraint_row.contype = 'u'
       and constraint_row.conkey = array[
         (select attnum
            from pg_attribute
           where attrelid = 'public.form_schedules'::regclass
             and attname = 'application_id'
             and not attisdropped)
       ]::smallint[]
  ),
  'an application accepts independent schedules'
);
select ok(
  exists(
    select 1
      from pg_constraint constraint_row
     where constraint_row.conrelid = 'public.form_occurrences'::regclass
       and constraint_row.contype = 'f'
       and constraint_row.confrelid = 'public.form_schedules'::regclass
  )
  and exists(
    select 1 from pg_indexes
     where schemaname = 'public'
       and indexname = 'form_occurrences_schedule_local_uidx'
  ),
  'occurrences retain their schedule and deduplicate per schedule'
);
select ok(
  pg_get_functiondef('app_private.form_save_schedule(uuid,bigint,jsonb)'::regprocedure)
    like '%schedule_id%'
  and pg_get_functiondef('app_private.form_remove_schedule(uuid,bigint,jsonb)'::regprocedure)
    like '%schedule_id%'
  and pg_get_functiondef('app_private.form_application_projection(uuid)'::regprocedure)
    like '%''schedules''%'
  and pg_get_functiondef('app_private.form_application_projection(uuid)'::regprocedure)
    like '%jsonb_agg%'
  and pg_get_functiondef('app_private.form_application_projection(uuid)'::regprocedure)
    like '%management_version%',
  'schedule RPCs and projections address independent schedules by id and version'
);
select ok(
  pg_get_functiondef('app_private.form_generate_occurrences(uuid,integer)'::regprocedure)
    like '%schedule_id%'
  and pg_get_functiondef('app_private.form_enqueue_due_reminders(interval)'::regprocedure)
    like '%schedule.id = occurrence.schedule_id%'
  and pg_get_functiondef('app_private.form_save_draft(uuid,bigint,jsonb)'::regprocedure)
    like '%use form_copy_or_move for institution changes%',
  'generation and reminders stay schedule-scoped and drafts cannot move directly'
);
select has_table('public', 'form_occurrences', 'occurrences freeze a form version');
select has_table('public', 'form_participations', 'participations exist independently');
select has_table('public', 'form_participation_responders', 'context responders are normalized');
select has_table('public', 'form_responses', 'responses exist');
select has_table('public', 'form_answers', 'answers use typed columns');
select has_table('public', 'form_answer_options', 'choice answers use child rows');
select has_table('public', 'form_answer_assets', 'media answers use child rows');
select has_table('public', 'form_response_revisions', 'response revisions exist');
select has_table('public', 'form_occurrence_metrics', 'occurrence metrics exist');
select has_table('public', 'form_scope_metrics', 'scope metrics exist');
select has_table('public', 'form_file_jobs', 'file jobs exist');
select has_table('app_private', 'form_command_receipts', 'command receipts are private');
select has_table('app_private', 'form_worker_jobs', 'worker jobs are private');
select ok(
  has_table('app_private', 'form_multipart_uploads')
  and has_table('app_private', 'form_multipart_parts'),
  'multipart uploads and their parts are normalized in the private schema'
);
select ok(
  exists(select 1 from pg_constraint where conname = 'form_multipart_uploads_state_ck')
  and exists(select 1 from pg_constraint where conname = 'form_multipart_uploads_progress_ck')
  and exists(select 1 from pg_constraint where conname = 'form_multipart_parts_number_ck')
  and exists(select 1 from pg_constraint where conname = 'form_multipart_parts_checksum_ck'),
  'multipart persistence validates state, monotonic position, byte progress and checksums'
);

select ok(
  not exists(
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'form_responses'
       and column_name in ('participation_id', 'response_unit_key', 'child_context_id')
  ),
  'anonymous responses cannot persist a participation correlation key'
);

select ok(
  exists(select 1 from pg_constraint where conname = 'form_responses_anonymity_ck'),
  'anonymous response identity is constrained'
);

select ok(
  exists(select 1 from pg_constraint where conname = 'form_assets_owner_ck')
  and exists(
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'form_assets'
       and column_name = 'prepared_by_person_id' and is_nullable = 'YES'
  ),
  'anonymous media stores a secret hash instead of an actor identifier'
);

select ok(
  pg_get_functiondef('app_private.form_begin_command(uuid,uuid,text,bigint,jsonb)'::regprocedure)
    like '%form command replay mismatch%'
  and pg_get_functiondef('app_private.form_begin_command(uuid,uuid,text,bigint,jsonb)'::regprocedure)
    like '%request_hash%',
  'idempotency binds request id to actor command version and payload hash'
);

select ok(
  pg_get_functiondef('app_private.form_publish(uuid,bigint,jsonb)'::regprocedure)
    like '%expected_version mismatch%'
  and pg_get_functiondef('app_private.form_save_draft(uuid,bigint,jsonb)'::regprocedure)
    like '%expected_version mismatch%',
  'lifecycle commands enforce optimistic concurrency'
);

select ok(
  pg_get_functiondef('app_private.form_replace_response_answers(public.form_responses,jsonb,text)'::regprocedure)
    like '%hidden form answers are not accepted%',
  'hidden answers are rejected server-side'
);

select ok(
  pg_get_functiondef('app_private.form_replace_response_answers(public.form_responses,jsonb,text)'::regprocedure)
    like '%short text answer exceeds maximum length%'
  and pg_get_functiondef('app_private.form_replace_response_answers(public.form_responses,jsonb,text)'::regprocedure)
    like '%numeric form answer is out of range%'
  and pg_get_functiondef('app_private.form_replace_response_answers(public.form_responses,jsonb,text)'::regprocedure)
    like '%date form answer is out of range%'
  and pg_get_functiondef('app_private.form_replace_response_answers(public.form_responses,jsonb,text)'::regprocedure)
    like '%scale form answer is out of range%'
  and pg_get_functiondef('app_private.form_replace_response_answers(public.form_responses,jsonb,text)'::regprocedure)
    like '%multiple choice selection count is out of range%'
  and pg_get_functiondef('app_private.form_replace_response_answers(public.form_responses,jsonb,text)'::regprocedure)
    like '%form answer option ids must be unique%'
  and pg_get_functiondef('app_private.form_replace_response_answers(public.form_responses,jsonb,text)'::regprocedure)
    like '%form answer asset count is out of range%',
  'response mutations enforce typed catalog bounds and reject forged or duplicate choices'
);

select ok(
  pg_get_functiondef('app_private.form_assert_required_response_answers(public.form_responses)'::regprocedure)
    like '%required visible form answers are missing%'
  and pg_get_functiondef('app_private.form_mutate_response(text,uuid,bigint,jsonb,boolean)'::regprocedure)
    like '%form_assert_required_response_answers%',
  'submission requires every visible required answer'
);

select ok(
  pg_get_functiondef('app_private.form_mutate_response(text,uuid,bigint,jsonb,boolean)'::regprocedure)
    like '%participation.eligibility_state = ''eligible''%'
  and pg_get_functiondef('app_private.form_mutate_response(text,uuid,bigint,jsonb,boolean)'::regprocedure)
    like '%p_command = ''form_edit_response'' and response_row.status <> ''submitted''%'
  and pg_get_functiondef('app_private.form_mutate_response(text,uuid,bigint,jsonb,boolean)'::regprocedure)
    like '%p_command = ''form_save_response_draft'' and response_row.status <> ''draft''%'
  and pg_get_functiondef('app_private.form_mutate_response(text,uuid,bigint,jsonb,boolean)'::regprocedure)
    like '%participation.person_id = actor%'
  and not exists(
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'form_responses'
       and column_name = 'participation_id'
  ),
  'every response mutation rechecks eligibility and action state without persisting correlation'
);

select ok(
  pg_get_functiondef('app_private.form_mutate_response(text,uuid,bigint,jsonb,boolean)'::regprocedure)
    like '%p_submit and response_row.status <> ''draft''%',
  'a submitted response cannot be submitted again'
);

select ok(
  pg_get_functiondef('app_private.form_open_response_draft(uuid,bigint,jsonb)'::regprocedure)
    like '%form_hash_anonymous_edit_secret%'
  and pg_get_functiondef('app_private.form_assert_response_actor(public.form_responses,uuid,text)'::regprocedure)
    like '%form_verify_anonymous_edit_secret%',
  'anonymous editing stores and verifies only a secret hash'
);

select ok(
  pg_get_functiondef('app_private.form_open_response_draft(uuid,bigint,jsonb)'::regprocedure)
    like '%candidate.status in (''draft'', ''submitted'')%'
  and pg_get_functiondef('app_private.form_open_response_draft(uuid,bigint,jsonb)'::regprocedure)
    like '%response_row.status = ''submitted''%'
  and pg_get_functiondef('app_private.form_open_response_draft(uuid,bigint,jsonb)'::regprocedure)
    like '%participation_row.response_state = ''responded'' and response_row.id is null%'
  and pg_get_functiondef('app_private.form_open_response_draft(uuid,bigint,jsonb)'::regprocedure)
    like '%form_verify_anonymous_edit_secret%'
  and pg_get_functiondef('app_private.form_open_response_draft(uuid,bigint,jsonb)'::regprocedure)
    not like '%response_id%participation_id%',
  'submitted responses reopen for authorized editing without anonymous correlation'
);

select ok(
  pg_get_functiondef('app_private.form_open_response_draft(uuid,bigint,jsonb)'::regprocedure)
    like '%requested_identity_mode = ''identified''%'
  and pg_get_functiondef('app_private.form_mutate_response(text,uuid,bigint,jsonb,boolean)'::regprocedure)
    like '%response_row.identity_mode = ''identified''%'
  and pg_get_functiondef('app_private.form_mutate_response(text,uuid,bigint,jsonb,boolean)'::regprocedure)
    like '%answers_snapshot = p_payload -> ''answers''%',
  'anonymous idempotency does not create an actor-to-response command receipt'
);

select ok(
  pg_get_functiondef('app_private.form_prepare_asset_upload(uuid,bigint,jsonb)'::regprocedure)
    like '%if identity_mode = ''anonymous'' then return result%'
  and pg_get_functiondef('app_private.form_finalize_asset_upload(uuid,bigint,jsonb)'::regprocedure)
    like '%if asset_row.prepared_by_person_id is null then return result%'
  and pg_get_functiondef('public.form_media_authorize_for_worker(uuid,uuid,text)'::regprocedure)
    like '%form_verify_anonymous_edit_secret%',
  'anonymous media avoids actor-linked receipts and authorizes with its opaque secret'
);

select ok(
  pg_get_functiondef('app_private.form_claim_worker_job(text,integer,text[])'::regprocedure)
    like '%for update skip locked%'
  and pg_get_functiondef('app_private.form_claim_worker_job(text,integer,text[])'::regprocedure)
    like '%lease_expires_at%',
  'worker claims are leased and non-blocking'
);

select ok(
  pg_get_functiondef('app_private.form_generate_occurrences(uuid,integer)'::regprocedure)
    like '%at time zone%'
  and pg_get_functiondef('app_private.form_generate_occurrences(uuid,integer)'::regprocedure)
    like '%on conflict%'
  and pg_get_functiondef('app_private.form_generate_occurrences(uuid,integer)'::regprocedure)
    like '%monthly_last_day%',
  'occurrence generation is timezone-aware, recurrence-aware and idempotent'
);

select ok(
  pg_get_functiondef('app_private.form_reconcile_occurrence_audience(uuid)'::regprocedure)
    like '%on conflict(occurrence_id, response_unit_key)%'
  and pg_get_functiondef('app_private.form_reconcile_occurrence_audience(uuid)'::regprocedure)
    like '%eligibility_state = ''ineligible''%',
  'audience reconciliation deduplicates response units and records lost eligibility'
);

select ok(
  pg_get_functiondef('app_private.form_reconcile_occurrence_audience(uuid)'::regprocedure)
    like '%form_participation_responders%'
  and pg_get_functiondef('app_private.form_resolve_child_audience(uuid)'::regprocedure)
    like '%guardian_context_permissions%',
  'child family participation derives only normalized child contexts and responders'
);

select ok(
  pg_get_functiondef('app_private.form_enqueue_due_reminders(interval)'::regprocedure)
    like '%context_notification_events%'
  and pg_get_functiondef('app_private.form_enqueue_due_reminders(interval)'::regprocedure)
    like '%delivery_state = ''cancelled''%'
  and pg_get_functiondef('app_private.form_enqueue_due_reminders(interval)'::regprocedure)
    like '%response_state = ''pending''%',
  'reminders use the contextual outbox and cancel after response or lost eligibility'
);

select ok(
  pg_get_functiondef('app_private.form_request_export(uuid,bigint,jsonb,boolean)'::regprocedure)
    like '%auditable justification required%'
  and pg_get_functiondef('app_private.form_request_export(uuid,bigint,jsonb,boolean)'::regprocedure)
    like '%form_require_owner%',
  'anonymous participation export requires Owner and justification'
);

select ok(
  (select bool_and(c.relrowsecurity and c.relforcerowsecurity)
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname like 'form_%'),
  'all public form tables force RLS'
);

select ok(
  not has_table_privilege('authenticated', 'public.form_responses', 'SELECT')
  and not has_table_privilege('authenticated', 'public.form_responses', 'INSERT')
  and not has_table_privilege('authenticated', 'public.form_answers', 'UPDATE')
  and not has_table_privilege('anon', 'public.form_file_jobs', 'SELECT'),
  'browser roles have no direct form table privileges'
);

select ok(
  pg_get_functiondef('app_private.validate_form_tenant_links()'::regprocedure)
    like '%form_audience_rules%'
  and pg_get_functiondef('app_private.validate_form_tenant_links()'::regprocedure)
    like '%audience rule target tenant mismatch%'
  and pg_get_functiondef('app_private.validate_form_tenant_links()'::regprocedure)
    like '%form_participations%'
  and pg_get_functiondef('app_private.validate_form_tenant_links()'::regprocedure)
    like '%schedule_row.application_id = new.application_id%'
  and pg_get_functiondef('app_private.validate_form_tenant_links()'::regprocedure)
    like '%form_assets%',
  'tenant triggers reject forged audience participation and media links'
);

select is(
  (select count(*) from cron.job where jobname like 'coelo-forms-%'),
  3::bigint,
  'forms module installs no more than its three approved cron jobs'
);

select ok(
  pg_get_functiondef('app_private.form_dispatch_operations_worker()'::regprocedure)
    like '%vault.decrypted_secrets%'
  and pg_get_functiondef('app_private.form_dispatch_operations_worker()'::regprocedure)
    like '%net.http_post%'
  and pg_get_functiondef('app_private.form_dispatch_operations_worker()'::regprocedure)
    not like '%service_role%',
  'worker dispatch reads opaque credentials from Vault without embedding secrets'
);

select ok(
  has_function_privilege('authenticated', 'public.form_save_draft(uuid,bigint,jsonb)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.form_save_draft(uuid,bigint,jsonb)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.form_submit_response(uuid,bigint,jsonb)', 'EXECUTE'),
  'only authenticated clients execute public form RPCs'
);

select ok(
  pg_get_functiondef('app_private.block_published_form_definition_mutation()'::regprocedure)
    like '%published form version is immutable%'
  and pg_get_functiondef('app_private.block_form_identity_mode_change()'::regprocedure)
    like '%identity mode is immutable after first publication%',
  'published definitions and identity mode are immutable'
);

select has_index('public', 'form_occurrences', 'form_occurrences_generation_idx', 'hot occurrence scan uses a partial index');
select has_index('app_private', 'form_worker_jobs', 'form_worker_jobs_claim_idx', 'worker claim uses a partial index');

select ok(
  pg_get_functiondef('app_private.form_worker_export_snapshot(uuid,uuid,integer)'::regprocedure)
    like '%form export job unavailable%'
  and pg_get_functiondef('app_private.form_worker_export_snapshot(uuid,uuid,integer)'::regprocedure)
    like '%/forms/media/%'
  and pg_get_functiondef('app_private.form_worker_export_snapshot(uuid,uuid,integer)'::regprocedure)
    like '%occurrence.form_id = file_job.form_id%'
  and pg_get_functiondef('app_private.form_worker_export_snapshot(uuid,uuid,integer)'::regprocedure)
    not like '%participation.form_id%'
  and not has_function_privilege('authenticated', 'public.form_worker_export_snapshot(uuid,uuid,integer)', 'EXECUTE'),
  'export snapshots are bounded, protected, query valid participation data, and expose media only through the authorized route'
);

select ok(
  has_function('public', 'form_worker_begin_export', array['uuid','text','uuid'])
  and has_function(
    'public', 'form_worker_complete_export',
    array['uuid','text','uuid','text','bigint','jsonb']
  )
  and has_function('public', 'form_worker_fail_export', array['uuid','text','uuid','text','integer'])
  and has_function('public', 'form_worker_cleanup_snapshot', array['uuid','text','integer'])
  and has_function('public', 'form_worker_complete_cleanup', array['uuid','text','uuid[]']),
  'export and cleanup workers expose only lease-bound server RPCs'
);

select ok(
  pg_get_functiondef('app_private.form_worker_complete_export(uuid,text,uuid,text,bigint,jsonb)'::regprocedure)
    like '%lease_owner = p_worker_id%'
  and pg_get_functiondef('app_private.form_worker_complete_export(uuid,text,uuid,text,bigint,jsonb)'::regprocedure)
    like '%lease_expires_at >= now()%'
  and pg_get_functiondef('app_private.form_worker_cleanup_snapshot(uuid,text,integer)'::regprocedure)
    like '%cleanup_uploads%'
  and pg_get_functiondef('app_private.form_worker_cleanup_snapshot(uuid,text,integer)'::regprocedure)
    like '%cleanup_artifacts%',
  'export transitions and cleanup snapshots bind work to a current worker lease'
);

select ok(
  has_function('app_private', 'form_worker_begin_multipart', array['uuid','text','uuid','text','text','text'])
  and has_function(
    'app_private', 'form_worker_record_multipart_part',
    array['uuid','text','uuid','text','integer','text','bigint','text']
  )
  and has_function('app_private', 'form_worker_complete_multipart', array['uuid','text','uuid','text'])
  and has_function('app_private', 'form_worker_abort_multipart', array['uuid','text','uuid','text']),
  'multipart lifecycle exposes explicit private worker transitions'
);

select ok(
  pg_get_functiondef('app_private.form_worker_begin_multipart(uuid,text,uuid,text,text,text)'::regprocedure)
    like '%lease_owner = p_worker_id%'
  and pg_get_functiondef('app_private.form_worker_complete_multipart(uuid,text,uuid,text)'::regprocedure)
    like '%lease_owner = p_worker_id%'
  and pg_get_functiondef('app_private.form_worker_abort_multipart(uuid,text,uuid,text)'::regprocedure)
    like '%lease_owner = p_worker_id%'
  and pg_get_functiondef('app_private.form_worker_record_multipart_part(uuid,text,uuid,text,integer,text,bigint,text)'::regprocedure)
    like '%lease_owner = p_worker_id%'
  and pg_get_functiondef('app_private.form_worker_record_multipart_part(uuid,text,uuid,text,integer,text,bigint,text)'::regprocedure)
    like '%lease_expires_at >= now()%'
  and not exists(
    select 1 from (values
      ('public.form_worker_begin_multipart(uuid,text,uuid,text,text,text)'),
      ('public.form_worker_record_multipart_part(uuid,text,uuid,text,integer,text,bigint,text)'),
      ('public.form_worker_complete_multipart(uuid,text,uuid,text)'),
      ('public.form_worker_abort_multipart(uuid,text,uuid,text)')
    ) as rpc(signature)
    where has_function_privilege('authenticated', rpc.signature, 'EXECUTE')
  )
  and has_function_privilege(
    'service_role', 'public.form_worker_record_multipart_part(uuid,text,uuid,text,integer,text,bigint,text)', 'EXECUTE'
  ),
  'multipart transitions require a current export lease and remain service-only'
);

select ok(
  has_function('app_private', 'form_worker_multipart_snapshot', array['uuid','text','uuid'])
  and pg_get_functiondef('app_private.form_worker_multipart_snapshot(uuid,text,uuid)'::regprocedure)
    like '%lease_owner = p_worker_id%'
  and pg_get_functiondef('app_private.form_worker_multipart_snapshot(uuid,text,uuid)'::regprocedure)
    like '%order by part.part_number%'
  and not has_function_privilege(
    'authenticated', 'public.form_worker_multipart_snapshot(uuid,text,uuid)', 'EXECUTE'
  ),
  'multipart resume snapshot is ordered, lease-bound and service-only'
);

select ok(
  has_function('public', 'form_list_monitor_hierarchy', array['jsonb'])
  and has_function('app_private', 'form_rebuild_occurrence_scope_metrics', array['uuid']),
  'hierarchy RPC and materialized scope rebuild are installed'
);

select ok(
  pg_get_functiondef('app_private.form_list_monitor_hierarchy(jsonb)'::regprocedure)
    like '%require_forms_actor(''forms.monitor'')%'
  and pg_get_functiondef('app_private.form_list_monitor_hierarchy(jsonb)'::regprocedure)
    like '%monitor scope unavailable%'
  and pg_get_functiondef('app_private.form_list_monitor_hierarchy(jsonb)'::regprocedure)
    like '%cursor_label%'
  and pg_get_functiondef('app_private.form_list_monitor_hierarchy(jsonb)'::regprocedure)
    like '%wanted_scope_kind%',
  'monitor hierarchy is capability-gated, tenant-scoped and cursor-paginated'
);

select ok(
  pg_get_functiondef('app_private.form_get_monitor(jsonb)'::regprocedure)
    like '%monitor scope unavailable%'
  and pg_get_functiondef('app_private.form_get_monitor(jsonb)'::regprocedure)
    like '%scope_metric%',
  'selected monitor scope changes aggregate metrics only after form and tenant validation'
);

select ok(
  pg_get_functiondef('app_private.form_rebuild_occurrence_metrics(uuid)'::regprocedure)
    like '%form_rebuild_occurrence_scope_metrics%'
  and not has_function_privilege('authenticated', 'app_private.form_rebuild_occurrence_scope_metrics(uuid)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.form_list_monitor_hierarchy(jsonb)', 'EXECUTE'),
  'scope projection rebuild stays private while the guarded RPC is callable'
);

select ok(
  pg_get_functiondef('app_private.form_list(jsonb)'::regprocedure)
    like '%operational_status%'
  and pg_get_functiondef('app_private.form_list(jsonb)'::regprocedure)
    like '%opens_at <= now()%'
  and pg_get_functiondef('app_private.form_list(jsonb)'::regprocedure)
    like '%closes_at > now()%'
  and pg_get_functiondef('app_private.form_list(jsonb)'::regprocedure)
    like '%operational_statuses%'
  and pg_get_functiondef('app_private.form_list(jsonb)'::regprocedure)
    like '%status in (''scheduled'', ''open'')%',
  'directory derives operational situations from occurrence windows without persisting them'
);

select ok(
  (select pg_get_expr(default_row.adbin, default_row.adrelid) like '%03:00:00%'
     from pg_attrdef default_row
     join pg_attribute attribute_row
       on attribute_row.attrelid = default_row.adrelid
      and attribute_row.attnum = default_row.adnum
    where default_row.adrelid = 'public.form_assets'::regclass
      and attribute_row.attname = 'expires_at'),
  'asset reservation outlives the two-hour signed upload token with margin'
);

select ok(
  pg_get_functiondef(
    'app_private.form_replace_response_answers(public.form_responses,jsonb,text)'::regprocedure
  ) like '%asset.prepared_by_person_id = p_response.respondent_person_id%'
  and pg_get_functiondef(
    'app_private.form_replace_response_answers(public.form_responses,jsonb,text)'::regprocedure
  ) like '%p_edit_secret, asset.anonymous_upload_secret_hash%',
  'response answers can attach only assets owned by that identified or anonymous response actor'
);

select ok(
  pg_get_functiondef('app_private.form_prepare_asset_upload(uuid,bigint,jsonb)'::regprocedure)
    like '%pg_advisory_xact_lock%'
  and pg_get_functiondef('app_private.form_prepare_asset_upload(uuid,bigint,jsonb)'::regprocedure)
    like '%candidate.expires_at > now()%',
  'asset prepare serializes the five-image quota and never replays an expired anonymous reservation'
);

select ok(
  pg_get_functiondef('app_private.form_finalize_asset_for_worker(uuid,bigint,text,text)'::regprocedure)
    like '%form_asset_verification_mismatch%'
  and pg_get_functiondef('app_private.form_finalize_asset_for_worker(uuid,bigint,text,text)'::regprocedure)
    not like '%raise check_violation using message = ''form asset verification mismatch''%',
  'verification mismatch commits the discarded state before the Edge handler reports failure'
);

select ok(
  pg_get_functiondef('public.form_media_authorize_for_worker(uuid,uuid,text)'::regprocedure)
    like '%form_answer_assets%'
  and pg_get_functiondef('app_private.form_worker_cleanup_snapshot(uuid,text,integer)'::regprocedure)
    like '%multipart_upload_id%'
  and pg_get_functiondef('app_private.form_worker_complete_cleanup(uuid,text,uuid[])'::regprocedure)
    like '%state = ''aborted''%',
  'administrative media reads require attached assets and artifact cleanup closes multipart uploads'
);

select ok(
  pg_get_functiondef('app_private.form_claim_notification_delivery(text,integer)'::regprocedure)
    like '%for update of candidate skip locked%'
  and pg_get_functiondef('app_private.form_claim_notification_delivery(text,integer)'::regprocedure)
    like '%delivery_attempts < 20%'
  and pg_get_functiondef(
    'app_private.form_complete_notification_delivery(uuid,uuid,text,boolean,text)'::regprocedure
  ) like '%delivery_lease_owner = p_worker_id%'
  and pg_get_functiondef(
    'app_private.form_complete_notification_delivery(uuid,uuid,text,boolean,text)'::regprocedure
  ) like '%delivery_lease_expires_at >= now()%'
  and pg_get_functiondef(
    'app_private.form_complete_notification_delivery(uuid,uuid,text,boolean,text)'::regprocedure
  ) like '%power(2%',
  'notification dispatch claims outside-network work with a lease and persists bounded retry backoff'
);

select ok(
  not has_function_privilege(
    'authenticated', 'public.form_worker_claim_notification(text,integer)', 'EXECUTE'
  )
  and has_function_privilege(
    'service_role', 'public.form_worker_claim_notification(text,integer)', 'EXECUTE'
  )
  and not has_table_privilege(
    'authenticated', 'public.context_notification_recipients', 'UPDATE'
  )
  and has_column_privilege(
    'authenticated', 'public.context_notification_recipients', 'read_at', 'UPDATE'
  )
  and not has_column_privilege(
    'authenticated', 'public.context_notification_recipients', 'delivery_state', 'UPDATE'
  ),
  'notification delivery state is service-only while recipients retain read acknowledgement access'
);

select * from finish();
rollback;
