-- Lote 87 — imagens das entidades: leitura em lote (diretórios/cards), leitor do Principal
-- (equipe ou responsável por guardian_links + can_view), ícone vetorial (SVG) da atividade e
-- expiração dos rascunhos por worker (Edge entity-media, action "expire", segredo no Vault).
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

-- 1. Ícone vetorial: image_kind 'icon_vector' (SVG) convive com 'icon' (PNG) -----------------------
alter table public.entity_image_assets drop constraint if exists entity_image_assets_image_kind_check;
alter table public.entity_image_assets add constraint entity_image_assets_image_kind_check
  check (image_kind in ('profile','cover','icon','icon_vector'));
alter table public.entity_image_assets drop constraint if exists entity_image_assets_mime_type_check;
alter table public.entity_image_assets add constraint entity_image_assets_mime_type_check
  check (mime_type in ('image/jpeg','image/png','image/webp','image/svg+xml')
    and ((image_kind = 'icon_vector') = (mime_type = 'image/svg+xml')));
alter table public.entity_image_assets drop constraint if exists entity_image_assets_object_key_check;
alter table public.entity_image_assets add constraint entity_image_assets_object_key_check
  check (object_key ~ '^entities/(institution|unit|group|activity|person)/[0-9a-f-]{36}/(profile|cover|icon|icon_vector)/[0-9a-f-]{36}\.(jpg|png|webp|svg)$');

create or replace function public.superadmin_entity_image_prepare_v1(
  p_request_id uuid, p_entity_kind text, p_entity_id uuid, p_image_kind text,
  p_file_name text, p_content_type text, p_byte_size bigint, p_sha256 text, p_icon_spec jsonb default null
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  actor_id uuid; tenant uuid; asset public.entity_image_assets%rowtype;
  content_type text := lower(btrim(coalesce(p_content_type, '')));
  checksum text := lower(btrim(coalesce(p_sha256, '')));
  asset_id uuid := gen_random_uuid();
begin
  actor_id := app_private.entity_image_actor_v1();
  if p_request_id is null or p_entity_kind not in ('institution','unit','group','activity','person')
    or p_image_kind not in ('profile','cover','icon','icon_vector')
    or (p_image_kind in ('icon','icon_vector') and p_entity_kind <> 'activity')
    or coalesce(p_file_name, '') = '' or char_length(p_file_name) > 255 or p_file_name ~ '[[:cntrl:]/\\]'
    or content_type not in ('image/jpeg','image/png','image/webp','image/svg+xml')
    or ((p_image_kind = 'icon_vector') <> (content_type = 'image/svg+xml'))
    or (content_type = 'image/svg+xml' and p_byte_size > 262144)
    or p_byte_size is null or p_byte_size < 1 or p_byte_size > 5242880 or checksum !~ '^[0-9a-f]{64}$'
    or (p_icon_spec is not null and jsonb_typeof(p_icon_spec) <> 'object') then
    raise exception using errcode = '22023', message = 'invalid_entity_image';
  end if;
  tenant := app_private.entity_image_tenant_v1(p_entity_kind, p_entity_id);
  if tenant is null then
    raise exception using errcode = 'P0002', message = 'entity_image_target_not_found';
  end if;
  if not app_private.entity_image_can_manage_v1(p_entity_kind, tenant) then
    raise exception using errcode = '42501', message = 'entity_image_denied';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(actor_id::text || p_request_id::text, 0));
  select * into asset from public.entity_image_assets
  where created_by_person_id = actor_id and request_id = p_request_id;
  if asset.id is null then
    insert into public.entity_image_assets(
      id, entity_kind, entity_id, image_kind, tenant_id, object_key, mime_type, byte_size,
      checksum_sha256, icon_spec, request_id, created_by_person_id
    ) values (
      asset_id, p_entity_kind, p_entity_id, p_image_kind, tenant,
      'entities/' || p_entity_kind || '/' || p_entity_id::text || '/' || p_image_kind || '/' || asset_id::text
        || case content_type when 'image/jpeg' then '.jpg' when 'image/png' then '.png'
             when 'image/svg+xml' then '.svg' else '.webp' end,
      content_type, p_byte_size, checksum, p_icon_spec, p_request_id, actor_id
    ) returning * into asset;
    insert into audit.audit_logs(actor_person_id, action_code, object_type, object_id, institution_id, outcome, after_json)
    values (actor_id, 'entity_image.prepare', 'entity_image_asset', asset.id, tenant, 'success',
      jsonb_build_object('entity_kind', p_entity_kind, 'entity_id', p_entity_id, 'image_kind', p_image_kind));
  end if;
  return jsonb_build_object('asset_id', asset.id, 'object_key', asset.object_key, 'content_type', asset.mime_type,
    'byte_size', asset.byte_size, 'upload_status', asset.status, 'expires_at', asset.expires_at);
end
$$;

