-- Retirada de publicacao do Acontece (action_id acontece.remove).
--
-- A rodada anterior registrou que o cliente estava fail-closed porque nao havia
-- contrato de servidor: nenhuma RPC de retirada, nenhuma capacidade catalogada
-- e nenhuma projecao de identidade no feed. Esta migration fecha esse contrato.
--
-- A retirada e SOFT por decisao de escopo: nao apaga linha, nao apaga midia e
-- nao altera retencao. Marca autor, horario e motivo opcional, registra
-- auditoria e some do feed. Nao existe hard delete nesta superficie.
--
-- Forward-only. `list_visible_happens_posts` muda o tipo de retorno, entao
-- precisa de drop + create; os grants originais sao reaplicados no fim.

alter table public.posts
  add column if not exists withdrawn_at timestamptz,
  add column if not exists withdrawn_by_person_id uuid references public.people(id),
  add column if not exists withdrawal_reason text;

alter table public.posts
  drop constraint if exists posts_withdrawal_reason_ck;
alter table public.posts
  add constraint posts_withdrawal_reason_ck
  check (withdrawal_reason is null or char_length(withdrawal_reason) <= 280);

alter table public.posts
  drop constraint if exists posts_withdrawal_shape_ck;
alter table public.posts
  add constraint posts_withdrawal_shape_ck
  check (
    withdrawn_at is null
    or (status in ('scheduled','published') and withdrawn_by_person_id is not null)
  );

create index if not exists posts_withdrawn_idx
  on public.posts(institution_id, withdrawn_at desc)
  where withdrawn_at is not null;

insert into public.institution_permissions(
  code,module_code,screen_code,action_code,description,status,
  module_label,screen_label,action_label
)
values
 ('happens.posts.remove','happens','posts','remove','Retirar do feed uma publicacao propria ja publicada ou agendada.','active','Acontece','Publicacoes','Remover')
on conflict(code) do update set
  module_code=excluded.module_code,
  screen_code=excluded.screen_code,
  action_code=excluded.action_code,
  description=excluded.description,
  status='active',
  module_label=excluded.module_label,
  screen_label=excluded.screen_label,
  action_label=excluded.action_label;

create or replace function public.withdraw_happens_post(
  p_request_id uuid,
  p_post_id uuid,
  p_expected_version bigint,
  p_reason text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  target public.posts%rowtype;
  actor record;
  normalized_reason text;
begin
  select * into target from public.posts where id=p_post_id for update;
  if not found then raise no_data_found using message='post_not_found'; end if;

  select * into actor from app_private.happens_actor(
    target.institution_id,'happens.posts.remove',target.unit_id,target.group_id);

  if target.author_person_id<>actor.person_id then
    raise insufficient_privilege using message='happens_permission_denied';
  end if;

  if target.withdrawn_at is not null then
    return jsonb_build_object(
      'id',target.id,
      'status',target.status,
      'withdrawn_at',target.withdrawn_at,
      'management_version',target.management_version
    );
  end if;

  if target.management_version<>p_expected_version then
    raise serialization_failure using message='expected_version_conflict';
  end if;

  if target.status='draft' then
    raise check_violation using message='post_not_published';
  end if;

  normalized_reason:=nullif(btrim(coalesce(p_reason,'')),'');
  if normalized_reason is not null and char_length(normalized_reason)>280 then
    raise check_violation using message='reason_too_long';
  end if;

  update public.posts
  set withdrawn_at=now(),
      withdrawn_by_person_id=actor.person_id,
      withdrawal_reason=normalized_reason,
      management_version=management_version+1,
      updated_at=now()
  where id=target.id
  returning * into target;

  insert into app_private.happens_publication_audit(
    post_id,institution_id,actor_person_id,event_code,detail)
  values(
    target.id,target.institution_id,actor.person_id,'post_withdrawn',
    jsonb_build_object('request_id',p_request_id,'reason',normalized_reason));

  return jsonb_build_object(
    'id',target.id,
    'status',target.status,
    'withdrawn_at',target.withdrawn_at,
    'management_version',target.management_version
  );
end $$;

drop function if exists public.list_visible_happens_posts(uuid,uuid,uuid,integer);

create function public.list_visible_happens_posts(p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_limit integer default 20)
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
    can_withdraw:=visible_post.author_person_id=actor.person_id;
    media:=media_items;
    return next;
  end loop;
end
$$;

revoke all on function
  public.withdraw_happens_post(uuid,uuid,bigint,text),
  public.list_visible_happens_posts(uuid,uuid,uuid,integer)
  from public,anon,authenticated;
grant execute on function
  public.withdraw_happens_post(uuid,uuid,bigint,text),
  public.list_visible_happens_posts(uuid,uuid,uuid,integer)
  to authenticated;
