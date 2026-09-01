begin;

create or replace function app_private.activity_v2_safe_uuid(p_value text)
returns uuid
language plpgsql
immutable
strict
security invoker
set search_path = ''
as $$
begin
  return p_value::uuid;
exception
  when invalid_text_representation then
    raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
end
$$;

create or replace function app_private.activity_v2_validate_participants(p_institution_id uuid,p_participants jsonb)
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
     where cgl.id=app_private.activity_v2_safe_uuid(item->>'child_group_link_id') and cgl.group_id=app_private.activity_v2_safe_uuid(item->>'group_id') and cgl.status='active'
       and cc.institution_id=p_institution_id) else false end)
 and (select count(*)=count(distinct (item->>'group_id',item->>'child_group_link_id')) from jsonb_array_elements(p_participants) item) end
$$;

create or replace function app_private.activity_v2_validate_professionals(p_institution_id uuid,p_professionals jsonb)
returns boolean language sql stable security definer set search_path='' as $$
 select case when jsonb_typeof(p_professionals) is distinct from 'array' then false else
 jsonb_array_length(p_professionals)<=500
 and not exists(select 1 from jsonb_array_elements(p_professionals) item
  where jsonb_typeof(item)<>'object' or not(item ?& array['membership_id','role','group_id']) or item-array['membership_id','role','group_id']<>'{}'::jsonb
   or jsonb_typeof(item->'membership_id')<>'string' or jsonb_typeof(item->'role')<>'string'
   or item->>'role' not in('instructor','activity_admin')
   or (item->>'role'='instructor' and nullif(item->>'group_id','') is null)
   or (item->>'role'='instructor' and app_private.activity_v2_safe_uuid(item->>'group_id') is null)
   or (item->>'role'='activity_admin' and item->'group_id'<>'null'::jsonb)
   or not exists(select 1 from public.institution_memberships m join public.people p on p.id=m.person_id
    where m.id=app_private.activity_v2_safe_uuid(item->>'membership_id') and m.institution_id=p_institution_id
      and m.status='active' and m.revoked_at is null and p.person_type='adult' and p.status='active'))
 and (select count(*)=count(distinct (item->>'membership_id',item->>'role',coalesce(item->>'group_id',''))) from jsonb_array_elements(p_professionals) item) end
$$;

