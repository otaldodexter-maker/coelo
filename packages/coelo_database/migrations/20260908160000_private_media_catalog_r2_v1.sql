-- C02 / I003: local candidate, ADR 0032. No cutover, backfill or public RPC.
-- Existing Acontece rows and commands keep their original shape and grants.
-- New image rows are catalogued atomically with a typed binding. The gateway
-- must authorize the current actor before writing; constraints are not auth.
begin;

alter table public.media_assets
  add column catalog_kind text not null default 'legacy-happens',
  add column form_id uuid references public.forms(id) on delete restrict,
  add column source_form_asset_id uuid references public.form_assets(id) on delete restrict,
  add column owner_internal_identity_id uuid references app_private.superadmin_internal_identities(id) on delete restrict,
  add column media_purpose text,
  add column pixel_width integer,
  add column pixel_height integer,
  alter column post_id drop not null,
  alter column owner_person_id drop not null,
  alter column byte_size drop not null,
  add constraint media_assets_catalog_shape_ck check ((
    (catalog_kind = 'legacy-happens'
      and post_id is not null and owner_person_id is not null and byte_size is not null
      and form_id is null and source_form_asset_id is null
      and owner_internal_identity_id is null and media_purpose is null
      and pixel_width is null and pixel_height is null)
    or
    (catalog_kind = 'form-image'
      and post_id is null and form_id is not null
      and storage_provider = 'r2' and bucket_id = 'coelo-media-prod'
      and original_name = '' and media_purpose is not null
      and mime_type in ('image/jpeg','image/png','image/webp')
      and (byte_size is null or byte_size between 1 and 4194304)
      and (
        (media_purpose = 'question-image' and source_form_asset_id is null
          and num_nonnulls(owner_person_id,owner_internal_identity_id) = 1)
        or (media_purpose = 'answer-image' and source_form_asset_id is not null
          and owner_internal_identity_id is null)
      )
      and (checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$')
      and num_nonnulls(pixel_width,pixel_height) in (0,2)
      and ((pixel_width is null and pixel_height is null)
        or (pixel_width between 1 and 2560 and pixel_height between 1 and 2560))
      and (status <> 'ready' or (checksum_sha256 is not null
        and pixel_width is not null and pixel_height is not null
        and byte_size is not null))
      and (status <> 'pending' or (byte_size is null and checksum_sha256 is null
        and pixel_width is null and pixel_height is null))
    )
  ) is true);

create index media_assets_form_fk_idx on public.media_assets(form_id) where form_id is not null;
create unique index media_assets_form_source_uidx on public.media_assets(source_form_asset_id)
  where source_form_asset_id is not null;
create index media_assets_internal_owner_fk_idx on public.media_assets(owner_internal_identity_id)
  where owner_internal_identity_id is not null;

-- Verified Coelo renditions only. Raw uploads remain processing inputs;
-- a metadata declaration or a HEAD response must never create a rendition.
create table public.media_variants (
  id uuid primary key default gen_random_uuid(),
  media_asset_id uuid not null references public.media_assets(id) on delete restrict,
  rendition text not null check (rendition in ('original','preview')),
  bucket_id text not null check (bucket_id = 'coelo-media-prod'),
  object_key text not null unique,
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/webp')),
  byte_size bigint not null check (byte_size between 1 and 4194304),
  checksum_sha256 text not null check (checksum_sha256 ~ '^[0-9a-f]{64}$'),
  pixel_width integer not null check (pixel_width between 1 and 2560),
  pixel_height integer not null check (pixel_height between 1 and 2560),
  created_at timestamptz not null default now(),
  unique(media_asset_id,rendition)
);

-- Typed references deliberately avoid an unchecked (entity_type, entity_id).
-- No respondent, participation, auth user or anonymous secret is duplicated.
create table public.media_bindings (
  id uuid primary key default gen_random_uuid(),
  media_asset_id uuid not null references public.media_assets(id) on delete restrict,
  form_version_id uuid not null references public.form_versions(id) on delete restrict,
  item_id uuid not null references public.form_items(id) on delete restrict,
  purpose text not null check (purpose in ('question-image','answer-image')),
  position integer not null check (position >= 0),
  created_at timestamptz not null default now(),
  unique(media_asset_id,item_id,purpose)
);
create index media_bindings_version_fk_idx on public.media_bindings(form_version_id);
create index media_bindings_item_fk_idx on public.media_bindings(item_id);

alter table public.media_variants enable row level security;
alter table public.media_variants force row level security;
alter table public.media_bindings enable row level security;
alter table public.media_bindings force row level security;
revoke all on public.media_variants,public.media_bindings from public,anon,authenticated,service_role;

create function app_private.private_media_catalog_key_v1(
  p_asset public.media_assets,p_rendition text,p_key text,p_mime text
) returns boolean language sql immutable security invoker set search_path = '' as $$
  select p_key ~ (
    '^tenants/' || p_asset.institution_id::text || '/forms/form/' || p_asset.form_id::text
    || '/' || p_asset.media_purpose || '/' || p_asset.id::text || '/' || p_rendition
    || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    || case p_mime when 'image/jpeg' then '[.]jpg$' when 'image/png' then '[.]png$'
      when 'image/webp' then '[.]webp$' else '$a' end
  );
$$;

create function app_private.private_media_catalog_asset_guard_v1()
returns trigger language plpgsql security definer set search_path = '' as $$
declare target public.forms; source public.form_assets;
begin
  if tg_op = 'UPDATE' and new.catalog_kind is distinct from old.catalog_kind then
    raise check_violation using message = 'media_catalog_origin_immutable';
  end if;
  if new.catalog_kind = 'legacy-happens' then return new; end if;
  if tg_op = 'UPDATE' and (
    row(new.id,new.institution_id,new.form_id,new.source_form_asset_id,
      new.owner_person_id,new.owner_internal_identity_id,new.media_purpose,new.object_key,new.bucket_id)
    is distinct from
    row(old.id,old.institution_id,old.form_id,old.source_form_asset_id,
      old.owner_person_id,old.owner_internal_identity_id,old.media_purpose,old.object_key,old.bucket_id)
    or (old.status <> 'pending' and row(new.mime_type,new.byte_size,new.checksum_sha256,new.pixel_width,new.pixel_height)
      is distinct from row(old.mime_type,old.byte_size,old.checksum_sha256,old.pixel_width,old.pixel_height))
    or (old.status = 'deleted' and new.status <> 'deleted')
    or (old.status <> 'pending' and new.status = 'pending')
  ) then raise check_violation using message = 'media_catalog_identity_immutable'; end if;
  select * into target from public.forms where id = new.form_id for share;
  if target.id is null or target.institution_id is distinct from new.institution_id
    or app_private.private_media_catalog_key_v1(new,'original',new.object_key,new.mime_type) is not true
  then raise check_violation using message = 'media_catalog_scope_invalid'; end if;
  if new.media_purpose = 'answer-image' then
    select * into source from public.form_assets where id = new.source_form_asset_id for share;
    if source.id is null or source.institution_id is distinct from new.institution_id
      or source.prepared_by_person_id is distinct from new.owner_person_id
      or ((source.prepared_by_person_id is null) <> (target.identity_mode = 'anonymous'))
      or (new.status = 'ready' and source.state <> 'finalized')
      or not exists (select 1 from public.form_occurrences occurrence
        where occurrence.id = source.occurrence_id and occurrence.form_id = target.id
          and occurrence.institution_id = new.institution_id)
    then raise check_violation using message = 'media_catalog_response_owner_invalid'; end if;
  elsif new.media_purpose = 'question-image' and
    ((target.created_by_internal_identity_id is null) <> (new.owner_internal_identity_id is null)) then
    raise check_violation using message = 'media_catalog_author_realm_invalid';
  end if;
  return new;
end;
$$;
create trigger private_media_catalog_asset_guard_v1
  before insert or update on public.media_assets for each row
  execute function app_private.private_media_catalog_asset_guard_v1();

create function app_private.private_media_catalog_child_guard_v1()
returns trigger language plpgsql security definer set search_path = '' as $$
declare asset public.media_assets;
begin
  if tg_op = 'UPDATE' then
    raise check_violation using message = 'media_catalog_child_immutable';
  end if;
  if tg_op = 'DELETE' then
    update public.media_assets set id = id where id = old.media_asset_id;
    return old;
  end if;
  -- A real row version serializes sibling changes even under repeatable read;
  -- a read lock alone would allow stale snapshots to remove the last two uses.
  update public.media_assets set id = id where id = new.media_asset_id returning * into asset;
  if asset.id is null or asset.catalog_kind <> 'form-image' or asset.status = 'deleted' then
    raise check_violation using message = 'media_catalog_asset_invalid';
  end if;
  if tg_table_name = 'media_variants' then
    if app_private.private_media_catalog_key_v1(asset,new.rendition,new.object_key,new.mime_type) is not true then
      raise check_violation using message = 'media_catalog_variant_key_invalid';
    end if;
  else
    if new.purpose is distinct from asset.media_purpose or not exists (
      select 1 from public.form_items item join public.form_versions version on version.id = item.form_version_id
      where item.id = new.item_id and item.form_version_id = new.form_version_id and version.form_id = asset.form_id
    ) then raise check_violation using message = 'media_catalog_binding_scope_invalid'; end if;
    if new.purpose = 'answer-image' and (new.position > 4 or not exists (
      select 1 from public.form_assets source
      join public.form_occurrences occurrence on occurrence.id = source.occurrence_id
      join public.form_items item on item.id = source.item_id
      where source.id = asset.source_form_asset_id and source.item_id = new.item_id
        and occurrence.form_version_id = new.form_version_id and item.kind in ('photo','gallery')
    )) then raise check_violation using message = 'media_catalog_answer_binding_invalid'; end if;
  end if;
  return new;
end;
$$;
create trigger private_media_catalog_variant_guard_v1
  before insert or update or delete on public.media_variants for each row
  execute function app_private.private_media_catalog_child_guard_v1();
create trigger private_media_catalog_binding_guard_v1
  before insert or update or delete on public.media_bindings for each row
  execute function app_private.private_media_catalog_child_guard_v1();

-- A pending asset needs an authoritative binding; a ready asset also needs a
-- verified original whose metadata exactly matches its catalog entry.
create function app_private.private_media_catalog_complete_v1()
returns trigger language plpgsql security definer set search_path = '' as $$
declare asset_id uuid; asset public.media_assets;
begin
  if tg_table_name = 'media_assets' then asset_id := new.id;
  elsif tg_op = 'DELETE' then asset_id := old.media_asset_id;
  else asset_id := new.media_asset_id; end if;
  select * into asset from public.media_assets where id = asset_id;
  if asset.id is null or asset.catalog_kind <> 'form-image' or asset.status = 'deleted' then return null; end if;
  if not exists(select 1 from public.media_bindings where media_asset_id = asset.id) then
    raise check_violation using message = 'media_catalog_binding_required';
  end if;
  if asset.status = 'ready' and not exists(
    select 1 from public.media_variants variant where variant.media_asset_id = asset.id and variant.rendition = 'original'
      and row(variant.bucket_id,variant.object_key,variant.mime_type,variant.byte_size,
        variant.checksum_sha256,variant.pixel_width,variant.pixel_height)
      = row(asset.bucket_id,asset.object_key,asset.mime_type,asset.byte_size,
        asset.checksum_sha256,asset.pixel_width,asset.pixel_height)
  ) then raise check_violation using message = 'media_catalog_original_required'; end if;
  return null;
end;
$$;
create constraint trigger private_media_catalog_complete_v1
  after insert or update on public.media_assets deferrable initially deferred
  for each row execute function app_private.private_media_catalog_complete_v1();
create constraint trigger private_media_catalog_complete_v1
  after insert or update or delete on public.media_bindings deferrable initially deferred
  for each row execute function app_private.private_media_catalog_complete_v1();
create constraint trigger private_media_catalog_complete_v1
  after insert or update or delete on public.media_variants deferrable initially deferred
  for each row execute function app_private.private_media_catalog_complete_v1();

revoke all on function app_private.private_media_catalog_key_v1(public.media_assets,text,text,text),
  app_private.private_media_catalog_asset_guard_v1(),app_private.private_media_catalog_child_guard_v1(),
  app_private.private_media_catalog_complete_v1() from public,anon,authenticated,service_role;

comment on table public.media_bindings is 'ADR0032 typed Forms image usages; no authorization derives from an R2 key. No client or worker grants in this foundation.';
comment on column public.media_assets.source_form_asset_id is 'Existing response upload ownership, including anonymous secret verification, stays in form_assets; never duplicate identity/correlation in the physical catalog.';
commit;
