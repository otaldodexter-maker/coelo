-- Read projection for Turmas. Student membership is contextual and therefore
-- never appears in effective_access, which is reserved for institutional roles.
create or replace function app_private.superadmin_group_students_payload(
  p_group_id uuid
) returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'child_context_id', child_context.id,
    'person_id', child_person.id,
    'display_name', child_person.display_name,
    'status', group_link.status
  ) order by child_person.display_name, child_context.id), '[]'::jsonb)
  from public.groups group_row
  join public.child_group_links group_link
    on group_link.group_id=group_row.id and group_link.status='active'
  join public.child_unit_links unit_link
    on unit_link.id=group_link.child_unit_link_id
    and unit_link.status='active' and unit_link.unit_id=group_row.unit_id
  join public.child_contexts child_context
    on child_context.id=unit_link.child_context_id
    and child_context.status='active'
    and child_context.institution_id=group_row.institution_id
  join public.people child_person
    on child_person.id=child_context.child_person_id and child_person.status='active'
  where group_row.id=p_group_id and group_row.status='active'
$$;

-- Both public entry points already authorize before their private command. The
-- projection remains app_private and cannot be called by a client directly.
create or replace function public.superadmin_group_get(p_group_id uuid)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select app_private.superadmin_group_get(p_group_id)
    || jsonb_build_object('students', app_private.superadmin_group_students_payload(p_group_id))
$$;

create or replace function public.superadmin_group_save(
  p_request_id uuid, p_group_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb
language sql
volatile
security definer
set search_path=''
as $$
  with saved as (
    select app_private.superadmin_group_save(
      p_request_id, p_group_id, p_expected_version, p_payload
    ) as value
  )
  select value || jsonb_build_object(
    'students', app_private.superadmin_group_students_payload((value->>'id')::uuid)
  ) from saved
$$;

revoke all on function app_private.superadmin_group_students_payload(uuid) from public, anon, authenticated;
revoke all on function public.superadmin_group_get(uuid) from public, anon;
grant execute on function public.superadmin_group_get(uuid) to authenticated;
revoke all on function public.superadmin_group_save(uuid,uuid,bigint,jsonb) from public, anon;
grant execute on function public.superadmin_group_save(uuid,uuid,bigint,jsonb) to authenticated;
