begin;

-- Count, page and every filter use exactly the same authorized relation.
create or replace function app_private.superadmin_list_import_export_jobs(
  p_domains text[], p_states text[], p_formats text[], p_search text,
  p_created_from timestamptz, p_created_to timestamptz,
  p_before_created_at timestamptz, p_before_job_id uuid, p_page_size integer
)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  actor uuid;
  normalized_search text := nullif(btrim(p_search), '');
  escaped_search text;
begin
  actor := app_private.assert_import_export_hub_actor();
  if p_page_size not between 1 and 100
    or (p_domains is not null and exists (select 1 from unnest(p_domains) domain_name where domain_name <> 'units'))
    or (p_states is not null and exists (select 1 from unnest(p_states) state_name where state_name not in ('PENDENTE','PROCESSANDO','SUCESSO','REJEICAO','ERRO')))
    or (p_formats is not null and exists (select 1 from unnest(p_formats) format_name where format_name not in ('csv','xlsx')))
    or (normalized_search is not null and (char_length(normalized_search) > 120 or normalized_search ~ '[[:cntrl:]]'))
    or (p_created_from is not null and p_created_to is not null and p_created_from > p_created_to)
  then raise invalid_parameter_value using message = 'invalid import/export list filters'; end if;

  escaped_search := case when normalized_search is null then null else
    replace(replace(replace(normalized_search, chr(92), chr(92) || chr(92)), '%', chr(92) || '%'), '_', chr(92) || '_')
  end;

  return (
    with authorized as materialized (
      select job.id, job.target_domain, job.source_format, job.processing_state,
        job.summary, job.created_at, job.started_at, job.finished_at,
        result_record.created_count, result_record.updated_count, result_record.linked_count,
        result_record.ignored_count, result_record.rejected_count
      from public.import_jobs job
      left join public.import_results result_record on result_record.import_job_id = job.id
      where job.created_by = actor
        and job.target_domain in ('units', 'units_export')
        and app_private.can_access_import_export_job(job.target_domain)
        and (p_domains is null or cardinality(p_domains) = 0 or app_private.import_export_job_domain(job.target_domain) = any(p_domains))
        and (p_states is null or cardinality(p_states) = 0 or job.processing_state::text = any(p_states))
        and (p_formats is null or cardinality(p_formats) = 0 or job.source_format = any(p_formats))
        and (p_created_from is null or job.created_at >= p_created_from)
        and (p_created_to is null or job.created_at <= p_created_to)
        and (escaped_search is null
          or job.target_domain ilike '%' || escaped_search || '%' escape chr(92)
          or job.source_format ilike '%' || escaped_search || '%' escape chr(92)
          or exists (select 1 from public.import_files file_record where file_record.import_job_id = job.id and file_record.file_name ilike '%' || escaped_search || '%' escape chr(92)))
    ), windowed as materialized (
      select * from authorized
      where p_before_created_at is null or (created_at, id) < (p_before_created_at, coalesce(p_before_job_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid))
      order by created_at desc, id desc limit p_page_size + 1
    ), visible as materialized (
      select * from windowed order by created_at desc, id desc limit p_page_size
    ), last_visible as (
      select created_at, id from visible order by created_at asc, id asc limit 1
    )
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'job_id', visible.id, 'domain', app_private.import_export_job_domain(visible.target_domain),
        'direction', app_private.import_export_job_direction(visible.target_domain), 'format', visible.source_format,
        'state', visible.processing_state, 'created_at', visible.created_at, 'started_at', visible.started_at,
        'finished_at', visible.finished_at, 'summary', jsonb_strip_nulls(jsonb_build_object(
          'phase', visible.summary ->> 'phase', 'valid_count', visible.summary -> 'valid_count',
          'rejected_count', visible.summary -> 'rejected_count', 'row_count', visible.summary -> 'row_count')),
        'result', jsonb_strip_nulls(jsonb_build_object('created_count', visible.created_count,
          'updated_count', visible.updated_count, 'linked_count', visible.linked_count,
          'ignored_count', visible.ignored_count, 'rejected_count', visible.rejected_count))
      ) order by visible.created_at desc, visible.id desc), '[]'::jsonb),
      'total_count', (select count(*) from authorized),
      'has_more', (select count(*) from windowed) > p_page_size,
      'next_cursor', case when (select count(*) from windowed) > p_page_size
        then (select jsonb_build_object('created_at', created_at, 'job_id', id) from last_visible) else null end
    ) from visible
  );
end;
$$;

create or replace function public.superadmin_list_import_export_jobs(
  p_domains text[], p_states text[], p_formats text[], p_search text,
  p_created_from timestamptz, p_created_to timestamptz,
  p_before_created_at timestamptz, p_before_job_id uuid, p_page_size integer
) returns jsonb language sql stable security definer set search_path = '' as $$
  select app_private.superadmin_list_import_export_jobs($1,$2,$3,$4,$5,$6,$7,$8,$9)
$$;

revoke all on function app_private.superadmin_list_import_export_jobs(text[],text[],text[],text,timestamptz,timestamptz,timestamptz,uuid,integer) from public, anon, authenticated, service_role;
revoke all on function public.superadmin_list_import_export_jobs(text[],text[],text[],text,timestamptz,timestamptz,timestamptz,uuid,integer) from public, anon, authenticated, service_role;
grant execute on function public.superadmin_list_import_export_jobs(text[],text[],text[],text,timestamptz,timestamptz,timestamptz,uuid,integer) to authenticated;
commit;
