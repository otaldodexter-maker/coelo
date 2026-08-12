begin;

do $$
declare
  required_function text;
  protected_table text;
begin
  foreach protected_table in array array[
    'message_receipts', 'message_edits', 'chat_attachment_metadata'
  ] loop
    if to_regclass('public.' || protected_table) is null then
      raise exception 'public.% is missing', protected_table;
    end if;
    if not exists (
      select 1
      from pg_class class_row
      join pg_namespace namespace_row on namespace_row.oid = class_row.relnamespace
      where namespace_row.nspname = 'public'
        and class_row.relname = protected_table
        and class_row.relrowsecurity
    ) then
      raise exception 'RLS missing on public.%', protected_table;
    end if;
    if has_table_privilege('authenticated', 'public.' || protected_table, 'insert')
      or has_table_privilege('authenticated', 'public.' || protected_table, 'update')
      or has_table_privilege('authenticated', 'public.' || protected_table, 'delete') then
      raise exception 'authenticated direct mutation remains granted on public.%', protected_table;
    end if;
  end loop;

  foreach required_function in array array[
    'public.chat_inbox_page(timestamptz,uuid,integer,text,boolean)',
    'public.chat_thread_page(uuid,timestamptz,uuid,integer)',
    'public.chat_send_message(uuid,text,uuid,uuid[])',
    'public.chat_mark_read(uuid,uuid)',
    'public.chat_realtime_refresh(uuid)'
  ] loop
    if to_regprocedure(required_function) is null then
      raise exception 'chat production RPC is missing: %', required_function;
    end if;
  end loop;
end
$$;

do $$
declare
  auth_actor uuid := '25000000-0000-0000-0000-000000000001';
  auth_reader uuid := '25000000-0000-0000-0000-000000000002';
  auth_outsider uuid := '25000000-0000-0000-0000-000000000003';
  actor_person uuid;
  reader_person uuid;
  outsider_person uuid;
  institution_id uuid;
  unit_id uuid;
  actor_membership uuid;
  reader_membership uuid;
  role_id uuid;
  conversation_id uuid;
  message_id uuid;
  replay_message_id uuid;
  inbox_count integer;
  thread_count integer;
  read_count integer;
  send_denied boolean := false;
begin
  insert into auth.users(id, aud, role, email, created_at, updated_at)
  values
    (auth_actor, 'authenticated', 'authenticated', 'chat-production-actor@example.invalid', now(), now()),
    (auth_reader, 'authenticated', 'authenticated', 'chat-production-reader@example.invalid', now(), now()),
    (auth_outsider, 'authenticated', 'authenticated', 'chat-production-outsider@example.invalid', now(), now());

  insert into public.people(person_type, first_name, last_name, display_name)
  values ('adult', 'Chat', 'Actor', 'Chat Actor')
  returning id into actor_person;
  insert into public.people(person_type, first_name, last_name, display_name)
  values ('adult', 'Chat', 'Reader', 'Chat Reader')
  returning id into reader_person;
  insert into public.people(person_type, first_name, last_name, display_name)
  values ('adult', 'Chat', 'Outsider', 'Chat Outsider')
  returning id into outsider_person;
  insert into public.person_auth_links(person_id, auth_user_id)
  values (actor_person, auth_actor), (reader_person, auth_reader), (outsider_person, auth_outsider);

  insert into public.institutions(public_name, legal_name, slug, status)
  values ('Chat Production Tenant', 'Chat Production Tenant LTDA', 'chat-production-tenant', 'active')
  returning id into institution_id;
  insert into public.units(institution_id, name, slug)
  values (institution_id, 'Chat Production Unit', 'chat-production-unit')
  returning id into unit_id;

  insert into public.institution_memberships(person_id, institution_id, role_code)
  values (actor_person, institution_id, 'chat_manager')
  returning id into actor_membership;
  insert into public.institution_memberships(person_id, institution_id, role_code)
  values (reader_person, institution_id, 'chat_member')
  returning id into reader_membership;
  insert into public.institution_roles(institution_id, code, name)
  values (institution_id, 'chat_manager', 'Chat Manager')
  returning id into role_id;
  insert into public.institution_role_permissions(role_id, permission_id)
  select role_id, id
  from public.institution_permissions
  where code in ('chat.read', 'chat.manage');
  insert into public.institution_role_assignments(membership_id, role_id, scope_kind)
  values (actor_membership, role_id, 'institution');

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_actor::text, true);
  select id into conversation_id
  from public.create_context_conversation(
    institution_id, 'unit', unit_id, null, null, 'direct', 'Production validation'
  );
  insert into public.conversation_participants(
    conversation_id, person_id, membership_id, experience_kind, role_snapshot
  ) values (conversation_id, reader_person, reader_membership, 'professional', 'chat_member');

  select sent.message_id into message_id
  from public.chat_send_message(
    conversation_id, 'Idempotent production message', '25000000-0000-0000-0000-000000000010', array[]::uuid[]
  ) sent;
  select replay.message_id into replay_message_id
  from public.chat_send_message(
    conversation_id, 'Idempotent production message', '25000000-0000-0000-0000-000000000010', array[]::uuid[]
  ) replay;
  if message_id is null or replay_message_id is distinct from message_id then
    raise exception 'chat_send_message did not replay idempotently';
  end if;
  if (select count(*) from public.messages message_row where message_row.conversation_id = conversation_id) <> 1 then
    raise exception 'idempotent replay created a duplicate message';
  end if;
  select count(*) into inbox_count from public.chat_inbox_page(null, null, 20, null, false) inbox
    where inbox.conversation_id = conversation_id;
  if inbox_count <> 1 then raise exception 'authorized inbox omitted conversation'; end if;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_reader::text, true);
  select count(*) into thread_count
  from public.chat_thread_page(conversation_id, null, null, 20);
  if thread_count <> 1 then raise exception 'authorized thread omitted message'; end if;
  select updated_count into read_count from public.chat_mark_read(conversation_id, message_id);
  if read_count <> 1 then raise exception 'chat_mark_read did not create the reader receipt'; end if;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_outsider::text, true);
  if exists (select 1 from public.chat_thread_page(conversation_id, null, null, 20)) then
    raise exception 'outsider read another conversation by UUID';
  end if;
  begin
    perform * from public.chat_send_message(
      conversation_id, 'Unauthorized message', '25000000-0000-0000-0000-000000000011', array[]::uuid[]
    );
  exception when insufficient_privilege then
    send_denied := true;
  end;
  if not send_denied then raise exception 'outsider sent to another conversation by UUID'; end if;
  execute 'reset role';
end
$$;

rollback;
