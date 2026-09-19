-- Perfis oficiais do Coelo seguidos automaticamente — spec 068 (parte 2/2). Lote 95.
--   * public.official_profiles: catálogo (pessoa técnica, handle reservado, obrigatório só
--     `coelo`, ordem, meta de posts/dia). Carga inicial: `coelo` → pessoa técnica Coelo
--     (c0e10000-…0001, ADR 0034 P35). Os demais (3–7) entram por carga quando o Owner decidir.
--   * follow_links aceita origin 'official_auto' (sem contexto infantil).
--   * app_private.official_profiles_backfill_follows_v1(): idempotente; cria o follow de cada
--     pessoa com login ativo para cada oficial ativo, sem recriar follow que a pessoa revogou
--     (só oficial não obrigatório). pg_cron a cada 15 min + execução imediata.
--   * follow_set: não deixa de seguir oficial obrigatório; deixar de seguir oficial não
--     obrigatório revoga também o follow automático.
--   * platform_notices.official_profile_id: publicação do Superadmin atribuída a um perfil
--     oficial (entra no "Para você" pelo leitor existente); superadmin_notice_json expõe
--     `author`; save_draft_v2 aceita `official_profile_id`; superadmin_official_profiles_list_v1
--     lista os perfis para o formulário.
--   Decisão registrada: sem permissão nova (`platform.content.publish`); a publicação segue
--   por notices.manage/publish, que já exigem contexto interno e AAL2.
begin;

create table if not exists public.official_profiles (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null unique references public.people(id),
  handle text not null unique check (handle ~ '^[a-z][a-z0-9._]{1,39}$'),
  display_name text not null check (btrim(display_name) <> ''),
  description text not null default '',
  mandatory boolean not null default false,
  status text not null default 'active' check (status in ('active', 'inactive')),
  sort_order integer not null default 0,
  posts_per_day_target numeric(4,2) not null default 0.5,
  management_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.official_profiles enable row level security;
alter table public.official_profiles force row level security;
revoke all on public.official_profiles from public, anon, authenticated;

insert into public.official_profiles(person_id, handle, display_name, description, mandatory, sort_order, posts_per_day_target)
values ('c0e10000-0000-4000-8000-000000000001', 'coelo', 'Coelo',
  'Novidades, dicas e versões do app.', true, 0, 0.5)
on conflict (handle) do update set person_id = excluded.person_id, mandatory = true;

-- follow_links: origin official_auto sem contexto infantil.
alter table public.follow_links drop constraint if exists follow_links_check1;
alter table public.follow_links drop constraint if exists follow_links_origin_source_check;
do $c$
declare cname text;
begin
  for cname in select conname from pg_constraint where conrelid = 'public.follow_links'::regclass
    and contype = 'c' and pg_get_constraintdef(oid) like '%origin = ''automatic''%' loop
    execute format('alter table public.follow_links drop constraint %I', cname);
  end loop;
end
$c$;
alter table public.follow_links add constraint follow_links_origin_source_check check (
  (origin = 'automatic' and source_child_context_id is not null and source_relationship is not null)
  or (origin = 'manual' and source_child_context_id is null and source_relationship is null)
  or (origin = 'official_auto' and source_child_context_id is null and source_relationship is null));
create index if not exists follow_links_official_auto_idx
  on public.follow_links(target_id, follower_person_id) where origin = 'official_auto';

create or replace function app_private.official_profiles_backfill_follows_v1()
returns integer language plpgsql security definer set search_path = '' as $$
declare inserted integer;
begin
  insert into public.follow_links(follower_person_id, target_kind, target_id, origin)
  select distinct l.person_id, 'person'::public.follow_target_kind, o.person_id, 'official_auto'::public.follow_origin
  from public.official_profiles o
  cross join public.person_auth_links l
  join public.people p on p.id = l.person_id
  where o.status = 'active' and l.status = 'active' and p.status = 'active'
    and p.person_type <> 'service' and l.person_id <> o.person_id
    -- já segue por qualquer origem
    and not exists (select 1 from public.follow_links f where f.follower_person_id = l.person_id
      and f.target_kind = 'person' and f.target_id = o.person_id and f.status = 'active')
    -- revogou um follow automático de oficial não obrigatório: respeita
    and not (not o.mandatory and exists (select 1 from public.follow_links f
      where f.follower_person_id = l.person_id and f.target_kind = 'person'
        and f.target_id = o.person_id and f.origin = 'official_auto' and f.status <> 'active'));
  get diagnostics inserted = row_count;
  return inserted;
end
$$;
alter function app_private.official_profiles_backfill_follows_v1() owner to postgres;
revoke all on function app_private.official_profiles_backfill_follows_v1() from public, anon, authenticated, service_role;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'coelo-official-profiles-follow') then
    perform cron.unschedule('coelo-official-profiles-follow');
  end if;
  perform cron.schedule('coelo-official-profiles-follow', '*/15 * * * *',
    'select app_private.official_profiles_backfill_follows_v1();');
exception when others then
  raise notice 'pg_cron indisponível neste ambiente: %', sqlerrm;
end
$$;
select app_private.official_profiles_backfill_follows_v1();

