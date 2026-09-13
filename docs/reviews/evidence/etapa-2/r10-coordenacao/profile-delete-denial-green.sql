-- Current mirror, synthetic fixtures, rollback. No remote mutation.
begin;
ALTER TABLE app_private.access_profile_catalog_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.access_profile_catalog_versions FORCE ROW LEVEL SECURITY;

ALTER TABLE app_private.access_profile_command_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.access_profile_command_receipts FORCE ROW LEVEL SECURITY;

ALTER TABLE app_private.access_profile_command_receipts_v2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.access_profile_command_receipts_v2 FORCE ROW LEVEL SECURITY;

select plan(7);
select is(md5(pg_get_functiondef('app_private.superadmin_access_profile_delete_and_reassign(uuid,text,uuid,bigint,uuid,text)'::regprocedure)), '5df18df346e79ea81166d2fcdf5afd31', 'delete body matches production');
select is(md5(pg_get_functiondef('app_private.access_profile_require_mutation(text)'::regprocedure)), '939d16f826329a4c6394ab13fd6d7f97', 'mutation guard matches production');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values('a1100000-0000-4000-8000-000000000001','authenticated','authenticated','r10-no-authority@invalid.test',now(),now(),now(),'{}','{}');
insert into public.people(id,person_type,first_name,last_name,display_name)
values('a1100000-0000-4000-8000-000000000002','adult','R10','Synthetic','R10 Synthetic');
insert into public.person_auth_links(id,person_id,auth_user_id)
values('a1100000-0000-4000-8000-000000000003','a1100000-0000-4000-8000-000000000002','a1100000-0000-4000-8000-000000000001');
insert into public.platform_roles(id,code,name,max_scope_kind)
values('a1100000-0000-4000-8000-000000000004','r10_denial_target','R10 denial target','platform');
set local role authenticated;
select throws_ok($$select public.superadmin_access_profile_delete_and_reassign('a1100000-0000-4000-8000-000000000005','platform','a1100000-0000-4000-8000-000000000004',1,null,'R10 negative')$$,'42501','profile management permission required','missing identity cannot delete');
select set_config('request.jwt.claims','{"sub":"a1100000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
select throws_ok($$select public.superadmin_access_profile_delete_and_reassign('a1100000-0000-4000-8000-000000000006','platform','a1100000-0000-4000-8000-000000000004',1,null,'R10 negative')$$,'42501','profile management permission required','existing identity without capability cannot delete another profile');
reset role;
select is((select count(*) from public.platform_roles where id='a1100000-0000-4000-8000-000000000004'),1::bigint,'target retained after denials');
select is((select count(*) from app_private.access_profile_command_receipts_v2 where request_id in ('a1100000-0000-4000-8000-000000000005','a1100000-0000-4000-8000-000000000006')),0::bigint,'denials create no receipt');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='app_private.access_profile_command_receipts_v2'::regclass),'private receipts remain FORCE RLS');
select * from finish();
rollback;
