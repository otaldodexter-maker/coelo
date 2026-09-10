-- Final typed-RPC presentation contract for contextual conversations.
--
-- The public RPCs remain SECURITY INVOKER. `display_name` is projected by a
-- narrowly-scoped app_private helper because the people directory intentionally
-- does not grant participants global people-table access.

create or replace function app_private.chat_author_display_name(
  p_conversation_id uuid,
  p_author_person_id uuid
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select person_row.display_name
  from public.messages message_row
  join public.people person_row on person_row.id = message_row.author_person_id
  where message_row.conversation_id = p_conversation_id
    and message_row.author_person_id = p_author_person_id
    and message_row.status = 'active'
    and message_row.deleted_at is null
    and app_private.can_access_chat_conversation(message_row.conversation_id, false)
  limit 1
$$;

revoke all on function app_private.chat_author_display_name(uuid, uuid) from public, anon;
grant execute on function app_private.chat_author_display_name(uuid, uuid) to authenticated;

drop function public.chat_inbox_page(timestamptz, uuid, integer, text, boolean);
create function public.chat_inbox_page(
  p_cursor_activity_at timestamptz default null,
  p_cursor_conversation_id uuid default null,
  p_limit integer default 30,
  p_search text default null,
  p_unread_only boolean default false
)
returns table (
  conversation_id uuid,
  title text,
  conversation_type text,
  scope_kind text,
  latest_message_id uuid,
  latest_message_text text,
  latest_message_at timestamptz,
  unread_count bigint,
  next_cursor_activity_at timestamptz,
  next_cursor_conversation_id uuid,
  is_read_only boolean
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if p_limit < 1 or p_limit > 100 then
    raise invalid_parameter_value using message = 'page limit must be between 1 and 100';
  end if;
  if (p_cursor_activity_at is null) <> (p_cursor_conversation_id is null) then
    raise invalid_parameter_value using message = 'cursor timestamp and conversation id must be provided together';
  end if;
  if p_search is not null and char_length(btrim(p_search)) > 100 then
    raise invalid_parameter_value using message = 'search is too long';
  end if;

  return query
  with candidate as (
    select
      conversation_row.id,
      conversation_row.title,
      conversation_row.conversation_type,
      conversation_row.scope_kind,
      conversation_row.is_read_only,
      latest_message.id as latest_message_id,
      latest_message.body_text as latest_message_text,
      latest_message.created_at as latest_message_at,
      coalesce(latest_message.created_at, conversation_row.updated_at) as activity_at,
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
      ) as unread_count
    from public.conversations conversation_row
    left join lateral (
      select message_row.id, message_row.body_text, message_row.created_at
      from public.messages message_row
      where message_row.conversation_id = conversation_row.id
        and message_row.status = 'active'
        and message_row.deleted_at is null
      order by message_row.created_at desc, message_row.id desc
      limit 1
    ) latest_message on true
    where app_private.can_access_chat_conversation(conversation_row.id, false)
      and (p_search is null or btrim(p_search) = '' or (
        coalesce(conversation_row.title, '') ilike '%' || btrim(p_search) || '%'
        or coalesce(latest_message.body_text, '') ilike '%' || btrim(p_search) || '%'
      ))
  ), filtered as (
    select * from candidate
    where (not p_unread_only or unread_count > 0)
      and (
        p_cursor_activity_at is null
        or (activity_at, id) < (p_cursor_activity_at, p_cursor_conversation_id)
      )
    order by activity_at desc, id desc
    limit p_limit
  )
  select id, title, conversation_type, scope_kind, latest_message_id,
    latest_message_text, latest_message_at, unread_count, activity_at, id,
    is_read_only
  from filtered
  order by activity_at desc, id desc;
end
$$;

drop function public.chat_thread_page(uuid, timestamptz, uuid, integer);
create function public.chat_thread_page(
  p_conversation_id uuid,
  p_cursor_created_at timestamptz default null,
  p_cursor_message_id uuid default null,
  p_limit integer default 50
)
returns table (
  message_id uuid,
  author_person_id uuid,
  author_name text,
  is_mine boolean,
  body_text text,
  message_type text,
  created_at timestamptz,
  updated_at timestamptz,
  attachments jsonb,
  next_cursor_created_at timestamptz,
  next_cursor_message_id uuid
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if p_limit < 1 or p_limit > 100 then
    raise invalid_parameter_value using message = 'page limit must be between 1 and 100';
  end if;
  if (p_cursor_created_at is null) <> (p_cursor_message_id is null) then
    raise invalid_parameter_value using message = 'cursor timestamp and message id must be provided together';
  end if;

  return query
  select
    message_row.id,
    message_row.author_person_id,
    app_private.chat_author_display_name(message_row.conversation_id, message_row.author_person_id),
    message_row.author_person_id = app_private.current_person_id(),
    message_row.body_text,
    message_row.message_type,
    message_row.created_at,
    message_row.updated_at,
    coalesce(attachment_rows.attachments, '[]'::jsonb),
    message_row.created_at,
    message_row.id
  from public.messages message_row
  left join lateral (
    select jsonb_agg(jsonb_build_object(
      'id', attachment.id,
      'file_name', attachment.file_name,
      'content_type', attachment.content_type,
      'byte_size', attachment.byte_size,
      'sha256', attachment.sha256,
      'upload_status', attachment.upload_status
    ) order by attachment.created_at) as attachments
    from public.chat_attachment_metadata attachment
    where attachment.message_id = message_row.id
  ) attachment_rows on true
  where message_row.conversation_id = p_conversation_id
    and message_row.status = 'active'
    and message_row.deleted_at is null
    and app_private.can_access_chat_conversation(message_row.conversation_id, false)
    and (
      p_cursor_created_at is null
      or (message_row.created_at, message_row.id) < (p_cursor_created_at, p_cursor_message_id)
    )
  order by message_row.created_at desc, message_row.id desc
  limit p_limit;
end
$$;

create or replace function public.chat_unread_total()
returns table (total_unread bigint)
language sql
stable
security invoker
set search_path = ''
as $$
  select count(*)
  from public.messages message_row
  left join public.message_receipts receipt
    on receipt.message_id = message_row.id
   and receipt.person_id = app_private.current_person_id()
  where message_row.status = 'active'
    and message_row.deleted_at is null
    and message_row.author_person_id <> app_private.current_person_id()
    and receipt.read_at is null
    and app_private.can_access_chat_conversation(message_row.conversation_id, false)
$$;

revoke all on function public.chat_inbox_page(timestamptz, uuid, integer, text, boolean)
  from public, anon, authenticated;
grant execute on function public.chat_inbox_page(timestamptz, uuid, integer, text, boolean)
  to authenticated;
revoke all on function public.chat_thread_page(uuid, timestamptz, uuid, integer)
  from public, anon, authenticated;
grant execute on function public.chat_thread_page(uuid, timestamptz, uuid, integer)
  to authenticated;
revoke all on function public.chat_unread_total() from public, anon, authenticated;
grant execute on function public.chat_unread_total() to authenticated;