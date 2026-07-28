begin;

create or replace function app_private.institution_profile_links_are_valid(
  links jsonb
)
returns boolean
language plpgsql
immutable
security invoker
set search_path = ''
as $$
begin
  if links is null
     or pg_catalog.jsonb_typeof(links) <> 'array'
     or pg_catalog.jsonb_array_length(links) > 3 then
    return false;
  end if;

  return not exists (
    select 1
    from pg_catalog.jsonb_array_elements(links) as entry(value)
    where pg_catalog.jsonb_typeof(entry.value) <> 'object'
       or not (entry.value ? 'label' and entry.value ? 'url')
       or pg_catalog.jsonb_typeof(entry.value -> 'label') <> 'string'
       or pg_catalog.jsonb_typeof(entry.value -> 'url') <> 'string'
       or pg_catalog.btrim(entry.value ->> 'label') = ''
       or pg_catalog.char_length(entry.value ->> 'label') > 60
       or pg_catalog.btrim(entry.value ->> 'url') = ''
       or pg_catalog.char_length(entry.value ->> 'url') > 2048
       or pg_catalog.btrim(entry.value ->> 'url')
            !~* '^https?://[^[:space:]]+$'
       or exists (
         select 1
         from pg_catalog.jsonb_object_keys(entry.value) as object_key(key)
         where object_key.key not in ('label', 'url')
       )
  );
end;
$$;

revoke all on function
  app_private.institution_profile_links_are_valid(jsonb)
from public, anon, authenticated;
grant execute on function
  app_private.institution_profile_links_are_valid(jsonb)
to service_role;

alter table public.institution_branding
  add column tertiary_color text,
  add column secondary_text_color text,
  add column tertiary_text_color text,
  add column profile_bio text,
  add column profile_links jsonb not null default '[]'::jsonb;

alter table public.institution_branding
  add constraint institution_branding_accent_color_hex_check
    check (accent_color is null or accent_color ~ '^#[0-9A-Fa-f]{6}$'),
  add constraint institution_branding_secondary_color_hex_check
    check (secondary_color is null or secondary_color ~ '^#[0-9A-Fa-f]{6}$'),
  add constraint institution_branding_tertiary_color_hex_check
    check (tertiary_color is null or tertiary_color ~ '^#[0-9A-Fa-f]{6}$'),
  add constraint institution_branding_text_color_hex_check
    check (text_color is null or text_color ~ '^#[0-9A-Fa-f]{6}$'),
  add constraint institution_branding_secondary_text_color_hex_check
    check (
      secondary_text_color is null
      or secondary_text_color ~ '^#[0-9A-Fa-f]{6}$'
    ),
  add constraint institution_branding_tertiary_text_color_hex_check
    check (
      tertiary_text_color is null
      or tertiary_text_color ~ '^#[0-9A-Fa-f]{6}$'
    ),
  add constraint institution_branding_surface_color_hex_check
    check (surface_color is null or surface_color ~ '^#[0-9A-Fa-f]{6}$'),
  add constraint institution_branding_profile_bio_length_check
    check (
      profile_bio is null
      or pg_catalog.char_length(profile_bio) <= 220
    ),
  add constraint institution_branding_profile_links_check
    check (
      app_private.institution_profile_links_are_valid(profile_links)
    );

alter table public.institution_contacts
  add column website_url text,
  add column whatsapp_number text;

