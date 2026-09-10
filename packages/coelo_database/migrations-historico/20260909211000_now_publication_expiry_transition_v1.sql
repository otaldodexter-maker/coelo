-- Transição material de expiração das publicações do Agora (action_id agora.expire).
-- Antes desta migração o valor 'expired' do enum public.now_publication_status era
-- inalcançável: a janela de 24 horas existia apenas como filtro temporal de leitura
-- (expires_at > now()) em public.list_visible_now_publications e em
-- public.redeem_now_media_read_ticket. Nenhuma rotina mudava o estado da linha.
--
-- Esta migração cria a varredura que transiciona o estado, sem alterar regra de
-- produto nem retenção: nenhuma linha é apagada, nenhuma mídia é removida do bucket
-- privado coelo-now-mvp e nenhum prazo é encurtado ou estendido. O enum não é
-- alterado. O filtro temporal permanece como garantia primária de leitura; o novo
-- predicado de estado é redundante por construção e serve para tornar explícito que
-- publicação expirada nunca é servida.
--
-- Limites conhecidos e deliberados:
-- * a expiração automática ainda depende de agendador externo (pg_cron, Edge
--   Function agendada ou Cloudflare Worker de cron) que NÃO está implantado. Sem
--   esse agendador a transição só ocorre quando app_private.sweep_expired_now_publications
--   for chamada pelo service_role ou quando um ator autorizado acionar
--   public.expire_due_now_publications a partir de uma superfície administrativa.
-- * a retirada manual de uma publicação pelo próprio autor NÃO é criada aqui: não há
--   decisão canônica registrada sobre o gesto, a permissão exigida, o efeito sobre a
--   mídia já entregue e a trilha esperada. Fica em aberto.
-- * a purga das mídias vencidas no bucket privado continua fora deste escopo.

create or replace function app_private.sweep_expired_now_publications(
  p_institution_id uuid default null,
  p_limit integer default 500
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare
  transitioned integer;
begin
  with due as (
    select
      publication.id,
      publication.status as previous_status
    from public.now_publications publication
    where publication.status in('scheduled','published')
      and publication.expires_at is not null
      and publication.expires_at<=now()
      and (p_institution_id is null or publication.institution_id=p_institution_id)
    order by publication.expires_at,publication.id
    limit least(greatest(coalesce(p_limit,500),1),5000)
    for update skip locked
  ),
  transitioned_rows as (
    update public.now_publications publication
    set status='expired',
        management_version=publication.management_version+1,
        updated_at=now()
    from due
    where publication.id=due.id
    returning
      publication.id,
      publication.institution_id,
      publication.author_person_id,
      publication.expires_at,
      publication.management_version,
      due.previous_status
  ),
  audited_rows as (
    insert into app_private.now_publication_audit(
      publication_id,institution_id,actor_person_id,event_code,detail
    )
    select
      transitioned_row.id,
      transitioned_row.institution_id,
      transitioned_row.author_person_id,
      'publication_expired',
      jsonb_build_object(
        'transition','automatic',
        'actor_kind','system_sweep',
        'actor_person_id_source','publication_author',
        'previous_status',transitioned_row.previous_status,
        'expires_at',transitioned_row.expires_at,
        'version',transitioned_row.management_version
      )
    from transitioned_rows transitioned_row
    returning 1
  )
  select count(*)::integer into transitioned from audited_rows;
  return coalesce(transitioned,0);
end
$$;

revoke all on function app_private.sweep_expired_now_publications(uuid,integer)
  from public,anon,authenticated;
grant execute on function app_private.sweep_expired_now_publications(uuid,integer)
  to service_role;

create or replace function public.expire_due_now_publications(p_institution_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor record;
  transitioned integer;
begin
  if p_institution_id is null then
    raise insufficient_privilege using message='context_not_authorized';
  end if;
  select * into actor
  from app_private.now_actor(p_institution_id,'now.publications.publish',null,null);
  transitioned:=app_private.sweep_expired_now_publications(p_institution_id,500);
  insert into app_private.now_publication_audit(
    publication_id,institution_id,actor_person_id,event_code,detail
  )
  values(
    null,
    p_institution_id,
    actor.person_id,
    'expiry_sweep_requested',
    jsonb_build_object('expired_count',transitioned)
  );
  return jsonb_build_object(
    'institution_id',p_institution_id,
    'expired_count',transitioned
  );
end
$$;

revoke all on function public.expire_due_now_publications(uuid)
  from public,anon,authenticated;
grant execute on function public.expire_due_now_publications(uuid)
  to authenticated;

-- Leitura consistente com o estado material. Corpo copiado fielmente de
-- 20260821130000_now_custom_role_audience_hardening.sql, com a única adição do
-- predicado explícito de estado; assinaturas e grants preservados.
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
    and publication.status<>'expired'
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
