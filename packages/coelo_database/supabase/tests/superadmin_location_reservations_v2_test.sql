-- D02 local candidate: normalization and surface safety. Integration/lock cases
-- must be added before any complete acceptance; this file is not remote evidence.
begin;
create extension if not exists pgtap with schema extensions;
select plan(49);
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

-- Nominal integration fixture. It exercises the real internal-auth context,
-- owner hierarchy and Group consumer; no permission helper or RPC is mocked.
insert into public.institution_types(id,code,name,status) values
  ('c1000000-0000-4000-8000-000000000001','reservation-test-type','Reservation test type','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
  ('c1100000-0000-4000-8000-000000000001','Reservation Institution A','reservation-a','active','c1000000-0000-4000-8000-000000000001'),
  ('c1100000-0000-4000-8000-000000000002','Reservation Institution B','reservation-b','active','c1000000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,name,slug,status,institution_type_id) values
  ('c1200000-0000-4000-8000-000000000001','c1100000-0000-4000-8000-000000000001','Reservation Unit A','reservation-unit-a','active','c1000000-0000-4000-8000-000000000001'),
  ('c1200000-0000-4000-8000-000000000002','c1100000-0000-4000-8000-000000000002','Reservation Unit B','reservation-unit-b','active','c1000000-0000-4000-8000-000000000001');
insert into public.groups(id,institution_id,unit_id,name,status) values
  ('c1300000-0000-4000-8000-000000000001','c1100000-0000-4000-8000-000000000001','c1200000-0000-4000-8000-000000000001','Reservation Group A','active'),
  ('c1300000-0000-4000-8000-000000000002','c1100000-0000-4000-8000-000000000002','c1200000-0000-4000-8000-000000000002','Reservation Group B','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
  select ('c1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'authenticated','authenticated',
    'reservation-'||i||'@invalid.test',now(),now(),now(),'{}','{}' from generate_series(1,4) i;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
  select ('c1500000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('c1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,now(),now(),'aal1',now()+interval '1 hour'
    from generate_series(1,4) i;
insert into app_private.superadmin_internal_identities(id)
  select ('c1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid from generate_series(1,4) i;
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,status)
  select ('c1700000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('c1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('c1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'active' from generate_series(1,4) i;
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,status)
  select ('c1800000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('c1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,r.id,
    (case when i in(1,2) then 'institution' else 'platform' end)::app_private.superadmin_internal_scope_kind,
    case when i=1 then 'c1100000-0000-4000-8000-000000000001'::uuid
      when i=2 then 'c1100000-0000-4000-8000-000000000002'::uuid end,'active'
  from generate_series(1,4) i
  join public.platform_roles r on r.code=case when i=4 then 'operations' else 'owner' end;
insert into public.activity_locations(id,institution_id,unit_id,name,status,scope_kind,kind,visibility,
  created_by_internal_identity_id) values
  ('c1900000-0000-4000-8000-000000000001','c1100000-0000-4000-8000-000000000001',null,
    'Reservation Room A','active','institution','internal','team','c1600000-0000-4000-8000-000000000001'),
  ('c1900000-0000-4000-8000-000000000002','c1100000-0000-4000-8000-000000000002',null,
    'Reservation Room B','active','institution','internal','team','c1600000-0000-4000-8000-000000000002');

create function pg_temp.reservation_actor(i integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub','c1400000-0000-4000-8000-'||lpad(i::text,12,'0'),
    'session_id','c1500000-0000-4000-8000-'||lpad(i::text,12,'0'),
    'aal','aal1','role','authenticated')::text,true);
end
$$;
create function pg_temp.reservation_payload(p_start text,p_end text,p_reason text default null)
returns jsonb language sql immutable as $$
  select jsonb_build_object('location_id','c1900000-0000-4000-8000-000000000001',
    'consumer',jsonb_build_object('kind','group','id','c1300000-0000-4000-8000-000000000001'),
    'first_occurrence',jsonb_build_object('starts_at',p_start,'ends_at',p_end),
    'recurrence',jsonb_build_object('kind','once'),'conflict_justification',p_reason)
$$;
create temporary table reservation_results(label text primary key,body jsonb);
grant select,insert on reservation_results to authenticated;

select pg_temp.reservation_actor(1);
set local role authenticated;
insert into reservation_results values('policy_unset',public.superadmin_location_scheduling_policy_v2(
  'c1900000-0000-4000-8000-000000000001'));
insert into reservation_results values('policy_block',public.superadmin_location_scheduling_policy_set_v2(
  'c1900000-0000-4000-8000-000000000001','{"policy":"block","expected_version":0}',
  'ca000000-0000-4000-8000-000000000001'));
insert into reservation_results values('assess_free',public.superadmin_location_reservation_assess_v2(
  pg_temp.reservation_payload('2026-09-10T12:00:00Z','2026-09-10T13:00:00Z')));
insert into reservation_results values('create_first',public.superadmin_location_reservation_create_v2(
  pg_temp.reservation_payload('2026-09-10T12:00:00Z','2026-09-10T13:00:00Z'),
  'ca000000-0000-4000-8000-000000000002'));
insert into reservation_results values('create_replay',public.superadmin_location_reservation_create_v2(
  pg_temp.reservation_payload('2026-09-10T12:00:00Z','2026-09-10T13:00:00Z'),
  'ca000000-0000-4000-8000-000000000002'));
insert into reservation_results values('create_changed_replay',public.superadmin_location_reservation_create_v2(
  pg_temp.reservation_payload('2026-09-10T12:00:00Z','2026-09-10T13:30:00Z'),
  'ca000000-0000-4000-8000-000000000002'));
insert into reservation_results values('assess_blocked',public.superadmin_location_reservation_assess_v2(
  pg_temp.reservation_payload('2026-09-10T12:30:00Z','2026-09-10T13:30:00Z')));
insert into reservation_results values('create_blocked',public.superadmin_location_reservation_create_v2(
  pg_temp.reservation_payload('2026-09-10T12:30:00Z','2026-09-10T13:30:00Z'),
  'ca000000-0000-4000-8000-000000000003'));
insert into reservation_results values('policy_warn',public.superadmin_location_scheduling_policy_set_v2(
  'c1900000-0000-4000-8000-000000000001','{"policy":"warn","expected_version":1}',
  'ca000000-0000-4000-8000-000000000004'));
insert into reservation_results values('assess_warn',public.superadmin_location_reservation_assess_v2(
  pg_temp.reservation_payload('2026-09-10T12:30:00Z','2026-09-10T13:30:00Z')));
insert into reservation_results values('override_without_reason',public.superadmin_location_reservation_create_v2(
  pg_temp.reservation_payload('2026-09-10T12:30:00Z','2026-09-10T13:30:00Z'),
  'ca000000-0000-4000-8000-000000000009'));
insert into reservation_results values('create_override',public.superadmin_location_reservation_create_v2(
  pg_temp.reservation_payload('2026-09-10T12:30:00Z','2026-09-10T13:30:00Z','Conflito aprovado'),
  'ca000000-0000-4000-8000-000000000005'));
insert into reservation_results values('cancel_first',public.superadmin_location_reservation_cancel_v2(
  'c1900000-0000-4000-8000-000000000001',jsonb_build_object(
    'consumer',jsonb_build_object('kind','group','id','c1300000-0000-4000-8000-000000000001'),
    'reservation_id',(select body#>>'{data,id}' from reservation_results where label='create_first'),
    'expected_version',1),'ca000000-0000-4000-8000-000000000006'));
insert into reservation_results select 'cancel_replay',public.superadmin_location_reservation_cancel_v2(
  'c1900000-0000-4000-8000-000000000001',jsonb_build_object(
    'consumer',jsonb_build_object('kind','group','id','c1300000-0000-4000-8000-000000000001'),
    'reservation_id',(select body#>>'{data,id}' from reservation_results where label='create_first'),
    'expected_version',1),'ca000000-0000-4000-8000-000000000006');
insert into reservation_results values('list_first',public.superadmin_location_reservations_v2(
  'c1900000-0000-4000-8000-000000000001',
  '{"kind":"group","id":"c1300000-0000-4000-8000-000000000001"}',null,1));
insert into reservation_results select 'list_second',public.superadmin_location_reservations_v2(
  'c1900000-0000-4000-8000-000000000001',
  '{"kind":"group","id":"c1300000-0000-4000-8000-000000000001"}',
  (select (body#>>'{data,next_id}')::uuid from reservation_results where label='list_first'),1);
reset role;

select pg_temp.reservation_actor(2);
set local role authenticated;
insert into reservation_results values('cross_scope',public.superadmin_location_reservation_create_v2(
  pg_temp.reservation_payload('2026-09-11T12:00:00Z','2026-09-11T13:00:00Z'),
  'ca000000-0000-4000-8000-000000000007'));
reset role;
select pg_temp.reservation_actor(3);
set local role authenticated;
insert into reservation_results values('platform_owner',public.superadmin_location_scheduling_policy_v2(
  'c1900000-0000-4000-8000-000000000001'));
reset role;
select pg_temp.reservation_actor(4);
set local role authenticated;
insert into reservation_results values('operations_denied',public.superadmin_location_scheduling_policy_v2(
  'c1900000-0000-4000-8000-000000000001'));
reset role;

update auth.sessions set not_after=clock_timestamp()
  where id='c1500000-0000-4000-8000-000000000001';
select pg_temp.reservation_actor(1);
set local role authenticated;
insert into reservation_results values('expired_create',public.superadmin_location_reservation_create_v2(
  pg_temp.reservation_payload('2026-09-12T12:00:00Z','2026-09-12T13:00:00Z'),
  'ca000000-0000-4000-8000-000000000008'));
reset role;

select ok((select body#>>'{ok}'='true' and body#>>'{data,policy}' is null
  and body#>>'{data,management_version}'='0' from reservation_results where label='policy_unset'),
  'policy get preserves explicit unset state');
select ok((select body#>>'{ok}'='true' and body#>>'{data,policy}'='block'
  and body#>>'{data,management_version}'='1' from reservation_results where label='policy_block'),
  'Owner sets the first explicit block policy');
select is((select body#>>'{data,conflict}' from reservation_results where label='assess_free'),'none',
  'assessment reports a free interval');
select ok((select body#>>'{ok}'='true' and body#>>'{data,state}'='active'
  from reservation_results where label='create_first'),'create persists the first reservation');
select is((select body#>>'{data,id}' from reservation_results where label='create_replay'),
  (select body#>>'{data,id}' from reservation_results where label='create_first'),
  'identical create request replays the same reservation');
select is((select body#>>'{error,code}' from reservation_results where label='create_changed_replay'),
  'SAI_CONCURRENT_CHANGE','changed payload cannot reuse a create request id');
select is((select body#>>'{data,conflict}' from reservation_results where label='assess_blocked'),'refused',
  'block policy refuses an overlapping assessment');
select ok((select body#>>'{error,code}'='SAI_CONCURRENT_CHANGE' from reservation_results
    where label='create_blocked') and not exists(select 1 from app_private.location_reservation_receipts
      where request_id='ca000000-0000-4000-8000-000000000003'),
  'blocked overlap writes neither reservation nor receipt');
select ok((select body#>>'{data,policy}'='warn' and body#>>'{data,management_version}'='2'
  from reservation_results where label='policy_warn'),'policy update uses optimistic versioning');
select is((select body#>>'{data,conflict}' from reservation_results where label='assess_warn'),'confirmable',
  'warn assessment reflects the real override capability');
select ok((select body#>>'{data,confirmed_over_conflict}'='true'
  from reservation_results where label='create_override')
  and (select body#>>'{error,code}'='SAI_INVALID_ARGUMENT'
    from reservation_results where label='override_without_reason')
  and not exists(select 1 from app_private.location_reservation_receipts
    where request_id='ca000000-0000-4000-8000-000000000009'),
  'warn override requires a reason before persisting its conflict marker');
select ok(exists(select 1 from audit.audit_logs where action_code='location.reservation.override'
  and permission_code='locations.reservations.override' and outcome='success'
  and reason_code='RESERVATION_CONFLICT_OVERRIDE'
  and after_json='{"state":"confirmed_over_conflict"}'::jsonb
  and object_id=(select (body#>>'{data,id}')::uuid from reservation_results where label='create_override')),
  'override audit records a nominal reason and reservation reference without free text');
select ok((select body#>>'{data,state}'='cancelled' and body#>>'{data,management_version}'='2'
  from reservation_results where label='cancel_first'),'cancel updates the complete reservation once');
select is((select body#>>'{data,id}' from reservation_results where label='cancel_replay'),
  (select body#>>'{data,id}' from reservation_results where label='cancel_first'),
  'identical cancel request replays its result');
select ok((select jsonb_array_length(body#>'{data,items}')=1 and body#>>'{data,next_id}'=
  body#>>'{data,items,0,id}' from reservation_results where label='list_first'),
  'first list page returns one item and its strict continuation cursor');
select ok((select jsonb_array_length(body#>'{data,items}')=1
  and body#>>'{data,items,0,id}'<>(select body#>>'{data,items,0,id}' from reservation_results where label='list_first')
  and body#>>'{data,next_id}' is null from reservation_results where label='list_second'),
  'second list page advances without duplicating the cursor item');
select ok((select body#>>'{error,code}'='SAI_PERMISSION_DENIED' from reservation_results
    where label='cross_scope') and not exists(select 1 from app_private.location_reservation_receipts
      where request_id='ca000000-0000-4000-8000-000000000007'),
  'institution B cannot reserve institution A or leave a receipt');
select is((select body#>>'{data,owner_id}' from reservation_results where label='platform_owner'),
  'c1100000-0000-4000-8000-000000000001','platform Owner reads the current catalog owner');
select is((select body#>>'{error,code}' from reservation_results where label='operations_denied'),
  'SAI_PERMISSION_DENIED','Operations cannot inherit Owner-only reservation access');
select ok((select body#>>'{error,code}'='SAI_SESSION_INVALID' from reservation_results
    where label='expired_create') and not exists(select 1 from app_private.location_reservation_receipts
      where request_id='ca000000-0000-4000-8000-000000000008'),
  'expired session rolls back reservation effects and its receipt');

select * from finish();
rollback;
