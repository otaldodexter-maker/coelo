-- Somente replay LOCAL descartavel. Fixtures sinteticas com rollback. Nenhuma conta real.
-- Prova da migration 20260917140000_now_feed_removal_projection_v1 (R15 Bloco B, ADR 0040):
-- list_visible_now_publications projeta management_version e can_remove; can_remove so e
-- verdadeiro para o autor que tambem tem now.publications.remove no contexto; outro membro do
-- mesmo tenant ve a publicacao com can_remove false; ator de outro tenant continua 42501.
-- Fixtures no padrao de now_publication_removal_cross_tenant_test (pessoa tecnica Coelo exigida
-- pelo trigger de follows: semeada aqui de forma idempotente).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select extensions.plan(9);

-- 1. Assinatura ampliada e grants.
select is(
  pg_get_function_result('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure),
  'TABLE(publication_id uuid, author_name text, author_initials text, context_label text, caption text, overlay_text text, crop_scale numeric, crop_x numeric, crop_y numeric, cover_position numeric, published_at timestamp with time zone, expires_at timestamp with time zone, media jsonb, management_version bigint, can_remove boolean)',
  'feed projects management_version and can_remove after the presentation columns');
select ok(
  has_function_privilege('authenticated','public.list_visible_now_publications(uuid,uuid,uuid,integer)','EXECUTE')
  and not has_function_privilege('anon','public.list_visible_now_publications(uuid,uuid,uuid,integer)','EXECUTE'),
  'feed keeps authenticated-only execution');
-- 18/09 (D6, 20260918140000): o feed segue a RPC — can_remove exige so a capacidade no escopo,
-- como remove_now_publication; a autoria deixou de ser exigida na projecao.
select ok(
  position('now.publications.remove' in pg_get_functiondef('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure))>0
  and position('author_person_id=actor.person_id' in pg_get_functiondef('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure))=0,
  'can_remove requires the remove permission only (no new right; RPC stays the authority; D6)');

-- Fixtures.
insert into public.people(id,person_type,first_name,last_name,display_name)
values ('c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema')
on conflict (id) do nothing;
insert into auth.users(id) values
  ('c2100000-0000-4000-8000-000000000011'),
  ('c2100000-0000-4000-8000-000000000012'),
  ('c2100000-0000-4000-8000-000000000013');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('c2200000-0000-4000-8000-000000000011','adult','Agora','Autor A','Agora Autor A','active'),
  ('c2200000-0000-4000-8000-000000000012','adult','Agora','Ator B','Agora Ator B','active'),
  ('c2200000-0000-4000-8000-000000000013','adult','Agora','Leitor C','Agora Leitor C','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
  ('c2200000-0000-4000-8000-000000000011','c2100000-0000-4000-8000-000000000011','active'),
  ('c2200000-0000-4000-8000-000000000012','c2100000-0000-4000-8000-000000000012','active'),
  ('c2200000-0000-4000-8000-000000000013','c2100000-0000-4000-8000-000000000013','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('c2300000-0000-4000-8000-000000000011','Agora Proj A','Agora Proj A','agora-proj-a','active'),
  ('c2300000-0000-4000-8000-000000000012','Agora Proj B','Agora Proj B','agora-proj-b','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
  ('c2400000-0000-4000-8000-000000000011','c2200000-0000-4000-8000-000000000011','c2300000-0000-4000-8000-000000000011','teacher','active','institution'),
  ('c2400000-0000-4000-8000-000000000012','c2200000-0000-4000-8000-000000000012','c2300000-0000-4000-8000-000000000012','teacher','active','institution'),
  ('c2400000-0000-4000-8000-000000000013','c2200000-0000-4000-8000-000000000013','c2300000-0000-4000-8000-000000000011','teacher','active','institution');
insert into public.institution_member_permission_overrides(
  membership_id,permission_code,effect,scope_kind,reason,status,changed_by_person_id) values
  ('c2400000-0000-4000-8000-000000000011','now.publications.read','allow','institution','fixture','active','c2200000-0000-4000-8000-000000000011'),
  ('c2400000-0000-4000-8000-000000000011','now.publications.remove','allow','institution','fixture','active','c2200000-0000-4000-8000-000000000011'),
  ('c2400000-0000-4000-8000-000000000012','now.publications.read','allow','institution','fixture','active','c2200000-0000-4000-8000-000000000012'),
  ('c2400000-0000-4000-8000-000000000012','now.publications.remove','allow','institution','fixture','active','c2200000-0000-4000-8000-000000000012'),
  ('c2400000-0000-4000-8000-000000000013','now.publications.read','allow','institution','fixture','active','c2200000-0000-4000-8000-000000000013');
-- Classe de leitor school_staff exige papel institucional com now.publications.read (now_viewer_role_class).
insert into public.institution_roles(id,institution_id,code,name,max_scope_kind) values
  ('c2700000-0000-4000-8000-000000000011','c2300000-0000-4000-8000-000000000011','agora_proj_reader','Agora Proj reader','institution');
insert into public.institution_role_permissions(role_id,permission_id)
select 'c2700000-0000-4000-8000-000000000011',id from public.institution_permissions where code='now.publications.read';
insert into public.institution_role_assignments(membership_id,role_id,scope_kind) values
  ('c2400000-0000-4000-8000-000000000011','c2700000-0000-4000-8000-000000000011','institution'),
  ('c2400000-0000-4000-8000-000000000013','c2700000-0000-4000-8000-000000000011','institution');
insert into public.now_publications(
  id,institution_id,author_person_id,author_membership_id,caption,status,publish_at,published_at,expires_at,management_version)
values (
  'c2500000-0000-4000-8000-000000000011','c2300000-0000-4000-8000-000000000011',
  'c2200000-0000-4000-8000-000000000011','c2400000-0000-4000-8000-000000000011',
  'Projection target','published',now(),now(),now()+interval '1 hour',2
);
insert into public.now_publication_audiences(publication_id,institution_id,unit_id,group_id,audience_kind)
values ('c2500000-0000-4000-8000-000000000011','c2300000-0000-4000-8000-000000000011',null,null,'school_staff');

-- 2. Autor A: ve a publicacao com management_version 2 e can_remove true.
select set_config('request.jwt.claim.sub','c2100000-0000-4000-8000-000000000011',true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','c2100000-0000-4000-8000-000000000011','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select is((select count(*)::int from public.list_visible_now_publications('c2300000-0000-4000-8000-000000000011',null,null,20)),1,
  'author sees the published item in the feed');
select is((select management_version from public.list_visible_now_publications('c2300000-0000-4000-8000-000000000011',null,null,20)
  where publication_id='c2500000-0000-4000-8000-000000000011'),2::bigint,
  'feed projects the current management_version for the optimistic removal');
select is((select can_remove from public.list_visible_now_publications('c2300000-0000-4000-8000-000000000011',null,null,20)
  where publication_id='c2500000-0000-4000-8000-000000000011'),true,
  'author with now.publications.remove sees can_remove true');
reset role;

-- 3. Leitor C (mesmo tenant, sem remove): ve a publicacao com can_remove false.
select set_config('request.jwt.claim.sub','c2100000-0000-4000-8000-000000000013',true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','c2100000-0000-4000-8000-000000000013','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select is((select can_remove from public.list_visible_now_publications('c2300000-0000-4000-8000-000000000011',null,null,20)
  where publication_id='c2500000-0000-4000-8000-000000000011'),false,
  'non-author member of the same tenant sees can_remove false');
reset role;

-- 4. Ator B (outro tenant): 42501 sem vazamento.
select set_config('request.jwt.claim.sub','c2100000-0000-4000-8000-000000000012',true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','c2100000-0000-4000-8000-000000000012','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select throws_ok($$select * from public.list_visible_now_publications('c2300000-0000-4000-8000-000000000011',null,null,20)$$,
  '42501',null,'tenant B cannot read tenant A feed (no projection leak)');
reset role;

-- 5. A publicacao nao foi mutada pela leitura.
select is((select management_version from public.now_publications where id='c2500000-0000-4000-8000-000000000011'),2::bigint,
  'reading the feed does not change the publication version');

select * from extensions.finish();
rollback;
