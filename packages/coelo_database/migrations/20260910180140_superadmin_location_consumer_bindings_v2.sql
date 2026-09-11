-- Local nominal candidate. Source: approved Locais design of 2026-09-02;
-- Etapa 2 Estrutura assignment. Requires the reviewed reservation engine.
-- Reads persisted reservation bindings, NOT the consumer's current selection.
-- No schema/data backfill, capability provisioning or remote application.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
set local search_path=public,pg_catalog;

do $preflight$
begin
 if current_user<>'postgres' then raise insufficient_privilege; end if;
 if to_regclass('public.location_bindings') is null
   or to_regprocedure('app_private.location_reservation_consumer_v2(app_private.superadmin_internal_context,public.activity_locations,jsonb,boolean)') is null
   or to_regprocedure('app_private.superadmin_location_owner_v2(app_private.superadmin_internal_context,text,uuid,uuid)') is null
   or to_regprocedure('public.superadmin_location_reservations_v2(uuid,jsonb,uuid,integer)') is null then
   raise object_not_in_prerequisite_state using message='reviewed reservation reader prerequisites missing';
 end if;
 if to_regprocedure('app_private.location_binding_consumer_context_v2(jsonb)') is not null
   or to_regprocedure('public.superadmin_location_consumer_bindings_v2(jsonb,uuid,integer)') is not null then
   raise duplicate_object using message='consumer binding reader collision';
 end if;
end $preflight$;

-- Resolve a REAL consumer even when it has zero bindings. Do not manufacture
-- an activity_locations row to obtain consumer authorization from the engine.
create function app_private.location_binding_consumer_context_v2(p_consumer jsonb)
returns app_private.superadmin_internal_context
language plpgsql volatile security definer set search_path=''
as $$
declare
 ctx app_private.superadmin_internal_context;
 initial_ctx app_private.superadmin_internal_context;
 extra_ctx app_private.superadmin_internal_context;
 v_consumer_id uuid; v_institution_id uuid; v_unit_id uuid; capability text;
