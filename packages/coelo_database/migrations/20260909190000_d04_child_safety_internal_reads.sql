-- D04 LOCAL CANDIDATE: internal reads only; no deployment authorization.
-- Sources: approved specs 030 and 039; ADR 0019 (including 2026-09-01 AAL1 addendum).
-- Legacy source queries: 20260812002200. No legacy function or shared helper changes.
-- Global platform scope preserves the previous platform-read boundary; capability,
-- not Owner role, authorizes. Institutional scope requires its own filtered contract.
-- Private data functions have no client/service execute grant. Only the audited
-- dispatcher can expose their result. No internal identity is linked to People.
begin;

-- Nominal preflight. Abort rather than silently substitute missing foundation.
do $preflight$
declare dependency text; target text;
begin
  if to_regtype('app_private.superadmin_internal_context') is null then
    raise exception 'D04 dependency missing: internal context type';
  end if;
  foreach dependency in array array[
    'app_private.require_superadmin_internal_context(text)',
    'app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)',
    'app_private.superadmin_internal_error_envelope(text,uuid)',
    'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)',
    'app_private.validate_child_safety_context()'] loop
    if to_regprocedure(dependency) is null then
      raise exception 'D04 dependency missing: %',dependency;
    end if;
  end loop;
  -- Auth45 contains the helper but predates its invalid-argument contract.
  -- Refuse that dependency instead of installing wrappers with masked errors.
  if (app_private.superadmin_internal_error_envelope('SAI_INVALID_ARGUMENT',null)
      #>>'{error,code}') is distinct from 'SAI_INVALID_ARGUMENT' then
    raise exception 'D04 dependency requires SAI_INVALID_ARGUMENT envelope';
  end if;
  foreach target in array array['authorized_people','authorized_person_authorizations',
    'authorized_person_authorization_capabilities','child_safety_restrictions','child_safety_alerts','child_safety_evidence'] loop
    if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname=target and c.relrowsecurity and c.relforcerowsecurity)
      or has_table_privilege('authenticated','public.'||target,'SELECT,INSERT,UPDATE,DELETE') then
      raise exception 'D04 dependency requires forced RLS and no direct client grant: %',target;
    end if;
  end loop;
  foreach target in array array['authorized_person_authorizations','child_safety_restrictions','child_safety_alerts','child_safety_evidence'] loop
    if not exists(select 1 from pg_trigger t
      where t.tgrelid=to_regclass('public.'||target) and not t.tgisinternal
        and t.tgname=target||'_validate' and t.tgenabled in ('O','A')
        and t.tgfoid='app_private.validate_child_safety_context()'::regprocedure) then
      raise exception 'D04 context integrity trigger missing: %',target;
    end if;
  end loop;
  if exists(select 1 from pg_proc p, lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
    where p.oid='app_private.require_superadmin_internal_context(text)'::regprocedure
      and a.privilege_type='EXECUTE' and (a.grantee=0 or a.grantee in
        (select oid from pg_roles where rolname in ('anon','authenticated','service_role')))) then
    raise exception 'D04 internal context helper ACL is not private';
  end if;
end;
$preflight$;
create temporary table d04_safety_legacy_snapshot on commit drop as
select p.oid,pg_get_functiondef(p.oid) definition,p.proacl,p.proowner
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','app_private')
  and (p.proname like '%child_safety%' or p.proname='require_superadmin_internal_context');

