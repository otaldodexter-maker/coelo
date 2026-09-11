-- Contrato de producao do chat contextual (realm de pessoas), sobre a baseline
-- de producao de 10/09/2026.
--
-- Producao nunca recebeu 20260812000000_chat_production_contract nem as tres
-- correcoes seguintes (120244, 121146, 25193128), que hoje vivem so em
-- migrations-historico. Este pacote entrega a forma FINAL desses quatro
-- arquivos como uma migration forward-only, ajustada ao que producao tem:
--   - as policies de conversations/messages/participants de producao usam
--     app_private.can_access_conversation (com bypass platform.read) e sao
--     preservadas; can_access_chat_conversation (sem bypass) passa a existir
--     como guarda das RPCs contextuais, como no historico;
--   - message_receipts e message_edits trocam a policy platform_read pela
--     leitura contextual, que o historico exigia para recibos e nao-lidos;
--   - anon perde os grants ALL que a baseline mostra em conversations,
--     messages, message_receipts e message_edits (mesmo padrao do achado de
--     Cardapios em 10/09; RLS ja barrava, mas o grant nao deveria existir).
-- Nao ha grant novo a anon; service_role mantem o que ja tinha.
--
-- Dependente: 20260910240100 (chat interno v2) precisa de
-- public.chat_attachment_metadata e do indice de cursor de mensagens.
begin;

do $$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'chat contract migration must run as postgres';
  end if;
  if to_regclass('public.conversations') is null
     or to_regclass('public.messages') is null
     or to_regclass('public.conversation_participants') is null
     or to_regclass('public.message_receipts') is null
     or to_regclass('public.message_edits') is null
     or to_regclass('public.conversation_child_contexts') is null
     or to_regclass('public.message_child_contexts') is null
     or to_regprocedure('app_private.current_person_id()') is null
     or to_regprocedure('app_private.has_context_permission(uuid,text,uuid,uuid,uuid,uuid,boolean)') is null
     or to_regprocedure('extensions.digest(bytea,text)') is null then
    raise exception using errcode = '55000',
      message = 'contextual chat baseline is unavailable';
  end if;
end
$$;

-- 1. Estado de idempotencia e metadados de anexo (bytes ficam no R2 privado;
--    aqui so metadados restritos, nunca credencial nem URL).
create table if not exists app_private.chat_command_receipts (
  idempotency_key uuid not null,
  actor_person_id uuid not null references public.people(id) on delete cascade,
  command_name text not null check (command_name = 'send_message'),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  message_id uuid not null references public.messages(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (actor_person_id, command_name, idempotency_key)
);

create table if not exists public.chat_attachment_metadata (
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
  unique (provider, object_key),
  constraint chat_attachment_metadata_object_key_no_traversal
    check (object_key !~ '(^|/)\\.\\.?(/|$)')
);

create index if not exists conversation_participants_active_inbox_idx
  on public.conversation_participants (person_id, conversation_id)
  where status = 'active' and left_at is null;
create index if not exists messages_conversation_cursor_idx
  on public.messages (conversation_id, created_at desc, id desc)
  where status = 'active' and deleted_at is null;
create index if not exists message_receipts_person_unread_idx
  on public.message_receipts (person_id, message_id)
  where read_at is null;
create index if not exists chat_attachment_metadata_message_idx
  on public.chat_attachment_metadata (message_id, created_at);

-- 2. Guarda das RPCs contextuais: participante ativo ou permissao contextual.
--    Sem o bypass platform.read: o Superadmin usa o realm interno (240100).
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

-- 3. RLS: recibos, edicoes e anexos passam a leitura contextual.
alter table public.message_receipts enable row level security;
alter table public.message_edits enable row level security;
alter table public.chat_attachment_metadata enable row level security;

drop policy if exists message_receipts_platform_read on public.message_receipts;
drop policy if exists message_edits_platform_read on public.message_edits;
drop policy if exists message_receipts_context_read on public.message_receipts;
drop policy if exists message_edits_context_read on public.message_edits;
drop policy if exists chat_attachment_metadata_context_read on public.chat_attachment_metadata;

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

-- 4. Grants: anon sai das tabelas de chat; authenticated so le recibos,
--    edicoes e anexos (escrita passa pelas RPCs security definer).
revoke all on public.conversations, public.messages from anon;
revoke all on public.message_receipts, public.message_edits, public.chat_attachment_metadata
  from public, anon, authenticated;
grant select on public.message_receipts, public.message_edits, public.chat_attachment_metadata
  to authenticated;
grant all on public.message_receipts, public.message_edits, public.chat_attachment_metadata
  to service_role;

alter table app_private.chat_command_receipts enable row level security;
alter table app_private.chat_command_receipts force row level security;
revoke all on app_private.chat_command_receipts from public, anon, authenticated;
grant all on app_private.chat_command_receipts to service_role;

-- 5. Comandos e leituras (forma final do historico).
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

drop function if exists public.chat_inbox_page(text, text, integer, boolean);
drop function if exists public.chat_inbox_page(timestamptz, uuid, integer, text, boolean);
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
    select * from candidate candidate_row
    where (not p_unread_only or candidate_row.unread_count > 0)
      and (
        p_cursor_activity_at is null
        or (candidate_row.activity_at, candidate_row.id) < (p_cursor_activity_at, p_cursor_conversation_id)
      )
    order by candidate_row.activity_at desc, candidate_row.id desc
    limit p_limit
  )
  select filtered_row.id, filtered_row.title, filtered_row.conversation_type, filtered_row.scope_kind,
    filtered_row.latest_message_id, filtered_row.latest_message_text, filtered_row.latest_message_at,
    filtered_row.unread_count, filtered_row.activity_at, filtered_row.id, filtered_row.is_read_only
  from filtered filtered_row
  order by filtered_row.activity_at desc, filtered_row.id desc;
