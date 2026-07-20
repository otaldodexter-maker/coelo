-- People, institutional context, family and invitation foundation validation.
-- Run after applying the people_context_foundation migration.

begin;

do $$
declare
  current_table text;
begin
  foreach current_table in array array[
    'institution_roles',
    'institution_permissions',
    'institution_role_permissions',
    'institution_role_assignments',
    'guardian_links',
    'child_contexts',
    'child_unit_links',
    'child_group_links',
    'guardian_context_permissions',
    'child_unit_access_requests',
    'child_unit_access_request_children'
  ]
  loop
    if to_regclass(format('public.%I', current_table)) is null then
      raise exception 'public.% is missing', current_table;
    end if;

    if not exists (
      select 1
      from pg_class relation
      join pg_namespace namespace on namespace.oid = relation.relnamespace
      where namespace.nspname = 'public'
        and relation.relname = current_table
        and relation.relrowsecurity
    ) then
      raise exception 'RLS is not enabled on public.%', current_table;
    end if;

    if not exists (
      select 1
      from pg_policies
      where schemaname = 'public'
        and tablename = current_table
        and roles = array['authenticated']::name[]
        and cmd = 'SELECT'
        and qual like '%has_platform_permission%platform.read%'
    ) then
      raise exception 'platform.read policy is missing on public.%', current_table;
    end if;

    if has_table_privilege('anon', format('public.%I', current_table), 'SELECT')
       or not has_table_privilege('authenticated', format('public.%I', current_table), 'SELECT')
       or has_table_privilege(
         'authenticated',
         format('public.%I', current_table),
         'INSERT,UPDATE,DELETE'
       ) then
      raise exception 'explicit grants are invalid on public.%', current_table;
    end if;
  end loop;

  if to_regclass('public.person_directory') is null then
    raise exception 'public.person_directory is missing';
  end if;

  if not exists (
    select 1
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'person_directory'
      and relation.relkind = 'v'
      and 'security_invoker=true' = any(coalesce(relation.reloptions, array[]::text[]))
  ) then
    raise exception 'public.person_directory must be a security_invoker view';
  end if;

  if has_table_privilege('anon', 'public.person_directory', 'SELECT')
     or not has_table_privilege('authenticated', 'public.person_directory', 'SELECT') then
    raise exception 'person_directory grants are invalid';
  end if;

  if pg_get_viewdef('public.person_directory'::regclass, true)
       not like '%has_platform_permission(''platform.read''%'
  then
    raise exception 'person_directory must enforce platform.read';
  end if;

  if exists (
    select required.column_name
    from unnest(array[
      'invitation_state', 'unit_id', 'group_id', 'invited_by',
      'target_contact_hash', 'masked_destination', 'sent_at',
      'last_sent_at', 'send_count', 'accepted_by'
    ]) required(column_name)
    except
    select column_name
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'invitations'
  ) then
    raise exception 'invitations context columns are incomplete';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'invitations'
      and roles = array['authenticated']::name[]
      and cmd = 'SELECT'
      and qual like '%has_platform_permission%platform.read%'
  ) then
    raise exception 'platform.read policy is missing on public.invitations';
  end if;

  if has_table_privilege('anon', 'public.invitations', 'SELECT')
     or not has_table_privilege('authenticated', 'public.invitations', 'SELECT')
     or has_table_privilege('authenticated', 'public.invitations', 'INSERT,UPDATE,DELETE')
  then
    raise exception 'explicit grants are invalid on public.invitations';
  end if;
end $$;

do $$
declare
  adult_id uuid;
  child_id uuid;
  second_child_id uuid;
  institution_a_id uuid;
  institution_b_id uuid;
  unit_a_id uuid;
  unit_b_id uuid;
  group_a_id uuid;
  group_b_id uuid;
  membership_a_id uuid;
  membership_b_id uuid;
  teacher_role_id uuid;
  guardian_link_id uuid;
  inactive_guardian_link_id uuid;
  child_context_id uuid;
  created_child_unit_link_id uuid;
  request_id uuid;
  rejected boolean;
