-- R14 Bloco E / owner.r12-46: avatar privado da Conta em R2.
-- O catalogo legado person_avatar_assets continua sendo a fonte de ownership;
-- assets novos usam R2 e carregam tenant para que o gateway negue IDOR/cross-tenant.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'account avatar migration must run as postgres';
  end if;
  if to_regclass('public.person_avatar_assets') is null
    or to_regprocedure('app_private.assert_account_actor()') is null
    or to_regprocedure('app_private.current_person_id()') is null then
    raise object_not_in_prerequisite_state using
      message = 'account profile and avatar catalog are required';
  end if;
end
$preflight$;

alter table public.person_avatar_assets
  add column if not exists storage_provider text not null default 'supabase_legacy',
  add column if not exists tenant_id uuid references public.institutions(id) on delete restrict;

alter table public.person_avatar_assets
  drop constraint if exists person_avatar_assets_bucket_check,
  drop constraint if exists person_avatar_assets_path_check;
alter table public.person_avatar_assets
  add constraint person_avatar_assets_bucket_check check (
    (storage_provider = 'supabase_legacy' and storage_bucket = 'coelo-person-identities')
    or (storage_provider = 'r2' and storage_bucket = 'coelo-media-prod')
  ),
  add constraint person_avatar_assets_path_check check (
    (
      storage_provider = 'supabase_legacy'
      and storage_path ~ '^people/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/avatars/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$'
    ) or (
      storage_provider = 'r2'
      and storage_path ~ '^people/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/avatars/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/original/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$'
    )
  ),
  add constraint person_avatar_assets_r2_tenant_check check (
    storage_provider <> 'r2' or tenant_id is not null
  );
create index if not exists person_avatar_assets_tenant_idx
  on public.person_avatar_assets (tenant_id, person_id, created_at desc);

create table if not exists app_private.superadmin_account_avatar_tickets (
  asset_id uuid primary key references public.person_avatar_assets(id) on delete cascade,
  request_id uuid not null,
  person_id uuid not null references public.people(id) on delete cascade,
  tenant_id uuid not null references public.institutions(id) on delete restrict,
  finalize_ticket uuid not null unique default gen_random_uuid(),
  request_hash bytea not null check (octet_length(request_hash) = 32),
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now(),
  unique (person_id, request_id)
);
alter table app_private.superadmin_account_avatar_tickets enable row level security;
alter table app_private.superadmin_account_avatar_tickets force row level security;
revoke all on table app_private.superadmin_account_avatar_tickets from public, anon, authenticated, service_role;
create index if not exists superadmin_account_avatar_tickets_expiry_idx
  on app_private.superadmin_account_avatar_tickets (expires_at) where used_at is null;

create or replace function app_private.account_avatar_extension_v1(p_content_type text)
returns text language sql immutable security invoker set search_path = '' as $$
  select case lower(p_content_type)
    when 'image/jpeg' then 'jpg' when 'image/png' then 'png' when 'image/webp' then 'webp'
  end
$$;