create or replace function public.superadmin_activity_directory_v2(
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
  institution_filter:=app_private.activity_v2_safe_uuid(nullif(p_filters->>'institution_id',''));
  unit_filter:=app_private.activity_v2_safe_uuid(nullif(p_filters->>'unit_id','')); group_filter:=app_private.activity_v2_safe_uuid(nullif(p_filters->>'group_id',''));
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

create or replace function public.superadmin_activity_set_permissions_v2(p_request_id uuid,p_activity_id uuid,p_expected_version bigint,p_capability_policies jsonb,p_group_capability_settings jsonb,p_professional_capability_actions jsonb)
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
 or jsonb_array_length(p_group_capability_settings)>200 or jsonb_array_length(p_professional_capability_actions)>500
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
 for item in select element.value from jsonb_array_elements(p_group_capability_settings) element loop select x.id into gl from public.activity_group_links x where x.activity_id=a.id and x.group_id=app_private.activity_v2_safe_uuid(item->>'group_id') and x.status='active'; if gl is null then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if; for entry in select * from jsonb_each(item->'capabilities') loop if entry.value<>'null'::jsonb then select c.id into cap from public.activity_capabilities c where c.code=entry.key; insert into public.activity_group_capability_settings(activity_group_link_id,capability_id,is_enabled,changed_by_person_id) values(gl,cap,(entry.value#>>'{}')::boolean,null); end if; end loop; end loop;
 for item in select element.value from jsonb_array_elements(p_professional_capability_actions) element loop if item->>'role'='activity_admin' then select x.id into ass from public.activity_admin_assignments x join public.institution_memberships m on m.id=x.membership_id and m.person_id=x.person_id and m.institution_id=a.institution_id and m.status='active' and m.revoked_at is null join public.people person on person.id=x.person_id and person.person_type='adult' and person.status='active' where x.activity_id=a.id and x.institution_id=a.institution_id and x.membership_id=app_private.activity_v2_safe_uuid(item->>'membership_id') and x.status='active' and x.revoked_at is null; else select x.id into ass from public.activity_group_assignments x join public.activity_group_links y on y.id=x.activity_group_link_id and y.institution_id=a.institution_id and y.status='active' join public.institution_memberships m on m.id=x.membership_id and m.person_id=x.person_id and m.institution_id=a.institution_id and m.status='active' and m.revoked_at is null join public.people person on person.id=x.person_id and person.person_type='adult' and person.status='active' where y.activity_id=a.id and y.group_id=app_private.activity_v2_safe_uuid(item->>'group_id') and x.institution_id=a.institution_id and x.membership_id=app_private.activity_v2_safe_uuid(item->>'membership_id') and x.assignment_role='instructor' and x.status='active' and x.revoked_at is null; end if; if ass is null then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if; for entry in select * from jsonb_each_text(item->'actions') loop select c.id into cap from public.activity_capabilities c where c.code=entry.key and c.status='active'; if item->>'role'='activity_admin' then insert into public.activity_admin_capability_actions(activity_admin_assignment_id,capability_id,can_view,can_edit,changed_by_person_id) values(ass,cap,entry.value in('view','both'),entry.value in('edit','both'),null); else insert into public.activity_assignment_capability_actions(assignment_id,capability_id,can_view,can_edit,changed_by_person_id) values(ass,cap,entry.value in('view','both'),entry.value in('edit','both'),null); end if; end loop; end loop;
 update public.activity_definitions x set management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; counts:=pg_catalog.jsonb_build_object('settings',jsonb_array_length(p_group_capability_settings),'actions',jsonb_array_length(p_professional_capability_actions)); correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.manage_permissions','activity.set_permissions',counts); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.set_permissions',h,a.management_version,a.status::text,correlation,counts);
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.manage_permissions','activity.set_permissions',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

create or replace function public.superadmin_activity_publish_v2(p_request_id uuid,p_activity_id uuid,p_expected_version bigint)
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
 if a.status<>'draft' or length(btrim(a.name)) not between 1 and 120 or not exists(select 1 from public.activity_taxonomies t where t.id=a.taxonomy_id and t.status='active' and t.code<>'outros')
 or not exists(select 1 from public.activity_unit_links ul join public.units u on u.id=ul.unit_id where ul.activity_id=a.id and ul.status='active' and ul.institution_id=a.institution_id and u.institution_id=a.institution_id and u.status='active')
 or exists(select 1 from public.activity_unit_links ul left join public.units u on u.id=ul.unit_id and u.institution_id=a.institution_id and u.status='active' where ul.activity_id=a.id and ul.status='active' and (ul.institution_id<>a.institution_id or u.id is null))
 or (a.origin_scope_kind='unit' and not exists(select 1 from public.activity_unit_links ul join public.units u on u.id=ul.unit_id where ul.activity_id=a.id and ul.unit_id=a.origin_unit_id and ul.status='active' and u.institution_id=a.institution_id and u.status='active'))
 or not exists(select 1 from public.activity_group_links gl join public.groups g on g.id=gl.group_id where gl.activity_id=a.id and gl.status='active' and gl.institution_id=a.institution_id and g.institution_id=a.institution_id and g.unit_id=gl.unit_id and g.status='active')
 or exists(select 1 from public.activity_group_links gl left join public.groups g on g.id=gl.group_id and g.institution_id=a.institution_id and g.unit_id=gl.unit_id and g.status='active' left join public.activity_unit_links ul on ul.activity_id=a.id and ul.unit_id=gl.unit_id and ul.status='active' where gl.activity_id=a.id and gl.status='active' and (gl.institution_id<>a.institution_id or g.id is null or ul.id is null))
 or exists(select 1 from public.activity_group_participants p join public.activity_group_links gl on gl.id=p.activity_group_link_id left join public.child_group_links cgl on cgl.id=p.child_group_link_id and cgl.group_id=gl.group_id and cgl.status='active' left join public.child_unit_links cul on cul.id=cgl.child_unit_link_id and cul.unit_id=gl.unit_id and cul.status='active' left join public.child_contexts cc on cc.id=cul.child_context_id and cc.institution_id=a.institution_id and cc.status='active' left join public.people child on child.id=cc.child_person_id and child.person_type='child' and child.status='active' where gl.activity_id=a.id and p.status='active' and (p.removed_at is not null or gl.status<>'active' or cgl.id is null or cul.id is null or cc.id is null or child.id is null))
 or exists(select 1 from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id left join public.institution_memberships m on m.id=ga.membership_id and m.institution_id=a.institution_id and m.person_id=ga.person_id and m.status='active' and m.revoked_at is null left join public.people person on person.id=ga.person_id and person.person_type='adult' and person.status='active' where gl.activity_id=a.id and ga.status='active' and ga.revoked_at is null and (gl.status<>'active' or ga.institution_id<>a.institution_id or m.id is null or person.id is null))
 or exists(select 1 from public.activity_admin_assignments aa left join public.institution_memberships m on m.id=aa.membership_id and m.institution_id=a.institution_id and m.person_id=aa.person_id and m.status='active' and m.revoked_at is null left join public.people person on person.id=aa.person_id and person.person_type='adult' and person.status='active' where aa.activity_id=a.id and aa.status='active' and aa.revoked_at is null and (aa.institution_id<>a.institution_id or m.id is null or person.id is null))
 or exists(select 1 from public.activity_capability_policies policy join public.activity_group_capability_settings setting on setting.capability_id=policy.capability_id join public.activity_group_links gl on gl.id=setting.activity_group_link_id where policy.activity_id=a.id and gl.activity_id=a.id and ((policy.policy_mode='prohibited' and setting.is_enabled) or (policy.policy_mode='required' and not setting.is_enabled)))
 or exists(select 1 from public.activity_capability_policies policy join public.activity_group_assignments ga on ga.status='active' and ga.revoked_at is null and ga.assignment_role='instructor' join public.activity_group_links gl on gl.id=ga.activity_group_link_id and gl.activity_id=policy.activity_id join public.activity_assignment_capability_actions action on action.assignment_id=ga.id and action.capability_id=policy.capability_id where policy.activity_id=a.id and policy.policy_mode='required' and not action.can_view and not action.can_edit)
 or exists(select 1 from public.activity_capability_policies policy join public.activity_admin_assignments aa on aa.activity_id=policy.activity_id and aa.status='active' and aa.revoked_at is null join public.activity_admin_capability_actions action on action.activity_admin_assignment_id=aa.id and action.capability_id=policy.capability_id where policy.activity_id=a.id and policy.policy_mode='required' and not action.can_view and not action.can_edit)
 or exists(select 1 from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id where gl.activity_id=a.id and ga.status='active' and ga.revoked_at is null and ga.assignment_role='instructor' and ((select count(*) from public.activity_assignment_capability_actions action where action.assignment_id=ga.id)<>5 or (select count(*) from public.activity_assignment_capability_actions action join public.activity_capabilities c on c.id=action.capability_id where action.assignment_id=ga.id and c.status='active' and c.code in('chat','now','happens','moments','attendance'))<>5))
 or exists(select 1 from public.activity_admin_assignments aa where aa.activity_id=a.id and aa.status='active' and aa.revoked_at is null and ((select count(*) from public.activity_admin_capability_actions action where action.activity_admin_assignment_id=aa.id)<>5 or (select count(*) from public.activity_admin_capability_actions action join public.activity_capabilities c on c.id=action.capability_id where action.activity_admin_assignment_id=aa.id and c.status='active' and c.code in('chat','now','happens','moments','attendance'))<>5))
 then raise invalid_parameter_value using detail='ACTIVITY_INVALID_STATE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.manage','manage',correlation); update public.activity_definitions x set status='active',management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.manage','activity.publish','{}'); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.publish',h,a.management_version,a.status::text,correlation,'{}');
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.manage','activity.publish',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

do $$
declare
  p regprocedure;
begin
  foreach p in array array[
    'app_private.activity_v2_safe_uuid(text)'::regprocedure,
    'app_private.activity_v2_validate_participants(uuid,jsonb)'::regprocedure,
    'app_private.activity_v2_validate_professionals(uuid,jsonb)'::regprocedure,
    'public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean)'::regprocedure,
    'public.superadmin_activity_set_permissions_v2(uuid,uuid,bigint,jsonb,jsonb,jsonb)'::regprocedure,
    'public.superadmin_activity_publish_v2(uuid,uuid,bigint)'::regprocedure
  ] loop
    execute format('alter function %s owner to postgres', p);
    execute format('revoke all on function %s from public, anon, authenticated, service_role', p);
  end loop;
end
$$;

grant execute on function public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean) to authenticated;
grant execute on function public.superadmin_activity_set_permissions_v2(uuid,uuid,bigint,jsonb,jsonb,jsonb) to authenticated;
grant execute on function public.superadmin_activity_publish_v2(uuid,uuid,bigint) to authenticated;

commit;
