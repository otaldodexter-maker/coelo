-- LOCAL CANDIDATE ONLY: selected/executed by the serialized replay owner.
-- Covers 20260908190650_superadmin_locations_schedule_v2.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_function('public','superadmin_location_schedule_v2',array['uuid']);
select has_function('public','superadmin_location_schedule_set_v2',
  array['uuid','jsonb','bigint','uuid']);
select ok(has_function_privilege('authenticated',
  'public.superadmin_location_schedule_v2(uuid)','EXECUTE'),
  'reading the schedule is reachable by a client');
select ok(has_function_privilege('authenticated',
  'public.superadmin_location_schedule_set_v2(uuid,jsonb,bigint,uuid)','EXECUTE'),
  'publishing the schedule is reachable by a client');
select ok(not has_function_privilege('anon',
  'public.superadmin_location_schedule_v2(uuid)','EXECUTE'),
  'an anonymous caller cannot read the schedule');
select ok(not has_function_privilege('anon',
  'public.superadmin_location_schedule_set_v2(uuid,jsonb,bigint,uuid)','EXECUTE'),
  'an anonymous caller cannot publish a schedule');
select ok(not has_function_privilege('authenticated',
  'app_private.superadmin_location_schedule_normalize_v2(jsonb)','EXECUTE'),
  'the schedule normalizer has no client execution');
select ok(not has_function_privilege('authenticated',
  'app_private.superadmin_location_schedule_payload_v2(uuid)','EXECUTE'),
  'the schedule payload helper has no client execution');
select is((select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in('public','app_private')
    and p.proname in('superadmin_location_schedule_v2','superadmin_location_schedule_set_v2',
      'superadmin_location_schedule_payload_v2')
    and p.prosecdef and p.proconfig @> array['search_path=""']),3,
  'every added definer function pins an empty search path');

-- The windows are a child of the catalog, not a second catalog.
select is((select count(*)::integer from pg_attribute
  where attrelid='public.activity_locations'::regclass and attnum>0 and not attisdropped),16,
  'the schedule package did not widen the catalog');
select has_table('public'::name,'activity_location_schedules'::name);
select ok((select relrowsecurity and relforcerowsecurity from pg_class
  where oid='public.activity_location_schedules'::regclass),'the windows are RLS forced');
select ok(not has_table_privilege('authenticated','public.activity_location_schedules','SELECT'),
  'a client cannot read the windows directly');
select ok(not has_table_privilege('authenticated','public.activity_location_schedules','INSERT'),
  'a client cannot write the windows directly');
select ok(not has_table_privilege('service_role','public.activity_location_schedules','SELECT'),
  'not even service_role reads the windows directly');
select is((select count(*)::integer from pg_policy
  where polrelid='public.activity_location_schedules'::regclass),0,
  'forced RLS with no policy denies every direct path');
select is((select count(*)::integer from pg_constraint
  where conrelid='public.activity_location_schedules'::regclass and contype='f'
    and confrelid='public.activity_locations'::regclass and confdeltype='c'),1,
  'the windows disappear with the location they belong to');
select is((select count(*)::integer from pg_constraint
  where conrelid='public.activity_location_schedules'::regclass and contype='c'
    and pg_get_constraintdef(oid)=$def$CHECK ((starts_minute < ends_minute))$def$),1,
  'a window cannot end before it starts');
select is((select count(*)::integer from pg_constraint
  where conrelid='public.activity_location_schedules'::regclass and contype='u'),1,
  'the same day cannot hold two windows starting at the same minute');

-- The schedule joins the same receipt lane instead of opening another.
select is((select count(*)::integer from pg_constraint
  where conrelid='app_private.superadmin_location_write_receipts'::regclass and contype='c'
    and pg_get_constraintdef(oid) like 'CHECK ((operation = ANY (ARRAY[%'
    and pg_get_constraintdef(oid) like '%''schedule''::text%'),1,
  'the receipt lane names the schedule verb');
select is((select count(*)::integer from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='app_private' and c.relkind='r'
    and c.relname like 'superadmin_location_%receipts'),1,
  'there is still exactly one write receipt table');

