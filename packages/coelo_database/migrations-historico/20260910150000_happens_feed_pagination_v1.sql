-- Acontece: o feed passa a paginar de verdade.
--
-- list_visible_happens_posts nasceu com um teto rigido: limit entre 1 e 50, sem
-- cursor nenhum. Quem tem mais publicacoes do que o teto simplesmente nao ve o
-- resto, e o "carregar mais" da tela nao tinha para onde ir. O Owner respondeu
-- em 10/09/2026 (D3 e D5) que nao existe previa: o feed funciona de verdade,
-- com carregar mais pela paginacao do servidor.
--
-- A paginacao e keyset por (publish_at, post_id), a mesma forma que o chat usa:
-- estavel sob insercao concorrente e sem OFFSET. A ordem do desempate passa de
-- id ascendente para descendente, porque um cursor so fecha quando as duas
-- colunas caminham na mesma direcao.
--
-- A autorizacao nao muda: continua vindo de happens_actor, do casamento de
-- audiencia por papel e de has_institution_permission. O cursor e apenas
-- posicao; ele nao alarga o que o ator pode ver.
begin;

drop function if exists public.list_visible_happens_posts(uuid, uuid, uuid, integer);

create function public.list_visible_happens_posts(
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid,
  p_limit integer default 20,
  p_cursor_published_at timestamptz default null,
  p_cursor_post_id uuid default null
)
returns table(
  post_id uuid,
  author_name text,
  author_initials text,
  context_label text,
  caption text,
  published_at timestamptz,
  management_version bigint,
  can_withdraw boolean,
  media jsonb
) language plpgsql security definer set search_path='' as $$
declare
  actor record;
  actor_role text;
  visible_post record;
  visible_media record;
  media_items jsonb;
  read_ticket uuid;
begin
  -- Os dois lados do cursor andam juntos: metade de um cursor e entrada
  -- malformada, nao um pedido de primeira pagina.
  if (p_cursor_published_at is null) <> (p_cursor_post_id is null) then
    raise invalid_parameter_value using message = 'cursor values must be provided together';
  end if;
  select * into actor from app_private.happens_actor(p_institution_id,'happens.posts.read',p_unit_id,p_group_id);
  select lower(membership.role_code) into actor_role
  from public.institution_memberships membership
  where membership.id=actor.membership_id;

  delete from app_private.happens_media_read_tickets ticket
  where ticket.expires_at<=now();

  for visible_post in
    select
      post.id,
      post.author_person_id,
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
      and (
        p_cursor_published_at is null
        or (post.publish_at, post.id) < (p_cursor_published_at, p_cursor_post_id)
      )
      and exists(
        select 1
        from public.post_audiences audience
        where audience.post_id=post.id
          and audience.institution_id=p_institution_id
          and audience.unit_id is not distinct from post.unit_id
          and audience.group_id is not distinct from post.group_id
          and app_private.happens_audience_matches_role(actor_role,audience.audience_kind)
      )
    order by post.publish_at desc,post.id desc
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
    can_withdraw:=visible_post.author_person_id=actor.person_id
      and app_private.has_institution_permission(
        p_institution_id,'happens.posts.remove',p_unit_id,p_group_id,false);
    media:=media_items;
    return next;
  end loop;
end
$$;

-- O cursor usa (publish_at, id) na mesma direcao do order by.
create index if not exists posts_happens_feed_keyset_idx
  on public.posts (institution_id, publish_at desc, id desc)
  where withdrawn_at is null;

revoke all on function
  public.list_visible_happens_posts(uuid,uuid,uuid,integer,timestamptz,uuid)
  from public,anon,authenticated;
grant execute on function
  public.list_visible_happens_posts(uuid,uuid,uuid,integer,timestamptz,uuid)
  to authenticated;

commit;
