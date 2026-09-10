-- Classifica a audiência do Agora por vínculos e capabilities, nunca por role_code livre.
create or replace function app_private.now_viewer_role_class(
  p_person_id uuid,
  p_membership_id uuid,
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid
)
returns text
language sql
stable
security definer
set search_path=''
as $$
  with student_context as (
    select 1
    from public.child_contexts child_context
    left join public.child_unit_links unit_link
      on unit_link.child_context_id=child_context.id
     and unit_link.status='active'
     and unit_link.revoked_at is null
    left join public.child_group_links group_link
      on group_link.child_unit_link_id=unit_link.id
     and group_link.status='active'
     and (group_link.starts_at is null or group_link.starts_at<=now())
     and (group_link.ends_at is null or group_link.ends_at>now())
    where child_context.child_person_id=p_person_id
      and child_context.institution_id=p_institution_id
      and child_context.status='active'
      and child_context.archived_at is null
      and (p_unit_id is null or unit_link.unit_id=p_unit_id)
      and (p_group_id is null or group_link.group_id=p_group_id)
    limit 1
  ),
  guardian_context as (
    select 1
    from public.guardian_links guardian
    join public.child_contexts child_context
      on child_context.child_person_id=guardian.child_person_id
     and child_context.institution_id=p_institution_id
     and child_context.status='active'
     and child_context.archived_at is null
    join public.guardian_context_permissions guardian_permission
      on guardian_permission.guardian_link_id=guardian.id
     and guardian_permission.child_context_id=child_context.id
     and guardian_permission.can_view
     and guardian_permission.status='active'
     and (guardian_permission.starts_at is null or guardian_permission.starts_at<=now())
     and (guardian_permission.expires_at is null or guardian_permission.expires_at>now())
    left join public.child_unit_links unit_link
      on unit_link.child_context_id=child_context.id
     and unit_link.status='active'
     and unit_link.revoked_at is null
    left join public.child_group_links group_link
      on group_link.child_unit_link_id=unit_link.id
     and group_link.status='active'
     and (group_link.starts_at is null or group_link.starts_at<=now())
     and (group_link.ends_at is null or group_link.ends_at>now())
    where guardian.guardian_person_id=p_person_id
      and guardian.status='active'
      and guardian.revoked_at is null
      and (p_unit_id is null or unit_link.unit_id=p_unit_id)
      and (p_group_id is null or group_link.group_id=p_group_id)
    limit 1
  ),
  active_membership as (
    select membership.id
    from public.institution_memberships membership
    where membership.id=p_membership_id
      and membership.person_id=p_person_id
      and membership.institution_id=p_institution_id
      and membership.status='active'
      and membership.revoked_at is null
  ),
  staff_effects as (
    select role_permission.effect
    from active_membership membership
    join public.institution_role_assignments assignment
      on assignment.membership_id=membership.id
     and assignment.status='active'
     and (assignment.starts_at is null or assignment.starts_at<=now())
     and (assignment.expires_at is null or assignment.expires_at>now())
    join public.institution_roles role_record
      on role_record.id=assignment.role_id
     and role_record.status='active'
     and (role_record.institution_id is null or role_record.institution_id=p_institution_id)
    join public.institution_role_permissions role_permission
      on role_permission.role_id=role_record.id
     and role_permission.status='active'
     and role_permission.revoked_at is null
    join public.institution_permissions permission_record
      on permission_record.id=role_permission.permission_id
     and permission_record.code='now.publications.read'
     and permission_record.status='active'
    where assignment.scope_kind='institution'
       or (assignment.scope_kind='unit' and assignment.scope_unit_id=p_unit_id)
       or (
         assignment.scope_kind='group'
         and assignment.scope_group_id=p_group_id
         and (p_unit_id is null or assignment.scope_unit_id=p_unit_id)
       )
  )
  select case
    when exists(select 1 from student_context) then 'student'
    when exists(select 1 from guardian_context) then 'guardian'
    when exists(select 1 from active_membership)
      and exists(select 1 from staff_effects where effect='allow')
      and not exists(select 1 from staff_effects where effect='deny')
      then 'school_staff'
    else null
  end
$$;

revoke all on function app_private.now_viewer_role_class(uuid,uuid,uuid,uuid,uuid)
  from public,anon,authenticated;

create or replace function app_private.now_audience_matches_role(
  p_role_code text,
  p_audience public.now_audience_kind
)
returns boolean language sql immutable set search_path='' as $$
  select case lower(coalesce(p_role_code,''))
    when 'guardian' then p_audience in ('families','guardians_only')
    when 'student' then p_audience='students'
    when 'school_staff' then p_audience='school_staff'
    else false
  end
$$;

revoke all on function app_private.now_audience_matches_role(text,public.now_audience_kind)
  from public,anon,authenticated;

