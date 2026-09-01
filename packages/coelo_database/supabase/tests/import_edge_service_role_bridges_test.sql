begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

select has_function(
  'public', 'superadmin_preview_unit_import_from_edge',
  array['uuid','uuid','jsonb','jsonb','text','bigint','text','text']
);
select has_function(
  'public', 'superadmin_fail_unit_file_job',
  array['uuid','text','uuid']
);
select function_privs_are(
  'public', 'superadmin_preview_unit_import_from_edge',
  array['uuid','uuid','jsonb','jsonb','text','bigint','text','text'],
  'service_role', array['EXECUTE']
);
select function_privs_are(
  'public', 'superadmin_fail_unit_file_job',
  array['uuid','text','uuid'], 'service_role', array['EXECUTE']
);
select ok(not has_function_privilege(
  'anon',
  'public.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)',
  'EXECUTE'
), 'anon cannot invoke the import preview Edge bridge');
select ok(not has_function_privilege(
  'authenticated',
  'public.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)',
  'EXECUTE'
), 'authenticated cannot invoke the import preview Edge bridge directly');
select ok(not has_function_privilege(
  'anon', 'public.superadmin_fail_unit_file_job(uuid,text,uuid)', 'EXECUTE'
), 'anon cannot invoke the import failure Edge bridge');
select ok(not has_function_privilege(
  'authenticated', 'public.superadmin_fail_unit_file_job(uuid,text,uuid)', 'EXECUTE'
), 'authenticated cannot invoke the import failure Edge bridge directly');
select ok(not has_function_privilege(
  'service_role',
  'app_private.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)',
  'EXECUTE'
), 'service_role cannot bypass the public preview bridge');
select ok(not has_function_privilege(
  'service_role', 'app_private.superadmin_fail_unit_file_job(uuid,text,uuid)', 'EXECUTE'
), 'service_role cannot bypass the public failure bridge');

select * from finish();
rollback;
