-- Candidate for isolated serialized Eng1 replay only. NOT EXECUTED.
begin;
set local search_path = extensions, public, pg_catalog;
select extensions.no_plan();

insert into public.institution_types(id,code,name,status) values
 ('a1000000-0000-4000-8000-000000000001','child-read-fixture','Child read fixture','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('a1100000-0000-4000-8000-000000000001','Child fixture A','child-read-a','active','a1000000-0000-4000-8000-000000000001'),
 ('a1100000-0000-4000-8000-000000000002','Child fixture B','child-read-b','active','a1000000-0000-4000-8000-000000000001');
insert into public.people(id,person_type,first_name,last_name,display_name) values
 ('a1200000-0000-4000-8000-000000000001','child','Synthetic','One','ALFA'),
 ('a1200000-0000-4000-8000-000000000002','child','Synthetic','Two','alfa'),
 ('a1200000-0000-4000-8000-000000000003','child','Synthetic','Three','Zulu'),
 ('a1200000-0000-4000-8000-000000000004','child','Synthetic','Inactive','Hidden inactive'),
 ('a1200000-0000-4000-8000-000000000005','child','Synthetic','Deleted','Hidden deleted');
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 ('a1300000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000001','active'),
 ('a1300000-0000-4000-8000-000000000002','a1200000-0000-4000-8000-000000000002','a1100000-0000-4000-8000-000000000001','active'),
 ('a1300000-0000-4000-8000-000000000003','a1200000-0000-4000-8000-000000000003','a1100000-0000-4000-8000-000000000001','active'),
 ('a1300000-0000-4000-8000-000000000004','a1200000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000002','active'),
 ('a1300000-0000-4000-8000-000000000005','a1200000-0000-4000-8000-000000000004','a1100000-0000-4000-8000-000000000001','inactive'),
 ('a1300000-0000-4000-8000-000000000006','a1200000-0000-4000-8000-000000000005','a1100000-0000-4000-8000-000000000001','active');
update public.people set deleted_at=now() where id='a1200000-0000-4000-8000-000000000005';

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
 select ('a1400000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated',
 'child-read-'||n||'@invalid.test',now(),now(),now(),'{}','{}' from generate_series(1,3) n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
 select ('a1500000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('a1400000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,now(),now(),'aal1',now()+interval '1 hour'
 from generate_series(1,3) n;
insert into app_private.superadmin_internal_identities(id)
 select ('a1600000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,3) n;
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,status)
 select ('a1700000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('a1600000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('a1400000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'active' from generate_series(1,3) n;
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,status)
 select ('a1800000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('a1600000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,r.id,
 (case when n=1 then 'institution' else 'platform' end)::app_private.superadmin_internal_scope_kind,
 case when n=1 then 'a1100000-0000-4000-8000-000000000001'::uuid else null end,'active'
 from generate_series(1,3) n join public.platform_roles r on r.code=case when n=3 then 'operations' else 'owner' end;

create function pg_temp.child_actor(n integer) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub','a1400000-0000-4000-8000-'||lpad(n::text,12,'0'),
 'session_id','a1500000-0000-4000-8000-'||lpad(n::text,12,'0'),'aal','aal1','role','authenticated')::text,true);
end $$;
create temporary table child_results(seq integer primary key,body jsonb);
grant select,insert on child_results to authenticated;

select pg_temp.child_actor(1);
set local role authenticated;
insert into child_results values (1,public.superadmin_child_context_directory_v2(null,null,null,2));
insert into child_results select 2,public.superadmin_child_context_directory_v2(null,
 body#>>'{data,next_cursor,name}',(body#>>'{data,next_cursor,context_id}')::uuid,2) from child_results where seq=1;
insert into child_results values (3,public.superadmin_child_context_directory_v2('a1100000-0000-4000-8000-000000000002'));
insert into child_results values (4,public.superadmin_child_context_directory_v2('a1100000-0000-4000-8000-000000000099'));
insert into child_results values (5,public.superadmin_child_context_directory_v2(null,'alfa',null,20));
insert into child_results values (6,public.superadmin_child_context_directory_v2(null,null,null,0));
insert into child_results values (7,public.superadmin_child_context_directory_v2(null,repeat('a',8193),'a1300000-0000-4000-8000-000000000001',20));
insert into child_results values (8,public.superadmin_child_context_directory_v2(null,'alfa','a1300000-0000-4000-8000-000000000004',20));
reset role;
select extensions.is((select body->>'ok' from child_results where seq=1),'true','institution Owner AAL1 succeeds');
select extensions.is((select jsonb_array_length(body#>'{data,items}') from child_results where seq=1),2,'first page bounded');
select extensions.is((select body#>>'{data,items,0,context_id}' from child_results where seq=1),'a1300000-0000-4000-8000-000000000001','case folded tie uses UUID');
select extensions.is((select body#>>'{data,next_cursor,context_id}' from child_results where seq=1),'a1300000-0000-4000-8000-000000000002','cursor is last RETURNED, not excess');
select extensions.is((select body#>>'{data,next_cursor,name}' from child_results where seq=1),'alfa','server lower key');
select extensions.is((select body#>>'{data,items,0,context_id}' from child_results where seq=2),'a1300000-0000-4000-8000-000000000003','second page strict greater');
select extensions.is((select body#>'{data,next_cursor}' from child_results where seq=2),'null'::jsonb,'last page has no cursor');
select extensions.is((select body#>>'{error,code}' from child_results where seq=3),'SAI_PERMISSION_DENIED','cross tenant rejected');
select extensions.is((select body#>>'{error,code}' from child_results where seq=4),(select body#>>'{error,code}' from child_results where seq=3),'foreign and unknown tenant indistinguishable');
select extensions.is((select count(*) from child_results where seq in(5,6,7) and body#>>'{error,code}'='SAI_INVALID_ARGUMENT'),3::bigint,'invalid pair, limit and byte budget rejected');
select extensions.is((select body#>>'{data,items,0,institution_id}' from child_results where seq=8),'a1100000-0000-4000-8000-000000000001','forged cursor only positions authorized set');
select extensions.ok(not exists(select 1 from child_results r cross join lateral jsonb_array_elements(r.body#>'{data,items}') item
 where (select array_agg(key order by key) from jsonb_object_keys(item) key)
 is distinct from array['context_id','institution_id','institution_name','person_id','person_name']::text[]),'exact five fields');

select pg_temp.child_actor(2);
set local role authenticated;
insert into child_results values (9,public.superadmin_child_context_directory_v2());
insert into child_results values (10,public.superadmin_child_context_directory_v2('a1100000-0000-4000-8000-000000000002'));
reset role;
select extensions.is((select jsonb_array_length(body#>'{data,items}') from child_results where seq=9),4,'platform lists eligible contexts including unallocated child');
select extensions.is((select count(*) from child_results r cross join lateral jsonb_array_elements(r.body#>'{data,items}') item
 where seq=9 and item->>'person_id'='a1200000-0000-4000-8000-000000000001'),2::bigint,'same child in two contexts allowed');
select extensions.is((select jsonb_array_length(body#>'{data,items}') from child_results where seq=10),1,'platform filter restricts');
select extensions.ok((select (select array_agg(key order by key) from jsonb_object_keys(body->'data') key)
 = array['items','next_cursor']::text[] from child_results where seq=9),'data has no total or extra projection');

select pg_temp.child_actor(3);
set local role authenticated;
insert into child_results values (11,public.superadmin_child_context_directory_v2());
reset role;
select extensions.is((select body#>>'{error,code}' from child_results where seq=11),'SAI_PERMISSION_DENIED','non-Owner denied');
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now()
 where id='a1800000-0000-4000-8000-000000000001';
select pg_temp.child_actor(1);
set local role authenticated;
insert into child_results values (12,public.superadmin_child_context_directory_v2());
reset role;
select extensions.is((select body#>>'{error,code}' from child_results where seq=12),'SAI_MEMBERSHIP_REVOKED','revocation rechecked');
select extensions.ok(not exists(select 1 from audit.audit_logs where action_code='child_context.directory'
 and (before_json is not null or after_json is not null)), 'no names or payload in audit');
select extensions.ok(exists(select 1 from audit.audit_logs where action_code='child_context.directory'
 and outcome='success' and permission_code='people.read' and object_type='child_context_catalog'), 'successful read audited');
select extensions.ok(not exists(select 1 from audit.audit_logs where action_code='child_context.directory'
 and outcome='denied' and institution_id is not null), 'negative audit never trusts input institution');

create temporary table child_audit_before as select count(*) n from audit.audit_logs;
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
insert into child_results values (13,public.superadmin_child_context_directory_v2());
reset role;
select extensions.is((select body#>>'{error,code}' from child_results where seq=13),'SAI_AUTH_REQUIRED','no session denied');
select extensions.is((select count(*) from audit.audit_logs),(select n from child_audit_before),'invalid session creates no audit actor');

-- Transaction time remains valid while wall clock has expired: Auth039 alone
-- would accept this fixture. Never use a busy-wait or a production session.
select pg_sleep(0.01);
update auth.sessions set not_after=clock_timestamp()
 where id='a1500000-0000-4000-8000-000000000002';
select extensions.ok((select not_after > now() from auth.sessions
 where id='a1500000-0000-4000-8000-000000000002'),'fixture expiration is after transaction timestamp');
select pg_temp.child_actor(2);
set local role authenticated;
insert into child_results values (15,public.superadmin_child_context_directory_v2());
reset role;
select extensions.is((select body#>>'{error,code}' from child_results where seq=15),'SAI_SESSION_INVALID','wall-clock expired session cannot read');
update auth.sessions set not_after=clock_timestamp()+interval '1 hour'
 where id='a1500000-0000-4000-8000-000000000002';

set local role authenticated;
insert into child_results values(16,public.superadmin_child_context_directory_v2(null,null,null,1));
insert into child_results values(17,public.superadmin_child_context_directory_v2(null,null,null,50));
insert into child_results values(18,public.superadmin_child_context_directory_v2(null,null,null,51));
insert into child_results values(19,public.superadmin_child_context_directory_v2(null,null,null,null));
insert into child_results values(20,public.superadmin_child_context_directory_v2(null,chr(127),'a1300000-0000-4000-8000-000000000001',20));
insert into child_results values(21,public.superadmin_child_context_directory_v2(null,chr(128),'a1300000-0000-4000-8000-000000000001',20));
reset role;
select extensions.is((select jsonb_array_length(body#>'{data,items}') from child_results where seq=16),1,'limit1 supported');
select extensions.is((select body->>'ok' from child_results where seq=17),'true','limit50 supported');
select extensions.is((select count(*) from child_results where seq in(18,19,20) and body#>>'{error,code}'='SAI_INVALID_ARGUMENT'),3::bigint,'limit51, null and DEL rejected');
select extensions.is((select body->>'ok' from child_results where seq=21),'true','C1 follows existing DTO contract without new sanitization');

update public.people set display_name=repeat('a',8193) where id='a1200000-0000-4000-8000-000000000003';
set local role authenticated;
insert into child_results values(22,public.superadmin_child_context_directory_v2(null,null,null,1));
insert into child_results values(23,public.superadmin_child_context_directory_v2(null,null,null,50));
reset role;
select extensions.is((select body#>>'{error,code}' from child_results where seq=22),'SAI_INTERNAL_ERROR','oversized output cursor fails without truncation or false last page');
select extensions.is((select length(body#>>'{data,items,0,person_name}') from child_results where seq=23),8193,'name itself has no invented cadastral cap');
update public.people set display_name='Zulu' where id='a1200000-0000-4000-8000-000000000003';
update public.institutions set deleted_at=now() where id='a1100000-0000-4000-8000-000000000002';
set local role authenticated;
insert into child_results values(24,public.superadmin_child_context_directory_v2('a1100000-0000-4000-8000-000000000002'));
insert into child_results values(25,public.superadmin_child_context_directory_v2());
reset role;
select extensions.is((select body#>>'{error,code}' from child_results where seq=24),'SAI_PERMISSION_DENIED','deleted institution cannot be selected');
select extensions.is((select jsonb_array_length(body#>'{data,items}') from child_results where seq=25),3,'deleted institution excluded from platform page');
update public.institutions set deleted_at=null where id='a1100000-0000-4000-8000-000000000002';

-- Fault injected only in this rollback-contained local fixture, never a deployed helper.
create function pg_temp.fail_child_audit() returns trigger language plpgsql as $$
begin raise exception using message='synthetic child audit failure'; end $$;
create trigger fail_child_audit before insert on audit.audit_logs for each row
 when(new.action_code='child_context.directory') execute function pg_temp.fail_child_audit();
select pg_temp.child_actor(2);
set local role authenticated;
do $$
declare value jsonb; failure_state text; failure_message text;
begin
 begin
  value:=public.superadmin_child_context_directory_v2();
  insert into child_results values(14,value);
 exception when others then
  get stacked diagnostics failure_state=returned_sqlstate,failure_message=message_text;
  insert into child_results values(14,jsonb_build_object('state',failure_state,'message',failure_message));
 end;
end $$;
reset role;
select extensions.is((select body from child_results where seq=14),
 '{"state":"P0001","message":"synthetic child audit failure"}'::jsonb,'audit trigger actually fails; no child data returned');
drop trigger fail_child_audit on audit.audit_logs;
update public.platform_role_permissions set status='inactive',revoked_at=now()
 where role_id=(select id from public.platform_roles where code='owner')
 and permission_id=(select id from public.platform_permissions where code='people.read');
set local role authenticated;
insert into child_results values(26,public.superadmin_child_context_directory_v2());
reset role;
select extensions.is((select body#>>'{error,code}' from child_results where seq=26),'SAI_PERMISSION_DENIED','effective capability revoked between calls');
select * from extensions.finish();
rollback;
