-- LOC-CATALOG04 LOCAL CANDIDATE. No remote lease or production capability provisioning.
-- Weekly availability windows for a catalog entry. Depends on 20260908190646 and
-- 20260908190648. public.activity_locations keeps the exact shape the create package
-- left it with; the windows live in their own child table, which is not a second
-- catalog and is unreadable except through this package's own read command.
-- Replay owner must supply the separately reviewed Owner-only capability fixture.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
set local search_path=public,pg_catalog;

do $preflight$
declare capability text;
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using message='location candidate requires postgres';
  end if;
  if to_regclass('app_private.superadmin_location_write_receipts') is null
    or to_regclass('app_private.superadmin_location_copy_lineage') is null
    or to_regprocedure('public.superadmin_location_update_v2(uuid,jsonb,bigint,uuid)') is null
    or to_regprocedure('public.superadmin_location_set_status_v2(uuid,text,bigint,uuid)') is null
    or to_regprocedure('public.superadmin_location_copy_v2(uuid,text,uuid,uuid,text,uuid)') is null
    or to_regprocedure('app_private.superadmin_location_locked_v2(app_private.superadmin_internal_context,uuid)') is null
    or to_regprocedure('app_private.superadmin_location_owner_v2(app_private.superadmin_internal_context,text,uuid,uuid)') is null
    or to_regprocedure('app_private.superadmin_location_payload_v2(uuid)') is null then
    raise object_not_in_prerequisite_state using message='location write packages missing';
  end if;
  if (select count(*)::integer from pg_attribute
      where attrelid='public.activity_locations'::regclass and attnum>0 and not attisdropped)<>16 then
    raise object_not_in_prerequisite_state using message='location column drift';
  end if;
  if (select pg_get_constraintdef(oid) from pg_constraint
      where conrelid='app_private.superadmin_location_write_receipts'::regclass
        and conname='superadmin_location_write_receipts_operation_check')
      is distinct from $def$CHECK ((operation = ANY (ARRAY['update'::text, 'status'::text, 'copy'::text])))$def$ then
    raise object_not_in_prerequisite_state using message='location receipt verb drift';
  end if;
  foreach capability in array array['locations.read','locations.create','locations.update',
    'locations.status','locations.copy','locations.schedule'] loop
    if not exists(select 1 from public.platform_permissions where code=capability and status='active')
      or (select array_agg(r.code order by r.code) from public.platform_role_permissions rp
        join public.platform_roles r on r.id=rp.role_id and r.status='active'
        join public.platform_permissions p on p.id=rp.permission_id
        where p.code=capability and rp.effect='allow' and rp.status='active' and rp.revoked_at is null)
        is distinct from array['owner']::text[] then
      raise object_not_in_prerequisite_state using message='location candidate requires separate Owner-only capability fixture';
    end if;
  end loop;
  if to_regclass('public.activity_location_schedules') is not null
    or exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname in('public','app_private') and p.proname in(
        'superadmin_location_schedule_normalize_v2','superadmin_location_schedule_payload_v2',
        'superadmin_location_schedule_v2','superadmin_location_schedule_set_v2')) then
    raise duplicate_object using message='location schedule candidate objects already exist';
  end if;
end
$preflight$;

alter table app_private.superadmin_location_write_receipts
  drop constraint superadmin_location_write_receipts_operation_check,
  add constraint superadmin_location_write_receipts_operation_check
    check(operation in('update','status','copy','schedule'));

-- Minutes from midnight rather than time, so a window is an integer range that
-- compares and sorts the same way in every client and in every timezone the
-- institution is read from. 1440 is midnight at the end of the day.
create table public.activity_location_schedules(
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.activity_locations(id) on delete cascade,
  weekday smallint not null check(weekday between 0 and 6),
  starts_minute smallint not null check(starts_minute between 0 and 1439),
  ends_minute smallint not null check(ends_minute between 1 and 1440),
  created_at timestamptz not null default now(),
  created_by_internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  constraint activity_location_schedules_window_check check(starts_minute<ends_minute),
  constraint activity_location_schedules_slot_key unique(location_id,weekday,starts_minute)
);
create index activity_location_schedules_location_idx
  on public.activity_location_schedules(location_id,weekday,starts_minute);
