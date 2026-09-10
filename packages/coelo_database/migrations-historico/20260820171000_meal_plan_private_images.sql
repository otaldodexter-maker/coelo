-- Private, production-grade image storage for meal plans and meal-plan templates.
-- This draft is intentionally not part of the applied migration directory.
begin;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'coelo-meal-plans-private',
  'coelo-meal-plans-private',
  false,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create unique index if not exists meal_plan_meal_items_id_tenant_uidx
  on public.meal_plan_meal_items(id, tenant_id);

create table public.meal_plan_image_assets (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  institution_id uuid references public.institutions(id) on delete cascade,
  resource_kind text not null
    check (resource_kind in ('meal_plan', 'template', 'meal', 'meal_item')),
  meal_plan_id uuid,
  template_id uuid,
  meal_id uuid,
  meal_item_id uuid,
  storage_bucket text not null default 'coelo-meal-plans-private'
    check (storage_bucket = 'coelo-meal-plans-private'),
  storage_path text not null unique,
  mime_type text not null
    check (mime_type in ('image/jpeg', 'image/png', 'image/webp')),
  size_bytes bigint not null check (size_bytes between 1 and 2097152),
  checksum_sha256 text
    check (checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$'),
  alt_text text check (alt_text is null or length(alt_text) <= 500),
  status text not null default 'pending'
    check (status in ('pending', 'active', 'pending_delete', 'deleted')),
  replaced_asset_id uuid references public.meal_plan_image_assets(id) on delete restrict,
  created_by uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  pending_delete_at timestamptz,
  deleted_at timestamptz,
  constraint meal_plan_image_assets_plan_fk
    foreign key (meal_plan_id, tenant_id)
    references public.meal_plans(id, tenant_id) on delete cascade,
  constraint meal_plan_image_assets_template_fk
    foreign key (template_id, tenant_id)
    references public.meal_plan_templates(id, tenant_id) on delete cascade,
  constraint meal_plan_image_assets_meal_fk
    foreign key (meal_id, tenant_id)
    references public.meal_plan_meals(id, tenant_id) on delete cascade,
  constraint meal_plan_image_assets_meal_item_fk
    foreign key (meal_item_id, tenant_id)
    references public.meal_plan_meal_items(id, tenant_id) on delete cascade,
  constraint meal_plan_image_assets_parent_shape_check check (
    (resource_kind = 'meal_plan' and meal_plan_id is not null
      and template_id is null and meal_id is null and meal_item_id is null)
    or (resource_kind = 'template' and template_id is not null
      and meal_plan_id is null and meal_id is null and meal_item_id is null)
    or (resource_kind = 'meal' and meal_id is not null
      and meal_plan_id is null and template_id is null and meal_item_id is null)
    or (resource_kind = 'meal_item' and meal_item_id is not null
      and meal_plan_id is null and template_id is null and meal_id is null)
  ),
  constraint meal_plan_image_assets_status_shape_check check (
    (status = 'pending' and checksum_sha256 is null and activated_at is null
      and pending_delete_at is null and deleted_at is null)
    or (status = 'active' and checksum_sha256 is not null and activated_at is not null
      and pending_delete_at is null and deleted_at is null)
    or (status = 'pending_delete' and checksum_sha256 is not null
      and activated_at is not null and pending_delete_at is not null
      and deleted_at is null)
    or (status = 'deleted' and deleted_at is not null)
  )
);

create index meal_plan_image_assets_parent_idx
  on public.meal_plan_image_assets(tenant_id, resource_kind, meal_plan_id,
    template_id, meal_id, meal_item_id, status);
create index meal_plan_image_assets_active_path_idx
  on public.meal_plan_image_assets(storage_path)
  where status in ('active', 'pending_delete');

create table app_private.meal_plan_image_upload_intents (
  request_id uuid primary key,
  asset_id uuid not null unique
    references public.meal_plan_image_assets(id) on delete cascade,
  actor_person_id uuid not null references public.people(id) on delete restrict,
  storage_path text not null unique,
  mime_type text not null
    check (mime_type in ('image/jpeg', 'image/png', 'image/webp')),
  size_bytes bigint not null check (size_bytes between 1 and 2097152),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  checksum_sha256 text
    check (checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);

create index meal_plan_image_upload_intents_open_idx
  on app_private.meal_plan_image_upload_intents(expires_at)
  where consumed_at is null;

create table app_private.meal_plan_image_delete_requests (
  request_id uuid primary key,
  asset_id uuid not null references public.meal_plan_image_assets(id) on delete cascade,
  actor_person_id uuid not null references public.people(id) on delete restrict,
  storage_path text not null,
  confirmed_at timestamptz,
  created_at timestamptz not null default now()
);

create index meal_plan_image_delete_requests_asset_idx
  on app_private.meal_plan_image_delete_requests(asset_id, created_at desc);

revoke all on public.meal_plan_image_assets
  from public, anon, authenticated, service_role;
grant select on public.meal_plan_image_assets to authenticated;
revoke all on app_private.meal_plan_image_upload_intents,
  app_private.meal_plan_image_delete_requests
  from public, anon, authenticated, service_role;

alter table public.meal_plan_image_assets enable row level security;
alter table public.meal_plan_image_assets force row level security;

create or replace function app_private.meal_plan_image_asset_parent_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  parent_tenant uuid;
  parent_institution uuid;
  parent_plan uuid;
  expected_path text;
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
    expected_path := 'meal-plans/' || new.meal_plan_id::text || '/' ||
      new.id::text || '.' || extension;
  elsif new.resource_kind = 'template' then
    select template.tenant_id, template.institution_id
      into parent_tenant, parent_institution
    from public.meal_plan_templates template
    where template.id = new.template_id;
    expected_path := 'meal-plan-templates/' || new.template_id::text || '/' ||
      new.id::text || '.' || extension;
  elsif new.resource_kind = 'meal' then
    select plan.tenant_id, plan.institution_id, plan.id
      into parent_tenant, parent_institution, parent_plan
    from public.meal_plan_meals meal
    join public.meal_plans plan
      on plan.id = meal.meal_plan_id and plan.tenant_id = meal.tenant_id
    where meal.id = new.meal_id;
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
  if new.storage_bucket <> 'coelo-meal-plans-private'
      or new.storage_path is distinct from expected_path then
    raise check_violation using message = 'meal plan image storage path mismatch';
  end if;
  return new;
end;
$function$;

revoke all on function app_private.meal_plan_image_asset_parent_guard()
  from public, anon, authenticated, service_role;

create trigger meal_plan_image_assets_parent_guard
before insert or update of tenant_id, institution_id, resource_kind,
  meal_plan_id, template_id, meal_id, meal_item_id, storage_bucket,
  storage_path, mime_type
on public.meal_plan_image_assets
for each row execute function app_private.meal_plan_image_asset_parent_guard();

create or replace function app_private.can_read_meal_plan_image_object(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.meal_plan_image_assets asset
    where asset.storage_path = object_name
      and asset.storage_bucket = 'coelo-meal-plans-private'
      and asset.status in ('active', 'pending_delete')
      and app_private.has_platform_permission('meal_plans.read')
      and app_private.meal_plan_scope_allowed(asset.tenant_id, asset.institution_id)
  );
$function$;

create or replace function app_private.can_upload_meal_plan_image_object(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from app_private.meal_plan_image_upload_intents intent
    join public.meal_plan_image_assets asset on asset.id = intent.asset_id
    where intent.storage_path = object_name
      and asset.storage_path = object_name
      and asset.storage_bucket = 'coelo-meal-plans-private'
      and asset.status = 'pending'
      and intent.actor_person_id = app_private.current_person_id()
      and intent.expires_at > now()
      and intent.consumed_at is null
      and app_private.has_platform_permission('meal_plans.manage')
      and app_private.meal_plan_scope_allowed(asset.tenant_id, asset.institution_id)
  );
$function$;

create or replace function app_private.can_delete_meal_plan_image_object(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.meal_plan_image_assets asset
    join app_private.meal_plan_image_delete_requests request
      on request.asset_id = asset.id and request.storage_path = asset.storage_path
    where asset.storage_path = object_name
      and asset.storage_bucket = 'coelo-meal-plans-private'
      and asset.status = 'pending_delete'
      and request.confirmed_at is null
      and request.actor_person_id = app_private.current_person_id()
      and app_private.has_platform_permission('meal_plans.manage')
      and app_private.meal_plan_scope_allowed(asset.tenant_id, asset.institution_id)
  );
$function$;

revoke all on function app_private.can_read_meal_plan_image_object(text),
  app_private.can_upload_meal_plan_image_object(text),
  app_private.can_delete_meal_plan_image_object(text)
  from public, anon, authenticated, service_role;

drop policy if exists meal_plan_image_assets_read on public.meal_plan_image_assets;
create policy meal_plan_image_assets_read
on public.meal_plan_image_assets
for select
to authenticated
using (
  status in ('active', 'pending_delete')
  and app_private.has_platform_permission('meal_plans.read')
  and app_private.meal_plan_scope_allowed(tenant_id, institution_id)
);

drop policy if exists meal_plan_image_object_select on storage.objects;
create policy meal_plan_image_object_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'coelo-meal-plans-private'
  and app_private.can_read_meal_plan_image_object(name)
);

drop policy if exists meal_plan_image_object_insert on storage.objects;
create policy meal_plan_image_object_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'coelo-meal-plans-private'
  and app_private.can_upload_meal_plan_image_object(name)
);

