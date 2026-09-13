-- R11: count active links using existing inheritance and authorized hierarchy.
create or replace function app_private.superadmin_group_directory(
  p_search text default '', p_institution_ids uuid[] default '{}',
  p_unit_ids uuid[] default '{}', p_type_ids text[] default '{}',
  p_statuses text[] default '{}', p_limit integer default 20,
  p_offset integer default 0, p_sort text default 'name',
  p_sort_ascending boolean default true
) returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare result jsonb;
begin
  if (select auth.uid()) is null or app_private.current_person_id() is null
     or not app_private.has_platform_permission('groups.read') then
    raise insufficient_privilege using message = 'groups.read required';
  end if;
  if p_limit < 1 or p_limit > 100 or p_offset < 0 then
    raise invalid_parameter_value using message = 'invalid pagination';
  end if;
  if p_sort not in ('name', 'institution_name', 'unit_name', 'group_type', 'status') then
    raise invalid_parameter_value using message = 'invalid sort';
  end if;
  with filtered as (
    select group_record.*, institution_record.public_name as institution_name,
           unit_record.name as unit_name, count(*) over() as total_count
    from public.groups group_record
    join public.institutions institution_record on institution_record.id = group_record.institution_id
    join public.units unit_record on unit_record.id = group_record.unit_id
      and unit_record.institution_id = group_record.institution_id
    where app_private.has_platform_permission('groups.read', group_record.institution_id)
      and (nullif(btrim(p_search), '') is null
      or group_record.name ilike '%' || replace(replace(replace(btrim(p_search), '\\', '\\\\'), '%', '\\%'), '_', '\\_') || '%' escape '\\')
      and (cardinality(p_institution_ids) = 0 or group_record.institution_id = any(p_institution_ids))
      and (cardinality(p_unit_ids) = 0 or group_record.unit_id = any(p_unit_ids))
      and (cardinality(p_type_ids) = 0 or group_record.group_type = any(p_type_ids))
      and (cardinality(p_statuses) = 0 or group_record.status::text = any(p_statuses))
    order by
      case when p_sort_ascending and p_sort = 'name' then group_record.name end asc,
      case when not p_sort_ascending and p_sort = 'name' then group_record.name end desc,
      case when p_sort_ascending and p_sort = 'institution_name' then institution_record.public_name end asc,
      case when not p_sort_ascending and p_sort = 'institution_name' then institution_record.public_name end desc,
      case when p_sort_ascending and p_sort = 'unit_name' then unit_record.name end asc,
      case when not p_sort_ascending and p_sort = 'unit_name' then unit_record.name end desc,
      case when p_sort_ascending and p_sort = 'group_type' then group_record.group_type end asc,
      case when not p_sort_ascending and p_sort = 'group_type' then group_record.group_type end desc,
      case when p_sort_ascending and p_sort = 'status' then group_record.status::text end asc,
      case when not p_sort_ascending and p_sort = 'status' then group_record.status::text end desc,
      group_record.id
    limit p_limit offset p_offset
  )
  select jsonb_build_object(
    'items', coalesce(jsonb_agg(jsonb_build_object(
      'id', id, 'institution_id', institution_id, 'institution_name', institution_name,
      'unit_id', unit_id, 'unit_name', unit_name, 'name', name,
      'group_type', group_type, 'group_type_other_text', group_type_other_text,
      'status', status, 'created_at', created_at, 'updated_at', updated_at,
      'student_count', jsonb_array_length(app_private.superadmin_group_students_payload(filtered.id)),
      'activity_ids', case when filtered.inherit_activities then
        coalesce((select jsonb_agg(distinct link.activity_id order by link.activity_id)
          from public.activity_unit_links link
          join public.activity_definitions activity on activity.id=link.activity_id
            and activity.institution_id=filtered.institution_id
          where link.unit_id=filtered.unit_id and link.institution_id=filtered.institution_id
            and link.status='active'), '[]'::jsonb)
        else coalesce((select jsonb_agg(distinct link.activity_id order by link.activity_id)
          from public.activity_group_links link
          join public.activity_definitions activity on activity.id=link.activity_id
            and activity.institution_id=filtered.institution_id
          where link.group_id=filtered.id and link.unit_id=filtered.unit_id
            and link.institution_id=filtered.institution_id and link.status='active'), '[]'::jsonb)
        end
    )), '[]'::jsonb),
    'total_count', coalesce(max(total_count), 0)
  ) into result from filtered;
  return result;
end $$;
