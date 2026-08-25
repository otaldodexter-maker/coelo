create or replace function public.superadmin_fail_unit_file_job(
  p_import_job_id uuid,
  p_error_code text,
  p_expected_request_id uuid
)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select app_private.superadmin_fail_unit_file_job($1, $2, $3)
$$;

revoke all on function public.superadmin_fail_unit_file_job(uuid, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_fail_unit_file_job(uuid, text, uuid)
  to service_role;
