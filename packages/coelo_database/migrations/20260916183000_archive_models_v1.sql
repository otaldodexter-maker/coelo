-- R14 Sessao 9 / ADR 0041 B1 (owner.r12-02): Arquivar e restaurar modelos de
-- Atividade (public.activity_templates) e de Rotina (public.routine_models)
-- como inativacao reversivel (OQ-033 opcao B). Contrato em
-- specs/052-archive-activity-routine-models.md.
--
-- Atividade: coluna management_version, recibos privados de ciclo de vida,
-- leitor de diretorio v1 (todos os status + versao) e comandos
-- archive/restore v1 no contexto interno (activities.templates.manage).
-- Rotina: tabela privada com o status anterior, comandos archive/restore v1
-- (routine.manage_models, recibo + audit.audit_logs) e o diretorio passa a
-- excluir arquivados quando p_status e nulo (model e application); o restante
-- do corpo de superadmin_routine_directory e identico ao dump de producao de
-- 16/09 (SHA-256 f1f677ca).
--
-- Versao defasada usa SQLSTATE PT409 (HTTP 409, sem retentativa do PostgREST;
-- OQ-047), nunca serialization_failure. Forward-only e idempotente.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'archive models v1 must run as postgres';
  end if;
  if to_regclass('public.activity_templates') is null
    or to_regclass('public.routine_models') is null
    or to_regclass('app_private.routine_command_receipts') is null
    or to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regprocedure('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)') is null
    or to_regprocedure('app_private.require_routine_actor(text,boolean)') is null
    or to_regprocedure('app_private.routine_receipt(uuid,uuid,text)') is null
    or to_regprocedure('app_private.routine_scope_allowed(text,uuid,uuid,uuid)') is null
    or to_regprocedure('app_private.superadmin_routine_directory(text,text,text,uuid,uuid,uuid,integer,integer)') is null
    or to_regprocedure('public.superadmin_activity_template_options(uuid)') is null then
    raise object_not_in_prerequisite_state using message = 'activity templates and routine models foundations are required';
  end if;
end
$preflight$;

-- ---------------------------------------------------------------------------
-- Atividade: versao de gestao + recibos privados
-- ---------------------------------------------------------------------------
alter table public.activity_templates
  add column if not exists management_version bigint not null default 0;

create table if not exists app_private.superadmin_internal_activity_template_lifecycle_receipts (
  request_id uuid primary key,
  internal_identity_id uuid not null,
  template_id uuid not null,
  command text not null check (command in ('archive', 'restore')),
  request_hash bytea not null check (octet_length(request_hash) = 32),
  result_json jsonb not null check (jsonb_typeof(result_json) = 'object'),
  correlation_id uuid not null,
  created_at timestamptz not null default now()
);
alter table app_private.superadmin_internal_activity_template_lifecycle_receipts owner to postgres;
alter table app_private.superadmin_internal_activity_template_lifecycle_receipts enable row level security;
alter table app_private.superadmin_internal_activity_template_lifecycle_receipts force row level security;
revoke all on table app_private.superadmin_internal_activity_template_lifecycle_receipts from public, anon, authenticated;

