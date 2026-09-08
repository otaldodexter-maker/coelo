-- Candidate migration, reserved locally by R01-C05-I007. Not applied remotely.
--
-- Momentos has draft, save, publish and media RPCs but no authorised read, so
-- `momentos.view` has no server contract at all. This adds one, following the
-- hardened Agora contract in 20260821130000 rather than the older Acontece
-- shape, so the two feeds cannot drift apart on the parts that authorise:
--
--   * the actor is resolved from the session by realm, tenant, membership and
--     capability; the UI filter never authorises anything;
--   * the viewer class is derived from real links and capabilities, never from
--     the free-text `institution_memberships.role_code`. An unrecognised or
--     absent class is denied, never demoted to a privileged default;
--   * a publication is visible only when it is published, its scope matches and
--     an audience row matches the derived class through an active membership.
--     Momentos has no expiry column, so there is nothing to expire here: the
--     lifecycle gate is `status = 'published'` plus `published_at <= now()`;
--   * media comes back as opaque, viewer-bound, short-lived descriptors. The R2
--     URL is only ever produced by the gateway after re-authorising the ticket,
--     so no object key or signed URL crosses this boundary;
--   * a ticket is a deferred question, not a standing grant: redemption replays
--     the whole chain against current state and dies with the publication, the
--     membership, the audience row or the auth link;
--   * the keyset cursor is (published_at, id), matching the projection order.
--
-- Realm contract, stated instead of assumed. `app_private.moments_actor`
-- resolves identity through `public.person_auth_links`, which is the people
-- realm used by Principal. The internal Superadmin realm is a disjoint set of
-- auth users (`app_private.superadmin_internal_auth_links`, kept disjoint by
-- the realm guards in 20260901190927) and it has no `public.people` identity at
-- all. There is no Momentos entry in `public.platform_permissions`, so
-- `app_private.require_superadmin_internal_context` cannot be satisfied for
-- this read and no internal-realm Momentos contract exists yet. This function
-- therefore serves the people realm only and fails closed with
-- `moments_internal_realm_unsupported` for an internal session. Do not paper
-- over that by minting a `people` row for an internal identity: the contract
-- has to be designed and approved first.

begin;

-- Viewer classification by links and capabilities, never by free role_code.
-- Mirrors app_private.now_viewer_role_class so Momentos and Agora answer the
-- same question the same way. Returns null when nothing proves a class, and
-- null is a denial upstream.
create or replace function app_private.moments_viewer_role_class(
  p_person_id uuid,
  p_membership_id uuid,
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid
) returns text language sql stable security definer set search_path = '' as $$
  with student_context as (
    select 1
    from public.child_contexts child_context
    left join public.child_unit_links unit_link
      on unit_link.child_context_id = child_context.id
     and unit_link.status = 'active'
     and unit_link.revoked_at is null
    left join public.child_group_links group_link
      on group_link.child_unit_link_id = unit_link.id
     and group_link.status = 'active'
     and (group_link.starts_at is null or group_link.starts_at <= now())
     and (group_link.ends_at is null or group_link.ends_at > now())
    where child_context.child_person_id = p_person_id
      and child_context.institution_id = p_institution_id
      and child_context.status = 'active'
      and child_context.archived_at is null
      and (p_unit_id is null or unit_link.unit_id = p_unit_id)
      and (p_group_id is null or group_link.group_id = p_group_id)
    limit 1
  ),
  guardian_context as (
    select 1
    from public.guardian_links guardian
    join public.child_contexts child_context
      on child_context.child_person_id = guardian.child_person_id
     and child_context.institution_id = p_institution_id
     and child_context.status = 'active'
     and child_context.archived_at is null
    join public.guardian_context_permissions guardian_permission
      on guardian_permission.guardian_link_id = guardian.id
     and guardian_permission.child_context_id = child_context.id
     and guardian_permission.can_view
     and guardian_permission.status = 'active'
     and (guardian_permission.starts_at is null or guardian_permission.starts_at <= now())
     and (guardian_permission.expires_at is null or guardian_permission.expires_at > now())
    left join public.child_unit_links unit_link
      on unit_link.child_context_id = child_context.id
     and unit_link.status = 'active'
     and unit_link.revoked_at is null
    left join public.child_group_links group_link
      on group_link.child_unit_link_id = unit_link.id
     and group_link.status = 'active'
     and (group_link.starts_at is null or group_link.starts_at <= now())
     and (group_link.ends_at is null or group_link.ends_at > now())
    where guardian.guardian_person_id = p_person_id
      and guardian.status = 'active'
      and guardian.revoked_at is null
      and (p_unit_id is null or unit_link.unit_id = p_unit_id)
      and (p_group_id is null or group_link.group_id = p_group_id)
    limit 1
  ),
  active_membership as (
    select membership.id
    from public.institution_memberships membership
    where membership.id = p_membership_id
      and membership.person_id = p_person_id
      and membership.institution_id = p_institution_id
      and membership.status = 'active'
      and membership.revoked_at is null
  ),
  staff_effects as (
    select role_permission.effect
    from active_membership membership
    join public.institution_role_assignments assignment
      on assignment.membership_id = membership.id
     and assignment.status = 'active'
     and (assignment.starts_at is null or assignment.starts_at <= now())
     and (assignment.expires_at is null or assignment.expires_at > now())
    join public.institution_roles role_record
      on role_record.id = assignment.role_id
     and role_record.status = 'active'
     and (role_record.institution_id is null or role_record.institution_id = p_institution_id)
    join public.institution_role_permissions role_permission
      on role_permission.role_id = role_record.id
     and role_permission.status = 'active'
     and role_permission.revoked_at is null
    join public.institution_permissions permission_record
      on permission_record.id = role_permission.permission_id
     and permission_record.code = 'moments.publications.read'
     and permission_record.status = 'active'
    where assignment.scope_kind = 'institution'
       or (assignment.scope_kind = 'unit' and assignment.scope_unit_id = p_unit_id)
       or (
         assignment.scope_kind = 'group'
         and assignment.scope_group_id = p_group_id
         and (p_unit_id is null or assignment.scope_unit_id = p_unit_id)
       )
  )
  select case
    when exists(select 1 from student_context) then 'student'
    when exists(select 1 from guardian_context) then 'guardian'
    when exists(select 1 from active_membership)
      and exists(select 1 from staff_effects where effect = 'allow')
      and not exists(select 1 from staff_effects where effect = 'deny')
      then 'school_staff'
    else null
  end
