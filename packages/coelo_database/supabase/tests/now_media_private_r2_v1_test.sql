-- Agora em R2 (candidato 20260910190600_now_media_private_r2_v1): contrato
-- estrutural e comportamento das RPCs com ator autenticado, dentro de uma
-- transacao revertida. Sem objeto remoto e sem segredo.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select col_default_is('public','now_media_assets','storage_provider','r2','Ativo novo do Agora nasce em R2');
select col_hasnt_default('public','now_media_assets','bucket_id','Bucket depende do provedor');
select ok(not exists(select 1 from storage.buckets where id='coelo-now-mvp'),
  'Nenhum bucket do Supabase Storage e criado para o Agora');
select ok((select pg_get_constraintdef(oid) from pg_constraint
  where conrelid='public.now_media_assets'::regclass and conname='now_media_assets_bucket_ck')
  like '%coelo-media-prod%','Ativo R2 do Agora aponta para coelo-media-prod');
select has_function('public','prepare_now_asset_upload',array['uuid','uuid','now_asset_kind','text','text','bigint','numeric','boolean'],'prepare mantem a assinatura');
select has_function('public','finalize_now_asset_upload',array['uuid','text'],'finalize mantem a assinatura');
select has_function('public','authorize_now_asset_read',array['uuid','uuid'],'authorize read mantem a assinatura');
select has_function('public','redeem_now_media_read_ticket',array['uuid','uuid'],'redeem mantem a assinatura');
select is((select count(*)::bigint from unnest(array[
    'public.prepare_now_asset_upload(uuid,uuid,public.now_asset_kind,text,text,bigint,numeric,boolean)',
    'public.finalize_now_asset_upload(uuid,text)',
    'public.authorize_now_asset_read(uuid,uuid)',
    'public.redeem_now_media_read_ticket(uuid,uuid)']) signature
  join pg_proc on pg_proc.oid=signature::regprocedure
  where pg_proc.prosecdef and coalesce(pg_proc.proconfig,'{}'::text[]) @> array['search_path=""']::text[]),
  4::bigint,'Funcoes recriadas sao security definer com search_path fechado');
select ok(not has_function_privilege('authenticated','public.redeem_now_media_read_ticket(uuid,uuid)','execute')
  and has_function_privilege('service_role','public.redeem_now_media_read_ticket(uuid,uuid)','execute')
  and not has_function_privilege('anon','public.prepare_now_asset_upload(uuid,uuid,public.now_asset_kind,text,text,bigint,numeric,boolean)','execute'),
  'Grants iguais aos da fundacao');

