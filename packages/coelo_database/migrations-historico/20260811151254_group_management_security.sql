-- Secure group (Turma) management and import command foundation.
-- Browser clients receive read models and command RPCs, never business-rule
-- authority or direct write privileges for protected aggregates.

begin;

insert into public.platform_permissions(
  code, module_code, screen_code, action_code, description,
  risk_level, requires_mfa, status, updated_at
)
values
  ('groups.read', 'groups', 'directory', 'read',
   'Visualizar turmas e seus resumos efetivos.', 'normal', false, 'active', now()),
  ('groups.manage', 'groups', 'management', 'manage',
   'Criar e editar turmas, heranca e vinculos locais.', 'high', true, 'active', now()),
  ('imports.read', 'imports', 'directory', 'read',
   'Visualizar jobs e rejeicoes de importacao.', 'normal', false, 'active', now()),
  ('imports.manage', 'imports', 'processing', 'manage',
   'Criar e iniciar jobs de importacao auditados.', 'high', true, 'active', now())
on conflict (code) do update set
  module_code = excluded.module_code,
  screen_code = excluded.screen_code,
  action_code = excluded.action_code,
  description = excluded.description,
  risk_level = excluded.risk_level,
  requires_mfa = excluded.requires_mfa,
  status = excluded.status,
  updated_at = now();

insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow', 'active'
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code in ('owner', 'operations')
  and permission_record.code in ('groups.read', 'groups.manage', 'groups.export', 'imports.read', 'imports.manage')
on conflict (role_id, permission_id) do update set
  effect = 'allow', status = 'active', revoked_at = null;

insert into public.institution_permissions(
  code, module_code, screen_code, action_code, description, risk_level, status, updated_at
)
values
  ('groups.read', 'groups', 'directory', 'read',
   'Visualizar turmas dentro do escopo efetivo.', 'normal', 'active', now()),
  ('groups.manage', 'groups', 'management', 'manage',
   'Gerenciar turmas dentro do escopo efetivo.', 'high', 'active', now()),
  ('groups.access.manage', 'groups', 'access', 'manage',
   'Gerenciar vinculos locais e excecoes de acesso de turmas.', 'critical', 'active', now())
on conflict (code) do update set
  module_code = excluded.module_code,
  screen_code = excluded.screen_code,
  action_code = excluded.action_code,
  description = excluded.description,
  risk_level = excluded.risk_level,
  status = excluded.status,
  updated_at = now();

create unique index if not exists units_id_institution_uidx
  on public.units(id, institution_id);
create unique index if not exists groups_id_institution_unit_uidx
  on public.groups(id, institution_id, unit_id);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'groups_unit_institution_fkey'
  ) then
    alter table public.groups
      add constraint groups_unit_institution_fkey
      foreign key (unit_id, institution_id)
      references public.units(id, institution_id)
      on delete restrict;
  end if;
end $$;

alter table public.groups
  add column if not exists group_type_other_text text,
  add column if not exists inherit_appearance boolean not null default true,
  add column if not exists inherit_access boolean not null default true,
  add column if not exists inherit_activities boolean not null default true,
  add column if not exists management_version bigint not null default 1;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'groups_management_version_check'
  ) then
    alter table public.groups add constraint groups_management_version_check
      check (management_version > 0);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'groups_type_other_text_check'
  ) then
    alter table public.groups add constraint groups_type_other_text_check check (
      (lower(group_type) = 'other' and nullif(btrim(group_type_other_text), '') is not null)
      or (lower(group_type) <> 'other')
    );
  end if;
end $$;

create table if not exists public.group_branding (
  group_id uuid primary key references public.groups(id) on delete cascade,
  accent_color text,
  secondary_color text,
  text_color text,
  surface_color text,
  updated_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint group_branding_color_check check (
    (accent_color is null or accent_color ~ '^#[0-9A-Fa-f]{6}$')
    and (secondary_color is null or secondary_color ~ '^#[0-9A-Fa-f]{6}$')
    and (text_color is null or text_color ~ '^#[0-9A-Fa-f]{6}$')
    and (surface_color is null or surface_color ~ '^#[0-9A-Fa-f]{6}$')
  )
);

