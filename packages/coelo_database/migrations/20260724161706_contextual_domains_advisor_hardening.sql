-- Index every newly introduced FK and split ALL policies so SELECT has one
-- permissive policy per role/action.

do $$
declare
  constraint_record record;
  column_list text;
  index_name text;
begin
  for constraint_record in
    select constraint_row.oid,constraint_row.conname,constraint_row.conrelid,
           constraint_row.conkey,class_row.relname
    from pg_constraint constraint_row
    join pg_class class_row on class_row.oid=constraint_row.conrelid
    join pg_namespace namespace_row on namespace_row.oid=class_row.relnamespace
    where constraint_row.contype='f'
      and namespace_row.nspname='public'
      and class_row.relname in (
        'institution_member_permission_overrides','professional_child_assignments',
        'guardian_context_permission_grants','guardian_invitation_children',
        'authorized_people','authorized_person_authorizations',
        'authorized_person_authorization_capabilities',
        'context_notification_events','context_notification_recipients',
        'child_unit_transfer_requests','child_unit_transfer_items',
        'activity_capability_policies','activity_group_capability_settings',
        'activity_group_participants','institution_chat_settings',
        'unit_chat_settings','conversation_routing_teams',
        'conversation_routing_team_members','conversation_participants',
        'conversation_child_contexts','message_child_contexts',
        'attendance_reason_catalog','attendance_sessions',
        'attendance_expected_participants','attendance_notices',
        'attendance_notice_attachments','attendance_records',
        'attendance_record_revisions'
      )
      and not exists (
        select 1 from pg_index index_row
        where index_row.indrelid=constraint_row.conrelid
          and index_row.indisvalid
          and (index_row.indkey::smallint[])[
            0:cardinality(constraint_row.conkey)-1
          ]=constraint_row.conkey
      )
  loop
    select string_agg(format('%I',attribute_row.attname),',' order by key_row.ord)
      into column_list
    from unnest(constraint_record.conkey) with ordinality key_row(attnum,ord)
    join pg_attribute attribute_row
      on attribute_row.attrelid=constraint_record.conrelid
     and attribute_row.attnum=key_row.attnum;
    index_name:='ctx_fk_'||substr(md5(constraint_record.conname),1,16);
    execute format(
      'create index if not exists %I on public.%I(%s)',
      index_name,constraint_record.relname,column_list
    );
  end loop;
end;
$$;

drop policy activity_capability_policies_manage
  on public.activity_capability_policies;
create policy activity_capability_policies_manage_insert
on public.activity_capability_policies for insert to authenticated
with check (app_private.has_context_permission(
  institution_id,'activities.manage_permissions',null,null,activity_id,null,true
));
create policy activity_capability_policies_manage_update
on public.activity_capability_policies for update to authenticated
using (app_private.has_context_permission(
  institution_id,'activities.manage_permissions',null,null,activity_id,null,true
))
with check (app_private.has_context_permission(
  institution_id,'activities.manage_permissions',null,null,activity_id,null,true
));

drop policy activity_group_capability_settings_manage
  on public.activity_group_capability_settings;
create policy activity_group_capability_settings_manage_insert
on public.activity_group_capability_settings for insert to authenticated
with check (exists (
  select 1 from public.activity_group_links group_link
  where group_link.id=activity_group_link_id
    and app_private.has_context_permission(
      group_link.institution_id,'activities.manage_permissions',
      group_link.unit_id,group_link.group_id,group_link.activity_id,null,false
    )
));
create policy activity_group_capability_settings_manage_update
on public.activity_group_capability_settings for update to authenticated
using (exists (
  select 1 from public.activity_group_links group_link
  where group_link.id=activity_group_link_id
    and app_private.has_context_permission(
      group_link.institution_id,'activities.manage_permissions',
      group_link.unit_id,group_link.group_id,group_link.activity_id,null,false
    )
))
with check (exists (
  select 1 from public.activity_group_links group_link
  where group_link.id=activity_group_link_id
    and app_private.has_context_permission(
      group_link.institution_id,'activities.manage_permissions',
      group_link.unit_id,group_link.group_id,group_link.activity_id,null,false
    )
));

drop policy activity_group_participants_manage
  on public.activity_group_participants;
create policy activity_group_participants_manage_insert
on public.activity_group_participants for insert to authenticated
with check (exists (
  select 1 from public.activity_group_links group_link
  where group_link.id=activity_group_link_id
    and app_private.has_context_permission(
      group_link.institution_id,'activities.link_groups',group_link.unit_id,
      group_link.group_id,group_link.activity_id,null,false
    )
));
create policy activity_group_participants_manage_update
on public.activity_group_participants for update to authenticated
using (exists (
  select 1 from public.activity_group_links group_link
  where group_link.id=activity_group_link_id
    and app_private.has_context_permission(
      group_link.institution_id,'activities.link_groups',group_link.unit_id,
      group_link.group_id,group_link.activity_id,null,false
    )
))
with check (exists (
  select 1 from public.activity_group_links group_link
  where group_link.id=activity_group_link_id
    and app_private.has_context_permission(
      group_link.institution_id,'activities.link_groups',group_link.unit_id,
      group_link.group_id,group_link.activity_id,null,false
    )
));

