-- LOCAL nominal Group CREATE DRAFT candidate. No legacy person-based writer.
-- Requires a reviewed LocationReservationsV1 successor. No production enablement.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
set local search_path=public,pg_catalog;
do $preflight$
begin
 if current_user<>'postgres' then raise insufficient_privilege; end if;
 if to_regprocedure('public.superadmin_location_reservation_create_v2(jsonb,uuid)') is null
   or to_regprocedure('app_private.superadmin_location_locked_v2(app_private.superadmin_internal_context,uuid)') is null
   or to_regclass('app_private.location_reservation_receipts') is null
   or not exists(select 1 from pg_attribute where attrelid='public.groups'::regclass and attname='management_version' and not attisdropped)
 then raise object_not_in_prerequisite_state using message='Group schema, internal Auth and reservation engine required'; end if;
 if to_regclass('public.group_location_selections') is not null
   or to_regclass('app_private.group_location_create_receipts') is not null
   or to_regprocedure('public.superadmin_group_location_create_v2(uuid,uuid,jsonb,jsonb)') is not null
   or to_regprocedure('public.superadmin_group_location_selection_v2(uuid)') is not null
   or to_regprocedure('app_private.group_location_authorize_v2(text[],app_private.superadmin_internal_context)') is not null
   or to_regprocedure('app_private.group_location_reservation_request_v2(uuid,uuid)') is not null
 then raise duplicate_object using message='Group location candidate object collision'; end if;
end $preflight$;
create table public.group_location_selections(
 group_id uuid primary key references public.groups(id) on delete restrict,
 location_id uuid not null references public.activity_locations(id) on delete restrict,
 created_by_internal_identity_id uuid not null references app_private.superadmin_internal_identities(id),
 created_at timestamptz not null default now()
);
create index group_location_selections_location_idx on public.group_location_selections(location_id);
create index group_location_selections_actor_idx on public.group_location_selections(created_by_internal_identity_id);
create table app_private.group_location_create_receipts(
 actor_id uuid not null references app_private.superadmin_internal_identities(id),
 request_id uuid not null,
 request_hash bytea not null check(octet_length(request_hash)=32),
 group_id uuid not null references public.groups(id) on delete restrict,
 location_id uuid not null references public.activity_locations(id) on delete restrict,
 result jsonb not null check(jsonb_typeof(result)='object'),
 created_at timestamptz not null default now(),
 primary key(actor_id,request_id)
);
create index group_location_create_receipts_group_idx on app_private.group_location_create_receipts(group_id);
create index group_location_create_receipts_location_idx on app_private.group_location_create_receipts(location_id);
alter table public.group_location_selections enable row level security;
alter table public.group_location_selections force row level security;
alter table app_private.group_location_create_receipts enable row level security;
alter table app_private.group_location_create_receipts force row level security;
revoke all on public.group_location_selections,app_private.group_location_create_receipts from public,anon,authenticated,service_role;
-- Deterministic child request; no Activity helper dependency and no client consumer ID.
create function app_private.group_location_reservation_request_v2(p_actor uuid,p_request uuid)
returns uuid language sql immutable strict set search_path='' as $$
 select md5('group-location-reserve:'||p_actor::text||':'||p_request::text)::uuid
$$;
create function app_private.group_location_authorize_v2(
 p_permissions text[],p_expected app_private.superadmin_internal_context default null
) returns app_private.superadmin_internal_context
language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; fresh app_private.superadmin_internal_context; permission text;
begin
 if coalesce(cardinality(p_permissions),0)=0 then raise invalid_parameter_value; end if;
 select * into strict ctx from app_private.require_superadmin_internal_context(p_permissions[1]);
 foreach permission in array p_permissions loop
   select * into strict fresh from app_private.require_superadmin_internal_context(permission);
   if row(fresh.internal_identity_id,fresh.internal_auth_link_id,fresh.internal_membership_id,
     fresh.auth_user_id,fresh.session_id,fresh.platform_role_id,fresh.scope_kind,fresh.scope_institution_id,fresh.aal)
     is distinct from row(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
     ctx.auth_user_id,ctx.session_id,ctx.platform_role_id,ctx.scope_kind,ctx.scope_institution_id,ctx.aal) then
     raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
   end if;
 end loop;
 if p_expected.internal_identity_id is not null and ctx is distinct from p_expected then
   raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
 end if;
 if not exists(select 1 from auth.sessions s where s.id=ctx.session_id and s.user_id=ctx.auth_user_id
   and (s.not_after is null or s.not_after>clock_timestamp())) then
   raise insufficient_privilege using detail='SAI_SESSION_INVALID';
 end if;
 return ctx;