create or replace function public.superadmin_account_avatar_prepare_v1(
  p_request_id uuid, p_tenant_id uuid, p_file_name text, p_content_type text,
  p_byte_size bigint, p_sha256 text
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  actor_id uuid; existing app_private.superadmin_account_avatar_tickets%rowtype;
  asset public.person_avatar_assets%rowtype; request_hash bytea;
  content_type text := lower(btrim(coalesce(p_content_type, '')));
  file_name text := btrim(coalesce(p_file_name, ''));
  checksum text := lower(btrim(coalesce(p_sha256, '')));
  tenant uuid := p_tenant_id; extension text; asset_id uuid := gen_random_uuid();
begin
  actor_id := app_private.assert_account_actor();
  if tenant is null then
    select membership.scope_institution_id into tenant from public.platform_memberships membership
    where membership.person_id = actor_id and membership.status = 'active' and membership.revoked_at is null
      and membership.scope_kind = 'institution' and membership.scope_institution_id is not null
    order by membership.created_at limit 1;
    if tenant is null then
      select membership.institution_id into tenant from public.institution_memberships membership
      where membership.person_id = actor_id and membership.status = 'active' and membership.revoked_at is null
      order by membership.created_at limit 1;
    end if;
  end if;
  if p_request_id is null or tenant is null or file_name = '' or char_length(file_name) > 255
    or file_name ~ '[[:cntrl:]/\\]' or content_type not in ('image/jpeg','image/png','image/webp')
    or p_byte_size is null or p_byte_size < 1 or p_byte_size > 2097152
    or checksum !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'invalid_account_avatar';
  end if;
  if not exists (
    select 1 from public.platform_memberships membership
    where membership.person_id = actor_id and membership.status = 'active'
      and membership.revoked_at is null
      and (membership.scope_kind = 'platform' or membership.scope_institution_id = tenant)
  ) then
    raise exception using errcode = '42501', message = 'account_avatar_tenant_denied';
  end if;
  request_hash := extensions.digest(convert_to(jsonb_build_object(
    'tenant_id', tenant, 'file_name', file_name, 'content_type', content_type,
    'byte_size', p_byte_size, 'sha256', checksum)::text, 'UTF8'), 'sha256');
  perform pg_advisory_xact_lock(hashtextextended(actor_id::text || p_request_id::text, 0));
  select * into existing from app_private.superadmin_account_avatar_tickets
  where person_id = actor_id and request_id = p_request_id for update;
  if existing.asset_id is not null then
    if existing.request_hash <> request_hash then
      raise exception using errcode = '23505', message = 'account_avatar_request_replay_mismatch';
    end if;
    select * into asset from public.person_avatar_assets where id = existing.asset_id;
  else
    extension := app_private.account_avatar_extension_v1(content_type);
    insert into public.person_avatar_assets(
      id, person_id, tenant_id, storage_provider, storage_bucket, storage_path,
      mime_type, size_bytes, checksum_sha256, pixel_width, pixel_height, crop_rect, status, created_by_person_id
    ) values (
      asset_id, actor_id, tenant, 'r2', 'coelo-media-prod',
      'people/' || actor_id::text || '/avatars/' || asset_id::text || '/original/' || gen_random_uuid()::text || '.' || extension,
      content_type, p_byte_size, checksum, 320, 320,
      jsonb_build_object('x', 0, 'y', 0, 'width', 1, 'height', 1), 'draft', actor_id
    ) returning * into asset;
    insert into app_private.superadmin_account_avatar_tickets(
      asset_id, request_id, person_id, tenant_id, request_hash, expires_at
    ) values (asset.id, p_request_id, actor_id, tenant, request_hash, now() + interval '30 minutes')
    returning * into existing;
    insert into audit.audit_logs(actor_person_id, action_code, object_type, object_id,
      institution_id, outcome, after_json)
    values (actor_id, 'account.avatar.prepare', 'person_avatar_asset', asset.id,
      tenant, 'success', jsonb_build_object('storage_provider', 'r2'));
  end if;
  return jsonb_build_object(
    'asset_id', asset.id, 'object_key', asset.storage_path, 'bucket', asset.storage_bucket,
    'content_type', asset.mime_type, 'byte_size', asset.size_bytes, 'sha256', p_sha256,
    'finalize_ticket', existing.finalize_ticket, 'expires_at', existing.expires_at,
    'upload_status', asset.status, 'replayed', existing.used_at is not null);
end
$$;

create or replace function public.superadmin_account_avatar_authorize_finalize_v1(p_asset_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor_id uuid; ticket app_private.superadmin_account_avatar_tickets%rowtype;
  asset public.person_avatar_assets%rowtype;
begin
  actor_id := app_private.assert_account_actor();
  select t.* into ticket from app_private.superadmin_account_avatar_tickets t
  where t.asset_id = p_asset_id and t.person_id = actor_id for update;
  if ticket.asset_id is null or ticket.used_at is not null or ticket.expires_at < now() then
    raise exception using errcode = '42501', message = 'account_avatar_ticket_denied';
  end if;
  select * into asset from public.person_avatar_assets where id = p_asset_id;
  if asset.status <> 'draft' then
    raise exception using errcode = '42501', message = 'account_avatar_ticket_denied';
  end if;
  return jsonb_build_object('asset_id', asset.id, 'object_key', asset.storage_path,
    'bucket', asset.storage_bucket, 'content_type', asset.mime_type, 'byte_size', asset.size_bytes,
    'sha256', asset.checksum_sha256, 'finalize_ticket', ticket.finalize_ticket,
    'expires_at', ticket.expires_at);
end
$$;

create or replace function public.superadmin_account_avatar_finalize_v1(
  p_asset_id uuid, p_finalize_ticket uuid, p_byte_size bigint, p_checksum_sha256 text
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare ticket app_private.superadmin_account_avatar_tickets%rowtype;
  asset public.person_avatar_assets%rowtype; actor_id uuid;
begin
  if current_setting('request.jwt.claim.role', true) is distinct from 'service_role'
    and coalesce(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role' is distinct from 'service_role' then
    raise exception using errcode = '42501', message = 'permission_denied';
  end if;
  select * into ticket from app_private.superadmin_account_avatar_tickets
  where asset_id = p_asset_id and finalize_ticket = p_finalize_ticket for update;
  if ticket.asset_id is null or ticket.used_at is not null or ticket.expires_at < now() then
    raise exception using errcode = '42501', message = 'account_avatar_ticket_denied';
  end if;
  select * into asset from public.person_avatar_assets where id = p_asset_id for update;
  if asset.status <> 'draft' then raise exception using errcode = '42501', message = 'account_avatar_ticket_denied'; end if;
  if p_byte_size is distinct from asset.size_bytes
    or lower(coalesce(p_checksum_sha256, '')) is distinct from lower(coalesce(asset.checksum_sha256, '')) then
    update public.person_avatar_assets set status = 'inactive', revoked_at = now() where id = asset.id;
    update app_private.superadmin_account_avatar_tickets set used_at = now() where asset_id = asset.id;
    raise exception using errcode = '22023', message = 'account_avatar_mismatch';
  end if;
  actor_id := ticket.person_id;
  update public.person_avatar_assets set status = 'inactive', revoked_at = now()
    where person_id = actor_id and status = 'active' and id <> asset.id;
  update public.person_avatar_assets set status = 'active', checksum_sha256 = lower(p_checksum_sha256), activated_at = now()
    where id = asset.id returning * into asset;
  update app_private.superadmin_account_avatar_tickets set used_at = now() where asset_id = asset.id;
  insert into audit.audit_logs(actor_person_id, action_code, object_type, object_id,
    institution_id, outcome, after_json)
  values (actor_id, 'account.avatar.finalize', 'person_avatar_asset', asset.id,
    asset.tenant_id, 'success', jsonb_build_object('storage_provider', 'r2'));
  return jsonb_build_object('asset_id', asset.id, 'status', 'active');
end
$$;

create or replace function public.superadmin_account_avatar_authorize_read_v1(p_asset_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor_id uuid; asset public.person_avatar_assets%rowtype;
begin
  actor_id := app_private.assert_account_actor();
  select * into asset from public.person_avatar_assets
  where id = p_asset_id and person_id = actor_id and storage_provider = 'r2' and status = 'active';
  if asset.id is null or not exists (
    select 1 from public.platform_memberships membership
    where membership.person_id = actor_id and membership.status = 'active'
      and membership.revoked_at is null
      and (membership.scope_kind = 'platform' or membership.scope_institution_id = asset.tenant_id)
  ) then
    raise exception using errcode = '42501', message = 'account_avatar_read_denied';
  end if;
  insert into audit.audit_logs(actor_person_id, action_code, object_type, object_id,
    institution_id, outcome)
  values (actor_id, 'account.avatar.read', 'person_avatar_asset', asset.id,
    asset.tenant_id, 'success');
  return jsonb_build_object('asset_id', asset.id, 'object_key', asset.storage_path,
    'bucket', asset.storage_bucket, 'content_type', asset.mime_type, 'byte_size', asset.size_bytes,
    'ttl_seconds', 120);
end
$$;

create or replace function public.superadmin_account_avatar_remove_v1(p_asset_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor_id uuid; asset public.person_avatar_assets%rowtype;
begin
  actor_id := app_private.assert_account_actor();
  select * into asset from public.person_avatar_assets
  where id = p_asset_id and person_id = actor_id and status = 'active';
  if asset.id is null or not exists (
    select 1 from public.platform_memberships membership
    where membership.person_id = actor_id and membership.status = 'active'
      and membership.revoked_at is null
      and (membership.scope_kind = 'platform' or membership.scope_institution_id = asset.tenant_id)
  ) then
    raise exception using errcode = '42501', message = 'account_avatar_remove_denied';
  end if;
  update public.person_avatar_assets set status = 'inactive', revoked_at = now()
  where id = asset.id returning * into asset;
  insert into audit.audit_logs(actor_person_id, action_code, object_type, object_id,
    institution_id, outcome)
  values (actor_id, 'account.avatar.remove', 'person_avatar_asset', asset.id,
    asset.tenant_id, 'success');
  return jsonb_build_object('asset_id', asset.id, 'status', 'revoked', 'object_key', asset.storage_path);
end
$$;

create or replace function public.superadmin_account_avatar_expire_v1(p_limit integer default 100)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare item record; expired integer := 0; items jsonb := '[]'::jsonb;
begin
  if current_setting('request.jwt.claim.role', true) is distinct from 'service_role'
    and coalesce(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role' is distinct from 'service_role' then
    raise exception using errcode = '42501', message = 'permission_denied';
  end if;
  for item in select t.asset_id, a.storage_path from app_private.superadmin_account_avatar_tickets t
    join public.person_avatar_assets a on a.id = t.asset_id
    where t.used_at is null and t.expires_at < now() and a.status = 'draft'
    order by t.expires_at limit least(greatest(coalesce(p_limit, 100), 1), 500) for update of t skip locked
  loop
    update public.person_avatar_assets set status = 'inactive', revoked_at = now() where id = item.asset_id;
    update app_private.superadmin_account_avatar_tickets set used_at = now() where asset_id = item.asset_id;
    items := items || jsonb_build_array(jsonb_build_object('asset_id', item.asset_id, 'object_key', item.storage_path));
    expired := expired + 1;
  end loop;
  return jsonb_build_object('expired', expired, 'items', items);
end
$$;

create or replace function app_private.account_profile_projection(p_person_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result jsonb; email_value text; pending jsonb; role_value text; avatar_asset public.person_avatar_assets%rowtype;
begin
  select u.email into email_value from auth.users u join public.person_auth_links link on link.auth_user_id = u.id
    where link.person_id = p_person_id and link.status = 'active' order by link.linked_at desc limit 1;
  if email_value is null and p_person_id = app_private.current_person_id() then
    select u.email into email_value from auth.users u where u.id = auth.uid();
  end if;
  select jsonb_build_object('requested_email', request.requested_email, 'status', request.status,
    'requested_at', request.requested_at) into pending from public.account_email_change_requests request
    where request.person_id = p_person_id and request.status = 'pending' order by request.requested_at desc limit 1;
  select coalesce(role.name, role.code, 'Acesso interno') into role_value from public.platform_memberships membership
    join public.platform_roles role on role.id = membership.role_id
    where membership.person_id = p_person_id and membership.status = 'active' order by membership.created_at limit 1;
  select * into avatar_asset from public.person_avatar_assets where person_id = p_person_id
    and storage_provider = 'r2' and status = 'active' and revoked_at is null order by activated_at desc limit 1;
  select jsonb_build_object('avatar_contract_version', 3, 'first_name', person.first_name, 'last_name', person.last_name,
    'email', coalesce(email_value, ''), 'mobile_phone', coalesce(person.mobile_phone, ''),
    'avatar', jsonb_build_object('mode', case when avatar_asset.id is null then 'initials' else 'photo' end,
      'asset_id', avatar_asset.id, 'initials', coalesce(person.account_avatar_initials,
        left(upper(coalesce(nullif(left(trim(person.first_name), 1), ''), '') || coalesce(nullif(left(trim(person.last_name), 1), ''), '')), 2)),
      'background_color', coalesce(person.account_avatar_background_color, '#FFF1EB')),
    'access', jsonb_build_object('role', coalesce(role_value, 'Acesso interno'),
      'mfa_enabled', coalesce((select auth.jwt()->>'aal') = 'aal2', false),
      'capabilities', coalesce((select jsonb_agg(distinct permission.description) from public.platform_permissions permission
        where permission.status='active' and exists (select 1 from public.platform_memberships membership
          where membership.person_id=p_person_id and membership.status='active' and membership.revoked_at is null
            and app_private.has_platform_permission(permission.code,membership.scope_institution_id))), '[]'::jsonb),
      'capability_details', coalesce((select jsonb_agg(item order by item->>'module_label',item->>'scope_label',item->>'label') from (
        select distinct jsonb_build_object('code',permission.code,'label',permission.description,'module_code',permission.module_code,
          'module_label',permission.module_label,'scope_kind',membership.scope_kind,'scope_id',membership.scope_institution_id,
          'scope_label',case when membership.scope_kind='platform' then 'Plataforma' else institution.public_name end) item
        from public.platform_memberships membership join public.platform_roles role on role.id=membership.role_id and role.status='active'
          cross join public.platform_permissions permission left join public.institutions institution on institution.id=membership.scope_institution_id
        where membership.person_id=p_person_id and membership.status='active' and membership.revoked_at is null
          and permission.status='active' and app_private.has_platform_permission(permission.code,membership.scope_institution_id)) items), '[]'::jsonb)),
    'email_change', pending) into result from public.people person where person.id = p_person_id and person.deleted_at is null;
  if result is null then raise exception using errcode = 'P0002', message = 'account_profile_not_found'; end if;
  return result;
end
$$;
revoke all on function app_private.account_avatar_extension_v1(text) from public, anon, authenticated;
revoke all on function public.superadmin_account_avatar_prepare_v1(uuid,uuid,text,text,bigint,text), public.superadmin_account_avatar_authorize_finalize_v1(uuid),
  public.superadmin_account_avatar_authorize_read_v1(uuid), public.superadmin_account_avatar_remove_v1(uuid) from public, anon;
revoke all on function public.superadmin_account_avatar_expire_v1(integer) from public, anon, authenticated;
revoke all on function public.superadmin_account_avatar_finalize_v1(uuid,uuid,bigint,text) from public, anon, authenticated;
grant execute on function public.superadmin_account_avatar_prepare_v1(uuid,uuid,text,text,bigint,text), public.superadmin_account_avatar_authorize_finalize_v1(uuid),
  public.superadmin_account_avatar_authorize_read_v1(uuid), public.superadmin_account_avatar_remove_v1(uuid) to authenticated;
grant execute on function public.superadmin_account_avatar_finalize_v1(uuid,uuid,bigint,text) to service_role;
grant execute on function public.superadmin_account_avatar_expire_v1(integer) to service_role;
comment on table public.person_avatar_assets is 'Private avatar catalog: legacy rows remain Supabase metadata; new rows are R2-only and never expose public URLs.';
commit;
