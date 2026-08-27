begin;

create or replace function app_private.reconcile_unit_import_export_function_acl()
returns void language plpgsql volatile security definer set search_path='' as $$
declare
  private_signatures constant text[]:=array[
    'app_private.assert_import_export_hub_actor()',
    'app_private.can_access_import_export_job(text)',
    'app_private.import_export_job_direction(text)',
    'app_private.import_export_job_domain(text)',
    'app_private.import_export_job_payload(uuid)',
    'app_private.superadmin_import_export_catalog()',
    'app_private.superadmin_list_import_export_jobs(text[],text[],timestamptz,uuid,integer)',
    'app_private.superadmin_list_import_export_jobs(text[],text[],text[],text,timestamptz,timestamptz,timestamptz,uuid,integer)',
    'app_private.superadmin_get_import_export_job(uuid)',
    'app_private.superadmin_create_import_export_job(text,text,text,text,uuid)',
    'app_private.superadmin_import_export_upload_contract(uuid)',
    'app_private.superadmin_confirm_import_export_job(uuid,uuid)',
    'app_private.superadmin_retry_import_export_job(uuid,uuid)',
    'app_private.superadmin_request_import_export(text,text,jsonb,jsonb,uuid)',
    'app_private.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)',
    'app_private.superadmin_materialize_unit_export_from_edge(uuid)',
    'app_private.superadmin_unit_export_page_v2(uuid,bigint,integer)',
    'app_private.superadmin_complete_unit_file_job(uuid,text,text,text,bigint,text,integer)',
    'app_private.enforce_unit_branding_identity_ownership()',
    'app_private.unit_file_job_payload(uuid)',
    'app_private.assert_unit_file_access(text,uuid)',
    'app_private.superadmin_unit_import_template()',
    'app_private.superadmin_create_unit_import_job(text,text,text,uuid)',
    'app_private.superadmin_preview_unit_import(uuid,uuid,jsonb,jsonb)',
    'app_private.superadmin_confirm_unit_import(uuid,uuid)',
    'app_private.superadmin_retry_unit_import(uuid,uuid)',
    'app_private.superadmin_request_unit_export(text,jsonb,jsonb,uuid)',
    'app_private.superadmin_unit_export_page(uuid,text,uuid,integer)',
    'app_private.superadmin_fail_unit_file_job(uuid,text)',
    'app_private.superadmin_fail_unit_file_job(uuid,text,uuid)',
    'app_private.superadmin_get_unit_file_job(uuid)',
    'app_private.attest_unit_import_file_retention()'
  ];
  authenticated_gateways constant text[]:=array[
    'public.superadmin_import_export_catalog()',
    'public.superadmin_list_import_export_jobs(text[],text[],timestamptz,uuid,integer)',
    'public.superadmin_list_import_export_jobs(text[],text[],text[],text,timestamptz,timestamptz,timestamptz,uuid,integer)',
    'public.superadmin_get_import_export_job(uuid)',
    'public.superadmin_create_import_export_job(text,text,text,text,uuid)',
    'public.superadmin_import_export_upload_contract(uuid)',
    'public.superadmin_confirm_import_export_job(uuid,uuid)',
    'public.superadmin_retry_import_export_job(uuid,uuid)',
    'public.superadmin_request_import_export(text,text,jsonb,jsonb,uuid)',
    'public.superadmin_unit_import_template()',
    'public.superadmin_create_unit_import_job(text,text,text,uuid)',
    'public.superadmin_confirm_unit_import(uuid,uuid)',
    'public.superadmin_retry_unit_import(uuid,uuid)',
    'public.superadmin_request_unit_export(text,jsonb,jsonb,uuid)',
    'public.superadmin_unit_export_page_v2(uuid,bigint,integer)',
    'public.superadmin_get_unit_file_job(uuid)'
  ];
  service_gateways constant text[]:=array[
    'public.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)',
    'public.superadmin_materialize_unit_export_from_edge(uuid)',
    'public.superadmin_complete_unit_file_job(uuid,text,text,text,bigint,text,integer)',
    'public.superadmin_fail_unit_file_job(uuid,text,uuid)'
  ];
  denied_public_gateways constant text[]:=array[
    'public.superadmin_preview_unit_import(uuid,uuid,jsonb,jsonb)',
    'public.superadmin_unit_export_page(uuid,text,uuid,integer)',
    'public.superadmin_fail_unit_file_job(uuid,text)'
  ];
  signature text; function_oid oid; function_record record;
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using message='unit import/export ACL reconciliation requires postgres';
  end if;
  foreach signature in array private_signatures loop
    function_oid:=pg_catalog.to_regprocedure(signature);
    if function_oid is null then continue; end if;
    select procedure_record.proowner,procedure_record.prosecdef,procedure_record.proconfig
      into function_record from pg_catalog.pg_proc procedure_record
      where procedure_record.oid=function_oid;
    if function_record.proowner<>'postgres'::regrole
      or not(coalesce(function_record.proconfig,'{}'::text[])
        @> array['search_path=""']::text[]) then
      raise object_not_in_prerequisite_state using
        message='unexpected private import/export function owner or search_path';
    end if;
    execute pg_catalog.format('revoke all on function %s from public, anon, authenticated, service_role',
      function_oid::regprocedure);
  end loop;
  foreach signature in array authenticated_gateways loop
    function_oid:=pg_catalog.to_regprocedure(signature);
    if function_oid is null then continue; end if;
    select procedure_record.proowner,procedure_record.prosecdef,procedure_record.proconfig
      into function_record from pg_catalog.pg_proc procedure_record
      where procedure_record.oid=function_oid;
    if function_record.proowner<>'postgres'::regrole or not function_record.prosecdef
      or not(coalesce(function_record.proconfig,'{}'::text[])
        @> array['search_path=""']::text[]) then
      raise object_not_in_prerequisite_state using
        message='unexpected authenticated import/export gateway metadata';
    end if;
    execute pg_catalog.format('revoke all on function %s from public, anon, authenticated, service_role',
      function_oid::regprocedure);
    execute pg_catalog.format('grant execute on function %s to authenticated',function_oid::regprocedure);
  end loop;
  foreach signature in array service_gateways loop
    function_oid:=pg_catalog.to_regprocedure(signature);
    if function_oid is null then continue; end if;
    select procedure_record.proowner,procedure_record.prosecdef,procedure_record.proconfig
      into function_record from pg_catalog.pg_proc procedure_record
      where procedure_record.oid=function_oid;
    if function_record.proowner<>'postgres'::regrole or not function_record.prosecdef
      or not(coalesce(function_record.proconfig,'{}'::text[])
        @> array['search_path=""']::text[]) then
      raise object_not_in_prerequisite_state using
        message='unexpected service import/export gateway metadata';
    end if;
    execute pg_catalog.format('revoke all on function %s from public, anon, authenticated, service_role',
      function_oid::regprocedure);
    execute pg_catalog.format('grant execute on function %s to service_role',function_oid::regprocedure);
  end loop;
  foreach signature in array denied_public_gateways loop
    function_oid:=pg_catalog.to_regprocedure(signature);
    if function_oid is null then continue; end if;
    select procedure_record.proowner,procedure_record.proconfig
      into function_record from pg_catalog.pg_proc procedure_record
      where procedure_record.oid=function_oid;
    if function_record.proowner<>'postgres'::regrole
      or not(coalesce(function_record.proconfig,'{}'::text[])
        @> array['search_path=""']::text[]) then
      raise object_not_in_prerequisite_state using
        message='unexpected denied import/export gateway metadata';
    end if;
    execute pg_catalog.format('revoke all on function %s from public, anon, authenticated, service_role',
      function_oid::regprocedure);
  end loop;
end
$$;

revoke all on function app_private.reconcile_unit_import_export_function_acl()
  from public,anon,authenticated,service_role;
select app_private.reconcile_unit_import_export_function_acl();

commit;