create function app_private.d04_child_safety_directory_data_v2(
  p_search text,p_institution_ids uuid[],p_unit_ids uuid[],p_segment text,
  p_limit integer,p_cursor jsonb
) returns jsonb language plpgsql stable security definer set search_path=''
as $$ declare result jsonb; cursor_name text; cursor_context uuid; cursor_unit uuid; begin
  if coalesce(array_ndims(p_institution_ids),1)>1 or coalesce(array_ndims(p_unit_ids),1)>1 then
    raise invalid_parameter_value using message='invalid child safety filter dimensions';
  end if;
  if cardinality(coalesce(p_institution_ids,'{}'::uuid[]))>100
     or cardinality(coalesce(p_unit_ids,'{}'::uuid[]))>100
     or array_position(p_institution_ids,null) is not null
     or array_position(p_unit_ids,null) is not null then
    raise invalid_parameter_value using message='invalid child safety filter size';
  end if;
  if p_cursor is not null and p_cursor<>'{}'::jsonb and (
    jsonb_typeof(p_cursor) is distinct from 'object'
    or p_cursor-array['name','child_context_id','unit_id']<>'{}'::jsonb
    or jsonb_typeof(p_cursor->'name') is distinct from 'string'
    or jsonb_typeof(p_cursor->'child_context_id') is distinct from 'string'
    or jsonb_typeof(p_cursor->'unit_id') is distinct from 'string'
    or p_cursor->>'name'='' or p_cursor->>'child_context_id'='' or p_cursor->>'unit_id'=''
  ) then raise invalid_parameter_value using message='invalid child safety cursor shape'; end if;
  if char_length(coalesce(p_search,''))>120
     or p_segment is null
     or p_segment not in ('all','awaiting_approval','attention','authorized','without_authorization')
     or p_limit is null or p_limit not in (8,11,20,50,100)
     or (p_cursor is not null and jsonb_typeof(p_cursor)<>'object') then
    raise invalid_parameter_value using message='invalid child safety directory filters';
  end if;
  begin
    cursor_name:=nullif(p_cursor->>'name','');
    cursor_context:=nullif(p_cursor->>'child_context_id','')::uuid;
    cursor_unit:=nullif(p_cursor->>'unit_id','')::uuid;
  exception when others then
    raise invalid_parameter_value using message='invalid child safety cursor';
  end;
  if (cursor_name is null)<>(cursor_context is null)
     or (cursor_name is null)<>(cursor_unit is null) then
    raise invalid_parameter_value using message='invalid child safety cursor';
  end if;
  if exists (
    select 1 from public.units u where u.id=any(coalesce(p_unit_ids,'{}'::uuid[]))
      and cardinality(coalesce(p_institution_ids,'{}'::uuid[]))>0
      and not u.institution_id=any(p_institution_ids)
  ) then raise invalid_parameter_value using message='invalid child safety hierarchy'; end if;

  with selected_units as (
    select distinct on (l.child_context_id) l.child_context_id,l.unit_id
    from public.child_unit_links l join public.units u on u.id=l.unit_id
    where l.status in ('active','awaiting_allocation')
      and (cardinality(coalesce(p_unit_ids,'{}'::uuid[]))=0 or l.unit_id=any(p_unit_ids))
      and (cardinality(coalesce(p_institution_ids,'{}'::uuid[]))=0
        or u.institution_id=any(p_institution_ids))
    order by l.child_context_id,case when l.status='active' then 0 else 1 end,l.unit_id
  ), scoped as (
    select c.id child_context_id,p.id child_id,p.display_name child_name,
      lower(p.display_name) sort_name,coalesce(c.local_identifier,'') internal_id,
      i.id institution_id,i.public_name institution_name,u.id unit_id,u.name unit_name,
      count(a.id) authorization_count,
      coalesce(bool_or(a.decision_status='pending') filter(where a.id is not null),false) has_pending,
      coalesce(bool_or(a.decision_status='approved' and a.status='active'
        and a.revoked_at is null and a.valid_from<=current_date
        and (a.valid_until is null or a.valid_until>=current_date))
        filter(where a.id is not null),false) has_authorized,
      exists(select 1 from public.child_safety_restrictions r
        where r.child_context_id=c.id and r.unit_id=u.id and r.status='active'
          and r.revoked_at is null and r.valid_from<=now()
          and (r.valid_until is null or r.valid_until>now()))
      or exists(select 1 from public.child_safety_alerts al
        where al.child_context_id=c.id and al.unit_id=u.id
          and al.status in ('open','acknowledged')) has_attention,
      max(a.updated_at) last_safety_change
    from public.child_contexts c
    join public.people p on p.id=c.child_person_id and p.person_type='child'
    join public.institutions i on i.id=c.institution_id
    join selected_units su on su.child_context_id=c.id
    join public.units u on u.id=su.unit_id and u.institution_id=c.institution_id
    left join public.authorized_person_authorizations a
      on a.child_context_id=c.id and a.unit_id=u.id
    where c.status='active' and p.status='active'
      and (nullif(btrim(p_search),'') is null
        or lower(p.display_name) like '%'||lower(btrim(p_search))||'%'
        or lower(coalesce(c.local_identifier,'')) like '%'||lower(btrim(p_search))||'%')
    group by c.id,p.id,p.display_name,c.local_identifier,i.id,i.public_name,u.id,u.name
  ), segmented as (
    select *,case when has_pending then 'awaiting_approval'
      when has_attention then 'attention' when has_authorized then 'authorized'
      else 'without_authorization' end segment from scoped
  ), filtered as (
    select * from segmented where p_segment='all' or segment=p_segment
  ), page_plus_one as (
    select * from filtered where cursor_name is null
      or (sort_name,child_context_id,unit_id)>(cursor_name,cursor_context,cursor_unit)
    order by sort_name,child_context_id,unit_id limit p_limit+1
  ), page_rows as (
    select * from page_plus_one order by sort_name,child_context_id,unit_id limit p_limit
  ), last_row as (
    select * from page_rows order by sort_name desc,child_context_id desc,unit_id desc limit 1
  )
  select jsonb_build_object(
    'items',coalesce((select jsonb_agg(jsonb_build_object(
      'child_id',child_id,'child_context_id',child_context_id,'child_name',child_name,
      'internal_id',internal_id,'institution_id',institution_id,'institution_name',institution_name,
      'unit_id',unit_id,'unit_name',unit_name,'authorization_count',authorization_count,
      'segment',segment,'last_safety_change',last_safety_change
    ) order by sort_name,child_context_id,unit_id) from page_rows),'[]'::jsonb),
    'total_count',(select count(*) from filtered),
    'segment_counts',jsonb_build_object(
      'all',(select count(*) from segmented),
      'awaiting_approval',(select count(*) from segmented where segment='awaiting_approval'),
      'attention',(select count(*) from segmented where segment='attention'),
      'authorized',(select count(*) from segmented where segment='authorized'),
      'without_authorization',(select count(*) from segmented where segment='without_authorization')),
    'next_cursor',case when (select count(*) from page_plus_one)>p_limit then
      (select jsonb_build_object('name',sort_name,'child_context_id',child_context_id,'unit_id',unit_id)
       from last_row) else null end,
    'can_create',false
  ) into result;
  return result;
