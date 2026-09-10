-- E2 R02 / L01: prova local do contrato 'chat-attachment' no catalogo privado.
-- Rollback-only. Nao depende de fixture de Forms nem de Acontece: a forma da
-- linha e verificada num clone temporario da tabela (LIKE ... INCLUDING
-- CONSTRAINTS copia os CHECK, mas nao copia FK nem trigger), e o caminho real
-- com trigger e verificado com o fixture minimo de instituicao e pessoa.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.chat_id(n integer) returns uuid language sql immutable as $$
  select ('8c030000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid;
$$;

-- Clone somente com CHECK: isola a forma declarada de qualquer autorizacao.
create temporary table shape_probe
  (like public.media_assets including constraints including defaults);

create function pg_temp.shape(patch jsonb) returns void language plpgsql as $$
declare data jsonb; asset public.media_assets;
begin
  data := jsonb_build_object(
    'id',gen_random_uuid(),'institution_id',pg_temp.chat_id(10),
    'upload_request_id','synthetic-chat','storage_provider','r2',
    'bucket_id','coelo-media-prod','object_key','k/'||gen_random_uuid()::text,
    'original_name','','mime_type','image/png','status','pending') || patch;
  asset := jsonb_populate_record(null::public.media_assets,data);
  insert into shape_probe(id,institution_id,post_id,owner_person_id,upload_request_id,
    storage_provider,bucket_id,object_key,original_name,mime_type,byte_size,checksum_sha256,status,
    catalog_kind,form_id,source_form_asset_id,owner_internal_identity_id,media_purpose,pixel_width,pixel_height)
  values(asset.id,asset.institution_id,asset.post_id,asset.owner_person_id,asset.upload_request_id,
    asset.storage_provider,asset.bucket_id,asset.object_key,asset.original_name,asset.mime_type,asset.byte_size,
    asset.checksum_sha256,asset.status,asset.catalog_kind,asset.form_id,asset.source_form_asset_id,
    asset.owner_internal_identity_id,asset.media_purpose,asset.pixel_width,asset.pixel_height);
end;
$$;

-- Os discriminadores antigos continuam bem formados apos a recriacao do CHECK.
select lives_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','legacy-happens',
  'storage_provider','supabase_mvp','bucket_id','coelo-happens-mvp','original_name','foto.png',
  'post_id',pg_temp.chat_id(20),'owner_person_id',pg_temp.chat_id(100),'byte_size',100))$$,
  'legacy-happens continua aceito');
select lives_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','form-image',
  'media_purpose','question-image','form_id',pg_temp.chat_id(30),
  'owner_person_id',pg_temp.chat_id(100)))$$,'form-image question-image continua aceito');
select lives_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','form-image',
  'media_purpose','answer-image','form_id',pg_temp.chat_id(30),
  'source_form_asset_id',pg_temp.chat_id(40),'owner_person_id',pg_temp.chat_id(100)))$$,
  'form-image answer-image continua aceito');

-- O discriminador novo e aceito nos dois realms e no ciclo pending -> ready.
select lives_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','attachment','owner_person_id',pg_temp.chat_id(100)))$$,
  'chat-attachment pendente com dono pessoa e aceito');
select lives_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','attachment','owner_internal_identity_id',pg_temp.chat_id(110)))$$,
  'chat-attachment pendente com identidade interna e aceito');
select lives_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','attachment','owner_person_id',pg_temp.chat_id(100),'status','ready',
  'byte_size',100,'checksum_sha256',repeat('a',64),'pixel_width',100,'pixel_height',100))$$,
  'chat-attachment ready com metadados medidos e aceito');

-- Linhas de chat malformadas sao recusadas pela propria forma declarada.
select throws_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','attachment','owner_person_id',pg_temp.chat_id(100),
  'form_id',pg_temp.chat_id(30)))$$,'23514',null,'chat nao pode carregar vinculo de Forms');
select throws_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','attachment','post_id',pg_temp.chat_id(20),
  'owner_person_id',pg_temp.chat_id(100)))$$,'23514',null,'chat nao pode carregar post do Acontece');
