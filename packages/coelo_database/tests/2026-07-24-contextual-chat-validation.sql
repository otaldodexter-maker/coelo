begin;

do $$
declare current_table text;
begin
  foreach current_table in array array[
    'institution_chat_settings','unit_chat_settings',
    'conversation_routing_teams','conversation_routing_team_members',
    'conversation_participants','conversation_child_contexts',
    'message_child_contexts'
  ] loop
    if to_regclass('public.' || current_table) is null then
      raise exception 'public.% is missing', current_table;
    end if;
    if not exists (
      select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname=current_table and c.relrowsecurity
    ) then raise exception 'RLS missing on public.%', current_table; end if;
  end loop;
  if to_regprocedure('public.send_context_message(uuid,text,uuid[])') is null
  then raise exception 'context message RPC missing'; end if;
  if to_regprocedure(
    'public.create_context_conversation(uuid,text,uuid,uuid,uuid,text,text,uuid,uuid[])'
  ) is null then
    raise exception 'context conversation creation RPC missing';
  end if;
  if to_regprocedure('app_private.can_access_conversation(uuid,boolean)') is null
  then raise exception 'conversation authorization helper missing'; end if;
end
$$;

do $$
declare
  auth_actor uuid := '24000000-0000-0000-0000-000000000001';
  actor_person uuid;
  child_person uuid;
  target_institution uuid;
  target_unit uuid;
  target_membership uuid;
  target_role uuid;
  target_child_context uuid;
  target_child_unit_link uuid;
  created_conversation uuid;
begin
  insert into auth.users(id, aud, role, email, created_at, updated_at)
  values (
    auth_actor, 'authenticated', 'authenticated',
    'chat-lifecycle@example.invalid', now(), now()
  );

  insert into public.people(person_type, first_name, last_name, display_name)
  values ('adult', 'Chat', 'Manager', 'Chat Manager')
  returning id into actor_person;
  insert into public.people(person_type, first_name, last_name, display_name)
  values ('child', 'Chat', 'Child', 'Chat Child')
  returning id into child_person;
  insert into public.person_auth_links(person_id, auth_user_id)
  values (actor_person, auth_actor);

  insert into public.institutions(public_name, legal_name, slug, status)
  values (
    'Chat Lifecycle Tenant',
    'Chat Lifecycle Tenant LTDA',
    'chat-lifecycle-tenant',
    'active'
  )
  returning id into target_institution;
  insert into public.units(institution_id, name, slug)
  values (target_institution, 'Chat Unit', 'chat-lifecycle-unit')
  returning id into target_unit;
  insert into public.child_contexts(child_person_id, institution_id)
  values (child_person, target_institution)
  returning id into target_child_context;
  insert into public.child_unit_links(
    child_context_id, unit_id, status, accepted_by, accepted_at
  )
  values (
    target_child_context, target_unit, 'active', actor_person, now()
  )
  returning id into target_child_unit_link;

  insert into public.institution_memberships(
    person_id, institution_id, role_code
  )
  values (actor_person, target_institution, 'chat_manager')
  returning id into target_membership;
  insert into public.institution_roles(institution_id, code, name)
  values (target_institution, 'chat_manager', 'Chat Manager')
  returning id into target_role;
  insert into public.institution_role_permissions(role_id, permission_id)
  select target_role, id
  from public.institution_permissions
  where code in ('chat.read', 'chat.manage');
  insert into public.institution_role_assignments(
    membership_id, role_id, scope_kind
  )
  values (target_membership, target_role, 'institution');

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_actor::text, true);

  select conversation.id
  into created_conversation
  from public.create_context_conversation(
    target_institution,
    'unit',
    target_unit,
    null,
    null,
    'direct',
    'Lifecycle validation',
    null,
    array[target_child_context]
  ) conversation;

  if not exists (
    select 1
    from public.conversation_participants participant
    where participant.conversation_id = created_conversation
      and participant.person_id = actor_person
      and participant.experience_kind = 'professional'
  ) then
    raise exception 'conversation creator was not recorded as participant';
  end if;

  perform public.send_context_message(
    created_conversation,
    'Lifecycle validation message',
    array[target_child_context]
  );
  execute 'reset role';

  update public.child_unit_links
  set status = 'revoked', revoked_at = now()
  where id = target_child_unit_link;

  if not exists (
    select 1
    from public.conversations conversation
    where conversation.id = created_conversation
      and conversation.is_read_only
      and conversation.read_only_reason = 'child_institution_context_ended'
  ) then
    raise exception 'ended child context did not make conversation read-only';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_actor::text, true);
  if not app_private.can_access_conversation(created_conversation, false) then
    raise exception 'historical conversation became invisible';
  end if;
  if app_private.can_access_conversation(created_conversation, true) then
    raise exception 'historical conversation remained writable';
  end if;
  execute 'reset role';
end
$$;

rollback;
