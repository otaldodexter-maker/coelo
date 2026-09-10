-- Authorized context catalog consumed by the productive Superadmin Agenda.

create or replace function public.superadmin_agenda_contexts()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_capabilities jsonb;
  v_granted_capabilities jsonb;
  v_restricted_capabilities jsonb;
  v_contexts jsonb;
begin
  v_actor := app_private.assert_agenda_permission('agenda.read', false);

  v_capabilities := pg_catalog.jsonb_build_object(
    'createAgendaItems', app_private.has_platform_permission('agenda.create'),
    'editOwnAgendaItems', app_private.has_platform_permission('agenda.edit_own'),
    'editAllAgendaItems', app_private.has_platform_permission('agenda.edit_all'),
    'publishAgendaItems', app_private.has_platform_permission('agenda.publish'),
    'cancelOrRestoreAgendaItems', app_private.has_platform_permission('agenda.cancel_restore'),
    'manageResponsesAndAuthorizations', app_private.has_platform_permission('agenda.manage_responses'),
    'overrideReservationConflict', app_private.has_platform_permission('agenda.override_reservation')
  );

  select
    coalesce(
      pg_catalog.jsonb_agg(capability.name order by capability.position)
        filter (where capability.allowed),
      '[]'::jsonb
    ),
    coalesce(
      pg_catalog.jsonb_agg(capability.name order by capability.position)
        filter (where not capability.allowed),
      '[]'::jsonb
    )
  into v_granted_capabilities, v_restricted_capabilities
  from (
    values
      (1, 'createAgendaItems', (v_capabilities ->> 'createAgendaItems')::boolean),
      (2, 'editOwnAgendaItems', (v_capabilities ->> 'editOwnAgendaItems')::boolean),
      (3, 'editAllAgendaItems', (v_capabilities ->> 'editAllAgendaItems')::boolean),
      (4, 'publishAgendaItems', (v_capabilities ->> 'publishAgendaItems')::boolean),
      (5, 'cancelOrRestoreAgendaItems', (v_capabilities ->> 'cancelOrRestoreAgendaItems')::boolean),
      (6, 'manageResponsesAndAuthorizations', (v_capabilities ->> 'manageResponsesAndAuthorizations')::boolean),
      (7, 'overrideReservationConflict', (v_capabilities ->> 'overrideReservationConflict')::boolean)
  ) as capability(position, name, allowed);

  with authorized_institutions as (
    select institution.id, institution.public_name
    from public.institutions institution
    where institution.status = 'active'
      and institution.deleted_at is null
      and exists (
        select 1
        from public.platform_memberships membership
        join public.platform_roles role_record
          on role_record.id = membership.role_id
         and role_record.status = 'active'
        where membership.person_id = v_actor
          and membership.status = 'active'
          and membership.revoked_at is null
          and (
            (membership.scope_kind = 'platform' and membership.scope_institution_id is null)
            or
            (membership.scope_kind = 'institution' and membership.scope_institution_id = institution.id)
          )
      )
  ), context_rows as (
    select
      institution.id,
      institution.public_name as name,
      institution.id as institution_id,
      null::uuid as parent_id,
      'institution'::text as level,
      1 as level_order
    from authorized_institutions institution

    union all

    select
      unit_record.id,
      unit_record.name,
      unit_record.institution_id,
      unit_record.institution_id as parent_id,
      'unit'::text as level,
      2 as level_order
    from public.units unit_record
    join authorized_institutions institution
      on institution.id = unit_record.institution_id
    where unit_record.status = 'active'

    union all

    select
      group_record.id,
      group_record.name,
      unit_record.institution_id,
      unit_record.id as parent_id,
      'group'::text as level,
      3 as level_order
    from public.groups group_record
    join public.units unit_record
      on unit_record.id = group_record.unit_id
     and unit_record.institution_id = group_record.institution_id
     and unit_record.status = 'active'
    join authorized_institutions institution
      on institution.id = unit_record.institution_id
    where group_record.status = 'active'

    union all

    select
      activity.id,
      activity.name,
      activity.institution_id,
      coalesce(activity.origin_unit_id, activity.institution_id) as parent_id,
      'activity'::text as level,
      4 as level_order
    from public.activity_definitions activity
    join authorized_institutions institution
      on institution.id = activity.institution_id
    left join public.units origin_unit
      on origin_unit.id = activity.origin_unit_id
     and origin_unit.institution_id = activity.institution_id
     and origin_unit.status = 'active'
    where activity.status = 'active'
      and (activity.origin_unit_id is null or origin_unit.id is not null)
  )
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'id', context_record.id,
        'name', context_record.name,
        'institution_id', context_record.institution_id,
        'parent_id', context_record.parent_id,
        'level', context_record.level,
        'granted_capabilities', v_granted_capabilities,
        'restricted_capabilities', v_restricted_capabilities
      )
      order by context_record.institution_id, context_record.level_order,
        pg_catalog.lower(context_record.name), context_record.id
    ),
    '[]'::jsonb
  )
  into v_contexts
  from context_rows context_record;

  return pg_catalog.jsonb_build_object(
    'contexts', v_contexts,
    'capabilities', v_capabilities
  );
end;
$$;

alter function public.superadmin_agenda_contexts() owner to postgres;
revoke execute on function public.superadmin_agenda_contexts()
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_agenda_contexts() to authenticated;
