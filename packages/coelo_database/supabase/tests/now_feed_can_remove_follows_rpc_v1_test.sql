-- Prova pgTAP da migration 20260918140000_now_feed_can_remove_follows_rpc_v1
-- (R16 Sessao RESERVA, D6 padrao "o feed segue a RPC" / divida can-remove, ADR 0044; ADR 0040):
-- can_remove reflete quem remove_now_publication aceita (capacidade now.publications.remove no
-- escopo), sem exigir autoria. Fixture da suite now_feed_removal_projection_v1 (prefixo c3) mais
-- um administrador D (nao autor, mesmo tenant, com remove).
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

select ok(
  position('can_remove:=actor_can_remove;' in pg_get_functiondef('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure))>0
  and position('author_person_id=actor.person_id' in pg_get_functiondef('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure))=0,
  'can_remove follows the remove permission only (feed follows the RPC)');
select ok(position('now_reader_actor' in pg_get_functiondef('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure))>0, 'feed keeps now_reader_actor (lote 81)');
select ok(
  has_function_privilege('authenticated','public.list_visible_now_publications(uuid,uuid,uuid,integer)','EXECUTE')
  and not has_function_privilege('anon','public.list_visible_now_publications(uuid,uuid,uuid,integer)','EXECUTE'),
  'feed keeps authenticated-only execution');

-- Fixtures.
insert into public.people(id,person_type,first_name,last_name,display_name)
values ('c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema')
on conflict (id) do nothing;
insert into auth.users(id) values
  ('c3100000-0000-4000-8000-000000000011'),
  ('c3100000-0000-4000-8000-000000000012'),
  ('c3100000-0000-4000-8000-000000000013'),
  ('c3100000-0000-4000-8000-000000000014');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('c3200000-0000-4000-8000-000000000011','adult','Agora','Autor A','Agora Autor A','active'),
  ('c3200000-0000-4000-8000-000000000012','adult','Agora','Ator B','Agora Ator B','active'),
  ('c3200000-0000-4000-8000-000000000013','adult','Agora','Leitor C','Agora Leitor C','active'),
  ('c3200000-0000-4000-8000-000000000014','adult','Agora','Admin D','Agora Admin D','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
  ('c3200000-0000-4000-8000-000000000011','c3100000-0000-4000-8000-000000000011','active'),
  ('c3200000-0000-4000-8000-000000000012','c3100000-0000-4000-8000-000000000012','active'),
  ('c3200000-0000-4000-8000-000000000013','c3100000-0000-4000-8000-000000000013','active'),
  ('c3200000-0000-4000-8000-000000000014','c3100000-0000-4000-8000-000000000014','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('c3300000-0000-4000-8000-000000000011','Agora CR A','Agora CR A','agora-cr-a','active'),
  ('c3300000-0000-4000-8000-000000000012','Agora CR B','Agora CR B','agora-cr-b','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
  ('c3400000-0000-4000-8000-000000000011','c3200000-0000-4000-8000-000000000011','c3300000-0000-4000-8000-000000000011','teacher','active','institution'),
  ('c3400000-0000-4000-8000-000000000012','c3200000-0000-4000-8000-000000000012','c3300000-0000-4000-8000-000000000012','teacher','active','institution'),
  ('c3400000-0000-4000-8000-000000000013','c3200000-0000-4000-8000-000000000013','c3300000-0000-4000-8000-000000000011','teacher','active','institution'),
  ('c3400000-0000-4000-8000-000000000014','c3200000-0000-4000-8000-000000000014','c3300000-0000-4000-8000-000000000011','institution_admin','active','institution');
insert into public.institution_member_permission_overrides(
  membership_id,permission_code,effect,scope_kind,reason,status,changed_by_person_id) values
  ('c3400000-0000-4000-8000-000000000011','now.publications.read','allow','institution','fixture','active','c3200000-0000-4000-8000-000000000011'),
  ('c3400000-0000-4000-8000-000000000011','now.publications.remove','allow','institution','fixture','active','c3200000-0000-4000-8000-000000000011'),
  ('c3400000-0000-4000-8000-000000000012','now.publications.read','allow','institution','fixture','active','c3200000-0000-4000-8000-000000000012'),
  ('c3400000-0000-4000-8000-000000000012','now.publications.remove','allow','institution','fixture','active','c3200000-0000-4000-8000-000000000012'),
  ('c3400000-0000-4000-8000-000000000013','now.publications.read','allow','institution','fixture','active','c3200000-0000-4000-8000-000000000013'),
  ('c3400000-0000-4000-8000-000000000014','now.publications.read','allow','institution','fixture','active','c3200000-0000-4000-8000-000000000014'),
  ('c3400000-0000-4000-8000-000000000014','now.publications.remove','allow','institution','fixture','active','c3200000-0000-4000-8000-000000000014');
-- Classe de leitor school_staff exige papel institucional com now.publications.read (now_viewer_role_class).
insert into public.institution_roles(id,institution_id,code,name,max_scope_kind) values
  ('c3700000-0000-4000-8000-000000000011','c3300000-0000-4000-8000-000000000011','agora_cr_reader','Agora CR reader','institution');
insert into public.institution_role_permissions(role_id,permission_id)
select 'c3700000-0000-4000-8000-000000000011',id from public.institution_permissions where code='now.publications.read';
insert into public.institution_role_assignments(membership_id,role_id,scope_kind) values
  ('c3400000-0000-4000-8000-000000000011','c3700000-0000-4000-8000-000000000011','institution'),
  ('c3400000-0000-4000-8000-000000000013','c3700000-0000-4000-8000-000000000011','institution'),
  ('c3400000-0000-4000-8000-000000000014','c3700000-0000-4000-8000-000000000011','institution');
insert into public.now_publications(
  id,institution_id,author_person_id,author_membership_id,caption,status,publish_at,published_at,expires_at,management_version)
values (
  'c3500000-0000-4000-8000-000000000011','c3300000-0000-4000-8000-000000000011',
  'c3200000-0000-4000-8000-000000000011','c3400000-0000-4000-8000-000000000011',
  'Projection target','published',now(),now(),now()+interval '1 hour',2
);
insert into public.now_publication_audiences(publication_id,institution_id,unit_id,group_id,audience_kind)
values ('c3500000-0000-4000-8000-000000000011','c3300000-0000-4000-8000-000000000011',null,null,'school_staff');


-- Admin D (nao autor, com now.publications.remove): can_remove true e a RPC remove.
select set_config('request.jwt.claim.sub','c3100000-0000-4000-8000-000000000014',true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','c3100000-0000-4000-8000-000000000014','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select is((select can_remove from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000011',null,null,20)
  where publication_id='c3500000-0000-4000-8000-000000000011'),true,
  'non-author admin with now.publications.remove sees can_remove true');
select is((select can_remove from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000011',null,null,20)
  where publication_id='c3500000-0000-4000-8000-000000000011'),
  (select app_private.has_institution_permission('c3300000-0000-4000-8000-000000000011','now.publications.remove',null,null,false)),
  'projection equals the RPC predicate for the admin');
reset role;

-- Leitor C (sem remove): can_remove false e a RPC nega sem mutar.
select set_config('request.jwt.claim.sub','c3100000-0000-4000-8000-000000000013',true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','c3100000-0000-4000-8000-000000000013','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select is((select can_remove from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000011',null,null,20)
  where publication_id='c3500000-0000-4000-8000-000000000011'),false,
  'member without remove sees can_remove false');
select throws_ok($$select public.remove_now_publication('c3600000-0000-4000-8000-000000000013','c3500000-0000-4000-8000-000000000011',2,'sem direito')$$,
  '42501',null,'RPC denies the member without remove (feed and RPC agree)');
reset role;
select is((select status from public.now_publications where id='c3500000-0000-4000-8000-000000000011'),'published','denied removal did not mutate');

-- Admin D remove de fato (mesma versao projetada), e a publicacao some do feed.
select set_config('request.jwt.claim.sub','c3100000-0000-4000-8000-000000000014',true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','c3100000-0000-4000-8000-000000000014','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select lives_ok($$select public.remove_now_publication('c3600000-0000-4000-8000-000000000014','c3500000-0000-4000-8000-000000000011',2,'D6 admin remove')$$,
  'RPC accepts the non-author admin exactly as the projection promised');
select is((select count(*)::int from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000011',null,null,20) where publication_id='c3500000-0000-4000-8000-000000000011'),0,
  'removed publication leaves the feed');
reset role;
select is((select status from public.now_publications where id='c3500000-0000-4000-8000-000000000011'),'removed','publication removed by the admin');

select * from finish();
rollback;
