-- Somente replay LOCAL descartavel. Fixtures sinteticas com rollback. Nenhuma conta real.
-- Prova da migration 20260917203000_now_guardian_reader_v1 (R16 Sessao AGORA, ADR 0044, OQ-048, spec 070):
-- o leitor do Agora reconhece o responsavel por guardian_links ativo + guardian_context_permissions.can_view
-- na instituicao da publicacao, sem membership institucional; equipe continua lendo como hoje; audiencias
-- isoladas (equipe nao ve Familias; responsavel nao ve equipe); sem vinculo/cross-tenant -> 42501;
-- expiradas/removidas ausentes; ticket de midia resgatavel pelo responsavel; now_actor (escrita) inalterado.
-- Fixtures no padrao de now_feed_removal_projection_v1_test (pessoa tecnica Coelo semeada de forma idempotente).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select extensions.plan(21);

-- 1. Contrato e grants.
select has_function('app_private','now_reader_actor',array['uuid','text','uuid','uuid'],'now_reader_actor (leitura) exists');
select ok(
  not has_function_privilege('authenticated','app_private.now_reader_actor(uuid,text,uuid,uuid)','EXECUTE')
  and not has_function_privilege('anon','app_private.now_reader_actor(uuid,text,uuid,uuid)','EXECUTE'),
  'clients cannot call the private reader resolver');
