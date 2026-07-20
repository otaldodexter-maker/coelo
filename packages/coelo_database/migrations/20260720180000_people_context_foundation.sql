-- People, institutional context, family and invitation foundation.

do $$
begin
  create type public.child_unit_link_status as enum (
    'pending',
    'awaiting_allocation',
    'active',
    'inactive',
    'revoked'
  );
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.access_request_status as enum (
    'pending',
    'accepted',
    'declined',
    'cancelled'
  );
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.invitation_state as enum (
    'pending',
    'accepted',
    'revoked',
    'expired'
  );
exception when duplicate_object then null;
end $$;

create table if not exists public.institution_roles (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid references public.institutions(id) on delete cascade,
  code text not null check (btrim(code) <> ''),
  name text not null check (btrim(name) <> ''),
  description text,
  is_system boolean not null default false,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint institution_roles_global_system_check
    check (institution_id is not null or is_system)
);

create unique index if not exists institution_roles_global_code_uidx
  on public.institution_roles(lower(code))
  where institution_id is null;
create unique index if not exists institution_roles_local_code_uidx
  on public.institution_roles(institution_id, lower(code))
  where institution_id is not null;
create index if not exists institution_roles_institution_status_idx
  on public.institution_roles(institution_id, status);

create table if not exists public.institution_permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (btrim(code) <> ''),
  module_code text not null check (btrim(module_code) <> ''),
  screen_code text,
  action_code text not null check (btrim(action_code) <> ''),
  description text,
  risk_level text not null default 'normal',
  requires_mfa boolean not null default false,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists institution_permissions_module_status_idx
  on public.institution_permissions(module_code, status);

create table if not exists public.institution_role_permissions (
  id uuid primary key default gen_random_uuid(),
  role_id uuid not null references public.institution_roles(id) on delete cascade,
  permission_id uuid not null references public.institution_permissions(id) on delete cascade,
  effect public.permission_effect not null default 'allow',
  conditions_json jsonb not null default '{}'::jsonb,
  granted_by uuid references public.people(id),
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  status public.record_status not null default 'active',
  unique(role_id, permission_id)
);

create index if not exists institution_role_permissions_permission_status_idx
  on public.institution_role_permissions(permission_id, status);

create table if not exists public.institution_role_assignments (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null references public.institution_memberships(id) on delete cascade,
  role_id uuid not null references public.institution_roles(id) on delete restrict,
  scope_kind text not null default 'institution'
    check (scope_kind in ('institution', 'unit', 'group')),
  scope_unit_id uuid references public.units(id) on delete cascade,
  scope_group_id uuid references public.groups(id) on delete cascade,
  starts_at timestamptz,
  expires_at timestamptz,
  granted_by uuid references public.people(id),
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint institution_role_assignments_scope_check check (
    (scope_kind = 'institution' and scope_unit_id is null and scope_group_id is null)
    or (scope_kind = 'unit' and scope_unit_id is not null and scope_group_id is null)
    or (scope_kind = 'group' and scope_unit_id is not null and scope_group_id is not null)
  ),
  constraint institution_role_assignments_dates_check
    check (expires_at is null or starts_at is null or expires_at > starts_at)
);

create unique index if not exists institution_memberships_person_institution_active_uidx
  on public.institution_memberships(person_id, institution_id)
  where status = 'active' and revoked_at is null;
