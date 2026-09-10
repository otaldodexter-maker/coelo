-- Rotina diaria: auxiliares de autorizacao, comandos, projecoes e RLS.
--
-- Complementa 20260910010000_daily_routine_foundation_v1 e fecha o contrato de
-- supabase/tests/daily_routine_foundation_test.sql e
-- supabase/tests/daily_routine_scope_closure_test.sql. Os corpos de
-- superadmin_routine_save_application, superadmin_routine_revert_application e
-- superadmin_routine_correct_launch sao repetidos verbatim de
-- 20260825193112_final_review_daily_routine_lint_hardening, porque aquela
-- migration esta fora do manifesto de replay e o perfil local nunca a aplica;
-- a secao correspondente explica o motivo em detalhe. Os privilegios sao
-- corrigidos aqui porque numa base nova o CREATE OR REPLACE daquelas funcoes
-- nasce com o ACL padrao de funcao, que concede EXECUTE a PUBLIC.
--
-- Autorizacao: nenhuma leitura ou escrita confia no cliente. Toda tabela
-- exposta usa RLS deny-by-default com FORCE, o cliente recebe apenas SELECT, e
-- toda mutacao passa por RPC SECURITY DEFINER que recalcula ator, capacidade e
-- escopo no servidor. Negativa de escopo e opaca: 'routine ... unavailable',
-- nunca 'nao autorizado para o id X', para nao confirmar existencia.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '600s';
select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('coelo.daily-routine.behavior', 0)
);

do $preflight$
begin
  if current_user <> 'postgres' then
    raise exception using errcode='42501',
      message='daily routine behavior must run as postgres';
  end if;
  if pg_catalog.to_regclass('public.routine_models') is null
    or pg_catalog.to_regclass('app_private.routine_command_receipts') is null then
    raise exception using errcode='55000',
      message='daily routine behavior requires the routine foundation';
  end if;
end
$preflight$;

-- ---------------------------------------------------------------------------
-- Fase de MFA
-- ---------------------------------------------------------------------------

-- ADR 0034: o MVP roda em AAL1. O metadado requires_mfa segue verdadeiro nas
-- capacidades de alto impacto e o portao continua escrito nos comandos; esta
-- funcao decide se ele esta valendo. Ligar MFA e trocar o false por true numa
-- migration propria, sem tocar nos comandos.
create or replace function app_private.routine_mfa_phase_enforced()
returns boolean
language sql
immutable
security definer
set search_path=''
as $$
  select false
$$;

-- ---------------------------------------------------------------------------
-- Autorizacao
-- ---------------------------------------------------------------------------

create or replace function app_private.routine_scope_allowed(
  p_permission text,
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid
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
        p_institution_id, p_permission, p_unit_id, p_group_id, null, null, false
      )
    )
$$;

create or replace function app_private.require_routine_actor(
  p_permission text,
  p_require_mfa boolean default false
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
  if p_require_mfa
    and app_private.routine_mfa_phase_enforced()
    and not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message='MFA AAL2 required';
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

create or replace function app_private.require_routine_scope(
  p_permission text,
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid,
  p_require_mfa boolean default false
) returns void
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if p_institution_id is null then
    raise invalid_parameter_value using message='routine scope required';
  end if;
  if p_require_mfa
    and app_private.routine_mfa_phase_enforced()
    and not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message='MFA AAL2 required';
  end if;
  if not app_private.routine_scope_allowed(
    p_permission, p_institution_id, p_unit_id, p_group_id
  ) then
    raise insufficient_privilege using message = p_permission || ' required';
  end if;
end
$$;

create or replace function app_private.routine_receipt(
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
  receipt app_private.routine_command_receipts%rowtype;
begin
  if p_request_id is null then
    raise invalid_parameter_value using message='request id required';
  end if;
  select * into receipt
  from app_private.routine_command_receipts
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

-- ---------------------------------------------------------------------------
-- Definicao: projecao e validacao
-- ---------------------------------------------------------------------------

create or replace function app_private.routine_definition_json(
  p_model_version_id uuid
) returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(
    jsonb_build_object(
      'model_version_id', version_row.id,
      'model_id', version_row.model_id,
      'version', version_row.version,
      'sections', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'id', section_row.id,
            'name', section_row.name,
            'sort_order', section_row.sort_order,
            'fields', coalesce((
              select jsonb_agg(
                jsonb_build_object(
                  'id', field_row.id,
                  'label', field_row.label,
                  'kind', field_row.kind,
                  'sort_order', field_row.sort_order,
                  'is_required', field_row.is_required,
                  'initial_value', field_row.initial_value,
                  'minimum_value', field_row.minimum_value,
                  'maximum_value', field_row.maximum_value,
                  'options', coalesce((
                    select jsonb_agg(
                      jsonb_build_object(
                        'id', option_row.id,
                        'label', option_row.label,
                        'sort_order', option_row.sort_order
                      ) order by option_row.sort_order
                    )
                    from public.routine_field_options option_row
                    where option_row.field_id = field_row.id
                  ), '[]'::jsonb),
                  'conditions', coalesce((
                    select jsonb_agg(
                      jsonb_build_object(
                        'id', condition_row.id,
                        'parent_field_id', condition_row.parent_field_id,
                        'target_field_id', condition_row.target_field_id,
                        'option_id', condition_row.option_id,
                        'boolean_value', condition_row.boolean_value,
                        'depth', condition_row.depth
                      ) order by condition_row.id
                    )
                    from public.routine_field_conditions condition_row
                    where condition_row.target_field_id = field_row.id
                  ), '[]'::jsonb)
                ) order by field_row.sort_order
              )
              from public.routine_fields field_row
              where field_row.section_id = section_row.id
            ), '[]'::jsonb)
          ) order by section_row.sort_order
        )
        from public.routine_sections section_row
        where section_row.model_version_id = version_row.id
      ), '[]'::jsonb)
    ),
    '{}'::jsonb
  )
  from public.routine_model_versions version_row
  where version_row.id = p_model_version_id
$$;

-- Rejeita ramificacao condicional profunda demais ou ciclica. As duas
-- mensagens sao conferidas por daily_routine_foundation_test.sql.
create or replace function app_private.validate_routine_definition(
  p_model_version_id uuid
) returns void
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  deepest integer;
  cyclic boolean;