create table if not exists public.group_type_requests (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  group_id uuid references public.groups(id) on delete set null,
  requested_label text not null check (nullif(btrim(requested_label), '') is not null),
  justification text not null check (nullif(btrim(justification), '') is not null),
  status public.record_status not null default 'draft',
  requested_by_person_id uuid not null references public.people(id) on delete restrict,
  reviewed_by_person_id uuid references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists group_type_requests_institution_status_idx
  on public.group_type_requests(institution_id, status, created_at desc);

create table if not exists app_private.group_management_command_receipts (
  request_id uuid primary key,
  request_hash bytea not null,
  actor_person_id uuid not null references public.people(id) on delete restrict,
  group_id uuid not null references public.groups(id) on delete cascade,
  result_management_version bigint not null check (result_management_version > 0),
  created_at timestamptz not null default now()
);
revoke all on table app_private.group_management_command_receipts
  from public, anon, authenticated;

do $$
begin
  create type public.import_processing_state as enum (
    'PENDENTE', 'PROCESSANDO', 'SUCESSO', 'REJEICAO', 'ERRO'
  );
exception when duplicate_object then null;
end $$;

alter table public.import_jobs
  add column if not exists request_id uuid,
  add column if not exists request_hash bytea,
  add column if not exists start_request_id uuid,
  add column if not exists processing_state public.import_processing_state not null default 'PENDENTE',
  add column if not exists started_at timestamptz,
  add column if not exists finished_at timestamptz;
create unique index if not exists import_jobs_request_uidx on public.import_jobs(request_id)
  where request_id is not null;
create index if not exists import_jobs_institution_state_created_idx
  on public.import_jobs(institution_id, processing_state, created_at desc);
create index if not exists import_rows_job_status_row_idx
  on public.import_rows(import_job_id, status, row_number);
create index if not exists import_errors_job_row_idx
  on public.import_errors(import_job_id, row_number, column_name);

create table if not exists app_private.import_processing_queue (
  import_job_id uuid primary key references public.import_jobs(id) on delete cascade,
  state public.import_processing_state not null default 'PENDENTE',
  attempts integer not null default 0 check (attempts >= 0),
  available_at timestamptz not null default now(),
  locked_at timestamptz,
  locked_by text,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
revoke all on table app_private.import_processing_queue
  from public, anon, authenticated;

alter table public.group_branding enable row level security;
alter table public.group_type_requests enable row level security;
alter table public.groups enable row level security;
alter table public.import_jobs enable row level security;
alter table public.import_files enable row level security;
alter table public.import_mappings enable row level security;
alter table public.import_rows enable row level security;
alter table public.import_errors enable row level security;
alter table public.import_results enable row level security;
alter table public.group_branding force row level security;
alter table public.group_type_requests force row level security;
alter table public.groups force row level security;
alter table public.import_jobs force row level security;
alter table public.import_files force row level security;
alter table public.import_mappings force row level security;
alter table public.import_rows force row level security;
alter table public.import_errors force row level security;
alter table public.import_results force row level security;

revoke insert, update, delete on table public.groups from anon, authenticated;
revoke insert, update, delete on table public.group_branding from anon, authenticated;
revoke insert, update, delete on table public.group_type_requests from anon, authenticated;
revoke insert, update, delete on table public.import_jobs from anon, authenticated;
revoke insert, update, delete on table public.import_files from anon, authenticated;
revoke insert, update, delete on table public.import_mappings from anon, authenticated;
revoke insert, update, delete on table public.import_rows from anon, authenticated;
revoke insert, update, delete on table public.import_errors from anon, authenticated;
revoke insert, update, delete on table public.import_results from anon, authenticated;

drop policy if exists groups_platform_read on public.groups;
drop policy if exists groups_scoped_platform_read on public.groups;
drop policy if exists groups_authorized_read on public.groups;
create policy groups_authorized_read on public.groups for select to authenticated
using (
  (select app_private.has_platform_permission('groups.read'))
  or app_private.has_institution_permission(
    institution_id, 'groups.read', unit_id, id, false
  )
);

drop policy if exists group_branding_authorized_read on public.group_branding;
create policy group_branding_authorized_read on public.group_branding for select to authenticated
using (
  exists (
    select 1 from public.groups group_record
    where group_record.id = group_id
      and (
        (select app_private.has_platform_permission('groups.read'))
        or app_private.has_institution_permission(
          group_record.institution_id, 'groups.read',
          group_record.unit_id, group_record.id, false
        )
      )
  )
);

drop policy if exists group_type_requests_authorized_read on public.group_type_requests;
create policy group_type_requests_authorized_read on public.group_type_requests
for select to authenticated
using (
  (select app_private.has_platform_permission('groups.read'))
  or app_private.has_institution_permission(
    institution_id, 'groups.manage', null, group_id, false
  )
);

drop policy if exists import_jobs_platform_read on public.import_jobs;
drop policy if exists import_jobs_authorized_read on public.import_jobs;
create policy import_jobs_authorized_read on public.import_jobs for select to authenticated
using ((select app_private.has_platform_permission('imports.read')));

drop policy if exists import_files_platform_read on public.import_files;
drop policy if exists import_mappings_platform_read on public.import_mappings;
drop policy if exists import_rows_platform_read on public.import_rows;
drop policy if exists import_errors_platform_read on public.import_errors;
drop policy if exists import_results_platform_read on public.import_results;

drop policy if exists import_files_authorized_read on public.import_files;
create policy import_files_authorized_read on public.import_files
for select to authenticated using (
  (select app_private.has_platform_permission('imports.read'))
  and exists (
    select 1 from public.import_jobs job where job.id = import_job_id
  )
);
drop policy if exists import_mappings_authorized_read on public.import_mappings;
create policy import_mappings_authorized_read on public.import_mappings
for select to authenticated using (
  (select app_private.has_platform_permission('imports.read'))
  and exists (
    select 1 from public.import_jobs job where job.id = import_job_id
  )
);
drop policy if exists import_rows_authorized_read on public.import_rows;
create policy import_rows_authorized_read on public.import_rows
for select to authenticated using (
  (select app_private.has_platform_permission('imports.read'))
  and exists (
    select 1 from public.import_jobs job where job.id = import_job_id
  )
);
drop policy if exists import_errors_authorized_read on public.import_errors;
create policy import_errors_authorized_read on public.import_errors
for select to authenticated using (
  (select app_private.has_platform_permission('imports.read'))
  and exists (
    select 1 from public.import_jobs job where job.id = import_job_id
  )
);
drop policy if exists import_results_authorized_read on public.import_results;
create policy import_results_authorized_read on public.import_results
for select to authenticated using (
  (select app_private.has_platform_permission('imports.read'))
  and exists (
    select 1 from public.import_jobs job where job.id = import_job_id
  )
);

create or replace function app_private.group_management_request_hash(p_payload jsonb)
returns bytea language sql immutable security invoker set search_path = ''
as $$ select extensions.digest(pg_catalog.convert_to(p_payload::text, 'UTF8'), 'sha256') $$;

create or replace function app_private.group_management_payload(p_group_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$
  with target as (
    select group_record.*, institution_record.public_name as institution_name,
           unit_record.name as unit_name,
           unit_branding_record.inherit_institution_branding,
           unit_branding_record.accent_color as unit_accent_color,
           unit_branding_record.secondary_color as unit_secondary_color,
           unit_branding_record.text_color as unit_text_color,
           unit_branding_record.surface_color as unit_surface_color,
           institution_branding_record.accent_color as institution_accent_color,
           institution_branding_record.secondary_color as institution_secondary_color,
           institution_branding_record.text_color as institution_text_color,
           institution_branding_record.surface_color as institution_surface_color,
           group_branding_record.accent_color as group_accent_color,
           group_branding_record.secondary_color as group_secondary_color,
           group_branding_record.text_color as group_text_color,
           group_branding_record.surface_color as group_surface_color
    from public.groups group_record
    join public.institutions institution_record on institution_record.id = group_record.institution_id
    join public.units unit_record on unit_record.id = group_record.unit_id
      and unit_record.institution_id = group_record.institution_id
    left join public.unit_branding unit_branding_record on unit_branding_record.unit_id = group_record.unit_id
    left join public.institution_branding institution_branding_record
      on institution_branding_record.institution_id = group_record.institution_id
    left join public.group_branding group_branding_record on group_branding_record.group_id = group_record.id
    where group_record.id = p_group_id
  ), effective_access as (
    select membership.person_id, person_record.display_name,
           assignment.scope_kind,
           case assignment.scope_kind
             when 'institution' then 'institution'
             when 'unit' then 'unit'
             else 'group_local'
           end as origin,
           role_record.id as profile_id, role_record.code as profile_code,
           role_record.name as profile_name,
           coalesce(jsonb_agg(distinct permission_record.code)
             filter (where permission_record.code is not null), '[]'::jsonb) as capabilities
    from target
    join public.institution_memberships membership
      on membership.institution_id = target.institution_id
     and membership.status = 'active' and membership.revoked_at is null
    join public.people person_record on person_record.id = membership.person_id
    join public.institution_role_assignments assignment
      on assignment.membership_id = membership.id and assignment.status = 'active'
     and (assignment.starts_at is null or assignment.starts_at <= now())
     and (assignment.expires_at is null or assignment.expires_at > now())
     and (
       assignment.scope_kind = 'institution'
       or (assignment.scope_kind = 'unit' and assignment.scope_unit_id = target.unit_id)
       or (assignment.scope_kind = 'group' and assignment.scope_group_id = target.id)
     )
    join public.institution_roles role_record on role_record.id = assignment.role_id
      and role_record.status = 'active'
    left join public.institution_role_permissions role_permission
      on role_permission.role_id = role_record.id
     and role_permission.status = 'active' and role_permission.revoked_at is null
    left join public.institution_permissions permission_record
      on permission_record.id = role_permission.permission_id and permission_record.status = 'active'
    group by membership.person_id, person_record.display_name, assignment.scope_kind,
             role_record.id, role_record.code, role_record.name
  ), access_rows as (
    select jsonb_agg(jsonb_build_object(
      'person_id', person_id, 'display_name', display_name,
      'origin', origin, 'inherited', origin <> 'group_local',
      'profile_id', profile_id, 'profile_code', profile_code,
      'profile_name', profile_name, 'capabilities', capabilities,
      'restrictions', coalesce((
        select jsonb_agg(override_record.permission_code order by override_record.permission_code)
        from public.institution_memberships membership
        join public.institution_member_permission_overrides override_record
          on override_record.membership_id = membership.id
         and override_record.effect = 'deny' and override_record.status = 'active'
         and override_record.revoked_at is null
        where membership.person_id = effective_access.person_id
          and membership.institution_id = (select institution_id from target)
          and (override_record.scope_kind = 'institution'
            or (override_record.scope_kind = 'unit' and override_record.scope_id = (select unit_id from target))
            or (override_record.scope_kind = 'group' and override_record.scope_id = p_group_id))
      ), '[]'::jsonb)
    ) order by (origin <> 'group_local') desc, display_name) as value from effective_access
  )
  select jsonb_build_object(
    'id', target.id, 'institution_id', target.institution_id,
    'institution_name', target.institution_name, 'unit_id', target.unit_id,
    'unit_name', target.unit_name, 'name', target.name,
    'group_type', target.group_type,
    'group_type_other_text', target.group_type_other_text,
    'status', target.status, 'inherit_appearance', target.inherit_appearance,
    'inherit_access', target.inherit_access,
    'inherit_activities', target.inherit_activities,
    'management_version', target.management_version,
    'appearance_origin', case
      when not target.inherit_appearance then 'group_local'
      when coalesce(target.inherit_institution_branding, true) then 'institution'
      else 'unit' end,
    'effective_appearance', jsonb_build_object(
      'accent_color', case when not target.inherit_appearance then target.group_accent_color
        when coalesce(target.inherit_institution_branding, true) then target.institution_accent_color
        else target.unit_accent_color end,
      'secondary_color', case when not target.inherit_appearance then target.group_secondary_color
        when coalesce(target.inherit_institution_branding, true) then target.institution_secondary_color
        else target.unit_secondary_color end,
      'text_color', case when not target.inherit_appearance then target.group_text_color
        when coalesce(target.inherit_institution_branding, true) then target.institution_text_color
        else target.unit_text_color end,
      'surface_color', case when not target.inherit_appearance then target.group_surface_color
        when coalesce(target.inherit_institution_branding, true) then target.institution_surface_color
        else target.unit_surface_color end
    ),
    'effective_access', coalesce((select value from access_rows), '[]'::jsonb),
    'activity_ids', case when target.inherit_activities then
      coalesce((select jsonb_agg(unit_link.activity_id order by unit_link.activity_id)
        from public.activity_unit_links unit_link
        where unit_link.unit_id = target.unit_id and unit_link.status = 'active'), '[]'::jsonb)
      else coalesce((select jsonb_agg(link.activity_id order by link.activity_id)
        from public.activity_group_links link
        where link.group_id = target.id and link.status = 'active'), '[]'::jsonb)
      end,
    'invites', coalesce((select jsonb_agg(jsonb_build_object(
      'id', invitation.id, 'person_id', invitation.target_person_id,
      'display_name', person_record.display_name, 'role_code', invitation.role_code,
      'status', invitation.invitation_state, 'send_count', invitation.send_count
    ) order by invitation.created_at)
      from public.invitations invitation
      join public.people person_record on person_record.id = invitation.target_person_id
      where invitation.group_id = target.id
        and invitation.institution_id = target.institution_id
        and invitation.invitation_state <> 'revoked'), '[]'::jsonb),
    'created_at', target.created_at, 'updated_at', target.updated_at
  ) from target
$$;

create or replace function app_private.superadmin_group_get(p_group_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare result jsonb;
begin
  if (select auth.uid()) is null or app_private.current_person_id() is null then
    raise insufficient_privilege using message = 'authenticated person required';
  end if;
  if not app_private.has_platform_permission('groups.read') then
    raise insufficient_privilege using message = 'groups.read required';
  end if;
  result := app_private.group_management_payload(p_group_id);
  if result is null then raise no_data_found using message = 'group not found'; end if;
  return result;
end $$;

create or replace function app_private.superadmin_group_directory(
  p_search text default '', p_institution_ids uuid[] default '{}',
  p_unit_ids uuid[] default '{}', p_type_ids text[] default '{}',
  p_statuses text[] default '{}', p_limit integer default 20,
  p_offset integer default 0, p_sort text default 'name',
  p_sort_ascending boolean default true
) returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare result jsonb;
begin
  if (select auth.uid()) is null or app_private.current_person_id() is null
     or not app_private.has_platform_permission('groups.read') then
    raise insufficient_privilege using message = 'groups.read required';
  end if;
  if p_limit < 1 or p_limit > 100 or p_offset < 0 then
    raise invalid_parameter_value using message = 'invalid pagination';
  end if;
  if p_sort not in ('name', 'institution_name', 'unit_name', 'group_type', 'status') then
    raise invalid_parameter_value using message = 'invalid sort';
  end if;
  with filtered as (
    select group_record.*, institution_record.public_name as institution_name,
           unit_record.name as unit_name, count(*) over() as total_count
    from public.groups group_record
    join public.institutions institution_record on institution_record.id = group_record.institution_id
    join public.units unit_record on unit_record.id = group_record.unit_id
      and unit_record.institution_id = group_record.institution_id
    where (nullif(btrim(p_search), '') is null
      or group_record.name ilike '%' || replace(replace(replace(btrim(p_search), '\\', '\\\\'), '%', '\\%'), '_', '\\_') || '%' escape '\\')
      and (cardinality(p_institution_ids) = 0 or group_record.institution_id = any(p_institution_ids))
      and (cardinality(p_unit_ids) = 0 or group_record.unit_id = any(p_unit_ids))
      and (cardinality(p_type_ids) = 0 or group_record.group_type = any(p_type_ids))
      and (cardinality(p_statuses) = 0 or group_record.status::text = any(p_statuses))
    order by
      case when p_sort_ascending and p_sort = 'name' then group_record.name end asc,
      case when not p_sort_ascending and p_sort = 'name' then group_record.name end desc,
      case when p_sort_ascending and p_sort = 'institution_name' then institution_record.public_name end asc,
      case when not p_sort_ascending and p_sort = 'institution_name' then institution_record.public_name end desc,
      case when p_sort_ascending and p_sort = 'unit_name' then unit_record.name end asc,
      case when not p_sort_ascending and p_sort = 'unit_name' then unit_record.name end desc,
      case when p_sort_ascending and p_sort = 'group_type' then group_record.group_type end asc,
      case when not p_sort_ascending and p_sort = 'group_type' then group_record.group_type end desc,
      case when p_sort_ascending and p_sort = 'status' then group_record.status::text end asc,
      case when not p_sort_ascending and p_sort = 'status' then group_record.status::text end desc,
      group_record.id
    limit p_limit offset p_offset
  )
  select jsonb_build_object(
    'items', coalesce(jsonb_agg(jsonb_build_object(
      'id', id, 'institution_id', institution_id, 'institution_name', institution_name,
      'unit_id', unit_id, 'unit_name', unit_name, 'name', name,
      'group_type', group_type, 'group_type_other_text', group_type_other_text,
      'status', status, 'created_at', created_at, 'updated_at', updated_at
    )), '[]'::jsonb),
    'total_count', coalesce(max(total_count), 0)
  ) into result from filtered;
  return result;
end $$;


create table if not exists app_private.invitation_delivery_queue (
  invitation_id uuid primary key references public.invitations(id) on delete cascade,
  requested_by_person_id uuid not null references public.people(id) on delete restrict,
  state text not null default 'pending' check (state in ('pending','processing','sent','rejected','error')),
  attempts integer not null default 0 check (attempts >= 0),
  available_at timestamptz not null default now(),
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
revoke all on table app_private.invitation_delivery_queue from public, anon, authenticated;
create or replace function app_private.superadmin_group_save(
  p_request_id uuid, p_group_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
declare
  actor_person_id uuid;
  request_hash bytea;
  prior app_private.group_management_command_receipts%rowtype;
  unit_record public.units%rowtype;
  group_record public.groups%rowtype;
  payload_institution_id uuid;
  payload_unit_id uuid;
  local_person jsonb;
  activity_value text;
  invite_value jsonb;
  role_record_id uuid;
  target_membership_id uuid;
  target_person_id uuid;
  target_invitation_id uuid;
  enqueue_invite boolean;
  result jsonb;
begin
  if p_request_id is null or p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise invalid_parameter_value using message = 'request_id and payload are required';
  end if;
  if (select auth.uid()) is null then raise insufficient_privilege using message = 'authentication required'; end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then raise insufficient_privilege using message = 'active person required'; end if;
  if not app_private.has_platform_permission('groups.manage') then
    raise insufficient_privilege using message = 'groups.manage required';
  end if;
  if not app_private.has_mfa_aal2() then raise insufficient_privilege using message = 'MFA AAL2 required'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  request_hash := app_private.group_management_request_hash(p_payload);
  select * into prior from app_private.group_management_command_receipts where request_id = p_request_id;
  if found then
    if prior.actor_person_id <> actor_person_id or prior.request_hash <> request_hash
       or prior.group_id is distinct from p_group_id then
      raise invalid_parameter_value using message = 'request_id already used by another command';
    end if;
    result := app_private.group_management_payload(prior.group_id);
    if (result ->> 'management_version')::bigint <> prior.result_management_version then
      raise serialization_failure using message = 'receipt result is no longer current';
    end if;
    return result;
  end if;

  if p_payload - array[
    'institution_id','unit_id','name','group_type','group_type_other_text','status',
    'inherit_appearance','inherit_access','inherit_activities','branding','local_people',
    'activity_ids','invites','type_request'
  ] <> '{}'::jsonb then
    raise invalid_parameter_value using message = 'unknown group payload key';
  end if;
  payload_unit_id := nullif(p_payload ->> 'unit_id', '')::uuid;
  payload_institution_id := nullif(p_payload ->> 'institution_id', '')::uuid;
  select * into unit_record from public.units where id = payload_unit_id and status = 'active';
  if unit_record.id is null then raise invalid_parameter_value using message = 'unknown or inactive unit'; end if;
  if payload_institution_id is distinct from unit_record.institution_id then
    raise invalid_parameter_value using message = 'unit does not belong to institution';
  end if;
  if nullif(btrim(p_payload ->> 'name'), '') is null
     or nullif(btrim(p_payload ->> 'group_type'), '') is null then
    raise invalid_parameter_value using message = 'name and group_type are required';
  end if;

  if p_group_id is null then
    if coalesce(p_expected_version, 0) <> 0 then
      raise invalid_parameter_value using message = 'create expected_version must be zero';
    end if;
    insert into public.groups(
      institution_id, unit_id, name, group_type, group_type_other_text, status,
      inherit_appearance, inherit_access, inherit_activities, created_at, updated_at
    ) values (
      unit_record.institution_id, unit_record.id, btrim(p_payload ->> 'name'),
      lower(btrim(p_payload ->> 'group_type')), nullif(btrim(p_payload ->> 'group_type_other_text'), ''),
      coalesce(p_payload ->> 'status', 'active')::public.record_status,
      coalesce((p_payload ->> 'inherit_appearance')::boolean, true),
      coalesce((p_payload ->> 'inherit_access')::boolean, true),
      coalesce((p_payload ->> 'inherit_activities')::boolean, true), now(), now()
    ) returning * into group_record;
  else
    select * into group_record from public.groups where id = p_group_id for update;
    if group_record.id is null then raise no_data_found using message = 'group not found'; end if;
    if group_record.institution_id <> unit_record.institution_id or group_record.unit_id <> unit_record.id then
      raise invalid_parameter_value using message = 'group hierarchy cannot be changed';
    end if;
    if group_record.management_version <> p_expected_version then
      raise serialization_failure using message = 'stale group version';
    end if;
    update public.groups set
      name = btrim(p_payload ->> 'name'),
      group_type = lower(btrim(p_payload ->> 'group_type')),
      group_type_other_text = nullif(btrim(p_payload ->> 'group_type_other_text'), ''),
      status = coalesce(p_payload ->> 'status', status::text)::public.record_status,
      inherit_appearance = coalesce((p_payload ->> 'inherit_appearance')::boolean, inherit_appearance),
      inherit_access = coalesce((p_payload ->> 'inherit_access')::boolean, inherit_access),
      inherit_activities = coalesce((p_payload ->> 'inherit_activities')::boolean, inherit_activities),
      management_version = management_version + 1, updated_at = now()
    where id = p_group_id returning * into group_record;
  end if;

  if group_record.inherit_appearance then
    delete from public.group_branding where group_id = group_record.id;
  else
    if jsonb_typeof(p_payload -> 'branding') <> 'object' then
      raise invalid_parameter_value using message = 'local branding is required when appearance is customized';
    end if;
    insert into public.group_branding(
      group_id, accent_color, secondary_color, text_color, surface_color,
      updated_by_person_id, updated_at
    ) values (
      group_record.id, nullif(p_payload -> 'branding' ->> 'accent_color', ''),
      nullif(p_payload -> 'branding' ->> 'secondary_color', ''),
      nullif(p_payload -> 'branding' ->> 'text_color', ''),
      nullif(p_payload -> 'branding' ->> 'surface_color', ''), actor_person_id, now()
    ) on conflict (group_id) do update set
      accent_color = excluded.accent_color, secondary_color = excluded.secondary_color,
      text_color = excluded.text_color, surface_color = excluded.surface_color,
      updated_by_person_id = excluded.updated_by_person_id, updated_at = now();
  end if;

  if p_payload ? 'local_people' then
    if jsonb_typeof(p_payload -> 'local_people') <> 'array' then
      raise invalid_parameter_value using message = 'local_people must be an array';
    end if;
    update public.institution_role_assignments assignment
       set status = 'inactive', updated_at = now()
      from public.institution_memberships membership
     where assignment.membership_id = membership.id
       and assignment.scope_kind = 'group'
       and assignment.scope_group_id = group_record.id
       and assignment.status = 'active'
       and membership.institution_id = group_record.institution_id
       and membership.person_id not in (
         select (value ->> 'person_id')::uuid
           from jsonb_array_elements(p_payload -> 'local_people') value
       );
    for local_person in select value from jsonb_array_elements(p_payload -> 'local_people') loop
      target_person_id := nullif(local_person ->> 'person_id', '')::uuid;
      if target_person_id is null or not exists (
        select 1 from public.people where id = target_person_id and status = 'active'
      ) then
        raise invalid_parameter_value using message = 'local person must be an existing active global identity';
      end if;
      select id into role_record_id from public.institution_roles
      where code = local_person ->> 'role_code' and status = 'active'
        and (institution_id is null or institution_id = group_record.institution_id)
      order by institution_id nulls last limit 1;
      if role_record_id is null then raise invalid_parameter_value using message = 'unknown role_code'; end if;
      target_membership_id := null;
      select id into target_membership_id from public.institution_memberships
      where person_id = target_person_id
        and institution_id = group_record.institution_id
        and status = 'active' and revoked_at is null
      order by created_at desc limit 1;
      if target_membership_id is null then
        insert into public.institution_memberships(
          person_id, institution_id, role_code, status, scope_kind,
          scope_unit_id, scope_group_id, invited_by
        ) values (
          target_person_id, group_record.institution_id,
          local_person ->> 'role_code', 'active', 'group', group_record.unit_id,
          group_record.id, actor_person_id
        ) returning id into target_membership_id;
      end if;
      update public.institution_role_assignments set
        status = 'inactive', updated_at = now()
      where membership_id = target_membership_id and status = 'active'
        and scope_kind = 'group' and scope_group_id = group_record.id
        and role_id <> role_record_id;
      insert into public.institution_role_assignments(
        membership_id, role_id, scope_kind, scope_unit_id, scope_group_id,
        status, granted_by
      ) values (
        target_membership_id, role_record_id, 'group', group_record.unit_id,
        group_record.id, 'active', actor_person_id
      ) on conflict do nothing;
    end loop;
  end if;

  if p_payload ? 'activity_ids' then
    if jsonb_typeof(p_payload -> 'activity_ids') <> 'array' then
      raise invalid_parameter_value using message = 'activity_ids must be an array';
    end if;
    update public.activity_group_links set status = 'inactive', updated_at = now()
    where group_id = group_record.id and status = 'active'
      and activity_id not in (
        select value::uuid from jsonb_array_elements_text(p_payload -> 'activity_ids') value
      );
    for activity_value in select value from jsonb_array_elements_text(p_payload -> 'activity_ids') loop
      if not exists (
        select 1 from public.activity_definitions definition
        join public.activity_unit_links unit_link on unit_link.activity_id = definition.id
          and unit_link.unit_id = group_record.unit_id and unit_link.status = 'active'
        where definition.id = activity_value::uuid
          and definition.institution_id = group_record.institution_id
      ) then raise invalid_parameter_value using message = 'activity is outside group hierarchy'; end if;
      insert into public.activity_group_links(activity_id, group_id, institution_id, unit_id, linked_by_person_id, status)
      values (activity_value::uuid, group_record.id, group_record.institution_id, group_record.unit_id, actor_person_id, 'active')
      on conflict (activity_id, group_id) do update set status = 'active', updated_at = now();
    end loop;
  end if;

  if p_payload ? 'invites' then
    if jsonb_typeof(p_payload -> 'invites') <> 'array' then
      raise invalid_parameter_value using message = 'invites must be an array';
    end if;
    update public.invitations invitation
       set invitation_state = 'revoked', revoked_at = now(), status = 'inactive'
     where invitation.group_id = group_record.id
       and invitation.invitation_state = 'pending'
       and invitation.id not in (
         select (value ->> 'invitation_id')::uuid
           from jsonb_array_elements(p_payload -> 'invites') value
          where nullif(value ->> 'invitation_id', '') is not null
            and value ->> 'invitation_id' not like 'invite-%'
       );
    for invite_value in select value from jsonb_array_elements(p_payload -> 'invites') loop
      target_person_id := nullif(invite_value ->> 'person_id', '')::uuid;
      if target_person_id is null or not exists (
        select 1 from public.people where id = target_person_id and status = 'active'
      ) then
        raise invalid_parameter_value using message = 'invite target must be an existing active global identity';
      end if;
      if not exists (
        select 1 from public.institution_roles
         where code = invite_value ->> 'role_code' and status = 'active'
           and (institution_id is null or institution_id = group_record.institution_id)
      ) then
        raise invalid_parameter_value using message = 'unknown invitation role_code';
      end if;
      enqueue_invite := false;
      target_invitation_id := case
        when nullif(invite_value ->> 'invitation_id', '') is null
          or invite_value ->> 'invitation_id' like 'invite-%' then null
        else (invite_value ->> 'invitation_id')::uuid end;
      if target_invitation_id is null then
        insert into public.invitations(
          scope_kind, institution_id, unit_id, group_id, target_person_id,
          role_code, token_hash, expires_at, invitation_state, invited_by,
          send_count, sent_at, last_sent_at
        ) values (
          'group', group_record.institution_id, group_record.unit_id, group_record.id,
          target_person_id, invite_value ->> 'role_code',
          encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'),
          now() + interval '7 days', 'pending', actor_person_id, 1, now(), now()
        ) returning id into target_invitation_id;
        enqueue_invite := true;
      else
        update public.invitations
           set last_sent_at = case when invite_value ->> 'command' = 'resend' then now() else last_sent_at end,
               send_count = case when invite_value ->> 'command' = 'resend' then send_count + 1 else send_count end
         where id = target_invitation_id and group_id = group_record.id
           and institution_id = group_record.institution_id and invitation_state = 'pending';
        if not found then raise no_data_found using message = 'invitation not found in group scope'; end if;
        enqueue_invite := invite_value ->> 'command' = 'resend';
      end if;
      if enqueue_invite then
        insert into app_private.invitation_delivery_queue(invitation_id, requested_by_person_id)
      values (target_invitation_id, actor_person_id)
      on conflict (invitation_id) do update set
        state = 'pending', requested_by_person_id = excluded.requested_by_person_id,
        available_at = now(), updated_at = now();
      end if;
    end loop;
  end if;
  if p_payload ? 'type_request' and jsonb_typeof(p_payload -> 'type_request') = 'object' then
    insert into public.group_type_requests(
      institution_id, group_id, requested_label, justification, requested_by_person_id
    ) values (
      group_record.institution_id, group_record.id,
      p_payload -> 'type_request' ->> 'label',
      p_payload -> 'type_request' ->> 'justification', actor_person_id
    );
  end if;

  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor_person_id, auth.jwt() ->> 'aal',
    case when p_group_id is null then 'group.create' else 'group.update' end,
    'group', group_record.id, group_record.institution_id, 'success',
    jsonb_build_object(
      'management_version', group_record.management_version,
      'inherit_appearance', group_record.inherit_appearance,
      'inherit_access', group_record.inherit_access,
      'inherit_activities', group_record.inherit_activities
    )
  );
  insert into app_private.group_management_command_receipts(
    request_id, request_hash, actor_person_id, group_id, result_management_version
  ) values (
    p_request_id, request_hash, actor_person_id, group_record.id, group_record.management_version
  );
  return app_private.group_management_payload(group_record.id);
end $$;

create or replace function app_private.superadmin_import_payload(p_import_job_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'id', job.id, 'institution_id', job.institution_id,
    'target_domain', job.target_domain, 'target_table', job.target_table,
    'source_format', job.source_format, 'processing_state', job.processing_state,
    'summary', job.summary, 'created_at', job.created_at,
    'started_at', job.started_at, 'finished_at', job.finished_at,
    'result', coalesce(to_jsonb(result_record), '{}'::jsonb),
    'errors', coalesce((select jsonb_agg(jsonb_build_object(
      'row', error_record.row_number, 'field', error_record.column_name,
      'code', error_record.error_code, 'message', error_record.message
    ) order by error_record.row_number, error_record.column_name)
      from public.import_errors error_record where error_record.import_job_id = job.id), '[]'::jsonb)
  )
  from public.import_jobs job
  left join public.import_results result_record on result_record.import_job_id = job.id
  where job.id = p_import_job_id
$$;

create or replace function app_private.superadmin_import_create(p_request_id uuid, p_payload jsonb)
returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
declare actor_person_id uuid; request_hash bytea; job public.import_jobs%rowtype;
begin
  if p_request_id is null or p_payload is null then raise invalid_parameter_value using message = 'request required'; end if;
  if (select auth.uid()) is null then raise insufficient_privilege using message = 'authentication required'; end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null or not app_private.has_platform_permission('imports.manage') then
    raise insufficient_privilege using message = 'imports.manage required';
  end if;
  if not app_private.has_mfa_aal2() then raise insufficient_privilege using message = 'MFA AAL2 required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  request_hash := extensions.digest(convert_to(p_payload::text, 'UTF8'), 'sha256');
  select * into job from public.import_jobs where request_id = p_request_id;
  if found then
    if job.created_by <> actor_person_id or job.request_hash <> request_hash then
      raise invalid_parameter_value using message = 'request_id already used';
    end if;
    return app_private.superadmin_import_payload(job.id);
  end if;
  if p_payload ->> 'target_table' not in ('institutions','units','groups','people','activities')
     or p_payload ->> 'source_format' not in ('csv','xlsx') then
    raise invalid_parameter_value using message = 'unsupported import schema or format';
  end if;
  insert into public.import_jobs(
    request_id, request_hash, institution_id, target_domain, target_table,
    source_format, source_locale, target_locale, status, processing_state,
    summary, created_by
  ) values (
    p_request_id, request_hash, nullif(p_payload ->> 'institution_id', '')::uuid,
    coalesce(nullif(p_payload ->> 'target_domain', ''), 'superadmin'),
    p_payload ->> 'target_table', p_payload ->> 'source_format',
    coalesce(nullif(p_payload ->> 'source_locale', ''), 'pt-BR'), 'pt-BR',
    'draft', 'PENDENTE', coalesce(p_payload -> 'summary', '{}'::jsonb), actor_person_id
  ) returning * into job;
  insert into public.import_results(import_job_id) values (job.id);
  insert into audit.audit_logs(actor_person_id, action_code, object_type, object_id,
    institution_id, outcome, after_json)
  values (actor_person_id, 'import.create', 'import_job', job.id, job.institution_id,
    'success', jsonb_build_object('target_table', job.target_table, 'state', job.processing_state));
  return app_private.superadmin_import_payload(job.id);
end $$;

create or replace function app_private.superadmin_import_start(p_request_id uuid, p_import_job_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
declare actor_person_id uuid; job public.import_jobs%rowtype;
begin
  if p_request_id is null or p_import_job_id is null then raise invalid_parameter_value using message = 'request required'; end if;
  if (select auth.uid()) is null then raise insufficient_privilege using message = 'authentication required'; end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null or not app_private.has_platform_permission('imports.manage') then
    raise insufficient_privilege using message = 'imports.manage required';
  end if;
  if not app_private.has_mfa_aal2() then raise insufficient_privilege using message = 'MFA AAL2 required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_import_job_id::text, 0));
  select * into job from public.import_jobs where start_request_id = p_request_id;
  if found then
    if job.id <> p_import_job_id then
      raise invalid_parameter_value using message = 'request_id already used by another import';
    end if;
    return app_private.superadmin_import_payload(job.id);
  end if;
  select * into job from public.import_jobs where id = p_import_job_id for update;
  if job.id is null then raise no_data_found using message = 'import job not found'; end if;
  if job.created_by <> actor_person_id and not app_private.has_platform_permission('imports.manage') then
    raise insufficient_privilege using message = 'import job outside actor scope';
  end if;
  if job.processing_state in ('SUCESSO','REJEICAO','ERRO') then
    return app_private.superadmin_import_payload(job.id);
  end if;
  update public.import_jobs set processing_state = 'PROCESSANDO', status = 'active',
    start_request_id = p_request_id, started_at = coalesce(started_at, now()),
    updated_at = now() where id = job.id;
  insert into app_private.import_processing_queue(import_job_id, state, available_at)
  values (job.id, 'PENDENTE', now())
  on conflict (import_job_id) do update set state = 'PENDENTE', available_at = now(), updated_at = now();
  insert into audit.audit_logs(actor_person_id, action_code, object_type, object_id,
    institution_id, outcome, after_json)
  values (actor_person_id, 'import.start', 'import_job', job.id, job.institution_id,
    'success', jsonb_build_object('state', 'PROCESSANDO'));
  return app_private.superadmin_import_payload(job.id);
end $$;


create or replace function app_private.superadmin_group_export_create(
  p_request_id uuid, p_payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
declare
  actor_person_id uuid;
  request_hash bytea;
  job public.import_jobs%rowtype;
  value text;
begin
  if p_request_id is null or p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise invalid_parameter_value using message = 'request_id and payload are required';
  end if;
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null or not app_private.has_platform_permission('groups.export') then
    raise insufficient_privilege using message = 'groups.export required';
  end if;
  if not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message = 'MFA AAL2 required';
  end if;
  if p_payload - array[
    'search','institution_ids','unit_ids','type_ids','statuses',
    'sort','sort_ascending','format'
  ] <> '{}'::jsonb then
    raise invalid_parameter_value using message = 'unknown export payload key';
  end if;
  if length(coalesce(p_payload ->> 'search', '')) > 200
     or coalesce(p_payload ->> 'sort', 'name') not in
       ('name','institution_name','unit_name','group_type','status')
     or coalesce(p_payload ->> 'format', 'xlsx') not in ('csv','xlsx') then
    raise invalid_parameter_value using message = 'invalid export parameters';
  end if;
  if jsonb_typeof(coalesce(p_payload -> 'institution_ids', '[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(p_payload -> 'unit_ids', '[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(p_payload -> 'type_ids', '[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(p_payload -> 'statuses', '[]'::jsonb)) <> 'array' then
    raise invalid_parameter_value using message = 'export filters must be arrays';
  end if;
  for value in select item.value from jsonb_array_elements_text(
    coalesce(p_payload -> 'institution_ids', '[]'::jsonb)
  ) as item(value) loop perform value::uuid; end loop;
  for value in select item.value from jsonb_array_elements_text(
    coalesce(p_payload -> 'unit_ids', '[]'::jsonb)
  ) as item(value) loop perform value::uuid; end loop;
  if exists (
    select 1 from jsonb_array_elements_text(
      coalesce(p_payload -> 'statuses', '[]'::jsonb)
    ) as status_item(value) where status_item.value not in ('draft','active','inactive','suspended','archived')
  ) then raise invalid_parameter_value using message = 'invalid group status filter'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  request_hash := extensions.digest(convert_to(p_payload::text, 'UTF8'), 'sha256');
  select * into job from public.import_jobs where request_id = p_request_id;
  if found then
    if job.created_by <> actor_person_id or job.request_hash <> request_hash
       or job.target_domain <> 'groups_export' then
      raise invalid_parameter_value using message = 'request_id already used';
    end if;
    return app_private.superadmin_import_payload(job.id);
  end if;

  insert into public.import_jobs(
    request_id, request_hash, target_domain, target_table, source_format,
    source_locale, target_locale, status, processing_state, started_at,
    summary, created_by
  ) values (
    p_request_id, request_hash, 'groups_export', 'groups',
    coalesce(p_payload ->> 'format', 'xlsx'), 'pt-BR', 'pt-BR',
    'active', 'PROCESSANDO', now(),
    jsonb_build_object('operation', 'export', 'context', 'Turmas', 'filters', p_payload),
    actor_person_id
  ) returning * into job;
  insert into public.import_results(import_job_id) values (job.id);
  insert into app_private.import_processing_queue(import_job_id, state, available_at)
  values (job.id, 'PENDENTE', now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id, outcome, after_json
  ) values (
    actor_person_id, auth.jwt() ->> 'aal', 'group.export.start',
    'import_job', job.id, 'success',
    jsonb_build_object('format', job.source_format, 'state', job.processing_state)
  );
  return app_private.superadmin_import_payload(job.id);
end $$;
create or replace function public.superadmin_group_get(p_group_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.superadmin_group_get(p_group_id) $$;
create or replace function public.superadmin_group_directory(
  p_search text default '', p_institution_ids uuid[] default '{}',
  p_unit_ids uuid[] default '{}', p_type_ids text[] default '{}',
  p_statuses text[] default '{}', p_limit integer default 20,
  p_offset integer default 0, p_sort text default 'name', p_sort_ascending boolean default true
) returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.superadmin_group_directory(p_search,p_institution_ids,p_unit_ids,p_type_ids,p_statuses,p_limit,p_offset,p_sort,p_sort_ascending) $$;
create or replace function public.superadmin_group_save(
  p_request_id uuid, p_group_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_group_save(p_request_id,p_group_id,p_expected_version,p_payload) $$;
create or replace function public.superadmin_group_export_create(
  p_request_id uuid, p_payload jsonb
) returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_group_export_create(p_request_id,p_payload) $$;
create or replace function public.superadmin_import_create(p_request_id uuid, p_payload jsonb)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_import_create(p_request_id,p_payload) $$;
create or replace function public.superadmin_import_start(p_request_id uuid, p_import_job_id uuid)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_import_start(p_request_id,p_import_job_id) $$;

revoke all on function app_private.group_management_request_hash(jsonb) from public, anon, authenticated;
revoke all on function app_private.group_management_payload(uuid) from public, anon, authenticated;
revoke all on function app_private.superadmin_group_get(uuid) from public, anon, authenticated;
revoke all on function app_private.superadmin_group_directory(text,uuid[],uuid[],text[],text[],integer,integer,text,boolean) from public, anon, authenticated;
revoke all on function app_private.superadmin_group_save(uuid,uuid,bigint,jsonb) from public, anon, authenticated;
revoke all on function app_private.superadmin_group_export_create(uuid,jsonb) from public, anon, authenticated;
revoke all on function app_private.superadmin_import_payload(uuid) from public, anon, authenticated;
revoke all on function app_private.superadmin_import_create(uuid,jsonb) from public, anon, authenticated;
revoke all on function app_private.superadmin_import_start(uuid,uuid) from public, anon, authenticated;

revoke all on function public.superadmin_group_get(uuid) from public, anon, authenticated;
revoke all on function public.superadmin_group_directory(text,uuid[],uuid[],text[],text[],integer,integer,text,boolean) from public, anon, authenticated;
revoke all on function public.superadmin_group_save(uuid,uuid,bigint,jsonb) from public, anon, authenticated;
revoke all on function public.superadmin_group_export_create(uuid,jsonb) from public, anon, authenticated;
revoke all on function public.superadmin_import_create(uuid,jsonb) from public, anon, authenticated;
revoke all on function public.superadmin_import_start(uuid,uuid) from public, anon, authenticated;
grant execute on function public.superadmin_group_get(uuid) to authenticated;
grant execute on function public.superadmin_group_directory(text,uuid[],uuid[],text[],text[],integer,integer,text,boolean) to authenticated;
grant execute on function public.superadmin_group_save(uuid,uuid,bigint,jsonb) to authenticated;
grant execute on function public.superadmin_group_export_create(uuid,jsonb) to authenticated;
grant execute on function public.superadmin_import_create(uuid,jsonb) to authenticated;
grant execute on function public.superadmin_import_start(uuid,uuid) to authenticated;

commit;

-- Operational import/export files are private, short-lived backoffice artifacts.
-- Product media remains governed by the R2 Media Gateway decision.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'coelo-operations', 'coelo-operations', false, 5242880,
  array['text/csv','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

alter table public.import_jobs
  add column if not exists apply_request_id uuid,
  add column if not exists apply_request_hash bytea;
create unique index if not exists import_jobs_apply_request_uidx
  on public.import_jobs(apply_request_id) where apply_request_id is not null;
alter table public.import_files
  add column if not exists checksum_sha256 text,
  add column if not exists expires_at timestamptz not null default (now() + interval '24 hours');
create index if not exists import_files_expiry_idx on public.import_files(expires_at);
create unique index if not exists import_rows_job_row_uidx
  on public.import_rows(import_job_id, row_number);

create or replace function app_private.superadmin_group_import_apply(
  p_request_id uuid, p_import_job_id uuid, p_file jsonb, p_rows jsonb
) returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
declare
  actor_person_id uuid;
  job public.import_jobs%rowtype;
  source_row jsonb;
  row_index bigint;
  row_number_value integer;
  institution_value uuid;
  unit_value uuid;
  group_value uuid;
  unit_record public.units%rowtype;
  group_record public.groups%rowtype;
  strategy_value text;
  name_value text;
  type_value text;
  type_other_value text;
  status_value text;
  created_count integer := 0;
  updated_count integer := 0;
  ignored_count integer := 0;
  rejected_count integer := 0;
  final_state public.import_processing_state;
  apply_hash bytea;
begin
  if p_request_id is null or p_import_job_id is null
     or jsonb_typeof(p_file) <> 'object' or jsonb_typeof(p_rows) <> 'array' then
    raise invalid_parameter_value using message = 'invalid import payload';
  end if;
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null
     or not app_private.has_platform_permission('imports.manage')
     or not app_private.has_platform_permission('groups.manage') then
    raise insufficient_privilege using message = 'import and group management required';
  end if;
  if not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message = 'MFA AAL2 required';
  end if;
  if jsonb_array_length(p_rows) < 1 or jsonb_array_length(p_rows) > 5000 then
    raise invalid_parameter_value using message = 'row count outside allowed range';
  end if;
  if p_file - array['storage_path','file_name','mime_type','size_bytes','checksum_sha256'] <> '{}'::jsonb
     or length(coalesce(p_file ->> 'file_name', '')) > 180
     or coalesce((p_file ->> 'size_bytes')::bigint, 0) not between 1 and 5242880
     or p_file ->> 'mime_type' not in (
       'text/csv','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
     )
     or p_file ->> 'storage_path' not like 'imports/' || p_import_job_id::text || '/%'
     or p_file ->> 'checksum_sha256' !~ '^[0-9a-f]{64}$' then
    raise invalid_parameter_value using message = 'invalid import file metadata';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_import_job_id::text, 0));
  apply_hash := extensions.digest(
    convert_to(jsonb_build_object('file', p_file, 'rows', p_rows)::text, 'UTF8'), 'sha256'
  );
  select * into job from public.import_jobs where id = p_import_job_id for update;
  if job.id is null or job.target_table <> 'groups' or job.target_domain <> 'superadmin' then
    raise no_data_found using message = 'group import job not found';
  end if;
  if job.created_by <> actor_person_id then
    raise insufficient_privilege using message = 'import job outside actor scope';
  end if;
  if job.apply_request_id is not null then
    if job.apply_request_id <> p_request_id or job.apply_request_hash <> apply_hash then
      raise invalid_parameter_value using message = 'import already applied with another request';
    end if;
    return app_private.superadmin_import_payload(job.id);
  end if;
  if job.processing_state in ('SUCESSO','REJEICAO') then
    return app_private.superadmin_import_payload(job.id);
  end if;

  update public.import_jobs set
    apply_request_id = p_request_id,
    apply_request_hash = apply_hash,
    processing_state = 'PROCESSANDO',
    status = 'active',
    started_at = coalesce(started_at, now()),
    summary = summary || jsonb_build_object('progress', 1),
    updated_at = now()
  where id = job.id;
  delete from public.import_errors where import_job_id = job.id;
  delete from public.import_rows where import_job_id = job.id;
  strategy_value := coalesce(job.summary ->> 'strategy', 'createOnly');
  if strategy_value not in ('createOnly','createAndUpdate') then
    raise invalid_parameter_value using message = 'invalid import strategy';
  end if;

  for source_row, row_index in
    select item.value, item.ordinality
    from jsonb_array_elements(p_rows) with ordinality as item(value, ordinality)
  loop
    begin
      if jsonb_typeof(source_row) <> 'object'
         or source_row - array[
           'row_number','id','institution_id','unit_id','name','group_type',
           'group_type_other_text','status'
         ] <> '{}'::jsonb then
        raise invalid_parameter_value using message = 'unknown import column';
      end if;
      row_number_value := coalesce(nullif(source_row ->> 'row_number', '')::integer, row_index::integer + 1);
      if row_number_value < 2 then
        raise invalid_parameter_value using message = 'invalid row number';
      end if;
      institution_value := nullif(source_row ->> 'institution_id', '')::uuid;
      unit_value := nullif(source_row ->> 'unit_id', '')::uuid;
      group_value := nullif(source_row ->> 'id', '')::uuid;
      name_value := nullif(btrim(source_row ->> 'name'), '');
      type_value := lower(coalesce(nullif(btrim(source_row ->> 'group_type'), ''), 'class'));
      type_other_value := nullif(btrim(source_row ->> 'group_type_other_text'), '');
      status_value := lower(coalesce(nullif(btrim(source_row ->> 'status'), ''), 'active'));
      if institution_value is null or unit_value is null or name_value is null
         or length(name_value) > 160 or length(type_value) > 80
         or length(coalesce(type_other_value, '')) > 160
         or status_value not in ('draft','active','inactive','suspended','archived')
         or (type_value = 'other' and type_other_value is null) then
        raise invalid_parameter_value using message = 'invalid group fields';
      end if;
      select * into unit_record from public.units
      where id = unit_value and institution_id = institution_value;
      if unit_record.id is null then
        raise foreign_key_violation using message = 'unit outside institution';
      end if;

      if group_value is not null then
        select * into group_record from public.groups where id = group_value for update;
        if group_record.id is null then
          raise no_data_found using message = 'group not found';
        end if;
        if group_record.institution_id <> institution_value or group_record.unit_id <> unit_value then
          raise insufficient_privilege using message = 'group hierarchy cannot change';
        end if;
        if strategy_value = 'createOnly' then
          ignored_count := ignored_count + 1;
        else
          update public.groups set
            name = name_value,
            group_type = type_value,
            group_type_other_text = type_other_value,
            status = status_value::public.record_status,
            management_version = management_version + 1,
            updated_at = now()
          where id = group_record.id;
          updated_count := updated_count + 1;
        end if;
      else
        insert into public.groups(
          institution_id, unit_id, name, group_type, group_type_other_text, status,
          inherit_appearance, inherit_access, inherit_activities, created_at, updated_at
        ) values (
          institution_value, unit_value, name_value, type_value, type_other_value,
          status_value::public.record_status, true, true, true, now(), now()
        ) returning id into group_value;
        created_count := created_count + 1;
      end if;
      insert into public.import_rows(import_job_id, row_number, payload_json, status)
      values (job.id, row_number_value, source_row, 'active');
    exception when others then
      rejected_count := rejected_count + 1;
      insert into public.import_rows(import_job_id, row_number, payload_json, status, error_code)
      values (
        job.id, coalesce(row_number_value, row_index::integer + 1), source_row,
        'inactive', sqlstate
      ) on conflict (import_job_id, row_number) do update set
        payload_json = excluded.payload_json, status = excluded.status, error_code = excluded.error_code;
      insert into public.import_errors(
        import_job_id, row_number, column_name, error_code, message
      ) values (
        job.id, coalesce(row_number_value, row_index::integer + 1), null,
        sqlstate, 'Linha rejeitada pela validacao do backend.'
      );
    end;
    row_number_value := null;
  end loop;

  final_state := case when rejected_count > 0 then 'REJEICAO'::public.import_processing_state
                      else 'SUCESSO'::public.import_processing_state end;
  insert into public.import_files(
    import_job_id, storage_path, file_name, mime_type, size_bytes,
    checksum_sha256, source_locale, expires_at
  ) values (
    job.id, p_file ->> 'storage_path', p_file ->> 'file_name', p_file ->> 'mime_type',
    (p_file ->> 'size_bytes')::bigint, p_file ->> 'checksum_sha256', job.source_locale,
    now() + interval '24 hours'
  );
  update public.import_results set
    created_count = created_count,
    updated_count = updated_count,
    ignored_count = ignored_count,
    rejected_count = rejected_count,
    completed_at = now()
  where import_job_id = job.id;
  update public.import_jobs set
    processing_state = final_state,
    finished_at = now(),
    summary = summary || jsonb_build_object(
      'progress', 100, 'row_count', jsonb_array_length(p_rows),
      'storage_path', p_file ->> 'storage_path', 'expires_at', now() + interval '24 hours'
    ),
    updated_at = now()
  where id = job.id;
  update app_private.import_processing_queue set
    state = final_state, locked_at = null, locked_by = null, updated_at = now()
  where import_job_id = job.id;
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor_person_id, auth.jwt() ->> 'aal', 'group.import.complete', 'import_job', job.id,
    job.institution_id, 'success', jsonb_build_object(
      'state', final_state, 'created', created_count, 'updated', updated_count,
      'ignored', ignored_count, 'rejected', rejected_count
    )
  );
  return app_private.superadmin_import_payload(job.id);
end $$;

create or replace function app_private.superadmin_group_export_prepare(p_import_job_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
declare
  actor_person_id uuid;
  job public.import_jobs%rowtype;
  filters jsonb;
  institution_ids uuid[];
  unit_ids uuid[];
  type_ids text[];
  statuses text[];
  result jsonb;
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null or not app_private.has_platform_permission('groups.export') then
    raise insufficient_privilege using message = 'groups.export required';
  end if;
  if not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message = 'MFA AAL2 required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_import_job_id::text, 0));
  select * into job from public.import_jobs where id = p_import_job_id for update;
  if job.id is null or job.target_domain <> 'groups_export' or job.target_table <> 'groups' then
    raise no_data_found using message = 'group export job not found';
  end if;
  if job.created_by <> actor_person_id then
    raise insufficient_privilege using message = 'export job outside actor scope';
  end if;
  filters := coalesce(job.summary -> 'filters', '{}'::jsonb);
  select coalesce(array_agg(value::uuid), '{}'::uuid[]) into institution_ids
    from jsonb_array_elements_text(coalesce(filters -> 'institution_ids', '[]'::jsonb));
  select coalesce(array_agg(value::uuid), '{}'::uuid[]) into unit_ids
    from jsonb_array_elements_text(coalesce(filters -> 'unit_ids', '[]'::jsonb));
  select coalesce(array_agg(value), '{}'::text[]) into type_ids
    from jsonb_array_elements_text(coalesce(filters -> 'type_ids', '[]'::jsonb));
  select coalesce(array_agg(value), '{}'::text[]) into statuses
    from jsonb_array_elements_text(coalesce(filters -> 'statuses', '[]'::jsonb));

  select jsonb_build_object(
    'job_id', job.id,
    'format', job.source_format,
    'rows', coalesce(jsonb_agg(jsonb_build_object(
      'id', group_record.id,
      'institution_id', group_record.institution_id,
      'institution_name', institution_record.public_name,
      'unit_id', group_record.unit_id,
      'unit_name', unit_record.name,
      'name', group_record.name,
      'group_type', group_record.group_type,
      'group_type_other_text', group_record.group_type_other_text,
      'status', group_record.status
    ) order by group_record.name, group_record.id), '[]'::jsonb)
  ) into result
  from public.groups group_record
  join public.institutions institution_record on institution_record.id = group_record.institution_id
  join public.units unit_record on unit_record.id = group_record.unit_id
    and unit_record.institution_id = group_record.institution_id
  where (
    nullif(btrim(filters ->> 'search'), '') is null
    or group_record.name ilike '%' || replace(replace(replace(
      btrim(filters ->> 'search'), '\', '\\'), '%', '\%'), '_', '\_') || '%' escape '\'
  )
    and (cardinality(institution_ids) = 0 or group_record.institution_id = any(institution_ids))
    and (cardinality(unit_ids) = 0 or group_record.unit_id = any(unit_ids))
    and (cardinality(type_ids) = 0 or group_record.group_type = any(type_ids))
    and (cardinality(statuses) = 0 or group_record.status::text = any(statuses));
  if jsonb_array_length(result -> 'rows') > 50000 then
    raise program_limit_exceeded using message = 'export exceeds row limit';
  end if;
  update public.import_jobs set
    processing_state = 'PROCESSANDO', started_at = coalesce(started_at, now()),
    summary = summary || jsonb_build_object('progress', 50), updated_at = now()
  where id = job.id;
  update app_private.import_processing_queue set
    state = 'PROCESSANDO', attempts = attempts + 1, locked_at = now(),
    locked_by = 'group-files', updated_at = now()
  where import_job_id = job.id;
  return result;
end $$;

create or replace function app_private.superadmin_group_export_complete(
  p_import_job_id uuid, p_storage_path text, p_file_name text, p_mime_type text,
  p_size_bytes bigint, p_checksum_sha256 text, p_row_count integer
) returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
declare job public.import_jobs%rowtype;
begin
  if p_import_job_id is null or p_storage_path not like 'exports/' || p_import_job_id::text || '/%'
     or nullif(btrim(p_file_name), '') is null or length(p_file_name) > 180
     or p_mime_type not in (
       'text/csv','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
     )
     or p_size_bytes not between 1 and 5242880
     or p_checksum_sha256 !~ '^[0-9a-f]{64}$'
     or p_row_count < 0 or p_row_count > 50000 then
    raise invalid_parameter_value using message = 'invalid export result';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_import_job_id::text, 0));
  select * into job from public.import_jobs where id = p_import_job_id for update;
  if job.id is null or job.target_domain <> 'groups_export' then
    raise no_data_found using message = 'group export job not found';
  end if;
  if job.processing_state = 'SUCESSO' then
    return app_private.superadmin_import_payload(job.id);
  end if;
  insert into public.import_files(
    import_job_id, storage_path, file_name, mime_type, size_bytes,
    checksum_sha256, source_locale, expires_at
  ) values (
    job.id, p_storage_path, p_file_name, p_mime_type, p_size_bytes,
    p_checksum_sha256, 'pt-BR', now() + interval '24 hours'
  );
  update public.import_results set
    created_count = p_row_count, completed_at = now()
  where import_job_id = job.id;
  update public.import_jobs set
    processing_state = 'SUCESSO', finished_at = now(),
    summary = summary || jsonb_build_object(
      'progress', 100, 'row_count', p_row_count,
      'storage_path', p_storage_path, 'expires_at', now() + interval '24 hours'
    ), updated_at = now()
  where id = job.id;
  update app_private.import_processing_queue set
    state = 'SUCESSO', locked_at = null, locked_by = null, updated_at = now()
  where import_job_id = job.id;
  insert into audit.audit_logs(
    actor_person_id, action_code, object_type, object_id, outcome, after_json
  ) values (
    job.created_by, 'group.export.complete', 'import_job', job.id, 'success',
    jsonb_build_object('rows', p_row_count, 'state', 'SUCESSO')
  );
  return app_private.superadmin_import_payload(job.id);
end $$;

create or replace function app_private.superadmin_file_job_fail(
  p_import_job_id uuid, p_error_code text
) returns void language plpgsql volatile security definer set search_path = ''
as $$
declare job public.import_jobs%rowtype;
begin
  select * into job from public.import_jobs where id = p_import_job_id for update;
  if job.id is null then return; end if;
  update public.import_jobs set
    processing_state = 'ERRO', finished_at = now(),
    summary = summary || jsonb_build_object('progress', 100, 'error_code', left(p_error_code, 80)),
    updated_at = now()
  where id = job.id and processing_state not in ('SUCESSO','REJEICAO');
  update app_private.import_processing_queue set
    state = 'ERRO', last_error_code = left(p_error_code, 80),
    locked_at = null, locked_by = null, updated_at = now()
  where import_job_id = job.id and state not in ('SUCESSO','REJEICAO');
  insert into audit.audit_logs(
    actor_person_id, action_code, object_type, object_id, outcome, error_code
  ) values (job.created_by, 'file.job.fail', 'import_job', job.id, 'failure', left(p_error_code, 80));
end $$;

create or replace function public.superadmin_group_import_apply(
  p_request_id uuid, p_import_job_id uuid, p_file jsonb, p_rows jsonb
) returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_group_import_apply(p_request_id,p_import_job_id,p_file,p_rows) $$;
create or replace function public.superadmin_group_export_prepare(p_import_job_id uuid)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_group_export_prepare(p_import_job_id) $$;
create or replace function public.superadmin_group_export_complete(
  p_import_job_id uuid, p_storage_path text, p_file_name text, p_mime_type text,
  p_size_bytes bigint, p_checksum_sha256 text, p_row_count integer
) returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_group_export_complete(
  p_import_job_id,p_storage_path,p_file_name,p_mime_type,
  p_size_bytes,p_checksum_sha256,p_row_count
) $$;
create or replace function public.superadmin_file_job_fail(
  p_import_job_id uuid, p_error_code text
) returns void language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_file_job_fail(p_import_job_id,p_error_code) $$;

revoke all on function app_private.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)
  from public, anon, authenticated;
revoke all on function app_private.superadmin_group_export_prepare(uuid)
  from public, anon, authenticated;
revoke all on function app_private.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)
  from public, anon, authenticated;
revoke all on function app_private.superadmin_file_job_fail(uuid,text)
  from public, anon, authenticated;
revoke all on function public.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.superadmin_group_export_prepare(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)
  from public, anon, authenticated, service_role;
revoke all on function public.superadmin_file_job_fail(uuid,text)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)
  to authenticated;
grant execute on function public.superadmin_group_export_prepare(uuid)
  to authenticated;
grant execute on function public.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)
  to service_role;
grant execute on function public.superadmin_file_job_fail(uuid,text)
  to service_role;