alter table public.activity_location_schedules enable row level security;
alter table public.activity_location_schedules force row level security;
revoke all on public.activity_location_schedules from public,anon,authenticated,service_role;

-- Validates the whole week at once and returns it canonically ordered, so two
-- clients that mean the same schedule produce the same request digest.
create function app_private.superadmin_location_schedule_normalize_v2(p_windows jsonb)
returns jsonb language plpgsql immutable security invoker set search_path=''
as $$
declare item jsonb; field text; numeric_value numeric; result jsonb;
begin
  if p_windows is null or jsonb_typeof(p_windows)<>'array' then
    raise invalid_parameter_value using message='invalid location schedule',detail='SAI_INVALID_ARGUMENT';
  end if;
  -- Ten windows a day is already more than a place is ever opened and closed.
  if jsonb_array_length(p_windows)>70 then
    raise invalid_parameter_value using message='location schedule too long',detail='SAI_INVALID_ARGUMENT';
  end if;
  for item in select value from jsonb_array_elements(p_windows) loop
    if jsonb_typeof(item)<>'object'
      or not(item ?& array['weekday','starts_minute','ends_minute'])
      or (select count(*) from jsonb_object_keys(item))<>3 then
      raise invalid_parameter_value using message='invalid location schedule window',detail='SAI_INVALID_ARGUMENT';
    end if;
    foreach field in array array['weekday','starts_minute','ends_minute'] loop
      if jsonb_typeof(item->field)<>'number' then
        raise invalid_parameter_value using message='invalid location schedule window',detail='SAI_INVALID_ARGUMENT';
      end if;
      numeric_value:=(item->>field)::numeric;
      if numeric_value<>trunc(numeric_value) then
        raise invalid_parameter_value using message='invalid location schedule window',detail='SAI_INVALID_ARGUMENT';
      end if;
    end loop;
    if (item->>'weekday')::integer<0 or (item->>'weekday')::integer>6
      or (item->>'starts_minute')::integer<0 or (item->>'ends_minute')::integer>1440
      or (item->>'starts_minute')::integer>=(item->>'ends_minute')::integer then
      raise invalid_parameter_value using message='invalid location schedule window',detail='SAI_INVALID_ARGUMENT';
    end if;
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object(
      'weekday',weekday,'starts_minute',starts_minute,'ends_minute',ends_minute)
      order by weekday,starts_minute),'[]'::jsonb)
    into result from (
      select (value->>'weekday')::integer weekday,(value->>'starts_minute')::integer starts_minute,
        (value->>'ends_minute')::integer ends_minute from jsonb_array_elements(p_windows)) parsed;
  -- Two windows that overlap on the same day mean the operator lost track of one of
  -- them; refusing is safer than merging something nobody asked to merge.
  if exists(select 1 from (
      select starts_minute,lag(ends_minute) over(partition by weekday order by starts_minute) previous_end
      from (select (value->>'weekday')::integer weekday,(value->>'starts_minute')::integer starts_minute,
              (value->>'ends_minute')::integer ends_minute from jsonb_array_elements(result)) ordered
    ) windowed where previous_end is not null and starts_minute<previous_end) then
    raise invalid_parameter_value using message='location schedule windows overlap',detail='SAI_INVALID_ARGUMENT';
  end if;
  return result;
end
$$;
revoke all on function app_private.superadmin_location_schedule_normalize_v2(jsonb)
  from public,anon,authenticated,service_role;

create function app_private.superadmin_location_schedule_payload_v2(p_location_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('weekday',s.weekday,
      'starts_minute',s.starts_minute,'ends_minute',s.ends_minute)
      order by s.weekday,s.starts_minute),'[]'::jsonb)
  from public.activity_location_schedules s where s.location_id=p_location_id
$$;
revoke all on function app_private.superadmin_location_schedule_payload_v2(uuid)
  from public,anon,authenticated,service_role;

