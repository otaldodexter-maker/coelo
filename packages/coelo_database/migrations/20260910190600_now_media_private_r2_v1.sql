-- Agora: midia nova nasce no R2 privado (ADR 0032; ADR 0034, Decisao 5 e 11).
--
-- Padrao de 20260909212000_circulars_media_private_r2_v1: forward-only, sem
-- cutover e sem backfill. Producao nunca teve linha em now_media_assets (a
-- fundacao entra nesta mesma fila, 20260910190300), entao o ramo legado
-- 'supabase_mvp' fica so por simetria com o gateway now-media, que ja trata
-- os dois provedores. Nenhum bucket do Supabase Storage e criado.
--
-- Master no R2: imagem, video e audio em 'coelo-media-prod'. Stream HOT por
-- ate 24 h (D2) e decisao do gateway a partir da publicacao, nunca do banco.
-- Chave opaca por escopo/dominio/entidade/finalidade/ativo/rendicao:
--   tenants/<institution>/now/publication/<publication>/<kind>/<asset>/original/<uuid>.<ext>
--
-- Substituicao de ativo (mesma publicacao e mesmo kind com metadados novos)
-- cria chave nova; o objeto anterior fica orfao no R2 ate um coletor proprio.
-- ponytail: sem claim_stale aqui; adicionar quando houver volume medido.
-- Nenhuma credencial R2 vive no banco: assinatura e transporte sao da Edge
-- Function now-media.
begin;

do $$begin
  if to_regclass('public.now_media_assets') is null
    or to_regprocedure('public.prepare_now_asset_upload(uuid,uuid,public.now_asset_kind,text,text,bigint,numeric,boolean)') is null
    or to_regprocedure('public.finalize_now_asset_upload(uuid,text)') is null
    or to_regprocedure('public.authorize_now_asset_read(uuid,uuid)') is null
    or to_regprocedure('public.redeem_now_media_read_ticket(uuid,uuid)') is null
    or to_regprocedure('app_private.now_actor(uuid,text,uuid,uuid)') is null
    or to_regprocedure('app_private.now_viewer_role_class(uuid,uuid,uuid,uuid,uuid)') is null
    or to_regprocedure('app_private.now_max_video_seconds(uuid)') is null then
    raise exception 'now_media_r2_dependencies_missing';
  end if;
end$$;