drop policy attendance_reason_catalog_manage
  on public.attendance_reason_catalog;
create policy attendance_reason_catalog_manage_insert
on public.attendance_reason_catalog for insert to authenticated
with check (app_private.has_context_permission(
  institution_id,'attendance.manage',unit_id,null,null,null,unit_id is null
));
create policy attendance_reason_catalog_manage_update
on public.attendance_reason_catalog for update to authenticated
using (app_private.has_context_permission(
  institution_id,'attendance.manage',unit_id,null,null,null,unit_id is null
))
with check (app_private.has_context_permission(
  institution_id,'attendance.manage',unit_id,null,null,null,unit_id is null
));

drop policy conversation_participants_manage
  on public.conversation_participants;
create policy conversation_participants_manage_insert
on public.conversation_participants for insert to authenticated
with check (exists (
  select 1 from public.conversations conversation_row
  where conversation_row.id=conversation_id
    and app_private.has_context_permission(
      conversation_row.institution_id,'chat.manage',conversation_row.unit_id,
      conversation_row.group_id,conversation_row.activity_id,null,
      conversation_row.scope_kind='institution'
    )
));
create policy conversation_participants_manage_update
on public.conversation_participants for update to authenticated
using (exists (
  select 1 from public.conversations conversation_row
  where conversation_row.id=conversation_id
    and app_private.has_context_permission(
      conversation_row.institution_id,'chat.manage',conversation_row.unit_id,
      conversation_row.group_id,conversation_row.activity_id,null,
      conversation_row.scope_kind='institution'
    )
))
with check (exists (
  select 1 from public.conversations conversation_row
  where conversation_row.id=conversation_id
    and app_private.has_context_permission(
      conversation_row.institution_id,'chat.manage',conversation_row.unit_id,
      conversation_row.group_id,conversation_row.activity_id,null,
      conversation_row.scope_kind='institution'
    )
));

drop policy conversation_child_contexts_manage
  on public.conversation_child_contexts;
create policy conversation_child_contexts_manage_insert
on public.conversation_child_contexts for insert to authenticated
with check (exists (
  select 1 from public.conversations conversation_row
  where conversation_row.id=conversation_id
    and app_private.has_context_permission(
      conversation_row.institution_id,'chat.manage',conversation_row.unit_id,
      conversation_row.group_id,conversation_row.activity_id,child_context_id,
      conversation_row.scope_kind='institution'
    )
));
create policy conversation_child_contexts_manage_update
on public.conversation_child_contexts for update to authenticated
using (exists (
  select 1 from public.conversations conversation_row
  where conversation_row.id=conversation_id
    and app_private.has_context_permission(
      conversation_row.institution_id,'chat.manage',conversation_row.unit_id,
      conversation_row.group_id,conversation_row.activity_id,child_context_id,
      conversation_row.scope_kind='institution'
    )
))
with check (exists (
  select 1 from public.conversations conversation_row
  where conversation_row.id=conversation_id
    and app_private.has_context_permission(
      conversation_row.institution_id,'chat.manage',conversation_row.unit_id,
      conversation_row.group_id,conversation_row.activity_id,child_context_id,
      conversation_row.scope_kind='institution'
    )
));

drop policy guardian_context_permission_grants_manage
  on public.guardian_context_permission_grants;
create policy guardian_context_permission_grants_manage_insert
on public.guardian_context_permission_grants for insert to authenticated
with check (exists (
  select 1 from public.guardian_context_permissions context_permission
  join public.child_contexts child_context
    on child_context.id=context_permission.child_context_id
  where context_permission.id=guardian_context_permission_id
    and app_private.has_context_permission(
      child_context.institution_id,'family.manage',
      null,null,null,child_context.id,false
    )
));
create policy guardian_context_permission_grants_manage_update
on public.guardian_context_permission_grants for update to authenticated
using (exists (
  select 1 from public.guardian_context_permissions context_permission
  join public.child_contexts child_context
    on child_context.id=context_permission.child_context_id
  where context_permission.id=guardian_context_permission_id
    and app_private.has_context_permission(
      child_context.institution_id,'family.manage',
      null,null,null,child_context.id,false
    )
))
with check (exists (
  select 1 from public.guardian_context_permissions context_permission
  join public.child_contexts child_context
    on child_context.id=context_permission.child_context_id
  where context_permission.id=guardian_context_permission_id
    and app_private.has_context_permission(
      child_context.institution_id,'family.manage',
      null,null,null,child_context.id,false
    )
));
