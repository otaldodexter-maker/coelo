begin;

-- This migration deliberately exposes no executable client surface. Task 4 grants
-- only the nominal wrappers after the final RLS review.

create function app_private.activity_v2_success_envelope(p_data jsonb)
returns jsonb language sql stable security invoker set search_path=''
as $$select pg_catalog.jsonb_build_object('ok',true,'data',p_data,'error',null)$$;

create function app_private.activity_v2_require_context(
  p_permission_code text,p_institution_id uuid default null
) returns app_private.superadmin_internal_context
language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context;
begin
  select * into strict ctx from app_private.require_superadmin_internal_context(p_permission_code);
  if p_institution_id is not null then
    if not exists(select 1 from public.institutions i where i.id=p_institution_id)
       or (ctx.scope_kind='institution' and ctx.scope_institution_id is distinct from p_institution_id) then
      raise insufficient_privilege using message='institution scope denied',detail='SAI_PERMISSION_DENIED';
    end if;
    ctx.resolved_institution_id:=p_institution_id;
  end if;
  return ctx;
end $$;

create or replace function app_private.audit_mask_payload(p_value jsonb)
returns jsonb language plpgsql immutable security invoker set search_path='' as $$
declare result jsonb:='{}'::jsonb; item record; safe_counts jsonb;
begin
 if p_value is null then return null; end if;
 if jsonb_typeof(p_value)<>'object' then return null; end if;
 for item in select * from jsonb_each(p_value) loop
  if item.key in('id','scope_id','institution_id','unit_id','group_id','child_context_id','activity_id')
   and (jsonb_typeof(item.value)='null' or (jsonb_typeof(item.value)='string' and trim(both '"' from item.value::text)~*'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')) then result:=result||jsonb_build_object(item.key,item.value);
  elsif item.key in('status','role_code','scope_kind','format','state') and jsonb_typeof(item.value)='string' and trim(both '"' from item.value::text)~'^[A-Za-z0-9][A-Za-z0-9._:-]{0,79}$' then result:=result||jsonb_build_object(item.key,item.value);
  elsif item.key in('version','management_version','row_count','valid_count','rejected_count','created_count','updated_count','linked_count','ignored_count') and jsonb_typeof(item.value)='number' then result:=result||jsonb_build_object(item.key,item.value);
  elsif item.key in('pii_included','replayed') and jsonb_typeof(item.value)='boolean' then result:=result||jsonb_build_object(item.key,item.value);
  elsif item.key in('created_at','updated_at') and jsonb_typeof(item.value)='string' and trim(both '"' from item.value::text)~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.+-]{8,35}Z?$' then result:=result||jsonb_build_object(item.key,item.value);
  elsif item.key='counts' and jsonb_typeof(item.value)='object' then
   select coalesce(jsonb_object_agg(entry.key,entry.value),'{}'::jsonb) into safe_counts from jsonb_each(item.value) entry
    where entry.key in('units','groups','participants','professionals','settings','actions') and jsonb_typeof(entry.value)='number' and (entry.value#>>'{}')::numeric>=0 and (entry.value#>>'{}')::numeric=trunc((entry.value#>>'{}')::numeric);
   result:=result||jsonb_build_object('counts',safe_counts);
  end if;
 end loop;
 return result;
end $$;

create function app_private.audit_append_superadmin_internal(
 p_internal_identity_id uuid,p_internal_auth_link_id uuid,p_internal_membership_id uuid,p_session_id uuid,
 p_permission_code text,p_aal text,p_action_code text,p_outcome public.audit_outcome,p_reason_code text,
 p_correlation_id uuid,p_institution_id uuid,p_object_type text,p_object_id uuid,p_after_json jsonb
) returns uuid language plpgsql volatile security definer set search_path='' as $$
declare event_id uuid:=gen_random_uuid();
begin
 if not exists(select 1 from app_private.superadmin_internal_auth_links l join app_private.superadmin_internal_memberships m on m.id=p_internal_membership_id and m.internal_identity_id=l.internal_identity_id where l.id=p_internal_auth_link_id and l.internal_identity_id=p_internal_identity_id) then raise foreign_key_violation using message='inconsistent internal audit actor'; end if;
 insert into audit.audit_logs(id,hash_version,actor_kind,actor_internal_identity_id,actor_internal_auth_link_id,actor_internal_membership_id,session_id_hash,permission_code,mfa_aal,action_code,object_type,object_id,institution_id,outcome,reason_code,correlation_id,origin,context_kind,context_id,after_json)
 values(event_id,2,'superadmin_internal',p_internal_identity_id,p_internal_auth_link_id,p_internal_membership_id,extensions.digest(pg_catalog.convert_to(p_session_id::text,'UTF8'),'sha256'),p_permission_code,p_aal,p_action_code,p_object_type,p_object_id,p_institution_id,p_outcome,p_reason_code,p_correlation_id,'database',case when p_institution_id is null then 'global' else 'institution' end,p_institution_id,p_after_json);
 return event_id;
end $$;

create function app_private.activity_v2_normalize_error(p_code text)
returns text language sql immutable security invoker set search_path='' as $$
 select case when p_code in(
  'ACTIVITY_INVALID_INPUT','ACTIVITY_INVALID_REFERENCE','ACTIVITY_NOT_FOUND',
  'ACTIVITY_INVALID_STATE','ACTIVITY_DEPENDENCIES_ACTIVE','SAI_AUTH_REQUIRED',
  'SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
  'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED',
  'SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE','SAI_INTERNAL_ERROR'
 ) then p_code else 'SAI_INTERNAL_ERROR' end
$$;

create function app_private.activity_v2_denied_envelope(
  p_permission_code text,p_action_code text,p_error_code text,
  p_correlation_id uuid,p_institution_id uuid default null
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare normalized_code text:=app_private.activity_v2_normalize_error(p_error_code);
 safe_institution_id uuid;
begin
  select p_institution_id into safe_institution_id
  where p_institution_id is not null
    and exists(select 1 from public.institutions i where i.id=p_institution_id)
    and exists(
      select 1
      from app_private.superadmin_internal_auth_links l
      join app_private.superadmin_internal_memberships m
        on m.internal_identity_id=l.internal_identity_id
       and m.status='active' and m.revoked_at is null
      where l.auth_user_id=auth.uid() and l.status='active' and l.revoked_at is null
        and (m.scope_kind='platform' or (m.scope_kind='institution' and m.scope_institution_id=p_institution_id))
    );
  perform app_private.audit_superadmin_internal_denial_if_identified(
    p_permission_code,p_action_code,normalized_code,p_correlation_id,safe_institution_id);
  return app_private.activity_v2_error_envelope(normalized_code,p_correlation_id);
end $$;

create function app_private.activity_v2_set_marker(
 p_ctx app_private.superadmin_internal_context,p_permission_code text,p_action_code text,p_correlation_id uuid
) returns void language plpgsql volatile security definer set search_path='' as $$
begin
  perform pg_catalog.set_config('app_private.activity_v2_internal_marker',pg_catalog.jsonb_build_object(
   'internal_identity_id',p_ctx.internal_identity_id,'internal_auth_link_id',p_ctx.internal_auth_link_id,
   'internal_membership_id',p_ctx.internal_membership_id,'auth_user_id',p_ctx.auth_user_id,
   'session_id',p_ctx.session_id,'permission_code',p_permission_code,'action_code',p_action_code,
   'correlation_id',p_correlation_id)::text,true);
end $$;

create or replace function app_private.require_activity_v2_internal_marker()
returns void language plpgsql security definer set search_path='' as $$
declare marker jsonb; permission_code text; action_code text; marker_correlation uuid;
 context_record app_private.superadmin_internal_context;
begin
 begin marker:=current_setting('app_private.activity_v2_internal_marker',true)::jsonb;
 exception when others then raise insufficient_privilege using message='activity internal marker denied'; end;
 permission_code:=marker->>'permission_code'; action_code:=marker->>'action_code';
 begin marker_correlation:=(marker->>'correlation_id')::uuid;
 exception when others then raise insufficient_privilege using message='activity internal marker denied'; end;
 if marker is null or jsonb_typeof(marker)<>'object'
  or (select count(*) from jsonb_object_keys(marker))<>8
  or permission_code is null or btrim(permission_code)='' or action_code is null or btrim(action_code)='' or marker_correlation is null
  or permission_code not in('activities.create','activities.manage','activities.link_units','activities.link_groups','activities.assign_people','activities.manage_permissions')
  or (permission_code,action_code) not in(
   ('activities.create','create'),('activities.manage','manage'),('activities.link_units','link_units'),
   ('activities.link_groups','link_groups'),('activities.assign_people','assign_people'),
   ('activities.manage_permissions','manage_permissions')) then
  raise insufficient_privilege using message='activity internal marker denied';
 end if;
 select * into strict context_record from app_private.require_superadmin_internal_context(permission_code);
 if not exists(select 1 from auth.sessions session_record where session_record.id=context_record.session_id and session_record.user_id=context_record.auth_user_id and (session_record.not_after is null or session_record.not_after>now()))
  or marker->>'internal_identity_id' is distinct from context_record.internal_identity_id::text
  or marker->>'internal_auth_link_id' is distinct from context_record.internal_auth_link_id::text
  or marker->>'internal_membership_id' is distinct from context_record.internal_membership_id::text
  or marker->>'auth_user_id' is distinct from context_record.auth_user_id::text
  or marker->>'session_id' is distinct from context_record.session_id::text then
  raise insufficient_privilege using message='activity internal marker denied';
 end if;
end $$;

create or replace function app_private.audit_activity_change()
returns trigger language plpgsql security definer set search_path='' as $$
declare row_data jsonb; before_data jsonb; after_data jsonb; target_institution_id uuid;
 target_object_id uuid; actor_person_id uuid; actor_membership_id uuid; marker_text text;
 marker jsonb; fresh app_private.superadmin_internal_context; suppress_legacy boolean:=false;
begin
  before_data:=case when tg_op in('UPDATE','DELETE') then to_jsonb(old) else null end;
  after_data:=case when tg_op in('INSERT','UPDATE') then to_jsonb(new) else null end;
  row_data:=coalesce(after_data,before_data); target_object_id:=(row_data->>'id')::uuid;
  if row_data?'institution_id' then target_institution_id:=(row_data->>'institution_id')::uuid;
  elsif tg_table_name='activity_permission_profile_capabilities' then select p.institution_id into target_institution_id from public.activity_permission_profiles p where p.id=(row_data->>'profile_id')::uuid;
  elsif tg_table_name='activity_assignment_permission_overrides' then select a.institution_id into target_institution_id from public.activity_group_assignments a where a.id=(row_data->>'assignment_id')::uuid; end if;
  marker_text:=nullif(current_setting('app_private.activity_v2_internal_marker',true),'');
  if marker_text is not null then
    begin
      marker:=marker_text::jsonb;
      perform app_private.require_activity_v2_internal_marker();
      select * into strict fresh from app_private.activity_v2_require_context(marker->>'permission_code',target_institution_id);
      suppress_legacy:=marker->>'internal_identity_id'=fresh.internal_identity_id::text
       and marker->>'internal_auth_link_id'=fresh.internal_auth_link_id::text
       and marker->>'internal_membership_id'=fresh.internal_membership_id::text
       and marker->>'auth_user_id'=fresh.auth_user_id::text
       and marker->>'session_id'=fresh.session_id::text;
    exception when others then suppress_legacy:=false; end;
    if suppress_legacy then return coalesce(new,old); end if;
  end if;
  actor_person_id:=app_private.current_person_id();
  select m.id into actor_membership_id from public.institution_memberships m where m.person_id=actor_person_id and m.institution_id=target_institution_id and m.status='active' and m.revoked_at is null limit 1;
  insert into audit.audit_logs(actor_person_id,actor_membership_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,reason,before_json,after_json)
  values(actor_person_id,actor_membership_id,auth.jwt()->>'aal','activity_'||lower(tg_op),tg_table_name,target_object_id,target_institution_id,'success',nullif(current_setting('coelo.audit_reason',true),''),before_data,after_data);
  return coalesce(new,old);
end $$;

create function app_private.activity_v2_append_audit(
 p_ctx app_private.superadmin_internal_context,p_institution_id uuid,p_activity_id uuid,
 p_permission_code text,p_action_code text,p_counts jsonb
) returns uuid language plpgsql volatile security definer set search_path='' as $$
declare marker jsonb; correlation uuid; audit_id uuid;
begin
  marker:=current_setting('app_private.activity_v2_internal_marker',true)::jsonb;
  correlation:=(marker->>'correlation_id')::uuid;
  if correlation is null or jsonb_typeof(p_counts) is distinct from 'object'
   or exists(select 1 from jsonb_each(p_counts) entry where entry.key not in('units','groups','participants','professionals','settings','actions') or jsonb_typeof(entry.value)<>'number' or (entry.value#>>'{}')::numeric<0 or (entry.value#>>'{}')::numeric<>trunc((entry.value#>>'{}')::numeric))
  then raise exception using message='activity audit context missing'; end if;
  select app_private.audit_append_superadmin_internal(
   p_ctx.internal_identity_id,p_ctx.internal_auth_link_id,p_ctx.internal_membership_id,p_ctx.session_id,
   p_permission_code,p_ctx.aal,p_action_code,'success',null,correlation,p_institution_id,'activity',p_activity_id,
   pg_catalog.jsonb_build_object('status',activity.status,'management_version',activity.management_version,'counts',p_counts))
  into audit_id from public.activity_definitions activity where activity.id=p_activity_id and activity.institution_id=p_institution_id;
  if audit_id is null then raise exception using message='activity audit append failed'; end if;
  return correlation;
end $$;

create function app_private.activity_v2_finish_command(
 p_ctx app_private.superadmin_internal_context,p_request_id uuid,p_institution_id uuid,p_activity_id uuid,
 p_command_kind text,p_request_hash bytea,p_version bigint,p_status text,p_correlation_id uuid,p_counts jsonb
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
begin
  insert into app_private.superadmin_internal_activity_command_receipts(
   request_id,internal_identity_id,institution_id,activity_id,command_kind,request_hash,
   resulting_version,resulting_status,correlation_id,result_counts)
  values(p_request_id,p_ctx.internal_identity_id,p_institution_id,p_activity_id,p_command_kind,p_request_hash,
   p_version,p_status,p_correlation_id,coalesce(p_counts,'{}'::jsonb));
  return app_private.activity_v2_success_envelope(pg_catalog.jsonb_build_object(
   'activity_id',p_activity_id,'management_version',p_version,'status',p_status,
   'correlation_id',p_correlation_id,'replayed',false));
end $$;

create function app_private.activity_v2_replay_or_error(
 p_ctx app_private.superadmin_internal_context,p_request_id uuid,p_institution_id uuid,p_activity_id uuid,
 p_command_kind text,p_request_hash bytea,p_correlation_id uuid
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare r app_private.superadmin_internal_activity_command_receipts%rowtype;
 fresh app_private.superadmin_internal_context; permission_code text;
begin
  permission_code:=case p_command_kind when 'activity.create' then 'activities.create'
   when 'activity.update' then 'activities.manage' when 'activity.publish' then 'activities.manage'
   when 'activity.set_units' then 'activities.link_units' when 'activity.set_groups' then 'activities.link_groups'
   when 'activity.set_participants' then 'activities.assign_people' when 'activity.set_professionals' then 'activities.assign_people'
   when 'activity.set_permissions' then 'activities.manage_permissions' end;
  if permission_code is null then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
  select * into strict fresh from app_private.activity_v2_require_context(permission_code,p_institution_id);
  if fresh.internal_identity_id<>p_ctx.internal_identity_id or fresh.internal_auth_link_id<>p_ctx.internal_auth_link_id
     or fresh.internal_membership_id<>p_ctx.internal_membership_id or fresh.session_id<>p_ctx.session_id then
    raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
  select * into r from app_private.superadmin_internal_activity_command_receipts x where x.request_id=p_request_id;
  if r.request_id is null then return null; end if;
  if r.internal_identity_id<>p_ctx.internal_identity_id then
    raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
  end if;
  if r.institution_id is distinct from p_institution_id
     or (p_command_kind<>'activity.create' and r.activity_id is distinct from p_activity_id)
     or r.command_kind<>p_command_kind or r.request_hash<>p_request_hash then
    raise serialization_failure using detail='SAI_CONCURRENT_CHANGE';
  end if;
  return app_private.activity_v2_success_envelope(pg_catalog.jsonb_build_object(
   'activity_id',r.activity_id,'management_version',r.resulting_version,'status',r.resulting_status,
   'correlation_id',r.correlation_id,'replayed',true));
end $$;

create function app_private.activity_v2_effective_permission(
 p_prohibited text,p_legacy_deny text,p_action text,p_legacy_allow text,p_policy text,p_setting text,
 p_default text,p_profile text
) returns text language sql immutable security invoker set search_path='' as $$
 select case when p_prohibited='prohibited' then 'none'
  when p_legacy_deny='deny' then 'none'
  when p_action in('both','edit','view','none') then p_action
  when p_legacy_allow='allow' then 'both'
  when p_policy='required' then 'both'
  when p_setting='false' then 'none'
  when p_setting='true' then 'both'
  when p_default='default_on' then 'both'
  when p_default='default_off' then 'none'
  when p_profile='allow' then 'both'
  else 'none' end
$$;

create or replace function app_private.has_activity_capability(
  target_activity_id uuid,target_group_id uuid,target_capability_code text
) returns boolean language sql stable security definer set search_path='' as $$
 with current_assignment as(
  select assignment.id,group_link.id group_link_id,group_link.permission_profile_id
  from public.activity_group_assignments assignment
  join public.activity_group_links group_link on group_link.id=assignment.activity_group_link_id and group_link.institution_id=assignment.institution_id
  join public.activity_definitions activity on activity.id=group_link.activity_id and activity.institution_id=group_link.institution_id
  where assignment.person_id=app_private.current_person_id() and assignment.status='active' and assignment.revoked_at is null
   and assignment.assignment_role='instructor' and group_link.status='active' and activity.status='active'
   and activity.id=target_activity_id and group_link.group_id=target_group_id limit 1
 ), target_capability as(
  select capability.id from public.activity_capabilities capability where capability.code=target_capability_code and capability.status='active'
 ), individual_override as(
  select override_row.effect::text effect from current_assignment assignment
  join public.activity_assignment_permission_overrides override_row on override_row.assignment_id=assignment.id
  join target_capability capability on capability.id=override_row.capability_id limit 1
 ), institution_policy as(
  select policy.policy_mode::text policy_mode from public.activity_capability_policies policy
  join target_capability capability on capability.id=policy.capability_id where policy.activity_id=target_activity_id limit 1
 ), explicit_action as(
  select case when action.can_view and action.can_edit then 'both' when action.can_edit then 'edit' when action.can_view then 'view' else 'none' end action_mode
  from current_assignment assignment join public.activity_assignment_capability_actions action on action.assignment_id=assignment.id
  join target_capability capability on capability.id=action.capability_id limit 1
 ), group_setting as(
  select setting.is_enabled::text setting_value from current_assignment assignment
  join public.activity_group_capability_settings setting on setting.activity_group_link_id=assignment.group_link_id
  join target_capability capability on capability.id=setting.capability_id limit 1
 ), profile_permission as(
  select profile_capability.effect::text effect from current_assignment assignment
  join public.activity_permission_profile_capabilities profile_capability on profile_capability.profile_id=assignment.permission_profile_id
  join target_capability capability on capability.id=profile_capability.capability_id limit 1
 )
 select exists(select 1 from current_assignment) and app_private.activity_v2_effective_permission(
  (select policy_mode from institution_policy),(select effect from individual_override where effect='deny'),
  (select action_mode from explicit_action),(select effect from individual_override where effect='allow'),
  (select policy_mode from institution_policy),(select setting_value from group_setting),
  (select policy_mode from institution_policy),(select effect from profile_permission))<>'none'
$$;

create function app_private.activity_v2_validate_participants(p_institution_id uuid,p_participants jsonb)
returns boolean language sql stable security definer set search_path='' as $$
 select case when jsonb_typeof(p_participants) is distinct from 'array' then false else
 jsonb_array_length(p_participants)<=1000
 and not exists(select 1 from jsonb_array_elements(p_participants) item
  where jsonb_typeof(item)<>'object' or not(item ?& array['group_id','child_group_link_id','belongs']) or item-array['group_id','child_group_link_id','belongs']<>'{}'::jsonb
   or jsonb_typeof(item->'group_id')<>'string' or jsonb_typeof(item->'child_group_link_id')<>'string'
   or jsonb_typeof(item->'belongs')<>'boolean'
   or case when jsonb_typeof(item->'belongs')='boolean' and (item->>'belongs')::boolean then
    not exists(select 1 from public.child_group_links cgl
     join public.child_unit_links cul on cul.id=cgl.child_unit_link_id and cul.status='active'
     join public.child_contexts cc on cc.id=cul.child_context_id and cc.status='active'
     join public.groups g on g.id=cgl.group_id and g.unit_id=cul.unit_id and g.institution_id=p_institution_id
     where cgl.id=(item->>'child_group_link_id')::uuid and cgl.group_id=(item->>'group_id')::uuid and cgl.status='active'
       and cc.institution_id=p_institution_id) else false end)
 and (select count(*)=count(distinct (item->>'group_id',item->>'child_group_link_id')) from jsonb_array_elements(p_participants) item) end
$$;

create function app_private.activity_v2_validate_professionals(p_institution_id uuid,p_professionals jsonb)
returns boolean language sql stable security definer set search_path='' as $$
 select case when jsonb_typeof(p_professionals) is distinct from 'array' then false else
 jsonb_array_length(p_professionals)<=100
 and not exists(select 1 from jsonb_array_elements(p_professionals) item
  where jsonb_typeof(item)<>'object' or not(item ?& array['membership_id','role','group_id']) or item-array['membership_id','role','group_id']<>'{}'::jsonb
   or jsonb_typeof(item->'membership_id')<>'string' or jsonb_typeof(item->'role')<>'string'
   or item->>'role' not in('instructor','activity_admin')
   or (item->>'role'='instructor' and nullif(item->>'group_id','') is null)
   or (item->>'role'='activity_admin' and item->'group_id'<>'null'::jsonb)
   or not exists(select 1 from public.institution_memberships m join public.people p on p.id=m.person_id
    where m.id=(item->>'membership_id')::uuid and m.institution_id=p_institution_id
      and m.status='active' and m.revoked_at is null and p.person_type='adult' and p.status='active'))
 and (select count(*)=count(distinct (item->>'membership_id',item->>'role',coalesce(item->>'group_id',''))) from jsonb_array_elements(p_professionals) item) end
$$;

-- Read wrappers. Every key is named explicitly; no row-shaped JSON is exposed.
create function public.superadmin_activity_directory_v2(
 p_filters jsonb default '{}'::jsonb,p_limit integer default 24,p_offset integer default 0,
 p_sort text default 'name',p_sort_ascending boolean default true
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); result jsonb;
 search_text text; institution_filter uuid; status_filter text; unit_filter uuid; group_filter uuid; code text;
begin
 begin
  select * into strict ctx from app_private.activity_v2_require_context('activities.read',null);
  if p_filters is null or jsonb_typeof(p_filters)<>'object' or p_filters-array['search','institution_id','status','unit_id','group_id']<>'{}'::jsonb
     or p_limit is null or p_offset is null or p_sort is null or p_sort_ascending is null
     or p_limit not between 1 and 100 or p_offset<0 or p_sort not in('name','status','created_at','updated_at') then
   raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT';
  end if;
  search_text:=nullif(btrim(p_filters->>'search'),'');
  if length(coalesce(search_text,''))>120 then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
  institution_filter:=nullif(p_filters->>'institution_id','')::uuid;
  unit_filter:=nullif(p_filters->>'unit_id','')::uuid; group_filter:=nullif(p_filters->>'group_id','')::uuid;
  status_filter:=nullif(p_filters->>'status','');
  with filtered as(
   select a.* from public.activity_definitions a where
    (institution_filter is null or a.institution_id=institution_filter)
    and (ctx.scope_kind<>'institution' or a.institution_id=ctx.scope_institution_id)
    and (search_text is null or a.name ilike '%'||search_text||'%')
    and (status_filter is null or a.status::text=status_filter)
    and (unit_filter is null or exists(select 1 from public.activity_unit_links ul where ul.activity_id=a.id and ul.unit_id=unit_filter and ul.status='active'))
    and (group_filter is null or exists(select 1 from public.activity_group_links gl where gl.activity_id=a.id and gl.group_id=group_filter and gl.status='active'))
  ), page as(select * from filtered order by
    case when p_sort='name' and p_sort_ascending then name end asc,
    case when p_sort='name' and not p_sort_ascending then name end desc,
    case when p_sort='status' and p_sort_ascending then status::text end asc,
    case when p_sort='status' and not p_sort_ascending then status::text end desc,
    case when p_sort='created_at' and p_sort_ascending then created_at end asc,
    case when p_sort='created_at' and not p_sort_ascending then created_at end desc,
    case when p_sort='updated_at' and p_sort_ascending then updated_at end asc,
    case when p_sort='updated_at' and not p_sort_ascending then updated_at end desc,id limit p_limit offset p_offset)
  select pg_catalog.jsonb_build_object('items',coalesce(jsonb_agg(pg_catalog.jsonb_build_object(
   'activity_id',p.id,'institution_id',p.institution_id,'institution_name',i.public_name,
   'name',p.name,'status',p.status,'management_version',p.management_version,
   'icon_key',p.identity_icon,'initials',p.identity_initials,
   'unit_count',(select count(*) from public.activity_unit_links x where x.activity_id=p.id and x.status='active'),
   'group_count',(select count(*) from public.activity_group_links x where x.activity_id=p.id and x.status='active'),
   'created_at',p.created_at,'updated_at',p.updated_at) order by
    case when p_sort='name' and p_sort_ascending then p.name end asc,
    case when p_sort='name' and not p_sort_ascending then p.name end desc,
    case when p_sort='status' and p_sort_ascending then p.status::text end asc,
    case when p_sort='status' and not p_sort_ascending then p.status::text end desc,
    case when p_sort='created_at' and p_sort_ascending then p.created_at end asc,
    case when p_sort='created_at' and not p_sort_ascending then p.created_at end desc,
    case when p_sort='updated_at' and p_sort_ascending then p.updated_at end asc,
    case when p_sort='updated_at' and not p_sort_ascending then p.updated_at end desc,p.id),'[]'::jsonb),
   'total',(select count(*) from filtered),'limit',p_limit,'offset',p_offset) into result
  from page p join public.institutions i on i.id=p.institution_id;
  return app_private.activity_v2_success_envelope(result);
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.read','activity.directory',code,correlation,
   case when ctx.scope_kind='institution' then ctx.scope_institution_id else institution_filter end);
end $$;

create function public.superadmin_activity_detail_v2(p_activity_id uuid,p_sections text[] default '{}')
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; a public.activity_definitions%rowtype; correlation uuid:=gen_random_uuid();
 result jsonb; section text; code text;
begin begin
 select * into strict ctx from app_private.activity_v2_require_context('activities.read',null);
 if p_activity_id is null or p_sections is null then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id
   and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id);
 if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.read',a.institution_id);
 if coalesce(array_length(p_sections,1),0)<>(select count(distinct x) from unnest(p_sections) x)
    or exists(select 1 from unnest(p_sections) x where x not in('participants','professionals','permissions')) then
  raise invalid_parameter_value using message='unknown or duplicate section',detail='ACTIVITY_INVALID_INPUT'; end if;
 foreach section in array p_sections loop
  if section in('participants','professionals') then perform app_private.activity_v2_require_context('activities.assign_people',a.institution_id);
  else perform app_private.activity_v2_require_context('activities.manage_permissions',a.institution_id); end if;
 end loop;
 result:=pg_catalog.jsonb_build_object('activity',pg_catalog.jsonb_build_object(
  'activity_id',a.id,'institution_id',a.institution_id,'name',a.name,'description',a.description,
  'taxonomy_id',a.taxonomy_id,'taxonomy_name',(select t.name from public.activity_taxonomies t where t.id=a.taxonomy_id),
  'status',a.status,'management_version',a.management_version,'icon_key',a.identity_icon,'initials',a.identity_initials,
  'created_at',a.created_at,'updated_at',a.updated_at),
  'units',coalesce((select jsonb_agg(pg_catalog.jsonb_build_object('unit_id',u.id,'name',u.name,'status',l.status) order by u.name) from public.activity_unit_links l join public.units u on u.id=l.unit_id where l.activity_id=a.id and l.status='active'),'[]'::jsonb),
  'groups',coalesce((select jsonb_agg(pg_catalog.jsonb_build_object('group_id',g.id,'unit_id',g.unit_id,'name',g.name,'status',l.status,'participation_mode',l.participation_mode) order by g.name) from public.activity_group_links l join public.groups g on g.id=l.group_id where l.activity_id=a.id and l.status='active'),'[]'::jsonb),
  'counts',pg_catalog.jsonb_build_object('units',(select count(*) from public.activity_unit_links l where l.activity_id=a.id and l.status='active'),'groups',(select count(*) from public.activity_group_links l where l.activity_id=a.id and l.status='active'),'participants',(select count(*) from public.activity_group_participants p join public.activity_group_links l on l.id=p.activity_group_link_id where l.activity_id=a.id and p.status='active' and p.removed_at is null),'instructors',(select count(*) from public.activity_group_assignments p join public.activity_group_links l on l.id=p.activity_group_link_id where l.activity_id=a.id and p.status='active' and p.assignment_role='instructor'),'activity_admins',(select count(*) from public.activity_admin_assignments p where p.activity_id=a.id and p.status='active')));
 if 'participants'=any(p_sections) then result:=result||pg_catalog.jsonb_build_object('participants',coalesce((select jsonb_agg(pg_catalog.jsonb_build_object('child_group_link_id',p.child_group_link_id,'group_id',gl.group_id,'display_name',person.display_name,'status',p.status)) from public.activity_group_participants p join public.activity_group_links gl on gl.id=p.activity_group_link_id join public.child_group_links cgl on cgl.id=p.child_group_link_id and cgl.group_id=gl.group_id and cgl.status='active' join public.child_unit_links cul on cul.id=cgl.child_unit_link_id and cul.unit_id=gl.unit_id and cul.status='active' join public.child_contexts cc on cc.id=cul.child_context_id and cc.institution_id=a.institution_id and cc.status='active' join public.people person on person.id=cc.child_person_id and person.person_type='child' and person.status='active' where gl.activity_id=a.id and gl.status='active' and p.status='active' and p.removed_at is null),'[]'::jsonb)); end if;
 if 'professionals'=any(p_sections) then result:=result||pg_catalog.jsonb_build_object('professionals',coalesce((select jsonb_agg(item) from(
  select pg_catalog.jsonb_build_object('membership_id',x.membership_id,'role','instructor','group_id',gl.group_id,'display_name',p.display_name,'status',x.status) item from public.activity_group_assignments x join public.activity_group_links gl on gl.id=x.activity_group_link_id and gl.institution_id=a.institution_id and gl.status='active' join public.groups g on g.id=gl.group_id and g.institution_id=a.institution_id and g.unit_id=gl.unit_id and g.status='active' join public.institution_memberships m on m.id=x.membership_id and m.person_id=x.person_id and m.institution_id=a.institution_id and m.status='active' and m.revoked_at is null join public.people p on p.id=x.person_id and p.person_type='adult' and p.status='active' where gl.activity_id=a.id and x.institution_id=a.institution_id and x.status='active' and x.revoked_at is null and x.assignment_role='instructor'
  union all select pg_catalog.jsonb_build_object('membership_id',x.membership_id,'role','activity_admin','group_id',null,'display_name',p.display_name,'status',x.status) from public.activity_admin_assignments x join public.institution_memberships m on m.id=x.membership_id and m.person_id=x.person_id and m.institution_id=a.institution_id and m.status='active' and m.revoked_at is null join public.people p on p.id=x.person_id and p.person_type='adult' and p.status='active' where x.activity_id=a.id and x.institution_id=a.institution_id and x.status='active' and x.revoked_at is null) q),'[]'::jsonb)); end if;
 if 'permissions'=any(p_sections) then result:=result||pg_catalog.jsonb_build_object('permissions',pg_catalog.jsonb_build_object(
  'policies',coalesce((select jsonb_agg(pg_catalog.jsonb_build_object('code',c.code,'mode',p.policy_mode)) from public.activity_capability_policies p join public.activity_capabilities c on c.id=p.capability_id where p.activity_id=a.id),'[]'::jsonb),
  'group_settings',coalesce((select jsonb_agg(pg_catalog.jsonb_build_object('group_id',gl.group_id,'code',c.code,'enabled',s.is_enabled)) from public.activity_group_capability_settings s join public.activity_group_links gl on gl.id=s.activity_group_link_id join public.activity_capabilities c on c.id=s.capability_id where gl.activity_id=a.id),'[]'::jsonb),
  'professional_actions',coalesce((select jsonb_agg(item order by role,membership_id,group_id nulls first) from(
    select ga.membership_id,'instructor'::text role,gl.group_id,
      pg_catalog.jsonb_build_object('membership_id',ga.membership_id,'role','instructor','group_id',gl.group_id,
        'actions',coalesce((select jsonb_object_agg(c.code,case when action.can_view and action.can_edit then 'both' when action.can_edit then 'edit' when action.can_view then 'view' else 'none' end order by c.code)
          from public.activity_assignment_capability_actions action join public.activity_capabilities c on c.id=action.capability_id
          where action.assignment_id=ga.id and c.code in('chat','now','happens','moments','attendance')),'{}'::jsonb)) item
    from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id and gl.institution_id=a.institution_id and gl.status='active'
    join public.groups g on g.id=gl.group_id and g.institution_id=a.institution_id and g.unit_id=gl.unit_id and g.status='active'
    join public.institution_memberships m on m.id=ga.membership_id and m.person_id=ga.person_id and m.institution_id=a.institution_id and m.status='active' and m.revoked_at is null
    join public.people person on person.id=ga.person_id and person.person_type='adult' and person.status='active'
    where gl.activity_id=a.id and ga.institution_id=a.institution_id and ga.status='active' and ga.revoked_at is null and ga.assignment_role='instructor'
    union all
    select aa.membership_id,'activity_admin'::text role,null::uuid group_id,
      pg_catalog.jsonb_build_object('membership_id',aa.membership_id,'role','activity_admin','group_id',null,
        'actions',coalesce((select jsonb_object_agg(c.code,case when action.can_view and action.can_edit then 'both' when action.can_edit then 'edit' when action.can_view then 'view' else 'none' end order by c.code)
          from public.activity_admin_capability_actions action join public.activity_capabilities c on c.id=action.capability_id
          where action.activity_admin_assignment_id=aa.id and c.code in('chat','now','happens','moments','attendance')),'{}'::jsonb)) item
    from public.activity_admin_assignments aa
    join public.institution_memberships m on m.id=aa.membership_id and m.person_id=aa.person_id and m.institution_id=a.institution_id and m.status='active' and m.revoked_at is null
    join public.people person on person.id=aa.person_id and person.person_type='adult' and person.status='active'
    where aa.activity_id=a.id and aa.institution_id=a.institution_id and aa.status='active' and aa.revoked_at is null
  ) actions),'[]'::jsonb))); end if;
  return app_private.activity_v2_success_envelope(result);
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.read','activity.detail',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

create function public.superadmin_activity_form_options_v2(p_institution_id uuid,p_sections text[],p_search text default null,p_limit integer default 50)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); result jsonb:='{}'; section text; code text;
begin begin
 select * into strict ctx from app_private.activity_v2_require_context('activities.read',p_institution_id);
 if p_institution_id is null or p_sections is null or p_limit is null or p_limit not between 1 and 100 or length(coalesce(p_search,''))>120 or coalesce(array_length(p_sections,1),0)<>(select count(distinct x) from unnest(p_sections)x)
 or exists(select 1 from unnest(p_sections)x where x not in('taxonomy','structure','participants','professionals','permissions')) then raise invalid_parameter_value using message='unknown or duplicate section',detail='ACTIVITY_INVALID_INPUT'; end if;
 foreach section in array p_sections loop
  if section='structure' then perform app_private.activity_v2_require_context('activities.link_units',p_institution_id); perform app_private.activity_v2_require_context('activities.link_groups',p_institution_id);
  elsif section in('participants','professionals') then perform app_private.activity_v2_require_context('activities.assign_people',p_institution_id);
  elsif section='permissions' then perform app_private.activity_v2_require_context('activities.manage_permissions',p_institution_id); end if;
 end loop;
 if 'taxonomy'=any(p_sections) then result:=result||pg_catalog.jsonb_build_object('taxonomy',coalesce((select jsonb_agg(pg_catalog.jsonb_build_object('taxonomy_id',t.id,'code',t.code,'name',t.name) order by t.name) from(select * from public.activity_taxonomies x where x.status='active' and x.code<>'outros' and (p_search is null or x.name ilike '%'||p_search||'%') order by x.name limit p_limit)t),'[]'::jsonb)); end if;
 if 'structure'=any(p_sections) then result:=result||pg_catalog.jsonb_build_object('structure',pg_catalog.jsonb_build_object('units',coalesce((select jsonb_agg(pg_catalog.jsonb_build_object('unit_id',u.id,'name',u.name) order by u.name) from(select * from public.units x where x.institution_id=p_institution_id and x.status='active' and (p_search is null or x.name ilike '%'||p_search||'%') order by x.name limit p_limit)u),'[]'::jsonb),'groups',coalesce((select jsonb_agg(pg_catalog.jsonb_build_object('group_id',g.id,'unit_id',g.unit_id,'name',g.name) order by g.name) from(select * from public.groups x where x.institution_id=p_institution_id and x.status='active' and (p_search is null or x.name ilike '%'||p_search||'%') order by x.name limit p_limit)g),'[]'::jsonb))); end if;
 if 'participants'=any(p_sections) then result:=result||pg_catalog.jsonb_build_object('participants',coalesce((select jsonb_agg(candidate.item) from (select pg_catalog.jsonb_build_object('child_group_link_id',cgl.id,'group_id',cgl.group_id,'display_name',p.display_name) item from public.child_group_links cgl join public.child_unit_links cul on cul.id=cgl.child_unit_link_id and cul.status='active' join public.child_contexts cc on cc.id=cul.child_context_id and cc.institution_id=p_institution_id and cc.status='active' join public.people p on p.id=cc.child_person_id and p.person_type='child' and p.status='active' join public.groups g on g.id=cgl.group_id and g.institution_id=p_institution_id and g.unit_id=cul.unit_id and g.status='active' where cgl.status='active' and (p_search is null or p.display_name ilike '%'||p_search||'%') order by p.display_name,cgl.id limit p_limit) candidate),'[]'::jsonb)); end if;
 if 'professionals'=any(p_sections) then result:=result||pg_catalog.jsonb_build_object('professionals',coalesce((select jsonb_agg(candidate.item) from (select pg_catalog.jsonb_build_object('membership_id',m.id,'display_name',p.display_name,'role_code',m.role_code) item from public.institution_memberships m join public.people p on p.id=m.person_id where m.institution_id=p_institution_id and m.status='active' and m.revoked_at is null and p.person_type='adult' and p.status='active' and (p_search is null or p.display_name ilike '%'||p_search||'%') order by p.display_name,m.id limit least(p_limit,100)) candidate),'[]'::jsonb)); end if;
 if 'permissions'=any(p_sections) then result:=result||pg_catalog.jsonb_build_object('capabilities',coalesce((select jsonb_agg(pg_catalog.jsonb_build_object('code',c.code,'name',c.name) order by c.code) from public.activity_capabilities c where c.status='active' and c.code in('chat','now','happens','moments','attendance')),'[]'::jsonb)); end if;
 return app_private.activity_v2_success_envelope(result);
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.read','activity.form_options',code,correlation,p_institution_id); end $$;

-- Commands are intentionally explicit. Each wrapper independently resolves the
-- internal realm, locks request then aggregate, validates scope and increments once.
create function public.superadmin_activity_create_v2(p_request_id uuid,p_payload jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); institution uuid; activity uuid:=gen_random_uuid(); taxonomy uuid; units uuid[]; h bytea; replay jsonb; a public.activity_definitions%rowtype; code text;
begin begin
 select * into strict ctx from app_private.activity_v2_require_context('activities.create',null);
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or p_payload-array['institution_id','name','description','taxonomy_id','icon_key','initials','unit_ids']<>'{}'::jsonb
 or jsonb_typeof(p_payload->'institution_id')<>'string' or jsonb_typeof(p_payload->'name')<>'string'
 or jsonb_typeof(p_payload->'taxonomy_id')<>'string' or jsonb_typeof(p_payload->'unit_ids')<>'array'
 or (p_payload?'description' and p_payload->'description'<>'null'::jsonb and jsonb_typeof(p_payload->'description')<>'string')
 or (p_payload?'icon_key' and p_payload->'icon_key'<>'null'::jsonb and jsonb_typeof(p_payload->'icon_key')<>'string')
 or (p_payload?'initials' and p_payload->'initials'<>'null'::jsonb and jsonb_typeof(p_payload->'initials')<>'string')
 or exists(select 1 from jsonb_array_elements(p_payload->'unit_ids') item where jsonb_typeof(item)<>'string')
 or length(btrim(coalesce(p_payload->>'name',''))) not between 1 and 120
 or length(coalesce(p_payload->>'description',''))>500 or length(coalesce(p_payload->>'icon_key',''))>64
 or length(btrim(coalesce(p_payload->>'initials',''))) not between 1 and 2
 or nullif(p_payload->>'institution_id','') is null or nullif(p_payload->>'taxonomy_id','') is null
 then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 begin institution:=(p_payload->>'institution_id')::uuid; taxonomy:=(p_payload->>'taxonomy_id')::uuid; select array_agg(x::uuid) into units from jsonb_array_elements_text(p_payload->'unit_ids')x; exception when others then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end;
 if p_request_id is null or nullif(btrim(p_payload->>'name'),'') is null or coalesce(array_length(units,1),0) not between 1 and 100 or cardinality(units)<>(select count(distinct unit_id) from unnest(units) unit_id) then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.create',institution); perform app_private.activity_v2_require_context('activities.link_units',institution);
 h:=app_private.activity_v2_command_request_hash('activity.create',institution,null,null,p_payload); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,institution,null,'activity.create',h,correlation); if replay is not null then return replay; end if;
 perform 1 from public.activity_taxonomies t where t.id=taxonomy order by t.id for share;
 perform 1 from public.units u where u.id=any(units) order by u.id for share;
 if not exists(select 1 from public.activity_taxonomies t where t.id=taxonomy and t.status='active' and t.code<>'outros') or (select count(*) from public.units u where u.id=any(units) and u.institution_id=institution and u.status='active')<>cardinality(units) then raise invalid_parameter_value using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.create','create',correlation);
 insert into public.activity_definitions(id,institution_id,name,description,origin_scope_kind,origin_unit_id,created_by_person_id,status,taxonomy_id,handle_stem,identity_mode,identity_initials,identity_color,identity_icon)
 values(activity,institution,btrim(p_payload->>'name'),nullif(btrim(p_payload->>'description'),''),'institution',null,null,'draft',taxonomy,coalesce(nullif(app_private.activity_slugify(p_payload->>'name'),''),'activity-'||left(activity::text,8)),'initials',nullif(p_payload->>'initials',''),'#D63C00',nullif(p_payload->>'icon_key','')) returning * into a;
 perform app_private.activity_v2_set_marker(ctx,'activities.link_units','link_units',correlation);
 insert into public.activity_unit_links(activity_id,institution_id,unit_id,linked_by_person_id) select activity,institution,x,null from unnest(units)x;
 correlation:=app_private.activity_v2_append_audit(ctx,institution,activity,'activities.create','activity.create',pg_catalog.jsonb_build_object('units',cardinality(units)));
 return app_private.activity_v2_finish_command(ctx,p_request_id,institution,activity,'activity.create',h,a.management_version,a.status::text,correlation,pg_catalog.jsonb_build_object('units',cardinality(units)));
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.create','activity.create',code,correlation,institution); end $$;

create function public.superadmin_activity_update_v2(p_request_id uuid,p_activity_id uuid,p_expected_version bigint,p_payload jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text;
begin begin
 select * into strict ctx from app_private.activity_v2_require_context('activities.manage',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1
 or p_payload is null or jsonb_typeof(p_payload)<>'object' or p_payload='{}'::jsonb or p_payload-array['name','description','taxonomy_id','icon_key','initials']<>'{}'::jsonb
 or (p_payload?'name' and (jsonb_typeof(p_payload->'name')<>'string' or length(btrim(p_payload->>'name')) not between 1 and 120))
 or (p_payload?'description' and p_payload->'description'<>'null'::jsonb and (jsonb_typeof(p_payload->'description')<>'string' or length(p_payload->>'description')>500))
 or (p_payload?'taxonomy_id' and jsonb_typeof(p_payload->'taxonomy_id')<>'string')
 or (p_payload?'icon_key' and p_payload->'icon_key'<>'null'::jsonb and (jsonb_typeof(p_payload->'icon_key')<>'string' or length(p_payload->>'icon_key')>64))
 or (p_payload?'initials' and p_payload->'initials'<>'null'::jsonb and (jsonb_typeof(p_payload->'initials')<>'string' or length(btrim(p_payload->>'initials')) not between 1 and 2))
 then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id); if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.manage',a.institution_id); h:=app_private.activity_v2_command_request_hash('activity.update',a.institution_id,p_activity_id,p_expected_version,p_payload); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,p_activity_id,'activity.update',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update; if a.management_version<>p_expected_version then raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
 if p_payload?'taxonomy_id' then begin
   perform 1 from public.activity_taxonomies t where t.id=(p_payload->>'taxonomy_id')::uuid order by t.id for share;
  exception when invalid_text_representation then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end;
  if not exists(select 1 from public.activity_taxonomies t where t.id=(p_payload->>'taxonomy_id')::uuid and t.status='active' and t.code<>'outros') then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.manage','manage',correlation);
 update public.activity_definitions x set name=case when p_payload?'name' then btrim(p_payload->>'name') else x.name end,description=case when p_payload?'description' then nullif(btrim(p_payload->>'description'),'') else x.description end,taxonomy_id=case when p_payload?'taxonomy_id' then (p_payload->>'taxonomy_id')::uuid else x.taxonomy_id end,identity_icon=case when p_payload?'icon_key' then nullif(p_payload->>'icon_key','') else x.identity_icon end,identity_initials=case when p_payload?'initials' then nullif(p_payload->>'initials','') else x.identity_initials end,management_version=x.management_version+1,updated_at=now() where x.id=p_activity_id returning * into a;
 correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.manage','activity.update','{}'); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.update',h,a.management_version,a.status::text,correlation,'{}');
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.manage','activity.update',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

create function public.superadmin_activity_set_units_v2(p_request_id uuid,p_activity_id uuid,p_expected_version bigint,p_unit_ids uuid[])
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text;
begin begin select * into strict ctx from app_private.activity_v2_require_context('activities.link_units',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1 or p_unit_ids is null then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id); if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.link_units',a.institution_id);
 if coalesce(cardinality(p_unit_ids),0) not between 1 and 100 or cardinality(p_unit_ids)<>(select count(distinct x) from unnest(p_unit_ids)x) then raise invalid_parameter_value using message='duplicate unit',detail='ACTIVITY_INVALID_INPUT'; end if;
 h:=app_private.activity_v2_command_request_hash('activity.set_units',a.institution_id,a.id,p_expected_version,to_jsonb(p_unit_ids)); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,a.id,'activity.set_units',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update; if a.management_version<>p_expected_version then raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
 perform 1 from public.units u where u.id=any(p_unit_ids) order by u.id for share;
 perform 1 from public.activity_unit_links ul where ul.activity_id=a.id order by ul.id for update;
 perform 1 from public.activity_group_links gl where gl.activity_id=a.id order by gl.id for share;
 if exists(select 1 from public.activity_group_links gl join public.activity_unit_links ul on ul.activity_id=gl.activity_id and ul.unit_id=gl.unit_id where gl.activity_id=a.id and gl.status='active' and not(gl.unit_id=any(p_unit_ids))) then raise integrity_constraint_violation using detail='ACTIVITY_DEPENDENCIES_ACTIVE'; end if;
 if (select count(*) from public.units u where u.id=any(p_unit_ids) and u.institution_id=a.institution_id and u.status='active')<>cardinality(p_unit_ids) then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.link_units','link_units',correlation); update public.activity_unit_links l set status='inactive',ends_at=now(),updated_at=now() where l.activity_id=a.id and l.status='active' and not(l.unit_id=any(p_unit_ids));
 insert into public.activity_unit_links(activity_id,institution_id,unit_id,linked_by_person_id,status,ends_at) select a.id,a.institution_id,x,null,'active',null from unnest(p_unit_ids)x on conflict(activity_id,unit_id) do update set status='active',ends_at=null,updated_at=now();
 update public.activity_definitions x set management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.link_units','activity.set_units',pg_catalog.jsonb_build_object('units',cardinality(p_unit_ids))); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.set_units',h,a.management_version,a.status::text,correlation,pg_catalog.jsonb_build_object('units',cardinality(p_unit_ids)));
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.link_units','activity.set_units',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

create function public.superadmin_activity_set_groups_v2(p_request_id uuid,p_activity_id uuid,p_expected_version bigint,p_group_ids uuid[],p_group_participation jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text;
begin begin select * into strict ctx from app_private.activity_v2_require_context('activities.link_groups',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1 or p_group_ids is null or jsonb_typeof(p_group_participation) is distinct from 'object' then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id); if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.link_groups',a.institution_id);
 if coalesce(cardinality(p_group_ids),0)>200 or jsonb_typeof(p_group_participation)<>'object' or cardinality(p_group_ids)<>(select count(distinct x) from unnest(p_group_ids)x) or (select coalesce(array_agg(k order by k),'{}') from jsonb_object_keys(p_group_participation)k)<>(select coalesce(array_agg(x::text order by x::text),'{}') from unnest(p_group_ids)x) or exists(select 1 from jsonb_each_text(p_group_participation)x where value not in('all','selected')) then raise invalid_parameter_value using message='duplicate group',detail='ACTIVITY_INVALID_INPUT'; end if;
 h:=app_private.activity_v2_command_request_hash('activity.set_groups',a.institution_id,a.id,p_expected_version,pg_catalog.jsonb_build_object('group_ids',p_group_ids,'participation',p_group_participation)); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,a.id,'activity.set_groups',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update; if a.management_version<>p_expected_version then raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
 perform 1 from public.groups g where g.id=any(p_group_ids) order by g.id for share;
 perform 1 from public.activity_unit_links ul where ul.activity_id=a.id order by ul.id for share;
 perform 1 from public.activity_group_links gl where gl.activity_id=a.id order by gl.id for update;
 perform 1 from public.activity_group_participants participant where participant.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by participant.id for share;
 perform 1 from public.activity_group_assignments assignment where assignment.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by assignment.id for share;
 perform 1 from public.activity_group_capability_settings setting where setting.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by setting.id for share;
 if exists(select 1 from public.activity_group_links gl where gl.activity_id=a.id and gl.status='active' and not(gl.group_id=any(p_group_ids)) and (exists(select 1 from public.activity_group_participants p where p.activity_group_link_id=gl.id and p.status='active') or exists(select 1 from public.activity_group_assignments p where p.activity_group_link_id=gl.id and p.status='active') or exists(select 1 from public.activity_group_capability_settings p where p.activity_group_link_id=gl.id))) then raise integrity_constraint_violation using detail='ACTIVITY_DEPENDENCIES_ACTIVE'; end if;
 if exists(select 1 from unnest(p_group_ids)x left join public.groups g on g.id=x and g.institution_id=a.institution_id and g.status='active' left join public.activity_unit_links ul on ul.activity_id=a.id and ul.unit_id=g.unit_id and ul.status='active' where g.id is null or ul.id is null) then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 if exists(select 1 from public.activity_group_links gl join public.activity_group_participants p on p.activity_group_link_id=gl.id and p.status='active' where gl.activity_id=a.id and gl.group_id=any(p_group_ids) and gl.participation_mode='selected' and p_group_participation->>gl.group_id::text='all') then raise integrity_constraint_violation using detail='ACTIVITY_DEPENDENCIES_ACTIVE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.link_groups','link_groups',correlation); update public.activity_group_links gl set status='inactive',ends_at=now(),updated_at=now() where gl.activity_id=a.id and gl.status='active' and not(gl.group_id=any(p_group_ids));
 insert into public.activity_group_links(activity_id,institution_id,unit_id,group_id,linked_by_person_id,status,ends_at,participation_mode) select a.id,a.institution_id,g.unit_id,g.id,null,'active',null,p_group_participation->>g.id::text from public.groups g where g.id=any(p_group_ids) on conflict(activity_id,group_id) do update set status='active',ends_at=null,participation_mode=excluded.participation_mode,updated_at=now();
 update public.activity_definitions x set management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.link_groups','activity.set_groups',pg_catalog.jsonb_build_object('groups',cardinality(p_group_ids))); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.set_groups',h,a.management_version,a.status::text,correlation,pg_catalog.jsonb_build_object('groups',cardinality(p_group_ids)));
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.link_groups','activity.set_groups',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