select ok(
  position('now_reader_actor' in pg_get_functiondef('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure))>0
  and position('now.publications.read' in pg_get_functiondef('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure))>0
  and position('now_viewer_role_class' in pg_get_functiondef('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure))>0,
  'feed resolves the reader through now_reader_actor and keeps the authoritative classifier');
select ok(
  has_function_privilege('authenticated','public.list_visible_now_publications(uuid,uuid,uuid,integer)','EXECUTE')
  and not has_function_privilege('anon','public.list_visible_now_publications(uuid,uuid,uuid,integer)','EXECUTE')
  and has_function_privilege('service_role','public.redeem_now_media_read_ticket(uuid,uuid)','EXECUTE')
  and not has_function_privilege('authenticated','public.redeem_now_media_read_ticket(uuid,uuid)','EXECUTE'),
  'feed and ticket redemption keep their grants');
select ok(
  position('now_viewer_role_class' in pg_get_functiondef('public.redeem_now_media_read_ticket(uuid,uuid)'::regprocedure))>0
  and position('membership.role_code' in pg_get_functiondef('public.redeem_now_media_read_ticket(uuid,uuid)'::regprocedure))=0
  and position('now.publications.read' in pg_get_functiondef('app_private.now_actor(uuid,text,uuid,uuid)'::regprocedure))=0
  and position('now_viewer_role_class' in pg_get_functiondef('app_private.now_actor(uuid,text,uuid,uuid)'::regprocedure))=0,
  'ticket redemption revalidates the classifier; the write-side now_actor is untouched');

-- Fixtures.
insert into public.people(id,person_type,first_name,last_name,display_name)
values ('c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema')
on conflict (id) do nothing;
insert into auth.users(id) values
  ('c3100000-0000-4000-8000-000000000011'),  -- autor (equipe A)
  ('c3100000-0000-4000-8000-000000000012'),  -- responsavel G1 (vinculo em A)
  ('c3100000-0000-4000-8000-000000000013'),  -- responsavel G2 (sem vinculo)
  ('c3100000-0000-4000-8000-000000000014');  -- responsavel G3 (vinculo em B)
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('c3200000-0000-4000-8000-000000000011','adult','Agora','Autor A','Agora Autor A','active'),
  ('c3200000-0000-4000-8000-000000000012','adult','Agora','Resp G1','Agora Resp G1','active'),
  ('c3200000-0000-4000-8000-000000000013','adult','Agora','Resp G2','Agora Resp G2','active'),
  ('c3200000-0000-4000-8000-000000000014','adult','Agora','Resp G3','Agora Resp G3','active'),
  ('c3200000-0000-4000-8000-000000000021','child','Agora','Crianca A','Agora Crianca A','active'),
  ('c3200000-0000-4000-8000-000000000022','child','Agora','Crianca B','Agora Crianca B','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
  ('c3200000-0000-4000-8000-000000000011','c3100000-0000-4000-8000-000000000011','active'),
  ('c3200000-0000-4000-8000-000000000012','c3100000-0000-4000-8000-000000000012','active'),
  ('c3200000-0000-4000-8000-000000000013','c3100000-0000-4000-8000-000000000013','active'),
  ('c3200000-0000-4000-8000-000000000014','c3100000-0000-4000-8000-000000000014','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('c3300000-0000-4000-8000-000000000011','Agora Guard A','Agora Guard A','agora-guard-a','active'),
  ('c3300000-0000-4000-8000-000000000012','Agora Guard B','Agora Guard B','agora-guard-b','active');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id) values
  ('c3600000-0000-4000-8000-000000000011','c3300000-0000-4000-8000-000000000011','Agora Guard Unidade','agora-guard-unidade','agora.guard.unidade',
    (select id from public.unit_types where status='active' order by code limit 1));
-- Equipe A: membership + override + papel com now.publications.read (classe school_staff).
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
  ('c3400000-0000-4000-8000-000000000011','c3200000-0000-4000-8000-000000000011','c3300000-0000-4000-8000-000000000011','teacher','active','institution');
insert into public.institution_member_permission_overrides(
  membership_id,permission_code,effect,scope_kind,reason,status,changed_by_person_id) values
  ('c3400000-0000-4000-8000-000000000011','now.publications.read','allow','institution','fixture','active','c3200000-0000-4000-8000-000000000011');
insert into public.institution_roles(id,institution_id,code,name,max_scope_kind) values
  ('c3700000-0000-4000-8000-000000000011','c3300000-0000-4000-8000-000000000011','agora_guard_reader','Agora Guard reader','institution');
insert into public.institution_role_permissions(role_id,permission_id)
select 'c3700000-0000-4000-8000-000000000011',id from public.institution_permissions where code='now.publications.read';
insert into public.institution_role_assignments(membership_id,role_id,scope_kind) values
  ('c3400000-0000-4000-8000-000000000011','c3700000-0000-4000-8000-000000000011','institution');
-- Criancas e vinculos de responsavel (sem membership para G1/G2/G3).
insert into public.child_contexts(id,child_person_id,institution_id,status) values
  ('c3800000-0000-4000-8000-000000000021','c3200000-0000-4000-8000-000000000021','c3300000-0000-4000-8000-000000000011','active'),
  ('c3800000-0000-4000-8000-000000000022','c3200000-0000-4000-8000-000000000022','c3300000-0000-4000-8000-000000000012','active');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,relationship_type_id,status) values
  ('c3900000-0000-4000-8000-000000000012','c3200000-0000-4000-8000-000000000012','c3200000-0000-4000-8000-000000000021','responsavel',
    (select id from public.family_relationship_types where code='other' and status='active'),'active'),
  ('c3900000-0000-4000-8000-000000000014','c3200000-0000-4000-8000-000000000014','c3200000-0000-4000-8000-000000000022','responsavel',
    (select id from public.family_relationship_types where code='other' and status='active'),'active');
insert into public.guardian_context_permissions(guardian_link_id,child_context_id,can_view,status) values
  ('c3900000-0000-4000-8000-000000000012','c3800000-0000-4000-8000-000000000021',true,'active'),
  ('c3900000-0000-4000-8000-000000000014','c3800000-0000-4000-8000-000000000022',true,'active');
-- Publicacoes em A: P1 Familias vigente; P2 equipe vigente; P3 Familias expirada; P4 Familias removida.
insert into public.now_publications(
  id,institution_id,author_person_id,author_membership_id,caption,status,publish_at,published_at,expires_at,management_version,
  removed_at,removed_by_person_id,removal_reason)
values
  ('c3500000-0000-4000-8000-000000000011','c3300000-0000-4000-8000-000000000011','c3200000-0000-4000-8000-000000000011','c3400000-0000-4000-8000-000000000011',
   'Familias vigente','published',now()-interval '1 minute',now()-interval '1 minute',now()+interval '1 hour',2,null,null,null),
  ('c3500000-0000-4000-8000-000000000012','c3300000-0000-4000-8000-000000000011','c3200000-0000-4000-8000-000000000011','c3400000-0000-4000-8000-000000000011',
   'Equipe vigente','published',now()-interval '2 minute',now()-interval '2 minute',now()+interval '1 hour',1,null,null,null),
  ('c3500000-0000-4000-8000-000000000013','c3300000-0000-4000-8000-000000000011','c3200000-0000-4000-8000-000000000011','c3400000-0000-4000-8000-000000000011',
   'Familias expirada','expired',now()-interval '2 day',now()-interval '2 day',now()-interval '1 day',1,null,null,null),
  ('c3500000-0000-4000-8000-000000000014','c3300000-0000-4000-8000-000000000011','c3200000-0000-4000-8000-000000000011','c3400000-0000-4000-8000-000000000011',
   'Familias removida','removed',now()-interval '3 minute',now()-interval '3 minute',now()+interval '1 hour',2,now(),'c3200000-0000-4000-8000-000000000011','fixture');
insert into public.now_publication_audiences(publication_id,institution_id,unit_id,group_id,audience_kind) values
  ('c3500000-0000-4000-8000-000000000011','c3300000-0000-4000-8000-000000000011',null,null,'families'),
  ('c3500000-0000-4000-8000-000000000012','c3300000-0000-4000-8000-000000000011',null,null,'school_staff'),
  ('c3500000-0000-4000-8000-000000000013','c3300000-0000-4000-8000-000000000011',null,null,'families'),
  ('c3500000-0000-4000-8000-000000000014','c3300000-0000-4000-8000-000000000011',null,null,'families');
insert into public.now_media_assets(
  id,publication_id,institution_id,owner_person_id,kind,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size,
  checksum_sha256,status,finalized_at)
values (
  'c3a00000-0000-4000-8000-000000000011','c3500000-0000-4000-8000-000000000011','c3300000-0000-4000-8000-000000000011',
  'c3200000-0000-4000-8000-000000000011','media','r2','coelo-media-prod',
  'tenants/c3300000-0000-4000-8000-000000000011/now/publication/c3500000-0000-4000-8000-000000000011/media/c3a00000-0000-4000-8000-000000000011/original/c3b00000-0000-4000-8000-000000000011.png',
  'fixture.png','image/png',64,repeat('a',64),'ready',now());

-- 2. Responsavel G1 (vinculo em A, sem membership): ve so a story de Familias vigente, com ticket de midia.
select set_config('request.jwt.claim.sub','c3100000-0000-4000-8000-000000000012',true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','c3100000-0000-4000-8000-000000000012','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select is((select count(*)::int from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000011',null,null,20)),1,
  'guardian linked by guardian_links + can_view reads the feed without any membership');
select is((select publication_id from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000011',null,null,20)),
  'c3500000-0000-4000-8000-000000000011'::uuid,
  'guardian sees the current families story only (staff, expired and removed stories are absent)');
select is((select can_remove from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000011',null,null,20)),false,
  'guardian never gets can_remove');
select set_config('test.g1_ticket',
  (select media->0->>'read_ticket' from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000011',null,null,20)),true);
select ok(current_setting('test.g1_ticket',true)<>'','feed emits an opaque read ticket for the guardian (second call stable)');
select throws_ok($$select * from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000011','c3600000-0000-4000-8000-000000000011',null,20)$$,
  '42501',null,'guardian without a child link in the requested unit is denied');
select throws_ok($$select * from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000012',null,null,20)$$,
  '42501',null,'guardian of tenant A cannot read tenant B (cross-tenant denied)');
reset role;

-- 3. Ticket do responsavel e resgatado (worker, service path) e fica de uso unico; visitante errado e negado.
select is(
  (public.redeem_now_media_read_ticket(current_setting('test.g1_ticket',true)::uuid,'c3100000-0000-4000-8000-000000000012'))->>'object_key',
  'tenants/c3300000-0000-4000-8000-000000000011/now/publication/c3500000-0000-4000-8000-000000000011/media/c3a00000-0000-4000-8000-000000000011/original/c3b00000-0000-4000-8000-000000000011.png',
  'guardian redeems the media ticket without membership');
select throws_ok(
  format($$select public.redeem_now_media_read_ticket(%L::uuid,'c3100000-0000-4000-8000-000000000012')$$,current_setting('test.g1_ticket',true)),
  '42501',null,'redeemed ticket is single use');
select set_config('test.g1_ticket2',(select token::text from app_private.now_media_read_tickets
  where viewer_person_id='c3200000-0000-4000-8000-000000000012' order by expires_at desc limit 1),true);
select throws_ok(
  format($$select public.redeem_now_media_read_ticket(%L::uuid,'c3100000-0000-4000-8000-000000000011')$$,current_setting('test.g1_ticket2',true)),
  '42501',null,'ticket stays bound to the guardian who received it');

-- 4. Equipe A: continua lendo; nao ve Familias.
select set_config('request.jwt.claim.sub','c3100000-0000-4000-8000-000000000011',true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','c3100000-0000-4000-8000-000000000011','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select is((select count(*)::int from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000011',null,null,20)),1,
  'staff reader keeps reading the feed as before');
select is((select publication_id from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000011',null,null,20)),
  'c3500000-0000-4000-8000-000000000012'::uuid,
  'staff sees the staff story only (families audience isolated from staff)');
reset role;

-- 5. Responsavel G2 (sem vinculo) e G3 (vinculo em B) lendo A: 42501 sem vazamento.
select set_config('request.jwt.claim.sub','c3100000-0000-4000-8000-000000000013',true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','c3100000-0000-4000-8000-000000000013','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select throws_ok($$select * from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000011',null,null,20)$$,
  '42501',null,'guardian without any link is denied');
reset role;
select set_config('request.jwt.claim.sub','c3100000-0000-4000-8000-000000000014',true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','c3100000-0000-4000-8000-000000000014','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select throws_ok($$select * from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000011',null,null,20)$$,
  '42501',null,'guardian of tenant B cannot read tenant A');
select is((select count(*)::int from public.list_visible_now_publications('c3300000-0000-4000-8000-000000000012',null,null,20)),0,
  'guardian of tenant B reads tenant B (empty feed, no error)');
reset role;

-- 6. Escrita continua de equipe: now_actor nega o responsavel; leitura nao muta a publicacao.
select set_config('request.jwt.claim.sub','c3100000-0000-4000-8000-000000000012',true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','c3100000-0000-4000-8000-000000000012','role','authenticated','aal','aal1')::text,true);
select throws_ok($$select * from app_private.now_actor('c3300000-0000-4000-8000-000000000011','now.publications.create',null,null)$$,
  '42501',null,'guardian gains no write capability (now_actor unchanged)');
select is((select management_version from public.now_publications where id='c3500000-0000-4000-8000-000000000011'),2::bigint,
  'reading the feed does not change the publication version');

select * from extensions.finish();
rollback;
