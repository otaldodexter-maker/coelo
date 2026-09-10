begin;

create or replace function app_private.superadmin_activity_template_options(
 p_institution_id uuid
) returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 if (select auth.uid()) is null
    or not app_private.has_platform_permission('activities.read') then
  raise insufficient_privilege using message='activities.read required';
 end if;
 if p_institution_id is not null and not exists(
  select 1 from public.institutions institution
  where institution.id=p_institution_id
 ) then
  raise no_data_found using message='institution not found';
 end if;
 select jsonb_build_object(
  'institutions',coalesce((select jsonb_agg(jsonb_build_object(
    'id',institution.id,'name',institution.public_name)
    order by institution.public_name)
    from public.institutions institution
    where p_institution_id is null or institution.id=p_institution_id),'[]'::jsonb),
  'taxonomy',coalesce((select jsonb_agg(jsonb_build_object(
    'id',category.id,'label',category.name,'is_other',category.code='outros',
    'subtypes',coalesce((select jsonb_agg(jsonb_build_object(
      'id',subtype.id,'label',subtype.name)
      order by subtype.sort_order,subtype.name)
      from public.activity_taxonomies subtype
      where subtype.parent_id=category.id and subtype.status='active'),'[]'::jsonb))
    order by category.sort_order,category.name)
    from public.activity_taxonomies category
    where category.taxonomy_kind='category'
     and category.status='active'),'[]'::jsonb),
  'templates',coalesce((select jsonb_agg(jsonb_build_object(
    'id',template.id,'name',template.name,
    'description',template.description,
    'scope_kind',template.scope_kind,
    'institution_id',template.institution_id,
    'governance_kind',template.governance_kind,
    'taxonomy_id',coalesce(taxonomy.parent_id,taxonomy.id),
    'subtype_id',case when taxonomy.taxonomy_kind='subtype' then taxonomy.id end)
    order by template.scope_kind desc,template.name)
    from public.activity_templates template
    join public.activity_taxonomies taxonomy on taxonomy.id=template.taxonomy_id
    where template.status='active'
     and (template.scope_kind='platform'
      or (p_institution_id is not null
       and template.institution_id=p_institution_id))),'[]'::jsonb)
 ) into result;
 return result;
end $$;

create or replace function public.superadmin_activity_template_options(
 p_institution_id uuid default null
) returns jsonb language sql stable security definer set search_path=''
as $$select app_private.superadmin_activity_template_options(p_institution_id)$$;

revoke all on function app_private.superadmin_activity_template_options(uuid)
 from public,anon,authenticated,service_role;
revoke all on function public.superadmin_activity_template_options(uuid)
 from public,anon,authenticated,service_role;
grant execute on function public.superadmin_activity_template_options(uuid)
 to authenticated;

commit;
