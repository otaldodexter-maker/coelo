-- LOC-CATALOG02 LOCAL CANDIDATE. No remote lease or production capability provisioning.
-- Edits and status transitions over the catalog that 20260908031000 already created.
-- No competing table is introduced: public.activity_locations keeps every column, index
-- and constraint it has, and this package only adds receipts, helpers and two RPCs.
-- Replay owner must supply the separately reviewed Owner-only capability fixture.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
set local search_path=public,pg_catalog;

do $preflight$
declare capability text; actual_columns text[];
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using message='location candidate requires postgres';
  end if;
  if to_regprocedure('app_private.superadmin_location_normalize_v2(jsonb)') is null
    or to_regprocedure('app_private.superadmin_location_owner_v2(app_private.superadmin_internal_context,text,uuid,uuid)') is null
    or to_regprocedure('app_private.superadmin_location_payload_v2(uuid)') is null
    or to_regprocedure('public.superadmin_location_create_v2(jsonb,uuid)') is null
    or to_regprocedure('public.superadmin_location_detail_v2(uuid)') is null
    or to_regclass('app_private.superadmin_location_create_receipts') is null
    or to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regprocedure('app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)') is null
    or to_regprocedure('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)') is null
    or to_regprocedure('app_private.superadmin_internal_error_envelope(text,uuid)') is null then
    raise object_not_in_prerequisite_state using message='location catalog v2 prerequisites missing';
  end if;
  lock table public.activity_locations in access exclusive mode;
  select array_agg(attname::text||':'||format_type(atttypid,atttypmod)||':'||attnotnull::text order by attnum)
    into actual_columns from pg_attribute
    where attrelid='public.activity_locations'::regclass and attnum>0 and not attisdropped;
  if actual_columns is distinct from array[
    'id:uuid:true','institution_id:uuid:true','unit_id:uuid:false','name:text:true',
    'description:text:false','status:record_status:true','management_version:bigint:true',
    'created_by_person_id:uuid:false','created_at:timestamp with time zone:true',
    'updated_at:timestamp with time zone:true','scope_kind:text:true','kind:text:true',
    'floor:text:false','address:jsonb:false','visibility:text:true',
    'created_by_internal_identity_id:uuid:false'] then
    raise object_not_in_prerequisite_state using message='location column drift';
  end if;
  if not exists(select 1 from pg_class c join pg_roles r on r.oid=c.relowner
      where c.oid='public.activity_locations'::regclass and c.relrowsecurity
        and c.relforcerowsecurity and r.rolname='postgres')
    or exists(select 1 from pg_policy where polrelid='public.activity_locations'::regclass) then
    raise object_not_in_prerequisite_state using message='location relation security drift';
  end if;
  -- Writing is reachable only through these RPCs, so a direct grant would be a second door.
  if exists(select 1 from information_schema.role_table_grants
      where table_schema='public' and table_name='activity_locations'
        and grantee in('public','anon','authenticated','service_role')) then
    raise object_not_in_prerequisite_state using message='location table grant drift';
  end if;
  foreach capability in array array['locations.read','locations.create','locations.update','locations.status'] loop
    if not exists(select 1 from public.platform_permissions where code=capability and status='active')
      or (select array_agg(r.code order by r.code) from public.platform_role_permissions rp
        join public.platform_roles r on r.id=rp.role_id and r.status='active'
        join public.platform_permissions p on p.id=rp.permission_id
        where p.code=capability and rp.effect='allow' and rp.status='active' and rp.revoked_at is null)
        is distinct from array['owner']::text[] then
      raise object_not_in_prerequisite_state using message='location candidate requires separate Owner-only capability fixture';
    end if;
  end loop;
  if app_private.superadmin_internal_error_envelope('SAI_INVALID_ARGUMENT',gen_random_uuid())#>>'{error,code}'
      is distinct from 'SAI_INVALID_ARGUMENT'
    or app_private.superadmin_internal_error_envelope('SAI_CONCURRENT_CHANGE',gen_random_uuid())#>>'{error,code}'
      is distinct from 'SAI_CONCURRENT_CHANGE' then
    raise object_not_in_prerequisite_state using message='location error envelope dependency missing';
  end if;
  if to_regclass('app_private.superadmin_location_write_receipts') is not null
    or exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname in('public','app_private') and p.proname in(
        'superadmin_location_locked_v2','superadmin_location_name_available_v2',
        'superadmin_location_update_v2','superadmin_location_set_status_v2')) then
    raise duplicate_object using message='location write candidate objects already exist';
  end if;
