-- Contextual Activities foundation validation.
-- Run after applying the contextual activities foundation migration.

begin;

do $$
declare
  current_table text;
begin
  foreach current_table in array array[
    'activity_definitions',
    'activity_unit_links',
    'activity_group_links',
    'activity_group_assignments',
    'activity_capabilities',
    'activity_permission_profiles',
    'activity_permission_profile_capabilities',
    'activity_assignment_permission_overrides',
    'activity_suggestions'
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

    if has_table_privilege('anon', format('public.%I', current_table), 'SELECT,INSERT,UPDATE,DELETE') then
      raise exception 'anon privileges are invalid on public.%', current_table;
    end if;
  end loop;

  if to_regprocedure(
    'public.create_activity_for_institution(uuid,uuid,text,text,text)'
  ) is null then
    raise exception 'public.create_activity_for_institution is missing';
  end if;

  if to_regprocedure(
    'public.create_activity_for_unit(uuid,text,text,text)'
  ) is null then
    raise exception 'public.create_activity_for_unit is missing';
  end if;

  if not exists (
    select 1
    from unnest(array[
      'activities.read',
      'activities.create',
      'activities.manage',
      'activities.link_units',
      'activities.link_groups',
      'activities.assign_people',
      'activities.manage_permissions'
    ]) expected(code)
    left join public.institution_permissions permission_record
      on permission_record.code = expected.code
     and permission_record.status = 'active'
    where permission_record.id is null
  ) then
    null;
  else
    raise exception 'institution activity permission catalog is incomplete';
  end if;

  if exists (
    select expected.code
    from unnest(array[
      'conversation',
      'attendance',
      'events',
      'media_now'
    ]) expected(code)
    left join public.activity_capabilities capability
      on capability.code = expected.code
     and capability.status = 'active'
    where capability.id is null
  ) then
    raise exception 'activity capability catalog is incomplete';
  end if;

  if exists (
    select expected.table_name
    from unnest(array[
      'activity_definitions',
      'activity_unit_links',
      'activity_group_links',
      'activity_group_assignments',
      'activity_capabilities',
      'activity_permission_profiles',
      'activity_permission_profile_capabilities',
      'activity_assignment_permission_overrides',
      'activity_suggestions'
    ]) expected(table_name)
    left join public.schema_tables schema_table
      on schema_table.schema_name = 'public'
     and schema_table.table_name = expected.table_name
     and schema_table.status = 'active'
    where schema_table.id is null
  ) then
    raise exception 'activity tables are missing from schema_tables';
  end if;
end
$$;

do $$
declare
  auth_institution_manager uuid := '10000000-0000-0000-0000-000000000001';
  auth_unit_manager uuid := '10000000-0000-0000-0000-000000000002';
  auth_unit_without_capability uuid := '10000000-0000-0000-0000-000000000003';
  auth_teacher_one uuid := '10000000-0000-0000-0000-000000000004';
  auth_teacher_two uuid := '10000000-0000-0000-0000-000000000005';
  auth_teacher_three uuid := '10000000-0000-0000-0000-000000000006';
  auth_tenant_b_manager uuid := '10000000-0000-0000-0000-000000000007';
  institution_manager uuid;
  unit_manager uuid;
  unit_without_capability uuid;
  teacher_one uuid;
  teacher_two uuid;
  teacher_three uuid;
  tenant_b_manager uuid;
  institution_a uuid;
  institution_b uuid;
  unit_a_one uuid;
  unit_a_two uuid;
  unit_b_one uuid;
  group_a_one uuid;
  group_a_two uuid;
  group_b_one uuid;
  membership_institution_manager uuid;
  membership_unit_manager uuid;
  membership_unit_without_capability uuid;
  membership_teacher_one uuid;
  membership_teacher_two uuid;
  membership_teacher_three uuid;
  membership_tenant_b_manager uuid;
  institution_manager_role uuid;
  unit_manager_role uuid;
  tenant_b_manager_role uuid;
  institutional_activity uuid;
  unit_activity uuid;
  tenant_b_activity uuid;
  group_link_one uuid;
  group_link_two uuid;
  assignment_teacher_one uuid;
  profile_id uuid;
  rejected boolean;
  visible_count bigint;
begin
  insert into auth.users(id, aud, role, email, created_at, updated_at)
  values
    (auth_institution_manager, 'authenticated', 'authenticated', 'activity-inst-manager@example.invalid', now(), now()),
    (auth_unit_manager, 'authenticated', 'authenticated', 'activity-unit-manager@example.invalid', now(), now()),
    (auth_unit_without_capability, 'authenticated', 'authenticated', 'activity-unit-denied@example.invalid', now(), now()),
    (auth_teacher_one, 'authenticated', 'authenticated', 'activity-teacher-one@example.invalid', now(), now()),
    (auth_teacher_two, 'authenticated', 'authenticated', 'activity-teacher-two@example.invalid', now(), now()),
    (auth_teacher_three, 'authenticated', 'authenticated', 'activity-teacher-three@example.invalid', now(), now()),
    (auth_tenant_b_manager, 'authenticated', 'authenticated', 'activity-tenant-b-manager@example.invalid', now(), now());

  insert into public.people(person_type, first_name, last_name, display_name)
  values
    ('adult', 'Gestor', 'Institucional', 'Gestor Institucional'),
    ('adult', 'Gestor', 'Unidade', 'Gestor Unidade'),
    ('adult', 'Sem', 'Capacidade', 'Unidade Sem Capacidade'),
    ('adult', 'Professor', 'Um', 'Professor Um'),
    ('adult', 'Professor', 'Dois', 'Professor Dois'),
    ('adult', 'Professor', 'Tres', 'Professor Tres'),
    ('adult', 'Gestor', 'Tenant B', 'Gestor Tenant B');

  select id into institution_manager
  from public.people where display_name = 'Gestor Institucional';
  select id into unit_manager
  from public.people where display_name = 'Gestor Unidade';
  select id into unit_without_capability
  from public.people where display_name = 'Unidade Sem Capacidade';
  select id into teacher_one
  from public.people where display_name = 'Professor Um';
  select id into teacher_two
  from public.people where display_name = 'Professor Dois';
  select id into teacher_three
  from public.people where display_name = 'Professor Tres';
  select id into tenant_b_manager
  from public.people where display_name = 'Gestor Tenant B';

  insert into public.person_auth_links(person_id, auth_user_id)
  values
    (institution_manager, auth_institution_manager),
    (unit_manager, auth_unit_manager),
    (unit_without_capability, auth_unit_without_capability),
    (teacher_one, auth_teacher_one),
    (teacher_two, auth_teacher_two),
    (teacher_three, auth_teacher_three),
    (tenant_b_manager, auth_tenant_b_manager);

  insert into public.institutions(public_name, legal_name, slug, status)
  values ('Atividades Tenant A', 'Atividades Tenant A LTDA', 'activities-tenant-a', 'active')
  returning id into institution_a;

  insert into public.institutions(public_name, legal_name, slug, status)
  values ('Atividades Tenant B', 'Atividades Tenant B LTDA', 'activities-tenant-b', 'active')
  returning id into institution_b;

  insert into public.units(institution_id, name, slug)
  values (institution_a, 'Unidade A1', 'activities-unit-a1')
  returning id into unit_a_one;
  insert into public.units(institution_id, name, slug)
  values (institution_a, 'Unidade A2', 'activities-unit-a2')
  returning id into unit_a_two;
  insert into public.units(institution_id, name, slug)
  values (institution_b, 'Unidade B1', 'activities-unit-b1')
  returning id into unit_b_one;

  insert into public.groups(institution_id, unit_id, name)
  values (institution_a, unit_a_one, 'Turma A1')
  returning id into group_a_one;
  insert into public.groups(institution_id, unit_id, name)
  values (institution_a, unit_a_two, 'Turma A2')
  returning id into group_a_two;
  insert into public.groups(institution_id, unit_id, name)
  values (institution_b, unit_b_one, 'Turma B1')
  returning id into group_b_one;

  insert into public.institution_memberships(person_id, institution_id, role_code)
  values (institution_manager, institution_a, 'activity_manager')
  returning id into membership_institution_manager;
  insert into public.institution_memberships(person_id, institution_id, role_code)
  values (unit_manager, institution_a, 'unit_activity_manager')
  returning id into membership_unit_manager;
  insert into public.institution_memberships(person_id, institution_id, role_code)
  values (unit_without_capability, institution_a, 'unit_without_capability')
  returning id into membership_unit_without_capability;
  insert into public.institution_memberships(person_id, institution_id, role_code)
  values (teacher_one, institution_a, 'teacher')
  returning id into membership_teacher_one;
  insert into public.institution_memberships(person_id, institution_id, role_code)
  values (teacher_two, institution_a, 'teacher')
  returning id into membership_teacher_two;
  insert into public.institution_memberships(person_id, institution_id, role_code)
  values (teacher_three, institution_a, 'teacher')
  returning id into membership_teacher_three;
  insert into public.institution_memberships(person_id, institution_id, role_code)
  values (tenant_b_manager, institution_b, 'activity_manager')
  returning id into membership_tenant_b_manager;

  insert into public.institution_roles(institution_id, code, name)
  values (institution_a, 'activity_manager', 'Gestor de atividades')
  returning id into institution_manager_role;
  insert into public.institution_roles(institution_id, code, name)
  values (institution_a, 'unit_activity_manager', 'Gestor de atividades da unidade')
  returning id into unit_manager_role;
  insert into public.institution_roles(institution_id, code, name)
  values (institution_b, 'activity_manager', 'Gestor de atividades')
  returning id into tenant_b_manager_role;

  insert into public.institution_role_permissions(role_id, permission_id)
  select institution_manager_role, permission_record.id
  from public.institution_permissions permission_record
  where permission_record.code like 'activities.%';

  insert into public.institution_role_permissions(role_id, permission_id)
  select unit_manager_role, permission_record.id
  from public.institution_permissions permission_record
  where permission_record.code in (
    'activities.read',
    'activities.create',
    'activities.link_groups',
    'activities.assign_people',
    'activities.manage_permissions'
  );

  insert into public.institution_role_permissions(role_id, permission_id)
  select tenant_b_manager_role, permission_record.id
  from public.institution_permissions permission_record
  where permission_record.code like 'activities.%';

  insert into public.institution_role_assignments(
    membership_id, role_id, scope_kind
  ) values (
    membership_institution_manager, institution_manager_role, 'institution'
  );

  insert into public.institution_role_assignments(
    membership_id, role_id, scope_kind, scope_unit_id
  ) values (
    membership_unit_manager, unit_manager_role, 'unit', unit_a_one
  );

  insert into public.institution_role_assignments(
    membership_id, role_id, scope_kind
  ) values (
    membership_tenant_b_manager, tenant_b_manager_role, 'institution'
  );

  -- 1. An authorized institution actor creates an activity.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_institution_manager::text, true);
  select created.id
  into institutional_activity
  from public.create_activity_for_institution(
    institution_a,
    unit_a_one,
    'Musica',
    'Atividade institucional reutilizavel.',
    'Teste de criacao institucional.'
  ) created;
  execute 'reset role';

  if institutional_activity is null then
    raise exception 'authorized institution actor did not create an activity';
  end if;

  -- 2. An authorized unit actor creates an activity with server-derived institution.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_unit_manager::text, true);
  select created.id
  into unit_activity
  from public.create_activity_for_unit(
    unit_a_one,
    'Capoeira',
    'Atividade criada pela unidade.',
    'Teste de criacao delegada.'
  ) created;
  execute 'reset role';

  if not exists (
    select 1
    from public.activity_definitions activity
    join public.activity_unit_links unit_link
      on unit_link.activity_id = activity.id
     and unit_link.unit_id = unit_a_one
     and unit_link.status = 'active'
    where activity.id = unit_activity
      and activity.institution_id = institution_a
      and activity.origin_scope_kind = 'unit'
      and activity.origin_unit_id = unit_a_one
  ) then
    raise exception 'unit-created activity did not inherit institution and origin unit';
  end if;

  -- 3. A unit actor without the explicit capability is denied.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_unit_without_capability::text, true);
  begin
    perform public.create_activity_for_unit(
      unit_a_one,
      'Atividade negada',
      null,
      'Teste sem capacidade.'
    );
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  execute 'reset role';
  if not rejected then
    raise exception 'unit without activities.create was allowed to create';
  end if;

  -- 4. An activity cannot be committed without an active unit link.
  begin
    insert into public.activity_definitions(
      institution_id,
      name,
      origin_scope_kind,
      created_by_person_id
    ) values (
      institution_a,
      'Sem unidade',
      'institution',
      institution_manager
    );
    set constraints all immediate;
    rejected := false;
  exception when check_violation then
    rejected := true;
  end;
  set constraints all deferred;
  if not rejected then
    raise exception 'activity without a unit link was accepted';
  end if;

  -- 5. Unit creation cannot target another institution.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_unit_manager::text, true);
  begin
    perform public.create_activity_for_unit(
      unit_b_one,
      'Cross tenant',
      null,
      'Teste cross tenant.'
    );
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  execute 'reset role';
  if not rejected then
    raise exception 'unit actor created an activity in another institution';
  end if;

  -- Create a tenant B activity for isolation assertions.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_tenant_b_manager::text, true);
  select created.id
  into tenant_b_activity
  from public.create_activity_for_institution(
    institution_b,
    unit_b_one,
    'Atividade B',
    null,
    'Teste tenant B.'
  ) created;
  execute 'reset role';

  -- Institution authority expands a unit-created activity to a sibling unit.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_institution_manager::text, true);
  insert into public.activity_unit_links(
    activity_id, institution_id, unit_id, linked_by_person_id
  ) values (
    unit_activity, institution_a, unit_a_two, institution_manager
  );
  execute 'reset role';

  -- 6. A unit-scoped actor does not automatically see the sibling unit link.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_unit_manager::text, true);
  select count(*) into visible_count
  from public.activity_unit_links
  where activity_id = unit_activity;
  execute 'reset role';
  if visible_count <> 1 then
    raise exception 'unit-scoped actor saw % unit links instead of 1', visible_count;
  end if;

  -- 7. Institution authority can edit and deactivate an activity created by a unit.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_institution_manager::text, true);
  update public.activity_definitions
  set description = 'Atualizada pela instituicao.',
      status = 'inactive'
  where id = unit_activity;
  execute 'reset role';
  if not exists (
    select 1 from public.activity_definitions
    where id = unit_activity
      and status = 'inactive'
      and description = 'Atualizada pela instituicao.'
  ) then
    raise exception 'institution did not update a unit-created activity';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_institution_manager::text, true);
  update public.activity_definitions
  set status = 'active'
  where id = unit_activity;

  -- 8. Link the same activity to two groups in the same institution.
  insert into public.activity_group_links(
    activity_id, institution_id, unit_id, group_id, linked_by_person_id
  ) values (
    institutional_activity, institution_a, unit_a_one, group_a_one, institution_manager
  ) returning id into group_link_one;

  insert into public.activity_unit_links(
    activity_id, institution_id, unit_id, linked_by_person_id
  ) values (
    institutional_activity, institution_a, unit_a_two, institution_manager
  ) on conflict (activity_id, unit_id) do nothing;

  insert into public.activity_group_links(
    activity_id, institution_id, unit_id, group_id, linked_by_person_id
  ) values (
    institutional_activity, institution_a, unit_a_two, group_a_two, institution_manager
  ) returning id into group_link_two;

  -- 9. A group from another institution is rejected.
  begin
    insert into public.activity_group_links(
      activity_id, institution_id, unit_id, group_id, linked_by_person_id
    ) values (
      institutional_activity, institution_a, unit_b_one, group_b_one, institution_manager
    );
    rejected := false;
  exception when foreign_key_violation or check_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'cross-institution activity-group link was accepted';
  end if;

  -- 10. Different teachers can be assigned in different groups.
  insert into public.activity_group_assignments(
    activity_group_link_id,
    institution_id,
    person_id,
    membership_id,
    assignment_role,
    assigned_by_person_id
  ) values (
    group_link_one,
    institution_a,
    teacher_one,
    membership_teacher_one,
    'teacher',
    institution_manager
  ) returning id into assignment_teacher_one;

  insert into public.activity_group_assignments(
    activity_group_link_id,
    institution_id,
    person_id,
    membership_id,
    assignment_role,
    assigned_by_person_id
  ) values (
    group_link_two,
    institution_a,
    teacher_two,
    membership_teacher_two,
    'teacher',
    institution_manager
  );

  -- 11. Two teachers can be assigned to the same activity and group.
  insert into public.activity_group_assignments(
    activity_group_link_id,
    institution_id,
    person_id,
    membership_id,
    assignment_role,
    assigned_by_person_id
  ) values (
    group_link_one,
    institution_a,
    teacher_three,
    membership_teacher_three,
    'teacher',
    institution_manager
  );

  if (
    select count(*)
    from public.activity_group_assignments
    where activity_group_link_id = group_link_one
      and assignment_role = 'teacher'
      and status = 'active'
  ) <> 2 then
    raise exception 'same group did not retain two teachers';
  end if;

  -- Configure a reusable profile and an assignment-specific override.
  insert into public.activity_permission_profiles(
    institution_id,
    scope_kind,
    code,
    name,
    created_by_person_id
  ) values (
    institution_a,
    'institution',
    'teacher_default',
    'Professor padrao',
    institution_manager
  ) returning id into profile_id;

  insert into public.activity_permission_profile_capabilities(
    profile_id, capability_id, effect, changed_by_person_id
  )
  select profile_id, capability.id, 'allow', institution_manager
  from public.activity_capabilities capability
  where capability.code in ('conversation', 'attendance');

  update public.activity_group_links
  set permission_profile_id = profile_id
  where id in (group_link_one, group_link_two);

  insert into public.activity_assignment_permission_overrides(
    assignment_id, capability_id, effect, changed_by_person_id
  )
  select assignment_teacher_one, capability.id, 'allow', institution_manager
  from public.activity_capabilities capability
  where capability.code = 'media_now';
  execute 'reset role';

  -- 12. A teacher sees only the activity-group context assigned to them.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', auth_teacher_one::text, true);
  select count(*) into visible_count
  from public.activity_group_links
  where activity_id = institutional_activity;
  if visible_count <> 1 then
    raise exception 'teacher saw % activity-group links instead of 1', visible_count;
  end if;

  select count(*) into visible_count
  from public.activity_group_assignments
  where person_id = teacher_one;
  if visible_count <> 1 then
    raise exception 'teacher saw assignments outside their own context';
  end if;

  -- 13. An override never grants access outside an existing assignment.
  if not app_private.has_activity_capability(
    institutional_activity,
    group_a_one,
    'media_now'
  ) then
    raise exception 'valid assignment override was not effective';
  end if;

  if app_private.has_activity_capability(
    institutional_activity,
    group_a_two,
    'media_now'
  ) then
    raise exception 'override granted access outside the teacher assignment';
  end if;

  -- 14. RLS blocks cross-tenant reads and commands.
  select count(*) into visible_count
  from public.activity_definitions
  where id = tenant_b_activity;
  if visible_count <> 0 then
    raise exception 'teacher read a cross-tenant activity';
  end if;

  begin
    update public.activity_definitions
    set name = 'Cross tenant update'
    where id = tenant_b_activity;
    if found then
      rejected := false;
    else
      rejected := true;
    end if;
  exception when insufficient_privilege then
    rejected := true;
  end;
  execute 'reset role';
  if not rejected then
    raise exception 'teacher updated a cross-tenant activity';
  end if;

  if not exists (
    select 1
    from audit.audit_logs
    where institution_id = institution_a
      and object_type in (
        'activity_definitions',
        'activity_unit_links',
        'activity_group_links',
        'activity_group_assignments',
        'activity_permission_profiles',
        'activity_assignment_permission_overrides'
      )
  ) then
    raise exception 'sensitive activity changes were not audited';
  end if;
end
$$;

rollback;
