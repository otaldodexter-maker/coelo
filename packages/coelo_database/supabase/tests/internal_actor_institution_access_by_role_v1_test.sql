-- Sincronizador por papel interno (pacote 20260911130400, R06 principal-chat-sistema).
-- Protege P48 (Owner, 11/09/2026, opcao A): owner interno -> institution_admin;
-- operations -> institution_reader (somente *.read); demais papeis internos sem
-- vinculo automatico; rebaixamento revoga o que o papel anterior tinha.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

-- Fixture: A = identidade interna owner; D = operations; E = auditor.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
  ('d1000000-0000-4000-8000-000000000001','authenticated','authenticated','byrole-owner@invalid.test',now(),now(),now(),'{}','{}'),
  ('d1000000-0000-4000-8000-000000000004','authenticated','authenticated','byrole-operations@invalid.test',now(),now(),now(),'{}','{}'),
  ('d1000000-0000-4000-8000-000000000005','authenticated','authenticated','byrole-auditor@invalid.test',now(),now(),now(),'{}','{}');
insert into app_private.superadmin_internal_identities(id) values
  ('d3000000-0000-4000-8000-000000000001'),
  ('d3000000-0000-4000-8000-000000000004'),
  ('d3000000-0000-4000-8000-000000000005');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
  ('d4000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000001'),
  ('d4000000-0000-4000-8000-000000000004','d3000000-0000-4000-8000-000000000004','d1000000-0000-4000-8000-000000000004'),
  ('d4000000-0000-4000-8000-000000000005','d3000000-0000-4000-8000-000000000005','d1000000-0000-4000-8000-000000000005');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select 'd5000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001',id,'platform' from public.platform_roles where code='owner';
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select 'd5000000-0000-4000-8000-000000000004','d3000000-0000-4000-8000-000000000004',id,'platform' from public.platform_roles where code='operations';
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select 'd5000000-0000-4000-8000-000000000005','d3000000-0000-4000-8000-000000000005',id,'platform' from public.platform_roles where code='auditor';
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('d7000000-0000-4000-8000-000000000001','ByRole X','ByRole X','byrole-x','active'),
  ('d7000000-0000-4000-8000-000000000002','ByRole Y','ByRole Y','byrole-y','active');

-- 1-3: papel de sistema de leitura
select is((select count(*)::int from public.institution_roles where code='institution_reader' and is_system and institution_id is null and status='active'), 1,
  'institution_reader existe como papel de sistema unico');
select cmp_ok((select count(*)::int from public.institution_role_permissions rp
  join public.institution_roles r on r.id=rp.role_id and r.code='institution_reader' and r.is_system and r.institution_id is null
  join public.institution_permissions p on p.id=rp.permission_id
  where rp.status='active' and rp.revoked_at is null and p.code like '%.read'), '>', 5,
  'institution_reader recebe as permissoes *.read');
select is((select count(*)::int from public.institution_role_permissions rp
  join public.institution_roles r on r.id=rp.role_id and r.code='institution_reader' and r.is_system and r.institution_id is null
  join public.institution_permissions p on p.id=rp.permission_id
  where rp.status='active' and rp.revoked_at is null and p.code not like '%.read'), 0,
  'institution_reader nao tem permissao de escrita');

-- helpers de leitura
create temp view actor_person as
select i.id as internal_identity_id, a.person_id
from app_private.superadmin_internal_identities i
join app_private.superadmin_internal_actor_people a on a.internal_identity_id=i.id;

create or replace function pg_temp.active_roles(p_identity uuid) returns text[] language sql as $$
  select coalesce(array_agg(distinct r.code order by r.code), '{}')
  from actor_person ap
  join public.institution_memberships m on m.person_id=ap.person_id and m.status='active' and m.revoked_at is null
  join public.institution_role_assignments a on a.membership_id=m.id and a.status='active' and a.scope_kind='institution'
  join public.institution_roles r on r.id=a.role_id
  where ap.internal_identity_id=p_identity
