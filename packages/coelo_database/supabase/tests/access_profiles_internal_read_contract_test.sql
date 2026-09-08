-- Nominal READ diagnostic only; coordinated disposable replay, never production.
-- No grants, helper replacement, or legacy people bridge to bypass the first gate.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data) values
  ('e1100000-0000-4000-8000-000000000001','authenticated','authenticated',
   'profiles-read-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('e1200000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000001',
   now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
  ('e1300000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
  ('e1400000-0000-4000-8000-000000000001','e1300000-0000-4000-8000-000000000001',
   'e1100000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select 'e1500000-0000-4000-8000-000000000001','e1300000-0000-4000-8000-000000000001',id,'platform'
from public.platform_roles where code='owner';

-- Distinct query prefix excludes pre-existing roles. Numbered names fix ordering.
insert into public.platform_roles(id,code,name,status,max_scope_kind,is_system)
select ('e1600000-0000-4000-8000-'||lpad(sequence_no::text,12,'0'))::uuid,
  'e1_profiles_read_'||sequence_no,
  'E1 profiles nominal '||lpad(sequence_no::text,2,'0'),
  case when sequence_no<=6 then 'active'::public.record_status
    else 'inactive'::public.record_status end,
  case when sequence_no%2=0 then 'institution' else 'platform' end,false
from generate_series(1,12) sequence_no;

select ok(not exists(select 1 from public.person_auth_links
  where auth_user_id='e1100000-0000-4000-8000-000000000001'),
  'fixture has an internal actor without any people auth link');
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','e1100000-0000-4000-8000-000000000001',
  'session_id','e1200000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.profiles_read_actor',current_user,true);
select set_config('test.profiles_read_bootstrap',public.superadmin_auth_bootstrap_context()::text,true);

-- Catch each SQL failure without changing permissions or aborting later diagnostics.
-- A failure here can be ACL, realm or contract; the diagnostics keep these distinct.
do $capture$
declare scenario jsonb; response jsonb; result jsonb;
  failure_state text; failure_detail text; failure_message text;
begin
  for scenario in select value from jsonb_array_elements('[
    {"name":"page1","page":1,"size":8},
    {"name":"page2","page":2,"size":8},
    {"name":"scopes","page":1,"size":20,"scope":"platform,institution"},
    {"name":"statuses","page":1,"size":20,"status":"active,inactive"}
  ]'::jsonb) loop
    begin
      response:=public.superadmin_access_profiles_list(
        'platform','E1 profiles nominal',scenario->>'status',scenario->>'scope',
        (scenario->>'page')::integer,(scenario->>'size')::integer);
      result:=jsonb_build_object('sqlstate','00000','response',response);
    exception when others then
      get stacked diagnostics failure_state=returned_sqlstate,
        failure_detail=pg_exception_detail,failure_message=message_text;
      result:=jsonb_build_object('sqlstate',failure_state,
        'detail',failure_detail,'failure_class',case
          when failure_state='42501' and failure_message like 'permission denied for %'
            then 'acl-before-contract'
          when failure_state='42501' then 'authorization-denied'
          else 'runtime-error' end);
    end;
    perform set_config('test.profiles_read_'||(scenario->>'name'),result::text,true);
  end loop;
end
$capture$;
reset role;

select is(current_setting('test.profiles_read_actor'),'authenticated',
  'bootstrap and profile RPC calls execute as authenticated');
select is(current_setting('test.profiles_read_bootstrap')::jsonb->>'ok','true',
  'internal Owner AAL1 bootstrap is a positive precondition independent of profiles');
select is(jsonb_array_length(current_setting('test.profiles_read_page1')::jsonb#>'{response,items}'),8,
  'internal Owner without people can read the first eight profiles');
select is(jsonb_build_array(
    current_setting('test.profiles_read_page1')::jsonb#>'{response,total}',
    current_setting('test.profiles_read_page1')::jsonb#>'{response,page}',
    current_setting('test.profiles_read_page1')::jsonb#>'{response,page_size}'),
  '[12,1,8]'::jsonb,'list returns the total/page/page_size contract consumed by Flutter');
select is((select jsonb_agg(item->>'id' order by item->>'name')
  from jsonb_array_elements(current_setting('test.profiles_read_page2')::jsonb#>'{response,items}') item),
  '["e1600000-0000-4000-8000-000000000009","e1600000-0000-4000-8000-000000000010","e1600000-0000-4000-8000-000000000011","e1600000-0000-4000-8000-000000000012"]'::jsonb,
  'page 2 returns only the four remaining profiles, never page 1 again');
select is(jsonb_array_length(current_setting('test.profiles_read_scopes')::jsonb#>'{response,items}'),12,
  'multiple scopes use set membership, matching the Flutter CSV contract');
select is(jsonb_array_length(current_setting('test.profiles_read_statuses')::jsonb#>'{response,items}'),12,
  'legacy status parameter accepts its CSV contract without adding a status UI');

select diag(jsonb_build_object(
  'page1',current_setting('test.profiles_read_page1')::jsonb-'response',
  'page2',current_setting('test.profiles_read_page2')::jsonb-'response',
  'scopes',current_setting('test.profiles_read_scopes')::jsonb-'response',
  'statuses',current_setting('test.profiles_read_statuses')::jsonb-'response')::text);
select * from finish();
rollback;
