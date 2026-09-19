-- spec 066 — sobras: atividades, pessoas/suspensão por período e instituições arquivadas. Lote 98.
--   * lifecycle_can_hard_delete_v1 e superadmin_structure_lifecycle_v1 ganham a entidade
--     'activity' (activity_definitions; activities.manage; exclusão lógica = archived + archived_at);
--     fachadas superadmin_activity_change_status_v1 / superadmin_activity_delete_v1.
--   * Pessoas (spec 066 §3): people.suspended_from / suspended_until / suspension_reason;
--     superadmin_person_suspend_v1(p_request_id, p_person_id, p_from, p_until, p_reason) e
--     superadmin_person_reactivate_v1(p_request_id, p_person_id, p_reason) (people.update, motivo
--     obrigatório, recibo idempotente, auditoria). Bloqueio de login no período: o resolvedor
--     app_private.current_person_id ignora o vínculo de conta (person_auth_links) enquanto a
--     pessoa está suspensa, então todo leitor/comando do Principal/Admin nega como sem pessoa;
--     identidades internas (Superadmin) não passam por esse ramo.
--   * Instituições arquivadas ficam no histórico: institution_directory passa a incluí-las e o
--     diretório só as mostra quando o filtro de status pede 'archived' (spec 066: "Arquivados").
begin;

alter table public.activity_definitions
  add column if not exists lifecycle_reason text,
  add column if not exists lifecycle_changed_at timestamptz;
alter table public.people
  add column if not exists suspended_from timestamptz,
  add column if not exists suspended_until timestamptz,
  add column if not exists suspension_reason text;
alter table public.people drop constraint if exists people_suspension_ck;
alter table public.people
  add constraint people_suspension_ck check (
    (suspended_from is null and suspended_until is null)
    or (suspended_from is not null and (suspended_until is null or suspended_until > suspended_from)));

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
      satellites := array['public.unit_care_policies', 'public.unit_addresses'];
    when 'group' then
      target := 'public.groups'::regclass;
      satellites := array[]::text[];
    when 'activity' then
      target := 'public.activity_definitions'::regclass;
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
      execute format('select count(*) from %s where %I = $1 and action_code not like %L',
        fk.tbl, fk.col, '%create%') into dependents using p_id;
    elsif fk.tbl = 'public.institution_memberships'::regclass then
      select count(*) into dependents from public.institution_memberships m
        join public.people p on p.id = m.person_id
        where m.institution_id = p_id and p.person_type <> 'service';
    else
      execute format('select count(*) from %s where %I = $1', fk.tbl, fk.col)
        into dependents using p_id;
    end if;
    if dependents > 0 then return false; end if;
  end loop;
  if exists (select 1 from audit.audit_logs l where l.object_id = p_id
      and l.action_code not like '%create%') then
    return false;
  end if;
  if to_regclass('public.entity_image_assets') is not null then
    execute 'select count(*) from public.entity_image_assets a where a.entity_id = $1'
      into dependents using p_id;
    if dependents > 0 then return false; end if;
  end if;
  return true;
end
$$;

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
    if p_entity not in ('unit', 'group', 'activity') then
      raise invalid_parameter_value using message = 'unsupported entity', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    permission := case p_entity when 'unit' then 'units.update' when 'group' then 'groups.manage'
      else 'activities.manage' end;
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
    elsif p_entity = 'group' then
      select g.institution_id, g.status::text, g.management_version into institution_id, current_status, current_version
        from public.groups g where g.id = p_id for update;
    else
      select a.institution_id, a.status::text, a.management_version into institution_id, current_status, current_version
        from public.activity_definitions a where a.id = p_id for update;
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
    -- Atividades: as triggers de proveniência exigem o marcador interno da família v2.
    if p_entity = 'activity' then
      perform app_private.activity_v2_set_marker(ctx, 'activities.manage', 'manage', correlation);
    end if;
    if hard then
      if p_entity = 'unit' then
        delete from public.unit_care_policies where unit_id = p_id;
        delete from public.unit_addresses where unit_id = p_id;
        delete from public.units where id = p_id;
      elsif p_entity = 'group' then
        delete from public.groups where id = p_id;
      else
        delete from public.activity_definitions where id = p_id;
      end if;
      after_json := null;
      result := jsonb_build_object('id', p_id, 'entity', p_entity, 'status', 'deleted', 'hard_deleted', true, 'management_version', null);
    else
      if p_entity = 'unit' then
        update public.units set status = new_status::public.record_status, lifecycle_reason = reason,
          lifecycle_changed_at = now(), management_version = management_version + 1, updated_at = now()
          where id = p_id returning management_version into current_version;
      elsif p_entity = 'group' then
        update public.groups set status = new_status::public.record_status, lifecycle_reason = reason,
          lifecycle_changed_at = now(), management_version = management_version + 1, updated_at = now()
          where id = p_id returning management_version into current_version;
      else
        update public.activity_definitions set status = new_status::public.record_status, lifecycle_reason = reason,
          lifecycle_changed_at = now(), archived_at = case when p_action = 'delete' then now() else archived_at end,
          management_version = management_version + 1, updated_at = now()
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