end $$;

create function app_private.d04_child_safety_search_children_data_v2(p_search text,p_limit integer)
returns jsonb language plpgsql stable security definer set search_path=''
as $$ begin
  if char_length(btrim(coalesce(p_search,'')))<2 or char_length(p_search)>120
     or p_limit is null or p_limit not between 1 and 20 then
    raise invalid_parameter_value using message='invalid child search';
  end if;
  return coalesce((select jsonb_agg(item order by item->>'display_name') from (
    select jsonb_build_object('id',p.id,'display_name',p.display_name,
      'internal_id',coalesce(c.local_identifier,''),
      'contexts',jsonb_agg(jsonb_build_object('child_context_id',c.id,
        'institution_id',i.id,'institution_name',i.public_name,
        'unit_id',u.id,'unit_name',u.name) order by i.public_name,u.name)) item
    from public.people p
    join public.child_contexts c on c.child_person_id=p.id and c.status='active'
    join public.institutions i on i.id=c.institution_id
    join public.child_unit_links l on l.child_context_id=c.id
      and l.status in ('active','awaiting_allocation')
    join public.units u on u.id=l.unit_id and u.institution_id=c.institution_id
    where p.person_type='child' and p.status='active'
      and (lower(p.display_name) like '%'||lower(btrim(p_search))||'%'
        or lower(coalesce(c.local_identifier,'')) like '%'||lower(btrim(p_search))||'%')
    group by p.id,p.display_name,c.local_identifier
    order by p.display_name,p.id limit p_limit
  ) rows),'[]'::jsonb);
end $$;