select throws_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','attachment'))$$,'23514',null,'chat sem dono e recusado');
select throws_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','attachment','owner_person_id',pg_temp.chat_id(100),
  'owner_internal_identity_id',pg_temp.chat_id(110)))$$,'23514',null,
  'chat nao pode ter dono nos dois realms');
select throws_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','question-image','owner_person_id',pg_temp.chat_id(100)))$$,'23514',null,
  'chat nao pode reutilizar finalidade de Forms');
select throws_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','attachment','owner_person_id',pg_temp.chat_id(100),
  'mime_type','video/mp4'))$$,'23514',null,'chat nao admite video nesta rodada');
select throws_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','attachment','owner_person_id',pg_temp.chat_id(100),
  'bucket_id','coelo-documents-prod'))$$,'23514',null,'chat nao admite bucket de documentos nesta rodada');
select throws_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','attachment','owner_person_id',pg_temp.chat_id(100),
  'original_name','conversa.png'))$$,'23514',null,'chat nao guarda nome de arquivo no catalogo fisico');
select throws_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','attachment','owner_person_id',pg_temp.chat_id(100),'byte_size',100))$$,
  '23514',null,'pendente nao pode declarar bytes ainda nao medidos');
select throws_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','attachment','owner_person_id',pg_temp.chat_id(100),'status','ready',
  'byte_size',100,'pixel_width',100,'pixel_height',100))$$,'23514',null,
  'ready sem checksum e recusado');
select throws_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','attachment','owner_person_id',pg_temp.chat_id(100),'status','ready',
  'byte_size',26214401,'checksum_sha256',repeat('a',64),'pixel_width',100,'pixel_height',100))$$,
  '23514',null,'bytes acima do teto de chat sao recusados');
select throws_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat-attachment',
  'media_purpose','attachment','owner_person_id',pg_temp.chat_id(100),'pixel_width',100))$$,
  '23514',null,'dimensao pela metade nao passa');
select throws_ok($$select pg_temp.shape(jsonb_build_object('catalog_kind','chat',
  'media_purpose','attachment','owner_person_id',pg_temp.chat_id(100)))$$,'23514',null,
  'discriminador desconhecido continua fora do dominio');

-- Validador de chave: formato opaco da ADR 0032, sem autorizacao derivada.
create function pg_temp.key_asset(kind text, purpose text) returns public.media_assets
language sql immutable as $$
  select jsonb_populate_record(null::public.media_assets,jsonb_build_object(
    'id',pg_temp.chat_id(1000),'institution_id',pg_temp.chat_id(10),
    'catalog_kind',kind,'media_purpose',purpose,'form_id',pg_temp.chat_id(30)));
$$;

select ok(app_private.private_media_catalog_key_v1(pg_temp.key_asset('chat-attachment','attachment'),
  'original','tenants/'||pg_temp.chat_id(10)::text||'/chat/message/'||pg_temp.chat_id(50)::text
  ||'/attachment/'||pg_temp.chat_id(1000)::text||'/original/'||pg_temp.chat_id(2000)::text||'.png','image/png'),
  'chave de chat bem formada e aceita pelo validador');
select ok(not app_private.private_media_catalog_key_v1(pg_temp.key_asset('chat-attachment','attachment'),
  'original','tenants/'||pg_temp.chat_id(10)::text||'/chat/message/conversa-do-joao'
  ||'/attachment/'||pg_temp.chat_id(1000)::text||'/original/'||pg_temp.chat_id(2000)::text||'.png','image/png'),
  'chave de chat com nome no lugar do uuid da mensagem e recusada');
select ok(not app_private.private_media_catalog_key_v1(pg_temp.key_asset('chat-attachment','attachment'),
  'original','tenants/'||pg_temp.chat_id(20)::text||'/chat/message/'||pg_temp.chat_id(50)::text
  ||'/attachment/'||pg_temp.chat_id(1000)::text||'/original/'||pg_temp.chat_id(2000)::text||'.png','image/png'),
  'chave de chat de outro tenant e recusada');