-- Participant/professional/permission snapshots use the same ordered protocol.
create function public.superadmin_activity_set_participants_v2(p_request_id uuid,p_activity_id uuid,p_expected_version bigint,p_participants jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text;
begin begin select * into strict ctx from app_private.activity_v2_require_context('activities.assign_people',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1 or jsonb_typeof(p_participants) is distinct from 'array' then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id); if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.assign_people',a.institution_id);
 if p_request_id is null or p_expected_version is null or p_expected_version<1 or app_private.activity_v2_validate_participants(a.institution_id,p_participants) is distinct from true then raise invalid_parameter_value using message='duplicate participant or invalid chain (max 1000)',detail='ACTIVITY_INVALID_INPUT'; end if;
 h:=app_private.activity_v2_command_request_hash('activity.set_participants',a.institution_id,a.id,p_expected_version,p_participants); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,a.id,'activity.set_participants',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update; if a.management_version<>p_expected_version then raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
 perform 1 from public.child_group_links cgl where cgl.id in(select (item->>'child_group_link_id')::uuid from jsonb_array_elements(p_participants) item where (item->>'belongs')::boolean) order by cgl.id for share;
 perform 1 from public.child_unit_links cul where cul.id in(select cgl.child_unit_link_id from public.child_group_links cgl where cgl.id in(select (item->>'child_group_link_id')::uuid from jsonb_array_elements(p_participants) item where (item->>'belongs')::boolean)) order by cul.id for share;
 perform 1 from public.child_contexts cc where cc.id in(select cul.child_context_id from public.child_unit_links cul where cul.id in(select cgl.child_unit_link_id from public.child_group_links cgl where cgl.id in(select (item->>'child_group_link_id')::uuid from jsonb_array_elements(p_participants) item where (item->>'belongs')::boolean))) order by cc.id for share;
 perform 1 from public.people person where person.id in(select cc.child_person_id from public.child_contexts cc where cc.id in(select cul.child_context_id from public.child_unit_links cul where cul.id in(select cgl.child_unit_link_id from public.child_group_links cgl where cgl.id in(select (item->>'child_group_link_id')::uuid from jsonb_array_elements(p_participants) item where (item->>'belongs')::boolean)))) order by person.id for share;
 perform 1 from public.activity_group_links gl where gl.activity_id=a.id order by gl.id for share;
 perform 1 from public.activity_group_participants participant where participant.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by participant.id for update;
 if app_private.activity_v2_validate_participants(a.institution_id,p_participants) is distinct from true then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 if exists(select 1 from jsonb_array_elements(p_participants)item left join public.activity_group_links gl on gl.activity_id=a.id and gl.group_id=(item->>'group_id')::uuid and gl.status='active' and gl.participation_mode='selected' where (item->>'belongs')::boolean and gl.id is null) then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.assign_people','assign_people',correlation); update public.activity_group_participants p set status='inactive',removed_at=now(),updated_at=now() where p.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) and p.status='active' and not exists(select 1 from jsonb_array_elements(p_participants)item where (item->>'belongs')::boolean and (item->>'child_group_link_id')::uuid=p.child_group_link_id);
 insert into public.activity_group_participants(activity_group_link_id,child_group_link_id,status,added_by_person_id) select gl.id,(item->>'child_group_link_id')::uuid,'active',null from jsonb_array_elements(p_participants)item join public.child_group_links cgl on cgl.id=(item->>'child_group_link_id')::uuid join public.activity_group_links gl on gl.activity_id=a.id and gl.group_id=(item->>'group_id')::uuid and gl.group_id=cgl.group_id and gl.status='active' where (item->>'belongs')::boolean on conflict(activity_group_link_id,child_group_link_id) where status='active' and removed_at is null do update set updated_at=now();
 update public.activity_definitions x set management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.assign_people','activity.set_participants',pg_catalog.jsonb_build_object('participants',jsonb_array_length(p_participants))); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.set_participants',h,a.management_version,a.status::text,correlation,pg_catalog.jsonb_build_object('participants',jsonb_array_length(p_participants)));
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.assign_people','activity.set_participants',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

