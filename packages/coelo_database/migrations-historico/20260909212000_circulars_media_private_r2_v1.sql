-- E2 R02 / L01: Circulares passam a gravar midia nova no R2 privado (ADR 0032).
--
-- Forward-only, sem cutover, sem backfill e sem remocao de acervo. As linhas ja
-- gravadas em public.circular_media_assets com storage_provider='supabase'
-- permanecem intocadas, continuam apontando para o bucket privado legado
-- 'coelo-circulars-private' e seguem legiveis pelo ramo legado do gateway
-- circular-media. Nada aqui apaga objeto, migra bytes ou reescreve object_key
-- historico; qualquer transferencia de acervo seria uma decisao separada.
--
-- Ativos novos nascem em R2: 'coelo-media-prod' para imagem/video e
-- 'coelo-documents-prod' para PDF, conforme a topologia da ADR 0032. PDF nunca
-- usa Stream. A chave e opaca e versionada por escopo/dominio/entidade/
-- finalidade/ativo/rendicao, no mesmo formato de
-- app_private.private_media_catalog_key_v1 usado por Forms:
--   tenants/<institution>/circulars/circular/<circular>/attachment/<asset>/original/<uuid>.<ext>
--
-- As restricoes novas entram como NOT VALID de proposito: elas sao aplicadas a
-- toda escrita futura (INSERT e UPDATE), mas nao revalidam o acervo legado, que
-- ficou sob o contrato anterior. Nenhuma credencial R2 vive no banco; assinatura
-- e transporte continuam exclusivamente server-side na Edge Function.
--
-- Circulares NAO entra em public.media_bindings nesta rodada: aquela tabela
-- ainda e tipada para form_versions/form_items. O alinhamento com a ADR aqui e
-- de transporte, provedor, bucket, chave e integridade.
begin;

do $$begin
  if to_regclass('public.circular_media_assets') is null
    or to_regprocedure('public.prepare_circular_media_upload(uuid,uuid,uuid,text,text,bigint)') is null
    or to_regprocedure('public.finalize_circular_media_upload(uuid,uuid,bigint,text,text,text)') is null
    or to_regprocedure('public.authorize_circular_media_read(uuid)') is null
    or to_regprocedure('public.remove_circular_media(uuid)') is null
    or to_regprocedure('app_private.claim_stale_circular_media(integer)') is null
    or to_regprocedure('public.claim_stale_circular_media(integer)') is null
    or to_regprocedure('app_private.circular_actor(uuid,text,uuid,uuid)') is null then
    raise exception 'circulars_media_r2_dependencies_missing';
  end if;
end$$;

-- O CHECK original era inline e anonimo: check (storage_provider = 'supabase').
-- Ele e localizado pela definicao para nao depender do nome gerado.
do $$
declare legacy_constraint text;
begin
  for legacy_constraint in
    select conname from pg_constraint
    where conrelid = 'public.circular_media_assets'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) like '%storage_provider%'
  loop
    execute format(
      'alter table public.circular_media_assets drop constraint %I',
      legacy_constraint);
  end loop;
end$$;

