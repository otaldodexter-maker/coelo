-- The internal Superadmin service person has a platform role rather than an
-- institution membership. Keep institution-scoped actors authorized by their
-- contextual role, and let a platform role act only inside its granted scope.
begin;

create or replace function app_private.student_link_require_scope(
  p_child_context_id uuid,
  p_unit_id uuid,
  p_group_id uuid
) returns uuid
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  institution uuid;
begin
  if actor is null then
    raise insufficient_privilege using message='authentication required';
  end if;
  select child_row.institution_id into institution
  from public.child_contexts child_row
  where child_row.id = p_child_context_id
    and child_row.status = 'active';
  if institution is null then
    raise no_data_found using message='student link unavailable';
  end if;
  if not (
    app_private.has_scoped_platform_permission('people.assign_children', institution)
    or app_private.has_context_permission(
      institution, 'people.assign_children', p_unit_id, p_group_id, null,
      p_child_context_id, false
    )
  ) then
    raise insufficient_privilege using message='people.assign_children required';
  end if;
  if p_unit_id is not null and not exists (
    select 1 from public.units unit_row
    where unit_row.id = p_unit_id and unit_row.institution_id = institution
  ) then
    raise no_data_found using message='student link unavailable';
  end if;
  if p_group_id is not null and not exists (
    select 1 from public.groups group_row
    where group_row.id = p_group_id
      and group_row.unit_id = p_unit_id
      and group_row.institution_id = institution
  ) then
    raise no_data_found using message='student link unavailable';
  end if;
  return institution;
end
$$;

commit;