create function public.superadmin_location_schedule_v2(p_location_id uuid)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare ctx app_private.superadmin_internal_context; target public.activity_locations%rowtype;
  initial_actor_id uuid; initial_session_id uuid;
  result jsonb; correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.read');
    if current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using message='location isolation unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    initial_actor_id:=ctx.internal_identity_id;
    initial_session_id:=ctx.session_id;
    select l.* into target from public.activity_locations l where l.id=p_location_id
      and ctx.platform_role_code='owner'
      and (ctx.scope_kind='platform' or
        (ctx.scope_kind='institution' and ctx.scope_institution_id=l.institution_id)) for share;
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.read');
    if ctx.internal_identity_id is distinct from initial_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    if ctx.session_id is distinct from initial_session_id or not exists(
      select 1 from auth.sessions session_record where session_record.id=initial_session_id
        and (session_record.not_after is null or session_record.not_after>clock_timestamp())) then
      raise insufficient_privilege using message='location session invalid',detail='SAI_SESSION_INVALID';
    end if;
    -- An empty array is a real answer: no window is recorded, which the caller must
    -- read as "nothing published", never as "open at all times".
    result:=jsonb_build_object('location_id',target.id,
      'management_version',target.management_version,
      'windows',app_private.superadmin_location_schedule_payload_v2(target.id));
  exception when insufficient_privilege then
    get stacked diagnostics error_detail=pg_exception_detail;
    error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
      then error_detail else 'SAI_INTERNAL_ERROR' end;
  when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
  when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'locations.read','location.schedule_read',error_code,correlation,null);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
    ctx.internal_membership_id,ctx.session_id,'locations.read',ctx.aal,'location.schedule_read','success',null,
    correlation,target.institution_id,'location',target.id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;
revoke all on function public.superadmin_location_schedule_v2(uuid) from public,anon,authenticated,service_role;
grant execute on function public.superadmin_location_schedule_v2(uuid) to authenticated;

