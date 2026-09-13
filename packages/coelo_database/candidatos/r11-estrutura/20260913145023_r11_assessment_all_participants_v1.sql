-- R11: all-mode eligibility and existing empty draft recovery. No participant/link creation.
create or replace function app_private.assessment_v2_initial_students(p_activity_group_link_id uuid)
returns jsonb language sql volatile security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', gen_random_uuid(), 'child_context_id', child_context.id,
    'name', person.display_name, 'state', 'not_started',
    'suggested_numeric_value', null, 'final_numeric_value', null,
    'final_concept_code', null, 'final_boolean_value', null,
    'override_reason', '', 'family_comment', '', 'internal_note', '',
    'instruments', '[]'::jsonb, 'competencies', '[]'::jsonb)
    order by person.display_name, child_context.id), '[]'::jsonb)
  from public.activity_group_links activity_link
  join public.groups group_row on group_row.id=activity_link.group_id
    and group_row.institution_id=activity_link.institution_id
    and group_row.unit_id=activity_link.unit_id and group_row.status='active'
  join public.units unit_row on unit_row.id=group_row.unit_id
    and unit_row.institution_id=group_row.institution_id and unit_row.status='active'
  join public.child_group_links child_group on child_group.group_id=group_row.id and child_group.status='active'
  join public.child_unit_links child_unit on child_unit.id=child_group.child_unit_link_id
    and child_unit.unit_id=group_row.unit_id and child_unit.status='active'
  join public.child_contexts child_context on child_context.id=child_unit.child_context_id
    and child_context.institution_id=group_row.institution_id and child_context.status='active'
  join public.people person on person.id=child_context.child_person_id and person.status='active'
  where activity_link.id=p_activity_group_link_id and activity_link.status='active'
    and (activity_link.participation_mode='all' or exists (
      select 1 from public.activity_group_participants participant
      where participant.activity_group_link_id=activity_link.id
        and participant.child_group_link_id=child_group.id
        and participant.status='active' and participant.removed_at is null))
