-- Unidades e turmas — spec 066 (ciclo de vida, mesma regra das instituições). Lote 97.
--   * app_private.superadmin_structure_lifecycle_v1(p_entity unit|group, p_request_id, p_id,
--     p_expected_version, p_action activate|inactivate|delete, p_reason): units.update / groups.manage;
--     motivo obrigatório em inativar/excluir; PT409 → SAI_CONCURRENT_CHANGE; exclusão real só quando
--     app_private.lifecycle_can_hard_delete_v1 permite (turma vazia criada por engano), senão
--     status='archived' (lógica; filhos e mídia ficam). Recibo idempotente e auditoria.
--   * public.superadmin_unit_change_status_v1 / superadmin_unit_delete_v1 /
--     superadmin_group_change_status_v1 / superadmin_group_delete_v1: fachadas.
--   * units.lifecycle_reason / groups.lifecycle_reason guardam o motivo (audit reason_code é código).
begin;

alter table public.units add column if not exists lifecycle_reason text,
  add column if not exists lifecycle_changed_at timestamptz;
alter table public.groups add column if not exists lifecycle_reason text,
  add column if not exists lifecycle_changed_at timestamptz;

create or replace function app_private.superadmin_structure_lifecycle_v1(
  p_entity text, p_request_id uuid, p_id uuid, p_expected_version bigint, p_action text, p_reason text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid();
  error_code text; error_detail text; reason text := nullif(btrim(coalesce(p_reason, '')), '');
  permission text; receipt app_private.superadmin_internal_lifecycle_receipts%rowtype;
  request_hash bytea; institution_id uuid; current_status text; current_version bigint;
  hard boolean := false; new_status text; after_json jsonb; result jsonb;
begin
  begin
    if p_entity not in ('unit', 'group') then
      raise invalid_parameter_value using message = 'unsupported entity', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    permission := case p_entity when 'unit' then 'units.update' else 'groups.manage' end;
    select * into strict ctx from app_private.require_superadmin_internal_context(permission);
    if ctx.platform_role_code not in ('owner', 'operations') then
      raise insufficient_privilege using message = 'structure access denied', detail = 'SAI_PERMISSION_DENIED';
    end if;
    if p_request_id is null or p_id is null or p_expected_version is null or p_expected_version <= 0
      or p_action not in ('activate', 'inactivate', 'delete')
      or (p_action in ('inactivate', 'delete') and (reason is null or char_length(reason) > 500)) then
      raise invalid_parameter_value using message = 'invalid lifecycle request', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    request_hash := extensions.digest(p_entity || '|' || p_id::text || '|' || p_expected_version::text || '|'
      || p_action || '|' || coalesce(reason, ''), 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
    select * into receipt from app_private.superadmin_internal_lifecycle_receipts where request_id = p_request_id;
    if receipt.request_id is not null then
      if receipt.actor_internal_identity_id is distinct from ctx.internal_identity_id
        or receipt.entity_id is distinct from p_id or receipt.request_hash is distinct from request_hash then
        raise invalid_parameter_value using message = 'request id already used', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      return jsonb_build_object('ok', true, 'data', receipt.result_json || jsonb_build_object('replayed', true), 'error', null);
    end if;
    if p_entity = 'unit' then
      select u.institution_id, u.status::text, u.management_version into institution_id, current_status, current_version
        from public.units u where u.id = p_id for update;
    else
      select g.institution_id, g.status::text, g.management_version into institution_id, current_status, current_version
        from public.groups g where g.id = p_id for update;
    end if;
    if institution_id is null or (ctx.scope_kind = 'institution' and ctx.scope_institution_id is distinct from institution_id) then
      raise insufficient_privilege using message = 'structure access denied', detail = 'SAI_PERMISSION_DENIED';
    end if;
    if current_version is distinct from p_expected_version then
      raise exception using errcode = 'PT409', message = 'stale version', detail = 'SAI_CONCURRENT_CHANGE';
    end if;
    if current_status = 'archived' then
      raise invalid_parameter_value using message = 'archived record', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    new_status := case p_action when 'activate' then 'active' when 'inactivate' then 'inactive' else 'archived' end;
    if p_action = 'delete' then
      hard := app_private.lifecycle_can_hard_delete_v1(p_entity, p_id);
    end if;
    if hard then
      if p_entity = 'unit' then
        delete from public.unit_care_policies where unit_id = p_id;
        delete from public.unit_addresses where unit_id = p_id;
        delete from public.units where id = p_id;
      else
        delete from public.groups where id = p_id;
      end if;
      after_json := null;
      result := jsonb_build_object('id', p_id, 'entity', p_entity, 'status', 'deleted', 'hard_deleted', true, 'management_version', null);
    else
      if p_entity = 'unit' then
        update public.units set status = new_status::public.record_status, lifecycle_reason = reason,
          lifecycle_changed_at = now(), management_version = management_version + 1, updated_at = now()
          where id = p_id returning management_version into current_version;
      else
        update public.groups set status = new_status::public.record_status, lifecycle_reason = reason,
          lifecycle_changed_at = now(), management_version = management_version + 1, updated_at = now()
          where id = p_id returning management_version into current_version;
      end if;
      after_json := jsonb_build_object('id', p_id, 'status', new_status, 'management_version', current_version);
      result := jsonb_build_object('id', p_id, 'entity', p_entity, 'status', new_status, 'hard_deleted', false,
        'management_version', current_version);
    end if;
    insert into app_private.superadmin_internal_lifecycle_receipts(request_id, actor_internal_identity_id, entity, entity_id,
      action_code, expected_version, request_hash, result_json)
    values (p_request_id, ctx.internal_identity_id, p_entity, p_id, p_entity || '.' || p_action, p_expected_version, request_hash, result);
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id, ctx.internal_auth_link_id,
      ctx.internal_membership_id, ctx.session_id, permission, ctx.aal, p_entity || '.' || p_action,
      'success'::public.audit_outcome, case when reason is null then null else 'LIFECYCLE_OPERATOR_REASON' end,
      correlation, institution_id, p_entity, p_id, after_json);
    return jsonb_build_object('ok', true, 'data', result || jsonb_build_object('replayed', false), 'error', null);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail like 'SAI_%' then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation or foreign_key_violation then error_code := 'SAI_INVALID_ARGUMENT';
    when sqlstate 'PT409' then error_code := 'SAI_CONCURRENT_CHANGE';
    when others then error_code := 'SAI_INTERNAL_ERROR';
  end;
  return app_private.superadmin_internal_error_envelope(error_code, correlation);
end
$$;
revoke all on function app_private.superadmin_structure_lifecycle_v1(text, uuid, uuid, bigint, text, text)
  from public, anon, authenticated, service_role;

create or replace function public.superadmin_unit_change_status_v1(
  p_request_id uuid, p_unit_id uuid, p_expected_version bigint, p_status text, p_reason text default null
) returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_structure_lifecycle_v1('unit', p_request_id, p_unit_id, p_expected_version,
    case p_status when 'active' then 'activate' when 'inactive' then 'inactivate' else coalesce(p_status, 'invalid') end, p_reason)
$$;
create or replace function public.superadmin_unit_delete_v1(
  p_request_id uuid, p_unit_id uuid, p_expected_version bigint, p_reason text
) returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_structure_lifecycle_v1('unit', p_request_id, p_unit_id, p_expected_version, 'delete', p_reason)
$$;
create or replace function public.superadmin_group_change_status_v1(
  p_request_id uuid, p_group_id uuid, p_expected_version bigint, p_status text, p_reason text default null
) returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_structure_lifecycle_v1('group', p_request_id, p_group_id, p_expected_version,
    case p_status when 'active' then 'activate' when 'inactive' then 'inactivate' else coalesce(p_status, 'invalid') end, p_reason)
$$;
create or replace function public.superadmin_group_delete_v1(
  p_request_id uuid, p_group_id uuid, p_expected_version bigint, p_reason text
) returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_structure_lifecycle_v1('group', p_request_id, p_group_id, p_expected_version, 'delete', p_reason)
$$;

do $acl$
declare f regprocedure;
begin
  for f in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('superadmin_unit_change_status_v1', 'superadmin_unit_delete_v1',
      'superadmin_group_change_status_v1', 'superadmin_group_delete_v1') loop
    execute format('alter function %s owner to postgres', f);
    execute format('revoke all on function %s from public, anon, service_role', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end
$acl$;

commit;
