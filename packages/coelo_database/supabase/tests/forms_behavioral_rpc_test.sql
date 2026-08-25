begin;

create extension if not exists pgtap with schema extensions;

select plan(17);

insert into auth.users(id, aud, role, email, created_at, updated_at) values
  ('84000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'forms-owner@test.invalid', now(), now()),
  ('84000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'forms-denied@test.invalid', now(), now());

insert into public.people(id, person_type, first_name, last_name, display_name, status) values
  ('84100000-0000-4000-8000-000000000001', 'adult', 'Forms', 'Owner', 'Forms Owner', 'active'),
  ('84100000-0000-4000-8000-000000000002', 'adult', 'Forms', 'Denied', 'Forms Denied', 'active');

insert into public.person_auth_links(person_id, auth_user_id, status) values
  ('84100000-0000-4000-8000-000000000001', '84000000-0000-4000-8000-000000000001', 'active'),
  ('84100000-0000-4000-8000-000000000002', '84000000-0000-4000-8000-000000000002', 'active');

insert into public.platform_roles(id, code, name, status, is_system)
values ('84200000-0000-4000-8000-000000000001', 'forms_behavior_denied', 'Forms behavior denied', 'active', true);

insert into public.platform_memberships(person_id, role_id, status, scope_kind, mfa_required)
select '84100000-0000-4000-8000-000000000001', id, 'active', 'platform', false
  from public.platform_roles
 where code = 'owner';

insert into public.platform_memberships(person_id, role_id, status, scope_kind, mfa_required)
values (
  '84100000-0000-4000-8000-000000000002',
  '84200000-0000-4000-8000-000000000001',
  'active',
  'platform',
  false
);

insert into public.institutions(id, public_name, legal_name, slug, status) values
  ('84300000-0000-4000-8000-000000000001', 'Forms Institution A', 'Forms Institution A', 'forms-behavior-a', 'active'),
  ('84300000-0000-4000-8000-000000000002', 'Forms Institution B', 'Forms Institution B', 'forms-behavior-b', 'active');

insert into public.institution_memberships(
  id, person_id, institution_id, role_code, status
) values (
  '84300000-0000-4000-8000-000000000003',
  '84100000-0000-4000-8000-000000000001',
  '84300000-0000-4000-8000-000000000001',
  'owner',
  'active'
);

create temporary table forms_behavior_results (
  key text primary key,
  result jsonb not null
);
grant select, insert, update on forms_behavior_results to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub', '84000000-0000-4000-8000-000000000099', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-4000-8000-000000000099","aal":"aal1","role":"authenticated"}',
  true
);

select throws_ok(
  $$select public.form_save_draft(
      '84400000-0000-4000-8000-000000000001', 0, '{}'::jsonb
    )$$,
  '42501',
  'authentication required',
  'an authenticated subject without a person mapping cannot execute a Forms command'
);

select set_config('request.jwt.claim.sub', '84000000-0000-4000-8000-000000000002', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-4000-8000-000000000002","aal":"aal1","role":"authenticated"}',
  true
);

select throws_ok(
  $$select public.form_save_draft(
      '84400000-0000-4000-8000-000000000002', 0, '{}'::jsonb
    )$$,
  '42501',
  'forms.manage required',
  'a mapped actor without forms.manage cannot execute a Forms command'
);

select set_config('request.jwt.claim.sub', '84000000-0000-4000-8000-000000000001', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}',
  true
);

insert into forms_behavior_results(key, result)
select 'created', public.form_save_draft(
  '84400000-0000-4000-8000-000000000010',
  0,
  jsonb_build_object(
    'id', '84500000-0000-4000-8000-000000000001',
    'institution_id', '84300000-0000-4000-8000-000000000001',
    'kind', 'form',
    'identity_mode', 'anonymous',
    'response_unit', 'person',
    'title', 'Forms behavior original',
    'description', 'Behavioral RPC contract',
    'sections', jsonb_build_array(jsonb_build_object(
      'id', 'section-1',
      'title', 'Original section',
      'description', null,
      'position', 0,
      'items', jsonb_build_array(jsonb_build_object(
        'id', 'item-1',
        'kind', 'short_text',
        'label', 'Original question',
        'help_text', null,
        'position', 0,
        'is_required', false,
        'config', jsonb_build_object('max_length', 100),
        'options', '[]'::jsonb,
        'conditions', '[]'::jsonb
      ))
    ))
  )
);

