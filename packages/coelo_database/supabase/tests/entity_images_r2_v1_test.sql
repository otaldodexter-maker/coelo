-- Prova pgTAP da migration 20260919200000_entity_images_r2_v1 (fotos de perfil/capa/ícone das entidades).
-- Fixture sintética com rollback (prefixo e1): instituição A (unidade A1, turma, atividade) e B.
-- Ator P: owner de plataforma com escopo na instituição A. Ator Q: owner com escopo em B.
begin;
create extension if not exists pgtap with schema extensions;
select plan(34);

create function pg_temp.e1(n integer) returns uuid language sql immutable as $$
  select ('e1000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
create function pg_temp.as_user(n integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', pg_temp.e1(n)::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.e1(n)::text, 'role', 'authenticated', 'aal', 'aal1')::text, true);
end $$;
create function pg_temp.as_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'service_role', true);
  perform set_config('request.jwt.claims', jsonb_build_object('role', 'service_role')::text, true);
end $$;

-- estrutura ----------------------------------------------------------------------------------------
select has_table('public','entity_image_assets','entity_image_assets exists');
select ok((select relforcerowsecurity and relrowsecurity from pg_class where oid='public.entity_image_assets'::regclass),'assets force RLS');
select ok(not has_table_privilege('anon','public.entity_image_assets','SELECT') and not has_table_privilege('authenticated','public.entity_image_assets','SELECT'),'no client read/write on assets');
select ok((select bool_and(has_function_privilege('authenticated',p.oid,'execute') and not has_function_privilege('anon',p.oid,'execute'))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
  and p.proname in ('superadmin_entity_image_prepare_v1','superadmin_entity_image_authorize_upload_v1','superadmin_entity_image_authorize_read_v1','superadmin_entity_image_remove_v1','superadmin_entity_images_get_v1')),
  'client RPCs: authenticated only');
select ok(not has_function_privilege('authenticated','public.superadmin_entity_image_finalize_v1(uuid,uuid,bigint,text)','execute')
  and has_function_privilege('service_role','public.superadmin_entity_image_finalize_v1(uuid,uuid,bigint,text)','execute'),'finalize: service_role only');

-- fixture ------------------------------------------------------------------------------------------
insert into public.institution_types(id,code,name,status) values (pg_temp.e1(1),'e1-type','E1 type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.e1(2),'e1-unit','E1 unit','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status,timezone) values
 (pg_temp.e1(10),pg_temp.e1(1),'E1 Instituicao A','e1-a','active','America/Sao_Paulo'),
 (pg_temp.e1(20),pg_temp.e1(1),'E1 Instituicao B','e1-b','active','America/Sao_Paulo');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status,timezone) values
 (pg_temp.e1(11),pg_temp.e1(10),'E1 Unidade A1','e1-unidade-a1','e1unidade.a1',pg_temp.e1(2),'active','America/Sao_Paulo'),
 (pg_temp.e1(21),pg_temp.e1(20),'E1 Unidade B1','e1-unidade-b1','e1unidade.b1',pg_temp.e1(2),'active','America/Sao_Paulo');
insert into public.groups(id,institution_id,unit_id,name,status) values
 (pg_temp.e1(12),pg_temp.e1(10),pg_temp.e1(11),'E1 Turma A1','active');
