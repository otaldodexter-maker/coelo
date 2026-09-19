-- Instituições — spec 066 (ciclo de vida, opção B da OQ-033). Lote 94.
--   * app_private.lifecycle_can_hard_delete_v1(p_entity, p_id): verdadeiro só quando nenhuma
--     tabela de negócio (schema public, fora das satélites da própria criação) referencia o
--     registro e não há trilha de auditoria além do próprio create. Instituição sempre tem
--     trilha (audit_logs.institution_id), logo a exclusão é sempre lógica.
--   * app_private.superadmin_internal_lifecycle_receipts: recibo idempotente por request.
--   * superadmin_institution_change_status_v1(p_request_id, p_institution_id, p_expected_version,
--     p_status in ('active','inactive'), p_reason): institution.status.change; motivo obrigatório
--     ao inativar; PT409 (SAI_CONCURRENT_CHANGE) em versão defasada; auditoria before/after mínima.
--   * superadmin_institution_delete_v1(p_request_id, p_institution_id, p_expected_version,
--     p_reason): institution.status.change; exclusão real só se lifecycle_can_hard_delete_v1,
--     senão lógica (status='archived', deleted_at=now()) — filhos e mídia ficam (ADR 0032).
--   * institutions.lifecycle_reason / lifecycle_changed_at guardam o motivo da última transição
--     (audit_logs.reason_code só aceita código: a auditoria leva LIFECYCLE_OPERATOR_REASON).
--   * institution_directory expõe management_version (o cliente precisa da versão para agir).
begin;

alter table public.institutions
  add column if not exists lifecycle_reason text,
  add column if not exists lifecycle_changed_at timestamptz;

create table if not exists app_private.superadmin_internal_lifecycle_receipts (
  request_id uuid primary key,
  actor_internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id),
  entity text not null,
  entity_id uuid not null,
  action_code text not null,
  expected_version bigint not null,
  request_hash bytea not null,
  result_json jsonb not null,
  created_at timestamptz not null default now()
);
alter table app_private.superadmin_internal_lifecycle_receipts enable row level security;
alter table app_private.superadmin_internal_lifecycle_receipts force row level security;
revoke all on app_private.superadmin_internal_lifecycle_receipts from public, anon, authenticated;

-- Predicado único de "pode excluir de verdade" (spec 066).
create or replace function app_private.lifecycle_can_hard_delete_v1(p_entity text, p_id uuid)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  target regclass;
  satellites text[];
  fk record;
  dependents bigint;
begin
  case p_entity
    when 'institution' then
      target := 'public.institutions'::regclass;
      satellites := array['public.institution_addresses', 'public.institution_contacts',
        'public.institution_legal_representatives', 'public.institution_subscriptions'];
    when 'unit' then
      target := 'public.units'::regclass;
      satellites := array['public.unit_care_policies'];
    when 'group' then
      target := 'public.groups'::regclass;
      satellites := array[]::text[];
    else
      raise invalid_parameter_value using message = 'unsupported lifecycle entity',
        detail = 'SAI_INVALID_ARGUMENT';
  end case;
  if p_id is null then return false; end if;
  for fk in
    select c.conrelid::regclass as tbl, a.attname as col, n.nspname as schema_name
    from pg_catalog.pg_constraint c
    join pg_catalog.pg_class r on r.oid = c.conrelid
    join pg_catalog.pg_namespace n on n.oid = r.relnamespace
    join pg_catalog.pg_attribute a on a.attrelid = c.conrelid and a.attnum = any(c.conkey)
    where c.contype = 'f' and c.confrelid = target
      and n.nspname in ('public', 'audit')
      and not (c.conrelid::regclass::text = any(satellites))
  loop
    if fk.schema_name = 'audit' then
      -- Trilha própria de criação não conta; qualquer outra entrada conta.
      execute format('select count(*) from %s where %I = $1 and action_code not like %L',
        fk.tbl, fk.col, '%create%') into dependents using p_id;
    elsif fk.tbl = 'public.institution_memberships'::regclass then
      -- Vínculos de serviço dos operadores internos nascem com a instituição
      -- (trigger institutions_superadmin_internal_access): não são vínculo de negócio.
      select count(*) into dependents from public.institution_memberships m
        join public.people p on p.id = m.person_id
        where m.institution_id = p_id and p.person_type <> 'service';
    else
      execute format('select count(*) from %s where %I = $1', fk.tbl, fk.col)
        into dependents using p_id;
    end if;
    if dependents > 0 then return false; end if;
  end loop;
  -- Trilha por object_id (sem FK) além do create.
  if exists (select 1 from audit.audit_logs l where l.object_id = p_id
      and l.action_code not like '%create%') then
    return false;
  end if;
  -- Mídia catalogada (imagens de entidade) impede a exclusão real.
  if to_regclass('public.entity_image_assets') is not null then
    execute 'select count(*) from public.entity_image_assets a where a.entity_id = $1'
      into dependents using p_id;
    if dependents > 0 then return false; end if;
  end if;
  return true;
