-- Prepared isolation RED contract; only Eng1 may execute on the nominal local base.
begin isolation level repeatable read;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values('8f021000-0000-4000-8000-000000000101','authenticated','authenticated','fauthor-isolation@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values('8f021000-0000-4000-8000-000000000201','8f021000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values('8f021000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
values('8f021000-0000-4000-8000-000000000401','8f021000-0000-4000-8000-000000000301','8f021000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '8f021000-0000-4000-8000-000000000501','8f021000-0000-4000-8000-000000000301',id,'platform'
from public.platform_roles where code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r cross join public.platform_permissions p
where r.code='owner' and p.code in('forms.manage','forms.read')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
create temporary table fauthor_isolation_results(label text,body jsonb,executed_as text);
grant select,insert on fauthor_isolation_results to authenticated;
select set_config('request.jwt.claims','{"sub":"8f021000-0000-4000-8000-000000000101","session_id":"8f021000-0000-4000-8000-000000000201","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into fauthor_isolation_results values
 ('reader',public.superadmin_forms_editor_v2('8f021000-0000-4000-8000-000000000701'),current_user),
 ('save',public.superadmin_forms_save_draft_v2('8f021000-0000-4000-8000-000000000801',0,
 '{"id":"8f021000-0000-4000-8000-000000000701","institution_id":"8f021000-0000-4000-8000-000000000010","kind":"form","identity_mode":"identified","response_unit":"person","title":"Isolation fixture","sections":[]}'),current_user);
reset role;
select is(current_setting('transaction_isolation'),'repeatable read','test uses the unsupported snapshot isolation');
select is(body#>>'{error,code}','SAI_INVALID_ARGUMENT',label||' rejects unsupported isolation before resource lookup') from fauthor_isolation_results;
select is(body->'data','null'::jsonb,label||' returns no snapshot') from fauthor_isolation_results;
select is((select count(*) from audit.audit_logs a where a.correlation_id=(r.body#>>'{error,correlation_id}')::uuid
 and a.outcome='denied' and a.reason_code='SAI_INVALID_ARGUMENT'),1::bigint,r.label||' rejection is audited') from fauthor_isolation_results r;
select ok(not exists(select 1 from public.forms where id='8f021000-0000-4000-8000-000000000701'),'unsupported isolation creates no form');
select ok(not exists(select 1 from app_private.superadmin_internal_form_draft_receipts where request_id='8f021000-0000-4000-8000-000000000801'),'unsupported isolation creates no receipt');
select ok((select bool_and(executed_as='authenticated') from fauthor_isolation_results),'RPCs execute as authenticated');
select * from finish();
rollback;