create function app_private.d04_child_safety_get_data_v2(p_child_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$ declare result jsonb; begin
  select jsonb_build_object('child_id',p.id,'child_name',p.display_name,
    'contexts',coalesce((select jsonb_agg(jsonb_build_object(
      'child_context_id',c.id,'internal_id',coalesce(c.local_identifier,''),
      'institution_id',i.id,'institution_name',i.public_name,'unit_id',u.id,'unit_name',u.name)
      order by i.public_name,u.name)
      from public.child_contexts c join public.institutions i on i.id=c.institution_id
      join public.child_unit_links l on l.child_context_id=c.id
        and l.status in ('active','awaiting_allocation')
      join public.units u on u.id=l.unit_id and u.institution_id=c.institution_id
      where c.child_person_id=p.id and c.status='active'),'[]'::jsonb),
    'authorizations',coalesce((select jsonb_agg(jsonb_build_object(
      'id',a.id,'child_context_id',a.child_context_id,'unit_id',a.unit_id,
      'person_id',ap.person_id,'name',ap.display_name,'relationship_code',rt.code,
      'relationship_detail',a.relationship_detail,
      'capability_codes',(select coalesce(jsonb_agg(cap.capability_code order by cap.capability_code),'[]')
        from public.authorized_person_authorization_capabilities cap where cap.authorization_id=a.id),
      'decision_status',a.decision_status,'lifecycle_status',a.status,
      'valid_from',a.valid_from,'valid_until',a.valid_until,'version',a.version,
      'request_reason',a.request_reason,'decision_reason',a.decision_reason)
      order by a.created_at desc)
      from public.authorized_person_authorizations a
      join public.authorized_people ap on ap.id=a.authorized_person_id
      join public.family_relationship_types rt on rt.id=a.relationship_type_id
      join public.child_contexts c on c.id=a.child_context_id
      where c.child_person_id=p.id),'[]'::jsonb),
    'restrictions',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'institution_id',r.institution_id,'unit_id',r.unit_id,'child_context_id',r.child_context_id,'restriction_code',r.restriction_code,'title',r.title,'description',r.description,'severity',r.severity,'reason',r.reason,'valid_from',r.valid_from,'valid_until',r.valid_until,'status',r.status,'version',r.version,'created_at',r.created_at,'updated_at',r.updated_at,'revoked_at',r.revoked_at))
      from public.child_safety_restrictions r join public.child_contexts c on c.id=r.child_context_id
      where c.child_person_id=p.id),'[]'::jsonb),
    'alerts',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'institution_id',a.institution_id,'unit_id',a.unit_id,'child_context_id',a.child_context_id,'authorization_id',a.authorization_id,'restriction_id',a.restriction_id,'event_code',a.event_code,'severity',a.severity,'status',a.status,'reason',a.reason,'acknowledged_at',a.acknowledged_at,'resolution_reason',a.resolution_reason,'version',a.version,'created_at',a.created_at,'updated_at',a.updated_at))
      from public.child_safety_alerts a join public.child_contexts c on c.id=a.child_context_id
      where c.child_person_id=p.id),'[]'::jsonb),
    'evidence',coalesce((select jsonb_agg(jsonb_build_object(
      'id',e.id,'child_context_id',e.child_context_id,'authorization_id',e.authorization_id,
      'restriction_id',e.restriction_id,'alert_id',e.alert_id,'file_name',e.file_name,
      'mime_type',e.mime_type,'size_bytes',e.size_bytes,'status',e.status,'created_at',e.created_at)
      order by e.created_at desc)
      from public.child_safety_evidence e join public.child_contexts c on c.id=e.child_context_id
      where c.child_person_id=p.id and e.status='active'),'[]'::jsonb)
  ) into result from public.people p
  where p.id=p_child_id and p.person_type='child' and p.status='active';
  if result is null then raise no_data_found using message='child safety record unavailable'; end if;
  return result;
end $$;

revoke all on function
  app_private.d04_child_safety_directory_data_v2(text,uuid[],uuid[],text,integer,jsonb),
  app_private.d04_child_safety_search_children_data_v2(text,integer),
  app_private.d04_child_safety_get_data_v2(uuid)
from public,anon,authenticated,service_role;