insert into auth.users(id) values (pg_temp.e1(101)),(pg_temp.e1(102)),(pg_temp.e1(103));
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.e1(201),'adult','E1','Ator P','E1 Ator P','active'),
 (pg_temp.e1(202),'adult','E1','Ator Q','E1 Ator Q','active'),
 (pg_temp.e1(203),'adult','E1','Leitor L','E1 Leitor L','active'),
 (pg_temp.e1(204),'adult','E1','Pessoa A','E1 Pessoa A','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.e1(201),pg_temp.e1(101),'active'),(pg_temp.e1(202),pg_temp.e1(102),'active'),(pg_temp.e1(203),pg_temp.e1(103),'active');
insert into public.platform_memberships(id,person_id,role_id,status,scope_kind,scope_institution_id)
select pg_temp.e1(301),pg_temp.e1(201),r.id,'active','institution',pg_temp.e1(10) from public.platform_roles r where r.code='owner' and r.is_system;
insert into public.platform_memberships(id,person_id,role_id,status,scope_kind,scope_institution_id)
select pg_temp.e1(302),pg_temp.e1(202),r.id,'active','institution',pg_temp.e1(20) from public.platform_roles r where r.code='owner' and r.is_system;
-- L: leitor sem permissão de edição (membership de instituição em A)
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
 (pg_temp.e1(303),pg_temp.e1(203),pg_temp.e1(10),'teacher','active','institution'),
 (pg_temp.e1(304),pg_temp.e1(204),pg_temp.e1(10),'teacher','active','institution');

-- P prepara a foto de perfil da unidade A1 ----------------------------------------------------------
select pg_temp.as_user(101);
select lives_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e1(500),'unit',pg_temp.e1(11),'profile','foto.png','image/png',1024,repeat('a',64))$$,
  'P prepares a unit profile image in A');
select is((select object_key from public.entity_image_assets where request_id=pg_temp.e1(500)),
  'entities/unit/'||pg_temp.e1(11)::text||'/profile/'||(select id::text from public.entity_image_assets where request_id=pg_temp.e1(500))||'.png',
  'object key follows entities/<kind>/<id>/<image>/<asset>.<ext>');
select is((select tenant_id from public.entity_image_assets where request_id=pg_temp.e1(500)),pg_temp.e1(10),'tenant resolved from the unit');
select is((select (public.superadmin_entity_image_prepare_v1(pg_temp.e1(500),'unit',pg_temp.e1(11),'profile','foto.png','image/png',1024,repeat('a',64)))->>'asset_id'),
  (select id::text from public.entity_image_assets where request_id=pg_temp.e1(500)),'same request id replays the same asset');
select throws_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e1(501),'unit',pg_temp.e1(21),'profile','foto.png','image/png',1024,repeat('a',64))$$,
  '42501','entity_image_denied','P cannot prepare an image for a unit of B (cross-tenant)');
select throws_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e1(502),'unit',pg_temp.e1(11),'icon','foto.png','image/png',1024,repeat('a',64))$$,
  '22023','invalid_entity_image','icon only exists for activities');
select throws_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e1(503),'unit',pg_temp.e1(99),'profile','foto.png','image/png',1024,repeat('a',64))$$,
  'P0002','entity_image_target_not_found','unknown entity is refused');
select lives_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e1(504),'person',pg_temp.e1(204),'profile','foto.jpg','image/jpeg',2048,repeat('b',64))$$,
  'P prepares a person profile image (tenant from the membership)');
select is((select tenant_id from public.entity_image_assets where request_id=pg_temp.e1(504)),pg_temp.e1(10),'person tenant resolved from institution membership');
select lives_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e1(505),'group',pg_temp.e1(12),'cover','capa.webp','image/webp',4096,repeat('c',64))$$,
  'P prepares a group cover');

-- ticket de upload ----------------------------------------------------------------------------------
select lives_ok($$select public.superadmin_entity_image_authorize_upload_v1((select id from public.entity_image_assets where request_id=pg_temp.e1(500)))$$,
  'P authorizes the upload of its own draft');
select pg_temp.as_user(102);
select throws_ok($$select public.superadmin_entity_image_authorize_upload_v1((select id from public.entity_image_assets where request_id=pg_temp.e1(500)))$$,
  '42501','entity_image_ticket_denied','Q cannot use P ticket');
select pg_temp.as_user(103);
select throws_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e1(506),'unit',pg_temp.e1(11),'profile','foto.png','image/png',1024,repeat('a',64))$$,
  '42501','entity_image_denied','reader without units.update cannot prepare');

