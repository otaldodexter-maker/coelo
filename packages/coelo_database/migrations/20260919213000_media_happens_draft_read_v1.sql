-- Lote 92 — leitura da mídia do rascunho do Acontece pelo autor (mesmo desenho de authorize_now_asset_read).
-- O rascunho já guardava a mídia pronta, mas a página de publicação não tinha como reler os bytes
-- (só o feed, por bilhete). A Edge happens-media ganha `read-draft`; a regra fica aqui: ativo pronto
-- da instituição, post em rascunho (ou agendado/publicado) e ator com happens.posts.create no contexto,
-- dono do ativo.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create or replace function public.authorize_happens_draft_media_read(p_institution_id uuid, p_asset_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare asset public.media_assets%rowtype; target public.posts%rowtype; actor record;
begin
  select * into asset from public.media_assets
  where id = p_asset_id and institution_id = p_institution_id and status = 'ready' and post_id is not null;
  if asset.id is null then raise insufficient_privilege using message = 'asset_not_authorized'; end if;
  select * into target from public.posts where id = asset.post_id and withdrawn_at is null;
  if target.id is null then raise insufficient_privilege using message = 'asset_not_authorized'; end if;
  select * into actor from app_private.happens_actor(p_institution_id, 'happens.posts.create', target.unit_id, target.group_id);
  if asset.owner_person_id is distinct from actor.person_id and target.author_person_id is distinct from actor.person_id then
    raise insufficient_privilege using message = 'asset_not_authorized';
  end if;
  return jsonb_build_object(
    'storage_provider', asset.storage_provider,
    'bucket_id', asset.bucket_id,
    'object_key', asset.object_key,
    'mime_type', asset.mime_type,
    'byte_size', asset.byte_size
  );
end
$$;
revoke all on function public.authorize_happens_draft_media_read(uuid, uuid) from public, anon;
grant execute on function public.authorize_happens_draft_media_read(uuid, uuid) to authenticated;
commit;
