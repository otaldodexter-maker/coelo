-- Perfis de cuidado e Planos de medicacao: autorizacao, comandos e RLS.
--
-- Complementa 20260910010300. Desenho de seguranca conforme
-- docs/superpowers/specs/2026-09-01-superadmin-access-health-care-finalization-design.md:
-- RLS deny-by-default em toda tabela exposta, cliente sem grant de escrita,
-- mutacao sensivel por RPC auditada com ator derivado da sessao, idempotencia,
-- versao esperada e motivo, e IDs/tenant/escopo revalidados no banco.
--
-- Uma diferenca deliberada em relacao ao restante do Superadmin: dado de saude
-- de crianca NAO e alcancado por platform.read. A leitura exige a capacidade
-- dedicada health_care.read ou medication.read, de plataforma ou contextual.
-- Quem so tem leitura geral do Superadmin nao ve saude de crianca.
--
-- Leitura por responsavel familiar nao entra aqui. Ela exigiria uma capacidade
-- de guardiao que ainda nao existe, e inventa-la seria decidir sozinho quem ve
-- dado de saude de crianca. Fica registrado como pendencia, nao como omissao.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '600s';
select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('coelo.health-care.behavior', 0)
);

do $preflight$
begin
  if current_user <> 'postgres' then
    raise exception using errcode='42501',
      message='health care behavior must run as postgres';
  end if;
  if pg_catalog.to_regclass('public.health_care_profiles') is null
    or pg_catalog.to_regclass('public.medication_plans') is null then
    raise exception using errcode='55000',
      message='health care behavior requires the health care foundation';
  end if;
end
$preflight$;

-- ---------------------------------------------------------------------------
-- Autorizacao
-- ---------------------------------------------------------------------------

create or replace function app_private.health_care_scope_allowed(
  p_permission text,
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid,
  p_child_context_id uuid
) returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select p_institution_id is not null
    and (
      app_private.has_platform_permission(p_permission)
      or app_private.has_context_permission(
        p_institution_id, p_permission, p_unit_id, p_group_id, null,
        p_child_context_id, false
      )
    )
$$;

create or replace function app_private.require_health_care_actor(
  p_permission text
) returns uuid
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid;
begin
  actor := app_private.current_person_id();
  if actor is null then
    raise insufficient_privilege using message='authentication required';
  end if;
  if not app_private.has_platform_permission(p_permission)
    and not exists (
      select 1
      from public.institution_memberships membership
      where membership.person_id = actor
        and membership.status = 'active'
        and membership.revoked_at is null
        and app_private.has_context_permission(
          membership.institution_id, p_permission, null, null, null, null, false
        )
    ) then
    raise insufficient_privilege using message = p_permission || ' required';
  end if;
  return actor;
end
$$;