select ok(
  (select result ->> 'id' = '84500000-0000-4000-8000-000000000001'
       and (result ->> 'management_version')::bigint = 1
     from forms_behavior_results where key = 'created'),
  'form_save_draft executes and returns the persisted initial version'
);

select is(
  public.form_save_draft(
    '84400000-0000-4000-8000-000000000010',
    0,
    jsonb_build_object(
      'id', '84500000-0000-4000-8000-000000000001',
      'institution_id', '84300000-0000-4000-8000-000000000001',
      'kind', 'form',
      'identity_mode', 'anonymous',
      'response_unit', 'person',
      'title', 'Forms behavior original',
      'description', 'Behavioral RPC contract',
      'sections', jsonb_build_array(jsonb_build_object(
        'id', 'section-1', 'title', 'Original section', 'description', null, 'position', 0,
        'items', jsonb_build_array(jsonb_build_object(
          'id', 'item-1', 'kind', 'short_text', 'label', 'Original question',
          'help_text', null, 'position', 0, 'is_required', false,
          'config', jsonb_build_object('max_length', 100),
          'options', '[]'::jsonb, 'conditions', '[]'::jsonb
        ))
      ))
    )
  ),
  (select result from forms_behavior_results where key = 'created'),
  'an identical request_id replay returns the original result'
);

select throws_ok(
  $$select public.form_save_draft(
      '84400000-0000-4000-8000-000000000010',
      0,
      jsonb_build_object(
        'id', '84500000-0000-4000-8000-000000000001',
        'institution_id', '84300000-0000-4000-8000-000000000001',
        'kind', 'form', 'identity_mode', 'anonymous', 'response_unit', 'person',
        'title', 'Divergent replay', 'description', 'Behavioral RPC contract',
        'sections', '[]'::jsonb
      )
    )$$,
  '23505',
  'form command replay mismatch',
  'a request_id cannot be replayed with a divergent payload'
);

select throws_ok(
  $$select public.form_save_draft(
      '84400000-0000-4000-8000-000000000011',
      1,
      jsonb_build_object(
        'id', '84500000-0000-4000-8000-000000000001',
        'institution_id', '84300000-0000-4000-8000-000000000002',
        'kind', 'form', 'identity_mode', 'anonymous', 'response_unit', 'person',
        'title', 'Cross tenant overwrite', 'description', 'Behavioral RPC contract',
        'sections', '[]'::jsonb
      )
    )$$,
  '23514',
  'use form_copy_or_move for institution changes',
  'an existing form id cannot be rewritten into another tenant'
);

select throws_ok(
  $$select public.form_save_draft(
      '84400000-0000-4000-8000-000000000012',
      0,
      jsonb_build_object(
        'id', '84500000-0000-4000-8000-000000000001',
        'institution_id', '84300000-0000-4000-8000-000000000001',
        'kind', 'form', 'identity_mode', 'anonymous', 'response_unit', 'person',
        'title', 'Stale overwrite', 'description', 'Behavioral RPC contract',
        'sections', '[]'::jsonb
      )
    )$$,
  '40001',
  'expected_version mismatch',
  'a stale expected_version cannot overwrite a form'
);

insert into forms_behavior_results(key, result)
select 'published', public.form_publish(
  '84400000-0000-4000-8000-000000000020',
  1,
  jsonb_build_object('form_id', '84500000-0000-4000-8000-000000000001')
);

select ok(
  (select result ->> 'status' = 'published'
       and (result ->> 'management_version')::bigint = 2
     from forms_behavior_results where key = 'published'),
  'form_publish executes and advances the management version'
);

select is(
  public.form_publish(
    '84400000-0000-4000-8000-000000000020',
    1,
    jsonb_build_object('form_id', '84500000-0000-4000-8000-000000000001')
  ),
  (select result from forms_behavior_results where key = 'published'),
  'an identical publish replay returns the original result'
);

