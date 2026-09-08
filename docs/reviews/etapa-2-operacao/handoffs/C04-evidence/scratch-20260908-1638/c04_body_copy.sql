begin;


-- The receipt lane stays single: one request id, one verb, one outcome.
alter table app_private.superadmin_location_write_receipts
  drop constraint superadmin_location_write_receipts_operation_check,
  add constraint superadmin_location_write_receipts_operation_check
    check(operation in('update','status','copy'));

-- Where a copy came from is internal provenance, not catalog data, so it lives
-- beside the receipts instead of widening public.activity_locations.
create table app_private.superadmin_location_copy_lineage(
  location_id uuid primary key references public.activity_locations(id) on delete cascade,
  source_location_id uuid not null references public.activity_locations(id) on delete restrict,
  copied_by_internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  copied_at timestamptz not null default now(),
  constraint superadmin_location_copy_lineage_distinct_check check(location_id<>source_location_id)
);
create index superadmin_location_copy_lineage_source_idx
  on app_private.superadmin_location_copy_lineage(source_location_id);
alter table app_private.superadmin_location_copy_lineage enable row level security;
alter table app_private.superadmin_location_copy_lineage force row level security;
revoke all on app_private.superadmin_location_copy_lineage from public,anon,authenticated,service_role;

create function public.superadmin_location_copy_v2(
  p_source_location_id uuid,p_scope_kind text,p_institution_id uuid,p_unit_id uuid,
  p_name text,p_request_id uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare ctx app_private.superadmin_internal_context; normalized jsonb; result jsonb;
  receipt app_private.superadmin_location_write_receipts%rowtype;
  source public.activity_locations%rowtype; target public.activity_locations%rowtype;
  requested_hash bytea; created_id uuid; locked_actor_id uuid; initial_session_id uuid;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.copy');
    initial_session_id:=ctx.session_id;
    if current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using message='location isolation unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_request_id is null or p_source_location_id is null then
      raise invalid_parameter_value using message='location request incomplete',detail='SAI_INVALID_ARGUMENT';
    end if;
    requested_hash:=extensions.digest(convert_to(
      p_source_location_id::text||':'||coalesce(p_scope_kind,'')||':'||coalesce(p_institution_id::text,'')
      ||':'||coalesce(p_unit_id::text,'')||':'||coalesce(p_name,''),'UTF8'),'sha256');
    locked_actor_id:=ctx.internal_identity_id;
    perform pg_advisory_xact_lock(hashtextextended(locked_actor_id::text||':'||p_request_id::text,0));
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.copy');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    select r.* into receipt from app_private.superadmin_location_write_receipts r
      where r.actor_internal_identity_id=ctx.internal_identity_id and r.request_id=p_request_id;
    if found then
      if receipt.operation<>'copy' or receipt.request_hash is distinct from requested_hash then
        raise serialization_failure using message='location request already used',detail='SAI_CONCURRENT_CHANGE';
      end if;
      target:=app_private.superadmin_location_locked_v2(ctx,receipt.location_id);
      created_id:=target.id;
    else
      -- The source is authorized and locked first: a copy of a row the caller may
      -- not reach would read that row through its result.
      source:=app_private.superadmin_location_locked_v2(ctx,p_source_location_id);
      -- The target owner is a separate authorization, not an inference from the source.
      perform app_private.superadmin_location_owner_v2(ctx,p_scope_kind,p_institution_id,p_unit_id);
      -- A copy stays inside its institution. Carrying one tenant's configuration into
      -- another is a product decision, not a convenience of this command.
      if p_institution_id is distinct from source.institution_id then
        raise invalid_parameter_value using message='location copy stays inside its institution',
          detail='SAI_INVALID_ARGUMENT';
      end if;
      if p_scope_kind=source.scope_kind and p_unit_id is not distinct from source.unit_id
        and lower(btrim(coalesce(p_name,'')))=lower(source.name) then
        raise invalid_parameter_value using message='location copy needs a distinct name or owner',
          detail='SAI_INVALID_ARGUMENT';
      end if;
      -- Validation is the create package's normalizer, so a copy can never produce a
      -- row that a create would have refused. An archived source is a usable template;
      -- what it produces is a new active entry, never a second archived one.
      normalized:=app_private.superadmin_location_normalize_v2(jsonb_build_object(
        'scope_kind',p_scope_kind,'institution_id',p_institution_id,'unit_id',p_unit_id,
        'name',p_name,'description',source.description,'kind',source.kind,
        'floor',source.floor,'address',source.address,'visibility',source.visibility));
      if not app_private.superadmin_location_name_available_v2(
          null,normalized->>'scope_kind',(normalized->>'institution_id')::uuid,
          (normalized->>'unit_id')::uuid,normalized->>'name') then
        raise invalid_parameter_value using message='location name already used',detail='SAI_INVALID_ARGUMENT';
      end if;
      insert into public.activity_locations(scope_kind,institution_id,unit_id,name,description,kind,floor,
        address,visibility,created_by_internal_identity_id)
      values(normalized->>'scope_kind',(normalized->>'institution_id')::uuid,
        (normalized->>'unit_id')::uuid,normalized->>'name',normalized->>'description',
        normalized->>'kind',normalized->>'floor',nullif(normalized->'address','null'::jsonb),
        normalized->>'visibility',ctx.internal_identity_id)
      returning id into created_id;
      insert into app_private.superadmin_location_copy_lineage(
        location_id,source_location_id,copied_by_internal_identity_id)
        values(created_id,source.id,ctx.internal_identity_id);
      insert into app_private.superadmin_location_write_receipts(
        actor_internal_identity_id,request_id,operation,request_hash,location_id,resulting_version)
        values(ctx.internal_identity_id,p_request_id,'copy',requested_hash,created_id,1);
      select l.* into target from public.activity_locations l where l.id=created_id for share;
    end if;
    -- The insert and both writes beside it may have waited, so the authorization that
    -- opened the command is re-proved before it is reported as done.
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.copy');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    if ctx.session_id is distinct from initial_session_id or not exists(
      select 1 from auth.sessions session_record where session_record.id=initial_session_id
        and (session_record.not_after is null or session_record.not_after>clock_timestamp())) then
      raise insufficient_privilege using message='location session invalid',detail='SAI_SESSION_INVALID';
    end if;
    result:=app_private.superadmin_location_payload_v2(created_id);
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
      'locations.copy','location.copy',error_code,correlation,p_source_location_id);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
    ctx.internal_membership_id,ctx.session_id,'locations.copy',ctx.aal,'location.copy','success',null,
    correlation,target.institution_id,'location',created_id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;
revoke all on function public.superadmin_location_copy_v2(uuid,text,uuid,uuid,text,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_location_copy_v2(uuid,text,uuid,uuid,text,uuid) to authenticated;


commit;
