-- Candidate only: execution awaits the coordinator's serialized SQL slot.
-- Real auth/owner/consumer helpers, no mock policies or helper replacement.
-- Separate serialized concurrency qualification must still cover expiry and
-- revocation while the final audit append is blocked; not simulated here.
begin;
create extension if not exists pgtap with schema extensions;
select plan(30);

select ok(has_function_privilege('authenticated','public.superadmin_location_consumer_bindings_v2(jsonb,uuid,integer)','EXECUTE'),'authenticated can enter checked reader');
select ok(not has_function_privilege('anon','public.superadmin_location_consumer_bindings_v2(jsonb,uuid,integer)','EXECUTE'),'anon cannot enter reader');
select ok(not has_function_privilege('service_role','public.superadmin_location_consumer_bindings_v2(jsonb,uuid,integer)','EXECUTE'),'service cannot enter reader');
select ok(not has_function_privilege('authenticated','app_private.location_binding_consumer_context_v2(jsonb)','EXECUTE'),'consumer context stays private');
select ok(not has_table_privilege('authenticated','public.location_bindings','SELECT'),'no direct binding read added');

insert into public.institution_types(id,code,name,status) values
 ('d1000000-0000-4000-8000-000000000001','bindings-test-type','Bindings test type','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('d1100000-0000-4000-8000-000000000001','Bindings A','bindings-a','active','d1000000-0000-4000-8000-000000000001'),
 ('d1100000-0000-4000-8000-000000000002','Bindings B','bindings-b','active','d1000000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,name,slug,status,institution_type_id) values
 ('d1200000-0000-4000-8000-000000000001','d1100000-0000-4000-8000-000000000001','Bindings Unit A','bindings-unit-a','active','d1000000-0000-4000-8000-000000000001'),
 ('d1200000-0000-4000-8000-000000000002','d1100000-0000-4000-8000-000000000002','Bindings Unit B','bindings-unit-b','active','d1000000-0000-4000-8000-000000000001');
insert into public.groups(id,institution_id,unit_id,name,status) values
 ('d1300000-0000-4000-8000-000000000001','d1100000-0000-4000-8000-000000000001','d1200000-0000-4000-8000-000000000001','Bindings Group A','active'),
 ('d1300000-0000-4000-8000-000000000002','d1100000-0000-4000-8000-000000000002','d1200000-0000-4000-8000-000000000002','Bindings Group B','active'),
 ('d1300000-0000-4000-8000-000000000003','d1100000-0000-4000-8000-000000000001','d1200000-0000-4000-8000-000000000001','Empty Bindings Group','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
 select ('d1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'authenticated','authenticated',
 'bindings-'||i||'@invalid.test',now(),now(),now(),'{}','{}' from generate_series(1,3) i;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
 select ('d1500000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('d1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,now(),now(),'aal1',now()+interval '1 hour' from generate_series(1,3) i;
insert into app_private.superadmin_internal_identities(id)
 select ('d1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid from generate_series(1,3) i;
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,status)
 select ('d1700000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('d1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('d1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'active' from generate_series(1,3) i;
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,status)
 select ('d1800000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('d1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,r.id,
 (case when i=3 then 'platform' else 'institution' end)::app_private.superadmin_internal_scope_kind,
 case when i=2 then 'd1100000-0000-4000-8000-000000000002'::uuid
   when i=1 then 'd1100000-0000-4000-8000-000000000001'::uuid end,'active'
 from generate_series(1,3) i join public.platform_roles r on r.code=case when i=3 then 'operations' else 'owner' end;
insert into public.activity_locations(id,institution_id,unit_id,name,status,scope_kind,kind,visibility,created_by_internal_identity_id) values
 ('d1900000-0000-4000-8000-000000000001','d1100000-0000-4000-8000-000000000001',null,'Room A','active','institution','internal','team','d1600000-0000-4000-8000-000000000001'),
 ('d1900000-0000-4000-8000-000000000002','d1100000-0000-4000-8000-000000000001','d1200000-0000-4000-8000-000000000001','Room B','inactive','unit','internal','team','d1600000-0000-4000-8000-000000000001'),
 ('d1900000-0000-4000-8000-000000000003','d1100000-0000-4000-8000-000000000002',null,'Tenant B Room','active','institution','internal','team','d1600000-0000-4000-8000-000000000002');
-- Persisted bindings, including one with no active reservation, are history.
insert into public.location_bindings(location_id,consumer_kind,consumer_id,group_id) values
 ('d1900000-0000-4000-8000-000000000001','group','d1300000-0000-4000-8000-000000000001','d1300000-0000-4000-8000-000000000001'),
 ('d1900000-0000-4000-8000-000000000002','group','d1300000-0000-4000-8000-000000000001','d1300000-0000-4000-8000-000000000001');
create function pg_temp.bindings_actor(i integer) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub','d1400000-0000-4000-8000-'||lpad(i::text,12,'0'),
 'session_id','d1500000-0000-4000-8000-'||lpad(i::text,12,'0'),'aal','aal1','role','authenticated')::text,true);
end $$;
create temporary table binding_results(label text primary key,body jsonb);
grant select,insert on binding_results to authenticated;
select pg_temp.bindings_actor(1);
set local role authenticated;
insert into binding_results values
 ('first',public.superadmin_location_consumer_bindings_v2('{"kind":"group","id":"d1300000-0000-4000-8000-000000000001"}',null,1)),
 ('second',public.superadmin_location_consumer_bindings_v2('{"kind":"group","id":"d1300000-0000-4000-8000-000000000001"}','d1900000-0000-4000-8000-000000000001',1)),
 ('empty',public.superadmin_location_consumer_bindings_v2('{"kind":"group","id":"d1300000-0000-4000-8000-000000000003"}')),
 ('foreign_empty',public.superadmin_location_consumer_bindings_v2('{"kind":"group","id":"d1300000-0000-4000-8000-000000000002"}')),
 ('missing',public.superadmin_location_consumer_bindings_v2('{"kind":"group","id":"d1300000-0000-4000-8000-000000000099"}')),
 ('cursor',public.superadmin_location_consumer_bindings_v2('{"kind":"group","id":"d1300000-0000-4000-8000-000000000001"}','d1900000-0000-4000-8000-000000000003')),
 ('shape',public.superadmin_location_consumer_bindings_v2('{"kind":"group","id":"d1300000-0000-4000-8000-000000000001","extra":true}')),
 ('kind',public.superadmin_location_consumer_bindings_v2('{"kind":"event","id":"d1300000-0000-4000-8000-000000000001"}')),
 ('limit',public.superadmin_location_consumer_bindings_v2('{"kind":"group","id":"d1300000-0000-4000-8000-000000000001"}',null,101));
reset role;
select is((select body->>'ok' from binding_results where label='first'),'true','authorized group binding read succeeds');
select is((select jsonb_array_length(body#>'{data,items}') from binding_results where label='first'),1,'limit bounds returned references');
select is((select body#>>'{data,next_location_id}' from binding_results where label='first'),'d1900000-0000-4000-8000-000000000001','cursor is last returned location');
select is((select body#>>'{data,items,0,location,id}' from binding_results where label='second'),'d1900000-0000-4000-8000-000000000002','second page does not repeat first');
select is((select body#>>'{data,items,0,location,status}' from binding_results where label='second'),'inactive','inactive historical binding remains readable');
select ok((select body#>'{data,next_location_id}'='null'::jsonb from binding_results where label='second'),'last page has null cursor');
select is((select body#>'{data,items}' from binding_results where label='empty'),'[]'::jsonb,'authorized empty consumer returns empty');
select is((select body#>>'{error,code}' from binding_results where label='foreign_empty'),'SAI_PERMISSION_DENIED','foreign consumer denied before empty result');
select is((select body#>>'{error,code}' from binding_results where label='missing'),'SAI_PERMISSION_DENIED','missing consumer is indistinguishable from denied');
select is((select body#>>'{error,code}' from binding_results where label='cursor'),'SAI_INVALID_ARGUMENT','cursor must belong to requested consumer');
select is((select body#>>'{error,code}' from binding_results where label='shape'),'SAI_INVALID_ARGUMENT','consumer rejects extra keys');
select is((select body#>>'{error,code}' from binding_results where label='kind'),'SAI_INVALID_ARGUMENT','unsupported consumer rejected');
select is((select body#>>'{error,code}' from binding_results where label='limit'),'SAI_INVALID_ARGUMENT','oversized page rejected');
select is((select count(*)::integer from jsonb_object_keys((select body#>'{data,items,0,location}' from binding_results where label='first'))),7,'reference excludes address media and other consumers');
-- Create the activity through its REAL v2 command, preserving attribution
-- markers/triggers instead of disabling them for a fabricated fixture.
create temporary table binding_activity_payload(payload jsonb);
insert into binding_activity_payload select jsonb_build_object(
 'institution_id','d1100000-0000-4000-8000-000000000001','name','Binding Activity',
 'taxonomy_id',t.id,'initials','BA','unit_ids',jsonb_build_array('d1200000-0000-4000-8000-000000000001'))
 from public.activity_taxonomies t where t.status='active' and t.code<>'outros' order by t.id limit 1;
grant select on binding_activity_payload to authenticated;
-- Fixture owner invokes the command with actor 1's real JWT. The reservation
-- replay contains its implementation, but does not provision Activity RPC ACLs.
insert into binding_results values('activity_create',public.superadmin_activity_create_v2(
 'da000000-0000-4000-8000-000000000001',(select payload from binding_activity_payload)));
set local role authenticated;
insert into binding_results values('activity_empty',public.superadmin_location_consumer_bindings_v2(
 jsonb_build_object('kind','activity','id',(select body#>>'{data,activity_id}' from binding_results where label='activity_create'))));
reset role;
select is((select body->>'ok' from binding_results where label='activity_create'),'true','real activity fixture command succeeds');
select is((select body#>'{data,items}' from binding_results where label='activity_empty'),'[]'::jsonb,'existing activity authorizes before empty result');
insert into public.location_bindings(location_id,consumer_kind,consumer_id,activity_id)
 select l.id,'activity',(r.body#>>'{data,activity_id}')::uuid,(r.body#>>'{data,activity_id}')::uuid
 from public.activity_locations l cross join binding_results r where r.label='activity_create'
   and l.id in('d1900000-0000-4000-8000-000000000001','d1900000-0000-4000-8000-000000000002');
set local role authenticated;
insert into binding_results values('activity_bound',public.superadmin_location_consumer_bindings_v2(
 jsonb_build_object('kind','activity','id',(select body#>>'{data,activity_id}' from binding_results where label='activity_create'))));
reset role;
select is((select jsonb_array_length(body#>'{data,items}') from binding_results where label='activity_bound'),2,'activity resolves institution and currently linked unit bindings');
select is((select body#>>'{data,consumer,id}' from binding_results where label='activity_bound'),
 (select body#>>'{data,activity_id}' from binding_results where label='activity_create'),'response echoes authorized real activity identity');
select pg_temp.bindings_actor(2);
set local role authenticated;
insert into binding_results values('foreign_activity',public.superadmin_location_consumer_bindings_v2(
 jsonb_build_object('kind','activity','id',(select body#>>'{data,activity_id}' from binding_results where label='activity_create'))));
reset role;
select is((select body#>>'{error,code}' from binding_results where label='foreign_activity'),'SAI_PERMISSION_DENIED','other institution cannot read activity bindings');
-- A corrupted historical relation cannot turn binding existence into access.
insert into public.location_bindings(location_id,consumer_kind,consumer_id,activity_id)
 select 'd1900000-0000-4000-8000-000000000003','activity',
 (body#>>'{data,activity_id}')::uuid,(body#>>'{data,activity_id}')::uuid from binding_results where label='activity_create';
select pg_temp.bindings_actor(1);
set local role authenticated;
insert into binding_results values('invalid_binding',public.superadmin_location_consumer_bindings_v2(
 jsonb_build_object('kind','activity','id',(select body#>>'{data,activity_id}' from binding_results where label='activity_create'))));
reset role;
select is((select body#>>'{error,code}' from binding_results where label='invalid_binding'),'SAI_PERMISSION_DENIED','foreign location binding is denied by canonical owner check');
select ok((select body->'data'='null'::jsonb from binding_results where label='invalid_binding'),'denied batch leaks no earlier authorized references');
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=clock_timestamp(),suspended_at=null,
 changed_by_internal_identity_id='d1600000-0000-4000-8000-000000000001',version=version+1
 where id='d1800000-0000-4000-8000-000000000002';
select pg_temp.bindings_actor(2);
set local role authenticated;
insert into binding_results values('revoked',public.superadmin_location_consumer_bindings_v2(
 '{"kind":"group","id":"d1300000-0000-4000-8000-000000000002"}'));
reset role;
select is((select body#>>'{error,code}' from binding_results where label='revoked'),'SAI_MEMBERSHIP_REVOKED','revoked actor cannot read its own empty consumer');
select pg_temp.bindings_actor(3);
set local role authenticated;
insert into binding_results values('nonowner',public.superadmin_location_consumer_bindings_v2('{"kind":"group","id":"d1300000-0000-4000-8000-000000000003"}'));
reset role;
select is((select body->>'ok' from binding_results where label='nonowner'),'false','non Owner cannot obtain even empty result');
select pg_temp.bindings_actor(1);
update auth.sessions set not_after=clock_timestamp()-interval '1 second' where id='d1500000-0000-4000-8000-000000000001';
set local role authenticated;
insert into binding_results values('expired',public.superadmin_location_consumer_bindings_v2('{"kind":"group","id":"d1300000-0000-4000-8000-000000000001"}'));
reset role;
select is((select body->>'ok' from binding_results where label='expired'),'false','expired session receives no references');
select is((select count(*)::integer from public.location_bindings where consumer_id='d1300000-0000-4000-8000-000000000001'),2,'reader does not mutate bindings');
select * from finish();
rollback;
