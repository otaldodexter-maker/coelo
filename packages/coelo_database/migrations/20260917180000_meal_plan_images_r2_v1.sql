-- R15 Bloco C2 / owner.r12-38 (R12-cardapios-owner.md, ADR 0032): imagens de
-- Cardapios em R2 privado pelo Media Gateway. Contrato em
-- specs/063-superadmin-meal-plan-images-r2.md.
--
-- (1) meal_plan_image_assets.storage_provider ('supabase_mvp' legado | 'r2'),
--     bucket 'coelo-media-prod' para r2, gatilho de guarda aceita a chave
--     canonica R2 (tenants/<tenant>/meal_plans/<kind>/<id>/image/<asset>/original/<uuid>.<ext>).
-- (2) RPCs v2: prepare (descritor R2), authorize_finalize (bilhete),
--     finalize (service_role, apos o gateway verificar os bytes), read
--     descriptor. As v1 permanecem intactas para o legado.
-- (3) claim/complete cleanup e request_image_delete_unreceipted: corpo de
--     producao (dump 20260917, SHA-256 c87f4d67) + condicao por provedor.
-- Forward-only e idempotente. Nenhum SQLSTATE 40001.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'meal plan images r2 v1 must run as postgres';
  end if;
  if to_regclass('public.meal_plan_image_assets') is null
    or to_regclass('app_private.meal_plan_image_upload_intents') is null
    or to_regclass('app_private.meal_plan_image_delete_requests') is null
    or to_regprocedure('app_private.meal_plan_scope_allowed(uuid,uuid)') is null
    or to_regprocedure('app_private.meal_plan_image_parent_status(public.meal_plan_image_assets)') is null
    or to_regprocedure('app_private.meal_plan_request_hash(jsonb)') is null
    or to_regprocedure('public.meal_plan_claim_image_cleanup(integer)') is null
    or to_regprocedure('public.meal_plan_complete_image_cleanup(uuid,boolean,text)') is null
    or to_regprocedure('app_private.meal_plan_request_image_delete_unreceipted(uuid,uuid)') is null then
    raise object_not_in_prerequisite_state using message = 'meal plan image objects are required';
  end if;
end
$preflight$;

-- (1) Provedor e bucket.
alter table public.meal_plan_image_assets
  add column if not exists storage_provider text not null default 'supabase_mvp';
alter table public.meal_plan_image_assets drop constraint if exists meal_plan_image_assets_storage_provider_check;
alter table public.meal_plan_image_assets add constraint meal_plan_image_assets_storage_provider_check
  check (storage_provider in ('supabase_mvp', 'r2'));
alter table public.meal_plan_image_assets drop constraint if exists meal_plan_image_assets_storage_bucket_check;
alter table public.meal_plan_image_assets add constraint meal_plan_image_assets_storage_bucket_check check (
  (storage_provider = 'supabase_mvp' and storage_bucket = 'coelo-meal-plans-private')
  or (storage_provider = 'r2' and storage_bucket = 'coelo-media-prod'));

create or replace function app_private.meal_plan_image_asset_parent_guard() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  parent_tenant uuid;
  parent_institution uuid;
  parent_plan uuid;
  expected_path text;
  resource_id uuid;
  extension text;
