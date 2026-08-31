begin;

do $$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using
      message = 'activities v2 actor attribution migration must run as postgres';
  end if;
  if to_regprocedure('app_private.current_person_id()') is null
     or to_regprocedure('app_private.require_superadmin_internal_context(text)') is null then
    raise exception using
      errcode = '55000',
      message = 'activities v2 actor attribution dependencies are unavailable';
  end if;
end $$;

alter table public.activity_definitions
  alter column created_by_person_id drop not null,
  add column created_by_actor_kind text generated always as
    (case when created_by_person_id is null then 'superadmin_internal' else 'person' end) stored;

alter table public.activity_unit_links
  alter column linked_by_person_id drop not null,
  add column linked_by_actor_kind text generated always as
    (case when linked_by_person_id is null then 'superadmin_internal' else 'person' end) stored;

alter table public.activity_group_links
  alter column linked_by_person_id drop not null,
  add column linked_by_actor_kind text generated always as
    (case when linked_by_person_id is null then 'superadmin_internal' else 'person' end) stored;

alter table public.activity_group_participants
  alter column added_by_person_id drop not null,
  add column added_by_actor_kind text generated always as
    (case when added_by_person_id is null then 'superadmin_internal' else 'person' end) stored;

alter table public.activity_group_assignments
  alter column assigned_by_person_id drop not null,
  add column assigned_by_actor_kind text generated always as
    (case when assigned_by_person_id is null then 'superadmin_internal' else 'person' end) stored;

alter table public.activity_admin_assignments
  alter column assigned_by_person_id drop not null,
  add column assigned_by_actor_kind text generated always as
    (case when assigned_by_person_id is null then 'superadmin_internal' else 'person' end) stored;

alter table public.activity_assignment_capability_actions
  alter column changed_by_person_id drop not null,
  add column changed_by_actor_kind text generated always as
    (case when changed_by_person_id is null then 'superadmin_internal' else 'person' end) stored;

alter table public.activity_capability_policies
  alter column changed_by_person_id drop not null,
  add column changed_by_actor_kind text generated always as
    (case when changed_by_person_id is null then 'superadmin_internal' else 'person' end) stored;

alter table public.activity_group_capability_settings
  alter column changed_by_person_id drop not null,
  add column changed_by_actor_kind text generated always as
    (case when changed_by_person_id is null then 'superadmin_internal' else 'person' end) stored;

create index activity_assignment_capability_actions_changed_by_person_idx
  on public.activity_assignment_capability_actions(changed_by_person_id);
create index activity_admin_assignments_assigned_by_person_idx
  on public.activity_admin_assignments(assigned_by_person_id);

create function app_private.require_activity_v2_internal_marker()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  marker jsonb;
  context_record app_private.superadmin_internal_context;
begin
  begin
    marker := current_setting('app_private.activity_v2_internal_marker', true)::jsonb;
  exception when others then
    raise insufficient_privilege using message = 'activity internal marker denied';
  end;

  if marker is null or jsonb_typeof(marker) <> 'object' then
    raise insufficient_privilege using message = 'activity internal marker denied';
  end if;

  select * into strict context_record
  from app_private.require_superadmin_internal_context('activities.create');

  if not exists (
    select 1
    from auth.sessions session_record
    where session_record.id = context_record.session_id
      and session_record.user_id = context_record.auth_user_id
      and (session_record.not_after is null or session_record.not_after > now())
  ) then
    raise insufficient_privilege using message = 'activity internal marker denied';
  end if;

  if marker ->> 'internal_identity_id' is distinct from context_record.internal_identity_id::text
     or marker ->> 'internal_auth_link_id' is distinct from context_record.internal_auth_link_id::text
     or marker ->> 'internal_membership_id' is distinct from context_record.internal_membership_id::text
     or marker ->> 'auth_user_id' is distinct from context_record.auth_user_id::text
     or marker ->> 'session_id' is distinct from context_record.session_id::text then
    raise insufficient_privilege using message = 'activity internal marker denied';
  end if;
