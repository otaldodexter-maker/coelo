-- Sessão MÍDIA-E2E-2 (20/09/2026) — leitores do responsável em Momentos, Acontece e Circulares
-- (mesma regra do Agora, spec 070: guardian_links ativo + child_contexts ativo + can_view vigente, via
-- app_private.now_viewer_role_class) e autor projetado nos feeds (author_person_id) para a foto do autor
-- (EntityImageView pelo leitor do Principal).
--
-- Antes: list_visible_moments / list_visible_happens_posts / list_visible_happens_feed / get_visible_circular /
-- list_visible_profile_circulars exigiam permissão institucional + membership (só equipe); o responsável
-- "puro" recebia 403. Agora: caminho de equipe idêntico ao de hoje; sem permissão institucional, o caminho de
-- família devolve (person_id, membership null, role 'guardian') e a audiência decide (families/guardians_only).
-- Escrita (publicar, retirar, responder) não muda. Leitura de mídia: authorize_moments_media_read ganha o
-- caminho de família; authorize_circular_media_read passa pelo leitor; tickets do Acontece já são por pessoa.
-- Assinaturas (argumentos) preservadas; list_visible_moments, list_visible_happens_posts e
-- list_visible_now_publications ganham a coluna author_person_id no fim (drop + create, grants refeitos).
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if to_regprocedure('app_private.now_viewer_role_class(uuid,uuid,uuid,uuid,uuid)') is null
    or to_regprocedure('app_private.now_reader_actor(uuid,text,uuid,uuid)') is null
    or to_regprocedure('app_private.circular_actor(uuid,text,uuid,uuid)') is null
    or to_regprocedure('app_private.circular_internal_capability(uuid,text)') is null
    or to_regprocedure('app_private.staff_access_assert(uuid,uuid,uuid,uuid)') is null
    or to_regprocedure('public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)') is null
    or to_regprocedure('public.list_visible_happens_posts(uuid,uuid,uuid,integer)') is null
    or to_regprocedure('public.list_visible_happens_feed(uuid,uuid,uuid,uuid,timestamptz,text,uuid,integer)') is null
    or to_regprocedure('public.list_visible_now_publications(uuid,uuid,uuid,integer)') is null
    or to_regprocedure('public.get_visible_circular(uuid,uuid)') is null
    or to_regprocedure('public.list_visible_profile_circulars(uuid,uuid,uuid,uuid,timestamptz,uuid,integer)') is null
    or to_regprocedure('public.authorize_moments_media_read(uuid)') is null
    or to_regprocedure('public.authorize_circular_media_read(uuid)') is null then
    raise object_not_in_prerequisite_state using message = 'feeds, now guardian reader (spec 070) and staff access (lote 84) are required';
  end if;
end
$preflight$;

-- 1. Leitor comum de família ---------------------------------------------------------------------------
-- Equipe: permissão institucional no contexto (has_institution_permission já ignora vínculo bloqueado) +
-- membership ativa. Família: classe 'guardian' do classificador do Agora. Sem os dois: motivo de bloqueio
-- (PT403 STAFF_ACCESS_DENIED) quando houver, senão a mensagem da família de funções.
create or replace function app_private.family_reader_actor(
  p_institution_id uuid, p_permission text, p_unit_id uuid, p_group_id uuid,
  p_person_id uuid, p_staff_allowed boolean, p_denied_message text
) returns table(person_id uuid, membership_id uuid, role_code text)
language plpgsql stable security definer set search_path = '' as $$
declare actor_membership record;
begin
  if p_person_id is null then
    raise insufficient_privilege using message = p_denied_message;
  end if;
  if p_staff_allowed then
    select membership.id, membership.role_code into actor_membership
    from public.institution_memberships membership
    where membership.person_id = p_person_id
      and membership.institution_id = p_institution_id
      and membership.status = 'active' and membership.revoked_at is null
    order by membership.created_at limit 1;
    if actor_membership.id is null then
      raise insufficient_privilege using message = 'active_membership_required';
    end if;
    person_id := p_person_id;
    membership_id := actor_membership.id;
    role_code := actor_membership.role_code;
    return next;
    return;
  end if;
  if app_private.now_viewer_role_class(p_person_id, null, p_institution_id, p_unit_id, p_group_id)
     is distinct from 'guardian' then
    -- equipe bloqueada e sem caminho de família: motivo em vez de 'sem permissão'
    perform app_private.staff_access_assert(p_institution_id, p_unit_id, p_group_id, p_person_id);
    raise insufficient_privilege using message = p_denied_message;
  end if;
  person_id := p_person_id;
  membership_id := null;
  role_code := 'guardian';
  return next;
