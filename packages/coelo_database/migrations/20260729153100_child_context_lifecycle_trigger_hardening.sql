-- Avoid evaluating fields that do not exist on the trigger's current table.

create or replace function app_private.make_ended_child_conversations_read_only()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_child_context_id uuid;
begin
  if tg_table_name = 'child_contexts' then
    affected_child_context_id := new.id;
  elsif tg_table_name = 'child_unit_links' then
    affected_child_context_id := new.child_context_id;
  else
    raise exception 'unsupported child lifecycle trigger table: %',
      tg_table_name;
  end if;

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
end
$$;

revoke all on function app_private.make_ended_child_conversations_read_only()
  from public, anon, authenticated;
grant execute on function app_private.make_ended_child_conversations_read_only()
  to service_role;
