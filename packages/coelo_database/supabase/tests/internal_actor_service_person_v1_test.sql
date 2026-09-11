-- Ator do realm interno v2 como pessoa de servico (pacote 20260910220400).
-- O que estas assercoes protegem: a sessao interna do Superadmin passa a ser
-- reconhecida pelas RPCs people-based SEM ganhar nada alem do papel que ja tem
-- no realm interno, e o realm people-based continua com precedencia.
begin;

create extension if not exists pgtap with schema extensions;

select plan(17);

-- Fixture: A = identidade interna owner (sem pessoa); B = pessoa adulta do
-- realm people-based; C = auth user sem vinculo em realm algum.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data) values
  ('a1000000-0000-4000-8000-000000000001','authenticated','authenticated',
   'actor-internal@invalid.test',now(),now(),now(),'{}','{}'),
  ('a1000000-0000-4000-8000-000000000002','authenticated','authenticated',
   'actor-people@invalid.test',now(),now(),now(),'{}','{}'),
  ('a1000000-0000-4000-8000-000000000003','authenticated','authenticated',
   'actor-nobody@invalid.test',now(),now(),now(),'{}','{}'),
  ('a1000000-0000-4000-8000-00000000000f','authenticated','authenticated',
   'actor-second-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('a2000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
  ('a2000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour'),
  ('a2000000-0000-4000-8000-000000000003','a1000000-0000-4000-8000-000000000003',now(),now(),'aal1',now()+interval '1 hour');
-- Z e um segundo owner interno (com auth link ativo): existe so para o guard
-- de "ultimo owner" permitir suspender A mais adiante.
insert into app_private.superadmin_internal_identities(id) values
  ('a3000000-0000-4000-8000-000000000001'),
  ('a3000000-0000-4000-8000-00000000000f');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
  ('a4000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001'),
  ('a4000000-0000-4000-8000-00000000000f','a3000000-0000-4000-8000-00000000000f','a1000000-0000-4000-8000-00000000000f');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select 'a5000000-0000-4000-8000-00000000000f','a3000000-0000-4000-8000-00000000000f',id,'platform'
from public.platform_roles where code='owner';
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select 'a5000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001',id,'platform'
from public.platform_roles where code='owner';
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('a6000000-0000-4000-8000-000000000002','adult','Pessoa','Do realm','Pessoa Do realm','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
  ('a6000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002','active');

-- 1-4: catalogo e concessoes
select has_table('app_private','superadmin_internal_actor_people',
  'a tabela de espelho da identidade interna existe');
select ok(
  (select count(*) = 3 from public.platform_permissions
   where code in ('attendance.read','attendance.manage','people.assign_children')
     and status = 'active'),
  'attendance.read, attendance.manage e people.assign_children existem no catalogo');
select ok(
  not exists (
    select 1 from public.platform_permissions permission_row
    where permission_row.status = 'active'
      and (permission_row.code like 'health_care.%' or permission_row.code like 'medication.%'
        or permission_row.code like 'routine.%' or permission_row.code like 'attendance.%'
        or permission_row.code in ('people.assign_children','people.read'))
      and not exists (
        select 1 from public.platform_role_permissions grant_row
        join public.platform_roles role_row on role_row.id = grant_row.role_id
        where role_row.code = 'owner' and grant_row.permission_id = permission_row.id
          and grant_row.status = 'active' and grant_row.effect = 'allow')),
  'o papel owner concede todas as permissoes das familias do recorte');
select ok(
  not has_table_privilege('authenticated','app_private.superadmin_internal_actor_people','select')
  and not has_table_privilege('anon','app_private.superadmin_internal_actor_people','select'),
  'o espelho nao tem grant para cliente');

-- 5-7: o gatilho espelhou a identidade A numa pessoa de servico com membership
select is(
  (select count(*)::int from app_private.superadmin_internal_actor_people
   where internal_identity_id = 'a3000000-0000-4000-8000-000000000001'),
  1, 'a identidade interna A ganhou um espelho');
select is(
  (select person_row.person_type::text from app_private.superadmin_internal_actor_people actor
   join public.people person_row on person_row.id = actor.person_id
   where actor.internal_identity_id = 'a3000000-0000-4000-8000-000000000001'),
  'service', 'o espelho e uma pessoa de servico, nao um adulto nem uma crianca');
select ok(
  exists (
    select 1 from app_private.superadmin_internal_actor_people actor
    join public.platform_memberships membership on membership.id = actor.platform_membership_id
    join public.platform_roles role_row on role_row.id = membership.role_id
    where actor.internal_identity_id = 'a3000000-0000-4000-8000-000000000001'
      and membership.status = 'active' and role_row.code = 'owner'
      and membership.scope_kind = 'platform' and membership.mfa_required = false),
  'a membership espelhada esta ativa, no mesmo papel owner, escopo plataforma');

-- 8-12: como A (sessao interna), as funcoes people-based reconhecem o ator
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','a1000000-0000-4000-8000-000000000001',
  'session_id','a2000000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.internal_actor', coalesce(app_private.current_person_id()::text, ''), true);
select set_config('test.internal_hc', app_private.has_platform_permission('health_care.read')::text, true);
select set_config('test.internal_att', app_private.has_platform_permission('attendance.manage')::text, true);
select set_config('test.internal_assign', app_private.has_platform_permission('people.assign_children')::text, true);
select set_config('test.internal_dir',
  coalesce((public.superadmin_health_care_directory(null,null,null,null,null,20,0)->>'total'), 'erro'), true);
reset role;

select is(
  current_setting('test.internal_actor', true),
  (select person_id::text from app_private.superadmin_internal_actor_people
   where internal_identity_id = 'a3000000-0000-4000-8000-000000000001'),
  'current_person_id() devolve a pessoa de servico da sessao interna');
select is(current_setting('test.internal_hc', true), 'true',
  'a sessao interna tem health_care.read pelo papel owner');
select is(current_setting('test.internal_att', true), 'true',
  'a sessao interna tem attendance.manage pelo papel owner');
select is(current_setting('test.internal_assign', true), 'true',
  'a sessao interna tem people.assign_children pelo papel owner');
select is(current_setting('test.internal_dir', true), '0',
  'o diretorio de Perfis de cuidado (lote 2) responde a sessao interna em vez de negar');

-- 13: o realm people-based continua com precedencia
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','a1000000-0000-4000-8000-000000000002',
  'session_id','a2000000-0000-4000-8000-000000000002',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.people_actor', coalesce(app_private.current_person_id()::text, ''), true);
reset role;
select is(current_setting('test.people_actor', true), 'a6000000-0000-4000-8000-000000000002',
  'quem tem person_auth_link continua sendo a propria pessoa');

-- 14: sem vinculo em realm algum continua sem ator
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','a1000000-0000-4000-8000-000000000003',
  'session_id','a2000000-0000-4000-8000-000000000003',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.nobody_actor', coalesce(app_private.current_person_id()::text, ''), true);
reset role;
select is(current_setting('test.nobody_actor', true), '',
  'auth user sem vinculo em nenhum realm nao vira ator');

-- 15-16: suspender a membership interna suspende o espelho e a capacidade some
update app_private.superadmin_internal_memberships
  set status = 'suspended', suspended_at = now(), version = version + 1
  where id = 'a5000000-0000-4000-8000-000000000001';
select is(
  (select membership.status::text from app_private.superadmin_internal_actor_people actor
   join public.platform_memberships membership on membership.id = actor.platform_membership_id
   where actor.internal_identity_id = 'a3000000-0000-4000-8000-000000000001'),
  'suspended', 'o espelho acompanha a suspensao no realm interno');
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','a1000000-0000-4000-8000-000000000001',
  'session_id','a2000000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.suspended_hc', app_private.has_platform_permission('health_care.read')::text, true);
reset role;
select is(current_setting('test.suspended_hc', true), 'false',
  'sessao interna suspensa perde a capacidade no realm people-based');

-- 17: reativar devolve a capacidade sem criar segunda pessoa
update app_private.superadmin_internal_memberships
  set status = 'active', suspended_at = null, version = version + 1
  where id = 'a5000000-0000-4000-8000-000000000001';
select is(
  (select count(*)::int from public.people person_row
   join app_private.superadmin_internal_actor_people actor on actor.person_id = person_row.id
   where actor.internal_identity_id = 'a3000000-0000-4000-8000-000000000001'
     and person_row.person_type = 'service'),
  1, 'reativar nao duplica a pessoa de servico');

select * from finish();
rollback;