end $$;
revoke all on function app_private.family_reader_actor(uuid,text,uuid,uuid,uuid,boolean,text) from public, anon, authenticated, service_role;

create or replace function app_private.moments_reader_actor(
  p_institution_id uuid, p_permission text, p_unit_id uuid, p_group_id uuid
) returns table(person_id uuid, membership_id uuid, role_code text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then raise insufficient_privilege using message = 'authentication_required'; end if;
  return query select * from app_private.family_reader_actor(
    p_institution_id, p_permission, p_unit_id, p_group_id,
    app_private.person_id_for_auth_user((select auth.uid())),
    app_private.has_institution_permission(p_institution_id, p_permission, p_unit_id, p_group_id, false),
    'moments_permission_denied');
end $$;
revoke all on function app_private.moments_reader_actor(uuid,text,uuid,uuid) from public, anon, authenticated, service_role;

create or replace function app_private.happens_reader_actor(
  p_institution_id uuid, p_permission text, p_unit_id uuid, p_group_id uuid
) returns table(person_id uuid, membership_id uuid, role_code text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then raise insufficient_privilege using message = 'authentication_required'; end if;
  return query select * from app_private.family_reader_actor(
    p_institution_id, p_permission, p_unit_id, p_group_id,
    app_private.person_id_for_auth_user((select auth.uid())),
    app_private.has_institution_permission(p_institution_id, p_permission, p_unit_id, p_group_id, false),
    'happens_permission_denied');
end $$;
revoke all on function app_private.happens_reader_actor(uuid,text,uuid,uuid) from public, anon, authenticated, service_role;

-- Circulares: caminho de equipe soma o realm interno (circular_internal_capability) e usa a ponte de ator
-- (current_person_id), como em circular_actor.
create or replace function app_private.circular_reader_actor(
  p_institution_id uuid, p_permission text, p_unit_id uuid, p_group_id uuid
) returns table(person_id uuid, membership_id uuid, role_code text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then raise insufficient_privilege using message = 'authentication_required'; end if;
  return query select * from app_private.family_reader_actor(
    p_institution_id, p_permission, p_unit_id, p_group_id,
    app_private.current_person_id(),
    app_private.has_institution_permission(p_institution_id, p_permission, p_unit_id, p_group_id, false)
      or app_private.circular_internal_capability(p_institution_id, p_permission),
    'circular_permission_denied');
end $$;
revoke all on function app_private.circular_reader_actor(uuid,text,uuid,uuid) from public, anon, authenticated, service_role;

-- 2. Momentos ------------------------------------------------------------------------------------------
drop function if exists public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz);
create function public.list_visible_moments(
  p_institution_id uuid, p_unit_id uuid, p_group_id uuid, p_limit integer default 20, p_cursor timestamptz default null
) returns table(
  publication_id uuid, author_name text, author_initials text, context_label text, caption text,
  published_at timestamptz, can_withdraw boolean, media jsonb, author_person_id uuid
) language plpgsql stable security definer set search_path = '' as $$
declare
  actor record;
  actor_role text;
begin
  select * into actor from app_private.moments_reader_actor(
    p_institution_id, 'moments.publications.read', p_unit_id, p_group_id
  );
  actor_role := lower(actor.role_code);

  return query
  select
    publication.id,
    person.display_name,
    upper(left(person.display_name, 1)),
    coalesce(scoped_group.name, scoped_unit.name, institution.public_name),
    publication.caption,
    publication.published_at,
    publication.author_person_id = actor.person_id
      and actor.membership_id is not null
      and app_private.has_institution_permission(
        publication.institution_id, 'moments.publications.remove', publication.unit_id, publication.group_id, false
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
    ),
    publication.author_person_id
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
revoke all on function public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz) from public, anon;
grant execute on function public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz) to authenticated;

