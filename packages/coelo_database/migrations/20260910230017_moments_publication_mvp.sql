-- Productive Momentos publication boundary.
-- Metadata and authorization live in Supabase/Postgres; operational media is
-- stored only in private Cloudflare R2 according to ADR 0022.

create type public.moments_publication_status as enum ('draft', 'published');
create type public.moments_audience_kind as enum (
  'families',
  'students',
  'school_staff',
  'guardians_only'
);
create type public.moments_media_status as enum (
  'pending',
  'ready',
  'quarantined',
  'orphaned',
  'deleted'
);

create table public.moments_publications (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id),
  unit_id uuid references public.units(id),
  group_id uuid references public.groups(id),
  author_person_id uuid not null references public.people(id),
  author_membership_id uuid not null references public.institution_memberships(id),
  caption text not null default '' check (char_length(caption) <= 2200),
  status public.moments_publication_status not null default 'draft',
  management_version bigint not null default 1 check (management_version > 0),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (unit_id is not null or group_id is null),
  check ((status = 'draft' and published_at is null) or status = 'published')
);

create index moments_publications_author_draft_idx
  on public.moments_publications (author_person_id, updated_at desc)
  where status = 'draft';
create index moments_publications_author_fk_idx
  on public.moments_publications (author_person_id);
create index moments_publications_feed_idx
  on public.moments_publications (institution_id, published_at desc, id)
  where status = 'published';
create index moments_publications_unit_fk_idx
  on public.moments_publications (unit_id) where unit_id is not null;
create index moments_publications_group_fk_idx
  on public.moments_publications (group_id) where group_id is not null;
create index moments_publications_membership_fk_idx
  on public.moments_publications (author_membership_id);

create table public.moments_publication_audiences (
  publication_id uuid not null references public.moments_publications(id) on delete cascade,
  audience_kind public.moments_audience_kind not null,
  institution_id uuid not null references public.institutions(id),
  unit_id uuid references public.units(id),
  group_id uuid references public.groups(id),
  primary key (publication_id, audience_kind)
);

create index moments_publication_audiences_scope_idx
  on public.moments_publication_audiences (institution_id, unit_id, group_id);

create table public.moments_media_assets (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id),
  publication_id uuid not null references public.moments_publications(id) on delete cascade,
  owner_person_id uuid not null references public.people(id),
  upload_request_id uuid not null,
  storage_provider text not null default 'cloudflare_r2'
    check (storage_provider = 'cloudflare_r2'),
  bucket_id text not null default 'coelo-moments-private',
  object_key text not null unique,
  original_name text not null check (char_length(original_name) between 1 and 240),
  mime_type text not null
    check (mime_type in ('image/jpeg', 'image/png', 'image/webp', 'video/mp4')),
  byte_size bigint not null check (byte_size between 1 and 26214400),
  duration_milliseconds bigint check (
    duration_milliseconds is null or duration_milliseconds between 1 and 300000
  ),
  checksum_sha256 text check (
    checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$'
  ),
  etag text,
  status public.moments_media_status not null default 'pending',
  finalized_at timestamptz,
  cleanup_attempted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (publication_id, upload_request_id)
);

create index moments_media_assets_owner_idx
  on public.moments_media_assets (institution_id, owner_person_id, status);
create index moments_media_assets_owner_person_fk_idx
  on public.moments_media_assets (owner_person_id);
create index moments_media_assets_cleanup_idx
  on public.moments_media_assets (created_at, cleanup_attempted_at)
  where status in ('pending', 'orphaned');

create table public.moments_media_links (
  publication_id uuid not null references public.moments_publications(id) on delete cascade,
  media_asset_id uuid not null references public.moments_media_assets(id) on delete restrict,
  display_order smallint not null check (display_order between 0 and 4),
  primary key (publication_id, media_asset_id),
  unique (publication_id, display_order)
);

create index moments_media_links_asset_fk_idx
  on public.moments_media_links (media_asset_id);

