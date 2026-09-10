-- Contextual authorization core.
-- Canonical authorization: active membership + role assignments/permissions
-- + direct grants + individual overrides. Legacy membership role/scope columns
-- remain compatibility metadata and are not authoritative.

alter table public.groups
  alter column unit_id set not null;

insert into public.institution_permissions(
  code, module_code, screen_code, action_code, description, risk_level
)
values
  ('people.read', 'people', 'people', 'read',
   'Visualizar pessoas dentro do escopo contextual.', 'normal'),
  ('people.manage', 'people', 'people', 'manage',
   'Gerenciar pessoas dentro do escopo contextual.', 'high'),
  ('people.assign_children', 'people', 'people', 'assign_children',
   'Atribuir profissionais a criancas especificas.', 'high'),
  ('permissions.manage', 'authorization', 'permissions', 'manage',
   'Gerenciar papeis, grants e overrides contextuais.', 'critical'),
  ('family.read', 'family', 'family', 'read',
   'Visualizar vinculos familiares autorizados.', 'high'),
  ('family.manage', 'family', 'family', 'manage',
   'Gerenciar responsaveis e suas permissoes.', 'critical'),
  ('authorized_people.manage', 'family', 'authorized_people', 'manage',
   'Gerenciar pessoas autorizadas para criancas.', 'critical'),
  ('transfers.manage', 'people', 'transfers', 'manage',
   'Solicitar e decidir transferencias entre unidades.', 'critical'),
  ('chat.read', 'chat', 'chat', 'read',
   'Ler conversas dentro do escopo contextual.', 'high'),
  ('chat.manage', 'chat', 'chat', 'manage',
   'Configurar canais, equipes e participantes.', 'critical'),
  ('attendance.read', 'attendance', 'attendance', 'read',
   'Visualizar presenca e assiduidade no escopo.', 'high'),
  ('attendance.manage', 'attendance', 'attendance', 'manage',
   'Confirmar ou corrigir registros oficiais de presenca.', 'critical')
on conflict (code) do update set
  module_code = excluded.module_code,
  screen_code = excluded.screen_code,
  action_code = excluded.action_code,
  description = excluded.description,
  risk_level = excluded.risk_level,
  status = 'active',
  updated_at = now();

create table public.institution_member_permission_overrides (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null
    references public.institution_memberships(id) on delete cascade,
  permission_code text not null
    references public.institution_permissions(code) on update cascade on delete restrict,
  effect public.permission_effect not null,
  scope_kind text not null
    check (scope_kind in ('institution', 'unit', 'group', 'activity', 'child')),
  scope_id uuid,
  reason text not null check (btrim(reason) <> ''),
  starts_at timestamptz,
  expires_at timestamptz,
  status public.record_status not null default 'active',
  changed_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint institution_member_permission_overrides_scope_check check (
    (scope_kind = 'institution' and scope_id is null)
    or (scope_kind <> 'institution' and scope_id is not null)
  ),
  constraint institution_member_permission_overrides_dates_check check (
    expires_at is null or starts_at is null or expires_at > starts_at
  )
);

