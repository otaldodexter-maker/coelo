-- R06 estrutura: superadmin_activity_detail_v2 devolve o @ da atividade
-- (handle_stem, canonical_handle, handle_last_changed_at) no objeto activity.
begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into public.institution_types(id,code,name,status) values
 ('9f0d0000-0000-4000-8000-000000000001','detail-handle','Detail handle','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9f0d0000-0000-4000-8000-000000000010','Escola Delta','escoladelta','active','9f0d0000-0000-4000-8000-000000000001');
insert into public.unit_types(id,code,name,status) values ('9f0d0000-0000-4000-8000-000000000002','dh-unit','Unidade DH','active');
insert into public.units(id,institution_id,unit_type_id,name,slug,status,handle) values
 ('9f0d0000-0000-4000-8000-000000000011','9f0d0000-0000-4000-8000-000000000010','9f0d0000-0000-4000-8000-000000000002','Norte','norte','active','norte.escoladelta');
insert into public.activity_taxonomies(id,code,name,status,taxonomy_kind) values
 ('9f0d0000-0000-4000-8000-000000000003','dh-esporte','Esporte DH','active','category');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f0d0000-0000-4000-8000-000000000101','authenticated','authenticated','dh-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9f0d0000-0000-4000-8000-000000000201','9f0d0000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values ('9f0d0000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f0d0000-0000-4000-8000-000000000401','9f0d0000-0000-4000-8000-000000000301','9f0d0000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '9f0d0000-0000-4000-8000-000000000501','9f0d0000-0000-4000-8000-000000000301',r.id,'platform' from public.platform_roles r where r.code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r cross join public.platform_permissions p where r.code='owner'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
select set_config('request.jwt.claims',jsonb_build_object('sub','9f0d0000-0000-4000-8000-000000000101','session_id','9f0d0000-0000-4000-8000-000000000201','aal','aal1','role','authenticated')::text,true);

create temporary table dh(label text primary key, body jsonb not null);
grant select,insert on dh to authenticated;

set local role authenticated;
insert into dh values('a1', public.superadmin_activity_create_v2('9f0d0000-0000-4000-8000-000000000901',
  '{"institution_id":"9f0d0000-0000-4000-8000-000000000010","name":"Xadrez","initials":"XA","taxonomy_id":"9f0d0000-0000-4000-8000-000000000003","unit_ids":["9f0d0000-0000-4000-8000-000000000011"],"handle":"@Xadrez.Norte"}'));
insert into dh values('d1', public.superadmin_activity_detail_v2((select (body#>>'{data,activity_id}')::uuid from dh where label='a1'), '{}'));
reset role;

select is((select body#>>'{data,activity,handle_stem}' from dh where label='d1'),'xadrez','detail_v2 devolve handle_stem');
select is((select body#>>'{data,activity,canonical_handle}' from dh where label='d1'),'xadrez.escoladelta','detail_v2 devolve canonical_handle');
select ok((select body#>'{data,activity}' ? 'handle_last_changed_at' from dh where label='d1'),'detail_v2 devolve handle_last_changed_at');

select * from finish();
rollback;
