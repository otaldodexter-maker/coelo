-- Retirada de publicacao do Acontece (action_id acontece.remove): prova
-- comportamental.
--
-- A versao anterior deste arquivo era quase toda assertiva sobre
-- `pg_get_functiondef` e sobre catalogo. Substring nao prova comportamento: o
-- texto `expected_version_conflict` continuava dentro da funcao mesmo quando a
-- guarda `<>` deixava `p_expected_version` nulo devolver NULL e escapar do lock
-- otimista, e o texto `happens.posts.remove` nao dizia se o feed conferia a
-- capacidade ou apenas a autoria. As duas correcoes de
-- `20260909133000_happens_post_withdrawal_v1.sql` sao exatamente desse tipo,
-- entao aqui o corpo do teste exercita as RPCs reais com fixtures reais.
--
-- Estrutura: um punhado minimo de asserçoes de contrato (colunas, definer,
-- search_path, grants) e, depois, comportamento ponta a ponta dentro da
-- transacao, com `rollback` ao final.

begin;
create extension if not exists pgtap with schema extensions;
select plan(33);

-- ---------------------------------------------------------------------------
-- Contrato estrutural minimo.
-- ---------------------------------------------------------------------------

select has_column('public','posts','withdrawn_at','withdrawal timestamp exists');
select has_column('public','posts','withdrawn_by_person_id','withdrawal actor exists');
select has_column('public','posts','withdrawal_reason','withdrawal reason exists');

select ok(
  (select prosecdef from pg_proc
   where oid='public.withdraw_happens_post(uuid,uuid,bigint,text)'::regprocedure)
  and (select prosecdef from pg_proc
       where oid='public.list_visible_happens_posts(uuid,uuid,uuid,integer)'::regprocedure),
  'withdrawal and feed run as security definer'
);

select ok(
  (select coalesce(proconfig,'{}'::text[]) from pg_proc
   where oid='public.withdraw_happens_post(uuid,uuid,bigint,text)'::regprocedure)
    @> array['search_path=""']::text[]
  and (select coalesce(proconfig,'{}'::text[]) from pg_proc
       where oid='public.list_visible_happens_posts(uuid,uuid,uuid,integer)'::regprocedure)
    @> array['search_path=""']::text[],
  'withdrawal and feed pin an empty search path'
);

select ok(
  has_function_privilege('authenticated','public.withdraw_happens_post(uuid,uuid,bigint,text)','execute')
  and has_function_privilege('authenticated','public.list_visible_happens_posts(uuid,uuid,uuid,integer)','execute'),
  'authenticated actors reach both contracts'
);

select ok(
  not has_function_privilege('anon','public.withdraw_happens_post(uuid,uuid,bigint,text)','execute')
  and not has_function_privilege('anon','public.list_visible_happens_posts(uuid,uuid,uuid,integer)','execute'),
  'anonymous callers reach neither contract'
);

-- ---------------------------------------------------------------------------
-- Fixtures.
--
--   Tenant A  instituicao dona das publicacoes
--   Tenant B  instituicao vizinha, usada para o isolamento por instituicao
--   P1        autora das publicacoes, membro de A e de B
--   P2        colega da mesma instituicao, NAO autora
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
-- Auxiliares: cada chamada troca para o papel `authenticated` e apresenta o
-- `sub` do JWT, como o cliente faria. A negativa e devolvida como
-- `sqlstate:mensagem` para que a asserçao compare comportamento observado, e
-- nao texto de codigo-fonte.
-- ---------------------------------------------------------------------------

create function pg_temp.try_withdraw(
  p_sub uuid, p_request uuid, p_post uuid, p_version bigint, p_reason text
) returns text language plpgsql as $fn$
declare
  result jsonb;
begin
  perform set_config('request.jwt.claim.sub', p_sub::text, true);
  set local role authenticated;
  begin
    result := public.withdraw_happens_post(p_request, p_post, p_version, p_reason);
    reset role;
    return 'ok:' || coalesce(result->>'management_version','null');
  exception when others then
    reset role;
    return sqlstate || ':' || sqlerrm;
  end;
end
$fn$;