reset role;

select ok(
  (select status = 'published'
       and working_version_id is null
       and published_version_id is not null
     from public.forms where id = '84500000-0000-4000-8000-000000000001'),
  'publication freezes the working version as the published version'
);

set local role authenticated;

insert into forms_behavior_results(key, result)
select 'edited', public.form_save_draft(
  '84400000-0000-4000-8000-000000000021',
  2,
  jsonb_build_object(
    'id', '84500000-0000-4000-8000-000000000001',
    'institution_id', '84300000-0000-4000-8000-000000000001',
    'kind', 'form',
    'identity_mode', 'anonymous',
    'response_unit', 'person',
    'title', 'Forms behavior revised',
    'description', 'Behavioral RPC contract',
    'sections', jsonb_build_array(jsonb_build_object(
      'id', 'section-1',
      'title', 'Revised section',
      'description', null,
      'position', 0,
      'items', jsonb_build_array(jsonb_build_object(
        'id', 'item-1',
        'kind', 'short_text',
        'label', 'Revised question',
        'help_text', null,
        'position', 0,
        'is_required', false,
        'config', jsonb_build_object('max_length', 100),
        'options', '[]'::jsonb,
        'conditions', '[]'::jsonb
      ))
    ))
  )
);

reset role;

select ok(
  (select working_version_id is not null
       and working_version_id <> published_version_id
       and management_version = 3
     from public.forms where id = '84500000-0000-4000-8000-000000000001'),
  'editing a published form creates a distinct working version'
);

select ok(
  (select count(*) = 2
       and count(*) filter (where state = 'published' and version_number = 1) = 1
       and count(*) filter (where state = 'working' and version_number = 2) = 1
     from public.form_versions where form_id = '84500000-0000-4000-8000-000000000001'),
  'the published version remains immutable while version two is working'
);

select ok(
  (select published_section.title = 'Original section'
       and working_section.title = 'Revised section'
     from public.forms form_row
     join public.form_sections published_section
       on published_section.form_version_id = form_row.published_version_id
     join public.form_sections working_section
       on working_section.form_version_id = form_row.working_version_id
    where form_row.id = '84500000-0000-4000-8000-000000000001'),
  'editing does not mutate the published relational definition'
);

reset role;

insert into public.form_applications(
  id, form_id, institution_id, name, status, opens_for_days, created_by_person_id
) values (
  '84600000-0000-4000-8000-000000000001',
  '84500000-0000-4000-8000-000000000001',
  '84300000-0000-4000-8000-000000000001',
  'Anonymous behavior application',
  'active',
  7,
  '84100000-0000-4000-8000-000000000001'
);

insert into public.form_schedules(
  id, application_id, status, time_zone, starts_at_local, recurrence_kind,
  interval_value, weekdays, monthly_day, monthly_last_day, end_kind
) values (
  '84600000-0000-4000-8000-000000000002',
  '84600000-0000-4000-8000-000000000001',
  'active',
  'America/Sao_Paulo',
  localtimestamp,
  'once',
  1,
  '{}'::smallint[],
  null,
  false,
  'never'
);

insert into public.form_audience_rules(
  id, application_id, institution_id, rule_kind, rule_mode, target_id, position
) values (
  '84600000-0000-4000-8000-000000000005',
  '84600000-0000-4000-8000-000000000001',
  '84300000-0000-4000-8000-000000000001',
  'institution',
  'include',
  '84300000-0000-4000-8000-000000000001',
  0
);

insert into public.form_schedule_reminders(
  id, schedule_id, reminder_kind, amount, position
) values (
  '84600000-0000-4000-8000-000000000007',
  '84600000-0000-4000-8000-000000000002',
  'before_close',
  2,
  0
);

insert into public.form_occurrences(
  id, application_id, schedule_id, institution_id, form_id, form_version_id,
  scheduled_local, time_zone, opens_at, closes_at, status, opened_at
)
select
  '84600000-0000-4000-8000-000000000003',
  '84600000-0000-4000-8000-000000000001',
  '84600000-0000-4000-8000-000000000002',
  form_row.institution_id,
  form_row.id,
  form_row.published_version_id,
  localtimestamp,
  'America/Sao_Paulo',
  now() - interval '1 hour',
  now() + interval '1 day',
  'open',
  now() - interval '1 hour'
