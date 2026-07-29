-- Unit type and plan inheritance foundation.
-- Sources: decisions/0016-unit-type-and-plan-inheritance.md;
-- specs/017-superadmin-unit-schema-foundation.md.

begin;

alter table public.units
  add column institution_type_id uuid,
  add column plan_override_id uuid;

update public.units unit_record
set institution_type_id = institution.institution_type_id
from public.institutions institution
where institution.id = unit_record.institution_id
  and unit_record.institution_type_id is null;

do $$
declare
  untyped_units_count bigint;
begin
  select count(*)
    into untyped_units_count
  from public.units
  where institution_type_id is null;

  if untyped_units_count > 0 then
    raise exception using
      message = 'cannot require units.institution_type_id while units remain untyped',
      detail = format(
        '%s unit record(s) belong to an institution without a type',
        untyped_units_count
      ),
      hint = 'Assign an approved institution type to every parent institution before applying this migration.';
  end if;
end $$;

alter table public.units
  alter column institution_type_id set not null,
  add constraint units_institution_type_id_fkey
    foreign key (institution_type_id)
    references public.institution_types(id),
  add constraint units_plan_override_id_fkey
    foreign key (plan_override_id)
    references public.plans(id);

create index units_institution_type_id_idx
  on public.units(institution_type_id);

create index units_plan_override_id_idx
  on public.units(plan_override_id);

with unit_column_catalog as (
  select
    schema_table.id as schema_table_id,
    column_info.column_name,
    case column_info.column_name
      when 'institution_type_id' then 'Tipo da unidade'
      when 'plan_override_id' then 'Override de plano'
    end as column_label,
    case column_info.column_name
      when 'institution_type_id' then
        'Tipo proprio da unidade no catalogo compartilhado de tipos institucionais.'
      when 'plan_override_id' then
        'Plano local opcional; quando ausente, a unidade herda o plano da instituicao.'
    end as column_description,
    case
      when column_info.data_type = 'USER-DEFINED'
        then column_info.udt_schema || '.' || column_info.udt_name
      when column_info.data_type = 'ARRAY'
        then column_info.udt_name
      else column_info.data_type
    end as column_type,
    (
      column_info.is_nullable = 'NO'
      and column_info.column_default is null
    ) as is_required,
    (column_info.is_nullable = 'YES') as is_nullable,
    column_info.ordinal_position as position
  from information_schema.columns column_info
  join public.schema_tables schema_table
    on schema_table.schema_name = column_info.table_schema
   and schema_table.table_name = column_info.table_name
   and schema_table.status = 'active'
  where column_info.table_schema = 'public'
    and column_info.table_name = 'units'
    and column_info.column_name in (
      'institution_type_id',
      'plan_override_id'
    )
)
insert into public.schema_columns(
  schema_table_id,
  column_name,
  column_label,
  column_description,
  column_type,
  is_required,
  is_nullable,
  is_unique,
  is_filterable,
  is_importable,
  is_active,
  position,
  updated_at
)
select
  schema_table_id,
  column_name,
  column_label,
  column_description,
  column_type,
  is_required,
  is_nullable,
  false,
  true,
  false,
  true,
  position,
  now()
from unit_column_catalog
on conflict (schema_table_id, column_name) do update set
  column_label = excluded.column_label,
  column_description = excluded.column_description,
  column_type = excluded.column_type,
  is_required = excluded.is_required,
  is_nullable = excluded.is_nullable,
  is_unique = false,
  is_filterable = true,
  is_importable = false,
  is_active = true,
  position = excluded.position,
  updated_at = now();

commit;