$$;

-- Closed set. An unknown or null class matches nothing: there is deliberately
-- no `else` that resolves to 'school_staff' or to any other default, because a
-- viewer nobody could classify must not inherit staff reach over children.
create or replace function app_private.moments_audience_matches_role(
  p_role_code text,
  p_audience public.moments_audience_kind
) returns boolean language sql immutable set search_path = '' as $$
  select case lower(coalesce(p_role_code, ''))
    when 'guardian' then p_audience in ('families', 'guardians_only')
    when 'student' then p_audience = 'students'
    when 'school_staff' then p_audience = 'school_staff'
    else false
  end
$$;

-- Viewer-bound, single-use, short-lived. The token addresses nothing by itself:
-- redeeming it replays the whole authorisation chain.
create table if not exists app_private.moments_media_read_tickets(
  token uuid primary key default gen_random_uuid(),
  media_asset_id uuid not null references public.moments_media_assets(id) on delete cascade,
  viewer_person_id uuid not null references public.people(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '2 minutes'),
  created_at timestamptz not null default now()
);
create index if not exists moments_media_read_tickets_expiry_idx
  on app_private.moments_media_read_tickets(expires_at);
create index if not exists moments_media_read_tickets_viewer_fk_idx
  on app_private.moments_media_read_tickets(viewer_person_id);

-- Deny-by-default: RLS enabled and forced with no policy at all, plus no direct
-- grant to any client or service role. The two functions below reach the table
-- as SECURITY DEFINER owned by postgres, which carries BYPASSRLS, so FORCE does
-- not constrain the definer path. If that owner ever loses BYPASSRLS this store
-- needs an explicit owner policy before the feed can write tickets again.
alter table app_private.moments_media_read_tickets enable row level security;
alter table app_private.moments_media_read_tickets force row level security;
revoke all on app_private.moments_media_read_tickets
  from public, anon, authenticated, service_role;

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
  caller_auth_user_id uuid;
  actor record;
  actor_role text;
  visible_moment record;
  visible_media record;
  media_items jsonb;
  read_ticket uuid;
begin
  caller_auth_user_id := (select auth.uid());
  if caller_auth_user_id is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;

  -- Realm before anything else. See the header: the internal Superadmin realm
  -- has no people identity and no Momentos platform permission, so it has no
  -- read contract here yet and must fail closed by name instead of falling
  -- through the people-realm helper by accident.
  if exists(
    select 1
    from app_private.superadmin_internal_auth_links internal_link
    where internal_link.auth_user_id = caller_auth_user_id
  ) then
    raise insufficient_privilege using message = 'moments_internal_realm_unsupported';
  end if;

  -- Capability next. A caller without moments.publications.read never reaches
  -- the rows, whatever the UI asked for.
  select * into actor from app_private.moments_actor(
    p_institution_id, 'moments.publications.read', p_unit_id, p_group_id);

  actor_role := app_private.moments_viewer_role_class(
    actor.person_id, actor.membership_id, p_institution_id, p_unit_id, p_group_id);
  if actor_role is null then
    raise insufficient_privilege using message = 'viewer_context_not_authorized';
  end if;

  -- The parameter contract is checked only after the caller is authorised, so
  -- an unauthorised caller learns nothing from the shape of its own request.
  if (p_cursor_published_at is null) <> (p_cursor_id is null) then
    raise invalid_parameter_value using message = 'moments_invalid_cursor';
  end if;

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
      where link.publication_id = visible_moment.id
        and asset.publication_id = visible_moment.id
        and asset.institution_id = p_institution_id
        and asset.status = 'ready'
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

