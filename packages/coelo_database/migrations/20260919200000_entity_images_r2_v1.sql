-- Fotos de perfil, capa e ícone de instituição, unidade, turma, atividade e pessoa em R2 privado.
-- Um catálogo só (public.entity_image_assets) com ticket embutido; os bytes passam pela Edge
-- `entity-media` (o navegador nunca fala com o R2). Autorização por tenant + permissão da entidade.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

create table if not exists public.entity_image_assets (
  id uuid primary key default gen_random_uuid(),
  entity_kind text not null check (entity_kind in ('institution','unit','group','activity','person')),
  entity_id uuid not null,
  image_kind text not null check (image_kind in ('profile','cover','icon')),
  tenant_id uuid not null references public.institutions(id) on delete restrict,
  storage_bucket text not null default 'coelo-media-prod' check (storage_bucket = 'coelo-media-prod'),
  object_key text not null unique check (object_key ~ '^entities/(institution|unit|group|activity|person)/[0-9a-f-]{36}/(profile|cover|icon)/[0-9a-f-]{36}\.(jpg|png|webp)$'),
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/webp')),
  byte_size bigint not null check (byte_size between 1 and 5242880),
  checksum_sha256 text check (checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$'),
  icon_spec jsonb check (icon_spec is null or jsonb_typeof(icon_spec) = 'object'),
  status text not null default 'draft' check (status in ('draft','active','inactive')),
  request_id uuid not null,
  finalize_ticket uuid not null unique default gen_random_uuid(),
  expires_at timestamptz not null default now() + interval '30 minutes',
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  revoked_at timestamptz,
  unique (created_by_person_id, request_id)
);
alter table public.entity_image_assets enable row level security;
alter table public.entity_image_assets force row level security;
revoke all on table public.entity_image_assets from public, anon, authenticated;
create index if not exists entity_image_assets_entity_idx
  on public.entity_image_assets (entity_kind, entity_id, image_kind) where status = 'active';
create index if not exists entity_image_assets_tenant_idx on public.entity_image_assets (tenant_id, created_at desc);

-- Ator interno autenticado (sem exigir platform.read: a permissão da entidade decide).
create or replace function app_private.entity_image_actor_v1()
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare actor_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;
  actor_id := app_private.current_person_id();
  if actor_id is null then
    raise exception using errcode = '42501', message = 'internal_actor_required';
  end if;
  return actor_id;
end
$$;

-- Tenant da entidade; null quando a entidade não existe.
create or replace function app_private.entity_image_tenant_v1(p_entity_kind text, p_entity_id uuid)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare tenant uuid; actor_id uuid := app_private.current_person_id();
begin
  if p_entity_id is null then return null; end if;
  case p_entity_kind
    when 'institution' then
      select i.id into tenant from public.institutions i where i.id = p_entity_id and i.deleted_at is null;
    when 'unit' then
      select u.institution_id into tenant from public.units u where u.id = p_entity_id;
    when 'group' then
      select g.institution_id into tenant from public.groups g where g.id = p_entity_id;
    when 'activity' then
      select a.institution_id into tenant from public.activity_definitions a where a.id = p_entity_id;
    when 'person' then
      if not exists (select 1 from public.people p where p.id = p_entity_id and p.deleted_at is null) then
        return null;
      end if;
      select m.institution_id into tenant from public.institution_memberships m
        where m.person_id = p_entity_id and m.status = 'active' and m.revoked_at is null order by m.created_at limit 1;
      if tenant is null then
        select m.scope_institution_id into tenant from public.platform_memberships m
          where m.person_id = p_entity_id and m.status = 'active' and m.revoked_at is null
            and m.scope_institution_id is not null order by m.created_at limit 1;
      end if;
      -- pessoa só de plataforma (equipe interna): tenant do ator que edita
      if tenant is null then
        select m.scope_institution_id into tenant from public.platform_memberships m
          where m.person_id = actor_id and m.status = 'active' and m.revoked_at is null
            and m.scope_institution_id is not null order by m.created_at limit 1;
      end if;
      if tenant is null then
        select m.institution_id into tenant from public.institution_memberships m
          where m.person_id = actor_id and m.status = 'active' and m.revoked_at is null order by m.created_at limit 1;
      end if;
    else
      tenant := null;
  end case;
  return tenant;
end
$$;

-- Quem pode trocar a imagem: permissão da entidade no tenant (Owner/plataforma inclusive).
create or replace function app_private.entity_image_can_manage_v1(p_entity_kind text, p_tenant_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select app_private.has_platform_permission(case p_entity_kind
    when 'institution' then 'institution.update'
    when 'unit' then 'units.update'
    when 'group' then 'groups.manage'
    when 'activity' then 'activities.manage'
    when 'person' then 'people.update' end, p_tenant_id)
$$;

-- Quem pode ver: qualquer identidade interna ativa da plataforma ou do tenant.
create or replace function app_private.entity_image_can_read_v1(p_tenant_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.platform_memberships m
    where m.person_id = app_private.current_person_id() and m.status = 'active' and m.revoked_at is null
      and (m.scope_kind = 'platform' or m.scope_institution_id = p_tenant_id)
  ) or exists (
    select 1 from public.institution_memberships m
    where m.person_id = app_private.current_person_id() and m.status = 'active' and m.revoked_at is null
      and m.institution_id = p_tenant_id
  )
$$;

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
    or p_image_kind not in ('profile','cover','icon') or (p_image_kind = 'icon' and p_entity_kind <> 'activity')
    or coalesce(p_file_name, '') = '' or char_length(p_file_name) > 255 or p_file_name ~ '[[:cntrl:]/\\]'
    or content_type not in ('image/jpeg','image/png','image/webp')
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
        || case content_type when 'image/jpeg' then '.jpg' when 'image/png' then '.png' else '.webp' end,
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

create or replace function public.superadmin_entity_image_authorize_upload_v1(p_asset_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor_id uuid; asset public.entity_image_assets%rowtype;
begin
  actor_id := app_private.entity_image_actor_v1();
  select * into asset from public.entity_image_assets
  where id = p_asset_id and created_by_person_id = actor_id and status = 'draft' and expires_at >= now();
  if asset.id is null or not app_private.entity_image_can_manage_v1(asset.entity_kind, asset.tenant_id) then
    raise exception using errcode = '42501', message = 'entity_image_ticket_denied';
  end if;
  return jsonb_build_object('asset_id', asset.id, 'object_key', asset.object_key, 'content_type', asset.mime_type,
    'byte_size', asset.byte_size, 'sha256', asset.checksum_sha256, 'finalize_ticket', asset.finalize_ticket);
end
$$;

create or replace function public.superadmin_entity_image_finalize_v1(
  p_asset_id uuid, p_finalize_ticket uuid, p_byte_size bigint, p_checksum_sha256 text
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare asset public.entity_image_assets%rowtype;
begin
  if current_setting('request.jwt.claim.role', true) is distinct from 'service_role'
    and coalesce(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role' is distinct from 'service_role' then
    raise exception using errcode = '42501', message = 'permission_denied';
  end if;
  select * into asset from public.entity_image_assets
  where id = p_asset_id and finalize_ticket = p_finalize_ticket and status = 'draft' and expires_at >= now() for update;
  if asset.id is null then
    raise exception using errcode = '42501', message = 'entity_image_ticket_denied';
  end if;
  if p_byte_size is distinct from asset.byte_size
    or lower(coalesce(p_checksum_sha256, '')) is distinct from asset.checksum_sha256 then
    -- o rascunho fica como está (expira em 30 min); a Edge apaga o objeto do R2
    raise exception using errcode = '22023', message = 'entity_image_mismatch';
  end if;
  update public.entity_image_assets set status = 'inactive', revoked_at = now()
  where entity_kind = asset.entity_kind and entity_id = asset.entity_id and image_kind = asset.image_kind
    and status = 'active' and id <> asset.id;
  update public.entity_image_assets set status = 'active', activated_at = now() where id = asset.id returning * into asset;
  insert into audit.audit_logs(actor_person_id, action_code, object_type, object_id, institution_id, outcome, after_json)
  values (asset.created_by_person_id, 'entity_image.finalize', 'entity_image_asset', asset.id, asset.tenant_id, 'success',
    jsonb_build_object('entity_kind', asset.entity_kind, 'entity_id', asset.entity_id, 'image_kind', asset.image_kind));
  return jsonb_build_object('asset_id', asset.id, 'status', 'active', 'content_type', asset.mime_type,
    'image_kind', asset.image_kind, 'icon_spec', asset.icon_spec);
end
$$;

create or replace function public.superadmin_entity_image_authorize_read_v1(p_asset_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor_id uuid; asset public.entity_image_assets%rowtype;
begin
  actor_id := app_private.entity_image_actor_v1();
  select * into asset from public.entity_image_assets where id = p_asset_id and status = 'active';
  if asset.id is null or not app_private.entity_image_can_read_v1(asset.tenant_id) then
    raise exception using errcode = '42501', message = 'entity_image_read_denied';
  end if;
  return jsonb_build_object('asset_id', asset.id, 'object_key', asset.object_key, 'content_type', asset.mime_type,
    'byte_size', asset.byte_size);
end
$$;

create or replace function public.superadmin_entity_image_remove_v1(p_asset_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor_id uuid; asset public.entity_image_assets%rowtype;
begin
  actor_id := app_private.entity_image_actor_v1();
  select * into asset from public.entity_image_assets where id = p_asset_id and status = 'active';
  if asset.id is null or not app_private.entity_image_can_manage_v1(asset.entity_kind, asset.tenant_id) then
    raise exception using errcode = '42501', message = 'entity_image_remove_denied';
  end if;
  update public.entity_image_assets set status = 'inactive', revoked_at = now() where id = asset.id returning * into asset;
  insert into audit.audit_logs(actor_person_id, action_code, object_type, object_id, institution_id, outcome)
  values (actor_id, 'entity_image.remove', 'entity_image_asset', asset.id, asset.tenant_id, 'success');
  return jsonb_build_object('asset_id', asset.id, 'status', 'revoked', 'object_key', asset.object_key);
end
$$;

-- Imagens ativas de uma entidade: {"profile": {...}, "cover": {...}, "icon": {...}} (chave ausente = sem imagem).
create or replace function public.superadmin_entity_images_get_v1(p_entity_kind text, p_entity_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare tenant uuid; result jsonb;
begin
  perform app_private.entity_image_actor_v1();
  tenant := app_private.entity_image_tenant_v1(p_entity_kind, p_entity_id);
  if tenant is null or not app_private.entity_image_can_read_v1(tenant) then
    return '{}'::jsonb;
  end if;
  select coalesce(jsonb_object_agg(a.image_kind, jsonb_build_object('asset_id', a.id, 'content_type', a.mime_type,
    'icon_spec', a.icon_spec)), '{}'::jsonb) into result
  from public.entity_image_assets a
  where a.entity_kind = p_entity_kind and a.entity_id = p_entity_id and a.status = 'active';
  return result;
end
$$;

revoke all on function app_private.entity_image_actor_v1(), app_private.entity_image_tenant_v1(text,uuid), app_private.entity_image_can_manage_v1(text,uuid),
  app_private.entity_image_can_read_v1(uuid) from public, anon, authenticated;
revoke all on function public.superadmin_entity_image_prepare_v1(uuid,text,uuid,text,text,text,bigint,text,jsonb),
  public.superadmin_entity_image_authorize_upload_v1(uuid), public.superadmin_entity_image_authorize_read_v1(uuid),
  public.superadmin_entity_image_remove_v1(uuid), public.superadmin_entity_images_get_v1(text,uuid),
  public.superadmin_entity_image_finalize_v1(uuid,uuid,bigint,text) from public, anon, authenticated;
grant execute on function public.superadmin_entity_image_prepare_v1(uuid,text,uuid,text,text,text,bigint,text,jsonb),
  public.superadmin_entity_image_authorize_upload_v1(uuid), public.superadmin_entity_image_authorize_read_v1(uuid),
  public.superadmin_entity_image_remove_v1(uuid), public.superadmin_entity_images_get_v1(text,uuid) to authenticated;
grant execute on function public.superadmin_entity_image_finalize_v1(uuid,uuid,bigint,text) to service_role;
commit;
