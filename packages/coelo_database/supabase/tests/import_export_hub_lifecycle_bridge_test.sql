begin;
select plan(8);

select has_function(
  'public',
  'superadmin_create_import_export_job',
  array['text', 'text', 'text', 'text', 'uuid']
);
select has_function(
  'public',
  'superadmin_import_export_upload_contract',
  array['uuid']
);
select has_function(
  'public',
  'superadmin_confirm_import_export_job',
  array['uuid', 'uuid']
);
select has_function(
  'public',
  'superadmin_retry_import_export_job',
  array['uuid', 'uuid']
);
select has_function(
  'public',
  'superadmin_request_import_export',
  array['text', 'text', 'jsonb', 'jsonb', 'uuid']
);
select function_privs_are(
  'public', 'superadmin_create_import_export_job',
  array['text', 'text', 'text', 'text', 'uuid'], 'authenticated', array['EXECUTE']
);
select ok(
  not has_function_privilege(
    'anon',
    'public.superadmin_create_import_export_job(text,text,text,text,uuid)',
    'EXECUTE'
  ),
  'anonymous callers cannot create a hub job'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.superadmin_create_import_export_job(text,text,text,text,uuid)',
    'EXECUTE'
  ),
  'bridge implementation stays private'
);

select * from finish();
rollback;