begin
  if p_model_version_id is null then
    return;
  end if;

  with recursive version_fields as (
    select field_row.id
    from public.routine_fields field_row
    join public.routine_sections section_row on section_row.id = field_row.section_id
    where section_row.model_version_id = p_model_version_id
  ),
  version_conditions as (
    select condition_row.parent_field_id, condition_row.target_field_id
    from public.routine_field_conditions condition_row
    join version_fields parent_field on parent_field.id = condition_row.parent_field_id
    join version_fields target_field on target_field.id = condition_row.target_field_id
  ),
  branch as (
    select condition_row.parent_field_id as root_field_id,
           condition_row.target_field_id as field_id,
           1 as depth,
           array[condition_row.parent_field_id, condition_row.target_field_id] as visited,
           false as looped
    from version_conditions condition_row
    union all
    select branch_row.root_field_id,
           next_condition.target_field_id,
           branch_row.depth + 1,
           branch_row.visited || next_condition.target_field_id,
           next_condition.target_field_id = any(branch_row.visited)
    from branch branch_row
    join version_conditions next_condition
      on next_condition.parent_field_id = branch_row.field_id
    where not branch_row.looped and branch_row.depth < 16
  )
  select coalesce(max(branch_row.depth), 0),
         coalesce(bool_or(branch_row.looped), false)
    into deepest, cyclic
  from branch branch_row;

  if cyclic then
    raise check_violation using message='routine definition has a conditional cycle';
  end if;
  if deepest > 4 then
    raise check_violation using message='routine definition maximum conditional depth is 4';
  end if;
end
$$;

