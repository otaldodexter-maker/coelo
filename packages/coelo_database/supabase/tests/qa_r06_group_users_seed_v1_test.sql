-- pgTAP da semente dos usuarios sinteticos por frente (candidato 20260912230000).
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into public.institution_types(id,code,name,status) values
 ('9c700000-0000-4000-8000-000000000001','qa-r06-seed-test','QA R06 seed test','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9c700000-0000-4000-8000-00000000000a','QA R04 Escola','qa-r04-escola','active','9c700000-0000-4000-8000-000000000001'),
 ('9c700000-0000-4000-8000-00000000000b','Outra ativa','qa-r06-outra','active','9c700000-0000-4000-8000-000000000001');

-- Dois dos sete auth users existem (criados "pela API do Auth"); os outros cinco nao.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9c700000-0000-4000-8000-000000000101','authenticated','authenticated','qa-r06-realm@coelo.me',now(),now(),now(),'{}','{}'),
 ('9c700000-0000-4000-8000-000000000102','authenticated','authenticated','qa-r06-estrutura@coelo.me',now(),now(),now(),'{}','{}');

create temporary table seed_run as select * from app_private.seed_qa_r06_group_users();
select is((select count(*)::int from seed_run),7,'semente relata os sete grupos');
select is((select count(*)::int from seed_run where outcome like 'ok%'),2,'dois usuarios existentes semeados');
select is((select count(*)::int from seed_run where outcome like 'auth user ausente%'),5,'cinco ausentes viram no-op com aviso');

select is((select count(*)::int from app_private.superadmin_internal_auth_links l
  where l.auth_user_id in ('9c700000-0000-4000-8000-000000000101','9c700000-0000-4000-8000-000000000102') and l.status='active'),2,
  'vinculo interno ativo para os dois');
select is((select count(*)::int from app_private.superadmin_internal_memberships m
  join app_private.superadmin_internal_auth_links l on l.internal_identity_id=m.internal_identity_id
  join public.platform_roles r on r.id=m.platform_role_id
  where l.auth_user_id in ('9c700000-0000-4000-8000-000000000101','9c700000-0000-4000-8000-000000000102')
    and m.status='active' and m.scope_kind='platform' and r.code='owner'),2,'membership owner de plataforma para os dois');
select is((select string_agg(p.display_name,',' order by p.display_name) from app_private.superadmin_internal_profiles p
  join app_private.superadmin_internal_auth_links l on l.internal_identity_id=p.internal_identity_id
  where l.auth_user_id in ('9c700000-0000-4000-8000-000000000101','9c700000-0000-4000-8000-000000000102')),
  'QA R06 Estrutura,QA R06 Realm','perfil interno sintetico com o nome do grupo');
select is((select count(*)::int from app_private.superadmin_internal_actor_people a
  join app_private.superadmin_internal_auth_links l on l.internal_identity_id=a.internal_identity_id
  where l.auth_user_id in ('9c700000-0000-4000-8000-000000000101','9c700000-0000-4000-8000-000000000102')
    and a.platform_membership_id is not null),2,'ponte de ator (220400) espelhou pessoa de servico e platform_membership');
select is((select count(*)::int from public.institution_memberships m
  join app_private.superadmin_internal_actor_people a on a.person_id=m.person_id
  join app_private.superadmin_internal_auth_links l on l.internal_identity_id=a.internal_identity_id
  where l.auth_user_id='9c700000-0000-4000-8000-000000000101' and m.status='active' and m.revoked_at is null
    and m.institution_id in ('9c700000-0000-4000-8000-00000000000a','9c700000-0000-4000-8000-00000000000b')),2,
  'qa-r06-realm e owner nas instituicoes ativas (sync do 130000 + padrao do lote 27)');

-- Idempotencia
create temporary table seed_rerun as select * from app_private.seed_qa_r06_group_users();
select is((select count(*)::int from seed_rerun where outcome like 'ok%'),2,'segunda execucao relata os mesmos dois');
select is((select count(*)::int from app_private.superadmin_internal_auth_links l
  where l.auth_user_id in ('9c700000-0000-4000-8000-000000000101','9c700000-0000-4000-8000-000000000102')),2,'nao duplica vinculo');
select is((select count(*)::int from app_private.superadmin_internal_memberships m
  join app_private.superadmin_internal_auth_links l on l.internal_identity_id=m.internal_identity_id
  where l.auth_user_id in ('9c700000-0000-4000-8000-000000000101','9c700000-0000-4000-8000-000000000102')),2,'nao duplica membership');

select is(has_function_privilege('authenticated','app_private.seed_qa_r06_group_users()','execute'),false,'cliente nao executa a semente');

select * from finish();
rollback;
