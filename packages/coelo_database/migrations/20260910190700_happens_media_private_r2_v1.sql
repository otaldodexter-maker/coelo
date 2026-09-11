-- Acontece: midia nova nasce no R2 privado (ADR 0032; ADR 0034, Decisao 5).
--
-- Padrao de 20260909212000_circulars_media_private_r2_v1: forward-only, sem
-- cutover, sem backfill e sem remocao de acervo. Linhas ja gravadas em
-- public.media_assets com storage_provider='supabase_mvp' (catalog_kind
-- 'legacy-happens') continuam intocadas, no bucket 'coelo-happens-mvp', e
-- seguem legiveis pelo ramo legado do gateway happens-media. Nada apaga objeto,
-- migra bytes ou reescreve object_key historico.
--
-- Ativos novos do Acontece nascem em R2, no bucket 'coelo-media-prod'
-- (imagem e video; Stream so por necessidade medida). Chave opaca versionada:
--   tenants/<institution>/happens/post/<post>/attachment/<asset>/original/<uuid>.<ext>
--
-- As restricoes entram como NOT VALID: valem para toda escrita futura e nao
-- revalidam o acervo legado. Todas sao condicionadas a catalog_kind
-- 'legacy-happens' para nao tocar o ramo 'form-image' de
-- 20260910230007_private_media_catalog_r2_v1, que tem o proprio contrato.
-- Nenhuma credencial R2 vive no banco.
begin;

do $$begin
  if to_regclass('public.media_assets') is null
    or to_regprocedure('public.prepare_happens_media_upload(text,uuid,uuid,text,text,bigint)') is null
    or to_regprocedure('public.finalize_happens_media_upload(uuid,uuid,text,bigint)') is null
    or to_regprocedure('public.remove_happens_media(uuid)') is null
    or to_regprocedure('public.redeem_happens_media_read_ticket(uuid,uuid)') is null
    or to_regprocedure('app_private.happens_actor(uuid,text,uuid,uuid)') is null
    or not exists(select 1 from pg_attribute where attrelid='public.media_assets'::regclass and attname='catalog_kind' and not attisdropped) then
    raise exception 'happens_media_r2_dependencies_missing';
  end if;
end$$;

alter table public.media_assets
  alter column storage_provider set default 'r2',
  -- Sem default: o bucket passa a ser escolhido pela RPC conforme o provedor.
  alter column bucket_id drop default,
  add constraint media_assets_happens_bucket_ck check (
    catalog_kind<>'legacy-happens'
    or (storage_provider='supabase_mvp' and bucket_id='coelo-happens-mvp')
    or (storage_provider='r2' and bucket_id='coelo-media-prod')
  ) not valid,
  add constraint media_assets_happens_r2_key_shape_ck check (
    catalog_kind<>'legacy-happens' or storage_provider<>'r2' or object_key ~ (
      '^tenants/'||institution_id::text||'/happens/post/'||post_id::text
      ||'/attachment/'||id::text||'/original/'
      ||'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
      ||case mime_type
        when 'image/jpeg' then '[.]jpg$' when 'image/png' then '[.]png$'
        when 'image/webp' then '[.]webp$' when 'video/mp4' then '[.]mp4$'
        else '$a' end)
  ) not valid,
  add constraint media_assets_happens_checksum_format_ck check (
    catalog_kind<>'legacy-happens' or checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$'
  ) not valid,
  -- Um ativo R2 so e 'ready' com integridade medida server-side pelo gateway.
  add constraint media_assets_happens_r2_ready_integrity_ck check (
    catalog_kind<>'legacy-happens' or storage_provider<>'r2' or status<>'ready'
    or (checksum_sha256 is not null and finalized_at is not null)
  ) not valid;

