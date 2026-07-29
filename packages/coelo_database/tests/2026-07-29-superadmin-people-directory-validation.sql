-- Transactional behavior validation for the Superadmin people directory.
-- The test creates synthetic rows only inside this transaction and rolls back.

begin;

do $$
#variable_conflict use_variable
declare
  owner_person_id uuid;
  owner_auth_id uuid := gen_random_uuid();
  owner_role_id uuid;
  unauthorized_person_id uuid;
  unauthorized_auth_id uuid := gen_random_uuid();
  unauthorized_platform_membership_id uuid;
  operations_role_id uuid;
  teacher_role_id uuid;
  institution_type_id uuid;
  institution_a_id uuid;
  institution_b_id uuid;
  unit_a_id uuid;
  unit_b_id uuid;
  group_a_id uuid;
  group_a_second_id uuid;
  group_b_id uuid;
  coordinator_role_id uuid;
  created_person_id uuid;
  created_updated_at timestamptz;
  created_membership_id uuid;
  first_assignment_id uuid;
  second_assignment_id uuid;
  child_person_id uuid;
  child_updated_at timestamptz;
  child_context_id uuid;
  child_unit_link_id uuid;
  child_group_link_id uuid;
  child_context_b_id uuid;
  child_unit_link_b_id uuid;
  child_group_link_b_id uuid;
  guardian_link_id uuid;
  guardian_permission_id uuid;
  service_person_id uuid;
  permission_probe_person_id uuid;
  permission_probe_updated_at timestamptz;
  sort_key text;
  sort_ascending boolean;
  permission_code text;
  observed_order text[];
  expected_order text[];
  result jsonb;
  rejected boolean;
