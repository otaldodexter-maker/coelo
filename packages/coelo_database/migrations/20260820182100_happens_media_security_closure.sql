-- Retry-safe media finalization and draft-scoped deletion for Acontece.
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
    asset.institution_id,
    'happens.posts.create',
    target.unit_id,
    target.group_id
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
    return jsonb_build_object('asset_id',asset.id,'object_key',asset.object_key);
  end if;

  if asset.status<>'pending' or exists(
    select 1 from public.media_links
    where post_id=target.id
      and (media_asset_id=asset.id or display_order=p_display_order::smallint)
  ) or not exists(
    select 1 from storage.objects
    where bucket_id=asset.bucket_id and name=asset.object_key
  ) then
    raise check_violation using message='media_finalize_conflict';
  end if;

  update public.media_assets
  set checksum_sha256=p_checksum_sha256,status='ready',finalized_at=now()
  where id=asset.id;
  insert into public.media_links(post_id,media_asset_id,display_order)
  values(target.id,asset.id,p_display_order::smallint);
  return jsonb_build_object('asset_id',asset.id,'object_key',asset.object_key);
end
$$;

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
    asset.institution_id,
    'happens.posts.create',
    target.unit_id,
    target.group_id
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
  return jsonb_build_object('bucket_id',asset.bucket_id,'object_key',asset.object_key);
end
$$;

revoke all on function public.finalize_happens_media_upload(uuid,uuid,text,bigint),
  public.remove_happens_media(uuid) from public,anon;
grant execute on function public.finalize_happens_media_upload(uuid,uuid,text,bigint),
  public.remove_happens_media(uuid) to authenticated;
