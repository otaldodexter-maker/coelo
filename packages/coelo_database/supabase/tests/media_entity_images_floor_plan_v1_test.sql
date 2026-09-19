-- Prova pgTAP da migration 20260920070000_media_entity_images_floor_plan_v1 (planta baixa, spec 067).
-- Fixture sintética com rollback (prefixo f1): instituição A (unidade A1, turma A1) e B.
-- P: owner de plataforma com escopo em A. Q: owner com escopo em B. G1: responsável com can_view em A.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

create function pg_temp.f1(n integer) returns uuid language sql immutable as $$
  select ('f1000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
create function pg_temp.as_user(n integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', pg_temp.f1(n)::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.f1(n)::text, 'role', 'authenticated', 'aal', 'aal1')::text, true);
end $$;
create function pg_temp.as_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'service_role', true);
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
end $$;
create function pg_temp.asset_of(req integer) returns uuid language sql stable as $$
  select id from public.entity_image_assets where request_id = pg_temp.f1(req);
$$;
create function pg_temp.activate(req integer) returns void language plpgsql as $$
declare a public.entity_image_assets%rowtype;
begin
  select * into a from public.entity_image_assets where request_id = pg_temp.f1(req);
  perform pg_temp.as_service();
  perform public.superadmin_entity_image_finalize_v1(a.id, a.finalize_ticket, a.byte_size, a.checksum_sha256);
end $$;

insert into public.institution_types(id,code,name,status) values (pg_temp.f1(1),'f1-type','F1 type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.f1(2),'f1-unit','F1 unit','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status,timezone) values
 (pg_temp.f1(10),pg_temp.f1(1),'F1 Instituicao A','f1-a','active','America/Sao_Paulo'),
 (pg_temp.f1(20),pg_temp.f1(1),'F1 Instituicao B','f1-b','active','America/Sao_Paulo');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status,timezone) values
 (pg_temp.f1(11),pg_temp.f1(10),'F1 Unidade A1','f1-unidade-a1','f1unidade.a1',pg_temp.f1(2),'active','America/Sao_Paulo');
insert into public.groups(id,institution_id,unit_id,name,status) values
 (pg_temp.f1(12),pg_temp.f1(10),pg_temp.f1(11),'F1 Turma A1','active');
insert into auth.users(id) values (pg_temp.f1(101)),(pg_temp.f1(102)),(pg_temp.f1(104));
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.f1(201),'adult','F1','Ator P','F1 Ator P','active'),
 (pg_temp.f1(202),'adult','F1','Ator Q','F1 Ator Q','active'),
 (pg_temp.f1(204),'adult','F1','Resp G1','F1 Resp G1','active'),
 (pg_temp.f1(221),'child','F1','Crianca A','F1 Crianca A','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.f1(201),pg_temp.f1(101),'active'),(pg_temp.f1(202),pg_temp.f1(102),'active'),(pg_temp.f1(204),pg_temp.f1(104),'active');
insert into public.platform_memberships(id,person_id,role_id,status,scope_kind,scope_institution_id)
select pg_temp.f1(301),pg_temp.f1(201),r.id,'active','institution',pg_temp.f1(10) from public.platform_roles r where r.code='owner' and r.is_system;
insert into public.platform_memberships(id,person_id,role_id,status,scope_kind,scope_institution_id)
select pg_temp.f1(302),pg_temp.f1(202),r.id,'active','institution',pg_temp.f1(20) from public.platform_roles r where r.code='owner' and r.is_system;
insert into public.child_contexts(id,child_person_id,institution_id,status) values (pg_temp.f1(401),pg_temp.f1(221),pg_temp.f1(10),'active');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,relationship_type_id,status) values
 (pg_temp.f1(411),pg_temp.f1(204),pg_temp.f1(221),'responsavel',(select id from public.family_relationship_types where code='other' and status='active'),'active');
insert into public.guardian_context_permissions(guardian_link_id,child_context_id,can_view,status) values (pg_temp.f1(411),pg_temp.f1(401),true,'active');

