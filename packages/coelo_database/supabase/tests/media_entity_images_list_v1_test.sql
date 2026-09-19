-- Prova pgTAP das migrations 20260919210000_media_entity_images_list_v1 (lote 87) e 20260919211000_media_entity_images_expire_cron_v1 (lote 88).
-- Fixture sintética com rollback (prefixo e2): instituição A (unidade A1, turma, atividade) e B (unidade B1).
-- P: owner de plataforma com escopo em A. Q: owner com escopo em B. L: professora em A (só leitura).
-- G1: responsável com guardian_links + can_view em A (sem membership). G2: responsável sem can_view.
begin;
create extension if not exists pgtap with schema extensions;
select plan(34);

create function pg_temp.e2(n integer) returns uuid language sql immutable as $$
  select ('e2000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
create function pg_temp.as_user(n integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', pg_temp.e2(n)::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.e2(n)::text, 'role', 'authenticated', 'aal', 'aal1')::text, true);
end $$;
create function pg_temp.as_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'service_role', true);
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
end $$;
create function pg_temp.asset_of(req integer) returns uuid language sql stable as $$
  select id from public.entity_image_assets where request_id = pg_temp.e2(req);
$$;
create function pg_temp.activate(req integer) returns void language plpgsql as $$
declare a public.entity_image_assets%rowtype;
begin
  select * into a from public.entity_image_assets where request_id = pg_temp.e2(req);
  perform pg_temp.as_service();
  perform public.superadmin_entity_image_finalize_v1(a.id, a.finalize_ticket, a.byte_size, a.checksum_sha256);
end $$;

-- ACL ---------------------------------------------------------------------------------------------
select ok((select bool_and(has_function_privilege('authenticated',p.oid,'execute') and not has_function_privilege('anon',p.oid,'execute'))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
  and p.proname in ('superadmin_entity_images_list_v1','principal_entity_images_list_v1','principal_entity_image_authorize_read_v1')),
  'list/read RPCs: authenticated only');
select ok(not has_function_privilege('authenticated','public.superadmin_entity_image_expire_v1(integer)','execute')
  and has_function_privilege('service_role','public.superadmin_entity_image_expire_v1(integer)','execute'),'expire: service_role only');
select ok(exists(select 1 from cron.job where jobname='coelo-entity-media-expire'),'cron job coelo-entity-media-expire scheduled');
select is((select command from cron.job where jobname='coelo-entity-media-expire'), 'select app_private.entity_image_expire_drafts_v1(200);', 'cron expires drafts directly in Postgres (no Edge, no secret)');
select ok(to_regprocedure('app_private.entity_media_dispatch_expire_worker()') is null, 'lote 87 dispatch function is gone');

-- fixture ------------------------------------------------------------------------------------------
insert into public.institution_types(id,code,name,status) values (pg_temp.e2(1),'e2-type','E2 type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.e2(2),'e2-unit','E2 unit','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status,timezone) values
 (pg_temp.e2(10),pg_temp.e2(1),'E2 Instituicao A','e2-a','active','America/Sao_Paulo'),
 (pg_temp.e2(20),pg_temp.e2(1),'E2 Instituicao B','e2-b','active','America/Sao_Paulo');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status,timezone) values
 (pg_temp.e2(11),pg_temp.e2(10),'E2 Unidade A1','e2-unidade-a1','e2unidade.a1',pg_temp.e2(2),'active','America/Sao_Paulo'),
 (pg_temp.e2(21),pg_temp.e2(20),'E2 Unidade B1','e2-unidade-b1','e2unidade.b1',pg_temp.e2(2),'active','America/Sao_Paulo');
insert into public.groups(id,institution_id,unit_id,name,status) values
 (pg_temp.e2(12),pg_temp.e2(10),pg_temp.e2(11),'E2 Turma A1','active');
-- atividade de fixture: o guard de proveniência interna (marcador v2) não interessa a esta prova
alter table public.activity_definitions disable trigger user;
insert into public.activity_definitions(id,institution_id,name,handle_stem,canonical_handle,origin_scope_kind,distribution_scope,status,management_version)
 values (pg_temp.e2(13),pg_temp.e2(10),'E2 Atividade A','e2-atividade-a','e2.atividade.a','institution','institution_standard','active',1);