create or replace function app_private.health_care_receipt(
  p_request_id uuid,
  p_actor uuid,
  p_command text
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  receipt app_private.health_care_command_receipts%rowtype;
begin
  if p_request_id is null then
    raise invalid_parameter_value using message='request id required';
  end if;
  select * into receipt
  from app_private.health_care_command_receipts
  where request_id = p_request_id;
  if receipt.request_id is null then
    return null;
  end if;
  if receipt.actor_person_id is distinct from p_actor
    or receipt.command is distinct from p_command then
    raise invalid_parameter_value using message='request id reused for another command';
  end if;
  return receipt.response;
end
$$;

-- O contexto infantil precisa estar ativo e pertencer a instituicao declarada.
-- Sem isso, um id de crianca de outro tenant entraria pelo payload.
create or replace function app_private.health_care_child_institution(
  p_child_context_id uuid
) returns uuid
language sql
stable
security definer
set search_path=''
as $$
  select child_row.institution_id
  from public.child_contexts child_row
  where child_row.id = p_child_context_id
    and child_row.status = 'active'
$$;

-- O cliente identifica a crianca pela pessoa (MedicationPlanSaveCommand.
-- childPersonId), nao pelo contexto infantil. Resolver aqui evita duas coisas
-- ruins: o cliente escolher o contexto de outro tenant, e o servidor adivinhar
-- qual contexto usar quando a mesma pessoa tem vinculo em mais de uma
-- instituicao. Quando o contexto vem explicito, ele manda; quando so vem a
-- pessoa, so resolve se a escolha for unica dentro do escopo pedido.
create or replace function app_private.health_care_resolve_child_context(
  p_child_context_id uuid,
  p_child_person_id uuid,
  p_institution_id uuid
) returns uuid
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  resolved uuid;
  candidates integer;
begin
  if p_child_context_id is not null then
    select child_row.id into resolved
    from public.child_contexts child_row
    where child_row.id = p_child_context_id
      and child_row.status = 'active'
      and (p_child_person_id is null
        or child_row.child_person_id = p_child_person_id)
      and (p_institution_id is null
        or child_row.institution_id = p_institution_id);
    return resolved;
  end if;
  if p_child_person_id is null then
    return null;
  end if;
  -- Postgres nao agrega uuid, entao a contagem e a escolha saem da mesma
  -- varredura por array em vez de min().
  select array_length(found.ids, 1), found.ids[1] into candidates, resolved
  from (
    select array_agg(child_row.id order by child_row.id) as ids
    from public.child_contexts child_row
    where child_row.child_person_id = p_child_person_id
      and child_row.status = 'active'
      and (p_institution_id is null or child_row.institution_id = p_institution_id)
  ) found;
  if coalesce(candidates, 0) <> 1 then
    -- Zero: nao existe. Mais de um: a instituicao precisa ser dita. Nos dois
    -- casos, adivinhar seria escrever dado de saude no lugar errado.
    return null;
  end if;
  return resolved;
end
$$;

-- ---------------------------------------------------------------------------
-- Perfis de cuidado: leitura
-- ---------------------------------------------------------------------------

create or replace function app_private.superadmin_health_care_directory(
  p_search text,
  p_statuses text[],
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid,
  p_limit integer,
  p_offset integer
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid;
  page_limit integer := least(greatest(coalesce(p_limit, 20), 1), 100);
  page_offset integer := greatest(coalesce(p_offset, 0), 0);
  search_term text := nullif(btrim(coalesce(p_search, '')), '');
  items jsonb;
  total bigint;
begin
  actor := app_private.require_health_care_actor('health_care.read');
  select coalesce(jsonb_agg(to_jsonb(page_row) order by page_row.updated_at desc), '[]'::jsonb),
         coalesce(max(page_row.total_count), 0)
    into items, total
  from (
    select profile_row.id, profile_row.institution_id, profile_row.child_context_id,
           profile_row.operational_status, profile_row.management_version,
           profile_row.updated_at,
           child_person.display_name,
           child_row.child_person_id,
           (select count(*) from public.medication_plans plan_row
             where plan_row.child_context_id = profile_row.child_context_id
               and plan_row.status <> 'ended') as medication_count,
           (select count(*) from public.health_care_allergies allergy_row
             where allergy_row.profile_id = profile_row.id
               and allergy_row.active) as active_allergy_count,
           count(*) over () as total_count
    from public.health_care_profiles profile_row
    join public.child_contexts child_row on child_row.id = profile_row.child_context_id
    join public.people child_person on child_person.id = child_row.child_person_id
    where app_private.health_care_scope_allowed(
            'health_care.read', profile_row.institution_id,
            null, null, profile_row.child_context_id)
      and (p_institution_id is null or profile_row.institution_id = p_institution_id)
      and (p_statuses is null or array_length(p_statuses, 1) is null
        or profile_row.operational_status = any(p_statuses))
      and (p_unit_id is null or exists (
            select 1 from public.child_unit_links unit_link
            where unit_link.child_context_id = profile_row.child_context_id
              and unit_link.unit_id = p_unit_id
              and unit_link.status in ('active','awaiting_allocation')))
      and (p_group_id is null or exists (
            select 1
            from public.child_group_links group_link
            join public.child_unit_links unit_link
              on unit_link.id = group_link.child_unit_link_id
            where unit_link.child_context_id = profile_row.child_context_id
              and group_link.group_id = p_group_id
              and group_link.status = 'active'))
      and (search_term is null
        or child_person.display_name ilike '%' || search_term || '%')
    order by profile_row.updated_at desc
    limit page_limit offset page_offset
  ) page_row;

  return jsonb_build_object(
    'items', items, 'total', total,
    'limit', page_limit, 'offset', page_offset
  );
end
$$;

create or replace function app_private.superadmin_health_care_profile_detail(
  p_profile_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid;
  profile_row public.health_care_profiles;
  child_person_id uuid;
  child_display_name text;
begin
  actor := app_private.require_health_care_actor('health_care.read');
  select * into profile_row
  from public.health_care_profiles
  where id = p_profile_id
    and app_private.health_care_scope_allowed(
      'health_care.read', institution_id, null, null, child_context_id);
  if profile_row.id is null then
    raise no_data_found using message='health care profile unavailable';
  end if;
  select child_row.child_person_id, child_person.display_name
    into child_person_id, child_display_name
  from public.child_contexts child_row
  join public.people child_person on child_person.id = child_row.child_person_id
  where child_row.id = profile_row.child_context_id;

  return jsonb_build_object(
    'id', profile_row.id,
    'institution_id', profile_row.institution_id,
    'child_context_id', profile_row.child_context_id,
    'child_person_id', child_person_id,
    'display_name', child_display_name,
    'operational_status', profile_row.operational_status,
    'important_signs', profile_row.important_signs,
    'adaptations', profile_row.adaptations,
    'management_version', profile_row.management_version,
    'can_manage', app_private.health_care_scope_allowed(
      'health_care.manage', profile_row.institution_id, null, null,
      profile_row.child_context_id),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'catalog_item_id', item_row.catalog_item_id,
        'other_text', item_row.other_text) order by item_row.catalog_item_id)
      from public.health_care_profile_items item_row
      where item_row.profile_id = profile_row.id), '[]'::jsonb),
    'allergies', coalesce((
      select jsonb_agg(to_jsonb(allergy_row) order by allergy_row.created_at)
      from public.health_care_allergies allergy_row
      where allergy_row.profile_id = profile_row.id), '[]'::jsonb),
    'revisions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'revision_no', revision_row.revision_no,
        'subject', revision_row.subject,
        'justification', revision_row.justification,
        'created_at', revision_row.created_at) order by revision_row.revision_no desc)
      from public.health_care_profile_revisions revision_row
      where revision_row.profile_id = profile_row.id), '[]'::jsonb)
  );