create or replace function public.superadmin_activity_change_status_v1(
  p_request_id uuid, p_activity_id uuid, p_expected_version bigint, p_status text, p_reason text default null
) returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_structure_lifecycle_v1('activity', p_request_id, p_activity_id, p_expected_version,
    case p_status when 'active' then 'activate' when 'inactive' then 'inactivate' else coalesce(p_status, 'invalid') end, p_reason)
$$;
create or replace function public.superadmin_activity_delete_v1(
  p_request_id uuid, p_activity_id uuid, p_expected_version bigint, p_reason text
) returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_structure_lifecycle_v1('activity', p_request_id, p_activity_id, p_expected_version, 'delete', p_reason)
$$;

-- Pessoas: suspensão por período -----------------------------------------------------------------
create or replace function app_private.superadmin_person_suspension_v1(
  p_request_id uuid, p_person_id uuid, p_action text, p_from timestamptz, p_until timestamptz, p_reason text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid();
  error_code text; error_detail text; reason text := nullif(btrim(coalesce(p_reason, '')), '');
  receipt app_private.superadmin_internal_lifecycle_receipts%rowtype; request_hash bytea;
  person public.people%rowtype; result jsonb; after_json jsonb;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('people.update');
    if ctx.platform_role_code not in ('owner', 'operations') then
      raise insufficient_privilege using message = 'person access denied', detail = 'SAI_PERMISSION_DENIED';
    end if;
    if p_request_id is null or p_person_id is null or p_action not in ('suspend', 'reactivate')
      or reason is null or char_length(reason) > 500
      or (p_action = 'suspend' and (p_from is null or (p_until is not null and p_until <= p_from))) then
      raise invalid_parameter_value using message = 'invalid suspension request', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    request_hash := extensions.digest(p_person_id::text || '|' || p_action || '|' || coalesce(p_from::text, '') || '|'
      || coalesce(p_until::text, '') || '|' || reason, 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
    select * into receipt from app_private.superadmin_internal_lifecycle_receipts where request_id = p_request_id;
    if receipt.request_id is not null then
      if receipt.actor_internal_identity_id is distinct from ctx.internal_identity_id
        or receipt.entity_id is distinct from p_person_id or receipt.request_hash is distinct from request_hash then
        raise invalid_parameter_value using message = 'request id already used', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      return jsonb_build_object('ok', true, 'data', receipt.result_json || jsonb_build_object('replayed', true), 'error', null);
    end if;
    select * into person from public.people where id = p_person_id and deleted_at is null for update;
    if person.id is null then
      raise insufficient_privilege using message = 'person access denied', detail = 'SAI_PERMISSION_DENIED';
    end if;
    -- Pessoa técnica de operador interno nunca é suspensa por aqui.
    if person.person_type = 'service' then
      raise invalid_parameter_value using message = 'service person', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    if ctx.scope_kind = 'institution' and not exists (select 1 from public.institution_memberships m
        where m.person_id = p_person_id and m.institution_id = ctx.scope_institution_id) then
      raise insufficient_privilege using message = 'person access denied', detail = 'SAI_PERMISSION_DENIED';
    end if;
    if p_action = 'suspend' then
      update public.people set suspended_from = p_from, suspended_until = p_until, suspension_reason = reason,
        updated_at = now() where id = p_person_id returning * into person;
    else
      update public.people set suspended_from = null, suspended_until = null, suspension_reason = null,
        updated_at = now() where id = p_person_id returning * into person;
    end if;
    after_json := jsonb_build_object('id', person.id, 'status', person.status::text);
    result := jsonb_build_object('person_id', person.id, 'suspended_from', person.suspended_from,
      'suspended_until', person.suspended_until, 'suspended_now', app_private.person_suspended_now(person.id));
    insert into app_private.superadmin_internal_lifecycle_receipts(request_id, actor_internal_identity_id, entity, entity_id,
      action_code, expected_version, request_hash, result_json)
    values (p_request_id, ctx.internal_identity_id, 'person', p_person_id, 'person.' || p_action, 0, request_hash, result);
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id, ctx.internal_auth_link_id,
      ctx.internal_membership_id, ctx.session_id, 'people.update', ctx.aal, 'person.' || p_action,
      'success'::public.audit_outcome, 'LIFECYCLE_OPERATOR_REASON', correlation,
      case when ctx.scope_kind = 'institution' then ctx.scope_institution_id end, 'person', p_person_id, after_json);
    return jsonb_build_object('ok', true, 'data', result || jsonb_build_object('replayed', false), 'error', null);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail like 'SAI_%' then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation then error_code := 'SAI_INVALID_ARGUMENT';
    when others then error_code := 'SAI_INTERNAL_ERROR';
  end;
  return app_private.superadmin_internal_error_envelope(error_code, correlation);
end
$$;
revoke all on function app_private.superadmin_person_suspension_v1(uuid, uuid, text, timestamptz, timestamptz, text)
  from public, anon, authenticated, service_role;

create or replace function app_private.person_suspended_now(p_person_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.people p where p.id = p_person_id
    and p.suspended_from is not null and p.suspended_from <= now()
    and (p.suspended_until is null or p.suspended_until > now()))
$$;
revoke all on function app_private.person_suspended_now(uuid) from public, anon, authenticated, service_role;

create or replace function public.superadmin_person_suspend_v1(
  p_request_id uuid, p_person_id uuid, p_from timestamptz, p_until timestamptz, p_reason text
) returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_person_suspension_v1(p_request_id, p_person_id, 'suspend', p_from, p_until, p_reason)
$$;
create or replace function public.superadmin_person_reactivate_v1(
  p_request_id uuid, p_person_id uuid, p_reason text
) returns jsonb language sql security definer set search_path = '' as $$
  select app_private.superadmin_person_suspension_v1(p_request_id, p_person_id, 'reactivate', null, null, p_reason)
$$;

-- Bloqueio no período: a conta de pessoa suspensa não resolve para ela.
create or replace function app_private.current_person_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select coalesce(
    (
      select auth_link.person_id
      from public.person_auth_links auth_link
      join public.people person on person.id = auth_link.person_id
      where auth_link.auth_user_id = (select auth.uid())
        and auth_link.status = 'active'
        and auth_link.revoked_at is null
        and not (person.suspended_from is not null and person.suspended_from <= now()
          and (person.suspended_until is null or person.suspended_until > now()))
      order by auth_link.linked_at desc, auth_link.id
      limit 1
    ),
    (
      select actor.person_id
      from app_private.superadmin_internal_auth_links internal_link
      join app_private.superadmin_internal_actor_people actor
        on actor.internal_identity_id = internal_link.internal_identity_id
      where internal_link.auth_user_id = (select auth.uid())
        and internal_link.status = 'active'
      order by internal_link.created_at desc
      limit 1
    )
  )
$$;

do $acl$
declare f regprocedure;
begin
  for f in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('superadmin_activity_change_status_v1', 'superadmin_activity_delete_v1',
      'superadmin_person_suspend_v1', 'superadmin_person_reactivate_v1') loop
    execute format('alter function %s owner to postgres', f);
    execute format('revoke all on function %s from public, anon, service_role', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end
$acl$;

-- Instituições arquivadas no histórico ------------------------------------------------------------
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
  where i.deleted_at is null or i.status = 'archived';

create or replace function app_private.superadmin_institution_directory_payload_v2(
  p_filters jsonb, p_limit integer, p_offset integer, p_sort text, p_sort_ascending boolean,
  p_scope_kind text, p_scope_institution_id uuid
) returns jsonb language plpgsql security definer set search_path = '' as $body$
declare
  result jsonb; filters jsonb := coalesce(p_filters, '{}'::jsonb);
begin
  -- Sem filtro de status, o arquivado fica fora (só aparece na aba "Arquivadas").
  if not (filters ? 'statuses') or jsonb_array_length(coalesce(filters -> 'statuses', '[]'::jsonb)) = 0 then
    filters := filters || jsonb_build_object('statuses',
      jsonb_build_array('draft', 'onboarding', 'active', 'inactive', 'suspended'));
  end if;
  result := app_private.superadmin_institution_directory_payload_v2_base(
    filters, p_limit, p_offset, p_sort, p_sort_ascending, p_scope_kind, p_scope_institution_id);
  return jsonb_set(result, '{items}', coalesce((
    select jsonb_agg(item || jsonb_build_object('management_version',
      (select d.management_version from public.institution_directory d where d.id = (item->>'id')::uuid)))
    from jsonb_array_elements(result->'items') item), '[]'::jsonb));
end
$body$;

commit;
