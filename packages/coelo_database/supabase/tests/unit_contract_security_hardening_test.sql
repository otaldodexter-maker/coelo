begin;
select plan(17);

select ok(
  to_regclass('app_private.unit_import_source_attestations') is not null,
  'private import source attestations exist'
);
select ok(
  to_regclass('app_private.unit_export_snapshot_rows') is not null,
  'private export snapshot rows exist'
);
select ok(
  to_regclass('app_private.unit_export_snapshot_rows_job_ordinal_idx') is not null,
  'export snapshot keyset index exists'
);
select has_function(
  'public',
  'superadmin_preview_unit_import_from_edge',
  array['uuid','uuid','jsonb','jsonb','text','bigint','text','text']
);
select has_function(
  'public',
  'superadmin_materialize_unit_export_from_edge',
  array['uuid']
);
select has_function(
  'public',
  'superadmin_unit_export_page_v2',
  array['uuid','bigint','integer']
);
select function_privs_are(
  'public',
  'superadmin_preview_unit_import_from_edge',
  array['uuid','uuid','jsonb','jsonb','text','bigint','text','text'],
  'service_role',
  array['EXECUTE']
);
select function_privs_are(
  'public',
  'superadmin_materialize_unit_export_from_edge',
  array['uuid'],
  'service_role',
  array['EXECUTE']
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.superadmin_preview_unit_import(uuid,uuid,jsonb,jsonb)',
    'EXECUTE'
  ),
  'browser clients cannot submit import preview rows'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.superadmin_unit_export_page(uuid,text,uuid,integer)',
    'EXECUTE'
  ),
  'legacy offset export page is revoked'
);
select function_privs_are(
  'public',
  'superadmin_complete_unit_file_job',
  array['uuid','text','text','text','bigint','text','integer'],
  'service_role',
  array['EXECUTE']
);
select ok(
  exists(
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'unit_identity_object_select'
  ),
  'identity reads remain scoped'
);
select ok(
  not exists(
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'unit_identity_object_insert'
  ),
  'direct identity upload policy is removed'
);
select ok(
  not exists(
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'unit_identity_object_delete'
  ),
  'direct identity delete policy is removed'
);
select ok(
  exists(
    select 1
    from pg_trigger trigger_record
    join pg_class relation_record on relation_record.oid = trigger_record.tgrelid
    join pg_namespace namespace_record on namespace_record.oid = relation_record.relnamespace
    where namespace_record.nspname = 'public'
      and relation_record.relname = 'unit_branding'
      and trigger_record.tgname = 'unit_branding_enforce_identity_ownership'
      and not trigger_record.tgisinternal
  ),
  'branding ownership trigger exists'
);
select ok(
  pg_get_functiondef(
    'app_private.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)'::regprocedure
  ) like '%storage.objects%'
  and pg_get_functiondef(
    'app_private.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)'::regprocedure
  ) like '%request.jwt.claims%',
  'Edge preview verifies Storage and restores the job actor'
);
select ok(
  position(
    'offset' in lower(
      pg_get_functiondef(
        'app_private.superadmin_unit_export_page_v2(uuid,bigint,integer)'::regprocedure
      )
    )
  ) = 0,
  'keyset page has no OFFSET'
);

select * from finish();
rollback;