create unique index if not exists institution_role_assignments_active_uidx
  on public.institution_role_assignments(
    membership_id,
    role_id,
    scope_kind,
    coalesce(scope_unit_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(scope_group_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where status = 'active';
create index if not exists institution_role_assignments_membership_status_idx
  on public.institution_role_assignments(membership_id, status);
create index if not exists institution_role_assignments_role_status_idx
  on public.institution_role_assignments(role_id, status);
create index if not exists institution_role_assignments_unit_group_idx
  on public.institution_role_assignments(scope_unit_id, scope_group_id)
  where status = 'active';

create table if not exists public.guardian_links (
  id uuid primary key default gen_random_uuid(),
  guardian_person_id uuid not null references public.people(id) on delete cascade,
  child_person_id uuid not null references public.people(id) on delete cascade,
  relation_type text not null check (btrim(relation_type) <> ''),
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint guardian_links_distinct_people_check
    check (guardian_person_id <> child_person_id)
);

create unique index if not exists guardian_links_active_uidx
  on public.guardian_links(guardian_person_id, child_person_id)
  where status = 'active' and revoked_at is null;
create index if not exists guardian_links_child_status_idx
  on public.guardian_links(child_person_id, status);

create table if not exists public.child_contexts (
  id uuid primary key default gen_random_uuid(),
  child_person_id uuid not null references public.people(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  local_identifier text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique(child_person_id, institution_id),
  constraint child_contexts_local_identifier_check
    check (local_identifier is null or btrim(local_identifier) <> '')
);

create unique index if not exists child_contexts_institution_identifier_uidx
  on public.child_contexts(institution_id, lower(local_identifier))
  where local_identifier is not null and status <> 'archived';
create index if not exists child_contexts_institution_status_idx
  on public.child_contexts(institution_id, status);

create table if not exists public.child_unit_links (
  id uuid primary key default gen_random_uuid(),
  child_context_id uuid not null references public.child_contexts(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  status public.child_unit_link_status not null default 'pending',
  accepted_by uuid references public.people(id),
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique(child_context_id, unit_id),
  constraint child_unit_links_acceptance_check check (
    status not in ('awaiting_allocation', 'active')
    or (accepted_by is not null and accepted_at is not null)
  )
);

create index if not exists child_unit_links_unit_status_idx
  on public.child_unit_links(unit_id, status);
create index if not exists child_unit_links_context_status_idx
  on public.child_unit_links(child_context_id, status);

create table if not exists public.child_group_links (
  id uuid primary key default gen_random_uuid(),
  child_unit_link_id uuid not null references public.child_unit_links(id) on delete cascade,
  group_id uuid not null references public.groups(id) on delete cascade,
  status public.record_status not null default 'active',
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(child_unit_link_id, group_id),
  constraint child_group_links_dates_check
    check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create index if not exists child_group_links_group_status_idx
  on public.child_group_links(group_id, status);

create table if not exists public.guardian_context_permissions (
  id uuid primary key default gen_random_uuid(),
  guardian_link_id uuid not null references public.guardian_links(id) on delete cascade,
  child_context_id uuid not null references public.child_contexts(id) on delete cascade,
  can_view boolean not null default true,
  can_message boolean not null default true,
  can_react boolean not null default true,
  status public.record_status not null default 'active',
  starts_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(guardian_link_id, child_context_id),
  constraint guardian_context_permissions_dates_check
    check (expires_at is null or starts_at is null or expires_at > starts_at)
);

create index if not exists guardian_context_permissions_context_status_idx
  on public.guardian_context_permissions(child_context_id, status);

create table if not exists public.child_unit_access_requests (
  id uuid primary key default gen_random_uuid(),
  requested_by uuid not null references public.people(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  message text,
  status public.access_request_status not null default 'pending',
  decided_by uuid references public.people(id),
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cancelled_at timestamptz,
  constraint child_unit_access_requests_message_check
    check (message is null or btrim(message) <> ''),
  constraint child_unit_access_requests_decision_check check (
    (status = 'pending' and decided_by is null and decided_at is null and cancelled_at is null)
    or (status in ('accepted', 'declined') and decided_by is not null and decided_at is not null)
    or (status = 'cancelled' and cancelled_at is not null)
  )
);

create index if not exists child_unit_access_requests_requester_status_idx
  on public.child_unit_access_requests(requested_by, status, created_at desc);
create index if not exists child_unit_access_requests_unit_status_idx
  on public.child_unit_access_requests(unit_id, status, created_at desc);

create table if not exists public.child_unit_access_request_children (
  request_id uuid not null references public.child_unit_access_requests(id) on delete cascade,
  guardian_link_id uuid not null references public.guardian_links(id) on delete cascade,
  child_person_id uuid not null references public.people(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(request_id, child_person_id),
  unique(request_id, guardian_link_id)
);

create index if not exists child_unit_access_request_children_guardian_idx
  on public.child_unit_access_request_children(guardian_link_id);
create index if not exists child_unit_access_request_children_child_idx
  on public.child_unit_access_request_children(child_person_id);

alter table public.invitations
  add column if not exists invitation_state public.invitation_state not null default 'pending',
  add column if not exists unit_id uuid references public.units(id) on delete cascade,
  add column if not exists group_id uuid references public.groups(id) on delete cascade,
  add column if not exists invited_by uuid references public.people(id),
  add column if not exists target_contact_hash text,
  add column if not exists masked_destination text,
  add column if not exists sent_at timestamptz,
  add column if not exists last_sent_at timestamptz,
  add column if not exists send_count integer not null default 0,
  add column if not exists accepted_by uuid references public.people(id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.invitations'::regclass
      and conname = 'invitations_institution_id_fkey'
  ) then
    alter table public.invitations
      add constraint invitations_institution_id_fkey
      foreign key (institution_id)
      references public.institutions(id)
      on delete cascade;
  end if;
end $$;

alter table public.invitations
  add constraint invitations_target_check
    check (target_person_id is not null or target_contact_hash is not null),
  add constraint invitations_send_count_check
    check (send_count >= 0);

create index if not exists invitations_unit_state_idx
  on public.invitations(unit_id, invitation_state, created_at desc);
create index if not exists invitations_group_state_idx
  on public.invitations(group_id, invitation_state, created_at desc);
create index if not exists invitations_target_person_state_idx
  on public.invitations(target_person_id, invitation_state, expires_at);
create index if not exists invitations_target_contact_state_idx
  on public.invitations(target_contact_hash, invitation_state, expires_at)
  where target_contact_hash is not null;
create unique index if not exists invitations_active_person_institution_uidx
  on public.invitations(target_person_id, institution_id, role_code)
  where target_person_id is not null and invitation_state = 'pending';

create or replace function app_private.validate_institution_role_assignment()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  membership_institution_id uuid;
  role_institution_id uuid;
  unit_institution_id uuid;
  group_institution_id uuid;
  group_unit_id uuid;
begin
  select membership.institution_id
  into membership_institution_id
  from public.institution_memberships membership
  where membership.id = new.membership_id;

  select role.institution_id
  into role_institution_id
  from public.institution_roles role
  where role.id = new.role_id;

  if role_institution_id is not null
     and role_institution_id <> membership_institution_id then
    raise check_violation using message = 'role and membership must belong to the same institution';
  end if;

  if new.scope_unit_id is not null then
    select unit.institution_id
    into unit_institution_id
    from public.units unit
    where unit.id = new.scope_unit_id;

    if unit_institution_id <> membership_institution_id then
      raise check_violation using message = 'unit and membership must belong to the same institution';
    end if;
  end if;

  if new.scope_group_id is not null then
    select current_group.institution_id, current_group.unit_id
    into group_institution_id, group_unit_id
    from public.groups current_group
    where current_group.id = new.scope_group_id;

    if group_institution_id <> membership_institution_id
       or group_unit_id is distinct from new.scope_unit_id then
      raise check_violation using message = 'group must belong to the assignment unit and institution';
    end if;
  end if;

  return new;
end
$$;

create or replace function app_private.validate_guardian_link()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  guardian_type public.person_type;
  child_type public.person_type;
begin
  select person.person_type into guardian_type
  from public.people person where person.id = new.guardian_person_id;
  select person.person_type into child_type
  from public.people person where person.id = new.child_person_id;

  if guardian_type <> 'adult' or child_type <> 'child' then
    raise check_violation using message = 'guardian must be adult and child must be child';
  end if;
  return new;
end
$$;

create or replace function app_private.validate_child_context()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  if not exists (
    select 1 from public.people person
    where person.id = new.child_person_id and person.person_type = 'child'
  ) then
    raise check_violation using message = 'child context requires a child person';
  end if;
  return new;
end
$$;

create or replace function app_private.validate_child_unit_link()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  context_institution_id uuid;
  unit_institution_id uuid;
begin
  select context.institution_id into context_institution_id
  from public.child_contexts context where context.id = new.child_context_id;
  select unit.institution_id into unit_institution_id
  from public.units unit where unit.id = new.unit_id;

  if context_institution_id <> unit_institution_id then
    raise check_violation using message = 'child context and unit must belong to the same institution';
  end if;
  return new;
end
$$;

create or replace function app_private.validate_child_group_link()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  linked_unit_id uuid;
  group_unit_id uuid;
begin
  select unit_link.unit_id into linked_unit_id
  from public.child_unit_links unit_link where unit_link.id = new.child_unit_link_id;
  select current_group.unit_id into group_unit_id
  from public.groups current_group where current_group.id = new.group_id;

  if group_unit_id is null or linked_unit_id <> group_unit_id then
    raise check_violation using message = 'group must belong to the child unit';
  end if;
  return new;
end
$$;

create or replace function app_private.validate_guardian_context_permission()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  linked_child_id uuid;
  context_child_id uuid;
begin
  select guardian_link.child_person_id into linked_child_id
  from public.guardian_links guardian_link where guardian_link.id = new.guardian_link_id;
  select context.child_person_id into context_child_id
  from public.child_contexts context where context.id = new.child_context_id;

  if linked_child_id <> context_child_id then
    raise check_violation using message = 'guardian link and child context must reference the same child';
  end if;
  return new;
end
$$;

create or replace function app_private.validate_access_request_child()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  requester_id uuid;
  linked_guardian_id uuid;
  linked_child_id uuid;
  link_status public.record_status;
begin
  select request.requested_by into requester_id
  from public.child_unit_access_requests request where request.id = new.request_id;
  select guardian_link.guardian_person_id, guardian_link.child_person_id, guardian_link.status
  into linked_guardian_id, linked_child_id, link_status
  from public.guardian_links guardian_link where guardian_link.id = new.guardian_link_id;

  if link_status <> 'active'
     or linked_guardian_id <> requester_id
     or linked_child_id <> new.child_person_id then
    raise check_violation using message = 'request child requires an active guardian link owned by requester';
  end if;
  return new;
end
$$;

create or replace function app_private.validate_invitation_scope()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  unit_institution_id uuid;
  group_institution_id uuid;
  group_unit_id uuid;
begin
  if new.unit_id is not null then
    select unit.institution_id into unit_institution_id
    from public.units unit where unit.id = new.unit_id;
    if new.institution_id is null then
      new.institution_id := unit_institution_id;
    elsif new.institution_id <> unit_institution_id then
      raise check_violation using message = 'invitation unit must belong to invitation institution';
    end if;
  end if;

  if new.group_id is not null then
    select current_group.institution_id, current_group.unit_id
    into group_institution_id, group_unit_id
    from public.groups current_group where current_group.id = new.group_id;
    if new.institution_id is null then
      new.institution_id := group_institution_id;
    elsif new.institution_id <> group_institution_id then
      raise check_violation using message = 'invitation group must belong to invitation institution';
    end if;
    if new.unit_id is null then
      new.unit_id := group_unit_id;
    elsif new.unit_id is distinct from group_unit_id then
      raise check_violation using message = 'invitation group must belong to invitation unit';
    end if;
  end if;

  return new;
end
$$;

drop trigger if exists institution_role_assignments_validate on public.institution_role_assignments;
create trigger institution_role_assignments_validate
before insert or update on public.institution_role_assignments
for each row execute function app_private.validate_institution_role_assignment();

drop trigger if exists guardian_links_validate on public.guardian_links;
create trigger guardian_links_validate
before insert or update on public.guardian_links
for each row execute function app_private.validate_guardian_link();

drop trigger if exists child_contexts_validate on public.child_contexts;
create trigger child_contexts_validate
before insert or update on public.child_contexts
for each row execute function app_private.validate_child_context();

drop trigger if exists child_unit_links_validate on public.child_unit_links;
create trigger child_unit_links_validate
before insert or update on public.child_unit_links
for each row execute function app_private.validate_child_unit_link();

drop trigger if exists child_group_links_validate on public.child_group_links;
create trigger child_group_links_validate
before insert or update on public.child_group_links
for each row execute function app_private.validate_child_group_link();

drop trigger if exists guardian_context_permissions_validate on public.guardian_context_permissions;
create trigger guardian_context_permissions_validate
before insert or update on public.guardian_context_permissions
for each row execute function app_private.validate_guardian_context_permission();

drop trigger if exists child_unit_access_request_children_validate
  on public.child_unit_access_request_children;
create trigger child_unit_access_request_children_validate
before insert or update on public.child_unit_access_request_children
for each row execute function app_private.validate_access_request_child();

drop trigger if exists invitations_scope_validate on public.invitations;
create trigger invitations_scope_validate
before insert or update on public.invitations
for each row execute function app_private.validate_invitation_scope();

do $$
declare
  current_table text;
begin
  foreach current_table in array array[
    'institution_roles',
    'institution_permissions',
    'institution_role_permissions',
    'institution_role_assignments',
    'guardian_links',
    'child_contexts',
    'child_unit_links',
    'child_group_links',
    'guardian_context_permissions',
    'child_unit_access_requests',
    'child_unit_access_request_children'
  ]
  loop
    execute format('alter table public.%I enable row level security', current_table);
    execute format('revoke all on table public.%I from anon, authenticated', current_table);
    execute format('grant select on table public.%I to authenticated', current_table);
    execute format('grant all on table public.%I to service_role', current_table);
    execute format('drop policy if exists %I on public.%I', current_table || '_platform_read', current_table);
    execute format(
      'create policy %I on public.%I for select to authenticated using ((select app_private.has_platform_permission(''platform.read'')))',
      current_table || '_platform_read',
      current_table
    );
  end loop;
end $$;

create or replace view public.person_directory
with (security_invoker = true)
as
select
  person.id,
  person.person_type,
  person.display_name,
  person.status,
  exists (
    select 1
    from public.person_auth_links auth_link
    where auth_link.person_id = person.id
      and auth_link.status = 'active'
  ) as has_active_login,
  (
    select count(*)
    from public.institution_memberships membership
    where membership.person_id = person.id
      and membership.status = 'active'
      and membership.revoked_at is null
  ) as institution_count,
  (
    select count(*)
    from public.guardian_links guardian_link
    where guardian_link.guardian_person_id = person.id
      and guardian_link.status = 'active'
      and guardian_link.revoked_at is null
  ) as child_count
from public.people person
where person.deleted_at is null
  and (select app_private.has_platform_permission('platform.read'));

revoke all on table public.person_directory from public, anon, authenticated;
grant select on table public.person_directory to authenticated;
grant all on table public.person_directory to service_role;

with table_catalog(table_name, table_label, table_description, domain) as (
  values
    ('institution_roles', 'Perfis institucionais', 'Catalogo de perfis reutilizaveis por instituicao.', 'authorization'),
    ('institution_permissions', 'Permissoes institucionais', 'Catalogo de permissoes institucionais.', 'authorization'),
    ('institution_role_permissions', 'Permissoes por perfil institucional', 'Permissoes herdadas por perfil institucional.', 'authorization'),
    ('institution_role_assignments', 'Atribuicoes institucionais', 'Papeis e escopos de uma membership institucional.', 'authorization'),
    ('guardian_links', 'Vinculos de responsaveis', 'Relacoes globais entre responsaveis e criancas.', 'family'),
    ('child_contexts', 'Contextos infantis', 'Crianca dentro de uma instituicao.', 'tenancy'),
    ('child_unit_links', 'Criancas por unidade', 'Vinculo da crianca com uma unidade.', 'tenancy'),
    ('child_group_links', 'Criancas por grupo', 'Vinculo da crianca com grupo ou turma.', 'tenancy'),
    ('guardian_context_permissions', 'Permissoes do responsavel', 'Acesso do responsavel por contexto infantil.', 'family'),
    ('child_unit_access_requests', 'Solicitacoes de vinculo', 'Solicitacoes de responsaveis para unidades.', 'family'),
    ('child_unit_access_request_children', 'Criancas da solicitacao', 'Criancas selecionadas em uma solicitacao.', 'family')
)
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
select
  'public',
  table_catalog.table_name,
  table_catalog.table_label,
  table_catalog.table_description,
  table_catalog.domain,
  'active',
  1,
  now()
from table_catalog
on conflict (schema_name, table_name, version) do update set
  table_label = excluded.table_label,
  table_description = excluded.table_description,
  domain = excluded.domain,
  status = excluded.status,
  updated_at = now();

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
  allowed_locales_json,
  aliases_json,
  examples_json,
  updated_at
)
select
  schema_table.id,
  column_info.column_name,
  replace(column_info.column_name, '_', ' '),
  'Campo interno ' || column_info.column_name || '.',
  column_info.data_type,
  column_info.is_nullable = 'NO',
  column_info.is_nullable = 'YES',
  false,
  column_info.column_name in ('status', 'institution_id', 'unit_id', 'group_id'),
  false,
  true,
  column_info.ordinal_position,
  '["pt-BR"]'::jsonb,
  '{}'::jsonb,
  '[]'::jsonb,
  now()
from information_schema.columns column_info
join public.schema_tables schema_table
  on schema_table.schema_name = column_info.table_schema
 and schema_table.table_name = column_info.table_name
 and schema_table.version = 1
where column_info.table_schema = 'public'
  and column_info.table_name in (
    'institution_roles',
    'institution_permissions',
    'institution_role_permissions',
    'institution_role_assignments',
    'guardian_links',
    'child_contexts',
    'child_unit_links',
    'child_group_links',
    'guardian_context_permissions',
    'child_unit_access_requests',
    'child_unit_access_request_children'
  )
on conflict (schema_table_id, column_name) do update set
  column_type = excluded.column_type,
  is_required = excluded.is_required,
  is_nullable = excluded.is_nullable,
  is_filterable = excluded.is_filterable,
  is_active = true,
  position = excluded.position,
  updated_at = now();