begin
  extension := case new.mime_type
    when 'image/jpeg' then 'jpg'
    when 'image/png' then 'png'
    when 'image/webp' then 'webp'
    else null
  end;

  if new.resource_kind = 'meal_plan' then
    select plan.tenant_id, plan.institution_id, plan.id
      into parent_tenant, parent_institution, parent_plan
    from public.meal_plans plan
    where plan.id = new.meal_plan_id;
    resource_id := new.meal_plan_id;
    expected_path := 'meal-plans/' || new.meal_plan_id::text || '/' ||
      new.id::text || '.' || extension;
  elsif new.resource_kind = 'template' then
    select template.tenant_id, template.institution_id
      into parent_tenant, parent_institution
    from public.meal_plan_templates template
    where template.id = new.template_id;
    resource_id := new.template_id;
    expected_path := 'meal-plan-templates/' || new.template_id::text || '/' ||
      new.id::text || '.' || extension;
  elsif new.resource_kind = 'meal' then
    select plan.tenant_id, plan.institution_id, plan.id
      into parent_tenant, parent_institution, parent_plan
    from public.meal_plan_meals meal
    join public.meal_plans plan
      on plan.id = meal.meal_plan_id and plan.tenant_id = meal.tenant_id
    where meal.id = new.meal_id;
    resource_id := new.meal_id;
    expected_path := 'meal-plans/' || parent_plan::text || '/meals/' ||
      new.meal_id::text || '/' || new.id::text || '.' || extension;
  elsif new.resource_kind = 'meal_item' then
    select plan.tenant_id, plan.institution_id, plan.id
      into parent_tenant, parent_institution, parent_plan
    from public.meal_plan_meal_items item
    join public.meal_plan_meals meal
      on meal.id = item.meal_id and meal.tenant_id = item.tenant_id
    join public.meal_plans plan
      on plan.id = meal.meal_plan_id and plan.tenant_id = meal.tenant_id
    where item.id = new.meal_item_id;
    resource_id := new.meal_item_id;
    expected_path := 'meal-plans/' || parent_plan::text || '/meal-items/' ||
      new.meal_item_id::text || '/' || new.id::text || '.' || extension;
  end if;

  if parent_tenant is null or extension is null then
    raise foreign_key_violation using message = 'meal plan image parent not found';
  end if;
  if new.tenant_id is distinct from parent_tenant
      or new.institution_id is distinct from parent_institution then
    raise check_violation using message = 'meal plan image parent scope mismatch';
  end if;
  if new.storage_provider = 'r2' then
    -- Chave opaca canonica da ADR 0032; o object_uuid final e livre.
    if new.storage_bucket <> 'coelo-media-prod'
        or new.storage_path !~ ('^tenants/' || new.tenant_id::text || '/meal_plans/' || new.resource_kind
          || '/' || resource_id::text || '/image/' || new.id::text
          || '/original/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.]' || extension || '$') then
      raise check_violation using message = 'meal plan image storage path mismatch';
    end if;
    return new;
  end if;
  if new.storage_bucket <> 'coelo-meal-plans-private'
      or new.storage_path is distinct from expected_path then
    raise check_violation using message = 'meal plan image storage path mismatch';
  end if;
  return new;
end;
$$;

