-- Keep table-specific NEW fields in separate PL/pgSQL branches.

create or replace function app_private.validate_chat_context_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare target_institution_id uuid;
begin
  if tg_table_name = 'unit_chat_settings' then
    select institution_id into target_institution_id
    from public.units where id = new.unit_id;
    if target_institution_id is null or target_institution_id <> new.institution_id
    then raise exception 'unit chat tenant mismatch'; end if;
  elsif tg_table_name = 'conversation_routing_teams' then
    if new.unit_id is not null and not exists (
      select 1 from public.units
      where id = new.unit_id and institution_id = new.institution_id
    ) then raise exception 'routing team tenant mismatch'; end if;
  elsif tg_table_name = 'conversation_routing_team_members' then
    if not exists (
      select 1 from public.conversation_routing_teams team
      join public.institution_memberships membership
        on membership.id = new.membership_id
       and membership.institution_id = team.institution_id
      where team.id = new.team_id
    ) then raise exception 'routing member tenant mismatch'; end if;
  elsif tg_table_name = 'conversations' then
    if new.scope_kind not in ('institution', 'unit', 'group', 'activity') then
      raise exception 'invalid conversation scope';
    end if;
    if new.scope_kind = 'institution' and (
      new.unit_id is not null or new.group_id is not null
      or new.activity_id is not null
    ) then raise exception 'institution conversation has child scope'; end if;
    if new.scope_kind = 'unit' and (
      new.unit_id is null or new.group_id is not null
      or new.activity_id is not null
    ) then raise exception 'invalid unit conversation scope'; end if;
    if new.scope_kind = 'group' and (
      new.unit_id is null or new.group_id is null
      or new.activity_id is not null
    ) then raise exception 'invalid group conversation scope'; end if;
    if new.scope_kind = 'activity' and (
      new.unit_id is null or new.group_id is null
      or new.activity_id is null
    ) then raise exception 'invalid activity conversation scope'; end if;
    if new.unit_id is not null and not exists (
      select 1 from public.units
      where id = new.unit_id and institution_id = new.institution_id
    ) then raise exception 'conversation unit tenant mismatch'; end if;
    if new.group_id is not null and not exists (
      select 1 from public.groups
      where id = new.group_id and unit_id = new.unit_id
        and institution_id = new.institution_id
    ) then raise exception 'conversation group tenant mismatch'; end if;
    if new.activity_id is not null and not exists (
      select 1 from public.activity_group_links link
      where link.activity_id = new.activity_id and link.group_id = new.group_id
        and link.unit_id = new.unit_id
        and link.institution_id = new.institution_id
    ) then raise exception 'conversation activity context mismatch'; end if;
  elsif tg_table_name = 'conversation_participants' then
    if new.membership_id is not null and not exists (
      select 1 from public.conversations conversation_row
      join public.institution_memberships membership
        on membership.id = new.membership_id
       and membership.institution_id = conversation_row.institution_id
       and membership.person_id = new.person_id
      where conversation_row.id = new.conversation_id
    ) then raise exception 'participant membership mismatch'; end if;
  elsif tg_table_name = 'conversation_child_contexts' then
    if not exists (
      select 1 from public.conversations conversation_row
      join public.child_contexts child_context
        on child_context.id = new.child_context_id
       and child_context.institution_id = conversation_row.institution_id
      where conversation_row.id = new.conversation_id
    ) then raise exception 'conversation child tenant mismatch'; end if;
  elsif tg_table_name = 'message_child_contexts' then
    if not exists (
      select 1 from public.messages message_row
      join public.conversations conversation_row
        on conversation_row.id = message_row.conversation_id
      join public.child_contexts child_context
        on child_context.id = new.child_context_id
       and child_context.institution_id = conversation_row.institution_id
      where message_row.id = new.message_id
    ) then raise exception 'message child tenant mismatch'; end if;
  end if;
  return new;
end;
$$;
