-- Momentos consumer feed and author withdrawal (frente L01, rodada E2 R02).
--
-- Forward-only complement to 20260821112822_moments_publication_mvp.sql.
-- Adds:
--   1. public.list_visible_moments  -- authorized consumer feed projection.
--   2. public.withdraw_moment       -- soft, author-only withdrawal.
--
-- Invariants preserved from ADR 0032: metadata and authorization live in
-- Postgres, operational media stays in private Cloudflare R2. The feed never
-- projects bucket_id, object_key or any credential; the client only receives
-- the module's own opaque asset identifier, which is redeemed through the
-- moments-media Edge Function (action "read") exactly like the authoring flow.
--
-- Withdrawal is a soft state transition. It never deletes rows, never deletes
-- media and never changes retention. Audit and idempotency follow the same
-- receipt discipline used by public.publish_moment.

alter table public.moments_publications
  add column withdrawn_at timestamptz,
  add column withdrawn_by_person_id uuid references public.people(id),
  add column withdrawal_reason text check (
    withdrawal_reason is null or char_length(withdrawal_reason) <= 280
  );

alter table public.moments_publications
  add constraint moments_publications_withdrawal_requires_published_check
  check (withdrawn_at is null or status = 'published');

create index moments_publications_withdrawn_by_fk_idx
  on public.moments_publications (withdrawn_by_person_id)
  where withdrawn_by_person_id is not null;

create index moments_publications_visible_feed_idx
  on public.moments_publications (institution_id, published_at desc, id)
  where status = 'published' and withdrawn_at is null;

insert into public.institution_permissions (
  code, module_code, screen_code, action_code, description, status,
  module_label, screen_label, action_label
)
values
  (
    'moments.publications.remove', 'moments', 'publications', 'remove',
    'Retirar do feed Momentos publicados de própria autoria no contexto autorizado.',
    'active', 'Momentos', 'Publicações', 'Remover'
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

-- Audience compatibility for the Momentos consumer feed. Mirrors the Acontece
-- helper so both feeds resolve the same contextual role semantics.
create or replace function app_private.moments_audience_matches_role(
  p_role_code text,
  p_audience public.moments_audience_kind
)
returns boolean
language sql
immutable
set search_path = ''
as $$
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
  text, public.moments_audience_kind
) from public, anon, authenticated, service_role;

-- Authorized consumer feed. Server-side authorization only: the caller's ids
-- are routing hints, never permission. Withdrawn and draft publications are
-- excluded. Media carries the module's opaque asset id, never storage details.
create or replace function public.list_visible_moments(
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid,
  p_limit integer default 20,
  p_cursor timestamptz default null
)
returns table (
  publication_id uuid,
  author_name text,
  author_initials text,
  context_label text,
  caption text,
  published_at timestamptz,
  can_withdraw boolean,
  media jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor record;
  actor_role text;
begin
  select * into actor from app_private.moments_actor(
    p_institution_id, 'moments.publications.read', p_unit_id, p_group_id
  );
  select lower(membership.role_code) into actor_role
  from public.institution_memberships membership
  where membership.id = actor.membership_id;

  return query
  select
    publication.id,
    person.display_name,
    upper(left(person.display_name, 1)),
    coalesce(scoped_group.name, scoped_unit.name, institution.public_name),
    publication.caption,
    publication.published_at,
    publication.author_person_id = actor.person_id,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'asset_id', asset.id,
            'mime_type', asset.mime_type,
            'display_order', link.display_order,
            'duration_milliseconds', asset.duration_milliseconds
          )
          order by link.display_order
        )
        from public.moments_media_links link
        join public.moments_media_assets asset on asset.id = link.media_asset_id
        where link.publication_id = publication.id and asset.status = 'ready'
      ),
      '[]'::jsonb
    )
  from public.moments_publications publication
  join public.people person on person.id = publication.author_person_id
  join public.institutions institution on institution.id = publication.institution_id
  left join public.units scoped_unit on scoped_unit.id = publication.unit_id
  left join public.groups scoped_group on scoped_group.id = publication.group_id
  where publication.institution_id = p_institution_id
    and publication.status = 'published'
    and publication.withdrawn_at is null
    and publication.published_at is not null
    and (publication.unit_id is null or publication.unit_id = p_unit_id)
    and (publication.group_id is null or publication.group_id = p_group_id)
    and (p_cursor is null or publication.published_at < p_cursor)
    and exists (
      select 1
      from public.moments_publication_audiences audience
      where audience.publication_id = publication.id
        and audience.institution_id = p_institution_id
        and audience.unit_id is not distinct from publication.unit_id
        and audience.group_id is not distinct from publication.group_id
        and app_private.moments_audience_matches_role(actor_role, audience.audience_kind)
    )
  order by publication.published_at desc, publication.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50);
end
$$;

