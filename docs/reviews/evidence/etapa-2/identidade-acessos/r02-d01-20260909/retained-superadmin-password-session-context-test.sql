-- source: D01 local recovery RED; 20260909173000_superadmin_password_session_context.sql
-- status: local-candidate-not-executed
-- generated_at: 2026-09-09
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);
create temporary table auth_test_responses(sequence_number integer primary key,body jsonb not null);
grant select,insert on auth_test_responses to authenticated;
select set_config('request.jwt.claim.sub','',true);
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data)
values('10000000-0000-4000-8000-000000000005','authenticated','authenticated',
  'synthetic-password-session@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
select session_id,'10000000-0000-4000-8000-000000000005',
  now(),now(),'aal1',now()+interval '1 hour'
from (values
  ('20000000-0000-4000-8000-000000000005'::uuid),
  ('20000000-0000-4000-8000-000000000006'::uuid),
  ('20000000-0000-4000-8000-000000000007'::uuid)
) sessions(session_id);
insert into auth.mfa_amr_claims(id,session_id,created_at,updated_at,authentication_method)
values
  (gen_random_uuid(),'20000000-0000-4000-8000-000000000005',now(),now(),'password'),
  (gen_random_uuid(),'20000000-0000-4000-8000-000000000006',now(),now(),'otp');
insert into app_private.superadmin_internal_identities(id)
values('30000000-0000-4000-8000-000000000005');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
values('40000000-0000-4000-8000-000000000005',
  '30000000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000005');
insert into app_private.superadmin_internal_memberships(
  internal_identity_id,platform_role_id,scope_kind,status)
select '30000000-0000-4000-8000-000000000005',id,'platform','active'
from public.platform_roles where code='operations' and status='active';

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','10000000-0000-4000-8000-000000000005',
  'session_id','20000000-0000-4000-8000-000000000005',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into auth_test_responses values(101,public.superadmin_auth_bootstrap_context());
reset role;
select ok((select body->>'ok'='true'
  and body#>>'{data,platform_role_code}'='operations'
  and body#>'{data,permission_codes}' ? 'platform.read'
  from auth_test_responses where sequence_number=101),
  'password AMR in the current provider session permits the active operations context');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','10000000-0000-4000-8000-000000000005',
  'session_id','20000000-0000-4000-8000-000000000006',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into auth_test_responses values(102,public.superadmin_auth_bootstrap_context());
reset role;
select ok((select body->>'ok'='false' and body->'data'='null'::jsonb
  and body#>>'{error,code}'='SAI_SESSION_INVALID'
  from auth_test_responses where sequence_number=102),
  'OTP-only session is denied even when the same user has a different password session');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','10000000-0000-4000-8000-000000000005',
  'session_id','20000000-0000-4000-8000-000000000007',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into auth_test_responses values(103,public.superadmin_auth_bootstrap_context());
reset role;
select ok((select body->>'ok'='false' and body->'data'='null'::jsonb
  and body#>>'{error,code}'='SAI_SESSION_INVALID'
  from auth_test_responses where sequence_number=103),
  'valid session without provider AMR is denied without productive context');

update auth.users set raw_user_meta_data='{"authentication_method":"password","password_authenticated":true}'::jsonb
where id='10000000-0000-4000-8000-000000000005';
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','10000000-0000-4000-8000-000000000005',
  'session_id','20000000-0000-4000-8000-000000000006',
  'aal','aal1','role','authenticated',
  'amr',jsonb_build_array(jsonb_build_object('method','password')),
  'user_metadata',jsonb_build_object('authentication_method','password','password_authenticated',true)
)::text,true);
set local role authenticated;
insert into auth_test_responses values(104,public.superadmin_auth_bootstrap_context());
reset role;
select ok((select body->>'ok'='false' and body->'data'='null'::jsonb
  and body#>>'{error,code}'='SAI_SESSION_INVALID'
  from auth_test_responses where sequence_number=104),
  'claimed password AMR and mutable user metadata cannot override provider OTP-only session');

select ok((select count(*)=3 and bool_and(app_private.audit_verify_entry(id))
  from audit.audit_logs
  where correlation_id in(select (body#>>'{error,correlation_id}')::uuid
    from auth_test_responses where sequence_number in(102,103,104))
    and outcome='denied' and reason_code='SAI_SESSION_INVALID'
    and action_code='superadmin.auth.bootstrap'),
  'password-session denials append three correlated verified minimized audit records');

set local role authenticated;
select throws_ok($$insert into auth.mfa_amr_claims(
  id,session_id,created_at,updated_at,authentication_method)
values(gen_random_uuid(),'20000000-0000-4000-8000-000000000006',now(),now(),'password')$$,
  '42501',null,'the client role cannot mint a provider password AMR claim');
reset role;

select * from finish();
rollback;
