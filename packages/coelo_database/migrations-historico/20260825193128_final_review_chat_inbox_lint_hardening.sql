-- Final Revisao Supabase: forward-only runtime/lint hardening.
-- Public signatures and existing privileges are preserved.

CREATE OR REPLACE FUNCTION public.chat_inbox_page(p_cursor_activity_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_cursor_conversation_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 30, p_search text DEFAULT NULL::text, p_unread_only boolean DEFAULT false)
 RETURNS TABLE(conversation_id uuid, title text, conversation_type text, scope_kind text, latest_message_id uuid, latest_message_text text, latest_message_at timestamp with time zone, unread_count bigint, next_cursor_activity_at timestamp with time zone, next_cursor_conversation_id uuid, is_read_only boolean)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
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
    select * from candidate candidate_row
    where (not p_unread_only or candidate_row.unread_count > 0)
      and (
        p_cursor_activity_at is null
        or (candidate_row.activity_at, candidate_row.id) < (p_cursor_activity_at, p_cursor_conversation_id)
      )
    order by candidate_row.activity_at desc, candidate_row.id desc
    limit p_limit
  )
  select filtered_row.id, filtered_row.title, filtered_row.conversation_type, filtered_row.scope_kind, filtered_row.latest_message_id,
    filtered_row.latest_message_text, filtered_row.latest_message_at, filtered_row.unread_count, filtered_row.activity_at, filtered_row.id,
    filtered_row.is_read_only
  from filtered filtered_row
  order by filtered_row.activity_at desc, filtered_row.id desc;
end
$function$;

