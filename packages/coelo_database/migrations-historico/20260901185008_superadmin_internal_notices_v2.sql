-- Forward-only internal gateway for Superadmin Notices.
-- This migration deliberately does not reuse the historical people-based RPCs.

alter type public.notice_type add value if not exists 'highlight';
alter type public.notice_type add value if not exists 'for_you';
alter type public.notice_status add value if not exists 'active';
alter type public.notice_status add value if not exists 'paused';
alter type public.notice_status add value if not exists 'inactive';

begin;

alter table public.platform_notices
  add column if not exists priority_code text not null default 'routine',
  add column if not exists audience_json jsonb not null
    default jsonb_build_object('rules', jsonb_build_array(jsonb_build_object(
      'dimension', 'platform', 'select_all', true))),
  add column if not exists audience_label text not null default 'Toda a plataforma',
  add column if not exists behavior text not null default 'dismissible',
  add column if not exists target_device text not null default 'all',
  add column if not exists content_format text not null default 'text_background',
  add column if not exists background_color text,
  add column if not exists text_color text,
  add column if not exists button_color text,
  add column if not exists popup_size text not null default 'standard',
  add column if not exists has_outer_inset boolean not null default true,
  add column if not exists recurrence text not null default 'one_time',
  add column if not exists recurrence_config jsonb not null default '{}'::jsonb,
  add column if not exists image_orientation text not null default 'vertical',
  add column if not exists management_version bigint not null default 1,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists created_by_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id),
  add column if not exists updated_by_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id),
  add column if not exists published_by_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id);

-- OQ-038 canonical mapping. Historical enum labels remain physically present because
-- PostgreSQL enum labels cannot be removed safely, but no row or command may use them.
update public.platform_notices set status = 'active' where status::text = 'published';
update public.platform_notices set status = 'inactive' where status::text = 'archived';

alter table public.platform_notices
  drop constraint if exists platform_notices_internal_v2_values_ck,
  add constraint platform_notices_internal_v2_values_ck check (
    status::text in ('draft', 'scheduled', 'active', 'paused', 'expired', 'inactive')
    and priority_code in ('routine', 'important', 'urgent')
    and behavior in ('dismissible', 'confirmation', 'checkbox_confirmation')
    and target_device in ('all', 'web', 'mobile', 'tablet')
    and content_format = 'text_background'
    and popup_size in ('compact', 'standard', 'large', 'fullscreen')
    and recurrence in ('one_time', 'daily', 'weekly', 'monthly', 'interval')
    and image_orientation in ('vertical', 'horizontal')
    and management_version > 0
    and char_length(btrim(coalesce(title, ''))) between 1 and 120
    and char_length(btrim(coalesce(body_text, ''))) between 1 and 4000
    and char_length(btrim(audience_label)) between 1 and 200
    and (ends_at is null or starts_at is null or ends_at >= starts_at)
    and (background_color is null or background_color ~ '^#[0-9A-F]{6}$')
    and (text_color is null or text_color ~ '^#[0-9A-F]{6}$')
    and (button_color is null or button_color ~ '^#[0-9A-F]{6}$')
  ) not valid;

create index if not exists platform_notices_internal_directory_idx
  on public.platform_notices(updated_at desc, id desc);
create index if not exists platform_notices_internal_lifecycle_idx
  on public.platform_notices(status, starts_at, ends_at, id)
  where status in ('scheduled'::public.notice_status, 'active'::public.notice_status);
create index if not exists platform_notices_created_internal_fk_idx
  on public.platform_notices(created_by_internal_identity_id)
  where created_by_internal_identity_id is not null;
create index if not exists platform_notices_updated_internal_fk_idx
  on public.platform_notices(updated_by_internal_identity_id)
  where updated_by_internal_identity_id is not null;
create index if not exists platform_notices_published_internal_fk_idx
  on public.platform_notices(published_by_internal_identity_id)
  where published_by_internal_identity_id is not null;

create table if not exists app_private.superadmin_notice_command_receipts (
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id),
  request_id uuid not null,
  action_code text not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  result_json jsonb not null,
  created_at timestamptz not null default now(),
  primary key (internal_identity_id, request_id, action_code)
);

alter table public.platform_notices enable row level security;
alter table public.platform_notices force row level security;
alter table public.notice_rules enable row level security;
alter table public.notice_rules force row level security;
alter table public.notice_media enable row level security;
alter table public.notice_media force row level security;
alter table public.notice_receipts enable row level security;
alter table public.notice_receipts force row level security;
alter table public.notice_events enable row level security;
alter table public.notice_events force row level security;
alter table app_private.superadmin_notice_command_receipts enable row level security;
alter table app_private.superadmin_notice_command_receipts force row level security;

