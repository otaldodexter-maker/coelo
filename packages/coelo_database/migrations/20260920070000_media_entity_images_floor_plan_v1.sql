-- Sessão MÍDIA-E2E-2 (20/09/2026) — planta baixa (spec 067, pedido da ETAPA-3): image_kind 'floor_plan'
-- em entity_image_assets para instituição e unidade (JPEG/PNG/WebP até 5 MB; SVG só no icon_vector).
-- Mesmo catálogo, mesmas RPCs de upload/leitura/remoção e o mesmo leitor do Principal; só o "prepare"
-- e as constraints aprendem o tipo novo. A tela de Locais lê pela RPC em lote (kind floor_plan).
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if to_regprocedure('public.superadmin_entity_image_prepare_v1(uuid,text,uuid,text,text,text,bigint,text,jsonb)') is null
    or to_regclass('public.entity_image_assets') is null then
    raise object_not_in_prerequisite_state using message = 'entity images (lotes 85/87) are required';
  end if;
end
$preflight$;

alter table public.entity_image_assets drop constraint if exists entity_image_assets_image_kind_check;
alter table public.entity_image_assets add constraint entity_image_assets_image_kind_check
  check (image_kind in ('profile','cover','icon','icon_vector','floor_plan')
    and (image_kind <> 'floor_plan' or entity_kind in ('institution','unit')));
alter table public.entity_image_assets drop constraint if exists entity_image_assets_object_key_check;
alter table public.entity_image_assets add constraint entity_image_assets_object_key_check
  check (object_key ~ '^entities/(institution|unit|group|activity|person)/[0-9a-f-]{36}/(profile|cover|icon|icon_vector|floor_plan)/[0-9a-f-]{36}\.(jpg|png|webp|svg)$');

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
    or p_image_kind not in ('profile','cover','icon','icon_vector','floor_plan')
    or (p_image_kind in ('icon','icon_vector') and p_entity_kind <> 'activity')
    or (p_image_kind = 'floor_plan' and p_entity_kind not in ('institution','unit'))
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
commit;
