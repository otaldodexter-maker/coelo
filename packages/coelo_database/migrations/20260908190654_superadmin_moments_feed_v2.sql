-- Candidate migration, reserved locally by R01-C05-I007. Not applied remotely.
--
-- Momentos has draft, save, publish and media RPCs but no authorised read, so
-- `momentos.view` has no server contract at all. This adds one, mirroring the
-- Acontece feed instead of inventing a second shape:
--
--   * the actor is resolved from the session by realm, tenant, membership and
--     capability; the UI filter never authorises anything;
--   * a publication is visible only when it is published, its scope matches and
--     an audience row matches the actor's role through an active membership;
--   * expired publications are excluded by the query, not by the client;
--   * media comes back as opaque, viewer-bound, short-lived descriptors. The R2
--     URL is only ever produced by the gateway after re-authorising the ticket,
--     so no object key or signed URL crosses this boundary;
--   * the keyset cursor is (published_at, id), matching the projection order.

begin;

-- Same role-to-audience rule the Acontece feed already uses, kept as its own
-- function so the two domains cannot drift apart silently.
create or replace function app_private.moments_audience_matches_role(
  p_role_code text,
  p_audience public.moments_audience_kind
) returns boolean language sql immutable set search_path = '' as $$
  select case
    when lower(coalesce(p_role_code, '')) in
      ('guardian', 'responsible', 'responsavel', 'parent', 'family')
      then p_audience in ('families', 'guardians_only')
    when lower(coalesce(p_role_code, '')) in ('student', 'aluno')
      then p_audience = 'students'
    else p_audience = 'school_staff'
  end
$$;
revoke all on function app_private.moments_audience_matches_role(
  text, public.moments_audience_kind) from public, anon, authenticated;

-- Viewer-bound, single-use, short-lived. The token addresses nothing by itself:
-- redeeming it re-checks the viewer and the asset.
create table if not exists app_private.moments_media_read_tickets(
  token uuid primary key default gen_random_uuid(),
  media_asset_id uuid not null references public.moments_media_assets(id) on delete cascade,
  viewer_person_id uuid not null references public.people(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '2 minutes'),
  created_at timestamptz not null default now()
);
create index if not exists moments_media_read_tickets_expiry_idx
  on app_private.moments_media_read_tickets(expires_at);
revoke all on app_private.moments_media_read_tickets from public, anon, authenticated;

create or replace function public.list_visible_moments(
  p_institution_id uuid,
  p_unit_id uuid default null,
  p_group_id uuid default null,
  p_cursor_published_at timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 20
) returns table(
  moment_id uuid,
  author_name text,
  author_initials text,
  context_label text,
  caption text,
  published_at timestamptz,
  media jsonb
) language plpgsql security definer set search_path = '' as $$
declare
  actor record;
  actor_role text;
  visible_moment record;
  visible_media record;
  media_items jsonb;
  read_ticket uuid;