-- caminho feliz: planta da instituição e da unidade (raster) --------------------------------------
select pg_temp.as_user(101);
select lives_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.f1(500),'institution',pg_temp.f1(10),'floor_plan','planta.png','image/png',2048,repeat('a',64))$$,
  'P prepares the institution floor plan (png)');
select is((select object_key from public.entity_image_assets where request_id=pg_temp.f1(500)),
  'entities/institution/'||pg_temp.f1(10)::text||'/floor_plan/'||pg_temp.asset_of(500)::text||'.png','floor plan key lives under floor_plan');
select lives_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.f1(501),'unit',pg_temp.f1(11),'floor_plan','planta.jpg','image/jpeg',2048,repeat('b',64))$$,
  'P prepares the unit floor plan (jpeg)');
select pg_temp.activate(500);
select pg_temp.activate(501);
select pg_temp.as_user(101);
select is((select public.superadmin_entity_images_get_v1('institution',pg_temp.f1(10)) -> 'floor_plan' ->> 'asset_id'), pg_temp.asset_of(500)::text,
  'institution images expose the active floor plan');
select is((select public.superadmin_entity_images_list_v1('unit',array[pg_temp.f1(11)]) -> pg_temp.f1(11)::text -> 'floor_plan' ->> 'content_type'), 'image/jpeg',
  'batch list carries the unit floor plan');
select lives_ok($$select public.superadmin_entity_image_authorize_read_v1(pg_temp.asset_of(501))$$, 'P reads the unit floor plan through the Edge');
-- substituição: a planta nova inativa a anterior
select lives_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.f1(502),'unit',pg_temp.f1(11),'floor_plan','planta2.webp','image/webp',4096,repeat('c',64))$$,
  'P prepares a replacement floor plan');
select pg_temp.activate(502);
select is((select status from public.entity_image_assets where request_id=pg_temp.f1(501)), 'inactive', 'previous floor plan is inactivated by the new one');

-- negativas ----------------------------------------------------------------------------------------
select pg_temp.as_user(101);
select throws_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.f1(510),'group',pg_temp.f1(12),'floor_plan','planta.png','image/png',2048,repeat('d',64))$$,
  '22023','invalid_entity_image','floor plan is refused for a group');
select throws_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.f1(511),'institution',pg_temp.f1(10),'floor_plan','planta.svg','image/svg+xml',2048,repeat('e',64))$$,
  '22023','invalid_entity_image','svg is refused for the floor plan');
select throws_ok($$insert into public.entity_image_assets(entity_kind,entity_id,image_kind,tenant_id,object_key,mime_type,byte_size,request_id,created_by_person_id)
  values ('group',pg_temp.f1(12),'floor_plan',pg_temp.f1(10),'entities/group/'||pg_temp.f1(12)::text||'/floor_plan/'||gen_random_uuid()::text||'.png','image/png',10,gen_random_uuid(),pg_temp.f1(201))$$,
  '23514',null,'floor plan is refused for a group by the table constraint too');
select pg_temp.as_user(102);
select throws_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.f1(512),'institution',pg_temp.f1(10),'floor_plan','planta.png','image/png',2048,repeat('f',64))$$,
  '42501','entity_image_denied','Q (tenant B) cannot upload a floor plan for A');
select throws_ok($$select public.superadmin_entity_image_authorize_read_v1(pg_temp.asset_of(500))$$, '42501', null, 'Q cannot read the floor plan of A');
-- leitor do Principal: responsável com can_view lê a planta (Locais no Principal, Etapa 4)
select pg_temp.as_user(104);
select is((select public.principal_entity_images_list_v1('institution',array[pg_temp.f1(10)]) -> pg_temp.f1(10)::text -> 'floor_plan' ->> 'asset_id'), pg_temp.asset_of(500)::text,
  'G1 (guardian with can_view) lists the institution floor plan');

select * from finish();
rollback;
