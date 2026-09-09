-- D02 local candidate: normalization and surface safety. Integration/lock cases
-- must be added before any complete acceptance; this file is not remote evidence.
begin;
select plan(29);
select is(jsonb_array_length(app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"group","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"once"},"conflict_justification":null}'::jsonb)->'occurrences'),1,'once expands to one occurrence');
select is(jsonb_array_length(app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"activity","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"weekly","weekdays":[3],"until":"2026-09-23","time_zone":"America/Sao_Paulo"},"conflict_justification":null}'::jsonb)->'occurrences'),3,'weekly expands calendar dates inclusively');
select throws_ok($$select app_private.location_reservation_normalize_v2('{}'::jsonb)$$,'22023',null,'missing request rejected');
select throws_ok($$select app_private.location_reservation_normalize_v2('{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"event","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"once"},"conflict_justification":null}'::jsonb)$$,'22023',null,'unimplemented consumer cannot obtain a binding');
select ok(not has_table_privilege('authenticated','public.location_reservations','SELECT,INSERT,UPDATE,DELETE'),'no direct reservation grants');
select ok(not has_table_privilege('service_role','public.location_reservation_occurrences','SELECT,INSERT,UPDATE,DELETE'),'no service direct occurrence grants');
select ok(not has_function_privilege('authenticated','app_private.location_reservation_normalize_v2(jsonb)','EXECUTE'),'normalizer stays private');
select ok(not has_function_privilege('anon','public.superadmin_location_reservation_create_v2(jsonb,uuid)','EXECUTE'),'anonymous create denied');
select ok(has_function_privilege('authenticated','public.superadmin_location_reservation_create_v2(jsonb,uuid)','EXECUTE'),'authenticated enters checked gateway');
select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in('public.location_reservations'::regclass,'public.location_reservation_occurrences'::regclass,'public.location_bindings'::regclass,'public.location_scheduling_policies'::regclass)),'all exposed tables force RLS');
select is((select count(*)::integer from pg_policies where schemaname='public' and tablename in('location_reservations','location_reservation_occurrences','location_bindings','location_scheduling_policies')),0,'deny by default without direct policies');
select ok(not exists(select 1 from public.location_scheduling_policies),'migration does not invent a default conflict policy');
select is(
  app_private.location_reservation_normalize_v2(
    '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"activity","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"weekly","weekdays":[5,3,1],"until":"2026-09-25","time_zone":"America/Sao_Paulo"},"conflict_justification":null}'::jsonb
  )#>'{recurrence,weekdays}',
  '[1,3,5]'::jsonb,
  'weekly weekdays are canonicalized before hashing and persistence'
);
select is(
  app_private.location_reservation_normalize_v2(
    '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"group","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"once"},"conflict_justification":"  reunião pedagógica  "}'::jsonb
  )->>'conflict_justification',
  'reunião pedagógica',
  'conflict justification is normalized once'
);
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":null,"id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"once"},"conflict_justification":null}'::jsonb)$$,
  '22023',null,'JSON null consumer kind is rejected');
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"group","id":null},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"once"},"conflict_justification":null}'::jsonb)$$,
  '22023',null,'JSON null consumer id is rejected');
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"group","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":null},"conflict_justification":null}'::jsonb)$$,
  '22023',null,'JSON null recurrence kind is rejected');
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"activity","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"weekly","weekdays":[3,3],"until":"2026-09-23","time_zone":"America/Sao_Paulo"},"conflict_justification":null}'::jsonb)$$,
  '22023',null,'duplicate recurrence weekdays are rejected');
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"activity","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"weekly","weekdays":[3],"until":"2026-09-23","time_zone":"Mars/Olympus"},"conflict_justification":null}'::jsonb)$$,
  '22023',null,'unknown timezone is rejected');
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"activity","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"weekly","weekdays":[3],"until":"2026-09-23","time_zone":"+03:00"},"conflict_justification":null}'::jsonb)$$,
  '22023',null,'fixed offset cannot replace an IANA timezone');
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"activity","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"weekly","weekdays":[3],"until":"2026-09-23","time_zone":"posix/America/Sao_Paulo"},"conflict_justification":null}'::jsonb)$$,
  '22023',null,'posix timezone aliases are outside the protocol');
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"activity","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"weekly","weekdays":[3],"until":"2026-09-23","time_zone":"right/America/Sao_Paulo"},"conflict_justification":null}'::jsonb)$$,
  '22023',null,'right timezone aliases are outside the protocol');
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"activity","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-03-01T07:30:00Z","ends_at":"2026-03-01T08:30:00Z"},"recurrence":{"kind":"weekly","weekdays":[0],"until":"2026-03-08","time_zone":"America/New_York"},"conflict_justification":null}'::jsonb)$$,
  '22023',null,'derived occurrence in a DST gap is rejected instead of shifted');
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"activity","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-10-25T05:30:00Z","ends_at":"2026-10-25T06:00:00Z"},"recurrence":{"kind":"weekly","weekdays":[0],"until":"2026-11-01","time_zone":"America/New_York"},"conflict_justification":null}'::jsonb)$$,
  '22023',null,'derived occurrence in a DST fold is rejected as ambiguous');
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"activity","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-01-01T12:00:00Z","ends_at":"2026-01-01T13:00:00Z"},"recurrence":{"kind":"weekly","weekdays":[0,1,2,3,4,5,6],"until":"2029-01-01","time_zone":"UTC"},"conflict_justification":null}'::jsonb)$$,
  '22023',null,'weekly expansion is bounded to one thousand occurrences');
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"activity","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"weekly","weekdays":[4],"until":"2026-09-24","time_zone":"UTC"},"conflict_justification":null}'::jsonb)$$,
  '22023',null,'first local calendar day must be one selected weekday');
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"group","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-01T12:00:00Z","ends_at":"2026-10-03T12:00:00Z"},"recurrence":{"kind":"once"},"conflict_justification":null}'::jsonb)$$,
  '22023',null,'single occurrence interval cannot exceed the defensive bound');
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"group","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"once"},"conflict_justification":null,"unexpected":true}'::jsonb)$$,
  '22023',null,'reservation request rejects unknown members');
select throws_ok($$select app_private.location_reservation_normalize_v2(
  '{"location_id":"a1000000-0000-4000-8000-000000000001","consumer":{"kind":"group","id":"a1000000-0000-4000-8000-000000000002"},"first_occurrence":{"starts_at":"2026-09-09T12:00:00Z","ends_at":"2026-09-09T13:00:00Z"},"recurrence":{"kind":"once"},"conflict_justification":[]}'::jsonb)$$,
  '22023',null,'conflict justification accepts only string or null');

select * from finish();
rollback;
