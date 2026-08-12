-- Privileged Superadmin activity read models.
begin;

alter table public.activity_definitions
 add column if not exists identity_checksum_sha256 text
 check(identity_checksum_sha256 is null or identity_checksum_sha256 ~ '^[0-9a-f]{64}$');

create or replace function app_private.activity_management_payload(p_activity_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$
 select jsonb_build_object(
  'activity',to_jsonb(activity),
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
      and link.status='active'
    where location.status='active'),'[]'::jsonb)
 ) from public.activity_definitions activity where activity.id=p_activity_id
$$;
revoke all on function app_private.activity_management_payload(uuid) from public,anon,authenticated;

create or replace function app_private.superadmin_activity_directory(
 p_search text,p_institution_ids uuid[],p_unit_ids uuid[],p_group_ids uuid[],
 p_statuses text[],p_origins text[],p_limit integer,p_offset integer,
 p_sort text,p_sort_ascending boolean
) returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb; normalized_search text:=lower(nullif(btrim(p_search),''));
begin
 if (select auth.uid()) is null or
    not app_private.has_platform_permission('activities.read') then
  raise insufficient_privilege using message='activities.read required';
 end if;
 if p_limit not between 1 and 100 or p_offset<0
    or p_sort not in ('name','institution','status','created_at','updated_at') then
  raise invalid_parameter_value using message='invalid directory parameters';
 end if;
 if exists(select 1 from unnest(coalesce(p_statuses,'{}')) value
   where value not in ('draft','active','inactive','suspended','archived'))
   or exists(select 1 from unnest(coalesce(p_origins,'{}')) value
   where value not in ('institution','unit')) then
  raise invalid_parameter_value using message='invalid directory filter';
 end if;
 with filtered as (
  select activity.*,institution.public_name institution_name,
    unit.name origin_unit_name,taxonomy.name taxonomy_name,
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',linked_unit.id,'name',linked_unit.name,
      'institution_id',linked_unit.institution_id) order by linked_unit.name)
      from public.activity_unit_links unit_link
      join public.units linked_unit on linked_unit.id=unit_link.unit_id
       and linked_unit.institution_id=unit_link.institution_id
      where unit_link.activity_id=activity.id and unit_link.status='active'),'[]'::jsonb)
      linked_units,
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',linked_group.id,'name',linked_group.name,'unit_id',linked_group.unit_id,
      'unit_name',group_unit.name) order by group_unit.name,linked_group.name)
      from public.activity_group_links group_link
      join public.groups linked_group on linked_group.id=group_link.group_id
      join public.units group_unit on group_unit.id=linked_group.unit_id
      where group_link.activity_id=activity.id and group_link.status='active'),'[]'::jsonb)
      linked_groups,
    coalesce((select jsonb_agg(distinct location.name order by location.name)
      from public.activity_unit_links unit_link
      join public.activity_locations location on location.unit_id=unit_link.unit_id
       and location.institution_id=unit_link.institution_id and location.status='active'
      where unit_link.activity_id=activity.id and unit_link.status='active'),'[]'::jsonb)
      location_names,
    (select count(distinct assignment.person_id)
      from public.activity_group_assignments assignment
      join public.activity_group_links group_link
       on group_link.id=assignment.activity_group_link_id
      where group_link.activity_id=activity.id and group_link.status='active'
       and assignment.status='active' and assignment.revoked_at is null)
      active_professional_count,
    (select count(*) from public.activity_group_participants participant
      join public.activity_group_links group_link
       on group_link.id=participant.activity_group_link_id
      where group_link.activity_id=activity.id and group_link.status='active'
       and participant.status='active' and participant.removed_at is null)
      active_participant_count
  from public.activity_definitions activity
  join public.institutions institution on institution.id=activity.institution_id
  left join public.units unit on unit.id=activity.origin_unit_id
   and unit.institution_id=activity.institution_id
  left join public.activity_taxonomies taxonomy on taxonomy.id=activity.taxonomy_id
  where (normalized_search is null
    or position(normalized_search in lower(activity.name||' '||activity.canonical_handle))>0
    or exists(select 1 from public.activity_handle_aliases alias_record
      where alias_record.activity_id=activity.id
       and position(normalized_search in lower(alias_record.alias))>0))
   and (cardinality(coalesce(p_institution_ids,'{}'))=0
     or activity.institution_id=any(p_institution_ids))
   and (cardinality(coalesce(p_unit_ids,'{}'))=0 or exists(
     select 1 from public.activity_unit_links unit_link
      where unit_link.activity_id=activity.id and unit_link.status='active'
       and unit_link.unit_id=any(p_unit_ids)))
   and (cardinality(coalesce(p_group_ids,'{}'))=0 or exists(
     select 1 from public.activity_group_links group_link
      where group_link.activity_id=activity.id and group_link.status='active'
       and group_link.group_id=any(p_group_ids)))
   and (cardinality(coalesce(p_statuses,'{}'))=0 or activity.status::text=any(p_statuses))
   and (cardinality(coalesce(p_origins,'{}'))=0 or activity.origin_scope_kind::text=any(p_origins))
 ), ordered as (
  select filtered.*,count(*) over() total_count from filtered
  order by
   case when p_sort='name' and p_sort_ascending then lower(name) end asc,
   case when p_sort='name' and not p_sort_ascending then lower(name) end desc,
   case when p_sort='institution' and p_sort_ascending then lower(institution_name) end asc,
   case when p_sort='institution' and not p_sort_ascending then lower(institution_name) end desc,
   case when p_sort='status' and p_sort_ascending then status::text end asc,
   case when p_sort='status' and not p_sort_ascending then status::text end desc,
   case when p_sort='created_at' and p_sort_ascending then created_at end asc,
   case when p_sort='created_at' and not p_sort_ascending then created_at end desc,
   case when p_sort='updated_at' and p_sort_ascending then updated_at end asc,
   case when p_sort='updated_at' and not p_sort_ascending then updated_at end desc,id
  limit p_limit offset p_offset
 )
 select jsonb_build_object(
  'items',coalesce(jsonb_agg(to_jsonb(ordered)-'total_count'),'[]'::jsonb),
  'total_count',coalesce(max(total_count),0)
 ) into result from ordered;
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
 if p_institution_id is not null and not exists(
  select 1 from public.institutions institution where institution.id=p_institution_id
 ) then raise no_data_found using message='institution not found'; end if;
 select jsonb_build_object(
  'institutions',coalesce((select jsonb_agg(jsonb_build_object(
    'id',institution.id,'name',institution.public_name,'slug',institution.slug,
    'status',institution.status) order by institution.public_name)
    from public.institutions institution
    where p_institution_id is null or institution.id=p_institution_id),'[]'::jsonb),
  'units',coalesce((select jsonb_agg(jsonb_build_object(
    'id',unit.id,'institution_id',unit.institution_id,'name',unit.name,
    'slug',unit.slug,'status',unit.status) order by unit.name)
    from public.units unit where (p_institution_id is null or unit.institution_id=p_institution_id)
      and unit.status<>'archived'),'[]'::jsonb),
  'groups',coalesce((select jsonb_agg(jsonb_build_object(
    'id',group_record.id,'institution_id',group_record.institution_id,
    'unit_id',group_record.unit_id,'name',group_record.name,'status',group_record.status)
    order by group_record.name)
    from public.groups group_record
    where (p_institution_id is null or group_record.institution_id=p_institution_id)
      and group_record.status<>'archived'),'[]'::jsonb),
  'locations',coalesce((select jsonb_agg(to_jsonb(location) order by location.name)
    from public.activity_locations location
    where (p_institution_id is null or location.institution_id=p_institution_id)
      and location.status='active'),'[]'::jsonb),
  'taxonomies',coalesce((select jsonb_agg(to_jsonb(taxonomy) order by
    taxonomy.sort_order,taxonomy.name)
    from public.activity_taxonomies taxonomy where taxonomy.status='active'),'[]'::jsonb),
  'templates',coalesce((select jsonb_agg(to_jsonb(template) order by template.name)
    from public.activity_templates template
    where template.status='active' and (
      template.scope_kind='platform' or template.institution_id=p_institution_id
    )),'[]'::jsonb),
  'capabilities',coalesce((select jsonb_agg(to_jsonb(capability) order by capability.name)
    from public.activity_capabilities capability where capability.status='active'),'[]'::jsonb),
  'professionals',coalesce((select jsonb_agg(jsonb_build_object(
    'membership_id',membership.id,'person_id',person.id,
    'institution_id',membership.institution_id,'display_name',person.display_name,
    'role_code',membership.role_code) order by person.display_name)
    from public.institution_memberships membership join public.people person
      on person.id=membership.person_id
    where (p_institution_id is null or membership.institution_id=p_institution_id)
      and membership.status='active' and membership.revoked_at is null
      and person.person_type<>'child' and person.status='active'),'[]'::jsonb),
  'students',coalesce((select jsonb_agg(jsonb_build_object(
    'child_group_link_id',child_group.id,'group_id',child_group.group_id,
    'unit_id',child_unit.unit_id,'person_id',person.id,'name',person.display_name,
    'age',case when person.date_of_birth is null then null
      else date_part('year',age(current_date,person.date_of_birth))::integer end,
    'gender',profile.gender) order by person.display_name)
    from public.child_group_links child_group
    join public.child_unit_links child_unit on child_unit.id=child_group.child_unit_link_id
    join public.child_contexts child_context on child_context.id=child_unit.child_context_id
    join public.people person on person.id=child_context.child_person_id
    left join public.person_profile_details profile on profile.person_id=person.id
    where p_institution_id is not null and child_context.institution_id=p_institution_id
      and child_group.status='active' and child_unit.status='active'
      and child_context.status='active'),'[]'::jsonb)
 ) into result;
 return result;
