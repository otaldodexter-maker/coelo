begin;

create table public.institution_contacts (
  institution_id uuid primary key references public.institutions(id) on delete cascade,
  email text,
  phone text,
  mobile_phone text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint institution_contacts_email_not_blank
    check (email is null or btrim(email) <> ''),
  constraint institution_contacts_email_shape
    check (email is null or position('@' in email) > 1),
  constraint institution_contacts_phone_not_blank
    check (phone is null or btrim(phone) <> ''),
  constraint institution_contacts_mobile_phone_not_blank
    check (mobile_phone is null or btrim(mobile_phone) <> ''),
  constraint institution_contacts_has_value
    check (num_nonnulls(email, phone, mobile_phone) > 0)
);

create table public.unit_contacts (
  unit_id uuid primary key references public.units(id) on delete cascade,
  email text,
  phone text,
  mobile_phone text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint unit_contacts_email_not_blank
    check (email is null or btrim(email) <> ''),
  constraint unit_contacts_email_shape
    check (email is null or position('@' in email) > 1),
  constraint unit_contacts_phone_not_blank
    check (phone is null or btrim(phone) <> ''),
  constraint unit_contacts_mobile_phone_not_blank
    check (mobile_phone is null or btrim(mobile_phone) <> ''),
  constraint unit_contacts_has_value
    check (num_nonnulls(email, phone, mobile_phone) > 0)
);

alter table public.institution_contacts enable row level security;
alter table public.unit_contacts enable row level security;

revoke all on table public.institution_contacts from public, anon, authenticated;
revoke all on table public.unit_contacts from public, anon, authenticated;

grant select on table public.institution_contacts to authenticated;
grant select on table public.unit_contacts to authenticated;

create policy institution_contacts_platform_read on public.institution_contacts
  for select to authenticated
  using ((select app_private.has_platform_permission('platform.read')));

create policy unit_contacts_platform_read on public.unit_contacts
  for select to authenticated
  using ((select app_private.has_platform_permission('platform.read')));

create or replace view public.institution_directory
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
  lower(concat_ws(' ', i.public_name, i.trade_name, i.legal_name)) as search_name,
  ic.email as contact_email,
  ic.phone as contact_phone,
  ic.mobile_phone as contact_mobile_phone
from public.institutions i
left join public.institution_types it
  on it.id = i.institution_type_id
left join public.institution_addresses ia
  on ia.institution_id = i.id
left join public.institution_contacts ic
  on ic.institution_id = i.id
 and ic.status <> 'archived'
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

create view public.institution_directory_locations
with (security_invoker = true)
as
select distinct
  ia.state,
  ia.city,
  ia.district
from public.institutions i
join public.institution_addresses ia
  on ia.institution_id = i.id
where i.deleted_at is null
  and ia.status <> 'archived'
  and ia.state is not null;

revoke all on table public.institution_directory_locations from public, anon, authenticated;
grant select on table public.institution_directory_locations to authenticated;

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
  (
    'public',
    'institution_contacts',
    'Contatos de instituicoes',
    'Contato principal de cada instituicao.',
    'tenancy',
    'active',
    1,
    now()
  ),
  (
    'public',
    'unit_contacts',
    'Contatos de unidades',
    'Contato principal de cada unidade.',
    'tenancy',
    'active',
    1,
    now()
  )
on conflict (schema_name, table_name, version) do update set
  table_label = excluded.table_label,
  table_description = excluded.table_description,
  domain = excluded.domain,
  status = 'active',
  updated_at = now();

with contact_columns(
  table_name,
  column_name,
  column_label,
  column_description,
  column_type,
  is_required,
  is_nullable,
  is_unique,
  is_filterable,
  position
) as (
  values
    (
      'institution_contacts', 'institution_id', 'Instituicao',
      'Instituicao proprietaria do contato.', 'uuid', true, false, true, true, 1
    ),
    (
      'institution_contacts', 'email', 'E-mail',
      'E-mail principal de contato da instituicao.', 'text', false, true, false, false, 2
    ),
    (
      'institution_contacts', 'phone', 'Telefone',
      'Telefone fixo principal da instituicao.', 'text', false, true, false, false, 3
    ),
    (
      'institution_contacts', 'mobile_phone', 'Celular',
      'Celular principal da instituicao.', 'text', false, true, false, false, 4
    ),
    (
      'institution_contacts', 'status', 'Status',
      'Status do contato da instituicao.', 'public.record_status', true, false, false, true, 5
    ),
    (
      'institution_contacts', 'created_at', 'Criado em',
      'Data de criacao do contato da instituicao.', 'timestamp with time zone', true, false, false, false, 6
    ),
    (
      'institution_contacts', 'updated_at', 'Atualizado em',
      'Data da ultima atualizacao do contato da instituicao.', 'timestamp with time zone', true, false, false, false, 7
    ),
    (
      'unit_contacts', 'unit_id', 'Unidade',
      'Unidade proprietaria do contato.', 'uuid', true, false, true, true, 1
    ),
    (
      'unit_contacts', 'email', 'E-mail',
      'E-mail principal de contato da unidade.', 'text', false, true, false, false, 2
    ),
    (
      'unit_contacts', 'phone', 'Telefone',
      'Telefone fixo principal da unidade.', 'text', false, true, false, false, 3
    ),
    (
      'unit_contacts', 'mobile_phone', 'Celular',
      'Celular principal da unidade.', 'text', false, true, false, false, 4
    ),
    (
      'unit_contacts', 'status', 'Status',
      'Status do contato da unidade.', 'public.record_status', true, false, false, true, 5
    ),
    (
      'unit_contacts', 'created_at', 'Criado em',
      'Data de criacao do contato da unidade.', 'timestamp with time zone', true, false, false, false, 6
    ),
    (
      'unit_contacts', 'updated_at', 'Atualizado em',
      'Data da ultima atualizacao do contato da unidade.', 'timestamp with time zone', true, false, false, false, 7
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
  contact_columns.column_name,
  contact_columns.column_label,
  contact_columns.column_description,
  contact_columns.column_type,
  contact_columns.is_required,
  contact_columns.is_nullable,
  contact_columns.is_unique,
  contact_columns.is_filterable,
  false,
  true,
  contact_columns.position,
  now()
from contact_columns
join public.schema_tables schema_table
  on schema_table.schema_name = 'public'
 and schema_table.table_name = contact_columns.table_name
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

commit;