create unique index institution_member_permission_overrides_active_uidx
  on public.institution_member_permission_overrides(
    membership_id, permission_code, effect, scope_kind,
    coalesce(scope_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where status = 'active' and revoked_at is null;
create index institution_member_permission_overrides_membership_idx
  on public.institution_member_permission_overrides(membership_id, status);
create index institution_member_permission_overrides_scope_idx
  on public.institution_member_permission_overrides(scope_kind, scope_id)
  where status = 'active' and revoked_at is null;

create table public.professional_child_assignments (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null
    references public.institution_memberships(id) on delete cascade,
  child_context_id uuid not null
    references public.child_contexts(id) on delete cascade,
  assignment_role text,
  assigned_by_person_id uuid not null references public.people(id) on delete restrict,
  starts_at timestamptz,
  expires_at timestamptz,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint professional_child_assignments_role_check
    check (assignment_role is null or btrim(assignment_role) <> ''),
  constraint professional_child_assignments_dates_check
    check (expires_at is null or starts_at is null or expires_at > starts_at)
);

create unique index professional_child_assignments_active_uidx
  on public.professional_child_assignments(membership_id, child_context_id)
  where status = 'active' and revoked_at is null;
create index professional_child_assignments_child_idx
  on public.professional_child_assignments(child_context_id, status);

create or replace function app_private.validate_contextual_authorization_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  membership_institution_id uuid;
  target_institution_id uuid;
begin
  select membership.institution_id
    into membership_institution_id
  from public.institution_memberships membership
  where membership.id = new.membership_id;

  if membership_institution_id is null then
    raise exception 'membership does not exist';
  end if;

  if tg_table_name = 'professional_child_assignments' then
    select child_context.institution_id
      into target_institution_id
    from public.child_contexts child_context
    where child_context.id = new.child_context_id;
  elsif new.scope_kind = 'institution' then
    target_institution_id := membership_institution_id;
  elsif new.scope_kind = 'unit' then
    select unit_record.institution_id into target_institution_id
    from public.units unit_record where unit_record.id = new.scope_id;
  elsif new.scope_kind = 'group' then
    select group_record.institution_id into target_institution_id
    from public.groups group_record where group_record.id = new.scope_id;
  elsif new.scope_kind = 'activity' then
    select activity.institution_id into target_institution_id
    from public.activity_definitions activity where activity.id = new.scope_id;
  elsif new.scope_kind = 'child' then
    select child_context.institution_id into target_institution_id
    from public.child_contexts child_context where child_context.id = new.scope_id;
  end if;

  if target_institution_id is null
     or target_institution_id <> membership_institution_id then
    raise exception 'context must belong to membership institution';
  end if;

  return new;
end
$$;

create trigger institution_member_permission_overrides_validate
before insert or update on public.institution_member_permission_overrides
for each row execute function app_private.validate_contextual_authorization_row();

create trigger professional_child_assignments_validate
before insert or update on public.professional_child_assignments
for each row execute function app_private.validate_contextual_authorization_row();

create or replace function app_private.has_context_permission(
  target_institution_id uuid,
  target_permission_code text,
  target_unit_id uuid default null,
  target_group_id uuid default null,
  target_activity_id uuid default null,
  target_child_context_id uuid default null,
  require_institution_scope boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with active_memberships as (
    select membership.id
    from public.institution_memberships membership
    where membership.person_id = app_private.current_person_id()
      and membership.institution_id = target_institution_id
      and membership.status = 'active'
      and membership.revoked_at is null
  ),
  role_effects as (
    select role_permission.effect
    from active_memberships membership
    join public.institution_role_assignments assignment
      on assignment.membership_id = membership.id
     and assignment.status = 'active'
     and (assignment.starts_at is null or assignment.starts_at <= pg_catalog.now())
     and (assignment.expires_at is null or assignment.expires_at > pg_catalog.now())
    join public.institution_roles role_record
      on role_record.id = assignment.role_id
     and role_record.status = 'active'
     and (role_record.institution_id is null
          or role_record.institution_id = target_institution_id)
    join public.institution_role_permissions role_permission
      on role_permission.role_id = role_record.id
     and role_permission.status = 'active'
     and role_permission.revoked_at is null
    join public.institution_permissions permission_record
      on permission_record.id = role_permission.permission_id
     and permission_record.code = target_permission_code
     and permission_record.status = 'active'
    where
      (require_institution_scope and assignment.scope_kind = 'institution')
      or (
        not require_institution_scope and (
          assignment.scope_kind = 'institution'
          or (assignment.scope_kind = 'unit'
              and target_unit_id = assignment.scope_unit_id)
          or (assignment.scope_kind = 'group'
              and target_group_id = assignment.scope_group_id
              and (target_unit_id is null
                   or target_unit_id = assignment.scope_unit_id))
        )
      )
  ),
  direct_allows as (
    select 1
    from active_memberships membership
    join public.institution_role_grants grant_record
      on grant_record.membership_id = membership.id
     and grant_record.permission_code = target_permission_code
     and grant_record.status = 'active'
     and (grant_record.starts_at is null or grant_record.starts_at <= pg_catalog.now())
     and (grant_record.expires_at is null or grant_record.expires_at > pg_catalog.now())
    where
      (require_institution_scope and grant_record.scope_kind = 'institution')
      or (
        not require_institution_scope and (
          grant_record.scope_kind = 'institution'
          or (grant_record.scope_kind = 'unit' and grant_record.scope_id = target_unit_id)
          or (grant_record.scope_kind = 'group' and grant_record.scope_id = target_group_id)
        )
      )
  ),
  individual_effects as (
    select override_record.effect
    from active_memberships membership
    join public.institution_member_permission_overrides override_record
      on override_record.membership_id = membership.id
     and override_record.permission_code = target_permission_code
     and override_record.status = 'active'
     and override_record.revoked_at is null
     and (override_record.starts_at is null
          or override_record.starts_at <= pg_catalog.now())
     and (override_record.expires_at is null
          or override_record.expires_at > pg_catalog.now())
    where
      (require_institution_scope and override_record.scope_kind = 'institution')
      or (
        not require_institution_scope and (
          override_record.scope_kind = 'institution'
          or (override_record.scope_kind = 'unit'
              and override_record.scope_id = target_unit_id)
          or (override_record.scope_kind = 'group'
              and override_record.scope_id = target_group_id)
          or (override_record.scope_kind = 'activity'
              and override_record.scope_id = target_activity_id)
          or (override_record.scope_kind = 'child'
              and override_record.scope_id = target_child_context_id)
        )
      )
  )
  select
    not exists (select 1 from individual_effects where effect = 'deny')
    and not exists (select 1 from role_effects where effect = 'deny')
    and (
      exists (select 1 from individual_effects where effect = 'allow')
      or exists (select 1 from role_effects where effect = 'allow')
      or exists (select 1 from direct_allows)
    )
$$;

create or replace function app_private.has_institution_permission(
  target_institution_id uuid,
  target_permission_code text,
  target_unit_id uuid default null,
  target_group_id uuid default null,
  require_institution_scope boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app_private.has_context_permission(
    target_institution_id,
    target_permission_code,
    target_unit_id,
    target_group_id,
    null,
    null,
    require_institution_scope
  )
$$;

create or replace function app_private.audit_contextual_sensitive_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_json jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  target_institution_id uuid;
begin
  select membership.institution_id into target_institution_id
  from public.institution_memberships membership
  where membership.id = (row_json ->> 'membership_id')::uuid;

  insert into audit.audit_logs(
    actor_person_id, action_code, object_type, object_id, institution_id,
    before_json, after_json
  ) values (
    app_private.current_person_id(),
    lower(tg_table_name || '.' || tg_op),
    tg_table_name,
    (row_json ->> 'id')::uuid,
    target_institution_id,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end
  );
  return coalesce(new, old);
end
$$;

create trigger institution_member_permission_overrides_audit
after insert or update or delete on public.institution_member_permission_overrides
for each row execute function app_private.audit_contextual_sensitive_change();
create trigger professional_child_assignments_audit
after insert or update or delete on public.professional_child_assignments
for each row execute function app_private.audit_contextual_sensitive_change();

alter table public.institution_member_permission_overrides enable row level security;
alter table public.professional_child_assignments enable row level security;

revoke all on public.institution_member_permission_overrides from public, anon, authenticated;
revoke all on public.professional_child_assignments from public, anon, authenticated;
grant select, insert, update on public.institution_member_permission_overrides to authenticated;
grant select, insert, update on public.professional_child_assignments to authenticated;
grant all on public.institution_member_permission_overrides to service_role;
grant all on public.professional_child_assignments to service_role;

create policy institution_member_permission_overrides_read
on public.institution_member_permission_overrides for select to authenticated
using (
  exists (
    select 1 from public.institution_memberships membership
    where membership.id = membership_id
      and (
        membership.person_id = app_private.current_person_id()
        or app_private.has_context_permission(
          membership.institution_id, 'permissions.manage',
          null, null, null, null, true
        )
      )
  )
);
create policy institution_member_permission_overrides_insert
on public.institution_member_permission_overrides for insert to authenticated
with check (
  exists (
    select 1 from public.institution_memberships membership
    where membership.id = membership_id
      and app_private.has_context_permission(
        membership.institution_id, 'permissions.manage',
        null, null, null, null, true
      )
  )
);
create policy institution_member_permission_overrides_update
on public.institution_member_permission_overrides for update to authenticated
using (
  exists (
    select 1 from public.institution_memberships membership
    where membership.id = membership_id
      and app_private.has_context_permission(
        membership.institution_id, 'permissions.manage',
        null, null, null, null, true
      )
  )
)
with check (
  exists (
    select 1 from public.institution_memberships membership
    where membership.id = membership_id
      and app_private.has_context_permission(
        membership.institution_id, 'permissions.manage',
        null, null, null, null, true
      )
  )
);

create policy professional_child_assignments_read
on public.professional_child_assignments for select to authenticated
using (
  exists (
    select 1
    from public.institution_memberships membership
    join public.child_contexts child_context
      on child_context.id = child_context_id
     and child_context.institution_id = membership.institution_id
    where membership.id = membership_id
      and (
        membership.person_id = app_private.current_person_id()
        or app_private.has_context_permission(
          membership.institution_id, 'people.read',
          null, null, null, child_context.id, false
        )
      )
  )
);
create policy professional_child_assignments_insert
on public.professional_child_assignments for insert to authenticated
with check (
  exists (
    select 1
    from public.institution_memberships membership
    join public.child_contexts child_context
      on child_context.id = child_context_id
     and child_context.institution_id = membership.institution_id
    where membership.id = membership_id
      and app_private.has_context_permission(
        membership.institution_id, 'people.assign_children',
        null, null, null, child_context.id, false
      )
  )
);
create policy professional_child_assignments_update
on public.professional_child_assignments for update to authenticated
using (
  exists (
    select 1
    from public.institution_memberships membership
    where membership.id = membership_id
      and app_private.has_context_permission(
        membership.institution_id, 'people.assign_children',
        null, null, null, child_context_id, false
      )
  )
)
with check (
  exists (
    select 1
    from public.institution_memberships membership
    where membership.id = membership_id
      and app_private.has_context_permission(
        membership.institution_id, 'people.assign_children',
        null, null, null, child_context_id, false
      )
  )
);

revoke all on function app_private.has_context_permission(
  uuid, text, uuid, uuid, uuid, uuid, boolean
) from public, anon;
grant execute on function app_private.has_context_permission(
  uuid, text, uuid, uuid, uuid, uuid, boolean
) to authenticated, service_role;
revoke all on function app_private.validate_contextual_authorization_row()
  from public, anon, authenticated;
revoke all on function app_private.audit_contextual_sensitive_change()
  from public, anon, authenticated;

with table_catalog(table_name, table_label, table_description, domain) as (
  values
    ('institution_member_permission_overrides', 'Overrides individuais',
     'Allow ou deny individual por permissao e contexto.', 'authorization'),
    ('professional_child_assignments', 'Profissionais por crianca',
     'Atribuicao profissional explicita a uma crianca institucional.', 'authorization')
)
insert into public.schema_tables(
  schema_name, table_name, table_label, table_description, domain,
  status, version, updated_at
)
select 'public', table_name, table_label, table_description, domain,
       'active', 1, now()
from table_catalog
on conflict (schema_name, table_name, version) do update set
  table_label = excluded.table_label,
  table_description = excluded.table_description,
  domain = excluded.domain,
  status = excluded.status,
  updated_at = now();

insert into public.schema_columns(
  schema_table_id, column_name, column_label, column_description, column_type,
  is_required, is_nullable, is_unique, is_filterable, is_importable,
  is_active, position, allowed_locales_json, aliases_json, examples_json,
  updated_at
)
select schema_table.id, column_info.column_name,
       replace(column_info.column_name, '_', ' '),
       'Campo contextual ' || column_info.column_name || '.',
       column_info.data_type,
       column_info.is_nullable = 'NO',
       column_info.is_nullable = 'YES',
       false,
       column_info.column_name in (
         'membership_id', 'permission_code', 'scope_kind', 'scope_id',
         'child_context_id', 'status'
       ),
       false, true, column_info.ordinal_position,
       '["pt-BR"]'::jsonb, '{}'::jsonb, '[]'::jsonb, now()
from information_schema.columns column_info
join public.schema_tables schema_table
  on schema_table.schema_name = column_info.table_schema
 and schema_table.table_name = column_info.table_name
 and schema_table.version = 1
where column_info.table_schema = 'public'
  and column_info.table_name in (
    'institution_member_permission_overrides',
    'professional_child_assignments'
  )
on conflict (schema_table_id, column_name) do update set
  column_type = excluded.column_type,
  is_required = excluded.is_required,
  is_nullable = excluded.is_nullable,
  is_filterable = excluded.is_filterable,
  is_active = true,
  position = excluded.position,
  updated_at = now();
