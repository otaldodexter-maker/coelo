begin;

create extension if not exists pgtap with schema extensions;
select plan(12);

select lives_ok(
  $$select app_private.form_assert_application_payload_limits(
      jsonb_build_object('rules', (
        select jsonb_agg(jsonb_build_object('position', value))
          from generate_series(0, 49) value
      ))
    )$$,
  'application payload accepts exactly 50 audience rules'
);

select throws_ok(
  $$select app_private.form_assert_application_payload_limits(
      jsonb_build_object('rules', (
        select jsonb_agg(jsonb_build_object('position', value))
          from generate_series(0, 50) value
      ))
    )$$,
  '23514',
  'maximum 50 form audience rules',
  'application payload rejects audience rule limit plus one'
);

select lives_ok(
  $$select app_private.form_assert_schedule_payload_limits(
      jsonb_build_object('reminders', (
        select jsonb_agg(jsonb_build_object('position', value))
          from generate_series(0, 2) value
      ))
    )$$,
  'schedule payload accepts exactly three reminders'
);

select throws_ok(
  $$select app_private.form_assert_schedule_payload_limits(
      jsonb_build_object('reminders', (
        select jsonb_agg(jsonb_build_object('position', value))
          from generate_series(0, 3) value
      ))
    )$$,
  '23514',
  'maximum 3 form schedule reminders',
  'schedule payload rejects reminder limit plus one'
);

insert into auth.users(id, aud, role, email, created_at, updated_at)
values ('87000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'forms-limits@test.invalid', now(), now());
insert into public.people(id, person_type, first_name, last_name, display_name, status)
values ('87100000-0000-4000-8000-000000000001', 'adult', 'Forms', 'Limits', 'Forms Limits', 'active');
insert into public.person_auth_links(person_id, auth_user_id, status)
values ('87100000-0000-4000-8000-000000000001', '87000000-0000-4000-8000-000000000001', 'active');
insert into public.institutions(id, public_name, legal_name, slug, status)
values ('87200000-0000-4000-8000-000000000001', 'Forms Limits', 'Forms Limits', 'forms-limits', 'active');
insert into public.forms(
  id, institution_id, kind, identity_mode, response_unit, title,
  created_by_person_id, updated_by_person_id
) values (
  '87300000-0000-4000-8000-000000000001', '87200000-0000-4000-8000-000000000001',
  'form', 'identified', 'person', 'Forms Limits',
  '87100000-0000-4000-8000-000000000001', '87100000-0000-4000-8000-000000000001'
);
insert into public.form_applications(id, form_id, institution_id, name, created_by_person_id)
values (
  '87400000-0000-4000-8000-000000000001', '87300000-0000-4000-8000-000000000001',
  '87200000-0000-4000-8000-000000000001', 'Forms Limits',
  '87100000-0000-4000-8000-000000000001'
);
insert into public.form_schedules(
  id, application_id, time_zone, starts_at_local, recurrence_kind, interval_value,
  weekdays, monthly_last_day, end_kind
)
select md5('forms-limit-' || value::text)::uuid,
       '87400000-0000-4000-8000-000000000001', 'America/Sao_Paulo',
       timestamp '2026-08-20 08:00:00' + value * interval '1 day',
       'once', 1, '{}'::smallint[], false, 'never'
  from generate_series(1, 19) value;

select lives_ok(
  $$select app_private.form_assert_schedule_capacity(
      '87400000-0000-4000-8000-000000000001',
      '87500000-0000-4000-8000-000000000001'
    )$$,
  'application accepts exactly twenty active schedules'
);

insert into public.form_schedules(
  id, application_id, time_zone, starts_at_local, recurrence_kind, interval_value,
  weekdays, monthly_last_day, end_kind
) values (
  '87500000-0000-4000-8000-000000000001', '87400000-0000-4000-8000-000000000001',
  'America/Sao_Paulo', timestamp '2026-12-01 08:00:00', 'once', 1, '{}'::smallint[], false, 'never'
);

select throws_ok(
  $$select app_private.form_assert_schedule_capacity(
      '87400000-0000-4000-8000-000000000001',
      '87500000-0000-4000-8000-000000000002'
    )$$,
  '23514',
  'maximum 20 active form schedules per application',
  'application rejects active schedule limit plus one'
);
select ok(
  pg_get_functiondef('app_private.form_save_application(uuid,bigint,jsonb)'::regprocedure)
    like '%form_assert_application_payload_limits%',
  'save_application invokes the audience payload guard'
);

select ok(
  pg_get_functiondef('app_private.form_save_schedule(uuid,bigint,jsonb)'::regprocedure)
    like '%form_assert_schedule_payload_limits%'
  and pg_get_functiondef('app_private.form_save_schedule(uuid,bigint,jsonb)'::regprocedure)
    like '%form_assert_schedule_capacity%',
  'save_schedule invokes reminder and application schedule guards'
);

select ok(
  pg_get_functiondef('app_private.form_application_projection(uuid)'::regprocedure)
    like '%limit 50%'
  and pg_get_functiondef('app_private.form_application_projection(uuid)'::regprocedure)
    like '%limit 20%'
  and pg_get_functiondef('app_private.form_application_projection(uuid)'::regprocedure)
    like '%limit 3%',
  'application projection has bounded normalized child collections'
);

select col_is_unique(
  'public', 'form_audience_rules', array['application_id', 'position'],
  'audience rule positions are unique inside an application'
);

select col_is_unique(
  'public', 'form_schedule_reminders', array['schedule_id', 'reminder_kind'],
  'each reminder kind occurs at most once per schedule'
);

select has_trigger(
  'public', 'form_schedules', 'form_distribution_cardinality_validate',
  'normalized schedules enforce their application cardinality'
);

select * from finish();
rollback;
