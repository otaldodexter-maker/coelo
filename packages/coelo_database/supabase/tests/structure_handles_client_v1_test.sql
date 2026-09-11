-- R06 estrutura: @ no cliente (sobre 20260912180000_structure_handles_client_v1):
-- save_v2 aceita definition.handle na criacao e recusa troca na edicao;
-- group_management_payload devolve handle e handle_last_changed_at.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into public.institution_types(id,code,name,status) values
 ('9f0b0000-0000-4000-8000-000000000001','handles-client','Handles client','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9f0b0000-0000-4000-8000-000000000010','Escola Boreal','escolaboreal','active','9f0b0000-0000-4000-8000-000000000001');
insert into public.unit_types(id,code,name,status) values ('9f0b0000-0000-4000-8000-000000000002','hc-unit','Unidade HC','active');
insert into public.units(id,institution_id,unit_type_id,name,slug,status,handle) values
 ('9f0b0000-0000-4000-8000-000000000011','9f0b0000-0000-4000-8000-000000000010','9f0b0000-0000-4000-8000-000000000002','Norte','norte','active','norte.escolaboreal');
insert into public.groups(id,institution_id,unit_id,name,group_type,status,management_version) values
 ('9f0b0000-0000-4000-8000-000000000021','9f0b0000-0000-4000-8000-000000000010','9f0b0000-0000-4000-8000-000000000011','Turma Lilas','class','active',1);
insert into public.activity_taxonomies(id,code,name,status,taxonomy_kind) values
 ('9f0b0000-0000-4000-8000-000000000003','hc-esporte','Esporte HC','active','category');

-- owner de plataforma com todas as permissoes (ponte 220400 cria a pessoa de servico)
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f0b0000-0000-4000-8000-000000000101','authenticated','authenticated','hc-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9f0b0000-0000-4000-8000-000000000201','9f0b0000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values ('9f0b0000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f0b0000-0000-4000-8000-000000000401','9f0b0000-0000-4000-8000-000000000301','9f0b0000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '9f0b0000-0000-4000-8000-000000000501','9f0b0000-0000-4000-8000-000000000301',r.id,'platform' from public.platform_roles r where r.code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r cross join public.platform_permissions p where r.code='owner'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
select set_config('request.jwt.claims',jsonb_build_object('sub','9f0b0000-0000-4000-8000-000000000101','session_id','9f0b0000-0000-4000-8000-000000000201','aal','aal1','role','authenticated')::text,true);

create function pg_temp.payload(target_name text, target_handle text) returns jsonb language sql stable set search_path='' as $$
 select pg_catalog.jsonb_build_object(
  'institution_id','9f0b0000-0000-4000-8000-000000000010',
  'definition',pg_catalog.jsonb_build_object('name',target_name,'description','','taxonomy_id','9f0b0000-0000-4000-8000-000000000003','icon_key','science','initials','HC')
    || case when target_handle is null then '{}'::jsonb else pg_catalog.jsonb_build_object('handle',target_handle) end,
  'unit_ids',pg_catalog.jsonb_build_array('9f0b0000-0000-4000-8000-000000000011'),
  'group_ids','[]'::jsonb,'group_participation','{}'::jsonb,'participants','[]'::jsonb,
  'professional_assignments','[]'::jsonb,
  'capability_policies','{"attendance":null,"chat":null,"happens":null,"moments":null,"now":null}'::jsonb,
  'group_capability_settings','[]'::jsonb,'professional_capability_actions','[]'::jsonb)
$$;
grant execute on function pg_temp.payload(text,text) to authenticated;
create temporary table hc(label text primary key, body jsonb not null);
grant select,insert on hc to authenticated;

set local role authenticated;
-- 1. criacao com @: primeiro segmento vira handle_stem
insert into hc values('c1', public.superadmin_activity_save_v2('9f0b0000-0000-4000-8000-000000000901',null,0,false,pg_temp.payload('Natação','@Nadar.Norte')));
-- 2. criacao sem @: padrao pelo nome
insert into hc values('c2', public.superadmin_activity_save_v2('9f0b0000-0000-4000-8000-000000000902',null,0,false,pg_temp.payload('Judô',null)));
reset role;
select is((select body->>'ok' from hc where label='c1'),'true','save_v2 cria com definition.handle');
select is((select canonical_handle from public.activity_definitions where id=(select (body#>>'{data,activity_id}')::uuid from hc where label='c1')),'nadar.escolaboreal',
  'o @ informado vira handle_stem e o canonical segue stem.instituicao');
select is((select canonical_handle from public.activity_definitions where id=(select (body#>>'{data,activity_id}')::uuid from hc where label='c2')),'judo.escolaboreal',
  'sem @ o padrao continua o slug do nome');

create temporary table c1 as select (body#>>'{data,activity_id}')::uuid id,(body#>>'{data,management_version}')::bigint v from hc where label='c1';
grant select on c1 to authenticated;
set local role authenticated;
-- 3. edicao com o mesmo @ passa (renomeia)
insert into hc values('e1', public.superadmin_activity_save_v2('9f0b0000-0000-4000-8000-000000000903',(select id from c1),(select v from c1),false,pg_temp.payload('Natação Infantil','nadar')));
-- 4. edicao com @ diferente e recusada: usa set_v1
insert into hc values('e2', public.superadmin_activity_save_v2('9f0b0000-0000-4000-8000-000000000904',(select id from c1),(select (body#>>'{data,management_version}')::bigint from hc where label='e1'),false,pg_temp.payload('Natação Infantil','mergulho')));
reset role;
select is((select body->>'ok' from hc where label='e1'),'true','edicao com o mesmo @ passa');
select is((select name from public.activity_definitions where id=(select id from c1)),'Natação Infantil','a edicao renomeou');
select is((select body#>>'{error,code}' from hc where label='e2'),'ACTIVITY_INVALID_INPUT','trocar o @ pela edicao e recusado (set_v1 com trava de 30 dias)');
select is((select handle_stem from public.activity_definitions where id=(select id from c1)),'nadar','o stem nao mudou pela edicao');

-- 5. group_management_payload devolve o @
select is((select app_private.group_management_payload('9f0b0000-0000-4000-8000-000000000021')->>'handle'),'turmalilas.norte.escolaboreal','group_management_payload devolve handle');
select ok((select app_private.group_management_payload('9f0b0000-0000-4000-8000-000000000021') ? 'handle_last_changed_at'),'group_management_payload devolve handle_last_changed_at');

select * from finish();
rollback;
