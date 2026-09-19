-- Avisos — spec 069 (H08 duplicar, H13 destino do CTA por tipo). Lote 92.
--   * platform_notices.cta_target_kind / cta_target_id: destino interno do CTA
--     (none | circular | form | invite | notice); nunca URL livre. O servidor
--     valida que o alvo existe e, quando a audiência é por instituição, que o
--     alvo pertence a uma das instituições escolhidas.
--   * superadmin_notice_json expõe `cta_target` = {kind, id} (Superadmin e
--     leitor do Principal, que usa a mesma projeção).
--   * superadmin_notice_save_draft_v2 aceita `cta_target` no payload.
--   * superadmin_notice_duplicate_v2(p_request_id, p_notice_id): clona o aviso
--     como rascunho "Cópia de …" em qualquer status, sem datas nem recibos,
--     management_version = 1; auditoria notice.duplicate (object_id = cópia, after_json.id = origem);
--     recibo idempotente por request.
begin;

alter table public.platform_notices
  add column if not exists cta_target_kind text not null default 'none',
  add column if not exists cta_target_id uuid;

alter table public.platform_notices
  drop constraint if exists platform_notices_cta_target_ck,
  add constraint platform_notices_cta_target_ck check (
    cta_target_kind in ('none', 'circular', 'form', 'invite', 'notice')
    and ((cta_target_kind = 'none') = (cta_target_id is null))
  );

create or replace function app_private.superadmin_notice_json(
  p_notice public.platform_notices
) returns jsonb language sql stable security definer set search_path = '' as $$
  select pg_catalog.jsonb_build_object(
    'id', p_notice.id,
    'type', p_notice.notice_type::text,
    'title', p_notice.title,
    'body', p_notice.body_text,
    'priority', p_notice.priority_code,
    'status', case p_notice.status::text
      when 'published' then 'active' when 'archived' then 'inactive'
      else p_notice.status::text end,
    'starts_at', p_notice.starts_at,
    'ends_at', p_notice.ends_at,
    'audience', p_notice.audience_json,
    'audience_label', p_notice.audience_label,
    'behavior', p_notice.behavior,
    'target_device', p_notice.target_device,
    'content_format', p_notice.content_format,
    'background_color', p_notice.background_color,
    'text_color', p_notice.text_color,
    'button_color', p_notice.button_color,
    'popup_size', p_notice.popup_size,
    'has_outer_inset', p_notice.has_outer_inset,
    'button_label', p_notice.cta_label,
    'link_label', p_notice.silencing_policy ->> 'link_label',
    'cta_target', pg_catalog.jsonb_build_object(
      'kind', p_notice.cta_target_kind, 'id', p_notice.cta_target_id),
    'recurrence', p_notice.recurrence,
    'interval_days', p_notice.recurrence_config -> 'interval_days',
    'weekly_days', coalesce(p_notice.recurrence_config -> 'weekly_days', '[]'::jsonb),
    'day_of_month', p_notice.recurrence_config -> 'day_of_month',
    'recurrence_until', p_notice.recurrence_config ->> 'until',
    'image_orientation', p_notice.image_orientation,
    'management_version', p_notice.management_version,
    'updated_at', p_notice.updated_at,
    'reach', (select count(*) from public.notice_receipts receipt
      where receipt.notice_id = p_notice.id),
    'delivered_count', (select count(*) from public.notice_receipts receipt
      where receipt.notice_id = p_notice.id and receipt.delivered_at is not null),
    'viewed_count', (select count(*) from public.notice_receipts receipt
      where receipt.notice_id = p_notice.id and receipt.opened_at is not null),
    'accepted_count', (select count(*) from public.notice_receipts receipt
      where receipt.notice_id = p_notice.id and receipt.acted_at is not null))
$$;

-- Valida o destino do CTA contra o catálogo e a audiência por instituição.
-- Devolve (kind, id) normalizados; levanta NOTICE_INVALID_INPUT quando o alvo
-- não existe ou está fora do escopo da audiência.
create or replace function app_private.superadmin_notice_cta_target(
  p_payload jsonb, out kind text, out target_id uuid
) language plpgsql stable security definer set search_path = '' as $$
declare target jsonb := p_payload -> 'cta_target'; rule jsonb;
  target_institution_id uuid; institution_ids jsonb;
