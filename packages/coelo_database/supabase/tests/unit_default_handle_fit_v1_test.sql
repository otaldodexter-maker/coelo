-- 211400: @ padrao de unidade cabe em 30 caracteres com o slug da instituicao sem hifens
-- (caso da G2: "unidadeqar05transfer.qa-r04-cu").
begin;
create extension if not exists pgtap with schema extensions;
select plan(5);
insert into public.institution_types(id,code,name,status) values ('9f0b0000-0000-4000-8000-000000000001','ufit','U fit','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9f0b0000-0000-4000-8000-000000000010','QA R04 Cuidado','qa-r04-cuidado-sintetico','active','9f0b0000-0000-4000-8000-000000000001');
insert into public.unit_types(id,code,name,status) values ('9f0b0000-0000-4000-8000-000000000002','ufit-unit','Unidade fit','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f0b0000-0000-4000-8000-000000000101','authenticated','authenticated','ufit-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9f0b0000-0000-4000-8000-000000000201','9f0b0000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values ('9f0b0000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f0b0000-0000-4000-8000-000000000401','9f0b0000-0000-4000-8000-000000000301','9f0b0000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '9f0b0000-0000-4000-8000-000000000501','9f0b0000-0000-4000-8000-000000000301',r.id,'platform' from public.platform_roles r where r.code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r cross join public.platform_permissions p where r.code='owner' and p.code in ('units.create','units.read')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
select set_config('request.jwt.claims',jsonb_build_object('sub','9f0b0000-0000-4000-8000-000000000101','session_id','9f0b0000-0000-4000-8000-000000000201','aal','aal1','role','authenticated')::text,true);

create temporary table uf(label text primary key, body jsonb not null);
insert into uf values('u1', app_private.create_unit_for_superadmin('9f0b0000-0000-4000-8000-000000000911',
  '{"institution_id":"9f0b0000-0000-4000-8000-000000000010","name":"Unidade QA R05 Transfer","slug":"unidade-qa-r05-transfer","unit_type_id":"9f0b0000-0000-4000-8000-000000000002"}'));
select is((select handle from public.units where slug='unidade-qa-r05-transfer'),'unidadeq.qar04cuidadosintetico','o caso da G2 cabe em 30: segmento da unidade truncado, sufixo inteiro e sem hifens');
select ok((select handle ~ '^[a-z0-9][a-z0-9._]{1,28}[a-z0-9]$' and length(handle)<=30 from public.units where slug='unidade-qa-r05-transfer'),'respeita units_handle_normalized_check');
insert into uf values('u2', app_private.create_unit_for_superadmin('9f0b0000-0000-4000-8000-000000000912',
  '{"institution_id":"9f0b0000-0000-4000-8000-000000000010","name":"Unidade QA R05 Transfer","slug":"unidade-qa-r05-transfer-2","unit_type_id":"9f0b0000-0000-4000-8000-000000000002"}'));
select ok((select handle ~ '^[a-z0-9]{1,5}\.qar04cuidadosintetico_[0-9a-f]{4}$' and length(handle)<=30 from public.units where slug='unidade-qa-r05-transfer-2'),'colisao abre espaco para o sufixo _xxxx sem passar de 30');
insert into uf values('u3', app_private.create_unit_for_superadmin('9f0b0000-0000-4000-8000-000000000913',
  '{"institution_id":"9f0b0000-0000-4000-8000-000000000010","name":"Sede","slug":"sede","unit_type_id":"9f0b0000-0000-4000-8000-000000000002","handle":"@sede.cuidado"}'));
select is((select handle from public.units where slug='sede'),'sede.cuidado','handle explicito continua respeitado');
select is((select count(*) from public.units where institution_id='9f0b0000-0000-4000-8000-000000000010'),3::bigint,'tres unidades criadas sem violar a check');
select * from finish();
rollback;
