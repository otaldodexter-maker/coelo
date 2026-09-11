-- 20260911220000_daily_routine_directory_can_manage_v1
-- Frente R05 · Formulários, Cuidado e Rotina. F-R04-FCR-009.
--
-- Problema medido na rota real (11/09, /daily-routine com qa-r03): o cliente
-- derivava canManage das linhas do diretório (rows.any(can_manage)), mas o
-- envelope de app_private.superadmin_routine_directory nunca projetou
-- can_manage por item nem no topo; com o diretório vazio a tela nasce
-- "somente leitura" e o card Criar some. Regra da skill coelo-backend: a
-- capacidade de criar/gerir é devolvida no topo do envelope do diretório,
-- nunca inferida pelo cliente.
--
-- O que este pacote faz: CREATE OR REPLACE de app_private.superadmin_routine_directory
-- com o mesmo corpo vigente (20260910010100) e a chave `can_manage` no topo:
--   true quando o ator tem routine.manage_models de plataforma ou por membership
--   ativa em alguma instituição (app_private.has_context_permission), o mesmo
--   predicado de app_private.routine_scope_allowed usado nos detalhes.
-- Sem tabela nova, sem grant novo, sem AAL2, sem segredo. Reversão
-- forward-only: reaplicar o corpo de 20260910010100.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if to_regprocedure('app_private.superadmin_routine_directory(text,text,text,uuid,uuid,uuid,integer,integer)') is null then
    raise exception 'preflight: app_private.superadmin_routine_directory ausente (lote 2 nao aplicado)';
  end if;
  if to_regprocedure('app_private.routine_scope_allowed(text,uuid,uuid,uuid)') is null then
    raise exception 'preflight: app_private.routine_scope_allowed ausente';
  end if;
end
$preflight$;

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
    'offset', page_offset,
    -- capacidade de criar/gerir no topo do envelope (F-R04-FCR-009)
    'can_manage', app_private.has_platform_permission('routine.manage_models')
      or exists (
        select 1
        from public.institution_memberships membership
        where membership.person_id = actor
          and membership.status = 'active'
          and membership.revoked_at is null
          and app_private.routine_scope_allowed(
            'routine.manage_models', membership.institution_id, null, null)
      )
  );
end
$$;


commit;
