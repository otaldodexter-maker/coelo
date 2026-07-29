begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select has_column(
  'public',
  'units',
  'institution_type_id',
  'units exposes its own institution type'
);
select col_not_null(
  'public',
  'units',
  'institution_type_id',
  'unit type is required'
);
select has_column(
  'public',
  'units',
  'plan_override_id',
  'units exposes an optional plan override'
);
select col_is_null(
  'public',
  'units',
  'plan_override_id',
  'unit plan override is optional'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.units'::regclass
      and conname = 'units_institution_type_id_fkey'
      and pg_get_constraintdef(oid)
        like '%FOREIGN KEY (institution_type_id)%institution_types(id)%'
  ),
  'unit type references the shared institution type catalog'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.units'::regclass
      and conname = 'units_plan_override_id_fkey'
      and pg_get_constraintdef(oid)
        like '%FOREIGN KEY (plan_override_id)%plans(id)%'
  ),
  'unit plan override references plans'
);
select has_index(
  'public',
  'units',
  'units_institution_type_id_idx',
  'cross-institution unit type filter is indexed'
);
select has_index(
  'public',
  'units',
  'units_plan_override_id_idx',
  'unit plan override filter is indexed'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.units'::regclass
      and contype = 'u'
      and pg_get_constraintdef(oid)
        like '%UNIQUE (institution_id, slug)%'
  ),
  'unit slug remains unique inside its institution'
);
select ok(
  exists (
    select 1
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'units'
      and relation.relrowsecurity
  ),
  'RLS remains enabled on units'
);
select policies_are(
  'public',
  'units',
  array['units_platform_read'],
  'units exposes only the platform read policy'
);
select ok(
  exists (
    select 1
    from public.schema_columns column_catalog
    join public.schema_tables table_catalog
      on table_catalog.id = column_catalog.schema_table_id
    where table_catalog.schema_name = 'public'
      and table_catalog.table_name = 'units'
      and column_catalog.column_name = 'institution_type_id'
      and column_catalog.is_active
      and column_catalog.is_filterable
      and not column_catalog.is_importable
  ),
  'unit type is filterable and not importable'
);
select ok(
  exists (
    select 1
    from public.schema_columns column_catalog
    join public.schema_tables table_catalog
      on table_catalog.id = column_catalog.schema_table_id
    where table_catalog.schema_name = 'public'
      and table_catalog.table_name = 'units'
      and column_catalog.column_name = 'plan_override_id'
      and column_catalog.is_active
      and column_catalog.is_filterable
      and not column_catalog.is_importable
  ),
  'unit plan override is filterable and not importable'
);

select * from finish();
rollback;