create or replace function app_private.validate_routine_launch_answers(
  p_launch_id uuid,
  p_require_complete boolean default false
) returns void
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  offender record;
begin
  for offender in
    select answer_row.id, field_row.kind, field_row.is_required,
           field_row.minimum_value, field_row.maximum_value,
           answer_row.value_json, answer_row.field_id
    from public.routine_answers answer_row
    join public.routine_child_entries entry_row on entry_row.id = answer_row.child_entry_id
    join public.routine_fields field_row on field_row.id = answer_row.field_id
    where entry_row.launch_id = p_launch_id
  loop
    if offender.value_json is null or jsonb_typeof(offender.value_json) = 'null' then
      if p_require_complete and offender.is_required then
        raise check_violation using message='routine answer required';
      end if;
      continue;
    end if;
    if offender.kind in ('short_text','long_text') then
      if jsonb_typeof(offender.value_json) <> 'string' then
        raise check_violation using message='routine answer type mismatch';
      end if;
    elsif offender.kind = 'number' then
      if jsonb_typeof(offender.value_json) <> 'number' then
        raise check_violation using message='routine answer type mismatch';
      end if;
      if (offender.minimum_value is not null
            and (offender.value_json)::numeric < offender.minimum_value)
        or (offender.maximum_value is not null
            and (offender.value_json)::numeric > offender.maximum_value) then
        raise check_violation using message='routine answer out of range';
      end if;
    elsif offender.kind = 'boolean' then
      if jsonb_typeof(offender.value_json) <> 'boolean' then
        raise check_violation using message='routine answer type mismatch';
      end if;
    elsif offender.kind = 'single_choice' then
      if jsonb_typeof(offender.value_json) <> 'string'
        or not exists (
          select 1 from public.routine_field_options option_row
          where option_row.field_id = offender.field_id
            and option_row.id = (offender.value_json #>> '{}')::uuid
        ) then
        raise check_violation using message='routine answer option unknown';
      end if;
    elsif offender.kind = 'multiple_choice' then
      if jsonb_typeof(offender.value_json) <> 'array'
        or exists (
          select 1
          from jsonb_array_elements_text(offender.value_json) as chosen(value)
          where not exists (
            select 1 from public.routine_field_options option_row
            where option_row.field_id = offender.field_id
              and option_row.id = chosen.value::uuid
          )
        ) then
        raise check_violation using message='routine answer option unknown';
      end if;
    end if;
  end loop;

  if p_require_complete and exists (
    select 1
    from public.routine_child_entries entry_row
    join public.routine_launches launch_row on launch_row.id = entry_row.launch_id
    join public.routine_application_revisions revision_row
      on revision_row.id = launch_row.application_revision_id
    join public.routine_sections section_row
      on section_row.model_version_id = revision_row.source_model_version_id
    join public.routine_fields field_row
      on field_row.section_id = section_row.id and field_row.is_required
    where entry_row.launch_id = p_launch_id
      and not exists (
        select 1 from public.routine_answers answer_row
        where answer_row.child_entry_id = entry_row.id
          and answer_row.field_id = field_row.id
          and answer_row.value_json is not null
          and jsonb_typeof(answer_row.value_json) <> 'null'
      )
  ) then
    raise check_violation using message='routine answer required';
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- Hierarquia da aplicacao
-- ---------------------------------------------------------------------------

create or replace function app_private.validate_routine_application_hierarchy()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  parent_row public.routine_applications;
begin
  if new.unit_id is not null and not exists (
    select 1 from public.units unit_row
    where unit_row.id = new.unit_id and unit_row.institution_id = new.institution_id
  ) then
    raise exception 'routine application hierarchy mismatch';
  end if;
  if new.group_id is not null and not exists (
    select 1 from public.groups group_row
    where group_row.id = new.group_id
      and group_row.unit_id = new.unit_id
      and group_row.institution_id = new.institution_id
  ) then
    raise exception 'routine application hierarchy mismatch';
  end if;
  if new.activity_id is not null and not exists (
    select 1 from public.activity_group_links link_row
    where link_row.activity_id = new.activity_id
      and link_row.group_id = new.group_id
      and link_row.unit_id = new.unit_id
      and link_row.institution_id = new.institution_id
  ) then
    raise exception 'routine application hierarchy mismatch';
  end if;
  if new.source_model_version_id is not null and not exists (
    select 1
    from public.routine_model_versions version_row
    join public.routine_models model_row on model_row.id = version_row.model_id
    where version_row.id = new.source_model_version_id
      and model_row.institution_id = new.institution_id
  ) then
    raise exception 'routine application hierarchy mismatch';
  end if;
  if new.parent_application_id is not null then
    select * into parent_row from public.routine_applications
    where id = new.parent_application_id;
    if parent_row.id is null
      or parent_row.institution_id <> new.institution_id
      or (parent_row.unit_id is not null and parent_row.unit_id is distinct from new.unit_id)
      or (parent_row.group_id is not null and parent_row.group_id is distinct from new.group_id)
      or (parent_row.activity_id is not null
          and parent_row.activity_id is distinct from new.activity_id) then
      raise exception 'routine application hierarchy mismatch';
    end if;
  end if;
  return new;
end
$$;

create trigger routine_applications_hierarchy
before insert or update on public.routine_applications
for each row execute function app_private.validate_routine_application_hierarchy();

-- ---------------------------------------------------------------------------
-- Projecoes de leitura
-- ---------------------------------------------------------------------------

create view public.daily_routine_effective_applications
with (security_invoker = true) as
select
  application_row.id,
  application_row.institution_id,
  application_row.unit_id,
  application_row.group_id,
  application_row.activity_id,
  application_row.scope_kind,
  application_row.status,
  application_row.inheritance_mode,
  application_row.visibility,
  application_row.valid_from,
  application_row.valid_until,
  application_row.starts_at,
  application_row.ends_at,
  application_row.management_version,
  application_row.parent_application_id,
  application_row.source_model_version_id,
  revision_row.id as revision_id,
  revision_row.revision_no,
  revision_row.origin_application_id,
  revision_row.effective_definition,
  application_row.updated_at
from public.routine_applications application_row
left join lateral (
  select candidate.*
  from public.routine_application_revisions candidate
  where candidate.application_id = application_row.id
  order by candidate.revision_no desc
  limit 1
) revision_row on true;

-- ---------------------------------------------------------------------------
-- Comandos e consultas
-- ---------------------------------------------------------------------------

create or replace function app_private.superadmin_routine_directory(
  p_entry_kind text,
  p_search text,
  p_status text,
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
  actor := app_private.require_routine_actor('routine.read', false);
  if p_entry_kind not in ('model','application','launch') then
    raise invalid_parameter_value using message='invalid routine entry kind';
  end if;

  if p_entry_kind = 'model' then
    select coalesce(jsonb_agg(to_jsonb(page_row) order by page_row.updated_at desc), '[]'::jsonb),
           coalesce(max(page_row.total_count), 0)
      into items, total
    from (
      select model_row.id, model_row.name, model_row.description, model_row.status,
             model_row.institution_id, model_row.origin_scope, model_row.origin_unit_id,
             model_row.management_version, model_row.updated_at,
             coalesce(version_row.version, 0) as version,
             model_row.current_version_id,
             count(*) over () as total_count
      from public.routine_models model_row
      left join public.routine_model_versions version_row
        on version_row.id = model_row.current_version_id
      where app_private.routine_scope_allowed(
              'routine.read', model_row.institution_id, model_row.origin_unit_id, null)
        and (p_institution_id is null or model_row.institution_id = p_institution_id)
        and (p_unit_id is null or model_row.origin_unit_id = p_unit_id)
        and (p_status is null or model_row.status = p_status)
        and (search_term is null or model_row.name ilike '%' || search_term || '%')
      order by model_row.updated_at desc
      limit page_limit offset page_offset
    ) page_row;
  elsif p_entry_kind = 'application' then
    select coalesce(jsonb_agg(to_jsonb(page_row) order by page_row.updated_at desc), '[]'::jsonb),
           coalesce(max(page_row.total_count), 0)
      into items, total
    from (
      select application_row.id, application_row.institution_id, application_row.unit_id,
             application_row.group_id, application_row.activity_id,
             application_row.scope_kind, application_row.status,
             application_row.inheritance_mode, application_row.visibility,
             application_row.valid_from, application_row.valid_until,
             application_row.starts_at, application_row.ends_at,
             application_row.parent_application_id,
             application_row.source_model_version_id,
             application_row.management_version, application_row.updated_at,
             count(*) over () as total_count
      from public.routine_applications application_row
      where app_private.routine_scope_allowed(
              'routine.read', application_row.institution_id,
              application_row.unit_id, application_row.group_id)
        and (p_institution_id is null or application_row.institution_id = p_institution_id)
        and (p_unit_id is null or application_row.unit_id = p_unit_id)
        and (p_group_id is null or application_row.group_id = p_group_id)
        and (p_status is null or application_row.status = p_status)
      order by application_row.updated_at desc
      limit page_limit offset page_offset
    ) page_row;
  else
    select coalesce(jsonb_agg(to_jsonb(page_row) order by page_row.launch_date desc), '[]'::jsonb),
           coalesce(max(page_row.total_count), 0)
      into items, total
    from (
      select launch_row.id, launch_row.institution_id, launch_row.unit_id,
             launch_row.group_id, launch_row.application_id,
             launch_row.application_revision_id, launch_row.launch_date,
             launch_row.status, launch_row.management_version,
             launch_row.published_at, launch_row.corrected_at, launch_row.updated_at,
             count(*) over () as total_count
      from public.routine_launches launch_row
      where app_private.routine_scope_allowed(
              'routine.read', launch_row.institution_id,
              launch_row.unit_id, launch_row.group_id)
        and (p_institution_id is null or launch_row.institution_id = p_institution_id)
        and (p_unit_id is null or launch_row.unit_id = p_unit_id)
        and (p_group_id is null or launch_row.group_id = p_group_id)
        and (p_status is null or launch_row.status = p_status)
      order by launch_row.launch_date desc
      limit page_limit offset page_offset
    ) page_row;
  end if;

  return jsonb_build_object(
    'items', items,
    'total', total,
    'limit', page_limit,
    'offset', page_offset
  );
end
$$;

create or replace function app_private.superadmin_routine_model_detail(
  p_model_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid;
  model_row public.routine_models;
begin
  actor := app_private.require_routine_actor('routine.read', false);
  select * into model_row
  from public.routine_models
  where id = p_model_id
    and app_private.routine_scope_allowed(
      'routine.read', institution_id, origin_unit_id, null);
  if model_row.id is null then
    raise no_data_found using message='routine model unavailable';
  end if;
  return jsonb_build_object(
    'id', model_row.id,
    'institution_id', model_row.institution_id,
    'origin_scope', model_row.origin_scope,
    'origin_unit_id', model_row.origin_unit_id,
    'name', model_row.name,
    'description', model_row.description,
    'status', model_row.status,
    'management_version', model_row.management_version,
    'can_manage', app_private.routine_scope_allowed(
      'routine.manage_models', model_row.institution_id, model_row.origin_unit_id, null),
    'definition', app_private.routine_definition_json(model_row.current_version_id)
  );
end
$$;

create or replace function app_private.superadmin_routine_save_model(
  p_request_id uuid,
  p_model_id uuid,
  p_expected_version bigint,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid;
  aggregate_id uuid := coalesce(p_model_id, gen_random_uuid());
  model_row public.routine_models;
  before_json jsonb;
  after_json jsonb;
  response jsonb;
  version_id uuid;
  version_no integer;
  section_item jsonb;
  field_item jsonb;
  option_item jsonb;
  condition_item jsonb;
  section_id uuid;
  field_id uuid;
  option_id uuid;
  field_ids jsonb := '{}'::jsonb;
  option_ids jsonb := '{}'::jsonb;
begin
  actor := app_private.require_routine_actor('routine.manage_models', false);
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text, 0));
  response := app_private.routine_receipt(p_request_id, actor, 'save_model');
  if response is not null then return response; end if;

  if p_model_id is not null then
    select * into model_row
    from public.routine_models
    where id = aggregate_id
      and app_private.routine_scope_allowed(
        'routine.manage_models', institution_id, origin_unit_id, null)
    for update;
    if model_row.id is null then
      raise no_data_found using message = 'routine model unavailable';
    end if;
    if model_row.management_version <> p_expected_version then
      raise serialization_failure using message='expected_version mismatch';
    end if;
    before_json := to_jsonb(model_row);
  else
    if p_expected_version <> 0 then
      raise serialization_failure using message='expected_version mismatch';
    end if;
    perform app_private.require_routine_scope(
      'routine.manage_models',
      (p_payload->>'institution_id')::uuid,
      (p_payload->>'origin_unit_id')::uuid,
      null,
      false
    );
    before_json := null;
  end if;

  if model_row.id is null then
    insert into public.routine_models(
      id, institution_id, origin_scope, origin_unit_id, name, description,
      status, created_by_person_id
    ) values (
      aggregate_id,
      (p_payload->>'institution_id')::uuid,
      coalesce(p_payload->>'origin_scope','institution'),
      (p_payload->>'origin_unit_id')::uuid,
      btrim(coalesce(p_payload->>'name','')),
      coalesce(p_payload->>'description',''),
      coalesce(p_payload->>'status','draft'),
      actor
    ) returning * into model_row;
  else
    update public.routine_models set
      name = btrim(coalesce(p_payload->>'name', name)),
      description = coalesce(p_payload->>'description', description),
      status = coalesce(p_payload->>'status', status),
      management_version = management_version + 1,
      updated_at = now()
    where id = aggregate_id returning * into model_row;
  end if;

  if p_payload ? 'sections' then
    if jsonb_typeof(p_payload->'sections') <> 'array' then
      raise invalid_parameter_value using message='invalid routine definition payload';
    end if;
    select coalesce(max(existing.version), 0) + 1 into version_no
    from public.routine_model_versions existing
    where existing.model_id = aggregate_id;

    insert into public.routine_model_versions(
      model_id, version, created_by_person_id
    ) values (aggregate_id, version_no, actor) returning id into version_id;

    for section_item in select value from jsonb_array_elements(p_payload->'sections') loop
      insert into public.routine_sections(model_version_id, name, sort_order)
      values (
        version_id,
        btrim(coalesce(section_item->>'name','')),
        coalesce((section_item->>'sort_order')::integer, 0)
      ) returning id into section_id;

      for field_item in
        select value from jsonb_array_elements(coalesce(section_item->'fields','[]'::jsonb))
      loop
        insert into public.routine_fields(
          section_id, label, kind, sort_order, is_required,
          initial_value, minimum_value, maximum_value
        ) values (
          section_id,
          btrim(coalesce(field_item->>'label','')),
          coalesce(field_item->>'kind','short_text'),
          coalesce((field_item->>'sort_order')::integer, 0),
          coalesce((field_item->>'is_required')::boolean, false),
          field_item->'initial_value',
          (field_item->>'minimum_value')::numeric,
          (field_item->>'maximum_value')::numeric
        ) returning id into field_id;
        field_ids := field_ids || jsonb_build_object(
          coalesce(field_item->>'id', field_id::text), field_id::text);

        for option_item in
          select value from jsonb_array_elements(coalesce(field_item->'options','[]'::jsonb))
        loop
          insert into public.routine_field_options(field_id, label, sort_order)
          values (
            field_id,
            btrim(coalesce(option_item->>'label','')),
            coalesce((option_item->>'sort_order')::integer, 0)
          ) returning id into option_id;
          option_ids := option_ids || jsonb_build_object(
            coalesce(option_item->>'id', option_id::text), option_id::text);
        end loop;
      end loop;
    end loop;

    for section_item in select value from jsonb_array_elements(p_payload->'sections') loop
      for field_item in
        select value from jsonb_array_elements(coalesce(section_item->'fields','[]'::jsonb))
      loop
        for condition_item in
          select value from jsonb_array_elements(coalesce(field_item->'conditions','[]'::jsonb))
        loop
          insert into public.routine_field_conditions(
            parent_field_id, target_field_id, option_id, boolean_value, depth
          ) values (
            (field_ids->>(condition_item->>'parent_field_id'))::uuid,
            (field_ids->>(condition_item->>'target_field_id'))::uuid,
            (option_ids->>(condition_item->>'option_id'))::uuid,
            (condition_item->>'boolean_value')::boolean,
            coalesce((condition_item->>'depth')::integer, 1)
          );
        end loop;
      end loop;
    end loop;

    perform app_private.validate_routine_definition(version_id);
    update public.routine_model_versions
      set definition_json = app_private.routine_definition_json(version_id),
          published_at = now()
    where id = version_id;
    update public.routine_models
      set current_version_id = version_id, updated_at = now()
    where id = aggregate_id returning * into model_row;
  end if;

  after_json := to_jsonb(model_row);
  response := jsonb_build_object(
    'id', aggregate_id,
    'management_version', model_row.management_version,
    'version', coalesce(version_no, 0),
    'version_id', version_id
  );
  insert into app_private.routine_command_receipts
    values (p_request_id, actor, 'save_model', aggregate_id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, before_json, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'routine.model.save', 'routine_model', aggregate_id,
    model_row.institution_id, 'success', before_json, after_json
  );
  return response;
end
$$;

create or replace function app_private.superadmin_routine_save_launch_draft(
  p_request_id uuid,
  p_launch_id uuid,
  p_expected_version bigint,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid;
  aggregate_id uuid := coalesce(p_launch_id, gen_random_uuid());
  launch_row public.routine_launches;
  application_row public.routine_applications;
  revision_row public.routine_application_revisions;
  entry_item jsonb;
  answer_item jsonb;
  entry_id uuid;
  response jsonb;
begin
  actor := app_private.require_routine_actor('routine.record', false);
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text, 0));
  response := app_private.routine_receipt(p_request_id, actor, 'save_launch_draft');
  if response is not null then return response; end if;

  if p_launch_id is not null then
    select * into launch_row
    from public.routine_launches
    where id = aggregate_id
      and app_private.routine_scope_allowed(
        'routine.record', institution_id, unit_id, group_id)
    for update;
    if launch_row.id is null then
      raise no_data_found using message='routine launch unavailable';
    end if;
    if launch_row.management_version <> p_expected_version then
      raise serialization_failure using message='expected_version mismatch';
    end if;
    if launch_row.status <> 'draft' then
      raise check_violation using message='routine launch is not a draft';
    end if;
    select * into application_row from public.routine_applications
    where id = launch_row.application_id;
  else
    if p_expected_version <> 0 then
      raise serialization_failure using message='expected_version mismatch';
    end if;
    select * into application_row from public.routine_applications
    where id = (p_payload->>'application_id')::uuid;
    if application_row.id is null then
      raise no_data_found using message='routine application unavailable';
    end if;
    perform app_private.require_routine_scope(
      'routine.record', application_row.institution_id,
      application_row.unit_id, application_row.group_id, false
    );
    select * into revision_row from public.routine_application_revisions
    where application_id = application_row.id
    order by revision_no desc limit 1;
    insert into public.routine_launches(
      id, institution_id, unit_id, group_id, application_id,
      application_revision_id, launch_date, status, created_by_person_id
    ) values (
      aggregate_id, application_row.institution_id, application_row.unit_id,
      application_row.group_id, application_row.id, revision_row.id,
      coalesce((p_payload->>'launch_date')::date, current_date), 'draft', actor
    ) returning * into launch_row;
  end if;

  for entry_item in
    select value from jsonb_array_elements(coalesce(p_payload->'entries','[]'::jsonb))
  loop
    insert into public.routine_child_entries(launch_id, child_context_id)
    values (aggregate_id, (entry_item->>'child_context_id')::uuid)
    on conflict (launch_id, child_context_id) do update set launch_id = excluded.launch_id
    returning id into entry_id;

    for answer_item in
      select value from jsonb_array_elements(coalesce(entry_item->'answers','[]'::jsonb))
    loop
      insert into public.routine_answers(
        child_entry_id, field_id, value_json, answered_by_person_id, answered_at
      ) values (
        entry_id, (answer_item->>'field_id')::uuid, answer_item->'value', actor, now()
      )
      on conflict (child_entry_id, field_id) do update set
        value_json = excluded.value_json,
        answered_by_person_id = excluded.answered_by_person_id,
        answered_at = excluded.answered_at;
    end loop;
  end loop;

  perform app_private.validate_routine_launch_answers(aggregate_id, false);

  update public.routine_launches
    set management_version = management_version + 1, updated_at = now()
  where id = aggregate_id returning * into launch_row;

  response := jsonb_build_object(
    'id', aggregate_id,
    'management_version', launch_row.management_version,
    'status', launch_row.status
  );
  insert into app_private.routine_command_receipts
    values (p_request_id, actor, 'save_launch_draft', aggregate_id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'routine.launch.save_draft', 'routine_launch',
    aggregate_id, launch_row.institution_id, 'success', response
  );
  return response;
end
$$;

create or replace function app_private.superadmin_routine_publish_launch(
  p_request_id uuid,
  p_launch_id uuid,
  p_expected_version bigint
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  launch_row public.routine_launches;
  response jsonb;
begin
  if actor is null then
    raise insufficient_privilege using message='authentication required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_launch_id::text, 0));
  response := app_private.routine_receipt(p_request_id, actor, 'publish_launch');
  if response is not null then return response; end if;

  select launch.* into launch_row
  from public.routine_launches launch
  where launch.id = p_launch_id
    and app_private.routine_scope_allowed(
      'routine.publish', launch.institution_id, launch.unit_id, launch.group_id)
  for update;
  if launch_row.id is null then
    raise insufficient_privilege using message='routine.publish required';
  end if;
  if app_private.routine_mfa_phase_enforced() and not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message='MFA AAL2 required';
  end if;
  if launch_row.management_version <> p_expected_version
    or launch_row.status <> 'draft' then
    raise serialization_failure using message='expected_version mismatch';
  end if;

  perform app_private.validate_routine_launch_answers(p_launch_id, true);

  update public.routine_launches set
    status = 'published',
    published_at = now(),
    published_by_person_id = actor,
    management_version = management_version + 1,
    updated_at = now()
  where id = p_launch_id returning * into launch_row;

  insert into public.context_notification_events(
    institution_id, unit_id, group_id, event_code, object_type, object_id,
    payload_json, created_by_person_id
  ) values (
    launch_row.institution_id, launch_row.unit_id, launch_row.group_id,
    'routine_launch_published', 'routine_launch', p_launch_id,
    jsonb_build_object('launch_date', launch_row.launch_date), actor
  );

  response := jsonb_build_object(
    'id', p_launch_id,
    'management_version', launch_row.management_version,
    'status', 'published'
  );
  insert into app_private.routine_command_receipts
    values (p_request_id, actor, 'publish_launch', p_launch_id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'routine.launch.publish', 'routine_launch',
    p_launch_id, launch_row.institution_id, 'success', response
  );
  return response;
end
$$;

-- ---------------------------------------------------------------------------
-- Comandos de aplicacao e correcao (corpos de 20260825193112)
-- ---------------------------------------------------------------------------
--
-- Copiados verbatim de
-- 20260825193112_final_review_daily_routine_lint_hardening.sql. Aquela
-- migration nasceu como CREATE OR REPLACE sobre funcoes de uma fundacao que
-- nunca existiu, e ficou fora do manifesto replay/foundation-migrations.sha256,
-- entao o perfil de replay local jamais a aplica. Repetir os corpos aqui torna
-- a familia replayavel e testavel sem alterar o comportamento: na cadeia real
-- este CREATE OR REPLACE roda depois, com o mesmo texto. As regressoes de
-- escopo em daily_routine_scope_closure_test.sql conferem justamente este
-- texto, entao ele nao pode ser reformatado.

CREATE OR REPLACE FUNCTION app_private.superadmin_routine_save_application(p_request_id uuid, p_application_id uuid, p_expected_version bigint, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor uuid;
  aggregate_id uuid := coalesce(p_application_id, gen_random_uuid());
  app_row public.routine_applications;
  response jsonb;
  revision_id uuid;
  revision_no integer;
begin
  actor := app_private.require_routine_actor('routine.manage_applications', false);
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text, 0));
  response := app_private.routine_receipt(p_request_id, actor, 'save_application');
  if response is not null then return response; end if;

  if p_application_id is not null then
    select * into app_row
    from public.routine_applications
    where id = aggregate_id
      and app_private.routine_scope_allowed('routine.manage_applications', institution_id, unit_id, group_id)
    for update;
    if app_row.id is null then
      raise no_data_found using message = 'routine application unavailable';
    end if;
  end if;

  if app_row.id is null then
    if p_expected_version <> 0 then
      raise serialization_failure using message = 'expected_version mismatch';
    end if;
    perform app_private.require_routine_scope(
      'routine.manage_applications',
      (p_payload->>'institution_id')::uuid,
      (p_payload->>'unit_id')::uuid,
      (p_payload->>'group_id')::uuid,
      false
    );
    insert into public.routine_applications(
      id,institution_id,unit_id,group_id,activity_id,scope_kind,source_model_version_id,
      parent_application_id,inheritance_mode,visibility,valid_from,valid_until,starts_at,
      ends_at,status,created_by_person_id
    ) values (
      aggregate_id,(p_payload->>'institution_id')::uuid,(p_payload->>'unit_id')::uuid,
      (p_payload->>'group_id')::uuid,(p_payload->>'activity_id')::uuid,p_payload->>'scope_kind',
      (p_payload->>'source_model_version_id')::uuid,(p_payload->>'parent_application_id')::uuid,
      coalesce(p_payload->>'inheritance_mode','inherited'),
      coalesce(p_payload->>'visibility','authorized_guardians'),(p_payload->>'valid_from')::date,
      (p_payload->>'valid_until')::date,(p_payload->>'starts_at')::time,
      (p_payload->>'ends_at')::time,coalesce(p_payload->>'status','draft'),actor
    ) returning * into app_row;
  else
    if app_row.management_version <> p_expected_version then
      raise serialization_failure using message = 'expected_version mismatch';
    end if;
    update public.routine_applications set
      source_model_version_id=(p_payload->>'source_model_version_id')::uuid,
      parent_application_id=(p_payload->>'parent_application_id')::uuid,
      inheritance_mode=coalesce(p_payload->>'inheritance_mode',inheritance_mode),
      visibility=coalesce(p_payload->>'visibility',visibility),
      valid_from=(p_payload->>'valid_from')::date,valid_until=(p_payload->>'valid_until')::date,
      starts_at=(p_payload->>'starts_at')::time,ends_at=(p_payload->>'ends_at')::time,
      status=coalesce(p_payload->>'status',status),management_version=management_version+1,
      updated_at=now()
    where id=aggregate_id returning * into app_row;
  end if;

  select coalesce(max(revision_row.revision_no),0)+1 into revision_no
  from public.routine_application_revisions revision_row where revision_row.application_id=aggregate_id;
  insert into public.routine_application_revisions(
    application_id,revision_no,source_model_version_id,origin_application_id,effective_definition,created_by_person_id
  ) values (
    aggregate_id,revision_no,app_row.source_model_version_id,
    coalesce(app_row.parent_application_id,aggregate_id),
    app_private.routine_definition_json(app_row.source_model_version_id),actor
  ) returning id into revision_id;
  delete from public.routine_application_assignees where application_id=aggregate_id;
  insert into public.routine_application_assignees(application_id,institution_id,membership_id,responsibility)
  select aggregate_id,app_row.institution_id,(x->>'membership_id')::uuid,coalesce(x->>'responsibility','record')
  from jsonb_array_elements(coalesce(p_payload->'assignees','[]')) x;
  response:=jsonb_build_object('id',aggregate_id,'management_version',app_row.management_version,
    'revision_id',revision_id,'revision',revision_no);
  insert into app_private.routine_command_receipts values(p_request_id,actor,'save_application',aggregate_id,response,now());
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
  values(actor,auth.jwt()->>'aal','routine.application.save','routine_application',aggregate_id,app_row.institution_id,'success',response);
  return response;
end $function$;

CREATE OR REPLACE FUNCTION app_private.superadmin_routine_revert_application(uuid, uuid, bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor uuid;
  app_row public.routine_applications;
  parent_row public.routine_applications;
  response jsonb;
  revision_no integer;
begin
  actor:=app_private.require_routine_actor('routine.manage_applications',false);
  perform pg_advisory_xact_lock(hashtextextended($2::text,0));
  response:=app_private.routine_receipt($1,actor,'revert_application');
  if response is not null then return response; end if;
  select * into app_row
  from public.routine_applications
  where id=$2
    and app_private.routine_scope_allowed('routine.manage_applications', institution_id, unit_id, group_id)
  for update;
  if app_row.id is null then
    raise no_data_found using message='routine application unavailable';
  end if;
  if app_row.management_version<>$3 or app_row.parent_application_id is null then
    raise serialization_failure using message='expected_version mismatch';
  end if;
  select * into parent_row from public.routine_applications
  where id=app_row.parent_application_id and institution_id=app_row.institution_id;
  if parent_row.id is null then
    raise no_data_found using message='routine application unavailable';
  end if;
  update public.routine_applications set source_model_version_id=parent_row.source_model_version_id,
    inheritance_mode='inherited',management_version=management_version+1,updated_at=now()
  where id=$2 returning * into app_row;
  select coalesce(max(revision_row.revision_no),0)+1 into revision_no
  from public.routine_application_revisions revision_row where revision_row.application_id=$2;
  insert into public.routine_application_revisions(
    application_id,revision_no,source_model_version_id,origin_application_id,effective_definition,created_by_person_id
  ) values ($2,revision_no,app_row.source_model_version_id,parent_row.id,
    app_private.routine_definition_json(app_row.source_model_version_id),actor);
  response:=jsonb_build_object('id',$2,'management_version',app_row.management_version,'inherited',true);
  insert into app_private.routine_command_receipts values($1,actor,'revert_application',$2,response,now());
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
  values(actor,auth.jwt()->>'aal','routine.application.revert','routine_application',$2,app_row.institution_id,'success',response);
  return response;
end $function$;

CREATE OR REPLACE FUNCTION app_private.superadmin_routine_correct_launch(uuid, uuid, bigint, text, jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=app_private.current_person_id(); launch_row public.routine_launches; before_state jsonb; after_state jsonb; response jsonb; item jsonb; next_revision integer; supplied integer;
begin
  if actor is null then raise insufficient_privilege using message='authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended($2::text,0));
  response:=app_private.routine_receipt($1,actor,'correct_launch'); if response is not null then return response; end if;
  select l.* into launch_row from public.routine_launches l where l.id=$2
    and app_private.routine_scope_allowed('routine.correct',l.institution_id,l.unit_id,l.group_id) for update;
  if launch_row.id is null then raise insufficient_privilege using message='routine.correct required'; end if;
  if not app_private.has_mfa_aal2() then raise insufficient_privilege using message='MFA AAL2 required'; end if;
  if btrim(coalesce($4,''))='' then raise check_violation using message='correction reason required'; end if;
  if jsonb_typeof($5) <> 'array' or jsonb_array_length($5) not between 1 and 500 then raise invalid_parameter_value using message='invalid routine correction payload'; end if;
  supplied := jsonb_array_length($5);
  if supplied <> (select count(distinct payload_item.value->>'answer_id') from jsonb_array_elements($5) as payload_item(value) where payload_item.value ? 'answer_id')
    or supplied <> (select count(*) from public.routine_answers a join public.routine_child_entries e on e.id=a.child_entry_id
      where e.launch_id=$2 and a.id in (select (payload_item.value->>'answer_id')::uuid from jsonb_array_elements($5) as payload_item(value))) then
    raise check_violation using message='routine correction answer mismatch';
  end if;
  if launch_row.management_version<>$3 or launch_row.status not in ('published','corrected') then raise serialization_failure using message='expected_version mismatch'; end if;
  select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]') into before_state from public.routine_answers a join public.routine_child_entries e on e.id=a.child_entry_id where e.launch_id=$2;
  for item in select value from jsonb_array_elements($5) loop
    update public.routine_answers a set value_json=item->'value',answered_by_person_id=actor,answered_at=now()
    from public.routine_child_entries e where a.id=(item->>'answer_id')::uuid and e.id=a.child_entry_id and e.launch_id=$2;
  end loop;
  perform app_private.validate_routine_launch_answers($2,true);
  select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]') into after_state from public.routine_answers a join public.routine_child_entries e on e.id=a.child_entry_id where e.launch_id=$2;
  select coalesce(max(revision_row.revision_no),0)+1 into next_revision from public.routine_launch_revisions revision_row where revision_row.launch_id=$2;
  insert into public.routine_launch_revisions(launch_id,revision_no,reason,before_json,after_json,changed_by_person_id) values($2,next_revision,btrim($4),before_state,after_state,actor);
  update public.routine_launches set status='corrected',corrected_at=now(),updated_at=now(),management_version=management_version+1 where id=$2 returning * into launch_row;
  response:=jsonb_build_object('id',$2,'management_version',launch_row.management_version,'status','corrected','revision',next_revision);
  insert into app_private.routine_command_receipts values($1,actor,'correct_launch',$2,response,now());
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,reason,before_json,after_json) values(actor,auth.jwt()->>'aal','routine.launch.correct','routine_launch',$2,launch_row.institution_id,'success',btrim($4),before_state,after_state);
  return response;