-- The normalizer is the whole contract for what a week may say.
select is(app_private.superadmin_location_schedule_normalize_v2('[]'::jsonb),'[]'::jsonb,
  'an empty week is a valid week');
select is(app_private.superadmin_location_schedule_normalize_v2(
  '[{"weekday":3,"starts_minute":600,"ends_minute":720},
    {"weekday":1,"starts_minute":480,"ends_minute":540}]'::jsonb),
  '[{"weekday": 1, "ends_minute": 540, "starts_minute": 480},
    {"weekday": 3, "ends_minute": 720, "starts_minute": 600}]'::jsonb,
  'a week comes back canonically ordered so equal weeks hash equally');
select throws_ok($$select app_private.superadmin_location_schedule_normalize_v2(
  '[{"weekday":1,"starts_minute":480,"ends_minute":600},
    {"weekday":1,"starts_minute":540,"ends_minute":660}]'::jsonb)$$,
  '22023',null,'two windows cannot overlap on the same day');
select throws_ok($$select app_private.superadmin_location_schedule_normalize_v2(
  '[{"weekday":1,"starts_minute":600,"ends_minute":600}]'::jsonb)$$,
  '22023',null,'a window with no duration is not a window');
select throws_ok($$select app_private.superadmin_location_schedule_normalize_v2(
  '[{"weekday":7,"starts_minute":0,"ends_minute":60}]'::jsonb)$$,
  '22023',null,'the week has seven days');
select throws_ok($$select app_private.superadmin_location_schedule_normalize_v2(
  '[{"weekday":1,"starts_minute":0,"ends_minute":1441}]'::jsonb)$$,
  '22023',null,'a day ends at midnight');
select throws_ok($$select app_private.superadmin_location_schedule_normalize_v2(
  '[{"weekday":1.5,"starts_minute":0,"ends_minute":60}]'::jsonb)$$,
  '22023',null,'a weekday is a whole number');
select throws_ok($$select app_private.superadmin_location_schedule_normalize_v2(
  '[{"weekday":1,"starts_minute":0,"ends_minute":60,"note":"x"}]'::jsonb)$$,
  '22023',null,'a window carries no field the catalog did not define');
select throws_ok($$select app_private.superadmin_location_schedule_normalize_v2('{}'::jsonb)$$,
  '22023',null,'a week is an array');
select throws_ok($$select app_private.superadmin_location_schedule_normalize_v2(null)$$,
  '22023',null,'a missing week is not an empty week');
select lives_ok($$select app_private.superadmin_location_schedule_normalize_v2(
  '[{"weekday":1,"starts_minute":480,"ends_minute":600},
    {"weekday":1,"starts_minute":600,"ends_minute":720}]'::jsonb)$$,
  'windows that merely touch are not overlapping');

-- Deny by default: without an internal context neither command does anything.
create temporary table location_schedule_responses(seq integer primary key, body jsonb);
grant insert on location_schedule_responses to authenticated;
set local role authenticated;
insert into location_schedule_responses values
  (1,public.superadmin_location_schedule_v2('10000000-0000-4000-8000-000000000001')),
  (2,public.superadmin_location_schedule_set_v2('10000000-0000-4000-8000-000000000001',
     '[{"weekday":1,"starts_minute":480,"ends_minute":600}]'::jsonb,1,
     '10000000-0000-4000-8000-000000000002')),
  -- A malformed request must still authenticate before it is judged malformed.
  (3,public.superadmin_location_schedule_set_v2(null,'"nao-e-uma-semana"'::jsonb,null,null));
reset role;
select is((select body#>>'{error,code}' from location_schedule_responses where seq=1),
  'SAI_AUTH_REQUIRED','reading a schedule requires a validated session');
select is((select body#>>'{error,code}' from location_schedule_responses where seq=2),
  'SAI_AUTH_REQUIRED','publishing a schedule requires a validated session');
select is((select body#>>'{error,code}' from location_schedule_responses where seq=3),
  'SAI_AUTH_REQUIRED','publishing authenticates before it reads the week');
select is((select count(*)::integer from location_schedule_responses where body->>'ok'<>'false'),0,
  'no unauthenticated call reported success');
select is((select count(*)::integer from public.activity_location_schedules),0,
  'no unauthenticated call published a window');

select * from finish();
rollback;
