begin;
select plan(31);

select has_function('public', 'superadmin_create_unit_import_job', array['text','text','text','uuid']);
select has_function('public', 'superadmin_preview_unit_import', array['uuid','uuid','jsonb','jsonb']);
select has_function('public', 'superadmin_confirm_unit_import', array['uuid','uuid']);
select has_function('public', 'superadmin_retry_unit_import', array['uuid','uuid']);
select has_function('public', 'superadmin_request_unit_export', array['text','jsonb','jsonb','uuid']);
select has_function('public', 'superadmin_unit_export_page', array['uuid','text','uuid','integer']);
select has_function('public', 'superadmin_complete_unit_file_job', array['uuid','text','text','text','bigint','text','integer']);
select hasnt_function('public', 'superadmin_fail_unit_file_job', array['uuid','text'],
  'legacy public failure worker wrapper is absent');
select has_function('public', 'superadmin_fail_unit_file_job', array['uuid','text','uuid'],
  'scoped failure worker gateway exists');

select function_privs_are(
  'public', 'superadmin_create_unit_import_job', array['text','text','text','uuid'],
  'authenticated', array[]::text[]
);
select function_privs_are(
  'public', 'superadmin_request_unit_export', array['text','jsonb','jsonb','uuid'],
  'authenticated', array['EXECUTE']
);
select function_privs_are(
  'public', 'superadmin_complete_unit_file_job',
  array['uuid','text','text','text','bigint','text','integer'],
  'service_role', array['EXECUTE']
);
select function_privs_are(
  'public', 'superadmin_fail_unit_file_job', array['uuid','text','uuid'],
  'service_role', array['EXECUTE']
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.superadmin_fail_unit_file_job(uuid,text,uuid)',
    'EXECUTE'
  ),
  'browser clients cannot fail storage jobs'
);

select ok(
  not has_function_privilege('anon', 'public.superadmin_create_unit_import_job(text,text,text,uuid)', 'EXECUTE'),
  'anonymous users cannot create unit import jobs'
);
select ok(
  not has_function_privilege('anon', 'public.superadmin_request_unit_export(text,jsonb,jsonb,uuid)', 'EXECUTE'),
  'anonymous users cannot request unit exports'
);
select ok(
  not has_function_privilege('authenticated', 'public.superadmin_complete_unit_file_job(uuid,text,text,text,bigint,text,integer)', 'EXECUTE'),
  'browser clients cannot complete storage jobs'
);
select ok(
  (select prosecdef and array_to_string(proconfig, ',') like 'search_path=%'
   from pg_proc where oid = 'public.superadmin_create_unit_import_job(text,text,text,uuid)'::regprocedure),
  'unit import gateway is security definer with empty search_path'
);
select ok(
  (select prosecdef and array_to_string(proconfig, ',') like 'search_path=%'
   from pg_proc where oid = 'public.superadmin_request_unit_export(text,jsonb,jsonb,uuid)'::regprocedure),
  'unit export gateway is security definer with empty search_path'
);
select ok(
  exists(select 1 from public.platform_permissions where code = 'units.import' and requires_mfa)
  and exists(select 1 from public.platform_permissions where code = 'units.export' and requires_mfa),
  'unit file operations require explicit MFA-protected capabilities'
);
select ok(
  exists(select 1 from pg_indexes where schemaname = 'public' and indexname = 'import_jobs_unit_scope_state_idx'),
  'unit jobs have a scoped processing index'
);

select is(
  (select coalesce(proargnames, array[]::text[]) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'superadmin_create_unit_import_job' and oidvectortypes(p.proargtypes) = 'text, text, text, uuid'),
  array['p_file_name','p_mime_type','p_source_format','p_idempotency_key']::text[],
  'unit import create wrapper uses named rpc parameters'
);
select is(
  (select coalesce(proargnames, array[]::text[]) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'superadmin_preview_unit_import' and oidvectortypes(p.proargtypes) = 'uuid, uuid, jsonb, jsonb'),
  array['p_request_id','p_import_job_id','p_rows','p_mapping']::text[],
  'unit import preview wrapper uses named rpc parameters'
);
select is(
  (select coalesce(proargnames, array[]::text[]) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'superadmin_confirm_unit_import' and oidvectortypes(p.proargtypes) = 'uuid, uuid'),
  array['p_request_id','p_import_job_id']::text[],
  'unit import confirm wrapper uses named rpc parameters'
);
select is(
  (select coalesce(proargnames, array[]::text[]) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'superadmin_retry_unit_import' and oidvectortypes(p.proargtypes) = 'uuid, uuid'),
  array['p_request_id','p_import_job_id']::text[],
  'unit import retry wrapper uses named rpc parameters'
);
select is(
  (select coalesce(proargnames, array[]::text[]) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'superadmin_request_unit_export' and oidvectortypes(p.proargtypes) = 'text, jsonb, jsonb, uuid'),
  array['p_format','p_filters','p_current_view','p_idempotency_key']::text[],
  'unit export request wrapper uses named rpc parameters'
);
select is(
  (select coalesce(proargnames, array[]::text[]) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'superadmin_unit_export_page' and oidvectortypes(p.proargtypes) = 'uuid, text, uuid, integer'),
  array['p_import_job_id','p_cursor_text','p_cursor_id','p_page_size']::text[],
  'unit export page wrapper uses named rpc parameters'
);
select is(
  (select coalesce(proargnames, array[]::text[]) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'superadmin_complete_unit_file_job' and oidvectortypes(p.proargtypes) = 'uuid, text, text, text, bigint, text, integer'),
  array['p_import_job_id','p_storage_path','p_file_name','p_mime_type','p_size_bytes','p_checksum_sha256','p_row_count']::text[],
  'unit export completion wrapper uses named rpc parameters'
);
select ok(
  to_regprocedure('public.superadmin_fail_unit_file_job(uuid,text)') is null,
  'unit export failure is not exposed through a legacy public worker wrapper'
);
select is(
  (select coalesce(proargnames, array[]::text[]) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'superadmin_get_unit_file_job' and oidvectortypes(p.proargtypes) = 'uuid'),
  array['p_import_job_id']::text[],
  'unit file job getter uses named rpc parameters'
);
select ok(
  position(
    'created_count=v_created_count,rejected_count=v_rejected_count'
    in regexp_replace(
      pg_get_functiondef('app_private.superadmin_confirm_unit_import(uuid,uuid)'::regprocedure),
      '[[:space:]]',
      '',
      'g'
    )
  ) > 0,
  'unit import completion persists independent created and rejected counters'
);
select * from finish();
rollback;
