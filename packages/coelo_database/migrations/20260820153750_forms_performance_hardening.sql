begin;

create extension if not exists pg_trgm with schema extensions;

create index if not exists forms_title_trgm_idx
  on public.forms using gin (lower(title) extensions.gin_trgm_ops);

create index if not exists form_command_receipts_actor_person_idx on app_private.form_command_receipts (actor_person_id);
create index if not exists form_answers_form_version_idx on public.form_answers (form_version_id);
create index if not exists form_applications_created_by_person_idx on public.form_applications (created_by_person_id);
create index if not exists form_assets_institution_idx on public.form_assets (institution_id);
create index if not exists form_assets_item_idx on public.form_assets (item_id);
create index if not exists form_assets_prepared_by_person_idx on public.form_assets (prepared_by_person_id);
create index if not exists form_file_jobs_institution_idx on public.form_file_jobs (institution_id);
create index if not exists form_file_jobs_occurrence_idx on public.form_file_jobs (occurrence_id);
create index if not exists form_occurrences_institution_idx on public.form_occurrences (institution_id);
create index if not exists form_participation_responders_institution_idx on public.form_participation_responders (institution_id);
create index if not exists form_participations_institution_idx on public.form_participations (institution_id);
create index if not exists form_response_revisions_changed_by_person_idx on public.form_response_revisions (changed_by_person_id);
create index if not exists form_responses_institution_idx on public.form_responses (institution_id);
create index if not exists form_versions_created_by_person_idx on public.form_versions (created_by_person_id);
create index if not exists forms_created_by_person_idx on public.forms (created_by_person_id);
create index if not exists forms_published_version_idx on public.forms (published_version_id);
create index if not exists forms_updated_by_person_idx on public.forms (updated_by_person_id);
create index if not exists forms_working_version_idx on public.forms (working_version_id);

create index if not exists form_occurrences_operational_window_idx
  on public.form_occurrences (form_id, status, opens_at, closes_at);
create index if not exists people_display_name_cursor_idx
  on public.people (lower(display_name), id);

create or replace function app_private.form_list(p_query jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.read');
declare page_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 25), 1), 100);
declare cursor_updated timestamptz;
declare cursor_id uuid;
begin
  perform app_private.form_assert_payload_keys(
    p_query,
    array['institution_id','search','statuses','operational_statuses','kinds','starts_on_or_after','ends_on_or_before','cursor_updated_at','cursor_id','limit'],
    'form directory query'
  );
  cursor_updated := (p_query ->> 'cursor_updated_at')::timestamptz;
  cursor_id := (p_query ->> 'cursor_id')::uuid;
  return (
    with candidate_forms as (
      select form_row.*
        from public.forms form_row
       where ((p_query ->> 'institution_id') is null
              or form_row.institution_id = (p_query ->> 'institution_id')::uuid)
         and (nullif(p_query ->> 'search', '') is null
              or lower(form_row.title) like
                 '%' || lower(app_private.form_escape_like(p_query ->> 'search')) || '%' escape '\')
         and (coalesce(jsonb_array_length(p_query -> 'statuses'), 0) = 0 or form_row.status in (
           select jsonb_array_elements_text(p_query -> 'statuses')
         ))
         and (coalesce(jsonb_array_length(p_query -> 'kinds'), 0) = 0 or form_row.kind in (
           select jsonb_array_elements_text(p_query -> 'kinds')
         ))
    ), occurrence_windows as (
      select candidate.id as form_id,
             bool_or(
               occurrence_row.status in ('scheduled', 'open')
               and occurrence_row.opens_at <= now()
               and occurrence_row.closes_at > now()
             ) as is_active,
             bool_or(
               occurrence_row.status in ('scheduled', 'open')
               and occurrence_row.opens_at > now()
             ) as is_scheduled,
             bool_or(occurrence_row.opens_at::date >= (p_query ->> 'starts_on_or_after')::date)
               filter (where (p_query ->> 'starts_on_or_after') is not null) as matches_start,
             bool_or(occurrence_row.closes_at::date <= (p_query ->> 'ends_on_or_before')::date)
               filter (where (p_query ->> 'ends_on_or_before') is not null) as matches_end
        from candidate_forms candidate
        left join public.form_occurrences occurrence_row
          on occurrence_row.form_id = candidate.id
         and occurrence_row.institution_id = candidate.institution_id
       group by candidate.id
    ), operational as (
      select candidate.*,
             case
               when candidate.status = 'archived' then 'archived'
               when candidate.status = 'draft' then 'draft'
               when coalesce(occurrence_window.is_active, false) then 'active'
               when coalesce(occurrence_window.is_scheduled, false) then 'scheduled'
               else 'closed'
             end as operational_status
        from candidate_forms candidate
        join occurrence_windows occurrence_window on occurrence_window.form_id = candidate.id
       where ((p_query ->> 'starts_on_or_after') is null or coalesce(occurrence_window.matches_start, false))
         and ((p_query ->> 'ends_on_or_before') is null or coalesce(occurrence_window.matches_end, false))
    ), page as (
      select operational.*
        from operational
       where (coalesce(jsonb_array_length(p_query -> 'operational_statuses'), 0) = 0
              or operational_status in (select jsonb_array_elements_text(p_query -> 'operational_statuses')))
         and (cursor_updated is null or (updated_at, id) < (cursor_updated, cursor_id))
       order by updated_at desc, id desc
       limit page_limit + 1
    ), visible as (select * from page limit page_limit)
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'title', title, 'kind', kind, 'status', status,
        'operational_status', operational_status, 'identity_mode', identity_mode,
        'updated_at', updated_at, 'management_version', management_version
      ) order by updated_at desc, id desc), '[]'::jsonb),
      'has_more', (select count(*) > page_limit from page),
      'next_cursor', (select jsonb_build_object('updated_at', updated_at, 'id', id)
                        from visible order by updated_at, id limit 1)
    ) from visible
  );
