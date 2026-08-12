begin;
select plan(10);

select has_function('app_private', 'import_export_job_direction', array['text']);
select has_function('app_private', 'import_export_job_domain', array['text']);
select has_function(
  'app_private',
  'superadmin_preview_unit_import_from_edge',
  array['uuid', 'uuid', 'jsonb', 'jsonb', 'text', 'bigint', 'text', 'text']
);
select has_function(
  'app_private',
  'superadmin_materialize_unit_export_from_edge',
  array['uuid']
);
select has_function(
  'app_private',
  'superadmin_unit_export_page_v2',
  array['uuid', 'bigint', 'integer']
);

select ok(
  not has_function_privilege('authenticated', 'app_private.import_export_job_direction(text)', 'EXECUTE'),
  'browser callers cannot invoke the private direction helper'
);
select ok(
  not has_function_privilege('authenticated', 'app_private.import_export_job_domain(text)', 'EXECUTE'),
  'browser callers cannot invoke the private domain helper'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)',
    'EXECUTE'
  ),
  'browser callers cannot submit parsed rows to the private edge preview worker'
);
select ok(
  not has_function_privilege('authenticated', 'app_private.superadmin_materialize_unit_export_from_edge(uuid)', 'EXECUTE'),
  'browser callers cannot materialize an export snapshot'
);
select ok(
  not has_function_privilege('authenticated', 'app_private.superadmin_unit_export_page_v2(uuid,bigint,integer)', 'EXECUTE'),
  'browser callers use the guarded public export-page gateway only'
);

select * from finish();
rollback;