end;
$$;

create function app_private.guard_activity_v2_actor_provenance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_column text := tg_argv[0];
  actor_person_id uuid;
  resolved_person_id uuid;
begin
  actor_person_id := (to_jsonb(new) ->> actor_column)::uuid;
  if actor_person_id is null then
    perform app_private.require_activity_v2_internal_marker();
  else
    resolved_person_id := app_private.current_person_id();
    if resolved_person_id is null or actor_person_id <> resolved_person_id then
      raise insufficient_privilege using message = 'activity actor provenance denied';
    end if;
  end if;
  return new;
end;
$$;

create function app_private.prevent_activity_v2_group_activity_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.assignment_role <> 'activity_admin' then
    return new;
  end if;

  if tg_op = 'INSERT'
     or old.assignment_role is distinct from 'activity_admin'
     or new.activity_group_link_id is distinct from old.activity_group_link_id
     or new.institution_id is distinct from old.institution_id
     or new.person_id is distinct from old.person_id
     or new.membership_id is distinct from old.membership_id
     or new.assigned_at is distinct from old.assigned_at
     or new.status not in ('inactive', 'suspended', 'archived')
     or new.revoked_at is null then
    raise check_violation using
      message = 'activity_admin assignments are activity-scoped only';
  end if;
  return new;
end;
$$;

alter function app_private.require_activity_v2_internal_marker() owner to postgres;
alter function app_private.guard_activity_v2_actor_provenance() owner to postgres;
alter function app_private.prevent_activity_v2_group_activity_admin() owner to postgres;
revoke all on function app_private.require_activity_v2_internal_marker() from public, anon, authenticated, service_role;
revoke all on function app_private.guard_activity_v2_actor_provenance() from public, anon, authenticated, service_role;
revoke all on function app_private.prevent_activity_v2_group_activity_admin() from public, anon, authenticated, service_role;

create trigger activity_definitions_actor_provenance_guard
before insert or update on public.activity_definitions
for each row execute function app_private.guard_activity_v2_actor_provenance('created_by_person_id');
create trigger activity_unit_links_actor_provenance_guard
before insert or update on public.activity_unit_links
for each row execute function app_private.guard_activity_v2_actor_provenance('linked_by_person_id');
create trigger activity_group_links_actor_provenance_guard
before insert or update on public.activity_group_links
for each row execute function app_private.guard_activity_v2_actor_provenance('linked_by_person_id');
create trigger activity_group_participants_actor_provenance_guard
before insert or update on public.activity_group_participants
for each row execute function app_private.guard_activity_v2_actor_provenance('added_by_person_id');
create trigger activity_group_assignments_actor_provenance_guard
before insert or update on public.activity_group_assignments
for each row execute function app_private.guard_activity_v2_actor_provenance('assigned_by_person_id');
create trigger activity_group_assignments_activity_admin_guard
before insert or update on public.activity_group_assignments
for each row execute function app_private.prevent_activity_v2_group_activity_admin();
create trigger activity_admin_assignments_actor_provenance_guard
before insert or update on public.activity_admin_assignments
for each row execute function app_private.guard_activity_v2_actor_provenance('assigned_by_person_id');
create trigger activity_assignment_capability_actions_actor_provenance_guard
before insert or update on public.activity_assignment_capability_actions
for each row execute function app_private.guard_activity_v2_actor_provenance('changed_by_person_id');
create trigger activity_capability_policies_actor_provenance_guard
before insert or update on public.activity_capability_policies
for each row execute function app_private.guard_activity_v2_actor_provenance('changed_by_person_id');
create trigger activity_group_capability_settings_actor_provenance_guard
before insert or update on public.activity_group_capability_settings
for each row execute function app_private.guard_activity_v2_actor_provenance('changed_by_person_id');

commit;
