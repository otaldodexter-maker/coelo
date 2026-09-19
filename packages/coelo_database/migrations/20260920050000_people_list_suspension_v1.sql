-- Pessoas — spec 066 §3 (lote 101): o diretório de pessoas expõe suspended_now / suspended_from /
-- suspended_until para o ⋯ "Suspender por período / Reativar". Corpo = definição de produção de
-- superadmin_people_list em 20/09/2026 + três chaves no item; nada mais muda.
begin;
CREATE OR REPLACE FUNCTION public.superadmin_people_list(p_search text DEFAULT ''::text, p_types person_type[] DEFAULT ARRAY[]::person_type[], p_statuses record_status[] DEFAULT ARRAY[]::record_status[], p_institution_ids uuid[] DEFAULT ARRAY[]::uuid[], p_unit_ids uuid[] DEFAULT ARRAY[]::uuid[], p_group_ids uuid[] DEFAULT ARRAY[]::uuid[], p_contextual_roles text[] DEFAULT ARRAY[]::text[], p_auth_links text[] DEFAULT ARRAY[]::text[], p_sort text DEFAULT 'display_name'::text, p_sort_ascending boolean DEFAULT true, p_offset integer DEFAULT 0, p_limit integer DEFAULT 11, p_segment text DEFAULT 'all'::text, p_activity_ids uuid[] DEFAULT ARRAY[]::uuid[], p_state_codes text[] DEFAULT ARRAY[]::text[], p_municipality_ids text[] DEFAULT ARRAY[]::text[], p_neighborhood_ids text[] DEFAULT ARRAY[]::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
  perform app_private.assert_people_permission('people.read');
  if p_offset < 0 then raise invalid_parameter_value using message = 'offset must not be negative'; end if;
  if p_limit not in (8,11,20,50,100) then raise invalid_parameter_value using message = 'limit must be 8, 11, 20, 50 or 100'; end if;
  if coalesce(p_segment,'all') not in ('all','institutional_team','guardians','children','dual_profile') then raise invalid_parameter_value using message = 'invalid segment'; end if;
  if p_sort not in ('display_name','type','status','institution_name','unit_name','group_name','contextual_role','auth_link') then raise invalid_parameter_value using message = 'unsupported people sort'; end if;

  -- Preserva as rejeições de contexto já expostas pelo contrato existente.
  if exists (select 1 from public.units u where u.id = any(coalesce(p_unit_ids,array[]::uuid[]))
      and cardinality(coalesce(p_institution_ids,array[]::uuid[])) > 0
      and not u.institution_id = any(p_institution_ids)) then
    raise check_violation using message = 'unit filter crosses institution selection';
  end if;
  if exists (select 1 from public.groups g where g.id = any(coalesce(p_group_ids,array[]::uuid[]))
      and ((cardinality(coalesce(p_institution_ids,array[]::uuid[])) > 0 and not g.institution_id = any(p_institution_ids))
        or (cardinality(coalesce(p_unit_ids,array[]::uuid[])) > 0 and not g.unit_id = any(p_unit_ids)))) then
    raise check_violation using message = 'group filter crosses selected context';
  end if;

  with base_context_rows as (
    -- Papel institucional vigente.
    select m.person_id, a.id row_id, m.institution_id, a.scope_unit_id unit_id,
      a.scope_group_id group_id, r.code contextual_role, r.name contextual_role_name, null::uuid activity_id
    from public.institution_memberships m
    join public.institution_role_assignments a on a.membership_id=m.id and a.status='active'
    join public.institution_roles r on r.id=a.role_id
    where m.status='active' and m.revoked_at is null
    union all
    -- Criança no contexto de unidade/grupo vigente.
    select c.child_person_id, c.id, c.institution_id, ul.unit_id, gl.group_id, 'student', 'Aluno', null::uuid
    from public.child_contexts c
    join public.child_unit_links ul on ul.child_context_id=c.id
      and ul.status in ('pending','awaiting_allocation','active') and ul.revoked_at is null
    left join public.child_group_links gl on gl.child_unit_link_id=ul.id and gl.status='active'
    where c.status='active'
    union all
    -- Profissional é elegível somente pela atribuição e vínculo de atividade ativos.
    select aga.person_id, aga.id, agl.institution_id, agl.unit_id, agl.group_id,
      aga.assignment_role, aga.assignment_role, agl.activity_id
    from public.activity_group_assignments aga
    join public.activity_group_links agl on agl.id=aga.activity_group_link_id
      and agl.institution_id=aga.institution_id and agl.status='active'
    where aga.status='active' and aga.revoked_at is null
    union all
    -- Criança: grupo/unidade ativo e participante ativo quando a atividade é selected.
    select c.child_person_id, cgl.id, agl.institution_id, agl.unit_id, agl.group_id,
      'student', 'Aluno', agl.activity_id
    from public.child_contexts c
    join public.child_unit_links cul on cul.child_context_id=c.id
      and cul.status in ('pending','awaiting_allocation','active') and cul.revoked_at is null
    join public.child_group_links cgl on cgl.child_unit_link_id=cul.id and cgl.status='active'
    join public.activity_group_links agl on agl.group_id=cgl.group_id and agl.unit_id=cul.unit_id
      and agl.institution_id=c.institution_id and agl.status='active'
    left join public.activity_group_participants agp on agp.activity_group_link_id=agl.id
      and agp.child_group_link_id=cgl.id and agp.status='active' and agp.removed_at is null
    where c.status='active' and (agl.participation_mode='all' or agp.id is not null)
  ), context_rows as (
    select b.*, coalesce(ua.state,ia.state) state_code,
      coalesce(ua.city,ia.city) municipality_id, coalesce(ua.district,ia.district) neighborhood_id,
      i.public_name institution_name, u.name unit_name, g.name group_name, b.contextual_role_name role_name,
      activity.name activity_name
    from base_context_rows b
    join public.institutions i on i.id=b.institution_id
    left join public.units u on u.id=b.unit_id and u.institution_id=b.institution_id
    left join public.groups g on g.id=b.group_id and g.unit_id=b.unit_id and g.institution_id=b.institution_id
    left join public.activity_definitions activity on activity.id=b.activity_id and activity.institution_id=b.institution_id
    left join public.unit_addresses ua on ua.unit_id=b.unit_id and ua.status='active'
    left join public.institution_addresses ia on ia.institution_id=b.institution_id and ia.status='active'
  ), filtered as (
    select p.id,p.display_name,p.person_type,p.status,p.updated_at,
      coalesce((select min(lower(c.institution_name)) from context_rows c where c.person_id=p.id),'') institution_sort,
      coalesce((select min(lower(c.unit_name)) from context_rows c where c.person_id=p.id),'') unit_sort,
      coalesce((select min(lower(c.group_name)) from context_rows c where c.person_id=p.id),'') group_sort,
      coalesce((select min(lower(c.role_name)) from context_rows c where c.person_id=p.id),'') role_sort,
      case when exists(select 1 from public.person_auth_links x where x.person_id=p.id and x.status='active' and x.revoked_at is null) then 'linked'
           when exists(select 1 from public.person_auth_links x where x.person_id=p.id and x.revoked_at is null) then 'pending' else 'unlinked' end auth_link_state
    from public.people p
    where p.deleted_at is null
      and (coalesce(p_segment,'all')='all' or (p_segment='children' and p.person_type='child')
        or (p_segment='guardians' and exists(select 1 from public.guardian_links x where x.guardian_person_id=p.id and x.status='active' and x.revoked_at is null))
        or (p_segment='institutional_team' and exists(select 1 from public.institution_memberships x where x.person_id=p.id and x.status='active' and x.revoked_at is null))
        or (p_segment='dual_profile' and exists(select 1 from public.guardian_links x where x.guardian_person_id=p.id and x.status='active' and x.revoked_at is null) and exists(select 1 from public.institution_memberships x where x.person_id=p.id and x.status='active' and x.revoked_at is null)))
      and (nullif(btrim(coalesce(p_search,'')),'') is null or p.display_name ilike '%'||btrim(p_search)||'%')
      and (cardinality(coalesce(p_types,array[]::public.person_type[]))=0 or p.person_type=any(p_types))
      and (cardinality(coalesce(p_statuses,array[]::public.record_status[]))=0 or p.status=any(p_statuses))
      and (cardinality(coalesce(p_auth_links,array[]::text[]))=0 or (case when exists(select 1 from public.person_auth_links x where x.person_id=p.id and x.status='active' and x.revoked_at is null) then 'linked' when exists(select 1 from public.person_auth_links x where x.person_id=p.id and x.revoked_at is null) then 'pending' else 'unlinked' end)=any(p_auth_links))
      and (cardinality(coalesce(p_institution_ids,array[]::uuid[]))=0 and cardinality(coalesce(p_unit_ids,array[]::uuid[]))=0 and cardinality(coalesce(p_group_ids,array[]::uuid[]))=0 and cardinality(coalesce(p_contextual_roles,array[]::text[]))=0 and cardinality(coalesce(p_activity_ids,array[]::uuid[]))=0 and cardinality(coalesce(p_state_codes,array[]::text[]))=0 and cardinality(coalesce(p_municipality_ids,array[]::text[]))=0 and cardinality(coalesce(p_neighborhood_ids,array[]::text[]))=0
        or exists(select 1 from context_rows c where c.person_id=p.id
          and (cardinality(coalesce(p_institution_ids,array[]::uuid[]))=0 or c.institution_id=any(p_institution_ids))
          and (cardinality(coalesce(p_unit_ids,array[]::uuid[]))=0 or c.unit_id=any(p_unit_ids))
          and (cardinality(coalesce(p_group_ids,array[]::uuid[]))=0 or c.group_id=any(p_group_ids))
          and (cardinality(coalesce(p_contextual_roles,array[]::text[]))=0 or c.contextual_role=any(p_contextual_roles))
          and (cardinality(coalesce(p_activity_ids,array[]::uuid[]))=0 or c.activity_id=any(p_activity_ids))
          and (cardinality(coalesce(p_state_codes,array[]::text[]))=0 or c.state_code=any(p_state_codes))
          and (cardinality(coalesce(p_municipality_ids,array[]::text[]))=0 or c.municipality_id=any(p_municipality_ids))
          and (cardinality(coalesce(p_neighborhood_ids,array[]::text[]))=0 or c.neighborhood_id=any(p_neighborhood_ids))))
  ), ranked as (
    select f.*, row_number() over(order by
      case when p_sort_ascending and p_sort='display_name' then lower(f.display_name) end asc, case when not p_sort_ascending and p_sort='display_name' then lower(f.display_name) end desc,
      case when p_sort_ascending and p_sort='type' then f.person_type::text end asc, case when not p_sort_ascending and p_sort='type' then f.person_type::text end desc,
      case when p_sort_ascending and p_sort='status' then f.status::text end asc, case when not p_sort_ascending and p_sort='status' then f.status::text end desc,
      case when p_sort_ascending and p_sort='institution_name' then f.institution_sort end asc, case when not p_sort_ascending and p_sort='institution_name' then f.institution_sort end desc,
      case when p_sort_ascending and p_sort='unit_name' then f.unit_sort end asc, case when not p_sort_ascending and p_sort='unit_name' then f.unit_sort end desc,
      case when p_sort_ascending and p_sort='group_name' then f.group_sort end asc, case when not p_sort_ascending and p_sort='group_name' then f.group_sort end desc,
      case when p_sort_ascending and p_sort='contextual_role' then f.role_sort end asc, case when not p_sort_ascending and p_sort='contextual_role' then f.role_sort end desc,
      case when p_sort_ascending and p_sort='auth_link' then f.auth_link_state end asc, case when not p_sort_ascending and p_sort='auth_link' then f.auth_link_state end desc, lower(f.display_name),f.id) ordinal
    from filtered f
  ), page_rows as (select * from ranked where ordinal>p_offset and ordinal<=p_offset+p_limit)
  select jsonb_build_object('items',coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'display_name',q.display_name,'type',q.person_type,'status',q.status,'auth_link',q.auth_link_state,'memberships',coalesce((select jsonb_agg(jsonb_build_object('id',c.row_id,'institution_id',c.institution_id,'institution_name',c.institution_name,'unit_id',c.unit_id,'unit_name',c.unit_name,'group_id',c.group_id,'group_name',c.group_name,'activity_id',c.activity_id,'activity_name',c.activity_name,'role',c.contextual_role,'role_name',c.role_name) order by lower(c.institution_name),lower(c.unit_name),lower(c.group_name),c.row_id) from context_rows c where c.person_id=q.id),'[]'::jsonb),'updated_at',q.updated_at,'suspended_now',app_private.person_suspended_now(q.id),'suspended_from',(select p.suspended_from from public.people p where p.id=q.id),'suspended_until',(select p.suspended_until from public.people p where p.id=q.id)) order by q.ordinal) from page_rows q),'[]'::jsonb),'total_count',(select count(*) from filtered)) into result;
  return result;
end; $function$
;
commit;
