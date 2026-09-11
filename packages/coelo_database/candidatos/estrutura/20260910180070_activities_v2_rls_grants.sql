begin;

do $$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='activities v2 RLS/grants migration must run as postgres';
  end if;
end
$$;

alter table public.activity_definitions force row level security;
alter table public.activity_unit_links force row level security;
alter table public.activity_group_links force row level security;
alter table public.activity_group_participants force row level security;
alter table public.activity_group_assignments force row level security;
alter table public.activity_admin_assignments force row level security;
alter table public.activity_assignment_capability_actions force row level security;
alter table public.activity_admin_capability_actions force row level security;
alter table public.activity_capability_policies force row level security;
alter table public.activity_group_capability_settings force row level security;
alter table app_private.superadmin_internal_activity_command_receipts force row level security;

create index activity_group_participants_group_link_fk_idx
  on public.activity_group_participants(activity_group_link_id);
create index activity_admin_assignments_activity_fk_idx
  on public.activity_admin_assignments(activity_id,institution_id);
create index activity_admin_assignments_membership_fk_idx
  on public.activity_admin_assignments(membership_id,institution_id,person_id);

alter default privileges for role postgres
  revoke execute on functions from public,anon,authenticated,service_role;
alter default privileges for role postgres in schema public
  revoke execute on functions from public,anon,authenticated,service_role;
alter default privileges for role postgres in schema app_private
  revoke execute on functions from public,anon,authenticated,service_role;

do $$
declare target regprocedure;
begin
  foreach target in array array[
    'app_private.activity_v2_success_envelope(jsonb)'::regprocedure,
    'app_private.activity_v2_require_context(text,uuid)'::regprocedure,
    'app_private.activity_v2_normalize_error(text)'::regprocedure,
    'app_private.activity_v2_denied_envelope(text,text,text,uuid,uuid)'::regprocedure,
    'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)'::regprocedure,
    'app_private.activity_v2_set_marker(app_private.superadmin_internal_context,text,text,uuid)'::regprocedure,
    'app_private.audit_activity_change()'::regprocedure,
    'app_private.activity_v2_append_audit(app_private.superadmin_internal_context,uuid,uuid,text,text,jsonb)'::regprocedure,
    'app_private.activity_v2_finish_command(app_private.superadmin_internal_context,uuid,uuid,uuid,text,bytea,bigint,text,uuid,jsonb)'::regprocedure,
    'app_private.activity_v2_replay_or_error(app_private.superadmin_internal_context,uuid,uuid,uuid,text,bytea,uuid)'::regprocedure,
    'app_private.activity_v2_effective_permission(text,text,text,text,text,text,text,text)'::regprocedure,
    'app_private.activity_v2_validate_participants(uuid,jsonb)'::regprocedure,
    'app_private.activity_v2_validate_professionals(uuid,jsonb)'::regprocedure,
    'app_private.activity_v2_command_request_hash(text,uuid,uuid,bigint,jsonb)'::regprocedure,
    'app_private.activity_v2_error_envelope(text,uuid)'::regprocedure,
    'app_private.require_activity_v2_internal_marker()'::regprocedure,
    'app_private.guard_activity_v2_actor_provenance()'::regprocedure,
    'app_private.prevent_activity_v2_group_activity_admin()'::regprocedure,
    'public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean)'::regprocedure,
    'public.superadmin_activity_detail_v2(uuid,text[])'::regprocedure,
    'public.superadmin_activity_form_options_v2(uuid,text[],text,integer)'::regprocedure,
    'public.superadmin_activity_create_v2(uuid,jsonb)'::regprocedure,
    'public.superadmin_activity_update_v2(uuid,uuid,bigint,jsonb)'::regprocedure,
    'public.superadmin_activity_publish_v2(uuid,uuid,bigint)'::regprocedure,
    'public.superadmin_activity_set_units_v2(uuid,uuid,bigint,uuid[])'::regprocedure,
    'public.superadmin_activity_set_groups_v2(uuid,uuid,bigint,uuid[],jsonb)'::regprocedure,
    'public.superadmin_activity_set_participants_v2(uuid,uuid,bigint,jsonb)'::regprocedure,
    'public.superadmin_activity_set_professionals_v2(uuid,uuid,bigint,jsonb)'::regprocedure,
    'public.superadmin_activity_set_permissions_v2(uuid,uuid,bigint,jsonb,jsonb,jsonb)'::regprocedure
  ] loop
    execute format('revoke all on function %s from public,anon,authenticated,service_role',target);
  end loop;
end
$$;

grant execute on function public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean) to authenticated;
grant execute on function public.superadmin_activity_detail_v2(uuid,text[]) to authenticated;
grant execute on function public.superadmin_activity_form_options_v2(uuid,text[],text,integer) to authenticated;
grant execute on function public.superadmin_activity_create_v2(uuid,jsonb) to authenticated;
grant execute on function public.superadmin_activity_update_v2(uuid,uuid,bigint,jsonb) to authenticated;
grant execute on function public.superadmin_activity_publish_v2(uuid,uuid,bigint) to authenticated;
grant execute on function public.superadmin_activity_set_units_v2(uuid,uuid,bigint,uuid[]) to authenticated;
grant execute on function public.superadmin_activity_set_groups_v2(uuid,uuid,bigint,uuid[],jsonb) to authenticated;
grant execute on function public.superadmin_activity_set_participants_v2(uuid,uuid,bigint,jsonb) to authenticated;
grant execute on function public.superadmin_activity_set_professionals_v2(uuid,uuid,bigint,jsonb) to authenticated;
grant execute on function public.superadmin_activity_set_permissions_v2(uuid,uuid,bigint,jsonb,jsonb,jsonb) to authenticated;

commit;