-- Leitor do diretorio de modelos: mesmo envelope das opcoes, todos os status,
-- management_version por item. O leitor de opcoes (formulario) nao muda.
create or replace function app_private.superadmin_activity_template_directory_v1(p_institution_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context;
  effective_institution_id uuid;
  result jsonb;
begin
  select * into strict ctx
  from app_private.require_superadmin_internal_context('activities.read');
  if p_institution_id is not null and not exists(
    select 1 from public.institutions institution
    where institution.id=p_institution_id
  ) then
    raise no_data_found using message='institution not found';
  end if;
  if p_institution_id is not null
     and ctx.scope_kind='institution'
     and ctx.scope_institution_id is distinct from p_institution_id then
    raise insufficient_privilege using message='institution scope denied',detail='SAI_PERMISSION_DENIED';
  end if;
  effective_institution_id:=coalesce(
    p_institution_id,
    case when ctx.scope_kind='institution' then ctx.scope_institution_id end
  );
  select jsonb_build_object(
    'institutions',coalesce((select jsonb_agg(jsonb_build_object(
      'id',institution.id,'name',institution.public_name) order by institution.public_name)
      from public.institutions institution
      where effective_institution_id is null
         or institution.id=effective_institution_id),'[]'::jsonb),
    'units',coalesce((select jsonb_agg(jsonb_build_object(
      'id',unit.id,'institution_id',unit.institution_id,'name',unit.name) order by unit.name)
      from public.units unit
      where unit.status<>'archived'
       and (effective_institution_id is null
        or unit.institution_id=effective_institution_id)),'[]'::jsonb),
    'taxonomy',coalesce((select jsonb_agg(jsonb_build_object(
      'id',category.id,'label',category.name,'is_other',category.code='outros',
      'subtypes',coalesce((select jsonb_agg(jsonb_build_object(
        'id',subtype.id,'label',subtype.name) order by subtype.sort_order,subtype.name)
        from public.activity_taxonomies subtype
        where subtype.parent_id=category.id and subtype.status='active'),'[]'::jsonb))
      order by category.sort_order,category.name)
      from public.activity_taxonomies category
      where category.taxonomy_kind='category' and category.status='active'),'[]'::jsonb),
    'templates',coalesce((select jsonb_agg(jsonb_build_object(
      'id',template.id,'name',template.name,'description',template.description,
      'scope_kind',template.scope_kind,'institution_id',template.institution_id,
      'unit_id',template.unit_id,'governance_kind',template.governance_kind,
      'taxonomy_id',coalesce(taxonomy.parent_id,taxonomy.id),
      'subtype_id',case when taxonomy.taxonomy_kind='subtype' then taxonomy.id end,
      'status',template.status,
      'management_version',template.management_version,
      'archived_at',template.template_payload#>>'{lifecycle,archived_at}')
      order by template.scope_kind desc,template.name)
      from public.activity_templates template
      join public.activity_taxonomies taxonomy on taxonomy.id=template.taxonomy_id
      where template.scope_kind='platform'
        or (effective_institution_id is not null
         and template.institution_id=effective_institution_id)),
      '[]'::jsonb)
  ) into result;
  return result;
end $$;
alter function app_private.superadmin_activity_template_directory_v1(uuid) owner to postgres;
revoke all on function app_private.superadmin_activity_template_directory_v1(uuid) from public, anon;

create or replace function public.superadmin_activity_template_directory_v1(p_institution_id uuid)
returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_activity_template_directory_v1(p_institution_id)
$$;
alter function public.superadmin_activity_template_directory_v1(uuid) owner to postgres;
revoke all on function public.superadmin_activity_template_directory_v1(uuid) from public, anon;
grant execute on function public.superadmin_activity_template_directory_v1(uuid) to authenticated, service_role;

-- Comando compartilhado de ciclo de vida do modelo de Atividade.
create or replace function app_private.superadmin_activity_template_lifecycle_v1(
  p_command text, p_template_id uuid, p_expected_version bigint, p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context;
  template public.activity_templates%rowtype;
  receipt app_private.superadmin_internal_activity_template_lifecycle_receipts%rowtype;
  request_hash bytea;
  correlation_id uuid := gen_random_uuid();
  restored_status public.record_status;
  result jsonb;
begin
  select * into strict ctx
  from app_private.require_superadmin_internal_context('activities.templates.manage');
  if p_command not in ('archive', 'restore')
     or p_template_id is null or p_expected_version is null or p_idempotency_key is null then
    raise invalid_parameter_value using message='invalid activity template lifecycle request';
  end if;
  request_hash := extensions.digest(convert_to(jsonb_build_object(
    'template_id', p_template_id, 'expected_version', p_expected_version,
    'command', p_command)::text, 'UTF8'), 'sha256');
  perform pg_advisory_xact_lock(hashtextextended(
    'activity-template-lifecycle:' || p_idempotency_key::text, 0));
  select lifecycle_receipt.* into receipt
  from app_private.superadmin_internal_activity_template_lifecycle_receipts lifecycle_receipt
  where lifecycle_receipt.request_id = p_idempotency_key;
  if receipt.request_id is not null then
    if receipt.internal_identity_id <> ctx.internal_identity_id then
      raise insufficient_privilege using message='template receipt actor mismatch';
    end if;
    if receipt.request_hash <> request_hash then
      raise invalid_parameter_value using message='idempotency key reused';
    end if;
    return receipt.result_json;
  end if;
  -- Escopo: modelo platform so por ator platform; modelo institucional so pela
  -- propria instituicao quando o ator e restrito. Fora disso nao enumera.
  select template_record.* into template
  from public.activity_templates template_record
  where template_record.id = p_template_id
    and (ctx.scope_kind <> 'institution'
      or (template_record.scope_kind <> 'platform'
        and template_record.institution_id = ctx.scope_institution_id))
  for update;
  if template.id is null then
    raise no_data_found using message='activity template not found';
  end if;
  if template.management_version <> p_expected_version then
    raise exception using errcode='PT409', message='stale activity template version',
      detail='ACTIVITY_TEMPLATE_STALE_VERSION';
  end if;
  if p_command = 'archive' then
    if template.status = 'archived' then
      raise object_not_in_prerequisite_state using message='activity template already archived',
        detail='ACTIVITY_TEMPLATE_STATE_INVALID';
    end if;
    update public.activity_templates set
      status = 'archived',
      template_payload = template_payload || jsonb_build_object('lifecycle', jsonb_build_object(
        'archived_from', template.status::text, 'archived_at', now())),
      management_version = management_version + 1,
      updated_at = now()
    where id = template.id
    returning * into template;
  else
    if template.status <> 'archived' then
      raise object_not_in_prerequisite_state using message='activity template is not archived',
        detail='ACTIVITY_TEMPLATE_STATE_INVALID';
    end if;
    restored_status := coalesce(
      nullif(template.template_payload #>> '{lifecycle,archived_from}', ''), 'active'
    )::public.record_status;
    if restored_status = 'archived' then restored_status := 'active'; end if;
    update public.activity_templates set
      status = restored_status,
      template_payload = template_payload - 'lifecycle',
      management_version = management_version + 1,
      updated_at = now()
    where id = template.id
    returning * into template;
  end if;
  result := jsonb_build_object(
    'id', template.id, 'status', template.status::text,
    'management_version', template.management_version,
    'archived_at', template.template_payload #>> '{lifecycle,archived_at}');
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id, ctx.internal_auth_link_id, ctx.internal_membership_id,
    ctx.session_id, 'activities.templates.manage', ctx.aal,
    'activity.template.' || p_command, 'success', null, correlation_id,
    template.institution_id, 'activity_template', template.id,
    jsonb_build_object('id', template.id, 'status', template.status::text,
      'scope_kind', template.scope_kind, 'institution_id', template.institution_id,
      'unit_id', template.unit_id, 'management_version', template.management_version));
  insert into app_private.superadmin_internal_activity_template_lifecycle_receipts(
    request_id, internal_identity_id, template_id, command, request_hash, result_json, correlation_id
  ) values (
    p_idempotency_key, ctx.internal_identity_id, template.id, p_command, request_hash, result, correlation_id
  );
  return result;
end $$;
alter function app_private.superadmin_activity_template_lifecycle_v1(text, uuid, bigint, uuid) owner to postgres;
revoke all on function app_private.superadmin_activity_template_lifecycle_v1(text, uuid, bigint, uuid) from public, anon;

create or replace function public.superadmin_activity_template_archive_v1(
  p_template_id uuid, p_expected_version bigint, p_idempotency_key uuid)
returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_activity_template_lifecycle_v1('archive', p_template_id, p_expected_version, p_idempotency_key)
$$;
create or replace function public.superadmin_activity_template_restore_v1(
  p_template_id uuid, p_expected_version bigint, p_idempotency_key uuid)
returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_activity_template_lifecycle_v1('restore', p_template_id, p_expected_version, p_idempotency_key)
$$;
alter function public.superadmin_activity_template_archive_v1(uuid, bigint, uuid) owner to postgres;
alter function public.superadmin_activity_template_restore_v1(uuid, bigint, uuid) owner to postgres;
revoke all on function public.superadmin_activity_template_archive_v1(uuid, bigint, uuid) from public, anon;
revoke all on function public.superadmin_activity_template_restore_v1(uuid, bigint, uuid) from public, anon;
grant execute on function public.superadmin_activity_template_archive_v1(uuid, bigint, uuid) to authenticated, service_role;
grant execute on function public.superadmin_activity_template_restore_v1(uuid, bigint, uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Rotina: status anterior + comandos archive/restore
-- ---------------------------------------------------------------------------
create table if not exists app_private.routine_model_lifecycle (
  model_id uuid primary key references public.routine_models(id) on delete cascade,
  archived_from text not null check (archived_from in ('draft', 'active', 'inactive')),
  archived_at timestamptz not null default now(),
  archived_by_person_id uuid not null
);
alter table app_private.routine_model_lifecycle owner to postgres;
alter table app_private.routine_model_lifecycle enable row level security;
alter table app_private.routine_model_lifecycle force row level security;
revoke all on table app_private.routine_model_lifecycle from public, anon, authenticated;

create or replace function app_private.superadmin_routine_model_lifecycle_v1(
  p_command text, p_request_id uuid, p_model_id uuid, p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid;
  model_row public.routine_models;
  lifecycle_row app_private.routine_model_lifecycle;
  before_json jsonb;
  response jsonb;
  command_name text := case p_command when 'archive' then 'archive_model' else 'restore_model' end;
begin
  if p_command not in ('archive', 'restore') or p_model_id is null or p_expected_version is null then
    raise invalid_parameter_value using message='invalid routine model lifecycle request';
  end if;
  actor := app_private.require_routine_actor('routine.manage_models', false);
  perform pg_advisory_xact_lock(hashtextextended(p_model_id::text, 0));
  response := app_private.routine_receipt(p_request_id, actor, command_name);
  if response is not null then return response; end if;

  select * into model_row
  from public.routine_models
  where id = p_model_id
    and app_private.routine_scope_allowed(
      'routine.manage_models', institution_id, origin_unit_id, null)
  for update;
  if model_row.id is null then
    raise no_data_found using message = 'routine model unavailable';
  end if;
  if model_row.management_version <> p_expected_version then
    raise exception using errcode='PT409', message='stale routine model version',
      detail='ROUTINE_MODEL_STALE_VERSION';
  end if;
  before_json := to_jsonb(model_row);

  if p_command = 'archive' then
    if model_row.status = 'archived' then
      raise object_not_in_prerequisite_state using message='routine model already archived',
        detail='ROUTINE_MODEL_STATE_INVALID';
    end if;
    insert into app_private.routine_model_lifecycle(model_id, archived_from, archived_by_person_id)
    values (model_row.id, model_row.status, actor)
    on conflict (model_id) do update
      set archived_from = excluded.archived_from, archived_at = now(),
          archived_by_person_id = excluded.archived_by_person_id;
    update public.routine_models set
      status = 'archived',
      management_version = management_version + 1,
      updated_at = now()
    where id = model_row.id returning * into model_row;
  else
    if model_row.status <> 'archived' then
      raise object_not_in_prerequisite_state using message='routine model is not archived',
        detail='ROUTINE_MODEL_STATE_INVALID';
    end if;
    delete from app_private.routine_model_lifecycle
    where model_id = model_row.id returning * into lifecycle_row;
    update public.routine_models set
      status = coalesce(lifecycle_row.archived_from, 'active'),
      management_version = management_version + 1,
      updated_at = now()
    where id = model_row.id returning * into model_row;
  end if;

  response := jsonb_build_object(
    'id', model_row.id,
    'status', model_row.status,
    'management_version', model_row.management_version
  );
  insert into app_private.routine_command_receipts
    values (p_request_id, actor, command_name, model_row.id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, before_json, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'routine.model.' || p_command, 'routine_model', model_row.id,
    model_row.institution_id, 'success', before_json, to_jsonb(model_row)
  );
  return response;
end $$;
alter function app_private.superadmin_routine_model_lifecycle_v1(text, uuid, uuid, bigint) owner to postgres;
revoke all on function app_private.superadmin_routine_model_lifecycle_v1(text, uuid, uuid, bigint) from public, anon;

create or replace function public.superadmin_routine_model_archive_v1(
  p_request_id uuid, p_model_id uuid, p_expected_version bigint)
returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_routine_model_lifecycle_v1('archive', p_request_id, p_model_id, p_expected_version)
$$;
create or replace function public.superadmin_routine_model_restore_v1(
  p_request_id uuid, p_model_id uuid, p_expected_version bigint)
returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_routine_model_lifecycle_v1('restore', p_request_id, p_model_id, p_expected_version)
$$;
alter function public.superadmin_routine_model_archive_v1(uuid, uuid, bigint) owner to postgres;
alter function public.superadmin_routine_model_restore_v1(uuid, uuid, bigint) owner to postgres;
revoke all on function public.superadmin_routine_model_archive_v1(uuid, uuid, bigint) from public, anon;
revoke all on function public.superadmin_routine_model_restore_v1(uuid, uuid, bigint) from public, anon;
grant execute on function public.superadmin_routine_model_archive_v1(uuid, uuid, bigint) to authenticated, service_role;
grant execute on function public.superadmin_routine_model_restore_v1(uuid, uuid, bigint) to authenticated, service_role;

-- Diretorio: sem filtro de status, modelos e rotinas arquivados saem da lista
-- padrao (B1). Corpo identico ao dump de 16/09 fora das duas linhas marcadas.
create or replace function app_private.superadmin_routine_directory(
  p_entry_kind text, p_search text, p_status text, p_institution_id uuid,
  p_unit_id uuid, p_group_id uuid, p_limit integer, p_offset integer)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
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
        -- B1: lista padrao exclui arquivados
        and (case when p_status is null then model_row.status <> 'archived'
                  else model_row.status = p_status end)
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
        -- B1: lista padrao exclui arquivados
        and (case when p_status is null then application_row.status <> 'archived'
                  else application_row.status = p_status end)
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
