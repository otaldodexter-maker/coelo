begin;

-- The hub owns only routing.  Unit-specific validation, idempotency and
-- scoped authorization remain in the established Unit lifecycle.
create or replace function app_private.superadmin_create_import_export_job(
  p_domain text,
  p_file_name text,
  p_mime_type text,
  p_source_format text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform app_private.assert_import_export_hub_actor();
  if p_domain <> 'units' then
    raise invalid_parameter_value using message = 'import domain unavailable';
  end if;
  return app_private.superadmin_create_unit_import_job(
    p_file_name, p_mime_type, p_source_format, p_idempotency_key
  );
end;
$$;

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
  actor := app_private.assert_import_export_hub_actor();
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

create or replace function app_private.superadmin_confirm_import_export_job(
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
  actor := app_private.assert_import_export_hub_actor();
  select * into job from public.import_jobs
  where id = p_import_job_id and created_by = actor;
  if job.id is null or job.target_domain <> 'units' then
    raise insufficient_privilege using message = 'import confirmation unavailable';
  end if;
  return app_private.superadmin_confirm_unit_import(p_request_id, p_import_job_id);
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
  actor := app_private.assert_import_export_hub_actor();
  select * into job from public.import_jobs
  where id = p_import_job_id and created_by = actor;
  if job.id is null or job.target_domain <> 'units' then
    raise insufficient_privilege using message = 'import retry unavailable';
  end if;
  return app_private.superadmin_retry_unit_import(p_request_id, p_import_job_id);
end;
$$;

create or replace function app_private.superadmin_request_import_export(
  p_domain text,
  p_format text,
  p_filters jsonb,
  p_current_view jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform app_private.assert_import_export_hub_actor();
  if p_domain <> 'units' then
    raise invalid_parameter_value using message = 'export domain unavailable';
  end if;
  return app_private.superadmin_request_unit_export(
    p_format, p_filters, p_current_view, p_idempotency_key
  );
end;
$$;

create or replace function public.superadmin_create_import_export_job(
  p_domain text, p_file_name text, p_mime_type text, p_source_format text,
  p_idempotency_key uuid
)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_create_import_export_job($1, $2, $3, $4, $5) $$;

create or replace function public.superadmin_import_export_upload_contract(
  p_import_job_id uuid
)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.superadmin_import_export_upload_contract($1) $$;

create or replace function public.superadmin_confirm_import_export_job(
  p_import_job_id uuid, p_request_id uuid
)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_confirm_import_export_job($1, $2) $$;

create or replace function public.superadmin_retry_import_export_job(
  p_import_job_id uuid, p_request_id uuid
)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_retry_import_export_job($1, $2) $$;

create or replace function public.superadmin_request_import_export(
  p_domain text, p_format text, p_filters jsonb, p_current_view jsonb,
  p_idempotency_key uuid
)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_request_import_export($1, $2, $3, $4, $5) $$;

revoke all on function public.superadmin_create_import_export_job(text, text, text, text, uuid),
  public.superadmin_import_export_upload_contract(uuid),
  public.superadmin_confirm_import_export_job(uuid, uuid),
  public.superadmin_retry_import_export_job(uuid, uuid),
  public.superadmin_request_import_export(text, text, jsonb, jsonb, uuid)
from public, anon, authenticated, service_role;
grant execute on function public.superadmin_create_import_export_job(text, text, text, text, uuid),
  public.superadmin_import_export_upload_contract(uuid),
  public.superadmin_confirm_import_export_job(uuid, uuid),
  public.superadmin_retry_import_export_job(uuid, uuid),
  public.superadmin_request_import_export(text, text, jsonb, jsonb, uuid)
to authenticated;

revoke all on function app_private.superadmin_create_import_export_job(text, text, text, text, uuid),
  app_private.superadmin_import_export_upload_contract(uuid),
  app_private.superadmin_confirm_import_export_job(uuid, uuid),
  app_private.superadmin_retry_import_export_job(uuid, uuid),
  app_private.superadmin_request_import_export(text, text, jsonb, jsonb, uuid)
from public, anon, authenticated, service_role;

commit;