-- Corpo original preservado. Muda somente a origem do ativo novo (R2, chave
-- opaca com o id do ativo) e o descritor devolvido ao gateway. Ativo ja
-- existente com o mesmo upload_request_id continua sendo devolvido como esta,
-- inclusive legado.
create or replace function public.prepare_happens_media_upload(p_request_id text,p_institution_id uuid,p_post_id uuid,p_name text,p_mime_type text,p_byte_size bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor record;asset public.media_assets%rowtype;target public.posts%rowtype;new_asset_id uuid;new_object_key text;
begin
  select * into target from public.posts where id=p_post_id and institution_id=p_institution_id and status='draft';
  if target.id is null then raise insufficient_privilege using message='post_not_authorized';end if;
  select * into actor from app_private.happens_actor(p_institution_id,'happens.posts.create',target.unit_id,target.group_id);
  if target.author_person_id<>actor.person_id then raise insufficient_privilege using message='post_not_authorized';end if;
  if p_mime_type not in('image/jpeg','image/png','image/webp','video/mp4') then raise check_violation using message='unsupported_media_type';end if;
  select * into asset from public.media_assets where post_id=p_post_id and upload_request_id=p_request_id;
  if asset.id is not null then
    if asset.owner_person_id<>actor.person_id or asset.mime_type<>p_mime_type or asset.byte_size<>p_byte_size then raise insufficient_privilege using message='upload_request_conflict';end if;
    return jsonb_build_object('asset_id',asset.id,'storage_provider',asset.storage_provider,'bucket_id',asset.bucket_id,'object_key',asset.object_key,'expected_mime_type',asset.mime_type,'expected_byte_size',asset.byte_size,'status',asset.status);
  end if;
  new_asset_id:=gen_random_uuid();
  new_object_key:='tenants/'||p_institution_id::text||'/happens/post/'||p_post_id::text
    ||'/attachment/'||new_asset_id::text||'/original/'||gen_random_uuid()::text
    ||case p_mime_type when 'image/jpeg' then '.jpg' when 'image/png' then '.png'
      when 'image/webp' then '.webp' else '.mp4' end;
  insert into public.media_assets(id,institution_id,post_id,owner_person_id,upload_request_id,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size)
  values(new_asset_id,p_institution_id,p_post_id,actor.person_id,p_request_id,'r2','coelo-media-prod',new_object_key,p_name,p_mime_type,p_byte_size)
  returning * into asset;
  return jsonb_build_object('asset_id',asset.id,'storage_provider',asset.storage_provider,'bucket_id',asset.bucket_id,'object_key',asset.object_key,'expected_mime_type',asset.mime_type,'expected_byte_size',asset.byte_size,'status',asset.status);
end $$;

-- Corpo original preservado. No R2 o objeto nao existe em storage.objects: a
-- prova de upload e o checksum sha256 medido pelo gateway sobre os bytes
-- relidos, exigido no formato. Ativo legado finaliza exatamente como antes.
create or replace function public.finalize_happens_media_upload(
  p_asset_id uuid,
  p_post_id uuid,
  p_checksum_sha256 text,
  p_display_order bigint
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  asset public.media_assets%rowtype;
  actor record;
  target public.posts%rowtype;
begin
  select * into asset
  from public.media_assets
  where id=p_asset_id and post_id=p_post_id
  for update;
  if asset.id is null then
    raise insufficient_privilege using message='asset_not_authorized';
  end if;

  select * into target
  from public.posts
  where id=p_post_id and institution_id=asset.institution_id and status='draft'
  for update;
  if target.id is null then
    raise insufficient_privilege using message='media_not_uploaded';
  end if;

  select * into actor
  from app_private.happens_actor(
    asset.institution_id,'happens.posts.create',target.unit_id,target.group_id
  );
  if asset.owner_person_id<>actor.person_id or target.author_person_id<>actor.person_id then
    raise insufficient_privilege using message='media_not_uploaded';
  end if;

  if exists(
    select 1 from public.media_links
    where post_id=target.id
      and media_asset_id=asset.id
      and display_order=p_display_order::smallint
  ) and asset.status='ready' then
    return jsonb_build_object('asset_id',asset.id,'storage_provider',asset.storage_provider,'object_key',asset.object_key);
  end if;

  if asset.storage_provider='r2' and (p_checksum_sha256 is null or p_checksum_sha256 !~ '^[0-9a-f]{64}$') then
    raise check_violation using message='media_checksum_required';
  end if;

  if asset.status<>'pending' or exists(
    select 1 from public.media_links
    where post_id=target.id
      and (media_asset_id=asset.id or display_order=p_display_order::smallint)
  ) or (asset.storage_provider<>'r2' and not exists(
    select 1 from storage.objects
    where bucket_id=asset.bucket_id and name=asset.object_key
  )) then
    raise check_violation using message='media_finalize_conflict';
  end if;

  update public.media_assets
  set checksum_sha256=p_checksum_sha256,status='ready',finalized_at=now()
  where id=asset.id;
  insert into public.media_links(post_id,media_asset_id,display_order)
  values(target.id,asset.id,p_display_order::smallint);
  return jsonb_build_object('asset_id',asset.id,'storage_provider',asset.storage_provider,'object_key',asset.object_key);
end
$$;

-- Corpo original preservado. Acrescenta somente o provedor ao descritor, para
-- que o gateway escolha o transporte certo ao apagar o objeto.
create or replace function public.remove_happens_media(p_asset_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  asset public.media_assets%rowtype;
  actor record;
  target public.posts%rowtype;
begin
  select * into asset from public.media_assets where id=p_asset_id for update;
  if asset.id is null then
    raise insufficient_privilege using message='asset_not_authorized';
  end if;
  select * into target
  from public.posts
  where id=asset.post_id and institution_id=asset.institution_id
  for update;
  if target.id is null or target.status<>'draft' then
    raise check_violation using message='published_media_immutable';
  end if;
  select * into actor
  from app_private.happens_actor(
    asset.institution_id,'happens.posts.create',target.unit_id,target.group_id
  );
  if asset.owner_person_id<>actor.person_id or target.author_person_id<>actor.person_id then
    raise insufficient_privilege using message='asset_not_authorized';
  end if;
  delete from public.media_links
  where post_id=target.id and media_asset_id=asset.id;
  update public.media_assets set status='deleted' where id=asset.id;
  insert into app_private.happens_publication_audit(
    post_id,institution_id,actor_person_id,event_code,detail
  ) values(
    target.id,
    asset.institution_id,
    actor.person_id,
    'media_removed',
    jsonb_build_object('asset_id',asset.id,'object_key',asset.object_key)
  );
  return jsonb_build_object('storage_provider',asset.storage_provider,'bucket_id',asset.bucket_id,'object_key',asset.object_key);
end
$$;

-- Corpo original preservado. Acrescenta somente o provedor ao descritor.
create or replace function public.redeem_happens_media_read_ticket(p_ticket uuid,p_viewer_auth_user_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  redeemed record;
begin
  delete from app_private.happens_media_read_tickets ticket
  using public.person_auth_links auth_link,public.media_assets asset
  where ticket.token=p_ticket
    and ticket.expires_at>now()
    and auth_link.person_id=ticket.viewer_person_id
    and auth_link.auth_user_id=p_viewer_auth_user_id
    and auth_link.status='active'
    and asset.id=ticket.media_asset_id
    and asset.status='ready'
  returning asset.storage_provider,asset.bucket_id,asset.object_key,asset.mime_type into redeemed;
  if redeemed.object_key is null then
    raise insufficient_privilege using message='media_read_ticket_invalid';
  end if;
  return jsonb_build_object(
    'storage_provider',redeemed.storage_provider,
    'bucket_id',redeemed.bucket_id,
    'object_key',redeemed.object_key,
    'mime_type',redeemed.mime_type
  );
end $$;

-- Mesmos revoke/grant da baseline, reaplicados sem alargar nada.
revoke all on function
  public.prepare_happens_media_upload(text,uuid,uuid,text,text,bigint),
  public.finalize_happens_media_upload(uuid,uuid,text,bigint),
  public.remove_happens_media(uuid),
  public.redeem_happens_media_read_ticket(uuid,uuid)
from public,anon,authenticated,service_role;
grant execute on function
  public.prepare_happens_media_upload(text,uuid,uuid,text,text,bigint),
  public.finalize_happens_media_upload(uuid,uuid,text,bigint),
  public.remove_happens_media(uuid)
to authenticated,service_role;
grant execute on function public.redeem_happens_media_read_ticket(uuid,uuid) to service_role;

commit;
