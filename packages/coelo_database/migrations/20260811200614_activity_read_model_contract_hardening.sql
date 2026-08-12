-- Wire-contract hardening for the Flutter activity repository.
begin;

create or replace function app_private.activity_management_payload(p_activity_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$
 select to_jsonb(activity)||jsonb_build_object(
  'institution_name',institution.public_name,
  'active_unit_count',(select count(*) from public.activity_unit_links link
    where link.activity_id=activity.id and link.status='active'),
  'active_group_count',(select count(*) from public.activity_group_links link
    where link.activity_id=activity.id and link.status='active'),
  'active_professional_count',(select count(distinct assignment.person_id)
    from public.activity_group_assignments assignment
    join public.activity_group_links link on link.id=assignment.activity_group_link_id
    where link.activity_id=activity.id and link.status='active'
     and assignment.status='active' and assignment.revoked_at is null),
  'active_participant_count',(select count(*)
    from public.activity_group_participants participant
    join public.activity_group_links link on link.id=participant.activity_group_link_id
    where link.activity_id=activity.id and link.status='active'
     and participant.status='active' and participant.removed_at is null),
  'location_names',coalesce((select jsonb_agg(distinct location.name order by location.name)
    from public.activity_unit_links link join public.activity_locations location
     on location.unit_id=link.unit_id and location.institution_id=link.institution_id
    where link.activity_id=activity.id and link.status='active'
     and location.status='active'),'[]'::jsonb),
  'linked_units',coalesce((select jsonb_agg(jsonb_build_object(
    'id',unit.id,'name',unit.name,'institution_id',unit.institution_id)
    order by unit.name)
    from public.activity_unit_links link join public.units unit on unit.id=link.unit_id
    where link.activity_id=activity.id and link.status='active'),'[]'::jsonb),
  'linked_groups',coalesce((select jsonb_agg(jsonb_build_object(
    'id',group_record.id,'name',group_record.name,'unit_id',group_record.unit_id,
    'unit_name',unit.name) order by unit.name,group_record.name)
    from public.activity_group_links link
    join public.groups group_record on group_record.id=link.group_id
    join public.units unit on unit.id=group_record.unit_id
    where link.activity_id=activity.id and link.status='active'),'[]'::jsonb),
  'activity_unit_links',coalesce((select jsonb_agg(
    to_jsonb(link)||jsonb_build_object('units',
      jsonb_build_object('id',unit.id,'name',unit.name,'institution_id',unit.institution_id))
    order by unit.name)
    from public.activity_unit_links link join public.units unit on unit.id=link.unit_id
    where link.activity_id=activity.id),'[]'::jsonb),
  'activity_group_links',coalesce((select jsonb_agg(
    to_jsonb(link)||jsonb_build_object(
      'groups',jsonb_build_object('id',group_record.id,'name',group_record.name),
      'units',jsonb_build_object('id',unit.id,'name',unit.name),
      'activity_group_assignments',coalesce((select jsonb_agg(to_jsonb(assignment))
        from public.activity_group_assignments assignment
        where assignment.activity_group_link_id=link.id),'[]'::jsonb),
      'activity_group_participants',coalesce((select jsonb_agg(to_jsonb(participant))
        from public.activity_group_participants participant
        where participant.activity_group_link_id=link.id),'[]'::jsonb))
    order by unit.name,group_record.name)
    from public.activity_group_links link
    join public.groups group_record on group_record.id=link.group_id
    join public.units unit on unit.id=group_record.unit_id
    where link.activity_id=activity.id),'[]'::jsonb),
  'unit_ids',coalesce((select jsonb_agg(link.unit_id order by link.unit_id)
    from public.activity_unit_links link
    where link.activity_id=activity.id and link.status='active'),'[]'::jsonb),
  'group_ids',coalesce((select jsonb_agg(link.group_id order by link.group_id)
    from public.activity_group_links link
    where link.activity_id=activity.id and link.status='active'),'[]'::jsonb),
  'locations',coalesce((select jsonb_agg(to_jsonb(location) order by location.name)
    from public.activity_locations location
    join public.activity_unit_links link on link.unit_id=location.unit_id
     and link.institution_id=location.institution_id and link.activity_id=activity.id
     and link.status='active' where location.status='active'),'[]'::jsonb)
 ) from public.activity_definitions activity
 join public.institutions institution on institution.id=activity.institution_id
 where activity.id=p_activity_id
$$;

create or replace function public.superadmin_activity_directory(
 p_search text default null,p_institution_ids uuid[] default '{}',p_unit_ids uuid[] default '{}',
 p_group_ids uuid[] default '{}',p_statuses text[] default '{}',p_origins text[] default '{}',
 p_limit integer default 24,p_offset integer default 0,p_sort text default 'name',
 p_sort_ascending boolean default true
) returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare payload jsonb; transformed jsonb;
begin
 payload:=app_private.superadmin_activity_directory(
  p_search,p_institution_ids,p_unit_ids,p_group_ids,p_statuses,p_origins,
  p_limit,p_offset,p_sort,p_sort_ascending);
 select jsonb_build_object(
  'items',coalesce(jsonb_agg(item||jsonb_build_object(
    'active_unit_count',jsonb_array_length(coalesce(item->'linked_units','[]'::jsonb)),
    'active_group_count',jsonb_array_length(coalesce(item->'linked_groups','[]'::jsonb)))
   ),'[]'::jsonb),
  'total_count',payload->'total_count') into transformed
 from jsonb_array_elements(coalesce(payload->'items','[]'::jsonb)) item;
 return transformed;
end $$;

create or replace function app_private.superadmin_activity_filter_options()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 if (select auth.uid()) is null or
    not app_private.has_platform_permission('activities.read') then
  raise insufficient_privilege using message='activities.read required';
 end if;
 select jsonb_build_object(
  'institutions',coalesce((select jsonb_agg(jsonb_build_object(
    'id',institution.id,'label',institution.public_name) order by institution.public_name)
    from public.institutions institution where institution.deleted_at is null),'[]'::jsonb),
  'units',coalesce((select jsonb_agg(jsonb_build_object(
    'id',unit.id,'label',unit.name,'institution_id',unit.institution_id) order by unit.name)
    from public.units unit where unit.status<>'archived'),'[]'::jsonb),
  'groups',coalesce((select jsonb_agg(jsonb_build_object(
    'id',group_record.id,'label',group_record.name,'unit_id',group_record.unit_id)
    order by group_record.name)
    from public.groups group_record where group_record.status<>'archived'),'[]'::jsonb)
 ) into result;
 return result;
end $$;

create or replace function app_private.superadmin_get_activity_form_options(p_institution_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 if (select auth.uid()) is null or
    not app_private.has_platform_permission('activities.read') then
  raise insufficient_privilege using message='activities.read required';
 end if;
 if p_institution_id is not null and not exists(select 1 from public.institutions institution
   where institution.id=p_institution_id) then
  raise no_data_found using message='institution not found';
 end if;
 select jsonb_build_object(
  'institutions',coalesce((select jsonb_agg(jsonb_build_object(
    'id',institution.id,'name',institution.public_name) order by institution.public_name)
    from public.institutions institution
    where p_institution_id is null or institution.id=p_institution_id),'[]'::jsonb),
  'units',coalesce((select jsonb_agg(jsonb_build_object(
    'id',unit.id,'institution_id',unit.institution_id,'name',unit.name) order by unit.name)
    from public.units unit where p_institution_id is not null
      and unit.institution_id=p_institution_id and unit.status<>'archived'),'[]'::jsonb),
  'locations',coalesce((select jsonb_agg(jsonb_build_object(
    'id',location.id,'unit_id',location.unit_id,'name',location.name) order by location.name)
    from public.activity_locations location where p_institution_id is not null
      and location.institution_id=p_institution_id and location.status='active'),'[]'::jsonb),
  'groups',coalesce((select jsonb_agg(jsonb_build_object(
    'id',group_record.id,'unit_id',group_record.unit_id,'name',group_record.name,
    'participant_count',(select count(*) from public.child_group_links child_link
      where child_link.group_id=group_record.id and child_link.status='active'))
    order by group_record.name) from public.groups group_record
    where p_institution_id is not null
     and group_record.institution_id=p_institution_id
     and group_record.status<>'archived'),'[]'::jsonb),
  'professionals',coalesce((select jsonb_agg(jsonb_build_object(
    'membership_id',membership.id,'person_id',person.id,'name',person.display_name,
    'role',membership.role_code) order by person.display_name)
    from public.institution_memberships membership
    join public.people person on person.id=membership.person_id
    where p_institution_id is not null
     and membership.institution_id=p_institution_id
     and membership.status='active' and membership.revoked_at is null
     and person.person_type<>'child' and person.status='active'),'[]'::jsonb),
  'students',coalesce((select jsonb_agg(jsonb_build_object(
    'child_group_link_id',child_group.id,'child_id',person.id,
    'group_id',child_group.group_id,'name',person.display_name,
    'age',case when person.date_of_birth is null then null
      else date_part('year',age(current_date,person.date_of_birth))::integer end,
    'gender',profile.gender) order by person.display_name)
    from public.child_group_links child_group
    join public.child_unit_links child_unit on child_unit.id=child_group.child_unit_link_id
    join public.child_contexts child_context on child_context.id=child_unit.child_context_id
    join public.people person on person.id=child_context.child_person_id
    left join public.person_profile_details profile on profile.person_id=person.id
    where p_institution_id is not null
     and child_context.institution_id=p_institution_id
     and child_group.status='active' and child_unit.status='active'
     and child_context.status='active'),'[]'::jsonb),
  'taxonomy',coalesce((select jsonb_agg(jsonb_build_object(
    'id',category.id,'label',category.name,'is_other',category.code='outros',
    'subtypes',coalesce((select jsonb_agg(jsonb_build_object(
      'id',subtype.id,'label',subtype.name) order by subtype.sort_order,subtype.name)
      from public.activity_taxonomies subtype where subtype.parent_id=category.id
       and subtype.status='active'),'[]'::jsonb))
    order by category.sort_order,category.name)
    from public.activity_taxonomies category
    where category.taxonomy_kind='category' and category.status='active'),'[]'::jsonb),
  'templates',coalesce((select jsonb_agg(jsonb_build_object(
    'id',template.id,'name',template.name,
    'description',template.description,
    'scope_kind',template.scope_kind,
    'institution_id',template.institution_id,
    'governance_kind',template.governance_kind,
    'taxonomy_id',coalesce(taxonomy.parent_id,taxonomy.id),
    'subtype_id',case when taxonomy.taxonomy_kind='subtype' then taxonomy.id end)
    order by template.name)
    from public.activity_templates template
    join public.activity_taxonomies taxonomy on taxonomy.id=template.taxonomy_id
    where template.status='active' and (template.scope_kind='platform'
      or template.institution_id=p_institution_id)),'[]'::jsonb)
 ) into result;
 return result;
end $$;

create or replace function app_private.superadmin_activity_detail(p_activity_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 if (select auth.uid()) is null or
    not app_private.has_platform_permission('activities.read') then
  raise insufficient_privilege using message='activities.read required';
 end if;
 result:=app_private.activity_management_payload(p_activity_id);
 if result is null then raise no_data_found using message='activity not found'; end if;
 return result;
end $$;

revoke all on function app_private.activity_management_payload(uuid)
 from public,anon,authenticated;
revoke all on function app_private.superadmin_activity_filter_options()
 from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_get_activity_form_options(uuid)
 from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_activity_detail(uuid)
 from public,anon,authenticated,service_role;
revoke all on function public.superadmin_activity_directory(
 text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean)
 from public,anon,authenticated,service_role;
grant execute on function public.superadmin_activity_directory(
 text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean) to authenticated;
commit;
