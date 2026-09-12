-- R06 estrutura: superadmin_assessment_configuration_read deixa de responder
-- SAI_INTERNAL_ERROR (ambiguidade variavel x coluna) e devolve data null para
-- atividade sem configuracao; outro tenant / id inexistente continuam nulos.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into public.institution_types(id,code,name,status) values
 ('9f0c0000-0000-4000-8000-000000000001','cfg-read','Cfg read','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9f0c0000-0000-4000-8000-000000000010','Escola Cfg','escolacfg','active','9f0c0000-0000-4000-8000-000000000001');
insert into public.unit_types(id,code,name,status) values ('9f0c0000-0000-4000-8000-000000000002','cfg-unit','Unidade Cfg','active');
insert into public.units(id,institution_id,unit_type_id,name,slug,status,handle) values
 ('9f0c0000-0000-4000-8000-000000000011','9f0c0000-0000-4000-8000-000000000010','9f0c0000-0000-4000-8000-000000000002','Norte','norte','active','norte.escolacfg');
insert into public.activity_taxonomies(id,code,name,status,taxonomy_kind) values
 ('9f0c0000-0000-4000-8000-000000000003','cfg-esporte','Esporte Cfg','active','category');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f0c0000-0000-4000-8000-000000000101','authenticated','authenticated','cfg-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9f0c0000-0000-4000-8000-000000000201','9f0c0000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values ('9f0c0000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f0c0000-0000-4000-8000-000000000401','9f0c0000-0000-4000-8000-000000000301','9f0c0000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '9f0c0000-0000-4000-8000-000000000501','9f0c0000-0000-4000-8000-000000000301',r.id,'platform' from public.platform_roles r where r.code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r cross join public.platform_permissions p where r.code='owner'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
select set_config('request.jwt.claims',jsonb_build_object('sub','9f0c0000-0000-4000-8000-000000000101','session_id','9f0c0000-0000-4000-8000-000000000201','aal','aal1','role','authenticated')::text,true);

create temporary table cfg(label text primary key, body jsonb not null);
grant select,insert on cfg to authenticated;

set local role authenticated;
insert into cfg values('a1', public.superadmin_activity_create_v2('9f0c0000-0000-4000-8000-000000000901',
  '{"institution_id":"9f0c0000-0000-4000-8000-000000000010","name":"Xadrez","initials":"XA","taxonomy_id":"9f0c0000-0000-4000-8000-000000000003","unit_ids":["9f0c0000-0000-4000-8000-000000000011"]}'));
insert into cfg values('r1', public.superadmin_assessment_configuration_read((select (body#>>'{data,activity_id}')::uuid from cfg where label='a1'), null));
insert into cfg values('r2', public.superadmin_assessment_configuration_read((select (body#>>'{data,activity_id}')::uuid from cfg where label='a1'), '9f0c0000-0000-4000-8000-000000000011'));
insert into cfg values('r3', public.superadmin_assessment_configuration_read('9f0c0000-0000-4000-8000-0000000000ff', null));
reset role;

select is((select body->>'ok' from cfg where label='r1'),'true','configuration_read responde ok (sem ambiguidade variavel x coluna)');
select is((select body->'data' from cfg where label='r1'),'null'::jsonb,'atividade sem configuracao devolve data null');
select is((select body->>'ok' from cfg where label='r2'),'true','com unidade valida tambem responde ok');
select is((select body->'data' from cfg where label='r3'),'null'::jsonb,'id inexistente nao enumera (data null)');

select * from finish();
rollback;