create or replace function public.authorize_moments_media_read(p_asset_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  asset public.moments_media_assets%rowtype;
  target public.moments_publications%rowtype;
  actor record;
  is_author boolean := false;
  is_consumer boolean := false;
  reader_resolved boolean := false;
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
    asset.institution_id, 'moments.publications.create', target.unit_id, target.group_id, false
  ) then
    select * into actor from app_private.moments_actor(
      asset.institution_id, 'moments.publications.create', target.unit_id, target.group_id
    );
    is_author := target.author_person_id = actor.person_id;
  end if;
  if not is_author and target.status = 'published' and target.withdrawn_at is null then
    -- Leitor: equipe (permissão + membership) ou responsável por vínculo; a audiência decide.
    begin
      select * into actor from app_private.moments_reader_actor(
        asset.institution_id, 'moments.publications.read', target.unit_id, target.group_id
      );
      reader_resolved := true;
    exception when insufficient_privilege then
      reader_resolved := false;
    end;
    if reader_resolved then
      is_consumer := exists (
        select 1
        from public.moments_publication_audiences audience
        where audience.publication_id = target.id
          and audience.institution_id = target.institution_id
          and audience.unit_id is not distinct from target.unit_id
          and audience.group_id is not distinct from target.group_id
          and app_private.moments_audience_matches_role(lower(actor.role_code), audience.audience_kind)
      );
    end if;
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

-- 3. Acontece ------------------------------------------------------------------------------------------
drop function if exists public.list_visible_happens_posts(uuid,uuid,uuid,integer);
create function public.list_visible_happens_posts(
  p_institution_id uuid, p_unit_id uuid, p_group_id uuid, p_limit integer default 20
) returns table(
  post_id uuid, author_name text, author_initials text, context_label text, caption text,
  published_at timestamptz, management_version bigint, can_withdraw boolean, media jsonb, author_person_id uuid
) language plpgsql security definer set search_path = '' as $$
declare
  actor record;
  actor_role text;
  visible_post record;
  visible_media record;
  media_items jsonb;
  read_ticket uuid;
begin
  select * into actor from app_private.happens_reader_actor(p_institution_id,'happens.posts.read',p_unit_id,p_group_id);
  actor_role := lower(actor.role_code);

  delete from app_private.happens_media_read_tickets ticket
  where ticket.expires_at<=now();

  for visible_post in
    select
      post.id,
      post.author_person_id as resolved_author,
      post.management_version as resolved_version,
      person.display_name,
      coalesce(scoped_group.name,scoped_unit.name,institution.public_name) as resolved_context,
      post.caption,
      coalesce(post.published_at,post.publish_at) as resolved_published_at
    from public.posts post
    join public.people person on person.id=post.author_person_id
    join public.institutions institution on institution.id=post.institution_id
    left join public.units scoped_unit on scoped_unit.id=post.unit_id
    left join public.groups scoped_group on scoped_group.id=post.group_id
    where post.institution_id=p_institution_id
      and post.status in('scheduled','published')
      and post.withdrawn_at is null
      and post.publish_at<=now()
      and (post.unit_id is null or post.unit_id=p_unit_id)
      and (post.group_id is null or post.group_id=p_group_id)
      and exists(
        select 1
        from public.post_audiences audience
        where audience.post_id=post.id
          and audience.institution_id=p_institution_id
          and audience.unit_id is not distinct from post.unit_id
          and audience.group_id is not distinct from post.group_id
          and app_private.happens_audience_matches_role(actor_role,audience.audience_kind)
      )
    order by post.publish_at desc,post.id
    limit least(greatest(coalesce(p_limit,20),1),50)
  loop
    media_items:='[]'::jsonb;
    for visible_media in
      select asset.id,asset.mime_type,link.display_order
      from public.media_links link
      join public.media_assets asset on asset.id=link.media_asset_id
      where link.post_id=visible_post.id and asset.status='ready'
      order by link.display_order
    loop
      insert into app_private.happens_media_read_tickets(media_asset_id,viewer_person_id)
      values(visible_media.id,actor.person_id)
      returning token into read_ticket;
      media_items:=media_items||jsonb_build_array(jsonb_build_object(
        'read_ticket',read_ticket,
        'mime_type',visible_media.mime_type,
        'display_order',visible_media.display_order
      ));
    end loop;

    post_id:=visible_post.id;
    author_name:=visible_post.display_name;
    author_initials:=upper(left(visible_post.display_name,1));
    context_label:=visible_post.resolved_context;
    caption:=visible_post.caption;
    published_at:=visible_post.resolved_published_at;
    management_version:=visible_post.resolved_version;
    can_withdraw:=visible_post.resolved_author=actor.person_id
      and actor.membership_id is not null
      and app_private.has_institution_permission(
        p_institution_id,'happens.posts.remove',p_unit_id,p_group_id,false);
    media:=media_items;
    author_person_id:=visible_post.resolved_author;
    return next;
  end loop;