-- Redemption is a second authorisation, not a lookup. The ticket only says
-- which question to ask; every answer is recomputed against current state, so
-- removing the publication, revoking the membership, dropping the audience row,
-- deactivating the auth link, unlinking the asset or simply letting the clock
-- run all take the ticket down with them. It returns the object key to the
-- gateway only; the gateway is what signs, and it re-authorises again.
create or replace function public.redeem_moments_media_read_ticket(
  p_ticket uuid,
  p_viewer_auth_user_id uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  redeemed record;
begin
  if p_ticket is null or p_viewer_auth_user_id is null then
    raise insufficient_privilege using message = 'moments_media_not_authorized';
  end if;
  delete from app_private.moments_media_read_tickets ticket
  using public.person_auth_links auth_link,
        public.institution_memberships membership,
        public.moments_media_assets asset,
        public.moments_publications publication,
        public.moments_media_links link
  where ticket.token = p_ticket
    and ticket.expires_at > now()
    and auth_link.person_id = ticket.viewer_person_id
    and auth_link.auth_user_id = p_viewer_auth_user_id
    and auth_link.status = 'active'
    and not exists(
      select 1
      from app_private.superadmin_internal_auth_links internal_link
      where internal_link.auth_user_id = p_viewer_auth_user_id
    )
    and asset.id = ticket.media_asset_id
    and asset.status = 'ready'
    and publication.id = asset.publication_id
    and publication.institution_id = asset.institution_id
    and publication.status = 'published'
    and publication.published_at is not null
    and publication.published_at <= now()
    and link.publication_id = publication.id
    and link.media_asset_id = asset.id
    and membership.person_id = ticket.viewer_person_id
    and membership.institution_id = publication.institution_id
    and membership.status = 'active'
    and membership.revoked_at is null
    and app_private.moments_viewer_role_class(
      ticket.viewer_person_id,
      membership.id,
      publication.institution_id,
      publication.unit_id,
      publication.group_id
    ) is not null
    and exists(
      select 1
      from public.moments_publication_audiences audience
      where audience.publication_id = publication.id
        and audience.institution_id = publication.institution_id
        and audience.unit_id is not distinct from publication.unit_id
        and audience.group_id is not distinct from publication.group_id
        and app_private.moments_audience_matches_role(
          app_private.moments_viewer_role_class(
            ticket.viewer_person_id,
            membership.id,
            publication.institution_id,
            publication.unit_id,
            publication.group_id
          ),
          audience.audience_kind
        )
    )
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

-- `moments.publications.read` is already catalogued by the Momentos foundation
-- migration 20260821112822 with the real column contract
-- (code, module_code, screen_code, action_code, description, status plus the
-- labels added by 20260811215451). `public.institution_permissions` has no
-- `name` column at all. This migration reuses that permission and deliberately
-- inserts nothing: re-declaring it here would duplicate the catalogue entry and
-- risk rewriting its module, screen and action codes.

alter function app_private.moments_viewer_role_class(uuid, uuid, uuid, uuid, uuid)
  owner to postgres;
alter function app_private.moments_audience_matches_role(text, public.moments_audience_kind)
  owner to postgres;
alter function public.list_visible_moments(uuid, uuid, uuid, timestamptz, uuid, integer)
  owner to postgres;
alter function public.redeem_moments_media_read_ticket(uuid, uuid)
  owner to postgres;

revoke all on function app_private.moments_viewer_role_class(uuid, uuid, uuid, uuid, uuid),
  app_private.moments_audience_matches_role(text, public.moments_audience_kind)
from public, anon, authenticated, service_role;

revoke all on function public.list_visible_moments(
    uuid, uuid, uuid, timestamptz, uuid, integer),
  public.redeem_moments_media_read_ticket(uuid, uuid)
from public, anon, authenticated, service_role;

grant execute on function public.list_visible_moments(
  uuid, uuid, uuid, timestamptz, uuid, integer) to authenticated;
-- Redeeming belongs to the gateway, never to the browser: the same split the
-- Agora ticket already uses.
grant execute on function public.redeem_moments_media_read_ticket(uuid, uuid) to service_role;

commit;
