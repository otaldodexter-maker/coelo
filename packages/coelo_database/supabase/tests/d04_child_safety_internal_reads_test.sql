-- Disposable LOCAL replay only. Synthetic fixtures roll back. No real account.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into public.platform_roles(id,code,name,max_scope_kind)
values('d4900000-0000-4000-8000-000000000001','d04_safety_reader','D04 synthetic reader','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect)
select 'd4900000-0000-4000-8000-000000000001',id,'allow'
from public.platform_permissions where code='child_safety.read';
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values('d4910000-0000-4000-8000-000000000001','authenticated','authenticated','d04-safety@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values('d4920000-0000-4000-8000-000000000001','d4910000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values('d4930000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
values('d4940000-0000-4000-8000-000000000001','d4930000-0000-4000-8000-000000000001','d4910000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
values('d4950000-0000-4000-8000-000000000001','d4930000-0000-4000-8000-000000000001','d4900000-0000-4000-8000-000000000001','platform');
insert into public.institution_types(id,code,name,status) values
('d4950000-0000-4000-8000-000000000001','d04-safety-type','D04 safety type','active');
insert into public.institutions(id,public_name,slug,institution_type_id) values
('d4960000-0000-4000-8000-000000000001','D04 synthetic A','d04-safety-a','d4950000-0000-4000-8000-000000000001'),
('d4960000-0000-4000-8000-000000000002','D04 synthetic B','d04-safety-b','d4950000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,unit_type_id,name,slug) values
('d4970000-0000-4000-8000-000000000001','d4960000-0000-4000-8000-000000000001','3cac54bf-0a5e-4293-a643-471e1319d63b','D04 unit A','a'),
('d4970000-0000-4000-8000-000000000002','d4960000-0000-4000-8000-000000000002','3cac54bf-0a5e-4293-a643-471e1319d63b','D04 unit B','b');
insert into public.people(id,person_type,first_name,last_name,display_name)
select ('d4980000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'child','D04','Synthetic','D04 safety synthetic '||n
from generate_series(1,9) n;
insert into public.child_contexts(id,child_person_id,institution_id)
select ('d4990000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
('d4980000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
case when n=9 then 'd4960000-0000-4000-8000-000000000002'::uuid else 'd4960000-0000-4000-8000-000000000001'::uuid end
from generate_series(1,9) n;
insert into public.people(id,person_type,first_name,last_name,display_name) values('d4980000-0000-4000-8000-000000000010','adult','D04','Synthetic','D04 synthetic adult');
insert into public.child_unit_links(child_context_id,unit_id,status,accepted_by,accepted_at)
select id,case when institution_id='d4960000-0000-4000-8000-000000000002' then 'd4970000-0000-4000-8000-000000000002'::uuid
else 'd4970000-0000-4000-8000-000000000001'::uuid end,'active','d4980000-0000-4000-8000-000000000010',now()
from public.child_contexts where id::text like 'd4990000%';

insert into public.child_safety_restrictions(id,institution_id,unit_id,child_context_id,restriction_code,title,description,severity,reason,created_by_person_id,updated_by_person_id)
values('d49a0000-0000-4000-8000-000000000001','d4960000-0000-4000-8000-000000000001','d4970000-0000-4000-8000-000000000001',
'd4990000-0000-4000-8000-000000000001','d04_test','Synthetic restriction','Synthetic restriction fixture','information','Synthetic test reason',
'd4980000-0000-4000-8000-000000000010','d4980000-0000-4000-8000-000000000010');
insert into public.child_safety_alerts(id,institution_id,unit_id,child_context_id,restriction_id,event_code,severity,reason)
values('d49b0000-0000-4000-8000-000000000001','d4960000-0000-4000-8000-000000000001','d4970000-0000-4000-8000-000000000001',
'd4990000-0000-4000-8000-000000000001','d49a0000-0000-4000-8000-000000000001','d04_test','information','Synthetic alert fixture');
insert into public.child_safety_evidence(id,institution_id,unit_id,child_context_id,restriction_id,object_path,file_name,mime_type,size_bytes,checksum_sha256,status,created_by_person_id)
values('d49c0000-0000-4000-8000-000000000001','d4960000-0000-4000-8000-000000000001','d4970000-0000-4000-8000-000000000001',
'd4990000-0000-4000-8000-000000000001','d49a0000-0000-4000-8000-000000000001',
'child-safety/d4960000-0000-4000-8000-000000000001/d4970000-0000-4000-8000-000000000001/d4990000-0000-4000-8000-000000000001/d49c0000-0000-4000-8000-000000000001.pdf',
'synthetic.pdf','application/pdf',10,repeat('a',64),'active','d4980000-0000-4000-8000-000000000010');

select set_config('request.jwt.claims',jsonb_build_object('sub','d4910000-0000-4000-8000-000000000001',
'session_id','d4920000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.d04_safety',jsonb_build_object(
'directory',public.superadmin_child_safety_directory_v2('D04 safety synthetic','{}','{}','all',8,null),
'filtered',public.superadmin_child_safety_directory_v2('D04 safety synthetic',array['d4960000-0000-4000-8000-000000000002'::uuid]),
'search',public.superadmin_child_safety_search_children_v2('D04 safety synthetic'),
'get',public.superadmin_child_safety_get_v2('d4980000-0000-4000-8000-000000000001'),
'missing',public.superadmin_child_safety_get_v2('d4980000-0000-4000-8000-000000000099'),
'bad_cursor',public.superadmin_child_safety_directory_v2(p_cursor=>'[]'),
'bad_limit',public.superadmin_child_safety_directory_v2(p_limit=>1),
'bad_search',public.superadmin_child_safety_search_children_v2('x'),
'bad_hierarchy',public.superadmin_child_safety_directory_v2(p_institution_ids=>array['d4960000-0000-4000-8000-000000000001'::uuid],p_unit_ids=>array['d4970000-0000-4000-8000-000000000002'::uuid])
)::text,true);
select set_config('test.d04_safety_next',public.superadmin_child_safety_directory_v2('D04 safety synthetic','{}','{}','all',8,
current_setting('test.d04_safety')::jsonb#>'{directory,data,next_cursor}')::text,true);
reset role;
select is(current_setting('test.d04_safety')::jsonb#>>'{directory,ok}','true','non-Owner capability reader succeeds in AAL1');
select is(current_setting('test.d04_safety')::jsonb#>>'{directory,data,can_create}','false','read-only cutover does not advertise legacy writes');
select is(current_setting('test.d04_safety')::jsonb#>>'{directory,data,total_count}','9','directory counts before cursor');
select is(jsonb_array_length(current_setting('test.d04_safety')::jsonb#>'{directory,data,items}'),8,'page size remains eight');
select is(jsonb_array_length(current_setting('test.d04_safety_next')::jsonb#>'{data,items}'),1,'stable cursor returns final row');
select is(current_setting('test.d04_safety_next')::jsonb#>>'{data,total_count}','9','next page retains full total');
select is(current_setting('test.d04_safety')::jsonb#>>'{directory,data,segment_counts,without_authorization}','8','segment count stays exclusive');
select is(current_setting('test.d04_safety')::jsonb#>>'{filtered,data,total_count}','1','institution filter excludes other institution');
select is(jsonb_array_length(current_setting('test.d04_safety')::jsonb#>'{search,data}'),9,'child search returns authorized minimized options');
select is(current_setting('test.d04_safety')::jsonb#>>'{get,data,child_id}','d4980000-0000-4000-8000-000000000001','detail returns requested child');
select is(current_setting('test.d04_safety')::jsonb#>>'{missing,error,code}','SAI_PERMISSION_DENIED','missing ID does not expose existence distinction');
select is(current_setting('test.d04_safety')::jsonb#>>'{bad_cursor,error,code}','SAI_INVALID_ARGUMENT','bad_cursor rejects malformed input');
select is(current_setting('test.d04_safety')::jsonb#>>'{bad_limit,error,code}','SAI_INVALID_ARGUMENT','bad_limit rejects malformed input');
select is(current_setting('test.d04_safety')::jsonb#>>'{bad_search,error,code}','SAI_INVALID_ARGUMENT','bad_search rejects malformed input');
select is(current_setting('test.d04_safety')::jsonb#>>'{bad_hierarchy,error,code}','SAI_INVALID_ARGUMENT','bad_hierarchy rejects malformed input');
select is(jsonb_array_length(current_setting('test.d04_safety')::jsonb#>'{get,data,restrictions}'),1,'nonempty restriction fixture returned');
select is(jsonb_array_length(current_setting('test.d04_safety')::jsonb#>'{get,data,alerts}'),1,'nonempty alert fixture returned');
select is(jsonb_array_length(current_setting('test.d04_safety')::jsonb#>'{get,data,evidence}'),1,'nonempty evidence metadata returned');
select ok(not (current_setting('test.d04_safety')::jsonb#>'{get,data,restrictions,0}') ?| array['created_by_person_id','updated_by_person_id'],
'restriction projection omits legacy actor identities');
select ok(not (current_setting('test.d04_safety')::jsonb#>'{get,data,alerts,0}') ? 'acknowledged_by_person_id',
'alert projection omits legacy actor identity');
select ok(not (current_setting('test.d04_safety')::jsonb#>'{get,data,evidence,0}') ?| array['object_path','bucket_id','checksum_sha256','created_by_person_id'],
'evidence projection omits private storage locator checksum and actor');
select ok(not exists(select 1 from audit.audit_logs a where a.actor_internal_identity_id='d4930000-0000-4000-8000-000000000001'
  and to_jsonb(a)::text like '%D04 safety synthetic%'),'audit never stores child name or search text');
select ok(exists(select 1 from audit.audit_logs where actor_internal_identity_id='d4930000-0000-4000-8000-000000000001'
  and action_code='superadmin.child-safety.child' and outcome='success' and actor_person_id is null),'successful reads use typed internal audit');
select ok(exists(select 1 from audit.audit_logs where actor_internal_identity_id='d4930000-0000-4000-8000-000000000001'
  and action_code='superadmin.child-safety.child' and outcome='denied'),'validated session denial is audited');
select ok(not exists(select 1 from public.person_auth_links where auth_user_id='d4910000-0000-4000-8000-000000000001'),'no internal-to-People bridge');

set local role authenticated;
select set_config('test.d04_bounds',jsonb_build_object(
'array',public.superadmin_child_safety_directory_v2(p_institution_ids=>array_fill('d4960000-0000-4000-8000-000000000001'::uuid,array[101])),
'cursor_type',public.superadmin_child_safety_directory_v2(p_cursor=>' {"name":5,"child_context_id":"d4990000-0000-4000-8000-000000000001","unit_id":"d4970000-0000-4000-8000-000000000001"}'),
'cursor_extra',public.superadmin_child_safety_directory_v2(p_cursor=>'{"extra":true}'),
'empty_cursor',public.superadmin_child_safety_directory_v2('D04 safety synthetic',p_cursor=>'{}')
)::text,true);
reset role;
select is(current_setting('test.d04_bounds')::jsonb#>>'{array,error,code}','SAI_INVALID_ARGUMENT','filter cardinality is bounded');
select is(current_setting('test.d04_bounds')::jsonb#>>'{cursor_type,error,code}','SAI_INVALID_ARGUMENT','numeric cursor name is rejected');
select is(current_setting('test.d04_bounds')::jsonb#>>'{cursor_extra,error,code}','SAI_INVALID_ARGUMENT','unknown cursor keys are rejected');
select is(current_setting('test.d04_bounds')::jsonb#>>'{empty_cursor,ok}','true','empty object retains legacy first-page semantics');

-- Scope denial must precede even malformed search and cursor validation.
update app_private.superadmin_internal_memberships set version=version+1,scope_kind='institution',scope_institution_id='d4960000-0000-4000-8000-000000000001'
where id='d4950000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('test.d04_scope',public.superadmin_child_safety_search_children_v2('x')::text,true);
reset role;
select is(current_setting('test.d04_scope')::jsonb#>>'{error,code}','SAI_PERMISSION_DENIED','institution membership cannot use global read even for invalid query');
update app_private.superadmin_internal_memberships set version=version+1,scope_kind='platform',scope_institution_id=null
where id='d4950000-0000-4000-8000-000000000001';
update public.platform_role_permissions set effect='deny' where role_id='d4900000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('test.d04_capability',public.superadmin_child_safety_get_v2('d4980000-0000-4000-8000-000000000001')::text,true);
reset role;
select is(current_setting('test.d04_capability')::jsonb#>>'{error,code}','SAI_PERMISSION_DENIED','explicit capability denial wins before child lookup');
update public.platform_role_permissions set effect='allow' where role_id='d4900000-0000-4000-8000-000000000001';
update app_private.superadmin_internal_memberships set version=version+1,status='suspended',suspended_at=now()
where id='d4950000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('test.d04_suspended',public.superadmin_child_safety_directory_v2()::text,true);
reset role;
select is(current_setting('test.d04_suspended')::jsonb#>>'{error,code}','SAI_MEMBERSHIP_SUSPENDED','suspended membership loses read access');
update app_private.superadmin_internal_memberships set version=version+1,status='active',suspended_at=null
where id='d4950000-0000-4000-8000-000000000001';
update app_private.superadmin_internal_auth_links set version=version+1,status='revoked',revoked_at=now()
where id='d4940000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('test.d04_revoked',public.superadmin_child_safety_directory_v2()::text,true);
reset role;
select is(current_setting('test.d04_revoked')::jsonb#>>'{error,code}','SAI_INTERNAL_CONTEXT_DENIED','revoked auth link loses read access');
update auth.sessions set not_after=now()-interval '1 minute' where id='d4920000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('test.d04_session',public.superadmin_child_safety_directory_v2()::text,true);
reset role;
select is(current_setting('test.d04_session')::jsonb#>>'{error,code}','SAI_SESSION_INVALID','expired session cannot read directory');
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select set_config('test.d04_anon',public.superadmin_child_safety_directory_v2()::text,true);
reset role;
select is(current_setting('test.d04_anon')::jsonb#>>'{error,code}','SAI_AUTH_REQUIRED','absent identity returns stable denial');
select ok(has_function_privilege('authenticated','public.superadmin_child_safety_directory_v2(text,uuid[],uuid[],text,integer,jsonb)','EXECUTE') and not has_function_privilege('anon','public.superadmin_child_safety_directory_v2(text,uuid[],uuid[],text,integer,jsonb)','EXECUTE') and not has_function_privilege('service_role','public.superadmin_child_safety_directory_v2(text,uuid[],uuid[],text,integer,jsonb)','EXECUTE'),'public directory_v2 grants only authenticated');
select ok(has_function_privilege('authenticated','public.superadmin_child_safety_search_children_v2(text,integer)','EXECUTE') and not has_function_privilege('anon','public.superadmin_child_safety_search_children_v2(text,integer)','EXECUTE') and not has_function_privilege('service_role','public.superadmin_child_safety_search_children_v2(text,integer)','EXECUTE'),'public search_children_v2 grants only authenticated');
select ok(has_function_privilege('authenticated','public.superadmin_child_safety_get_v2(uuid)','EXECUTE') and not has_function_privilege('anon','public.superadmin_child_safety_get_v2(uuid)','EXECUTE') and not has_function_privilege('service_role','public.superadmin_child_safety_get_v2(uuid)','EXECUTE'),'public get_v2 grants only authenticated');
select ok(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace,
lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
where n.nspname='app_private' and p.proname like 'd04_child_safety_%'
and a.privilege_type='EXECUTE' and (a.grantee=0 or a.grantee in (select oid from pg_roles where rolname in ('anon','authenticated','service_role')))),
'private dispatcher and data readers have no client or service execute grants');
select ok(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace,
lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
where n.nspname='public' and p.proname like 'superadmin_child_safety_%_v2' and a.privilege_type='EXECUTE' and a.grantee=0),
'new public wrappers have no PUBLIC execution');
select ok((select bool_and(prosecdef and array_to_string(proconfig,',') like '%search_path=""%') from pg_proc
where proname like 'd04_child_safety_%' or proname in ('superadmin_child_safety_directory_v2','superadmin_child_safety_search_children_v2','superadmin_child_safety_get_v2')),
'privileged new functions fix an empty search_path');
-- Dedicated global actor, entirely distinct from the internal fixture above.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values('d4910000-0000-4000-8000-000000000002','authenticated','authenticated','d04-safety-global@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values('d4920000-0000-4000-8000-000000000002','d4910000-0000-4000-8000-000000000002',now(),now(),'aal2',now()+interval '1 hour');
insert into public.person_auth_links(person_id,auth_user_id)
values('d4980000-0000-4000-8000-000000000010','d4910000-0000-4000-8000-000000000002');
insert into public.platform_memberships(person_id,role_id,status)
values('d4980000-0000-4000-8000-000000000010','d4900000-0000-4000-8000-000000000001','active');
select set_config('request.jwt.claims',jsonb_build_object('sub','d4910000-0000-4000-8000-000000000002',
'session_id','d4920000-0000-4000-8000-000000000002','aal','aal2','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.d04_realm',public.superadmin_child_safety_get_v2('d4980000-0000-4000-8000-000000000001')::text,true);
reset role;
select is(current_setting('test.d04_realm')::jsonb#>>'{error,code}','SAI_INTERNAL_CONTEXT_DENIED','global AAL2 actor with legacy platform grant cannot use internal v2');
select ok(exists(select 1 from audit.audit_logs where correlation_id=(current_setting('test.d04_realm')::jsonb#>>'{error,correlation_id}')::uuid
  and actor_kind='auth_session' and actor_person_id is null and outcome='denied'),'cross-realm denial uses auth-session audit without legacy actor');
select * from finish();
rollback;
