-- R08 G5, lote 58 candidato. Forward-only; aplicacao exclusiva do C0.
--
-- Defeito medido em producao: o mesmo autor interno Owner publicou e leu um
-- Momento, mas withdraw_moment retornou 403. A permissao remove foi criada
-- depois do seed do institution_admin e nunca foi concedida a esse papel.
-- O feed ainda calculava can_withdraw apenas por autoria, divergindo do RPC.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'moments withdrawal permission must run as postgres';
  end if;
  if to_regprocedure('public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)') is null
     or to_regprocedure('public.withdraw_moment(uuid,uuid,bigint,text)') is null then
    raise object_not_in_prerequisite_state using message = 'moments feed and withdrawal baseline is required';
  end if;
  if (select count(*) from public.institution_roles
      where institution_id is null and code = 'institution_admin'
        and is_system and status = 'active') <> 1 then
    raise object_not_in_prerequisite_state using message = 'exactly one active institution_admin system role is required';
  end if;
  if not exists (
    select 1 from public.institution_permissions
    where code = 'moments.publications.remove' and status = 'active'
  ) then
    raise object_not_in_prerequisite_state using message = 'active moments removal permission is required';
  end if;
end
$preflight$;

insert into public.institution_role_permissions (
  role_id, permission_id, effect, status
)
select role_record.id, permission_record.id, 'allow', 'active'
from public.institution_roles role_record
join public.institution_permissions permission_record
  on permission_record.code = 'moments.publications.remove'
 and permission_record.status = 'active'
where role_record.institution_id is null
  and role_record.code = 'institution_admin'
  and role_record.is_system
  and role_record.status = 'active'
on conflict (role_id, permission_id) do update set
  effect = 'allow',
  status = 'active',
  revoked_at = null;

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
    publication.author_person_id = actor.person_id
      and app_private.has_institution_permission(
        publication.institution_id,
        'moments.publications.remove',
        publication.unit_id,
        publication.group_id,
        false
      ),
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

revoke all on function public.list_visible_moments(uuid, uuid, uuid, integer, timestamptz)
from public, anon, authenticated, service_role;
grant execute on function public.list_visible_moments(uuid, uuid, uuid, integer, timestamptz)
to authenticated;

commit;