end
$preflight$;

-- One receipt table for both operations: a request id identifies a request, not a verb,
-- so replaying it under a different verb must collide instead of opening a second lane.
create table app_private.superadmin_location_write_receipts(
  actor_internal_identity_id uuid not null references app_private.superadmin_internal_identities(id) on delete restrict,
  request_id uuid not null,
  operation text not null check(operation in('update','status')),
  request_hash bytea not null check(octet_length(request_hash)=32),
  location_id uuid not null references public.activity_locations(id) on delete restrict,
  resulting_version bigint not null check(resulting_version>0),
  created_at timestamptz not null default now(),
  primary key(actor_internal_identity_id,request_id)
);
create index superadmin_location_write_receipt_location_idx
  on app_private.superadmin_location_write_receipts(location_id);
alter table app_private.superadmin_location_write_receipts enable row level security;
alter table app_private.superadmin_location_write_receipts force row level security;
revoke all on app_private.superadmin_location_write_receipts from public,anon,authenticated,service_role;

-- Loads the row under a write lock and refuses anything the caller may not reach.
-- Returning the locked row keeps every command on one authorization path.
create function app_private.superadmin_location_locked_v2(
  p_context app_private.superadmin_internal_context,p_location_id uuid
) returns public.activity_locations language plpgsql volatile security definer set search_path=''
as $$
declare target public.activity_locations%rowtype;
begin
  if p_location_id is null then
    raise invalid_parameter_value using message='location id required',detail='SAI_INVALID_ARGUMENT';
  end if;
  select l.* into target from public.activity_locations l
    where l.id=p_location_id
      and p_context.platform_role_code='owner'
      and (p_context.scope_kind='platform'
        or (p_context.scope_kind='institution' and p_context.scope_institution_id=l.institution_id))
    for update;
  if not found then
    raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
  end if;
  perform app_private.superadmin_location_owner_v2(p_context,target.scope_kind,target.institution_id,target.unit_id);
  return target;
end
$$;
revoke all on function app_private.superadmin_location_locked_v2(app_private.superadmin_internal_context,uuid)
  from public,anon,authenticated,service_role;

-- Mirrors the two partial unique indexes so a rename or a restore fails as an argument
-- error the operator can read, and not as an opaque constraint violation.
create function app_private.superadmin_location_name_available_v2(
  p_location_id uuid,p_scope_kind text,p_institution_id uuid,p_unit_id uuid,p_name text
) returns boolean language sql stable security definer set search_path=''
as $$
  select not exists(
    select 1 from public.activity_locations l
    where l.id is distinct from p_location_id
      and l.status<>'archived'
      and l.institution_id=p_institution_id
      and lower(l.name)=lower(p_name)
      and ((p_scope_kind='unit' and l.unit_id=p_unit_id)
        or (p_scope_kind='institution' and l.unit_id is null)))
$$;
revoke all on function app_private.superadmin_location_name_available_v2(uuid,text,uuid,uuid,text)
  from public,anon,authenticated,service_role;