$$;
create or replace function app_private.assessment_v2_validate_students(
  p_gradebook public.assessment_gradebooks, p_students jsonb
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare item jsonb; normalized jsonb := '[]'::jsonb; old_item jsonb;
  child_context_id uuid; instrument jsonb; competency jsonb; config record;
begin
  if p_students is null or jsonb_typeof(p_students) <> 'array'
    or jsonb_array_length(p_students) > 500
    or (select count(*) from jsonb_array_elements(p_students)) <>
       (select count(distinct value->>'child_context_id') from jsonb_array_elements(p_students)) then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;
  select c.result_scale_kind, c.scale_options into config
  from public.activity_assessment_configurations c where c.id = p_gradebook.configuration_id;
  for item in select value from jsonb_array_elements(p_students) loop
    if jsonb_typeof(item) <> 'object'
      or not (item ?& array['child_context_id','state','instruments','competencies'])
      or exists (select 1 from jsonb_object_keys(item) k where k not in (
        'child_context_id','state','final_numeric_value','final_concept_code',
        'final_boolean_value','override_reason','family_comment','internal_note',
        'instruments','competencies'))
      or item->>'state' not in ('not_started','pending','complete','absent')
      or jsonb_typeof(item->'instruments') <> 'array'
      or jsonb_typeof(item->'competencies') <> 'array'
      or char_length(coalesce(item->>'override_reason','')) > 500
      or char_length(coalesce(item->>'family_comment','')) > 2000
      or char_length(coalesce(item->>'internal_note','')) > 4000 then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    begin child_context_id := (item->>'child_context_id')::uuid;
    exception when others then raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT'; end;
    if not exists (
      select 1 from jsonb_array_elements(app_private.assessment_v2_initial_students(p_gradebook.activity_group_link_id)) candidate
      where candidate->>'child_context_id'=child_context_id::text
    ) then raise invalid_parameter_value using detail='ASSESSMENT_INVALID_REFERENCE'; end if;
    if (select count(*) from jsonb_array_elements(item->'instruments')) <>
       (select count(distinct value->>'instrument_id') from jsonb_array_elements(item->'instruments'))
      or (select count(*) from jsonb_array_elements(item->'competencies')) <>
       (select count(distinct value->>'competency_id') from jsonb_array_elements(item->'competencies')) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    for instrument in select value from jsonb_array_elements(item->'instruments') loop
      if not exists (select 1 from public.assessment_instruments i
        where i.id = (instrument->>'instrument_id')::uuid
          and i.configuration_id = p_gradebook.configuration_id)
        or coalesce((instrument->>'absent')::boolean, false) = false and
          num_nonnulls(instrument->>'numeric_value', instrument->>'concept_code',
            instrument->>'boolean_value') <> 1 then
        raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_REFERENCE';
      end if;
      if config.result_scale_kind = 'numeric_0_10'
        and (instrument->>'numeric_value')::numeric not between 0 and 10
        or config.result_scale_kind = 'numeric_0_100'
        and (instrument->>'numeric_value')::numeric not between 0 and 100
        or config.result_scale_kind in ('numeric_1_5')
        and (instrument->>'numeric_value')::numeric not between 1 and 5
        or config.result_scale_kind = 'stars_0_5'
        and (instrument->>'numeric_value')::numeric not between 0 and 5
        or config.result_scale_kind = 'concept' and not exists (
          select 1 from public.assessment_scale_concepts s
          where s.configuration_id = p_gradebook.configuration_id
            and s.code = instrument->>'concept_code') then
        raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
      end if;
    end loop;
    for competency in select value from jsonb_array_elements(item->'competencies') loop
      if not exists (select 1 from public.assessment_competencies c
        where c.id = (competency->>'competency_id')::uuid
          and c.configuration_id = p_gradebook.configuration_id)
        or (competency->>'score')::numeric not between 0 and 5 then
        raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_REFERENCE';
      end if;
    end loop;
    select value into old_item from jsonb_array_elements(p_gradebook.students_payload)
    where value->>'child_context_id' = child_context_id::text limit 1;
    normalized := normalized || jsonb_build_array(item || jsonb_build_object(
      'id', coalesce(old_item->>'id', gen_random_uuid()::text),
      'name', coalesce(old_item->>'name', (select person.display_name
        from public.child_contexts cc join public.people person on person.id = cc.child_person_id
        where cc.id = child_context_id)),
      'suggested_numeric_value', case
        when item->>'state' = 'absent' then null
        else (select round(sum((entry->>'numeric_value')::numeric * i.weight) /
          nullif(sum(i.weight), 0), 2)
          from jsonb_array_elements(item->'instruments') entry
          join public.assessment_instruments i
            on i.id = (entry->>'instrument_id')::uuid
          where not coalesce((entry->>'absent')::boolean, false)
            and entry->>'numeric_value' is not null) end));
  end loop;
  return normalized;
end $$;
create or replace function app_private.assessment_v2_gradebook_snapshot(p_gradebook_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'gradebook', jsonb_build_object(
      'id', b.id, 'institution_id', b.institution_id,
      'institution_name', i.public_name, 'unit_id', b.unit_id, 'unit_name', u.name,
      'activity_group_link_id', b.activity_group_link_id,
      'group_id', gl.group_id, 'group_name', g.name,
      'activity_id', a.id, 'activity_name', a.name,
      'period_id', p.id, 'period_name', p.name,
      'configuration_id', b.configuration_id, 'status', b.status,
      'management_version', b.management_version,
      'family_release_at', b.family_release_at,
      'publish_scheduled_at', b.publish_scheduled_at,
      'published_at', b.published_at),
    'configuration', app_private.assessment_v2_configuration_snapshot(b.configuration_id),
    'students', b.students_payload || case when b.status='draft' then
      coalesce((select jsonb_agg(candidate || jsonb_build_object('id',candidate->>'child_context_id'))
        from jsonb_array_elements(app_private.assessment_v2_initial_students(b.activity_group_link_id)) candidate
        where not exists (select 1 from jsonb_array_elements(b.students_payload) saved
          where saved->>'child_context_id'=candidate->>'child_context_id')), '[]'::jsonb)
      else '[]'::jsonb end,
    'events', coalesce((select jsonb_agg(jsonb_build_object(
      'id', e.id, 'event_kind', e.event_kind, 'actor_person_id', null,
      'reason', coalesce(e.reason, ''), 'version', e.version,
      'created_at', e.created_at) order by e.created_at desc, e.id desc)
      from app_private.superadmin_internal_assessment_events e
      where e.gradebook_id = b.id), '[]'::jsonb))
  from public.assessment_gradebooks b
  join public.activity_group_links gl on gl.id = b.activity_group_link_id
  join public.activity_definitions a on a.id = gl.activity_id
  join public.institutions i on i.id = b.institution_id
  join public.units u on u.id = b.unit_id
  join public.groups g on g.id = gl.group_id
  join public.assessment_periods p on p.id = b.period_id
  where b.id = p_gradebook_id
$$;