from public.forms form_row
where form_row.id = '84500000-0000-4000-8000-000000000001';

insert into public.form_participations(
  id, occurrence_id, institution_id, person_id, response_unit_key,
  eligibility_state, response_state
) values (
  '84600000-0000-4000-8000-000000000004',
  '84600000-0000-4000-8000-000000000003',
  '84300000-0000-4000-8000-000000000001',
  '84100000-0000-4000-8000-000000000001',
  'person:84100000-0000-4000-8000-000000000001',
  'eligible',
  'pending'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '84000000-0000-4000-8000-000000000001', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}',
  true
);

select ok(
  (select editor -> 'definition' ->> 'id' = '84500000-0000-4000-8000-000000000001'
       and editor -> 'application' ->> 'id' = '84600000-0000-4000-8000-000000000001'
       and editor -> 'application' -> 'audience_rules' -> 0 ->> 'target_id'
         = '84300000-0000-4000-8000-000000000001'
       and editor -> 'application' -> 'schedules' -> 0 -> 'reminders' -> 0 ->> 'kind'
         = 'before_close'
     from (select public.form_get_editor(
       '84500000-0000-4000-8000-000000000001'
     ) editor) projection),
  'form_get_editor restores the persisted application, audience, schedules and reminders'
);

insert into forms_behavior_results(key, result)
select 'anonymous_opened', public.form_open_response_draft(
  '84400000-0000-4000-8000-000000000030',
  0,
  jsonb_build_object(
    'occurrence_id', '84600000-0000-4000-8000-000000000003',
    'participation_id', '84600000-0000-4000-8000-000000000004',
    'identity_mode', 'anonymous',
    'edit_secret', 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGH'
  )
);

reset role;

select ok(
  (select response.identity_mode = 'anonymous'
       and response.respondent_person_id is null
       and response.anonymous_edit_secret_hash is not null
       and participation.response_state = 'draft'
       and not exists (
         select 1 from app_private.form_command_receipts receipt
          where receipt.request_id = '84400000-0000-4000-8000-000000000030'
       )
     from forms_behavior_results opened
     join public.form_responses response on response.id = (opened.result ->> 'id')::uuid
     join public.form_participations participation
       on participation.id = '84600000-0000-4000-8000-000000000004'
    where opened.key = 'anonymous_opened'),
  'opening an anonymous response stores no actor identity or actor-linked command receipt'
);

set local role authenticated;

insert into forms_behavior_results(key, result)
select 'anonymous_submitted', public.form_submit_response(
  '84400000-0000-4000-8000-000000000031',
  1,
  jsonb_build_object(
    'response_id', (select result ->> 'id' from forms_behavior_results where key = 'anonymous_opened'),
    'participation_id', '84600000-0000-4000-8000-000000000004',
    'edit_secret', 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGH',
    'answers', '[]'::jsonb
  )
);

reset role;

select ok(
  (select response.status = 'submitted'
       and response.respondent_person_id is null
       and participation.response_state = 'responded'
       and revision.changed_by_person_id is null
     from forms_behavior_results submitted
     join public.form_responses response on response.id = (submitted.result ->> 'id')::uuid
     join public.form_participations participation
       on participation.id = '84600000-0000-4000-8000-000000000004'
     join public.form_response_revisions revision on revision.response_id = response.id
    where submitted.key = 'anonymous_submitted'
      and revision.action = 'submitted'),
  'submitting an anonymous response updates eligibility state without persisting the actor on content or revision'
);

select ok(
  not exists (
    select 1
      from information_schema.columns
     where table_schema = 'public'
       and table_name = 'form_responses'
       and column_name in ('participation_id', 'response_unit_key', 'child_context_id')
  )
  and not exists (
    select 1
      from pg_constraint constraint_row
     where constraint_row.conrelid = 'public.form_responses'::regclass
       and constraint_row.confrelid = 'public.form_participations'::regclass
  ),
  'anonymous response content has no persistent participation key or foreign-key link'
);

reset role;

select * from finish();
rollback;