create function pg_temp.feed(p_sub uuid, p_institution uuid)
returns table(post_id uuid, management_version bigint, can_withdraw boolean)
language plpgsql as $fn$
begin
  perform set_config('request.jwt.claim.sub', p_sub::text, true);
  set local role authenticated;
  return query
    select visible.post_id, visible.management_version, visible.can_withdraw
    from public.list_visible_happens_posts(p_institution, null, null, 50) visible;
  reset role;
end
$fn$;

-- ---------------------------------------------------------------------------
-- Feed: identidade, versao e `can_withdraw` honesto.
-- ---------------------------------------------------------------------------

select is(
  (select count(*) from pg_temp.feed(
     'a1000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001')
   where post_id='a1400000-0000-4000-8000-000000000001'),
  1::bigint,
  'the feed projects post_id for the published post'
);

select is(
  (select management_version from pg_temp.feed(
     'a1000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001')
   where post_id='a1400000-0000-4000-8000-000000000001'),
  2::bigint,
  'the feed projects the real management_version, not a default'
);

select is(
  (select can_withdraw from pg_temp.feed(
     'a1000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001')
   where post_id='a1400000-0000-4000-8000-000000000001'),
  false,
  'the author without happens.posts.remove is offered no withdrawal'
);

-- A autora recebe a capacidade de remocao.
insert into public.institution_member_permission_overrides(
  membership_id,permission_code,effect,scope_kind,reason,status,changed_by_person_id) values
  ('a1300000-0000-4000-8000-000000000001','happens.posts.remove','allow','institution',
   'fixture: autora recebe a capacidade de remocao','active',
   'a1100000-0000-4000-8000-000000000001');

select is(
  (select can_withdraw from pg_temp.feed(
     'a1000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001')
   where post_id='a1400000-0000-4000-8000-000000000001'),
  true,
  'the same author with happens.posts.remove is offered the withdrawal'
);

select is(
  (select can_withdraw from pg_temp.feed(
     'a1000000-0000-4000-8000-000000000002','a1200000-0000-4000-8000-000000000001')
   where post_id='a1400000-0000-4000-8000-000000000001'),
  false,
  'a non-author holding happens.posts.remove is offered no withdrawal'
);

-- ---------------------------------------------------------------------------
-- Comando: negativas comportamentais.
-- ---------------------------------------------------------------------------

select is(
  pg_temp.try_withdraw(
    'a1000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000001',
    'a1400000-0000-4000-8000-000000000001', null, null),
  '40001:expected_version_conflict',
  'a null expected version is a conflict, not a silently waived optimistic lock'
);

select is(
  (select (withdrawn_at is null) and management_version=2 and status='published'
   from public.posts where id='a1400000-0000-4000-8000-000000000001'),
  true,
  'the rejected null-version call leaves the publication untouched'
);

select is(
  pg_temp.try_withdraw(
    'a1000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000002',
    'a1400000-0000-4000-8000-000000000001', 1, null),
  '40001:expected_version_conflict',
  'a stale expected version is refused'
);

select is(
  pg_temp.try_withdraw(
    'a1000000-0000-4000-8000-000000000002','a1600000-0000-4000-8000-000000000003',
    'a1400000-0000-4000-8000-000000000001', 2, null),
  '42501:happens_permission_denied',
  'a non-author holding the removal capability is still refused'
);

-- Um post inexistente devolve exatamente a mesma classe e a mesma mensagem do
-- post alheio. Se este teste falhar porque alguem reintroduziu post_not_found,
-- a regressao e de invariante: distinguir os dois entrega informacao antes da
-- autorizacao e vira um oraculo de existencia atravessando tenant.
select is(
  pg_temp.try_withdraw(
    'a1000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000009',
    'a14fffff-ffff-4fff-8fff-ffffffffffff', 1, null),
  '42501:happens_permission_denied',
  'a post that does not exist is refused exactly like a post that is not yours'
);

select is(
  pg_temp.try_withdraw(
    'a1000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000004',
    'a1400000-0000-4000-8000-000000000003', 1, null),
  '23514:post_not_published',
  'a draft cannot be withdrawn'
);

