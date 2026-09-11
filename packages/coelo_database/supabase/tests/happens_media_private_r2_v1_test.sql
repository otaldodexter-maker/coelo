-- Acontece em R2 (candidato 20260910190700_happens_media_private_r2_v1):
-- contrato estrutural e comportamento das RPCs com ator autenticado, dentro
-- de uma transacao revertida. Sem objeto remoto e sem segredo.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Provedor: R2 como default de ativo novo, legado preservado.
select col_default_is('public','media_assets','storage_provider','r2',
  'Ativo novo do Acontece nasce em R2');
select col_hasnt_default('public','media_assets','bucket_id',
  'Bucket deixa de ter default porque depende do provedor');
select ok((select pg_get_constraintdef(oid) from pg_constraint
  where conrelid='public.media_assets'::regclass and conname='media_assets_happens_bucket_ck')
  like '%coelo-media-prod%' ,'Ativo R2 do Acontece aponta para coelo-media-prod');
select ok((select pg_get_constraintdef(oid) from pg_constraint
  where conrelid='public.media_assets'::regclass and conname='media_assets_happens_bucket_ck')
  like '%coelo-happens-mvp%','Ativo legado continua preso ao bucket privado anterior');
select is((select count(*)::bigint from pg_constraint
  where conrelid='public.media_assets'::regclass and not convalidated
    and conname in ('media_assets_happens_bucket_ck','media_assets_happens_r2_key_shape_ck',
      'media_assets_happens_checksum_format_ck','media_assets_happens_r2_ready_integrity_ck')),
  4::bigint,'As quatro restricoes novas entram como NOT VALID');

-- Assinaturas e grants preservados.
select has_function('public','prepare_happens_media_upload',array['text','uuid','uuid','text','text','bigint'],'prepare mantem a assinatura');
select has_function('public','finalize_happens_media_upload',array['uuid','uuid','text','bigint'],'finalize mantem a assinatura');
select has_function('public','remove_happens_media',array['uuid'],'remove mantem a assinatura');
select has_function('public','redeem_happens_media_read_ticket',array['uuid','uuid'],'redeem mantem a assinatura');
select is((select count(*)::bigint from unnest(array[
    'public.prepare_happens_media_upload(text,uuid,uuid,text,text,bigint)',
    'public.finalize_happens_media_upload(uuid,uuid,text,bigint)',
    'public.remove_happens_media(uuid)',
    'public.redeem_happens_media_read_ticket(uuid,uuid)']) signature
  join pg_proc on pg_proc.oid=signature::regprocedure
  where pg_proc.prosecdef and coalesce(pg_proc.proconfig,'{}'::text[]) @> array['search_path=""']::text[]),
  4::bigint,'Funcoes recriadas sao security definer com search_path fechado');
select ok(not has_function_privilege('authenticated','public.redeem_happens_media_read_ticket(uuid,uuid)','execute')
  and not has_function_privilege('anon','public.prepare_happens_media_upload(text,uuid,uuid,text,text,bigint)','execute'),
  'Cliente nao resgata ticket e anon nao prepara upload');