create function public.superadmin_activity_set_professionals_v2(p_request_id uuid,p_activity_id uuid,p_expected_version bigint,p_professional_assignments jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text; item jsonb; m public.institution_memberships%rowtype; gl uuid;
begin begin select * into strict ctx from app_private.activity_v2_require_context('activities.assign_people',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1 or jsonb_typeof(p_professional_assignments) is distinct from 'array' then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id); if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.assign_people',a.institution_id);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1 or app_private.activity_v2_validate_professionals(a.institution_id,p_professional_assignments) is distinct from true then raise invalid_parameter_value using message='duplicate professional or invalid active membership (max 100)',detail='ACTIVITY_INVALID_INPUT'; end if;
 h:=app_private.activity_v2_command_request_hash('activity.set_professionals',a.institution_id,a.id,p_expected_version,p_professional_assignments); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,a.id,'activity.set_professionals',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update; if a.management_version<>p_expected_version then raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
 perform 1 from public.institution_memberships membership where membership.id in(select (requested->>'membership_id')::uuid from jsonb_array_elements(p_professional_assignments) requested) order by membership.id for share;
 perform 1 from public.people person where person.id in(select membership.person_id from public.institution_memberships membership where membership.id in(select (requested->>'membership_id')::uuid from jsonb_array_elements(p_professional_assignments) requested)) order by person.id for share;
 perform 1 from public.activity_group_links gl where gl.activity_id=a.id order by gl.id for share;
 perform 1 from public.activity_group_assignments assignment where assignment.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by assignment.id for update;
 perform 1 from public.activity_admin_assignments assignment where assignment.activity_id=a.id order by assignment.id for update;
 if app_private.activity_v2_validate_professionals(a.institution_id,p_professional_assignments) is distinct from true then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.assign_people','assign_people',correlation);
 update public.activity_group_assignments x set status='inactive',revoked_at=now(),updated_at=now()
 where x.activity_group_link_id in(select id from public.activity_group_links where activity_id=a.id)
   and x.status='active' and x.assignment_role='instructor' and not exists(
    select 1 from jsonb_array_elements(p_professional_assignments)desired_item
    join public.activity_group_links desired on desired.activity_id=a.id and desired.group_id=(desired_item->>'group_id')::uuid
    where desired_item->>'role'='instructor' and (desired_item->>'membership_id')::uuid=x.membership_id and desired.id=x.activity_group_link_id);
 update public.activity_admin_assignments x set status='inactive',revoked_at=now(),updated_at=now()
 where x.activity_id=a.id and x.status='active' and not exists(
  select 1 from jsonb_array_elements(p_professional_assignments)desired_item
  where desired_item->>'role'='activity_admin' and (desired_item->>'membership_id')::uuid=x.membership_id);
 for item in select element.value from jsonb_array_elements(p_professional_assignments) element loop
  select * into m from public.institution_memberships x where x.id=(item->>'membership_id')::uuid;
  if item->>'role'='activity_admin' then
   if not exists(select 1 from public.activity_admin_assignments x where x.activity_id=a.id and x.membership_id=m.id and x.status='active' and x.revoked_at is null) then
    insert into public.activity_admin_assignments(activity_id,institution_id,person_id,membership_id,assigned_by_person_id) values(a.id,a.institution_id,m.person_id,m.id,null);
   end if;
  else
   select id into gl from public.activity_group_links where activity_id=a.id and group_id=(item->>'group_id')::uuid and status='active';
   if gl is null then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
   if not exists(select 1 from public.activity_group_assignments x where x.activity_group_link_id=gl and x.membership_id=m.id and x.assignment_role='instructor' and x.status='active' and x.revoked_at is null) then
    insert into public.activity_group_assignments(activity_group_link_id,institution_id,person_id,membership_id,assignment_role,assigned_by_person_id) values(gl,a.institution_id,m.person_id,m.id,'instructor',null);
   end if;
  end if;
 end loop;
 update public.activity_definitions x set management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.assign_people','activity.set_professionals',pg_catalog.jsonb_build_object('professionals',jsonb_array_length(p_professional_assignments))); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.set_professionals',h,a.management_version,a.status::text,correlation,pg_catalog.jsonb_build_object('professionals',jsonb_array_length(p_professional_assignments)));
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.assign_people','activity.set_professionals',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

