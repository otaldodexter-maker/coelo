begin;

create or replace function app_private.assert_unit_hierarchy_contract()
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  expected_column_is_required boolean;
  conflicting_column_exists boolean;
  expected_catalog_exists boolean;
  conflicting_catalog_exists boolean;
  expected_foreign_key_exists boolean;
  expected_index_exists boolean;
begin
  select exists (
    select 1
    from information_schema.columns column_record
    where column_record.table_schema = 'public'
      and column_record.table_name = 'units'
      and column_record.column_name = 'institution_type_id'
      and column_record.is_nullable = 'NO'
      and column_record.data_type = 'uuid'
  ) into expected_column_is_required;

  select exists (
    select 1
    from information_schema.columns column_record
    where column_record.table_schema = 'public'
      and column_record.table_name = 'units'
      and column_record.column_name = 'unit_type_id'
  ) into conflicting_column_exists;

  select to_regclass('public.institution_types') is not null
    into expected_catalog_exists;
  select to_regclass('public.unit_types') is not null
    into conflicting_catalog_exists;

  select exists (
    select 1
    from pg_constraint constraint_record
    join pg_attribute source_column
      on source_column.attrelid = constraint_record.conrelid
     and source_column.attnum = constraint_record.conkey[1]
    join pg_attribute target_column
      on target_column.attrelid = constraint_record.confrelid
     and target_column.attnum = constraint_record.confkey[1]
    where constraint_record.conrelid = 'public.units'::regclass
      and constraint_record.confrelid = 'public.institution_types'::regclass
      and constraint_record.contype = 'f'
      and cardinality(constraint_record.conkey) = 1
      and cardinality(constraint_record.confkey) = 1
      and source_column.attname = 'institution_type_id'
      and target_column.attname = 'id'
  ) into expected_foreign_key_exists;

  select to_regclass('public.units_institution_type_id_idx') is not null
    into expected_index_exists;

  if not expected_column_is_required
     or conflicting_column_exists
     or not expected_catalog_exists
     or conflicting_catalog_exists
     or not expected_foreign_key_exists
     or not expected_index_exists then
    raise exception using
      errcode = '55000',
      message = 'unit hierarchy contract mismatch',
      detail = jsonb_build_object(
        'expected_column_is_required', expected_column_is_required,
        'conflicting_column_exists', conflicting_column_exists,
        'expected_catalog_exists', expected_catalog_exists,
        'conflicting_catalog_exists', conflicting_catalog_exists,
        'expected_foreign_key_exists', expected_foreign_key_exists,
        'expected_index_exists', expected_index_exists
      )::text,
      hint = 'Reconcile OQ-032 provenance before applying unit hierarchy changes.';
  end if;

  return jsonb_build_object(
    'catalog', 'institution_types',
    'column', 'institution_type_id',
    'contract', 'shared-institution-type'
  );
end;
$$;

alter function app_private.assert_unit_hierarchy_contract() owner to postgres;
revoke all on function app_private.assert_unit_hierarchy_contract() from public;
revoke all on function app_private.assert_unit_hierarchy_contract() from anon;
revoke all on function app_private.assert_unit_hierarchy_contract() from authenticated;
revoke all on function app_private.assert_unit_hierarchy_contract() from service_role;

select app_private.assert_unit_hierarchy_contract();

commit;