end
$$;
revoke all on function app_private.lifecycle_can_hard_delete_v1(text, uuid) from public, anon, authenticated;

create or replace function app_private.superadmin_institution_lifecycle_apply_v1(
  p_request_id uuid, p_institution_id uuid, p_expected_version bigint,
  p_action text, p_reason text, p_context app_private.superadmin_internal_context,
  p_correlation_id uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  receipt app_private.superadmin_internal_lifecycle_receipts%rowtype;
  institution_record public.institutions%rowtype;
  request_hash bytea := extensions.digest(
    p_institution_id::text || '|' || p_expected_version::text || '|' || p_action || '|' ||
    coalesce(p_reason, ''), 'sha256');
  before_json jsonb; after_json jsonb; result jsonb; hard boolean := false;
  new_status public.institution_status;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text, 0));
  select * into receipt from app_private.superadmin_internal_lifecycle_receipts
    where request_id = p_request_id;
  if receipt.request_id is not null then
    if receipt.actor_internal_identity_id is distinct from p_context.internal_identity_id
      or receipt.entity_id is distinct from p_institution_id
      or receipt.request_hash is distinct from request_hash then
      raise invalid_parameter_value using message = 'request id already used',
        detail = 'SAI_INVALID_ARGUMENT';
    end if;
    return receipt.result_json || jsonb_build_object('replayed', true);
  end if;

  select * into institution_record from public.institutions
    where id = p_institution_id and deleted_at is null for update;
  if institution_record.id is null then
    raise insufficient_privilege using message = 'internal institution access denied',
      detail = 'SAI_PERMISSION_DENIED';
  end if;
  if institution_record.management_version is distinct from p_expected_version then
    raise exception using errcode = 'PT409', message = 'stale institution version',
      detail = 'SAI_CONCURRENT_CHANGE';
  end if;
  before_json := jsonb_build_object('id', institution_record.id,
    'status', institution_record.status::text,
    'management_version', institution_record.management_version);

  case p_action
    when 'activate' then
      if institution_record.status = 'archived' then
        raise invalid_parameter_value using message = 'archived institution',
          detail = 'SAI_INVALID_ARGUMENT';
      end if;
      new_status := 'active';
    when 'inactivate' then
      if institution_record.status = 'archived' then
        raise invalid_parameter_value using message = 'archived institution',
          detail = 'SAI_INVALID_ARGUMENT';
      end if;
      new_status := 'inactive';
    when 'delete' then
      hard := app_private.lifecycle_can_hard_delete_v1('institution', p_institution_id);
      new_status := 'archived';
    else
      raise invalid_parameter_value using message = 'invalid lifecycle action',
        detail = 'SAI_INVALID_ARGUMENT';
  end case;

  if hard then
    delete from public.institution_role_assignments ra
      using public.institution_memberships m
      where ra.membership_id = m.id and m.institution_id = p_institution_id;
    delete from public.institution_memberships where institution_id = p_institution_id;
    delete from public.institution_addresses where institution_id = p_institution_id;
    delete from public.institution_contacts where institution_id = p_institution_id;
    delete from public.institution_legal_representatives where institution_id = p_institution_id;
    delete from public.institution_subscriptions where institution_id = p_institution_id;
    delete from public.institutions where id = p_institution_id;
    after_json := null;
    result := jsonb_build_object('institution_id', p_institution_id, 'status', 'deleted',
      'hard_deleted', true, 'management_version', null);
  else
    update public.institutions set
      status = new_status,
      deleted_at = case when p_action = 'delete' then now() else deleted_at end,
      lifecycle_reason = p_reason,
      lifecycle_changed_at = now(),
      management_version = management_version + 1,
      updated_at = now()
    where id = p_institution_id returning * into institution_record;
    after_json := jsonb_build_object('id', institution_record.id,
      'status', institution_record.status::text,
      'management_version', institution_record.management_version);
    result := jsonb_build_object('institution_id', p_institution_id,
      'status', institution_record.status::text, 'hard_deleted', false,
      'management_version', institution_record.management_version);
  end if;

  insert into app_private.superadmin_internal_lifecycle_receipts(
    request_id, actor_internal_identity_id, entity, entity_id, action_code,
    expected_version, request_hash, result_json
  ) values (p_request_id, p_context.internal_identity_id, 'institution', p_institution_id,
    'institution.' || p_action, p_expected_version, request_hash, result);

  perform app_private.audit_append_superadmin_internal(
    p_context.internal_identity_id, p_context.internal_auth_link_id,
    p_context.internal_membership_id, p_context.session_id,
    'institution.status.change', p_context.aal, 'institution.' || p_action,
    'success'::public.audit_outcome,
    case when p_reason is null then null else 'LIFECYCLE_OPERATOR_REASON' end, p_correlation_id,
    case when hard then null else p_institution_id end, 'institution', p_institution_id,
    after_json);
  return result || jsonb_build_object('replayed', false);
