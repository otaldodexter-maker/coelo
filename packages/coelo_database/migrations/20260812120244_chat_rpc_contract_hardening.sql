-- Keep the Flutter adapter on the typed SETOF RPC contract.  The previous
-- JSON overloads had the same public RPC names and made the endpoint shape
-- dependent on the supplied parameter names.  That is fragile for PostgREST
-- clients and caused the Realtime refresh to return a scalar while the client
-- correctly expected a row set.

drop function if exists public.chat_inbox_page(text, text, integer, boolean);
drop function if exists public.chat_thread_page(uuid, text, integer);
drop function if exists public.chat_send_message(uuid, text, uuid, uuid[], uuid[]);
drop function if exists public.chat_realtime_refresh(uuid);

create function public.chat_realtime_refresh(p_conversation_id uuid)
returns table (
  conversation_id uuid,
  latest_message_at timestamptz,
  unread_count bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    conversation_row.id,
    latest_message.created_at,
    (
      select count(*)
      from public.messages unread_message
      left join public.message_receipts receipt
        on receipt.message_id = unread_message.id
       and receipt.person_id = app_private.current_person_id()
      where unread_message.conversation_id = conversation_row.id
        and unread_message.status = 'active'
        and unread_message.deleted_at is null
        and unread_message.author_person_id <> app_private.current_person_id()
        and receipt.read_at is null
    )
  from public.conversations conversation_row
  left join lateral (
    select message_row.created_at
    from public.messages message_row
    where message_row.conversation_id = conversation_row.id
      and message_row.status = 'active'
      and message_row.deleted_at is null
    order by message_row.created_at desc, message_row.id desc
    limit 1
  ) latest_message on true
  where conversation_row.id = p_conversation_id
    and app_private.can_access_chat_conversation(conversation_row.id, false)
$$;

revoke all on function public.chat_realtime_refresh(uuid) from public, anon;
grant execute on function public.chat_realtime_refresh(uuid) to authenticated;

alter table public.chat_attachment_metadata
  add constraint chat_attachment_metadata_object_key_no_traversal
  check (object_key !~ '(^|/)\\.\\.?(/|$)');