alter table public.now_media_assets
  alter column storage_provider set default 'r2',
  -- Sem default: o bucket passa a ser escolhido pela RPC conforme o provedor.
  alter column bucket_id drop default,
  add constraint now_media_assets_bucket_ck check (
    (storage_provider='supabase_mvp' and bucket_id='coelo-now-mvp')
    or (storage_provider='r2' and bucket_id='coelo-media-prod')
  ),
  add constraint now_media_assets_r2_key_shape_ck check (
    storage_provider<>'r2' or object_key ~ (
      '^tenants/'||institution_id::text||'/now/publication/'||publication_id::text
      ||'/'||kind::text||'/'||id::text||'/original/'
      ||'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
      ||case mime_type
        when 'image/jpeg' then '[.]jpg$' when 'image/png' then '[.]png$'
        when 'image/webp' then '[.]webp$' when 'video/mp4' then '[.]mp4$'
        when 'audio/mpeg' then '[.]mp3$' when 'audio/mp4' then '[.]m4a$'
        when 'audio/wav' then '[.]wav$' when 'audio/aac' then '[.]aac$'
        else '$a' end)
  ),
  add constraint now_media_assets_checksum_format_ck
    check (checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$'),
  -- Um ativo R2 so e 'ready' com integridade medida server-side pelo gateway.
  add constraint now_media_assets_r2_ready_integrity_ck check (
    storage_provider<>'r2' or status<>'ready'
    or (checksum_sha256 is not null and finalized_at is not null)
  );

-- Validacoes originais preservadas. Muda a origem do ativo novo (R2, chave
-- opaca com o id do ativo) e o descritor devolvido ao gateway. Chamada repetida
-- com os mesmos metadados devolve o mesmo descritor: o gateway chama prepare de
-- novo ao finalizar, e a chave nao pode mudar no meio do upload.
create or replace function public.prepare_now_asset_upload(p_institution_id uuid,p_publication_id uuid,p_kind public.now_asset_kind,p_name text,p_mime_type text,p_byte_size bigint,p_duration_seconds numeric,p_rights_confirmed boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor record;asset public.now_media_assets%rowtype;target public.now_publications%rowtype;
  max_seconds integer;new_asset_id uuid;new_object_key text;
begin
  select * into target from public.now_publications
    where id=p_publication_id and institution_id=p_institution_id and status='draft';
  if target.id is null then raise insufficient_privilege using message='publication_not_authorized';end if;
  select * into actor from app_private.now_actor(p_institution_id,'now.publications.create',target.unit_id,target.group_id);
  if target.author_person_id<>actor.person_id then raise insufficient_privilege using message='publication_not_authorized';end if;
  if p_byte_size<1 or p_byte_size>26214400 or char_length(p_name)>255 then raise check_violation using message='invalid_asset_metadata';end if;
  if p_kind='media' and p_mime_type not in('image/jpeg','image/png','image/webp','video/mp4') then raise check_violation using message='unsupported_media_type';end if;
  if p_kind='audio' and (p_mime_type not in('audio/mpeg','audio/mp4','audio/wav','audio/aac') or not p_rights_confirmed) then raise check_violation using message='audio_rights_required';end if;
  if p_kind='cover' and p_mime_type not in('image/jpeg','image/png','image/webp') then raise check_violation using message='unsupported_cover_type';end if;
  max_seconds:=app_private.now_max_video_seconds(p_institution_id);
  if p_mime_type='video/mp4' and (p_duration_seconds is null or p_duration_seconds>max_seconds) then raise check_violation using message='video_duration_exceeded';end if;

  select * into asset from public.now_media_assets
    where publication_id=p_publication_id and kind=p_kind for update;
  if asset.id is not null and asset.owner_person_id=actor.person_id
    and asset.mime_type=p_mime_type and asset.byte_size=p_byte_size
    and asset.original_name=p_name and asset.status in('pending','ready') then
    return jsonb_build_object('asset_id',asset.id,'storage_provider',asset.storage_provider,'bucket_id',asset.bucket_id,'object_key',asset.object_key,'expected_mime_type',asset.mime_type,'expected_byte_size',asset.byte_size,'status',asset.status);
  end if;

  new_asset_id:=coalesce(asset.id,gen_random_uuid());
  new_object_key:='tenants/'||p_institution_id::text||'/now/publication/'||p_publication_id::text
    ||'/'||p_kind::text||'/'||new_asset_id::text||'/original/'||gen_random_uuid()::text
    ||case p_mime_type when 'image/jpeg' then '.jpg' when 'image/png' then '.png'
      when 'image/webp' then '.webp' when 'video/mp4' then '.mp4' when 'audio/mpeg' then '.mp3'
      when 'audio/mp4' then '.m4a' when 'audio/wav' then '.wav' else '.aac' end;
  if asset.id is null then
    insert into public.now_media_assets(id,publication_id,institution_id,owner_person_id,kind,storage_provider,bucket_id,object_key,original_name,mime_type,byte_size,duration_seconds,rights_confirmed)
    values(new_asset_id,p_publication_id,p_institution_id,actor.person_id,p_kind,'r2','coelo-media-prod',new_object_key,p_name,p_mime_type,p_byte_size,p_duration_seconds,p_rights_confirmed)
    returning * into asset;
  else
    update public.now_media_assets set storage_provider='r2',bucket_id='coelo-media-prod',object_key=new_object_key,
      original_name=p_name,mime_type=p_mime_type,byte_size=p_byte_size,duration_seconds=p_duration_seconds,
      rights_confirmed=p_rights_confirmed,status='pending',finalized_at=null,checksum_sha256=null
    where id=asset.id returning * into asset;
  end if;
  return jsonb_build_object('asset_id',asset.id,'storage_provider',asset.storage_provider,'bucket_id',asset.bucket_id,'object_key',asset.object_key,'expected_mime_type',asset.mime_type,'expected_byte_size',asset.byte_size,'status',asset.status);
end $$;

-- Corpo original preservado. No R2 o objeto nao existe em storage.objects: a
-- prova de upload e o checksum medido pelo gateway sobre os bytes relidos.
create or replace function public.finalize_now_asset_upload(p_asset_id uuid,p_checksum_sha256 text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare asset public.now_media_assets%rowtype;target public.now_publications%rowtype;actor record;
begin
  select * into asset from public.now_media_assets where id=p_asset_id for update;
  if asset.id is null then raise insufficient_privilege using message='asset_not_authorized';end if;
  select * into target from public.now_publications where id=asset.publication_id;
  select * into actor from app_private.now_actor(asset.institution_id,'now.publications.create',target.unit_id,target.group_id);
  if asset.owner_person_id<>actor.person_id or p_checksum_sha256 !~ '^[0-9a-f]{64}$'
    or (asset.storage_provider<>'r2' and not exists(select 1 from storage.objects where bucket_id=asset.bucket_id and name=asset.object_key))
  then raise insufficient_privilege using message='asset_not_uploaded';end if;
  update public.now_media_assets set checksum_sha256=p_checksum_sha256,status='ready',finalized_at=now() where id=p_asset_id;
  return jsonb_build_object('asset_id',asset.id,'storage_provider',asset.storage_provider,'object_key',asset.object_key);
end $$;

-- Corpo original preservado. Acrescenta somente o provedor ao descritor.
create or replace function public.authorize_now_asset_read(p_institution_id uuid,p_asset_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare asset public.now_media_assets%rowtype;target public.now_publications%rowtype;actor record;
begin
  select * into asset from public.now_media_assets where id=p_asset_id and institution_id=p_institution_id and status='ready';
  if asset.id is null then raise insufficient_privilege using message='asset_not_authorized';end if;
  select * into target from public.now_publications where id=asset.publication_id and status='draft';
  if target.id is null then raise insufficient_privilege using message='asset_not_authorized';end if;
  select * into actor from app_private.now_actor(p_institution_id,'now.publications.create',target.unit_id,target.group_id);
  if asset.owner_person_id<>actor.person_id then raise insufficient_privilege using message='asset_not_authorized';end if;
  return jsonb_build_object(
    'storage_provider',asset.storage_provider,
    'bucket_id',asset.bucket_id,
    'object_key',asset.object_key,
    'mime_type',asset.mime_type
  );
end $$;

-- Corpo de 20260910190500 preservado. Acrescenta somente o provedor.
create or replace function public.redeem_now_media_read_ticket(
  p_ticket uuid,
  p_viewer_auth_user_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  redeemed record;
begin
  delete from app_private.now_media_read_tickets ticket
  using public.person_auth_links auth_link,
        public.institution_memberships membership,
        public.now_media_assets asset,
        public.now_publications publication
  where ticket.token=p_ticket
    and ticket.expires_at>now()
    and auth_link.person_id=ticket.viewer_person_id
    and auth_link.auth_user_id=p_viewer_auth_user_id
    and auth_link.status='active'
    and membership.person_id=ticket.viewer_person_id
    and membership.institution_id=asset.institution_id
    and membership.status='active'
    and membership.revoked_at is null
    and asset.id=ticket.media_asset_id
    and asset.status='ready'
    and publication.id=asset.publication_id
    and publication.institution_id=asset.institution_id
    and publication.status in('scheduled','published')
    and publication.publish_at<=now()
    and publication.expires_at>now()
    and publication.status<>'expired'
    and app_private.now_viewer_role_class(
      ticket.viewer_person_id,
      membership.id,
      publication.institution_id,
      publication.unit_id,
      publication.group_id
    ) is not null
    and exists(
      select 1
      from public.now_publication_audiences audience
      where audience.publication_id=publication.id
        and audience.institution_id=publication.institution_id
        and audience.unit_id is not distinct from publication.unit_id
        and audience.group_id is not distinct from publication.group_id
        and app_private.now_audience_matches_role(
          app_private.now_viewer_role_class(
            ticket.viewer_person_id,
            membership.id,
            publication.institution_id,
            publication.unit_id,
            publication.group_id
          ),
          audience.audience_kind
        )
    )
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

-- Mesmos revoke/grant da fundacao, reaplicados sem alargar nada.
revoke all on function
  public.prepare_now_asset_upload(uuid,uuid,public.now_asset_kind,text,text,bigint,numeric,boolean),
  public.finalize_now_asset_upload(uuid,text),
  public.authorize_now_asset_read(uuid,uuid),
  public.redeem_now_media_read_ticket(uuid,uuid)
from public,anon,authenticated,service_role;
grant execute on function
  public.prepare_now_asset_upload(uuid,uuid,public.now_asset_kind,text,text,bigint,numeric,boolean),
  public.finalize_now_asset_upload(uuid,text),
  public.authorize_now_asset_read(uuid,uuid)
to authenticated;
grant execute on function public.redeem_now_media_read_ticket(uuid,uuid) to service_role;

commit;
