-- E2 R02 / L01. Contrato estrutural da migration
-- 20260909132000_circulars_media_private_r2_v1.sql: provedor, bucket, chave
-- opaca, integridade, assinaturas recriadas e grants inalterados. Sem objeto
-- remoto, sem segredo real e sem prova de comportamento ponta a ponta.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Colunas do catalogo continuam existindo com a semantica da ADR 0032.
select has_column('public','circular_media_assets','storage_provider',
  'Provedor do ativo e explicito');
select has_column('public','circular_media_assets','bucket_id',
  'Bucket do ativo e explicito');
select has_column('public','circular_media_assets','object_key',
  'Chave opaca do objeto e explicita');
select has_column('public','circular_media_assets','checksum_sha256',
  'Checksum sha256 e catalogado');
select has_column('public','circular_media_assets','byte_size',
  'Bytes reais sao catalogados');
select has_column('public','circular_media_assets','mime_type',
  'MIME real e catalogado');

-- Provedor: aceita o legado e o novo, com R2 como default de ativo novo.
select ok(exists(
  select 1 from pg_constraint
  where conrelid='public.circular_media_assets'::regclass
    and conname='circular_media_assets_storage_provider_ck'),
  'CHECK nomeado de provedor existe');
select ok(not exists(
  select 1 from pg_constraint
  where conrelid='public.circular_media_assets'::regclass and contype='c'
    and pg_get_constraintdef(oid) like '%storage_provider%'
    and pg_get_constraintdef(oid) not like '%r2%'),
  'Nenhum CHECK sobrevivente prende o provedor a supabase');
select ok((select pg_get_constraintdef(oid)
  from pg_constraint where conrelid='public.circular_media_assets'::regclass
    and conname='circular_media_assets_storage_provider_ck')
  like '%''supabase''%',
  'Ativo legado supabase continua permitido');
select ok((select pg_get_constraintdef(oid)
  from pg_constraint where conrelid='public.circular_media_assets'::regclass
    and conname='circular_media_assets_storage_provider_ck')
  like '%''r2''%',
  'Ativo novo em R2 e permitido');
select col_default_is('public','circular_media_assets','storage_provider',
  'r2','Ativo novo nasce em R2');
select col_hasnt_default('public','circular_media_assets','bucket_id',
  'Bucket deixa de ter default porque depende do MIME');

-- Bucket coerente com provedor e finalidade, conforme a topologia da ADR 0032.
select ok(exists(
  select 1 from pg_constraint
  where conrelid='public.circular_media_assets'::regclass
    and conname='circular_media_assets_bucket_ck'),
  'CHECK de coerencia de bucket existe');
select ok((select pg_get_constraintdef(oid)
  from pg_constraint where conrelid='public.circular_media_assets'::regclass
    and conname='circular_media_assets_bucket_ck')
  like '%coelo-media-prod%',
  'Imagem e video de Circulares apontam para coelo-media-prod');
select ok((select pg_get_constraintdef(oid)
  from pg_constraint where conrelid='public.circular_media_assets'::regclass
    and conname='circular_media_assets_bucket_ck')
  like '%coelo-documents-prod%',
  'PDF de Circulares aponta para coelo-documents-prod');
select ok((select pg_get_constraintdef(oid)
  from pg_constraint where conrelid='public.circular_media_assets'::regclass
    and conname='circular_media_assets_bucket_ck')
  like '%coelo-circulars-private%',
  'Ativo legado continua preso ao bucket privado anterior');

-- Chave opaca versionada por escopo/dominio/entidade/finalidade/ativo/rendicao.
select ok(exists(
  select 1 from pg_constraint
  where conrelid='public.circular_media_assets'::regclass
    and conname='circular_media_assets_r2_key_shape_ck'),
  'CHECK de forma da chave R2 existe');
select ok((select pg_get_constraintdef(oid)
  from pg_constraint where conrelid='public.circular_media_assets'::regclass
    and conname='circular_media_assets_r2_key_shape_ck')
  like '%tenants/%' ,'Chave R2 comeca no escopo do tenant');
select ok((select pg_get_constraintdef(oid)
  from pg_constraint where conrelid='public.circular_media_assets'::regclass
    and conname='circular_media_assets_r2_key_shape_ck')
  like '%/original/%','Chave R2 declara a rendicao');

-- Integridade medida no servidor antes de um ativo R2 ficar ready.
select ok(exists(
  select 1 from pg_constraint
  where conrelid='public.circular_media_assets'::regclass
    and conname='circular_media_assets_checksum_format_ck'),
  'CHECK de formato do checksum existe');
select ok((select pg_get_constraintdef(oid)
  from pg_constraint where conrelid='public.circular_media_assets'::regclass
    and conname='circular_media_assets_checksum_format_ck')
  like '%[0-9a-f]{64}%','Checksum tem formato sha256 hexadecimal');
select ok(exists(
  select 1 from pg_constraint
  where conrelid='public.circular_media_assets'::regclass
    and conname='circular_media_assets_r2_ready_integrity_ck'),
  'CHECK de integridade de ativo R2 ready existe');

