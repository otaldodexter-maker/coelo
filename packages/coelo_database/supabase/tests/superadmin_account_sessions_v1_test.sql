begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

-- Fixtures no realm people (mesma forma de superadmin_support_assignees_v1_test.sql).
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at) values
 ('85100000-0000-4000-8000-000000000001','authenticated','authenticated','sessions-owner@test.invalid',now(),now(),now()),
 ('85100000-0000-4000-8000-000000000002','authenticated','authenticated','sessions-other@test.invalid',now(),now(),now()),
 ('85100000-0000-4000-8000-000000000003','authenticated','authenticated','sessions-nolink@test.invalid',now(),now(),now());
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after,user_agent,ip) values
 ('85110000-0000-4000-8000-000000000001','85100000-0000-4000-8000-000000000001',now()-interval '2 day',now()-interval '1 hour','aal1',now()+interval '1 hour','Mozilla/5.0 (Windows) Chrome/130','203.0.113.10'),
 ('85110000-0000-4000-8000-000000000002','85100000-0000-4000-8000-000000000001',now()-interval '1 day',now(),'aal1',now()+interval '1 hour','Mozilla/5.0 (iPhone) Safari','203.0.113.11'),
 ('85110000-0000-4000-8000-000000000003','85100000-0000-4000-8000-000000000001',now()-interval '3 day',now()-interval '3 day','aal1',now()-interval '1 minute',null,null),
 ('85110000-0000-4000-8000-000000000004','85100000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour','Outro usuario','203.0.113.99'),
 ('85110000-0000-4000-8000-000000000005','85100000-0000-4000-8000-000000000003',now(),now(),'aal1',now()+interval '1 hour','Sem vinculo','203.0.113.98');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('85200000-0000-4000-8000-000000000001','adult','Sessoes','Owner','Sessoes Owner','active'),
 ('85200000-0000-4000-8000-000000000002','adult','Sessoes','Outro','Sessoes Outro','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('85200000-0000-4000-8000-000000000001','85100000-0000-4000-8000-000000000001','active'),
 ('85200000-0000-4000-8000-000000000002','85100000-0000-4000-8000-000000000002','active');
insert into public.platform_memberships(id,person_id,role_id,status,scope_kind,mfa_required)
select '85500000-0000-4000-8000-000000000001','85200000-0000-4000-8000-000000000001',id,'active','platform',false
from public.platform_roles where code='owner';
insert into public.platform_memberships(id,person_id,role_id,status,scope_kind,mfa_required)
select '85500000-0000-4000-8000-000000000002','85200000-0000-4000-8000-000000000002',id,'active','platform',false
from public.platform_roles where code='owner';

create temporary table sessions_responses(label text primary key, body jsonb not null);
grant select, insert on sessions_responses to authenticated;

select function_returns('public','superadmin_account_sessions_list_v1',array[]::text[],'jsonb','sessions list returns jsonb');
select is(has_function_privilege('anon','public.superadmin_account_sessions_list_v1()','execute'),false,'anon cannot list sessions');
select is(has_function_privilege('authenticated','public.superadmin_account_sessions_list_v1()','execute'),true,'authenticated can list sessions through authorization');
select ok((select pg_get_functiondef('public.superadmin_account_sessions_list_v1()'::regprocedure) not like '%auth.admin%'),'sessions list does not expose the admin API');
select is((select pg_get_function_arguments('public.superadmin_account_sessions_list_v1()'::regprocedure)),'','sessions list never accepts a user id (IDOR)');

-- Sem sessao: nega antes de qualquer leitura.
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select throws_ok($$select public.superadmin_account_sessions_list_v1()$$,'28000','authentication_required','anonymous cannot list sessions');
reset role;

-- Usuario sem vinculo de pessoa interna: nega.
select set_config('request.jwt.claims',jsonb_build_object('sub','85100000-0000-4000-8000-000000000003','session_id','85110000-0000-4000-8000-000000000005','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok($$select public.superadmin_account_sessions_list_v1()$$,'42501','internal_actor_required','user without internal person cannot list sessions');
reset role;

-- Owner: ve so as proprias sessoes vivas, a atual primeiro.
select set_config('request.jwt.claims',jsonb_build_object('sub','85100000-0000-4000-8000-000000000001','session_id','85110000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into sessions_responses values('owner', public.superadmin_account_sessions_list_v1());
reset role;

select is((select body->>'current_session_id' from sessions_responses where label='owner'),'85110000-0000-4000-8000-000000000001','current session id comes from the jwt claim');
select is((select jsonb_array_length(body->'sessions') from sessions_responses where label='owner'),2,'expired session is not listed');
select is((select body->'sessions'->0->>'id' from sessions_responses where label='owner'),'85110000-0000-4000-8000-000000000001','current session is listed first');
select is((select body->'sessions'->0->>'is_current' from sessions_responses where label='owner'),'true','current session is flagged');
select is((select body->'sessions'->1->>'ip' from sessions_responses where label='owner'),'203.0.113.11','ip is projected as text');
select ok(not exists(select 1 from sessions_responses, jsonb_array_elements(body->'sessions') s where label='owner' and s->>'id'='85110000-0000-4000-8000-000000000004'),'another user session never appears (cross-user)');

-- Outro usuario: nunca ve as sessoes do owner.
select set_config('request.jwt.claims',jsonb_build_object('sub','85100000-0000-4000-8000-000000000002','session_id','85110000-0000-4000-8000-000000000004','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into sessions_responses values('other', public.superadmin_account_sessions_list_v1());
reset role;
select is((select jsonb_array_length(body->'sessions') from sessions_responses where label='other'),1,'other user sees only its own session');

select * from finish();
rollback;
