begin;

create extension if not exists pgtap with schema extensions;
select plan(13);

select ok(
  to_regprocedure('app_private.form_actor_has_export_permission(uuid,text)') is not null
  and exists(
    select 1 from pg_indexes
     where schemaname='app_private'
       and indexname='form_file_download_tokens_one_active_idx'
       and indexdef like '%UNIQUE%'
  ),
  'explicit actor capability helper and one-active-token uniqueness exist'
);

insert into auth.users(id,aud,role,email,created_at,updated_at) values
 ('86000000-0000-4000-8000-000000000001','authenticated','authenticated','forms-export-owner@test.invalid',now(),now()),
 ('86000000-0000-4000-8000-000000000002','authenticated','authenticated','forms-export-content@test.invalid',now(),now());
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('86100000-0000-4000-8000-000000000001','adult','Export','Owner','Export Owner','active'),
 ('86100000-0000-4000-8000-000000000002','adult','Export','Content','Export Content','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('86100000-0000-4000-8000-000000000001','86000000-0000-4000-8000-000000000001','active'),
 ('86100000-0000-4000-8000-000000000002','86000000-0000-4000-8000-000000000002','active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select '86100000-0000-4000-8000-000000000001',id,'active','platform',false
  from public.platform_roles where code='owner';
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select '86100000-0000-4000-8000-000000000002',id,'active','platform',false
  from public.platform_roles where code='content';
insert into public.institutions(id,public_name,legal_name,slug,status)
values ('86200000-0000-4000-8000-000000000001','Export Kind','Export Kind','forms-export-kind','active');
insert into public.forms(
 id,institution_id,kind,identity_mode,response_unit,title,created_by_person_id,updated_by_person_id
) values (
 '86300000-0000-4000-8000-000000000001','86200000-0000-4000-8000-000000000001',
 'form','anonymous','person','Export Kind','86100000-0000-4000-8000-000000000001',
 '86100000-0000-4000-8000-000000000001'
);
insert into public.form_file_jobs(
 id,institution_id,form_id,requested_by_person_id,request_id,export_kind,state,progress,artifact_path,expires_at
) values
 ('86400000-0000-4000-8000-000000000001','86200000-0000-4000-8000-000000000001','86300000-0000-4000-8000-000000000001','86100000-0000-4000-8000-000000000001','86500000-0000-4000-8000-000000000001','csv','succeeded',1,'aa/86600000-0000-4000-8000-000000000001',now()+interval '1 hour'),
 ('86400000-0000-4000-8000-000000000002','86200000-0000-4000-8000-000000000001','86300000-0000-4000-8000-000000000001','86100000-0000-4000-8000-000000000001','86500000-0000-4000-8000-000000000002','anonymous_participation','succeeded',1,'aa/86600000-0000-4000-8000-000000000002',now()+interval '1 hour'),
 ('86400000-0000-4000-8000-000000000003','86200000-0000-4000-8000-000000000001','86300000-0000-4000-8000-000000000001','86100000-0000-4000-8000-000000000002','86500000-0000-4000-8000-000000000003','csv','succeeded',1,'aa/86600000-0000-4000-8000-000000000003',now()+interval '1 hour'),
 ('86400000-0000-4000-8000-000000000004','86200000-0000-4000-8000-000000000001','86300000-0000-4000-8000-000000000001','86100000-0000-4000-8000-000000000002','86500000-0000-4000-8000-000000000004','anonymous_participation','succeeded',1,'aa/86600000-0000-4000-8000-000000000004',now()+interval '1 hour');

create temporary table forms_export_hardening_results(key text primary key,result jsonb);
grant select,insert,update on forms_export_hardening_results to authenticated,service_role;

set local role authenticated;
select set_config('request.jwt.claim.sub','86000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"86000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}',true);

select is(
  jsonb_array_length(public.form_list_file_jobs(jsonb_build_object(
    'form_id','86300000-0000-4000-8000-000000000001','limit',25
  ))->'items'),
  2,
  'Owner with both capabilities lists response and anonymous participation exports'
);

insert into forms_export_hardening_results
select 'first',public.form_authorize_file_job_download('86400000-0000-4000-8000-000000000002');
select ok(
  (select result ? 'download_token' and not result ? 'storage_path'
     from forms_export_hardening_results where key='first'),
  'anonymous participation export issues only an opaque token to Owner'
);

insert into forms_export_hardening_results
select 'second',public.form_authorize_file_job_download('86400000-0000-4000-8000-000000000002');
reset role;
select is(
  (select count(*)::integer
     from app_private.form_file_download_tokens
    where file_job_id='86400000-0000-4000-8000-000000000002'
      and actor_person_id='86100000-0000-4000-8000-000000000001'
      and consumed_at is null),
  1,
  'sequential issuance leaves at most one active token per job and actor'
);
select ok(
  not exists(
    select 1 from app_private.form_file_download_tokens token_row
    join forms_export_hardening_results first_result on first_result.key='first'
    where token_row.token_hash=encode(digest(first_result.result->>'download_token','sha256'),'hex')
      and token_row.consumed_at is null
  ),
  'a newer token invalidates the previous active token'
);

update public.platform_role_permissions grant_row
   set status='inactive',revoked_at=now()
  from public.platform_roles role_row,public.platform_permissions permission_row
 where role_row.id=grant_row.role_id and role_row.code='owner'
   and permission_row.id=grant_row.permission_id
   and permission_row.code='forms.anonymous_participation.export';

set local role authenticated;
select is(
  jsonb_array_length(public.form_list_file_jobs(jsonb_build_object(
    'form_id','86300000-0000-4000-8000-000000000001','limit',25
  ))->'items'),
  1,
  'revoking anonymous export capability removes only that export kind from the list'
);
select throws_ok(
  $$select public.form_authorize_file_job_download('86400000-0000-4000-8000-000000000002')$$,
  '42501',
  'Owner role and forms.anonymous_participation.export required',
  'revoked anonymous export capability blocks new token issuance'
);

reset role;
set local role service_role;
select is(
  public.form_redeem_file_job_download(
    (select (result->>'download_token')::uuid
       from forms_export_hardening_results where key='second')
  ),
  null::jsonb,
  'revocation after issuance blocks and consumes anonymous token redemption'
);

reset role;
select ok(
  (select consumed_at is not null
     from app_private.form_file_download_tokens token_row
     join forms_export_hardening_results second_result on second_result.key='second'
       and token_row.token_hash=encode(digest(second_result.result->>'download_token','sha256'),'hex')),
  'a token denied during redemption cannot become usable after regrant'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','86000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"86000000-0000-4000-8000-000000000002","aal":"aal1","role":"authenticated"}',true);
select is(
  jsonb_array_length(public.form_list_file_jobs(jsonb_build_object(
    'form_id','86300000-0000-4000-8000-000000000001','limit',25
  ))->'items'),
  1,
  'content actor lists response exports but never anonymous participation exports'
);
select throws_ok(
  $$select public.form_authorize_file_job_download('86400000-0000-4000-8000-000000000004')$$,
  '42501',
  'Owner role and forms.anonymous_participation.export required',
  'non-Owner cannot authorize an anonymous participation export'
);

insert into forms_export_hardening_results
select 'content_response',public.form_authorize_file_job_download('86400000-0000-4000-8000-000000000003');
select ok(
  (select result ? 'download_token' from forms_export_hardening_results where key='content_response'),
  'responses export remains authorized by forms.responses.export'
);

reset role;
update public.platform_role_permissions grant_row
   set status='inactive',revoked_at=now()
  from public.platform_roles role_row,public.platform_permissions permission_row
 where role_row.id=grant_row.role_id and role_row.code='content'
   and permission_row.id=grant_row.permission_id
   and permission_row.code='forms.responses.export';

set local role service_role;
select is(
  public.form_redeem_file_job_download(
    (select (result->>'download_token')::uuid
       from forms_export_hardening_results where key='content_response')
  ),
  null::jsonb,
  'revoking responses export capability blocks an already-issued response token'
);

reset role;
select * from finish();
rollback;
