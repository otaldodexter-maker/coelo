-- Institution Directory Foundation
-- Source: approved Superadmin Institution Directory plan, 2026-07-17
-- Applied migration version: 20260717151609

create table public.institution_types (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  description text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint institution_types_code_not_blank check (btrim(code) <> ''),
  constraint institution_types_name_not_blank check (btrim(name) <> ''),
  constraint institution_types_description_not_blank check (description is null or btrim(description) <> '')
);

create unique index institution_types_code_uidx
  on public.institution_types(lower(code));

create unique index institution_types_name_uidx
  on public.institution_types(lower(name));

alter table public.institutions
  add column institution_type_id uuid;

alter table public.institutions
  add constraint institutions_institution_type_id_fkey
  foreign key (institution_type_id)
  references public.institution_types(id)
  on delete set null;

create index institutions_institution_type_id_idx
  on public.institutions(institution_type_id);

create table public.institution_addresses (
  institution_id uuid primary key references public.institutions(id) on delete cascade,
  country text not null default 'BR',
  state text,
  city text,
  district text,
  street text,
  number text,
  complement text,
  postal_code text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint institution_addresses_country_not_blank check (btrim(country) <> ''),
  constraint institution_addresses_state_not_blank check (state is null or btrim(state) <> ''),
  constraint institution_addresses_city_not_blank check (city is null or btrim(city) <> ''),
  constraint institution_addresses_district_not_blank check (district is null or btrim(district) <> ''),
  constraint institution_addresses_street_not_blank check (street is null or btrim(street) <> ''),
  constraint institution_addresses_number_not_blank check (number is null or btrim(number) <> ''),
  constraint institution_addresses_complement_not_blank check (complement is null or btrim(complement) <> ''),
  constraint institution_addresses_postal_code_not_blank check (postal_code is null or btrim(postal_code) <> '')
);

create index institution_addresses_state_city_idx
  on public.institution_addresses(state, city);

create table public.unit_addresses (
  unit_id uuid primary key references public.units(id) on delete cascade,
  country text not null default 'BR',
  state text,
  city text,
  district text,
  street text,
  number text,
  complement text,
  postal_code text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint unit_addresses_country_not_blank check (btrim(country) <> ''),
  constraint unit_addresses_state_not_blank check (state is null or btrim(state) <> ''),
  constraint unit_addresses_city_not_blank check (city is null or btrim(city) <> ''),
  constraint unit_addresses_district_not_blank check (district is null or btrim(district) <> ''),
  constraint unit_addresses_street_not_blank check (street is null or btrim(street) <> ''),
  constraint unit_addresses_number_not_blank check (number is null or btrim(number) <> ''),
  constraint unit_addresses_complement_not_blank check (complement is null or btrim(complement) <> ''),
  constraint unit_addresses_postal_code_not_blank check (postal_code is null or btrim(postal_code) <> '')
);

create index unit_addresses_state_city_idx
  on public.unit_addresses(state, city);

alter table public.institution_types enable row level security;
alter table public.institution_addresses enable row level security;
alter table public.unit_addresses enable row level security;

revoke all on table public.institution_types from public, anon, authenticated;
revoke all on table public.institution_addresses from public, anon, authenticated;
revoke all on table public.unit_addresses from public, anon, authenticated;

grant select on table public.institution_types to authenticated;
grant select on table public.institution_addresses to authenticated;
grant select on table public.unit_addresses to authenticated;

create policy institution_types_platform_read on public.institution_types
  for select to authenticated
  using ((select app_private.has_platform_permission('platform.read')));

create policy institution_addresses_platform_read on public.institution_addresses
  for select to authenticated
  using ((select app_private.has_platform_permission('platform.read')));

create policy unit_addresses_platform_read on public.unit_addresses
  for select to authenticated
  using ((select app_private.has_platform_permission('platform.read')));

create view public.institution_directory
with (security_invoker = true)
as
select
  i.id,
  i.public_name,
  i.trade_name,
  i.legal_name,
  i.primary_domain,
  i.status::text as status,
  i.institution_type_id,
  it.code as type_code,
  it.name as type_name,
  ia.country,
  ia.state,
  ia.city,
  ia.district,
  ia.street,
  ia.number,
  ia.complement,
  ia.postal_code,
  latest_subscription.plan_id,
  latest_subscription.plan_name,
  latest_subscription.subscription_status,
  (
    select count(*)::integer
    from public.units u
    where u.institution_id = i.id
      and u.status <> 'archived'
  ) as units_count,
  (
    select count(*)::integer
    from public.groups g
    where g.institution_id = i.id
      and g.status <> 'archived'
  ) as groups_count,
  lower(concat_ws(' ', i.public_name, i.trade_name, i.legal_name)) as search_name
from public.institutions i
left join public.institution_types it
  on it.id = i.institution_type_id
left join public.institution_addresses ia
  on ia.institution_id = i.id
left join lateral (
  select
    subscription.plan_id,
    plan.name as plan_name,
    subscription.status::text as subscription_status
  from public.institution_subscriptions subscription
  left join public.plans plan
    on plan.id = subscription.plan_id
  where subscription.institution_id = i.id
  order by subscription.created_at desc, subscription.id desc
  limit 1
) latest_subscription on true
where i.deleted_at is null;

