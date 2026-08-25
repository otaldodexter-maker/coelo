begin;

create extension if not exists pgtap with schema extensions;
select plan(11);

select has_function('public', 'form_authorize_file_job_download', array['uuid']);
select has_function('public', 'form_redeem_file_job_download', array['uuid']);
select ok(
  has_function_privilege('authenticated', 'public.form_authorize_file_job_download(uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.form_authorize_file_job_download(uuid)', 'EXECUTE')
  and has_function_privilege('service_role', 'public.form_redeem_file_job_download(uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.form_redeem_file_job_download(uuid)', 'EXECUTE'),
  'only authenticated can request a token and only service_role can redeem it'
);

insert into auth.users(id, aud, role, email, created_at, updated_at) values
 ('85000000-0000-4000-8000-000000000001','authenticated','authenticated','forms-download-owner@test.invalid',now(),now()),
 ('85000000-0000-4000-8000-000000000002','authenticated','authenticated','forms-download-denied@test.invalid',now(),now());
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('85100000-0000-4000-8000-000000000001','adult','Download','Owner','Download Owner','active'),
 ('85100000-0000-4000-8000-000000000002','adult','Download','Denied','Download Denied','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('85100000-0000-4000-8000-000000000001','85000000-0000-4000-8000-000000000001','active'),
 ('85100000-0000-4000-8000-000000000002','85000000-0000-4000-8000-000000000002','active');
insert into public.platform_roles(id,code,name,status,is_system)
values ('85200000-0000-4000-8000-000000000001','forms_download_denied','Forms download denied','active',true);
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select '85100000-0000-4000-8000-000000000001',id,'active','platform',false from public.platform_roles where code='owner';
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
values ('85100000-0000-4000-8000-000000000002','85200000-0000-4000-8000-000000000001','active','platform',false);
insert into public.institutions(id,public_name,legal_name,slug,status) values
 ('85300000-0000-4000-8000-000000000001','Download A','Download A','forms-download-a','active'),
 ('85300000-0000-4000-8000-000000000002','Download B','Download B','forms-download-b','active');
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_person_id,updated_by_person_id) values
 ('85400000-0000-4000-8000-000000000001','85300000-0000-4000-8000-000000000001','form','identified','person','Download A','85100000-0000-4000-8000-000000000001','85100000-0000-4000-8000-000000000001'),
 ('85400000-0000-4000-8000-000000000002','85300000-0000-4000-8000-000000000002','form','identified','person','Download B','85100000-0000-4000-8000-000000000001','85100000-0000-4000-8000-000000000001');
insert into public.form_file_jobs(id,institution_id,form_id,requested_by_person_id,request_id,export_kind,state,progress,artifact_path,expires_at) values
 ('85500000-0000-4000-8000-000000000001','85300000-0000-4000-8000-000000000001','85400000-0000-4000-8000-000000000001','85100000-0000-4000-8000-000000000001','85600000-0000-4000-8000-000000000001','csv','succeeded',1,'aa/85700000-0000-4000-8000-000000000001',now()+interval '1 hour'),
 ('85500000-0000-4000-8000-000000000002','85300000-0000-4000-8000-000000000002','85400000-0000-4000-8000-000000000002','85100000-0000-4000-8000-000000000002','85600000-0000-4000-8000-000000000002','csv','succeeded',1,'bb/85700000-0000-4000-8000-000000000002',now()+interval '1 hour'),
 ('85500000-0000-4000-8000-000000000003','85300000-0000-4000-8000-000000000001','85400000-0000-4000-8000-000000000001','85100000-0000-4000-8000-000000000001','85600000-0000-4000-8000-000000000003','csv','expired',1,'cc/85700000-0000-4000-8000-000000000003',now()-interval '1 second');

alter table public.form_file_jobs disable trigger form_file_jobs_tenant_validate;
insert into public.form_file_jobs(id,institution_id,form_id,requested_by_person_id,request_id,export_kind,state,progress,artifact_path,expires_at)
values ('85500000-0000-4000-8000-000000000004','85300000-0000-4000-8000-000000000001','85400000-0000-4000-8000-000000000002','85100000-0000-4000-8000-000000000001','85600000-0000-4000-8000-000000000004','csv','succeeded',1,'dd/85700000-0000-4000-8000-000000000004',now()+interval '1 hour');
alter table public.form_file_jobs enable trigger form_file_jobs_tenant_validate;

create temporary table forms_download_results(key text primary key,result jsonb);
grant select,insert,update on forms_download_results to authenticated,service_role;

set local role authenticated;
select set_config('request.jwt.claim.sub','85000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"85000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}',true);

select ok(
  not jsonb_path_exists(public.form_list_file_jobs(jsonb_build_object('form_id','85400000-0000-4000-8000-000000000001','limit',25)),'$.items[*].download_path')
  and not jsonb_path_exists(public.form_list_file_jobs(jsonb_build_object('form_id','85400000-0000-4000-8000-000000000001','limit',25)),'$.items[*].artifact_path')
  and jsonb_path_exists(public.form_list_file_jobs(jsonb_build_object('form_id','85400000-0000-4000-8000-000000000001','limit',25)),'$.items[*] ? (@.download_available == true)'),
  'file job list exposes availability without any storage path'
);

insert into forms_download_results
select 'token',public.form_authorize_file_job_download('85500000-0000-4000-8000-000000000001');

select ok(
  (select result ? 'download_token' and result ? 'expires_at'
       and not result ? 'storage_path' and not result ? 'artifact_path'
     from forms_download_results where key='token'),
  'authorized actor receives only an opaque short-lived token'
);

reset role;
select ok(
  (select token_hash <> (result->>'download_token')
       and expires_at <= now()+interval '2 minutes'
       and consumed_at is null
     from app_private.form_file_download_tokens token_row
     join forms_download_results result_row on result_row.key='token'
    where token_row.file_job_id='85500000-0000-4000-8000-000000000001'),
  'only a hash is persisted and token lifetime is at most two minutes'
);

set local role authenticated;
select is(public.form_authorize_file_job_download('85500000-0000-4000-8000-000000000002'),null::jsonb,
  'another actor and tenant job is indistinguishable from unavailable');
select is(public.form_authorize_file_job_download('85500000-0000-4000-8000-000000000003'),null::jsonb,
  'an expired job is unavailable');
select is(public.form_authorize_file_job_download('85500000-0000-4000-8000-000000000004'),null::jsonb,
  'a job with inconsistent tenant and form is unavailable');

select set_config('request.jwt.claim.sub','85000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"85000000-0000-4000-8000-000000000002","aal":"aal1","role":"authenticated"}',true);
select throws_ok(
  $$select public.form_authorize_file_job_download('85500000-0000-4000-8000-000000000002')$$,
  '42501','forms.responses.export required',
  'an actor without export capability cannot request a token'
);

reset role;
set local role service_role;
insert into forms_download_results
select 'redeemed',public.form_redeem_file_job_download(
  (select (result->>'download_token')::uuid from forms_download_results where key='token')
);
select ok(
  (select result->>'storage_path'='aa/85700000-0000-4000-8000-000000000001'
       and result->>'job_id'='85500000-0000-4000-8000-000000000001'
     from forms_download_results where key='redeemed')
  and public.form_redeem_file_job_download(
    (select (result->>'download_token')::uuid from forms_download_results where key='token')
  ) is null,
  'service_role redeems the path exactly once'
);

reset role;
select * from finish();
rollback;