-- Media read authorization now serves two authorized paths: the author while
-- authoring, and an audience-compatible consumer of a live published moment.
-- Withdrawn moments stop serving media to consumers immediately.
create or replace function public.authorize_moments_media_read(p_asset_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  asset public.moments_media_assets%rowtype;
  target public.moments_publications%rowtype;
  actor record;
  actor_role text;
  is_author boolean := false;
  is_consumer boolean := false;
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;
  select * into asset from public.moments_media_assets media
  where media.id = p_asset_id and media.status = 'ready';
  if asset.id is null then
    raise insufficient_privilege using message = 'asset_not_authorized';
  end if;
  select * into target from public.moments_publications publication
  where publication.id = asset.publication_id;
  if target.id is null then
    raise insufficient_privilege using message = 'asset_not_authorized';
  end if;

  if app_private.has_institution_permission(
    asset.institution_id, 'moments.publications.create',
    target.unit_id, target.group_id, false
  ) then
    select * into actor from app_private.moments_actor(
      asset.institution_id, 'moments.publications.create',
      target.unit_id, target.group_id
    );
    is_author := target.author_person_id = actor.person_id;
  end if;

  if not is_author
    and target.status = 'published'
    and target.withdrawn_at is null
    and app_private.has_institution_permission(
      asset.institution_id, 'moments.publications.read',
      target.unit_id, target.group_id, false
    )
  then
    select * into actor from app_private.moments_actor(
      asset.institution_id, 'moments.publications.read',
      target.unit_id, target.group_id
    );
    select lower(membership.role_code) into actor_role
    from public.institution_memberships membership
    where membership.id = actor.membership_id;
    is_consumer := exists (
      select 1
      from public.moments_publication_audiences audience
      where audience.publication_id = target.id
        and audience.institution_id = target.institution_id
        and audience.unit_id is not distinct from target.unit_id
        and audience.group_id is not distinct from target.group_id
        and app_private.moments_audience_matches_role(actor_role, audience.audience_kind)
    );
  end if;

  if not (is_author or is_consumer) then
    raise insufficient_privilege using message = 'asset_not_authorized';
  end if;

  return jsonb_build_object(
    'asset_id', asset.id,
    'object_key', asset.object_key,
    'mime_type', asset.mime_type
  );
end
$$;

-- Soft, author-only withdrawal of a published moment.
--
-- p_expected_version is optional: when supplied it is enforced as an optimistic
-- lock and a mismatch raises serialization_failure ('expected_version_conflict').
-- Consumer surfaces that legitimately never received the management version
-- (the feed projection does not expose it) may pass null; authorship, tenant,
-- scope and permission are still enforced server-side.
create or replace function public.withdraw_moment(
  p_request_id uuid,
  p_publication_id uuid,
  p_expected_version bigint,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor record;
  target public.moments_publications%rowtype;
  reason text := nullif(btrim(coalesce(p_reason, '')), '');
  fingerprint text;
  prior record;
  receipt_id uuid := gen_random_uuid();
  result jsonb;
begin
  select * into target from public.moments_publications publication
  where publication.id = p_publication_id for update;
  if target.id is null then
    raise insufficient_privilege using message = 'publication_not_authorized';
  end if;
  select * into actor from app_private.moments_actor(
    target.institution_id, 'moments.publications.remove', target.unit_id, target.group_id
  );
  if target.author_person_id <> actor.person_id then
    raise insufficient_privilege using message = 'publication_not_authorized';
  end if;
  if reason is not null and char_length(reason) > 280 then
    raise check_violation using message = 'withdrawal_reason_too_long';
  end if;

  fingerprint := app_private.moments_request_fingerprint(jsonb_build_object(
    'publication_id', p_publication_id,
    'expected_version', p_expected_version,
    'reason', reason
  ));
  perform pg_advisory_xact_lock(
    hashtextextended(actor.person_id::text || p_request_id::text, 0)
  );
  select receipt.request_fingerprint, receipt.response into prior
  from app_private.moments_command_receipts receipt
  where receipt.actor_person_id = actor.person_id
    and receipt.command_name = 'withdraw'
    and receipt.request_id = p_request_id;
  if prior.response is not null then
    if prior.request_fingerprint <> fingerprint then
      raise unique_violation using message = 'idempotency_key_reused';
    end if;
    return prior.response;
  end if;

  -- Already withdrawn: idempotent echo of the current state, no new audit row.
  if target.withdrawn_at is not null then
    return jsonb_build_object(
      'id', target.id,
      'status', target.status,
      'withdrawn_at', target.withdrawn_at,
      'version', target.management_version
    );
  end if;

  if target.status <> 'published' then
    raise check_violation using message = 'publication_not_published';
  end if;
  if p_expected_version is not null
    and target.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version_conflict';
  end if;

  update public.moments_publications publication set
    withdrawn_at = now(),
    withdrawn_by_person_id = actor.person_id,
    withdrawal_reason = reason,
    management_version = publication.management_version + 1,
    updated_at = now()
  where publication.id = target.id
  returning * into target;

  result := jsonb_build_object(
    'id', target.id,
    'status', target.status,
    'withdrawn_at', target.withdrawn_at,
    'version', target.management_version,
    'receipt_id', receipt_id
  );
  insert into app_private.moments_command_receipts (
    id, actor_person_id, institution_id, command_name,
    request_id, request_fingerprint, response
  ) values (
    receipt_id, actor.person_id, target.institution_id, 'withdraw',
    p_request_id, fingerprint, result
  );
  insert into app_private.moments_publication_audit (
    publication_id, institution_id, actor_person_id, receipt_id, event_code, detail
  ) values (
    target.id, target.institution_id, actor.person_id, receipt_id,
    'publication_withdrawn',
    jsonb_build_object(
      'request_id', p_request_id,
      'reason', reason,
      'version', target.management_version
    )
  );
  return result;
end
$$;

revoke all on function public.list_visible_moments(uuid, uuid, uuid, integer, timestamptz),
  public.withdraw_moment(uuid, uuid, bigint, text)
from public, anon, authenticated, service_role;

grant execute on function public.list_visible_moments(uuid, uuid, uuid, integer, timestamptz),
  public.withdraw_moment(uuid, uuid, bigint, text)
to authenticated;
