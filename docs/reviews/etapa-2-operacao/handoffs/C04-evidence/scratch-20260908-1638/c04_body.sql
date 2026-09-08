begin;


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


commit;
