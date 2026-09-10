-- LOCAL candidate; TAP U. No SQL executed. Requires nominal LocationReservationsV1 successor.
-- Two-session late revocation/expiry during a final audit lock requires coordinator qualification.
begin;
create extension if not exists pgtap with schema extensions;
select plan(46);
select ok(has_function_privilege('authenticated','public.superadmin_group_location_create_v2(uuid,uuid,jsonb,jsonb)','EXECUTE'),'authenticated checked entry');
select ok(not has_function_privilege('anon','public.superadmin_group_location_create_v2(uuid,uuid,jsonb,jsonb)','EXECUTE'),'anonymous denied');
select ok(not has_function_privilege('service_role','public.superadmin_group_location_create_v2(uuid,uuid,jsonb,jsonb)','EXECUTE'),'service denied');
select ok(not has_table_privilege('authenticated','public.group_location_selections','SELECT,INSERT,UPDATE,DELETE'),'selection grants closed');
select ok(not has_table_privilege('authenticated','app_private.group_location_create_receipts','SELECT,INSERT,UPDATE,DELETE'),'receipts private');
insert into public.institution_types(id,code,name,status) values
 ('e1000000-0000-4000-8000-000000000001','group-location-test','Activity location test','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('e1100000-0000-4000-8000-000000000001','Group Location A','group-location-a','active','e1000000-0000-4000-8000-000000000001'),
 ('e1100000-0000-4000-8000-000000000002','Group Location B','group-location-b','active','e1000000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,name,slug,status,institution_type_id) values
 ('e1200000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000001','Group Location Unit','group-location-unit','active','e1000000-0000-4000-8000-000000000001');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
 select ('e1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'authenticated','authenticated',
 'group-location-'||i||'@invalid.test',now(),now(),now(),'{}','{}' from generate_series(1,3) i;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
 select ('e1500000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('e1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,now(),now(),'aal1',now()+interval '1 hour' from generate_series(1,3) i;
insert into app_private.superadmin_internal_identities(id)
 select ('e1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid from generate_series(1,3) i;
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,status)
 select ('e1700000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('e1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('e1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'active' from generate_series(1,3) i;
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,status)
 select ('e1800000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('e1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,r.id,'institution'::app_private.superadmin_internal_scope_kind,
 ('e1100000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'active'
 from generate_series(1,2) i join public.platform_roles r on r.code='owner';
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,status)
 select 'e1800000-0000-4000-8000-000000000003','e1600000-0000-4000-8000-000000000003',r.id,
 'institution'::app_private.superadmin_internal_scope_kind,'e1100000-0000-4000-8000-000000000001','active'
 from public.platform_roles r where r.code='auditor' and r.status='active';
insert into public.activity_locations(id,institution_id,unit_id,name,status,scope_kind,kind,visibility,created_by_internal_identity_id) values
 ('e1900000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000001',null,'Group Room A','active','institution','internal','team','e1600000-0000-4000-8000-000000000001'),
 ('e1900000-0000-4000-8000-000000000002','e1100000-0000-4000-8000-000000000002',null,'Group Room B','active','institution','internal','team','e1600000-0000-4000-8000-000000000002');
create function pg_temp.group_location_actor(i integer) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub','e1400000-0000-4000-8000-'||lpad(i::text,12,'0'),
 'session_id','e1500000-0000-4000-8000-'||lpad(i::text,12,'0'),'aal','aal1','role','authenticated')::text,true);
end $$;

create function pg_temp.group_payload(p_name text default 'Group draft') returns jsonb language sql immutable as $$
 select jsonb_build_object('institution_id','e1100000-0000-4000-8000-000000000001',
 'unit_id','e1200000-0000-4000-8000-000000000001','name',p_name,'group_type','class','group_type_other_text',null)
$$;
create function pg_temp.group_reservation(p_hour integer default 12) returns jsonb language sql immutable as $$
 select jsonb_build_object('first_occurrence',jsonb_build_object(
 'starts_at',format('2026-09-11T%s:00:00Z',p_hour),'ends_at',format('2026-09-11T%s:00:00Z',p_hour+1)),
 'recurrence',jsonb_build_object('kind','once'),'conflict_justification',null)
$$;
create temporary table group_location_results(label text primary key,body jsonb);
grant select,insert on group_location_results to authenticated;
grant execute on function pg_temp.group_payload(text),pg_temp.group_reservation(integer) to authenticated;
select ok(exists(select 1 from app_private.superadmin_internal_memberships m join public.platform_roles r on r.id=m.platform_role_id
 where m.id='e1800000-0000-4000-8000-000000000003' and r.code='auditor') and not exists(
 select 1 from public.platform_role_permissions rp join public.platform_roles r on r.id=rp.role_id
 join public.platform_permissions p on p.id=rp.permission_id where r.code='auditor' and p.code='groups.manage'
 and rp.effect='allow' and rp.status='active' and rp.revoked_at is null),'auditor fixture exists without groups.manage grant');
select pg_temp.group_location_actor(2);
set local role authenticated;
insert into group_location_results values('foreign_create',public.superadmin_group_location_create_v2(
 'ea000000-0000-4000-8000-000000000012','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload('Foreign create')));
reset role;
select is((select body#>>'{error,code}' from group_location_results where label='foreign_create'),'SAI_PERMISSION_DENIED','tenant B cannot create payload A at location A');
select is((select count(*)::integer from public.groups where name='Foreign create' and institution_id='e1100000-0000-4000-8000-000000000001'),0,'foreign create inserts no Group');
select pg_temp.group_location_actor(3);
set local role authenticated;
insert into group_location_results values('no_manage',public.superadmin_group_location_create_v2(
 'ea000000-0000-4000-8000-000000000013','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload('No manage')));
reset role;
select is((select body#>>'{error,code}' from group_location_results where label='no_manage'),'SAI_PERMISSION_DENIED','actor without groups.manage cannot create');
select is((select count(*)::integer from public.groups where name='No manage' and institution_id='e1100000-0000-4000-8000-000000000001'),0,'missing capability inserts no Group');
select pg_temp.group_location_actor(1);
set local role authenticated;
insert into group_location_results values('injected_consumer',public.superadmin_group_location_create_v2(
 'ea000000-0000-4000-8000-000000000014','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload('Injected consumer'),
 pg_temp.group_reservation()||'{"consumer":{"kind":"group","id":"eb000000-0000-4000-8000-000000000001"}}'::jsonb));
reset role;
select is((select body#>>'{error,code}' from group_location_results where label='injected_consumer'),'SAI_INVALID_ARGUMENT','reservation accepts exactly three keys without injected consumer');
select is((select count(*)::integer from app_private.group_location_create_receipts where request_id in(
 'ea000000-0000-4000-8000-000000000012','ea000000-0000-4000-8000-000000000013','ea000000-0000-4000-8000-000000000014')),0,'all early denials leave no receipt');
select pg_temp.group_location_actor(1);
set local role authenticated;
insert into group_location_results values
 ('plain',public.superadmin_group_location_create_v2('ea000000-0000-4000-8000-000000000001','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload())),
 ('retry',public.superadmin_group_location_create_v2('ea000000-0000-4000-8000-000000000001','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload())),
 ('changed',public.superadmin_group_location_create_v2('ea000000-0000-4000-8000-000000000001','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload('Changed'))),
 ('extra',public.superadmin_group_location_create_v2('ea000000-0000-4000-8000-000000000010','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload()||'{"status":"active"}'::jsonb)),
 ('other',public.superadmin_group_location_create_v2('ea000000-0000-4000-8000-000000000011','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload()||'{"group_type":"other"}'::jsonb));
insert into group_location_results values('read',public.superadmin_group_location_selection_v2((select (body#>>'{data,group_id}')::uuid from group_location_results where label='plain')));
reset role;
select is((select body->>'ok' from group_location_results where label='plain'),'true','draft created');
select ok((select status='draft' and inherit_appearance and inherit_access and inherit_activities and management_version=1 from public.groups where id=(select (body#>>'{data,group_id}')::uuid from group_location_results where label='plain')),'draft and inherited defaults persisted');
select is((select body#>>'{data,group_id}' from group_location_results where label='retry'),(select body#>>'{data,group_id}' from group_location_results where label='plain'),'retry retains server Group ID');
select is((select body#>>'{data,replayed}' from group_location_results where label='retry'),'true','retry identified');
select is((select body#>>'{error,code}' from group_location_results where label='changed'),'SAI_CONCURRENT_CHANGE','changed payload rejects replay');
select is((select body#>>'{error,code}' from group_location_results where label='extra'),'SAI_INVALID_ARGUMENT','caller cannot publish or customize hidden fields');
select is((select body#>>'{error,code}' from group_location_results where label='other'),'SAI_INVALID_ARGUMENT','other requires complement');
select is((select body#>>'{data,location,id}' from group_location_results where label='read'),'e1900000-0000-4000-8000-000000000001','authorized current selection');
select is((select count(*)::integer from public.location_reservations where location_id='e1900000-0000-4000-8000-000000000001'),0,'catalog reference alone is not reservation');
set local role authenticated;
insert into group_location_results values('policy',public.superadmin_location_scheduling_policy_set_v2('e1900000-0000-4000-8000-000000000001','{"policy":"block","expected_version":0}','ea000000-0000-4000-8000-000000000002'));
insert into group_location_results values
 ('reserved',public.superadmin_group_location_create_v2('ea000000-0000-4000-8000-000000000003','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload('Reserved'),pg_temp.group_reservation())),
 ('blocked',public.superadmin_group_location_create_v2('ea000000-0000-4000-8000-000000000004','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload('Blocked'),pg_temp.group_reservation()));
insert into group_location_results values('reserved_retry',public.superadmin_group_location_create_v2('ea000000-0000-4000-8000-000000000003','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload('Reserved'),pg_temp.group_reservation()));
reset role;
select is((select body#>>'{data,reservation,id}' from group_location_results where label='reserved_retry'),(select body#>>'{data,reservation,id}' from group_location_results where label='reserved'),'reservation retry preserves the same child ID');
select is((select body->>'ok' from group_location_results where label='reserved'),'true','Group and reservation commit together');
select is((select body#>>'{data,reservation,consumer,id}' from group_location_results where label='reserved'),(select body#>>'{data,group_id}' from group_location_results where label='reserved'),'reservation consumer is newly created Group');
select is((select body#>>'{error,code}' from group_location_results where label='blocked'),'SAI_CONCURRENT_CHANGE','real overlap aborts aggregate');
select is((select count(*)::integer from public.groups where name='Blocked' and institution_id='e1100000-0000-4000-8000-000000000001'),0,'conflict rolls back Group');
select is((select count(*)::integer from app_private.group_location_create_receipts where request_id='ea000000-0000-4000-8000-000000000004'),0,'conflict rolls back receipt');
create temporary table group_audit_count as select count(*) value from audit.audit_logs where institution_id='e1100000-0000-4000-8000-000000000001' and outcome='success';
create function pg_temp.reject_group_audit() returns trigger language plpgsql as $$
begin
 if new.action_code='group.location.create' and new.outcome='success' then raise exception 'test final audit failure'; end if;
 return new;
end $$;
create trigger group_location_test_audit_failure before insert on audit.audit_logs for each row execute function pg_temp.reject_group_audit();
set local role authenticated;
insert into group_location_results values('audit_failure',public.superadmin_group_location_create_v2('ea000000-0000-4000-8000-000000000005','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload('Audit failure'),pg_temp.group_reservation(14)));
reset role;
drop trigger group_location_test_audit_failure on audit.audit_logs;
select is((select body->>'ok' from group_location_results where label='audit_failure'),'false','audit failure aborts response');
select is((select count(*)::integer from public.groups where name='Audit failure' and institution_id='e1100000-0000-4000-8000-000000000001'),0,'late failure rolls back Group');
select is((select count(*)::integer from public.group_location_selections where location_id='e1900000-0000-4000-8000-000000000001'),2,'late failure rolls back selection');
select is((select count(*)::integer from public.location_bindings where location_id='e1900000-0000-4000-8000-000000000001'),1,'late failure rolls back historic binding');
select is((select count(*)::integer from app_private.location_reservation_receipts where actor_id='e1600000-0000-4000-8000-000000000001' and request_id=app_private.group_location_reservation_request_v2('e1600000-0000-4000-8000-000000000001','ea000000-0000-4000-8000-000000000005')),0,'late failure rolls back child receipt');
select is((select count(*) from audit.audit_logs where institution_id='e1100000-0000-4000-8000-000000000001' and outcome='success'),(select value from group_audit_count),'late failure rolls back success audits');
insert into public.groups(id,institution_id,unit_id,name,group_type,status) values('eb000000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000001','e1200000-0000-4000-8000-000000000001','No selection','class','draft');
select pg_temp.group_location_actor(2);
set local role authenticated;
insert into group_location_results values('foreign_empty',public.superadmin_group_location_selection_v2('eb000000-0000-4000-8000-000000000001'));
reset role;
select is((select body#>>'{error,code}' from group_location_results where label='foreign_empty'),'SAI_PERMISSION_DENIED','owner authorization precedes empty result');
select pg_temp.group_location_actor(1);
set local role authenticated;
insert into group_location_results values('empty',public.superadmin_group_location_selection_v2('eb000000-0000-4000-8000-000000000001'));
reset role;
select ok((select body->>'ok'='true' and body#>'{data,location}'='null'::jsonb from group_location_results where label='empty'),'authorized consumer can have no selection');
-- Causal late-session failure at the actual final audit, without replacing authorization helpers.
create function pg_temp.expire_group_at_audit() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.action_code='group.location.create' and new.outcome='success' then
   update auth.sessions set not_after=clock_timestamp()-interval '1 second' where id='e1500000-0000-4000-8000-000000000001';
 end if;
 return new;
end $$;
create trigger group_location_test_expiry after insert on audit.audit_logs for each row execute function pg_temp.expire_group_at_audit();
set local role authenticated;
insert into group_location_results values('late_expiry',public.superadmin_group_location_create_v2('ea000000-0000-4000-8000-000000000007','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload('Late expiry'),pg_temp.group_reservation(16)));
reset role;
drop trigger group_location_test_expiry on audit.audit_logs;
select is((select body#>>'{error,code}' from group_location_results where label='late_expiry'),'SAI_SESSION_INVALID','expiry after successful motor rolls back outer transaction');
select is((select count(*)::integer from public.groups where name='Late expiry' and institution_id='e1100000-0000-4000-8000-000000000001'),0,'late expiry removes new Group');
select ok((select not_after>clock_timestamp() from auth.sessions where id='e1500000-0000-4000-8000-000000000001'),'test expiry mutation also rolled back');
insert into public.units(id,institution_id,name,slug,status,institution_type_id) values
 ('e1200000-0000-4000-8000-000000000002','e1100000-0000-4000-8000-000000000001','Second unit','group-second-unit','active','e1000000-0000-4000-8000-000000000001');
insert into public.activity_locations(id,institution_id,unit_id,name,status,scope_kind,kind,visibility,created_by_internal_identity_id) values
 ('e1900000-0000-4000-8000-000000000003','e1100000-0000-4000-8000-000000000001','e1200000-0000-4000-8000-000000000001','Unit room','active','unit','internal','team','e1600000-0000-4000-8000-000000000001');
set local role authenticated;
insert into group_location_results values
 ('unit_ok',public.superadmin_group_location_create_v2('ea000000-0000-4000-8000-000000000008','e1900000-0000-4000-8000-000000000003',pg_temp.group_payload('Unit room Group'))),
 ('unit_cross',public.superadmin_group_location_create_v2('ea000000-0000-4000-8000-000000000009','e1900000-0000-4000-8000-000000000003',pg_temp.group_payload()||'{"unit_id":"e1200000-0000-4000-8000-000000000002"}'::jsonb));
reset role;
select is((select body->>'ok' from group_location_results where label='unit_ok'),'true','Group can select its real unit catalog');
select is((select body#>>'{error,code}' from group_location_results where label='unit_cross'),'SAI_PERMISSION_DENIED','another unit cannot adopt unit catalog');
select is((select count(*)::integer from app_private.group_location_create_receipts where request_id='ea000000-0000-4000-8000-000000000005'),0,'audit failure removes outer receipt');
select is((select count(*)::integer from public.location_reservations where location_id='e1900000-0000-4000-8000-000000000001'),1,'all late failures remove reservations');
select is((select count(*)::integer from public.location_reservation_occurrences o join public.location_reservations r on r.id=o.reservation_id where r.location_id='e1900000-0000-4000-8000-000000000001'),1,'all late failures remove occurrences');
update public.units set status='inactive' where id='e1200000-0000-4000-8000-000000000001';
set local role authenticated;
insert into group_location_results values('inactive',public.superadmin_group_location_create_v2('ea000000-0000-4000-8000-000000000006','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload('Inactive unit')));
reset role;
select is((select body->>'ok' from group_location_results where label='inactive'),'false','inactive unit cannot create');
update public.units set status='active' where id='e1200000-0000-4000-8000-000000000001';
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=clock_timestamp(),suspended_at=null,
 changed_by_internal_identity_id='e1600000-0000-4000-8000-000000000002',version=version+1
 where id='e1800000-0000-4000-8000-000000000001';
set local role authenticated;
insert into group_location_results values('revoked_retry',public.superadmin_group_location_create_v2('ea000000-0000-4000-8000-000000000001','e1900000-0000-4000-8000-000000000001',pg_temp.group_payload()));
reset role;
select is((select body#>>'{error,code}' from group_location_results where label='revoked_retry'),'SAI_MEMBERSHIP_REVOKED','revoked actor cannot replay receipt');
select pg_temp.group_location_actor(2);
update auth.sessions set not_after=clock_timestamp()-interval '1 second' where id='e1500000-0000-4000-8000-000000000002';
set local role authenticated;
insert into group_location_results values('expired',public.superadmin_group_location_selection_v2('eb000000-0000-4000-8000-000000000001'));
reset role;
select is((select body#>>'{error,code}' from group_location_results where label='expired'),'SAI_SESSION_INVALID','wall clock expiry denied');
select * from finish();
rollback;
