-- Prova pgTAP da migration 20260920110000_unit_form_institution_slug_v1 (lote 108):
-- get_unit_form_for_superadmin devolve institution_slug em cada opcao de instituicao.
begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into public.institution_types(id,code,name,status) values ('9d100000-0000-4000-8000-000000000001','us-test','US test','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9d100000-0000-4000-8000-000000000010','Colégio Horizonte US','colegio-horizonte-us','active','9d100000-0000-4000-8000-000000000001');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9d100000-0000-4000-8000-000000000101','authenticated','authenticated','us-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9d100000-0000-4000-8000-000000000201','9d100000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values ('9d100000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9d100000-0000-4000-8000-000000000401','9d100000-0000-4000-8000-000000000301','9d100000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '9d100000-0000-4000-8000-000000000501','9d100000-0000-4000-8000-000000000301',r.id,'platform' from public.platform_roles r where r.code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r cross join public.platform_permissions p
where r.code='owner' and p.code in ('units.read')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
select set_config('request.jwt.claims',jsonb_build_object('sub','9d100000-0000-4000-8000-000000000101',
 'session_id','9d100000-0000-4000-8000-000000000201','aal','aal1','role','authenticated')::text,true);

create temporary table r(label text primary key, body jsonb not null);
insert into r values('form', public.get_unit_form_for_superadmin(null));
select is((select body->>'not_found' from r where label='form'),'false','formulario responde');
select is((select i->>'institution_slug' from r, jsonb_array_elements(body->'institutions') i
  where label='form' and i->>'institution_id'='9d100000-0000-4000-8000-000000000010'),
  'colegio-horizonte-us','opcao de instituicao traz institution_slug (= @ da instituicao)');
select is((select i->>'institution_name' from r, jsonb_array_elements(body->'institutions') i
  where label='form' and i->>'institution_id'='9d100000-0000-4000-8000-000000000010'),
  'Colégio Horizonte US','institution_name continua');

select * from finish();
rollback;