begin
  insert into auth.users(id, aud, role, email, created_at, updated_at)
  values
    (
      owner_auth_id, 'authenticated', 'authenticated',
      'owner-people-directory@example.invalid', now(), now()
    ),
    (
      unauthorized_auth_id, 'authenticated', 'authenticated',
      'operations-people-directory@example.invalid', now(), now()
    );

  insert into public.people(
    person_type, first_name, last_name, display_name, status
  ) values (
    'adult', 'Owner', 'Diretorio', 'Owner Diretorio', 'active'
  ) returning id into owner_person_id;

  insert into public.person_auth_links(person_id, auth_user_id)
  values (owner_person_id, owner_auth_id);

  insert into public.people(
    person_type, first_name, last_name, display_name, status
  ) values (
    'adult', 'Operacoes', 'Sem Pessoas', 'Operacoes Sem Pessoas', 'active'
  ) returning id into unauthorized_person_id;

  insert into public.people(
    person_type, first_name, last_name, display_name, status
  ) values (
    'service', 'Servico', 'Somente Leitura', 'Servico Somente Leitura', 'active'
  ) returning id into service_person_id;

  insert into public.person_auth_links(person_id, auth_user_id)
  values (unauthorized_person_id, unauthorized_auth_id);

  select id into owner_role_id
  from public.platform_roles
  where code = 'owner';

  insert into public.platform_memberships(person_id, role_id, status)
  values (owner_person_id, owner_role_id, 'active');

  select id into operations_role_id
  from public.platform_roles
  where code = 'operations';

  insert into public.platform_memberships(person_id, role_id, status)
  values (unauthorized_person_id, operations_role_id, 'active')
  returning id into unauthorized_platform_membership_id;

  insert into public.institution_types(code, name)
  values ('people-directory-test', 'Tipo teste de pessoas')
  returning id into institution_type_id;

  insert into public.institutions(public_name, legal_name, slug)
  values (
    'Instituicao Teste A',
    'Instituicao Teste A',
    'people-directory-test-a'
  )
  returning id into institution_a_id;

  insert into public.institutions(public_name, legal_name, slug)
  values (
    'Instituicao Teste B',
    'Instituicao Teste B',
    'people-directory-test-b'
  )
  returning id into institution_b_id;

  insert into public.units(institution_id, name, slug, institution_type_id)
  values (
    institution_a_id,
    'Unidade A',
    'people-directory-unit-a',
    institution_type_id
  )
  returning id into unit_a_id;

  insert into public.units(institution_id, name, slug, institution_type_id)
  values (
    institution_b_id,
    'Unidade B',
    'people-directory-unit-b',
    institution_type_id
  )
  returning id into unit_b_id;

  insert into public.institution_roles(institution_id, code, name)
  values (institution_a_id, 'teacher', 'Professor')
  returning id into teacher_role_id;

  insert into public.institution_roles(institution_id, code, name)
  values (institution_a_id, 'coordinator', 'Coordenador')
  returning id into coordinator_role_id;

  insert into public.groups(institution_id, unit_id, name)
  values (institution_a_id, unit_a_id, 'Grupo A')
  returning id into group_a_id;

  insert into public.groups(institution_id, unit_id, name)
  values (institution_a_id, unit_a_id, 'Grupo A Segundo')
  returning id into group_a_second_id;

  insert into public.groups(institution_id, unit_id, name)
  values (institution_b_id, unit_b_id, 'Grupo B')
  returning id into group_b_id;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', unauthorized_auth_id::text, true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', unauthorized_auth_id, 'aal', 'aal2')::text,
    true
  );
  begin
    perform public.superadmin_people_list();
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  if not rejected then
    raise exception 'platform.read unexpectedly authorized people directory';
  end if;
  if (select count(*) from public.people) <> 1 then
    raise exception 'people RLS exposed identities beyond the current person';
  end if;

  execute 'reset role';
  insert into public.platform_member_permission_overrides(
    membership_id,
    permission_id,
    effect,
    status
  )
  select
    unauthorized_platform_membership_id,
    permission.id,
    'allow',
    'active'
  from public.platform_permissions permission
  where permission.code = 'people.read';

  execute 'set local role authenticated';
  result := public.superadmin_people_list();
  if (result ->> 'total_count')::integer < 3 then
    raise exception 'independent people.read did not authorize list';
  end if;
  if (select count(*) from public.people) <> 1
     or (select count(*) from public.institution_memberships) <> 0
     or (select count(*) from public.child_contexts) <> 0 then
    raise exception 'AAL2 people.read enumerated direct identity tables';
  end if;
  perform public.superadmin_people_filter_options();
  perform public.superadmin_people_detail(service_person_id);
  begin
    perform public.superadmin_people_create_draft(jsonb_build_object(
      'type', 'adult',
      'first_name', 'Leitura',
      'last_name', 'Somente',
      'display_name', 'Leitura Somente'
    ));
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  if not rejected then
    raise exception 'people.read unexpectedly granted people.create';
  end if;

  execute 'reset role';
  delete from public.platform_member_permission_overrides
  where membership_id = unauthorized_platform_membership_id;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', owner_auth_id::text, true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', owner_auth_id, 'aal', 'aal1')::text,
    true
  );
  begin
    perform public.superadmin_people_list();
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  if not rejected then
    raise exception 'people.read accepted an AAL1 session';
  end if;
  if (select count(*) from public.people) <> 1 then
    raise exception 'AAL1 direct people SELECT enumerated identities';
  end if;
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', owner_auth_id, 'aal', 'aal2')::text,
    true
  );
  if (select count(*) from public.people) <> 1 then
    raise exception 'AAL2 direct people SELECT enumerated identities';
  end if;

  result := public.superadmin_people_filter_options();
  if jsonb_array_length(result -> 'institutions') < 2
     or not ((result -> 'units' -> 0) ? 'institution_id')
     or not ((result -> 'groups' -> 0) ? 'unit_id')
     or not ((result -> 'roles' -> 0) ? 'institution_id') then
    raise exception 'dependent filter option parents are incomplete';
  end if;

  result := public.superadmin_people_create_draft(
    jsonb_build_object(
      'type', 'adult',
      'first_name', 'Pessoa',
      'last_name', 'Teste',
      'display_name', 'Pessoa Teste',
      'memberships', jsonb_build_array(jsonb_build_object(
        'institution_id', institution_a_id,
        'role', 'teacher'
      ))
    )
  );
  created_person_id := (result ->> 'id')::uuid;
  created_updated_at := (result ->> 'updated_at')::timestamptz;

  if (result ->> 'status') <> 'draft' then
    raise exception 'created person is not draft';
  end if;
  execute 'reset role';
  if exists (
    select 1 from public.person_auth_links where person_id = created_person_id
  ) then
    raise exception 'draft creation unexpectedly activated Auth';
  end if;
  if not exists (
    select 1 from public.institution_memberships
    where person_id = created_person_id
      and institution_id = institution_a_id
      and role_code = 'teacher'
  ) then
    raise exception 'adult membership was not created';
  end if;
  if not exists (
    select 1
    from public.institution_role_assignments assignment
    join public.institution_memberships membership
      on membership.id = assignment.membership_id
    where membership.person_id = created_person_id
      and assignment.role_id = teacher_role_id
      and assignment.status = 'active'
  ) then
    raise exception 'canonical contextual role assignment was not created';
  end if;
  select membership.id, assignment.id
  into created_membership_id, first_assignment_id
  from public.institution_memberships membership
  join public.institution_role_assignments assignment
    on assignment.membership_id = membership.id
  where membership.person_id = created_person_id
    and assignment.role_id = teacher_role_id
    and assignment.status = 'active';
  execute 'set local role authenticated';

  result := public.superadmin_people_list(
    'Pessoa Teste', array['adult']::public.person_type[],
    array['draft']::public.record_status[],
    array[institution_a_id], array[]::uuid[], array[]::uuid[],
    array['teacher'], array['unlinked'], 'display_name', true, 0, 11
  );
  if (result ->> 'total_count')::integer <> 1 then
    raise exception 'authorized directory filters did not isolate the person';
  end if;

  result := public.superadmin_people_detail(created_person_id);
  if result ->> 'auth_link' <> 'unlinked'
     or jsonb_array_length(result -> 'memberships') <> 1 then
    raise exception 'detail summary is incomplete';
  end if;
  if not ((result -> 'memberships' -> 0) ? 'assignment_id')
     or not ((result -> 'memberships' -> 0) ? 'membership_id') then
    raise exception 'detail does not expose assignment and membership ids';
  end if;
  result := public.superadmin_people_detail(service_person_id);
  if result ->> 'type' <> 'service' then
    raise exception 'service person is not readable';
  end if;
  begin
    perform public.superadmin_people_create_draft(jsonb_build_object(
      'type', 'service',
      'display_name', 'Servico Indevido',
      'first_name', 'Servico',
      'last_name', 'Indevido'
    ));
    rejected := false;
  exception when invalid_parameter_value then
    rejected := true;
  end;
  if not rejected then
    raise exception 'service creation was accepted';
  end if;
  begin
    perform public.superadmin_people_update(jsonb_build_object(
      'person_id', service_person_id,
      'expected_updated_at', result ->> 'updated_at',
      'display_name', 'Servico Editado'
    ));
    rejected := false;
  exception when invalid_parameter_value then
    rejected := true;
  end;
  if not rejected then
    raise exception 'service update was accepted';
  end if;

  foreach sort_key in array array[
    'display_name', 'type', 'status', 'institution_name', 'unit_name',
    'group_name', 'contextual_role', 'auth_link'
  ]
  loop
    foreach sort_ascending in array array[true, false]
    loop
      result := public.superadmin_people_list(
        '', array[]::public.person_type[], array[]::public.record_status[],
        array[]::uuid[], array[]::uuid[], array[]::uuid[],
        array[]::text[], array[]::text[],
        sort_key, sort_ascending, 0, 11
      );
      if jsonb_typeof(result -> 'items') <> 'array' then
        raise exception 'sort % direction % returned invalid items',
          sort_key, sort_ascending;
      end if;
      select array_agg(row_data.item ->> 'id' order by row_data.ordinality)
      into observed_order
      from jsonb_array_elements(result -> 'items')
        with ordinality row_data(item, ordinality);
      select array_agg(
        sortable.item ->> 'id'
        order by
          case when sort_ascending then sortable.sort_value end asc,
          case when not sort_ascending then sortable.sort_value end desc,
          lower(sortable.item ->> 'display_name'),
          sortable.item ->> 'id'
      )
      into expected_order
      from (
        select
          row_data.item,
          case sort_key
            when 'display_name'
              then lower(row_data.item ->> 'display_name')
            when 'type' then row_data.item ->> 'type'
            when 'status' then row_data.item ->> 'status'
            when 'institution_name' then coalesce((
              select min(lower(membership ->> 'institution_name'))
              from jsonb_array_elements(
                row_data.item -> 'memberships'
              ) membership
            ), '')
            when 'unit_name' then coalesce((
              select min(lower(membership ->> 'unit_name'))
              from jsonb_array_elements(
                row_data.item -> 'memberships'
              ) membership
            ), '')
            when 'group_name' then coalesce((
              select min(lower(membership ->> 'group_name'))
              from jsonb_array_elements(
                row_data.item -> 'memberships'
              ) membership
            ), '')
            when 'contextual_role' then coalesce((
              select min(lower(membership ->> 'role_name'))
              from jsonb_array_elements(
                row_data.item -> 'memberships'
              ) membership
            ), '')
            when 'auth_link' then row_data.item ->> 'auth_link'
          end as sort_value
        from jsonb_array_elements(result -> 'items')
          with ordinality row_data(item, ordinality)
      ) sortable;
      if observed_order is distinct from expected_order then
        raise exception 'sort % direction % returned unexpected order',
          sort_key, sort_ascending;
      end if;
      if result <> public.superadmin_people_list(
        '', array[]::public.person_type[], array[]::public.record_status[],
        array[]::uuid[], array[]::uuid[], array[]::uuid[],
        array[]::text[], array[]::text[],
        sort_key, sort_ascending, 0, 11
      ) then
        raise exception 'sort % direction % is not deterministic',
          sort_key, sort_ascending;
      end if;
      if exists (
        select 1
        from jsonb_array_elements(result -> 'items') item
        where item ?| array[
          'first_name', 'last_name', 'legal_name',
          'platform_membership_summary', 'guardian_links_summary',
          'child_contexts'
        ]
      ) then
        raise exception 'list exposed detail-only identity fields';
      end if;
    end loop;
  end loop;

  result := public.superadmin_people_update(
    jsonb_build_object(
      'person_id', created_person_id,
      'expected_updated_at', created_updated_at,
      'display_name', 'Pessoa Atualizada',
      'membership_changes', '[]'::jsonb
    )
  );
  if result ->> 'display_name' <> 'Pessoa Atualizada' then
    raise exception 'approved global field was not updated';
  end if;
  created_updated_at := (result ->> 'updated_at')::timestamptz;

  execute 'reset role';
  update public.institution_role_assignments assignment
  set updated_at = clock_timestamp()
  where assignment.id = first_assignment_id;
  execute 'set local role authenticated';
  begin
    perform public.superadmin_people_update(jsonb_build_object(
      'person_id', created_person_id,
      'expected_updated_at', created_updated_at,
      'display_name', 'Concorrencia Externa'
    ));
    rejected := false;
  exception when serialization_failure then
    rejected := true;
  end;
  if not rejected then
    raise exception 'external context mutation did not invalidate person timestamp';
  end if;
  result := public.superadmin_people_detail(created_person_id);

  result := public.superadmin_people_update(jsonb_build_object(
    'person_id', created_person_id,
    'expected_updated_at', result ->> 'updated_at',
    'display_name', 'Pessoa Atualizada',
    'context_changes', jsonb_build_array(jsonb_build_object(
      'kind', 'institution_membership',
      'operation', 'add',
      'membership_id', created_membership_id,
      'institution_id', institution_a_id,
      'role_code', 'coordinator'
    ))
  ));
  execute 'reset role';
  select assignment.id
  into second_assignment_id
  from public.institution_role_assignments assignment
  where assignment.membership_id = created_membership_id
    and assignment.role_id = coordinator_role_id
    and assignment.status = 'active';
  execute 'set local role authenticated';

  result := public.superadmin_people_update(jsonb_build_object(
    'person_id', created_person_id,
    'expected_updated_at', result ->> 'updated_at',
    'display_name', 'Pessoa Atualizada',
    'context_changes', jsonb_build_array(jsonb_build_object(
      'kind', 'institution_membership',
      'operation', 'update',
      'membership_id', created_membership_id,
      'assignment_id', first_assignment_id,
      'scope_unit_id', unit_a_id,
      'role_code', 'teacher'
    ))
  ));
  execute 'reset role';
  if not exists (
    select 1
    from public.institution_role_assignments assignment
    where assignment.id = first_assignment_id
      and assignment.scope_unit_id = unit_a_id
      and assignment.status = 'active'
  ) or not exists (
    select 1
    from public.institution_role_assignments assignment
    where assignment.id = second_assignment_id
      and assignment.role_id = coordinator_role_id
      and assignment.scope_unit_id is null
      and assignment.status = 'active'
  ) then
    raise exception 'adult assignment update overwrote an unrelated role';
  end if;
  execute 'set local role authenticated';

  result := public.superadmin_people_update(jsonb_build_object(
    'person_id', created_person_id,
    'expected_updated_at', result ->> 'updated_at',
    'display_name', 'Pessoa Atualizada',
    'context_changes', jsonb_build_array(jsonb_build_object(
      'kind', 'institution_membership',
      'operation', 'revoke',
      'membership_id', created_membership_id,
      'assignment_id', first_assignment_id
    ))
  ));
  execute 'reset role';
  if (
    select status <> 'active' or revoked_at is not null
    from public.institution_memberships
    where id = created_membership_id
  ) then
    raise exception 'membership was revoked while another assignment remained';
  end if;
  if (
    select status <> 'inactive'
    from public.institution_role_assignments
    where id = first_assignment_id
  ) then
    raise exception 'target adult assignment was not revoked';
  end if;
  execute 'set local role authenticated';

  begin
    perform public.superadmin_people_update(
      jsonb_build_object(
        'person_id', created_person_id,
        'expected_updated_at', created_updated_at,
        'display_name', 'Conflito'
      )
    );
    rejected := false;
  exception when serialization_failure then
    rejected := true;
  end;
  if not rejected then
    raise exception 'stale concurrent update was accepted';
  end if;

  begin
    perform public.superadmin_people_update(
      jsonb_build_object(
        'person_id', created_person_id,
        'expected_updated_at', result ->> 'updated_at',
        'display_name', 'Pessoa Atualizada',
        'date_of_birth', '2000-01-01'
      )
    );
    rejected := false;
  exception when invalid_parameter_value then
    rejected := true;
  end;
  if not rejected then
    raise exception 'unapproved identity field was accepted';
  end if;

  begin
    perform public.superadmin_people_update(
      jsonb_build_object(
        'person_id', created_person_id,
        'expected_updated_at', result ->> 'updated_at',
        'display_name', 'Pessoa Atualizada',
        'membership_changes', jsonb_build_array(jsonb_build_object(
          'operation', 'add',
          'institution_id', institution_a_id,
          'unit_id', unit_b_id,
          'role', 'teacher'
        ))
      )
    );
    rejected := false;
  exception when check_violation or foreign_key_violation then
    rejected := true;
  end;
  if not rejected then
    raise exception 'cross-tenant membership scope was accepted';
  end if;

  result := public.superadmin_people_create_draft(jsonb_build_object(
    'type', 'child',
    'first_name', 'Crianca',
    'last_name', 'Teste',
    'display_name', 'Crianca Teste',
    'child_contexts', '[]'::jsonb
  ));
  child_person_id := (result ->> 'id')::uuid;
  child_updated_at := (result ->> 'updated_at')::timestamptz;
  result := public.superadmin_people_update(jsonb_build_object(
    'person_id', child_person_id,
    'expected_updated_at', child_updated_at,
    'display_name', 'Crianca Teste',
    'child_context_changes', jsonb_build_array(jsonb_build_object(
      'operation', 'add',
      'institution_id', institution_a_id,
      'unit_id', unit_a_id,
      'group_id', group_a_id,
      'role', 'student'
    ))
  ));
  execute 'reset role';
  if not exists (
    select 1
    from public.child_contexts child_context
    join public.child_unit_links unit_link
      on unit_link.child_context_id = child_context.id
    join public.child_group_links group_link
      on group_link.child_unit_link_id = unit_link.id
    where child_context.child_person_id = child_person_id
      and child_context.institution_id = institution_a_id
      and unit_link.unit_id = unit_a_id
      and group_link.group_id = group_a_id
  ) then
    raise exception 'child context update did not preserve unit and group';
  end if;
  select child_context.id, unit_link.id, group_link.id
  into child_context_id, child_unit_link_id, child_group_link_id
  from public.child_contexts child_context
  join public.child_unit_links unit_link
    on unit_link.child_context_id = child_context.id
  join public.child_group_links group_link
    on group_link.child_unit_link_id = unit_link.id
  where child_context.child_person_id = child_person_id
    and child_context.institution_id = institution_a_id
    and unit_link.unit_id = unit_a_id
    and group_link.group_id = group_a_id;
  execute 'set local role authenticated';

  result := public.superadmin_people_update(jsonb_build_object(
    'person_id', child_person_id,
    'expected_updated_at', result ->> 'updated_at',
    'display_name', 'Crianca Teste',
    'context_changes', jsonb_build_array(jsonb_build_object(
      'kind', 'child_context',
      'operation', 'update',
      'child_context_id', child_context_id,
      'child_unit_link_id', child_unit_link_id,
      'child_group_link_id', child_group_link_id,
      'unit_id', unit_a_id,
      'group_id', group_a_second_id
    ))
  ));
  execute 'reset role';
  if not exists (
    select 1
    from public.child_group_links group_link
    where group_link.id = child_group_link_id
      and group_link.group_id = group_a_second_id
      and group_link.status = 'active'
  ) then
    raise exception 'target child group link was not updated';
  end if;
  execute 'set local role authenticated';

  result := public.superadmin_people_update(jsonb_build_object(
    'person_id', child_person_id,
    'expected_updated_at', result ->> 'updated_at',
    'display_name', 'Crianca Teste',
    'context_changes', jsonb_build_array(jsonb_build_object(
      'kind', 'child_context',
      'operation', 'revoke',
      'child_context_id', child_context_id
    ))
  ));
  execute 'reset role';
  if (
    select status <> 'inactive'
    from public.child_contexts
    where id = child_context_id
  ) then
    raise exception 'child context was not revoked';
  end if;
  execute 'set local role authenticated';
  result := public.superadmin_people_detail(child_person_id);
  if jsonb_array_length(result -> 'child_contexts') <> 0 then
    raise exception 'detail exposed revoked child context or links';
  end if;

  result := public.superadmin_people_update(jsonb_build_object(
    'person_id', child_person_id,
    'expected_updated_at', result ->> 'updated_at',
    'display_name', 'Crianca Teste',
    'child_context_changes', jsonb_build_array(jsonb_build_object(
      'operation', 'add',
      'institution_id', institution_a_id,
      'unit_id', unit_a_id,
      'group_id', group_a_second_id
    ))
  ));
  execute 'reset role';
  if not exists (
    select 1
    from public.child_contexts child_context
    join public.child_unit_links unit_link
      on unit_link.child_context_id = child_context.id
    join public.child_group_links group_link
      on group_link.child_unit_link_id = unit_link.id
    where child_context.id = child_context_id
      and child_context.status = 'active'
      and unit_link.id = child_unit_link_id
      and unit_link.status = 'pending'
      and unit_link.revoked_at is null
      and group_link.id = child_group_link_id
      and group_link.status = 'active'
  ) then
    raise exception 'child add did not reactivate canonical context/link ids';
  end if;
  execute 'set local role authenticated';
  if (result -> 'child_contexts' -> 0 ->> 'child_unit_link_id')::uuid
       <> child_unit_link_id
     or (result -> 'child_contexts' -> 0 ->> 'child_group_link_id')::uuid
       <> child_group_link_id then
    raise exception 'detail did not preserve child link ids';
  end if;

  execute 'reset role';
  insert into public.child_contexts(child_person_id, institution_id)
  values (child_person_id, institution_b_id)
  returning id into child_context_b_id;
  insert into public.child_unit_links(child_context_id, unit_id, status)
  values (child_context_b_id, unit_b_id, 'pending')
  returning id into child_unit_link_b_id;
  insert into public.child_group_links(child_unit_link_id, group_id, status)
  values (child_unit_link_b_id, group_b_id, 'active')
  returning id into child_group_link_b_id;
  insert into public.guardian_links(
    guardian_person_id,
    child_person_id,
    relation_type,
    status
  )
  values (owner_person_id, child_person_id, 'guardian', 'active')
  returning id into guardian_link_id;
  insert into public.guardian_context_permissions(
    guardian_link_id,
    child_context_id,
    can_view,
    status
  )
  values (guardian_link_id, child_context_id, true, 'active')
  returning id into guardian_permission_id;

  execute 'set local role authenticated';
  if (
    select count(*)
    from public.child_contexts child_context
    where child_context.id in (child_context_id, child_context_b_id)
  ) <> 1 or exists (
    select 1
    from public.child_contexts
    where id = child_context_b_id
  ) then
    raise exception 'guardian context permission crossed institution scope';
  end if;
  if exists (
    select 1
    from public.child_unit_links
    where id = child_unit_link_b_id
  ) or exists (
    select 1
    from public.child_group_links
    where id = child_group_link_b_id
  ) then
    raise exception 'guardian permission leaked cross-context child links';
  end if;
  if not exists (
    select 1 from public.child_unit_links
    where id = child_unit_link_id
  ) or not exists (
    select 1 from public.child_group_links
    where id = child_group_link_id
  ) then
    raise exception 'guardian context did not expose authorized child links';
  end if;

  execute 'reset role';
  update public.guardian_context_permissions permission
  set can_view = false, updated_at = clock_timestamp()
  where permission.id = guardian_permission_id;
  execute 'set local role authenticated';
  if exists (
    select 1 from public.child_contexts where id = child_context_id
  ) or exists (
    select 1 from public.child_unit_links where id = child_unit_link_id
  ) or exists (
    select 1 from public.child_group_links where id = child_group_link_id
  ) then
    raise exception 'guardian can_view=false still exposed child context';
  end if;
  execute 'reset role';
  update public.guardian_context_permissions permission
  set
    can_view = true,
    expires_at = clock_timestamp() - interval '1 minute',
    updated_at = clock_timestamp()
  where permission.id = guardian_permission_id;
  execute 'set local role authenticated';
  if exists (
    select 1 from public.child_contexts where id = child_context_id
  ) then
    raise exception 'expired guardian context permission still exposed context';
  end if;

  execute 'reset role';
  if not exists (
    select 1 from audit.audit_logs
    where object_type = 'people'
      and object_id = created_person_id
      and action_code in ('people.create_draft', 'people.update')
      and before_json is null
      and after_json ? 'changed_fields'
      and not (after_json ? 'first_name')
      and not (after_json ? 'last_name')
      and not (after_json ? 'display_name')
  ) then
    raise exception 'minimized people audit evidence is missing';
  end if;
  if not exists (
    select 1 from audit.audit_logs
    where actor_person_id = owner_person_id
      and action_code like 'people.%context.%'
      and institution_id = institution_a_id
      and after_json ? 'operation'
      and not (after_json ? 'display_name')
  ) then
    raise exception 'minimized context-change audit evidence is missing';
  end if;
  if not exists (
    select 1
    from audit.audit_logs
    where action_code = 'people.membership.context.add'
      and object_type = 'institution_role_assignments'
      and object_id = first_assignment_id
      and institution_id = institution_a_id
      and after_json = jsonb_build_object(
        'operation', 'add',
        'changed_fields', jsonb_build_array('role', 'scope')
      )
  ) then
    raise exception 'draft creation lacks individual minimized binding audit';
  end if;

  execute 'reset role';
  insert into public.platform_member_permission_overrides(
    membership_id, permission_id, effect, status
  )
  select unauthorized_platform_membership_id, permission.id, 'allow', 'active'
  from public.platform_permissions permission
  where permission.code = 'people.create';
  perform set_config('request.jwt.claim.sub', unauthorized_auth_id::text, true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', unauthorized_auth_id, 'aal', 'aal2')::text,
    true
  );
  execute 'set local role authenticated';
  result := public.superadmin_people_create_draft(jsonb_build_object(
    'type', 'adult',
    'first_name', 'Permissao',
    'last_name', 'Criar',
    'display_name', 'Permissao Criar'
  ));
  permission_probe_person_id := (result ->> 'id')::uuid;
  permission_probe_updated_at := (result ->> 'updated_at')::timestamptz;
  begin
    perform public.superadmin_people_list();
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  if not rejected then
    raise exception 'people.create unexpectedly granted people.read';
  end if;

  execute 'reset role';
  delete from public.platform_member_permission_overrides
  where membership_id = unauthorized_platform_membership_id;
  insert into public.platform_member_permission_overrides(
    membership_id, permission_id, effect, status
  )
  select unauthorized_platform_membership_id, permission.id, 'allow', 'active'
  from public.platform_permissions permission
  where permission.code = 'people.update';
  execute 'set local role authenticated';
  result := public.superadmin_people_update(jsonb_build_object(
    'person_id', permission_probe_person_id,
    'expected_updated_at', permission_probe_updated_at,
    'display_name', 'Permissao Atualizar'
  ));
  if result ->> 'display_name' <> 'Permissao Atualizar' then
    raise exception 'independent people.update did not update identity';
  end if;

  foreach permission_code in array array[
    'people.memberships.manage', 'people.child_contexts.manage'
  ]
  loop
    execute 'reset role';
    delete from public.platform_member_permission_overrides
    where membership_id = unauthorized_platform_membership_id;
    insert into public.platform_member_permission_overrides(
      membership_id, permission_id, effect, status
    )
    select
      unauthorized_platform_membership_id,
      permission.id,
      'allow',
      'active'
    from public.platform_permissions permission
    where permission.code = permission_code;
    execute 'set local role authenticated';
    begin
      perform public.superadmin_people_update(jsonb_build_object(
        'person_id', permission_probe_person_id,
        'expected_updated_at', result ->> 'updated_at',
        'display_name', 'Gestao Isolada'
      ));
      rejected := false;
    exception when insufficient_privilege then
      rejected := true;
    end;
    if not rejected then
      raise exception '% unexpectedly granted people.update', permission_code;
    end if;
  end loop;

  execute 'reset role';
  delete from public.platform_member_permission_overrides
  where membership_id = unauthorized_platform_membership_id;
end $$;

rollback;
