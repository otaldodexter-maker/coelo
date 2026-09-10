-- LOCAL nominal candidate. Approved Locais design 2026-09-02 and Estrutura
-- create-draft slice: existing catalog selection + optional reservation.
-- No one-off text, edit, publish, About, catalog promotion or production enablement.
-- Apply only over the reviewed ActivityAggregateConcurrencyClock/reservations
-- union. Existing aggregate and engine remain unchanged and authoritative.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
set local search_path=public,pg_catalog;
do $preflight$
begin
 if current_user<>'postgres' then raise insufficient_privilege; end if;
 if to_regprocedure('public.superadmin_activity_save_v2(uuid,uuid,bigint,boolean,jsonb)') is null
   or to_regprocedure('public.superadmin_location_reservation_create_v2(jsonb,uuid)') is null
   or to_regprocedure('app_private.activity_request_uuid(text,uuid)') is null
   or to_regprocedure('app_private.superadmin_location_locked_v2(app_private.superadmin_internal_context,uuid)') is null
   or to_regclass('app_private.superadmin_internal_activity_save_receipts') is null then
   raise object_not_in_prerequisite_state using message='reviewed Activity aggregate and reservation prerequisites missing';
 end if;
 if to_regclass('public.activity_location_selections') is not null
   or to_regclass('app_private.activity_location_create_receipts') is not null
   or to_regprocedure('public.superadmin_activity_location_create_v2(uuid,uuid,jsonb,jsonb)') is not null
   or to_regprocedure('public.superadmin_activity_location_selection_v2(uuid)') is not null
   or to_regprocedure('app_private.activity_location_authorize_v2(text[],app_private.superadmin_internal_context)') is not null then
   raise duplicate_object using message='Activity location candidate object collision';
 end if;
end $preflight$;

-- One current reference per Activity. Historical reservation bindings can have
-- several locations and survive cancellation, so they cannot store this fact.
create table public.activity_location_selections(
 activity_id uuid primary key references public.activity_definitions(id) on delete restrict,
 location_id uuid not null references public.activity_locations(id) on delete restrict,
 created_by_internal_identity_id uuid not null references app_private.superadmin_internal_identities(id),
 created_at timestamptz not null default now()
);
create index activity_location_selections_location_idx on public.activity_location_selections(location_id);
create index activity_location_selections_actor_idx on public.activity_location_selections(created_by_internal_identity_id);
create table app_private.activity_location_create_receipts(
 actor_id uuid not null references app_private.superadmin_internal_identities(id),
 request_id uuid not null,
 request_hash bytea not null check(octet_length(request_hash)=32),
 activity_id uuid not null references public.activity_definitions(id) on delete restrict,
 location_id uuid not null references public.activity_locations(id) on delete restrict,
 result jsonb not null check(jsonb_typeof(result)='object'),
 created_at timestamptz not null default now(),
 primary key(actor_id,request_id)
);
create index activity_location_create_receipts_activity_idx on app_private.activity_location_create_receipts(activity_id);
create index activity_location_create_receipts_location_idx on app_private.activity_location_create_receipts(location_id);
alter table public.activity_location_selections enable row level security;
alter table public.activity_location_selections force row level security;
alter table app_private.activity_location_create_receipts enable row level security;
alter table app_private.activity_location_create_receipts force row level security;
revoke all on public.activity_location_selections,app_private.activity_location_create_receipts
 from public,anon,authenticated,service_role;

