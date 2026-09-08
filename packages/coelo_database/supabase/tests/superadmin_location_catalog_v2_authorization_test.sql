-- Prepared for SERIALIZED LOCAL REPLAY; no remote execution authority.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
insert into public.institution_types(id,code,name,status) values
  ('81000000-0000-4000-8000-000000000001','location-test-type','Location test type','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
  ('81100000-0000-4000-8000-000000000001','Location Institution A','location-test-a','active','81000000-0000-4000-8000-000000000001'),
  ('81100000-0000-4000-8000-000000000002','Location Institution B','location-test-b','active','81000000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,name,slug,status,institution_type_id) values
  ('81200000-0000-4000-8000-000000000001','81100000-0000-4000-8000-000000000001','Location Unit A','location-unit-a','active','81000000-0000-4000-8000-000000000001'),
  ('81200000-0000-4000-8000-000000000002','81100000-0000-4000-8000-000000000002','Location Unit B','location-unit-b','active','81000000-0000-4000-8000-000000000001');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
  select ('81300000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'authenticated','authenticated',
    'location-'||i::text||'@invalid.test',now(),now(),now(),'{}','{}' from generate_series(1,4) i;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
  select ('81400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('81300000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,now(),now(),'aal1',now()+interval '1 hour'
    from generate_series(1,4) i;
insert into app_private.superadmin_internal_identities(id)
  select ('81500000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid from generate_series(1,3) i;
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,status)
  select ('81600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('81500000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('81300000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'active' from generate_series(1,3) i;
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,status)
  select ('81700000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('81500000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,r.id,
    (case when i=1 then 'institution' else 'platform' end)::app_private.superadmin_internal_scope_kind,
    case when i=1 then '81100000-0000-4000-8000-000000000001'::uuid else null end,'active'
  from generate_series(1,3) i join public.platform_roles r on r.code=case when i=3 then 'operations' else 'owner' end;

create function pg_temp.location_actor(i integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub','81300000-0000-4000-8000-'||lpad(i::text,12,'0'),
    'session_id','81400000-0000-4000-8000-'||lpad(i::text,12,'0'),
    'aal','aal1','role','authenticated')::text,true);
end
$$;
create temporary table location_test_payload(value jsonb);
insert into location_test_payload values(jsonb_build_object(
  'scope_kind','institution','institution_id','81100000-0000-4000-8000-000000000001',
  'unit_id',null,'name','Sala Azul','description',null,'kind','internal',
  'floor',null,'address',null,'visibility','guardians'));
create temporary table location_test_responses(seq integer primary key,body jsonb);
grant select on location_test_payload to authenticated;
grant select,insert on location_test_responses to authenticated;

select pg_temp.location_actor(1);
set local role authenticated;
insert into location_test_responses select 1,public.superadmin_location_create_v2(value,
  '81800000-0000-4000-8000-000000000001') from location_test_payload;
insert into location_test_responses select 2,public.superadmin_location_create_v2(value,
  '81800000-0000-4000-8000-000000000001') from location_test_payload;
insert into location_test_responses select 3,public.superadmin_location_create_v2(
  value||'{"name":"Other name"}','81800000-0000-4000-8000-000000000001') from location_test_payload;
insert into location_test_responses select 4,public.superadmin_location_create_v2(
  value||'{"name":"sala azul"}','81800000-0000-4000-8000-000000000004') from location_test_payload;
insert into location_test_responses select 5,public.superadmin_location_create_v2(
  value||'{"scope_kind":"unit","unit_id":"81200000-0000-4000-8000-000000000001"}',
  '81800000-0000-4000-8000-000000000005') from location_test_payload;
insert into location_test_responses select 6,public.superadmin_location_create_v2(
  value||'{"scope_kind":"unit","unit_id":"81200000-0000-4000-8000-000000000002"}',
  '81800000-0000-4000-8000-000000000006') from location_test_payload;
insert into location_test_responses values(7,public.superadmin_location_directory_v2('institution',
  '81100000-0000-4000-8000-000000000001',null,null,24,0));
reset role;
select is((select body->>'ok' from location_test_responses where seq=1),'true','Owner A creates at AAL1');
select is((select body#>>'{data,id}' from location_test_responses where seq=2),
  (select body#>>'{data,id}' from location_test_responses where seq=1),'identical replay preserves id');
select is((select body#>>'{error,code}' from location_test_responses where seq=3),
  'SAI_CONCURRENT_CHANGE','divergent replay is a conflict');
select is((select body#>>'{error,code}' from location_test_responses where seq=4),
  'SAI_CONCURRENT_CHANGE','case-insensitive duplicate owner name conflicts');
select is((select body->>'ok' from location_test_responses where seq=5),'true','same name in unit owner is independent');
select is((select body#>>'{error,code}' from location_test_responses where seq=6),
  'SAI_PERMISSION_DENIED','cross-institution unit is denied');
select is((select body#>>'{data,total_count}' from location_test_responses where seq=7),'1',
  'institution directory excludes unit-owned locations');
select ok(not exists(select 1 from public.activity_locations where created_by_person_id is not null),
  'no synthetic people authors');
select is((select count(*) from app_private.superadmin_location_create_receipts),2::bigint,
  'only two authorized creations have receipts');

-- Move the referenced fixture as a privileged setup step: replay must reauthorize REAL owner.
update public.activity_locations set institution_id='81100000-0000-4000-8000-000000000002'
  where id=(select (body#>>'{data,id}')::uuid from location_test_responses where seq=1);
select pg_temp.location_actor(1);
set local role authenticated;
insert into location_test_responses select 8,public.superadmin_location_create_v2(value,
  '81800000-0000-4000-8000-000000000001') from location_test_payload;
insert into location_test_responses select 9,public.superadmin_location_detail_v2((body#>>'{data,id}')::uuid)
  from location_test_responses where seq=1;
insert into location_test_responses values(10,public.superadmin_location_detail_v2('81900000-0000-4000-8000-000000000001'));
reset role;
select is((select body#>>'{error,code}' from location_test_responses where seq=8),
  'SAI_PERMISSION_DENIED','receipt cannot disclose relocated resource');
select is((select body#>>'{error,code}' from location_test_responses where seq=9),
  (select body#>>'{error,code}' from location_test_responses where seq=10),
  'cross-scope and nonexistent ids are indistinguishable');
update public.activity_locations set institution_id='81100000-0000-4000-8000-000000000001'
  where id=(select (body#>>'{data,id}')::uuid from location_test_responses where seq=1);

-- A platform Owner may still access a relocated receipt, with the CURRENT tenant audited.
select pg_temp.location_actor(2);
set local role authenticated;
insert into location_test_responses select 16,public.superadmin_location_create_v2(
  value||'{"name":"Platform room"}','81800000-0000-4000-8000-000000000016') from location_test_payload;
reset role;
update public.activity_locations set institution_id='81100000-0000-4000-8000-000000000002'
  where id=(select (body#>>'{data,id}')::uuid from location_test_responses where seq=16);
set local role authenticated;
insert into location_test_responses select 17,public.superadmin_location_create_v2(
  value||'{"name":"Platform room"}','81800000-0000-4000-8000-000000000016') from location_test_payload;
reset role;
select is((select body#>>'{data,institution_id}' from location_test_responses where seq=17),
  '81100000-0000-4000-8000-000000000002','platform Owner replay projects current owner');
select ok(exists(select 1 from audit.audit_logs where action_code='location.create'
  and outcome='success' and institution_id='81100000-0000-4000-8000-000000000002'
  and object_id=(select (body#>>'{data,id}')::uuid from location_test_responses where seq=16)),
  'platform Owner replay audit identifies current tenant');

select pg_temp.location_actor(3);
set local role authenticated;
insert into location_test_responses select 11,public.superadmin_location_create_v2(value,
  '81800000-0000-4000-8000-000000000011') from location_test_payload;
reset role;
select is((select body#>>'{error,code}' from location_test_responses where seq=11),
  'SAI_PERMISSION_DENIED','non-Owner cannot manage even when audience is guardians');
select pg_temp.location_actor(4);
set local role authenticated;
insert into location_test_responses select 12,public.superadmin_location_detail_v2((body#>>'{data,id}')::uuid)
  from location_test_responses where seq=1;
reset role;
select is((select body#>>'{error,code}' from location_test_responses where seq=12),
  'SAI_INTERNAL_CONTEXT_DENIED','valid external session does not become internal actor');

-- Revocation is evaluated again even for an already successful receipt.
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now(),suspended_at=null
  where id='81700000-0000-4000-8000-000000000001';
select pg_temp.location_actor(1);
set local role authenticated;
insert into location_test_responses select 14,public.superadmin_location_create_v2(value,
  '81800000-0000-4000-8000-000000000001') from location_test_payload;
reset role;
select is((select body#>>'{error,code}' from location_test_responses where seq=14),
  'SAI_MEMBERSHIP_REVOKED','revoked membership cannot replay receipt');
update app_private.superadmin_internal_memberships set status='active',revoked_at=null,suspended_at=null
  where id='81700000-0000-4000-8000-000000000001';
update public.platform_role_permissions set status='inactive',revoked_at=now()
  where role_id=(select id from public.platform_roles where code='owner')
    and permission_id=(select id from public.platform_permissions where code='locations.create');
set local role authenticated;
insert into location_test_responses select 15,public.superadmin_location_create_v2(value,
  '81800000-0000-4000-8000-000000000001') from location_test_payload;
reset role;
select is((select body#>>'{error,code}' from location_test_responses where seq=15),
  'SAI_PERMISSION_DENIED','removed effective capability cannot replay receipt');
update public.platform_role_permissions set status='active',revoked_at=null
  where role_id=(select id from public.platform_roles where code='owner')
    and permission_id=(select id from public.platform_permissions where code='locations.create');

create temporary table location_audit_rollback_snapshot as select
  (select count(*) from public.activity_locations) as locations,
  (select count(*) from app_private.superadmin_location_create_receipts) as receipts;
create function pg_temp.fail_location_audit() returns trigger language plpgsql as $$
begin raise exception using message='forced location audit failure'; end $$;
create trigger fail_location_audit before insert on audit.audit_logs
  for each row when(new.action_code='location.create') execute function pg_temp.fail_location_audit();
select pg_temp.location_actor(1);
set local role authenticated;
do $capture_audit_failure$
declare captured_message text; captured_state text; captured_result jsonb;
begin
  begin
    select public.superadmin_location_create_v2(
      value||'{"name":"Audit rollback"}','81800000-0000-4000-8000-000000000013')
      into captured_result from pg_temp.location_test_payload;
  exception when others then
    get stacked diagnostics captured_message=message_text,captured_state=returned_sqlstate;
    captured_result:=jsonb_build_object('sqlstate',captured_state,'message',captured_message);
  end;
  insert into pg_temp.location_test_responses values(18,captured_result);
end
$capture_audit_failure$;
reset role;
select is((select (body->>'sqlstate')||':'||(body->>'message') from location_test_responses where seq=18),
  'P0001:forced location audit failure','audit failure aborts creation');
drop trigger fail_location_audit on audit.audit_logs;
select ok((select locations=(select count(*) from public.activity_locations)
  and receipts=(select count(*) from app_private.superadmin_location_create_receipts)
  from location_audit_rollback_snapshot),'audit failure rolls back location and receipt');
select ok(not exists(select 1 from audit.audit_logs where action_code like 'location.%'
  and (before_json is not null or after_json is not null or not app_private.audit_verify_entry(id))),
  'location audit is minimized and verifies');

select * from finish();
rollback;
