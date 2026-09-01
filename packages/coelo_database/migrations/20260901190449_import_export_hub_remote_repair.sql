begin;

-- Remote repair for the already deployed import-export-jobs Edge boundary.
-- Only Units has a complete import/export lifecycle; every other domain stays
-- fail-closed until its own backend contract exists.

create or replace function app_private.assert_import_export_hub_actor()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.current_person_id();
begin
  if (select auth.uid()) is null or actor is null or not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message = 'authenticated AAL2 required';
  end if;
  return actor;
end;
$$;

create or replace function app_private.can_access_import_export_job(p_target_domain text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case p_target_domain
    when 'units' then app_private.has_platform_permission('units.import')
    when 'units_export' then app_private.has_platform_permission('units.export')
    else false
  end
$$;

create or replace function app_private.import_export_job_direction(p_target_domain text)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select case when p_target_domain like '%_export' then 'export' else 'import' end
$$;

create or replace function app_private.import_export_job_domain(p_target_domain text)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select regexp_replace(p_target_domain, '_export$', '')
$$;

create or replace function app_private.import_export_job_payload(p_job_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'job_id', job.id,
    'domain', app_private.import_export_job_domain(job.target_domain),
    'direction', app_private.import_export_job_direction(job.target_domain),
    'format', job.source_format,
    'file_name', source_file.file_name,
    'state', job.processing_state,
    'progress', case job.processing_state
      when 'PENDENTE' then coalesce((job.summary ->> 'progress')::integer, 0)
      when 'PROCESSANDO' then coalesce((job.summary ->> 'progress')::integer, 50)
      else 100
    end,
    'created_at', job.created_at,
    'started_at', job.started_at,
    'finished_at', job.finished_at,
    'summary', jsonb_strip_nulls(jsonb_build_object(
      'phase', job.summary ->> 'phase',
      'valid_count', job.summary -> 'valid_count',
      'rejected_count', job.summary -> 'rejected_count',
      'row_count', job.summary -> 'row_count'
    )),
    'result', coalesce(to_jsonb(result_record), '{}'::jsonb),
    'errors', coalesce((
      select jsonb_agg(jsonb_build_object(
        'row_number', error_record.row_number,
        'field', error_record.column_name,
        'code', error_record.error_code,
        'message', error_record.message
      ) order by error_record.row_number, error_record.id)
      from public.import_errors error_record
      where error_record.import_job_id = job.id
    ), '[]'::jsonb)
  )
  from public.import_jobs job
  left join public.import_results result_record on result_record.import_job_id = job.id
  left join lateral (
    select file_record.file_name
    from public.import_files file_record
    where file_record.import_job_id = job.id
    order by file_record.uploaded_at desc, file_record.id desc
    limit 1
  ) source_file on true
  where job.id = p_job_id
$$;

create or replace function app_private.superadmin_import_export_catalog()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform app_private.assert_import_export_hub_actor();
  return jsonb_build_object('domains', jsonb_build_array(
    jsonb_build_object(
      'domain', 'institutions', 'label', 'Instituições', 'template_version', null,
      'import_available', false, 'export_available', false,
      'import_authorized', false, 'export_authorized', false
    ),
    jsonb_build_object(
      'domain', 'units', 'label', 'Unidades', 'template_version', 'v2',
      'import_available', true, 'export_available', true,
      'import_authorized', app_private.has_platform_permission('units.import'),
      'export_authorized', app_private.has_platform_permission('units.export')
    ),
    jsonb_build_object(
      'domain', 'groups', 'label', 'Turmas', 'template_version', null,
      'import_available', false, 'export_available', false,
      'import_authorized', false, 'export_authorized', false
    ),
    jsonb_build_object(
      'domain', 'activities', 'label', 'Atividades', 'template_version', null,
      'import_available', false, 'export_available', false,
      'import_authorized', false, 'export_authorized', false
    ),
    jsonb_build_object(
      'domain', 'people', 'label', 'Pessoas', 'template_version', null,
      'import_available', false, 'export_available', false,
      'import_authorized', false, 'export_authorized', false
    ),
    jsonb_build_object(
      'domain', 'internal_users', 'label', 'Usuários internos', 'template_version', null,
      'import_available', false, 'export_available', false,
      'import_authorized', false, 'export_authorized', false
    )
  ));
end;
$$;

create or replace function app_private.superadmin_list_import_export_jobs(
  p_domains text[], p_states text[], p_formats text[], p_search text,
  p_created_from timestamptz, p_created_to timestamptz,
  p_before_created_at timestamptz, p_before_job_id uuid, p_page_size integer
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid;
  normalized_search text := nullif(btrim(p_search), '');
  escaped_search text;
begin
  actor := app_private.assert_import_export_hub_actor();
  if p_page_size not between 1 and 100
    or (p_domains is not null and exists (
      select 1 from unnest(p_domains) domain_name where domain_name <> 'units'
    ))
    or (p_states is not null and exists (
      select 1 from unnest(p_states) state_name
      where state_name not in ('PENDENTE','PROCESSANDO','SUCESSO','REJEICAO','ERRO')
    ))
    or (p_formats is not null and exists (
      select 1 from unnest(p_formats) format_name where format_name not in ('csv','xlsx')
    ))
    or (normalized_search is not null and (
      char_length(normalized_search) > 120 or normalized_search ~ '[[:cntrl:]]'
    ))
    or (p_created_from is not null and p_created_to is not null
      and p_created_from > p_created_to)
  then
    raise invalid_parameter_value using message = 'invalid import/export list filters';
  end if;

  escaped_search := case when normalized_search is null then null else
    replace(replace(replace(normalized_search, chr(92), chr(92) || chr(92)),
      '%', chr(92) || '%'), '_', chr(92) || '_')
  end;

  return (
    with authorized as materialized (
      select job.id, job.target_domain, job.source_format, job.processing_state,
        job.summary, job.created_at, job.started_at, job.finished_at,
        source_file.file_name,
        result_record.created_count, result_record.updated_count,
        result_record.linked_count, result_record.ignored_count,
        result_record.rejected_count
      from public.import_jobs job
      left join public.import_results result_record on result_record.import_job_id = job.id
      left join lateral (
        select file_record.file_name
        from public.import_files file_record
        where file_record.import_job_id = job.id
        order by file_record.uploaded_at desc, file_record.id desc
        limit 1
      ) source_file on true
      where job.created_by = actor
        and job.target_domain in ('units', 'units_export')
        and app_private.can_access_import_export_job(job.target_domain)
        and (p_domains is null or cardinality(p_domains) = 0
          or app_private.import_export_job_domain(job.target_domain) = any(p_domains))
        and (p_states is null or cardinality(p_states) = 0
          or job.processing_state::text = any(p_states))
        and (p_formats is null or cardinality(p_formats) = 0
          or job.source_format = any(p_formats))
        and (p_created_from is null or job.created_at >= p_created_from)
        and (p_created_to is null or job.created_at <= p_created_to)
        and (escaped_search is null
          or job.target_domain ilike '%' || escaped_search || '%' escape chr(92)
          or job.source_format ilike '%' || escaped_search || '%' escape chr(92)
          or source_file.file_name ilike '%' || escaped_search || '%' escape chr(92))
    ), windowed as materialized (
      select * from authorized
      where p_before_created_at is null or (created_at, id) < (
        p_before_created_at,
        coalesce(p_before_job_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)
      )
      order by created_at desc, id desc
      limit p_page_size + 1
    ), visible as materialized (
      select * from windowed order by created_at desc, id desc limit p_page_size
    ), last_visible as (
      select created_at, id from visible order by created_at asc, id asc limit 1
    )
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'job_id', visible.id,
        'domain', app_private.import_export_job_domain(visible.target_domain),
        'direction', app_private.import_export_job_direction(visible.target_domain),
        'format', visible.source_format,
        'file_name', visible.file_name,
        'state', visible.processing_state,
        'progress', case visible.processing_state
          when 'PENDENTE' then coalesce((visible.summary ->> 'progress')::integer, 0)
          when 'PROCESSANDO' then coalesce((visible.summary ->> 'progress')::integer, 50)
          else 100
        end,
        'created_at', visible.created_at,
        'started_at', visible.started_at,
        'finished_at', visible.finished_at,
        'summary', jsonb_strip_nulls(jsonb_build_object(
          'phase', visible.summary ->> 'phase',
          'valid_count', visible.summary -> 'valid_count',
          'rejected_count', visible.summary -> 'rejected_count',
          'row_count', visible.summary -> 'row_count'
        )),
        'result', jsonb_strip_nulls(jsonb_build_object(
          'created_count', visible.created_count,
          'updated_count', visible.updated_count,
          'linked_count', visible.linked_count,
          'ignored_count', visible.ignored_count,
          'rejected_count', visible.rejected_count
        ))
      ) order by visible.created_at desc, visible.id desc), '[]'::jsonb),
      'total_count', (select count(*) from authorized),
      'has_more', (select count(*) from windowed) > p_page_size,
      'next_cursor', case when (select count(*) from windowed) > p_page_size
        then (select jsonb_build_object('created_at', created_at, 'job_id', id)
          from last_visible)
        else null
      end
    ) from visible
  );
