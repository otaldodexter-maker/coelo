-- Transactional conversation creation and automatic historical read-only lifecycle.

create or replace function app_private.create_context_conversation(
  target_institution_id uuid,
  target_scope_kind text,
  target_unit_id uuid default null,
  target_group_id uuid default null,
  target_activity_id uuid default null,
  target_conversation_type text default 'direct',
  target_title text default null,
  target_routing_team_id uuid default null,
  target_child_context_ids uuid[] default array[]::uuid[]
)
returns public.conversations
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid := app_private.current_person_id();
  actor_membership public.institution_memberships%rowtype;
  created_conversation public.conversations%rowtype;
  is_context_manager boolean;
  is_family_initiator boolean;
begin
  if actor_person_id is null then
    raise exception 'authenticated person required';
  end if;
  if target_scope_kind not in ('institution', 'unit', 'group', 'activity') then
    raise exception 'invalid conversation scope';
  end if;
  if nullif(btrim(target_conversation_type), '') is null then
    raise exception 'conversation type required';
  end if;

  is_context_manager := app_private.has_context_permission(
    target_institution_id,
    'chat.manage',
    target_unit_id,
    target_group_id,
    target_activity_id,
    null,
    target_scope_kind = 'institution'
  );

  is_family_initiator :=
    coalesce(cardinality(target_child_context_ids), 0) > 0
    and not exists (
      select 1
      from unnest(target_child_context_ids) as requested_child(child_context_id)
      where not app_private.guardian_has_capability(
        requested_child.child_context_id,
        'message'
      )
    )
    and not exists (
      select 1
      from unnest(target_child_context_ids) as requested_child(child_context_id)
      where not exists (
        select 1
        from public.child_contexts child_context
        where child_context.id = requested_child.child_context_id
          and child_context.institution_id = target_institution_id
          and child_context.status = 'active'
          and (
            target_scope_kind = 'institution'
            or (
              target_scope_kind = 'unit'
              and exists (
                select 1
                from public.child_unit_links child_unit
                where child_unit.child_context_id = child_context.id
                  and child_unit.unit_id = target_unit_id
                  and child_unit.status in ('awaiting_allocation', 'active')
              )
            )
            or (
              target_scope_kind in ('group', 'activity')
              and exists (
                select 1
                from public.child_unit_links child_unit
                join public.child_group_links child_group
                  on child_group.child_unit_link_id = child_unit.id
                 and child_group.group_id = target_group_id
                 and child_group.status = 'active'
                where child_unit.child_context_id = child_context.id
                  and child_unit.unit_id = target_unit_id
                  and child_unit.status = 'active'
              )
            )
          )
      )
    );

  if is_family_initiator and target_scope_kind = 'institution' then
    is_family_initiator := coalesce((
      select setting.institution_chat_enabled
      from public.institution_chat_settings setting
      where setting.institution_id = target_institution_id
    ), true);
  elsif is_family_initiator and target_scope_kind = 'unit' then
    is_family_initiator :=
      coalesce((
        select setting.unit_chat_enabled
        from public.institution_chat_settings setting
        where setting.institution_id = target_institution_id
      ), true)
      and coalesce((
        select setting.is_enabled
        from public.unit_chat_settings setting
        where setting.unit_id = target_unit_id
          and setting.institution_id = target_institution_id
      ), true);
  end if;

  if not is_context_manager and not is_family_initiator then
    raise exception 'conversation creation denied';
  end if;

  if target_routing_team_id is not null and not exists (
    select 1
    from public.conversation_routing_teams team
    where team.id = target_routing_team_id
      and team.institution_id = target_institution_id
      and (team.unit_id is null or team.unit_id = target_unit_id)
      and team.status = 'active'
  ) then
    raise exception 'invalid routing team';
  end if;

  insert into public.conversations(
    institution_id,
    scope_kind,
    scope_id,
    conversation_type,
    title,
    created_by,
    unit_id,
    group_id,
    activity_id,
    routing_team_id
  )
  values (
    target_institution_id,
    target_scope_kind,
    case target_scope_kind
      when 'unit' then target_unit_id
      when 'group' then target_group_id
      when 'activity' then target_activity_id
      else null
    end,
    btrim(target_conversation_type),
    nullif(btrim(target_title), ''),
    actor_person_id,
    target_unit_id,
    target_group_id,
    target_activity_id,
    target_routing_team_id
  )
  returning * into created_conversation;

  select *
  into actor_membership
  from public.institution_memberships membership
  where membership.person_id = actor_person_id
    and membership.institution_id = target_institution_id
    and membership.status = 'active'
    and membership.revoked_at is null
  order by membership.created_at desc
  limit 1;

  insert into public.conversation_participants(
    conversation_id,
    person_id,
    membership_id,
    experience_kind,
    role_snapshot
  )
  values (
    created_conversation.id,
    actor_person_id,
    actor_membership.id,
    case when actor_membership.id is null then 'family' else 'professional' end,
    coalesce(nullif(actor_membership.role_code, ''), 'responsavel')
  );

  insert into public.conversation_child_contexts(
    conversation_id,
    child_context_id
  )
  select created_conversation.id, requested_child.child_context_id
  from (
    select distinct unnest(target_child_context_ids) as child_context_id
  ) requested_child;

  insert into public.conversation_participants(
    conversation_id,
    person_id,
    membership_id,
    experience_kind,
    role_snapshot
  )
  select
    created_conversation.id,
    membership.person_id,
    membership.id,
    'professional',
    membership.role_code
  from public.conversation_routing_team_members team_member
  join public.institution_memberships membership
    on membership.id = team_member.membership_id
   and membership.institution_id = target_institution_id
   and membership.status = 'active'
   and membership.revoked_at is null
  where team_member.team_id = target_routing_team_id
    and team_member.status = 'active'
    and team_member.removed_at is null
  on conflict do nothing;

  insert into audit.audit_logs(
    actor_person_id,
    actor_membership_id,
    action_code,
    object_type,
    object_id,
    institution_id,
    outcome,
    after_json
  )
  values (
    actor_person_id,
    actor_membership.id,
    'chat.conversation.create',
    'conversation',
    created_conversation.id,
    target_institution_id,
    'success',
    jsonb_build_object(
      'scope_kind', target_scope_kind,
      'unit_id', target_unit_id,
      'group_id', target_group_id,
      'activity_id', target_activity_id,
      'child_context_ids', target_child_context_ids
    )
  );

  return created_conversation;
