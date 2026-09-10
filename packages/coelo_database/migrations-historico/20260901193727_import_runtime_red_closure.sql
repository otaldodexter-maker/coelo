begin;

create or replace function app_private.superadmin_import_export_upload_contract(
  p_import_job_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid;
  job public.import_jobs%rowtype;
  mime_type text;
begin
  if p_import_job_id is null then
    raise invalid_parameter_value using message = 'import job required';
  end if;

  actor := app_private.assert_unit_file_access('units.import', null);
  select * into job
  from public.import_jobs
  where id = p_import_job_id and created_by = actor;

  if job.id is null or job.target_domain <> 'units'
    or job.processing_state <> 'PENDENTE' then
    raise insufficient_privilege using message = 'import upload unavailable';
  end if;

  mime_type := case job.source_format
    when 'csv' then 'text/csv'
    when 'xlsx' then 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else null
  end;
  if mime_type is null then
    raise invalid_parameter_value using message = 'invalid import format';
  end if;

  return jsonb_build_object(
    'job_id', job.id,
    'bucket', 'coelo-operations',
    'path', 'imports/units/' || job.id || '/source.' || job.source_format,
    'mime_type', mime_type,
    'max_bytes', 5242880,
    'expires_in', 60
  );
end;
$$;

create or replace function app_private.superadmin_retry_unit_import(
  p_request_id uuid,
  p_import_job_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid;
  job public.import_jobs%rowtype;
  prior_job_id uuid;
begin
  if p_request_id is null or p_import_job_id is null then
    raise invalid_parameter_value using message = 'request_id and import job are required';
  end if;

  actor := app_private.assert_unit_file_access('units.import', null);
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('unit-import-retry:' || p_request_id::text, 0)
  );

  select candidate.id into prior_job_id
  from public.import_jobs candidate
  where candidate.target_domain = 'units'
    and candidate.summary ->> 'retry_request_id' = p_request_id::text
  limit 1;

  if prior_job_id is not null then
    if prior_job_id <> p_import_job_id then
      raise invalid_parameter_value using message = 'retry request_id already used';
    end if;
    select * into job
    from public.import_jobs
    where id = prior_job_id and created_by = actor;
    if job.id is null then
      raise insufficient_privilege using message = 'unit import outside actor scope';
    end if;
    return app_private.unit_file_job_payload(job.id);
  end if;

  select * into job
  from public.import_jobs
  where id = p_import_job_id
  for update;
  if job.id is null then
    raise no_data_found using message = 'unit import not found';
  end if;
  if job.created_by <> actor or job.target_domain <> 'units' then
    raise insufficient_privilege using message = 'unit import outside actor scope';
  end if;
  if job.processing_state not in ('ERRO', 'REJEICAO') then
    raise object_not_in_prerequisite_state using message = 'unit import is not retryable';
  end if;

  update public.import_jobs
  set processing_state = 'PENDENTE',
      status = 'draft',
      finished_at = null,
      summary = coalesce(summary, '{}'::jsonb) || jsonb_build_object(
        'phase', 'preview',
        'retry_request_id', p_request_id
      ),
      updated_at = now()
  where id = job.id;

  return app_private.unit_file_job_payload(job.id);
end;
$$;

create or replace function app_private.superadmin_retry_import_export_job(
  p_import_job_id uuid,
  p_request_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid;
  job public.import_jobs%rowtype;
begin
  if p_request_id is null or p_import_job_id is null then
    raise invalid_parameter_value using message = 'request_id and import job are required';
  end if;

  actor := app_private.assert_unit_file_access('units.import', null);
  select * into job
  from public.import_jobs
  where id = p_import_job_id and created_by = actor;
  if job.id is null or job.target_domain <> 'units' then
    raise insufficient_privilege using message = 'import retry unavailable';
  end if;
  return app_private.superadmin_retry_unit_import(p_request_id, p_import_job_id);
end;
$$;

revoke all on function app_private.superadmin_import_export_upload_contract(uuid),
  app_private.superadmin_retry_unit_import(uuid, uuid),
  app_private.superadmin_retry_import_export_job(uuid, uuid)
from public, anon, authenticated, service_role;

do $$
declare
  upload_definition text;
  retry_definition text;
begin
  upload_definition := pg_catalog.pg_get_functiondef(
    'app_private.superadmin_import_export_upload_contract(uuid)'::regprocedure
  );
  retry_definition := pg_catalog.pg_get_functiondef(
    'app_private.superadmin_retry_unit_import(uuid,uuid)'::regprocedure
  );

  if pg_catalog.strpos(upload_definition, 'assert_unit_file_access') = 0
    or pg_catalog.strpos(upload_definition, 'units.import') = 0 then
    raise object_not_in_prerequisite_state using
      message = 'upload contract must revalidate units.import';
  end if;
  if pg_catalog.strpos(pg_catalog.lower(retry_definition), 'p_request_id is null') = 0
    or pg_catalog.strpos(pg_catalog.lower(retry_definition), 'pg_advisory_xact_lock') = 0
    or pg_catalog.strpos(pg_catalog.lower(retry_definition), 'retry_request_id') = 0 then
    raise object_not_in_prerequisite_state using
      message = 'unit import retry idempotency guard is missing';
  end if;
  if has_function_privilege(
      'authenticated',
      'app_private.superadmin_retry_unit_import(uuid,uuid)',
      'EXECUTE'
    ) then
    raise object_not_in_prerequisite_state using
      message = 'private unit import retry must not be executable by authenticated';
  end if;
end;
$$;

commit;