end
$$;
revoke all on function public.list_visible_happens_posts(uuid,uuid,uuid,integer) from public, anon;
grant execute on function public.list_visible_happens_posts(uuid,uuid,uuid,integer) to authenticated, service_role;

create or replace function public.list_visible_happens_feed(
  p_institution_id uuid, p_unit_id uuid, p_group_id uuid, p_activity_id uuid,
  p_before_at timestamptz, p_before_type text, p_before_id uuid, p_limit integer default 20
) returns table(item_type text, item_id uuid, effective_published_at timestamptz, payload jsonb)
language plpgsql security definer set search_path = '' as $$
declare actor record; actor_role text; actor_is_staff boolean;
begin
  select * into actor from app_private.happens_reader_actor(p_institution_id,'happens.posts.read',p_unit_id,p_group_id);
  actor_role:=lower(actor.role_code);
  actor_is_staff:=actor.membership_id is not null;
  delete from app_private.happens_media_read_tickets ticket where ticket.expires_at<=now();
  return query
  with authorized_items as (
    select 'post'::text as kind,post.id,coalesce(post.published_at,post.publish_at) as at,
      jsonb_build_object('author_name',person.display_name,'author_initials',upper(left(person.display_name,1)),'author_person_id',post.author_person_id,'context_label',coalesce(g.name,u.name,i.public_name),'caption',post.caption,'management_version',post.management_version,'can_withdraw',actor_is_staff and post.author_person_id=actor.person_id and app_private.has_institution_permission(p_institution_id,'happens.posts.remove',p_unit_id,p_group_id,false),'media',app_private.circular_feed_post_media(post.id,actor.person_id)) as body
    from public.posts post join public.people person on person.id=post.author_person_id join public.institutions i on i.id=post.institution_id
    left join public.units u on u.id=post.unit_id left join public.groups g on g.id=post.group_id
    where post.institution_id=p_institution_id
      and post.withdrawn_at is null
      and app_private.circular_feed_post_visible(post,actor.person_id,actor_role,p_unit_id,p_group_id)
    union all
    select 'circular',c.id,c.publish_at,jsonb_build_object('author_name',person.display_name,'author_initials',upper(left(person.display_name,1)),'author_person_id',c.author_person_id,'context_label',coalesce(g.name,u.name,i.public_name),
      'title',r.title,'excerpt',left(r.body_text,420),'revised_at',c.revised_at,'attachment_count',(select count(*) from public.circular_media_links ml where ml.revision_id=r.id),
      'question_count',(select count(*) from public.circular_questions q where q.revision_id=r.id),'response_state',case when exists(select 1 from public.circular_response_sessions s where s.revision_id=r.id and s.last_actor_person_id=actor.person_id and s.status='submitted') then 'answered' when exists(select 1 from public.circular_response_sessions s where s.revision_id=r.id and s.last_actor_person_id=actor.person_id) then 'partial' else 'unanswered' end)
    from public.circulars c join public.circular_revisions r on r.id=c.current_revision_id join public.people person on person.id=c.author_person_id join public.institutions i on i.id=c.institution_id
    left join public.units u on u.id=c.unit_id left join public.groups g on g.id=c.group_id
    where c.institution_id=p_institution_id
      -- equipe precisa da permissão de circulares no escopo; família passa pela audiência (circular_visible)
      and (not actor_is_staff or app_private.has_institution_permission(c.institution_id,'circulars.circulars.read',c.unit_id,c.group_id,false))
      and app_private.circular_visible(c,actor.person_id,actor_role,p_unit_id,p_group_id,p_activity_id)
  )
  select source.kind,source.id,source.at,source.body from authorized_items source
  where p_before_at is null or (source.at,source.kind,source.id)<(p_before_at,coalesce(p_before_type,'zz'),p_before_id)
  order by source.at desc,source.kind desc,source.id desc limit least(greatest(coalesce(p_limit,20),1),50);
end $$;