-- Fixtures.
insert into auth.users(id) values ('c1000000-0000-4000-8000-000000000001');
insert into public.people(id,person_type,first_name,last_name,display_name,status)
values ('c1100000-0000-4000-8000-000000000001','adult','Ana','Autora','Ana Autora','active');
insert into public.person_auth_links(person_id,auth_user_id,status)
values ('c1100000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000001','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('c1200000-0000-4000-8000-000000000001','Agora R2 A','Agora R2 A','agora-r2-a','active'),
  ('c1200000-0000-4000-8000-000000000002','Agora R2 B','Agora R2 B','agora-r2-b','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
  ('c1300000-0000-4000-8000-000000000001','c1100000-0000-4000-8000-000000000001','c1200000-0000-4000-8000-000000000001','teacher','active','institution'),
  ('c1300000-0000-4000-8000-000000000002','c1100000-0000-4000-8000-000000000001','c1200000-0000-4000-8000-000000000002','teacher','suspended','institution');
insert into public.institution_member_permission_overrides(
  membership_id,permission_code,effect,scope_kind,reason,status,changed_by_person_id) values
  ('c1300000-0000-4000-8000-000000000001','now.publications.create','allow','institution','fixture','active','c1100000-0000-4000-8000-000000000001');
insert into public.now_publications(id,institution_id,author_person_id,author_membership_id) values
  ('c1400000-0000-4000-8000-000000000001','c1200000-0000-4000-8000-000000000001','c1100000-0000-4000-8000-000000000001','c1300000-0000-4000-8000-000000000001'),
  ('c1400000-0000-4000-8000-000000000002','c1200000-0000-4000-8000-000000000002','c1100000-0000-4000-8000-000000000001','c1300000-0000-4000-8000-000000000002');

create function pg_temp.as_author(p_sql text) returns jsonb language plpgsql as $fn$
declare result jsonb;
begin
  perform set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000001',true);
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

create function pg_temp.now_asset() returns uuid language sql security definer set search_path='' as $fn$
  select id from public.now_media_assets where publication_id='c1400000-0000-4000-8000-000000000001'
$fn$;

select is(pg_temp.as_author($$select public.prepare_now_asset_upload('c1200000-0000-4000-8000-000000000001','c1400000-0000-4000-8000-000000000001','media','foto.png','image/png',1024,null,false)$$)->>'storage_provider',
  'r2','prepare devolve provedor r2');
select matches(pg_temp.as_author($$select public.prepare_now_asset_upload('c1200000-0000-4000-8000-000000000001','c1400000-0000-4000-8000-000000000001','media','foto.png','image/png',1024,null,false)$$)->>'object_key',
  '^tenants/c1200000-0000-4000-8000-000000000001/now/publication/c1400000-0000-4000-8000-000000000001/media/[0-9a-f-]{36}/original/[0-9a-f-]{36}[.]png$',
  'chave opaca versionada por escopo, dominio, entidade, finalidade, ativo e rendicao');
select is((select count(*) from public.now_media_assets where publication_id='c1400000-0000-4000-8000-000000000001'),1::bigint,
  'prepare repetido com os mesmos metadados nao cria segundo ativo');
select is((select count(distinct object_key) from public.now_media_assets where publication_id='c1400000-0000-4000-8000-000000000001'),1::bigint,
  'prepare repetido com os mesmos metadados mantem a chave (o gateway chama prepare de novo ao finalizar)');

select is(pg_temp.try_author($$select public.finalize_now_asset_upload(
  pg_temp.now_asset(),'nao-e-sha')$$),
  '42501','finalize R2 sem checksum valido e recusado');
select is(pg_temp.try_author($$select public.finalize_now_asset_upload(
  pg_temp.now_asset(),repeat('b',64))$$),
  'ok','finalize R2 com checksum fecha o ativo sem consultar storage.objects');
select is((select status::text from public.now_media_assets where publication_id='c1400000-0000-4000-8000-000000000001'),'ready','ativo fica ready');

-- Substituicao com metadados novos gera chave nova e volta a pending.
create temp table before_swap as select object_key from public.now_media_assets where publication_id='c1400000-0000-4000-8000-000000000001';
select isnt(pg_temp.as_author($$select public.prepare_now_asset_upload('c1200000-0000-4000-8000-000000000001','c1400000-0000-4000-8000-000000000001','media','outra.jpg','image/jpeg',2048,null,false)$$)->>'object_key',
  (select object_key from before_swap),'substituicao com metadados novos gera chave nova');
select is((select status::text from public.now_media_assets where publication_id='c1400000-0000-4000-8000-000000000001'),'pending','substituicao volta o ativo a pending');
select matches((select object_key from public.now_media_assets where publication_id='c1400000-0000-4000-8000-000000000001'),'[.]jpg$','substituicao usa a extensao do MIME novo');
select is(pg_temp.try_author($$select public.authorize_now_asset_read('c1200000-0000-4000-8000-000000000001',pg_temp.now_asset())$$),
  '42501','authorize read nao devolve ativo pendente');

-- Outro tenant: membership suspensa em B; negado.
select is(pg_temp.try_author($$select public.prepare_now_asset_upload('c1200000-0000-4000-8000-000000000002','c1400000-0000-4000-8000-000000000002','media','foto.png','image/png',1024,null,false)$$),
  '42501','prepare em outro tenant e negado');

select throws_ok($$insert into public.now_media_assets(publication_id,institution_id,owner_person_id,kind,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size)
  values('c1400000-0000-4000-8000-000000000001','c1200000-0000-4000-8000-000000000001','c1100000-0000-4000-8000-000000000001','cover','r2','coelo-now-mvp','x','x.png','image/png',1)$$,
  '23514',null,'Ativo R2 nao pode cair no bucket legado');

select * from finish();
rollback;
