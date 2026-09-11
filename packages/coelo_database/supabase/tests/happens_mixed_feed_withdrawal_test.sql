-- Feed misto do Acontece coerente com a retirada (candidato
-- `20260909214000_happens_mixed_feed_withdrawal_v1.sql`): prova comportamental.
--
-- Este candidato era o unico dos seis de publicacoes-midia sem suite. Ele copia
-- "fielmente" o corpo grande de `public.list_visible_happens_feed` e altera duas
-- coisas: o predicado de retirada e dois campos novos no payload de post. Copia
-- fiel de corpo grande sem teste e onde a divergencia silenciosa se esconde, e
-- esta funcao alimenta o feed misto de Acontece que ja esta integrado e em uso.
--
-- As tres asserçoes exigidas antes da aplicacao: publicacao retirada some do
-- feed misto, `can_withdraw` verdadeiro somente para autor COM a capacidade no
-- escopo, e `management_version` projetado.

begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

-- ---------------------------------------------------------------------------
-- Contrato estrutural minimo.
-- ---------------------------------------------------------------------------

select ok(
  (select prosecdef from pg_proc
   where oid='public.list_visible_happens_feed(uuid,uuid,uuid,uuid,timestamptz,text,uuid,integer)'::regprocedure),
  'the mixed feed runs as security definer'
);

select ok(
  (select coalesce(proconfig,'{}'::text[]) from pg_proc
   where oid='public.list_visible_happens_feed(uuid,uuid,uuid,uuid,timestamptz,text,uuid,integer)'::regprocedure)
    @> array['search_path=""']::text[],
  'the mixed feed pins an empty search path'
);

select ok(
  has_function_privilege('authenticated','public.list_visible_happens_feed(uuid,uuid,uuid,uuid,timestamptz,text,uuid,integer)','execute')
  and not has_function_privilege('anon','public.list_visible_happens_feed(uuid,uuid,uuid,uuid,timestamptz,text,uuid,integer)','execute'),
  'create or replace preserved the original grants'
);

-- ---------------------------------------------------------------------------
-- Fixtures (as mesmas de happens_post_withdrawal_test.sql).
-- ---------------------------------------------------------------------------

insert into auth.users(id) values
  ('a1000000-0000-4000-8000-000000000001'),
  ('a1000000-0000-4000-8000-000000000002');

insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('a1100000-0000-4000-8000-000000000001','adult','Ana','Autora','Ana Autora','active'),
  ('a1100000-0000-4000-8000-000000000002','adult','Bruno','Colega','Bruno Colega','active');

insert into public.person_auth_links(person_id,auth_user_id,status) values
  ('a1100000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','active'),
  ('a1100000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002','active');

insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('a1200000-0000-4000-8000-000000000001','Acontece Tenant A','Acontece Tenant A','acontece-tenant-a','active'),
  ('a1200000-0000-4000-8000-000000000002','Acontece Tenant B','Acontece Tenant B','acontece-tenant-b','active');

insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
  ('a1300000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000001',
   'a1200000-0000-4000-8000-000000000001','teacher','active','institution'),
  ('a1300000-0000-4000-8000-000000000002','a1100000-0000-4000-8000-000000000002',
   'a1200000-0000-4000-8000-000000000001','teacher','active','institution'),
  ('a1300000-0000-4000-8000-000000000003','a1100000-0000-4000-8000-000000000001',
   'a1200000-0000-4000-8000-000000000002','teacher','active','institution');

-- P1 comeca somente com leitura no Tenant A: e a situacao que precisa produzir
-- `can_withdraw = false` mesmo sendo autora.
insert into public.institution_member_permission_overrides(
  membership_id,permission_code,effect,scope_kind,reason,status,changed_by_person_id) values
  ('a1300000-0000-4000-8000-000000000001','happens.posts.read','allow','institution',
   'fixture: autora le o feed','active','a1100000-0000-4000-8000-000000000001'),
  ('a1300000-0000-4000-8000-000000000002','happens.posts.read','allow','institution',
   'fixture: colega le o feed','active','a1100000-0000-4000-8000-000000000001'),
  ('a1300000-0000-4000-8000-000000000002','happens.posts.remove','allow','institution',
   'fixture: colega pode remover, mas nao e autor','active','a1100000-0000-4000-8000-000000000001'),
  ('a1300000-0000-4000-8000-000000000003','happens.posts.read','allow','institution',
   'fixture: leitura no tenant vizinho','active','a1100000-0000-4000-8000-000000000001');

-- O alvo da retirada nasce com `management_version` = 2 de proposito, para que
-- a projecao de versao no feed nao possa passar pelo default 1.
insert into public.posts(
  id,institution_id,author_person_id,author_membership_id,caption,status,
  publish_at,published_at,management_version) values
  ('a1400000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001',
   'a1100000-0000-4000-8000-000000000001','a1300000-0000-4000-8000-000000000001',
   'Publicacao alvo da retirada','published',now()-interval '1 hour',now()-interval '1 hour',2),
  ('a1400000-0000-4000-8000-000000000002','a1200000-0000-4000-8000-000000000001',
   'a1100000-0000-4000-8000-000000000001','a1300000-0000-4000-8000-000000000001',
   'Publicacao usada para normalizar o motivo','published',now()-interval '2 hours',now()-interval '2 hours',1),
  ('a1400000-0000-4000-8000-000000000003','a1200000-0000-4000-8000-000000000001',
   'a1100000-0000-4000-8000-000000000001','a1300000-0000-4000-8000-000000000001',
   'Rascunho que nunca foi publicado','draft',null,null,1),
  ('a1400000-0000-4000-8000-000000000004','a1200000-0000-4000-8000-000000000002',
   'a1100000-0000-4000-8000-000000000001','a1300000-0000-4000-8000-000000000003',
   'Publicacao do tenant vizinho','published',now()-interval '1 hour',now()-interval '1 hour',1);