end;
$$;

create or replace function public.create_context_conversation(
  institution_id uuid,
  scope_kind text,
  unit_id uuid default null,
  group_id uuid default null,
  activity_id uuid default null,
  conversation_type text default 'direct',
  title text default null,
  routing_team_id uuid default null,
  child_context_ids uuid[] default array[]::uuid[]
)
returns public.conversations
language sql
volatile
security invoker
set search_path = ''
as $$
  select app_private.create_context_conversation(
    institution_id,
    scope_kind,
    unit_id,
    group_id,
    activity_id,
    conversation_type,
    title,
    routing_team_id,
    child_context_ids
  )
$$;

create or replace function app_private.make_ended_child_conversations_read_only()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_child_context_id uuid;
begin
  affected_child_context_id := case
    when tg_table_name = 'child_contexts' then new.id
    else new.child_context_id
  end;

  update public.conversations conversation_row
  set
    is_read_only = true,
    read_only_reason = coalesce(
      conversation_row.read_only_reason,
      'child_institution_context_ended'
    ),
    updated_at = now()
  where conversation_row.is_read_only = false
    and exists (
      select 1
      from public.conversation_child_contexts conversation_child
      where conversation_child.conversation_id = conversation_row.id
        and conversation_child.child_context_id = affected_child_context_id
    )
    and not exists (
      select 1
      from public.conversation_child_contexts conversation_child
      join public.child_contexts child_context
        on child_context.id = conversation_child.child_context_id
       and child_context.status = 'active'
       and child_context.archived_at is null
      where conversation_child.conversation_id = conversation_row.id
        and exists (
          select 1
          from public.child_unit_links child_unit
          where child_unit.child_context_id = child_context.id
            and child_unit.status in ('awaiting_allocation', 'active')
            and child_unit.revoked_at is null
        )
    );

  return new;
end;
$$;

drop trigger if exists child_contexts_chat_read_only
  on public.child_contexts;
create trigger child_contexts_chat_read_only
after update of status, archived_at
on public.child_contexts
for each row
when (
  old.status is distinct from new.status
  or old.archived_at is distinct from new.archived_at
)
execute function app_private.make_ended_child_conversations_read_only();

drop trigger if exists child_unit_links_chat_read_only
  on public.child_unit_links;
create trigger child_unit_links_chat_read_only
after update of status, revoked_at
on public.child_unit_links
for each row
when (
  old.status is distinct from new.status
  or old.revoked_at is distinct from new.revoked_at
)
execute function app_private.make_ended_child_conversations_read_only();

revoke all on function app_private.create_context_conversation(
  uuid,text,uuid,uuid,uuid,text,text,uuid,uuid[]
) from public,anon;
grant execute on function app_private.create_context_conversation(
  uuid,text,uuid,uuid,uuid,text,text,uuid,uuid[]
) to authenticated,service_role;

revoke all on function public.create_context_conversation(
  uuid,text,uuid,uuid,uuid,text,text,uuid,uuid[]
) from public,anon;
grant execute on function public.create_context_conversation(
  uuid,text,uuid,uuid,uuid,text,text,uuid,uuid[]
) to authenticated;

revoke all on function app_private.make_ended_child_conversations_read_only()
  from public,anon,authenticated;
grant execute on function app_private.make_ended_child_conversations_read_only()
  to service_role;