select ok(not app_private.private_media_catalog_key_v1(pg_temp.key_asset('chat-attachment','attachment'),
  'original','tenants/'||pg_temp.chat_id(10)::text||'/forms/form/'||pg_temp.chat_id(30)::text
  ||'/attachment/'||pg_temp.chat_id(1000)::text||'/original/'||pg_temp.chat_id(2000)::text||'.png','image/png'),
  'chave de chat nao pode usar o dominio de Forms');
select ok(not app_private.private_media_catalog_key_v1(pg_temp.key_asset('chat-attachment','attachment'),
  'original','tenants/'||pg_temp.chat_id(10)::text||'/chat/message/'||pg_temp.chat_id(50)::text
  ||'/attachment/'||pg_temp.chat_id(1000)::text||'/original/'||pg_temp.chat_id(2000)::text||'.jpg','image/png'),
  'extensao incompativel com o MIME e recusada');
select ok(app_private.private_media_catalog_key_v1(pg_temp.key_asset('form-image','question-image'),
  'original','tenants/'||pg_temp.chat_id(10)::text||'/forms/form/'||pg_temp.chat_id(30)::text
  ||'/question-image/'||pg_temp.chat_id(1000)::text||'/original/'||pg_temp.chat_id(2000)::text||'.png','image/png'),
  'formato de Forms continua valido apos a generalizacao');
select ok(not app_private.private_media_catalog_key_v1(pg_temp.key_asset('form-image','question-image'),
  'original','tenants/'||pg_temp.chat_id(10)::text||'/chat/message/'||pg_temp.chat_id(50)::text
  ||'/question-image/'||pg_temp.chat_id(1000)::text||'/original/'||pg_temp.chat_id(2000)::text||'.png','image/png'),
  'ativo de Forms nao pode usar o dominio de chat');
select ok(app_private.private_media_catalog_key_v1(pg_temp.key_asset('legacy-happens',null),
  'original','tenants/'||pg_temp.chat_id(10)::text||'/chat/message/'||pg_temp.chat_id(50)::text
  ||'/attachment/'||pg_temp.chat_id(1000)::text||'/original/'||pg_temp.chat_id(2000)::text||'.png','image/png')
  is not true,'acervo legado nao ganha formato canonico por acidente');