end $$;


create function public.superadmin_group_location_create_v2(
 p_request_id uuid,p_location_id uuid,p_group_payload jsonb,p_reservation jsonb default null
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
<<command>>
declare
 ctx app_private.superadmin_internal_context; initial_ctx app_private.superadmin_internal_context;
 target public.activity_locations%rowtype; target_unit public.units%rowtype; created_group public.groups%rowtype;
 receipt app_private.group_location_create_receipts%rowtype;
 permissions text[]:=array['groups.manage','groups.read','locations.read'];
 reservation_request uuid; institution_id uuid; unit_id uuid; group_id uuid;
 owner_kind text; owner_id uuid; request_hash bytea; consumer jsonb;
 result jsonb; reservation_result jsonb; correlation uuid:=gen_random_uuid();
 audit_institution_id uuid; error_code text; error_detail text;
begin
 begin
   if p_request_id is null or p_location_id is null or p_group_payload is null
     or jsonb_typeof(p_group_payload) is distinct from 'object'
     or current_setting('transaction_isolation')<>'read committed' then raise invalid_parameter_value; end if;
   if not(p_group_payload ?& array['institution_id','unit_id','name','group_type','group_type_other_text'])
     or (select count(*) from jsonb_object_keys(p_group_payload))<>5
     or jsonb_typeof(p_group_payload->'institution_id') is distinct from 'string'
     or jsonb_typeof(p_group_payload->'unit_id') is distinct from 'string'
     or jsonb_typeof(p_group_payload->'name') is distinct from 'string'
     or jsonb_typeof(p_group_payload->'group_type') is distinct from 'string'
     or jsonb_typeof(p_group_payload->'group_type_other_text') not in('string','null')
     or nullif(btrim(p_group_payload->>'name'),'') is null
     or nullif(btrim(p_group_payload->>'group_type'),'') is null
     or (lower(btrim(p_group_payload->>'group_type'))='other' and nullif(btrim(p_group_payload->>'group_type_other_text'),'') is null)
   then raise invalid_parameter_value; end if;
   institution_id:=(p_group_payload->>'institution_id')::uuid;
   unit_id:=(p_group_payload->>'unit_id')::uuid;
   if p_reservation is not null then
     if jsonb_typeof(p_reservation) is distinct from 'object' then raise invalid_parameter_value; end if;
     if not(p_reservation ?& array['first_occurrence','recurrence','conflict_justification'])
       or (select count(*) from jsonb_object_keys(p_reservation))<>3 then raise invalid_parameter_value; end if;
     permissions:=permissions||array['locations.reservations.manage'];
   end if;
   initial_ctx:=app_private.group_location_authorize_v2(permissions);
   ctx:=initial_ctx;
   request_hash:=extensions.digest(convert_to(jsonb_build_object('group',p_group_payload,'location_id',p_location_id,'reservation',p_reservation)::text,'UTF8'),'sha256');
   reservation_request:=app_private.group_location_reservation_request_v2(ctx.internal_identity_id,p_request_id);
   -- Request locks before owner/location, then the real unit and Group rows.
   perform pg_advisory_xact_lock(hashtextextended('group-location-request:'||ctx.internal_identity_id::text||':'||p_request_id::text,0));
   if p_reservation is not null then
     perform pg_advisory_xact_lock(hashtextextended('location-reservation-request:'||ctx.internal_identity_id::text||':'||reservation_request::text,0));
   end if;
   ctx:=app_private.group_location_authorize_v2(permissions,initial_ctx);
   select l.scope_kind,coalesce(l.unit_id,l.institution_id) into owner_kind,owner_id from public.activity_locations l where l.id=p_location_id;
   if owner_id is null then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
   perform pg_advisory_xact_lock_shared(hashtextextended('location-reservation-owner:'||owner_kind||':'||owner_id::text,0));
   target:=app_private.superadmin_location_locked_v2(ctx,p_location_id);
   if target.scope_kind is distinct from owner_kind or coalesce(target.unit_id,target.institution_id) is distinct from owner_id then
     raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
   audit_institution_id:=target.institution_id;
   if institution_id is distinct from target.institution_id or (target.scope_kind='unit' and unit_id is distinct from target.unit_id) then
     raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
   perform app_private.superadmin_location_owner_v2(ctx,'unit',institution_id,unit_id);
   select u.* into target_unit from public.units u where u.id=command.unit_id and u.institution_id=command.institution_id for share;
   if not found or target_unit.status<>'active' then raise invalid_parameter_value; end if;
   ctx:=app_private.group_location_authorize_v2(permissions,initial_ctx);
   select r.* into receipt from app_private.group_location_create_receipts r
     where r.actor_id=ctx.internal_identity_id and r.request_id=p_request_id;
   if found then
     if receipt.request_hash is distinct from request_hash or receipt.location_id is distinct from target.id then
       raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
     group_id:=receipt.group_id;
     select g.* into created_group from public.groups g where g.id=command.group_id for share;
     if not found or created_group.institution_id is distinct from institution_id or created_group.unit_id is distinct from unit_id
       or created_group.management_version is distinct from (receipt.result->>'management_version')::bigint
       or created_group.status::text is distinct from receipt.result->>'status'
       or not exists(select 1 from public.group_location_selections s where s.group_id=created_group.id and s.location_id=target.id)
     then raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
     result:=receipt.result||jsonb_build_object('replayed',true);
   else
     if target.status<>'active' then raise invalid_parameter_value; end if;
     if p_reservation is not null and exists(select 1 from app_private.location_reservation_receipts r
       where r.actor_id=ctx.internal_identity_id and r.request_id=reservation_request) then
       raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
     insert into public.groups(institution_id,unit_id,name,group_type,group_type_other_text,status,
       inherit_appearance,inherit_access,inherit_activities,management_version)
     values(command.institution_id,command.unit_id,btrim(p_group_payload->>'name'),lower(btrim(p_group_payload->>'group_type')),
       nullif(btrim(p_group_payload->>'group_type_other_text'),''),'draft',true,true,true,1)
       returning * into created_group;
     group_id:=created_group.id;
     consumer:=jsonb_build_object('kind','group','id',group_id);
     perform app_private.location_reservation_consumer_v2(ctx,target,consumer,p_reservation is not null);
     insert into public.group_location_selections(group_id,location_id,created_by_internal_identity_id)
       values(command.group_id,target.id,ctx.internal_identity_id);
     if p_reservation is not null then
       reservation_result:=public.superadmin_location_reservation_create_v2(
         p_reservation||jsonb_build_object('location_id',target.id,'consumer',consumer),reservation_request);
       if reservation_result->>'ok' is distinct from 'true' then
         raise exception using detail=coalesce(reservation_result#>>'{error,code}','SAI_INTERNAL_ERROR'); end if;
     end if;
     result:=jsonb_build_object('group_id',group_id,'management_version',created_group.management_version,
       'status',created_group.status,'location_id',target.id,'reservation',reservation_result->'data',
       'correlation_id',correlation,'replayed',false);
     insert into app_private.group_location_create_receipts(actor_id,request_id,request_hash,group_id,location_id,result)
       values(ctx.internal_identity_id,p_request_id,command.request_hash,command.group_id,target.id,command.result);
   end if;
   consumer:=jsonb_build_object('kind','group','id',group_id);
   perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
     ctx.internal_membership_id,ctx.session_id,'groups.manage',ctx.aal,'group.location.create','success',null,
     correlation,target.institution_id,'group',group_id);
   perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
   perform app_private.superadmin_location_owner_v2(ctx,'unit',institution_id,unit_id);
   perform app_private.location_reservation_consumer_v2(ctx,target,consumer,p_reservation is not null);
   if not exists(select 1 from public.units u where u.id=command.unit_id
     and u.institution_id=command.institution_id and u.status='active') then
     raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
   if result#>>'{reservation,confirmed_over_conflict}'='true' then
     perform app_private.require_superadmin_internal_context('locations.reservations.override'); end if;
   ctx:=app_private.group_location_authorize_v2(permissions,initial_ctx);
 exception when others then
   get stacked diagnostics error_detail=pg_exception_detail;
   error_code:=case when sqlstate in('22023','22P02','22003','23514') then 'SAI_INVALID_ARGUMENT'
     when sqlstate in('40001','23505') or error_detail='SAI_CONCURRENT_CHANGE' then 'SAI_CONCURRENT_CHANGE'
     when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
       'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED','SAI_INVALID_ARGUMENT') then error_detail
     when sqlstate='42501' then 'SAI_PERMISSION_DENIED' else 'SAI_INTERNAL_ERROR' end;
 end;
 if error_code is not null then
   perform app_private.audit_superadmin_internal_denial_if_identified('groups.manage','group.location.create',error_code,correlation,audit_institution_id);
   return app_private.superadmin_internal_error_envelope(error_code,correlation);
 end if;
 return jsonb_build_object('ok',true,'data',result,'error',null);
