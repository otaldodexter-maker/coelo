-- Contextual authorization core validation.
-- Safe to run remotely: all fixtures are rolled back.
begin;

do $$
declare
  current_table text;
begin
  if exists (
    select 1 from information_schema.columns column_record
    where column_record.table_schema = 'public'
      and column_record.table_name = 'groups'
      and column_record.column_name = 'unit_id'
      and column_record.is_nullable = 'YES'
  ) then
    raise exception 'groups.unit_id must be required';
  end if;

  foreach current_table in array array[
    'institution_member_permission_overrides',
    'professional_child_assignments'
  ] loop
    if to_regclass('public.' || current_table) is null then
      raise exception 'public.% is missing', current_table;
    end if;
    if not exists (
      select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = current_table and c.relrowsecurity
    ) then
      raise exception 'RLS missing on public.%', current_table;
    end if;
  end loop;

  if to_regprocedure(
    'app_private.has_context_permission(uuid,text,uuid,uuid,uuid,uuid,boolean)'
  ) is null then
    raise exception 'app_private.has_context_permission is missing';
  end if;
end
$$;

do $$
declare
  auth_actor uuid := '20000000-0000-0000-0000-000000000001';
  actor_person uuid;
  child_person uuid;
  institution_id uuid;
  unit_one uuid;
  unit_two uuid;
  group_one uuid;
  child_context_id uuid;
  membership_id uuid;
  role_id uuid;
begin
  insert into auth.users(id, aud, role, email, created_at, updated_at)
  values (auth_actor, 'authenticated', 'authenticated',
          'context-auth@example.invalid', now(), now());

  insert into public.people(person_type, first_name, last_name, display_name)
  values ('adult', 'Context', 'Actor', 'Context Actor')
  returning id into actor_person;
  insert into public.people(person_type, first_name, last_name, display_name)
  values ('child', 'Context', 'Child', 'Context Child')
  returning id into child_person;
  insert into public.person_auth_links(person_id, auth_user_id)
  values (actor_person, auth_actor);

  insert into public.institutions(public_name, legal_name, slug, status)
  values ('Context Tenant', 'Context Tenant LTDA', 'context-auth-tenant', 'active')
  returning id into institution_id;
  insert into public.units(institution_id, name, slug)
  values (institution_id, 'Unit One', 'context-unit-one') returning id into unit_one;
  insert into public.units(institution_id, name, slug)
  values (institution_id, 'Unit Two', 'context-unit-two') returning id into unit_two;
  insert into public.groups(institution_id, unit_id, name)
  values (institution_id, unit_one, 'Group One') returning id into group_one;
  insert into public.child_contexts(child_person_id, institution_id)
  values (child_person, institution_id) returning id into child_context_id;

  insert into public.institution_memberships(person_id, institution_id, role_code)
  values (actor_person, institution_id, 'context_role') returning id into membership_id;
  insert into public.institution_roles(institution_id, code, name)
  values (institution_id, 'context_role', 'Context Role') returning id into role_id;
  insert into public.institution_role_permissions(role_id, permission_id)
  select role_id, id from public.institution_permissions where code = 'people.read';
  insert into public.institution_role_assignments(
    membership_id, role_id, scope_kind, scope_unit_id
  ) values (membership_id, role_id, 'unit', unit_one);

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_actor::text, true);

  if not app_private.has_context_permission(
    institution_id, 'people.read', unit_one, group_one, null, null, false
  ) then
    raise exception 'unit assignment did not include its group';
  end if;
  if app_private.has_context_permission(
    institution_id, 'people.read', unit_two, null, null, null, false
  ) then
    raise exception 'unit assignment leaked into sibling unit';
  end if;

  execute 'reset role';
  insert into public.institution_member_permission_overrides(
    membership_id, permission_code, effect, scope_kind, scope_id, reason,
    changed_by_person_id
  ) values (
    membership_id, 'people.read', 'deny', 'group', group_one,
    'Validation deny', actor_person
  );

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_actor::text, true);
  if app_private.has_context_permission(
    institution_id, 'people.read', unit_one, group_one, null, null, false
  ) then
    raise exception 'individual deny did not prevail';
  end if;
  execute 'reset role';

  insert into public.professional_child_assignments(
    membership_id, child_context_id, assigned_by_person_id
  ) values (membership_id, child_context_id, actor_person);
end
$$;

rollback;
