-- Candidato de estrutura (R04, 11/09/2026): recarimbo de 20260909165000 sobre a
-- baseline de producao. Duas mudancas: o preflight exige a assinatura REAL de
-- app_private.audit_append_superadmin_internal em producao (13 argumentos, sem o
-- jsonb final que so existia nos gateways historicos de Atividades v2) e a
-- auditoria do override deixa de passar o metadado jsonb; o reason_code
-- RESERVATION_CONFLICT_OVERRIDE ja carrega o fato. Sem mudanca de regra.
-- Historico original abaixo.
-- D02 LOCAL CANDIDATE, reserved by D00 r15. Never applied remotely by this file.
-- Source: approved 2026-09-02-superadmin-locais-mapas-agendamentos-design.md;
-- R02 ADENDO-LOCAIS. LOC01..04 are prerequisites, not included implicitly.
-- Once/weekly, independent owner policy, block/warn + explicit override,
-- audited cancellation and stable request receipts implement the approved rules.
-- Event/form consumers and atomic group/activity save integration remain separate
-- contracts. No fake consumers, default policy, capability grants or media store.
-- Bounds (1000 occurrences, 3660 calendar days, 31-day single interval) are
-- defensive protocol limits, not new product entitlements.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
set local search_path=public,pg_catalog;

do $preflight$
declare capability text;
begin
  if current_user<>'postgres' then raise insufficient_privilege; end if;
  if to_regprocedure('app_private.superadmin_location_locked_v2(app_private.superadmin_internal_context,uuid)') is null
    or to_regprocedure('public.superadmin_location_schedule_set_v2(uuid,jsonb,bigint,uuid)') is null
    or to_regprocedure('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)') is null
    or to_regclass('public.activity_definitions') is null
    or to_regclass('public.groups') is null then
    raise object_not_in_prerequisite_state using message='reservation prerequisites missing';
  end if;
  if to_regclass('public.location_reservations') is not null
    or to_regclass('public.location_reservation_occurrences') is not null
    or to_regclass('public.location_bindings') is not null
    or to_regclass('public.location_scheduling_policies') is not null
    or to_regclass('app_private.location_reservation_receipts') is not null then
    raise duplicate_object using message='reservation object collision';
  end if;
  foreach capability in array array['locations.reservations.read',
      'locations.reservations.manage','locations.reservations.override'] loop
    if not exists(select 1 from public.platform_permissions where code=capability and status='active')
      or (select array_agg(r.code order by r.code) from public.platform_role_permissions rp
        join public.platform_roles r on r.id=rp.role_id and r.status='active'
        join public.platform_permissions p on p.id=rp.permission_id
        where p.code=capability and rp.effect='allow' and rp.status='active' and rp.revoked_at is null)
        is distinct from array['owner']::text[] then
      raise object_not_in_prerequisite_state using message='reviewed Owner-only reservation capability provisioning required';
    end if;
  end loop;
end
$preflight$;