-- Fixtures: autora com happens.posts.create no tenant A; tenant B vizinho.
insert into auth.users(id) values ('b1000000-0000-4000-8000-000000000001');
insert into public.people(id,person_type,first_name,last_name,display_name,status)
values ('b1100000-0000-4000-8000-000000000001','adult','Ana','Autora','Ana Autora','active');
insert into public.person_auth_links(person_id,auth_user_id,status)
values ('b1100000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000001','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('b1200000-0000-4000-8000-000000000001','R2 Tenant A','R2 Tenant A','r2-tenant-a','active'),
  ('b1200000-0000-4000-8000-000000000002','R2 Tenant B','R2 Tenant B','r2-tenant-b','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
  ('b1300000-0000-4000-8000-000000000001','b1100000-0000-4000-8000-000000000001','b1200000-0000-4000-8000-000000000001','teacher','active','institution');
insert into public.institution_member_permission_overrides(
  membership_id,permission_code,effect,scope_kind,reason,status,changed_by_person_id) values
  ('b1300000-0000-4000-8000-000000000001','happens.posts.create','allow','institution',
   'fixture','active','b1100000-0000-4000-8000-000000000001');
insert into public.posts(id,institution_id,author_person_id,author_membership_id,caption,status) values
  ('b1400000-0000-4000-8000-000000000001','b1200000-0000-4000-8000-000000000001',
   'b1100000-0000-4000-8000-000000000001','b1300000-0000-4000-8000-000000000001','rascunho','draft');
-- Post do tenant B com a mesma autora como author_person_id, mas sem membership em B.
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
  ('b1300000-0000-4000-8000-000000000002','b1100000-0000-4000-8000-000000000001','b1200000-0000-4000-8000-000000000002','teacher','suspended','institution');
insert into public.posts(id,institution_id,author_person_id,author_membership_id,caption,status) values
  ('b1400000-0000-4000-8000-000000000002','b1200000-0000-4000-8000-000000000002',
   'b1100000-0000-4000-8000-000000000001','b1300000-0000-4000-8000-000000000002','rascunho B','draft');

create function pg_temp.as_author(p_sql text) returns jsonb language plpgsql as $fn$
declare result jsonb;
begin
  perform set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
  set local role authenticated;
  execute p_sql into result;
  reset role;
  return result;
end $fn$;
create function pg_temp.try_author(p_sql text) returns text language plpgsql as $fn$
begin
  perform pg_temp.as_author(p_sql);
  return 'ok';
exception when others then
  reset role;
  return sqlstate;
end $fn$;

create function pg_temp.happens_asset() returns uuid language sql security definer set search_path='' as $fn$
  select id from public.media_assets where post_id='b1400000-0000-4000-8000-000000000001' and upload_request_id='req-1'
$fn$;

-- prepare: ativo novo nasce em R2 com chave opaca no escopo do tenant.
select is(pg_temp.as_author($$select public.prepare_happens_media_upload('req-1','b1200000-0000-4000-8000-000000000001','b1400000-0000-4000-8000-000000000001','foto.png','image/png',1024)$$)->>'storage_provider',
  'r2','prepare devolve provedor r2');
select is(pg_temp.as_author($$select public.prepare_happens_media_upload('req-1','b1200000-0000-4000-8000-000000000001','b1400000-0000-4000-8000-000000000001','foto.png','image/png',1024)$$)->>'bucket_id',
  'coelo-media-prod','prepare devolve o bucket de midia');
select matches(pg_temp.as_author($$select public.prepare_happens_media_upload('req-1','b1200000-0000-4000-8000-000000000001','b1400000-0000-4000-8000-000000000001','foto.png','image/png',1024)$$)->>'object_key',
  '^tenants/b1200000-0000-4000-8000-000000000001/happens/post/b1400000-0000-4000-8000-000000000001/attachment/[0-9a-f-]{36}/original/[0-9a-f-]{36}[.]png$',
  'chave opaca versionada por escopo, dominio, entidade, finalidade, ativo e rendicao');
select is((select count(*) from public.media_assets where post_id='b1400000-0000-4000-8000-000000000001'),1::bigint,
  'prepare repetido com o mesmo request_id nao cria segundo ativo');

-- finalize no R2 nao exige storage.objects: exige checksum medido pelo gateway.
select is(pg_temp.try_author($$select public.finalize_happens_media_upload(
  pg_temp.happens_asset(),
  'b1400000-0000-4000-8000-000000000001',null,0)$$),
  '23514','finalize R2 sem checksum e recusado');
select is(pg_temp.try_author($$select public.finalize_happens_media_upload(
  pg_temp.happens_asset(),
  'b1400000-0000-4000-8000-000000000001',repeat('a',64),0)$$),
  'ok','finalize R2 com checksum sha256 fecha o ativo sem consultar storage.objects');
select is((select status::text from public.media_assets where post_id='b1400000-0000-4000-8000-000000000001'),
  'ready','ativo R2 fica ready com checksum e finalized_at');

-- remove devolve o provedor para o gateway apagar no transporte certo.
select is(pg_temp.as_author($$select public.remove_happens_media(
  pg_temp.happens_asset())$$)->>'storage_provider',
  'r2','remove devolve o provedor');

-- Outro tenant: a autora nao tem membership ativa em B; negado antes de qualquer dado.
select is(pg_temp.try_author($$select public.prepare_happens_media_upload('req-b','b1200000-0000-4000-8000-000000000002','b1400000-0000-4000-8000-000000000002','foto.png','image/png',1024)$$),
  '42501','prepare em outro tenant e negado');

-- Acervo legado: continua gravavel exatamente como antes.
select lives_ok($$insert into public.media_assets(institution_id,post_id,owner_person_id,upload_request_id,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size)
  values('b1200000-0000-4000-8000-000000000001','b1400000-0000-4000-8000-000000000001','b1100000-0000-4000-8000-000000000001','legacy-1','supabase_mvp','coelo-happens-mvp','b1200000-0000-4000-8000-000000000001/b1400000-0000-4000-8000-000000000001/legacy','legacy.jpg','image/jpeg',10)$$,
  'Ativo legado em Supabase Storage continua aceito no bucket anterior');
select throws_ok($$insert into public.media_assets(institution_id,post_id,owner_person_id,upload_request_id,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size)
  values('b1200000-0000-4000-8000-000000000001','b1400000-0000-4000-8000-000000000001','b1100000-0000-4000-8000-000000000001','bad-1','r2','coelo-media-prod','fora/do/escopo.jpg','x.jpg','image/jpeg',10)$$,
  '23514',null,'Chave R2 fora da forma opaca e recusada');

select * from finish();
rollback;
