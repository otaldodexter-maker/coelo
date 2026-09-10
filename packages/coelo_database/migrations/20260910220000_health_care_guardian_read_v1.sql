-- Saude e cuidado: o responsavel autorizado passa a ler a propria crianca.
--
-- Decisao do Owner em 2026-09-10 (ADR 0034, Decisao 9), em resposta a pergunta
-- "quem pode ler dado de saude de uma crianca, alem da instituicao?": opcao 1,
-- o responsavel autorizado le o perfil de cuidado e os planos de medicacao da
-- propria crianca.
--
-- Ate aqui o pacote 20260910010300/010400 deixou isso deliberadamente de fora,
-- porque criar uma capacidade de guardiao sem decisao seria escolher sozinho
-- quem enxerga dado de saude de crianca. Com a decisao tomada, esta migration
-- implementa exatamente isso e nada alem.
--
-- Tres limites que a implementacao respeita:
--
--   1. Somente leitura. O responsavel nunca alcanca health_care.manage,
--      medication.manage nem medication.record_evidence. O ramo de guardiao so
--      existe para os dois codigos de leitura.
--   2. Somente a propria crianca. A autorizacao vem de
--      guardian_has_capability(child_context_id, ...), que ja exige vinculo
--      ativo, permissao de contexto vigente e concessao ativa daquela
--      capacidade para AQUELE contexto infantil.
--   3. Sem diretorio. O responsavel nao enumera nada: as duas RPCs proprias
--      exigem o contexto infantil como argumento e nao aceitam busca, filtro
--      nem paginacao. Enumerar e uma superficie de instituicao.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '600s';
select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('coelo.health-care.guardian-read', 0)
);

do $preflight$
begin
  if current_user <> 'postgres' then
    raise exception using errcode='42501',
      message='health care guardian read must run as postgres';
  end if;
  if pg_catalog.to_regprocedure(
    'app_private.health_care_scope_allowed(text,uuid,uuid,uuid,uuid)') is null then
    raise exception using errcode='55000',
      message='health care guardian read requires the health care behavior package';
  end if;
  if pg_catalog.to_regprocedure(
    'app_private.guardian_has_capability(uuid,text)') is null then
    raise exception using errcode='55000',
      message='health care guardian read requires the guardian capability core';
  end if;
end
$preflight$;

insert into public.guardian_permission_capabilities(
  code, name, description, module_code, module_label,
  screen_code, screen_label, action_code, action_label, risk_level, requires_mfa
) values (
  'view_health_care',
  'Ver saude e cuidado',
  'Ler o perfil de cuidado e os planos de medicacao da propria crianca.',
  'principal', 'Principal', 'health_care', 'Saude e cuidado',
  'view', 'Ver', 'high', false
)
on conflict (code) do update set
  name=excluded.name, description=excluded.description,
  module_code=excluded.module_code, module_label=excluded.module_label,
  screen_code=excluded.screen_code, screen_label=excluded.screen_label,
  action_code=excluded.action_code, action_label=excluded.action_label,
  risk_level=excluded.risk_level, status='active', updated_at=now();

-- O ramo de guardiao entra SO nos dois codigos de leitura. Escrever continua
-- exigindo capacidade de plataforma ou contextual, como antes.
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
      or (
        p_permission in ('health_care.read', 'medication.read')
        and p_child_context_id is not null
        and app_private.guardian_has_capability(p_child_context_id, 'view_health_care')
      )
    )
$$;

-- ---------------------------------------------------------------------------
-- Superficie do responsavel
-- ---------------------------------------------------------------------------

