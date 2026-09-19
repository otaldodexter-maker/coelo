-- Prova pgTAP da migration 20260920050000_people_list_suspension_v1: o item do diretório de
-- pessoas expõe a suspensão (spec 066 §3). Fixture com rollback total (prefixo 9d2).
begin;
create extension if not exists pgtap with schema extensions;
select plan(3);
select ok(position('suspended_now' in pg_get_functiondef('public.superadmin_people_list'::regproc))>0,'people_list exposes suspended_now');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9d200000-0000-4000-8000-000000000101','authenticated','authenticated','ps-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9d200000-0000-4000-8000-000000000201','9d200000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour');
insert into public.people(id,person_type,first_name,last_name,display_name,status,suspended_from,suspended_until,suspension_reason) values
 ('9d200000-0000-4000-8000-000000000401','adult','PS','Suspensa','PS Suspensa Zz','active',now()-interval '1 hour',now()+interval '1 day','prova');
insert into app_private.superadmin_internal_identities(id) values ('9d200000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9d200000-0000-4000-8000-000000000501','9d200000-0000-4000-8000-000000000301','9d200000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select '9d200000-0000-4000-8000-000000000601','9d200000-0000-4000-8000-000000000301',r.id,'platform',null from public.platform_roles r where r.code='owner';
select set_config('request.jwt.claims',jsonb_build_object('sub','9d200000-0000-4000-8000-000000000101',
 'session_id','9d200000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);
select set_config('request.jwt.claim.sub','9d200000-0000-4000-8000-000000000101',true);
create temporary table r(body jsonb);
insert into r select public.superadmin_people_list('PS Suspensa Zz','{}','{}','{}','{}','{}','{}','{}','display_name',true,0,20,null,'{}','{}','{}','{}');
select is((select body#>'{items}'->0->>'suspended_now' from r),'true','directory item says suspended_now');
select ok((select (body#>'{items}'->0->>'suspended_until')::timestamptz > now() from r),'directory item carries suspended_until');
select * from finish();
rollback;