revoke all on table public.institution_directory from public, anon, authenticated;
grant select on table public.institution_directory to authenticated;

insert into public.schema_tables(
  schema_name,
  table_name,
  table_label,
  table_description,
  domain,
  status,
  version,
  updated_at
)
values
  ('public', 'institution_types', 'Tipos de instituicao', 'Catalogo de tipos de instituicao.', 'tenancy', 'active', 1, now()),
  ('public', 'institution_addresses', 'Enderecos legais', 'Endereco legal unico de cada instituicao.', 'tenancy', 'active', 1, now()),
  ('public', 'unit_addresses', 'Enderecos de unidades', 'Endereco fisico unico de cada unidade.', 'tenancy', 'active', 1, now())
on conflict (schema_name, table_name, version) do update set
  table_label = excluded.table_label,
  table_description = excluded.table_description,
  domain = excluded.domain,
  status = 'active',
  updated_at = now();

with unique_columns as (
  select
    namespace.nspname as table_schema,
    relation.relname as table_name,
    attribute.attname as column_name
  from pg_constraint constraint_record
  join pg_class relation on relation.oid = constraint_record.conrelid
  join pg_namespace namespace on namespace.oid = relation.relnamespace
  join pg_attribute attribute
    on attribute.attrelid = relation.oid
   and attribute.attnum = any(constraint_record.conkey)
  where constraint_record.contype in ('p', 'u')
    and array_length(constraint_record.conkey, 1) = 1
),
column_catalog as (
  select
    column_record.table_schema,
    column_record.table_name,
    column_record.column_name,
    case column_record.column_name
      when 'id' then 'ID'
      when 'institution_id' then 'Instituicao'
      when 'institution_type_id' then 'Tipo de instituicao'
      when 'unit_id' then 'Unidade'
      when 'code' then 'Codigo'
      when 'name' then 'Nome'
      when 'description' then 'Descricao'
      when 'country' then 'Pais'
      when 'state' then 'UF'
      when 'city' then 'Municipio'
      when 'district' then 'Bairro'
      when 'street' then 'Logradouro'
      when 'number' then 'Numero'
      when 'complement' then 'Complemento'
      when 'postal_code' then 'CEP'
      when 'status' then 'Status'
      when 'created_at' then 'Criado em'
      when 'updated_at' then 'Atualizado em'
      else initcap(replace(column_record.column_name, '_', ' '))
    end as column_label,
    'Campo ' || column_record.column_name || ' da tabela ' || schema_table.table_label || '.' as column_description,
    case
      when column_record.data_type = 'USER-DEFINED' then column_record.udt_schema || '.' || column_record.udt_name
      when column_record.data_type = 'ARRAY' then column_record.udt_name
      else column_record.data_type
    end as column_type,
    (column_record.is_nullable = 'NO' and column_record.column_default is null) as is_required,
    (column_record.is_nullable = 'YES') as is_nullable,
    (unique_column.column_name is not null) as is_unique,
    (
      column_record.column_name = 'id'
      or column_record.column_name like '%\_id' escape '\'
      or column_record.column_name in ('status', 'code', 'state', 'city')
      or column_record.column_name like '%\_at' escape '\'
    ) as is_filterable,
    coalesce(existing_column.is_importable, false) as is_importable,
    column_record.ordinal_position as position
  from information_schema.columns column_record
  join public.schema_tables schema_table
    on schema_table.schema_name = column_record.table_schema
   and schema_table.table_name = column_record.table_name
   and schema_table.status = 'active'
  left join unique_columns unique_column
    on unique_column.table_schema = column_record.table_schema
   and unique_column.table_name = column_record.table_name
   and unique_column.column_name = column_record.column_name
  left join public.schema_columns existing_column
    on existing_column.schema_table_id = schema_table.id
   and existing_column.column_name = column_record.column_name
  where column_record.table_schema = 'public'
    and column_record.table_name in (
      'institutions',
      'institution_types',
      'institution_addresses',
      'unit_addresses'
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
  schema_table.id,
  column_catalog.column_name,
  column_catalog.column_label,
  column_catalog.column_description,
  column_catalog.column_type,
  column_catalog.is_required,
  column_catalog.is_nullable,
  column_catalog.is_unique,
  column_catalog.is_filterable,
  column_catalog.is_importable,
  true,
  column_catalog.position,
  now()
from column_catalog
join public.schema_tables schema_table
  on schema_table.schema_name = column_catalog.table_schema
 and schema_table.table_name = column_catalog.table_name
 and schema_table.status = 'active'
on conflict (schema_table_id, column_name) do update set
  column_label = excluded.column_label,
  column_description = excluded.column_description,
  column_type = excluded.column_type,
  is_required = excluded.is_required,
  is_nullable = excluded.is_nullable,
  is_unique = excluded.is_unique,
  is_filterable = excluded.is_filterable,
  is_importable = excluded.is_importable,
  is_active = true,
  position = excluded.position,
  updated_at = now();