end $$;
create function public.superadmin_group_location_selection_v2(p_group_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
 ctx app_private.superadmin_internal_context; initial_ctx app_private.superadmin_internal_context;
 v_institution_id uuid; v_unit_id uuid; v_location_id uuid; target public.activity_locations%rowtype;
 result jsonb; location_data jsonb; correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
 begin
   if p_group_id is null or current_setting('transaction_isolation')<>'read committed' then raise invalid_parameter_value; end if;
   initial_ctx:=app_private.group_location_authorize_v2(array['groups.read','locations.read']);
   ctx:=initial_ctx;
   select a.institution_id,a.unit_id into v_institution_id,v_unit_id from public.groups a
     where a.id=p_group_id and a.status<>'archived'
       and (ctx.scope_kind='platform' or (ctx.scope_kind='institution' and ctx.scope_institution_id=a.institution_id));
   if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
   perform app_private.superadmin_location_owner_v2(ctx,'unit',v_institution_id,v_unit_id);
   select s.location_id into v_location_id from public.group_location_selections s where s.group_id=p_group_id;
   if v_location_id is not null then
     select l.* into target from public.activity_locations l where l.id=v_location_id for share;
     if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
     perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
     perform app_private.location_reservation_consumer_v2(ctx,target,jsonb_build_object('kind','group','id',p_group_id),false);
     location_data:=jsonb_build_object('id',target.id,'scope_kind',target.scope_kind,
       'institution_id',target.institution_id,'unit_id',target.unit_id,'kind',target.kind,'name',target.name,'status',target.status);
   end if;
   perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
     ctx.internal_membership_id,ctx.session_id,'groups.read',ctx.aal,'group.location.read','success',null,
     correlation,v_institution_id,'group',p_group_id);
   perform app_private.superadmin_location_owner_v2(ctx,'unit',v_institution_id,v_unit_id);
   if v_location_id is not null then
     perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
     perform app_private.location_reservation_consumer_v2(ctx,target,jsonb_build_object('kind','group','id',p_group_id),false);
   end if;
   ctx:=app_private.group_location_authorize_v2(array['groups.read','locations.read'],initial_ctx);
   if not exists(select 1 from public.groups a where a.id=p_group_id
     and a.institution_id=v_institution_id and a.unit_id=v_unit_id and a.status<>'archived') then
     raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
   end if;
   result:=jsonb_build_object('group_id',p_group_id,'location',location_data);
 exception when insufficient_privilege then
   get stacked diagnostics error_detail=pg_exception_detail;
   error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
     'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then error_detail else 'SAI_PERMISSION_DENIED' end;
 when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
 when others then error_code:='SAI_INTERNAL_ERROR';
 end;
 if error_code is not null then
   perform app_private.audit_superadmin_internal_denial_if_identified('groups.read','group.location.read',error_code,correlation,v_institution_id);
   return app_private.superadmin_internal_error_envelope(error_code,correlation);
 end if;
 return jsonb_build_object('ok',true,'data',result,'error',null);
end $$;

revoke all on function app_private.group_location_authorize_v2(text[],app_private.superadmin_internal_context),
 app_private.group_location_reservation_request_v2(uuid,uuid) from public,anon,authenticated,service_role;
revoke all on function public.superadmin_group_location_create_v2(uuid,uuid,jsonb,jsonb),
 public.superadmin_group_location_selection_v2(uuid) from public,anon,authenticated,service_role;
grant execute on function public.superadmin_group_location_create_v2(uuid,uuid,jsonb,jsonb),
 public.superadmin_group_location_selection_v2(uuid) to authenticated;
commit;