-- 4. Agora: autor projetado (leitor já era o de família) --------------------------------------------------
drop function if exists public.list_visible_now_publications(uuid,uuid,uuid,integer);
create function public.list_visible_now_publications(
  p_institution_id uuid, p_unit_id uuid, p_group_id uuid, p_limit integer default 20
) returns table(
  publication_id uuid, author_name text, author_initials text, context_label text, caption text, overlay_text text,
  crop_scale numeric, crop_x numeric, crop_y numeric, cover_position numeric, published_at timestamptz,
  expires_at timestamptz, media jsonb, management_version bigint, can_remove boolean, author_person_id uuid
) language plpgsql security definer set search_path = '' as $$
declare
  actor record;
  actor_role text;
  actor_can_remove boolean;
  visible_publication record;
  visible_asset record;
  media_items jsonb;
  read_ticket uuid;
begin
  -- Leitor: equipe com now.publications.read + membership, ou responsavel por vinculo (spec 070).
  select * into actor
  from app_private.now_reader_actor(p_institution_id,'now.publications.read',p_unit_id,p_group_id);
  actor_role:=app_private.now_viewer_role_class(
    actor.person_id,actor.membership_id,p_institution_id,p_unit_id,p_group_id
  );
  if actor_role is null then
    raise insufficient_privilege using message='viewer_context_not_authorized';
  end if;
  actor_can_remove:=coalesce(app_private.has_institution_permission(
    p_institution_id,'now.publications.remove',p_unit_id,p_group_id,false
  ),false);
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
      publication.expires_at,
      publication.management_version,
      publication.author_person_id as resolved_author
    from public.now_publications publication
    join public.people person on person.id=publication.author_person_id
    join public.institutions institution on institution.id=publication.institution_id
    left join public.units scoped_unit on scoped_unit.id=publication.unit_id
    left join public.groups scoped_group on scoped_group.id=publication.group_id
    where publication.institution_id=p_institution_id
      and publication.status in('scheduled','published')
      and publication.publish_at<=now()
      and publication.expires_at>now()
      and publication.status<>'expired'
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
    management_version:=visible_publication.management_version;
    can_remove:=actor_can_remove;
    author_person_id:=visible_publication.resolved_author;
    return next;
  end loop;
end
$$;
revoke all on function public.list_visible_now_publications(uuid,uuid,uuid,integer) from public, anon;
grant execute on function public.list_visible_now_publications(uuid,uuid,uuid,integer) to authenticated, service_role;

-- 5. Circulares ------------------------------------------------------------------------------------------
create or replace function public.get_visible_circular(p_circular_id uuid, p_child_context_id uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare target public.circulars%rowtype; revision public.circular_revisions%rowtype; actor record; response_unit record; response_session public.circular_response_sessions%rowtype;
begin
  select * into target from public.circulars c where c.id=p_circular_id and c.deleted_at is null;
  if target.id is null then raise insufficient_privilege using message='circular_not_found'; end if;
  select * into actor from app_private.circular_reader_actor(target.institution_id,'circulars.circulars.read',target.unit_id,target.group_id);
  if not app_private.circular_audience_visible(target,actor.person_id,actor.role_code,target.unit_id,target.group_id,target.activity_id) then raise insufficient_privilege using message='circular_not_found'; end if;
  if target.publish_at>now() then raise check_violation using message='circular_not_available'; end if;
  select * into revision from public.circular_revisions r where r.id=target.current_revision_id;
  if target.response_policy in ('per_person','per_staff_member') or p_child_context_id is not null then
    select * into response_unit from app_private.circular_response_unit(
      revision.id,actor.person_id,jsonb_build_object('child_context_id',p_child_context_id)
    );
    select * into response_session from public.circular_response_sessions s
    where s.revision_id=revision.id and s.response_unit_key=response_unit.unit_key;
  end if;
  return jsonb_build_object('id',target.id,'revision_id',revision.id,'title',revision.title,'body_text',revision.body_text,'published_at',target.publish_at,'revised_at',target.revised_at,
    'author_name',(select p.display_name from public.people p where p.id=target.author_person_id),
    'author_person_id',target.author_person_id,
    'context_label',coalesce((select g.name from public.groups g where g.id=target.group_id),(select u.name from public.units u where u.id=target.unit_id),(select i.public_name from public.institutions i where i.id=target.institution_id)),
    'response_state',case when response_session.status='submitted' then 'answered' when response_session.id is not null then 'partial' else 'unanswered' end,
    'response_session_id',response_session.id,'response_version',coalesce(response_session.response_version,0),
    'response_context_required',target.response_policy in ('per_child_any_guardian','per_child_each_guardian') and p_child_context_id is null,
    'answers',case when response_session.id is null then '{}'::jsonb else (select coalesce(jsonb_object_agg(answer.question_id::text,(
      select coalesce(jsonb_agg(selected.option_id::text order by selected.option_id),'[]'::jsonb)
      from public.circular_answer_options selected where selected.session_id=answer.session_id and selected.question_id=answer.question_id
    )),'{}'::jsonb) from public.circular_answers answer where answer.session_id=response_session.id) end,
    'status',target.status,'response_policy',target.response_policy,'responses_close_at',target.responses_close_at,'responses_closed_at',target.responses_closed_at,
    'blocks',(select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'kind',b.block_kind,'text',b.text_content,'order',b.display_order,'media',(
      select coalesce(jsonb_agg(jsonb_build_object('asset_id',m.id,'mime_type',m.mime_type,'name',m.original_name,'order',l.display_order) order by l.display_order),'[]') from public.circular_media_links l join public.circular_media_assets m on m.id=l.media_asset_id where l.block_id=b.id and m.status='ready'),
      'question',(select jsonb_build_object('id',q.id,'prompt',q.prompt,'kind',q.question_kind,'required',q.required,'options',(
        select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'label',o.label,'order',o.display_order) order by o.display_order),'[]') from public.circular_question_options o where o.question_id=q.id)) from public.circular_questions q where q.block_id=b.id)) order by b.display_order),'[]') from public.circular_blocks b where b.revision_id=revision.id));