-- finalize (service_role) ---------------------------------------------------------------------------
select pg_temp.as_user(101);
select throws_ok($$select public.superadmin_entity_image_finalize_v1((select id from public.entity_image_assets where request_id=pg_temp.e1(500)),
  (select finalize_ticket from public.entity_image_assets where request_id=pg_temp.e1(500)),1024,repeat('a',64))$$,
  '42501','permission_denied','client cannot finalize');
select pg_temp.as_service();
select throws_ok($$select public.superadmin_entity_image_finalize_v1((select id from public.entity_image_assets where request_id=pg_temp.e1(505)),
  (select finalize_ticket from public.entity_image_assets where request_id=pg_temp.e1(505)),4096,repeat('d',64))$$,
  '22023','entity_image_mismatch','checksum mismatch is refused');
select is((select status from public.entity_image_assets where request_id=pg_temp.e1(505)),'draft','mismatch leaves the draft untouched (expires later)');
select is((select public.superadmin_entity_image_finalize_v1((select id from public.entity_image_assets where request_id=pg_temp.e1(500)),
  (select finalize_ticket from public.entity_image_assets where request_id=pg_temp.e1(500)),1024,repeat('a',64)))->>'status','active','finalize activates the asset');
select throws_ok($$select public.superadmin_entity_image_finalize_v1((select id from public.entity_image_assets where request_id=pg_temp.e1(500)),
  (select finalize_ticket from public.entity_image_assets where request_id=pg_temp.e1(500)),1024,repeat('a',64))$$,
  '42501','entity_image_ticket_denied','ticket is single use');

-- leitura ------------------------------------------------------------------------------------------
select pg_temp.as_user(103);
select is((select public.superadmin_entity_images_get_v1('unit',pg_temp.e1(11)))->'profile'->>'asset_id',
  (select id::text from public.entity_image_assets where request_id=pg_temp.e1(500)),'reader of A sees the unit profile image');
select lives_ok($$select public.superadmin_entity_image_authorize_read_v1((select id from public.entity_image_assets where request_id=pg_temp.e1(500)))$$,
  'reader of A can read the bytes descriptor');
select pg_temp.as_user(102);
select is(public.superadmin_entity_images_get_v1('unit',pg_temp.e1(11)),'{}'::jsonb,'Q (B only) sees nothing of A');
select throws_ok($$select public.superadmin_entity_image_authorize_read_v1((select id from public.entity_image_assets where request_id=pg_temp.e1(500)))$$,
  '42501','entity_image_read_denied','Q cannot read A image');

-- troca: nova foto ativa desativa a anterior; remoção ----------------------------------------------
select pg_temp.as_user(101);
select lives_ok($$select public.superadmin_entity_image_prepare_v1(pg_temp.e1(507),'unit',pg_temp.e1(11),'profile','foto2.png','image/png',1025,repeat('e',64))$$,'P prepares a second profile image');
select pg_temp.as_service();
select lives_ok($$select public.superadmin_entity_image_finalize_v1((select id from public.entity_image_assets where request_id=pg_temp.e1(507)),
  (select finalize_ticket from public.entity_image_assets where request_id=pg_temp.e1(507)),1025,repeat('e',64))$$,'second image finalized');
select is((select status from public.entity_image_assets where request_id=pg_temp.e1(500)),'inactive','previous profile image is deactivated');
select pg_temp.as_user(103);
select throws_ok($$select public.superadmin_entity_image_remove_v1((select id from public.entity_image_assets where request_id=pg_temp.e1(507)))$$,
  '42501','entity_image_remove_denied','reader cannot remove');
select pg_temp.as_user(101);
select is((select public.superadmin_entity_image_remove_v1((select id from public.entity_image_assets where request_id=pg_temp.e1(507))))->>'status','revoked','P removes the image');
select is(public.superadmin_entity_images_get_v1('unit',pg_temp.e1(11)),'{}'::jsonb,'no active image after removal');
select ok((select count(*)>=4 from audit.audit_logs where action_code like 'entity_image.%' and object_id in (select id from public.entity_image_assets where tenant_id=pg_temp.e1(10))),'audit trail written');

select * from finish();
rollback;
