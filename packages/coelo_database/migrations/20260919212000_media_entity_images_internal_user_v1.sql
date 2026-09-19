-- Lote 89 — leitura em lote das fotos dos usuários internos pelo id da identidade interna.
-- O diretório de Usuários internos só conhece internal_identity_id; a foto vive na pessoa de serviço
-- (app_private.superadmin_internal_actor_people). p_entity_kind = 'internal_user' resolve o vínculo no
-- servidor e devolve o mapa chaveado pelo id pedido; regra de leitura continua a do tenant do asset.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create or replace function public.superadmin_entity_images_list_v1(p_entity_kind text, p_entity_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  perform app_private.entity_image_actor_v1();
  if p_entity_kind not in ('institution','unit','group','activity','person','internal_user') or p_entity_ids is null
    or cardinality(p_entity_ids) > 200 then
    raise exception using errcode = '22023', message = 'invalid_entity_image_query';
  end if;
  if p_entity_kind = 'internal_user' then
    if not app_private.has_platform_permission('platform.member.read', null) then
      return '{}'::jsonb;
    end if;
    select coalesce(jsonb_object_agg(per_entity.internal_identity_id, per_entity.images), '{}'::jsonb) into result
    from (
      select actor.internal_identity_id, jsonb_object_agg(a.image_kind, jsonb_build_object('asset_id', a.id,
        'content_type', a.mime_type, 'icon_spec', a.icon_spec)) as images
      from app_private.superadmin_internal_actor_people actor
      join public.entity_image_assets a on a.entity_kind = 'person' and a.entity_id = actor.person_id and a.status = 'active'
      where actor.internal_identity_id = any (p_entity_ids)
        and app_private.entity_image_can_read_v1(a.tenant_id)
      group by actor.internal_identity_id
    ) per_entity;
    return result;
  end if;
  select coalesce(jsonb_object_agg(per_entity.entity_id, per_entity.images), '{}'::jsonb) into result
  from (
    select a.entity_id, jsonb_object_agg(a.image_kind, jsonb_build_object('asset_id', a.id,
      'content_type', a.mime_type, 'icon_spec', a.icon_spec)) as images
    from public.entity_image_assets a
    where a.entity_kind = p_entity_kind and a.entity_id = any (p_entity_ids) and a.status = 'active'
      and app_private.entity_image_can_read_v1(a.tenant_id)
    group by a.entity_id
  ) per_entity;
  return result;
end
$$;
commit;