create function public.superadmin_activity_set_permissions_v2(p_request_id uuid,p_activity_id uuid,p_expected_version bigint,p_capability_policies jsonb,p_group_capability_settings jsonb,p_professional_capability_actions jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text; item jsonb; entry record; cap uuid; gl uuid; ass uuid; counts jsonb; approved text[]:=array['attendance','chat','happens','moments','now'];
begin begin select * into strict ctx from app_private.activity_v2_require_context('activities.manage_permissions',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1
  or jsonb_typeof(p_capability_policies) is distinct from 'object'
  or jsonb_typeof(p_group_capability_settings) is distinct from 'array'
  or jsonb_typeof(p_professional_capability_actions) is distinct from 'array' then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id); if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.manage_permissions',a.institution_id);
 if (select array_agg(key order by key) from jsonb_object_keys(p_capability_policies)key) is distinct from approved
 or exists(select 1 from jsonb_each(p_capability_policies)x where x.value<>'null'::jsonb and (jsonb_typeof(x.value)<>'string' or x.value#>>'{}' not in('required','default_on','default_off','prohibited')))
 or jsonb_array_length(p_group_capability_settings)>200 or jsonb_array_length(p_professional_capability_actions)>100
 or exists(select 1 from jsonb_array_elements(p_group_capability_settings)x where not(x ?& array['group_id','capabilities']) or x-array['group_id','capabilities']<>'{}'::jsonb or jsonb_typeof(x->'group_id')<>'string' or jsonb_typeof(x->'capabilities')<>'object' or (select array_agg(key order by key) from jsonb_object_keys(x->'capabilities')key) is distinct from approved or exists(select 1 from jsonb_each(x->'capabilities')v where v.value<>'null'::jsonb and jsonb_typeof(v.value)<>'boolean'))
 or exists(select 1 from jsonb_array_elements(p_professional_capability_actions)x where not(x ?& array['membership_id','role','group_id','actions']) or x-array['membership_id','role','group_id','actions']<>'{}'::jsonb or jsonb_typeof(x->'membership_id')<>'string' or jsonb_typeof(x->'role')<>'string' or x->>'role' not in('instructor','activity_admin') or (x->>'role'='instructor' and jsonb_typeof(x->'group_id')<>'string') or (x->>'role'='activity_admin' and x->'group_id'<>'null'::jsonb) or jsonb_typeof(x->'actions')<>'object' or (select array_agg(key order by key) from jsonb_object_keys(x->'actions')key) is distinct from approved or exists(select 1 from jsonb_each_text(x->'actions')v where v.value not in('none','view','edit','both')))
 or (select count(*)<>count(distinct (x->>'membership_id',x->>'role',coalesce(x->>'group_id',''))) from jsonb_array_elements(p_professional_capability_actions)x)
 or (select count(*)<>count(distinct x->>'group_id') from jsonb_array_elements(p_group_capability_settings)x)
 then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 if exists(select 1 from jsonb_each_text(p_capability_policies)p join jsonb_array_elements(p_professional_capability_actions)x on x->'actions'->>p.key='none' where p.value='required') then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 if exists(select 1 from jsonb_each_text(p_capability_policies) policy join jsonb_array_elements(p_group_capability_settings) setting on true join jsonb_each(setting->'capabilities') capability on capability.key=policy.key where (policy.value='required' and capability.value='false'::jsonb) or (policy.value='prohibited' and capability.value='true'::jsonb)) then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 h:=app_private.activity_v2_command_request_hash('activity.set_permissions',a.institution_id,a.id,p_expected_version,pg_catalog.jsonb_build_object('policies',p_capability_policies,'settings',p_group_capability_settings,'actions',p_professional_capability_actions)); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,a.id,'activity.set_permissions',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update; if a.management_version<>p_expected_version then raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if; perform app_private.activity_v2_set_marker(ctx,'activities.manage_permissions','manage_permissions',correlation);
 perform 1 from public.activity_capabilities capability where capability.code=any(approved) order by capability.id for share;
 perform 1 from public.activity_group_links gl where gl.activity_id=a.id order by gl.id for share;
 perform 1 from public.activity_group_assignments assignment where assignment.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by assignment.id for share;
 perform 1 from public.activity_admin_assignments assignment where assignment.activity_id=a.id order by assignment.id for share;
 if (select count(*) from public.activity_capabilities capability where capability.code=any(approved) and capability.status='active')<>5 then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 delete from public.activity_assignment_capability_actions x using public.activity_group_assignments ga,public.activity_group_links gl where x.assignment_id=ga.id and ga.activity_group_link_id=gl.id and gl.activity_id=a.id; delete from public.activity_admin_capability_actions x using public.activity_admin_assignments aa where x.activity_admin_assignment_id=aa.id and aa.activity_id=a.id; delete from public.activity_group_capability_settings x using public.activity_group_links gl where x.activity_group_link_id=gl.id and gl.activity_id=a.id; delete from public.activity_capability_policies x where x.activity_id=a.id;
 for entry in select * from jsonb_each_text(p_capability_policies) loop if entry.value is not null then select c.id into cap from public.activity_capabilities c where c.code=entry.key and c.status='active'; insert into public.activity_capability_policies(activity_id,institution_id,capability_id,policy_mode,changed_by_person_id) values(a.id,a.institution_id,cap,entry.value,null); end if; end loop;
 for item in select element.value from jsonb_array_elements(p_group_capability_settings) element loop select x.id into gl from public.activity_group_links x where x.activity_id=a.id and x.group_id=(item->>'group_id')::uuid and x.status='active'; if gl is null then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if; for entry in select * from jsonb_each(item->'capabilities') loop if entry.value<>'null'::jsonb then select c.id into cap from public.activity_capabilities c where c.code=entry.key; insert into public.activity_group_capability_settings(activity_group_link_id,capability_id,is_enabled,changed_by_person_id) values(gl,cap,(entry.value#>>'{}')::boolean,null); end if; end loop; end loop;
 for item in select element.value from jsonb_array_elements(p_professional_capability_actions) element loop if item->>'role'='activity_admin' then select x.id into ass from public.activity_admin_assignments x join public.institution_memberships m on m.id=x.membership_id and m.person_id=x.person_id and m.institution_id=a.institution_id and m.status='active' and m.revoked_at is null join public.people person on person.id=x.person_id and person.person_type='adult' and person.status='active' where x.activity_id=a.id and x.institution_id=a.institution_id and x.membership_id=(item->>'membership_id')::uuid and x.status='active' and x.revoked_at is null; else select x.id into ass from public.activity_group_assignments x join public.activity_group_links y on y.id=x.activity_group_link_id and y.institution_id=a.institution_id and y.status='active' join public.institution_memberships m on m.id=x.membership_id and m.person_id=x.person_id and m.institution_id=a.institution_id and m.status='active' and m.revoked_at is null join public.people person on person.id=x.person_id and person.person_type='adult' and person.status='active' where y.activity_id=a.id and y.group_id=(item->>'group_id')::uuid and x.institution_id=a.institution_id and x.membership_id=(item->>'membership_id')::uuid and x.assignment_role='instructor' and x.status='active' and x.revoked_at is null; end if; if ass is null then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if; for entry in select * from jsonb_each_text(item->'actions') loop select c.id into cap from public.activity_capabilities c where c.code=entry.key and c.status='active'; if item->>'role'='activity_admin' then insert into public.activity_admin_capability_actions(activity_admin_assignment_id,capability_id,can_view,can_edit,changed_by_person_id) values(ass,cap,entry.value in('view','both'),entry.value in('edit','both'),null); else insert into public.activity_assignment_capability_actions(assignment_id,capability_id,can_view,can_edit,changed_by_person_id) values(ass,cap,entry.value in('view','both'),entry.value in('edit','both'),null); end if; end loop; end loop;
 update public.activity_definitions x set management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; counts:=pg_catalog.jsonb_build_object('settings',jsonb_array_length(p_group_capability_settings),'actions',jsonb_array_length(p_professional_capability_actions)); correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.manage_permissions','activity.set_permissions',counts); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.set_permissions',h,a.management_version,a.status::text,correlation,counts);
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.manage_permissions','activity.set_permissions',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

create function public.superadmin_activity_publish_v2(p_request_id uuid,p_activity_id uuid,p_expected_version bigint)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text;
begin begin
 select * into strict ctx from app_private.activity_v2_require_context('activities.manage',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1 then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id);
 if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.manage',a.institution_id);
 h:=app_private.activity_v2_command_request_hash('activity.publish',a.institution_id,a.id,p_expected_version,'{}'); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,a.id,'activity.publish',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update;
 if a.management_version<>p_expected_version then raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
 perform 1 from public.activity_taxonomies t where t.id=a.taxonomy_id order by t.id for share;
 perform 1 from public.activity_unit_links ul where ul.activity_id=a.id order by ul.id for share;
 perform 1 from public.units u where u.id in(select ul.unit_id from public.activity_unit_links ul where ul.activity_id=a.id) order by u.id for share;
 perform 1 from public.activity_group_links gl where gl.activity_id=a.id order by gl.id for share;
 perform 1 from public.groups g where g.id in(select gl.group_id from public.activity_group_links gl where gl.activity_id=a.id) order by g.id for share;
 perform 1 from public.activity_group_participants p join public.activity_group_links gl on gl.id=p.activity_group_link_id where gl.activity_id=a.id order by p.id for share of p;
 perform 1 from public.child_group_links cgl where cgl.id in(select p.child_group_link_id from public.activity_group_participants p join public.activity_group_links gl on gl.id=p.activity_group_link_id where gl.activity_id=a.id and p.status='active') order by cgl.id for share;
 perform 1 from public.child_unit_links cul where cul.id in(select cgl.child_unit_link_id from public.child_group_links cgl where cgl.id in(select p.child_group_link_id from public.activity_group_participants p join public.activity_group_links gl on gl.id=p.activity_group_link_id where gl.activity_id=a.id and p.status='active')) order by cul.id for share;
 perform 1 from public.child_contexts cc where cc.id in(select cul.child_context_id from public.child_unit_links cul where cul.id in(select cgl.child_unit_link_id from public.child_group_links cgl where cgl.id in(select p.child_group_link_id from public.activity_group_participants p join public.activity_group_links gl on gl.id=p.activity_group_link_id where gl.activity_id=a.id and p.status='active'))) order by cc.id for share;
 perform 1 from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id where gl.activity_id=a.id order by ga.id for share of ga;
 perform 1 from public.activity_admin_assignments aa where aa.activity_id=a.id order by aa.id for share;
 perform 1 from public.institution_memberships m where m.id in(select ga.membership_id from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id where gl.activity_id=a.id and ga.status='active' union select aa.membership_id from public.activity_admin_assignments aa where aa.activity_id=a.id and aa.status='active') order by m.id for share;
 perform 1 from public.people person where person.id in(select m.person_id from public.institution_memberships m where m.id in(select ga.membership_id from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id where gl.activity_id=a.id and ga.status='active' union select aa.membership_id from public.activity_admin_assignments aa where aa.activity_id=a.id and aa.status='active')) order by person.id for share;
 perform 1 from public.activity_assignment_capability_actions action where action.assignment_id in(select ga.id from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id where gl.activity_id=a.id and ga.status='active') order by action.id for share;
 perform 1 from public.activity_admin_capability_actions action where action.activity_admin_assignment_id in(select aa.id from public.activity_admin_assignments aa where aa.activity_id=a.id and aa.status='active') order by action.id for share;
 perform 1 from public.activity_capability_policies p where p.activity_id=a.id order by p.id for share;
 perform 1 from public.activity_group_capability_settings s join public.activity_group_links gl on gl.id=s.activity_group_link_id where gl.activity_id=a.id order by s.id for share of s;
 if a.status<>'draft' or not exists(select 1 from public.activity_taxonomies t where t.id=a.taxonomy_id and t.status='active' and t.code<>'outros')
 or not exists(select 1 from public.activity_unit_links ul join public.units u on u.id=ul.unit_id where ul.activity_id=a.id and ul.status='active' and ul.institution_id=a.institution_id and u.institution_id=a.institution_id and u.status='active')
 or exists(select 1 from public.activity_unit_links ul left join public.units u on u.id=ul.unit_id and u.institution_id=a.institution_id and u.status='active' where ul.activity_id=a.id and ul.status='active' and (ul.institution_id<>a.institution_id or u.id is null))
 or (a.origin_scope_kind='unit' and not exists(select 1 from public.activity_unit_links ul join public.units u on u.id=ul.unit_id where ul.activity_id=a.id and ul.unit_id=a.origin_unit_id and ul.status='active' and u.institution_id=a.institution_id and u.status='active'))
 or not exists(select 1 from public.activity_group_links gl join public.groups g on g.id=gl.group_id where gl.activity_id=a.id and gl.status='active' and gl.institution_id=a.institution_id and g.institution_id=a.institution_id and g.unit_id=gl.unit_id and g.status='active')
 or exists(select 1 from public.activity_group_links gl left join public.groups g on g.id=gl.group_id and g.institution_id=a.institution_id and g.unit_id=gl.unit_id and g.status='active' left join public.activity_unit_links ul on ul.activity_id=a.id and ul.unit_id=gl.unit_id and ul.status='active' where gl.activity_id=a.id and gl.status='active' and (gl.institution_id<>a.institution_id or g.id is null or ul.id is null))
 or exists(select 1 from public.activity_group_participants p join public.activity_group_links gl on gl.id=p.activity_group_link_id left join public.child_group_links cgl on cgl.id=p.child_group_link_id and cgl.group_id=gl.group_id and cgl.status='active' left join public.child_unit_links cul on cul.id=cgl.child_unit_link_id and cul.unit_id=gl.unit_id and cul.status='active' left join public.child_contexts cc on cc.id=cul.child_context_id and cc.institution_id=a.institution_id and cc.status='active' left join public.people child on child.id=cc.child_person_id and child.person_type='child' and child.status='active' where gl.activity_id=a.id and p.status='active' and (p.removed_at is not null or gl.status<>'active' or cgl.id is null or cul.id is null or cc.id is null or child.id is null))
 or exists(select 1 from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id left join public.institution_memberships m on m.id=ga.membership_id and m.institution_id=a.institution_id and m.person_id=ga.person_id and m.status='active' and m.revoked_at is null left join public.people person on person.id=ga.person_id and person.person_type='adult' and person.status='active' where gl.activity_id=a.id and ga.status='active' and ga.revoked_at is null and (gl.status<>'active' or ga.institution_id<>a.institution_id or m.id is null or person.id is null))
 or exists(select 1 from public.activity_admin_assignments aa left join public.institution_memberships m on m.id=aa.membership_id and m.institution_id=a.institution_id and m.person_id=aa.person_id and m.status='active' and m.revoked_at is null left join public.people person on person.id=aa.person_id and person.person_type='adult' and person.status='active' where aa.activity_id=a.id and aa.status='active' and aa.revoked_at is null and (aa.institution_id<>a.institution_id or m.id is null or person.id is null))
 or exists(select 1 from public.activity_capability_policies policy join public.activity_group_capability_settings setting on setting.capability_id=policy.capability_id join public.activity_group_links gl on gl.id=setting.activity_group_link_id where policy.activity_id=a.id and gl.activity_id=a.id and ((policy.policy_mode='prohibited' and setting.is_enabled) or (policy.policy_mode='required' and not setting.is_enabled)))
 or exists(select 1 from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id where gl.activity_id=a.id and ga.status='active' and ga.revoked_at is null and ga.assignment_role='instructor' and ((select count(*) from public.activity_assignment_capability_actions action where action.assignment_id=ga.id)<>5 or (select count(*) from public.activity_assignment_capability_actions action join public.activity_capabilities c on c.id=action.capability_id where action.assignment_id=ga.id and c.status='active' and c.code in('chat','now','happens','moments','attendance'))<>5))
 or exists(select 1 from public.activity_admin_assignments aa where aa.activity_id=a.id and aa.status='active' and aa.revoked_at is null and ((select count(*) from public.activity_admin_capability_actions action where action.activity_admin_assignment_id=aa.id)<>5 or (select count(*) from public.activity_admin_capability_actions action join public.activity_capabilities c on c.id=action.capability_id where action.activity_admin_assignment_id=aa.id and c.status='active' and c.code in('chat','now','happens','moments','attendance'))<>5))
 then raise invalid_parameter_value using detail='ACTIVITY_INVALID_STATE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.manage','manage',correlation); update public.activity_definitions x set status='active',management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.manage','activity.publish','{}'); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.publish',h,a.management_version,a.status::text,correlation,'{}');
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.manage','activity.publish',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

do $$declare p regprocedure; begin
 foreach p in array array[
  'app_private.activity_v2_success_envelope(jsonb)'::regprocedure,'app_private.activity_v2_require_context(text,uuid)'::regprocedure,
  'app_private.activity_v2_normalize_error(text)'::regprocedure,
  'app_private.activity_v2_denied_envelope(text,text,text,uuid,uuid)'::regprocedure,
  'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)'::regprocedure,
  'app_private.activity_v2_set_marker(app_private.superadmin_internal_context,text,text,uuid)'::regprocedure,
  'app_private.audit_activity_change()'::regprocedure,
  'app_private.activity_v2_append_audit(app_private.superadmin_internal_context,uuid,uuid,text,text,jsonb)'::regprocedure,
  'app_private.activity_v2_finish_command(app_private.superadmin_internal_context,uuid,uuid,uuid,text,bytea,bigint,text,uuid,jsonb)'::regprocedure,
  'app_private.activity_v2_replay_or_error(app_private.superadmin_internal_context,uuid,uuid,uuid,text,bytea,uuid)'::regprocedure,
  'app_private.activity_v2_effective_permission(text,text,text,text,text,text,text,text)'::regprocedure,
  'app_private.activity_v2_validate_participants(uuid,jsonb)'::regprocedure,'app_private.activity_v2_validate_professionals(uuid,jsonb)'::regprocedure,
  'public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean)'::regprocedure,'public.superadmin_activity_detail_v2(uuid,text[])'::regprocedure,
  'public.superadmin_activity_form_options_v2(uuid,text[],text,integer)'::regprocedure,'public.superadmin_activity_create_v2(uuid,jsonb)'::regprocedure,
  'public.superadmin_activity_update_v2(uuid,uuid,bigint,jsonb)'::regprocedure,'public.superadmin_activity_publish_v2(uuid,uuid,bigint)'::regprocedure,
  'public.superadmin_activity_set_units_v2(uuid,uuid,bigint,uuid[])'::regprocedure,'public.superadmin_activity_set_groups_v2(uuid,uuid,bigint,uuid[],jsonb)'::regprocedure,
  'public.superadmin_activity_set_participants_v2(uuid,uuid,bigint,jsonb)'::regprocedure,'public.superadmin_activity_set_professionals_v2(uuid,uuid,bigint,jsonb)'::regprocedure,
  'public.superadmin_activity_set_permissions_v2(uuid,uuid,bigint,jsonb,jsonb,jsonb)'::regprocedure
 ] loop execute format('alter function %s owner to postgres',p); execute format('revoke all on function %s from public,anon,authenticated,service_role',p); end loop;
end $$;

commit;