end
$$;

-- ---------------------------------------------------------------------------
-- Perfis de cuidado: comando
-- ---------------------------------------------------------------------------

create or replace function app_private.superadmin_health_care_save_profile(
  p_request_id uuid,
  p_profile_id uuid,
  p_expected_version bigint,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid;
  aggregate_id uuid := coalesce(p_profile_id, gen_random_uuid());
  profile_row public.health_care_profiles;
  child_context uuid;
  child_institution uuid;
  before_json jsonb;
  after_json jsonb;
  justification text := btrim(coalesce(p_payload->>'justification', ''));
  response jsonb;
  revision_no integer;
  item_entry jsonb;
  allergy_entry jsonb;
begin
  actor := app_private.require_health_care_actor('health_care.manage');
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text, 0));
  response := app_private.health_care_receipt(p_request_id, actor, 'save_profile');
  if response is not null then return response; end if;
  if justification = '' then
    raise check_violation using message='justification required';
  end if;

  if p_profile_id is not null then
    select * into profile_row
    from public.health_care_profiles
    where id = aggregate_id
      and app_private.health_care_scope_allowed(
        'health_care.manage', institution_id, null, null, child_context_id)
    for update;
    if profile_row.id is null then
      raise no_data_found using message='health care profile unavailable';
    end if;
    if profile_row.management_version <> p_expected_version then
      raise serialization_failure using message='expected_version mismatch';
    end if;
    before_json := to_jsonb(profile_row);
  else
    if p_expected_version <> 0 then
      raise serialization_failure using message='expected_version mismatch';
    end if;
    -- A instituicao vem do contexto infantil, nunca do payload: aceitar a
    -- instituicao enviada pelo cliente permitiria anexar a crianca de um
    -- tenant a um perfil de outro.
    child_context := app_private.health_care_resolve_child_context(
      (p_payload->>'child_context_id')::uuid,
      (p_payload->>'child_person_id')::uuid,
      (p_payload->>'institution_id')::uuid);
    child_institution := app_private.health_care_child_institution(child_context);
    if child_institution is null then
      raise no_data_found using message='health care profile unavailable';
    end if;
    if not app_private.health_care_scope_allowed(
      'health_care.manage', child_institution, null, null, child_context) then
      raise insufficient_privilege using message='health_care.manage required';
    end if;
    before_json := null;
  end if;

  if profile_row.id is null then
    insert into public.health_care_profiles(
      id, institution_id, child_context_id, operational_status,
      important_signs, adaptations, created_by_person_id
    ) values (
      aggregate_id, child_institution, child_context,
      coalesce(p_payload->>'operational_status','implementation'),
      coalesce(p_payload->>'important_signs',''),
      coalesce(p_payload->>'adaptations',''),
      actor
    ) returning * into profile_row;
  else
    -- A identidade da crianca fica travada na edicao (spec 020): o payload nao
    -- pode mover um perfil para outra crianca.
    update public.health_care_profiles set
      operational_status = coalesce(p_payload->>'operational_status', operational_status),
      important_signs = coalesce(p_payload->>'important_signs', important_signs),
      adaptations = coalesce(p_payload->>'adaptations', adaptations),
      management_version = management_version + 1,
      updated_at = now()
    where id = aggregate_id returning * into profile_row;
  end if;

  if p_payload ? 'items' then
    delete from public.health_care_profile_items where profile_id = aggregate_id;
    for item_entry in select value from jsonb_array_elements(p_payload->'items') loop
      insert into public.health_care_profile_items(
        profile_id, catalog_item_id, other_text
      ) values (
        aggregate_id,
        item_entry->>'catalog_item_id',
        nullif(btrim(coalesce(item_entry->>'other_text','')), '')
      );
    end loop;
  end if;

  if p_payload ? 'allergies' then
    for allergy_entry in select value from jsonb_array_elements(p_payload->'allergies') loop
      if allergy_entry ? 'id' then
        update public.health_care_allergies set
          label = coalesce(allergy_entry->>'label', label),
          allergy_type = coalesce(allergy_entry->>'allergy_type', allergy_type),
          status = coalesce(allergy_entry->>'status', status),
          active = coalesce((allergy_entry->>'active')::boolean, active),
          last_episode_at = coalesce(
            (allergy_entry->>'last_episode_at')::timestamptz, last_episode_at),
          episode_severity = coalesce(
            allergy_entry->>'episode_severity', episode_severity),
          observed_reaction = coalesce(
            allergy_entry->>'observed_reaction', observed_reaction),
          guidance = coalesce(allergy_entry->>'guidance', guidance),
          notes = coalesce(allergy_entry->>'notes', notes),
          inactivated_at = case
            when coalesce((allergy_entry->>'active')::boolean, active) then null
            else coalesce(inactivated_at, now()) end,
          inactivation_reason = case
            when coalesce((allergy_entry->>'active')::boolean, active) then null
            else justification end,
          updated_at = now()
        where id = (allergy_entry->>'id')::uuid
          and profile_id = aggregate_id;
      else
        insert into public.health_care_allergies(
          profile_id, label, allergy_type, status, last_episode_at,
          episode_severity, observed_reaction, guidance, notes,
          created_by_person_id
        ) values (
          aggregate_id,
          btrim(coalesce(allergy_entry->>'label','')),
          coalesce(allergy_entry->>'allergy_type','other'),
          coalesce(allergy_entry->>'status','active'),
          (allergy_entry->>'last_episode_at')::timestamptz,
          allergy_entry->>'episode_severity',
          coalesce(allergy_entry->>'observed_reaction',''),
          coalesce(allergy_entry->>'guidance',''),
          coalesce(allergy_entry->>'notes',''),
          actor
        );
      end if;
    end loop;
  end if;

  after_json := to_jsonb(profile_row);
  select coalesce(max(existing.revision_no), 0) + 1 into revision_no
  from public.health_care_profile_revisions existing
  where existing.profile_id = aggregate_id;
  insert into public.health_care_profile_revisions(
    profile_id, revision_no, subject, justification,
    before_json, after_json, changed_by_person_id
  ) values (
    aggregate_id, revision_no,
    coalesce(p_payload->>'subject','care_profile'), justification,
    before_json, after_json, actor
  );

  response := jsonb_build_object(
    'id', aggregate_id,
    'management_version', profile_row.management_version,
    'revision', revision_no
  );
  insert into app_private.health_care_command_receipts
    values (p_request_id, actor, 'save_profile', aggregate_id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, reason, before_json, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'health_care.profile.save', 'health_care_profile',
    aggregate_id, profile_row.institution_id, 'success', justification,
    before_json, after_json
  );
  return response;