-- The whole week is replaced in one call. Per-window commands would let a client
-- believe a half-applied week is a week, which is the failure this avoids.
create function public.superadmin_location_schedule_set_v2(
  p_location_id uuid,p_windows jsonb,p_expected_version bigint,p_request_id uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare ctx app_private.superadmin_internal_context; normalized jsonb; result jsonb;
  receipt app_private.superadmin_location_write_receipts%rowtype;
  target public.activity_locations%rowtype;
  requested_hash bytea; locked_actor_id uuid; initial_session_id uuid;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.schedule');
    initial_session_id:=ctx.session_id;
    if current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using message='location isolation unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_request_id is null or p_location_id is null
      or p_expected_version is null or p_expected_version<=0 then
      raise invalid_parameter_value using message='location request incomplete',detail='SAI_INVALID_ARGUMENT';
    end if;
    normalized:=app_private.superadmin_location_schedule_normalize_v2(p_windows);
    requested_hash:=extensions.digest(convert_to(
      p_location_id::text||':'||p_expected_version::text||':'||normalized::text,'UTF8'),'sha256');
    locked_actor_id:=ctx.internal_identity_id;
    perform pg_advisory_xact_lock(hashtextextended(locked_actor_id::text||':'||p_request_id::text,0));
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.schedule');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    select r.* into receipt from app_private.superadmin_location_write_receipts r
      where r.actor_internal_identity_id=ctx.internal_identity_id and r.request_id=p_request_id;
    if found then
      if receipt.operation<>'schedule' or receipt.request_hash is distinct from requested_hash
        or receipt.location_id is distinct from p_location_id then
        raise serialization_failure using message='location request already used',detail='SAI_CONCURRENT_CHANGE';
      end if;
      target:=app_private.superadmin_location_locked_v2(ctx,receipt.location_id);
    else
      -- The location row is the lock every schedule writer takes, so replacing a week
      -- is serialized per location and the windows cannot interleave.
      target:=app_private.superadmin_location_locked_v2(ctx,p_location_id);
      if target.status='archived' then
        raise invalid_parameter_value using message='archived location publishes no schedule',
          detail='SAI_INVALID_ARGUMENT';
      end if;
      if target.management_version is distinct from p_expected_version then
        raise serialization_failure using message='location version stale',detail='SAI_CONCURRENT_CHANGE';
      end if;
      delete from public.activity_location_schedules where location_id=target.id;
      insert into public.activity_location_schedules(
        location_id,weekday,starts_minute,ends_minute,created_by_internal_identity_id)
      select target.id,(value->>'weekday')::smallint,(value->>'starts_minute')::smallint,
        (value->>'ends_minute')::smallint,ctx.internal_identity_id
      from jsonb_array_elements(normalized);
      update public.activity_locations set
        management_version=management_version+1,updated_at=now()
      where id=target.id and management_version=p_expected_version
      returning * into target;
      if not found then
        raise serialization_failure using message='location version stale',detail='SAI_CONCURRENT_CHANGE';
      end if;
      insert into app_private.superadmin_location_write_receipts(
        actor_internal_identity_id,request_id,operation,request_hash,location_id,resulting_version)
        values(ctx.internal_identity_id,p_request_id,'schedule',requested_hash,target.id,
          target.management_version);
    end if;
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.schedule');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    if ctx.session_id is distinct from initial_session_id or not exists(
      select 1 from auth.sessions session_record where session_record.id=initial_session_id
        and (session_record.not_after is null or session_record.not_after>clock_timestamp())) then
      raise insufficient_privilege using message='location session invalid',detail='SAI_SESSION_INVALID';
    end if;
    result:=jsonb_build_object('location_id',target.id,
      'management_version',target.management_version,
      'windows',app_private.superadmin_location_schedule_payload_v2(target.id));
  exception when insufficient_privilege then
    get stacked diagnostics error_detail=pg_exception_detail;
    error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
      then error_detail else 'SAI_INTERNAL_ERROR' end;
  when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
  when unique_violation or serialization_failure then error_code:='SAI_CONCURRENT_CHANGE';
  when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'locations.schedule','location.schedule',error_code,correlation,p_location_id);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
    ctx.internal_membership_id,ctx.session_id,'locations.schedule',ctx.aal,'location.schedule','success',null,
    correlation,target.institution_id,'location',target.id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;
revoke all on function public.superadmin_location_schedule_set_v2(uuid,jsonb,bigint,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_location_schedule_set_v2(uuid,jsonb,bigint,uuid) to authenticated;

do $postflight$
begin
  if to_regclass('public.activity_location_schedules') is null
    or to_regprocedure('public.superadmin_location_schedule_v2(uuid)') is null
    or to_regprocedure('public.superadmin_location_schedule_set_v2(uuid,jsonb,bigint,uuid)') is null then
    raise object_not_in_prerequisite_state using message='location schedule candidate incomplete';
  end if;
  if (select count(*)::integer from pg_attribute
      where attrelid='public.activity_locations'::regclass and attnum>0 and not attisdropped)<>16 then
    raise object_not_in_prerequisite_state using message='location schedule widened the catalog';
  end if;
  -- The windows are reachable only through the two commands above.
  if exists(select 1 from information_schema.role_table_grants
      where table_schema='public' and table_name='activity_location_schedules'
        and grantee in('public','anon','authenticated','service_role'))
    or exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='app_private'
        and p.proname in('superadmin_location_schedule_normalize_v2',
          'superadmin_location_schedule_payload_v2')
        and has_function_privilege('authenticated',p.oid,'EXECUTE')) then
    raise object_not_in_prerequisite_state using message='location schedule grant drift';
  end if;
  if not has_function_privilege('authenticated',
      'public.superadmin_location_schedule_v2(uuid)'::regprocedure,'EXECUTE')
    or not has_function_privilege('authenticated',
      'public.superadmin_location_schedule_set_v2(uuid,jsonb,bigint,uuid)'::regprocedure,'EXECUTE') then
    raise object_not_in_prerequisite_state using message='location schedule candidate is unreachable';
  end if;
end
$postflight$;

commit;
