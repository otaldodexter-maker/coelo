-- Unit type and plan inheritance foundation validation.
-- Run after applying 20260729*_unit_type_plan_foundation.sql.

begin;

do $$
declare
  type_nullable text;
  plan_nullable text;
begin
  select is_nullable
    into type_nullable
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'units'
    and column_name = 'institution_type_id';

  if type_nullable is distinct from 'NO' then
    raise exception 'units.institution_type_id must exist and be NOT NULL';
  end if;

  select is_nullable
    into plan_nullable
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'units'
    and column_name = 'plan_override_id';

  if plan_nullable is distinct from 'YES' then
    raise exception 'units.plan_override_id must exist and be nullable';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.units'::regclass
      and conname = 'units_institution_type_id_fkey'
      and pg_get_constraintdef(oid)
        like '%FOREIGN KEY (institution_type_id)%institution_types(id)%'
  ) then
    raise exception 'units institution type foreign key is missing';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.units'::regclass
      and conname = 'units_plan_override_id_fkey'
      and pg_get_constraintdef(oid)
        like '%FOREIGN KEY (plan_override_id)%plans(id)%'
  ) then
    raise exception 'units plan override foreign key is missing';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.units'::regclass
      and contype = 'u'
      and pg_get_constraintdef(oid)
        like '%UNIQUE (institution_id, slug)%'
  ) then
    raise exception 'unit slug must remain unique inside its institution';
  end if;

  if not exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'units'
      and indexname = 'units_institution_type_id_idx'
  ) or not exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'units'
      and indexname = 'units_plan_override_id_idx'
  ) then
    raise exception 'unit filter indexes are incomplete';
  end if;

  if exists (
    select 1
    from public.schema_columns column_catalog
    join public.schema_tables table_catalog
      on table_catalog.id = column_catalog.schema_table_id
    where table_catalog.schema_name = 'public'
      and table_catalog.table_name = 'units'
      and column_catalog.column_name in (
        'institution_type_id',
        'plan_override_id'
      )
      and (
        not column_catalog.is_active
        or not column_catalog.is_filterable
        or column_catalog.is_importable
      )
  ) or (
    select count(*)
    from public.schema_columns column_catalog
    join public.schema_tables table_catalog
      on table_catalog.id = column_catalog.schema_table_id
    where table_catalog.schema_name = 'public'
      and table_catalog.table_name = 'units'
      and column_catalog.column_name in (
        'institution_type_id',
        'plan_override_id'
      )
  ) <> 2 then
    raise exception
      'unit type and plan override catalog entries must be active, filterable and non-importable';
  end if;

  if not exists (
    select 1
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'units'
      and relation.relrowsecurity
  ) then
    raise exception 'RLS must remain enabled on units';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'units'
      and policyname = 'units_platform_read'
      and roles = array['authenticated']::name[]
      and cmd = 'SELECT'
      and qual like '%has_platform_permission%platform.read%'
  ) then
    raise exception 'units platform.read policy is missing';
  end if;

  if exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'units'
      and cmd <> 'SELECT'
  ) then
    raise exception 'unit schema foundation must not add write policies';
  end if;
end $$;

do $$
declare
  institution_type_id uuid;
  inherited_plan_id uuid;
  override_plan_id uuid;
  institution_id uuid;
  unit_id uuid;
  effective_plan_id uuid;
  rejected boolean;
begin
  insert into public.institution_types(code, name)
  values ('unit-foundation-test', 'Tipo para teste de unidade')
  returning id into institution_type_id;

  insert into public.plans(code, name)
  values ('unit-foundation-inherited', 'Plano herdado para teste')
  returning id into inherited_plan_id;

  insert into public.plans(code, name)
  values ('unit-foundation-override', 'Plano override para teste')
  returning id into override_plan_id;

  insert into public.institutions(
    public_name,
    legal_name,
    slug,
    institution_type_id
  ) values (
    'Instituicao da validacao de unidades',
    'Instituicao da validacao de unidades LTDA',
    'unit-foundation-validation',
    institution_type_id
  ) returning id into institution_id;

  insert into public.units(
    institution_id,
    institution_type_id,
    name,
    slug
  ) values (
    institution_id,
    institution_type_id,
    'Unidade da validacao',
    'unit-foundation-validation'
  ) returning id into unit_id;

  insert into public.institution_subscriptions(
    institution_id,
    plan_id,
    status,
    starts_at
  ) values (
    institution_id,
    inherited_plan_id,
    'active',
    now()
  );

  select coalesce(unit_record.plan_override_id, subscription.plan_id)
    into effective_plan_id
  from public.units unit_record
  join lateral (
    select institution_subscription.plan_id
    from public.institution_subscriptions institution_subscription
    where institution_subscription.institution_id =
      unit_record.institution_id
    order by
      institution_subscription.created_at desc,
      institution_subscription.id desc
    limit 1
  ) subscription on true
  where unit_record.id = unit_id;

  if effective_plan_id is distinct from inherited_plan_id then
    raise exception 'unit without override did not inherit institution plan';
  end if;

  update public.units
  set plan_override_id = override_plan_id
  where id = unit_id;

  select coalesce(unit_record.plan_override_id, subscription.plan_id)
    into effective_plan_id
  from public.units unit_record
  join lateral (
    select institution_subscription.plan_id
    from public.institution_subscriptions institution_subscription
    where institution_subscription.institution_id =
      unit_record.institution_id
    order by
      institution_subscription.created_at desc,
      institution_subscription.id desc
    limit 1
  ) subscription on true
  where unit_record.id = unit_id;

  if effective_plan_id is distinct from override_plan_id then
    raise exception 'unit override did not replace institution plan';
  end if;

  begin
    update public.units
    set institution_type_id = null
    where id = unit_id;
    rejected := false;
  exception when not_null_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'unit without institution type was accepted';
  end if;

  begin
    update public.units
    set institution_type_id = gen_random_uuid()
    where id = unit_id;
    rejected := false;
  exception when foreign_key_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'unit with unknown institution type was accepted';
  end if;

  begin
    insert into public.units(
      institution_id,
      institution_type_id,
      name,
      slug
    ) values (
      institution_id,
      institution_type_id,
      'Unidade com slug duplicado',
      'unit-foundation-validation'
    );
    rejected := false;
  exception when unique_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'duplicate unit slug inside one institution was accepted';
  end if;
end $$;

rollback;