begin
  kind := coalesce(nullif(btrim(target ->> 'kind'), ''), 'none');
  if kind not in ('none', 'circular', 'form', 'invite', 'notice') then
    raise invalid_parameter_value using message = 'invalid cta target kind',
      detail = 'NOTICE_INVALID_INPUT';
  end if;
  if kind = 'none' then
    target_id := null;
    return;
  end if;
  if nullif(target ->> 'id', '') is null or not pg_input_is_valid(target ->> 'id', 'uuid') then
    raise invalid_parameter_value using message = 'invalid cta target id',
      detail = 'NOTICE_INVALID_INPUT';
  end if;
  target_id := (target ->> 'id')::uuid;
  case kind
    when 'circular' then
      select institution_id into target_institution_id from public.circulars
        where id = target_id and deleted_at is null;
    when 'form' then
      select institution_id into target_institution_id from public.forms
        where id = target_id and archived_at is null;
    when 'invite' then
      select institution_id into target_institution_id from public.invitations
        where id = target_id;
    when 'notice' then
      if not exists (select 1 from public.platform_notices where id = target_id) then
        raise invalid_parameter_value using message = 'cta target not found',
          detail = 'NOTICE_INVALID_INPUT';
      end if;
      return;
  end case;
  if not found then
    raise invalid_parameter_value using message = 'cta target not found',
      detail = 'NOTICE_INVALID_INPUT';
  end if;
  -- Audiência por instituição sem "todas": o alvo tem de pertencer a uma delas.
  rule := p_payload #> '{audience,rules,0}';
  if rule ->> 'dimension' = 'institution'
    and not coalesce((rule ->> 'select_all')::boolean, false) then
    institution_ids := coalesce(rule -> 'target_ids', '[]'::jsonb);
    if target_institution_id is null or not (institution_ids ? target_institution_id::text) then
      raise invalid_parameter_value using message = 'cta target outside audience',
        detail = 'NOTICE_INVALID_INPUT';
    end if;
  end if;
end
$$;

