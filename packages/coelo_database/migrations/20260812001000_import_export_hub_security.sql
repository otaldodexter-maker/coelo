begin;

-- Import/export artifacts are operational records.  They are never a public
-- Storage surface and browser clients only reach them through guarded RPCs.
alter table public.import_files
  add column if not exists checksum_sha256 text,
  add column if not exists retention_expires_at timestamptz,
  add column if not exists deleted_at timestamptz;

alter table public.import_files
  drop constraint if exists import_files_checksum_sha256_format_check,
  add constraint import_files_checksum_sha256_format_check
    check (checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$'),
  drop constraint if exists import_files_retention_after_upload_check,
  add constraint import_files_retention_after_upload_check
    check (retention_expires_at is null or retention_expires_at >= uploaded_at);

create index if not exists import_jobs_created_by_cursor_idx
  on public.import_jobs (created_by, created_at desc, id desc);
create index if not exists import_errors_job_row_idx
  on public.import_errors (import_job_id, row_number, id);

alter table public.import_jobs enable row level security;
alter table public.import_files enable row level security;
alter table public.import_mappings enable row level security;
alter table public.import_rows enable row level security;
alter table public.import_errors enable row level security;
alter table public.import_results enable row level security;

revoke all on table public.import_jobs, public.import_files, public.import_mappings,
  public.import_rows, public.import_errors, public.import_results
  from public, anon, authenticated;

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
    when 'institutions' then app_private.has_platform_permission('institutions.import')
    when 'institutions_export' then app_private.has_platform_permission('institutions.export')
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
    'state', job.processing_state,
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
      'domain', 'institutions', 'label', 'Institui\u00e7\u00f5es', 'template_version', 'v1',
      'import_available', true, 'export_available', true,
      'import_authorized', app_private.has_platform_permission('institutions.import'),
      'export_authorized', app_private.has_platform_permission('institutions.export')
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
      'domain', 'internal_users', 'label', 'Usu\u00e1rios internos', 'template_version', null,
      'import_available', false, 'export_available', false,
      'import_authorized', false, 'export_authorized', false
    )
  ));
end;
$$;

create or replace function app_private.superadmin_list_import_export_jobs(
  p_domains text[] default null,
  p_states text[] default null,
  p_before_created_at timestamptz default null,
  p_before_job_id uuid default null,
  p_page_size integer default 25
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid;
begin
  actor := app_private.assert_import_export_hub_actor();
  if p_page_size not between 1 and 100
    or (p_domains is not null and exists (
      select 1 from unnest(p_domains) domain_name
      where domain_name not in ('institutions', 'units', 'groups', 'activities', 'people', 'internal_users')
    ))
    or (p_states is not null and exists (
      select 1 from unnest(p_states) state_name
      where state_name not in ('PENDENTE', 'PROCESSANDO', 'SUCESSO', 'REJEICAO', 'ERRO')
    ))
  then
    raise invalid_parameter_value using message = 'invalid import/export list filters';
  end if;

  return (
    with limited as (
      select job.id, job.target_domain, job.source_format, job.processing_state,
        job.summary, job.created_at, job.started_at, job.finished_at,
        result_record.created_count, result_record.updated_count,
        result_record.linked_count, result_record.ignored_count, result_record.rejected_count
      from public.import_jobs job
      left join public.import_results result_record on result_record.import_job_id = job.id
      where job.created_by = actor
        and app_private.can_access_import_export_job(job.target_domain)
        and (p_domains is null or cardinality(p_domains) = 0
          or app_private.import_export_job_domain(job.target_domain) = any(p_domains))
        and (p_states is null or cardinality(p_states) = 0
          or job.processing_state::text = any(p_states))
        and (p_before_created_at is null or (job.created_at, job.id) < (
          p_before_created_at,
          coalesce(p_before_job_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)
        ))
      order by job.created_at desc, job.id desc
      limit p_page_size + 1
    ), visible as (
      select * from limited order by created_at desc, id desc limit p_page_size
    ), last_visible as (
      select created_at, id from visible order by created_at asc, id asc limit 1
    )
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'job_id', visible.id,
        'domain', app_private.import_export_job_domain(visible.target_domain),
        'direction', app_private.import_export_job_direction(visible.target_domain),
        'format', visible.source_format,
        'state', visible.processing_state,
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
      'has_more', (select count(*) from limited) > p_page_size,
      'next_cursor', case when (select count(*) from limited) > p_page_size then
        (select jsonb_build_object('created_at', created_at, 'job_id', id) from last_visible)
      else null end
    ) from visible
  );
end;
$$;

create or replace function app_private.superadmin_get_import_export_job(p_import_job_id uuid)
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
  where id = p_import_job_id
    and created_by = actor;

  if job.id is null or not app_private.can_access_import_export_job(job.target_domain) then
    raise insufficient_privilege using message = 'import/export job unavailable';
  end if;
  return app_private.import_export_job_payload(job.id);
end;
$$;

create or replace function public.superadmin_import_export_catalog()
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.superadmin_import_export_catalog() $$;

create or replace function public.superadmin_list_import_export_jobs(
  p_domains text[] default null,
  p_states text[] default null,
  p_before_created_at timestamptz default null,
  p_before_job_id uuid default null,
  p_page_size integer default 25
)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select app_private.superadmin_list_import_export_jobs(
    p_domains, p_states, p_before_created_at, p_before_job_id, p_page_size
  )
$$;

create or replace function public.superadmin_get_import_export_job(p_import_job_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.superadmin_get_import_export_job(p_import_job_id) $$;

revoke all on function public.superadmin_import_export_catalog() from public, anon, authenticated, service_role;
revoke all on function public.superadmin_list_import_export_jobs(text[], text[], timestamptz, uuid, integer)
  from public, anon, authenticated, service_role;
revoke all on function public.superadmin_get_import_export_job(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_import_export_catalog() to authenticated;
grant execute on function public.superadmin_list_import_export_jobs(text[], text[], timestamptz, uuid, integer)
  to authenticated;
grant execute on function public.superadmin_get_import_export_job(uuid) to authenticated;

commit;