-- Caminho real, com o guarda de ativo ativo. Fixture minimo e nominal.
insert into public.institution_types(id,code,name,status)
values(pg_temp.chat_id(1),'l01-chat-media-test','Synthetic chat media type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status)
select pg_temp.chat_id(n),pg_temp.chat_id(1),'Synthetic chat media '||n,'l01-chat-media-'||n,'active'
from unnest(array[10,20]) n;
insert into public.people(id,person_type,first_name,last_name,display_name,status)
values(pg_temp.chat_id(100),'adult','Synthetic','Chat','Synthetic chat','active');
insert into app_private.superadmin_internal_identities(id) values(pg_temp.chat_id(110));

create function pg_temp.chat_insert(n integer, patch jsonb default '{}'::jsonb)
returns void language plpgsql as $$
declare data jsonb; asset public.media_assets;
begin
  data := jsonb_build_object('id',pg_temp.chat_id(n),'institution_id',pg_temp.chat_id(10),
    'owner_person_id',pg_temp.chat_id(100),'catalog_kind','chat-attachment',
    'media_purpose','attachment','storage_provider','r2','bucket_id','coelo-media-prod',
    'mime_type','image/png','original_name','','upload_request_id','synthetic-chat-'||n,
    'status','pending') || patch;
  data := jsonb_build_object('object_key',
    'tenants/'||(data->>'institution_id')||'/chat/message/'||pg_temp.chat_id(50)::text
    ||'/attachment/'||(data->>'id')||'/original/'||pg_temp.chat_id(n+10000)::text||'.png') || data;
  asset := jsonb_populate_record(null::public.media_assets,data);
  insert into public.media_assets(id,institution_id,post_id,owner_person_id,upload_request_id,
    storage_provider,bucket_id,object_key,original_name,mime_type,byte_size,checksum_sha256,status,
    catalog_kind,form_id,source_form_asset_id,owner_internal_identity_id,media_purpose,pixel_width,pixel_height)
  values(asset.id,asset.institution_id,asset.post_id,asset.owner_person_id,asset.upload_request_id,
    asset.storage_provider,asset.bucket_id,asset.object_key,asset.original_name,asset.mime_type,asset.byte_size,
    asset.checksum_sha256,asset.status,asset.catalog_kind,asset.form_id,asset.source_form_asset_id,
    asset.owner_internal_identity_id,asset.media_purpose,asset.pixel_width,asset.pixel_height);
  set constraints all immediate;
  set constraints all deferred;
end;
$$;

select lives_ok($$select pg_temp.chat_insert(3000)$$,
  'ativo de chat entra no catalogo sem exigir binding de Forms');
select is((select count(*)::int from public.media_bindings where media_asset_id=pg_temp.chat_id(3000)),0,
  'chat nao cria uso tipado de Forms');
select lives_ok($$select pg_temp.chat_insert(3001,jsonb_build_object('owner_person_id',null,
  'owner_internal_identity_id',pg_temp.chat_id(110)))$$,
  'ativo de chat do realm interno dispensa People sintetico');
select throws_ok($$select pg_temp.chat_insert(3002,jsonb_build_object('object_key',
  'tenants/'||pg_temp.chat_id(10)::text||'/chat/message/foto-da-turma/attachment/'
  ||pg_temp.chat_id(3002)::text||'/original/'||pg_temp.chat_id(13002)::text||'.png'))$$,
  '23514','media_catalog_scope_invalid','chave de chat malformada e recusada na escrita real');
select throws_ok($$select pg_temp.chat_insert(3003,jsonb_build_object(
  'institution_id',pg_temp.chat_id(20),'object_key',
  'tenants/'||pg_temp.chat_id(10)::text||'/chat/message/'||pg_temp.chat_id(50)::text||'/attachment/'
  ||pg_temp.chat_id(3003)::text||'/original/'||pg_temp.chat_id(13003)::text||'.png'))$$,
  '23514','media_catalog_scope_invalid','chave nao pode apontar para outro tenant');
select throws_ok($$update public.media_assets set catalog_kind='form-image' where id=pg_temp.chat_id(3000)$$,
  '23514','media_catalog_origin_immutable','origem do ativo de chat e imutavel');
select throws_ok($$update public.media_assets set object_key=object_key||'x' where id=pg_temp.chat_id(3000)$$,
  '23514','media_catalog_identity_immutable','chave do ativo de chat e imutavel');
select throws_ok($$insert into public.media_variants(media_asset_id,rendition,bucket_id,object_key,
  mime_type,byte_size,checksum_sha256,pixel_width,pixel_height)
  select id,'preview',bucket_id,object_key||'.preview',mime_type,100,repeat('a',64),100,100
  from public.media_assets where id=pg_temp.chat_id(3000)$$,
  '23514','media_catalog_asset_invalid','chat ainda nao tem rendicao derivada nesta fundacao');

-- A fundacao continua fail-closed: nenhum grant novo nasce deste contrato.
select ok(not has_table_privilege(actor,object_name,'select,insert,update,delete'),
  actor||' continua sem acesso direto a '||object_name)
from unnest(array['anon','authenticated','service_role']) actor
cross join unnest(array['public.media_variants','public.media_bindings']) object_name;
select ok(not has_table_privilege(actor,'public.media_assets','select,insert,update,delete'),
  actor||' continua sem acesso direto a public.media_assets')
from unnest(array['anon','authenticated']) actor;
select ok(not has_function_privilege('authenticated',oid,'execute'),
  'helper privado do catalogo continua sem grant de cliente')
from pg_proc where pronamespace='app_private'::regnamespace and proname like 'private_media_catalog_%_v1';
select ok(relrowsecurity and relforcerowsecurity,relname||' continua forcando RLS') from pg_class
where oid in ('public.media_assets'::regclass,'public.media_variants'::regclass,'public.media_bindings'::regclass);

set constraints all immediate;
select * from finish();
rollback;