begin
  if (p_cursor_published_at is null) <> (p_cursor_id is null) then
    raise invalid_parameter_value using message = 'moments_invalid_cursor';
  end if;

  -- Capability first. A caller without moments.publications.read never reaches
  -- the rows, whatever the UI asked for.
  select * into actor from app_private.moments_actor(
    p_institution_id, 'moments.publications.read', p_unit_id, p_group_id);
  select lower(membership.role_code) into actor_role
  from public.institution_memberships membership
  where membership.id = actor.membership_id;

  delete from app_private.moments_media_read_tickets ticket
  where ticket.expires_at <= now();

  for visible_moment in
    select
      publication.id,
      person.display_name,
      coalesce(scoped_group.name, scoped_unit.name, institution.public_name) as resolved_context,
      publication.caption,
      publication.published_at as resolved_published_at
    from public.moments_publications publication
    join public.people person on person.id = publication.author_person_id
    join public.institutions institution on institution.id = publication.institution_id
    left join public.units scoped_unit on scoped_unit.id = publication.unit_id
    left join public.groups scoped_group on scoped_group.id = publication.group_id
    where publication.institution_id = p_institution_id
      and publication.status = 'published'
      and publication.published_at is not null
      and publication.published_at <= now()
      and (publication.unit_id is null or publication.unit_id = p_unit_id)
      and (publication.group_id is null or publication.group_id = p_group_id)
      and (p_cursor_published_at is null
        or (publication.published_at, publication.id) < (p_cursor_published_at, p_cursor_id))
      and exists(
        select 1
        from public.moments_publication_audiences audience
        where audience.publication_id = publication.id
          and audience.institution_id = p_institution_id
          and audience.unit_id is not distinct from publication.unit_id
          and audience.group_id is not distinct from publication.group_id
          and app_private.moments_audience_matches_role(actor_role, audience.audience_kind)
      )
    order by publication.published_at desc, publication.id desc
    limit least(greatest(coalesce(p_limit, 20), 1), 50)
  loop
    media_items := '[]'::jsonb;
    for visible_media in
      select asset.id, asset.mime_type, asset.duration_milliseconds, link.display_order
      from public.moments_media_links link
      join public.moments_media_assets asset on asset.id = link.media_asset_id
      where link.publication_id = visible_moment.id and asset.status = 'ready'
      order by link.display_order
    loop
      insert into app_private.moments_media_read_tickets(media_asset_id, viewer_person_id)
      values(visible_media.id, actor.person_id)
      returning token into read_ticket;
      -- Descriptor only: no bucket, no object key, no URL.
      media_items := media_items || jsonb_build_array(jsonb_build_object(
        'read_ticket', read_ticket,
        'mime_type', visible_media.mime_type,
        'duration_milliseconds', visible_media.duration_milliseconds,
        'display_order', visible_media.display_order
      ));
    end loop;

    moment_id := visible_moment.id;
    author_name := visible_moment.display_name;
    author_initials := upper(left(visible_moment.display_name, 1));
    context_label := visible_moment.resolved_context;
    caption := visible_moment.caption;
    published_at := visible_moment.resolved_published_at;
    media := media_items;
    return next;
  end loop;
end
$$;

-- Redeeming consumes the ticket and re-checks the viewer. It returns the object
-- key to the gateway only; the gateway is what signs, and it re-authorises again.
create or replace function public.redeem_moments_media_read_ticket(
  p_ticket uuid,
  p_viewer_auth_user_id uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  redeemed record;
begin
  delete from app_private.moments_media_read_tickets ticket
  using public.person_auth_links auth_link, public.moments_media_assets asset
  where ticket.token = p_ticket
    and ticket.expires_at > now()
    and auth_link.person_id = ticket.viewer_person_id
    and auth_link.auth_user_id = p_viewer_auth_user_id
    and auth_link.status = 'active'
    and asset.id = ticket.media_asset_id
    and asset.status = 'ready'
  returning asset.id, asset.bucket_id, asset.object_key, asset.mime_type into redeemed;
  if redeemed.id is null then
    raise insufficient_privilege using message = 'moments_media_not_authorized';
  end if;
  return jsonb_build_object(
    'asset_id', redeemed.id,
    'bucket_id', redeemed.bucket_id,
    'object_key', redeemed.object_key,
    'mime_type', redeemed.mime_type
  );
end
$$;

insert into public.institution_permissions(code, name, description, status)
values(
  'moments.publications.read',
  'Ler Momentos publicados',
  'Permite ler os Momentos publicados no escopo autorizado.',
  'active')
on conflict(code) do update set status = 'active';

do $acl$
declare function_record regprocedure;
begin
  for function_record in
    select procedure_record.oid::regprocedure
    from pg_proc procedure_record
    join pg_namespace namespace_record on namespace_record.oid = procedure_record.pronamespace
    where procedure_record.proname in (
      'list_visible_moments', 'redeem_moments_media_read_ticket', 'moments_audience_matches_role')
      and namespace_record.nspname in ('public', 'app_private')
  loop
    execute format('alter function %s owner to postgres', function_record);
    execute format('revoke all on function %s from public, anon, authenticated, service_role',
      function_record);
  end loop;
end
$acl$;

grant execute on function public.list_visible_moments(
  uuid, uuid, uuid, timestamptz, uuid, integer) to authenticated;
-- Redeeming belongs to the gateway, never to the browser: the same split the
-- Acontece ticket already uses.
grant execute on function public.redeem_moments_media_read_ticket(uuid, uuid) to service_role;

commit;
