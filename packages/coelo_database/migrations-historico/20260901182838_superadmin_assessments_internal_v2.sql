begin;

-- Avaliacoes intentionally inherit the already-approved Activities internal
-- capability matrix. Reads use activities.read and every mutation uses
-- activities.manage. This migration does not create roles or permissions.

create table public.activity_assessment_configurations (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid,
  version bigint not null default 1 check (version > 0),
  management_version bigint not null default 1 check (management_version > 0),
  periodicity text not null check (periodicity in ('bimonthly','trimester','semester','annual')),
  result_scale_kind text not null check (result_scale_kind in (
    'numeric_0_10','numeric_0_100','concept','numeric_1_5','binary','stars_0_5')),
  scale_options jsonb not null default '{}'::jsonb check (jsonb_typeof(scale_options) = 'object'),
  allow_final_override boolean not null default false,
  enabled boolean not null default true,
  status text not null default 'draft' check (status in ('draft','active','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, institution_id),
  foreign key (activity_id, institution_id)
    references public.activity_definitions(id, institution_id) on delete cascade,
  foreign key (unit_id, institution_id)
    references public.units(id, institution_id) on delete cascade
);
create index activity_assessment_configurations_scope_idx
  on public.activity_assessment_configurations(institution_id, unit_id, activity_id, status);
create unique index activity_assessment_configurations_active_uidx
  on public.activity_assessment_configurations(
    activity_id, coalesce(unit_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where status = 'active';

create table public.assessment_instruments (
  id uuid primary key default gen_random_uuid(),
  configuration_id uuid not null references public.activity_assessment_configurations(id) on delete cascade,
  name text not null check (btrim(name) <> '' and char_length(name) <= 120),
  weight numeric(7,4) not null check (weight > 0 and weight <= 100),
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  unique (configuration_id, name),
  unique (configuration_id, sort_order)
);
create index assessment_instruments_configuration_idx
  on public.assessment_instruments(configuration_id, sort_order);

create table public.assessment_categories (
  id uuid primary key default gen_random_uuid(),
  configuration_id uuid not null references public.activity_assessment_configurations(id) on delete cascade,
  name text not null check (btrim(name) <> '' and char_length(name) <= 120),
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  unique (configuration_id, name),
  unique (id, configuration_id)
);
create index assessment_categories_configuration_idx
  on public.assessment_categories(configuration_id, sort_order);

create table public.assessment_competencies (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null,
  configuration_id uuid not null references public.activity_assessment_configurations(id) on delete cascade,
  name text not null check (btrim(name) <> '' and char_length(name) <= 160),
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  unique (configuration_id, category_id, name),
  unique (id, configuration_id),
  foreign key (category_id, configuration_id)
    references public.assessment_categories(id, configuration_id) on delete cascade
);
create index assessment_competencies_configuration_idx
  on public.assessment_competencies(configuration_id, category_id, sort_order);

create table public.assessment_configuration_competencies (
  configuration_id uuid not null references public.activity_assessment_configurations(id) on delete cascade,
  competency_id uuid not null,
  sort_order integer not null default 0 check (sort_order >= 0),
  primary key (configuration_id, competency_id),
  foreign key (competency_id, configuration_id)
    references public.assessment_competencies(id, configuration_id) on delete cascade
);

create table public.assessment_scale_concepts (
  id uuid primary key default gen_random_uuid(),
  configuration_id uuid not null references public.activity_assessment_configurations(id) on delete cascade,
  code text not null check (btrim(code) <> '' and char_length(code) <= 40),
  label text not null check (btrim(label) <> '' and char_length(label) <= 100),
  sort_order integer not null default 0 check (sort_order >= 0),
  unique (configuration_id, code),
  unique (configuration_id, sort_order)
);

create table public.assessment_periods (
  id uuid primary key default gen_random_uuid(),
  configuration_id uuid not null references public.activity_assessment_configurations(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid,
  name text not null check (btrim(name) <> '' and char_length(name) <= 120),
  periodicity text not null check (periodicity in ('bimonthly','trimester','semester','annual')),
  ordinal smallint not null check (ordinal between 1 and 12),
  academic_year integer not null check (academic_year between 2000 and 2200),
  starts_on date not null,
  ends_on date not null,
  entry_closes_at timestamptz not null,
  family_release_at timestamptz not null,
  timezone text not null default 'America/Sao_Paulo' check (btrim(timezone) <> ''),
  status text not null default 'draft' check (status in ('draft','open','closed','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, institution_id),
  unique (configuration_id, ordinal),
  foreign key (unit_id, institution_id)
    references public.units(id, institution_id) on delete cascade,
  check (ends_on >= starts_on),
  check (entry_closes_at >= starts_on::timestamptz),
  check (family_release_at >= entry_closes_at)
);
create index assessment_periods_scope_status_idx
  on public.assessment_periods(institution_id, unit_id, status, academic_year, ordinal);

create table public.assessment_gradebooks (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid not null,
  activity_group_link_id uuid not null,
  period_id uuid not null,
  configuration_id uuid not null,
  status text not null default 'draft' check (status in ('draft','submitted','reviewed','published')),
  management_version bigint not null default 1 check (management_version > 0),
  students_payload jsonb not null default '[]'::jsonb check (jsonb_typeof(students_payload) = 'array'),
  family_release_at timestamptz,
  publish_scheduled_at timestamptz,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (activity_group_link_id, period_id),
  foreign key (unit_id, institution_id)
    references public.units(id, institution_id) on delete restrict,
  foreign key (activity_group_link_id, institution_id)
    references public.activity_group_links(id, institution_id) on delete restrict,
  foreign key (period_id, institution_id)
    references public.assessment_periods(id, institution_id) on delete restrict,
  foreign key (configuration_id, institution_id)
    references public.activity_assessment_configurations(id, institution_id) on delete restrict
);
create index assessment_gradebooks_closing_idx
  on public.assessment_gradebooks(institution_id, status, updated_at desc);

create table app_private.superadmin_internal_assessment_command_receipts (
  request_id uuid primary key,
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  aggregate_id uuid not null,
  command_kind text not null check (command_kind in (
    'configuration.save','configuration.activate','gradebook.save','gradebook.submit',
    'gradebook.review','gradebook.return','gradebook.publish','gradebook.schedule')),
  request_hash bytea not null check (octet_length(request_hash) = 32),
  resulting_version bigint not null check (resulting_version > 0),
  resulting_status text not null,
  result_json jsonb not null check (jsonb_typeof(result_json) = 'object'),
  correlation_id uuid not null unique,
  created_at timestamptz not null default now()
);
create index superadmin_internal_assessment_receipts_actor_idx
  on app_private.superadmin_internal_assessment_command_receipts(internal_identity_id, created_at desc);
create index superadmin_internal_assessment_receipts_aggregate_idx
  on app_private.superadmin_internal_assessment_command_receipts(aggregate_id, created_at desc);

create table app_private.superadmin_internal_assessment_events (
  id uuid primary key default gen_random_uuid(),
  gradebook_id uuid not null references public.assessment_gradebooks(id) on delete cascade,
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  event_kind text not null check (event_kind in ('saved','submitted','reviewed','returned','published','scheduled')),
  reason text,
  version bigint not null check (version > 0),
  correlation_id uuid not null unique,
  created_at timestamptz not null default now(),
  check (reason is null or (btrim(reason) <> '' and char_length(reason) <= 500))
);
create index superadmin_internal_assessment_events_history_idx
  on app_private.superadmin_internal_assessment_events(gradebook_id, created_at desc);

create or replace function app_private.assessment_v2_require_context(
  p_permission_code text, p_institution_id uuid default null
) returns app_private.superadmin_internal_context
language plpgsql volatile security definer set search_path = '' as $$
declare ctx app_private.superadmin_internal_context;
begin
  select * into strict ctx
  from app_private.require_superadmin_internal_context(p_permission_code);
  if p_institution_id is not null then
    if not exists (select 1 from public.institutions i where i.id = p_institution_id)
      or (ctx.scope_kind = 'institution'
        and ctx.scope_institution_id is distinct from p_institution_id) then
      raise insufficient_privilege using message = 'assessment access denied', detail = 'SAI_PERMISSION_DENIED';
    end if;
    ctx.resolved_institution_id := p_institution_id;
  end if;
  return ctx;
end $$;

create or replace function app_private.assessment_v2_hash(p_value jsonb)
returns bytea language sql immutable security invoker set search_path = ''
as $$select extensions.digest(pg_catalog.convert_to(coalesce(p_value, 'null'::jsonb)::text, 'UTF8'), 'sha256')$$;

create or replace function app_private.assessment_v2_replay(
  p_ctx app_private.superadmin_internal_context,
  p_request_id uuid,
  p_command_kind text,
  p_request_hash bytea
) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare receipt app_private.superadmin_internal_assessment_command_receipts%rowtype;
begin
  if p_request_id is null then
    raise invalid_parameter_value using message = 'assessment request_id is required';
  end if;
  select * into receipt
  from app_private.superadmin_internal_assessment_command_receipts r
  where r.request_id = p_request_id
  for update;
  if not found then return null; end if;
  if receipt.internal_identity_id is distinct from p_ctx.internal_identity_id then
    raise insufficient_privilege using message = 'assessment receipt actor mismatch',
      detail = 'SAI_PERMISSION_DENIED';
  end if;
  if receipt.command_kind is distinct from p_command_kind
    or receipt.request_hash is distinct from p_request_hash then
    raise invalid_parameter_value using message = 'assessment idempotency key reused',
      detail = 'ASSESSMENT_INVALID_INPUT';
  end if;
  -- Revalidate session, lifecycle, capability and scope before replay.
  perform app_private.assessment_v2_require_context(
    case when p_command_kind like '%.%' then 'activities.manage' else 'activities.manage' end,
    receipt.institution_id);
  return receipt.result_json || jsonb_build_object('replayed', true);
end $$;

create or replace function app_private.assessment_v2_finish(
  p_ctx app_private.superadmin_internal_context,
  p_request_id uuid,
  p_institution_id uuid,
  p_aggregate_id uuid,
  p_command_kind text,
  p_request_hash bytea,
  p_version bigint,
  p_status text,
  p_reason text default null
) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare result jsonb; correlation uuid := gen_random_uuid(); audit_id uuid;
begin
  result := jsonb_build_object(
    'id', p_aggregate_id, 'version', p_version, 'status', p_status,
    'correlation_id', correlation, 'replayed', false);
  select app_private.audit_append_superadmin_internal(
    p_ctx.internal_identity_id, p_ctx.internal_auth_link_id,
    p_ctx.internal_membership_id, p_ctx.session_id,
    'activities.manage', p_ctx.aal, 'assessment.' || p_command_kind,
    'success', null, correlation, p_institution_id, 'assessment', p_aggregate_id,
    jsonb_build_object('id', p_aggregate_id, 'status', p_status, 'management_version', p_version))
  into audit_id;
  if audit_id is null then raise exception using message = 'assessment audit append failed'; end if;
  insert into app_private.superadmin_internal_assessment_command_receipts(
    request_id, internal_identity_id, institution_id, aggregate_id, command_kind,
    request_hash, resulting_version, resulting_status, result_json, correlation_id)
  values (p_request_id, p_ctx.internal_identity_id, p_institution_id, p_aggregate_id,
    p_command_kind, p_request_hash, p_version, p_status, result, correlation);
  if p_command_kind like 'gradebook.%' then
    insert into app_private.superadmin_internal_assessment_events(
      gradebook_id, internal_identity_id, event_kind, reason, version, correlation_id)
    values (p_aggregate_id, p_ctx.internal_identity_id,
      case p_command_kind
        when 'gradebook.save' then 'saved'
        when 'gradebook.submit' then 'submitted'
        when 'gradebook.review' then 'reviewed'
        when 'gradebook.return' then 'returned'
        when 'gradebook.publish' then 'published'
        else 'scheduled' end,
      nullif(btrim(p_reason), ''), p_version, correlation);
  end if;
  return result;
end $$;

create or replace function app_private.assessment_v2_configuration_snapshot(p_configuration_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'configuration', jsonb_build_object(
      'id', c.id, 'activity_id', c.activity_id, 'institution_id', c.institution_id,
      'unit_id', c.unit_id, 'periodicity', c.periodicity,
      'result_scale_kind', c.result_scale_kind, 'scale_options', c.scale_options,
      'allow_final_override', c.allow_final_override,
      'management_version', c.management_version, 'status', c.status),
    'instruments', coalesce((select jsonb_agg(jsonb_build_object(
      'id', i.id, 'name', i.name, 'weight', i.weight, 'sort_order', i.sort_order)
      order by i.sort_order, i.id) from public.assessment_instruments i
      where i.configuration_id = c.id), '[]'::jsonb),
    'concepts', coalesce((select jsonb_agg(jsonb_build_object(
      'id', s.id, 'code', s.code, 'label', s.label, 'sort_order', s.sort_order)
      order by s.sort_order, s.id) from public.assessment_scale_concepts s
      where s.configuration_id = c.id), '[]'::jsonb),
    'competencies', coalesce((select jsonb_agg(jsonb_build_object(
      'id', x.id, 'name', x.name, 'category', cat.name)
      order by cat.sort_order, x.sort_order, x.id)
      from public.assessment_competencies x
      join public.assessment_categories cat on cat.id = x.category_id
      where x.configuration_id = c.id), '[]'::jsonb),
    'available_competencies', coalesce((select jsonb_agg(jsonb_build_object(
      'id', x.id, 'name', x.name, 'category', cat.name)
      order by cat.sort_order, x.sort_order, x.id)
      from public.assessment_competencies x
      join public.assessment_categories cat on cat.id = x.category_id
      where x.configuration_id = c.id), '[]'::jsonb),
    'periods', coalesce((select jsonb_agg(jsonb_build_object(
      'id', p.id, 'name', p.name, 'ordinal', p.ordinal,
      'academic_year', p.academic_year, 'starts_on', p.starts_on,
      'ends_on', p.ends_on, 'entry_closes_at', p.entry_closes_at,
      'family_release_at', p.family_release_at, 'timezone', p.timezone,
      'status', p.status) order by p.academic_year, p.ordinal, p.id)
      from public.assessment_periods p where p.configuration_id = c.id), '[]'::jsonb))
  from public.activity_assessment_configurations c where c.id = p_configuration_id
$$;

create or replace function app_private.assessment_v2_gradebook_snapshot(p_gradebook_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'gradebook', jsonb_build_object(
      'id', b.id, 'institution_id', b.institution_id,
      'institution_name', i.public_name, 'unit_id', b.unit_id, 'unit_name', u.name,
      'activity_group_link_id', b.activity_group_link_id,
      'group_id', gl.group_id, 'group_name', g.name,
      'activity_id', a.id, 'activity_name', a.name,
      'period_id', p.id, 'period_name', p.name,
      'configuration_id', b.configuration_id, 'status', b.status,
      'management_version', b.management_version,
      'family_release_at', b.family_release_at,
      'publish_scheduled_at', b.publish_scheduled_at,
      'published_at', b.published_at),
    'configuration', app_private.assessment_v2_configuration_snapshot(b.configuration_id),
    'students', b.students_payload,
    'events', coalesce((select jsonb_agg(jsonb_build_object(
      'id', e.id, 'event_kind', e.event_kind, 'actor_person_id', null,
      'reason', coalesce(e.reason, ''), 'version', e.version,
      'created_at', e.created_at) order by e.created_at desc, e.id desc)
      from app_private.superadmin_internal_assessment_events e
      where e.gradebook_id = b.id), '[]'::jsonb))
  from public.assessment_gradebooks b
  join public.activity_group_links gl on gl.id = b.activity_group_link_id
  join public.activity_definitions a on a.id = gl.activity_id
  join public.institutions i on i.id = b.institution_id
  join public.units u on u.id = b.unit_id
  join public.groups g on g.id = gl.group_id
  join public.assessment_periods p on p.id = b.period_id
  where b.id = p_gradebook_id
$$;

create or replace function app_private.assessment_v2_ok(p_data jsonb)
returns jsonb language sql immutable security invoker set search_path = ''
as $$select jsonb_build_object('ok', true, 'data', p_data, 'error', null)$$;

create or replace function app_private.assessment_v2_error(
  p_code text, p_correlation_id uuid
) returns jsonb language sql immutable security invoker set search_path = '' as $$
  select jsonb_build_object('ok', false, 'data', null, 'error', jsonb_build_object(
    'code', case when p_code in (
      'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED','SAI_CONCURRENT_CHANGE','ASSESSMENT_INVALID_INPUT',
      'ASSESSMENT_INVALID_REFERENCE','ASSESSMENT_NOT_FOUND','ASSESSMENT_INVALID_STATE')
      then p_code else 'SAI_INTERNAL_ERROR' end,
    'message', case
      when p_code = 'SAI_AUTH_REQUIRED' then 'Autenticação necessária.'
      when p_code = 'SAI_SESSION_INVALID' then 'Sessão inválida.'
      when p_code = 'SAI_MFA_REQUIRED' then 'Confirmação adicional necessária.'
      when p_code = 'SAI_CONCURRENT_CHANGE' then 'Os dados foram alterados por outra sessão.'
      when p_code = 'ASSESSMENT_INVALID_INPUT' then 'Dados da avaliação inválidos.'
      when p_code = 'ASSESSMENT_INVALID_REFERENCE' then 'Referência da avaliação inválida.'
      when p_code = 'ASSESSMENT_NOT_FOUND' then 'Avaliação não encontrada.'
      when p_code = 'ASSESSMENT_INVALID_STATE' then 'A avaliação não permite esta ação.'
      else 'Acesso negado.' end,
    'http_status', case
      when p_code in ('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
      when p_code in ('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
        'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
      when p_code = 'ASSESSMENT_NOT_FOUND' then 404
      when p_code in ('SAI_CONCURRENT_CHANGE','ASSESSMENT_INVALID_STATE') then 409
      when p_code in ('ASSESSMENT_INVALID_INPUT','ASSESSMENT_INVALID_REFERENCE') then 422
      else 500 end,
    'correlation_id', p_correlation_id))
$$;

create or replace function app_private.assessment_v2_denied(
  p_permission_code text, p_action_code text, p_code text,
  p_correlation_id uuid, p_institution_id uuid default null
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare normalized text := case when coalesce(p_code, '') in (
  'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
  'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
  'SAI_MFA_REQUIRED','SAI_CONCURRENT_CHANGE','ASSESSMENT_INVALID_INPUT',
  'ASSESSMENT_INVALID_REFERENCE','ASSESSMENT_NOT_FOUND','ASSESSMENT_INVALID_STATE')
  then p_code else 'SAI_INTERNAL_ERROR' end;
begin
  perform app_private.audit_superadmin_internal_denial_if_identified(
    p_permission_code, p_action_code, normalized, p_correlation_id, p_institution_id);
  return app_private.assessment_v2_error(normalized, p_correlation_id);
end $$;

create or replace function app_private.assessment_v2_save_configuration(
  request_id uuid, configuration_id uuid, expected_version bigint, payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context; saved public.activity_assessment_configurations%rowtype;
  institution_id uuid; unit_id uuid; activity_id uuid; request_hash bytea; replay jsonb;
  instrument jsonb; concept jsonb; category jsonb; competency jsonb; period jsonb;
  v_category_id uuid; v_competency_id uuid; instrument_total numeric;
begin
  if payload is null or jsonb_typeof(payload) <> 'object'
    or exists (select 1 from jsonb_object_keys(payload) k where k not in (
      'activity_id','institution_id','unit_id','periodicity','result_scale_kind',
      'scale_options','concepts','periods','allow_final_override','instruments','categories'))
    or not (payload ?& array['activity_id','institution_id','periodicity','result_scale_kind',
      'scale_options','periods','allow_final_override','instruments','categories'])
    or jsonb_typeof(payload->'scale_options') <> 'object'
    or jsonb_typeof(payload->'periods') <> 'array'
    or jsonb_typeof(payload->'instruments') <> 'array'
    or jsonb_typeof(payload->'categories') <> 'array'
    or coalesce(jsonb_typeof(payload->'concepts'), 'array') <> 'array'
    or jsonb_array_length(payload->'periods') not between 1 and 12
    or jsonb_array_length(payload->'instruments') not between 1 and 30
    or jsonb_array_length(payload->'categories') > 30 then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;
  begin
    activity_id := (payload->>'activity_id')::uuid;
    institution_id := (payload->>'institution_id')::uuid;
    unit_id := nullif(payload->>'unit_id', '')::uuid;
  exception when others then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
  end;
  select * into strict ctx
  from app_private.assessment_v2_require_context('activities.manage', institution_id);
  if not exists (select 1 from public.activity_definitions a
    where a.id = activity_id and a.institution_id = institution_id
      and a.status in ('draft','active'))
    or (unit_id is not null and not exists (select 1 from public.units u
      where u.id = unit_id and u.institution_id = institution_id and u.status = 'active'))
    or payload->>'periodicity' not in ('bimonthly','trimester','semester','annual')
    or payload->>'result_scale_kind' not in (
      'numeric_0_10','numeric_0_100','concept','numeric_1_5','binary','stars_0_5') then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_REFERENCE';
  end if;
  request_hash := app_private.assessment_v2_hash(jsonb_build_object(
    'configuration_id', configuration_id, 'expected_version', expected_version, 'payload', payload));
  replay := app_private.assessment_v2_replay(ctx, request_id, 'configuration.save', request_hash);
  if replay is not null then return replay; end if;

  if configuration_id is null then
    if expected_version <> 0 then raise serialization_failure using detail = 'SAI_CONCURRENT_CHANGE'; end if;
    insert into public.activity_assessment_configurations(
      activity_id, institution_id, unit_id, periodicity, result_scale_kind,
      scale_options, allow_final_override)
    values (activity_id, institution_id, unit_id, payload->>'periodicity',
      payload->>'result_scale_kind', payload->'scale_options',
      coalesce((payload->>'allow_final_override')::boolean, false))
    returning * into saved;
  else
    select * into saved from public.activity_assessment_configurations c
    where c.id = configuration_id and c.institution_id = institution_id for update;
    if not found then raise no_data_found using detail = 'ASSESSMENT_NOT_FOUND'; end if;
    if saved.management_version <> expected_version then
      raise serialization_failure using detail = 'SAI_CONCURRENT_CHANGE';
    end if;
    if saved.status <> 'draft' or saved.activity_id <> activity_id
      or saved.unit_id is distinct from unit_id then
      raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
    end if;
    update public.activity_assessment_configurations c set
      periodicity = payload->>'periodicity', result_scale_kind = payload->>'result_scale_kind',
      scale_options = payload->'scale_options',
      allow_final_override = coalesce((payload->>'allow_final_override')::boolean, false),
      management_version = c.management_version + 1, updated_at = now()
    where c.id = saved.id returning * into saved;
    delete from public.assessment_instruments where configuration_id = saved.id;
    delete from public.assessment_categories where configuration_id = saved.id;
    delete from public.assessment_scale_concepts where configuration_id = saved.id;
    delete from public.assessment_periods where configuration_id = saved.id;
  end if;

  for instrument in select value from jsonb_array_elements(payload->'instruments') loop
    if jsonb_typeof(instrument) <> 'object'
      or not (instrument ?& array['name','weight','sort_order'])
      or exists (select 1 from jsonb_object_keys(instrument) k
        where k not in ('name','weight','sort_order')) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_instruments(configuration_id, name, weight, sort_order)
    values (saved.id, btrim(instrument->>'name'), (instrument->>'weight')::numeric,
      (instrument->>'sort_order')::integer);
  end loop;
  select sum(i.weight) into instrument_total from public.assessment_instruments i
  where i.configuration_id = saved.id;
  if instrument_total <> 100 then
    raise check_violation using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;

  for concept in select value from jsonb_array_elements(coalesce(payload->'concepts','[]'::jsonb)) loop
    if jsonb_typeof(concept) <> 'object' or not (concept ?& array['code','label','sort_order']) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_scale_concepts(configuration_id, code, label, sort_order)
    values (saved.id, btrim(concept->>'code'), btrim(concept->>'label'),
      (concept->>'sort_order')::integer);
  end loop;
  if saved.result_scale_kind = 'concept'
    and not exists (select 1 from public.assessment_scale_concepts s where s.configuration_id = saved.id) then
    raise check_violation using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;

  for category in select value from jsonb_array_elements(payload->'categories') loop
    if jsonb_typeof(category) <> 'object' or not (category ?& array['name','competencies'])
      or jsonb_typeof(category->'competencies') <> 'array' then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_categories(configuration_id, name, sort_order)
    values (saved.id, btrim(category->>'name'),
      coalesce((category->>'sort_order')::integer,
        (select count(*) from public.assessment_categories c where c.configuration_id = saved.id)))
    returning id into v_category_id;
    for competency in select value from jsonb_array_elements(category->'competencies') loop
      insert into public.assessment_competencies(category_id, configuration_id, name, sort_order)
      values (v_category_id, saved.id, btrim(competency->>'name'),
        coalesce((competency->>'sort_order')::integer, 0))
      returning id into v_competency_id;
      insert into public.assessment_configuration_competencies(configuration_id, competency_id, sort_order)
      values (saved.id, v_competency_id, coalesce((competency->>'sort_order')::integer, 0));
    end loop;
  end loop;

  for period in select value from jsonb_array_elements(payload->'periods') loop
    if jsonb_typeof(period) <> 'object'
      or not (period ?& array['name','ordinal','academic_year','starts_on','ends_on',
        'entry_closes_at','family_release_at']) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    if not exists (select 1 from pg_catalog.pg_timezone_names z
      where z.name = coalesce(nullif(period->>'timezone',''), 'America/Sao_Paulo')) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_periods(
      configuration_id, institution_id, unit_id, name, periodicity, ordinal,
      academic_year, starts_on, ends_on, entry_closes_at, family_release_at,
      timezone, status)
    values (saved.id, saved.institution_id, saved.unit_id, btrim(period->>'name'),
      saved.periodicity, (period->>'ordinal')::smallint, (period->>'academic_year')::integer,
      (period->>'starts_on')::date, (period->>'ends_on')::date,
      (period->>'entry_closes_at')::timestamptz, (period->>'family_release_at')::timestamptz,
      coalesce(nullif(period->>'timezone',''), 'America/Sao_Paulo'), 'draft');
  end loop;
  return app_private.assessment_v2_finish(ctx, request_id, saved.institution_id,
    saved.id, 'configuration.save', request_hash, saved.management_version,
    saved.status, null);
end $$;

create or replace function app_private.assessment_v2_activate_configuration(
  request_id uuid, configuration_id uuid, expected_version bigint
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare ctx app_private.superadmin_internal_context;
  config public.activity_assessment_configurations%rowtype; request_hash bytea; replay jsonb;
begin
  select * into config from public.activity_assessment_configurations c
  where c.id = configuration_id;
  if not found then raise no_data_found using detail = 'ASSESSMENT_NOT_FOUND'; end if;
  select * into strict ctx
  from app_private.assessment_v2_require_context('activities.manage', config.institution_id);
  request_hash := app_private.assessment_v2_hash(jsonb_build_object(
    'configuration_id', configuration_id, 'expected_version', expected_version));
  replay := app_private.assessment_v2_replay(ctx, request_id, 'configuration.activate', request_hash);
  if replay is not null then return replay; end if;
  select * into config from public.activity_assessment_configurations c
  where c.id = configuration_id for update;
  if config.management_version <> expected_version then
    raise serialization_failure using detail = 'SAI_CONCURRENT_CHANGE';
  end if;
  if config.status <> 'draft'
    or (select coalesce(sum(i.weight), 0) from public.assessment_instruments i
      where i.configuration_id = config.id) <> 100
    or not exists (select 1 from public.assessment_periods p where p.configuration_id = config.id) then
    raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
  end if;
  update public.activity_assessment_configurations c set status = 'archived', updated_at = now()
  where c.activity_id = config.activity_id and c.unit_id is not distinct from config.unit_id
    and c.status = 'active';
  update public.activity_assessment_configurations c set status = 'active',
    management_version = c.management_version + 1, updated_at = now()
  where c.id = config.id returning * into config;
  update public.assessment_periods p set status = 'open', updated_at = now()
  where p.configuration_id = config.id;
  return app_private.assessment_v2_finish(ctx, request_id, config.institution_id,
    config.id, 'configuration.activate', request_hash, config.management_version,
    config.status, null);
end $$;

create or replace function app_private.assessment_v2_validate_students(
  p_gradebook public.assessment_gradebooks, p_students jsonb
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare item jsonb; normalized jsonb := '[]'::jsonb; old_item jsonb;
  child_context_id uuid; instrument jsonb; competency jsonb; config record;
begin
  if p_students is null or jsonb_typeof(p_students) <> 'array'
    or jsonb_array_length(p_students) > 500
    or (select count(*) from jsonb_array_elements(p_students)) <>
       (select count(distinct value->>'child_context_id') from jsonb_array_elements(p_students)) then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;
  select c.result_scale_kind, c.scale_options into config
  from public.activity_assessment_configurations c where c.id = p_gradebook.configuration_id;
  for item in select value from jsonb_array_elements(p_students) loop
    if jsonb_typeof(item) <> 'object'
      or not (item ?& array['child_context_id','state','instruments','competencies'])
      or exists (select 1 from jsonb_object_keys(item) k where k not in (
        'child_context_id','state','final_numeric_value','final_concept_code',
        'final_boolean_value','override_reason','family_comment','internal_note',
        'instruments','competencies'))
      or item->>'state' not in ('not_started','pending','complete','absent')
      or jsonb_typeof(item->'instruments') <> 'array'
      or jsonb_typeof(item->'competencies') <> 'array'
      or char_length(coalesce(item->>'override_reason','')) > 500
      or char_length(coalesce(item->>'family_comment','')) > 2000
      or char_length(coalesce(item->>'internal_note','')) > 4000 then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    begin child_context_id := (item->>'child_context_id')::uuid;
    exception when others then raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT'; end;
    if not exists (
      select 1 from public.activity_group_participants participant
      join public.child_group_links child_group
        on child_group.id = participant.child_group_link_id and child_group.status = 'active'
      join public.child_unit_links child_unit
        on child_unit.id = child_group.child_unit_link_id and child_unit.status = 'active'
      join public.child_contexts child_context
        on child_context.id = child_unit.child_context_id and child_context.status = 'active'
      where participant.activity_group_link_id = p_gradebook.activity_group_link_id
        and participant.status = 'active' and participant.removed_at is null
        and child_context.id = child_context_id
        and child_context.institution_id = p_gradebook.institution_id
    ) then raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_REFERENCE'; end if;
    if (select count(*) from jsonb_array_elements(item->'instruments')) <>
       (select count(distinct value->>'instrument_id') from jsonb_array_elements(item->'instruments'))
      or (select count(*) from jsonb_array_elements(item->'competencies')) <>
       (select count(distinct value->>'competency_id') from jsonb_array_elements(item->'competencies')) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    for instrument in select value from jsonb_array_elements(item->'instruments') loop
      if not exists (select 1 from public.assessment_instruments i
        where i.id = (instrument->>'instrument_id')::uuid
          and i.configuration_id = p_gradebook.configuration_id)
        or coalesce((instrument->>'absent')::boolean, false) = false and
          num_nonnulls(instrument->>'numeric_value', instrument->>'concept_code',
            instrument->>'boolean_value') <> 1 then
        raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_REFERENCE';
      end if;
      if config.result_scale_kind = 'numeric_0_10'
        and (instrument->>'numeric_value')::numeric not between 0 and 10
        or config.result_scale_kind = 'numeric_0_100'
        and (instrument->>'numeric_value')::numeric not between 0 and 100
        or config.result_scale_kind in ('numeric_1_5')
        and (instrument->>'numeric_value')::numeric not between 1 and 5
        or config.result_scale_kind = 'stars_0_5'
        and (instrument->>'numeric_value')::numeric not between 0 and 5
        or config.result_scale_kind = 'concept' and not exists (
          select 1 from public.assessment_scale_concepts s
          where s.configuration_id = p_gradebook.configuration_id
            and s.code = instrument->>'concept_code') then
        raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
      end if;
    end loop;
    for competency in select value from jsonb_array_elements(item->'competencies') loop
      if not exists (select 1 from public.assessment_competencies c
        where c.id = (competency->>'competency_id')::uuid
          and c.configuration_id = p_gradebook.configuration_id)
        or (competency->>'score')::numeric not between 0 and 5 then
        raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_REFERENCE';
      end if;
    end loop;
    select value into old_item from jsonb_array_elements(p_gradebook.students_payload)
    where value->>'child_context_id' = child_context_id::text limit 1;
    normalized := normalized || jsonb_build_array(item || jsonb_build_object(
      'id', coalesce(old_item->>'id', gen_random_uuid()::text),
      'name', coalesce(old_item->>'name', (select person.display_name
        from public.child_contexts cc join public.people person on person.id = cc.child_person_id
        where cc.id = child_context_id)),
      'suggested_numeric_value', case
        when item->>'state' = 'absent' then null
        else (select round(sum((entry->>'numeric_value')::numeric * i.weight) /
          nullif(sum(i.weight), 0), 2)
          from jsonb_array_elements(item->'instruments') entry
          join public.assessment_instruments i
            on i.id = (entry->>'instrument_id')::uuid
          where not coalesce((entry->>'absent')::boolean, false)
            and entry->>'numeric_value' is not null) end));
  end loop;
  return normalized;
end $$;

create or replace function app_private.assessment_v2_initial_students(p_activity_group_link_id uuid)
returns jsonb language sql volatile security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', gen_random_uuid(), 'child_context_id', child_context.id,
    'name', person.display_name, 'state', 'not_started',
    'suggested_numeric_value', null, 'final_numeric_value', null,
    'final_concept_code', null, 'final_boolean_value', null,
    'override_reason', '', 'family_comment', '', 'internal_note', '',
    'instruments', '[]'::jsonb, 'competencies', '[]'::jsonb)
    order by person.display_name, child_context.id), '[]'::jsonb)
  from public.activity_group_participants participant
  join public.child_group_links child_group
    on child_group.id = participant.child_group_link_id and child_group.status = 'active'
  join public.child_unit_links child_unit
    on child_unit.id = child_group.child_unit_link_id and child_unit.status = 'active'
  join public.child_contexts child_context
    on child_context.id = child_unit.child_context_id and child_context.status = 'active'
  join public.people person on person.id = child_context.child_person_id and person.status = 'active'
  where participant.activity_group_link_id = p_activity_group_link_id
    and participant.status = 'active' and participant.removed_at is null
$$;

create or replace function app_private.assessment_v2_save_gradebook(
  request_id uuid, gradebook_id uuid, expected_version bigint, payload jsonb, reason text
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare ctx app_private.superadmin_internal_context; book public.assessment_gradebooks%rowtype;
  group_link public.activity_group_links%rowtype; config public.activity_assessment_configurations%rowtype;
  period public.assessment_periods%rowtype; request_hash bytea; replay jsonb; normalized jsonb;
begin
  if payload is null or jsonb_typeof(payload) <> 'object'
    or not (payload ?& array['activity_group_link_id','period_id','configuration_id','students'])
    or exists (select 1 from jsonb_object_keys(payload) k
      where k not in ('activity_group_link_id','period_id','configuration_id','students')) then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;
  request_hash := app_private.assessment_v2_hash(jsonb_build_object(
    'gradebook_id', gradebook_id, 'expected_version', expected_version,
    'payload', payload, 'reason', coalesce(reason, '')));
  if gradebook_id is null then
    begin
      select * into group_link from public.activity_group_links gl
      where gl.id = (payload->>'activity_group_link_id')::uuid and gl.status = 'active';
      select * into config from public.activity_assessment_configurations c
      where c.id = (payload->>'configuration_id')::uuid and c.status = 'active';
      select * into period from public.assessment_periods p
      where p.id = (payload->>'period_id')::uuid and p.status = 'open';
    exception when others then raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT'; end;
    if group_link.id is null or config.id is null or period.id is null
      or group_link.activity_id <> config.activity_id
      or group_link.institution_id <> config.institution_id
      or (config.unit_id is not null and config.unit_id <> group_link.unit_id)
      or period.configuration_id <> config.id
      or period.institution_id <> group_link.institution_id
      or (period.unit_id is not null and period.unit_id <> group_link.unit_id) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_REFERENCE';
    end if;
    select * into strict ctx
    from app_private.assessment_v2_require_context('activities.manage', group_link.institution_id);
    replay := app_private.assessment_v2_replay(ctx, request_id, 'gradebook.save', request_hash);
    if replay is not null then return replay; end if;
    if expected_version <> 0 then raise serialization_failure using detail = 'SAI_CONCURRENT_CHANGE'; end if;
    select * into book from public.assessment_gradebooks b
    where b.activity_group_link_id = group_link.id and b.period_id = period.id for update;
    if not found then
      insert into public.assessment_gradebooks(
        institution_id, unit_id, activity_group_link_id, period_id, configuration_id,
        students_payload, family_release_at)
      values (group_link.institution_id, group_link.unit_id, group_link.id, period.id,
        config.id, app_private.assessment_v2_initial_students(group_link.id), period.family_release_at)
      returning * into book;
    end if;
  else
    select * into book from public.assessment_gradebooks b where b.id = gradebook_id;
    if not found then raise no_data_found using detail = 'ASSESSMENT_NOT_FOUND'; end if;
    select * into strict ctx
    from app_private.assessment_v2_require_context('activities.manage', book.institution_id);
    replay := app_private.assessment_v2_replay(ctx, request_id, 'gradebook.save', request_hash);
    if replay is not null then return replay; end if;
    select * into book from public.assessment_gradebooks b where b.id = gradebook_id for update;
    if book.management_version <> expected_version then
      raise serialization_failure using detail = 'SAI_CONCURRENT_CHANGE';
    end if;
    if book.status <> 'draft' then raise check_violation using detail = 'ASSESSMENT_INVALID_STATE'; end if;
    if (payload->>'activity_group_link_id')::uuid <> book.activity_group_link_id
      or (payload->>'period_id')::uuid <> book.period_id
      or (payload->>'configuration_id')::uuid <> book.configuration_id then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_REFERENCE';
    end if;
    normalized := app_private.assessment_v2_validate_students(book, payload->'students');
    update public.assessment_gradebooks b set students_payload = normalized,
      management_version = b.management_version + 1, updated_at = now()
    where b.id = book.id returning * into book;
  end if;
  return app_private.assessment_v2_finish(ctx, request_id, book.institution_id,
    book.id, 'gradebook.save', request_hash, book.management_version,
    book.status, reason);
end $$;

create or replace function app_private.assessment_v2_transition_gradebook(
  request_id uuid, gradebook_id uuid, expected_version bigint,
  target_status text, command_kind text, reason text, publish_at timestamptz default null
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare ctx app_private.superadmin_internal_context; book public.assessment_gradebooks%rowtype;
  request_hash bytea; replay jsonb;
begin
  select * into book from public.assessment_gradebooks b where b.id = gradebook_id;
  if not found then raise no_data_found using detail = 'ASSESSMENT_NOT_FOUND'; end if;
  select * into strict ctx
  from app_private.assessment_v2_require_context('activities.manage', book.institution_id);
  request_hash := app_private.assessment_v2_hash(jsonb_build_object(
    'gradebook_id', gradebook_id, 'expected_version', expected_version,
    'target_status', target_status, 'command_kind', command_kind,
    'reason', coalesce(reason, ''), 'publish_at', publish_at));
  replay := app_private.assessment_v2_replay(ctx, request_id, command_kind, request_hash);
  if replay is not null then return replay; end if;
  select * into book from public.assessment_gradebooks b where b.id = gradebook_id for update;
  if book.management_version <> expected_version then
    raise serialization_failure using detail = 'SAI_CONCURRENT_CHANGE';
  end if;
  if command_kind = 'gradebook.submit' and (book.status <> 'draft'
      or exists (select 1 from jsonb_array_elements(book.students_payload) student
        where student->>'state' not in ('complete','absent'))) then
    raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
  elsif command_kind = 'gradebook.review' and book.status <> 'submitted' then
    raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
  elsif command_kind = 'gradebook.return' and book.status not in ('submitted','reviewed') then
    raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
  elsif command_kind = 'gradebook.publish' and book.status <> 'reviewed' then
    raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
  elsif command_kind = 'gradebook.schedule' and (book.status <> 'reviewed'
      or publish_at is null or publish_at <= now()) then
    raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
  end if;
  update public.assessment_gradebooks b set
    status = target_status,
    management_version = b.management_version + 1,
    submitted_at = case when command_kind = 'gradebook.submit' then now() else b.submitted_at end,
    reviewed_at = case when command_kind = 'gradebook.review' then now() else b.reviewed_at end,
    published_at = case when command_kind = 'gradebook.publish' then now() else b.published_at end,
    publish_scheduled_at = case when command_kind = 'gradebook.schedule' then publish_at
      when command_kind in ('gradebook.return','gradebook.publish') then null
      else b.publish_scheduled_at end,
    updated_at = now()
  where b.id = book.id returning * into book;
  return app_private.assessment_v2_finish(ctx, request_id, book.institution_id,
    book.id, command_kind, request_hash, book.management_version, book.status, reason);
end $$;

create or replace function public.superadmin_assessment_context_options()
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid();
  result jsonb; code text;
begin
  begin
    select * into strict ctx from app_private.assessment_v2_require_context('activities.read', null);
    select jsonb_build_object(
      'assignments', coalesce(jsonb_agg(jsonb_build_object(
        'activity_group_link_id', gl.id, 'institution_id', gl.institution_id,
        'institution_name', institution.public_name, 'unit_id', gl.unit_id,
        'unit_name', unit_record.name, 'group_id', gl.group_id,
        'group_name', group_record.name, 'activity_id', activity.id,
        'activity_name', activity.name, 'period_id', null, 'period_name', null)
        order by institution.public_name, unit_record.name, group_record.name, activity.name)
        filter (where gl.id is not null), '[]'::jsonb)
    into result
    from public.activity_group_links gl
    join public.activity_definitions activity on activity.id = gl.activity_id
    join public.institutions institution on institution.id = gl.institution_id
    join public.units unit_record on unit_record.id = gl.unit_id
    join public.groups group_record on group_record.id = gl.group_id
    where gl.status = 'active' and activity.status = 'active'
      and (ctx.scope_kind <> 'institution' or gl.institution_id = ctx.scope_institution_id);
    result := result || jsonb_build_object('periods', coalesce((select jsonb_agg(
      jsonb_build_object('id', p.id, 'name', p.name, 'status', p.status,
        'institution_id', p.institution_id, 'unit_id', p.unit_id)
      order by p.academic_year, p.ordinal, p.id)
      from public.assessment_periods p
      where p.status in ('open','closed')
        and (ctx.scope_kind <> 'institution' or p.institution_id = ctx.scope_institution_id)), '[]'::jsonb));
    return app_private.assessment_v2_ok(result);
  exception when others then get stacked diagnostics code = pg_exception_detail; end;
  return app_private.assessment_v2_denied('activities.read', 'assessment.context_options',
    coalesce(nullif(code,''), 'SAI_INTERNAL_ERROR'), correlation, null);
end $$;

create or replace function public.superadmin_assessment_configuration_read(
  target_activity uuid, target_unit uuid default null
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid();
  institution_id uuid; configuration_id uuid; result jsonb; code text;
begin
  begin
    select * into strict ctx from app_private.assessment_v2_require_context('activities.read', null);
    select a.institution_id into institution_id from public.activity_definitions a
    where a.id = target_activity
      and (ctx.scope_kind <> 'institution' or a.institution_id = ctx.scope_institution_id);
    if institution_id is null then return app_private.assessment_v2_ok(null); end if;
    select * into strict ctx
    from app_private.assessment_v2_require_context('activities.read', institution_id);
    if target_unit is not null and not exists (select 1 from public.units u
      where u.id = target_unit and u.institution_id = institution_id) then
      return app_private.assessment_v2_ok(null);
    end if;
    select c.id into configuration_id
    from public.activity_assessment_configurations c
    where c.activity_id = target_activity and c.institution_id = institution_id
      and c.unit_id is not distinct from target_unit and c.status in ('active','draft')
    order by (c.status = 'active') desc, c.version desc, c.created_at desc limit 1;
    result := case when configuration_id is null then null
      else app_private.assessment_v2_configuration_snapshot(configuration_id) end;
    return app_private.assessment_v2_ok(result);
  exception when others then get stacked diagnostics code = pg_exception_detail; end;
  return app_private.assessment_v2_denied('activities.read', 'assessment.configuration.read',
    coalesce(nullif(code,''), 'SAI_INTERNAL_ERROR'), correlation, institution_id);
end $$;

create or replace function public.superadmin_assessment_gradebook_read(target_gradebook uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid();
  institution_id uuid; result jsonb; code text;
begin
  begin
    select * into strict ctx from app_private.assessment_v2_require_context('activities.read', null);
    select b.institution_id into institution_id from public.assessment_gradebooks b
    where b.id = target_gradebook
      and (ctx.scope_kind <> 'institution' or b.institution_id = ctx.scope_institution_id);
    if institution_id is null then return app_private.assessment_v2_ok(null); end if;
    select * into strict ctx
    from app_private.assessment_v2_require_context('activities.read', institution_id);
    result := app_private.assessment_v2_gradebook_snapshot(target_gradebook);
    return app_private.assessment_v2_ok(result);
  exception when others then get stacked diagnostics code = pg_exception_detail; end;
  return app_private.assessment_v2_denied('activities.read', 'assessment.gradebook.read',
    coalesce(nullif(code,''), 'SAI_INTERNAL_ERROR'), correlation, institution_id);
end $$;

create or replace function public.superadmin_assessment_closing_queue()
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid();
  result jsonb; code text;
begin
  begin
    select * into strict ctx from app_private.assessment_v2_require_context('activities.read', null);
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', b.id, 'status', b.status, 'version', b.management_version,
      'institution_name', institution.public_name, 'unit_name', unit_record.name,
      'group_name', group_record.name, 'activity_name', activity.name,
      'period_name', period.name,
      'pending_count', (select count(*) from jsonb_array_elements(b.students_payload) student
        where student->>'state' in ('not_started','pending')))
      order by b.updated_at desc, b.id desc), '[]'::jsonb) into result
    from public.assessment_gradebooks b
    join public.activity_group_links gl on gl.id = b.activity_group_link_id
    join public.activity_definitions activity on activity.id = gl.activity_id
    join public.institutions institution on institution.id = b.institution_id
    join public.units unit_record on unit_record.id = b.unit_id
    join public.groups group_record on group_record.id = gl.group_id
    join public.assessment_periods period on period.id = b.period_id
    where b.status <> 'published'
      and (ctx.scope_kind <> 'institution' or b.institution_id = ctx.scope_institution_id);
    return app_private.assessment_v2_ok(result);
  exception when others then get stacked diagnostics code = pg_exception_detail; end;
  return app_private.assessment_v2_denied('activities.read', 'assessment.closing.queue',
    coalesce(nullif(code,''), 'SAI_INTERNAL_ERROR'), correlation, null);
end $$;

create or replace function public.superadmin_assessment_save_configuration(
  request_id uuid, configuration_id uuid, expected_version bigint, payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare correlation uuid := gen_random_uuid(); result jsonb; code text; institution_id uuid;
begin
  begin
    begin institution_id := (payload->>'institution_id')::uuid; exception when others then institution_id := null; end;
    result := app_private.assessment_v2_save_configuration(
      request_id, configuration_id, expected_version, payload);
    return app_private.assessment_v2_ok(result);
  exception when others then get stacked diagnostics code = pg_exception_detail; end;
  return app_private.assessment_v2_denied('activities.manage', 'assessment.configuration.save',
    coalesce(nullif(code,''), 'SAI_INTERNAL_ERROR'), correlation, institution_id);
end $$;

create or replace function public.superadmin_assessment_activate_configuration(
  request_id uuid, configuration_id uuid, expected_version bigint
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare correlation uuid := gen_random_uuid(); result jsonb; code text; institution_id uuid;
begin
  begin
    select c.institution_id into institution_id from public.activity_assessment_configurations c
    where c.id = configuration_id;
    result := app_private.assessment_v2_activate_configuration(
      request_id, configuration_id, expected_version);
    return app_private.assessment_v2_ok(result);
  exception when others then get stacked diagnostics code = pg_exception_detail; end;
  return app_private.assessment_v2_denied('activities.manage', 'assessment.configuration.activate',
    coalesce(nullif(code,''), 'SAI_INTERNAL_ERROR'), correlation, institution_id);
end $$;

create or replace function public.superadmin_assessment_save_gradebook(
  request_id uuid, gradebook_id uuid, expected_version bigint, payload jsonb, reason text
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare correlation uuid := gen_random_uuid(); result jsonb; code text; institution_id uuid;
begin
  begin
    select b.institution_id into institution_id from public.assessment_gradebooks b where b.id = gradebook_id;
    if institution_id is null then select gl.institution_id into institution_id
      from public.activity_group_links gl where gl.id = (payload->>'activity_group_link_id')::uuid; end if;
    result := app_private.assessment_v2_save_gradebook(
      request_id, gradebook_id, expected_version, payload, reason);
    return app_private.assessment_v2_ok(result);
  exception when others then get stacked diagnostics code = pg_exception_detail; end;
  return app_private.assessment_v2_denied('activities.manage', 'assessment.gradebook.save',
    coalesce(nullif(code,''), 'SAI_INTERNAL_ERROR'), correlation, institution_id);
end $$;

create or replace function public.superadmin_assessment_submit_gradebook(
  request_id uuid, gradebook_id uuid, expected_version bigint, reason text
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare correlation uuid := gen_random_uuid(); result jsonb; code text; institution_id uuid;
begin begin
  select b.institution_id into institution_id from public.assessment_gradebooks b where b.id = gradebook_id;
  result := app_private.assessment_v2_transition_gradebook(request_id, gradebook_id,
    expected_version, 'submitted', 'gradebook.submit', reason, null);
  return app_private.assessment_v2_ok(result);
exception when others then get stacked diagnostics code = pg_exception_detail; end;
return app_private.assessment_v2_denied('activities.manage', 'assessment.gradebook.submit',
  coalesce(nullif(code,''), 'SAI_INTERNAL_ERROR'), correlation, institution_id); end $$;

create or replace function public.superadmin_assessment_review_gradebook(
  request_id uuid, gradebook_id uuid, expected_version bigint, reason text
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare correlation uuid := gen_random_uuid(); result jsonb; code text; institution_id uuid;
begin begin
  select b.institution_id into institution_id from public.assessment_gradebooks b where b.id = gradebook_id;
  result := app_private.assessment_v2_transition_gradebook(request_id, gradebook_id,
    expected_version, 'reviewed', 'gradebook.review', reason, null);
  return app_private.assessment_v2_ok(result);
exception when others then get stacked diagnostics code = pg_exception_detail; end;
return app_private.assessment_v2_denied('activities.manage', 'assessment.gradebook.review',
  coalesce(nullif(code,''), 'SAI_INTERNAL_ERROR'), correlation, institution_id); end $$;

create or replace function public.superadmin_assessment_return_gradebook(
  request_id uuid, gradebook_id uuid, expected_version bigint, reason text
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare correlation uuid := gen_random_uuid(); result jsonb; code text; institution_id uuid;
begin begin
  select b.institution_id into institution_id from public.assessment_gradebooks b where b.id = gradebook_id;
  result := app_private.assessment_v2_transition_gradebook(request_id, gradebook_id,
    expected_version, 'draft', 'gradebook.return', reason, null);
  return app_private.assessment_v2_ok(result);
exception when others then get stacked diagnostics code = pg_exception_detail; end;
return app_private.assessment_v2_denied('activities.manage', 'assessment.gradebook.return',
  coalesce(nullif(code,''), 'SAI_INTERNAL_ERROR'), correlation, institution_id); end $$;

create or replace function public.superadmin_assessment_publish_gradebook(
  request_id uuid, gradebook_id uuid, expected_version bigint, reason text
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare correlation uuid := gen_random_uuid(); result jsonb; code text; institution_id uuid;
begin begin
  select b.institution_id into institution_id from public.assessment_gradebooks b where b.id = gradebook_id;
  result := app_private.assessment_v2_transition_gradebook(request_id, gradebook_id,
    expected_version, 'published', 'gradebook.publish', reason, null);
  return app_private.assessment_v2_ok(result);
exception when others then get stacked diagnostics code = pg_exception_detail; end;
return app_private.assessment_v2_denied('activities.manage', 'assessment.gradebook.publish',
  coalesce(nullif(code,''), 'SAI_INTERNAL_ERROR'), correlation, institution_id); end $$;

create or replace function public.superadmin_assessment_schedule_publication(
  request_id uuid, gradebook_id uuid, expected_version bigint, publish_at timestamptz, reason text
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare correlation uuid := gen_random_uuid(); result jsonb; code text; institution_id uuid;
begin begin
  select b.institution_id into institution_id from public.assessment_gradebooks b where b.id = gradebook_id;
  result := app_private.assessment_v2_transition_gradebook(request_id, gradebook_id,
    expected_version, 'reviewed', 'gradebook.schedule', reason, publish_at);
  return app_private.assessment_v2_ok(result);
exception when others then get stacked diagnostics code = pg_exception_detail; end;
return app_private.assessment_v2_denied('activities.manage', 'assessment.gradebook.schedule',
  coalesce(nullif(code,''), 'SAI_INTERNAL_ERROR'), correlation, institution_id); end $$;

do $$ declare table_name text; begin
  foreach table_name in array array[
    'activity_assessment_configurations','assessment_instruments','assessment_categories',
    'assessment_competencies','assessment_configuration_competencies',
    'assessment_scale_concepts','assessment_periods','assessment_gradebooks']
  loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
    execute format('revoke all on table public.%I from public,anon,authenticated,service_role', table_name);
  end loop;
end $$;

alter table app_private.superadmin_internal_assessment_command_receipts enable row level security;
alter table app_private.superadmin_internal_assessment_command_receipts force row level security;
alter table app_private.superadmin_internal_assessment_events enable row level security;
alter table app_private.superadmin_internal_assessment_events force row level security;
revoke all on table app_private.superadmin_internal_assessment_command_receipts
  from public,anon,authenticated,service_role;
revoke all on table app_private.superadmin_internal_assessment_events
  from public,anon,authenticated,service_role;

do $$ declare proc regprocedure; begin
  for proc in select p.oid::regprocedure from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app_private' and p.proname like 'assessment_v2_%'
  loop
    execute format('alter function %s owner to postgres', proc);
    execute format('revoke all on function %s from public,anon,authenticated,service_role', proc);
  end loop;
  for proc in select p.oid::regprocedure from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'superadmin_assessment_%'
  loop
    execute format('alter function %s owner to postgres', proc);
    execute format('revoke all on function %s from public,anon,authenticated,service_role', proc);
    execute format('grant execute on function %s to authenticated', proc);
  end loop;
end $$;

commit;