drop policy if exists meal_plan_image_object_update on storage.objects;
drop policy if exists meal_plan_image_object_delete on storage.objects;
create policy meal_plan_image_object_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'coelo-meal-plans-private'
  and app_private.can_delete_meal_plan_image_object(name)
);

create or replace function app_private.meal_plan_prepare_image_upload(
  p_resource_kind text,
  p_resource_id uuid,
  p_file_name text,
  p_mime_type text,
  p_size_bytes bigint,
  p_alt_text text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := app_private.current_person_id();
  asset_id uuid;
  parent_tenant uuid;
  parent_institution uuid;
  parent_plan uuid;
  extension text;
  storage_path text;
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
        or prior_asset.resource_kind <> p_resource_kind
        or coalesce(prior_asset.meal_plan_id, prior_asset.template_id,
          prior_asset.meal_id, prior_asset.meal_item_id) <> p_resource_id
        or prior_asset.alt_text is distinct from nullif(btrim(p_alt_text), '') then
      raise invalid_parameter_value using message = 'idempotency key reused';
    end if;
    return jsonb_build_object(
      'asset_id', prior.asset_id,
      'bucket', 'coelo-meal-plans-private',
      'path', prior.storage_path,
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
  storage_path := case p_resource_kind
    when 'meal_plan' then 'meal-plans/' || p_resource_id::text || '/' || asset_id::text || '.' || extension
    when 'template' then 'meal-plan-templates/' || p_resource_id::text || '/' || asset_id::text || '.' || extension
    when 'meal' then 'meal-plans/' || parent_plan::text || '/meals/' || p_resource_id::text || '/' || asset_id::text || '.' || extension
    else 'meal-plans/' || parent_plan::text || '/meal-items/' || p_resource_id::text || '/' || asset_id::text || '.' || extension
  end;

  insert into public.meal_plan_image_assets (
    id, tenant_id, institution_id, resource_kind, meal_plan_id, template_id,
    meal_id, meal_item_id, storage_path, mime_type, size_bytes, alt_text, created_by
  ) values (
    asset_id, parent_tenant, parent_institution, p_resource_kind,
    case when p_resource_kind = 'meal_plan' then p_resource_id end,
    case when p_resource_kind = 'template' then p_resource_id end,
    case when p_resource_kind = 'meal' then p_resource_id end,
    case when p_resource_kind = 'meal_item' then p_resource_id end,
    storage_path, p_mime_type, p_size_bytes, nullif(btrim(p_alt_text), ''), actor_id
  );

  insert into app_private.meal_plan_image_upload_intents (
    request_id, asset_id, actor_person_id, storage_path, mime_type,
    size_bytes, expires_at
  ) values (
    p_idempotency_key, asset_id, actor_id, storage_path, p_mime_type,
    p_size_bytes, expires_at
  );

  insert into audit.audit_logs (
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor_id, auth.jwt()->>'aal', 'meal_plan.image.upload.prepare',
    'meal_plan_image_asset', asset_id, parent_institution, 'success',
    jsonb_build_object('resource_kind', p_resource_kind,
      'resource_id', p_resource_id, 'bucket', 'coelo-meal-plans-private',
      'path', storage_path, 'mime_type', p_mime_type, 'size_bytes', p_size_bytes)
  );

  return jsonb_build_object(
    'asset_id', asset_id,
    'bucket', 'coelo-meal-plans-private',
    'path', storage_path,
    'mime_type', p_mime_type,
    'max_bytes', 2097152,
    'expires_at', expires_at
  );
end;
$function$;

create or replace function app_private.meal_plan_finalize_image_upload(
  p_request_id uuid,
  p_checksum_sha256 text,
  p_alt_text text default null,
  p_replace_asset_id uuid default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := app_private.current_person_id();
  intent app_private.meal_plan_image_upload_intents%rowtype;
  asset public.meal_plan_image_assets%rowtype;
  previous public.meal_plan_image_assets%rowtype;
  object_metadata jsonb;
  cleanup_request_id uuid;
begin
  if auth.uid() is null or actor_id is null or p_request_id is null
      or p_checksum_sha256 !~ '^[0-9a-f]{64}$'
      or (p_alt_text is not null and length(p_alt_text) > 500) then
    raise invalid_parameter_value using message = 'invalid meal plan image finalization';
  end if;

  select * into intent
  from app_private.meal_plan_image_upload_intents candidate
  where candidate.request_id = p_request_id
  for update;
  if intent.request_id is null then
    raise no_data_found using message = 'meal plan image upload intent not found';
  end if;
  select * into asset
  from public.meal_plan_image_assets candidate
  where candidate.id = intent.asset_id
  for update;
  if intent.actor_person_id <> actor_id
      or not app_private.has_platform_permission('meal_plans.manage')
      or not app_private.meal_plan_scope_allowed(asset.tenant_id, asset.institution_id) then
    raise insufficient_privilege using message = 'meal plan image finalization denied';
  end if;
  if intent.consumed_at is not null then
    if intent.checksum_sha256 is distinct from p_checksum_sha256 then
      raise invalid_parameter_value using message = 'finalization payload changed';
    end if;
    return to_jsonb(asset);
  end if;
  if intent.expires_at <= now() or asset.status <> 'pending' then
    raise invalid_parameter_value using message = 'meal plan image upload intent expired';
  end if;

  select object_record.metadata into object_metadata
  from storage.objects object_record
  where object_record.bucket_id = 'coelo-meal-plans-private'
    and object_record.name = intent.storage_path;
  if object_metadata is null
      or coalesce((object_metadata->>'size')::bigint, -1) <> intent.size_bytes
      or coalesce(object_metadata->>'mimetype', '') <> intent.mime_type then
    raise invalid_parameter_value using message = 'uploaded object metadata mismatch';
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
  update app_private.meal_plan_image_upload_intents
  set consumed_at = now(), checksum_sha256 = p_checksum_sha256
  where request_id = intent.request_id;

  if previous.id is not null then
    cleanup_request_id := gen_random_uuid();
    update public.meal_plan_image_assets
    set status = 'pending_delete', pending_delete_at = now()
    where id = previous.id;
    insert into app_private.meal_plan_image_delete_requests (
      request_id, asset_id, actor_person_id, storage_path
    ) values (
      cleanup_request_id, previous.id, actor_id, previous.storage_path
    );
  end if;

  insert into audit.audit_logs (
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor_id, auth.jwt()->>'aal', 'meal_plan.image.upload.finalize',
    'meal_plan_image_asset', asset.id, asset.institution_id, 'success',
    to_jsonb(asset) || jsonb_build_object('cleanup_request_id', cleanup_request_id,
      'cleanup_asset_id', previous.id, 'cleanup_path', previous.storage_path)
  );

  return to_jsonb(asset) || jsonb_build_object(
    'cleanup_request_id', cleanup_request_id,
    'cleanup_asset_id', previous.id,
    'cleanup_path', previous.storage_path
  );
end;
$function$;

create or replace function app_private.meal_plan_image_download_descriptor(
  p_asset_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
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
    'bucket', asset.storage_bucket,
    'path', asset.storage_path,
    'mime_type', asset.mime_type,
    'alt_text', asset.alt_text,
    'signed_url_ttl_seconds', 300
  );
end;
$function$;

create or replace function app_private.meal_plan_request_image_delete(
  p_asset_id uuid,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
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

  select exists (
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
$function$;

create or replace function public.meal_plan_prepare_image_upload(
  p_resource_kind text,
  p_resource_id uuid,
  p_file_name text,
  p_mime_type text,
  p_size_bytes bigint,
  p_alt_text text,
  p_idempotency_key uuid
)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $function$
  select app_private.meal_plan_prepare_image_upload(
    p_resource_kind, p_resource_id, p_file_name, p_mime_type,
    p_size_bytes, p_alt_text, p_idempotency_key
  );
$function$;

create or replace function public.meal_plan_finalize_image_upload(
  p_request_id uuid,
  p_checksum_sha256 text,
  p_alt_text text default null,
  p_replace_asset_id uuid default null
)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $function$
  select app_private.meal_plan_finalize_image_upload(
    p_request_id, p_checksum_sha256, p_alt_text, p_replace_asset_id
  );
$function$;

create or replace function public.meal_plan_image_download_descriptor(p_asset_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  select app_private.meal_plan_image_download_descriptor(p_asset_id);
$function$;

create or replace function public.meal_plan_request_image_delete(
  p_asset_id uuid,
  p_idempotency_key uuid
)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $function$
  select app_private.meal_plan_request_image_delete(p_asset_id, p_idempotency_key);
$function$;

revoke all on function public.meal_plan_prepare_image_upload(
  text, uuid, text, text, bigint, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.meal_plan_finalize_image_upload(
  uuid, text, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.meal_plan_image_download_descriptor(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.meal_plan_request_image_delete(uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.meal_plan_prepare_image_upload(
  text, uuid, text, text, bigint, text, uuid
) to authenticated;
grant execute on function public.meal_plan_finalize_image_upload(
  uuid, text, text, uuid
) to authenticated;
grant execute on function public.meal_plan_image_download_descriptor(uuid)
  to authenticated;
grant execute on function public.meal_plan_request_image_delete(uuid, uuid)
  to authenticated;

revoke all on function app_private.meal_plan_prepare_image_upload(
  text, uuid, text, text, bigint, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function app_private.meal_plan_finalize_image_upload(
  uuid, text, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function app_private.meal_plan_image_download_descriptor(uuid)
  from public, anon, authenticated, service_role;
revoke all on function app_private.meal_plan_request_image_delete(uuid, uuid)
  from public, anon, authenticated, service_role;

comment on table public.meal_plan_image_assets is
  'Private meal-plan image metadata. Render only through short signed URLs.';
comment on function public.meal_plan_prepare_image_upload(
  text, uuid, text, text, bigint, text, uuid
) is 'Creates a short-lived, actor-bound upload intent. No MFA is required.';
comment on function public.meal_plan_image_download_descriptor(uuid) is
  'Returns an authorized private Storage descriptor with a 300-second URL TTL.';

commit;