-- Restricoes novas sao NOT VALID de proposito: valem para escrita futura sem
-- revalidar nem reescrever o acervo legado ja gravado.
select is((select count(*)::bigint from pg_constraint
  where conrelid='public.circular_media_assets'::regclass and not convalidated
    and conname in ('circular_media_assets_bucket_ck',
      'circular_media_assets_r2_key_shape_ck',
      'circular_media_assets_checksum_format_ck',
      'circular_media_assets_r2_ready_integrity_ck')),
  4::bigint,'As quatro restricoes novas entram como NOT VALID');

-- Acervo legado preservado: bucket privado do Supabase Storage segue de pe.
select ok(exists(select 1 from storage.buckets
  where id='coelo-circulars-private' and not public),
  'Bucket privado legado permanece e continua privado');

-- Assinaturas: argumentos preservados em tudo que foi recriado.
select has_function('public','prepare_circular_media_upload',
  array['uuid','uuid','uuid','text','text','bigint'],
  'prepare mantem a assinatura original');
select has_function('public','finalize_circular_media_upload',
  array['uuid','uuid','bigint','text','text','text'],
  'finalize mantem a assinatura original');
select has_function('public','remove_circular_media',array['uuid'],
  'remove mantem a assinatura original');
select has_function('public','authorize_circular_media_read',array['uuid'],
  'authorize read mantem a assinatura original');
select has_function('public','claim_stale_circular_media',array['integer'],
  'claim_stale publico mantem a assinatura de argumentos');
select has_function('app_private','claim_stale_circular_media',
  array['integer'],'claim_stale privado mantem a assinatura de argumentos');

-- claim_stale foi recriada porque o coletor precisa do provedor e do bucket.
select ok((select pg_get_function_result(
    'public.claim_stale_circular_media(integer)'::regprocedure))
  like '%storage_provider%',
  'Coletor recebe o provedor de cada ativo reivindicado');
select ok((select pg_get_function_result(
    'public.claim_stale_circular_media(integer)'::regprocedure))
  like '%bucket_id%',
  'Coletor recebe o bucket de cada ativo reivindicado');

-- Toda funcao recriada continua security definer com search_path fechado.
select is((select count(*)::bigint from unnest(array[
    'public.prepare_circular_media_upload(uuid,uuid,uuid,text,text,bigint)',
    'public.finalize_circular_media_upload(uuid,uuid,bigint,text,text,text)',
    'public.remove_circular_media(uuid)',
    'public.authorize_circular_media_read(uuid)',
    'public.claim_stale_circular_media(integer)',
    'app_private.claim_stale_circular_media(integer)']) signature
  join pg_proc on pg_proc.oid=signature::regprocedure
  where pg_proc.prosecdef
    and coalesce(pg_proc.proconfig,'{}'::text[]) @> array['search_path=""']::text[]),
  6::bigint,'Funcoes recriadas sao security definer com search_path fechado');

-- Grants identicos aos do arquivo original: nada foi alargado.
select ok(has_function_privilege('authenticated',
  'public.prepare_circular_media_upload(uuid,uuid,uuid,text,text,bigint)','execute'),
  'prepare continua exposta a authenticated');
select ok(has_function_privilege('authenticated',
  'public.remove_circular_media(uuid)','execute'),
  'remove continua exposta a authenticated');
select ok(has_function_privilege('authenticated',
  'public.authorize_circular_media_read(uuid)','execute'),
  'authorize read continua exposta a authenticated');
select ok(has_function_privilege('service_role',
  'public.finalize_circular_media_upload(uuid,uuid,bigint,text,text,text)','execute'),
  'finalize continua restrita a service_role');
select ok(has_function_privilege('service_role',
  'public.claim_stale_circular_media(integer)','execute')
  and has_function_privilege('service_role',
  'app_private.claim_stale_circular_media(integer)','execute'),
  'claim_stale continua restrita a service_role');
select is((select count(*)::bigint from unnest(array['anon','authenticated']) actor
  cross join unnest(array[
    'public.finalize_circular_media_upload(uuid,uuid,bigint,text,text,text)',
    'public.claim_stale_circular_media(integer)',
    'app_private.claim_stale_circular_media(integer)']) signature
  where has_function_privilege(actor,signature::regprocedure,'execute')),
  0::bigint,'Nenhum cliente ganha as funcoes privilegiadas do coletor');
select is((select count(*)::bigint from unnest(array[
    'public.prepare_circular_media_upload(uuid,uuid,uuid,text,text,bigint)',
    'public.remove_circular_media(uuid)',
    'public.authorize_circular_media_read(uuid)']) signature
  where has_function_privilege('anon',signature::regprocedure,'execute')),
  0::bigint,'anon nao ganha nenhuma RPC de midia de Circulares');