$$;
create or replace function pg_temp.membership_codes(p_identity uuid) returns text[] language sql as $$
  select coalesce(array_agg(distinct m.role_code order by m.role_code), '{}')
  from actor_person ap
  join public.institution_memberships m on m.person_id=ap.person_id and m.status='active' and m.revoked_at is null
  where ap.internal_identity_id=p_identity
$$;
create or replace function pg_temp.active_membership_count(p_identity uuid) returns int language sql as $$
  select count(*)::int
  from actor_person ap
  join public.institution_memberships m on m.person_id=ap.person_id and m.status='active' and m.revoked_at is null
  where ap.internal_identity_id=p_identity
    and m.institution_id in ('d7000000-0000-4000-8000-000000000001','d7000000-0000-4000-8000-000000000002')
$$;

-- 4-6: owner
select is(pg_temp.active_membership_count('d3000000-0000-4000-8000-000000000001'), 2, 'owner interno: membership nas duas instituicoes ativas');
select is(pg_temp.membership_codes('d3000000-0000-4000-8000-000000000001'), array['owner'], 'owner interno: role_code owner');
select is(pg_temp.active_roles('d3000000-0000-4000-8000-000000000001'), array['institution_admin'], 'owner interno: papel institution_admin, nunca reader');

-- 7-9: operations
select is(pg_temp.active_membership_count('d3000000-0000-4000-8000-000000000004'), 2, 'operations: membership nas duas instituicoes ativas');
select is(pg_temp.membership_codes('d3000000-0000-4000-8000-000000000004'), array['professional'], 'operations: role_code professional (nao owner)');
select is(pg_temp.active_roles('d3000000-0000-4000-8000-000000000004'), array['institution_reader'], 'operations: somente institution_reader');

-- 10: auditor
select is(pg_temp.active_membership_count('d3000000-0000-4000-8000-000000000005'), 0, 'auditor: nenhuma membership automatica');

-- 11: idempotencia
select is(app_private.superadmin_internal_actor_institution_access_sync(), 0, 'segunda sincronizacao e no-op');

-- 12-14: rebaixamento owner -> operations revoga institution_admin e concede reader
update public.platform_memberships pm set role_id=(select id from public.platform_roles where code='operations')
from app_private.superadmin_internal_actor_people a
where pm.id=a.platform_membership_id and a.internal_identity_id='d3000000-0000-4000-8000-000000000001';
select cmp_ok(app_private.superadmin_internal_actor_institution_access_sync(), '>', 0, 'rebaixamento mexe em algo');
select is(pg_temp.active_roles('d3000000-0000-4000-8000-000000000001'), array['institution_reader'], 'rebaixado: institution_admin revogado, reader concedido');
select is(pg_temp.membership_codes('d3000000-0000-4000-8000-000000000001'), array['professional'], 'rebaixado: role_code vira professional');

-- 15: promocao operations -> owner
update public.platform_memberships pm set role_id=(select id from public.platform_roles where code='owner')
from app_private.superadmin_internal_actor_people a
where pm.id=a.platform_membership_id and a.internal_identity_id='d3000000-0000-4000-8000-000000000004';
select app_private.superadmin_internal_actor_institution_access_sync();
select is(pg_temp.active_roles('d3000000-0000-4000-8000-000000000004'), array['institution_admin'], 'promovido: reader revogado, institution_admin concedido');

-- 16: revogacao do papel interno (auditor) tira a membership automatica de quem tinha
update public.platform_memberships pm set role_id=(select id from public.platform_roles where code='auditor')
from app_private.superadmin_internal_actor_people a
where pm.id=a.platform_membership_id and a.internal_identity_id='d3000000-0000-4000-8000-000000000004';
select app_private.superadmin_internal_actor_institution_access_sync();
select is(pg_temp.active_membership_count('d3000000-0000-4000-8000-000000000004'), 0, 'papel sem alvo: membership automatica revogada');

select * from finish();
rollback;