create table if not exists app_private.meal_plan_image_finalize_tickets (
  token_hash text primary key check (token_hash ~ '^[0-9a-f]{64}$'),
  request_id uuid not null,
  asset_id uuid not null references public.meal_plan_image_assets(id) on delete cascade,
  actor_person_id uuid not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
alter table app_private.meal_plan_image_finalize_tickets enable row level security;
alter table app_private.meal_plan_image_finalize_tickets force row level security;
revoke all on table app_private.meal_plan_image_finalize_tickets from public, anon, authenticated;

-- (2a) Prepare v2: identico ao v1 exceto provedor/bucket/chave.
create or replace function app_private.meal_plan_prepare_image_upload_v2(
  p_resource_kind text, p_resource_id uuid, p_file_name text, p_mime_type text,
  p_size_bytes bigint, p_alt_text text, p_idempotency_key uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := app_private.current_person_id();
  asset_id uuid;
  parent_tenant uuid;
  parent_institution uuid;
  parent_plan uuid;
  extension text;
  object_key text;
  expires_at timestamptz := now() + interval '10 minutes';
  prior app_private.meal_plan_image_upload_intents%rowtype;
  prior_asset public.meal_plan_image_assets%rowtype;
begin
  if auth.uid() is null or actor_id is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  if not app_private.has_platform_permission('meal_plans.manage') then
    raise insufficient_privilege using message = 'meal_plans.manage required';
  end if;
  if p_resource_kind not in ('meal_plan', 'template', 'meal', 'meal_item')
      or p_resource_id is null or p_idempotency_key is null
      or nullif(btrim(p_file_name), '') is null or length(p_file_name) > 180
      or p_mime_type not in ('image/jpeg', 'image/png', 'image/webp')
      or p_size_bytes not between 1 and 2097152
      or (p_alt_text is not null and length(p_alt_text) > 500) then
    raise invalid_parameter_value using message = 'invalid meal plan image upload';
  end if;

  if p_resource_kind = 'meal_plan' then
    select plan.tenant_id, plan.institution_id, plan.id
      into parent_tenant, parent_institution, parent_plan
    from public.meal_plans plan where plan.id = p_resource_id;
  elsif p_resource_kind = 'template' then
    select template.tenant_id, template.institution_id
      into parent_tenant, parent_institution
    from public.meal_plan_templates template where template.id = p_resource_id;
  elsif p_resource_kind = 'meal' then
    select plan.tenant_id, plan.institution_id, plan.id
      into parent_tenant, parent_institution, parent_plan
    from public.meal_plan_meals meal
    join public.meal_plans plan
      on plan.id = meal.meal_plan_id and plan.tenant_id = meal.tenant_id
    where meal.id = p_resource_id;
  else
    select plan.tenant_id, plan.institution_id, plan.id
      into parent_tenant, parent_institution, parent_plan
    from public.meal_plan_meal_items item
    join public.meal_plan_meals meal
      on meal.id = item.meal_id and meal.tenant_id = item.tenant_id
    join public.meal_plans plan
      on plan.id = meal.meal_plan_id and plan.tenant_id = meal.tenant_id
    where item.id = p_resource_id;
  end if;

  if parent_tenant is null then
    raise no_data_found using message = 'meal plan image parent not found';
  end if;
  if not app_private.meal_plan_scope_allowed(parent_tenant, parent_institution) then
    raise insufficient_privilege using message = 'meal plan image scope denied';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key::text, 0));
  select * into prior
  from app_private.meal_plan_image_upload_intents intent
  where intent.request_id = p_idempotency_key;
  if prior.request_id is not null then
    select * into prior_asset
    from public.meal_plan_image_assets asset where asset.id = prior.asset_id;
    if prior.actor_person_id <> actor_id
        or prior.mime_type <> p_mime_type
        or prior.size_bytes <> p_size_bytes
        or prior_asset.storage_provider <> 'r2'
        or prior_asset.resource_kind <> p_resource_kind
        or coalesce(prior_asset.meal_plan_id, prior_asset.template_id,
          prior_asset.meal_id, prior_asset.meal_item_id) <> p_resource_id
        or prior_asset.alt_text is distinct from nullif(btrim(p_alt_text), '') then
      raise invalid_parameter_value using message = 'idempotency key reused';
    end if;
    return jsonb_build_object(
      'asset_id', prior.asset_id,
      'storage_provider', 'r2',
      'bucket_id', prior_asset.storage_bucket,
      'object_key', prior.storage_path,
      'mime_type', prior.mime_type,
      'max_bytes', 2097152,
      'expires_at', prior.expires_at
    );
  end if;

  asset_id := gen_random_uuid();
  extension := case p_mime_type
    when 'image/jpeg' then 'jpg'
    when 'image/png' then 'png'
    else 'webp'
  end;
  object_key := 'tenants/' || parent_tenant::text || '/meal_plans/' || p_resource_kind || '/'
    || p_resource_id::text || '/image/' || asset_id::text || '/original/' || gen_random_uuid()::text
    || '.' || extension;

  insert into public.meal_plan_image_assets (
    id, tenant_id, institution_id, resource_kind, meal_plan_id, template_id,
    meal_id, meal_item_id, storage_provider, storage_bucket, storage_path, mime_type,
    size_bytes, alt_text, created_by
  ) values (
    asset_id, parent_tenant, parent_institution, p_resource_kind,
    case when p_resource_kind = 'meal_plan' then p_resource_id end,
    case when p_resource_kind = 'template' then p_resource_id end,
    case when p_resource_kind = 'meal' then p_resource_id end,
    case when p_resource_kind = 'meal_item' then p_resource_id end,
    'r2', 'coelo-media-prod', object_key, p_mime_type, p_size_bytes,
    nullif(btrim(p_alt_text), ''), actor_id
  );

  insert into app_private.meal_plan_image_upload_intents (
    request_id, asset_id, actor_person_id, storage_path, mime_type,
    size_bytes, expires_at
  ) values (
    p_idempotency_key, asset_id, actor_id, object_key, p_mime_type,
    p_size_bytes, expires_at
  );

  insert into audit.audit_logs (
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor_id, auth.jwt()->>'aal', 'meal_plan.image.upload.prepare',
    'meal_plan_image_asset', asset_id, parent_institution, 'success',
    jsonb_build_object('resource_kind', p_resource_kind,
      'resource_id', p_resource_id, 'storage_provider', 'r2', 'bucket', 'coelo-media-prod',
      'path', object_key, 'mime_type', p_mime_type, 'size_bytes', p_size_bytes)
  );

  return jsonb_build_object(
    'asset_id', asset_id,
    'storage_provider', 'r2',
    'bucket_id', 'coelo-media-prod',
    'object_key', object_key,
    'mime_type', p_mime_type,
    'max_bytes', 2097152,
    'expires_at', expires_at
  );
