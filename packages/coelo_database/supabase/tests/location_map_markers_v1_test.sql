-- Prova pgTAP da migration 20260920010000_location_map_markers_v1 (spec 067, marcadores do mapa).
-- Fixture com rollback total (prefixo 9a1): owner interno de plataforma, operations com escopo na
-- instituição B, instituição A (unidade A1 com endereço próprio, local "Quadra") e instituição B.
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

select has_table('public','location_map_markers','markers table exists');
select ok((select relforcerowsecurity from pg_class where oid='public.location_map_markers'::regclass),'markers force RLS');
select ok(not has_table_privilege('authenticated','public.location_map_markers','SELECT'),'markers are RPC-only');
select has_function('public','superadmin_location_map_get_v1',array['text','uuid','uuid'],'get rpc exists');
select has_function('public','superadmin_location_map_marker_save_v1',array['uuid','uuid','bigint','jsonb'],'save rpc exists');
select ok(has_function_privilege('authenticated','public.superadmin_location_map_marker_save_v1(uuid,uuid,bigint,jsonb)','execute')
  and not has_function_privilege('anon','public.superadmin_location_map_marker_save_v1(uuid,uuid,bigint,jsonb)','execute'),'authenticated only');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9a100000-0000-4000-8000-000000000101','authenticated','authenticated','map-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('9a100000-0000-4000-8000-000000000102','authenticated','authenticated','map-ops@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9a100000-0000-4000-8000-000000000201','9a100000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('9a100000-0000-4000-8000-000000000202','9a100000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour');
insert into public.institution_types(id,code,name,status) values ('9a100000-0000-4000-8000-000000000001','map-test','Map test','active');
insert into public.unit_types(id,code,name,status) values ('9a100000-0000-4000-8000-000000000002','map-unit','Map unit','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9a100000-0000-4000-8000-000000000010','Map Instituição A','map-a','active','9a100000-0000-4000-8000-000000000001'),
 ('9a100000-0000-4000-8000-000000000011','Map Instituição B','map-b','active','9a100000-0000-4000-8000-000000000001');
insert into public.institution_addresses(institution_id,country,state,city,district,street,number,postal_code) values
 ('9a100000-0000-4000-8000-000000000010','BR','SP','São Paulo','Centro','Rua A','10','01000000');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status) values
 ('9a100000-0000-4000-8000-000000000020','9a100000-0000-4000-8000-000000000010','Map Unidade A1','map-unidade-a1','mapunidade.a1','9a100000-0000-4000-8000-000000000002','active');
insert into app_private.superadmin_internal_identities(id) values
 ('9a100000-0000-4000-8000-000000000301'),('9a100000-0000-4000-8000-000000000302');
insert into public.activity_locations(id,institution_id,unit_id,name,status,scope_kind,kind,visibility,created_by_internal_identity_id) values
 ('9a100000-0000-4000-8000-000000000030','9a100000-0000-4000-8000-000000000010','9a100000-0000-4000-8000-000000000020','Quadra','active','unit','internal','all','9a100000-0000-4000-8000-000000000301'),
 ('9a100000-0000-4000-8000-000000000031','9a100000-0000-4000-8000-000000000011',null,'Sala B','active','institution','internal','all','9a100000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9a100000-0000-4000-8000-000000000401','9a100000-0000-4000-8000-000000000301','9a100000-0000-4000-8000-000000000101'),
 ('9a100000-0000-4000-8000-000000000402','9a100000-0000-4000-8000-000000000302','9a100000-0000-4000-8000-000000000102');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select f.id,f.identity_id,r.id,f.scope_kind::app_private.superadmin_internal_scope_kind,f.inst