create function app_private.d04_child_safety_internal_read_v2(
  p_operation text,p_search text,p_institution_ids uuid[],p_unit_ids uuid[],
  p_segment text,p_limit integer,p_cursor jsonb,p_child_id uuid
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  ctx app_private.superadmin_internal_context;
  final_ctx app_private.superadmin_internal_context;
  capability constant text := 'child_safety.read';
  action_code text;
  correlation uuid := gen_random_uuid();
  error_code text;
  result jsonb;
begin
  -- Operation codes are selected by fixed public wrappers, never supplied by UI.
  action_code := case p_operation
    when 'directory' then 'superadmin.child-safety.list'
    when 'search_children' then 'superadmin.child-safety.search-children'
    when 'get' then 'superadmin.child-safety.child' end;
  begin
    select * into strict ctx
      from app_private.require_superadmin_internal_context(capability);
    if ctx.scope_kind is distinct from 'platform'
      or ctx.scope_institution_id is not null
      or ctx.aal is null or ctx.aal not in ('aal1','aal2') then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    if action_code is null then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    -- No domain table is read until identity, session, capability and scope pass.
    case p_operation
      when 'directory' then
        result := app_private.d04_child_safety_directory_data_v2(
          p_search,p_institution_ids,p_unit_ids,p_segment,p_limit,p_cursor);
      when 'search_children' then
        result := app_private.d04_child_safety_search_children_data_v2(p_search,p_limit);
      when 'get' then
        if p_child_id is null then
          raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
        end if;
        result := app_private.d04_child_safety_get_data_v2(p_child_id);
    end case;
    select * into strict final_ctx
      from app_private.require_superadmin_internal_context(capability);
    if (ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
        ctx.session_id,ctx.platform_role_id,ctx.scope_kind,ctx.scope_institution_id)
      is distinct from
       (final_ctx.internal_identity_id,final_ctx.internal_auth_link_id,final_ctx.internal_membership_id,
        final_ctx.session_id,final_ctx.platform_role_id,final_ctx.scope_kind,final_ctx.scope_institution_id)
      or not exists(select 1 from auth.sessions s
        where s.id=final_ctx.session_id and s.user_id=final_ctx.auth_user_id
          and (s.not_after is null or s.not_after>clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
  exception
    when no_data_found then error_code := 'SAI_PERMISSION_DENIED';
    when invalid_parameter_value or invalid_text_representation
      or numeric_value_out_of_range then error_code := 'SAI_INVALID_ARGUMENT';
    when others then
      get stacked diagnostics error_code=pg_exception_detail;
      error_code := app_private.superadmin_internal_error_envelope(error_code,correlation)#>>'{error,code}';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      capability,coalesce(action_code,'superadmin.child-safety.read'),error_code,correlation);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  -- Audit contains opaque actor/resource IDs only; never search or child payload.
  -- Audit failure aborts the RPC instead of returning unaudited data.
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,capability,ctx.aal,action_code,'success',null,correlation,null,
    case when p_operation='get' then 'child' else 'child_safety_directory' end,
    case when p_operation='get' then p_child_id else null end);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end;
$$;
revoke all on function app_private.d04_child_safety_internal_read_v2(
  text,text,uuid[],uuid[],text,integer,jsonb,uuid) from public,anon,authenticated,service_role;

create function public.superadmin_child_safety_directory_v2(
  p_search text default '',p_institution_ids uuid[] default '{}',p_unit_ids uuid[] default '{}',
  p_segment text default 'all',p_limit integer default 11,p_cursor jsonb default null
) returns jsonb language sql volatile security definer set search_path='' as $$
  select app_private.d04_child_safety_internal_read_v2('directory',$1,$2,$3,$4,$5,$6,null);
$$;
create function public.superadmin_child_safety_search_children_v2(p_search text,p_limit integer default 20)
returns jsonb language sql volatile security definer set search_path='' as $$
  select app_private.d04_child_safety_internal_read_v2('search_children',$1,null,null,null,$2,null,null);
$$;
create function public.superadmin_child_safety_get_v2(p_child_id uuid)
returns jsonb language sql volatile security definer set search_path='' as $$
  select app_private.d04_child_safety_internal_read_v2('get',null,null,null,null,null,null,$1);
$$;
revoke all on function
  public.superadmin_child_safety_directory_v2(text,uuid[],uuid[],text,integer,jsonb),
  public.superadmin_child_safety_search_children_v2(text,integer),
  public.superadmin_child_safety_get_v2(uuid)
from public,anon,authenticated,service_role;
grant execute on function
  public.superadmin_child_safety_directory_v2(text,uuid[],uuid[],text,integer,jsonb),
  public.superadmin_child_safety_search_children_v2(text,integer),
  public.superadmin_child_safety_get_v2(uuid)
to authenticated;

do $postflight$
declare item record; expected_owner oid;
begin
  select proowner into strict expected_owner from pg_proc
    where oid='app_private.require_superadmin_internal_context(text)'::regprocedure;
  for item in select p.*,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='app_private' and p.proname in ('d04_child_safety_directory_data_v2',
      'd04_child_safety_search_children_data_v2','d04_child_safety_get_data_v2','d04_child_safety_internal_read_v2'))
      or (n.nspname='public' and p.proname in ('superadmin_child_safety_directory_v2',
        'superadmin_child_safety_search_children_v2','superadmin_child_safety_get_v2')) loop
    if not item.prosecdef or item.proowner<>expected_owner
      or not coalesce('search_path=""'=any(item.proconfig),false) then
      raise exception 'D04 function owner/security configuration mismatch: %',item.proname;
    end if;
    if exists(select 1 from aclexplode(coalesce(item.proacl,acldefault('f',item.proowner))) a
      where a.privilege_type='EXECUTE' and a.grantee<>expected_owner
        and (item.nspname='app_private' or a.grantee<>(select oid from pg_roles where rolname='authenticated'))) then
      raise exception 'D04 unexpected execute grant: %',item.proname;
    end if;
    if item.nspname='public' and not has_function_privilege('authenticated',item.oid,'EXECUTE') then
      raise exception 'D04 missing public wrapper grant: %',item.proname;
    end if;
  end loop;
  if exists(select 1 from d04_safety_legacy_snapshot s left join pg_proc p on p.oid=s.oid
    where p.oid is null or pg_get_functiondef(p.oid) is distinct from s.definition
      or p.proacl is distinct from s.proacl or p.proowner is distinct from s.proowner) then
    raise exception 'D04 legacy routine or ACL changed';
  end if;
end;
$postflight$;
commit;