create or replace function public.follow_set(p_target_kind text, p_target_id uuid, p_follow boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  kind public.follow_target_kind := app_private.follow_target_kind_of(p_target_kind);
  actor uuid := app_private.current_person_id();
  target_exists boolean;
begin
  if (select auth.uid()) is null or actor is null then
    raise insufficient_privilege using message = 'follow requires an identified person';
  end if;
  if kind = 'person' and p_target_id = actor then
    raise invalid_parameter_value using message = 'a person cannot follow themselves';
  end if;
  target_exists := case kind
    when 'institution' then exists(select 1 from public.institutions x where x.id = p_target_id)
    when 'unit' then exists(select 1 from public.units x where x.id = p_target_id)
    when 'group' then exists(select 1 from public.groups x where x.id = p_target_id)
    when 'person' then exists(select 1 from public.people x where x.id = p_target_id)
  end;
  if not target_exists then
    raise no_data_found using message = 'follow target not found';
  end if;
  if p_follow then
    insert into public.follow_links (follower_person_id, target_kind, target_id, origin)
    select actor, kind, p_target_id, 'manual'
    where not exists (
      select 1 from public.follow_links link
      where link.follower_person_id = actor and link.target_kind = kind
        and link.target_id = p_target_id and link.origin = 'manual' and link.status = 'active'
    );
  else
    -- Perfil oficial obrigatório (spec 068 §2): não se deixa de seguir.
    if kind = 'person' and exists (select 1 from public.official_profiles o
        where o.person_id = p_target_id and o.status = 'active' and o.mandatory) then
      raise invalid_parameter_value using message = 'mandatory official profile',
        detail = 'FOLLOW_MANDATORY_OFFICIAL';
    end if;
    update public.follow_links link
    set status = 'inactive', revoked_at = now(), updated_at = now()
    where link.follower_person_id = actor and link.target_kind = kind
      and link.target_id = p_target_id and link.origin in ('manual', 'official_auto')
      and link.status = 'active';
  end if;
  return public.follow_summary(p_target_kind, p_target_id)
    || jsonb_build_object('following', exists(
      select 1 from public.follow_links link
      where link.follower_person_id = actor and link.target_kind = kind
        and link.target_id = p_target_id and link.status = 'active'));
end $$;

-- Publicação atribuída a um perfil oficial ----------------------------------------------------
alter table public.platform_notices
  add column if not exists official_profile_id uuid references public.official_profiles(id);
create index if not exists platform_notices_official_profile_idx
  on public.platform_notices(official_profile_id) where official_profile_id is not null;

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
    'author', (select pg_catalog.jsonb_build_object('id', o.id, 'handle', o.handle,
        'display_name', o.display_name, 'mandatory', o.mandatory)
      from public.official_profiles o where o.id = p_notice.official_profile_id),
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

-- Resolve e valida o perfil oficial do payload (nulo quando ausente).
create or replace function app_private.superadmin_notice_official_profile(p_payload jsonb)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare raw text := nullif(btrim(coalesce(p_payload ->> 'official_profile_id', '')), '');
begin
  if raw is null then return null; end if;
  if not pg_input_is_valid(raw, 'uuid')
    or not exists (select 1 from public.official_profiles o where o.id = raw::uuid and o.status = 'active') then
    raise invalid_parameter_value using message = 'invalid official profile', detail = 'NOTICE_INVALID_INPUT';
  end if;
  return raw::uuid;
end
$$;
revoke all on function app_private.superadmin_notice_official_profile(jsonb) from public, anon, authenticated, service_role;

create or replace function public.superadmin_notice_save_draft_v2(
  p_request_id uuid, p_notice_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare context_record app_private.superadmin_internal_context;
  notice_record public.platform_notices%rowtype; cached_record record;
  correlation_id uuid := gen_random_uuid(); error_code text;
  request_hash bytea; result_json jsonb; canonical_type text;
  cta_kind text; cta_id uuid; official_id uuid;
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
    official_id := app_private.superadmin_notice_official_profile(p_payload);
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
        cta_target_kind, cta_target_id, official_profile_id
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
        cta_kind, cta_id, official_id)
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
        official_profile_id = official_id,
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

-- Cópia (spec 069) preserva o perfil oficial.
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
      cta_target_kind, cta_target_id, official_profile_id
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
      source_record.cta_target_kind, source_record.cta_target_id, source_record.official_profile_id)
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
      jsonb_build_object('id', source_record.id));
    return result_json;
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_notice_denied(
      'notices.publish', 'notice.duplicate', error_code, correlation_id);
  end;
end
$$;

create or replace function public.superadmin_official_profiles_list_v1()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare context_record app_private.superadmin_internal_context;
begin
  context_record := app_private.superadmin_notice_context('notices.read');
  return jsonb_build_object('ok', true, 'data', jsonb_build_object('items', coalesce((
    select jsonb_agg(jsonb_build_object('id', o.id, 'handle', o.handle,
      'display_name', o.display_name, 'description', o.description,
      'mandatory', o.mandatory, 'status', o.status,
      'followers', (select count(*) from public.follow_links f
        where f.target_kind = 'person' and f.target_id = o.person_id and f.status = 'active'))
      order by o.sort_order, o.handle)
    from public.official_profiles o where o.status = 'active'), '[]'::jsonb)), 'error', null);
end
$$;
alter function public.superadmin_official_profiles_list_v1() owner to postgres;
revoke all on function public.superadmin_official_profiles_list_v1() from public, anon, service_role;
grant execute on function public.superadmin_official_profiles_list_v1() to authenticated;

commit;