select is(
  pg_temp.try_withdraw(
    'a1000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000005',
    'a1400000-0000-4000-8000-000000000002', 1, repeat('m',281)),
  '23514:reason_too_long',
  'a reason longer than 280 characters is refused'
);

select is(
  (select (withdrawn_at is null) and management_version=1
   from public.posts where id='a1400000-0000-4000-8000-000000000002'),
  true,
  'the refused over-long reason leaves its publication untouched'
);

-- ---------------------------------------------------------------------------
-- Comando: caminho autorizado.
-- ---------------------------------------------------------------------------

select is(
  pg_temp.try_withdraw(
    'a1000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000006',
    'a1400000-0000-4000-8000-000000000001', 2, '   Publicado por engano   '),
  'ok:3',
  'the correct expected version withdraws and returns the new version'
);

select is(
  (select withdrawn_at is not null
      and withdrawn_by_person_id='a1100000-0000-4000-8000-000000000001'
      and management_version=3
      and status='published'
   from public.posts where id='a1400000-0000-4000-8000-000000000001'),
  true,
  'withdrawal stamps actor and time, bumps the version and keeps the status'
);

select is(
  (select withdrawal_reason from public.posts
   where id='a1400000-0000-4000-8000-000000000001'),
  'Publicado por engano',
  'the reason is trimmed before it is stored'
);

select is(
  (select count(*) from pg_temp.feed(
     'a1000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001')
   where post_id='a1400000-0000-4000-8000-000000000001'),
  0::bigint,
  'the withdrawn publication disappears from the feed'
);

select is(
  pg_temp.try_withdraw(
    'a1000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000007',
    'a1400000-0000-4000-8000-000000000001', 2, 'segunda tentativa'),
  'ok:3',
  'a second call is an idempotent echo instead of an error'
);

select is(
  (select management_version=3 and withdrawal_reason='Publicado por engano'
   from public.posts where id='a1400000-0000-4000-8000-000000000001'),
  true,
  'the idempotent echo neither bumps the version nor rewrites the reason'
);

select is(
  (select count(*) from app_private.happens_publication_audit
   where post_id='a1400000-0000-4000-8000-000000000001' and event_code='post_withdrawn'),
  1::bigint,
  'exactly one post_withdrawn audit row survives both calls'
);

select is(
  (select actor_person_id::text || '|' || (detail->>'request_id')
   from app_private.happens_publication_audit
   where post_id='a1400000-0000-4000-8000-000000000001' and event_code='post_withdrawn'),
  'a1100000-0000-4000-8000-000000000001|a1600000-0000-4000-8000-000000000006',
  'the audit row carries the actor and the request_id of the effective call'
);

select is(
  (select
     (select count(*) from public.posts where id='a1400000-0000-4000-8000-000000000001')
     + (select count(*) from public.media_links where post_id='a1400000-0000-4000-8000-000000000001')
     + (select count(*) from public.media_assets
        where id='a1500000-0000-4000-8000-000000000001' and status='ready')),
  3::bigint,
  'withdrawal is soft: post row, media link and media asset all survive'
);

-- Motivo em branco vira nulo.
select is(
  pg_temp.try_withdraw(
    'a1000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000008',
    'a1400000-0000-4000-8000-000000000002', 1, '    '),
  'ok:2',
  'a blank reason still withdraws'
);

select is(
  (select withdrawal_reason is null and withdrawn_at is not null
   from public.posts where id='a1400000-0000-4000-8000-000000000002'),
  true,
  'a blank reason is normalized to null'
);

-- ---------------------------------------------------------------------------
-- Isolamento por instituicao.
-- ---------------------------------------------------------------------------

select is(
  (select count(*) from pg_temp.feed(
     'a1000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000002')
   where post_id='a1400000-0000-4000-8000-000000000004'),
  1::bigint,
  'the neighbouring tenant feed is not trivially empty'
);

select is(
  (select count(*) from pg_temp.feed(
     'a1000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000002')
   where post_id in (
     'a1400000-0000-4000-8000-000000000001','a1400000-0000-4000-8000-000000000002',
     'a1400000-0000-4000-8000-000000000003')),
  0::bigint,
  'the neighbouring tenant feed never returns another institution publication'
);

select * from finish();
rollback;