end $$;

create or replace function app_private.superadmin_activity_filter_options()
returns jsonb language sql stable security definer set search_path=''
as $$select app_private.superadmin_get_activity_form_options(null)$$;

create or replace function public.superadmin_activity_directory(
 p_search text default null,p_institution_ids uuid[] default '{}',p_unit_ids uuid[] default '{}',
 p_group_ids uuid[] default '{}',p_statuses text[] default '{}',p_origins text[] default '{}',
 p_limit integer default 24,p_offset integer default 0,p_sort text default 'name',
 p_sort_ascending boolean default true
) returns jsonb language sql stable security definer set search_path=''
as $$select app_private.superadmin_activity_directory(
 p_search,p_institution_ids,p_unit_ids,p_group_ids,p_statuses,p_origins,
 p_limit,p_offset,p_sort,p_sort_ascending)$$;
create or replace function public.superadmin_activity_filter_options()
returns jsonb language sql stable security definer set search_path=''
as $$select app_private.superadmin_activity_filter_options()$$;
create or replace function public.superadmin_get_activity_form_options(p_institution_id uuid default null)
returns jsonb language sql stable security definer set search_path=''
as $$select app_private.superadmin_get_activity_form_options(p_institution_id)$$;

revoke all on function app_private.superadmin_activity_directory(
 text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean)
 from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_activity_filter_options()
 from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_get_activity_form_options(uuid)
 from public,anon,authenticated,service_role;
revoke all on function public.superadmin_activity_directory(
 text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean)
 from public,anon,authenticated,service_role;
revoke all on function public.superadmin_activity_filter_options()
 from public,anon,authenticated,service_role;
revoke all on function public.superadmin_get_activity_form_options(uuid)
 from public,anon,authenticated,service_role;
grant execute on function public.superadmin_activity_directory(
 text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean) to authenticated;
grant execute on function public.superadmin_activity_filter_options() to authenticated;
grant execute on function public.superadmin_get_activity_form_options(uuid) to authenticated;
commit;