end;
$$;

create or replace function app_private.superadmin_get_import_export_job(
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
begin
  actor := app_private.assert_import_export_hub_actor();
  select * into job
  from public.import_jobs
  where id = p_import_job_id and created_by = actor;

  if job.id is null or not app_private.can_access_import_export_job(job.target_domain) then
    raise insufficient_privilege using message = 'import/export job unavailable';
  end if;
  return app_private.import_export_job_payload(job.id);
end;
$$;

create or replace function app_private.superadmin_create_import_export_job(
  p_domain text, p_file_name text, p_mime_type text, p_source_format text,
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
  p_import_job_id uuid, p_request_id uuid
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
  p_import_job_id uuid, p_request_id uuid
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
  p_domain text, p_format text, p_filters jsonb, p_current_view jsonb,
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

create or replace function public.superadmin_import_export_catalog()
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.superadmin_import_export_catalog() $$;

create or replace function public.superadmin_list_import_export_jobs(
  p_domains text[], p_states text[], p_formats text[], p_search text,
  p_created_from timestamptz, p_created_to timestamptz,
  p_before_created_at timestamptz, p_before_job_id uuid, p_page_size integer
)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select app_private.superadmin_list_import_export_jobs(
    $1,$2,$3,$4,$5,$6,$7,$8,$9
  )
$$;

create or replace function public.superadmin_get_import_export_job(p_import_job_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.superadmin_get_import_export_job($1) $$;

create or replace function public.superadmin_create_import_export_job(
  p_domain text, p_file_name text, p_mime_type text, p_source_format text,
  p_idempotency_key uuid
)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_create_import_export_job($1,$2,$3,$4,$5) $$;

create or replace function public.superadmin_import_export_upload_contract(
  p_import_job_id uuid
)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.superadmin_import_export_upload_contract($1) $$;

create or replace function public.superadmin_confirm_import_export_job(
  p_import_job_id uuid, p_request_id uuid
)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_confirm_import_export_job($1,$2) $$;

create or replace function public.superadmin_retry_import_export_job(
  p_import_job_id uuid, p_request_id uuid
)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_retry_import_export_job($1,$2) $$;

create or replace function public.superadmin_request_import_export(
  p_domain text, p_format text, p_filters jsonb, p_current_view jsonb,
  p_idempotency_key uuid
)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_request_import_export($1,$2,$3,$4,$5) $$;

revoke all on function app_private.assert_import_export_hub_actor(),
  app_private.can_access_import_export_job(text),
  app_private.import_export_job_direction(text),
  app_private.import_export_job_domain(text),
  app_private.import_export_job_payload(uuid),
  app_private.superadmin_import_export_catalog(),
  app_private.superadmin_list_import_export_jobs(
    text[],text[],text[],text,timestamptz,timestamptz,timestamptz,uuid,integer
  ),
  app_private.superadmin_get_import_export_job(uuid),
  app_private.superadmin_create_import_export_job(text,text,text,text,uuid),
  app_private.superadmin_import_export_upload_contract(uuid),
  app_private.superadmin_confirm_import_export_job(uuid,uuid),
  app_private.superadmin_retry_import_export_job(uuid,uuid),
  app_private.superadmin_request_import_export(text,text,jsonb,jsonb,uuid)
from public, anon, authenticated, service_role;

revoke all on function public.superadmin_import_export_catalog(),
  public.superadmin_list_import_export_jobs(
    text[],text[],text[],text,timestamptz,timestamptz,timestamptz,uuid,integer
  ),
  public.superadmin_get_import_export_job(uuid),
  public.superadmin_create_import_export_job(text,text,text,text,uuid),
  public.superadmin_import_export_upload_contract(uuid),
  public.superadmin_confirm_import_export_job(uuid,uuid),
  public.superadmin_retry_import_export_job(uuid,uuid),
  public.superadmin_request_import_export(text,text,jsonb,jsonb,uuid)
from public, anon, authenticated, service_role;

grant execute on function public.superadmin_import_export_catalog(),
  public.superadmin_list_import_export_jobs(
    text[],text[],text[],text,timestamptz,timestamptz,timestamptz,uuid,integer
  ),
  public.superadmin_get_import_export_job(uuid),
  public.superadmin_create_import_export_job(text,text,text,text,uuid),
  public.superadmin_import_export_upload_contract(uuid),
  public.superadmin_confirm_import_export_job(uuid,uuid),
  public.superadmin_retry_import_export_job(uuid,uuid),
  public.superadmin_request_import_export(text,text,jsonb,jsonb,uuid)
to authenticated;

commit;
