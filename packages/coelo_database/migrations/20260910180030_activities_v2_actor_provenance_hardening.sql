begin;

create or replace function app_private.require_activity_v2_internal_marker()
returns void language plpgsql security definer set search_path='' as $$
declare marker jsonb; context_record app_private.superadmin_internal_context;
begin
  begin marker:=current_setting('app_private.activity_v2_internal_marker',true)::jsonb;
  exception when others then raise insufficient_privilege using message='activity internal marker denied'; end;
  if marker is null or jsonb_typeof(marker)<>'object'
     or marker->>'permission_code' not in('activities.create','activities.manage','activities.link_units','activities.link_groups','activities.assign_people','activities.manage_permissions')
     or (marker->>'permission_code',marker->>'action_code') not in(
       ('activities.create','create'),('activities.manage','manage'),('activities.link_units','link_units'),
       ('activities.link_groups','link_groups'),('activities.assign_people','assign_people'),('activities.manage_permissions','manage_permissions')) then
    raise insufficient_privilege using message='activity internal marker denied';
  end if;
  select * into strict context_record from app_private.require_superadmin_internal_context(marker->>'permission_code');
  if not exists(select 1 from auth.sessions s where s.id=context_record.session_id and s.user_id=context_record.auth_user_id and (s.not_after is null or s.not_after>now()))
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
declare actor_column text:=tg_argv[0]; actor_person_id uuid; resolved_person_id uuid;
begin
  if tg_op='UPDATE' then
    if (to_jsonb(old)->>actor_column) is not distinct from (to_jsonb(new)->>actor_column) then return new; end if;
    raise insufficient_privilege using message='activity actor provenance immutable';
  end if;
  actor_person_id:=(to_jsonb(new)->>actor_column)::uuid;
  if actor_person_id is null then perform app_private.require_activity_v2_internal_marker();
  else
    resolved_person_id:=app_private.current_person_id();
    if resolved_person_id is null or actor_person_id<>resolved_person_id then raise insufficient_privilege using message='activity actor provenance denied'; end if;
  end if;
  return new;
end $$;

create or replace function app_private.prevent_activity_v2_group_activity_admin()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.assignment_role<>'activity_admin' then return new; end if;
  if tg_op='INSERT' or old.assignment_role is distinct from 'activity_admin'
     or new.id is distinct from old.id or new.activity_group_link_id is distinct from old.activity_group_link_id
     or new.institution_id is distinct from old.institution_id or new.person_id is distinct from old.person_id
     or new.membership_id is distinct from old.membership_id or new.assigned_by_person_id is distinct from old.assigned_by_person_id
     or new.assigned_at is distinct from old.assigned_at or new.created_at is distinct from old.created_at
     or new.status not in('inactive','suspended','archived') or new.revoked_at is null then
    raise check_violation using message='activity_admin assignments are activity-scoped only';
  end if;
  return new;
end $$;

alter function app_private.require_activity_v2_internal_marker() owner to postgres;
alter function app_private.guard_activity_v2_actor_provenance() owner to postgres;
alter function app_private.prevent_activity_v2_group_activity_admin() owner to postgres;
revoke all on function app_private.require_activity_v2_internal_marker() from public,anon,authenticated,service_role;
revoke all on function app_private.guard_activity_v2_actor_provenance() from public,anon,authenticated,service_role;
revoke all on function app_private.prevent_activity_v2_group_activity_admin() from public,anon,authenticated,service_role;

commit;