revoke all on table public.platform_notices, public.notice_rules, public.notice_media,
  public.notice_receipts, public.notice_events,
  app_private.superadmin_notice_command_receipts
from public, anon, authenticated, service_role;

-- The schema catalogue names analytics.notice_events as canonical. Preserve the
-- historical public table read-only and move its rows into the protected schema.
create table if not exists analytics.notice_events (
  id uuid primary key default gen_random_uuid(),
  notice_id uuid not null references public.platform_notices(id) on delete restrict,
  event_name text not null,
  person_id uuid references public.people(id) on delete restrict,
  institution_id uuid references public.institutions(id) on delete restrict,
  occurred_at timestamptz not null default now(),
  properties_json jsonb not null default '{}'::jsonb
);
insert into analytics.notice_events(
  id, notice_id, event_name, person_id, institution_id, occurred_at, properties_json
)
select id, notice_id, event_name, person_id, institution_id, occurred_at, properties_json
from public.notice_events
on conflict (id) do nothing;
create index if not exists analytics_notice_events_notice_fk_idx
  on analytics.notice_events(notice_id);
create index if not exists analytics_notice_events_person_fk_idx
  on analytics.notice_events(person_id) where person_id is not null;
create index if not exists analytics_notice_events_institution_fk_idx
  on analytics.notice_events(institution_id) where institution_id is not null;
alter table analytics.notice_events enable row level security;
alter table analytics.notice_events force row level security;
revoke all on table analytics.notice_events from public, anon, authenticated, service_role;

insert into public.platform_permissions(
  code, module_code, screen_code, action_code, description, risk_level,
  requires_mfa, status
)
values
  ('notices.read', 'communication', 'notices', 'read',
   'Ler comunicações administrativas.', 'normal', false, 'active'),
  ('notices.manage', 'communication', 'notices', 'manage',
   'Criar e alterar comunicações administrativas.', 'high', true, 'active'),
  ('notices.publish', 'communication', 'notices', 'publish',
   'Publicar e alterar o ciclo de comunicações administrativas.', 'critical', true, 'active')
on conflict (code) do update set
  module_code = excluded.module_code,
  screen_code = excluded.screen_code,
  action_code = excluded.action_code,
  description = excluded.description,
  risk_level = excluded.risk_level,
  requires_mfa = excluded.requires_mfa,
  status = 'active';

-- Owner is the only mutation principal in this cutover. Content and Operations
-- receive only the minimized directory/detail read capability.
insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow'::public.permission_effect, 'active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on permission_record.code = 'notices.read'
where role_record.code in ('owner', 'content', 'operations')
on conflict (role_id, permission_id) do update set
  effect = 'allow', status = 'active', revoked_at = null;

insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow'::public.permission_effect, 'active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on permission_record.code in ('notices.manage', 'notices.publish')
where role_record.code = 'owner'
on conflict (role_id, permission_id) do update set
  effect = 'allow', status = 'active', revoked_at = null;

create or replace function app_private.superadmin_notice_context(p_permission_code text)
returns app_private.superadmin_internal_context
language plpgsql stable security definer set search_path = '' as $$
declare context_record app_private.superadmin_internal_context;
begin
  select * into strict context_record
  from app_private.require_superadmin_internal_context(p_permission_code);
  if context_record.scope_kind <> 'platform' then
    raise insufficient_privilege using
      message = 'notice authorization denied', detail = 'SAI_PERMISSION_DENIED';
  end if;
  return context_record;
end
$$;

