begin;

do $$
begin
  if to_regprocedure('realtime.send(jsonb,text,text,boolean)') is null then
    raise exception 'required realtime.send(jsonb,text,text,boolean) contract is unavailable';
  end if;
end
$$;

create or replace function app_private.parse_chat_realtime_topic(
  target_topic text
)
returns uuid
language sql
immutable
strict
security invoker
set search_path = ''
as $$
  select case
    when target_topic ~ '^chat:conversation:[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      then substring(target_topic from '^chat:conversation:(.*)$')::uuid
    else null::uuid
  end
$$;

revoke all on function app_private.parse_chat_realtime_topic(text)
  from public, anon, authenticated;
grant execute on function app_private.parse_chat_realtime_topic(text)
  to service_role;

create or replace function app_private.can_receive_chat_realtime_broadcast(
  target_topic text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    app_private.can_access_chat_conversation(
      app_private.parse_chat_realtime_topic(target_topic),
      false
    ),
    false
  )
$$;

revoke all on function app_private.can_receive_chat_realtime_broadcast(text)
  from public, anon, authenticated;
grant execute on function app_private.can_receive_chat_realtime_broadcast(text)
  to authenticated, service_role;

drop policy if exists chat_private_broadcast_receive on realtime.messages;
create policy chat_private_broadcast_receive
on realtime.messages
for select
to authenticated
using (
  extension = 'broadcast'
  and app_private.can_receive_chat_realtime_broadcast(realtime.topic())
);

create or replace function app_private.emit_chat_realtime_invalidation()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  target_conversation_id uuid;
begin
  if tg_table_schema <> 'public' then
    raise exception 'unsupported chat realtime source';
  end if;

  case tg_table_name
    when 'messages' then
      target_conversation_id := new.conversation_id;
    when 'message_receipts' then
      if tg_op = 'UPDATE' and old.read_at is not distinct from new.read_at then
        return new;
      end if;
      select message_row.conversation_id
      into target_conversation_id
      from public.messages message_row
      where message_row.id = new.message_id;
    when 'chat_attachment_metadata' then
      if old.upload_status is not distinct from new.upload_status
        and old.message_id is not distinct from new.message_id then
        return new;
      end if;
      target_conversation_id := new.conversation_id;
    else
      raise exception 'unsupported chat realtime source';
  end case;

  if target_conversation_id is null then
    raise exception 'chat realtime conversation unavailable';
  end if;

  begin
    perform realtime.send(
      '{}'::jsonb,
      'invalidate',
      'chat:conversation:' || target_conversation_id::text,
      true
    );
  exception
    when others then
      raise warning 'chat realtime invalidation failed';
  end;

  return new;
end
$$;

revoke all on function app_private.emit_chat_realtime_invalidation()
  from public, anon, authenticated;
grant execute on function app_private.emit_chat_realtime_invalidation()
  to service_role;

drop trigger if exists chat_message_broadcast_invalidation on public.messages;
create trigger chat_message_broadcast_invalidation
after insert on public.messages
for each row execute function app_private.emit_chat_realtime_invalidation();

drop trigger if exists chat_receipt_broadcast_invalidation on public.message_receipts;
create trigger chat_receipt_broadcast_invalidation
after insert or update of read_at on public.message_receipts
for each row execute function app_private.emit_chat_realtime_invalidation();

drop trigger if exists chat_attachment_broadcast_invalidation on public.chat_attachment_metadata;
create trigger chat_attachment_broadcast_invalidation
after update of upload_status, message_id on public.chat_attachment_metadata
for each row execute function app_private.emit_chat_realtime_invalidation();

commit;