alter table public.activity_definitions enable trigger user;
insert into auth.users(id) values (pg_temp.e2(101)),(pg_temp.e2(102)),(pg_temp.e2(103)),(pg_temp.e2(104)),(pg_temp.e2(105));
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.e2(201),'adult','E2','Ator P','E2 Ator P','active'),
 (pg_temp.e2(202),'adult','E2','Ator Q','E2 Ator Q','active'),
 (pg_temp.e2(203),'adult','E2','Leitor L','E2 Leitor L','active'),
 (pg_temp.e2(204),'adult','E2','Resp G1','E2 Resp G1','active'),
 (pg_temp.e2(205),'adult','E2','Resp G2','E2 Resp G2','active'),
 (pg_temp.e2(221),'child','E2','Crianca A','E2 Crianca A','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.e2(201),pg_temp.e2(101),'active'),(pg_temp.e2(202),pg_temp.e2(102),'active'),(pg_temp.e2(203),pg_temp.e2(103),'active'),
 (pg_temp.e2(204),pg_temp.e2(104),'active'),(pg_temp.e2(205),pg_temp.e2(105),'active');
insert into public.platform_memberships(id,person_id,role_id,status,scope_kind,scope_institution_id)
select pg_temp.e2(301),pg_temp.e2(201),r.id,'active','institution',pg_temp.e2(10) from public.platform_roles r where r.code='owner' and r.is_system;
insert into public.platform_memberships(id,person_id,role_id,status,scope_kind,scope_institution_id)
select pg_temp.e2(302),pg_temp.e2(202),r.id,'active','institution',pg_temp.e2(20) from public.platform_roles r where r.code='owner' and r.is_system;
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
 (pg_temp.e2(303),pg_temp.e2(203),pg_temp.e2(10),'teacher','active','institution');
-- responsáveis: G1 com can_view na instituição A; G2 vinculado mas sem can_view
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 (pg_temp.e2(401),pg_temp.e2(221),pg_temp.e2(10),'active');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,relationship_type_id,status) values
 (pg_temp.e2(411),pg_temp.e2(204),pg_temp.e2(221),'responsavel',(select id from public.family_relationship_types where code='other' and status='active'),'active'),
 (pg_temp.e2(412),pg_temp.e2(205),pg_temp.e2(221),'responsavel',(select id from public.family_relationship_types where code='other' and status='active'),'active');
insert into public.guardian_context_permissions(guardian_link_id,child_context_id,can_view,status) values
 (pg_temp.e2(411),pg_temp.e2(401),true,'active'),
 (pg_temp.e2(412),pg_temp.e2(401),false,'active');

-- ícone vetorial -----------------------------------------------------------------------------------
select pg_temp.as_user(101);
select lives_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e2(500),'activity',pg_temp.e2(13),'icon','icone.png','image/png',1024,repeat('a',64),'{"icon":"star"}')$$,
  'P prepares the raster icon (png)');
select lives_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e2(501),'activity',pg_temp.e2(13),'icon_vector','icone.svg','image/svg+xml',900,repeat('b',64),'{"icon":"star"}')$$,
  'P prepares the vector icon (svg)');
select is((select object_key from public.entity_image_assets where request_id=pg_temp.e2(501)),
  'entities/activity/'||pg_temp.e2(13)::text||'/icon_vector/'||pg_temp.asset_of(501)::text||'.svg','svg key ends with .svg under icon_vector');
select throws_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e2(502),'activity',pg_temp.e2(13),'icon','icone.svg','image/svg+xml',900,repeat('c',64))$$,
  '22023','invalid_entity_image','svg is refused for the raster icon kind');
select throws_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e2(503),'activity',pg_temp.e2(13),'icon_vector','icone.png','image/png',900,repeat('d',64))$$,
  '22023','invalid_entity_image','png is refused for the vector icon kind');
select throws_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e2(504),'unit',pg_temp.e2(11),'icon_vector','icone.svg','image/svg+xml',900,repeat('e',64))$$,
  '22023','invalid_entity_image','vector icon only exists for activities');
select throws_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e2(505),'activity',pg_temp.e2(13),'icon_vector','icone.svg','image/svg+xml',300000,repeat('f',64))$$,
  '22023','invalid_entity_image','svg larger than 256 KiB is refused');
select pg_temp.activate(500);
select pg_temp.activate(501);
select pg_temp.as_user(101);
select is((select public.superadmin_entity_images_get_v1('activity',pg_temp.e2(13)) ?& array['icon','icon_vector']), true,
  'png and svg icons stay active side by side');

