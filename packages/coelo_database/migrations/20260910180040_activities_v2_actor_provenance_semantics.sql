begin;

create or replace function app_private.require_activity_v2_internal_marker()
returns void language plpgsql security definer set search_path='' as $$
declare
  marker jsonb;
  permission_code text;
  action_code text;
  context_record app_private.superadmin_internal_context;
begin
  begin
    marker:=current_setting('app_private.activity_v2_internal_marker',true)::jsonb;
  exception when others then
    raise insufficient_privilege using message='activity internal marker denied';
  end;

  permission_code:=marker->>'permission_code';
  action_code:=marker->>'action_code';
  if marker is null or jsonb_typeof(marker)<>'object'
     or permission_code is null or btrim(permission_code)=''
     or action_code is null or btrim(action_code)=''
     or permission_code not in(
       'activities.create','activities.manage','activities.link_units',
       'activities.link_groups','activities.assign_people','activities.manage_permissions')
     or (permission_code,action_code) not in(
       ('activities.create','create'),('activities.manage','manage'),
       ('activities.link_units','link_units'),('activities.link_groups','link_groups'),
       ('activities.assign_people','assign_people'),
       ('activities.manage_permissions','manage_permissions')) then
    raise insufficient_privilege using message='activity internal marker denied';
  end if;

  select * into strict context_record
  from app_private.require_superadmin_internal_context(permission_code);
  if not exists(
       select 1 from auth.sessions s
       where s.id=context_record.session_id and s.user_id=context_record.auth_user_id
         and (s.not_after is null or s.not_after>now()))
     or marker->>'internal_identity_id' is distinct from context_record.internal_identity_id::text
     or marker->>'internal_auth_link_id' is distinct from context_record.internal_auth_link_id::text
     or marker->>'internal_membership_id' is distinct from context_record.internal_membership_id::text
     or marker->>'auth_user_id' is distinct from context_record.auth_user_id::text
     or marker->>'session_id' is distinct from context_record.session_id::text then
    raise insufficient_privilege using message='activity internal marker denied';
  end if;
end $$;

create or replace function app_private.guard_activity_v2_actor_provenance()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  actor_column text:=tg_argv[0];
  provenance_mode text:=tg_argv[1];
  actor_person_id uuid;
  resolved_person_id uuid;
begin
  if actor_column is null
     or provenance_mode not in ('origin','change') then
    raise exception using message='activity actor provenance trigger misconfigured';
  end if;

  if tg_op='UPDATE' and provenance_mode='origin' then
    if (to_jsonb(old)->>actor_column) is distinct from (to_jsonb(new)->>actor_column) then
      raise insufficient_privilege using message='activity actor provenance immutable';
    end if;
    return new;
  end if;

  actor_person_id:=(to_jsonb(new)->>actor_column)::uuid;
  if actor_person_id is null then
    perform app_private.require_activity_v2_internal_marker();
  else
    resolved_person_id:=app_private.current_person_id();
    if resolved_person_id is null or actor_person_id<>resolved_person_id then
      raise insufficient_privilege using message='activity actor provenance denied';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists activity_definitions_actor_provenance_guard on public.activity_definitions;
create trigger activity_definitions_actor_provenance_guard before insert or update on public.activity_definitions
for each row execute function app_private.guard_activity_v2_actor_provenance('created_by_person_id','origin');
drop trigger if exists activity_unit_links_actor_provenance_guard on public.activity_unit_links;
create trigger activity_unit_links_actor_provenance_guard before insert or update on public.activity_unit_links
for each row execute function app_private.guard_activity_v2_actor_provenance('linked_by_person_id','origin');
drop trigger if exists activity_group_links_actor_provenance_guard on public.activity_group_links;
create trigger activity_group_links_actor_provenance_guard before insert or update on public.activity_group_links
for each row execute function app_private.guard_activity_v2_actor_provenance('linked_by_person_id','origin');
drop trigger if exists activity_group_participants_actor_provenance_guard on public.activity_group_participants;
create trigger activity_group_participants_actor_provenance_guard before insert or update on public.activity_group_participants
for each row execute function app_private.guard_activity_v2_actor_provenance('added_by_person_id','origin');
drop trigger if exists activity_group_assignments_actor_provenance_guard on public.activity_group_assignments;
create trigger activity_group_assignments_actor_provenance_guard before insert or update on public.activity_group_assignments
for each row execute function app_private.guard_activity_v2_actor_provenance('assigned_by_person_id','origin');
drop trigger if exists activity_admin_assignments_actor_provenance_guard on public.activity_admin_assignments;
create trigger activity_admin_assignments_actor_provenance_guard before insert or update on public.activity_admin_assignments
for each row execute function app_private.guard_activity_v2_actor_provenance('assigned_by_person_id','origin');
drop trigger if exists activity_assignment_capability_actions_actor_provenance_guard on public.activity_assignment_capability_actions;
create trigger activity_assignment_capability_actions_actor_provenance_guard before insert or update on public.activity_assignment_capability_actions
for each row execute function app_private.guard_activity_v2_actor_provenance('changed_by_person_id','change');
drop trigger if exists activity_capability_policies_actor_provenance_guard on public.activity_capability_policies;
create trigger activity_capability_policies_actor_provenance_guard before insert or update on public.activity_capability_policies
for each row execute function app_private.guard_activity_v2_actor_provenance('changed_by_person_id','change');
drop trigger if exists activity_group_capability_settings_actor_provenance_guard on public.activity_group_capability_settings;
create trigger activity_group_capability_settings_actor_provenance_guard before insert or update on public.activity_group_capability_settings
for each row execute function app_private.guard_activity_v2_actor_provenance('changed_by_person_id','change');

alter function app_private.require_activity_v2_internal_marker() owner to postgres;
alter function app_private.guard_activity_v2_actor_provenance() owner to postgres;
revoke all on function app_private.require_activity_v2_internal_marker() from public,anon,authenticated,service_role;
revoke all on function app_private.guard_activity_v2_actor_provenance() from public,anon,authenticated,service_role;

commit;