create function app_private.activity_location_authorize_v2(
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

create function public.superadmin_activity_location_create_v2(
 p_request_id uuid,p_location_id uuid,p_activity_payload jsonb,p_reservation jsonb default null
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
 ctx app_private.superadmin_internal_context; initial_ctx app_private.superadmin_internal_context;
 target public.activity_locations%rowtype;
 receipt app_private.activity_location_create_receipts%rowtype;
 required_permissions text[]:=array['activities.create','activities.read','activities.link_units',
   'activities.link_groups','activities.assign_people','activities.manage_permissions','locations.read'];
 save_request uuid; create_request uuid; reservation_request uuid; v_activity_id uuid;
 owner_kind text; v_owner_id uuid; v_hash bytea;
 aggregate_result jsonb; reservation_result jsonb; result jsonb; consumer jsonb;
 correlation uuid:=gen_random_uuid(); audit_institution_id uuid; error_code text; error_detail text;
begin
 begin
   if p_request_id is null or p_location_id is null or p_activity_payload is null
     or jsonb_typeof(p_activity_payload) is distinct from 'object'
     or current_setting('transaction_isolation')<>'read committed' then raise invalid_parameter_value; end if;
   if p_reservation is not null then
     if jsonb_typeof(p_reservation) is distinct from 'object' then raise invalid_parameter_value; end if;
     if not(p_reservation ?& array['first_occurrence','recurrence','conflict_justification'])
       or (select count(*) from jsonb_object_keys(p_reservation))<>3 then raise invalid_parameter_value; end if;
     required_permissions:=required_permissions||array['locations.reservations.manage','activities.manage'];
   end if;
   initial_ctx:=app_private.activity_location_authorize_v2(required_permissions);
   ctx:=initial_ctx;
   v_hash:=extensions.digest(convert_to(jsonb_build_object('location_id',p_location_id,
     'activity',p_activity_payload,'reservation',p_reservation)::text,'UTF8'),'sha256');
   save_request:=app_private.activity_request_uuid('activity-location-save:'||ctx.internal_identity_id::text,p_request_id);
   create_request:=app_private.activity_request_uuid('activity-save-create',save_request);
   reservation_request:=app_private.activity_request_uuid('activity-location-reserve:'||ctx.internal_identity_id::text,p_request_id);
   -- All request locks precede owner/location and consumer mutation locks.
   perform pg_advisory_xact_lock(hashtextextended('activity-location-request:'||ctx.internal_identity_id::text||':'||p_request_id::text,0));
   perform pg_advisory_xact_lock(hashtextextended(save_request::text,0));
   perform pg_advisory_xact_lock(hashtextextended(create_request::text,0));
   if p_reservation is not null then
     perform pg_advisory_xact_lock(hashtextextended('location-reservation-request:'||ctx.internal_identity_id::text||':'||reservation_request::text,0));
   end if;
   ctx:=app_private.activity_location_authorize_v2(required_permissions,initial_ctx);
   select l.scope_kind,coalesce(l.unit_id,l.institution_id) into owner_kind,v_owner_id
     from public.activity_locations l where l.id=p_location_id;
   if v_owner_id is null then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
   perform pg_advisory_xact_lock_shared(hashtextextended('location-reservation-owner:'||owner_kind||':'||v_owner_id::text,0));
   target:=app_private.superadmin_location_locked_v2(ctx,p_location_id);
   if target.scope_kind is distinct from owner_kind or coalesce(target.unit_id,target.institution_id) is distinct from v_owner_id then
     raise serialization_failure using detail='SAI_CONCURRENT_CHANGE';
   end if;
   audit_institution_id:=target.institution_id;
   ctx:=app_private.activity_location_authorize_v2(required_permissions,initial_ctx);
   if (p_activity_payload->>'institution_id')::uuid is distinct from target.institution_id then
     raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
   end if;
   select r.* into receipt from app_private.activity_location_create_receipts r
     where r.actor_id=ctx.internal_identity_id and r.request_id=p_request_id;
   if found then
     if receipt.request_hash is distinct from v_hash or receipt.location_id is distinct from target.id then
       raise serialization_failure using detail='SAI_CONCURRENT_CHANGE';
     end if;
     v_activity_id:=receipt.activity_id;
     if not exists(select 1 from public.activity_location_selections s
       where s.activity_id=v_activity_id and s.location_id=target.id) then
       raise serialization_failure using detail='SAI_CONCURRENT_CHANGE';
     end if;
     result:=receipt.result||jsonb_build_object('replayed',true);
   else
     if target.status<>'active' then raise invalid_parameter_value; end if;
     -- Public child gateways must not let a pre-existing unrelated save be
     -- adopted into this wrapper. Child locks above serialize this check.
     if exists(select 1 from app_private.superadmin_internal_activity_save_receipts r where r.request_id=save_request)
       or exists(select 1 from app_private.superadmin_internal_activity_command_receipts r where r.request_id=create_request)
       or (p_reservation is not null and exists(select 1 from app_private.location_reservation_receipts r
         where r.actor_id=ctx.internal_identity_id and r.request_id=reservation_request)) then
       raise serialization_failure using detail='SAI_CONCURRENT_CHANGE';
     end if;
     aggregate_result:=public.superadmin_activity_save_v2(save_request,null,0,false,p_activity_payload);
     if aggregate_result->>'ok' is distinct from 'true' then
       raise exception using detail=coalesce(aggregate_result#>>'{error,code}','SAI_INTERNAL_ERROR');
     end if;
     v_activity_id:=(aggregate_result#>>'{data,activity_id}')::uuid;
     consumer:=jsonb_build_object('kind','activity','id',v_activity_id);
     perform app_private.location_reservation_consumer_v2(ctx,target,consumer,p_reservation is not null);
     insert into public.activity_location_selections(activity_id,location_id,created_by_internal_identity_id)
       values(v_activity_id,target.id,ctx.internal_identity_id);
     if p_reservation is not null then
       reservation_result:=public.superadmin_location_reservation_create_v2(
         p_reservation||jsonb_build_object('location_id',target.id,'consumer',consumer),reservation_request);
       if reservation_result->>'ok' is distinct from 'true' then
         raise exception using detail=coalesce(reservation_result#>>'{error,code}','SAI_INTERNAL_ERROR');
       end if;
     end if;
     result:=(aggregate_result->'data')||jsonb_build_object('location_id',target.id,
       'reservation',reservation_result->'data','replayed',false);
     insert into app_private.activity_location_create_receipts(actor_id,request_id,request_hash,activity_id,location_id,result)
       values(ctx.internal_identity_id,p_request_id,v_hash,v_activity_id,target.id,result);
   end if;
   consumer:=jsonb_build_object('kind','activity','id',v_activity_id);
   perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
     ctx.internal_membership_id,ctx.session_id,'activities.create',ctx.aal,'activity.location.create','success',null,
     correlation,target.institution_id,'activity',v_activity_id);
   -- The outer audit can block after the child engine's final checks. Recheck
   -- all capabilities and hierarchy here; raising removes ALL child effects.
   perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
   perform app_private.location_reservation_consumer_v2(ctx,target,consumer,p_reservation is not null);
   if result#>>'{reservation,confirmed_over_conflict}'='true' then
     perform app_private.require_superadmin_internal_context('locations.reservations.override');
   end if;
   ctx:=app_private.activity_location_authorize_v2(required_permissions,initial_ctx);
 exception when others then
   get stacked diagnostics error_detail=pg_exception_detail;
   error_code:=case
     when sqlstate in('22023','22P02','22003') or error_detail in('ACTIVITY_INVALID_INPUT','ACTIVITY_INVALID_REFERENCE') then 'SAI_INVALID_ARGUMENT'
     when sqlstate in('40001','23505') or error_detail in('SAI_CONCURRENT_CHANGE','ACTIVITY_INVALID_STATE','ACTIVITY_DEPENDENCIES_ACTIVE') then 'SAI_CONCURRENT_CHANGE'
     when error_detail='ACTIVITY_NOT_FOUND' then 'SAI_PERMISSION_DENIED'
     when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
       'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED','SAI_INVALID_ARGUMENT') then error_detail
     else 'SAI_INTERNAL_ERROR' end;
 end;
 if error_code is not null then
   perform app_private.audit_superadmin_internal_denial_if_identified('activities.create','activity.location.create',error_code,correlation,audit_institution_id);
   return app_private.superadmin_internal_error_envelope(error_code,correlation);
 end if;
 return jsonb_build_object('ok',true,'data',result,'error',null);
end $$;

create function public.superadmin_activity_location_selection_v2(p_activity_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
 ctx app_private.superadmin_internal_context; initial_ctx app_private.superadmin_internal_context;
 v_institution_id uuid; v_location_id uuid; target public.activity_locations%rowtype;
 result jsonb; location_data jsonb; correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
 begin
   if p_activity_id is null or current_setting('transaction_isolation')<>'read committed' then raise invalid_parameter_value; end if;
   initial_ctx:=app_private.activity_location_authorize_v2(array['activities.read','locations.read']);
   ctx:=initial_ctx;
   select a.institution_id into v_institution_id from public.activity_definitions a
     where a.id=p_activity_id and a.status<>'archived'
       and (ctx.scope_kind='platform' or (ctx.scope_kind='institution' and ctx.scope_institution_id=a.institution_id));
   if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
   perform app_private.superadmin_location_owner_v2(ctx,'institution',v_institution_id,null);
   select s.location_id into v_location_id from public.activity_location_selections s where s.activity_id=p_activity_id;
   if v_location_id is not null then
     select l.* into target from public.activity_locations l where l.id=v_location_id for share;
     if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
     perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
     perform app_private.location_reservation_consumer_v2(ctx,target,jsonb_build_object('kind','activity','id',p_activity_id),false);
     location_data:=jsonb_build_object('id',target.id,'scope_kind',target.scope_kind,
       'institution_id',target.institution_id,'unit_id',target.unit_id,'kind',target.kind,'name',target.name,'status',target.status);
   end if;
   perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
     ctx.internal_membership_id,ctx.session_id,'activities.read',ctx.aal,'activity.location.read','success',null,
     correlation,v_institution_id,'activity',p_activity_id);
   perform app_private.superadmin_location_owner_v2(ctx,'institution',v_institution_id,null);
   if v_location_id is not null then
     perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
     perform app_private.location_reservation_consumer_v2(ctx,target,jsonb_build_object('kind','activity','id',p_activity_id),false);
   end if;
   ctx:=app_private.activity_location_authorize_v2(array['activities.read','locations.read'],initial_ctx);
   if not exists(select 1 from public.activity_definitions a where a.id=p_activity_id
     and a.institution_id=v_institution_id and a.status<>'archived') then
     raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
   end if;
   result:=jsonb_build_object('activity_id',p_activity_id,'location',location_data);
 exception when insufficient_privilege then
   get stacked diagnostics error_detail=pg_exception_detail;
   error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
     'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then error_detail else 'SAI_PERMISSION_DENIED' end;
 when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
 when others then error_code:='SAI_INTERNAL_ERROR';
 end;
 if error_code is not null then
   perform app_private.audit_superadmin_internal_denial_if_identified('activities.read','activity.location.read',error_code,correlation,v_institution_id);
   return app_private.superadmin_internal_error_envelope(error_code,correlation);
 end if;
 return jsonb_build_object('ok',true,'data',result,'error',null);
end $$;
revoke all on function app_private.activity_location_authorize_v2(text[],app_private.superadmin_internal_context)
 from public,anon,authenticated,service_role;
revoke all on function public.superadmin_activity_location_create_v2(uuid,uuid,jsonb,jsonb),
 public.superadmin_activity_location_selection_v2(uuid) from public,anon,authenticated,service_role;
grant execute on function public.superadmin_activity_location_create_v2(uuid,uuid,jsonb,jsonb),
 public.superadmin_activity_location_selection_v2(uuid) to authenticated;
commit;