-- 2. Leitura em lote para diretórios e cabeçalhos (equipe interna): {"<entity_id>": {"profile": {...}, ...}}
-- Só entidades cujo tenant o ator pode ler; ids sem imagem não aparecem. Até 200 ids por chamada.
create or replace function public.superadmin_entity_images_list_v1(p_entity_kind text, p_entity_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  perform app_private.entity_image_actor_v1();
  if p_entity_kind not in ('institution','unit','group','activity','person') or p_entity_ids is null
    or cardinality(p_entity_ids) > 200 then
    raise exception using errcode = '22023', message = 'invalid_entity_image_query';
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

-- 3. Leitor do Principal: equipe do tenant ou responsável por guardian_links + can_view (mesma regra
-- de app_private.now_reader_actor, via now_viewer_role_class); sem membership, sem escrita.
create or replace function app_private.entity_image_principal_can_read_v1(p_tenant_id uuid)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare actor_person_id uuid;
begin
  if (select auth.uid()) is null then return false; end if;
  if app_private.entity_image_can_read_v1(p_tenant_id) then return true; end if;
  actor_person_id := app_private.person_id_for_auth_user((select auth.uid()));
  if actor_person_id is null then return false; end if;
  return coalesce(app_private.now_viewer_role_class(actor_person_id, null, p_tenant_id, null, null) = 'guardian', false);
end
$$;

create or replace function public.principal_entity_images_list_v1(p_entity_kind text, p_entity_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;
  if p_entity_kind not in ('institution','unit','group','activity','person') or p_entity_ids is null
    or cardinality(p_entity_ids) > 200 then
    raise exception using errcode = '22023', message = 'invalid_entity_image_query';
  end if;
  select coalesce(jsonb_object_agg(per_entity.entity_id, per_entity.images), '{}'::jsonb) into result
  from (
    select a.entity_id, jsonb_object_agg(a.image_kind, jsonb_build_object('asset_id', a.id,
      'content_type', a.mime_type, 'icon_spec', a.icon_spec)) as images
    from public.entity_image_assets a
    where a.entity_kind = p_entity_kind and a.entity_id = any (p_entity_ids) and a.status = 'active'
      and app_private.entity_image_principal_can_read_v1(a.tenant_id)
    group by a.entity_id
  ) per_entity;
  return result;
end
$$;

create or replace function public.principal_entity_image_authorize_read_v1(p_asset_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare asset public.entity_image_assets%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;
  select * into asset from public.entity_image_assets where id = p_asset_id and status = 'active';
  if asset.id is null or not app_private.entity_image_principal_can_read_v1(asset.tenant_id) then
    raise exception using errcode = '42501', message = 'entity_image_read_denied';
  end if;
  return jsonb_build_object('asset_id', asset.id, 'object_key', asset.object_key, 'content_type', asset.mime_type,
    'byte_size', asset.byte_size);
end
$$;

-- 4. Expiração dos rascunhos sem upload (service_role, chamada pela Edge entity-media action "expire").
-- Devolve as chaves para a Edge apagar no R2 um objeto órfão de upload interrompido.
create or replace function public.superadmin_entity_image_expire_v1(p_limit integer default 100)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare expired_items jsonb; expired_count integer;
begin
  if current_setting('request.jwt.claim.role', true) is distinct from 'service_role'
    and coalesce(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role' is distinct from 'service_role' then
    raise exception using errcode = '42501', message = 'permission_denied';
  end if;
  with candidates as (
    select id from public.entity_image_assets
    where status = 'draft' and expires_at < now()
    order by expires_at limit greatest(1, least(coalesce(p_limit, 100), 500))
    for update skip locked
  ), expired as (
    update public.entity_image_assets a set status = 'inactive', revoked_at = now()
    from candidates c where a.id = c.id
    returning a.id, a.object_key
  )
  select coalesce(jsonb_agg(jsonb_build_object('asset_id', e.id, 'object_key', e.object_key)), '[]'::jsonb), count(*)
  into expired_items, expired_count from expired e;
  return jsonb_build_object('expired', expired_count, 'items', expired_items);
end
$$;

-- Dispatch pelo pg_cron (mesmo padrão do chat-media): URL e segredo no Vault
-- (entity_media_worker_url, entity_media_worker_secret); devolve null enquanto faltarem.
create or replace function app_private.entity_media_dispatch_expire_worker()
returns bigint language plpgsql security definer set search_path = '' as $$
declare worker_url text; worker_secret text; request_id bigint;
begin
  select decrypted_secret into worker_url from vault.decrypted_secrets where name = 'entity_media_worker_url' limit 1;
  select decrypted_secret into worker_secret from vault.decrypted_secrets where name = 'entity_media_worker_secret' limit 1;
  if nullif(worker_url, '') is null or nullif(worker_secret, '') is null then
    return null;
  end if;
  select net.http_post(
    url := worker_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-worker-secret', worker_secret),
    body := '{"action":"expire"}'::jsonb,
    timeout_milliseconds := 5000
  ) into request_id;
  return request_id;
end
$$;
alter function app_private.entity_media_dispatch_expire_worker() owner to postgres;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'coelo-entity-media-expire') then
    perform cron.unschedule('coelo-entity-media-expire');
  end if;
  perform cron.schedule('coelo-entity-media-expire', '*/10 * * * *',
    'select app_private.entity_media_dispatch_expire_worker();');
end
$$;

-- 5. ACL --------------------------------------------------------------------------------------------
revoke all on function app_private.entity_image_principal_can_read_v1(uuid),
  app_private.entity_media_dispatch_expire_worker() from public, anon, authenticated, service_role;
revoke all on function public.superadmin_entity_images_list_v1(text,uuid[]), public.principal_entity_images_list_v1(text,uuid[]),
  public.principal_entity_image_authorize_read_v1(uuid), public.superadmin_entity_image_expire_v1(integer)
  from public, anon, authenticated;
grant execute on function public.superadmin_entity_images_list_v1(text,uuid[]), public.principal_entity_images_list_v1(text,uuid[]),
  public.principal_entity_image_authorize_read_v1(uuid) to authenticated;
grant execute on function public.superadmin_entity_image_expire_v1(integer) to service_role;
commit;