end;
$$;
revoke all on function app_private.meal_plan_prepare_image_upload_v2(text, uuid, text, text, bigint, text, uuid) from public, anon, authenticated;
create or replace function public.meal_plan_prepare_image_upload_v2(
  p_resource_kind text, p_resource_id uuid, p_file_name text, p_mime_type text,
  p_size_bytes bigint, p_alt_text text, p_idempotency_key uuid)
returns jsonb language sql security definer set search_path = ''
as $$
  select app_private.meal_plan_prepare_image_upload_v2(
    p_resource_kind, p_resource_id, p_file_name, p_mime_type, p_size_bytes, p_alt_text, p_idempotency_key);
$$;
revoke all on function public.meal_plan_prepare_image_upload_v2(text, uuid, text, text, bigint, text, uuid) from public, anon;
grant execute on function public.meal_plan_prepare_image_upload_v2(text, uuid, text, text, bigint, text, uuid) to authenticated, service_role;

-- (2b) Bilhete de finalize (JWT do usuario, dono da intencao).
create or replace function public.meal_plan_authorize_image_finalize_v2(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := app_private.current_person_id();
  intent app_private.meal_plan_image_upload_intents%rowtype;
  asset public.meal_plan_image_assets%rowtype;
  ticket uuid := gen_random_uuid();
  ticket_expires timestamptz := now() + interval '2 minutes';
begin
  if auth.uid() is null or actor_id is null or p_request_id is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  select * into intent from app_private.meal_plan_image_upload_intents candidate
  where candidate.request_id = p_request_id;
  if intent.request_id is null or intent.actor_person_id <> actor_id then
    raise no_data_found using message = 'meal plan image upload intent not found';
  end if;
  select * into asset from public.meal_plan_image_assets candidate where candidate.id = intent.asset_id;
  if asset.id is null or asset.storage_provider <> 'r2'
      or not app_private.has_platform_permission('meal_plans.manage')
      or not app_private.meal_plan_scope_allowed(asset.tenant_id, asset.institution_id) then
    raise insufficient_privilege using message = 'meal plan image finalization denied';
  end if;
  delete from app_private.meal_plan_image_finalize_tickets t where t.expires_at <= now();
  delete from app_private.meal_plan_image_finalize_tickets t where t.request_id = p_request_id;
  insert into app_private.meal_plan_image_finalize_tickets (token_hash, request_id, asset_id, actor_person_id, expires_at)
  values (encode(extensions.digest(convert_to(ticket::text, 'UTF8'), 'sha256'), 'hex'), p_request_id, asset.id, actor_id, ticket_expires);
  return jsonb_build_object('finalize_ticket', ticket, 'expires_at', ticket_expires,
    'asset_id', asset.id, 'storage_provider', asset.storage_provider, 'bucket_id', asset.storage_bucket,
    'object_key', asset.storage_path, 'mime_type', asset.mime_type, 'byte_size', asset.size_bytes,
    'already_active', asset.status = 'active');
end;
$$;
revoke all on function public.meal_plan_authorize_image_finalize_v2(uuid) from public, anon;
grant execute on function public.meal_plan_authorize_image_finalize_v2(uuid) to authenticated, service_role;

-- (2c) Finalize v2 (service_role): o gateway ja releu os bytes no R2.
create or replace function public.meal_plan_finalize_image_upload_v2(
  p_request_id uuid, p_finalize_ticket uuid, p_byte_size bigint, p_mime_type text,
  p_checksum_sha256 text, p_alt_text text default null, p_replace_asset_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  intent app_private.meal_plan_image_upload_intents%rowtype;
  asset public.meal_plan_image_assets%rowtype;
  previous public.meal_plan_image_assets%rowtype;
  consumed app_private.meal_plan_image_finalize_tickets%rowtype;
  request_hash text;
  cleanup_request_id uuid;
  result_payload jsonb;
begin
  if auth.role() <> 'service_role' then
    raise insufficient_privilege using message = 'service role required';
  end if;
  select candidate.* into intent from app_private.meal_plan_image_upload_intents candidate
  where candidate.request_id = p_request_id;
  if not found then raise no_data_found using message = 'meal plan image upload intent not found'; end if;
  select candidate.* into asset from public.meal_plan_image_assets candidate where candidate.id = intent.asset_id;
  if not found then raise no_data_found using message = 'meal plan image not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended(asset.id::text, 0));
  select candidate.* into intent from app_private.meal_plan_image_upload_intents candidate
  where candidate.request_id = p_request_id for update;
  select candidate.* into asset from public.meal_plan_image_assets candidate
  where candidate.id = intent.asset_id for update;

  request_hash := app_private.meal_plan_request_hash(jsonb_build_object(
    'checksum_sha256', p_checksum_sha256,
    'alt_text', nullif(btrim(p_alt_text), ''),
    'replace_asset_id', p_replace_asset_id
  ));
  if intent.consumed_at is not null then
    if intent.finalize_payload_hash is distinct from request_hash then
      raise invalid_parameter_value using message = 'finalization payload changed';
    end if;
    return intent.finalize_result_json;
  end if;

  delete from app_private.meal_plan_image_finalize_tickets t
  where t.token_hash = encode(extensions.digest(convert_to(p_finalize_ticket::text, 'UTF8'), 'sha256'), 'hex')
    and t.request_id = p_request_id and t.asset_id = asset.id and t.expires_at > now()
  returning t.* into consumed;
  if consumed.asset_id is null then
    raise insufficient_privilege using message = 'finalize ticket invalid';
  end if;
  if asset.storage_provider <> 'r2' or intent.expires_at <= now() or asset.status <> 'pending' then
    raise invalid_parameter_value using message = 'meal plan image upload intent expired';
  end if;
  if p_byte_size <> intent.size_bytes or p_mime_type <> intent.mime_type
      or p_checksum_sha256 !~ '^[0-9a-f]{64}$'
      or (p_alt_text is not null and length(p_alt_text) > 500) then
    raise invalid_parameter_value using message = 'uploaded object metadata mismatch';
  end if;
  if app_private.meal_plan_image_parent_status(asset)
      not in ('draft', 'inReview', 'updated', 'archived') then
    raise invalid_parameter_value using message = 'meal plan image parent is immutable';
  end if;

  if p_replace_asset_id is not null then
    select * into previous
    from public.meal_plan_image_assets candidate
    where candidate.id = p_replace_asset_id
      and candidate.tenant_id = asset.tenant_id
      and candidate.resource_kind = asset.resource_kind
      and coalesce(candidate.meal_plan_id, candidate.template_id,
        candidate.meal_id, candidate.meal_item_id)
        = coalesce(asset.meal_plan_id, asset.template_id, asset.meal_id, asset.meal_item_id)
      and candidate.status = 'active'
    for update;
    if previous.id is null then
      raise invalid_parameter_value using message = 'replacement image is invalid';
    end if;
  end if;

  update public.meal_plan_image_assets
  set status = 'active',
      checksum_sha256 = p_checksum_sha256,
      alt_text = coalesce(nullif(btrim(p_alt_text), ''), alt_text),
      replaced_asset_id = previous.id,
      activated_at = now()
  where id = asset.id
  returning * into asset;

  if previous.id is not null then
    cleanup_request_id := gen_random_uuid();
    update public.meal_plan_image_assets
    set status = 'pending_delete', pending_delete_at = now(), revision = revision + 1
    where id = previous.id;
    insert into app_private.meal_plan_image_delete_requests (
      request_id, asset_id, actor_person_id, storage_path, expected_revision, payload_hash, result_json
    ) values (
      cleanup_request_id, previous.id, consumed.actor_person_id, previous.storage_path,
      previous.revision, app_private.meal_plan_request_hash(jsonb_build_object('replaced_by', asset.id)),
      jsonb_build_object('asset_id', previous.id, 'bucket', previous.storage_bucket,
        'delete_path', previous.storage_path, 'confirmed', false)
    );
  end if;

  result_payload := to_jsonb(asset) || jsonb_build_object(
    'cleanup_request_id', cleanup_request_id,
    'cleanup_asset_id', previous.id,
    'cleanup_path', previous.storage_path
  );
  update app_private.meal_plan_image_upload_intents
  set consumed_at = now(), checksum_sha256 = p_checksum_sha256,
      finalize_payload_hash = request_hash, finalize_result_json = result_payload
  where request_id = intent.request_id;

  insert into audit.audit_logs (
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    consumed.actor_person_id, 'aal1', 'meal_plan.image.upload.finalize',
    'meal_plan_image_asset', asset.id, asset.institution_id, 'success',
    result_payload
  );
  return result_payload;
end;
$$;
revoke all on function public.meal_plan_finalize_image_upload_v2(uuid, uuid, bigint, text, text, text, uuid) from public, anon, authenticated;
grant execute on function public.meal_plan_finalize_image_upload_v2(uuid, uuid, bigint, text, text, text, uuid) to service_role;

-- (2d) Descritor de leitura v2 (sem URL).
create or replace function public.meal_plan_image_read_descriptor_v2(p_asset_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  asset public.meal_plan_image_assets%rowtype;
begin
  select * into asset
  from public.meal_plan_image_assets candidate
  where candidate.id = p_asset_id and candidate.status = 'active';
  if asset.id is null then
    raise no_data_found using message = 'meal plan image not found';
  end if;
  if auth.uid() is null
      or not app_private.has_platform_permission('meal_plans.read')
      or not app_private.meal_plan_scope_allowed(asset.tenant_id, asset.institution_id) then
    raise insufficient_privilege using message = 'meal_plans.read required';
  end if;
  return jsonb_build_object(
    'asset_id', asset.id,
    'storage_provider', asset.storage_provider,
    'bucket_id', asset.storage_bucket,
    'object_key', asset.storage_path,
    'mime_type', asset.mime_type,
    'alt_text', asset.alt_text,
    'expires_in_seconds', 300
  );
end;
$$;
revoke all on function public.meal_plan_image_read_descriptor_v2(uuid) from public, anon;
grant execute on function public.meal_plan_image_read_descriptor_v2(uuid) to authenticated, service_role;

-- (3) Limpeza e exclusao: corpo de producao + condicao por provedor.
-- Corpo de producao (dump 20260917, SHA-256 c87f4d67); apenas a condicao por provedor mudou.
CREATE OR REPLACE FUNCTION "public"."meal_plan_claim_image_cleanup"("p_limit" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare result_payload jsonb;
begin
  if auth.role() <> 'service_role' then
    raise insufficient_privilege using message = 'service role required';
  end if;
  if p_limit not between 1 and 100 then
    raise invalid_parameter_value using message = 'invalid cleanup limit';
  end if;

  update app_private.meal_plan_image_delete_requests request
  set state = 'cancelled',
      last_error = 'asset is active or no longer pending deletion'
  from public.meal_plan_image_assets asset
  where asset.id = request.asset_id
    and request.state in ('pending', 'processing', 'failed')
    and (
      asset.status <> 'pending_delete'
      or asset.storage_path <> request.storage_path
      or exists (
        select 1 from public.meal_plan_image_assets active_asset
        where active_asset.storage_bucket = asset.storage_bucket
          and active_asset.storage_path = asset.storage_path
          and active_asset.status = 'active'
      )
    );

  with candidates as (
    select request.request_id
    from app_private.meal_plan_image_delete_requests request
    join public.meal_plan_image_assets asset on asset.id = request.asset_id
    where (
        request.state in ('pending', 'failed')
        or (request.state = 'processing'
          and request.claimed_at < now() - interval '15 minutes')
      )
      and request.available_at <= now()
      and request.attempts < 10
      and asset.status = 'pending_delete'
      and asset.storage_path = request.storage_path
      and pg_try_advisory_xact_lock(hashtextextended(asset.id::text, 0))
    order by request.created_at
    for update of request skip locked
    limit p_limit
  ), claimed as (
    update app_private.meal_plan_image_delete_requests request
    set state = 'processing',
        claimed_at = now(),
        attempts = attempts + 1
    from candidates
    where request.request_id = candidates.request_id
    returning request.*
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'request_id', claimed.request_id,
    'asset_id', claimed.asset_id,
    'storage_provider', asset_row.storage_provider,
    'bucket', asset_row.storage_bucket,
    'path', claimed.storage_path,
    'attempt', claimed.attempts
  ) order by claimed.created_at), '[]'::jsonb)
  into result_payload
  from claimed
  join public.meal_plan_image_assets asset_row on asset_row.id = claimed.asset_id;
  return result_payload;
end;
$$;

-- Corpo de producao (dump 20260917, SHA-256 c87f4d67); apenas a condicao por provedor mudou.
CREATE OR REPLACE FUNCTION "public"."meal_plan_complete_image_cleanup"("p_request_id" "uuid", "p_succeeded" boolean, "p_error" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  request app_private.meal_plan_image_delete_requests%rowtype;
  asset public.meal_plan_image_assets%rowtype;
  object_exists boolean;
begin
  if auth.role() <> 'service_role' then
    raise insufficient_privilege using message = 'service role required';
  end if;
  select candidate.* into request
  from app_private.meal_plan_image_delete_requests candidate
  where candidate.request_id = p_request_id
  for update;
  if not found then raise no_data_found using message = 'cleanup request not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended(request.asset_id::text, 0));
  select candidate.* into asset
  from public.meal_plan_image_assets candidate
  where candidate.id = request.asset_id
  for update;
  if request.state = 'completed' then return request.result_json; end if;
  if request.state <> 'processing' then
    raise invalid_parameter_value using message = 'cleanup request is not processing';
  end if;

  if p_succeeded then
    -- R2: o gateway confirmou a exclusao; storage.objects so existe no legado.
    select asset.storage_provider = 'supabase_mvp' and exists (
      select 1 from storage.objects object_record
      where object_record.bucket_id = asset.storage_bucket
        and object_record.name = asset.storage_path
    ) into object_exists;
    if object_exists then
      raise invalid_parameter_value using message = 'meal plan image object still exists';
    end if;
    if asset.status <> 'pending_delete' or asset.storage_path <> request.storage_path
        or exists (
          select 1 from public.meal_plan_image_assets active_asset
          where active_asset.storage_bucket = asset.storage_bucket
            and active_asset.storage_path = asset.storage_path
            and active_asset.status = 'active'
        ) then
      update app_private.meal_plan_image_delete_requests
      set state = 'cancelled',
          completed_at = now(),
          last_error = 'asset is active or no longer pending deletion',
          result_json = result_json || jsonb_build_object(
            'confirmed', false,
            'cancelled', true,
            'reason', 'asset is active or no longer pending deletion'
          )
      where request_id = request.request_id;
      return request.result_json || jsonb_build_object(
        'confirmed', false,
        'cancelled', true,
        'reason', 'asset is active or no longer pending deletion'
      );
    end if;
    update public.meal_plan_image_assets
    set status = 'deleted',
        deleted_at = now(),
        revision = revision + 1
    where id = asset.id;
    update app_private.meal_plan_image_delete_requests
    set state = 'completed',
        confirmed_at = now(),
        completed_at = now(),
        last_error = null,
        result_json = result_json || jsonb_build_object('confirmed', true)
    where request_id = request.request_id
    returning * into request;
  else
    update app_private.meal_plan_image_delete_requests
    set state = case when attempts >= 10 then 'failed' else 'pending' end,
        available_at = now() + make_interval(
          secs => least(3600, 30 * greatest(attempts, 1))
        ),
        claimed_at = null,
        last_error = left(
          coalesce(nullif(btrim(p_error), ''), 'storage deletion failed'), 1000
        )
    where request_id = request.request_id
    returning * into request;
  end if;
  return request.result_json || jsonb_build_object(
    'state', request.state,
    'attempts', request.attempts
  );
end;
$$;

-- Corpo de producao (dump 20260917, SHA-256 c87f4d67); apenas a condicao por provedor mudou.
CREATE OR REPLACE FUNCTION "app_private"."meal_plan_request_image_delete_unreceipted"("p_asset_id" "uuid", "p_idempotency_key" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  actor_id uuid := app_private.current_person_id();
  asset public.meal_plan_image_assets%rowtype;
  prior app_private.meal_plan_image_delete_requests%rowtype;
  object_exists boolean;
begin
  if auth.uid() is null or actor_id is null or p_idempotency_key is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key::text, 0));
  select * into prior
  from app_private.meal_plan_image_delete_requests request
  where request.request_id = p_idempotency_key;
  if prior.request_id is not null then
    if prior.actor_person_id <> actor_id or prior.asset_id <> p_asset_id then
      raise invalid_parameter_value using message = 'idempotency key reused';
    end if;
    return jsonb_build_object(
      'asset_id', prior.asset_id,
      'bucket', 'coelo-meal-plans-private',
      'delete_path', prior.storage_path,
      'confirmed', prior.confirmed_at is not null
    );
  end if;

  select * into asset
  from public.meal_plan_image_assets candidate
  where candidate.id = p_asset_id
  for update;
  if asset.id is null then
    raise no_data_found using message = 'meal plan image not found';
  end if;
  if not app_private.has_platform_permission('meal_plans.manage')
      or not app_private.meal_plan_scope_allowed(asset.tenant_id, asset.institution_id) then
    raise insufficient_privilege using message = 'meal_plans.manage required';
  end if;
  if asset.status not in ('active', 'pending_delete') then
    raise invalid_parameter_value using message = 'meal plan image cannot be deleted';
  end if;

  -- R2: o objeto existe ate o worker de limpeza o remover (pending_delete + fila).
  select asset.storage_provider = 'r2' or exists (
    select 1 from storage.objects object_record
    where object_record.bucket_id = asset.storage_bucket
      and object_record.name = asset.storage_path
  ) into object_exists;
  update public.meal_plan_image_assets
  set status = case when object_exists then 'pending_delete' else 'deleted' end,
      pending_delete_at = coalesce(pending_delete_at, now()),
      deleted_at = case when object_exists then null else now() end
  where id = asset.id
  returning * into asset;
  insert into app_private.meal_plan_image_delete_requests (
    request_id, asset_id, actor_person_id, storage_path, confirmed_at
  ) values (
    p_idempotency_key, asset.id, actor_id, asset.storage_path,
    case when object_exists then null else now() end
  );

  insert into audit.audit_logs (
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, before_json, after_json
  ) values (
    actor_id, auth.jwt()->>'aal', 'meal_plan.image.delete.request',
    'meal_plan_image_asset', asset.id, asset.institution_id, 'success',
    to_jsonb(asset), jsonb_build_object('status', asset.status,
      'bucket', asset.storage_bucket, 'path', asset.storage_path)
  );

  return jsonb_build_object(
    'asset_id', asset.id,
    'bucket', asset.storage_bucket,
    'delete_path', asset.storage_path,
    'confirmed', not object_exists
  );
end;
$$;

do $postcheck$
begin
  if to_regprocedure('public.meal_plan_prepare_image_upload_v2(text,uuid,text,text,bigint,text,uuid)') is null
    or to_regprocedure('public.meal_plan_finalize_image_upload_v2(uuid,uuid,bigint,text,text,text,uuid)') is null
    or to_regprocedure('public.meal_plan_image_read_descriptor_v2(uuid)') is null
    or not exists (select 1 from pg_attribute where attrelid = 'public.meal_plan_image_assets'::regclass
      and attname = 'storage_provider' and not attisdropped)
    or exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'app_private') and p.proname like 'meal_plan_%image%'
        and p.prosrc like '%serialization_failure%') then
    raise object_not_in_prerequisite_state using message = 'meal plan images r2 v1 postcheck failed';
  end if;
end
$postcheck$;

commit;
