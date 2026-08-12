begin;
select plan(9);

select has_function('public', 'superadmin_list_import_export_jobs', array['text[]','text[]','text[]','text','timestamp with time zone','timestamp with time zone','timestamp with time zone','uuid','integer']);
select function_privs_are('public', 'superadmin_list_import_export_jobs', array['text[]','text[]','text[]','text','timestamp with time zone','timestamp with time zone','timestamp with time zone','uuid','integer'], 'authenticated', array['EXECUTE']);
select ok(not has_function_privilege('anon', 'public.superadmin_list_import_export_jobs(text[],text[],text[],text,timestamp with time zone,timestamp with time zone,timestamp with time zone,uuid,integer)', 'EXECUTE'), 'anonymous callers cannot list with expanded filters');
select ok(not has_function_privilege('authenticated', 'app_private.superadmin_list_import_export_jobs(text[],text[],text[],text,timestamp with time zone,timestamp with time zone,timestamp with time zone,uuid,integer)', 'EXECUTE'), 'expanded listing implementation stays private');

select ok(position('with authorized as materialized' in pg_get_functiondef('app_private.superadmin_list_import_export_jobs(text[],text[],text[],text,timestamp with time zone,timestamp with time zone,timestamp with time zone,uuid,integer)'::regprocedure)) > 0, 'count and page derive from authorized relation');
select ok(position('''total_count''' in pg_get_functiondef('app_private.superadmin_list_import_export_jobs(text[],text[],text[],text,timestamp with time zone,timestamp with time zone,timestamp with time zone,uuid,integer)'::regprocedure)) > 0, 'exact authorized total count is returned');
select ok(position('job.target_domain in (''units'', ''units_export'')' in pg_get_functiondef('app_private.superadmin_list_import_export_jobs(text[],text[],text[],text,timestamp with time zone,timestamp with time zone,timestamp with time zone,uuid,integer)'::regprocedure)) > 0, 'listing is limited to implemented Unit lifecycles');
select ok(position('file_record.file_name ilike' in pg_get_functiondef('app_private.superadmin_list_import_export_jobs(text[],text[],text[],text,timestamp with time zone,timestamp with time zone,timestamp with time zone,uuid,integer)'::regprocedure)) > 0, 'search runs inside the database against authorized jobs and files');
select ok(position('p_created_from' in pg_get_functiondef('app_private.superadmin_list_import_export_jobs(text[],text[],text[],text,timestamp with time zone,timestamp with time zone,timestamp with time zone,uuid,integer)'::regprocedure)) > 0 and position('p_created_to' in pg_get_functiondef('app_private.superadmin_list_import_export_jobs(text[],text[],text[],text,timestamp with time zone,timestamp with time zone,timestamp with time zone,uuid,integer)'::regprocedure)) > 0, 'date range is part of guarded query contract');

select * from finish();
rollback;