-- leitura em lote (equipe) ---------------------------------------------------------------------------
select pg_temp.as_user(101);
select lives_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e2(510),'unit',pg_temp.e2(11),'profile','a1.png','image/png',1024,repeat('1',64))$$,'P prepares A1 profile');
select pg_temp.activate(510);
select pg_temp.as_user(102);
select lives_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e2(520),'unit',pg_temp.e2(21),'profile','b1.png','image/png',1024,repeat('2',64))$$,'Q prepares B1 profile');
select pg_temp.activate(520);
select pg_temp.as_user(101);
select is((select public.superadmin_entity_images_list_v1('unit',array[pg_temp.e2(11),pg_temp.e2(21),pg_temp.e2(99)])),
  jsonb_build_object(pg_temp.e2(11)::text, jsonb_build_object('profile', jsonb_build_object('asset_id',pg_temp.asset_of(510),'content_type','image/png','icon_spec',null))),
  'P lists A1 only: B1 (other tenant) and unknown ids are omitted');
select pg_temp.as_user(102);
select is((select public.superadmin_entity_images_list_v1('unit',array[pg_temp.e2(11),pg_temp.e2(21)]) ? pg_temp.e2(21)::text), true, 'Q sees B1');
select is((select public.superadmin_entity_images_list_v1('unit',array[pg_temp.e2(11),pg_temp.e2(21)]) ? pg_temp.e2(11)::text), false, 'Q does not see A1 (cross-tenant)');
select pg_temp.as_user(103);
select is((select public.superadmin_entity_images_list_v1('unit',array[pg_temp.e2(11)]) ? pg_temp.e2(11)::text), true, 'L (teacher in A) sees A1');
select throws_ok($$select public.superadmin_entity_images_list_v1('planet',array[pg_temp.e2(11)])$$,'22023','invalid_entity_image_query','unknown kind is refused');
select throws_ok($$select public.superadmin_entity_images_list_v1('unit',(select array_agg(gen_random_uuid()) from generate_series(1,201)))$$,
  '22023','invalid_entity_image_query','more than 200 ids is refused');

-- leitor do Principal ------------------------------------------------------------------------------
select pg_temp.as_user(104);
select is((select public.principal_entity_images_list_v1('unit',array[pg_temp.e2(11),pg_temp.e2(21)])),
  jsonb_build_object(pg_temp.e2(11)::text, jsonb_build_object('profile', jsonb_build_object('asset_id',pg_temp.asset_of(510),'content_type','image/png','icon_spec',null))),
  'G1 (guardian with can_view in A, no membership) lists A1 only');
select lives_ok($$select public.principal_entity_image_authorize_read_v1(pg_temp.asset_of(510))$$,'G1 can read the A1 asset through the Edge');
select throws_ok($$select public.principal_entity_image_authorize_read_v1(pg_temp.asset_of(520))$$,'42501','entity_image_read_denied','G1 cannot read the B1 asset');
select pg_temp.as_user(105);
select is((select public.principal_entity_images_list_v1('unit',array[pg_temp.e2(11)])), '{}'::jsonb, 'G2 (no can_view) lists nothing');
select throws_ok($$select public.principal_entity_image_authorize_read_v1(pg_temp.asset_of(510))$$,'42501','entity_image_read_denied','G2 cannot read the A1 asset');
select pg_temp.as_user(103);
select is((select public.principal_entity_images_list_v1('unit',array[pg_temp.e2(11)]) ? pg_temp.e2(11)::text), true, 'staff L also reads through the Principal RPC');
select pg_temp.as_user(102);
select throws_ok($$select public.principal_entity_image_authorize_read_v1(pg_temp.asset_of(510))$$,'42501','entity_image_read_denied','Q (tenant B) cannot read A1 via the Principal RPC');

-- expiração ----------------------------------------------------------------------------------------
select pg_temp.as_user(101);
select lives_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e2(530),'unit',pg_temp.e2(11),'cover','capa.png','image/png',1024,repeat('3',64))$$,'P prepares a draft that will expire');
update public.entity_image_assets set expires_at = now() - interval '1 minute' where request_id = pg_temp.e2(530);
select throws_ok($$select public.superadmin_entity_image_expire_v1(10)$$,'42501','permission_denied','expire is refused to an authenticated actor');
select pg_temp.as_service();
select is((select (public.superadmin_entity_image_expire_v1(10))->>'expired'), '1', 'service_role expires the stale draft');
select is((select status from public.entity_image_assets where request_id=pg_temp.e2(530)), 'inactive', 'expired draft is inactive');
select is((select (public.superadmin_entity_image_expire_v1(10))->>'expired'), '0', 'second run finds nothing');
update public.entity_image_assets set status='draft', revoked_at=null where request_id = pg_temp.e2(530);
select is((select app_private.entity_image_expire_drafts_v1(200)), 1, 'cron function expires the stale draft without any JWT');

select * from finish();
rollback;
