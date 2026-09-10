-- LOC-CATALOG03 LOCAL CANDIDATE. No remote lease or production capability provisioning.
-- Duplicates one catalog entry into another owner of the same institution.
-- Depends on 20260908190646. No competing table is introduced and
-- public.activity_locations keeps the shape the create package left it with.
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
    or to_regprocedure('public.superadmin_location_update_v2(uuid,jsonb,bigint,uuid)') is null
    or to_regprocedure('public.superadmin_location_set_status_v2(uuid,text,bigint,uuid)') is null
    or to_regprocedure('app_private.superadmin_location_locked_v2(app_private.superadmin_internal_context,uuid)') is null
    or to_regprocedure('app_private.superadmin_location_name_available_v2(uuid,text,uuid,uuid,text)') is null
    or to_regprocedure('app_private.superadmin_location_normalize_v2(jsonb)') is null
    or to_regprocedure('app_private.superadmin_location_owner_v2(app_private.superadmin_internal_context,text,uuid,uuid)') is null
    or to_regprocedure('app_private.superadmin_location_payload_v2(uuid)') is null then
    raise object_not_in_prerequisite_state using message='location write package missing';
  end if;
  if (select count(*)::integer from pg_attribute
      where attrelid='public.activity_locations'::regclass and attnum>0 and not attisdropped)<>16 then
    raise object_not_in_prerequisite_state using message='location column drift';
  end if;
  if (select pg_get_constraintdef(oid) from pg_constraint
      where conrelid='app_private.superadmin_location_write_receipts'::regclass
        and conname='superadmin_location_write_receipts_operation_check')
      is distinct from $def$CHECK ((operation = ANY (ARRAY['update'::text, 'status'::text])))$def$ then
    raise object_not_in_prerequisite_state using message='location receipt verb drift';
  end if;
  foreach capability in array array['locations.read','locations.create','locations.update',
    'locations.status','locations.copy'] loop
    if not exists(select 1 from public.platform_permissions where code=capability and status='active')
      or (select array_agg(r.code order by r.code) from public.platform_role_permissions rp
        join public.platform_roles r on r.id=rp.role_id and r.status='active'
        join public.platform_permissions p on p.id=rp.permission_id
        where p.code=capability and rp.effect='allow' and rp.status='active' and rp.revoked_at is null)
        is distinct from array['owner']::text[] then
      raise object_not_in_prerequisite_state using message='location candidate requires separate Owner-only capability fixture';
    end if;
  end loop;
  if to_regclass('app_private.superadmin_location_copy_lineage') is not null
    or to_regprocedure('public.superadmin_location_copy_v2(uuid,text,uuid,uuid,text,uuid)') is not null then
    raise duplicate_object using message='location copy candidate objects already exist';
  end if;
end
$preflight$;

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

do $postflight$
begin
  if to_regclass('app_private.superadmin_location_copy_lineage') is null
    or to_regprocedure('public.superadmin_location_copy_v2(uuid,text,uuid,uuid,text,uuid)') is null then
    raise object_not_in_prerequisite_state using message='location copy candidate incomplete';
  end if;
  if (select count(*)::integer from pg_attribute
      where attrelid='public.activity_locations'::regclass and attnum>0 and not attisdropped)<>16 then
    raise object_not_in_prerequisite_state using message='location copy widened the catalog';
  end if;
  if exists(select 1 from information_schema.role_table_grants
      where table_schema='app_private' and table_name='superadmin_location_copy_lineage'
        and grantee in('public','anon','authenticated','service_role')) then
    raise object_not_in_prerequisite_state using message='location copy lineage grant drift';
  end if;
  if not has_function_privilege('authenticated',
      'public.superadmin_location_copy_v2(uuid,text,uuid,uuid,text,uuid)'::regprocedure,'EXECUTE') then
    raise object_not_in_prerequisite_state using message='location copy candidate is unreachable';
  end if;
end
$postflight$;

commit;