create or replace function app_private.superadmin_notice_error(
  p_code text, p_correlation_id uuid
) returns jsonb language sql immutable security definer set search_path = '' as $$
  select case
    when p_code like 'SAI_%' then
      app_private.superadmin_internal_error_envelope(p_code, p_correlation_id)
    else pg_catalog.jsonb_build_object(
      'ok', false, 'data', null,
      'error', pg_catalog.jsonb_build_object(
        'code', case when p_code in (
          'NOTICE_INVALID_INPUT', 'NOTICE_NOT_FOUND', 'NOTICE_CONFLICT',
          'NOTICE_INVALID_TRANSITION', 'NOTICE_TERMINAL', 'NOTICE_MEDIA_BLOCKED'
        ) then p_code else 'NOTICE_INTERNAL_ERROR' end,
        'message', case
          when p_code = 'NOTICE_INVALID_INPUT' then 'Revise os dados da comunicação.'
          when p_code = 'NOTICE_NOT_FOUND' then 'Comunicação não encontrada.'
          when p_code = 'NOTICE_CONFLICT' then 'A comunicação foi alterada. Recarregue e tente novamente.'
          when p_code in ('NOTICE_INVALID_TRANSITION', 'NOTICE_TERMINAL') then 'Esta transição não é permitida.'
          when p_code = 'NOTICE_MEDIA_BLOCKED' then 'A mídia ainda não está disponível.'
          else 'Não foi possível concluir a operação.' end,
        'correlation_id', p_correlation_id,
        'http_status', case
          when p_code = 'NOTICE_NOT_FOUND' then 404
          when p_code = 'NOTICE_CONFLICT' then 409
          when p_code in ('NOTICE_INVALID_INPUT', 'NOTICE_INVALID_TRANSITION',
            'NOTICE_TERMINAL', 'NOTICE_MEDIA_BLOCKED') then 422
          else 500 end)) end
$$;

