-- PROPOSED ONLY: not part of the test runner, replay profile, or migrations.
-- Source: ROUTINE-READ01 crosswalk, 2026-09-07. No SQL execution claimed.
-- Run only after the coordinator closes the nominal base and signature.
-- Precondition: the authorized harness installs pgTAP and exposes its functions
-- through search_path. This draft does not bootstrap any database dependency.
begin;
select no_plan();
select has_function('public','superadmin_routine_directory_v2',
 array['text','text','text','uuid','uuid','uuid','integer','integer'],
 'proposed internal directory signature exists');
select ok(coalesce(has_function_privilege('authenticated',
 to_regprocedure('public.superadmin_routine_directory_v2(text,text,text,uuid,uuid,uuid,integer,integer)'),
 'EXECUTE'),false),'authenticated may enter the nominal wrapper');
select ok(not coalesce(has_function_privilege('anon',
 to_regprocedure('public.superadmin_routine_directory_v2(text,text,text,uuid,uuid,uuid,integer,integer)'),
 'EXECUTE'),true),'anonymous has no directory execute');
select ok(not coalesce(has_function_privilege('service_role',
 to_regprocedure('public.superadmin_routine_directory_v2(text,text,text,uuid,uuid,uuid,integer,integer)'),
 'EXECUTE'),true),'service role has no implicit directory execute');
-- Behavioral fixture/negative/reload/audit tests remain mandatory in the crosswalk.
-- These catalog checks alone never prove authorization or integration.
select * from finish();
rollback;
