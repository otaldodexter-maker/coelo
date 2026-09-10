begin;

-- PostgREST resolves Edge Function RPC calls in the public schema. Keep the
-- implementation private and expose only the two service-role bridges used by
-- import-export-jobs for preview and auditable failure recording.
create or replace function public.superadmin_preview_unit_import_from_edge(
  p_request_id uuid,
  p_import_job_id uuid,
  p_rows jsonb,
  p_mapping_columns jsonb,
  p_checksum_sha256 text,
  p_size_bytes bigint,
  p_mime_type text,
  p_parser_version text
)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select app_private.superadmin_preview_unit_import_from_edge(
    $1,$2,$3,$4,$5,$6,$7,$8
  )
$$;

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
as $$ select app_private.superadmin_fail_unit_file_job($1,$2,$3) $$;

revoke all on function public.superadmin_preview_unit_import_from_edge(
  uuid,uuid,jsonb,jsonb,text,bigint,text,text
), public.superadmin_fail_unit_file_job(uuid,text,uuid)
from public, anon, authenticated, service_role;

grant execute on function public.superadmin_preview_unit_import_from_edge(
  uuid,uuid,jsonb,jsonb,text,bigint,text,text
), public.superadmin_fail_unit_file_job(uuid,text,uuid)
to service_role;

revoke all on function app_private.superadmin_preview_unit_import_from_edge(
  uuid,uuid,jsonb,jsonb,text,bigint,text,text
), app_private.superadmin_fail_unit_file_job(uuid,text,uuid)
from public, anon, authenticated, service_role;

do $$
declare
  signature text;
  function_oid oid;
begin
  foreach signature in array array[
    'public.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)',
    'public.superadmin_fail_unit_file_job(uuid,text,uuid)'
  ] loop
    function_oid := pg_catalog.to_regprocedure(signature);
    if function_oid is null
      or not pg_catalog.has_function_privilege('service_role', function_oid, 'EXECUTE')
      or pg_catalog.has_function_privilege('anon', function_oid, 'EXECUTE')
      or pg_catalog.has_function_privilege('authenticated', function_oid, 'EXECUTE')
      or not exists (
        select 1 from pg_catalog.pg_proc procedure_record
        where procedure_record.oid = function_oid
          and procedure_record.prosecdef
          and coalesce(procedure_record.proconfig, '{}'::text[])
            @> array['search_path=""']::text[]
      )
    then
      raise object_not_in_prerequisite_state
        using message = 'unexpected import Edge bridge ACL: ' || signature;
    end if;
  end loop;

  foreach signature in array array[
    'app_private.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)',
    'app_private.superadmin_fail_unit_file_job(uuid,text,uuid)'
  ] loop
    function_oid := pg_catalog.to_regprocedure(signature);
    if function_oid is null
      or pg_catalog.has_function_privilege('anon', function_oid, 'EXECUTE')
      or pg_catalog.has_function_privilege('authenticated', function_oid, 'EXECUTE')
      or pg_catalog.has_function_privilege('service_role', function_oid, 'EXECUTE')
      or exists (
        select 1
        from pg_catalog.pg_proc procedure_record,
          lateral pg_catalog.aclexplode(coalesce(
            procedure_record.proacl,
            pg_catalog.acldefault('f', procedure_record.proowner)
          )) acl
        where procedure_record.oid = function_oid
          and acl.grantee = 0
          and acl.privilege_type = 'EXECUTE'
      )
    then
      raise object_not_in_prerequisite_state
        using message = 'private import helper execution path remains: ' || signature;
    end if;
  end loop;
end
$$;

commit;
