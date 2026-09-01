begin;

select plan(20);

select ok(
  to_regprocedure(
    'public.superadmin_institution_directory_v2(jsonb,integer,integer,text,boolean)'
  ) is not null,
  'Institution directory v2 remains present'
);
select ok(
  to_regprocedure('public.superadmin_institution_filter_options_v2(text[],text[])') is not null,
  'Institution filter options v2 remain present'
);
select ok(
  to_regprocedure('public.superadmin_institution_detail_v2(uuid)') is not null,
  'Institution detail v2 remains present'
);
select ok(
  to_regprocedure(
    'public.superadmin_institution_edit_core_v2(uuid,uuid,bigint,jsonb)'
  ) is not null,
  'Institution edit-core v2 remains present'
);
select ok(
  to_regprocedure('public.superadmin_unit_detail_v2(uuid)') is not null,
  'Unit detail v2 remains present'
);
select ok(
  to_regprocedure('public.superadmin_group_detail_v2(uuid)') is not null,
  'Group detail v2 remains present'
);
select ok(
  to_regprocedure('app_private.assert_unit_hierarchy_contract()') is not null,
  'Unit hierarchy provenance guard remains present'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_proc as procedure_record
    join pg_catalog.pg_namespace as namespace_record
      on namespace_record.oid = procedure_record.pronamespace
    where namespace_record.nspname = 'public'
      and procedure_record.proname = 'superadmin_institution_create_v2'
  ),
  0::bigint,
  'Institution create v2 is absent until an approved contract exists'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_proc as procedure_record
    join pg_catalog.pg_namespace as namespace_record
      on namespace_record.oid = procedure_record.pronamespace
    where namespace_record.nspname = 'public'
      and procedure_record.proname = 'superadmin_institution_status_v2'
  ),
  0::bigint,
  'Institution status v2 is absent until an approved contract exists'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_proc as procedure_record
    join pg_catalog.pg_namespace as namespace_record
      on namespace_record.oid = procedure_record.pronamespace
    where namespace_record.nspname = 'public'
      and procedure_record.proname in (
        'superadmin_unit_directory_v2',
        'superadmin_unit_filter_options_v2',
        'superadmin_unit_create_v2',
        'superadmin_unit_edit_v2',
        'superadmin_unit_status_v2'
      )
  ),
  0::bigint,
  'Unit v2 list/options/write gateways stay absent while OQ-032 is open'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_proc as procedure_record
    join pg_catalog.pg_namespace as namespace_record
      on namespace_record.oid = procedure_record.pronamespace
    where namespace_record.nspname = 'public'
      and procedure_record.proname in (
        'superadmin_group_directory_v2',
        'superadmin_group_filter_options_v2',
        'superadmin_group_create_v2',
        'superadmin_group_edit_v2',
        'superadmin_group_status_v2'
      )
  ),
  0::bigint,
  'Group v2 list/options/write gateways stay absent while OQ-031 is open'
);

select ok(
  pg_catalog.pg_get_functiondef(
    'public.superadmin_institution_directory_v2(jsonb,integer,integer,text,boolean)'::regprocedure
  ) like '%require_superadmin_internal_context%',
  'Institution directory v2 revalidates the internal context'
);
select ok(
  pg_catalog.pg_get_functiondef(
    'public.superadmin_institution_filter_options_v2(text[],text[])'::regprocedure
  ) like '%require_superadmin_internal_context%',
  'Institution options v2 revalidate the internal context'
);
select ok(
  pg_catalog.pg_get_functiondef(
    'public.superadmin_institution_detail_v2(uuid)'::regprocedure
  ) like '%require_superadmin_internal_context%',
  'Institution detail v2 revalidates the internal context'
);
select ok(
  pg_catalog.pg_get_functiondef(
    'public.superadmin_institution_edit_core_v2(uuid,uuid,bigint,jsonb)'::regprocedure
  ) like '%require_superadmin_internal_context%',
  'Institution edit-core v2 revalidates the internal context'
);
select ok(
  pg_catalog.pg_get_functiondef(
    'public.superadmin_unit_detail_v2(uuid)'::regprocedure
  ) like '%require_superadmin_internal_context%',
  'Unit detail v2 revalidates the internal context'
);
select ok(
  pg_catalog.pg_get_functiondef(
    'public.superadmin_group_detail_v2(uuid)'::regprocedure
  ) like '%require_superadmin_internal_context%',
  'Group detail v2 revalidates the internal context'
);

select ok(
  not pg_catalog.pg_get_functiondef(
    'public.superadmin_unit_detail_v2(uuid)'::regprocedure
  ) like '%current_person_id%',
  'Unit detail v2 does not authorize through a global person'
);
select ok(
  not pg_catalog.pg_get_functiondef(
    'public.superadmin_group_detail_v2(uuid)'::regprocedure
  ) like '%current_person_id%',
  'Group detail v2 does not authorize through a global person'
);
select ok(
  not pg_catalog.pg_get_functiondef(
    'public.superadmin_institution_edit_core_v2(uuid,uuid,bigint,jsonb)'::regprocedure
  ) like '%current_person_id%',
  'Institution edit-core v2 does not authorize through a global person'
);

select * from finish();
rollback;