create table app_private.moments_command_receipts (
  id uuid primary key default gen_random_uuid(),
  actor_person_id uuid not null references public.people(id),
  institution_id uuid not null references public.institutions(id),
  command_name text not null,
  request_id uuid not null,
  request_fingerprint text not null check (request_fingerprint ~ '^[0-9a-f]{64}$'),
  response jsonb not null,
  created_at timestamptz not null default now(),
  unique (actor_person_id, command_name, request_id)
);

create index moments_command_receipts_institution_idx
  on app_private.moments_command_receipts (institution_id, created_at desc);

create table app_private.moments_media_finalize_tickets (
  token_hash text primary key check (token_hash ~ '^[0-9a-f]{64}$'),
  asset_id uuid not null references public.moments_media_assets(id) on delete cascade,
  actor_person_id uuid not null references public.people(id),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index moments_media_finalize_tickets_expiry_idx
  on app_private.moments_media_finalize_tickets (expires_at);
create index moments_media_finalize_tickets_actor_fk_idx
  on app_private.moments_media_finalize_tickets (actor_person_id);
create unique index moments_media_finalize_tickets_active_actor_idx
  on app_private.moments_media_finalize_tickets (asset_id, actor_person_id);

create table app_private.moments_publication_audit (
  id bigint generated always as identity primary key,
  publication_id uuid,
  institution_id uuid not null,
  actor_person_id uuid not null,
  receipt_id uuid,
  event_code text not null,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index moments_publication_audit_target_idx
  on app_private.moments_publication_audit (publication_id, created_at desc);

alter table public.moments_publications enable row level security;
alter table public.moments_publications force row level security;
alter table public.moments_publication_audiences enable row level security;
alter table public.moments_publication_audiences force row level security;
alter table public.moments_media_assets enable row level security;
alter table public.moments_media_assets force row level security;
alter table public.moments_media_links enable row level security;
alter table public.moments_media_links force row level security;

revoke all on public.moments_publications,
  public.moments_publication_audiences,
  public.moments_media_assets,
  public.moments_media_links
from public, anon, authenticated, service_role;
revoke all on app_private.moments_command_receipts,
  app_private.moments_media_finalize_tickets,
  app_private.moments_publication_audit
from public, anon, authenticated, service_role;

insert into public.institution_permissions (
  code, module_code, screen_code, action_code, description, status,
  module_label, screen_label, action_label
)
values
  (
    'moments.publications.create', 'moments', 'publications', 'create',
    'Criar e manter rascunhos de Momentos no contexto autorizado.',
    'active', 'Momentos', 'Publicações', 'Criar'
  ),
  (
    'moments.publications.publish', 'moments', 'publications', 'publish',
    'Publicar Momentos no contexto autorizado.',
    'active', 'Momentos', 'Publicações', 'Publicar'
  ),
  (
    'moments.publications.read', 'moments', 'publications', 'read',
    'Ler Momentos disponíveis no contexto autorizado.',
    'active', 'Momentos', 'Publicações', 'Ler'
  )
on conflict (code) do update set
  module_code = excluded.module_code,
  screen_code = excluded.screen_code,
  action_code = excluded.action_code,
  description = excluded.description,
  status = 'active',
  module_label = excluded.module_label,
  screen_label = excluded.screen_label,
  action_label = excluded.action_label;

create or replace function app_private.moments_request_fingerprint(p_payload jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(
    extensions.digest(pg_catalog.convert_to(p_payload::text, 'UTF8'), 'sha256'),
    'hex'
  )
$$;

create or replace function app_private.moments_actor_for_auth_user(
  p_auth_user_id uuid,
  p_institution_id uuid,
  p_permission text,
  p_unit_id uuid,
  p_group_id uuid
)
returns table (person_id uuid, membership_id uuid)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_auth_user_id is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;
  if not app_private.has_institution_permission(
    p_institution_id, p_permission, p_unit_id, p_group_id, false
  ) then
    raise insufficient_privilege using message = 'moments_permission_denied';
  end if;
  return query
  select auth_link.person_id, membership.id
  from public.person_auth_links auth_link
  join public.institution_memberships membership
    on membership.person_id = auth_link.person_id
  where auth_link.auth_user_id = p_auth_user_id
    and auth_link.status = 'active'
    and membership.institution_id = p_institution_id
    and membership.status = 'active'
    and membership.revoked_at is null
  order by membership.created_at
  limit 1;
  if not found then
    raise insufficient_privilege using message = 'active_membership_required';
  end if;
end
$$;

create or replace function app_private.moments_actor(
  p_institution_id uuid,
  p_permission text,
  p_unit_id uuid,
  p_group_id uuid
)
returns table (person_id uuid, membership_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select * from app_private.moments_actor_for_auth_user(
    (select auth.uid()), p_institution_id, p_permission, p_unit_id, p_group_id
  )
$$;

create or replace function public.load_moments_draft(
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor record;
  target public.moments_publications%rowtype;
begin
  select * into actor from app_private.moments_actor(
    p_institution_id, 'moments.publications.create', p_unit_id, p_group_id
  );
  select * into target
  from public.moments_publications publication
  where publication.institution_id = p_institution_id
    and publication.author_person_id = actor.person_id
    and publication.status = 'draft'
    and publication.unit_id is not distinct from p_unit_id
    and publication.group_id is not distinct from p_group_id
  order by publication.updated_at desc
  limit 1;
  if target.id is null then return null; end if;
  return jsonb_build_object(
    'id', target.id,
    'caption', target.caption,
    'version', target.management_version,
    'audiences', (
      select coalesce(jsonb_agg(audience.audience_kind order by audience.audience_kind), '[]')
      from public.moments_publication_audiences audience
      where audience.publication_id = target.id
    ),
    'media', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'asset_id', asset.id,
            'name', asset.original_name,
            'mime_type', asset.mime_type,
            'duration_milliseconds', asset.duration_milliseconds,
            'display_order', link.display_order
          ) order by link.display_order
        ),
        '[]'
      )
      from public.moments_media_links link
      join public.moments_media_assets asset on asset.id = link.media_asset_id
      where link.publication_id = target.id and asset.status = 'ready'
    )
  );
end
$$;

create or replace function public.save_moments_draft(
  p_request_id uuid,
  p_draft jsonb,
  p_publication_id uuid,
  p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor record;
  target public.moments_publications%rowtype;
  institution uuid := (p_draft ->> 'institution_id')::uuid;
  unit uuid := nullif(p_draft ->> 'unit_id', '')::uuid;
  scoped_group uuid := nullif(p_draft ->> 'group_id', '')::uuid;
  audience text;
  fingerprint text;
  prior record;
  receipt_id uuid := gen_random_uuid();
  result jsonb;
begin
  if p_request_id is null then raise invalid_parameter_value using message = 'request_id_required'; end if;
  if unit is not null and not exists (
    select 1 from public.units scoped_unit
    where scoped_unit.id = unit and scoped_unit.institution_id = institution
  ) then raise insufficient_privilege using message = 'unit_scope_invalid'; end if;
  if scoped_group is not null and not exists (
    select 1 from public.groups target_group
    where target_group.id = scoped_group
      and target_group.institution_id = institution
      and target_group.unit_id = unit
  ) then raise insufficient_privilege using message = 'group_scope_invalid'; end if;

  select * into actor from app_private.moments_actor(
    institution, 'moments.publications.create', unit, scoped_group
  );
  fingerprint := app_private.moments_request_fingerprint(jsonb_build_object(
    'draft', p_draft,
    'publication_id', p_publication_id,
    'expected_version', p_expected_version
  ));
  perform pg_advisory_xact_lock(hashtextextended(actor.person_id::text || p_request_id::text, 0));
  select receipt.request_fingerprint, receipt.response into prior
  from app_private.moments_command_receipts receipt
  where receipt.actor_person_id = actor.person_id
    and receipt.command_name = 'save_draft'
    and receipt.request_id = p_request_id;
  if prior.response is not null then
    if prior.request_fingerprint <> fingerprint then
      raise unique_violation using message = 'idempotency_key_reused';
    end if;
    return prior.response;
  end if;
  if char_length(coalesce(p_draft ->> 'caption', '')) > 2200 then
    raise check_violation using message = 'caption_too_long';
  end if;

  if p_publication_id is null then
    insert into public.moments_publications (
      institution_id, unit_id, group_id, author_person_id,
      author_membership_id, caption
    ) values (
      institution, unit, scoped_group, actor.person_id,
      actor.membership_id, coalesce(p_draft ->> 'caption', '')
    ) returning * into target;
  else
    update public.moments_publications publication set
      caption = coalesce(p_draft ->> 'caption', ''),
      management_version = publication.management_version + 1,
      updated_at = now()
    where publication.id = p_publication_id
      and publication.institution_id = institution
      and publication.author_person_id = actor.person_id
      and publication.status = 'draft'
      and publication.management_version = p_expected_version
    returning * into target;
    if target.id is null then
      raise serialization_failure using message = 'expected_version_conflict';
    end if;
  end if;

  delete from public.moments_publication_audiences existing
  where existing.publication_id = target.id;
  for audience in
    select jsonb_array_elements_text(coalesce(p_draft -> 'audiences', '[]'))
  loop
    insert into public.moments_publication_audiences (
      publication_id, audience_kind, institution_id, unit_id, group_id
    ) values (
      target.id, audience::public.moments_audience_kind,
      institution, unit, scoped_group
    );
  end loop;

  result := jsonb_build_object(
    'id', target.id,
    'version', target.management_version,
    'receipt_id', receipt_id
  );
  insert into app_private.moments_command_receipts (
    id, actor_person_id, institution_id, command_name,
    request_id, request_fingerprint, response
  ) values (
    receipt_id, actor.person_id, institution, 'save_draft',
    p_request_id, fingerprint, result
  );
  insert into app_private.moments_publication_audit (
    publication_id, institution_id, actor_person_id, receipt_id, event_code, detail
  ) values (
    target.id, institution, actor.person_id, receipt_id, 'draft_saved',
    jsonb_build_object('version', target.management_version)
  );
  return result;
end
$$;

create or replace function public.prepare_moments_media_upload(
  p_request_id uuid,
  p_institution_id uuid,
  p_publication_id uuid,
  p_name text,
  p_mime_type text,
  p_byte_size bigint,
  p_duration_milliseconds bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor record;
  target public.moments_publications%rowtype;
  asset public.moments_media_assets%rowtype;
  asset_id uuid := gen_random_uuid();
  object_key text;
  fingerprint text;
  prior record;
  receipt_id uuid := gen_random_uuid();
  result jsonb;
begin
  select * into target from public.moments_publications publication
  where publication.id = p_publication_id
    and publication.institution_id = p_institution_id
    and publication.status = 'draft';
  if target.id is null then raise insufficient_privilege using message = 'publication_not_authorized'; end if;
  select * into actor from app_private.moments_actor(
    p_institution_id, 'moments.publications.create', target.unit_id, target.group_id
  );
  if target.author_person_id <> actor.person_id then
    raise insufficient_privilege using message = 'publication_not_authorized';
  end if;
  if p_mime_type not in ('image/jpeg', 'image/png', 'image/webp', 'video/mp4') then
    raise check_violation using message = 'unsupported_media_type';
  end if;
  if p_byte_size < 1 or p_byte_size > 26214400 then
    raise check_violation using message = 'media_size_invalid';
  end if;
  if p_mime_type = 'video/mp4' and (
    p_duration_milliseconds is null or p_duration_milliseconds not between 1 and 300000
  ) then raise check_violation using message = 'video_duration_invalid'; end if;
  if p_mime_type <> 'video/mp4' and p_duration_milliseconds is not null then
    raise check_violation using message = 'image_duration_invalid';
  end if;

  fingerprint := app_private.moments_request_fingerprint(jsonb_build_object(
    'institution_id', p_institution_id,
    'publication_id', p_publication_id,
    'name', p_name,
    'mime_type', p_mime_type,
    'byte_size', p_byte_size,
    'duration_milliseconds', p_duration_milliseconds
  ));
  perform pg_advisory_xact_lock(hashtextextended(actor.person_id::text || p_request_id::text, 0));
  select receipt.request_fingerprint, receipt.response into prior
  from app_private.moments_command_receipts receipt
  where receipt.actor_person_id = actor.person_id
    and receipt.command_name = 'prepare_media'
    and receipt.request_id = p_request_id;
  if prior.response is not null then
    if prior.request_fingerprint <> fingerprint then
      raise unique_violation using message = 'idempotency_key_reused';
    end if;
    return prior.response;
  end if;

  object_key := 'institution/' || p_institution_id::text ||
    '/moments/' || to_char(now() at time zone 'utc', 'YYYY/MM') ||
    '/' || asset_id::text || '/original';
  insert into public.moments_media_assets (
    id, institution_id, publication_id, owner_person_id, upload_request_id,
    object_key, original_name, mime_type, byte_size, duration_milliseconds
  ) values (
    asset_id, p_institution_id, p_publication_id, actor.person_id, p_request_id,
    object_key, left(p_name, 240), p_mime_type, p_byte_size, p_duration_milliseconds
  ) returning * into asset;

  result := jsonb_build_object(
    'asset_id', asset.id,
    'object_key', asset.object_key,
    'expected_byte_size', asset.byte_size,
    'expected_mime_type', asset.mime_type,
    'receipt_id', receipt_id
  );
  insert into app_private.moments_command_receipts (
    id, actor_person_id, institution_id, command_name,
    request_id, request_fingerprint, response
  ) values (
    receipt_id, actor.person_id, p_institution_id, 'prepare_media',
    p_request_id, fingerprint, result
  );
  insert into app_private.moments_publication_audit (
    publication_id, institution_id, actor_person_id, receipt_id, event_code, detail
  ) values (
    p_publication_id, p_institution_id, actor.person_id, receipt_id,
    'media_upload_requested', jsonb_build_object('asset_id', asset.id)
  );
  return result;
end
$$;

create or replace function public.authorize_moments_media_finalize(p_asset_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor record;
  asset public.moments_media_assets%rowtype;
  target public.moments_publications%rowtype;
  finalize_ticket uuid := gen_random_uuid();
  ticket_expires_at timestamptz := now() + interval '2 minutes';
begin
  select * into asset from public.moments_media_assets media
  where media.id = p_asset_id and media.status in ('pending', 'ready');
  if asset.id is null then
    raise insufficient_privilege using message = 'asset_not_authorized';
  end if;
  select * into target from public.moments_publications publication
  where publication.id = asset.publication_id and publication.status = 'draft';
  if target.id is null then
    raise insufficient_privilege using message = 'publication_not_authorized';
  end if;
  select * into actor from app_private.moments_actor(
    asset.institution_id, 'moments.publications.create', target.unit_id, target.group_id
  );
  if asset.owner_person_id <> actor.person_id or target.author_person_id <> actor.person_id then
    raise insufficient_privilege using message = 'asset_not_authorized';
  end if;

  delete from app_private.moments_media_finalize_tickets ticket
  where ticket.expires_at <= now();
  delete from app_private.moments_media_finalize_tickets ticket
  where ticket.asset_id = asset.id
    and ticket.actor_person_id = actor.person_id;
  insert into app_private.moments_media_finalize_tickets (
    token_hash, asset_id, actor_person_id, expires_at
  ) values (
    app_private.moments_request_fingerprint(to_jsonb(finalize_ticket::text)),
    asset.id,
    actor.person_id,
    ticket_expires_at
  );
  return jsonb_build_object(
    'finalize_ticket', finalize_ticket,
    'expires_at', ticket_expires_at
  );
end
$$;

create or replace function public.finalize_moments_media_upload(
  p_request_id uuid,
  p_asset_id uuid,
  p_finalize_ticket uuid,
  p_expected_byte_size bigint,
  p_expected_mime_type text,
  p_checksum_sha256 text,
  p_etag text,
  p_display_order bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  asset public.moments_media_assets%rowtype;
  target public.moments_publications%rowtype;
  consumed_ticket app_private.moments_media_finalize_tickets%rowtype;
  fingerprint text;
  prior record;
  receipt_id uuid := gen_random_uuid();
  result jsonb;
begin
  select * into asset from public.moments_media_assets media
  where media.id = p_asset_id for update;
  if asset.id is null then raise insufficient_privilege using message = 'asset_not_authorized'; end if;
  select * into target from public.moments_publications publication
  where publication.id = asset.publication_id and publication.status = 'draft';
  if target.id is null then raise insufficient_privilege using message = 'publication_not_authorized'; end if;
  if asset.owner_person_id <> target.author_person_id then
    raise insufficient_privilege using message = 'asset_not_authorized';
  end if;
  if p_expected_byte_size <> asset.byte_size or p_expected_mime_type <> asset.mime_type then
    raise check_violation using message = 'uploaded_media_mismatch';
  end if;
  if p_display_order not between 0 and 4 then
    raise check_violation using message = 'display_order_invalid';
  end if;

  fingerprint := app_private.moments_request_fingerprint(jsonb_build_object(
    'asset_id', p_asset_id,
    'expected_byte_size', p_expected_byte_size,
    'expected_mime_type', p_expected_mime_type,
    'checksum_sha256', p_checksum_sha256,
    'etag', p_etag,
    'display_order', p_display_order
  ));
  perform pg_advisory_xact_lock(
    hashtextextended(asset.owner_person_id::text || p_request_id::text, 0)
  );
  select receipt.request_fingerprint, receipt.response into prior
  from app_private.moments_command_receipts receipt
  where receipt.actor_person_id = asset.owner_person_id
    and receipt.command_name = 'finalize_media'
    and receipt.request_id = p_request_id;
  if prior.response is not null then
    if prior.request_fingerprint <> fingerprint then
      raise unique_violation using message = 'idempotency_key_reused';
    end if;
    return prior.response;
  end if;

  if asset.status <> 'pending' then
    raise object_not_in_prerequisite_state using message = 'asset_not_pending';
  end if;

  delete from app_private.moments_media_finalize_tickets ticket
  where ticket.token_hash = app_private.moments_request_fingerprint(
      to_jsonb(p_finalize_ticket::text)
    )
    and ticket.asset_id = asset.id
    and ticket.actor_person_id = asset.owner_person_id
    and ticket.expires_at > now()
  returning ticket.* into consumed_ticket;
  if consumed_ticket.asset_id is null then
    raise insufficient_privilege using message = 'finalize_ticket_invalid';
  end if;

  if asset.status = 'ready' then raise unique_violation using message = 'asset_already_finalized'; end if;
  if p_checksum_sha256 is not null and p_checksum_sha256 !~ '^[0-9a-f]{64}$' then
    raise check_violation using message = 'checksum_invalid';
  end if;
  update public.moments_media_assets replaced set
    status = 'orphaned',
    cleanup_attempted_at = null
  from public.moments_media_links existing_link
  where existing_link.publication_id = target.id
    and existing_link.display_order = p_display_order
    and existing_link.media_asset_id <> asset.id
    and replaced.id = existing_link.media_asset_id
    and replaced.status = 'ready';
  delete from public.moments_media_links link
  where link.publication_id = target.id and link.display_order = p_display_order;
  update public.moments_media_assets set
    checksum_sha256 = p_checksum_sha256,
    etag = nullif(p_etag, ''),
    status = 'ready',
    finalized_at = now()
  where id = asset.id;
  insert into public.moments_media_links (publication_id, media_asset_id, display_order)
  values (target.id, asset.id, p_display_order::smallint)
  on conflict (publication_id, media_asset_id) do update
    set display_order = excluded.display_order;

  result := jsonb_build_object(
    'asset_id', asset.id,
    'object_key', asset.object_key,
    'receipt_id', receipt_id
  );
  insert into app_private.moments_command_receipts (
    id, actor_person_id, institution_id, command_name,
    request_id, request_fingerprint, response
  ) values (
    receipt_id, asset.owner_person_id, asset.institution_id, 'finalize_media',
    p_request_id, fingerprint, result
  );
  insert into app_private.moments_publication_audit (
    publication_id, institution_id, actor_person_id, receipt_id, event_code, detail
  ) values (
    target.id, asset.institution_id, asset.owner_person_id, receipt_id,
    'media_upload_finalized', jsonb_build_object('asset_id', asset.id)
  );
  return result;
end
$$;

create or replace function public.authorize_moments_media_read(p_asset_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor record;
  asset public.moments_media_assets%rowtype;
  target public.moments_publications%rowtype;
begin
  select * into asset from public.moments_media_assets media
  where media.id = p_asset_id and media.status = 'ready';
  if asset.id is null then raise insufficient_privilege using message = 'asset_not_authorized'; end if;
  select * into target from public.moments_publications publication
  where publication.id = asset.publication_id;
  select * into actor from app_private.moments_actor(
    asset.institution_id, 'moments.publications.create', target.unit_id, target.group_id
  );
  if target.author_person_id <> actor.person_id then
    raise insufficient_privilege using message = 'asset_not_authorized';
  end if;
  return jsonb_build_object(
    'asset_id', asset.id,
    'object_key', asset.object_key,
    'mime_type', asset.mime_type
  );
end
$$;

create or replace function public.publish_moment(
  p_request_id uuid,
  p_publication_id uuid,
  p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor record;
  target public.moments_publications%rowtype;
  fingerprint text;
  prior record;
  receipt_id uuid := gen_random_uuid();
  result jsonb;
begin
  select * into target from public.moments_publications publication
  where publication.id = p_publication_id for update;
  if target.id is null then raise insufficient_privilege using message = 'publication_not_authorized'; end if;
  select * into actor from app_private.moments_actor(
    target.institution_id, 'moments.publications.publish', target.unit_id, target.group_id
  );
  fingerprint := app_private.moments_request_fingerprint(jsonb_build_object(
    'publication_id', p_publication_id,
    'expected_version', p_expected_version
  ));
  perform pg_advisory_xact_lock(hashtextextended(actor.person_id::text || p_request_id::text, 0));
  select receipt.request_fingerprint, receipt.response into prior
  from app_private.moments_command_receipts receipt
  where receipt.actor_person_id = actor.person_id
    and receipt.command_name = 'publish'
    and receipt.request_id = p_request_id;
  if prior.response is not null then
    if prior.request_fingerprint <> fingerprint then
      raise unique_violation using message = 'idempotency_key_reused';
    end if;
    return prior.response;
  end if;
  if target.author_person_id <> actor.person_id
    or target.status <> 'draft'
    or target.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version_conflict';
  end if;
  if not exists (
    select 1 from public.moments_publication_audiences audience
    where audience.publication_id = target.id
  ) then raise check_violation using message = 'audience_required'; end if;
  if not exists (
    select 1 from public.moments_media_links link
    join public.moments_media_assets asset on asset.id = link.media_asset_id
    where link.publication_id = target.id and asset.status = 'ready'
  ) then raise check_violation using message = 'media_required'; end if;

  update public.moments_publications publication set
    status = 'published',
    published_at = now(),
    management_version = publication.management_version + 1,
    updated_at = now()
  where publication.id = target.id
  returning * into target;
  result := jsonb_build_object(
    'publication_id', target.id,
    'status', target.status,
    'version', target.management_version,
    'published_at', target.published_at,
    'receipt_id', receipt_id
  );
  insert into app_private.moments_command_receipts (
    id, actor_person_id, institution_id, command_name,
    request_id, request_fingerprint, response
  ) values (
    receipt_id, actor.person_id, target.institution_id, 'publish',
    p_request_id, fingerprint, result
  );
  insert into app_private.moments_publication_audit (
    publication_id, institution_id, actor_person_id, receipt_id, event_code, detail
  ) values (
    target.id, target.institution_id, actor.person_id, receipt_id,
    'moment_published', jsonb_build_object('version', target.management_version)
  );
  return result;
end
$$;

create or replace function app_private.claim_stale_moments_media(p_limit integer default 50)
returns table (asset_id uuid, object_key text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with claimed as (
    select media.id
    from public.moments_media_assets media
    where media.status in ('pending', 'orphaned')
      and media.created_at < now() - interval '30 minutes'
      and (
        media.cleanup_attempted_at is null
        or media.cleanup_attempted_at < now() - interval '10 minutes'
      )
    order by media.created_at
    for update skip locked
    limit least(greatest(coalesce(p_limit, 50), 1), 200)
  )
  update public.moments_media_assets media set
    status = 'orphaned',
    cleanup_attempted_at = now()
  from claimed
  where media.id = claimed.id
  returning media.id, media.object_key;
end
$$;

create or replace function app_private.mark_moments_media_deleted(p_asset_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.moments_media_assets
  set status = 'deleted'
  where id = p_asset_id and status = 'orphaned'
$$;

create or replace function public.claim_stale_moments_media(p_limit integer default 50)
returns table (asset_id uuid, object_key text)
language sql
security definer
set search_path = ''
as $$
  select * from app_private.claim_stale_moments_media(p_limit)
$$;

create or replace function public.mark_moments_media_deleted(p_asset_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  select app_private.mark_moments_media_deleted(p_asset_id)
$$;

revoke all on function app_private.moments_request_fingerprint(jsonb),
  app_private.moments_actor_for_auth_user(uuid, uuid, text, uuid, uuid),
  app_private.moments_actor(uuid, text, uuid, uuid),
  app_private.claim_stale_moments_media(integer),
  app_private.mark_moments_media_deleted(uuid)
from public, anon, authenticated, service_role;

revoke all on function public.load_moments_draft(uuid, uuid, uuid),
  public.save_moments_draft(uuid, jsonb, uuid, bigint),
  public.prepare_moments_media_upload(uuid, uuid, uuid, text, text, bigint, bigint),
  public.authorize_moments_media_finalize(uuid),
  public.finalize_moments_media_upload(uuid, uuid, uuid, bigint, text, text, text, bigint),
  public.authorize_moments_media_read(uuid),
  public.publish_moment(uuid, uuid, bigint),
  public.claim_stale_moments_media(integer),
  public.mark_moments_media_deleted(uuid)
from public, anon, authenticated, service_role;

grant execute on function public.load_moments_draft(uuid, uuid, uuid),
  public.save_moments_draft(uuid, jsonb, uuid, bigint),
  public.prepare_moments_media_upload(uuid, uuid, uuid, text, text, bigint, bigint),
  public.authorize_moments_media_finalize(uuid),
  public.authorize_moments_media_read(uuid),
  public.publish_moment(uuid, uuid, bigint)
to authenticated;

grant execute on function public.finalize_moments_media_upload(
  uuid, uuid, uuid, bigint, text, text, text, bigint
)
to service_role;

grant execute on function public.claim_stale_moments_media(integer)
to service_role;

grant execute on function public.mark_moments_media_deleted(uuid)
to service_role;