-- Comportamento das restricoes novas sobre linhas sinteticas. Tudo abaixo vive
-- somente dentro desta transacao revertida: nenhum objeto remoto e tocado.
set constraints all deferred;
create function pg_temp.r2_id(n integer) returns uuid language sql immutable as $$
  select ('90000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
create function pg_temp.r2_key(asset integer,extension text) returns text language sql stable as $$
  select 'tenants/'||pg_temp.r2_id(10)::text||'/circulars/circular/'||pg_temp.r2_id(40)::text
    ||'/attachment/'||pg_temp.r2_id(asset)::text
    ||'/original/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'||extension;
$$;
insert into public.institution_types(id,code,name,status)
values(pg_temp.r2_id(1),'circ-r2-probe','Synthetic circular media type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status)
values(pg_temp.r2_id(10),pg_temp.r2_id(1),'Synthetic circular media','circ-r2-probe','active');
insert into public.people(id,person_type,first_name,last_name,display_name,status)
values(pg_temp.r2_id(20),'adult','Synthetic','Author','Synthetic author','active');
insert into public.institution_memberships(id,institution_id,person_id,role_code,status)
values(pg_temp.r2_id(30),pg_temp.r2_id(10),pg_temp.r2_id(20),'institution_admin','active');
insert into public.circulars(id,institution_id,author_person_id,author_membership_id,status,publish_at)
values(pg_temp.r2_id(40),pg_temp.r2_id(10),pg_temp.r2_id(20),pg_temp.r2_id(30),'draft',now());

select lives_ok($$
  insert into public.circular_media_assets(id,circular_id,institution_id,owner_person_id,
    upload_request_id,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size)
  values(pg_temp.r2_id(50),pg_temp.r2_id(40),pg_temp.r2_id(10),pg_temp.r2_id(20),
    pg_temp.r2_id(60),'r2','coelo-media-prod',pg_temp.r2_key(50,'.png'),
    'synthetic.png','image/png',1024)$$,
  'Imagem nova e aceita em coelo-media-prod com chave opaca no escopo do tenant');

select throws_ok($$
  insert into public.circular_media_assets(id,circular_id,institution_id,owner_person_id,
    upload_request_id,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size)
  values(pg_temp.r2_id(51),pg_temp.r2_id(40),pg_temp.r2_id(10),pg_temp.r2_id(20),
    pg_temp.r2_id(61),'r2','coelo-media-prod',pg_temp.r2_key(51,'.pdf'),
    'synthetic.pdf','application/pdf',1024)$$,
  '23514'::char(5),null,'PDF nao pode cair no bucket de imagem e video');

select throws_ok($$
  insert into public.circular_media_assets(id,circular_id,institution_id,owner_person_id,
    upload_request_id,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size)
  values(pg_temp.r2_id(52),pg_temp.r2_id(40),pg_temp.r2_id(10),pg_temp.r2_id(20),
    pg_temp.r2_id(62),'r2','coelo-media-prod',
    replace(pg_temp.r2_key(52,'.png'),pg_temp.r2_id(10)::text,pg_temp.r2_id(99)::text),
    'synthetic.png','image/png',1024)$$,
  '23514'::char(5),null,'Chave fora do escopo do tenant e recusada');

select throws_ok($$
  insert into public.circular_media_assets(id,circular_id,institution_id,owner_person_id,
    upload_request_id,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size,
    status,finalized_at)
  values(pg_temp.r2_id(53),pg_temp.r2_id(40),pg_temp.r2_id(10),pg_temp.r2_id(20),
    pg_temp.r2_id(63),'r2','coelo-media-prod',pg_temp.r2_key(53,'.png'),
    'synthetic.png','image/png',1024,'ready',now())$$,
  '23514'::char(5),null,'Ativo R2 nao fica ready sem checksum medido no servidor');

select throws_ok($$
  insert into public.circular_media_assets(id,circular_id,institution_id,owner_person_id,
    upload_request_id,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size,
    status,finalized_at,checksum_sha256)
  values(pg_temp.r2_id(54),pg_temp.r2_id(40),pg_temp.r2_id(10),pg_temp.r2_id(20),
    pg_temp.r2_id(64),'r2','coelo-media-prod',pg_temp.r2_key(54,'.png'),
    'synthetic.png','image/png',1024,'ready',now(),'NOT-A-SHA256')$$,
  '23514'::char(5),null,'Checksum fora do formato sha256 hexadecimal e recusado');

-- Acervo legado: continua gravavel e legivel exatamente como antes.
select lives_ok($$
  insert into public.circular_media_assets(id,circular_id,institution_id,owner_person_id,
    upload_request_id,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size)
  values(pg_temp.r2_id(55),pg_temp.r2_id(40),pg_temp.r2_id(10),pg_temp.r2_id(20),
    pg_temp.r2_id(65),'supabase','coelo-circulars-private',
    pg_temp.r2_id(10)::text||'/circulars/'||pg_temp.r2_id(40)::text||'/legacy-object',
    'legacy.png','image/png',1024)$$,
  'Ativo legado em Supabase Storage continua aceito no bucket anterior');
set constraints all immediate;

select * from finish();
rollback;