end
$$;
revoke all on function app_private.superadmin_institution_lifecycle_apply_v1(
  uuid, uuid, bigint, text, text, app_private.superadmin_internal_context, uuid)
  from public, anon, authenticated;

create or replace function app_private.superadmin_institution_lifecycle_v1(
  p_request_id uuid, p_institution_id uuid, p_expected_version bigint,
  p_action text, p_reason text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  context_record app_private.superadmin_internal_context;
  correlation_id uuid := gen_random_uuid();
  response_data jsonb; error_code text; error_detail text;
  reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  begin
    select * into strict context_record
    from app_private.require_superadmin_internal_context('institution.status.change');
    if context_record.platform_role_code not in ('owner', 'operations') then
      raise insufficient_privilege using message = 'internal institution access denied',
        detail = 'SAI_PERMISSION_DENIED';
    end if;
    if p_institution_id is null or (context_record.scope_kind = 'institution'
        and context_record.scope_institution_id is distinct from p_institution_id) then
      raise insufficient_privilege using message = 'internal institution access denied',
        detail = 'SAI_PERMISSION_DENIED';
    end if;
    if p_request_id is null or p_expected_version is null or p_expected_version <= 0
      or p_action not in ('activate', 'inactivate', 'delete')
      -- Transição restritiva exige motivo (spec 066 §4).
      or (p_action in ('inactivate', 'delete') and (reason is null or char_length(reason) > 500)) then
      raise invalid_parameter_value using message = 'invalid lifecycle request',
        detail = 'SAI_INVALID_ARGUMENT';
    end if;
    response_data := app_private.superadmin_institution_lifecycle_apply_v1(
      p_request_id, p_institution_id, p_expected_version, p_action, reason,
      context_record, correlation_id);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail in ('SAI_AUTH_REQUIRED', 'SAI_SESSION_INVALID',
        'SAI_INTERNAL_CONTEXT_DENIED', 'SAI_MEMBERSHIP_SUSPENDED', 'SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED', 'SAI_MFA_REQUIRED') then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation or unique_violation or foreign_key_violation then
      error_code := 'SAI_INVALID_ARGUMENT';
    when serialization_failure or sqlstate 'PT409' then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail = 'SAI_CONCURRENT_CHANGE'
        then error_detail else 'SAI_INTERNAL_ERROR' end;
    when others then
      error_code := 'SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'institution.status.change', 'institution.' || coalesce(p_action, 'lifecycle'),
      error_code, correlation_id,
      case when context_record.scope_kind = 'institution' then context_record.scope_institution_id end);
    return app_private.superadmin_internal_error_envelope(error_code, correlation_id);
  end if;
  return jsonb_build_object('ok', true, 'data', response_data, 'error', null);
end
$$;
revoke all on function app_private.superadmin_institution_lifecycle_v1(uuid, uuid, bigint, text, text)
  from public, anon, authenticated;