from (values
 ('9a100000-0000-4000-8000-000000000501'::uuid,'9a100000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('9a100000-0000-4000-8000-000000000502'::uuid,'9a100000-0000-4000-8000-000000000302'::uuid,'operations','institution','9a100000-0000-4000-8000-000000000011'::uuid)
) f(id,identity_id,role_code,scope_kind,inst) join public.platform_roles r on r.code=f.role_code;

create temporary table r(label text primary key, body jsonb not null);
select set_config('request.jwt.claims',jsonb_build_object('sub','9a100000-0000-4000-8000-000000000101',
 'session_id','9a100000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);

insert into r values ('get_empty',public.superadmin_location_map_get_v1('unit','9a100000-0000-4000-8000-000000000010','9a100000-0000-4000-8000-000000000020'));
select is((select body#>>'{data,owner,name}' from r where label='get_empty'),'Map Unidade A1','get resolves the owner');
select is((select body#>>'{data,owner,address,street}' from r where label='get_empty'),'Rua A','unit without own address inherits the institution address');
select is((select jsonb_array_length(body#>'{data,markers}') from r where label='get_empty'),0,'no markers yet');
select is((select body#>'{data,locations}'->0->>'name' from r where label='get_empty'),'Quadra','locations of the owner are offered for linking');

insert into r values ('point',public.superadmin_location_map_marker_save_v1('9a100000-0000-4000-8000-000000000701',null,null,
  jsonb_build_object('owner_kind','unit','institution_id','9a100000-0000-4000-8000-000000000010','unit_id','9a100000-0000-4000-8000-000000000020',
    'label','Quadra coberta','x',0.25,'y',0.6,'location_id','9a100000-0000-4000-8000-000000000030','visibility','staff')));
select is((select body->>'ok' from r where label='point'),'true','point saved');
select is((select body#>>'{data,location_name}' from r where label='point'),'Quadra','marker carries the linked location');

insert into r values ('area',public.superadmin_location_map_marker_save_v1('9a100000-0000-4000-8000-000000000702',null,null,
  jsonb_build_object('owner_kind','unit','institution_id','9a100000-0000-4000-8000-000000000010','unit_id','9a100000-0000-4000-8000-000000000020',
    'label','Pátio','shape','area','x',0.5,'y',0.5,'points',jsonb_build_array(jsonb_build_array(0.1,0.1),jsonb_build_array(0.9,0.1),jsonb_build_array(0.5,0.9)))));
select is((select body#>>'{data,shape}' from r where label='area'),'area','area saved');

insert into r values ('bad_area',public.superadmin_location_map_marker_save_v1('9a100000-0000-4000-8000-000000000703',null,null,
  jsonb_build_object('owner_kind','unit','institution_id','9a100000-0000-4000-8000-000000000010','unit_id','9a100000-0000-4000-8000-000000000020',
    'label','Ruim','shape','area','x',0.5,'y',0.5,'points',jsonb_build_array(jsonb_build_array(0.1,0.1),jsonb_build_array(2,0.1)))));
select is((select body#>>'{error,code}' from r where label='bad_area'),'SAI_INVALID_ARGUMENT','area with two/out-of-range points rejected');

insert into r values ('foreign_loc',public.superadmin_location_map_marker_save_v1('9a100000-0000-4000-8000-000000000704',null,null,
  jsonb_build_object('owner_kind','institution','institution_id','9a100000-0000-4000-8000-000000000010',
    'label','Sala de outra','x',0.5,'y',0.5,'location_id','9a100000-0000-4000-8000-000000000031')));
select is((select body#>>'{error,code}' from r where label='foreign_loc'),'SAI_INVALID_ARGUMENT','location of another institution rejected');

insert into r values ('replay',public.superadmin_location_map_marker_save_v1('9a100000-0000-4000-8000-000000000701',null,null,
  jsonb_build_object('owner_kind','unit','institution_id','9a100000-0000-4000-8000-000000000010','unit_id','9a100000-0000-4000-8000-000000000020',
    'label','Quadra coberta','x',0.25,'y',0.6,'location_id','9a100000-0000-4000-8000-000000000030','visibility','staff')));
select is((select body#>>'{data,replayed}' from r where label='replay'),'true','same request replays');
select is((select count(*) from public.location_map_markers where label='Quadra coberta'),1::bigint,'replay creates nothing');

insert into r values ('move',public.superadmin_location_map_marker_save_v1('9a100000-0000-4000-8000-000000000705',
  (select (body#>>'{data,id}')::uuid from r where label='point'),1,jsonb_build_object('x',0.3,'y',0.7)));
select is((select body#>>'{data,x}' from r where label='move'),'0.300000','moved');
select is((select body#>>'{data,management_version}' from r where label='move'),'2','version bumped');
insert into r values ('stale',public.superadmin_location_map_marker_save_v1('9a100000-0000-4000-8000-000000000706',
  (select (body#>>'{data,id}')::uuid from r where label='point'),1,jsonb_build_object('x',0.9)));
select is((select body#>>'{error,code}' from r where label='stale'),'SAI_CONCURRENT_CHANGE','stale version = SAI_CONCURRENT_CHANGE');

insert into r values ('remove',public.superadmin_location_map_marker_remove_v1('9a100000-0000-4000-8000-000000000707',
  (select (body#>>'{data,id}')::uuid from r where label='area'),1));
select is((select body#>>'{data,status}' from r where label='remove'),'inactive','removed = inactive');
insert into r values ('get_after',public.superadmin_location_map_get_v1('unit','9a100000-0000-4000-8000-000000000010','9a100000-0000-4000-8000-000000000020'));
select is((select jsonb_array_length(body#>'{data,markers}') from r where label='get_after'),1,'get lists only active markers');

-- operations com escopo em B não vê nem escreve em A
select set_config('request.jwt.claims',jsonb_build_object('sub','9a100000-0000-4000-8000-000000000102',
 'session_id','9a100000-0000-4000-8000-000000000202','aal','aal2','role','authenticated')::text,true);
insert into r values ('cross_get',public.superadmin_location_map_get_v1('institution','9a100000-0000-4000-8000-000000000010',null));
select is((select body#>>'{error,code}' from r where label='cross_get'),'SAI_PERMISSION_DENIED','cross-tenant read denied');
insert into r values ('cross_save',public.superadmin_location_map_marker_save_v1('9a100000-0000-4000-8000-000000000708',null,null,
  jsonb_build_object('owner_kind','institution','institution_id','9a100000-0000-4000-8000-000000000010','label','X','x',0.1,'y',0.1)));
select is((select body#>>'{error,code}' from r where label='cross_save'),'SAI_PERMISSION_DENIED','cross-tenant write denied');

select * from finish();
rollback;