begin
  insert into public.people(person_type, first_name, last_name, display_name)
  values ('adult', 'Pessoa', 'Global', 'Pessoa Global')
  returning id into adult_id;

  insert into public.people(person_type, first_name, last_name, display_name)
  values ('child', 'Crianca', 'Um', 'Crianca Um')
  returning id into child_id;

  insert into public.people(person_type, first_name, last_name, display_name)
  values ('child', 'Crianca', 'Dois', 'Crianca Dois')
  returning id into second_child_id;

  insert into public.institutions(public_name, legal_name, slug)
  values ('Instituicao A', 'Instituicao A LTDA', 'people-context-institution-a')
  returning id into institution_a_id;

  insert into public.institutions(public_name, legal_name, slug)
  values ('Instituicao B', 'Instituicao B LTDA', 'people-context-institution-b')
  returning id into institution_b_id;

  insert into public.units(institution_id, name, slug)
  values (institution_a_id, 'Unidade A', 'people-context-unit-a')
  returning id into unit_a_id;

  insert into public.units(institution_id, name, slug)
  values (institution_b_id, 'Unidade B', 'people-context-unit-b')
  returning id into unit_b_id;

  insert into public.groups(institution_id, unit_id, name)
  values (institution_a_id, unit_a_id, 'Grupo A')
  returning id into group_a_id;

  insert into public.groups(institution_id, unit_id, name)
  values (institution_b_id, unit_b_id, 'Grupo B')
  returning id into group_b_id;

  insert into public.institution_memberships(
    person_id, institution_id, role_code, scope_kind
  ) values (
    adult_id, institution_a_id, 'teacher', 'institution'
  ) returning id into membership_a_id;

  insert into public.institution_memberships(
    person_id, institution_id, role_code, scope_kind
  ) values (
    adult_id, institution_b_id, 'teacher', 'institution'
  ) returning id into membership_b_id;

  insert into public.institution_roles(
    institution_id, code, name
  ) values (
    institution_a_id, 'teacher', 'Professor'
  ) returning id into teacher_role_id;

  insert into public.institution_role_assignments(
    membership_id, role_id, scope_kind, scope_unit_id, scope_group_id
  ) values (
    membership_a_id, teacher_role_id, 'group', unit_a_id, group_a_id
  );

  insert into public.guardian_links(
    guardian_person_id, child_person_id, relation_type
  ) values (
    adult_id, child_id, 'responsible'
  ) returning id into guardian_link_id;

  insert into public.guardian_links(
    guardian_person_id, child_person_id, relation_type, status
  ) values (
    adult_id, second_child_id, 'responsible', 'inactive'
  ) returning id into inactive_guardian_link_id;

  insert into public.child_contexts(child_person_id, institution_id)
  values (child_id, institution_a_id)
  returning id into child_context_id;

  insert into public.child_unit_links(
    child_context_id, unit_id, status, accepted_by, accepted_at
  ) values (
    child_context_id, unit_a_id, 'awaiting_allocation', adult_id, now()
  ) returning id into created_child_unit_link_id;

  if exists (
    select 1
    from public.child_group_links group_link
    where group_link.child_unit_link_id = created_child_unit_link_id
  ) then
    raise exception 'awaiting child unexpectedly has a group';
  end if;

  insert into public.child_group_links(child_unit_link_id, group_id)
  values (created_child_unit_link_id, group_a_id);

  begin
    insert into public.child_group_links(child_unit_link_id, group_id)
    values (created_child_unit_link_id, group_b_id);
    rejected := false;
  exception when check_violation or foreign_key_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'cross-institution child group link was accepted';
  end if;

  insert into public.child_unit_access_requests(requested_by, unit_id, message)
  values (adult_id, unit_a_id, 'Solicito o vinculo da crianca.')
  returning id into request_id;

  insert into public.child_unit_access_request_children(
    request_id, guardian_link_id, child_person_id
  ) values (
    request_id, guardian_link_id, child_id
  );

  begin
    insert into public.child_unit_access_request_children(
      request_id, guardian_link_id, child_person_id
    ) values (
      request_id, inactive_guardian_link_id, second_child_id
    );
    rejected := false;
  exception when check_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'request with inactive guardian link was accepted';
  end if;

  insert into public.invitations(
    scope_kind, institution_id, target_person_id, role_code,
    token_hash, expires_at, invited_by
  ) values
    (
      'institution', institution_a_id, adult_id, 'teacher',
      encode(digest('invite-a', 'sha256'), 'hex'), now() + interval '7 days', adult_id
    ),
    (
      'institution', institution_b_id, adult_id, 'teacher',
      encode(digest('invite-b', 'sha256'), 'hex'), now() + interval '7 days', adult_id
    );

  if (select count(*) from public.institution_memberships where person_id = adult_id) <> 2 then
    raise exception 'global person did not retain two institution memberships';
  end if;

  if (select count(*) from public.guardian_links where guardian_person_id = adult_id and status = 'active') <> 1 then
    raise exception 'global person did not retain the active guardian relationship';
  end if;
end $$;

rollback;
