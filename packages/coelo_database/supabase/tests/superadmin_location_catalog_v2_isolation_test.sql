-- Prepared local replay only. No mutation of global isolation defaults or Auth helpers.
begin isolation level repeatable read;
create extension if not exists pgtap with schema extensions;
select no_plan();
insert into public.institution_types(id,code,name,status)
values('91000000-0000-4000-8000-000000000001','location-isolation-type','Location isolation type','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id)
values('91100000-0000-4000-8000-000000000001','Location isolation institution','location-isolation',
  'active','91000000-0000-4000-8000-000000000001');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values('91300000-0000-4000-8000-000000000001','authenticated','authenticated',
  'location-isolation@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values('91400000-0000-4000-8000-000000000001','91300000-0000-4000-8000-000000000001',
  now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id)
values('91500000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,status)
values('91600000-0000-4000-8000-000000000001','91500000-0000-4000-8000-000000000001',
  '91300000-0000-4000-8000-000000000001','active');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,status)
select '91700000-0000-4000-8000-000000000001','91500000-0000-4000-8000-000000000001',
  id,'platform','active' from public.platform_roles where code='owner';
create temporary table location_isolation_responses(seq integer primary key,body jsonb);
grant insert on location_isolation_responses to authenticated;
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','91300000-0000-4000-8000-000000000001','session_id','91400000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into location_isolation_responses values
  (1,public.superadmin_location_create_v2(jsonb_build_object(
    'scope_kind','institution','institution_id','91100000-0000-4000-8000-000000000001',
    'unit_id',null,'name','Isolation room','description',null,'kind','internal',
    'floor',null,'address',null,'visibility','team'),'91800000-0000-4000-8000-000000000001')),
  (2,public.superadmin_location_detail_v2('91900000-0000-4000-8000-000000000001')),
  (3,public.superadmin_location_directory_v2('institution','91100000-0000-4000-8000-000000000001'));
reset role;
select is(current_setting('transaction_isolation'),'repeatable read','test really uses incompatible isolation');
select is((select body#>>'{error,code}' from location_isolation_responses where seq=1),
  'SAI_INVALID_ARGUMENT','create rejects incompatible isolation');
select is((select body#>>'{error,code}' from location_isolation_responses where seq=2),
  'SAI_INVALID_ARGUMENT','detail rejects incompatible isolation');
select is((select body#>>'{error,code}' from location_isolation_responses where seq=3),
  'SAI_INVALID_ARGUMENT','directory rejects incompatible isolation');
select ok((select bool_and(body->>'ok'='false' and body->'data'='null'::jsonb)
  from location_isolation_responses),'incompatible isolation exposes no data');
select is((select count(*) from app_private.superadmin_location_create_receipts
  where actor_internal_identity_id='91500000-0000-4000-8000-000000000001'),0::bigint,
  'incompatible isolation creates no receipt');
select * from finish();
rollback;
