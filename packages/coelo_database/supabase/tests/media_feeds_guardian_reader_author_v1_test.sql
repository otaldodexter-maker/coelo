-- Prova pgTAP da migration 20260920071000_media_feeds_guardian_reader_author_v1: leitor de família em
-- Momentos/Acontece/Circulares (guardian_links + can_view, sem membership) e author_person_id nos feeds.
-- Fixture sintética com rollback (prefixo f2): instituição A (unidade A1) e B.
-- T: professora em A (moments/happens/circulars read+remove por override). G1: responsável com can_view em A.
-- G2: responsável vinculado sem can_view. X: responsável só em B.
begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

create function pg_temp.f2(n integer) returns uuid language sql immutable as $$
  select ('f2000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
create function pg_temp.as_user(n integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', pg_temp.f2(n)::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.f2(n)::text, 'role', 'authenticated', 'aal', 'aal1')::text, true);
end $$;
create function pg_temp.try(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate || ':' || sqlerrm;
end $$;

-- ACL ---------------------------------------------------------------------------------------------
select ok((select bool_and(has_function_privilege('authenticated',p.oid,'execute') and not has_function_privilege('anon',p.oid,'execute'))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
  and p.proname in ('list_visible_moments','list_visible_happens_posts','list_visible_happens_feed','list_visible_now_publications',
    'get_visible_circular','list_visible_profile_circulars','authorize_moments_media_read','authorize_circular_media_read')),
  'feed/read RPCs: authenticated only');
select ok((select bool_and(not has_function_privilege('authenticated',p.oid,'execute'))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_private'
  and p.proname in ('family_reader_actor','moments_reader_actor','happens_reader_actor','circular_reader_actor')),
  'reader helpers are private');
select ok(position('author_person_id' in pg_get_function_result('public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)'::regprocedure)) > 0
  and position('author_person_id' in pg_get_function_result('public.list_visible_happens_posts(uuid,uuid,uuid,integer)'::regprocedure)) > 0
  and position('author_person_id' in pg_get_function_result('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure)) > 0,
  'feeds project author_person_id');

-- fixture ------------------------------------------------------------------------------------------
insert into public.institution_types(id,code,name,status) values (pg_temp.f2(1),'f2-type','F2 type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.f2(2),'f2-unit','F2 unit','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status,timezone) values
 (pg_temp.f2(10),pg_temp.f2(1),'F2 Instituicao A','f2-a','active','America/Sao_Paulo'),
 (pg_temp.f2(20),pg_temp.f2(1),'F2 Instituicao B','f2-b','active','America/Sao_Paulo');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status,timezone) values
 (pg_temp.f2(11),pg_temp.f2(10),'F2 Unidade A1','f2-unidade-a1','f2unidade.a1',pg_temp.f2(2),'active','America/Sao_Paulo');
insert into auth.users(id) values (pg_temp.f2(101)),(pg_temp.f2(104)),(pg_temp.f2(105)),(pg_temp.f2(106));
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.f2(201),'adult','F2','Professora T','F2 Professora T','active'),
 (pg_temp.f2(204),'adult','F2','Resp G1','F2 Resp G1','active'),
 (pg_temp.f2(205),'adult','F2','Resp G2','F2 Resp G2','active'),
 (pg_temp.f2(206),'adult','F2','Resp X','F2 Resp X','active'),
 (pg_temp.f2(221),'child','F2','Crianca A','F2 Crianca A','active'),
 (pg_temp.f2(222),'child','F2','Crianca B','F2 Crianca B','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.f2(201),pg_temp.f2(101),'active'),(pg_temp.f2(204),pg_temp.f2(104),'active'),
 (pg_temp.f2(205),pg_temp.f2(105),'active'),(pg_temp.f2(206),pg_temp.f2(106),'active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
 (pg_temp.f2(301),pg_temp.f2(201),pg_temp.f2(10),'teacher','active','institution');
insert into public.institution_member_permission_overrides(membership_id,permission_code,effect,scope_kind,reason,status,changed_by_person_id)
select pg_temp.f2(301),code,'allow','institution','fixture','active',pg_temp.f2(201)
from unnest(array['moments.publications.read','moments.publications.create','moments.publications.remove',
  'happens.posts.read','happens.posts.remove','circulars.circulars.read']) as code;
-- crianças: A em A (G1 com can_view, G2 sem); B em B (X com can_view)
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 (pg_temp.f2(401),pg_temp.f2(221),pg_temp.f2(10),'active'),
 (pg_temp.f2(402),pg_temp.f2(222),pg_temp.f2(20),'active');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,relationship_type_id,status) values
 (pg_temp.f2(411),pg_temp.f2(204),pg_temp.f2(221),'responsavel',(select id from public.family_relationship_types where code='other' and status='active'),'active'),
 (pg_temp.f2(412),pg_temp.f2(205),pg_temp.f2(221),'responsavel',(select id from public.family_relationship_types where code='other' and status='active'),'active'),
 (pg_temp.f2(413),pg_temp.f2(206),pg_temp.f2(222),'responsavel',(select id from public.family_relationship_types where code='other' and status='active'),'active');
insert into public.guardian_context_permissions(guardian_link_id,child_context_id,can_view,status) values
 (pg_temp.f2(411),pg_temp.f2(401),true,'active'),
 (pg_temp.f2(412),pg_temp.f2(401),false,'active'),
 (pg_temp.f2(413),pg_temp.f2(402),true,'active');

-- publicações de T em A: Momento para famílias (com mídia pronta) e Momento só para equipe (com mídia)
insert into public.moments_publications(id,institution_id,author_person_id,author_membership_id,caption,status,published_at) values
 (pg_temp.f2(500),pg_temp.f2(10),pg_temp.f2(201),pg_temp.f2(301),'momento familias','published',now()-interval '1 hour'),
 (pg_temp.f2(501),pg_temp.f2(10),pg_temp.f2(201),pg_temp.f2(301),'momento equipe','published',now()-interval '2 hour');
insert into public.moments_publication_audiences(publication_id,audience_kind,institution_id) values
 (pg_temp.f2(500),'families',pg_temp.f2(10)),(pg_temp.f2(501),'school_staff',pg_temp.f2(10));
insert into public.moments_media_assets(id,institution_id,publication_id,owner_person_id,upload_request_id,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size,status) values
 (pg_temp.f2(510),pg_temp.f2(10),pg_temp.f2(500),pg_temp.f2(201),pg_temp.f2(610),'cloudflare_r2','coelo-media-prod','moments/'||pg_temp.f2(10)::text||'/'||pg_temp.f2(500)::text||'/'||pg_temp.f2(510)::text||'.jpg','a.jpg','image/jpeg',1000,'ready'),
 (pg_temp.f2(511),pg_temp.f2(10),pg_temp.f2(501),pg_temp.f2(201),pg_temp.f2(611),'cloudflare_r2','coelo-media-prod','moments/'||pg_temp.f2(10)::text||'/'||pg_temp.f2(501)::text||'/'||pg_temp.f2(511)::text||'.jpg','b.jpg','image/jpeg',1000,'ready');
insert into public.moments_media_links(publication_id,media_asset_id,display_order) values (pg_temp.f2(500),pg_temp.f2(510),1),(pg_temp.f2(501),pg_temp.f2(511),1);
-- Acontece: post para famílias com mídia pronta
insert into public.posts(id,institution_id,author_person_id,author_membership_id,caption,status,publish_at,published_at) values
 (pg_temp.f2(520),pg_temp.f2(10),pg_temp.f2(201),pg_temp.f2(301),'acontece familias','published',now()-interval '1 hour',now()-interval '1 hour');
insert into public.post_audiences(post_id,audience_kind,institution_id) values (pg_temp.f2(520),'families',pg_temp.f2(10));
insert into public.media_assets(id,institution_id,post_id,owner_person_id,upload_request_id,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size,status,checksum_sha256,finalized_at) values
 (pg_temp.f2(521),pg_temp.f2(10),pg_temp.f2(520),pg_temp.f2(201),'f2-req-521','r2','coelo-media-prod','tenants/'||pg_temp.f2(10)::text||'/happens/post/'||pg_temp.f2(520)::text||'/attachment/'||pg_temp.f2(521)::text||'/original/'||pg_temp.f2(721)::text||'.jpg','c.jpg','image/jpeg',1000,'ready',repeat('c',64),now());
insert into public.media_links(post_id,media_asset_id,display_order) values (pg_temp.f2(520),pg_temp.f2(521),1);
-- Circular publicada para famílias com um bloco de mídia pronto
insert into public.circulars(id,institution_id,author_person_id,author_membership_id,status,response_policy,publish_at,published_at) values
 (pg_temp.f2(530),pg_temp.f2(10),pg_temp.f2(201),pg_temp.f2(301),'published','per_person',now()-interval '1 hour',now()-interval '1 hour');
insert into public.circular_revisions(id,circular_id,institution_id,revision_number,status,title,body_text,created_by_person_id,published_at) values
 (pg_temp.f2(531),pg_temp.f2(530),pg_temp.f2(10),1,'published','Circular familias','corpo',pg_temp.f2(201),now()-interval '1 hour');
update public.circulars set current_revision_id=pg_temp.f2(531) where id=pg_temp.f2(530);
insert into public.circular_audience_rules(circular_id,revision_id,institution_id,audience_kind,scope_kind) values (pg_temp.f2(530),pg_temp.f2(531),pg_temp.f2(10),'families','institution');
insert into public.circular_blocks(id,revision_id,block_kind,display_order) values (pg_temp.f2(532),pg_temp.f2(531),'media',1);
insert into public.circular_media_assets(id,circular_id,institution_id,owner_person_id,upload_request_id,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size,status,checksum_sha256,finalized_at) values
 (pg_temp.f2(533),pg_temp.f2(530),pg_temp.f2(10),pg_temp.f2(201),pg_temp.f2(633),'r2','coelo-media-prod','tenants/'||pg_temp.f2(10)::text||'/circulars/circular/'||pg_temp.f2(530)::text||'/attachment/'||pg_temp.f2(533)::text||'/original/'||pg_temp.f2(733)::text||'.jpg','d.jpg','image/jpeg',1000,'ready',repeat('d',64),now());
insert into public.circular_media_links(revision_id,block_id,media_asset_id,display_order) values (pg_temp.f2(531),pg_temp.f2(532),pg_temp.f2(533),1);
-- Agora: publicação para famílias
insert into public.now_publications(id,institution_id,author_person_id,author_membership_id,caption,status,publish_at,published_at,expires_at) values
 (pg_temp.f2(540),pg_temp.f2(10),pg_temp.f2(201),pg_temp.f2(301),'agora familias','published',now()-interval '1 hour',now()-interval '1 hour',now()+interval '23 hour');
insert into public.now_publication_audiences(publication_id,audience_kind,institution_id) values (pg_temp.f2(540),'families',pg_temp.f2(10));

-- G1: responsável com can_view, sem membership ------------------------------------------------------
select pg_temp.as_user(104);
select is((select count(*) from public.list_visible_moments(pg_temp.f2(10),null,null,20,null)), 1::bigint, 'G1 sees only the families moment');
select is((select m.author_person_id from public.list_visible_moments(pg_temp.f2(10),null,null,20,null) m), pg_temp.f2(201), 'moments project the author person id');
select is((select m.can_withdraw from public.list_visible_moments(pg_temp.f2(10),null,null,20,null) m), false, 'guardian never withdraws');
select is((select count(*) from public.list_visible_happens_posts(pg_temp.f2(10),null,null,20)), 1::bigint, 'G1 sees the families post');
select is((select p.author_person_id from public.list_visible_happens_posts(pg_temp.f2(10),null,null,20) p), pg_temp.f2(201), 'posts project the author person id');
select is((select jsonb_array_length(p.media) from public.list_visible_happens_posts(pg_temp.f2(10),null,null,20) p), 1, 'G1 receives a media read ticket');
select is((select string_agg(f.item_type, ',' order by f.item_type) from public.list_visible_happens_feed(pg_temp.f2(10),null,null,null,null,null,null,20) f), 'circular,post', 'mixed feed carries post and circular for G1');
select is((select bool_and(f.payload->>'author_person_id' = pg_temp.f2(201)::text) from public.list_visible_happens_feed(pg_temp.f2(10),null,null,null,null,null,null,20) f), true, 'mixed feed payloads carry author_person_id');
select is((select public.get_visible_circular(pg_temp.f2(530),null)->>'author_person_id'), pg_temp.f2(201)::text, 'G1 opens the circular (author projected)');
select is((select count(*) from public.list_visible_profile_circulars(pg_temp.f2(10),null,null,null,null,null,20)), 1::bigint, 'G1 lists the profile circulars');
select is((select public.authorize_moments_media_read(pg_temp.f2(510))->>'mime_type'), 'image/jpeg', 'G1 reads the families moment media');
select is(pg_temp.try(format('select public.authorize_moments_media_read(%L)', pg_temp.f2(511))), '42501:asset_not_authorized', 'G1 cannot read the staff-only moment media');
select is((select public.authorize_circular_media_read(pg_temp.f2(533))->>'mime_type'), 'image/jpeg', 'G1 reads the circular media');
select is((select n.author_person_id from public.list_visible_now_publications(pg_temp.f2(10),null,null,20) n), pg_temp.f2(201), 'now feed projects the author person id');

-- G2: vinculado sem can_view --------------------------------------------------------------------------
select pg_temp.as_user(105);
select is(pg_temp.try(format('select * from public.list_visible_moments(%L,null,null,20,null)', pg_temp.f2(10))), '42501:moments_permission_denied', 'G2 (no can_view) is refused in Moments');
select is(pg_temp.try(format('select * from public.list_visible_happens_posts(%L,null,null,20)', pg_temp.f2(10))), '42501:happens_permission_denied', 'G2 is refused in Acontece');
select is(pg_temp.try(format('select public.get_visible_circular(%L,null)', pg_temp.f2(530))), '42501:circular_permission_denied', 'G2 is refused in the circular');
select is(pg_temp.try(format('select public.authorize_circular_media_read(%L)', pg_temp.f2(533))), '42501:circular_permission_denied', 'G2 cannot read the circular media');

-- X: responsável de outra instituição -----------------------------------------------------------------
select pg_temp.as_user(106);
select is(pg_temp.try(format('select * from public.list_visible_moments(%L,null,null,20,null)', pg_temp.f2(10))), '42501:moments_permission_denied', 'X (tenant B) is refused in A');
select is(pg_temp.try(format('select public.authorize_moments_media_read(%L)', pg_temp.f2(510))), '42501:asset_not_authorized', 'X cannot read the media of A');

-- T: equipe continua como antes -------------------------------------------------------------------------
select pg_temp.as_user(101);
select is((select count(*) from public.list_visible_moments(pg_temp.f2(10),null,null,20,null)), 1::bigint, 'T (teacher) sees the staff moment, not the families one');
select is((select m.can_withdraw from public.list_visible_moments(pg_temp.f2(10),null,null,20,null) m), true, 'T can withdraw her own moment');
select is((select public.authorize_moments_media_read(pg_temp.f2(510))->>'mime_type'), 'image/jpeg', 'T (author) reads the families moment media');

select * from finish();
rollback;