insert into public.post_audiences(post_id,audience_kind,institution_id) values
  ('a1400000-0000-4000-8000-000000000001','school_staff','a1200000-0000-4000-8000-000000000001'),
  ('a1400000-0000-4000-8000-000000000002','school_staff','a1200000-0000-4000-8000-000000000001'),
  ('a1400000-0000-4000-8000-000000000003','school_staff','a1200000-0000-4000-8000-000000000001'),
  ('a1400000-0000-4000-8000-000000000004','school_staff','a1200000-0000-4000-8000-000000000002');

insert into public.media_assets(
  id,institution_id,post_id,owner_person_id,upload_request_id,storage_provider,bucket_id,object_key,
  original_name,mime_type,byte_size,status,finalized_at) values
  ('a1500000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001',
   'a1400000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000001',
   'fixture-upload-1','supabase_mvp','coelo-happens-mvp','a1200000-0000-4000-8000-000000000001/a1400000-0000-4000-8000-000000000001/one',
   'foto.jpg','image/jpeg',2048,'ready',now());

insert into public.media_links(post_id,media_asset_id,display_order) values
  ('a1400000-0000-4000-8000-000000000001','a1500000-0000-4000-8000-000000000001',0);


-- ---------------------------------------------------------------------------
-- Auxiliar: le o feed MISTO como o cliente faria e projeta so o que importa.
-- ---------------------------------------------------------------------------

create function pg_temp.mixed_posts(p_sub uuid, p_institution uuid)
returns table(item_id uuid, management_version bigint, can_withdraw boolean)
language plpgsql as $fn$
begin
  perform set_config('request.jwt.claim.sub', p_sub::text, true);
  set local role authenticated;
  return query
    select feed.item_id,
           (feed.payload->>'management_version')::bigint,
           (feed.payload->>'can_withdraw')::boolean
    from public.list_visible_happens_feed(
      p_institution, null, null, null, null, null, null, 50) feed
    where feed.item_type = 'post';
  reset role;
end
$fn$;

-- ---------------------------------------------------------------------------
-- 1. `management_version` projetado.
-- ---------------------------------------------------------------------------

select is(
  (select management_version from pg_temp.mixed_posts(
     'a1000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001')
   where item_id='a1400000-0000-4000-8000-000000000001'),
  2::bigint,
  'the mixed feed projects the real management version, not the default'
);

-- ---------------------------------------------------------------------------
-- 2. `can_withdraw` confere autoria E capacidade no escopo.
--
-- P1 e autora e comeca somente com `happens.posts.read`: oferecer a retirada
-- aqui seria uma promessa que o servidor negaria em seguida. P2 tem a
-- capacidade `happens.posts.remove` mas NAO e autora.
-- ---------------------------------------------------------------------------

select is(
  (select can_withdraw from pg_temp.mixed_posts(
     'a1000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001')
   where item_id='a1400000-0000-4000-8000-000000000001'),
  false,
  'the author without the removal capability is not offered the withdrawal'
);

select is(
  (select can_withdraw from pg_temp.mixed_posts(
     'a1000000-0000-4000-8000-000000000002','a1200000-0000-4000-8000-000000000001')
   where item_id='a1400000-0000-4000-8000-000000000001'),
  false,
  'a non author holding the removal capability is not offered the withdrawal'
);

insert into public.institution_member_permission_overrides(
  membership_id,permission_code,effect,scope_kind,reason,status,changed_by_person_id) values
  ('a1300000-0000-4000-8000-000000000001','happens.posts.remove','allow','institution',
   'fixture: autora recebe a capacidade','active','a1100000-0000-4000-8000-000000000001');

select is(
  (select can_withdraw from pg_temp.mixed_posts(
     'a1000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001')
   where item_id='a1400000-0000-4000-8000-000000000001'),
  true,
  'the author with the removal capability in scope is offered the withdrawal'
);

-- ---------------------------------------------------------------------------
-- 3. Publicacao retirada some do feed misto.
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::int from pg_temp.mixed_posts(
     'a1000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001')
   where item_id='a1400000-0000-4000-8000-000000000001'),
  1,
  'the target publication is visible before the withdrawal'
);

update public.posts
set withdrawn_at = now(),
    withdrawn_by_person_id = 'a1100000-0000-4000-8000-000000000001'
where id = 'a1400000-0000-4000-8000-000000000001';

select is(
  (select count(*)::int from pg_temp.mixed_posts(
     'a1000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001')
   where item_id='a1400000-0000-4000-8000-000000000001'),
  0,
  'a withdrawn publication disappears from the mixed feed'
);

select isnt(
  (select count(*)::int from pg_temp.mixed_posts(
     'a1000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001')),
  0,
  'the withdrawal removes only the withdrawn publication, not the feed'
);

select * from finish();
rollback;