begin
 select * into strict initial_ctx from app_private.require_superadmin_internal_context('locations.reservations.read');
 if p_consumer is null or jsonb_typeof(p_consumer) is distinct from 'object' then
   raise invalid_parameter_value;
 end if;
 if not(p_consumer ?& array['kind','id'])
   or (select count(*) from jsonb_object_keys(p_consumer))<>2
   or coalesce(p_consumer->>'kind','') not in('group','activity')
   or jsonb_typeof(p_consumer->'id') is distinct from 'string'
   or coalesce(p_consumer->>'id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
   raise invalid_parameter_value;
 end if;
 v_consumer_id:=(p_consumer->>'id')::uuid;
 capability:=case when p_consumer->>'kind'='group' then 'groups.read' else 'activities.read' end;
 perform app_private.require_superadmin_internal_context('locations.read');
 perform app_private.require_superadmin_internal_context(capability);
 -- No consumer row lock before location locks: the reservation engine locks
 -- location first and consumer second. The final pass rechecks this lookup.
 if p_consumer->>'kind'='group' then
   select g.institution_id,g.unit_id into v_institution_id,v_unit_id
   from public.groups g where g.id=v_consumer_id and g.status<>'archived';
 else
   select a.institution_id into v_institution_id
   from public.activity_definitions a where a.id=v_consumer_id and a.status<>'archived';
 end if;
 if v_institution_id is null then
   raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
 end if;
 perform app_private.superadmin_location_owner_v2(initial_ctx,
   case when v_unit_id is null then 'institution' else 'unit' end,v_institution_id,v_unit_id);
 -- Owner visibility is exactly the catalog's current owner-only read policy;
 -- this reader grants no family/team access or public visibility bypass.
 select * into strict ctx from app_private.require_superadmin_internal_context('locations.reservations.read');
 if ctx is distinct from initial_ctx then
   raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
 end if;
 foreach capability in array array['locations.read',capability] loop
   select * into strict extra_ctx from app_private.require_superadmin_internal_context(capability);
   if row(extra_ctx.internal_identity_id,extra_ctx.session_id,extra_ctx.internal_membership_id,
     extra_ctx.scope_kind,extra_ctx.scope_institution_id,extra_ctx.platform_role_id)
     is distinct from row(ctx.internal_identity_id,ctx.session_id,ctx.internal_membership_id,
     ctx.scope_kind,ctx.scope_institution_id,ctx.platform_role_id) then
     raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
   end if;
 end loop;
 -- Owner resolution may have waited. Refresh the consumer row after that
 -- wait even when there are no bindings (and thus no consumer helper call).
 if p_consumer->>'kind'='group' then
   if not exists(select 1 from public.groups g where g.id=v_consumer_id
     and g.institution_id=v_institution_id and g.unit_id=v_unit_id and g.status<>'archived') then
     raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
   end if;
 elsif not exists(select 1 from public.activity_definitions a where a.id=v_consumer_id
   and a.institution_id=v_institution_id and a.status<>'archived') then
   raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
 end if;
 ctx.resolved_institution_id:=v_institution_id;
 return ctx;
end $$;

create function public.superadmin_location_consumer_bindings_v2(
 p_consumer jsonb,p_after_location_id uuid default null,p_limit integer default 20
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
 ctx app_private.superadmin_internal_context;
 initial_ctx app_private.superadmin_internal_context;
 target public.activity_locations%rowtype;
 v_consumer_id uuid; ids uuid[]; checked_ids uuid[]; v_location_id uuid;
 items jsonb:='[]'; result jsonb; pass integer;
 correlation uuid:=gen_random_uuid(); audit_institution_id uuid;
 error_code text; error_detail text;
begin
 begin
   if current_setting('transaction_isolation')<>'read committed'
     or p_limit is null or p_limit not between 1 and 100 then
     raise invalid_parameter_value;
   end if;
   initial_ctx:=app_private.location_binding_consumer_context_v2(p_consumer);
   ctx:=initial_ctx;
   audit_institution_id:=ctx.resolved_institution_id;
   v_consumer_id:=(p_consumer->>'id')::uuid;
   if p_after_location_id is not null and not exists(
     select 1 from public.location_bindings b where b.consumer_kind=p_consumer->>'kind'
       and b.consumer_id=v_consumer_id and b.location_id=p_after_location_id) then
     raise invalid_parameter_value using message='invalid binding cursor';
   end if;
   select coalesce(array_agg(page.location_id order by page.location_id),'{}'::uuid[]) into ids
   from (select b.location_id from public.location_bindings b
     where b.consumer_kind=p_consumer->>'kind' and b.consumer_id=v_consumer_id
       -- Match the existing per-consumer indexes, rather than scan the global
       -- binding catalog through its location-first primary key.
       and ((p_consumer->>'kind'='group' and b.group_id=v_consumer_id)
         or (p_consumer->>'kind'='activity' and b.activity_id=v_consumer_id))
       and (p_after_location_id is null or b.location_id>p_after_location_id)
     order by b.location_id limit p_limit+1) page;
   -- Validate the cursor and lookahead too: neither pagination nor an empty
   -- page may reveal an inaccessible binding. Shared locks avoid read/read
   -- deadlocks and preserve catalog metadata until this transaction finishes.
   select coalesce(array_agg(distinct id order by id),'{}'::uuid[]) into checked_ids
   from unnest(ids||case when p_after_location_id is null then '{}'::uuid[] else array[p_after_location_id] end) id;
   for pass in 1..2 loop
     foreach v_location_id in array checked_ids loop
       select l.* into target from public.activity_locations l
       where l.id=v_location_id and ctx.platform_role_code='owner'
         and (ctx.scope_kind='platform' or
           (ctx.scope_kind='institution' and ctx.scope_institution_id=l.institution_id)) for share;
       if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
       perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
       perform app_private.location_reservation_consumer_v2(ctx,target,p_consumer,false);
       if pass=1 and v_location_id=any(ids[1:p_limit]) then
         items:=items||jsonb_build_array(jsonb_build_object('location',jsonb_build_object(
           'id',target.id,'scope_kind',target.scope_kind,'institution_id',target.institution_id,
           'unit_id',target.unit_id,'kind',target.kind,'name',target.name,'status',target.status)));
       end if;
     end loop;
     if pass=1 then
       perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
         ctx.internal_membership_id,ctx.session_id,'locations.reservations.read',ctx.aal,
         'location.consumer_bindings.read','success',null,correlation,audit_institution_id,
         case when p_consumer->>'kind'='group' then 'group' else 'activity' end,v_consumer_id);
     end if;
     -- After audit and all blocking owner/location/consumer checks, reauthorize
     -- the original actor and consumer, including the zero-bindings case.
     ctx:=app_private.location_binding_consumer_context_v2(p_consumer);
     if ctx is distinct from initial_ctx then
       raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
     end if;
     if not exists(select 1 from auth.sessions s where s.id=initial_ctx.session_id
       and s.user_id=initial_ctx.auth_user_id and (s.not_after is null or s.not_after>clock_timestamp())) then
       raise insufficient_privilege using detail='SAI_SESSION_INVALID';
     end if;
   end loop;
   result:=jsonb_build_object('consumer',jsonb_build_object('kind',p_consumer->>'kind','id',v_consumer_id),
     'items',items,'next_location_id',case when cardinality(ids)>p_limit then ids[p_limit] end);
 exception when insufficient_privilege then
   get stacked diagnostics error_detail=pg_exception_detail;
   error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
     'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
     then error_detail else 'SAI_PERMISSION_DENIED' end;
 when invalid_parameter_value or invalid_text_representation then error_code:='SAI_INVALID_ARGUMENT';
 when others then error_code:='SAI_INTERNAL_ERROR';
 end;
 if error_code is not null then
   perform app_private.audit_superadmin_internal_denial_if_identified('locations.reservations.read',
     'location.consumer_bindings.read',error_code,correlation,audit_institution_id);
   return app_private.superadmin_internal_error_envelope(error_code,correlation);
 end if;
 return jsonb_build_object('ok',true,'data',result,'error',null);
end $$;

revoke all on function app_private.location_binding_consumer_context_v2(jsonb)
 from public,anon,authenticated,service_role;
revoke all on function public.superadmin_location_consumer_bindings_v2(jsonb,uuid,integer)
 from public,anon,authenticated,service_role;
grant execute on function public.superadmin_location_consumer_bindings_v2(jsonb,uuid,integer) to authenticated;
comment on function public.superadmin_location_consumer_bindings_v2(jsonb,uuid,integer) is
 'Owner-only, reauthorized historical reservation bindings. Does not describe a current consumer location selection.';
commit;