end;
$$;

create or replace function app_private.form_list_monitor_people(p_query jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.monitor');
declare form_row public.forms;
declare page_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 25), 1), 100);
begin
  perform app_private.form_assert_payload_keys(
    p_query, array[
      'form_id','application_id','occurrence_id','starts_on_or_after','ends_on_or_before','scope_id',
      'justification','cursor_name','cursor_id','limit'
    ],
    'form monitor people query'
  );
  select * into form_row from public.forms where id = (p_query ->> 'form_id')::uuid;
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if form_row.identity_mode = 'anonymous' then
    perform app_private.form_require_owner(actor, 'forms.anonymous_participation.read');
    if char_length(btrim(coalesce(p_query ->> 'justification', ''))) < 10 then
      raise invalid_parameter_value using message = 'auditable justification required';
    end if;
  end if;
  return (
    with monitor_candidates as (
      select participation.id,
             coalesce(person.id, responder_person.id) as person_id,
             coalesce(person.display_name, responder_person.display_name) as display_name,
             lower(coalesce(person.display_name, responder_person.display_name)) as cursor_label,
             membership.role_code as profile_label,
             participation.response_unit_key as context_label,
             participation.response_state = 'responded' as responded
        from public.form_occurrences occurrence_row
        join public.form_participations participation
          on participation.occurrence_id = occurrence_row.id
         and participation.institution_id = occurrence_row.institution_id
        left join public.people person on person.id = participation.person_id
        left join public.form_participation_responders responder
          on responder.participation_id = participation.id
         and responder.institution_id = participation.institution_id
        left join public.people responder_person on responder_person.id = responder.person_id
        left join public.institution_memberships membership
          on membership.person_id = coalesce(person.id, responder_person.id)
         and membership.institution_id = participation.institution_id
         and membership.status = 'active'
       where form_row.institution_id = occurrence_row.institution_id
         and occurrence_row.form_id = form_row.id
         and ((p_query ->> 'application_id') is null
              or occurrence_row.application_id = (p_query ->> 'application_id')::uuid)
         and ((p_query ->> 'occurrence_id') is null
              or occurrence_row.id = (p_query ->> 'occurrence_id')::uuid)
         and ((p_query ->> 'starts_on_or_after') is null
              or occurrence_row.opens_at::date >= (p_query ->> 'starts_on_or_after')::date)
         and ((p_query ->> 'ends_on_or_before') is null
              or occurrence_row.closes_at::date <= (p_query ->> 'ends_on_or_before')::date)
         and participation.eligibility_state = 'eligible'
    ), page as (
      select *
        from monitor_candidates
       where ((p_query ->> 'cursor_name') is null
              or (cursor_label, id)
                 > (lower(p_query ->> 'cursor_name'), (p_query ->> 'cursor_id')::uuid))
       order by cursor_label, id
       limit page_limit + 1
    ), visible as (select * from page limit page_limit)
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'person_id', person_id, 'display_name', display_name, 'profile_label', profile_label,
        'context_label', context_label, 'responded', responded
      ) order by cursor_label, id), '[]'::jsonb),
      'has_more', (select count(*) > page_limit from page),
      'next_cursor', (select jsonb_build_object('name', display_name, 'id', id)
                        from visible order by cursor_label desc, id desc limit 1)
    ) from visible
  );
end;
$$;

revoke all on function app_private.form_list(jsonb) from public, anon, authenticated;
revoke all on function app_private.form_list_monitor_people(jsonb) from public, anon, authenticated;

commit;