-- Nao reaproveita superadmin_health_care_profile_detail de proposito: aquela
-- comeca por require_health_care_actor, que exige capacidade de plataforma ou
-- membership institucional, e afrouxar aquele portao para caber o responsavel
-- abriria o diretorio inteiro junto. Esta e uma porta estreita e separada.
create or replace function app_private.health_care_profile_for_guardian(
  p_child_context_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  profile_row public.health_care_profiles;
begin
  if actor is null then
    raise insufficient_privilege using message='authentication required';
  end if;
  if p_child_context_id is null
    or not app_private.guardian_has_capability(p_child_context_id, 'view_health_care') then
    -- Negativa opaca: a mesma resposta para uma crianca que nao existe e para
    -- uma que existe e nao e sua.
    raise no_data_found using message='health care profile unavailable';
  end if;
  select * into profile_row
  from public.health_care_profiles
  where child_context_id = p_child_context_id;
  if profile_row.id is null then
    raise no_data_found using message='health care profile unavailable';
  end if;

  return jsonb_build_object(
    'id', profile_row.id,
    'child_context_id', profile_row.child_context_id,
    'operational_status', profile_row.operational_status,
    'important_signs', profile_row.important_signs,
    'adaptations', profile_row.adaptations,
    -- A projecao para a familia nao carrega a versao esperada do agregado nem
    -- a marca de quem pode gerir: o responsavel nao edita, entao entregar isso
    -- seria entregar municao para uma escrita que o servidor recusaria.
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'catalog_item_id', item_row.catalog_item_id,
        'other_text', item_row.other_text) order by item_row.catalog_item_id)
      from public.health_care_profile_items item_row
      where item_row.profile_id = profile_row.id), '[]'::jsonb),
    'allergies', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', allergy_row.id,
        'label', allergy_row.label,
        'allergy_type', allergy_row.allergy_type,
        'status', allergy_row.status,
        'active', allergy_row.active,
        'last_episode_at', allergy_row.last_episode_at,
        'episode_severity', allergy_row.episode_severity,
        'observed_reaction', allergy_row.observed_reaction,
        'guidance', allergy_row.guidance,
        'notes', allergy_row.notes) order by allergy_row.created_at)
      from public.health_care_allergies allergy_row
      where allergy_row.profile_id = profile_row.id), '[]'::jsonb)
    -- A trilha com justificativa fica de fora: ela e da instituicao e mostra
    -- quem mudou o que. Nao e projecao minima para a familia.
  );
end
$$;

create or replace function app_private.medication_plans_for_guardian(
  p_child_context_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
begin
  if actor is null then
    raise insufficient_privilege using message='authentication required';
  end if;
  if p_child_context_id is null
    or not app_private.guardian_has_capability(p_child_context_id, 'view_health_care') then
    raise no_data_found using message='medication plan unavailable';
  end if;

  return jsonb_build_object('items', coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', plan_row.id,
      'status', plan_row.status,
      'medication_name', version_row.medication_name,
      'dose_amount', version_row.dose_amount,
      'dose_unit', version_row.dose_unit,
      'administration_route', version_row.administration_route,
      'instructions', version_row.instructions,
      'valid_from', version_row.valid_from,
      'valid_until', version_row.valid_until,
      'timezone', version_row.timezone,
      'schedules', coalesce((
        select jsonb_agg(jsonb_build_object(
          'time_of_day', schedule_row.time_of_day,
          'weekdays', schedule_row.weekdays,
          'timezone', schedule_row.timezone) order by schedule_row.time_of_day)
        from public.medication_plan_schedules schedule_row
        where schedule_row.plan_version_id = version_row.id), '[]'::jsonb)
      -- Sem evidencia de administracao: quem administrou e quando e registro
      -- operacional da instituicao. Se a familia precisar disso, e outra
      -- decisao, com outra capacidade.
    ) order by plan_row.updated_at desc)
    from public.medication_plans plan_row
    left join public.medication_plan_versions version_row
      on version_row.id = plan_row.current_version_id
    where plan_row.child_context_id = p_child_context_id
      and plan_row.status <> 'draft'
  ), '[]'::jsonb));
end
$$;

create or replace function public.health_care_profile_for_guardian(child_context_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select app_private.health_care_profile_for_guardian(child_context_id)
$$;

create or replace function public.medication_plans_for_guardian(child_context_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select app_private.medication_plans_for_guardian(child_context_id)
$$;

do $grants$
declare current_signature text;
begin
  foreach current_signature in array array[
    'app_private.health_care_profile_for_guardian(uuid)',
    'app_private.medication_plans_for_guardian(uuid)',
    'public.health_care_profile_for_guardian(uuid)',
    'public.medication_plans_for_guardian(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated',
      current_signature);
    execute format('grant execute on function %s to authenticated, service_role',
      current_signature);
  end loop;
end
$grants$;

commit;
