-- Authorized, materialized drill-down for Forms monitoring.
-- Keep this file byte-for-byte mirrored under supabase/migrations.

create or replace function app_private.form_rebuild_occurrence_scope_metrics(p_occurrence_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.form_scope_metrics where occurrence_id = p_occurrence_id;

  insert into public.form_scope_metrics(
    occurrence_id, institution_id, scope_kind, scope_id,
    eligible_count, responded_count, pending_count, updated_at
  )
  with occurrence_row as (
    select occurrence.id, occurrence.institution_id, occurrence.application_id
      from public.form_occurrences occurrence
     where occurrence.id = p_occurrence_id
  ), scopes as (
    select occurrence.id as occurrence_id, occurrence.institution_id,
           'institution'::text as scope_kind, occurrence.institution_id as scope_id
      from occurrence_row occurrence
    union
    select occurrence.id, occurrence.institution_id, rule.rule_kind, rule.target_id
      from occurrence_row occurrence
      join public.form_audience_rules rule on rule.application_id = occurrence.application_id
     where rule.rule_mode = 'include'
       and rule.rule_kind in ('unit', 'group', 'activity', 'profile')
  ), counted as (
    select scope.occurrence_id, scope.institution_id, scope.scope_kind, scope.scope_id,
           count(*) filter (where participation.eligibility_state = 'eligible') as eligible_count,
           count(*) filter (
             where participation.eligibility_state = 'eligible'
               and participation.response_state = 'responded'
           ) as responded_count,
           count(*) filter (
             where participation.eligibility_state = 'eligible'
               and participation.response_state <> 'responded'
           ) as pending_count
      from scopes scope
      left join public.form_participations participation
        on participation.occurrence_id = scope.occurrence_id
       and (
         scope.scope_kind = 'institution'
         or (scope.scope_kind = 'unit' and (
           exists(
             select 1 from public.institution_memberships membership
              where membership.person_id = participation.person_id
                and membership.institution_id = scope.institution_id
                and membership.status = 'active'
                and membership.scope_unit_id = scope.scope_id
           ) or exists(
             select 1 from public.child_unit_links child_unit
              where child_unit.child_context_id = participation.child_context_id
                and child_unit.unit_id = scope.scope_id and child_unit.status = 'active'
           )
         ))
         or (scope.scope_kind = 'group' and (
           exists(
             select 1 from public.institution_memberships membership
              where membership.person_id = participation.person_id
                and membership.institution_id = scope.institution_id
                and membership.status = 'active'
                and membership.scope_group_id = scope.scope_id
           ) or exists(
             select 1 from public.child_group_links child_group
              join public.child_unit_links child_unit on child_unit.id = child_group.child_unit_link_id
              where child_unit.child_context_id = participation.child_context_id
                and child_group.group_id = scope.scope_id and child_group.status = 'active'
           )
         ))
         or (scope.scope_kind = 'activity' and (
           exists(
             select 1 from public.activity_group_assignments assignment
              join public.activity_group_links activity_link on activity_link.id = assignment.activity_group_link_id
              where assignment.person_id = participation.person_id
                and assignment.status = 'active' and activity_link.status = 'active'
                and activity_link.activity_id = scope.scope_id
           ) or exists(
             select 1 from public.child_group_links child_group
              join public.child_unit_links child_unit on child_unit.id = child_group.child_unit_link_id
              join public.activity_group_links activity_link on activity_link.group_id = child_group.group_id
              left join public.activity_group_participants selected
                on selected.activity_group_link_id = activity_link.id
               and selected.child_group_link_id = child_group.id
               and selected.status = 'active' and selected.removed_at is null
              where child_unit.child_context_id = participation.child_context_id
                and child_group.status = 'active' and activity_link.status = 'active'
                and activity_link.activity_id = scope.scope_id
                and (activity_link.participation_mode = 'all' or selected.id is not null)
           )
         ))
         or (scope.scope_kind = 'profile' and exists(
           select 1 from public.institution_role_assignments assignment
            where assignment.membership_id in (
              select membership.id from public.institution_memberships membership
               where membership.person_id = participation.person_id
                 and membership.institution_id = scope.institution_id and membership.status = 'active'
            ) and assignment.role_id = scope.scope_id and assignment.status = 'active'
         ))
       )
     group by scope.occurrence_id, scope.institution_id, scope.scope_kind, scope.scope_id
  )
  select occurrence_id, institution_id, scope_kind, scope_id,
         eligible_count, responded_count, pending_count, now()
    from counted;
$$;

create or replace function app_private.form_rebuild_occurrence_metrics(p_occurrence_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.form_occurrence_metrics(
    occurrence_id, institution_id, eligible_count, responded_count, pending_count, updated_at
  )
  select occurrence.id, occurrence.institution_id,
         count(*) filter (where participation.eligibility_state = 'eligible'),
         count(*) filter (where participation.eligibility_state = 'eligible' and participation.response_state = 'responded'),
         count(*) filter (where participation.eligibility_state = 'eligible' and participation.response_state <> 'responded'), now()
    from public.form_occurrences occurrence
    left join public.form_participations participation on participation.occurrence_id = occurrence.id
   where occurrence.id = p_occurrence_id
   group by occurrence.id, occurrence.institution_id
  on conflict(occurrence_id) do update set
    eligible_count = excluded.eligible_count, responded_count = excluded.responded_count,
    pending_count = excluded.pending_count, updated_at = excluded.updated_at;
  perform app_private.form_rebuild_occurrence_scope_metrics(p_occurrence_id);
end;
$$;

create or replace function app_private.form_get_monitor(p_query jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.monitor');
declare form_row public.forms;
begin
  perform app_private.form_assert_payload_keys(
    p_query, array['form_id','application_id','occurrence_id','starts_on_or_after','ends_on_or_before','scope_id'],
    'form monitor query'
  );
  select * into form_row from public.forms where id = (p_query ->> 'form_id')::uuid;
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if p_query ->> 'scope_id' is not null and not exists(
    select 1 from public.form_scope_metrics metric
    join public.form_occurrences occurrence on occurrence.id = metric.occurrence_id
     where occurrence.form_id = form_row.id
       and metric.institution_id = form_row.institution_id
       and metric.scope_id = (p_query ->> 'scope_id')::uuid
  ) then
    raise no_data_found using message = 'monitor scope unavailable';
  end if;
  return (
    select jsonb_build_object(
      'eligible_count', coalesce(sum(case when p_query ->> 'scope_id' is null
        then occurrence_metric.eligible_count else scope_metric.eligible_count end), 0),
      'responded_count', coalesce(sum(case when p_query ->> 'scope_id' is null
        then occurrence_metric.responded_count else scope_metric.responded_count end), 0),
      'pending_count', coalesce(sum(case when p_query ->> 'scope_id' is null
        then occurrence_metric.pending_count else scope_metric.pending_count end), 0),
      'is_anonymous', form_row.identity_mode = 'anonymous'
    )
      from public.form_occurrences occurrence
      left join public.form_occurrence_metrics occurrence_metric on occurrence_metric.occurrence_id = occurrence.id
      left join public.form_scope_metrics scope_metric on scope_metric.occurrence_id = occurrence.id
       and scope_metric.scope_id = (p_query ->> 'scope_id')::uuid
     where occurrence.form_id = form_row.id
       and ((p_query ->> 'application_id') is null or occurrence.application_id = (p_query ->> 'application_id')::uuid)
       and ((p_query ->> 'occurrence_id') is null or occurrence.id = (p_query ->> 'occurrence_id')::uuid)
       and ((p_query ->> 'starts_on_or_after') is null or occurrence.opens_at::date >= (p_query ->> 'starts_on_or_after')::date)
       and ((p_query ->> 'ends_on_or_before') is null or occurrence.closes_at::date <= (p_query ->> 'ends_on_or_before')::date)
  );
end;
$$;

create or replace function app_private.form_list_monitor_hierarchy(p_query jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.monitor');
declare form_row public.forms;
declare requested_scope_kind text;
declare wanted_scope_kind text;
declare page_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 25), 1), 100);
declare cursor_label text := p_query ->> 'cursor_label';
declare cursor_id uuid := (p_query ->> 'cursor_id')::uuid;
begin
  perform app_private.form_assert_payload_keys(
    p_query, array['form_id','application_id','occurrence_id','starts_on_or_after','ends_on_or_before',
                    'scope_id','cursor_label','cursor_id','limit'],
    'form monitor hierarchy query'
  );
  select * into form_row from public.forms where id = (p_query ->> 'form_id')::uuid;
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;

  if p_query ->> 'scope_id' is not null then
    select metric.scope_kind into requested_scope_kind
      from public.form_scope_metrics metric
      join public.form_occurrences occurrence on occurrence.id = metric.occurrence_id
     where occurrence.form_id = form_row.id and metric.scope_id = (p_query ->> 'scope_id')::uuid
     limit 1;
    if requested_scope_kind is null then
      raise no_data_found using message = 'monitor scope unavailable';
    end if;
  end if;
  wanted_scope_kind := case
    when requested_scope_kind is null then 'institution'
    when 'institution' then 'unit'
    when 'unit' then 'group'
    when 'group' then 'activity'
    when 'activity' then 'profile'
    else null
  end;
  if wanted_scope_kind is null then
    return jsonb_build_object('items', '[]'::jsonb, 'has_more', false, 'next_cursor', null);
  end if;

  return (
    with scopes as (
      select metric.scope_id, metric.scope_kind,
             case metric.scope_kind
               when 'institution' then (select institution.name from public.institutions institution where institution.id = metric.scope_id)
               when 'unit' then (select unit.name from public.units unit where unit.id = metric.scope_id and unit.institution_id = form_row.institution_id)
               when 'group' then (select group_row.name from public.groups group_row where group_row.id = metric.scope_id and group_row.institution_id = form_row.institution_id)
               when 'activity' then (select activity.name from public.activity_definitions activity where activity.id = metric.scope_id and activity.institution_id = form_row.institution_id)
               when 'profile' then (select role_row.name from public.institution_roles role_row where role_row.id = metric.scope_id and role_row.institution_id = form_row.institution_id)
             end as label,
             sum(metric.eligible_count)::bigint as eligible_count,
             sum(metric.responded_count)::bigint as responded_count,
             sum(metric.pending_count)::bigint as pending_count
        from public.form_scope_metrics metric
        join public.form_occurrences occurrence on occurrence.id = metric.occurrence_id
       where occurrence.form_id = form_row.id and metric.institution_id = form_row.institution_id
         and metric.scope_kind = wanted_scope_kind
         and (
           requested_scope_kind is null
           or requested_scope_kind = 'institution'
           or (requested_scope_kind = 'unit' and exists(
             select 1 from public.groups group_row
              where group_row.id = metric.scope_id
                and group_row.unit_id = (p_query ->> 'scope_id')::uuid
                and group_row.institution_id = form_row.institution_id
           ))
           or (requested_scope_kind = 'group' and exists(
             select 1 from public.activity_group_links activity_link
              where activity_link.activity_id = metric.scope_id
                and activity_link.group_id = (p_query ->> 'scope_id')::uuid
                and activity_link.institution_id = form_row.institution_id
                and activity_link.status = 'active'
           ))
           or requested_scope_kind = 'activity'
         )
         and ((p_query ->> 'application_id') is null or occurrence.application_id = (p_query ->> 'application_id')::uuid)
         and ((p_query ->> 'occurrence_id') is null or occurrence.id = (p_query ->> 'occurrence_id')::uuid)
         and ((p_query ->> 'starts_on_or_after') is null or occurrence.opens_at::date >= (p_query ->> 'starts_on_or_after')::date)
         and ((p_query ->> 'ends_on_or_before') is null or occurrence.closes_at::date <= (p_query ->> 'ends_on_or_before')::date)
       group by metric.scope_id, metric.scope_kind
    ), page as (
      select * from scopes
       where label is not null
         and (cursor_label is null or (lower(label), scope_id) > (lower(cursor_label), cursor_id))
       order by lower(label), scope_id limit page_limit + 1
    ), visible as (select * from page limit page_limit)
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'scope_id', scope_id, 'scope_kind', scope_kind, 'label', label,
        'eligible_count', eligible_count, 'responded_count', responded_count, 'pending_count', pending_count
      ) order by lower(label), scope_id), '[]'::jsonb),
      'has_more', (select count(*) > page_limit from page),
      'next_cursor', (select jsonb_build_object('label', label, 'id', scope_id)
                        from visible order by lower(label) desc, scope_id desc limit 1)
    ) from visible
  );
end;
$$;

create or replace function public.form_list_monitor_hierarchy(p_query jsonb)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.form_list_monitor_hierarchy($1) $$;

revoke all on function app_private.form_rebuild_occurrence_scope_metrics(uuid) from public, anon, authenticated;
revoke all on function app_private.form_list_monitor_hierarchy(jsonb) from public, anon, authenticated;
revoke all on function public.form_list_monitor_hierarchy(jsonb) from public, anon;
grant execute on function public.form_list_monitor_hierarchy(jsonb) to authenticated;