alter table public.institution_contacts
  drop constraint institution_contacts_has_value,
  add constraint institution_contacts_website_url_not_blank
    check (website_url is null or pg_catalog.btrim(website_url) <> ''),
  add constraint institution_contacts_website_url_shape
    check (
      website_url is null
      or pg_catalog.btrim(website_url) ~* '^https?://[^[:space:]]+$'
    ),
  add constraint institution_contacts_website_url_length_check
    check (
      website_url is null
      or pg_catalog.char_length(website_url) <= 2048
    ),
  add constraint institution_contacts_whatsapp_number_not_blank
    check (
      whatsapp_number is null
      or pg_catalog.btrim(whatsapp_number) <> ''
    ),
  add constraint institution_contacts_whatsapp_number_e164_check
    check (
      whatsapp_number is null
      or whatsapp_number ~ '^\+[1-9][0-9]{7,14}$'
    ),
  add constraint institution_contacts_has_value
    check (
      pg_catalog.num_nonnulls(
        email,
        phone,
        mobile_phone,
        website_url,
        whatsapp_number
      ) > 0
    );

create table public.institution_legal_representatives (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null,
  person_id uuid not null,
  membership_id uuid not null,
  is_primary boolean not null default false,
  starts_on date not null default current_date,
  ends_on date,
  status public.record_status not null default 'active',
  created_by uuid references public.people(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint institution_legal_representatives_institution_fkey
    foreign key (institution_id)
    references public.institutions(id)
    on delete cascade,
  constraint institution_legal_representatives_person_fkey
    foreign key (person_id)
    references public.people(id)
    on delete restrict,
  constraint institution_legal_representatives_membership_tenant_fkey
    foreign key (membership_id, institution_id, person_id)
    references public.institution_memberships(id, institution_id, person_id)
    on delete cascade,
  constraint institution_legal_representatives_dates_check
    check (ends_on is null or ends_on >= starts_on)
);

create unique index
  institution_legal_representatives_active_person_uidx
on public.institution_legal_representatives(institution_id, person_id)
where status = 'active' and ends_on is null;

create index institution_legal_representatives_membership_idx
  on public.institution_legal_representatives(membership_id);

create index institution_legal_representatives_institution_status_idx
  on public.institution_legal_representatives(institution_id, status);

create index institution_legal_representatives_person_status_idx
  on public.institution_legal_representatives(person_id, status);

create or replace function
  app_private.validate_institution_legal_representative()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  representative public.people%rowtype;
  representative_membership public.institution_memberships%rowtype;
begin
  select *
    into representative
  from public.people
  where id = new.person_id;

  if representative.id is null
     or representative.person_type <> 'adult'
     or representative.date_of_birth is null
     or representative.date_of_birth > (
       current_date - interval '18 years'
     )::date then
    raise check_violation using
      message = 'legal representative must be an adult with a known birth date';
  end if;

  select *
    into representative_membership
  from public.institution_memberships
  where id = new.membership_id;

  if representative_membership.id is null
     or representative_membership.status <> 'active'
     or representative_membership.revoked_at is not null then
    raise check_violation using
      message = 'legal representative membership must be active';
  end if;

  return new;
end;
$$;

revoke all on function
  app_private.validate_institution_legal_representative()
from public, anon, authenticated;
grant execute on function
  app_private.validate_institution_legal_representative()
to service_role;

create trigger institution_legal_representatives_validate
before insert or update of person_id, membership_id, institution_id
on public.institution_legal_representatives
for each row
execute function app_private.validate_institution_legal_representative();

alter table public.institution_branding enable row level security;
alter table public.institution_contacts enable row level security;
alter table public.institution_legal_representatives enable row level security;

revoke all on table public.institution_branding
  from public, anon, authenticated, service_role;
revoke all on table public.institution_contacts
  from public, anon, authenticated, service_role;
revoke all on table public.institution_legal_representatives
  from public, anon, authenticated, service_role;

grant select on table public.institution_branding to authenticated;
grant select on table public.institution_contacts to authenticated;
grant select on table public.institution_legal_representatives to authenticated;

grant select, insert, update, delete
  on table public.institution_branding to service_role;
grant select, insert, update, delete
  on table public.institution_contacts to service_role;
grant select, insert, update, delete
  on table public.institution_legal_representatives to service_role;

create policy institution_legal_representatives_platform_read
on public.institution_legal_representatives
for select
to authenticated
using ((select app_private.has_platform_permission('platform.read')));

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
values (
  'public',
  'institution_legal_representatives',
  'Representantes legais de instituicoes',
  'Vinculos normalizados entre instituicoes, pessoas adultas e memberships.',
  'tenancy',
  'active',
  1,
  now()
)
on conflict (schema_name, table_name, version) do update set
  table_label = excluded.table_label,
  table_description = excluded.table_description,
  domain = excluded.domain,
  status = excluded.status,
  updated_at = excluded.updated_at;

with catalog_targets(table_name) as (
  values
    ('institution_branding'::text),
    ('institution_contacts'::text),
    ('institution_legal_representatives'::text)
),
catalog_columns as (
  select
    column_info.table_name,
    column_info.column_name,
    case column_info.column_name
      when 'institution_id' then 'Instituicao'
      when 'person_id' then 'Pessoa'
      when 'membership_id' then 'Membership'
      when 'tertiary_color' then 'Cor terciaria'
      when 'secondary_text_color' then 'Cor secundaria do texto'
      when 'tertiary_text_color' then 'Cor terciaria do texto'
      when 'profile_bio' then 'Bio do perfil'
      when 'profile_links' then 'Links do perfil'
      when 'website_url' then 'Site'
      when 'whatsapp_number' then 'WhatsApp'
      when 'is_primary' then 'Principal'
      when 'starts_on' then 'Inicio'
      when 'ends_on' then 'Fim'
      when 'created_by' then 'Criado por'
      when 'created_at' then 'Criado em'
      when 'updated_at' then 'Atualizado em'
      when 'status' then 'Status'
      else pg_catalog.initcap(
        pg_catalog.replace(column_info.column_name, '_', ' ')
      )
    end as column_label,
    'Campo ' || column_info.column_name || ' de ' || column_info.table_name
      || '.' as column_description,
    case
      when column_info.data_type = 'USER-DEFINED'
        then column_info.udt_schema || '.' || column_info.udt_name
      else column_info.data_type
    end as column_type,
    column_info.is_nullable = 'NO' as is_required,
    column_info.is_nullable = 'YES' as is_nullable,
    exists (
      select 1
      from pg_constraint constraint_info
      where constraint_info.conrelid = pg_catalog.to_regclass(
        'public.' || column_info.table_name
      )
        and constraint_info.contype in ('p', 'u')
        and constraint_info.conkey = array[column_info.ordinal_position]::smallint[]
    ) as is_unique,
    column_info.column_name in (
      'institution_id',
      'person_id',
      'membership_id',
      'status',
      'is_primary',
      'starts_on',
      'ends_on'
    ) as is_filterable,
    column_info.ordinal_position as position
  from information_schema.columns column_info
  join catalog_targets target
    on target.table_name = column_info.table_name
  where column_info.table_schema = 'public'
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
  table_catalog.id,
  catalog_columns.column_name,
  catalog_columns.column_label,
  catalog_columns.column_description,
  catalog_columns.column_type,
  catalog_columns.is_required,
  catalog_columns.is_nullable,
  catalog_columns.is_unique,
  catalog_columns.is_filterable,
  false,
  true,
  catalog_columns.position,
  now()
from catalog_columns
join public.schema_tables table_catalog
  on table_catalog.schema_name = 'public'
 and table_catalog.table_name = catalog_columns.table_name
 and table_catalog.status = 'active'
on conflict (schema_table_id, column_name) do update set
  column_label = excluded.column_label,
  column_description = excluded.column_description,
  column_type = excluded.column_type,
  is_required = excluded.is_required,
  is_nullable = excluded.is_nullable,
  is_unique = excluded.is_unique,
  is_filterable = excluded.is_filterable,
  is_importable = excluded.is_importable,
  is_active = excluded.is_active,
  position = excluded.position,
  updated_at = excluded.updated_at;

commit;
