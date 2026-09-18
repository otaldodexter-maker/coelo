-- 20260918140000_now_feed_can_remove_follows_rpc_v1
--
-- R16 Sessao RESERVA / decisao D6 do Owner em 18/09/2026 (padrao adotado: "o feed segue a RPC";
-- R16-prompt-reserva-20260918.md, Bloco 4; divida `can-remove` da Mesa R16, ADR 0044; ADR 0040).
--
-- Situacao: remove_now_publication (lote 71/75) autoriza qualquer ator com a capacidade
-- now.publications.remove no tenant/contexto da publicacao (autor OU papel institucional), mas a
-- projecao can_remove do feed (lote 79, preservada no lote 81) exigia tambem autoria — o botao
-- "Remover" nao aparecia para administradores que a RPC aceita.
--
-- O que muda: SOMENTE a linha da projecao em public.list_visible_now_publications
-- (corpo vigente extraido do dump de producao de 18/09/2026, schema-producao-20260918-r16-reserva-before.sql,
-- SHA-256 9bb98a47): can_remove := actor_can_remove (permissao no escopo, sem autoria). Assinatura,
-- projecao, tickets, now_reader_actor (lote 81) e grants inalterados. Nenhum direito novo: a RPC de
-- remocao continua a unica autoridade; a projecao apenas reflete quem ela aceita.
-- Forward-only, idempotente (create or replace, mesma assinatura RETURNS TABLE).
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'now feed can_remove migration must run as postgres';
  end if;
  if to_regprocedure('public.list_visible_now_publications(uuid,uuid,uuid,integer)') is null
    or to_regprocedure('app_private.now_reader_actor(uuid,text,uuid,uuid)') is null
    or to_regprocedure('public.remove_now_publication(uuid,uuid,bigint,text)') is null then
    raise object_not_in_prerequisite_state using message = 'agora feed (lote 81) and removal contract are required';
  end if;
  if pg_get_function_result('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure)
     not like '%management_version bigint, can_remove boolean)' then
    raise object_not_in_prerequisite_state using message = 'feed projection (lote 79) is required';
  end if;
end
$preflight$;

CREATE OR REPLACE FUNCTION "public"."list_visible_now_publications"("p_institution_id" "uuid", "p_unit_id" "uuid", "p_group_id" "uuid", "p_limit" integer DEFAULT 20) RETURNS TABLE("publication_id" "uuid", "author_name" "text", "author_initials" "text", "context_label" "text", "caption" "text", "overlay_text" "text", "crop_scale" numeric, "crop_x" numeric, "crop_y" numeric, "cover_position" numeric, "published_at" timestamp with time zone, "expires_at" timestamp with time zone, "media" "jsonb", "management_version" bigint, "can_remove" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
  from app_private.now_reader_actor(
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
  -- Capacidade de remover avaliada uma vez por chamada, com o mesmo predicado de app_private.now_actor
  -- para 'now.publications.remove'; a RPC de remocao continua sendo a unica autoridade.
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
      publication.author_person_id
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
    -- D6 (18/09): o feed segue a RPC — remove_now_publication aceita qualquer ator com
    -- now.publications.remove no escopo (autor ou papel institucional); a autoria deixa de ser exigida aqui.
    can_remove:=actor_can_remove;
    return next;
  end loop;
end
$$;

alter function public.list_visible_now_publications(uuid, uuid, uuid, integer) owner to postgres;
revoke all on function public.list_visible_now_publications(uuid, uuid, uuid, integer) from public, anon;
grant execute on function public.list_visible_now_publications(uuid, uuid, uuid, integer) to authenticated;

do $postcheck$
declare def text := pg_get_functiondef('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure);
begin
  if position('can_remove:=actor_can_remove;' in def) = 0
     or position('author_person_id=actor.person_id' in def) > 0 then
    raise object_not_in_prerequisite_state using message = 'can_remove projection still requires authorship';
  end if;
  if position('now_reader_actor' in def) = 0 then
    raise object_not_in_prerequisite_state using message = 'feed lost now_reader_actor (lote 81)';
  end if;
end
$postcheck$;

commit;