end
$$;

-- ---------------------------------------------------------------------------
-- Planos de medicacao
-- ---------------------------------------------------------------------------

create or replace function app_private.superadmin_medication_plan_directory(
  p_search text,
  p_statuses text[],
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid,
  p_limit integer,
  p_offset integer
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid;
  page_limit integer := least(greatest(coalesce(p_limit, 20), 1), 100);
  page_offset integer := greatest(coalesce(p_offset, 0), 0);
  search_term text := nullif(btrim(coalesce(p_search, '')), '');
  items jsonb;
  total bigint;
begin
  actor := app_private.require_health_care_actor('medication.read');
  select coalesce(jsonb_agg(to_jsonb(page_row) order by page_row.updated_at desc), '[]'::jsonb),
         coalesce(max(page_row.total_count), 0)
    into items, total
  from (
    select plan_row.id, plan_row.institution_id, plan_row.child_context_id,
           plan_row.scope_kind, plan_row.unit_id, plan_row.group_id,
           plan_row.status, plan_row.management_version, plan_row.updated_at,
           child_row.child_person_id, child_person.display_name,
           version_row.medication_name, version_row.dose_amount,
           version_row.dose_unit, version_row.administration_route,
           version_row.valid_from, version_row.valid_until,
           version_row.review_status, version_row.version,
           count(*) over () as total_count
    from public.medication_plans plan_row
    join public.child_contexts child_row on child_row.id = plan_row.child_context_id
    join public.people child_person on child_person.id = child_row.child_person_id
    left join public.medication_plan_versions version_row
      on version_row.id = plan_row.current_version_id
    where app_private.health_care_scope_allowed(
            'medication.read', plan_row.institution_id,
            plan_row.unit_id, plan_row.group_id, plan_row.child_context_id)
      and (p_institution_id is null or plan_row.institution_id = p_institution_id)
      and (p_unit_id is null or plan_row.unit_id = p_unit_id)
      and (p_group_id is null or plan_row.group_id = p_group_id)
      and (p_statuses is null or array_length(p_statuses, 1) is null
        or plan_row.status = any(p_statuses))
      and (search_term is null
        or child_person.display_name ilike '%' || search_term || '%'
        or version_row.medication_name ilike '%' || search_term || '%')
    order by plan_row.updated_at desc
    limit page_limit offset page_offset
  ) page_row;

  return jsonb_build_object(
    'items', items, 'total', total,
    'limit', page_limit, 'offset', page_offset
  );
end
$$;

create or replace function app_private.superadmin_medication_plan_detail(
  p_plan_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid;
  plan_row public.medication_plans;
  version_row public.medication_plan_versions;
begin
  actor := app_private.require_health_care_actor('medication.read');
  select * into plan_row
  from public.medication_plans
  where id = p_plan_id
    and app_private.health_care_scope_allowed(
      'medication.read', institution_id, unit_id, group_id, child_context_id);
  if plan_row.id is null then
    raise no_data_found using message='medication plan unavailable';
  end if;
  select * into version_row from public.medication_plan_versions
  where id = plan_row.current_version_id;

  return jsonb_build_object(
    'id', plan_row.id,
    'institution_id', plan_row.institution_id,
    'child_context_id', plan_row.child_context_id,
    'child_person_id', (
      select child_row.child_person_id from public.child_contexts child_row
      where child_row.id = plan_row.child_context_id),
    'scope_kind', plan_row.scope_kind,
    'unit_id', plan_row.unit_id,
    'group_id', plan_row.group_id,
    'status', plan_row.status,
    'management_version', plan_row.management_version,
    'can_manage', app_private.health_care_scope_allowed(
      'medication.manage', plan_row.institution_id, plan_row.unit_id,
      plan_row.group_id, plan_row.child_context_id),
    'current_version', to_jsonb(version_row),
    'schedules', coalesce((
      select jsonb_agg(to_jsonb(schedule_row) order by schedule_row.time_of_day)
      from public.medication_plan_schedules schedule_row
      where schedule_row.plan_version_id = version_row.id), '[]'::jsonb),
    'evidence', coalesce((
      select jsonb_agg(to_jsonb(evidence_row) order by evidence_row.occurred_at desc)
      from public.medication_plan_evidence evidence_row
      where evidence_row.plan_id = plan_row.id), '[]'::jsonb)
  );
end
$$;

create or replace function app_private.superadmin_medication_plan_save(
  p_request_id uuid,
  p_plan_id uuid,
  p_expected_version bigint,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid;
  aggregate_id uuid := coalesce(p_plan_id, gen_random_uuid());
  plan_row public.medication_plans;
  child_context uuid;
  child_institution uuid;
  version_id uuid;
  version_no integer;
  response jsonb;
  before_json jsonb;
  schedule_entry jsonb;
begin
  actor := app_private.require_health_care_actor('medication.manage');
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text, 0));
  response := app_private.health_care_receipt(p_request_id, actor, 'save_plan');
  if response is not null then return response; end if;
  if jsonb_typeof(p_payload->'schedules') <> 'array'
    or jsonb_array_length(p_payload->'schedules') = 0 then
    raise check_violation using message='medication plan requires schedules';
  end if;

  if p_plan_id is not null then
    select * into plan_row
    from public.medication_plans
    where id = aggregate_id
      and app_private.health_care_scope_allowed(
        'medication.manage', institution_id, unit_id, group_id, child_context_id)
    for update;
    if plan_row.id is null then
      raise no_data_found using message='medication plan unavailable';
    end if;
    if plan_row.management_version <> p_expected_version then
      raise serialization_failure using message='expected_version mismatch';
    end if;
    before_json := to_jsonb(plan_row);
  else
    if p_expected_version <> 0 then
      raise serialization_failure using message='expected_version mismatch';
    end if;
    child_context := app_private.health_care_resolve_child_context(
      (p_payload->>'child_context_id')::uuid,
      (p_payload->>'child_person_id')::uuid,
      (p_payload->>'institution_id')::uuid);
    child_institution := app_private.health_care_child_institution(child_context);
    if child_institution is null then
      raise no_data_found using message='medication plan unavailable';
    end if;
    if not app_private.health_care_scope_allowed(
      'medication.manage', child_institution,
      (p_payload->>'unit_id')::uuid, (p_payload->>'group_id')::uuid,
      child_context) then
      raise insufficient_privilege using message='medication.manage required';
    end if;
    insert into public.medication_plans(
      id, institution_id, child_context_id, scope_kind, unit_id, group_id,
      status, created_by_person_id
    ) values (
      aggregate_id, child_institution, child_context,
      coalesce(p_payload->>'scope_kind','institution'),
      (p_payload->>'unit_id')::uuid, (p_payload->>'group_id')::uuid,
      coalesce(p_payload->>'status','draft'), actor
    ) returning * into plan_row;
    before_json := null;
  end if;

  -- Mudanca relevante cria versao e invalida aprovacoes anteriores (spec 020).
  -- As versoes antigas ficam; nenhuma dose registrada perde referencia.
  update public.medication_plan_versions
    set review_status = 'invalidated',
        review_reason = 'nova versao do plano',
        approved_at = null,
        approved_by_person_id = null
  where plan_id = aggregate_id and review_status in ('pending','approved');

  select coalesce(max(existing.version), 0) + 1 into version_no
  from public.medication_plan_versions existing
  where existing.plan_id = aggregate_id;

  insert into public.medication_plan_versions(
    plan_id, version, medication_name, dose_amount, dose_unit,
    administration_route, route_details, instructions, reason,
    valid_from, valid_until, timezone, created_by_person_id
  ) values (
    aggregate_id, version_no,
    btrim(coalesce(p_payload->>'medication_name','')),
    (p_payload->>'dose_amount')::numeric,
    btrim(coalesce(p_payload->>'dose_unit','')),
    btrim(coalesce(p_payload->>'administration_route','')),
    nullif(btrim(coalesce(p_payload->>'route_details','')), ''),
    nullif(btrim(coalesce(p_payload->>'instructions','')), ''),
    btrim(coalesce(p_payload->>'reason','')),
    (p_payload->>'valid_from')::date,
    (p_payload->>'valid_until')::date,
    btrim(coalesce(p_payload->>'timezone','')),
    actor
  ) returning id into version_id;

  for schedule_entry in select value from jsonb_array_elements(p_payload->'schedules') loop
    insert into public.medication_plan_schedules(
      plan_version_id, time_of_day, weekdays, timezone, frequency_kind,
      start_date, end_date, max_occurrences_per_day, institution_id
    ) values (
      version_id,
      (schedule_entry->>'time_of_day')::time,
      (select array_agg(value::smallint)
         from jsonb_array_elements_text(schedule_entry->'weekdays')),
      btrim(coalesce(schedule_entry->>'timezone', p_payload->>'timezone')),
      coalesce(schedule_entry->>'frequency_kind','weekly'),
      (schedule_entry->>'start_date')::date,
      (schedule_entry->>'end_date')::date,
      (schedule_entry->>'max_occurrences_per_day')::smallint,
      (schedule_entry->>'institution_id')::uuid
    );
  end loop;

  update public.medication_plans set
    current_version_id = version_id,
    status = coalesce(p_payload->>'status', status),
    management_version = management_version + 1,
    updated_at = now()
  where id = aggregate_id returning * into plan_row;

  response := jsonb_build_object(
    'id', aggregate_id,
    'management_version', plan_row.management_version,
    'version', version_no,
    'version_id', version_id
  );
  insert into app_private.health_care_command_receipts
    values (p_request_id, actor, 'save_plan', aggregate_id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, reason, before_json, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'medication.plan.save', 'medication_plan',
    aggregate_id, plan_row.institution_id, 'success',
    nullif(btrim(coalesce(p_payload->>'reason','')), ''),
    before_json, to_jsonb(plan_row)
  );
  return response;
end
$$;

-- Registrar evidencia nao e editar o plano: comando proprio, capacidade
-- propria, append-only, e nao mexe na versao do agregado.
create or replace function app_private.superadmin_medication_plan_record_evidence(
  p_request_id uuid,
  p_plan_id uuid,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid;
  plan_row public.medication_plans;
  evidence_id uuid;
  response jsonb;
begin
  actor := app_private.require_health_care_actor('medication.record_evidence');
  perform pg_advisory_xact_lock(hashtextextended(p_plan_id::text, 0));
  response := app_private.health_care_receipt(p_request_id, actor, 'record_evidence');
  if response is not null then return response; end if;

  select * into plan_row
  from public.medication_plans
  where id = p_plan_id
    and app_private.health_care_scope_allowed(
      'medication.record_evidence', institution_id, unit_id, group_id,
      child_context_id);
  if plan_row.id is null then
    raise no_data_found using message='medication plan unavailable';
  end if;
  if plan_row.current_version_id is null then
    raise check_violation using message='medication plan has no version';
  end if;

  insert into public.medication_plan_evidence(
    plan_id, plan_version_id, schedule_id, occurred_at, outcome,
    reason, note, media_asset_id, recorded_by_person_id
  ) values (
    p_plan_id, plan_row.current_version_id,
    (p_payload->>'schedule_id')::uuid,
    coalesce((p_payload->>'occurred_at')::timestamptz, now()),
    coalesce(p_payload->>'outcome','administered'),
    nullif(btrim(coalesce(p_payload->>'reason','')), ''),
    nullif(btrim(coalesce(p_payload->>'note','')), ''),
    (p_payload->>'media_asset_id')::uuid,
    actor
  ) returning id into evidence_id;

  response := jsonb_build_object('id', evidence_id, 'plan_id', p_plan_id);
  insert into app_private.health_care_command_receipts
    values (p_request_id, actor, 'record_evidence', p_plan_id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'medication.evidence.record',
    'medication_plan_evidence', evidence_id, plan_row.institution_id,
    'success', response
  );
  return response;
end
$$;

-- ---------------------------------------------------------------------------
-- Superficie publica
-- ---------------------------------------------------------------------------

create or replace function public.superadmin_health_care_directory(
  search text, statuses text[], institution_id uuid, unit_id uuid,
  group_id uuid, page_limit integer, page_offset integer
) returns jsonb language sql stable security invoker set search_path='' as $$
  select app_private.superadmin_health_care_directory(
    search, statuses, institution_id, unit_id, group_id, page_limit, page_offset)
$$;

create or replace function public.superadmin_health_care_profile_detail(profile_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select app_private.superadmin_health_care_profile_detail(profile_id)
$$;

create or replace function public.superadmin_health_care_save_profile(
  request_id uuid, profile_id uuid, expected_version bigint, payload jsonb
) returns jsonb language sql volatile security invoker set search_path='' as $$
  select app_private.superadmin_health_care_save_profile(
    request_id, profile_id, expected_version, payload)
$$;

create or replace function public.superadmin_medication_plan_directory(
  search text, statuses text[], institution_id uuid, unit_id uuid,
  group_id uuid, page_limit integer, page_offset integer
) returns jsonb language sql stable security invoker set search_path='' as $$
  select app_private.superadmin_medication_plan_directory(
    search, statuses, institution_id, unit_id, group_id, page_limit, page_offset)
$$;

create or replace function public.superadmin_medication_plan_detail(plan_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select app_private.superadmin_medication_plan_detail(plan_id)
$$;

create or replace function public.superadmin_medication_plan_save(
  request_id uuid, plan_id uuid, expected_version bigint, payload jsonb
) returns jsonb language sql volatile security invoker set search_path='' as $$
  select app_private.superadmin_medication_plan_save(
    request_id, plan_id, expected_version, payload)
$$;

create or replace function public.superadmin_medication_plan_record_evidence(
  request_id uuid, plan_id uuid, payload jsonb
) returns jsonb language sql volatile security invoker set search_path='' as $$
  select app_private.superadmin_medication_plan_record_evidence(
    request_id, plan_id, payload)
$$;

-- ---------------------------------------------------------------------------
-- RLS e privilegios
-- ---------------------------------------------------------------------------

do $rls$
declare current_table text;
begin
  foreach current_table in array array[
    'health_care_profiles','health_care_profile_items','health_care_allergies',
    'health_care_profile_revisions','medication_plans','medication_plan_versions',
    'medication_plan_schedules','medication_plan_evidence'
  ] loop
    execute format('alter table public.%I enable row level security', current_table);
    execute format('alter table public.%I force row level security', current_table);
    execute format('revoke all on public.%I from public, anon, authenticated', current_table);
    execute format('grant all on public.%I to service_role', current_table);
    execute format('grant select on public.%I to authenticated', current_table);
  end loop;
end
$rls$;

alter table app_private.health_care_command_receipts enable row level security;
alter table app_private.health_care_command_receipts force row level security;
revoke all on app_private.health_care_command_receipts
  from public, anon, authenticated;
grant all on app_private.health_care_command_receipts to service_role;

create policy health_care_profiles_read on public.health_care_profiles
for select to authenticated using (
  app_private.health_care_scope_allowed(
    'health_care.read', institution_id, null, null, child_context_id)
);

create policy health_care_profile_items_read on public.health_care_profile_items
for select to authenticated using (
  exists (
    select 1 from public.health_care_profiles profile_row
    where profile_row.id = profile_id
      and app_private.health_care_scope_allowed(
        'health_care.read', profile_row.institution_id, null, null,
        profile_row.child_context_id)
  )
);

create policy health_care_allergies_read on public.health_care_allergies
for select to authenticated using (
  exists (
    select 1 from public.health_care_profiles profile_row
    where profile_row.id = profile_id
      and app_private.health_care_scope_allowed(
        'health_care.read', profile_row.institution_id, null, null,
        profile_row.child_context_id)
  )
);

create policy health_care_profile_revisions_read on public.health_care_profile_revisions
for select to authenticated using (
  exists (
    select 1 from public.health_care_profiles profile_row
    where profile_row.id = profile_id
      and app_private.health_care_scope_allowed(
        'health_care.read', profile_row.institution_id, null, null,
        profile_row.child_context_id)
  )
);

create policy medication_plans_read on public.medication_plans
for select to authenticated using (
  app_private.health_care_scope_allowed(
    'medication.read', institution_id, unit_id, group_id, child_context_id)
);

create policy medication_plan_versions_read on public.medication_plan_versions
for select to authenticated using (
  exists (
    select 1 from public.medication_plans plan_row
    where plan_row.id = plan_id
      and app_private.health_care_scope_allowed(
        'medication.read', plan_row.institution_id, plan_row.unit_id,
        plan_row.group_id, plan_row.child_context_id)
  )
);

create policy medication_plan_schedules_read on public.medication_plan_schedules
for select to authenticated using (
  exists (
    select 1
    from public.medication_plan_versions version_row
    join public.medication_plans plan_row on plan_row.id = version_row.plan_id
    where version_row.id = plan_version_id
      and app_private.health_care_scope_allowed(
        'medication.read', plan_row.institution_id, plan_row.unit_id,
        plan_row.group_id, plan_row.child_context_id)
  )
);

create policy medication_plan_evidence_read on public.medication_plan_evidence
for select to authenticated using (
  exists (
    select 1 from public.medication_plans plan_row
    where plan_row.id = plan_id
      and app_private.health_care_scope_allowed(
        'medication.read', plan_row.institution_id, plan_row.unit_id,
        plan_row.group_id, plan_row.child_context_id)
  )
);

do $grants$
declare current_signature text;
begin
  foreach current_signature in array array[
    'app_private.require_health_care_actor(text)',
    'app_private.health_care_receipt(uuid,uuid,text)',
    'app_private.health_care_child_institution(uuid)',
    'app_private.health_care_resolve_child_context(uuid,uuid,uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated',
      current_signature);
  end loop;

  foreach current_signature in array array[
    'app_private.health_care_scope_allowed(text,uuid,uuid,uuid,uuid)',
    'app_private.superadmin_health_care_directory(text,text[],uuid,uuid,uuid,integer,integer)',
    'app_private.superadmin_health_care_profile_detail(uuid)',
    'app_private.superadmin_health_care_save_profile(uuid,uuid,bigint,jsonb)',
    'app_private.superadmin_medication_plan_directory(text,text[],uuid,uuid,uuid,integer,integer)',
    'app_private.superadmin_medication_plan_detail(uuid)',
    'app_private.superadmin_medication_plan_save(uuid,uuid,bigint,jsonb)',
    'app_private.superadmin_medication_plan_record_evidence(uuid,uuid,jsonb)',
    'public.superadmin_health_care_directory(text,text[],uuid,uuid,uuid,integer,integer)',
    'public.superadmin_health_care_profile_detail(uuid)',
    'public.superadmin_health_care_save_profile(uuid,uuid,bigint,jsonb)',
    'public.superadmin_medication_plan_directory(text,text[],uuid,uuid,uuid,integer,integer)',
    'public.superadmin_medication_plan_detail(uuid)',
    'public.superadmin_medication_plan_save(uuid,uuid,bigint,jsonb)',
    'public.superadmin_medication_plan_record_evidence(uuid,uuid,jsonb)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated',
      current_signature);
    execute format('grant execute on function %s to authenticated, service_role',
      current_signature);
  end loop;
end
$grants$;

commit;