create table public.location_scheduling_policies(
  scope_kind text not null check(scope_kind in('institution','unit')),
  owner_id uuid not null,
  institution_id uuid not null references public.institutions(id) on delete restrict,
  unit_id uuid references public.units(id) on delete restrict,
  policy text not null check(policy in('block','warn')),
  management_version bigint not null default 1 check(management_version>0),
  updated_at timestamptz not null default now(),
  updated_by_internal_identity_id uuid not null references app_private.superadmin_internal_identities(id),
  primary key(scope_kind,owner_id),
  check((scope_kind='institution' and owner_id=institution_id and unit_id is null)
    or (scope_kind='unit' and owner_id=unit_id and unit_id is not null))
);
create table public.location_bindings(
  location_id uuid not null references public.activity_locations(id) on delete restrict,
  consumer_kind text not null check(consumer_kind in('group','activity')),
  consumer_id uuid not null,
  group_id uuid references public.groups(id) on delete restrict,
  activity_id uuid references public.activity_definitions(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key(location_id,consumer_kind,consumer_id),
  check((consumer_kind='group' and group_id=consumer_id and group_id is not null and activity_id is null)
    or (consumer_kind='activity' and activity_id=consumer_id and activity_id is not null and group_id is null))
);
create index location_bindings_group_idx on public.location_bindings(group_id) where group_id is not null;
create index location_bindings_activity_idx on public.location_bindings(activity_id) where activity_id is not null;
create table public.location_reservations(
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null,
  consumer_kind text not null,
  consumer_id uuid not null,
  recurrence jsonb not null check(jsonb_typeof(recurrence)='object'),
  state text not null default 'active' check(state in('active','cancelled')),
  confirmed_over_conflict boolean not null default false,
  conflict_justification text,
  management_version bigint not null default 1 check(management_version>0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  actor_internal_identity_id uuid not null references app_private.superadmin_internal_identities(id),
  foreign key(location_id,consumer_kind,consumer_id)
    references public.location_bindings(location_id,consumer_kind,consumer_id) on delete restrict,
  check((not confirmed_over_conflict and conflict_justification is null)
    or (confirmed_over_conflict and conflict_justification is not null
      and length(btrim(conflict_justification)) between 1 and 1000))
);
create index location_reservations_binding_idx on public.location_reservations(location_id,consumer_kind,consumer_id);
create index location_reservations_actor_idx on public.location_reservations(actor_internal_identity_id);
create table public.location_reservation_occurrences(
  reservation_id uuid not null references public.location_reservations(id) on delete restrict,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  primary key(reservation_id,starts_at),
  check(isfinite(starts_at) and isfinite(ends_at) and starts_at<ends_at)
);
create index location_reservation_occurrences_range_idx
  on public.location_reservation_occurrences using gist(tstzrange(starts_at,ends_at,'[)'));
create table app_private.location_reservation_receipts(
  actor_id uuid not null references app_private.superadmin_internal_identities(id),
  request_id uuid not null,
  operation text not null check(operation in('create','cancel','policy_set')),
  request_hash bytea not null,
  location_id uuid not null references public.activity_locations(id),
  reservation_id uuid references public.location_reservations(id),
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key(actor_id,request_id)
);
create index location_reservation_receipts_location_idx on app_private.location_reservation_receipts(location_id);
create index location_reservation_receipts_reservation_idx on app_private.location_reservation_receipts(reservation_id);

alter table public.location_scheduling_policies enable row level security;
alter table public.location_scheduling_policies force row level security;
alter table public.location_bindings enable row level security;
alter table public.location_bindings force row level security;
alter table public.location_reservations enable row level security;
alter table public.location_reservations force row level security;
alter table public.location_reservation_occurrences enable row level security;
alter table public.location_reservation_occurrences force row level security;
alter table app_private.location_reservation_receipts enable row level security;
alter table app_private.location_reservation_receipts force row level security;
revoke all on public.location_scheduling_policies,public.location_bindings,
  public.location_reservations,public.location_reservation_occurrences,
  app_private.location_reservation_receipts from public,anon,authenticated,service_role;

create function app_private.location_reservation_normalize_v2(p_payload jsonb)
returns jsonb language plpgsql stable security invoker set search_path=''
as $$
declare first_start timestamptz; first_end timestamptz; recurrence jsonb;
  zone text; days integer[]; until_date date; first_date date; day_date date;
  local_start timestamp; local_end timestamp; occurrence_start timestamptz;
  occurrence_end timestamptz; occurrences jsonb:='[]'; justification text;
  wall_start timestamp; wall_end timestamp; probe interval; candidate timestamptz;
begin
  if p_payload is null or jsonb_typeof(p_payload)<>'object'
    or not(p_payload ?& array['location_id','consumer','first_occurrence','recurrence','conflict_justification'])
    or (select count(*) from jsonb_object_keys(p_payload))<>5
    or jsonb_typeof(p_payload->'consumer')<>'object'
    or not(p_payload->'consumer' ?& array['kind','id'])
    or (select count(*) from jsonb_object_keys(p_payload->'consumer'))<>2
    or coalesce(p_payload#>>'{consumer,kind}','') not in('group','activity')
    or jsonb_typeof(p_payload->'first_occurrence')<>'object'
    or not(p_payload->'first_occurrence' ?& array['starts_at','ends_at'])
    or (select count(*) from jsonb_object_keys(p_payload->'first_occurrence'))<>2
    or jsonb_typeof(p_payload->'recurrence')<>'object'
    or jsonb_typeof(p_payload->'location_id')<>'string'
    or jsonb_typeof(p_payload#>'{consumer,id}')<>'string'
    or (p_payload->>'location_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    or (p_payload#>>'{consumer,id}') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    or coalesce(p_payload#>>'{first_occurrence,starts_at}','') !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|\+00:00)$'
    or coalesce(p_payload#>>'{first_occurrence,ends_at}','') !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|\+00:00)$' then
    raise invalid_parameter_value using message='invalid reservation request';
  end if;
  first_start:=(p_payload#>>'{first_occurrence,starts_at}')::timestamptz;
  first_end:=(p_payload#>>'{first_occurrence,ends_at}')::timestamptz;
  if not isfinite(first_start) or not isfinite(first_end) or first_end<=first_start
    or first_end-first_start>interval '31 days' then
    raise invalid_parameter_value using message='invalid reservation interval';
  end if;
  if jsonb_typeof(p_payload->'conflict_justification') not in('null','string') then
    raise invalid_parameter_value using message='invalid conflict justification';
  end if;
  justification:=nullif(btrim(p_payload->>'conflict_justification'),'');
  if length(justification)>1000 then raise invalid_parameter_value using message='conflict justification too long'; end if;
  recurrence:=p_payload->'recurrence';
  if recurrence->>'kind'='once' then
    if (select count(*) from jsonb_object_keys(recurrence))<>1 then
      raise invalid_parameter_value using message='invalid once recurrence';
    end if;
    occurrences:=jsonb_build_array(jsonb_build_object('starts_at',first_start,'ends_at',first_end));
  elsif recurrence->>'kind'='weekly' then
    if not(recurrence ?& array['kind','weekdays','until','time_zone'])
      or (select count(*) from jsonb_object_keys(recurrence))<>4
      or jsonb_typeof(recurrence->'weekdays')<>'array'
      or jsonb_array_length(recurrence->'weekdays') not between 1 and 7
      or coalesce(recurrence->>'until','') !~ '^\d{4}-\d{2}-\d{2}$'
      or jsonb_typeof(recurrence->'time_zone')<>'string' then
      raise invalid_parameter_value using message='invalid weekly recurrence';
    end if;
    if exists(select 1 from jsonb_array_elements(recurrence->'weekdays') item
      where jsonb_typeof(item)<>'number' or item::text !~ '^[0-6]$') then
      raise invalid_parameter_value using message='invalid recurrence weekday';
    end if;
    select array_agg(value::integer order by value::integer) into days
      from jsonb_array_elements_text(recurrence->'weekdays');
    if cardinality(days)<>(select count(distinct x) from unnest(days) x) then
      raise invalid_parameter_value using message='duplicate recurrence weekday';
    end if;
    zone:=recurrence->>'time_zone';
    if length(zone)>100 or zone like 'posix/%' or zone like 'right/%'
      or not exists(select 1 from pg_catalog.pg_timezone_names where name=zone) then
      raise invalid_parameter_value using message='unknown reservation timezone';
    end if;
    until_date:=(recurrence->>'until')::date;
    local_start:=first_start at time zone zone;
    local_end:=first_end at time zone zone;
    first_date:=local_start::date;
    if until_date<first_date or until_date-first_date>3660
      or not(extract(dow from first_date)::integer=any(days)) then
      raise invalid_parameter_value using message='invalid recurrence calendar bounds';
    end if;
    for day_date in select first_date+i from generate_series(0,until_date-first_date) i loop
      if extract(dow from day_date)::integer=any(days) then
        -- Preserve wall-clock start/end in the explicit named zone, including
        -- midnight crossings. Refuse nonexistent DST wall times; never shift silently.
        wall_start:=local_start+(day_date-first_date)*interval '1 day';
        wall_end:=local_end+(day_date-first_date)*interval '1 day';
        occurrence_start:=wall_start at time zone zone;
        occurrence_end:=wall_end at time zone zone;
        if occurrence_start at time zone zone <> wall_start
          or occurrence_end at time zone zone <> wall_end
          or occurrence_end<=occurrence_start then
          raise invalid_parameter_value using message='recurrence contains an invalid local time';
        end if;
        if day_date=first_date then
          occurrence_start:=first_start; occurrence_end:=first_end;
        else
          -- A fold has two instants for the same wall clock. No product rule
          -- chose one for generated dates: refuse instead of silently choosing
          -- PostgreSQL's default offset. Probe the offsets on both sides.
          foreach probe in array array[interval '-2 days',interval '2 days'] loop
            candidate:=(wall_start-(((occurrence_start+probe) at time zone zone)
              -((occurrence_start+probe) at time zone 'UTC'))) at time zone 'UTC';
            if candidate<>occurrence_start and candidate at time zone zone=wall_start then
              raise invalid_parameter_value using message='recurrence contains an ambiguous local time';
            end if;
            candidate:=(wall_end-(((occurrence_end+probe) at time zone zone)
              -((occurrence_end+probe) at time zone 'UTC'))) at time zone 'UTC';
            if candidate<>occurrence_end and candidate at time zone zone=wall_end then
              raise invalid_parameter_value using message='recurrence contains an ambiguous local time';
            end if;
          end loop;
        end if;
        occurrences:=occurrences||jsonb_build_array(jsonb_build_object('starts_at',occurrence_start,'ends_at',occurrence_end));
        if jsonb_array_length(occurrences)>1000 then
          raise invalid_parameter_value using message='too many reservation occurrences';
        end if;
      end if;
    end loop;
    if exists(select 1 from (
      select (value->>'starts_at')::timestamptz starts_at,
        lag((value->>'ends_at')::timestamptz) over(order by (value->>'starts_at')::timestamptz) previous_end
      from jsonb_array_elements(occurrences)) x where starts_at<previous_end) then
      raise invalid_parameter_value using message='recurrence overlaps itself';
    end if;
    recurrence:=recurrence||jsonb_build_object('weekdays',to_jsonb(days));
  else raise invalid_parameter_value using message='unsupported reservation recurrence';
  end if;
  return jsonb_build_object('location_id',(p_payload->>'location_id')::uuid,
    'consumer',jsonb_build_object('kind',p_payload#>>'{consumer,kind}','id',(p_payload#>>'{consumer,id}')::uuid),
    'recurrence',recurrence,'occurrences',occurrences,'conflict_justification',justification);
exception when invalid_text_representation or datetime_field_overflow or invalid_datetime_format or numeric_value_out_of_range then
  raise invalid_parameter_value using message='invalid reservation request';
end
$$;

create function app_private.location_reservation_consumer_v2(
  p_context app_private.superadmin_internal_context,p_location public.activity_locations,
  p_consumer jsonb,p_write boolean
) returns void language plpgsql volatile security definer set search_path=''
as $$
declare consumer_id uuid; capability text; consumer_ctx app_private.superadmin_internal_context;
begin
  if p_consumer is null or jsonb_typeof(p_consumer)<>'object'
    or not(p_consumer ?& array['kind','id'])
    or (select count(*) from jsonb_object_keys(p_consumer))<>2
    or coalesce(p_consumer->>'kind','') not in('group','activity')
    or jsonb_typeof(p_consumer->'id')<>'string'
    or coalesce(p_consumer->>'id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    raise invalid_parameter_value using message='unsupported reservation consumer';
  end if;
  consumer_id:=(p_consumer->>'id')::uuid;
  capability:=case when p_consumer->>'kind'='group' then
    case when p_write then 'groups.manage' else 'groups.read' end else
    case when p_write then 'activities.manage' else 'activities.read' end end;
  select * into strict consumer_ctx from app_private.require_superadmin_internal_context(capability);
  if consumer_ctx.internal_identity_id is distinct from p_context.internal_identity_id
    or consumer_ctx.session_id is distinct from p_context.session_id then
    raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
  end if;
  if p_consumer->>'kind'='group' then
    perform 1 from public.groups g where g.id=consumer_id
      and g.institution_id=p_location.institution_id and g.status<>'archived'
      and (p_location.scope_kind='institution' or g.unit_id=p_location.unit_id) for share;
    if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
  else
    perform 1 from public.activity_definitions a where a.id=consumer_id
      and a.institution_id=p_location.institution_id and a.status<>'archived' for share;
    if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    if p_location.scope_kind='unit' then
      perform 1 from public.activity_unit_links link where link.activity_id=consumer_id
        and link.institution_id=p_location.institution_id and link.unit_id=p_location.unit_id
        and link.status='active' and link.starts_at<=clock_timestamp()
        and (link.ends_at is null or link.ends_at>clock_timestamp()) for share;
      if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    end if;
  end if;
end
$$;

create function app_private.location_reservation_payload_v2(p_id uuid)
returns jsonb language sql stable security definer set search_path='' set timezone='UTC'
as $$
  select jsonb_build_object('id',r.id,'location_id',r.location_id,
    'consumer',jsonb_build_object('kind',r.consumer_kind,'id',r.consumer_id),
    'state',r.state,'recurrence',r.recurrence,'management_version',r.management_version,
    'confirmed_over_conflict',r.confirmed_over_conflict,
    'occurrences',(select jsonb_agg(jsonb_build_object('starts_at',o.starts_at,'ends_at',o.ends_at) order by o.starts_at)
      from public.location_reservation_occurrences o where o.reservation_id=r.id))
  from public.location_reservations r where r.id=p_id
$$;

-- One private dispatcher owns the lock order and authorization boundary for all
-- public entry points. Shared owner lock serializes policy changes versus reservations;
-- the catalog row lock also serializes LOC02 status updates versus reservation.
create function app_private.location_reservation_command_v2(
  p_operation text,p_location_id uuid,p_payload jsonb,p_request_id uuid
) returns jsonb language plpgsql volatile security definer set search_path='' set timezone='UTC'
as $$
declare ctx app_private.superadmin_internal_context; initial_actor uuid; initial_session uuid;
  target public.activity_locations%rowtype; target_reservation public.location_reservations%rowtype;
  v_owner_id uuid; owner_kind text; capability text; correlation uuid:=gen_random_uuid();
  policy_record public.location_scheduling_policies%rowtype;
  receipt app_private.location_reservation_receipts%rowtype;
  normalized jsonb; consumer jsonb; requested_hash bytea; result jsonb;
  conflicts jsonb; can_override boolean:=false; is_write boolean;
  error_code text; error_detail text; new_id uuid; expected_version bigint; audit_institution_id uuid;
  page_limit integer; after_id uuid; after_created timestamptz; page_ids uuid[];
begin
  is_write:=p_operation in('create','cancel','policy_set');
  capability:=case when is_write then 'locations.reservations.manage' else 'locations.reservations.read' end;
  begin
    if p_operation is null or p_operation not in('create','assess','cancel','list','policy_get','policy_set')
      or p_payload is null or jsonb_typeof(p_payload)<>'object'
      or current_setting('transaction_isolation')<>'read committed'
      or (is_write and p_request_id is null) then
      raise invalid_parameter_value using message='invalid reservation command';
    end if;
    select * into strict ctx from app_private.require_superadmin_internal_context(capability);
    initial_actor:=ctx.internal_identity_id; initial_session:=ctx.session_id;
    if p_operation in('create','assess') then
      normalized:=app_private.location_reservation_normalize_v2(p_payload);
      p_location_id:=(normalized->>'location_id')::uuid;
    end if;
    if p_location_id is null then raise invalid_parameter_value using message='location required'; end if;
    if is_write then
      requested_hash:=extensions.digest(convert_to(p_operation||':'||p_location_id::text||':'||p_payload::text,'UTF8'),'sha256');
      perform pg_advisory_xact_lock(hashtextextended('location-reservation-request:'||initial_actor::text||':'||p_request_id::text,0));
    end if;
    -- This first lookup yields only the owner lock key; no data is returned or
    -- effect performed before the canonical ownership check below.
    select l.scope_kind,coalesce(l.unit_id,l.institution_id) into owner_kind,v_owner_id
      from public.activity_locations l where l.id=p_location_id;
    if v_owner_id is null then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    if p_operation='policy_set' then
      perform pg_advisory_xact_lock(hashtextextended('location-reservation-owner:'||owner_kind||':'||v_owner_id::text,0));
    else
      perform pg_advisory_xact_lock_shared(hashtextextended('location-reservation-owner:'||owner_kind||':'||v_owner_id::text,0));
    end if;
    select * into strict ctx from app_private.require_superadmin_internal_context(capability);
    target:=app_private.superadmin_location_locked_v2(ctx,p_location_id);
    if target.scope_kind is distinct from owner_kind or coalesce(target.unit_id,target.institution_id) is distinct from v_owner_id then
      raise serialization_failure using detail='SAI_CONCURRENT_CHANGE';
    end if;
    if ctx.internal_identity_id is distinct from initial_actor or ctx.session_id is distinct from initial_session then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
    if not exists(select 1 from auth.sessions s where s.id=initial_session
      and (s.not_after is null or s.not_after>clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
    -- Set only after the canonical location lock has resolved and authorized
    -- ownership. Client location UUIDs are never institution audit targets.
    audit_institution_id:=target.institution_id;
    if p_operation in('create','assess') then
      if (normalized->>'location_id')::uuid is distinct from target.id then
        raise invalid_parameter_value using message='reservation location mismatch';
      end if;
      consumer:=normalized->'consumer';
    elsif p_operation in('cancel','list') then consumer:=p_payload->'consumer'; end if;
    if consumer is not null then
      perform app_private.location_reservation_consumer_v2(ctx,target,consumer,is_write);
    elsif p_operation in('create','assess','cancel','list') then
      raise invalid_parameter_value using message='reservation consumer required';
    end if;
    select p.* into policy_record from public.location_scheduling_policies p
      where p.scope_kind=owner_kind and p.owner_id=v_owner_id;
    if is_write then
      select r.* into receipt from app_private.location_reservation_receipts r
        where r.actor_id=initial_actor and r.request_id=p_request_id;
      if found and (receipt.operation is distinct from p_operation
        or receipt.request_hash is distinct from requested_hash or receipt.location_id is distinct from target.id) then
        raise serialization_failure using detail='SAI_CONCURRENT_CHANGE';
      end if;
    end if;
    if receipt.request_id is not null then
      result:=receipt.result;
      new_id:=receipt.reservation_id;
    elsif p_operation='policy_get' then
      if p_payload<>'{}'::jsonb then raise invalid_parameter_value; end if;
      result:=jsonb_build_object('scope_kind',owner_kind,'owner_id',v_owner_id,
        'policy',policy_record.policy,'management_version',coalesce(policy_record.management_version,0));
    elsif p_operation='policy_set' then
      if not(p_payload ?& array['policy','expected_version'])
        or (select count(*) from jsonb_object_keys(p_payload))<>2
        or coalesce(p_payload->>'policy','') not in('block','warn')
        or coalesce(p_payload->>'expected_version','') !~ '^(0|[1-9][0-9]{0,17})$' then
        raise invalid_parameter_value using message='invalid scheduling policy';
      end if;
      expected_version:=(p_payload->>'expected_version')::bigint;
      if expected_version<>coalesce(policy_record.management_version,0) then
        raise serialization_failure using detail='SAI_CONCURRENT_CHANGE';
      end if;
      insert into public.location_scheduling_policies(scope_kind,owner_id,institution_id,unit_id,policy,updated_by_internal_identity_id)
        values(owner_kind,v_owner_id,target.institution_id,target.unit_id,p_payload->>'policy',initial_actor)
      on conflict on constraint location_scheduling_policies_pkey do update set policy=excluded.policy,
        management_version=location_scheduling_policies.management_version+1,
        updated_at=clock_timestamp(),updated_by_internal_identity_id=excluded.updated_by_internal_identity_id
      returning * into policy_record;
      result:=jsonb_build_object('scope_kind',owner_kind,'owner_id',v_owner_id,
        'policy',policy_record.policy,'management_version',policy_record.management_version);
    elsif p_operation in('create','assess') then
      if target.status<>'active' or policy_record.policy is null then
        raise invalid_parameter_value using message='active location and explicit scheduling policy required';
      end if;
      select coalesce(jsonb_agg(jsonb_build_object('starts_at',x.starts_at,'ends_at',x.ends_at) order by x.starts_at,x.ends_at),'[]')
        into conflicts from (select distinct o.starts_at,o.ends_at
          from public.location_reservations r join public.location_reservation_occurrences o on o.reservation_id=r.id
          where r.location_id=target.id and r.state='active'
            and exists(select 1 from jsonb_array_elements(normalized->'occurrences') requested
              where tstzrange(o.starts_at,o.ends_at,'[)') && tstzrange((requested->>'starts_at')::timestamptz,(requested->>'ends_at')::timestamptz,'[)'))
          order by o.starts_at,o.ends_at limit 1000) x;
      if jsonb_array_length(conflicts)>0 and policy_record.policy='warn' then
        begin
          perform app_private.require_superadmin_internal_context('locations.reservations.override');
          can_override:=true;
        exception when insufficient_privilege then can_override:=false; end;
      end if;
      if p_operation='assess' then
        result:=jsonb_build_object('location_id',target.id,'consumer',consumer,'policy',policy_record.policy,
          'conflict',case when jsonb_array_length(conflicts)=0 then 'none'
            when policy_record.policy='block' then 'refused' when can_override then 'confirmable' else 'not_confirmable' end,
          'conflicting',conflicts);
      else
        if jsonb_array_length(conflicts)>0 then
          if policy_record.policy='block' then raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
          if not can_override then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
          if normalized->>'conflict_justification' is null then
            raise invalid_parameter_value using message='conflict justification required';
          end if;
        end if;
        insert into public.location_bindings(location_id,consumer_kind,consumer_id,group_id,activity_id)
          values(target.id,consumer->>'kind',(consumer->>'id')::uuid,
            case when consumer->>'kind'='group' then (consumer->>'id')::uuid end,
            case when consumer->>'kind'='activity' then (consumer->>'id')::uuid end)
          on conflict do nothing;
        insert into public.location_reservations(location_id,consumer_kind,consumer_id,recurrence,
          confirmed_over_conflict,conflict_justification,actor_internal_identity_id)
          values(target.id,consumer->>'kind',(consumer->>'id')::uuid,normalized->'recurrence',
            jsonb_array_length(conflicts)>0,case when jsonb_array_length(conflicts)>0 then normalized->>'conflict_justification' end,initial_actor)
          returning id into new_id;
        insert into public.location_reservation_occurrences(reservation_id,starts_at,ends_at)
          select new_id,(value->>'starts_at')::timestamptz,(value->>'ends_at')::timestamptz
          from jsonb_array_elements(normalized->'occurrences');
        result:=app_private.location_reservation_payload_v2(new_id);
      end if;
    elsif p_operation='cancel' then
      if not(p_payload ?& array['consumer','reservation_id','expected_version'])
        or (select count(*) from jsonb_object_keys(p_payload))<>3
        or coalesce(p_payload->>'expected_version','') !~ '^[1-9][0-9]{0,17}$' then raise invalid_parameter_value; end if;
      select r.* into target_reservation from public.location_reservations r
        where r.id=(p_payload->>'reservation_id')::uuid and r.location_id=target.id
          and r.consumer_kind=consumer->>'kind' and r.consumer_id=(consumer->>'id')::uuid for update;
      if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
      if target_reservation.management_version<>(p_payload->>'expected_version')::bigint
        or target_reservation.state<>'active' then raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
      update public.location_reservations set state='cancelled',management_version=management_version+1,updated_at=clock_timestamp()
        where id=target_reservation.id;
      new_id:=target_reservation.id;
      result:=app_private.location_reservation_payload_v2(new_id);
    elsif p_operation='list' then
      if not(p_payload ?& array['consumer','after_id','limit'])
        or (select count(*) from jsonb_object_keys(p_payload))<>3
        or coalesce(p_payload->>'limit','') !~ '^[1-9][0-9]{0,2}$' then raise invalid_parameter_value; end if;
      page_limit:=(p_payload->>'limit')::integer;
      if page_limit>100 then raise invalid_parameter_value; end if;
      after_id:=(p_payload->>'after_id')::uuid;
      if after_id is not null then
        select r.created_at into after_created from public.location_reservations r
          where r.id=after_id and r.location_id=target.id and r.consumer_kind=consumer->>'kind'
            and r.consumer_id=(consumer->>'id')::uuid;
        if not found then raise invalid_parameter_value using message='invalid reservation cursor'; end if;
      end if;
      select array_agg(x.id order by x.created_at,x.id) into page_ids
        from (select r.id,r.created_at from public.location_reservations r
          where r.location_id=target.id and r.consumer_kind=consumer->>'kind' and r.consumer_id=(consumer->>'id')::uuid
            and (after_id is null or (r.created_at,r.id)>(after_created,after_id))
          order by r.created_at,r.id limit page_limit+1) x;
      result:=jsonb_build_object('location_id',target.id,'consumer',consumer,
        'items',(select coalesce(jsonb_agg(app_private.location_reservation_payload_v2(x.id) order by x.position),'[]')
          from unnest(page_ids[1:page_limit]) with ordinality x(id,position)),
        'next_id',case when cardinality(page_ids)>page_limit then page_ids[page_limit] end);
    end if;
    if is_write and receipt.request_id is null then
      insert into app_private.location_reservation_receipts(actor_id,request_id,operation,request_hash,location_id,reservation_id,result)
        values(initial_actor,p_request_id,p_operation,requested_hash,target.id,new_id,result);
    end if;
    -- Audit can wait on the shared chain lock. Keep success records inside the
    -- same rollback boundary and authorize again AFTER every append completes.
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
      ctx.internal_membership_id,ctx.session_id,capability,ctx.aal,'location.reservation.'||p_operation,'success',null,
      correlation,target.institution_id,case when new_id is not null then 'location_reservation' else 'location' end,
      coalesce(new_id,target.id));
    if p_operation='create' and receipt.request_id is null and jsonb_array_length(conflicts)>0 then
      perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
        ctx.internal_membership_id,ctx.session_id,'locations.reservations.override',ctx.aal,
        'location.reservation.override','success','RESERVATION_CONFLICT_OVERRIDE',correlation,
        target.institution_id,'location_reservation',new_id);
    end if;
    -- Recheck after all potentially blocking writes/audits. Raising inside this
    -- subtransaction removes data, receipt, binding AND success audit records.
    select * into strict ctx from app_private.require_superadmin_internal_context(capability);
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    if consumer is not null then perform app_private.location_reservation_consumer_v2(ctx,target,consumer,is_write); end if;
    if p_operation in('create','assess') and can_override and jsonb_array_length(conflicts)>0 then
      perform app_private.require_superadmin_internal_context('locations.reservations.override');
    end if;
    select * into strict ctx from app_private.require_superadmin_internal_context(capability);
    if ctx.internal_identity_id is distinct from initial_actor or ctx.session_id is distinct from initial_session
      or not exists(select 1 from auth.sessions s where s.id=initial_session and (s.not_after is null or s.not_after>clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
  exception when insufficient_privilege then
    get stacked diagnostics error_detail=pg_exception_detail;
    error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then error_detail else 'SAI_PERMISSION_DENIED' end;
  when invalid_parameter_value or invalid_text_representation or numeric_value_out_of_range then error_code:='SAI_INVALID_ARGUMENT';
  when serialization_failure or unique_violation then error_code:='SAI_CONCURRENT_CHANGE';
  when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(capability,'location.reservation.'||p_operation,error_code,correlation,audit_institution_id);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

create function public.superadmin_location_reservation_create_v2(p_payload jsonb,p_request_id uuid)
returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.location_reservation_command_v2('create',null,p_payload,p_request_id) $$;
create function public.superadmin_location_reservation_assess_v2(p_payload jsonb)
returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.location_reservation_command_v2('assess',null,p_payload,null) $$;
create function public.superadmin_location_reservation_cancel_v2(p_location_id uuid,p_payload jsonb,p_request_id uuid)
returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.location_reservation_command_v2('cancel',p_location_id,p_payload,p_request_id) $$;
create function public.superadmin_location_reservations_v2(p_location_id uuid,p_consumer jsonb,p_after_id uuid default null,p_limit integer default 50)
returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.location_reservation_command_v2('list',p_location_id,jsonb_build_object('consumer',p_consumer,'after_id',p_after_id,'limit',p_limit),null) $$;
create function public.superadmin_location_scheduling_policy_v2(p_location_id uuid)
returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.location_reservation_command_v2('policy_get',p_location_id,'{}',null) $$;
create function public.superadmin_location_scheduling_policy_set_v2(p_location_id uuid,p_payload jsonb,p_request_id uuid)
returns jsonb language sql volatile security definer set search_path=''
as $$ select app_private.location_reservation_command_v2('policy_set',p_location_id,p_payload,p_request_id) $$;

revoke all on function app_private.location_reservation_normalize_v2(jsonb),
  app_private.location_reservation_consumer_v2(app_private.superadmin_internal_context,public.activity_locations,jsonb,boolean),
  app_private.location_reservation_payload_v2(uuid),app_private.location_reservation_command_v2(text,uuid,jsonb,uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.superadmin_location_reservation_create_v2(jsonb,uuid),
  public.superadmin_location_reservation_assess_v2(jsonb),public.superadmin_location_reservation_cancel_v2(uuid,jsonb,uuid),
  public.superadmin_location_reservations_v2(uuid,jsonb,uuid,integer),public.superadmin_location_scheduling_policy_v2(uuid),
  public.superadmin_location_scheduling_policy_set_v2(uuid,jsonb,uuid) from public,anon,authenticated,service_role;
grant execute on function public.superadmin_location_reservation_create_v2(jsonb,uuid),
  public.superadmin_location_reservation_assess_v2(jsonb),public.superadmin_location_reservation_cancel_v2(uuid,jsonb,uuid),
  public.superadmin_location_reservations_v2(uuid,jsonb,uuid,integer),public.superadmin_location_scheduling_policy_v2(uuid),
  public.superadmin_location_scheduling_policy_set_v2(uuid,jsonb,uuid) to authenticated;
commit;
