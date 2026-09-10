-- Meal-plan command receipts and private image cleanup closure.
begin;

create table app_private.meal_plan_command_receipts (
  actor_person_id uuid not null references public.people(id) on delete restrict,
  request_id text not null,
  command_name text not null,
  meal_plan_id uuid not null references public.meal_plans(id) on delete restrict,
  payload_hash text not null check (payload_hash ~ '^[0-9a-f]{64}$'),
  result_json jsonb not null,
  created_at timestamptz not null default now(),
  primary key (actor_person_id, request_id),
  check (request_id = btrim(request_id) and length(request_id) between 1 and 200)
);

revoke all on app_private.meal_plan_command_receipts
  from public, anon, authenticated, service_role;
alter table app_private.meal_plan_command_receipts enable row level security;
alter table app_private.meal_plan_command_receipts force row level security;

create or replace function app_private.meal_plan_request_hash(p_payload jsonb)
returns text
language sql
immutable
set search_path = ''
as $function$
  select encode(
    extensions.digest(convert_to(coalesce(p_payload, '{}'::jsonb)::text, 'UTF8'), 'sha256'),
    'hex'
  );
$function$;

revoke all on function app_private.meal_plan_request_hash(jsonb)
  from public, anon, authenticated, service_role;

alter function public.meal_plan_create_or_update_draft(text, jsonb, uuid, integer)
  rename to meal_plan_create_or_update_draft_unreceipted;
alter function public.meal_plan_submit_for_review(text, uuid, integer)
  rename to meal_plan_submit_for_review_unreceipted;
alter function public.meal_plan_publish(text, uuid, integer)
  rename to meal_plan_publish_unreceipted;

revoke all on function public.meal_plan_create_or_update_draft_unreceipted(
  text, jsonb, uuid, integer
) from public, anon, authenticated, service_role;
revoke all on function public.meal_plan_submit_for_review_unreceipted(
  text, uuid, integer
) from public, anon, authenticated, service_role;
revoke all on function public.meal_plan_publish_unreceipted(
  text, uuid, integer
) from public, anon, authenticated, service_role;