alter table public.circular_media_assets
  alter column storage_provider set default 'r2',
  -- Sem default: o bucket depende do MIME e passa a ser escolhido pela RPC.
  alter column bucket_id drop default,
  add constraint circular_media_assets_storage_provider_ck
    check (storage_provider in ('supabase','r2')),
  add constraint circular_media_assets_bucket_ck check (
    (storage_provider = 'supabase' and bucket_id = 'coelo-circulars-private')
    or (storage_provider = 'r2' and bucket_id = case
      when mime_type = 'application/pdf' then 'coelo-documents-prod'
      else 'coelo-media-prod' end)
  ) not valid,
  add constraint circular_media_assets_r2_key_shape_ck check (
    storage_provider <> 'r2' or object_key ~ (
      '^tenants/' || institution_id::text || '/circulars/circular/'
      || circular_id::text || '/attachment/' || id::text || '/original/'
      || '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
      || case mime_type
        when 'image/jpeg' then '[.]jpg$'
        when 'image/png' then '[.]png$'
        when 'image/webp' then '[.]webp$'
        when 'video/mp4' then '[.]mp4$'
        when 'application/pdf' then '[.]pdf$'
        else '$a' end)
  ) not valid,
  add constraint circular_media_assets_checksum_format_ck
    check (checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$') not valid,
  -- Um ativo R2 so e 'ready' com integridade medida server-side pelo gateway.
  add constraint circular_media_assets_r2_ready_integrity_ck check (
    storage_provider <> 'r2' or status <> 'ready'
    or (checksum_sha256 is not null and byte_size is not null
      and finalized_at is not null)
  ) not valid;

-- Corpo original preservado. Muda somente a origem da chave/bucket do ativo
-- novo (R2) e o provedor devolvido ao gateway. Ativo ja existente com o mesmo
-- upload_request_id continua sendo devolvido como estava, inclusive legado.
create or replace function public.prepare_circular_media_upload(
  p_request_id uuid,p_institution_id uuid,p_circular_id uuid,p_name text,p_mime_type text,p_byte_size bigint
) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor record; target public.circulars%rowtype; asset public.circular_media_assets%rowtype; max_bytes bigint;
  new_asset_id uuid; new_bucket text; new_object_key text;
begin
  select * into target from public.circulars c where c.id=p_circular_id and c.institution_id=p_institution_id and c.working_revision_id is not null and c.deleted_at is null;
  if target.id is null then raise insufficient_privilege using message='circular_not_authorized'; end if;
  select * into actor from app_private.circular_actor(p_institution_id,'circulars.circulars.create',target.unit_id,target.group_id);
  if target.author_person_id<>actor.person_id then raise insufficient_privilege using message='circular_not_authorized'; end if;
  max_bytes:=case when p_mime_type in ('image/jpeg','image/png','image/webp') then 10485760 when p_mime_type='video/mp4' then 26214400 when p_mime_type='application/pdf' then 5242880 end;
  if max_bytes is null or p_byte_size not between 1 and max_bytes then raise check_violation using message='circular_media_invalid'; end if;
  select * into asset from public.circular_media_assets m where m.circular_id=target.id and m.upload_request_id=p_request_id;
  if asset.id is null then
    if (select count(*) from public.circular_media_assets m where m.circular_id=target.id and m.status<>'deleted')>=4 then raise check_violation using message='circular_media_limit'; end if;
    new_asset_id:=gen_random_uuid();
    new_bucket:=case when p_mime_type='application/pdf' then 'coelo-documents-prod' else 'coelo-media-prod' end;
    new_object_key:='tenants/'||p_institution_id::text||'/circulars/circular/'||target.id::text
      ||'/attachment/'||new_asset_id::text||'/original/'||gen_random_uuid()::text
      ||case p_mime_type when 'image/jpeg' then '.jpg' when 'image/png' then '.png'
        when 'image/webp' then '.webp' when 'video/mp4' then '.mp4' else '.pdf' end;
    insert into public.circular_media_assets(id,circular_id,institution_id,owner_person_id,upload_request_id,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size)
    values(new_asset_id,target.id,p_institution_id,actor.person_id,p_request_id,'r2',new_bucket,new_object_key,p_name,p_mime_type,p_byte_size)
    returning * into asset;
  elsif asset.owner_person_id<>actor.person_id or asset.mime_type<>p_mime_type or asset.byte_size<>p_byte_size then
    raise insufficient_privilege using message='upload_request_conflict';
  end if;
  return jsonb_build_object('asset_id',asset.id,'storage_provider',asset.storage_provider,'bucket_id',asset.bucket_id,'object_key',asset.object_key,'expected_mime_type',asset.mime_type,'expected_byte_size',asset.byte_size,'status',asset.status);
end $$;

-- Corpo original preservado. Acrescenta o provedor na resposta e exige o
-- checksum sha256 medido pelo gateway para todo ativo R2. Ativo legado
-- 'supabase' finaliza exatamente como antes.
create or replace function public.finalize_circular_media_upload(
  p_asset_id uuid,p_finalize_ticket uuid,p_expected_byte_size bigint,p_expected_mime_type text,p_checksum_sha256 text,p_etag text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare asset public.circular_media_assets%rowtype;
begin
  select * into asset from public.circular_media_assets m where m.id=p_asset_id for update;
  if asset.status='ready' and asset.byte_size=p_expected_byte_size and asset.mime_type=p_expected_mime_type then
    return jsonb_build_object('asset_id',asset.id,'storage_provider',asset.storage_provider,'bucket_id',asset.bucket_id,'object_key',asset.object_key,'status',asset.status);
  end if;
  if asset.id is null or asset.status<>'pending' or asset.finalize_ticket<>p_finalize_ticket or asset.finalize_ticket_expires_at<=now()
    or asset.byte_size<>p_expected_byte_size or asset.mime_type<>p_expected_mime_type
  then raise insufficient_privilege using message='media_finalize_denied'; end if;
  if asset.storage_provider='r2' and (p_checksum_sha256 is null or p_checksum_sha256 !~ '^[0-9a-f]{64}$')
  then raise check_violation using message='media_checksum_required'; end if;
  update public.circular_media_assets set status='ready',checksum_sha256=p_checksum_sha256,etag=p_etag,finalized_at=now(),finalize_ticket=null,finalize_ticket_expires_at=null where id=asset.id returning * into asset;
  return jsonb_build_object('asset_id',asset.id,'storage_provider',asset.storage_provider,'bucket_id',asset.bucket_id,'object_key',asset.object_key,'status',asset.status);
end $$;

-- Corpo original preservado. Acrescenta somente o provedor ao descritor, para
-- que o gateway escolha o transporte certo ao apagar o objeto.
create or replace function public.remove_circular_media(p_asset_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare asset public.circular_media_assets%rowtype; target public.circulars%rowtype; actor record;
begin
  select * into asset from public.circular_media_assets m where m.id=p_asset_id for update;
  select * into target from public.circulars c where c.id=asset.circular_id;
  select * into actor from app_private.circular_actor(asset.institution_id,'circulars.circulars.create',target.unit_id,target.group_id);
  if asset.id is null or asset.owner_person_id<>actor.person_id or target.working_revision_id is null then raise insufficient_privilege using message='media_remove_denied'; end if;
  if exists(select 1 from public.circular_media_links l join public.circular_revisions r on r.id=l.revision_id where l.media_asset_id=asset.id and r.status<>'working')
  then raise check_violation using message='published_media_immutable'; end if;
  delete from public.circular_media_links l using public.circular_revisions r where l.media_asset_id=asset.id and r.id=l.revision_id and r.status='working';
  update public.circular_media_assets set status='orphaned' where id=asset.id;
  return jsonb_build_object('asset_id',asset.id,'storage_provider',asset.storage_provider,'bucket_id',asset.bucket_id,'object_key',asset.object_key);
end $$;

-- Corpo original preservado. Acrescenta somente o provedor ao descritor de
-- leitura autorizada; a autorizacao continua sendo a mesma e no servidor.
create or replace function public.authorize_circular_media_read(p_asset_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare asset public.circular_media_assets%rowtype; target public.circulars%rowtype; actor record;
begin
  select * into asset from public.circular_media_assets m where m.id=p_asset_id and m.status='ready';
  select * into target from public.circulars c where c.id=asset.circular_id;
  select * into actor from app_private.circular_actor(target.institution_id,'circulars.circulars.read',target.unit_id,target.group_id);
  if asset.id is null or not app_private.circular_visible(target,actor.person_id,actor.role_code,target.unit_id,target.group_id,target.activity_id) then raise insufficient_privilege using message='media_read_denied'; end if;
  return jsonb_build_object('storage_provider',asset.storage_provider,'bucket_id',asset.bucket_id,'object_key',asset.object_key,'mime_type',asset.mime_type,'byte_size',asset.byte_size);
end $$;

-- claim_stale_circular_media e o unico caso em que preservar a forma exata foi
-- impossivel: e "returns table" e o coletor precisa saber provedor e bucket
-- para apagar o objeto certo. "create or replace" nao altera colunas de saida,
-- entao as duas funcoes sao recriadas com a MESMA assinatura de argumentos
-- (integer) e duas colunas acrescentadas ao fim do retorno. Os grants abaixo
-- reproduzem exatamente os do arquivo original: somente service_role.
drop function public.claim_stale_circular_media(integer);
drop function app_private.claim_stale_circular_media(integer);

create function app_private.claim_stale_circular_media(p_limit integer default 50)
returns table(asset_id uuid,object_key text,storage_provider text,bucket_id text) language plpgsql security definer set search_path='' as $$
begin
  return query with claimed as (
    select m.id from public.circular_media_assets m where m.status in ('pending','orphaned') and m.created_at<now()-interval '30 minutes'
      and (m.cleanup_attempted_at is null or m.cleanup_attempted_at<now()-interval '10 minutes') order by m.created_at for update skip locked limit least(greatest(coalesce(p_limit,50),1),200)
  ) update public.circular_media_assets m set status='orphaned',cleanup_attempted_at=now() from claimed where m.id=claimed.id returning m.id,m.object_key,m.storage_provider,m.bucket_id;
end $$;

create function public.claim_stale_circular_media(p_limit integer default 50)
returns table(asset_id uuid,object_key text,storage_provider text,bucket_id text) language sql security definer set search_path='' as $$
  select * from app_private.claim_stale_circular_media(p_limit)
$$;

-- Mesmos revoke/grant do arquivo original, reaplicados sem alargar nada.
revoke all on function
  public.prepare_circular_media_upload(uuid,uuid,uuid,text,text,bigint),
  public.finalize_circular_media_upload(uuid,uuid,bigint,text,text,text),
  public.remove_circular_media(uuid),
  public.authorize_circular_media_read(uuid),
  public.claim_stale_circular_media(integer),
  app_private.claim_stale_circular_media(integer)
from public,anon,authenticated,service_role;

grant execute on function
  public.prepare_circular_media_upload(uuid,uuid,uuid,text,text,bigint),
  public.remove_circular_media(uuid),
  public.authorize_circular_media_read(uuid)
to authenticated;

grant execute on function
  public.finalize_circular_media_upload(uuid,uuid,bigint,text,text,text),
  public.claim_stale_circular_media(integer),
  app_private.claim_stale_circular_media(integer)
to service_role;

commit;
