-- 20260911170400_people_list_segment_v1
-- Diretorio de Pessoas: as abas Todos / Equipe institucional / Responsaveis /
-- Criancas / Perfil duplo so filtravam no repositorio de desenvolvimento; em
-- producao a aba selecionada nao mudava a lista (achado da rota real, R05).
-- Este pacote adiciona p_segment (default 'all') a superadmin_people_list,
-- filtrado no servidor (tipo, guardian_links, institution_memberships), com
-- validacao da allowlist. A assinatura antiga (12 parametros) e removida para
-- nao haver duas sobrecargas no PostgREST; chamadas sem p_segment continuam
-- validas pelo default. Corpo copiado da baseline com so essas mudancas.
drop function if exists public.superadmin_people_list(text, public.person_type[], public.record_status[], uuid[], uuid[], uuid[], text[], text[], text, boolean, integer, integer);


CREATE OR REPLACE FUNCTION "public"."superadmin_people_list"("p_search" "text" DEFAULT ''::"text", "p_types" "public"."person_type"[] DEFAULT ARRAY[]::"public"."person_type"[], "p_statuses" "public"."record_status"[] DEFAULT ARRAY[]::"public"."record_status"[], "p_institution_ids" "uuid"[] DEFAULT ARRAY[]::"uuid"[], "p_unit_ids" "uuid"[] DEFAULT ARRAY[]::"uuid"[], "p_group_ids" "uuid"[] DEFAULT ARRAY[]::"uuid"[], "p_contextual_roles" "text"[] DEFAULT ARRAY[]::"text"[], "p_auth_links" "text"[] DEFAULT ARRAY[]::"text"[], "p_sort" "text" DEFAULT 'display_name'::"text", "p_sort_ascending" boolean DEFAULT true, "p_offset" integer DEFAULT 0, "p_limit" integer DEFAULT 11, "p_segment" "text" DEFAULT 'all') RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  result jsonb;
begin
  perform app_private.assert_people_permission('people.read');
  if p_offset < 0 then
    raise invalid_parameter_value using message = 'offset must not be negative';
  end if;
  if coalesce(p_segment, 'all') not in ('all', 'institutional_team', 'guardians', 'children', 'dual_profile') then
    raise invalid_parameter_value using message = 'invalid segment';
  end if;
  if p_limit not in (8, 11, 20, 50, 100) then
    raise invalid_parameter_value using
      message = 'limit must be 8, 11, 20, 50 or 100';
  end if;
  if p_sort not in (
    'display_name', 'type', 'status', 'institution_name', 'unit_name',
    'group_name', 'contextual_role', 'auth_link'
  ) then
    raise invalid_parameter_value using message = 'unsupported people sort';
  end if;
  if exists (
    select 1
    from public.units unit
    where unit.id = any(coalesce(p_unit_ids, array[]::uuid[]))
      and cardinality(coalesce(p_institution_ids, array[]::uuid[])) > 0
      and not unit.institution_id = any(p_institution_ids)
  ) then
    raise check_violation using message = 'unit filter crosses institution selection';
  end if;
  if exists (
    select 1
    from public.groups group_row
    where group_row.id = any(coalesce(p_group_ids, array[]::uuid[]))
      and (
        (
          cardinality(coalesce(p_institution_ids, array[]::uuid[])) > 0
          and not group_row.institution_id = any(p_institution_ids)
        )
        or (
          cardinality(coalesce(p_unit_ids, array[]::uuid[])) > 0
          and not group_row.unit_id = any(p_unit_ids)
        )
      )
  ) then
    raise check_violation using message = 'group filter crosses selected context';
  end if;

  with context_rows as (
    select
      membership.person_id,
      assignment.id as row_id,
      assignment.id as assignment_id,
      membership.id as membership_id,
      null::uuid as child_context_id,
      membership.institution_id,
      institution.public_name as institution_name,
      assignment.scope_unit_id as unit_id,
      unit.name as unit_name,
      assignment.scope_group_id as group_id,
      group_row.name as group_name,
      role.code as contextual_role,
      role.name as contextual_role_name
    from public.institution_memberships membership
    join public.institution_role_assignments assignment
      on assignment.membership_id = membership.id
      and assignment.status = 'active'
    join public.institution_roles role on role.id = assignment.role_id
    join public.institutions institution
      on institution.id = membership.institution_id
    left join public.units unit on unit.id = assignment.scope_unit_id
    left join public.groups group_row on group_row.id = assignment.scope_group_id
    where membership.status = 'active'
      and membership.revoked_at is null
    union all
    select
      child_context.child_person_id,
      child_context.id,
      null::uuid,
      null::uuid,
      child_context.id,
      child_context.institution_id,
      institution.public_name,
      unit_link.unit_id,
      unit.name,
      group_link.group_id,
      group_row.name,
      'student',
      'Aluno'
    from public.child_contexts child_context
    join public.institutions institution
      on institution.id = child_context.institution_id
    left join public.child_unit_links unit_link
      on unit_link.child_context_id = child_context.id
      and unit_link.status in ('pending', 'awaiting_allocation', 'active')
      and unit_link.revoked_at is null
    left join public.units unit on unit.id = unit_link.unit_id
    left join public.child_group_links group_link
      on group_link.child_unit_link_id = unit_link.id
      and group_link.status = 'active'
    left join public.groups group_row on group_row.id = group_link.group_id
    where child_context.status = 'active'
  ),
  context_summary as (
    select
      context_row.person_id,
      min(lower(context_row.institution_name)) as institution_sort,
      min(lower(context_row.unit_name)) as unit_sort,
      min(lower(context_row.group_name)) as group_sort,
      min(lower(context_row.contextual_role_name)) as role_sort
    from context_rows context_row
    group by context_row.person_id
  ),
  filtered as (
    select
      person.id,
      person.display_name,
      person.person_type,
      person.status,
      person.updated_at,
      coalesce(context_summary.institution_sort, '') as institution_sort,
      coalesce(context_summary.unit_sort, '') as unit_sort,
      coalesce(context_summary.group_sort, '') as group_sort,
      coalesce(context_summary.role_sort, '') as role_sort,
      case
        when exists (
          select 1 from public.person_auth_links auth_link
          where auth_link.person_id = person.id
            and auth_link.status = 'active'
            and auth_link.revoked_at is null
        ) then 'linked'
        when exists (
          select 1 from public.person_auth_links auth_link
          where auth_link.person_id = person.id
            and auth_link.revoked_at is null
        ) then 'pending'
        else 'unlinked'
      end as auth_link_state
    from public.people person
    left join context_summary on context_summary.person_id = person.id
    where person.deleted_at is null
      -- Abas do diretorio (segmento): equipe institucional = membership ativa
      -- com papel institucional; responsaveis = guardian_links ativo;
      -- criancas = tipo; perfil duplo = equipe e responsavel.
      and (
        coalesce(p_segment, 'all') = 'all'
        or (p_segment = 'children' and person.person_type = 'child')
        or (p_segment = 'guardians' and exists (
          select 1 from public.guardian_links gl
          where gl.guardian_person_id = person.id and gl.status = 'active' and gl.revoked_at is null))
        or (p_segment = 'institutional_team' and exists (
          select 1 from public.institution_memberships im
          where im.person_id = person.id and im.status = 'active' and im.revoked_at is null))
        or (p_segment = 'dual_profile'
          and exists (
            select 1 from public.guardian_links gl
            where gl.guardian_person_id = person.id and gl.status = 'active' and gl.revoked_at is null)
          and exists (
            select 1 from public.institution_memberships im
            where im.person_id = person.id and im.status = 'active' and im.revoked_at is null))
      )
      and (
        nullif(btrim(coalesce(p_search, '')), '') is null
        or person.display_name ilike '%' || btrim(p_search) || '%'
      )
      and (
        cardinality(coalesce(p_types, array[]::public.person_type[])) = 0
        or person.person_type = any(p_types)
      )
      and (
        cardinality(coalesce(p_statuses, array[]::public.record_status[])) = 0
        or person.status = any(p_statuses)
      )
      and (
        cardinality(coalesce(p_auth_links, array[]::text[])) = 0
        or (
          case
            when exists (
              select 1 from public.person_auth_links auth_link
              where auth_link.person_id = person.id
                and auth_link.status = 'active'
                and auth_link.revoked_at is null
            ) then 'linked'
            when exists (
              select 1 from public.person_auth_links auth_link
              where auth_link.person_id = person.id
                and auth_link.revoked_at is null
            ) then 'pending'
            else 'unlinked'
          end
        ) = any(p_auth_links)
      )
      and (
        (
          cardinality(coalesce(p_institution_ids, array[]::uuid[])) = 0
          and cardinality(coalesce(p_unit_ids, array[]::uuid[])) = 0
          and cardinality(coalesce(p_group_ids, array[]::uuid[])) = 0
          and cardinality(coalesce(p_contextual_roles, array[]::text[])) = 0
        )
        or exists (
          select 1
          from context_rows context_row
          where context_row.person_id = person.id
            and (
              cardinality(coalesce(p_institution_ids, array[]::uuid[])) = 0
              or context_row.institution_id = any(p_institution_ids)
            )
            and (
              cardinality(coalesce(p_unit_ids, array[]::uuid[])) = 0
              or context_row.unit_id = any(p_unit_ids)
            )
            and (
              cardinality(coalesce(p_group_ids, array[]::uuid[])) = 0
              or context_row.group_id = any(p_group_ids)
            )
            and (
              cardinality(coalesce(p_contextual_roles, array[]::text[])) = 0
              or context_row.contextual_role = any(p_contextual_roles)
            )
        )
      )
  ),
  ranked as (
    select
      filtered.*,
      row_number() over (
        order by
          case when p_sort_ascending and p_sort = 'display_name'
            then lower(display_name) end asc,
          case when not p_sort_ascending and p_sort = 'display_name'
            then lower(display_name) end desc,
          case when p_sort_ascending and p_sort = 'type'
            then person_type::text end asc,
          case when not p_sort_ascending and p_sort = 'type'
            then person_type::text end desc,
          case when p_sort_ascending and p_sort = 'status'
            then status::text end asc,
          case when not p_sort_ascending and p_sort = 'status'
            then status::text end desc,
          case when p_sort_ascending and p_sort = 'institution_name'
            then institution_sort end asc,
          case when not p_sort_ascending and p_sort = 'institution_name'
            then institution_sort end desc,
          case when p_sort_ascending and p_sort = 'unit_name'
            then unit_sort end asc,
          case when not p_sort_ascending and p_sort = 'unit_name'
            then unit_sort end desc,
          case when p_sort_ascending and p_sort = 'group_name'
            then group_sort end asc,
          case when not p_sort_ascending and p_sort = 'group_name'
            then group_sort end desc,
          case when p_sort_ascending and p_sort = 'contextual_role'
            then role_sort end asc,
          case when not p_sort_ascending and p_sort = 'contextual_role'
            then role_sort end desc,
          case when p_sort_ascending and p_sort = 'auth_link'
            then auth_link_state end asc,
          case when not p_sort_ascending and p_sort = 'auth_link'
            then auth_link_state end desc,
          lower(display_name),
          id
      ) as ordinal
    from filtered
  ),
  page_rows as (
    select *
    from ranked
    where ordinal > p_offset
      and ordinal <= p_offset + p_limit
  ),
  membership_payloads as (
    select
      page_row.id as person_id,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', context_row.row_id,
            'assignment_id', context_row.assignment_id,
            'membership_id', context_row.membership_id,
            'child_context_id', context_row.child_context_id,
            'institution_id', context_row.institution_id,
            'institution_name', context_row.institution_name,
            'unit_id', context_row.unit_id,
            'unit_name', context_row.unit_name,
            'group_id', context_row.group_id,
            'group_name', context_row.group_name,
            'role', context_row.contextual_role,
            'role_name', context_row.contextual_role_name
          )
          order by
            lower(context_row.institution_name),
            lower(context_row.unit_name),
            lower(context_row.group_name),
            context_row.row_id
        ) filter (where context_row.row_id is not null),
        '[]'::jsonb
      ) as memberships
    from page_rows page_row
    left join context_rows context_row on context_row.person_id = page_row.id
    group by page_row.id
  )
  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', page_row.id,
          'display_name', page_row.display_name,
          'type', page_row.person_type,
          'status', page_row.status,
          'auth_link', page_row.auth_link_state,
          'memberships', membership_payload.memberships,
          'updated_at', page_row.updated_at
        )
        order by page_row.ordinal
      )
      from page_rows page_row
      join membership_payloads membership_payload
        on membership_payload.person_id = page_row.id
    ), '[]'::jsonb),
    'total_count', (select count(*) from filtered)
  )
  into result;
  return result;
end
$$;

ALTER FUNCTION public.superadmin_people_list(text, public.person_type[], public.record_status[], uuid[], uuid[], uuid[], text[], text[], text, boolean, integer, integer, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.superadmin_people_list(text, public.person_type[], public.record_status[], uuid[], uuid[], uuid[], text[], text[], text, boolean, integer, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.superadmin_people_list(text, public.person_type[], public.record_status[], uuid[], uuid[], uuid[], text[], text[], text, boolean, integer, integer, text) TO authenticated, service_role;