create or replace function app_private.superadmin_notice_denied(
  p_permission_code text, p_action_code text, p_code text, p_correlation_id uuid
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare normalized_code text := case when p_code in (
  'NOTICE_INVALID_INPUT', 'NOTICE_NOT_FOUND', 'NOTICE_CONFLICT',
  'NOTICE_INVALID_TRANSITION', 'NOTICE_TERMINAL', 'NOTICE_MEDIA_BLOCKED',
  'SAI_AUTH_REQUIRED', 'SAI_SESSION_INVALID', 'SAI_INTERNAL_CONTEXT_DENIED',
  'SAI_MEMBERSHIP_SUSPENDED', 'SAI_MEMBERSHIP_REVOKED',
  'SAI_PERMISSION_DENIED', 'SAI_MFA_REQUIRED') then p_code
  else 'SAI_INTERNAL_ERROR' end;
begin
  perform app_private.audit_superadmin_internal_denial_if_identified(
    p_permission_code, p_action_code, normalized_code, p_correlation_id);
  return app_private.superadmin_notice_error(normalized_code, p_correlation_id);
end
$$;

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

create or replace function app_private.superadmin_notice_validate_payload(p_payload jsonb)
returns void language plpgsql stable security definer set search_path = '' as $$
declare rule jsonb; dimension text; target_id text;
begin
  if jsonb_typeof(p_payload) <> 'object'
    or p_payload ->> 'type' not in ('popup', 'notice', 'critical_notice',
      'content_card', 'highlight', 'for_you')
    or char_length(btrim(coalesce(p_payload ->> 'title', ''))) not between 1 and 120
    or char_length(btrim(coalesce(p_payload ->> 'body', ''))) not between 1 and 4000
    or p_payload ->> 'priority' not in ('routine', 'important', 'urgent')
    or p_payload ->> 'content_format' <> 'text_background'
    or p_payload ->> 'behavior' not in ('dismissible', 'confirmation', 'checkbox_confirmation')
    or p_payload ->> 'target_device' not in ('all', 'web', 'mobile', 'tablet')
    or p_payload ->> 'popup_size' not in ('compact', 'standard', 'large', 'fullscreen')
    or p_payload ->> 'recurrence' not in ('one_time', 'daily', 'weekly', 'monthly', 'interval')
    or nullif(p_payload ->> 'starts_at', '') is null
    or not pg_input_is_valid(p_payload ->> 'starts_at', 'timestamptz')
    or (nullif(p_payload ->> 'ends_at', '') is not null
      and not pg_input_is_valid(p_payload ->> 'ends_at', 'timestamptz'))
    or jsonb_typeof(p_payload -> 'audience') <> 'object'
    or jsonb_typeof(p_payload #> '{audience,rules}') <> 'array'
    or jsonb_array_length(p_payload #> '{audience,rules}') <> 1 then
    raise invalid_parameter_value using message = 'invalid notice payload',
      detail = case when p_payload ->> 'content_format' = 'image'
        then 'NOTICE_MEDIA_BLOCKED' else 'NOTICE_INVALID_INPUT' end;
  end if;
  if p_payload ? 'ends_at' and nullif(p_payload ->> 'ends_at', '') is not null
    and (p_payload ->> 'ends_at')::timestamptz < (p_payload ->> 'starts_at')::timestamptz then
    raise invalid_parameter_value using message = 'invalid notice dates',
      detail = 'NOTICE_INVALID_INPUT';
  end if;
  for rule in select value from jsonb_array_elements(p_payload #> '{audience,rules}') loop
    dimension := rule ->> 'dimension';
    if dimension not in ('platform', 'institution', 'unit', 'group', 'person')
      or jsonb_typeof(coalesce(rule -> 'target_ids', '[]'::jsonb)) <> 'array'
      or jsonb_array_length(coalesce(rule -> 'target_ids', '[]'::jsonb)) > 500
      or (dimension = 'platform' and not coalesce((rule ->> 'select_all')::boolean, false))
      or (dimension <> 'platform' and not coalesce((rule ->> 'select_all')::boolean, false)
        and jsonb_array_length(coalesce(rule -> 'target_ids', '[]'::jsonb)) = 0) then
      raise invalid_parameter_value using message = 'invalid notice audience',
        detail = 'NOTICE_INVALID_INPUT';
    end if;
    for target_id in select value from jsonb_array_elements_text(
      coalesce(rule -> 'target_ids', '[]'::jsonb)) loop
      begin perform target_id::uuid;
      exception when invalid_text_representation then
        raise invalid_parameter_value using message = 'invalid notice audience id',
          detail = 'NOTICE_INVALID_INPUT';
      end;
      if (dimension = 'institution' and not exists(select 1 from public.institutions where id = target_id::uuid))
        or (dimension = 'unit' and not exists(select 1 from public.units where id = target_id::uuid))
        or (dimension = 'group' and not exists(select 1 from public.groups where id = target_id::uuid))
        or (dimension = 'person' and not exists(select 1 from public.people where id = target_id::uuid)) then
        raise invalid_parameter_value using message = 'invalid notice audience target',
          detail = 'NOTICE_INVALID_INPUT';
      end if;
    end loop;
  end loop;
end
$$;

create or replace function app_private.superadmin_notice_guard_transition()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status::text in ('expired', 'inactive') and new.status is distinct from old.status then
    raise object_not_in_prerequisite_state using message = 'terminal notice state',
      detail = 'NOTICE_TERMINAL';
  end if;
  if new.status::text = 'published' or new.status::text = 'archived' then
    raise invalid_parameter_value using message = 'legacy notice state denied',
      detail = 'NOTICE_INVALID_TRANSITION';
  end if;
  if old.status is distinct from new.status and not (
    (old.status::text = 'draft' and new.status::text in ('scheduled', 'active', 'inactive'))
    or (old.status::text = 'scheduled' and new.status::text in ('active', 'expired', 'inactive'))
    or (old.status::text = 'active' and new.status::text in ('paused', 'expired', 'inactive'))
    or (old.status::text = 'paused' and new.status::text in ('scheduled', 'active', 'inactive'))
  ) then
    raise object_not_in_prerequisite_state using message = 'invalid notice transition',
      detail = 'NOTICE_INVALID_TRANSITION';
  end if;
  return new;
end
$$;

drop trigger if exists platform_notices_internal_transition_guard on public.platform_notices;
create trigger platform_notices_internal_transition_guard
before update of status on public.platform_notices
for each row execute function app_private.superadmin_notice_guard_transition();

create or replace function app_private.superadmin_notice_append_audit(
  p_context app_private.superadmin_internal_context,
  p_action_code text, p_resource_id uuid, p_outcome text,
  p_reason_code text, p_correlation_id uuid
) returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  perform app_private.audit_append_superadmin_internal(
    p_context.internal_identity_id, p_context.internal_auth_link_id,
    p_context.internal_membership_id, p_context.session_id,
    p_context.permission_code, p_context.aal, p_action_code,
    p_outcome::public.audit_outcome, left(p_reason_code, 120), p_correlation_id,
    null, 'platform_notice', p_resource_id);
end
$$;

create or replace function app_private.superadmin_notice_refresh_lifecycle()
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  update public.platform_notices
  set status = 'active', published_at = coalesce(published_at, clock_timestamp()),
      updated_at = clock_timestamp(), management_version = management_version + 1
  where status = 'scheduled'::public.notice_status
    and starts_at <= clock_timestamp()
    and (ends_at is null or ends_at > clock_timestamp());
  update public.platform_notices
  set status = 'expired', updated_at = clock_timestamp(),
      management_version = management_version + 1
  where status in ('scheduled'::public.notice_status, 'active'::public.notice_status)
    and ends_at is not null and ends_at <= clock_timestamp();
end
$$;

create or replace function public.superadmin_notice_directory_v2(
  p_types text[] default null,
  p_search text default null,
  p_statuses text[] default null,
  p_priorities text[] default null,
  p_cursor_occurred_at timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 25
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare context_record app_private.superadmin_internal_context;
  correlation_id uuid := gen_random_uuid(); items jsonb; next_row record;
  error_code text; has_more boolean;
begin
  begin
    context_record := app_private.superadmin_notice_context('notices.read');
    if p_limit not between 1 and 100 or char_length(coalesce(p_search, '')) > 120
      or ((p_cursor_occurred_at is null) <> (p_cursor_id is null))
      or (p_types is not null and not (p_types <@ array['popup','notice','critical_notice','content_card','highlight','for_you']::text[]))
      or (p_statuses is not null and not (p_statuses <@ array['draft','scheduled','active','paused','expired','inactive']::text[]))
      or (p_priorities is not null and not (p_priorities <@ array['routine','important','urgent']::text[])) then
      raise invalid_parameter_value using message = 'invalid directory query', detail = 'NOTICE_INVALID_INPUT';
    end if;
    perform app_private.superadmin_notice_refresh_lifecycle();
    with page as (
      select notice_record.*,
        row_number() over(order by notice_record.updated_at desc, notice_record.id desc) page_row
      from public.platform_notices notice_record
      where (p_search is null or notice_record.title ilike '%' ||
          replace(replace(btrim(p_search), '%', '\%'), '_', '\_') || '%' escape '\')
        and (p_types is null or notice_record.notice_type::text = any(p_types))
        and (p_statuses is null or notice_record.status::text = any(p_statuses))
        and (p_priorities is null or notice_record.priority_code = any(p_priorities))
        and (p_cursor_occurred_at is null or
          (notice_record.updated_at, notice_record.id) < (p_cursor_occurred_at, p_cursor_id))
      order by notice_record.updated_at desc, notice_record.id desc
      limit p_limit + 1
    )
    select coalesce(jsonb_agg(app_private.superadmin_notice_json(page)
      order by page.updated_at desc, page.id desc) filter(where page.page_row <= p_limit), '[]'::jsonb),
      count(*) > p_limit
    into items, has_more from page;
    if has_more then
      select updated_at, id into next_row from public.platform_notices notice_record
      where (p_search is null or notice_record.title ilike '%' ||
          replace(replace(btrim(p_search), '%', '\%'), '_', '\_') || '%' escape '\')
        and (p_types is null or notice_record.notice_type::text = any(p_types))
        and (p_statuses is null or notice_record.status::text = any(p_statuses))
        and (p_priorities is null or notice_record.priority_code = any(p_priorities))
        and (p_cursor_occurred_at is null or
          (notice_record.updated_at, notice_record.id) < (p_cursor_occurred_at, p_cursor_id))
      order by updated_at desc, id desc offset p_limit - 1 limit 1;
    end if;
    return jsonb_build_object('ok', true, 'data', jsonb_build_object(
      'items', items,
      'next_cursor_occurred_at', case when has_more then next_row.updated_at else null end,
      'next_cursor_id', case when has_more then next_row.id else null end), 'error', null);
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_notice_denied(
      'notices.read', 'notice.directory', error_code, correlation_id);
  end;
end
$$;

create or replace function public.superadmin_notice_detail_v2(p_notice_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare context_record app_private.superadmin_internal_context;
  notice_record public.platform_notices%rowtype;
  correlation_id uuid := gen_random_uuid(); error_code text;
begin
  begin
    context_record := app_private.superadmin_notice_context('notices.read');
    perform app_private.superadmin_notice_refresh_lifecycle();
    select * into notice_record from public.platform_notices where id = p_notice_id;
    if notice_record.id is null then
      raise no_data_found using message = 'notice unavailable', detail = 'NOTICE_NOT_FOUND';
    end if;
    return jsonb_build_object('ok', true,
      'data', app_private.superadmin_notice_json(notice_record), 'error', null);
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_notice_denied(
      'notices.read', 'notice.detail', error_code, correlation_id);
  end;
end
$$;

create or replace function public.superadmin_notice_audience_options_v2(
  p_dimension text, p_search text default null, p_parent_ids uuid[] default null,
  p_cursor_label text default null, p_cursor_id text default null,
  p_limit integer default 30
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare context_record app_private.superadmin_internal_context;
  correlation_id uuid := gen_random_uuid(); error_code text; items jsonb;
begin
  begin
    context_record := app_private.superadmin_notice_context('notices.read');
    if p_dimension not in ('institution', 'unit', 'group', 'person', 'role', 'plan')
      or p_limit not between 1 and 100 or char_length(coalesce(p_search, '')) > 120 then
      raise invalid_parameter_value using message = 'invalid audience query', detail = 'NOTICE_INVALID_INPUT';
    end if;
    if p_dimension = 'institution' then
      select coalesce(jsonb_agg(jsonb_build_object('id', id, 'label', public_name, 'parent_id', null)
        order by public_name, id), '[]'::jsonb) into items
      from (select id, public_name from public.institutions
        where (p_search is null or public_name ilike '%' || p_search || '%')
          and (p_cursor_label is null or (public_name, id::text) > (p_cursor_label, p_cursor_id))
        order by public_name, id limit p_limit) options;
    elsif p_dimension = 'unit' then
      select coalesce(jsonb_agg(jsonb_build_object('id', id, 'label', name, 'parent_id', institution_id)
        order by name, id), '[]'::jsonb) into items
      from (select id, name, institution_id from public.units
        where (p_parent_ids is null or institution_id = any(p_parent_ids))
          and (p_search is null or name ilike '%' || p_search || '%')
          and (p_cursor_label is null or (name, id::text) > (p_cursor_label, p_cursor_id))
        order by name, id limit p_limit) options;
    elsif p_dimension = 'group' then
      select coalesce(jsonb_agg(jsonb_build_object('id', id, 'label', name, 'parent_id', unit_id)
        order by name, id), '[]'::jsonb) into items
      from (select id, name, unit_id from public.groups
        where (p_parent_ids is null or unit_id = any(p_parent_ids))
          and (p_search is null or name ilike '%' || p_search || '%')
          and (p_cursor_label is null or (name, id::text) > (p_cursor_label, p_cursor_id))
        order by name, id limit p_limit) options;
    elsif p_dimension = 'person' then
      select coalesce(jsonb_agg(jsonb_build_object('id', id, 'label', display_name, 'parent_id', null)
        order by display_name, id), '[]'::jsonb) into items
      from (select id, display_name from public.people where deleted_at is null
        and (p_search is null or display_name ilike '%' || p_search || '%')
        and (p_cursor_label is null or (display_name, id::text) > (p_cursor_label, p_cursor_id))
        order by display_name, id limit p_limit) options;
    elsif p_dimension = 'plan' then
      select coalesce(jsonb_agg(jsonb_build_object('id', id, 'label', name, 'parent_id', null)
        order by name, id), '[]'::jsonb) into items
      from (select id, name from public.plans where status = 'active'
        and (p_search is null or name ilike '%' || p_search || '%')
        and (p_cursor_label is null or (name, id::text) > (p_cursor_label, p_cursor_id))
        order by name, id limit p_limit) options;
    else
      select coalesce(jsonb_agg(jsonb_build_object('id', code, 'label', name, 'parent_id', null)
        order by name, code), '[]'::jsonb) into items
      from (select code, name from public.institution_roles where status = 'active'
        and (p_search is null or name ilike '%' || p_search || '%')
        and (p_cursor_label is null or (name, code) > (p_cursor_label, p_cursor_id))
        order by name, code limit p_limit) options;
    end if;
    return jsonb_build_object('ok', true, 'data', jsonb_build_object(
      'items', items, 'next_cursor_label', null, 'next_cursor_id', null), 'error', null);
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_notice_denied(
      'notices.read', 'notice.audience_options', error_code, correlation_id);
  end;
end
$$;

create or replace function public.superadmin_notice_save_draft_v2(
  p_request_id uuid, p_notice_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare context_record app_private.superadmin_internal_context;
  notice_record public.platform_notices%rowtype; cached_record record;
  correlation_id uuid := gen_random_uuid(); error_code text;
  request_hash bytea; result_json jsonb; canonical_type text;
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
        updated_by_internal_identity_id, created_at, updated_at, silencing_policy
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
        jsonb_build_object('link_label', nullif(btrim(p_payload ->> 'link_label'), '')))
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

create or replace function public.superadmin_notice_publish_v2(
  p_request_id uuid, p_notice_id uuid, p_expected_version bigint
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare context_record app_private.superadmin_internal_context;
  notice_record public.platform_notices%rowtype; cached_record record;
  correlation_id uuid := gen_random_uuid(); error_code text;
  request_hash bytea; result_json jsonb; next_status public.notice_status;
begin
  begin
    context_record := app_private.superadmin_notice_context('notices.publish');
    if p_request_id is null or p_notice_id is null or p_expected_version is null then
      raise invalid_parameter_value using message = 'publish command incomplete', detail = 'NOTICE_INVALID_INPUT';
    end if;
    request_hash := extensions.digest(p_notice_id::text || '|' || coalesce(p_expected_version::text, ''), 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(
      context_record.internal_identity_id::text || p_request_id::text || 'notice.publish', 0));
    select * into cached_record from app_private.superadmin_notice_command_receipts
      where internal_identity_id = context_record.internal_identity_id
        and request_id = p_request_id and action_code = 'publish';
    if cached_record.request_id is not null then
      if cached_record.request_hash <> request_hash then
        raise unique_violation using message = 'idempotency conflict', detail = 'NOTICE_CONFLICT';
      end if;
      return cached_record.result_json;
    end if;
    select * into notice_record from public.platform_notices where id = p_notice_id for update;
    if notice_record.id is null then
      raise no_data_found using message = 'notice unavailable', detail = 'NOTICE_NOT_FOUND';
    end if;
    if notice_record.management_version <> p_expected_version then
      raise serialization_failure using message = 'version conflict', detail = 'NOTICE_CONFLICT';
    end if;
    if notice_record.status::text <> 'draft' then
      raise object_not_in_prerequisite_state using message = 'notice cannot be published',
        detail = case when notice_record.status::text in ('expired', 'inactive')
          then 'NOTICE_TERMINAL' else 'NOTICE_INVALID_TRANSITION' end;
    end if;
    if notice_record.content_format <> 'text_background' then
      raise invalid_parameter_value using message = 'notice media blocked', detail = 'NOTICE_MEDIA_BLOCKED';
    end if;
    if notice_record.ends_at is not null and notice_record.ends_at <= clock_timestamp() then
      raise invalid_parameter_value using message = 'notice already ended', detail = 'NOTICE_INVALID_INPUT';
    end if;
    next_status := case when notice_record.starts_at > clock_timestamp()
      then 'scheduled'::public.notice_status else 'active'::public.notice_status end;
    update public.platform_notices set status = next_status,
      published_at = case when next_status::text = 'active' then clock_timestamp() else null end,
      published_by_internal_identity_id = context_record.internal_identity_id,
      updated_by_internal_identity_id = context_record.internal_identity_id,
      management_version = management_version + 1, updated_at = clock_timestamp()
    where id = p_notice_id returning * into notice_record;
    result_json := jsonb_build_object('ok', true,
      'data', app_private.superadmin_notice_json(notice_record), 'error', null);
    insert into app_private.superadmin_notice_command_receipts(
      internal_identity_id, request_id, action_code, request_hash, result_json
    ) values (context_record.internal_identity_id, p_request_id, 'publish', request_hash, result_json);
    perform app_private.superadmin_notice_append_audit(context_record, 'notice.publish',
      notice_record.id, 'success', null, correlation_id);
    return result_json;
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_notice_denied(
      'notices.publish', 'notice.publish', error_code, correlation_id);
  end;
end
$$;

create or replace function public.superadmin_notice_change_status_v2(
  p_request_id uuid, p_notice_id uuid, p_expected_version bigint,
  p_status text, p_reason text default null
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare context_record app_private.superadmin_internal_context;
  notice_record public.platform_notices%rowtype; cached_record record;
  correlation_id uuid := gen_random_uuid(); error_code text;
  request_hash bytea; result_json jsonb; target_status public.notice_status;
begin
  begin
    context_record := app_private.superadmin_notice_context('notices.publish');
    if p_request_id is null or p_notice_id is null or p_expected_version is null then
      raise invalid_parameter_value using message = 'status command incomplete', detail = 'NOTICE_INVALID_INPUT';
    end if;
    if p_status not in ('paused', 'scheduled', 'inactive')
      or (p_status = 'inactive' and char_length(btrim(coalesce(p_reason, ''))) not between 3 and 500) then
      raise invalid_parameter_value using message = 'invalid status command', detail = 'NOTICE_INVALID_INPUT';
    end if;
    request_hash := extensions.digest(p_notice_id::text || '|' || coalesce(p_expected_version::text, '') ||
      '|' || p_status || '|' || coalesce(btrim(p_reason), ''), 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(
      context_record.internal_identity_id::text || p_request_id::text || 'notice.status', 0));
    select * into cached_record from app_private.superadmin_notice_command_receipts
      where internal_identity_id = context_record.internal_identity_id
        and request_id = p_request_id and action_code = 'status';
    if cached_record.request_id is not null then
      if cached_record.request_hash <> request_hash then
        raise unique_violation using message = 'idempotency conflict', detail = 'NOTICE_CONFLICT';
      end if;
      return cached_record.result_json;
    end if;
    select * into notice_record from public.platform_notices where id = p_notice_id for update;
    if notice_record.id is null then
      raise no_data_found using message = 'notice unavailable', detail = 'NOTICE_NOT_FOUND';
    end if;
    if notice_record.management_version <> p_expected_version then
      raise serialization_failure using message = 'version conflict', detail = 'NOTICE_CONFLICT';
    end if;
    if notice_record.status::text in ('expired', 'inactive') then
      raise object_not_in_prerequisite_state using message = 'terminal notice state', detail = 'NOTICE_TERMINAL';
    end if;
    if (p_status = 'paused' and notice_record.status::text <> 'active')
      or (p_status = 'scheduled' and notice_record.status::text <> 'paused') then
      raise object_not_in_prerequisite_state using message = 'invalid notice transition', detail = 'NOTICE_INVALID_TRANSITION';
    end if;
    target_status := case
      when p_status = 'scheduled' and notice_record.starts_at <= clock_timestamp()
        then 'active'::public.notice_status
      else p_status::public.notice_status end;
    update public.platform_notices set status = target_status,
      published_at = case when target_status::text = 'active'
        then coalesce(published_at, clock_timestamp()) else published_at end,
      management_version = management_version + 1,
      updated_by_internal_identity_id = context_record.internal_identity_id,
      updated_at = clock_timestamp()
    where id = p_notice_id returning * into notice_record;
    result_json := jsonb_build_object('ok', true,
      'data', app_private.superadmin_notice_json(notice_record), 'error', null);
    insert into app_private.superadmin_notice_command_receipts(
      internal_identity_id, request_id, action_code, request_hash, result_json
    ) values (context_record.internal_identity_id, p_request_id, 'status', request_hash, result_json);
    perform app_private.superadmin_notice_append_audit(context_record,
      'notice.status.' || p_status, notice_record.id, 'success',
      nullif(left(btrim(p_reason), 120), ''), correlation_id);
    return result_json;
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_notice_denied(
      'notices.publish', 'notice.status.' || coalesce(p_status, 'invalid'),
      error_code, correlation_id);
  end;
end
$$;

-- Retire the people-based public gateways from client execution. Workers remain private.
do $revoke_legacy$
declare function_record regprocedure;
begin
  for function_record in
    select procedure_record.oid::regprocedure
    from pg_proc procedure_record
    join pg_namespace namespace_record on namespace_record.oid = procedure_record.pronamespace
    where namespace_record.nspname = 'public'
      and procedure_record.proname in (
        'list_notices_for_superadmin', 'get_notice_for_superadmin',
        'list_notice_audience_options_for_superadmin',
        'save_notice_draft_for_superadmin', 'publish_notice_for_superadmin',
        'change_notice_status_for_superadmin')
  loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role',
      function_record);
  end loop;
end
$revoke_legacy$;

do $acl$
declare function_record regprocedure;
begin
  for function_record in
    select procedure_record.oid::regprocedure
    from pg_proc procedure_record
    join pg_namespace namespace_record on namespace_record.oid = procedure_record.pronamespace
    where (namespace_record.nspname = 'app_private'
      and procedure_record.proname like 'superadmin_notice_%')
      or (namespace_record.nspname = 'public'
      and procedure_record.proname like 'superadmin_notice_%_v2')
  loop
    execute format('alter function %s owner to postgres', function_record);
    execute format('revoke all on function %s from public, anon, authenticated, service_role',
      function_record);
  end loop;
end
$acl$;

grant execute on function public.superadmin_notice_directory_v2(
  text[], text, text[], text[], timestamptz, uuid, integer) to authenticated;
grant execute on function public.superadmin_notice_detail_v2(uuid) to authenticated;
grant execute on function public.superadmin_notice_audience_options_v2(
  text, text, uuid[], text, text, integer) to authenticated;
grant execute on function public.superadmin_notice_save_draft_v2(
  uuid, uuid, bigint, jsonb) to authenticated;
grant execute on function public.superadmin_notice_publish_v2(uuid, uuid, bigint) to authenticated;
grant execute on function public.superadmin_notice_change_status_v2(
  uuid, uuid, bigint, text, text) to authenticated;

commit;