create function public.superadmin_location_update_v2(
  p_location_id uuid,p_payload jsonb,p_expected_version bigint,p_request_id uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare ctx app_private.superadmin_internal_context; normalized jsonb; result jsonb;
  receipt app_private.superadmin_location_write_receipts%rowtype;
  target public.activity_locations%rowtype;
  requested_hash bytea; institution_id uuid; locked_actor_id uuid; initial_session_id uuid;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.update');
    initial_session_id:=ctx.session_id;
    if current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using message='location isolation unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_request_id is null or p_location_id is null
      or p_expected_version is null or p_expected_version<=0 then
      raise invalid_parameter_value using message='location request incomplete',detail='SAI_INVALID_ARGUMENT';
    end if;
    normalized:=app_private.superadmin_location_normalize_v2(p_payload);
    -- The version and the target belong to the request, so a replay that changed either
    -- is a different request and must not reuse the receipt.
    requested_hash:=extensions.digest(convert_to(
      p_location_id::text||':'||p_expected_version::text||':'||normalized::text,'UTF8'),'sha256');
    locked_actor_id:=ctx.internal_identity_id;
    perform pg_advisory_xact_lock(hashtextextended(locked_actor_id::text||':'||p_request_id::text,0));
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.update');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    select r.* into receipt from app_private.superadmin_location_write_receipts r
      where r.actor_internal_identity_id=ctx.internal_identity_id and r.request_id=p_request_id;
    if found then
      if receipt.operation<>'update' or receipt.request_hash is distinct from requested_hash
        or receipt.location_id is distinct from p_location_id then
        raise serialization_failure using message='location request already used',detail='SAI_CONCURRENT_CHANGE';
      end if;
      target:=app_private.superadmin_location_locked_v2(ctx,receipt.location_id);
    else
      target:=app_private.superadmin_location_locked_v2(ctx,p_location_id);
      -- The catalog never re-parents a location. Activities resolve it through its owner,
      -- so moving it between institutions or units would silently change their answer.
      if target.scope_kind is distinct from normalized->>'scope_kind'
        or target.institution_id is distinct from (normalized->>'institution_id')::uuid
        or target.unit_id is distinct from (normalized->>'unit_id')::uuid then
        raise invalid_parameter_value using message='location owner is immutable',detail='SAI_INVALID_ARGUMENT';
      end if;
      if target.status='archived' then
        raise invalid_parameter_value using message='archived location is read only',detail='SAI_INVALID_ARGUMENT';
      end if;
      if target.management_version is distinct from p_expected_version then
        raise serialization_failure using message='location version stale',detail='SAI_CONCURRENT_CHANGE';
      end if;
      if not app_private.superadmin_location_name_available_v2(
          target.id,target.scope_kind,target.institution_id,target.unit_id,normalized->>'name') then
        raise invalid_parameter_value using message='location name already used',detail='SAI_INVALID_ARGUMENT';
      end if;
      update public.activity_locations set
        name=normalized->>'name',
        description=normalized->>'description',
        kind=normalized->>'kind',
        floor=normalized->>'floor',
        address=nullif(normalized->'address','null'::jsonb),
        visibility=normalized->>'visibility',
        management_version=management_version+1,
        updated_at=now()
      where id=target.id and management_version=p_expected_version
      returning * into target;
      if not found then
        raise serialization_failure using message='location version stale',detail='SAI_CONCURRENT_CHANGE';
      end if;
      insert into app_private.superadmin_location_write_receipts(
        actor_internal_identity_id,request_id,operation,request_hash,location_id,resulting_version)
        values(ctx.internal_identity_id,p_request_id,'update',requested_hash,target.id,target.management_version);
    end if;
    -- The row lock, the receipt insert and the update may all have waited, so the
    -- authorization that opened the command is re-proved before it is reported as done.
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.update');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    institution_id:=target.institution_id;
    if ctx.session_id is distinct from initial_session_id or not exists(
      select 1 from auth.sessions session_record where session_record.id=initial_session_id
        and (session_record.not_after is null or session_record.not_after>clock_timestamp())) then
      raise insufficient_privilege using message='location session invalid',detail='SAI_SESSION_INVALID';
    end if;
    result:=app_private.superadmin_location_payload_v2(target.id);
    if result is null then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
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
      'locations.update','location.update',error_code,correlation,p_location_id);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
    ctx.internal_membership_id,ctx.session_id,'locations.update',ctx.aal,'location.update','success',null,
    correlation,institution_id,'location',target.id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;
