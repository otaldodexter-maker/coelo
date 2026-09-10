-- Prova do pacote 20260910150000: o feed do Acontece pagina de verdade.
--
-- list_visible_happens_posts nascia com teto e sem cursor: quem tivesse mais
-- publicacoes do que o limite nunca via o resto, e o carregar mais da tela nao
-- tinha para onde ir. O Owner respondeu em 10/09/2026 (D3 e D5) que nao existe
-- previa: o feed funciona de verdade, com paginacao do servidor.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select has_function(
  'public', 'list_visible_happens_posts',
  array['uuid', 'uuid', 'uuid', 'integer', 'timestamp with time zone', 'uuid'],
  'the feed accepts a keyset cursor');
select ok(
  has_function_privilege('authenticated',
    'public.list_visible_happens_posts(uuid,uuid,uuid,integer,timestamptz,uuid)', 'execute')
  and not has_function_privilege('anon',
    'public.list_visible_happens_posts(uuid,uuid,uuid,integer,timestamptz,uuid)', 'execute'),
  'the paginated feed stays authenticated only');

insert into auth.users(id) values ('a2000000-0000-4000-8000-000000000001');
insert into public.people(id, person_type, first_name, last_name, display_name, status) values
  ('a2100000-0000-4000-8000-000000000001', 'adult', 'Ana', 'Leitora', 'Ana Leitora', 'active');
insert into public.person_auth_links(person_id, auth_user_id, status) values
  ('a2100000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'active');
insert into public.institutions(id, public_name, legal_name, slug, status) values
  ('a2200000-0000-4000-8000-000000000001', 'Acontece Paginacao', 'Acontece Paginacao', 'acontece-paginacao', 'active');
insert into public.institution_memberships(id, person_id, institution_id, role_code, status, scope_kind) values
  ('a2300000-0000-4000-8000-000000000001', 'a2100000-0000-4000-8000-000000000001',
   'a2200000-0000-4000-8000-000000000001', 'teacher', 'active', 'institution');
insert into public.institution_member_permission_overrides(
  membership_id, permission_code, effect, scope_kind, reason, status, changed_by_person_id) values
  ('a2300000-0000-4000-8000-000000000001', 'happens.posts.read', 'allow', 'institution',
   'fixture: leitura do feed', 'active', 'a2100000-0000-4000-8000-000000000001');

-- Tres publicacoes visiveis, com instantes distintos e decrescentes.
insert into public.posts(
  id, institution_id, author_person_id, author_membership_id, caption, status,
  publish_at, published_at, management_version)
select
  ('a2400000-0000-4000-8000-00000000000' || position::text)::uuid,
  'a2200000-0000-4000-8000-000000000001',
  'a2100000-0000-4000-8000-000000000001',
  'a2300000-0000-4000-8000-000000000001',
  'Publicacao ' || position::text,
  'published',
  now() - (position || ' hours')::interval,
  now() - (position || ' hours')::interval,
  1
from generate_series(1, 3) as position;
insert into public.post_audiences(post_id, audience_kind, institution_id)
select ('a2400000-0000-4000-8000-00000000000' || position::text)::uuid,
  'school_staff', 'a2200000-0000-4000-8000-000000000001'
from generate_series(1, 3) as position;

create function pg_temp.feed_page(
  p_limit integer, p_cursor_at timestamptz, p_cursor_id uuid)
returns table(feed_post_id uuid, feed_published_at timestamptz)
language plpgsql as $fn$
begin
  perform set_config(
    'request.jwt.claim.sub', 'a2000000-0000-4000-8000-000000000001', true);
  set local role authenticated;
  return query
    select visible.post_id, visible.published_at
    from public.list_visible_happens_posts(
      'a2200000-0000-4000-8000-000000000001', null, null,
      p_limit, p_cursor_at, p_cursor_id) visible;
  reset role;
end
$fn$;

create temporary table happens_pagination_pages as
select 'first' as label, feed_post_id, feed_published_at
from pg_temp.feed_page(2, null, null);

insert into happens_pagination_pages
select 'second', page.feed_post_id, page.feed_published_at
from pg_temp.feed_page(
  2,
  (select feed_published_at from happens_pagination_pages
   where label = 'first' order by feed_published_at limit 1),
  (select feed_post_id from happens_pagination_pages
   where label = 'first' order by feed_published_at limit 1)) page;

select is(
  (select count(*) from happens_pagination_pages where label = 'first'),
  2::bigint, 'the first page honours the requested limit instead of a fixed ceiling');
select is(
  (select count(*) from happens_pagination_pages where label = 'second'),
  1::bigint, 'the second page returns the remainder and nothing else');
select is(
  (select count(distinct feed_post_id) from happens_pagination_pages),
  3::bigint, 'paging covers every visible post exactly once, with no gap and no repeat');
select throws_ok(
  $$select * from public.list_visible_happens_posts(
    'a2200000-0000-4000-8000-000000000001', null, null, 20, now(), null)$$,
  '22023', 'cursor values must be provided together',
  'half a cursor is malformed input, not a request for the first page');

select * from finish();
rollback;