create or replace function public.list_visible_now_publications(
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid,
  p_limit integer default 20
)
returns table(
  publication_id uuid,
  author_name text,
  author_initials text,
  context_label text,
  caption text,
  overlay_text text,
  crop_scale numeric,
  crop_x numeric,
  crop_y numeric,
  cover_position numeric,
  published_at timestamptz,
  expires_at timestamptz,
  media jsonb
) language plpgsql security definer set search_path='' as $$
declare
  actor record;
  actor_role text;
  visible_publication record;
  visible_asset record;
  media_items jsonb;
  read_ticket uuid;
begin
  select * into actor
  from app_private.now_actor(
    p_institution_id,
    'now.publications.read',
    p_unit_id,
    p_group_id
  );
  actor_role:=app_private.now_viewer_role_class(
    actor.person_id,actor.membership_id,p_institution_id,p_unit_id,p_group_id
  );
  if actor_role is null then
    raise insufficient_privilege using message='viewer_context_not_authorized';
  end if;

  delete from app_private.now_media_read_tickets ticket
  where ticket.expires_at<=now();

  for visible_publication in
    select
      publication.id,
      person.display_name,
      coalesce(scoped_group.name,scoped_unit.name,institution.public_name) as resolved_context,
      publication.caption,
      publication.overlay_text,
      publication.crop_scale,
      publication.crop_x,
      publication.crop_y,
      publication.cover_position,
      coalesce(publication.published_at,publication.publish_at) as resolved_published_at,
      publication.expires_at
    from public.now_publications publication
    join public.people person on person.id=publication.author_person_id
    join public.institutions institution on institution.id=publication.institution_id
    left join public.units scoped_unit on scoped_unit.id=publication.unit_id
    left join public.groups scoped_group on scoped_group.id=publication.group_id
    where publication.institution_id=p_institution_id
      and publication.status in('scheduled','published')
      and publication.publish_at<=now()
      and publication.expires_at>now()
      and (publication.unit_id is null or publication.unit_id=p_unit_id)
      and (publication.group_id is null or publication.group_id=p_group_id)
      and exists(
        select 1
        from public.now_publication_audiences audience
        where audience.publication_id=publication.id
          and audience.institution_id=p_institution_id
          and audience.unit_id is not distinct from publication.unit_id
          and audience.group_id is not distinct from publication.group_id
          and app_private.now_audience_matches_role(actor_role,audience.audience_kind)
      )
    order by publication.publish_at desc,publication.id
    limit least(greatest(coalesce(p_limit,20),1),50)
  loop
    media_items:='[]'::jsonb;
    for visible_asset in
      select asset.id,asset.kind,asset.mime_type
      from public.now_media_assets asset
      where asset.publication_id=visible_publication.id
        and asset.institution_id=p_institution_id
        and asset.status='ready'
      order by asset.kind
    loop
      insert into app_private.now_media_read_tickets(media_asset_id,viewer_person_id)
      values(visible_asset.id,actor.person_id)
      returning token into read_ticket;
      media_items:=media_items||jsonb_build_array(jsonb_build_object(
        'read_ticket',read_ticket,
        'kind',visible_asset.kind,
        'mime_type',visible_asset.mime_type
      ));
    end loop;

    publication_id:=visible_publication.id;
    author_name:=visible_publication.display_name;
    author_initials:=upper(left(visible_publication.display_name,1));
    context_label:=visible_publication.resolved_context;
    caption:=visible_publication.caption;
    overlay_text:=visible_publication.overlay_text;
    crop_scale:=visible_publication.crop_scale;
    crop_x:=visible_publication.crop_x;
    crop_y:=visible_publication.crop_y;
    cover_position:=visible_publication.cover_position;
    published_at:=visible_publication.resolved_published_at;
    expires_at:=visible_publication.expires_at;
    media:=media_items;
    return next;
  end loop;
end
$$;

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
  returning asset.bucket_id,asset.object_key,asset.mime_type into redeemed;
  if redeemed.object_key is null then
    raise insufficient_privilege using message='media_read_ticket_invalid';
  end if;
  return jsonb_build_object(
    'bucket_id',redeemed.bucket_id,
    'object_key',redeemed.object_key,
    'mime_type',redeemed.mime_type
  );
end $$;

revoke all on function public.list_visible_now_publications(uuid,uuid,uuid,integer)
  from public,anon,authenticated;
grant execute on function public.list_visible_now_publications(uuid,uuid,uuid,integer)
  to authenticated;
revoke all on function public.redeem_now_media_read_ticket(uuid,uuid)
  from public,anon,authenticated;
grant execute on function public.redeem_now_media_read_ticket(uuid,uuid)
  to service_role;