end $$;

create or replace function public.list_visible_profile_circulars(
  p_institution_id uuid, p_unit_id uuid, p_group_id uuid, p_activity_id uuid,
  p_before_at timestamptz, p_before_id uuid, p_limit integer default 20
) returns table(item_id uuid, title text, excerpt text, author_name text, context_label text, effective_published_at timestamptz, revised_at timestamptz, attachment_count bigint, question_count bigint, response_state text)
language plpgsql security definer set search_path = '' as $$
declare actor record;
begin
  select * into actor from app_private.circular_reader_actor(p_institution_id,'circulars.circulars.read',p_unit_id,p_group_id);
  return query select c.id,r.title,left(r.body_text,320),p.display_name,coalesce(g.name,u.name,i.public_name),c.publish_at,c.revised_at,
    (select count(*) from public.circular_media_links ml where ml.revision_id=r.id),
    (select count(*) from public.circular_questions q where q.revision_id=r.id),
    case when exists(select 1 from public.circular_response_sessions s where s.revision_id=r.id and s.last_actor_person_id=actor.person_id and s.status='submitted') then 'answered'
      when exists(select 1 from public.circular_response_sessions s where s.revision_id=r.id and s.last_actor_person_id=actor.person_id) then 'partial' else 'unanswered' end
  from public.circulars c join public.circular_revisions r on r.id=c.current_revision_id join public.people p on p.id=c.author_person_id
  join public.institutions i on i.id=c.institution_id left join public.units u on u.id=c.unit_id left join public.groups g on g.id=c.group_id
  where c.institution_id=p_institution_id and app_private.circular_visible(c,actor.person_id,actor.role_code,p_unit_id,p_group_id,p_activity_id)
    and (p_before_at is null or (c.publish_at,c.id)<(p_before_at,p_before_id))
  order by c.publish_at desc,c.id desc limit least(greatest(coalesce(p_limit,20),1),50);
end $$;

create or replace function public.authorize_circular_media_read(p_asset_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare asset public.circular_media_assets%rowtype; target public.circulars%rowtype; actor record;
begin
  select * into asset from public.circular_media_assets m where m.id=p_asset_id and m.status='ready';
  if asset.id is null then raise insufficient_privilege using message='media_read_denied'; end if;
  select * into target from public.circulars c where c.id=asset.circular_id;
  select * into actor from app_private.circular_reader_actor(target.institution_id,'circulars.circulars.read',target.unit_id,target.group_id);
  if not app_private.circular_visible(target,actor.person_id,actor.role_code,target.unit_id,target.group_id,target.activity_id) then raise insufficient_privilege using message='media_read_denied'; end if;
  return jsonb_build_object('storage_provider',asset.storage_provider,'bucket_id',asset.bucket_id,'object_key',asset.object_key,'mime_type',asset.mime_type,'byte_size',asset.byte_size);
end $$;
commit;