revoke all on function public.superadmin_location_update_v2(uuid,jsonb,bigint,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_location_update_v2(uuid,jsonb,bigint,uuid) to authenticated;

create function public.superadmin_location_set_status_v2(
  p_location_id uuid,p_status text,p_expected_version bigint,p_request_id uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare ctx app_private.superadmin_internal_context; result jsonb;
  receipt app_private.superadmin_location_write_receipts%rowtype;
  target public.activity_locations%rowtype;
  requested_hash bytea; institution_id uuid; locked_actor_id uuid; initial_session_id uuid;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.status');
    initial_session_id:=ctx.session_id;
    if current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using message='location isolation unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_request_id is null or p_location_id is null
      or p_expected_version is null or p_expected_version<=0 then
      raise invalid_parameter_value using message='location request incomplete',detail='SAI_INVALID_ARGUMENT';
    end if;
    -- A place is available, temporarily unavailable, or retired. Draft and suspended
    -- belong to records that are negotiated, which a room is not.
    if p_status is null or p_status not in('active','inactive','archived') then
      raise invalid_parameter_value using message='location status unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    requested_hash:=extensions.digest(convert_to(
      p_location_id::text||':'||p_expected_version::text||':'||p_status,'UTF8'),'sha256');
    locked_actor_id:=ctx.internal_identity_id;
    perform pg_advisory_xact_lock(hashtextextended(locked_actor_id::text||':'||p_request_id::text,0));
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.status');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    select r.* into receipt from app_private.superadmin_location_write_receipts r
      where r.actor_internal_identity_id=ctx.internal_identity_id and r.request_id=p_request_id;
    if found then
      if receipt.operation<>'status' or receipt.request_hash is distinct from requested_hash
        or receipt.location_id is distinct from p_location_id then
        raise serialization_failure using message='location request already used',detail='SAI_CONCURRENT_CHANGE';
      end if;
      target:=app_private.superadmin_location_locked_v2(ctx,receipt.location_id);
    else
      target:=app_private.superadmin_location_locked_v2(ctx,p_location_id);
      if target.management_version is distinct from p_expected_version then
        raise serialization_failure using message='location version stale',detail='SAI_CONCURRENT_CHANGE';
      end if;
      -- Asking for the status the row already has is a client that lost track of it.
      -- Retries are covered by the receipt above, so this only fires on a real mistake.
      if target.status::text=p_status then
        raise invalid_parameter_value using message='location status unchanged',detail='SAI_INVALID_ARGUMENT';
      end if;
      -- Leaving the archive puts the name back under the partial unique indexes.
      if target.status='archived' and not app_private.superadmin_location_name_available_v2(
          target.id,target.scope_kind,target.institution_id,target.unit_id,target.name) then
        raise invalid_parameter_value using message='location name already used',detail='SAI_INVALID_ARGUMENT';
      end if;
      update public.activity_locations set
        status=p_status::public.record_status,
        management_version=management_version+1,
        updated_at=now()
      where id=target.id and management_version=p_expected_version
      returning * into target;
      if not found then
        raise serialization_failure using message='location version stale',detail='SAI_CONCURRENT_CHANGE';
      end if;
      insert into app_private.superadmin_location_write_receipts(
        actor_internal_identity_id,request_id,operation,request_hash,location_id,resulting_version)
        values(ctx.internal_identity_id,p_request_id,'status',requested_hash,target.id,target.management_version);
    end if;
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.status');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    institution_id:=target.institution_id;
    if ctx.session_id is distinct from initial_session_id or not exists(
      select 1 from auth.sessions session_record where session_record.id=initial_session_id
        and (session_record.not_after is null or session_record.not_after>clock_timestamp())) then
      raise insufficient_privilege using message='location session invalid',detail='SAI_SESSION_INVALID';
    end if;
    result:=app_private.superadmin_location_payload_v2(target.id);
    if result is null then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
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
      'locations.status','location.status',error_code,correlation,p_location_id);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
    ctx.internal_membership_id,ctx.session_id,'locations.status',ctx.aal,'location.status','success',null,
    correlation,institution_id,'location',target.id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;
revoke all on function public.superadmin_location_set_status_v2(uuid,text,bigint,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_location_set_status_v2(uuid,text,bigint,uuid) to authenticated;

do $postflight$
begin
  if to_regclass('app_private.superadmin_location_write_receipts') is null
    or to_regprocedure('public.superadmin_location_update_v2(uuid,jsonb,bigint,uuid)') is null
    or to_regprocedure('public.superadmin_location_set_status_v2(uuid,text,bigint,uuid)') is null then
    raise object_not_in_prerequisite_state using message='location write candidate incomplete';
  end if;
  -- Only the two RPCs are reachable from a client; the helpers and the receipts are not.
  if exists(select 1 from information_schema.role_table_grants
      where table_schema='app_private' and table_name='superadmin_location_write_receipts'
        and grantee in('public','anon','authenticated','service_role'))
    or exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='app_private'
        and p.proname in('superadmin_location_locked_v2','superadmin_location_name_available_v2')
        and has_function_privilege('authenticated',p.oid,'EXECUTE')) then
    raise object_not_in_prerequisite_state using message='location write candidate grant drift';
  end if;
  if not has_function_privilege('authenticated',
      'public.superadmin_location_update_v2(uuid,jsonb,bigint,uuid)'::regprocedure,'EXECUTE')
    or not has_function_privilege('authenticated',
      'public.superadmin_location_set_status_v2(uuid,text,bigint,uuid)'::regprocedure,'EXECUTE') then
    raise object_not_in_prerequisite_state using message='location write candidate is unreachable';
  end if;
end
$postflight$;

commit;
