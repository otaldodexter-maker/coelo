-- LOCAL CANDIDATE; all SQL cases unexecuted until the coordinator's slot.
-- Requires ActivityAggregateConcurrencyClock + LocationReservationsV1 nominal
-- union, then 20260909200000. No helpers, policies or grants are mocked.
-- Real two-session expiry/revocation during the final audit lock remain a
-- separate serialized qualification; this TAP does not substitute for them.
begin;
create extension if not exists pgtap with schema extensions;
select plan(33);
select ok(has_function_privilege('authenticated','public.superadmin_activity_location_create_v2(uuid,uuid,jsonb,jsonb)','EXECUTE'),'authenticated enters checked create');
select ok(not has_function_privilege('anon','public.superadmin_activity_location_create_v2(uuid,uuid,jsonb,jsonb)','EXECUTE'),'anonymous create denied');
select ok(not has_function_privilege('service_role','public.superadmin_activity_location_create_v2(uuid,uuid,jsonb,jsonb)','EXECUTE'),'service create denied');
select ok(not has_table_privilege('authenticated','public.activity_location_selections','SELECT,INSERT,UPDATE,DELETE'),'selection table has no direct grants');
select ok(not has_table_privilege('authenticated','app_private.activity_location_create_receipts','SELECT,INSERT,UPDATE,DELETE'),'receipts remain private');
insert into public.institution_types(id,code,name,status) values
 ('e1000000-0000-4000-8000-000000000001','activity-location-test','Activity location test','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('e1100000-0000-4000-8000-000000000001','Activity Location A','activity-location-a','active','e1000000-0000-4000-8000-000000000001'),
 ('e1100000-0000-4000-8000-000000000002','Activity Location B','activity-location-b','active','e1000000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,name,slug,status,institution_type_id) values
 ('e1200000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000001','Activity Location Unit','activity-location-unit','active','e1000000-0000-4000-8000-000000000001');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
 select ('e1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'authenticated','authenticated',
 'activity-location-'||i||'@invalid.test',now(),now(),now(),'{}','{}' from generate_series(1,2) i;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
 select ('e1500000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('e1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,now(),now(),'aal1',now()+interval '1 hour' from generate_series(1,2) i;
insert into app_private.superadmin_internal_identities(id)
 select ('e1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid from generate_series(1,2) i;
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,status)
 select ('e1700000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('e1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('e1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'active' from generate_series(1,2) i;
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,status)
 select ('e1800000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('e1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,r.id,'institution'::app_private.superadmin_internal_scope_kind,
 ('e1100000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'active'
 from generate_series(1,2) i join public.platform_roles r on r.code='owner';
insert into public.activity_locations(id,institution_id,unit_id,name,status,scope_kind,kind,visibility,created_by_internal_identity_id) values
 ('e1900000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000001',null,'Activity Room A','active','institution','internal','team','e1600000-0000-4000-8000-000000000001'),
 ('e1900000-0000-4000-8000-000000000002','e1100000-0000-4000-8000-000000000002',null,'Activity Room B','active','institution','internal','team','e1600000-0000-4000-8000-000000000002');
create function pg_temp.activity_location_actor(i integer) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub','e1400000-0000-4000-8000-'||lpad(i::text,12,'0'),
 'session_id','e1500000-0000-4000-8000-'||lpad(i::text,12,'0'),'aal','aal1','role','authenticated')::text,true);
end $$;
create temporary table activity_location_payload(payload jsonb);
insert into activity_location_payload select jsonb_build_object(
 'institution_id','e1100000-0000-4000-8000-000000000001',
 'definition',jsonb_build_object('name','Activity location draft','taxonomy_id',t.id,'initials','AL'),
 'unit_ids',jsonb_build_array('e1200000-0000-4000-8000-000000000001'),
 'group_ids','[]'::jsonb,'group_participation','{}'::jsonb,'participants','[]'::jsonb,
 'professional_assignments','[]'::jsonb,'group_capability_settings','[]'::jsonb,
 'professional_capability_actions','[]'::jsonb,
 'capability_policies',jsonb_build_object('attendance',null,'chat',null,'happens',null,'moments',null,'now',null))
 from public.activity_taxonomies t where t.status='active' and t.code<>'outros' order by t.id limit 1;
create function pg_temp.activity_location_reservation() returns jsonb language sql immutable as $$
 select '{"first_occurrence":{"starts_at":"2026-09-11T12:00:00Z","ends_at":"2026-09-11T13:00:00Z"},"recurrence":{"kind":"once"},"conflict_justification":null}'::jsonb
$$;
grant execute on function pg_temp.activity_location_reservation() to authenticated;
create temporary table activity_location_results(label text primary key,body jsonb);
grant select on activity_location_payload to authenticated;
grant select,insert on activity_location_results to authenticated;
select pg_temp.activity_location_actor(1);
set local role authenticated;
insert into activity_location_results values('plain',public.superadmin_activity_location_create_v2(
 'ea000000-0000-4000-8000-000000000001','e1900000-0000-4000-8000-000000000001',(select payload from activity_location_payload)));
insert into activity_location_results values('retry',public.superadmin_activity_location_create_v2(
 'ea000000-0000-4000-8000-000000000001','e1900000-0000-4000-8000-000000000001',(select payload from activity_location_payload)));
insert into activity_location_results values('changed',public.superadmin_activity_location_create_v2(
 'ea000000-0000-4000-8000-000000000001','e1900000-0000-4000-8000-000000000001',
 jsonb_set((select payload from activity_location_payload),'{definition,name}','"Changed draft"')));
insert into activity_location_results values('reload',public.superadmin_activity_location_selection_v2(
 (select (body#>>'{data,activity_id}')::uuid from activity_location_results where label='plain')));
reset role;
select is((select body->>'ok' from activity_location_results where label='plain'),'true','catalog-only draft commits');
select is((select body#>>'{data,activity_id}' from activity_location_results where label='retry'),
 (select body#>>'{data,activity_id}' from activity_location_results where label='plain'),'lost-response retry preserves Activity ID');
select is((select body#>>'{data,replayed}' from activity_location_results where label='retry'),'true','retry is identified');
select is((select body#>>'{error,code}' from activity_location_results where label='changed'),'SAI_CONCURRENT_CHANGE','same request with changed payload is rejected');
select is((select body#>>'{data,location,id}' from activity_location_results where label='reload'),'e1900000-0000-4000-8000-000000000001','current selection reloads through authorized reader');
select is((select count(*)::integer from public.location_reservations where location_id='e1900000-0000-4000-8000-000000000001'),0,'informational selection creates no reservation');
set local role authenticated;
insert into activity_location_results values('policy',public.superadmin_location_scheduling_policy_set_v2(
 'e1900000-0000-4000-8000-000000000001','{"policy":"block","expected_version":0}','ea000000-0000-4000-8000-000000000002'));
insert into activity_location_results values('reserved',public.superadmin_activity_location_create_v2(
 'ea000000-0000-4000-8000-000000000003','e1900000-0000-4000-8000-000000000001',
 jsonb_set((select payload from activity_location_payload),'{definition,name}','"Reserved draft"'),pg_temp.activity_location_reservation()));
insert into activity_location_results values('blocked',public.superadmin_activity_location_create_v2(
 'ea000000-0000-4000-8000-000000000004','e1900000-0000-4000-8000-000000000001',
 jsonb_set((select payload from activity_location_payload),'{definition,name}','"Blocked draft"'),pg_temp.activity_location_reservation()));
insert into activity_location_results values('reserved_retry',public.superadmin_activity_location_create_v2(
 'ea000000-0000-4000-8000-000000000003','e1900000-0000-4000-8000-000000000001',
 jsonb_set((select payload from activity_location_payload),'{definition,name}','"Reserved draft"'),pg_temp.activity_location_reservation()));
reset role;
select is((select body->>'ok' from activity_location_results where label='reserved'),'true','reservation and Activity commit together');
select is((select body#>>'{error,code}' from activity_location_results where label='blocked'),'SAI_CONCURRENT_CHANGE','reservation conflict fails outer save');
select is((select count(*)::integer from public.activity_definitions where institution_id='e1100000-0000-4000-8000-000000000001' and name='Blocked draft'),0,'reservation failure rolls back Activity');
select is((select count(*)::integer from app_private.activity_location_create_receipts where request_id='ea000000-0000-4000-8000-000000000004'),0,'failed aggregate has no wrapper receipt');
select is((select count(*)::integer from app_private.superadmin_internal_activity_save_receipts where request_id=app_private.activity_request_uuid(
 'activity-location-save:e1600000-0000-4000-8000-000000000001','ea000000-0000-4000-8000-000000000004')),0,'failed aggregate has no child save receipt');
select is((select body#>>'{data,reservation,id}' from activity_location_results where label='reserved_retry'),
 (select body#>>'{data,reservation,id}' from activity_location_results where label='reserved'),'retry preserves the same reservation ID');
create temporary table activity_location_audit_count as
 select count(*) as value from audit.audit_logs where institution_id='e1100000-0000-4000-8000-000000000001' and outcome='success';
-- Fault injection at the real final audit write, after a reservation succeeded.
create function pg_temp.reject_activity_location_audit() returns trigger language plpgsql as $$
begin
 if new.action_code='activity.location.create' and new.outcome='success' then raise exception 'test final audit failure'; end if;
 return new;
end $$;
create trigger activity_location_test_audit_failure before insert on audit.audit_logs
 for each row execute function pg_temp.reject_activity_location_audit();
set local role authenticated;
insert into activity_location_results values('audit_failure',public.superadmin_activity_location_create_v2(
 'ea000000-0000-4000-8000-000000000005','e1900000-0000-4000-8000-000000000001',
 jsonb_set((select payload from activity_location_payload),'{definition,name}','"Audit failure draft"'),
 jsonb_set(jsonb_set(pg_temp.activity_location_reservation(),'{first_occurrence,starts_at}','"2026-09-11T14:00:00Z"'),'{first_occurrence,ends_at}','"2026-09-11T15:00:00Z"')));
reset role;
drop trigger activity_location_test_audit_failure on audit.audit_logs;
select is((select body->>'ok' from activity_location_results where label='audit_failure'),'false','late audit failure returns no success');
select is((select count(*)::integer from public.activity_definitions where institution_id='e1100000-0000-4000-8000-000000000001' and name='Audit failure draft'),0,'late audit failure rolls back Activity');
select is((select count(*)::integer from public.location_reservations where location_id='e1900000-0000-4000-8000-000000000001'),1,'late audit failure rolls back second reservation');
select is((select count(*)::integer from public.location_bindings where location_id='e1900000-0000-4000-8000-000000000001'),1,'late failure leaves no extra historical binding');
select is((select count(*)::integer from public.location_reservation_occurrences o join public.location_reservations r on r.id=o.reservation_id
 where r.location_id='e1900000-0000-4000-8000-000000000001'),1,'late failure leaves no extra occurrence');
select is((select count(*) from audit.audit_logs where institution_id='e1100000-0000-4000-8000-000000000001' and outcome='success'),
 (select value from activity_location_audit_count),'late failure rolls back child success audits');
select is((select count(*)::integer from app_private.superadmin_internal_activity_command_receipts r
 where r.request_id in(select app_private.activity_request_uuid(kind,app_private.activity_request_uuid(
 'activity-location-save:e1600000-0000-4000-8000-000000000001','ea000000-0000-4000-8000-000000000005'))
 from unnest(array['activity-save-create','activity-save-groups','activity-save-participants','activity-save-professionals','activity-save-permissions']) kind)),0,'late failure rolls back every child command receipt');
select is((select count(*)::integer from app_private.location_reservation_receipts where actor_id='e1600000-0000-4000-8000-000000000001'
 and request_id=app_private.activity_request_uuid('activity-location-reserve:e1600000-0000-4000-8000-000000000001',
 'ea000000-0000-4000-8000-000000000005')),0,'late failure rolls back reservation receipt');
-- A caller can predict derived child IDs and invoke a public leaf command.
-- That earlier Activity must never be adopted as a new atomic wrapper save.
insert into activity_location_results values('external_leaf',public.superadmin_activity_create_v2(
 app_private.activity_request_uuid('activity-save-create',app_private.activity_request_uuid(
 'activity-location-save:e1600000-0000-4000-8000-000000000001','ea000000-0000-4000-8000-000000000006')),
 (jsonb_set((select payload from activity_location_payload),'{definition,name}','"External leaf draft"')->'definition')||
 jsonb_build_object('institution_id','e1100000-0000-4000-8000-000000000001','unit_ids',jsonb_build_array('e1200000-0000-4000-8000-000000000001'))));
set local role authenticated;
insert into activity_location_results values('adoption',public.superadmin_activity_location_create_v2(
 'ea000000-0000-4000-8000-000000000006','e1900000-0000-4000-8000-000000000001',
 jsonb_set((select payload from activity_location_payload),'{definition,name}','"External leaf draft"')));
reset role;
select is((select body->>'ok' from activity_location_results where label='external_leaf'),'true','real external leaf fixture exists');
select is((select body#>>'{error,code}' from activity_location_results where label='adoption'),'SAI_CONCURRENT_CHANGE','wrapper refuses pre-existing leaf receipt');
select is((select count(*)::integer from public.activity_location_selections where activity_id=
 (select (body#>>'{data,activity_id}')::uuid from activity_location_results where label='external_leaf')),0,'external leaf never receives wrapper selection');
select pg_temp.activity_location_actor(2);
set local role authenticated;
insert into activity_location_results values('foreign_read',public.superadmin_activity_location_selection_v2(
 (select (body#>>'{data,activity_id}')::uuid from activity_location_results where label='plain')));
insert into activity_location_results values('foreign_create',public.superadmin_activity_location_create_v2(
 'ea000000-0000-4000-8000-000000000007','e1900000-0000-4000-8000-000000000002',(select payload from activity_location_payload)));
reset role;
select is((select body->>'ok' from activity_location_results where label='foreign_read'),'false','other tenant cannot reload selection');
select is((select body#>>'{error,code}' from activity_location_results where label='foreign_create'),'SAI_PERMISSION_DENIED','activity and selected location cannot cross tenant');
select is((select count(*)::integer from public.activity_location_selections s join public.activity_definitions a on a.id=s.activity_id
 where a.institution_id='e1100000-0000-4000-8000-000000000001'),2,'only two successful selections persist');
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=clock_timestamp(),suspended_at=null,
 changed_by_internal_identity_id='e1600000-0000-4000-8000-000000000002',version=version+1
 where id='e1800000-0000-4000-8000-000000000001';
select pg_temp.activity_location_actor(1);
set local role authenticated;
insert into activity_location_results values('revoked_retry',public.superadmin_activity_location_create_v2(
 'ea000000-0000-4000-8000-000000000001','e1900000-0000-4000-8000-000000000001',(select payload from activity_location_payload)));
reset role;
select is((select body#>>'{error,code}' from activity_location_results where label='revoked_retry'),'SAI_MEMBERSHIP_REVOKED','revoked actor cannot replay committed receipt');
update auth.sessions set not_after=clock_timestamp()-interval '1 second' where id='e1500000-0000-4000-8000-000000000002';
select pg_temp.activity_location_actor(2);
set local role authenticated;
insert into activity_location_results values('expired',public.superadmin_activity_location_selection_v2(
 (select (body#>>'{data,activity_id}')::uuid from activity_location_results where label='plain')));
reset role;
select is((select body#>>'{error,code}' from activity_location_results where label='expired'),'SAI_SESSION_INVALID','expired session is denied before selection lookup');
select * from finish();
rollback;