end $function$;

-- ---------------------------------------------------------------------------
-- Superficie publica
-- ---------------------------------------------------------------------------

create or replace function public.superadmin_routine_directory(
  entry_kind text, search text, status text, institution_id uuid,
  unit_id uuid, group_id uuid, page_limit integer, page_offset integer
) returns jsonb language sql stable security invoker set search_path='' as $$
  select app_private.superadmin_routine_directory(
    entry_kind, search, status, institution_id, unit_id, group_id,
    page_limit, page_offset)
$$;

create or replace function public.superadmin_routine_model_detail(model_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select app_private.superadmin_routine_model_detail(model_id)
$$;

create or replace function public.superadmin_routine_save_model(
  request_id uuid, model_id uuid, expected_version bigint, payload jsonb
) returns jsonb language sql volatile security invoker set search_path='' as $$
  select app_private.superadmin_routine_save_model(
    request_id, model_id, expected_version, payload)
$$;

create or replace function public.superadmin_routine_save_application(
  request_id uuid, application_id uuid, expected_version bigint, payload jsonb
) returns jsonb language sql volatile security invoker set search_path='' as $$
  select app_private.superadmin_routine_save_application(
    request_id, application_id, expected_version, payload)
$$;

create or replace function public.superadmin_routine_revert_application(
  request_id uuid, application_id uuid, expected_version bigint
) returns jsonb language sql volatile security invoker set search_path='' as $$
  select app_private.superadmin_routine_revert_application(
    request_id, application_id, expected_version)
$$;

create or replace function public.superadmin_routine_save_launch_draft(
  request_id uuid, launch_id uuid, expected_version bigint, payload jsonb
) returns jsonb language sql volatile security invoker set search_path='' as $$
  select app_private.superadmin_routine_save_launch_draft(
    request_id, launch_id, expected_version, payload)
$$;

create or replace function public.superadmin_routine_publish_launch(
  request_id uuid, launch_id uuid, expected_version bigint
) returns jsonb language sql volatile security invoker set search_path='' as $$
  select app_private.superadmin_routine_publish_launch(
    request_id, launch_id, expected_version)
$$;

create or replace function public.superadmin_routine_correct_launch(
  request_id uuid, launch_id uuid, expected_version bigint, reason text, payload jsonb
) returns jsonb language sql volatile security invoker set search_path='' as $$
  select app_private.superadmin_routine_correct_launch(
    request_id, launch_id, expected_version, reason, payload)
$$;

-- ---------------------------------------------------------------------------
-- RLS e privilegios
-- ---------------------------------------------------------------------------

do $rls$
declare current_table text;
begin
  foreach current_table in array array[
    'routine_models','routine_model_versions','routine_sections','routine_fields',
    'routine_field_options','routine_field_conditions','routine_applications',
    'routine_application_revisions','routine_application_assignees',
    'routine_launches','routine_child_entries','routine_answers',
    'routine_launch_revisions'
  ] loop
    execute format('alter table public.%I enable row level security', current_table);
    execute format('alter table public.%I force row level security', current_table);
    execute format('revoke all on public.%I from public, anon, authenticated', current_table);
    execute format('grant all on public.%I to service_role', current_table);
    execute format('grant select on public.%I to authenticated', current_table);
  end loop;
end
$rls$;

revoke all on app_private.routine_command_receipts from public, anon, authenticated;
grant all on app_private.routine_command_receipts to service_role;
alter table app_private.routine_command_receipts enable row level security;
alter table app_private.routine_command_receipts force row level security;

create policy routine_models_read on public.routine_models
for select to authenticated using (
  app_private.routine_scope_allowed('routine.read', institution_id, origin_unit_id, null)
);

create policy routine_model_versions_read on public.routine_model_versions
for select to authenticated using (
  exists (
    select 1 from public.routine_models model_row
    where model_row.id = model_id
      and app_private.routine_scope_allowed(
        'routine.read', model_row.institution_id, model_row.origin_unit_id, null)
  )
);

create policy routine_sections_read on public.routine_sections
for select to authenticated using (
  exists (
    select 1
    from public.routine_model_versions version_row
    join public.routine_models model_row on model_row.id = version_row.model_id
    where version_row.id = model_version_id
      and app_private.routine_scope_allowed(
        'routine.read', model_row.institution_id, model_row.origin_unit_id, null)
  )
);

create policy routine_fields_read on public.routine_fields
for select to authenticated using (
  exists (
    select 1
    from public.routine_sections section_row
    join public.routine_model_versions version_row
      on version_row.id = section_row.model_version_id
    join public.routine_models model_row on model_row.id = version_row.model_id
    where section_row.id = section_id
      and app_private.routine_scope_allowed(
        'routine.read', model_row.institution_id, model_row.origin_unit_id, null)
  )
);

create policy routine_field_options_read on public.routine_field_options
for select to authenticated using (
  exists (
    select 1
    from public.routine_fields field_row
    join public.routine_sections section_row on section_row.id = field_row.section_id
    join public.routine_model_versions version_row
      on version_row.id = section_row.model_version_id
    join public.routine_models model_row on model_row.id = version_row.model_id
    where field_row.id = field_id
      and app_private.routine_scope_allowed(
        'routine.read', model_row.institution_id, model_row.origin_unit_id, null)
  )
);

create policy routine_field_conditions_read on public.routine_field_conditions
for select to authenticated using (
  exists (
    select 1
    from public.routine_fields field_row
    join public.routine_sections section_row on section_row.id = field_row.section_id
    join public.routine_model_versions version_row
      on version_row.id = section_row.model_version_id
    join public.routine_models model_row on model_row.id = version_row.model_id
    where field_row.id = target_field_id
      and app_private.routine_scope_allowed(
        'routine.read', model_row.institution_id, model_row.origin_unit_id, null)
  )
);

create policy routine_applications_read on public.routine_applications
for select to authenticated using (
  app_private.routine_scope_allowed('routine.read', institution_id, unit_id, group_id)
);

create policy routine_application_revisions_read on public.routine_application_revisions
for select to authenticated using (
  exists (
    select 1 from public.routine_applications application_row
    where application_row.id = application_id
      and app_private.routine_scope_allowed(
        'routine.read', application_row.institution_id,
        application_row.unit_id, application_row.group_id)
  )
);

create policy routine_application_assignees_read on public.routine_application_assignees
for select to authenticated using (
  exists (
    select 1 from public.routine_applications application_row
    where application_row.id = application_id
      and app_private.routine_scope_allowed(
        'routine.read', application_row.institution_id,
        application_row.unit_id, application_row.group_id)
  )
);

create policy routine_launches_read on public.routine_launches
for select to authenticated using (
  app_private.routine_scope_allowed('routine.read', institution_id, unit_id, group_id)
);

create policy routine_child_entries_read on public.routine_child_entries
for select to authenticated using (
  exists (
    select 1 from public.routine_launches launch_row
    where launch_row.id = launch_id
      and app_private.routine_scope_allowed(
        'routine.read', launch_row.institution_id, launch_row.unit_id, launch_row.group_id)
  )
);

create policy routine_answers_read on public.routine_answers
for select to authenticated using (
  exists (
    select 1
    from public.routine_child_entries entry_row
    join public.routine_launches launch_row on launch_row.id = entry_row.launch_id
    where entry_row.id = child_entry_id
      and app_private.routine_scope_allowed(
        'routine.read', launch_row.institution_id, launch_row.unit_id, launch_row.group_id)
  )
);

create policy routine_launch_revisions_read on public.routine_launch_revisions
for select to authenticated using (
  exists (
    select 1 from public.routine_launches launch_row
    where launch_row.id = launch_id
      and app_private.routine_scope_allowed(
        'routine.read', launch_row.institution_id, launch_row.unit_id, launch_row.group_id)
  )
);

revoke all on public.daily_routine_effective_applications from public, anon, authenticated;
grant select on public.daily_routine_effective_applications to authenticated, service_role;

do $grants$
declare current_signature text;
begin
  foreach current_signature in array array[
    'app_private.routine_mfa_phase_enforced()',
    'app_private.routine_scope_allowed(text,uuid,uuid,uuid)',
    'app_private.require_routine_actor(text,boolean)',
    'app_private.require_routine_scope(text,uuid,uuid,uuid,boolean)',
    'app_private.routine_receipt(uuid,uuid,text)',
    'app_private.routine_definition_json(uuid)',
    'app_private.validate_routine_definition(uuid)',
    'app_private.validate_routine_launch_answers(uuid,boolean)',
    'app_private.validate_routine_application_hierarchy()',
    'app_private.superadmin_routine_directory(text,text,text,uuid,uuid,uuid,integer,integer)',
    'app_private.superadmin_routine_model_detail(uuid)',
    'app_private.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)',
    'app_private.superadmin_routine_save_application(uuid,uuid,bigint,jsonb)',
    'app_private.superadmin_routine_revert_application(uuid,uuid,bigint)',
    'app_private.superadmin_routine_save_launch_draft(uuid,uuid,bigint,jsonb)',
    'app_private.superadmin_routine_publish_launch(uuid,uuid,bigint)',
    'app_private.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated',
      current_signature);
  end loop;

  foreach current_signature in array array[
    'public.superadmin_routine_directory(text,text,text,uuid,uuid,uuid,integer,integer)',
    'public.superadmin_routine_model_detail(uuid)',
    'public.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)',
    'public.superadmin_routine_save_application(uuid,uuid,bigint,jsonb)',
    'public.superadmin_routine_revert_application(uuid,uuid,bigint)',
    'public.superadmin_routine_save_launch_draft(uuid,uuid,bigint,jsonb)',
    'public.superadmin_routine_publish_launch(uuid,uuid,bigint)',
    'public.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated',
      current_signature);
    execute format('grant execute on function %s to authenticated, service_role',
      current_signature);
  end loop;
end
$grants$;

commit;