create or replace function public.meal_plan_create_or_update_draft(
  p_request_id text,
  p_payload jsonb,
  p_meal_plan_id uuid default null,
  p_expected_revision integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := app_private.current_person_id();
  stored_plan public.meal_plans%rowtype;
  requested_institution_id uuid := nullif(p_payload ->> 'institutionId', '')::uuid;
  requested_tenant_id uuid := coalesce(
    requested_institution_id,
    nullif(p_payload ->> 'tenantId', '')::uuid
  );
  request_hash text;
  receipt app_private.meal_plan_command_receipts%rowtype;
  result_payload jsonb;
  result_id uuid;
begin
  if auth.uid() is null or actor_id is null
      or not app_private.has_platform_permission('meal_plans.manage') then
    raise insufficient_privilege using message = 'meal_plans.manage required';
  end if;
  if nullif(btrim(coalesce(p_request_id, '')), '') is null
      or length(p_request_id) > 200 then
    raise invalid_parameter_value using message = 'invalid meal plan request id';
  end if;
  if p_meal_plan_id is null then
    if requested_tenant_id is null
        or not app_private.meal_plan_scope_allowed(
          requested_tenant_id, requested_institution_id
        ) then
      raise insufficient_privilege using message = 'meal plan scope is not allowed';
    end if;
  else
    select candidate.* into stored_plan
    from public.meal_plans candidate
    where candidate.id = p_meal_plan_id
      and app_private.meal_plan_scope_allowed(
        candidate.tenant_id, candidate.institution_id
      );
    if not found then
      raise no_data_found using message = 'meal plan not found';
    end if;
  end if;

  request_hash := app_private.meal_plan_request_hash(jsonb_build_object(
    'command', 'save_draft',
    'meal_plan_id', p_meal_plan_id,
    'expected_revision', p_expected_revision,
    'payload', p_payload
  ));
  perform pg_advisory_xact_lock(
    hashtextextended(actor_id::text || ':' || p_request_id, 0)
  );
  select candidate.* into receipt
  from app_private.meal_plan_command_receipts candidate
  where candidate.actor_person_id = actor_id
    and candidate.request_id = p_request_id;
  if found then
    if receipt.command_name <> 'save_draft'
        or receipt.payload_hash <> request_hash then
      raise invalid_parameter_value using message = 'idempotency key reused';
    end if;
    return receipt.result_json;
  end if;

  result_payload := public.meal_plan_create_or_update_draft_unreceipted(
    p_request_id, p_payload, p_meal_plan_id, p_expected_revision
  );
  result_id := (result_payload ->> 'id')::uuid;
  insert into app_private.meal_plan_command_receipts (
    actor_person_id, request_id, command_name, meal_plan_id,
    payload_hash, result_json
  ) values (
    actor_id, p_request_id, 'save_draft', result_id,
    request_hash, result_payload
  );
  return result_payload;
end;
$function$;

create or replace function public.meal_plan_submit_for_review(
  p_request_id text,
  p_meal_plan_id uuid,
  p_expected_revision integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := app_private.current_person_id();
  stored_plan public.meal_plans%rowtype;
  request_hash text;
  receipt app_private.meal_plan_command_receipts%rowtype;
  result_payload jsonb;
begin
  if auth.uid() is null or actor_id is null
      or not app_private.has_platform_permission('meal_plans.manage') then
    raise insufficient_privilege using message = 'meal_plans.manage required';
  end if;
  if nullif(btrim(coalesce(p_request_id, '')), '') is null
      or length(p_request_id) > 200 then
    raise invalid_parameter_value using message = 'invalid meal plan request id';
  end if;
  select candidate.* into stored_plan
  from public.meal_plans candidate
  where candidate.id = p_meal_plan_id
    and app_private.meal_plan_scope_allowed(
      candidate.tenant_id, candidate.institution_id
    );
  if not found then raise no_data_found using message = 'meal plan not found'; end if;

  request_hash := app_private.meal_plan_request_hash(jsonb_build_object(
    'command', 'submit_for_review',
    'meal_plan_id', p_meal_plan_id,
    'expected_revision', p_expected_revision
  ));
  perform pg_advisory_xact_lock(
    hashtextextended(actor_id::text || ':' || p_request_id, 0)
  );
  select candidate.* into receipt
  from app_private.meal_plan_command_receipts candidate
  where candidate.actor_person_id = actor_id
    and candidate.request_id = p_request_id;
  if found then
    if receipt.command_name <> 'submit_for_review'
        or receipt.payload_hash <> request_hash then
      raise invalid_parameter_value using message = 'idempotency key reused';
    end if;
    return receipt.result_json;
  end if;

  result_payload := public.meal_plan_submit_for_review_unreceipted(
    p_request_id, p_meal_plan_id, p_expected_revision
  );
  insert into app_private.meal_plan_command_receipts (
    actor_person_id, request_id, command_name, meal_plan_id,
    payload_hash, result_json
  ) values (
    actor_id, p_request_id, 'submit_for_review', p_meal_plan_id,
    request_hash, result_payload
  );
  return result_payload;
end;
$function$;

create or replace function public.meal_plan_publish(
  p_request_id text,
  p_meal_plan_id uuid,
  p_expected_revision integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := app_private.current_person_id();
  stored_plan public.meal_plans%rowtype;
  request_hash text;
  receipt app_private.meal_plan_command_receipts%rowtype;
  result_payload jsonb;
begin
  if auth.uid() is null or actor_id is null
      or not app_private.has_platform_permission('meal_plans.publish') then
    raise insufficient_privilege using message = 'meal_plans.publish required';
  end if;
  if nullif(btrim(coalesce(p_request_id, '')), '') is null
      or length(p_request_id) > 200 then
    raise invalid_parameter_value using message = 'invalid meal plan request id';
  end if;
  select candidate.* into stored_plan
  from public.meal_plans candidate
  where candidate.id = p_meal_plan_id
    and app_private.meal_plan_scope_allowed(
      candidate.tenant_id, candidate.institution_id
    );
  if not found then raise no_data_found using message = 'meal plan not found'; end if;

  request_hash := app_private.meal_plan_request_hash(jsonb_build_object(
    'command', 'publish',
    'meal_plan_id', p_meal_plan_id,
    'expected_revision', p_expected_revision
  ));
  perform pg_advisory_xact_lock(
    hashtextextended(actor_id::text || ':' || p_request_id, 0)
  );
  select candidate.* into receipt
  from app_private.meal_plan_command_receipts candidate
  where candidate.actor_person_id = actor_id
    and candidate.request_id = p_request_id;
  if found then
    if receipt.command_name <> 'publish'
        or receipt.payload_hash <> request_hash then
      raise invalid_parameter_value using message = 'idempotency key reused';
    end if;
    return receipt.result_json;
  end if;

  result_payload := public.meal_plan_publish_unreceipted(
    p_request_id, p_meal_plan_id, p_expected_revision
  );
  insert into app_private.meal_plan_command_receipts (
    actor_person_id, request_id, command_name, meal_plan_id,
    payload_hash, result_json
  ) values (
    actor_id, p_request_id, 'publish', p_meal_plan_id,
    request_hash, result_payload
  );
  return result_payload;
end;
$function$;

create or replace function public.meal_plan_archive(
  p_request_id text,
  p_meal_plan_id uuid,
  p_expected_revision integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := app_private.current_person_id();
  stored_plan public.meal_plans%rowtype;
  request_hash text;
  receipt app_private.meal_plan_command_receipts%rowtype;
  result_payload jsonb;
begin
  if auth.uid() is null or actor_id is null
      or not app_private.has_platform_permission('meal_plans.manage') then
    raise insufficient_privilege using message = 'meal_plans.manage required';
  end if;
  if nullif(btrim(coalesce(p_request_id, '')), '') is null
      or length(p_request_id) > 200 then
    raise invalid_parameter_value using message = 'invalid meal plan request id';
  end if;
  select candidate.* into stored_plan
  from public.meal_plans candidate
  where candidate.id = p_meal_plan_id
    and app_private.meal_plan_scope_allowed(
      candidate.tenant_id, candidate.institution_id
    )
  for update;
  if not found then raise no_data_found using message = 'meal plan not found'; end if;

  request_hash := app_private.meal_plan_request_hash(jsonb_build_object(
    'command', 'archive',
    'meal_plan_id', p_meal_plan_id,
    'expected_revision', p_expected_revision
  ));
  perform pg_advisory_xact_lock(
    hashtextextended(actor_id::text || ':' || p_request_id, 0)
  );
  select candidate.* into receipt
  from app_private.meal_plan_command_receipts candidate
  where candidate.actor_person_id = actor_id
    and candidate.request_id = p_request_id;
  if found then
    if receipt.command_name <> 'archive'
        or receipt.payload_hash <> request_hash then
      raise invalid_parameter_value using message = 'idempotency key reused';
    end if;
    return receipt.result_json;
  end if;

  update public.meal_plans
  set status = 'archived',
      is_draft = false,
      requires_review = false,
      revision = revision + 1,
      updated_by = actor_id,
      updated_at = now()
  where id = p_meal_plan_id
    and revision = p_expected_revision
    and status in ('draft', 'inReview', 'scheduled', 'published', 'updated', 'closed')
  returning public.meal_plan_json(meal_plans) into result_payload;
  if not found then
    raise exception 'meal plan revision or status conflict' using errcode = 'P0003';
  end if;
  insert into app_private.meal_plan_command_receipts (
    actor_person_id, request_id, command_name, meal_plan_id,
    payload_hash, result_json
  ) values (
    actor_id, p_request_id, 'archive', p_meal_plan_id,
    request_hash, result_payload
  );
  return result_payload;
end;
$function$;

revoke all on function public.meal_plan_create_or_update_draft(
  text, jsonb, uuid, integer
) from public, anon, authenticated, service_role;
revoke all on function public.meal_plan_submit_for_review(text, uuid, integer)
  from public, anon, authenticated, service_role;
revoke all on function public.meal_plan_publish(text, uuid, integer)
  from public, anon, authenticated, service_role;
revoke all on function public.meal_plan_archive(text, uuid, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.meal_plan_create_or_update_draft(
  text, jsonb, uuid, integer
) to authenticated;
grant execute on function public.meal_plan_submit_for_review(text, uuid, integer)
  to authenticated;
grant execute on function public.meal_plan_publish(text, uuid, integer)
  to authenticated;
grant execute on function public.meal_plan_archive(text, uuid, integer)
  to authenticated;

alter table public.meal_plan_image_assets
  add column revision integer not null default 1;
alter table public.meal_plan_image_assets
  add constraint meal_plan_image_assets_revision_positive check (revision > 0);

alter table app_private.meal_plan_image_upload_intents
  add column finalize_payload_hash text,
  add column finalize_result_json jsonb;
alter table app_private.meal_plan_image_upload_intents
  add constraint meal_plan_image_upload_finalize_hash_check check (
    finalize_payload_hash is null or finalize_payload_hash ~ '^[0-9a-f]{64}$'
  );

alter table app_private.meal_plan_image_delete_requests
  add column expected_revision integer,
  add column payload_hash text,
  add column result_json jsonb,
  add column state text not null default 'pending',
  add column attempts integer not null default 0,
  add column available_at timestamptz not null default now(),
  add column claimed_at timestamptz,
  add column completed_at timestamptz,
  add column last_error text;
alter table app_private.meal_plan_image_delete_requests
  add constraint meal_plan_image_delete_payload_hash_check check (
    payload_hash is null or payload_hash ~ '^[0-9a-f]{64}$'
  ),
  add constraint meal_plan_image_delete_state_check check (
    state in ('pending', 'processing', 'completed', 'failed', 'cancelled')
  ),
  add constraint meal_plan_image_delete_attempts_check check (attempts >= 0);

create index meal_plan_image_cleanup_claim_idx
  on app_private.meal_plan_image_delete_requests(state, available_at, created_at)
  where state in ('pending', 'processing', 'failed');

create or replace function app_private.meal_plan_image_delete_request_defaults()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  asset public.meal_plan_image_assets%rowtype;
begin
  select candidate.* into asset
  from public.meal_plan_image_assets candidate
  where candidate.id = new.asset_id;
  if asset.id is null or new.storage_path is distinct from asset.storage_path then
    raise foreign_key_violation using message = 'meal plan cleanup asset mismatch';
  end if;
  new.expected_revision := coalesce(new.expected_revision, asset.revision);
  new.payload_hash := coalesce(
    new.payload_hash,
    app_private.meal_plan_request_hash(jsonb_build_object(
      'asset_id', new.asset_id,
      'expected_revision', new.expected_revision
    ))
  );
  new.result_json := coalesce(new.result_json, jsonb_build_object(
    'asset_id', asset.id,
    'bucket', asset.storage_bucket,
    'delete_path', asset.storage_path,
    'confirmed', new.confirmed_at is not null,
    'revision', asset.revision
  ));
  new.state := case when new.confirmed_at is null then new.state else 'completed' end;
  new.completed_at := coalesce(new.completed_at, new.confirmed_at);
  return new;
end;
$function$;

create trigger meal_plan_image_delete_request_defaults
before insert on app_private.meal_plan_image_delete_requests
for each row execute function app_private.meal_plan_image_delete_request_defaults();

update app_private.meal_plan_image_upload_intents intent
set finalize_payload_hash = app_private.meal_plan_request_hash(jsonb_build_object(
      'checksum_sha256', intent.checksum_sha256,
      'alt_text', asset.alt_text,
      'replace_asset_id', asset.replaced_asset_id
    )),
    finalize_result_json = to_jsonb(asset)
from public.meal_plan_image_assets asset
where asset.id = intent.asset_id
  and intent.consumed_at is not null
  and intent.finalize_payload_hash is null;

update app_private.meal_plan_image_delete_requests request
set expected_revision = coalesce(request.expected_revision, asset.revision),
    payload_hash = coalesce(request.payload_hash,
      app_private.meal_plan_request_hash(jsonb_build_object(
        'asset_id', request.asset_id,
        'expected_revision', coalesce(request.expected_revision, asset.revision)
      ))),
    result_json = coalesce(request.result_json, jsonb_build_object(
      'asset_id', asset.id,
      'bucket', asset.storage_bucket,
      'delete_path', asset.storage_path,
      'confirmed', request.confirmed_at is not null,
      'revision', asset.revision
    )),
    state = case when request.confirmed_at is null then 'pending' else 'completed' end,
    completed_at = request.confirmed_at
from public.meal_plan_image_assets asset
where asset.id = request.asset_id;

alter table app_private.meal_plan_image_delete_requests
  alter column expected_revision set not null,
  alter column payload_hash set not null,
  alter column result_json set not null;

alter function app_private.meal_plan_finalize_image_upload(uuid, text, text, uuid)
  rename to meal_plan_finalize_image_upload_unreceipted;
alter function app_private.meal_plan_request_image_delete(uuid, uuid)
  rename to meal_plan_request_image_delete_unreceipted;
revoke all on function app_private.meal_plan_finalize_image_upload_unreceipted(
  uuid, text, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function app_private.meal_plan_request_image_delete_unreceipted(
  uuid, uuid
) from public, anon, authenticated, service_role;

create or replace function app_private.meal_plan_image_parent_status(
  p_asset public.meal_plan_image_assets
)
returns text
language sql
stable
security definer
set search_path = ''
as $function$
  select case p_asset.resource_kind
    when 'template' then (
      select template.status from public.meal_plan_templates template
      where template.id = p_asset.template_id
        and template.tenant_id = p_asset.tenant_id
    )
    when 'meal' then (
      select plan.status
      from public.meal_plan_meals meal
      join public.meal_plans plan
        on plan.id = meal.meal_plan_id and plan.tenant_id = meal.tenant_id
      where meal.id = p_asset.meal_id and meal.tenant_id = p_asset.tenant_id
    )
    when 'meal_item' then (
      select plan.status
      from public.meal_plan_meal_items item
      join public.meal_plan_meals meal
        on meal.id = item.meal_id and meal.tenant_id = item.tenant_id
      join public.meal_plans plan
        on plan.id = meal.meal_plan_id and plan.tenant_id = meal.tenant_id
      where item.id = p_asset.meal_item_id and item.tenant_id = p_asset.tenant_id
    )
    else (
      select plan.status from public.meal_plans plan
      where plan.id = p_asset.meal_plan_id and plan.tenant_id = p_asset.tenant_id
    )
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
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := app_private.current_person_id();
  intent app_private.meal_plan_image_upload_intents%rowtype;
  asset public.meal_plan_image_assets%rowtype;
  previous public.meal_plan_image_assets%rowtype;
  request_hash text;
  raw_result jsonb;
  result_payload jsonb;
begin
  if auth.uid() is null or actor_id is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  select candidate.* into intent
  from app_private.meal_plan_image_upload_intents candidate
  where candidate.request_id = p_request_id;
  if not found then
    raise no_data_found using message = 'meal plan image upload intent not found';
  end if;
  select candidate.* into asset
  from public.meal_plan_image_assets candidate
  where candidate.id = intent.asset_id;
  if not found then raise no_data_found using message = 'meal plan image not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended(asset.id::text, 0));
  select candidate.* into intent
  from app_private.meal_plan_image_upload_intents candidate
  where candidate.request_id = p_request_id
  for update;
  select candidate.* into asset
  from public.meal_plan_image_assets candidate
  where candidate.id = intent.asset_id
  for update;

  if intent.actor_person_id <> actor_id or asset.created_by <> actor_id
      or not app_private.has_platform_permission('meal_plans.manage')
      or not app_private.meal_plan_scope_allowed(asset.tenant_id, asset.institution_id) then
    raise insufficient_privilege using message = 'meal plan image finalization denied';
  end if;
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

  if app_private.meal_plan_image_parent_status(asset)
      not in ('draft', 'inReview', 'updated', 'archived') then
    raise invalid_parameter_value using message = 'meal plan image parent is immutable';
  end if;
  if p_replace_asset_id is not null then
    select candidate.* into previous
    from public.meal_plan_image_assets candidate
    where candidate.id = p_replace_asset_id
    for update;
    if previous.id is null or previous.created_by <> actor_id then
      raise insufficient_privilege using message = 'replacement image ownership denied';
    end if;
  end if;

  raw_result := app_private.meal_plan_finalize_image_upload_unreceipted(
    p_request_id, p_checksum_sha256, p_alt_text, p_replace_asset_id
  );
  update public.meal_plan_image_assets
  set revision = revision + 1
  where id = asset.id
  returning * into asset;
  if p_replace_asset_id is not null then
    update public.meal_plan_image_assets
    set revision = revision + 1
    where id = p_replace_asset_id;
  end if;
  result_payload := to_jsonb(asset) || jsonb_build_object(
    'cleanup_request_id', raw_result -> 'cleanup_request_id',
    'cleanup_asset_id', raw_result -> 'cleanup_asset_id',
    'cleanup_path', raw_result -> 'cleanup_path'
  );
  update app_private.meal_plan_image_upload_intents
  set finalize_payload_hash = request_hash,
      finalize_result_json = result_payload
  where request_id = p_request_id;
  return result_payload;
end;
$function$;

create or replace function app_private.meal_plan_request_image_delete(
  p_asset_id uuid,
  p_idempotency_key uuid,
  p_expected_revision integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := app_private.current_person_id();
  asset public.meal_plan_image_assets%rowtype;
  prior app_private.meal_plan_image_delete_requests%rowtype;
  request_hash text;
  raw_result jsonb;
  result_payload jsonb;
begin
  if auth.uid() is null or actor_id is null or p_idempotency_key is null
      or p_expected_revision is null or p_expected_revision < 1 then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  select candidate.* into asset
  from public.meal_plan_image_assets candidate
  where candidate.id = p_asset_id;
  if not found then raise no_data_found using message = 'meal plan image not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended(asset.id::text, 0));
  select candidate.* into asset
  from public.meal_plan_image_assets candidate
  where candidate.id = p_asset_id
  for update;
  if not app_private.has_platform_permission('meal_plans.manage')
      or asset.created_by <> actor_id
      or not app_private.meal_plan_scope_allowed(asset.tenant_id, asset.institution_id) then
    raise insufficient_privilege using message = 'meal plan image delete denied';
  end if;
  request_hash := app_private.meal_plan_request_hash(jsonb_build_object(
    'asset_id', p_asset_id,
    'expected_revision', p_expected_revision
  ));
  select candidate.* into prior
  from app_private.meal_plan_image_delete_requests candidate
  where candidate.request_id = p_idempotency_key;
  if found then
    if prior.actor_person_id <> actor_id or prior.asset_id <> p_asset_id
        or prior.payload_hash <> request_hash then
      raise invalid_parameter_value using message = 'idempotency key reused';
    end if;
    return prior.result_json;
  end if;
  if asset.revision <> p_expected_revision then
    raise exception 'meal plan image revision conflict' using errcode = 'P0003';
  end if;
  if app_private.meal_plan_image_parent_status(asset)
      not in ('draft', 'inReview', 'updated', 'archived') then
    raise invalid_parameter_value using message = 'meal plan image parent is immutable';
  end if;

  raw_result := app_private.meal_plan_request_image_delete_unreceipted(
    p_asset_id, p_idempotency_key
  );
  update public.meal_plan_image_assets
  set revision = revision + 1
  where id = p_asset_id
  returning * into asset;
  result_payload := raw_result || jsonb_build_object('revision', asset.revision);
  update app_private.meal_plan_image_delete_requests
  set expected_revision = p_expected_revision,
      payload_hash = request_hash,
      result_json = result_payload,
      state = case when confirmed_at is null then 'pending' else 'completed' end,
      completed_at = confirmed_at
  where request_id = p_idempotency_key;
  return result_payload;
end;
$function$;

create or replace function app_private.meal_plan_request_image_delete(
  p_asset_id uuid,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare current_revision integer;
begin
  select revision into current_revision
  from public.meal_plan_image_assets
  where id = p_asset_id;
  if not found then raise no_data_found using message = 'meal plan image not found'; end if;
  return app_private.meal_plan_request_image_delete(
    p_asset_id, p_idempotency_key, current_revision
  );
end;
$function$;

create or replace function public.meal_plan_request_image_delete(
  p_asset_id uuid,
  p_idempotency_key uuid,
  p_expected_revision integer
)
returns jsonb
language sql
security definer
set search_path = ''
as $function$
  select app_private.meal_plan_request_image_delete(
    p_asset_id, p_idempotency_key, p_expected_revision
  );
$function$;

drop policy if exists meal_plan_image_object_delete on storage.objects;

create or replace function public.meal_plan_claim_image_cleanup(p_limit integer default 20)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
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
    'bucket', 'coelo-meal-plans-private',
    'path', claimed.storage_path,
    'attempt', claimed.attempts
  ) order by claimed.created_at), '[]'::jsonb)
  into result_payload
  from claimed;
  return result_payload;
end;
$function$;

create or replace function public.meal_plan_complete_image_cleanup(
  p_request_id uuid,
  p_succeeded boolean,
  p_error text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
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
    select exists (
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
$function$;

revoke all on function app_private.meal_plan_image_delete_request_defaults()
  from public, anon, authenticated, service_role;
revoke all on function app_private.meal_plan_image_parent_status(
  public.meal_plan_image_assets
) from public, anon, authenticated, service_role;
revoke all on function app_private.meal_plan_finalize_image_upload(
  uuid, text, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function app_private.meal_plan_request_image_delete(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function app_private.meal_plan_request_image_delete(
  uuid, uuid, integer
) from public, anon, authenticated, service_role;

revoke all on function public.meal_plan_request_image_delete(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.meal_plan_request_image_delete(uuid, uuid, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.meal_plan_request_image_delete(uuid, uuid)
  to authenticated;
grant execute on function public.meal_plan_request_image_delete(uuid, uuid, integer)
  to authenticated;

revoke all on function public.meal_plan_claim_image_cleanup(integer)
  from public, anon, authenticated, service_role;
revoke all on function public.meal_plan_complete_image_cleanup(uuid, boolean, text)
  from public, anon, authenticated, service_role;
grant execute on function public.meal_plan_claim_image_cleanup(integer)
  to service_role;
grant execute on function public.meal_plan_complete_image_cleanup(uuid, boolean, text)
  to service_role;

commit;
