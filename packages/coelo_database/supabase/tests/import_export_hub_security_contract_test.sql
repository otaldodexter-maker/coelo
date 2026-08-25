begin;
select plan(23);

select has_function('public', 'superadmin_import_export_catalog', array[]::text[]);
select has_function(
  'public', 'superadmin_list_import_export_jobs',
  array['text[]', 'text[]', 'timestamp with time zone', 'uuid', 'integer']
);
select has_function('public', 'superadmin_get_import_export_job', array['uuid']);

select function_privs_are(
  'public', 'superadmin_import_export_catalog', array[]::text[], 'authenticated', array['EXECUTE']
);
select function_privs_are(
  'public', 'superadmin_list_import_export_jobs',
  array['text[]', 'text[]', 'timestamp with time zone', 'uuid', 'integer'],
  'authenticated', array['EXECUTE']
);
select function_privs_are(
  'public', 'superadmin_get_import_export_job', array['uuid'], 'authenticated', array['EXECUTE']
);

select ok(not has_function_privilege('anon', 'public.superadmin_import_export_catalog()', 'EXECUTE'),
  'anonymous users cannot inspect the import/export catalog');
select ok(not has_function_privilege(
  'anon', 'public.superadmin_list_import_export_jobs(text[],text[],timestamp with time zone,uuid,integer)', 'EXECUTE'
), 'anonymous users cannot list import/export jobs');
select ok(not has_function_privilege('anon', 'public.superadmin_get_import_export_job(uuid)', 'EXECUTE'),
  'anonymous users cannot fetch an import/export job');
select ok(not has_function_privilege('authenticated', 'app_private.assert_import_export_hub_actor()', 'EXECUTE'),
  'browser callers cannot invoke the private AAL2 authorization helper');
select ok(not has_function_privilege('authenticated', 'app_private.import_export_job_payload(uuid)', 'EXECUTE'),
  'browser callers cannot invoke the private job payload helper');

select ok((select relrowsecurity from pg_class where oid = 'public.import_jobs'::regclass),
  'RLS is enabled on import_jobs');
select ok((select relrowsecurity from pg_class where oid = 'public.import_files'::regclass),
  'RLS is enabled on import_files');
select ok((select relrowsecurity from pg_class where oid = 'public.import_mappings'::regclass),
  'RLS is enabled on import_mappings');
select ok((select relrowsecurity from pg_class where oid = 'public.import_rows'::regclass),
  'RLS is enabled on import_rows');
select ok((select relrowsecurity from pg_class where oid = 'public.import_errors'::regclass),
  'RLS is enabled on import_errors');
select ok((select relrowsecurity from pg_class where oid = 'public.import_results'::regclass),
  'RLS is enabled on import_results');

select table_privs_are('public', 'import_jobs', 'authenticated', array[]::text[]);
select table_privs_are('public', 'import_files', 'authenticated', array[]::text[]);
select table_privs_are('public', 'import_rows', 'authenticated', array[]::text[]);

select col_is_null('public', 'import_files', 'checksum_sha256',
  'legacy import files remain compatible while new workers attest checksums');
select ok(exists (
  select 1 from pg_constraint
  where conrelid = 'public.import_files'::regclass
    and conname = 'import_files_checksum_sha256_format_check'
    and contype = 'c'
), 'import files require SHA-256 checksum syntax when supplied');
select ok(exists (
  select 1 from pg_constraint
  where conrelid = 'public.import_files'::regclass
    and conname = 'import_files_retention_after_upload_check'
    and contype = 'c'
), 'import file retention cannot predate upload');

select * from finish();
rollback;