end
$$;

drop function if exists public.chat_thread_page(uuid, text, integer);
drop function if exists public.chat_thread_page(uuid, timestamptz, uuid, integer);
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

drop function if exists public.chat_send_message(uuid, text, uuid, uuid[], uuid[]);
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

-- 6. Privilegios: revoke explicito de PUBLIC/anon/authenticated antes do grant
--    minimo (o Supabase concede execute a PUBLIC por padrao).
do $$
declare p regprocedure;
begin
  foreach p in array array[
    'app_private.can_access_chat_conversation(uuid,boolean)'::regprocedure,
    'app_private.chat_send_message(uuid,text,uuid,uuid[])'::regprocedure,
    'app_private.chat_author_display_name(uuid,uuid)'::regprocedure,
    'app_private.chat_mark_read(uuid,uuid)'::regprocedure,
    'public.chat_inbox_page(timestamptz,uuid,integer,text,boolean)'::regprocedure,
    'public.chat_thread_page(uuid,timestamptz,uuid,integer)'::regprocedure,
    'public.chat_unread_total()'::regprocedure,
    'public.chat_send_message(uuid,text,uuid,uuid[])'::regprocedure,
    'public.chat_mark_read(uuid,uuid)'::regprocedure,
    'public.chat_realtime_refresh(uuid)'::regprocedure
  ] loop
    execute format('alter function %s owner to postgres', p);
    execute format('revoke all on function %s from public, anon, authenticated', p);
  end loop;
end
$$;

grant execute on function app_private.can_access_chat_conversation(uuid, boolean)
  to authenticated, service_role;
grant execute on function app_private.chat_send_message(uuid, text, uuid, uuid[])
  to authenticated, service_role;
grant execute on function app_private.chat_author_display_name(uuid, uuid) to authenticated;
grant execute on function app_private.chat_mark_read(uuid, uuid) to authenticated, service_role;
grant execute on function public.chat_inbox_page(timestamptz, uuid, integer, text, boolean)
  to authenticated;
grant execute on function public.chat_thread_page(uuid, timestamptz, uuid, integer)
  to authenticated;
grant execute on function public.chat_unread_total() to authenticated;
grant execute on function public.chat_send_message(uuid, text, uuid, uuid[]) to authenticated;
grant execute on function public.chat_mark_read(uuid, uuid) to authenticated;
grant execute on function public.chat_realtime_refresh(uuid) to authenticated;

commit;
