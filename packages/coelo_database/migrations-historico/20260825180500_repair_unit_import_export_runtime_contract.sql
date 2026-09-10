-- Repair locally installed Unit import/export worker functions without widening grants.
drop function if exists public.superadmin_file_job_fail(uuid, text);
drop function if exists app_private.superadmin_file_job_fail(uuid, text);

create or replace function app_private.superadmin_confirm_unit_import(
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
  source_row record;
  v_created_count integer := 0;
  v_rejected_count integer := 0;
begin
  actor := app_private.assert_unit_file_access('units.import', null);
  if p_request_id is null then
    raise invalid_parameter_value using message = 'request required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_import_job_id::text, 0));
  select * into job from public.import_jobs where id = p_import_job_id for update;
  if job.id is null then
    raise no_data_found using message = 'unit import not found';
  end if;
  if job.target_domain <> 'units' or job.created_by <> actor then
    raise insufficient_privilege using message = 'unit import outside actor scope';
  end if;
  if job.summary->>'confirm_request_id' = p_request_id::text
     or job.processing_state in ('SUCESSO', 'REJEICAO') then
    return app_private.unit_file_job_payload(job.id);
  end if;
  if job.summary->>'phase' <> 'preview' then
    raise object_not_in_prerequisite_state using message = 'preview required';
  end if;

  update public.import_jobs
  set processing_state = 'PROCESSANDO',
      status = 'active',
      started_at = coalesce(started_at, now()),
      updated_at = now()
  where id = job.id;

  for source_row in
    select * from public.import_rows r
    where r.import_job_id = job.id and r.error_code is null
    order by r.row_number
  loop
    begin
      perform app_private.create_unit_for_superadmin(
        (source_row.payload_json->>'request_id')::uuid,
        source_row.payload_json
      );
      v_created_count := v_created_count + 1;
      update public.import_rows set status = 'active' where id = source_row.id;
    exception when others then
      v_rejected_count := v_rejected_count + 1;
      update public.import_rows
      set status = 'archived', error_code = 'create_rejected'
      where id = source_row.id;
      insert into public.import_errors(import_job_id, row_number, error_code, message)
      values (
        job.id,
        source_row.row_number,
        'create_rejected',
        'Linha rejeitada durante a criacao segura da unidade.'
      );
    end;
  end loop;

  v_rejected_count := v_rejected_count + (
    select count(*) from public.import_rows r
    where r.import_job_id = job.id
      and r.error_code is not null
      and r.error_code <> 'create_rejected'
  );

  update public.import_results
  set created_count = v_created_count,
      rejected_count = v_rejected_count,
      completed_at = now()
  where import_job_id = job.id;

  update public.import_jobs
  set processing_state = case
        when v_rejected_count = 0 then 'SUCESSO'::public.import_processing_state
        else 'REJEICAO'::public.import_processing_state
      end,
      status = case
        when v_rejected_count = 0 then 'active'::public.record_status
        else 'draft'::public.record_status
      end,
      finished_at = now(),
      summary = summary || jsonb_build_object(
        'phase', 'complete',
        'confirm_request_id', p_request_id
      ),
      updated_at = now()
  where id = job.id;

  insert into audit.audit_logs(
    actor_person_id,
    mfa_aal,
    action_code,
    object_type,
    object_id,
    outcome,
    after_json
  ) values (
    actor,
    'aal2',
    'unit.import.confirm',
    'import_job',
    job.id,
    case
      when v_rejected_count = 0 then 'success'::public.audit_outcome
      else 'failed'::public.audit_outcome
    end,
    jsonb_build_object('created', v_created_count, 'rejected', v_rejected_count)
  );
  return app_private.unit_file_job_payload(job.id);
end;
$$;

create or replace function app_private.superadmin_fail_unit_file_job(
  p_import_job_id uuid,
  p_error_code text,
  p_expected_request_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  job public.import_jobs%rowtype;
begin
  select * into job
  from public.import_jobs
  where id = p_import_job_id
  for update;

  if job.id is null
     or job.target_domain not in ('units', 'units_export')
     or job.request_id is distinct from p_expected_request_id then
    raise insufficient_privilege
      using message = 'unit_file_job_outside_edge_execution_scope';
  end if;
  if job.processing_state in ('SUCESSO', 'ERRO') then
    return app_private.unit_file_job_payload(job.id);
  end if;
  if job.processing_state not in ('PENDENTE', 'PROCESSANDO', 'REJEICAO') then
    raise object_not_in_prerequisite_state
      using message = 'unit_file_state_unavailable';
  end if;

  update public.import_jobs
  set processing_state = 'ERRO',
      status = 'draft',
      finished_at = now(),
      summary = summary || jsonb_build_object(
        'phase', 'failed',
        'progress', 100,
        'error_code', left(coalesce(p_error_code, 'worker_error'), 80)
      ),
      updated_at = now()
  where id = job.id;

  insert into audit.audit_logs(
    actor_person_id,
    mfa_aal,
    action_code,
    object_type,
    object_id,
    outcome,
    after_json
  ) values (
    job.created_by,
    'aal2',
    'unit.file.fail',
    'import_job',
    job.id,
    'failed',
    jsonb_build_object(
      'error_code', left(coalesce(p_error_code, 'worker_error'), 80)
    )
  );

  return app_private.unit_file_job_payload(job.id);
end;
$$;

revoke all on function app_private.superadmin_confirm_unit_import(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function app_private.superadmin_fail_unit_file_job(uuid, text, uuid)
  from public, anon, authenticated, service_role;

revoke all on function public.superadmin_fail_unit_file_job(uuid, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_fail_unit_file_job(uuid, text, uuid)
  to service_role;