create or replace function public.superadmin_notice_save_draft_v2(
  p_request_id uuid, p_notice_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare context_record app_private.superadmin_internal_context;
  notice_record public.platform_notices%rowtype; cached_record record;
  correlation_id uuid := gen_random_uuid(); error_code text;
  request_hash bytea; result_json jsonb; canonical_type text;
  cta_kind text; cta_id uuid;
begin
  begin
    context_record := app_private.superadmin_notice_context('notices.manage');
    if p_request_id is null then
      raise invalid_parameter_value using message = 'request id required', detail = 'NOTICE_INVALID_INPUT';
    end if;
    request_hash := extensions.digest(coalesce(p_notice_id::text, '') || '|' ||
      coalesce(p_expected_version::text, '') || '|' || p_payload::text, 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(
      context_record.internal_identity_id::text || p_request_id::text || 'notice.save', 0));
    select * into cached_record from app_private.superadmin_notice_command_receipts
      where internal_identity_id = context_record.internal_identity_id
        and request_id = p_request_id and action_code = 'save';
    if cached_record.request_id is not null then
      if cached_record.request_hash <> request_hash then
        raise unique_violation using message = 'idempotency conflict', detail = 'NOTICE_CONFLICT';
      end if;
      return cached_record.result_json;
    end if;
    perform app_private.superadmin_notice_validate_payload(p_payload);
    select kind, target_id into cta_kind, cta_id
      from app_private.superadmin_notice_cta_target(p_payload);
    canonical_type := case p_payload ->> 'type'
      when 'notice' then 'popup' when 'critical_notice' then 'popup'
      else p_payload ->> 'type' end;
    if p_notice_id is null then
      if p_expected_version is not null then
        raise serialization_failure using message = 'version conflict', detail = 'NOTICE_CONFLICT';
      end if;
      insert into public.platform_notices(
        notice_type, status, title, body_text, cta_label, starts_at, ends_at,
        priority_code, audience_json, audience_label, behavior, target_device,
        content_format, background_color, text_color, button_color, popup_size,
        has_outer_inset, recurrence, recurrence_config, image_orientation,
        management_version, created_by_internal_identity_id,
        updated_by_internal_identity_id, created_at, updated_at, silencing_policy,
        cta_target_kind, cta_target_id
      ) values (
        canonical_type::public.notice_type, 'draft', btrim(p_payload ->> 'title'),
        btrim(p_payload ->> 'body'), nullif(btrim(p_payload ->> 'button_label'), ''),
        (p_payload ->> 'starts_at')::timestamptz,
        nullif(p_payload ->> 'ends_at', '')::timestamptz,
        p_payload ->> 'priority', p_payload -> 'audience',
        btrim(p_payload ->> 'audience_label'), p_payload ->> 'behavior',
        p_payload ->> 'target_device', 'text_background',
        p_payload ->> 'background_color', p_payload ->> 'text_color',
        p_payload ->> 'button_color', p_payload ->> 'popup_size',
        coalesce((p_payload ->> 'has_outer_inset')::boolean, true),
        p_payload ->> 'recurrence', jsonb_strip_nulls(jsonb_build_object(
          'interval_days', p_payload -> 'interval_days',
          'weekly_days', coalesce(p_payload -> 'weekly_days', '[]'::jsonb),
          'day_of_month', p_payload -> 'day_of_month',
          'until', p_payload ->> 'recurrence_until')),
        coalesce(p_payload ->> 'image_orientation', 'vertical'), 1,
        context_record.internal_identity_id, context_record.internal_identity_id,
        clock_timestamp(), clock_timestamp(),
        jsonb_build_object('link_label', nullif(btrim(p_payload ->> 'link_label'), '')),
        cta_kind, cta_id)
      returning * into notice_record;
    else
      select * into notice_record from public.platform_notices where id = p_notice_id for update;
      if notice_record.id is null then
        raise no_data_found using message = 'notice unavailable', detail = 'NOTICE_NOT_FOUND';
      end if;
      if p_expected_version is null or notice_record.management_version <> p_expected_version then
        raise serialization_failure using message = 'version conflict', detail = 'NOTICE_CONFLICT';
      end if;
      if notice_record.status::text not in ('draft', 'scheduled', 'paused') then
        raise object_not_in_prerequisite_state using message = 'notice cannot be edited',
          detail = case when notice_record.status::text in ('expired', 'inactive')
            then 'NOTICE_TERMINAL' else 'NOTICE_INVALID_TRANSITION' end;
      end if;
      update public.platform_notices set
        notice_type = canonical_type::public.notice_type,
        title = btrim(p_payload ->> 'title'), body_text = btrim(p_payload ->> 'body'),
        cta_label = nullif(btrim(p_payload ->> 'button_label'), ''),
        starts_at = (p_payload ->> 'starts_at')::timestamptz,
        ends_at = nullif(p_payload ->> 'ends_at', '')::timestamptz,
        priority_code = p_payload ->> 'priority', audience_json = p_payload -> 'audience',
        audience_label = btrim(p_payload ->> 'audience_label'),
        behavior = p_payload ->> 'behavior', target_device = p_payload ->> 'target_device',
        content_format = 'text_background', background_color = p_payload ->> 'background_color',
        text_color = p_payload ->> 'text_color', button_color = p_payload ->> 'button_color',
        popup_size = p_payload ->> 'popup_size',
        has_outer_inset = coalesce((p_payload ->> 'has_outer_inset')::boolean, true),
        recurrence = p_payload ->> 'recurrence',
        recurrence_config = jsonb_strip_nulls(jsonb_build_object(
          'interval_days', p_payload -> 'interval_days',
          'weekly_days', coalesce(p_payload -> 'weekly_days', '[]'::jsonb),
          'day_of_month', p_payload -> 'day_of_month',
          'until', p_payload ->> 'recurrence_until')),
        image_orientation = coalesce(p_payload ->> 'image_orientation', 'vertical'),
        silencing_policy = jsonb_build_object('link_label', nullif(btrim(p_payload ->> 'link_label'), '')),
        cta_target_kind = cta_kind, cta_target_id = cta_id,
        management_version = management_version + 1,
        updated_by_internal_identity_id = context_record.internal_identity_id,
        updated_at = clock_timestamp()
      where id = p_notice_id returning * into notice_record;
    end if;
    result_json := jsonb_build_object('ok', true,
      'data', app_private.superadmin_notice_json(notice_record), 'error', null);
    insert into app_private.superadmin_notice_command_receipts(
      internal_identity_id, request_id, action_code, request_hash, result_json
    ) values (context_record.internal_identity_id, p_request_id, 'save', request_hash, result_json);
    perform app_private.superadmin_notice_append_audit(context_record, 'notice.save',
      notice_record.id, 'success', null, correlation_id);
    return result_json;
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_notice_denied(
      'notices.manage', 'notice.save', error_code, correlation_id);
  end;
end
$$;

create or replace function public.superadmin_notice_duplicate_v2(
  p_request_id uuid, p_notice_id uuid
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare context_record app_private.superadmin_internal_context;
  source_record public.platform_notices%rowtype;
  notice_record public.platform_notices%rowtype; cached_record record;
  correlation_id uuid := gen_random_uuid(); error_code text;
  request_hash bytea; result_json jsonb;
begin
  begin
    context_record := app_private.superadmin_notice_context('notices.publish');
    if p_request_id is null or p_notice_id is null then
      raise invalid_parameter_value using message = 'request and notice id required',
        detail = 'NOTICE_INVALID_INPUT';
    end if;
    request_hash := extensions.digest(p_notice_id::text, 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(
      context_record.internal_identity_id::text || p_request_id::text || 'notice.duplicate', 0));
    select * into cached_record from app_private.superadmin_notice_command_receipts
      where internal_identity_id = context_record.internal_identity_id
        and request_id = p_request_id and action_code = 'duplicate';
    if cached_record.request_id is not null then
      if cached_record.request_hash <> request_hash then
        raise unique_violation using message = 'idempotency conflict', detail = 'NOTICE_CONFLICT';
      end if;
      return cached_record.result_json;
    end if;
    select * into source_record from public.platform_notices where id = p_notice_id;
    if source_record.id is null then
      raise no_data_found using message = 'notice unavailable', detail = 'NOTICE_NOT_FOUND';
    end if;
    insert into public.platform_notices(
      notice_type, status, title, body_text, cta_label, starts_at, ends_at,
      priority_code, audience_json, audience_label, behavior, target_device,
      content_format, background_color, text_color, button_color, popup_size,
      has_outer_inset, recurrence, recurrence_config, image_orientation,
      management_version, created_by_internal_identity_id,
      updated_by_internal_identity_id, created_at, updated_at, silencing_policy,
      cta_target_kind, cta_target_id
    ) values (
      source_record.notice_type, 'draft', left('Cópia de ' || source_record.title, 120),
      source_record.body_text, source_record.cta_label, null, null,
      source_record.priority_code, source_record.audience_json, source_record.audience_label,
      source_record.behavior, source_record.target_device, source_record.content_format,
      source_record.background_color, source_record.text_color, source_record.button_color,
      source_record.popup_size, source_record.has_outer_inset, source_record.recurrence,
      source_record.recurrence_config, source_record.image_orientation, 1,
      context_record.internal_identity_id, context_record.internal_identity_id,
      clock_timestamp(), clock_timestamp(),
      jsonb_build_object('link_label', source_record.silencing_policy ->> 'link_label'),
      source_record.cta_target_kind, source_record.cta_target_id)
    returning * into notice_record;
    result_json := jsonb_build_object('ok', true,
      'data', app_private.superadmin_notice_json(notice_record), 'error', null);
    insert into app_private.superadmin_notice_command_receipts(
      internal_identity_id, request_id, action_code, request_hash, result_json
    ) values (context_record.internal_identity_id, p_request_id, 'duplicate', request_hash, result_json);
    perform app_private.audit_append_superadmin_internal(
      context_record.internal_identity_id, context_record.internal_auth_link_id,
      context_record.internal_membership_id, context_record.session_id,
      context_record.permission_code, context_record.aal, 'notice.duplicate',
      'success'::public.audit_outcome, null, correlation_id,
      null, 'platform_notice', notice_record.id,
      -- audit_mask_payload só preserva chaves do allowlist: `id` aqui é a origem
      -- (object_id é a cópia).
      jsonb_build_object('id', source_record.id));
    return result_json;
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_notice_denied(
      'notices.publish', 'notice.duplicate', error_code, correlation_id);
  end;
end
$$;

alter function app_private.superadmin_notice_cta_target(jsonb) owner to postgres;
revoke all on function app_private.superadmin_notice_cta_target(jsonb)
  from public, anon, authenticated, service_role;
alter function public.superadmin_notice_duplicate_v2(uuid, uuid) owner to postgres;
revoke all on function public.superadmin_notice_duplicate_v2(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_notice_duplicate_v2(uuid, uuid) to authenticated;

commit;
