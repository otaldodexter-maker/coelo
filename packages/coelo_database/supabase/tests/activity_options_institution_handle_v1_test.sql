-- Prova pgTAP da migration 20260920033000_activity_options_institution_handle_v1 (lote 101):
-- as opcoes de instituicao do formulario de atividades trazem `handle` (= slug) para a previa do @.
begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into public.institution_types(id,code,name,status) values ('9c900000-0000-4000-8000-000000000001','oh-test','OH test','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9c900000-0000-4000-8000-000000000010','OH Instituicao','oh-inst','active','9c900000-0000-4000-8000-000000000001');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9c900000-0000-4000-8000-000000000101','authenticated','authenticated','oh-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9c900000-0000-4000-8000-000000000201','9c900000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values ('9c900000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9c900000-0000-4000-8000-000000000401','9c900000-0000-4000-8000-000000000301','9c900000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '9c900000-0000-4000-8000-000000000501','9c900000-0000-4000-8000-000000000301',r.id,'platform' from public.platform_roles r where r.code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r cross join public.platform_permissions p where r.code='owner'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
select set_config('request.jwt.claims',jsonb_build_object('sub','9c900000-0000-4000-8000-000000000101',
 'session_id','9c900000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);

create temporary table r(label text primary key, body jsonb not null);
insert into r values('tpl', public.superadmin_activity_template_options('9c900000-0000-4000-8000-000000000010'));
select is((select i->>'handle' from r, jsonb_array_elements(body->'institutions') i where label='tpl' and i->>'id'='9c900000-0000-4000-8000-000000000010'),
  'oh-inst','template_options: instituicao traz handle = slug');
insert into r values('flt', public.superadmin_activity_filter_options_v2());
select is((select body->>'ok' from r where label='flt'),'true','filter_options_v2 responde');
select is((select i->>'handle' from r, jsonb_array_elements(body#>'{data,institutions}') i where label='flt' and i->>'id'='9c900000-0000-4000-8000-000000000010'),
  'oh-inst','filter_options_v2: instituicao traz handle = slug');

select * from finish();
rollback;
