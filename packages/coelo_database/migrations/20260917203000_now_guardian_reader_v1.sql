-- R16 Sessao AGORA / ADR 0044 (agora.publish executar na R16; oq048-membership) / OQ-048 / spec 070.
-- Defeito em producao (dump 17/09/2026 schema-producao-20260917-r16-agora-before.sql, SHA-256 0c6c6468):
-- list_visible_now_publications obtem o ator por app_private.now_actor, que exige
-- has_institution_permission(inst,'now.publications.read') + institution_memberships ativa ANTES de
-- now_viewer_role_class; como 'now.publications.read' so existe em papeis de equipe, nenhum responsavel
-- "puro" (guardian_links + guardian_context_permissions.can_view, sem membership) le o Agora, mesmo com
-- audiencia families. Decisao do Owner: corrigir o contrato, sem override nem membership sintetica.
--
-- Entrega (spec 070):
--   * app_private.now_reader_actor(uuid,text,uuid,uuid) — funcao irma de now_actor para LEITURA: mesma
--     validacao de contexto; caminho de equipe identico (permissao + membership ativa); sem permissao
--     institucional, tenta o caminho de responsavel (now_viewer_role_class com membership null = 'guardian',
--     ou seja, guardian_links ativo + child_contexts ativo na instituicao + can_view vigente, e vinculo de
--     unidade/turma quando o contexto e informado) e devolve (person_id, membership_id null).
--   * public.list_visible_now_publications: mesma assinatura, projecao e grants; ator por now_reader_actor
--     com 'now.publications.read'; classificacao por now_viewer_role_class inalterada (guardian so casa com
--     families/guardians_only; equipe nao ve Familias); can_remove continua exigindo permissao + autoria.
--   * public.redeem_now_media_read_ticket: mesma assinatura e grants (service_role); a membership deixa de
--     ser juncao obrigatoria — a membership ativa (quando existe) e resolvida para o classificador; ticket
--     unico, vinculado ao visitante autenticado, revalidando vigencia e audiencia.
-- app_private.now_actor (escrita: criar, publicar, remover, midia de autor) NAO muda. Sem versao otimista
-- envolvida (nada a sinalizar com PT409). create or replace (assinaturas preservadas). Idempotente.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'now guardian reader must run as postgres';
  end if;
  if to_regprocedure('app_private.now_actor(uuid,text,uuid,uuid)') is null
    or to_regprocedure('app_private.now_viewer_role_class(uuid,uuid,uuid,uuid,uuid)') is null
    or to_regprocedure('app_private.has_institution_permission(uuid,text,uuid,uuid,boolean)') is null
    or to_regprocedure('app_private.now_audience_matches_role(text,public.now_audience_kind)') is null
    or to_regprocedure('app_private.person_id_for_auth_user(uuid)') is null
    or to_regprocedure('public.list_visible_now_publications(uuid,uuid,uuid,integer)') is null
    or to_regprocedure('public.redeem_now_media_read_ticket(uuid,uuid)') is null
    or position('management_version' in pg_get_function_result('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure)) = 0
    or not exists (select 1 from public.institution_permissions where code = 'now.publications.read') then
    raise object_not_in_prerequisite_state using message = 'agora feed removal projection (lote 79) and viewer classifier are required';
  end if;
end
$preflight$;

-- 1. Funcao irma de leitura: equipe como hoje; responsavel por vinculo quando nao ha permissao institucional.
create or replace function app_private.now_reader_actor(
  p_institution_id uuid,
  p_permission text,
  p_unit_id uuid,
  p_group_id uuid
) returns table(person_id uuid, membership_id uuid)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid;
  actor_membership_id uuid;
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message='authentication_required';
  end if;
  if p_unit_id is not null and not exists(
    select 1 from public.units where id=p_unit_id and institution_id=p_institution_id
  ) then raise insufficient_privilege using message='context_not_authorized'; end if;
  if p_group_id is not null and (
    p_unit_id is null or not exists(
      select 1 from public.groups
      where id=p_group_id and institution_id=p_institution_id and unit_id=p_unit_id
    )
  ) then raise insufficient_privilege using message='context_not_authorized'; end if;

  actor_person_id:=app_private.person_id_for_auth_user((select auth.uid()));
  if actor_person_id is null then
    raise insufficient_privilege using message='now_permission_denied';
  end if;

  -- Caminho de equipe (contrato vigente): permissao institucional no contexto + membership ativa.
  if app_private.has_institution_permission(p_institution_id,p_permission,p_unit_id,p_group_id,false) then
    select membership.id into actor_membership_id
    from public.institution_memberships membership
    where membership.person_id=actor_person_id
      and membership.institution_id=p_institution_id
      and membership.status='active' and membership.revoked_at is null
    order by membership.created_at limit 1;
    if actor_membership_id is null then
      raise insufficient_privilege using message='active_membership_required';
    end if;
    person_id:=actor_person_id;
    membership_id:=actor_membership_id;
    return next;
    return;
  end if;

  -- Caminho de responsavel (spec 070): guardian_links ativo + child_contexts ativo na instituicao pedida +
  -- guardian_context_permissions.can_view vigente (+ vinculo de unidade/turma quando o contexto e informado),
  -- pelo mesmo predicado guardian_context de now_viewer_role_class. Sem membership; sem capacidade de escrita.
  if app_private.now_viewer_role_class(actor_person_id,null,p_institution_id,p_unit_id,p_group_id)
     is distinct from 'guardian' then
    raise insufficient_privilege using message='now_permission_denied';
  end if;
  person_id:=actor_person_id;
  membership_id:=null;
  return next;
end $$;

revoke all on function app_private.now_reader_actor(uuid,text,uuid,uuid) from public;
revoke all on function app_private.now_reader_actor(uuid,text,uuid,uuid) from anon, authenticated, service_role;

-- 2. Feed: ator por now_reader_actor; corpo do lote 79 preservado (projecao, tickets, can_remove).
create or replace function public.list_visible_now_publications(
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
  published_at timestamptz,
  expires_at timestamptz,
  media jsonb,
  management_version bigint,
  can_remove boolean
)
language plpgsql
security definer
set search_path = ''
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
    can_remove:=actor_can_remove and visible_publication.author_person_id=actor.person_id;
    return next;
  end loop;
end
$$;

revoke all on function public.list_visible_now_publications(uuid,uuid,uuid,integer) from public;
revoke all on function public.list_visible_now_publications(uuid,uuid,uuid,integer) from anon;
grant execute on function public.list_visible_now_publications(uuid,uuid,uuid,integer) to authenticated, service_role;

-- 3. Resgate do ticket: membership ativa resolvida (pode ser nula para o responsavel); demais guardas iguais.
create or replace function public.redeem_now_media_read_ticket(
  p_ticket uuid,
  p_viewer_auth_user_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  redeemed record;
  redeeming_person_id uuid;
begin
  redeeming_person_id:=app_private.person_id_for_auth_user(p_viewer_auth_user_id);
  if redeeming_person_id is null then
    raise insufficient_privilege using message='media_read_ticket_invalid';
  end if;
  delete from app_private.now_media_read_tickets ticket
  using public.now_media_assets asset,
        public.now_publications publication
  where ticket.token=p_ticket
    and ticket.expires_at>now()
    and ticket.viewer_person_id=redeeming_person_id
    and asset.id=ticket.media_asset_id
    and asset.status='ready'
    and publication.id=asset.publication_id
    and publication.institution_id=asset.institution_id
    and publication.status in('scheduled','published')
    and publication.publish_at<=now()
    and publication.expires_at>now()
    and publication.status<>'expired'
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
            (
              -- membership ativa do visitante na instituicao da publicacao (nula para o responsavel por vinculo)
              select membership.id
              from public.institution_memberships membership
              where membership.person_id=ticket.viewer_person_id
                and membership.institution_id=publication.institution_id
                and membership.status='active'
                and membership.revoked_at is null
              order by membership.created_at
              limit 1
            ),
            publication.institution_id,
            publication.unit_id,
            publication.group_id
          ),
          audience.audience_kind
        )
    )
  returning asset.storage_provider,asset.bucket_id,asset.object_key,asset.mime_type into redeemed;
  if redeemed.object_key is null then
    raise insufficient_privilege using message='media_read_ticket_invalid';
  end if;
  return jsonb_build_object(
    'storage_provider',redeemed.storage_provider,
    'bucket_id',redeemed.bucket_id,
    'object_key',redeemed.object_key,
    'mime_type',redeemed.mime_type
  );
end $$;

revoke all on function public.redeem_now_media_read_ticket(uuid,uuid) from public;
revoke all on function public.redeem_now_media_read_ticket(uuid,uuid) from anon, authenticated;
grant execute on function public.redeem_now_media_read_ticket(uuid,uuid) to service_role;

commit;