create or replace function public.superadmin_institution_change_status_v1(
  p_request_id uuid, p_institution_id uuid, p_expected_version bigint, p_status text, p_reason text default null
) returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_institution_lifecycle_v1(p_request_id, p_institution_id,
    p_expected_version, case p_status when 'active' then 'activate' when 'inactive' then 'inactivate'
      else coalesce(p_status, 'invalid') end, p_reason)
$$;
create or replace function public.superadmin_institution_delete_v1(
  p_request_id uuid, p_institution_id uuid, p_expected_version bigint, p_reason text
) returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_institution_lifecycle_v1(p_request_id, p_institution_id,
    p_expected_version, 'delete', p_reason)
$$;
alter function public.superadmin_institution_change_status_v1(uuid, uuid, bigint, text, text) owner to postgres;
alter function public.superadmin_institution_delete_v1(uuid, uuid, bigint, text) owner to postgres;
revoke all on function public.superadmin_institution_change_status_v1(uuid, uuid, bigint, text, text)
  from public, anon, service_role;
revoke all on function public.superadmin_institution_delete_v1(uuid, uuid, bigint, text)
  from public, anon, service_role;
grant execute on function public.superadmin_institution_change_status_v1(uuid, uuid, bigint, text, text) to authenticated;
grant execute on function public.superadmin_institution_delete_v1(uuid, uuid, bigint, text) to authenticated;

-- Diretório expõe a versão (coluna nova no fim da view).
create or replace view public.institution_directory as
 select i.id, i.public_name, i.trade_name, i.legal_name, i.primary_domain,
    (i.status)::text as status, i.institution_type_id, it.code as type_code, it.name as type_name,
    ia.country, ia.state, ia.city, ia.district, ia.street, ia.number, ia.complement, ia.postal_code,
    latest_subscription.plan_id, latest_subscription.plan_name, latest_subscription.subscription_status,
    (select count(*)::integer from public.units u
       where u.institution_id = i.id and u.status <> 'archived'::public.record_status) as units_count,
    (select count(*)::integer from public.groups g
       where g.institution_id = i.id and g.status <> 'archived'::public.record_status) as groups_count,
    lower(concat_ws(' '::text, i.public_name, i.trade_name, i.legal_name)) as search_name,
    ic.email as contact_email, ic.phone as contact_phone, ic.mobile_phone as contact_mobile_phone,
    i.management_version
   from public.institutions i
     left join public.institution_types it on it.id = i.institution_type_id
     left join public.institution_addresses ia on ia.institution_id = i.id
     left join public.institution_contacts ic on ic.institution_id = i.id
       and ic.status <> 'archived'::public.record_status
     left join lateral (
       select subscription.plan_id, plan.name as plan_name, (subscription.status)::text as subscription_status
       from public.institution_subscriptions subscription
         left join public.plans plan on plan.id = subscription.plan_id
       where subscription.institution_id = i.id
       order by subscription.created_at desc, subscription.id desc
       limit 1) latest_subscription on true
  where i.deleted_at is null;

do $rename$
begin
  if to_regprocedure('app_private.superadmin_institution_directory_payload_v2_base(jsonb,integer,integer,text,boolean,text,uuid)') is null then
    alter function app_private.superadmin_institution_directory_payload_v2(jsonb,integer,integer,text,boolean,text,uuid)
      rename to superadmin_institution_directory_payload_v2_base;
  end if;
end
$rename$;

create or replace function app_private.superadmin_institution_directory_payload_v2(
  p_filters jsonb, p_limit integer, p_offset integer, p_sort text, p_sort_ascending boolean,
  p_scope_kind text, p_scope_institution_id uuid
) returns jsonb language plpgsql security definer set search_path = '' as $body$
declare
  result jsonb;
begin
  -- Delegação: a versão anterior monta o payload; aqui só acrescentamos
  -- management_version por item, lendo a view atualizada.
  result := app_private.superadmin_institution_directory_payload_v2_base(
    p_filters, p_limit, p_offset, p_sort, p_sort_ascending, p_scope_kind, p_scope_institution_id);
  return jsonb_set(result, '{items}', coalesce((
    select jsonb_agg(item || jsonb_build_object('management_version',
      (select d.management_version from public.institution_directory d where d.id = (item->>'id')::uuid)))
    from jsonb_array_elements(result->'items') item), '[]'::jsonb));
end
$body$;

commit;
