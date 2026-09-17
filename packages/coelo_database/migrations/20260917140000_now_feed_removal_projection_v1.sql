-- R15 Bloco B / ADR 0040 (remocao imediata do Agora) / R14 Sessao 7 (handoff §5, candidato provado no espelho
-- coelo_mirror_r14_agora, nunca aplicado): a tela do Agora nao consegue chamar remove_now_publication porque
-- o feed (list_visible_now_publications) nao projeta a versao otimista nem a capacidade de remover.
--
-- Corpo vigente em producao (dump 17/09/2026, schema-producao-20260917-r15-b-before.sql, SHA-256 c87f4d67)
-- com DUAS colunas de saida a mais:
--   * management_version bigint  — versao otimista da publicacao (p_expected_version da remocao);
--   * can_remove boolean         — autor = ator E app_private.has_institution_permission(
--                                  institution,'now.publications.remove',unit,group,false)
--                                  (mesmo predicado de app_private.now_actor). Sem direito novo: a
--                                  autorizacao continua exclusivamente em remove_now_publication.
-- drop/create e obrigatorio (RETURNS TABLE muda); grants reaplicados (authenticated execute; public/anon nao).
-- O guard "Agora feed exposes only its minimum presentation projection" (now_publication_mvp_test) passa a
-- exigir a assinatura ampliada no mesmo lote. Idempotente.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'now feed removal projection must run as postgres';
  end if;
  if to_regprocedure('public.remove_now_publication(uuid,uuid,bigint,text)') is null
    or to_regprocedure('app_private.now_actor(uuid,text,uuid,uuid)') is null
    or to_regprocedure('app_private.has_institution_permission(uuid,text,uuid,uuid,boolean)') is null
    or not exists (select 1 from public.institution_permissions where code = 'now.publications.remove') then
    raise object_not_in_prerequisite_state using message = 'agora immediate removal contract (lote 71) is required';
  end if;
end
$preflight$;

drop function if exists public.list_visible_now_publications(uuid, uuid, uuid, integer);

create function public.list_visible_now_publications(
  p_institution_id uuid,
  p_unit_id uuid,
  p_group_id uuid,
  p_limit integer default 20
) returns table(
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
  published_at timestamp with time zone,
  expires_at timestamp with time zone,
  media jsonb,
  management_version bigint,
  can_remove boolean
)
language plpgsql security definer
set search_path to ''
as $$
declare
  actor record;
  actor_role text;
  actor_can_remove boolean;
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
    can_remove:=actor_can_remove and visible_publication.author_person_id=actor.person_id;
    return next;
  end loop;
end
$$;

alter function public.list_visible_now_publications(uuid, uuid, uuid, integer) owner to postgres;
revoke all on function public.list_visible_now_publications(uuid, uuid, uuid, integer) from public, anon;
grant execute on function public.list_visible_now_publications(uuid, uuid, uuid, integer) to authenticated, service_role;

do $postcheck$
begin
  if pg_get_function_result('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure)
     not like '%management_version bigint, can_remove boolean)' then
    raise exception using message = 'now feed projection not applied';
  end if;
  if not has_function_privilege('authenticated','public.list_visible_now_publications(uuid,uuid,uuid,integer)','execute')
     or has_function_privilege('anon','public.list_visible_now_publications(uuid,uuid,uuid,integer)','execute') then
    raise exception using message = 'now feed grants unexpected';
  end if;
end
$postcheck$;

commit;
