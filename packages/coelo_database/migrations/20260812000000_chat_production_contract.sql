-- Authorized production chat surface. R2 object transfer remains server-side;
-- this migration stores only constrained metadata and never credentials or URLs.

create table app_private.chat_command_receipts (
  idempotency_key uuid not null,
  actor_person_id uuid not null references public.people(id) on delete cascade,
  command_name text not null check (command_name = 'send_message'),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  message_id uuid not null references public.messages(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (actor_person_id, command_name, idempotency_key)
);

create table public.chat_attachment_metadata (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  provider text not null default 'r2' check (provider = 'r2'),
  object_key text not null check (
    btrim(object_key) <> '' and object_key !~ '[\\\\[:cntrl:]]'
  ),
  file_name text not null check (
    btrim(file_name) <> '' and char_length(file_name) <= 255
      and file_name !~ '[[:cntrl:]]'
  ),
  content_type text not null check (
    content_type ~ '^[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]*/[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]*$'
  ),
  byte_size bigint not null check (byte_size > 0 and byte_size <= 26214400),
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  upload_status text not null default 'pending'
    check (upload_status in ('pending', 'ready', 'failed', 'deleted')),
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  uploaded_at timestamptz,
  unique (provider, object_key)
);

create index conversation_participants_active_inbox_idx
  on public.conversation_participants (person_id, conversation_id)
  where status = 'active' and left_at is null;
create index messages_conversation_cursor_idx
  on public.messages (conversation_id, created_at desc, id desc)
  where status = 'active' and deleted_at is null;
create index message_receipts_person_unread_idx
  on public.message_receipts (person_id, message_id)
  where read_at is null;
create index chat_attachment_metadata_message_idx
  on public.chat_attachment_metadata (message_id, created_at);

create or replace function app_private.can_access_chat_conversation(
  target_conversation_id uuid,
  require_write boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.conversations conversation_row
    where conversation_row.id = target_conversation_id
      and (not require_write or (
        conversation_row.status = 'active' and not conversation_row.is_read_only
      ))
      and (
        exists (
          select 1
          from public.conversation_participants participant
          where participant.conversation_id = conversation_row.id
            and participant.person_id = app_private.current_person_id()
            and participant.status = 'active'
            and participant.left_at is null
        )
        or app_private.has_context_permission(
          conversation_row.institution_id,
          case when require_write then 'chat.manage' else 'chat.read' end,
          conversation_row.unit_id,
          conversation_row.group_id,
          conversation_row.activity_id,
          null,
          conversation_row.scope_kind = 'institution'
        )
      )
  )
$$;

drop policy if exists conversations_context_read on public.conversations;
create policy conversations_context_read on public.conversations
for select to authenticated using (app_private.can_access_chat_conversation(id, false));

drop policy if exists messages_context_read on public.messages;
create policy messages_context_read on public.messages
for select to authenticated using (
  app_private.can_access_chat_conversation(conversation_id, false)
);

drop policy if exists conversation_participants_context_read on public.conversation_participants;
create policy conversation_participants_context_read on public.conversation_participants
for select to authenticated using (
  app_private.can_access_chat_conversation(conversation_id, false)
);

drop policy if exists conversation_child_contexts_context_read on public.conversation_child_contexts;
create policy conversation_child_contexts_context_read on public.conversation_child_contexts
for select to authenticated using (
  app_private.can_access_chat_conversation(conversation_id, false)
);

drop policy if exists message_child_contexts_context_read on public.message_child_contexts;
create policy message_child_contexts_context_read on public.message_child_contexts
for select to authenticated using (
  exists (
    select 1 from public.messages message_row
    where message_row.id = message_id
      and app_private.can_access_chat_conversation(message_row.conversation_id, false)
  )
);

alter table public.message_receipts enable row level security;
alter table public.message_edits enable row level security;
alter table public.chat_attachment_metadata enable row level security;

drop policy if exists message_receipts_platform_read on public.message_receipts;
drop policy if exists message_edits_platform_read on public.message_edits;
create policy message_receipts_context_read on public.message_receipts
for select to authenticated using (
  exists (
    select 1
    from public.messages message_row
    join public.conversations conversation_row on conversation_row.id = message_row.conversation_id
    where message_row.id = message_id
      and app_private.can_access_chat_conversation(conversation_row.id, false)
      and (
        message_receipts.person_id = app_private.current_person_id()
        or message_row.author_person_id = app_private.current_person_id()
        or app_private.has_context_permission(
          conversation_row.institution_id, 'chat.manage', conversation_row.unit_id,
          conversation_row.group_id, conversation_row.activity_id, null,
          conversation_row.scope_kind = 'institution'
        )
      )
  )
);
create policy message_edits_context_read on public.message_edits
for select to authenticated using (
  exists (
    select 1 from public.messages message_row
    where message_row.id = message_id
      and app_private.can_access_chat_conversation(message_row.conversation_id, false)
  )
);
create policy chat_attachment_metadata_context_read on public.chat_attachment_metadata
for select to authenticated using (
  exists (
    select 1 from public.messages message_row
    where message_row.id = message_id
      and app_private.can_access_chat_conversation(message_row.conversation_id, false)
  )
);

revoke all on public.message_receipts, public.message_edits, public.chat_attachment_metadata
  from public, anon, authenticated;
grant select on public.message_receipts, public.message_edits, public.chat_attachment_metadata
  to authenticated;
grant all on public.message_receipts, public.message_edits, public.chat_attachment_metadata
  to service_role;

alter table app_private.chat_command_receipts enable row level security;
revoke all on app_private.chat_command_receipts from public, anon, authenticated;
grant all on app_private.chat_command_receipts to service_role;

create or replace function app_private.chat_send_message(
  p_conversation_id uuid,
  p_body_text text,
  p_idempotency_key uuid,
  p_child_context_ids uuid[] default array[]::uuid[]
)
returns table (message_id uuid, created_at timestamptz, replayed boolean)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid := app_private.current_person_id();
  participant_record public.conversation_participants%rowtype;
  created_message public.messages%rowtype;
  existing_receipt app_private.chat_command_receipts%rowtype;
  normalized_body text := nullif(btrim(p_body_text), '');
  request_hash text;
begin
  if actor_id is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  if p_idempotency_key is null then
    raise invalid_parameter_value using message = 'idempotency key required';
  end if;
  if normalized_body is null or char_length(normalized_body) > 4000 then
    raise invalid_parameter_value using message = 'message body must contain 1 to 4000 characters';
  end if;
  if not app_private.can_access_chat_conversation(p_conversation_id, true) then
    raise insufficient_privilege using message = 'conversation is not writable';
  end if;
  if exists (
    select 1 from unnest(coalesce(p_child_context_ids, array[]::uuid[])) child_id
    where not exists (
      select 1 from public.conversation_child_contexts conversation_child
      where conversation_child.conversation_id = p_conversation_id
        and conversation_child.child_context_id = child_id
    )
  ) then
    raise invalid_parameter_value using message = 'message child is outside conversation';
  end if;

  request_hash := encode(
    extensions.digest(
      pg_catalog.convert_to(
        p_conversation_id::text || '|' || normalized_body || '|' || coalesce((
          select string_agg(child_id::text, ',' order by child_id::text)
          from (select distinct unnest(coalesce(p_child_context_ids, array[]::uuid[])) as child_id) children
        ), ''),
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(actor_id::text || p_idempotency_key::text, 0)
  );
  select * into existing_receipt
  from app_private.chat_command_receipts
  where chat_command_receipts.actor_person_id = actor_id
    and command_name = 'send_message'
    and idempotency_key = p_idempotency_key
  for update;
  if existing_receipt.idempotency_key is not null then
    if existing_receipt.request_hash <> request_hash then
      raise unique_violation using message = 'idempotency key replay mismatch';
    end if;
    return query
      select existing_receipt.message_id, message_row.created_at, true
      from public.messages message_row
      where message_row.id = existing_receipt.message_id
        and message_row.conversation_id = p_conversation_id
        and app_private.can_access_chat_conversation(message_row.conversation_id, false);
    return;
  end if;

  select * into participant_record
  from public.conversation_participants participant
  where participant.conversation_id = p_conversation_id
    and participant.person_id = actor_id
    and participant.status = 'active'
    and participant.left_at is null
  order by participant.joined_at desc
  limit 1;
  if participant_record.id is null then
    raise insufficient_privilege using message = 'active participant required to send';
  end if;

  insert into public.messages(
    conversation_id, author_person_id, body_text, message_type,
    author_membership_id, author_experience_kind, author_role_snapshot
  ) values (
    p_conversation_id, actor_id, normalized_body, 'text',
    participant_record.membership_id, participant_record.experience_kind,
    participant_record.role_snapshot
  ) returning * into created_message;
  insert into public.message_child_contexts(message_id, child_context_id)
  select created_message.id, child_id
  from (select distinct unnest(coalesce(p_child_context_ids, array[]::uuid[])) as child_id) children;
  insert into app_private.chat_command_receipts(
    idempotency_key, actor_person_id, command_name, request_hash, message_id
  ) values (
    p_idempotency_key, actor_id, 'send_message', request_hash, created_message.id
  );
  insert into audit.audit_logs(
    actor_person_id, actor_membership_id, action_code, object_type, object_id,
    institution_id, outcome, after_json
  )
  select actor_id, participant_record.membership_id, 'chat.message.send',
    'message', created_message.id, conversation_row.institution_id, 'success',
    jsonb_build_object('conversation_id', p_conversation_id, 'idempotency_key', p_idempotency_key)
  from public.conversations conversation_row
  where conversation_row.id = p_conversation_id;
  return query select created_message.id, created_message.created_at, false;
end
$$;

create or replace function public.chat_inbox_page(
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
  next_cursor_conversation_id uuid
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
    latest_message_text, latest_message_at, unread_count, activity_at, id
  from filtered
  order by activity_at desc, id desc;
end
$$;

create or replace function public.chat_thread_page(
  p_conversation_id uuid,
  p_cursor_created_at timestamptz default null,
  p_cursor_message_id uuid default null,
  p_limit integer default 50
)
returns table (
  message_id uuid,
  author_person_id uuid,
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
  select message_row.id, message_row.author_person_id, message_row.body_text,
    message_row.message_type, message_row.created_at, message_row.updated_at,
    coalesce(attachment_rows.attachments, '[]'::jsonb), message_row.created_at, message_row.id
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

create or replace function app_private.chat_mark_read(
  p_conversation_id uuid,
  p_through_message_id uuid default null
)
returns table (updated_count integer, read_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid := app_private.current_person_id();
  cutoff_created_at timestamptz;
  marked_at timestamptz := now();
begin
  if actor_id is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  if not app_private.can_access_chat_conversation(p_conversation_id, false) then
    return query select 0, marked_at;
    return;
  end if;
  if p_through_message_id is not null then
    select message_row.created_at into cutoff_created_at
    from public.messages message_row
    where message_row.id = p_through_message_id
      and message_row.conversation_id = p_conversation_id
      and app_private.can_access_chat_conversation(message_row.conversation_id, false);
    if cutoff_created_at is null then
      return query select 0, marked_at;
      return;
    end if;
  end if;
  insert into audit.audit_logs(
    actor_person_id, action_code, object_type, object_id, institution_id, outcome, after_json
  )
  select actor_id, 'chat.conversation.read', 'conversation', conversation_row.id,
    conversation_row.institution_id, 'success',
    jsonb_build_object('through_message_id', p_through_message_id)
  from public.conversations conversation_row
  where conversation_row.id = p_conversation_id;
  return query
  with written as (
    insert into public.message_receipts(message_id, person_id, delivered_at, read_at)
    select message_row.id, actor_id, marked_at, marked_at
    from public.messages message_row
    where message_row.conversation_id = p_conversation_id
      and message_row.status = 'active'
      and message_row.deleted_at is null
      and message_row.author_person_id <> actor_id
      and (cutoff_created_at is null or message_row.created_at <= cutoff_created_at)
    on conflict (message_id, person_id) do update
      set delivered_at = coalesce(public.message_receipts.delivered_at, excluded.delivered_at),
          read_at = coalesce(public.message_receipts.read_at, excluded.read_at)
      where public.message_receipts.read_at is null
    returning 1
  )
  select count(*)::integer, marked_at from written;
end
$$;

create or replace function public.chat_send_message(
  p_conversation_id uuid,
  p_body_text text,
  p_idempotency_key uuid,
  p_child_context_ids uuid[] default array[]::uuid[]
)
returns table (message_id uuid, created_at timestamptz, replayed boolean)
language sql
volatile
security invoker
set search_path = ''
as $$
  select * from app_private.chat_send_message(
    p_conversation_id, p_body_text, p_idempotency_key, p_child_context_ids
  )
$$;

create or replace function public.chat_mark_read(
  p_conversation_id uuid,
  p_through_message_id uuid default null
)
returns table (updated_count integer, read_at timestamptz)
language sql
volatile
security invoker
set search_path = ''
as $$
  select * from app_private.chat_mark_read(p_conversation_id, p_through_message_id)
$$;

create or replace function public.chat_realtime_refresh(p_conversation_id uuid)
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
  select inbox.conversation_id, inbox.latest_message_at, inbox.unread_count
  from public.chat_inbox_page(null, null, 1, null, false) inbox
  where inbox.conversation_id = p_conversation_id
$$;

revoke all on function app_private.can_access_chat_conversation(uuid, boolean)
  from public, anon;
grant execute on function app_private.can_access_chat_conversation(uuid, boolean)
  to authenticated, service_role;
revoke all on function app_private.chat_send_message(uuid, text, uuid, uuid[])
  from public, anon;
grant execute on function app_private.chat_send_message(uuid, text, uuid, uuid[])
  to authenticated, service_role;
revoke all on function app_private.chat_mark_read(uuid, uuid)
  from public, anon;
grant execute on function app_private.chat_mark_read(uuid, uuid)
  to authenticated, service_role;
revoke all on function public.chat_inbox_page(timestamptz, uuid, integer, text, boolean)
  from public, anon;
grant execute on function public.chat_inbox_page(timestamptz, uuid, integer, text, boolean)
  to authenticated;
revoke all on function public.chat_thread_page(uuid, timestamptz, uuid, integer)
  from public, anon;
grant execute on function public.chat_thread_page(uuid, timestamptz, uuid, integer)
  to authenticated;
revoke all on function public.chat_send_message(uuid, text, uuid, uuid[])
  from public, anon;
grant execute on function public.chat_send_message(uuid, text, uuid, uuid[])
  to authenticated;
revoke all on function public.chat_mark_read(uuid, uuid) from public, anon;
grant execute on function public.chat_mark_read(uuid, uuid) to authenticated;
revoke all on function public.chat_realtime_refresh(uuid) from public, anon;
grant execute on function public.chat_realtime_refresh(uuid) to authenticated;

-- JSON RPC overloads are the Flutter contract; typed table RPCs above remain
-- available to SQL validation and internal composition.
create or replace function public.chat_inbox_page(
  p_search text default null,
  p_cursor text default null,
  p_limit integer default 30,
  p_unread_only boolean default false
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  cursor_at timestamptz;
  cursor_id uuid;
  row_record record;
  items jsonb := '[]'::jsonb;
  next_cursor text;
  total_unread bigint;
begin
  if p_cursor is not null and p_cursor <> '' then
    begin
      cursor_at := split_part(p_cursor, '|', 1)::timestamptz;
      cursor_id := split_part(p_cursor, '|', 2)::uuid;
      if split_part(p_cursor, '|', 3) <> '' then
        raise invalid_parameter_value;
      end if;
    exception when others then
      raise invalid_parameter_value using message = 'invalid chat inbox cursor';
    end;
  end if;
  for row_record in
    select inbox.*, conversation_row.is_read_only
    from public.chat_inbox_page(cursor_at, cursor_id, p_limit, p_search, p_unread_only) inbox
    join public.conversations conversation_row on conversation_row.id = inbox.conversation_id
    order by inbox.next_cursor_activity_at desc, inbox.next_cursor_conversation_id desc
  loop
    items := items || jsonb_build_array(jsonb_build_object(
      'conversation_id', row_record.conversation_id,
      'title', coalesce(row_record.title, initcap(row_record.scope_kind) || ' · ' || row_record.conversation_type),
      'preview', coalesce(row_record.latest_message_text, ''),
      'context_label', initcap(row_record.scope_kind),
      'kind', row_record.conversation_type,
      'unread_count', row_record.unread_count,
      'updated_at', coalesce(row_record.latest_message_at, row_record.next_cursor_activity_at),
      'is_read_only', row_record.is_read_only
    ));
    next_cursor := row_record.next_cursor_activity_at::text || '|' || row_record.next_cursor_conversation_id::text;
  end loop;
  select count(*) into total_unread
  from public.messages message_row
  left join public.message_receipts receipt
    on receipt.message_id = message_row.id
   and receipt.person_id = app_private.current_person_id()
  where message_row.status = 'active'
    and message_row.deleted_at is null
    and message_row.author_person_id <> app_private.current_person_id()
    and receipt.read_at is null
    and app_private.can_access_chat_conversation(message_row.conversation_id, false);
  return jsonb_build_object(
    'items', items,
    'next_cursor', next_cursor,
    'total_unread', total_unread
  );
end
$$;

create or replace function public.chat_thread_page(
  p_conversation_id uuid,
  p_cursor text default null,
  p_limit integer default 50
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  cursor_at timestamptz;
  cursor_id uuid;
  row_record record;
  items jsonb := '[]'::jsonb;
  next_cursor text;
begin
  if p_cursor is not null and p_cursor <> '' then
    begin
      cursor_at := split_part(p_cursor, '|', 1)::timestamptz;
      cursor_id := split_part(p_cursor, '|', 2)::uuid;
      if split_part(p_cursor, '|', 3) <> '' then
        raise invalid_parameter_value;
      end if;
    exception when others then
      raise invalid_parameter_value using message = 'invalid chat thread cursor';
    end;
  end if;
  for row_record in
    select thread.*
    from public.chat_thread_page(p_conversation_id, cursor_at, cursor_id, p_limit) thread
    order by thread.next_cursor_created_at desc, thread.next_cursor_message_id desc
  loop
    items := items || jsonb_build_array(jsonb_build_object(
      'message_id', row_record.message_id,
      'conversation_id', p_conversation_id,
      'body_text', coalesce(row_record.body_text, ''),
      'author_name', null,
      'sent_at', row_record.created_at,
      'is_mine', row_record.author_person_id = app_private.current_person_id(),
      'kind', row_record.message_type,
      'attachments', coalesce((
        select jsonb_agg(jsonb_build_object(
          'attachment_id', attachment ->> 'id',
          'file_name', attachment ->> 'file_name',
          'media_type', attachment ->> 'content_type',
          'byte_size', attachment -> 'byte_size',
          'download_url', null
        ))
        from jsonb_array_elements(row_record.attachments) attachment
      ), '[]'::jsonb)
    ));
    next_cursor := row_record.next_cursor_created_at::text || '|' || row_record.next_cursor_message_id::text;
  end loop;
  return jsonb_build_object('items', items, 'next_cursor', next_cursor);
end
$$;

create or replace function public.chat_send_message(
  p_conversation_id uuid,
  p_body text,
  p_idempotency_key uuid,
  p_child_context_ids uuid[] default array[]::uuid[],
  p_attachment_ids uuid[] default array[]::uuid[]
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  sent_record record;
  message_row public.messages%rowtype;
begin
  if coalesce(cardinality(p_attachment_ids), 0) > 0 then
    raise check_violation using message = 'attachments require the server-side R2 gateway';
  end if;
  select * into sent_record
  from public.chat_send_message(
    p_conversation_id, p_body, p_idempotency_key, p_child_context_ids
  );
  select * into message_row
  from public.messages
  where id = sent_record.message_id
    and conversation_id = p_conversation_id
    and app_private.can_access_chat_conversation(conversation_id, false);
  if message_row.id is null then
    raise insufficient_privilege using message = 'message is unavailable';
  end if;
  return jsonb_build_object('message', jsonb_build_object(
    'message_id', message_row.id,
    'conversation_id', message_row.conversation_id,
    'body_text', coalesce(message_row.body_text, ''),
    'author_name', null,
    'sent_at', message_row.created_at,
    'is_mine', message_row.author_person_id = app_private.current_person_id(),
    'kind', message_row.message_type,
    'attachments', '[]'::jsonb
  ));
end
$$;

drop function public.chat_realtime_refresh(uuid);
create function public.chat_realtime_refresh(p_conversation_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  payload jsonb;
begin
  -- The requested id is resolved inside the caller's authorised set. A null
  -- result is deliberately indistinguishable from a missing conversation.
  if not app_private.can_access_chat_conversation(p_conversation_id, false) then
    return null;
  end if;
  select jsonb_build_object(
    'conversation_id', conversation_row.id,
    'latest_message_id', latest_message.id,
    'unread_count', (
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
    ),
    'occurred_at', coalesce(latest_message.created_at, conversation_row.created_at)
  ) into payload
  from public.conversations conversation_row
  left join lateral (
    select message_row.id, message_row.created_at
    from public.messages message_row
    where message_row.conversation_id = conversation_row.id
      and message_row.status = 'active'
      and message_row.deleted_at is null
    order by message_row.created_at desc, message_row.id desc
    limit 1
  ) latest_message on true
  where conversation_row.id = p_conversation_id;
  return payload;
end
$$;

revoke all on function public.chat_inbox_page(text, text, integer, boolean) from public, anon;
grant execute on function public.chat_inbox_page(text, text, integer, boolean) to authenticated;
revoke all on function public.chat_thread_page(uuid, text, integer) from public, anon;
grant execute on function public.chat_thread_page(uuid, text, integer) to authenticated;
revoke all on function public.chat_send_message(uuid, text, uuid, uuid[], uuid[]) from public, anon;
grant execute on function public.chat_send_message(uuid, text, uuid, uuid[], uuid[]) to authenticated;
revoke all on function public.chat_realtime_refresh(uuid) from public, anon;
grant execute on function public.chat_realtime_refresh(uuid) to authenticated;
