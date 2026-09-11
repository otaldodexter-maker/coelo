-- R05 realm-interno (4): forms_files — arquivos de Formularios no R2 privado
-- (ADR 0032) sobre o catalogo private_media_catalog (230007: media_assets
-- form-image + media_bindings + media_variants), finalidade question-image
-- (imagem de pergunta, autoria pelo Superadmin no realm interno).
--
-- RPCs (forms.manage no realm interno; escopo por instituicao do formulario):
--   * superadmin_form_media_prepare_v2(p_request_id, p_form_id, p_form_version_id,
--     p_item_id, p_mime_type, p_byte_size, p_sha256): media_assets pending +
--     media_bindings(question-image) + ticket privado; devolve object_key,
--     bucket e finalize_ticket para a Edge Function form-media assinar o PUT.
--   * superadmin_form_media_authorize_finalize_v2(p_asset_id): o autor
--     libera a finalizacao (ticket) para a Edge Function medir o objeto.
--   * form_media_finalize_question_r2_v1(p_asset_id, p_finalize_ticket,
--     p_byte_size, p_checksum_sha256, p_pixel_width, p_pixel_height)
--     [service_role]: variante original + asset ready; medidas divergentes
--     -> asset deleted (fila de limpeza) e FORM_MEDIA_MISMATCH.
--   * superadmin_form_media_resolve_v2(p_asset_id): resolve/baixa imagem de
--     pergunta pronta (object_key + ttl para a Edge Function assinar o GET),
--     auditado. Respostas (answer-image) continuam em
--     superadmin_form_authorize_media_read_v2 (230011).
--   * superadmin_form_media_delete_v2(p_request_id, p_asset_id): exclui
--     (status deleted) e enfileira a limpeza fisica no R2; idempotente.
--   * form_media_expire_question_r2_v1(p_limit) [service_role, cron]:
--     pendentes com ticket vencido (30 min) viram deleted + fila de limpeza.
--   * form_media_claim_cleanup_r2_v1(p_limit) / form_media_mark_purged_r2_v1
--     [service_role, worker]: entrega e baixa das chaves a apagar no R2.
--
-- Limites: image/jpeg|png|webp ate 4 MiB (constraint do catalogo), ate 2560
-- px, uma posicao por (item, versao). Nenhum grant a anon; helpers privados;
-- tabelas novas em app_private sem grant a cliente.
--
-- Reversao: drop das funcoes *_form_media_*_v2 / form_media_*_r2_v1 e das
-- tabelas app_private.form_media_upload_tickets e app_private.form_media_r2_cleanup.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'forms media migration must run as postgres';
  end if;
  if to_regclass('public.media_assets') is null or to_regclass('public.media_bindings') is null
    or to_regclass('public.media_variants') is null
    or to_regprocedure('app_private.private_media_catalog_key_v1(public.media_assets,text,text,text)') is null
    or to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regprocedure('app_private.superadmin_internal_error_envelope(text,uuid)') is null
    or not exists (select 1 from information_schema.columns where table_schema='public'
      and table_name='forms' and column_name='created_by_internal_identity_id')
    or not exists (select 1 from public.platform_permissions where code = 'forms.manage') then
    raise object_not_in_prerequisite_state using
      message = 'private media catalog (230007), internal form drafts (230004) and forms.manage are required';
  end if;
end
$preflight$;

-- 1. Tabelas privadas -----------------------------------------------------------
create table app_private.form_media_upload_tickets (
  asset_id uuid primary key references public.media_assets(id) on delete cascade,
  finalize_ticket uuid not null unique default gen_random_uuid(),
  internal_identity_id uuid not null references app_private.superadmin_internal_identities(id),
  internal_auth_link_id uuid not null,
  internal_membership_id uuid not null,
  session_id uuid not null,
  institution_id uuid not null references public.institutions(id),
  form_id uuid not null references public.forms(id),
  request_id uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  expected_byte_size bigint not null check (expected_byte_size between 1 and 4194304),
  expected_sha256 text not null check (expected_sha256 ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now(),
  unique (internal_identity_id, request_id)
);
create table app_private.form_media_r2_cleanup (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.media_assets(id) on delete cascade,
  bucket_id text not null,
  object_key text not null,
  reason text not null check (reason in ('deleted','expired','mismatch')),
  queued_at timestamptz not null default now(),
  claimed_at timestamptz,
  purged_at timestamptz,
  unique (bucket_id, object_key)
);
alter table app_private.form_media_upload_tickets enable row level security;
alter table app_private.form_media_upload_tickets force row level security;
alter table app_private.form_media_r2_cleanup enable row level security;
alter table app_private.form_media_r2_cleanup force row level security;
revoke all on table app_private.form_media_upload_tickets, app_private.form_media_r2_cleanup
  from public, anon, authenticated, service_role;
create index form_media_upload_tickets_expiry_idx on app_private.form_media_upload_tickets(expires_at) where used_at is null;
create index form_media_r2_cleanup_pending_idx on app_private.form_media_r2_cleanup(queued_at) where purged_at is null;

-- 2. Envelope -------------------------------------------------------------------
create function app_private.form_media_envelope_error_v1(p_code text, p_correlation uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select case when p_code in ('FORM_MEDIA_INVALID','FORM_MEDIA_NOT_FOUND','FORM_MEDIA_NOT_READY',
      'FORM_MEDIA_TICKET_INVALID','FORM_MEDIA_MISMATCH','FORM_MEDIA_REPLAY_MISMATCH')
    then pg_catalog.jsonb_build_object('ok', false, 'data', null, 'error', pg_catalog.jsonb_build_object(
      'code', p_code,
      'message', case p_code
        when 'FORM_MEDIA_INVALID' then 'Imagem não permitida: confira o tipo e o tamanho.'
        when 'FORM_MEDIA_NOT_FOUND' then 'Arquivo não encontrado.'
        when 'FORM_MEDIA_NOT_READY' then 'O arquivo ainda não terminou de ser enviado.'
        when 'FORM_MEDIA_TICKET_INVALID' then 'O envio expirou. Envie o arquivo novamente.'
        when 'FORM_MEDIA_MISMATCH' then 'O arquivo recebido não confere com o anunciado.'
        else 'A solicitação já foi usada com outros dados.' end,
      'http_status', case p_code
        when 'FORM_MEDIA_NOT_FOUND' then 404
        when 'FORM_MEDIA_INVALID' then 422 when 'FORM_MEDIA_MISMATCH' then 422
        else 409 end,
      'correlation_id', p_correlation))
    else app_private.superadmin_internal_error_envelope(p_code, p_correlation) end
$$;
create function app_private.form_media_success_v1(p_data jsonb)
returns jsonb language sql immutable security invoker set search_path='' as $$
  select pg_catalog.jsonb_build_object('ok', true, 'data', p_data, 'error', null)
$$;

-- 3. prepare -------------------------------------------------------------------
create function public.superadmin_form_media_prepare_v2(
  p_request_id uuid, p_form_id uuid, p_form_version_id uuid, p_item_id uuid,
  p_mime_type text, p_byte_size bigint, p_sha256 text
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid(); code text;
  target public.forms%rowtype; mime text := lower(btrim(coalesce(p_mime_type,''))); sha text := lower(btrim(coalesce(p_sha256,'')));
  request_hash bytea; prior app_private.form_media_upload_tickets%rowtype;
  asset public.media_assets%rowtype; new_asset_id uuid := gen_random_uuid(); object_key text; next_position integer;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.manage');
    if p_request_id is null or p_form_id is null or p_form_version_id is null or p_item_id is null then
      raise invalid_parameter_value using detail='FORM_MEDIA_INVALID';
    end if;
    if mime not in ('image/jpeg','image/png','image/webp') or p_byte_size is null
      or p_byte_size < 1 or p_byte_size > 4194304 or sha !~ '^[0-9a-f]{64}$' then
      raise invalid_parameter_value using detail='FORM_MEDIA_INVALID';
    end if;
    select f.* into target from public.forms f
    where f.id = p_form_id and f.created_by_internal_identity_id is not null
      and (ctx.scope_kind <> 'institution' or f.institution_id = ctx.scope_institution_id) for share;
    if target.id is null then raise no_data_found using detail='FORM_MEDIA_NOT_FOUND'; end if;
    if not exists (select 1 from public.form_items item join public.form_versions v on v.id = item.form_version_id
      where item.id = p_item_id and item.form_version_id = p_form_version_id and v.form_id = target.id) then
      raise no_data_found using detail='FORM_MEDIA_NOT_FOUND';
    end if;
    request_hash := extensions.digest(convert_to(jsonb_build_object('form_id', p_form_id, 'form_version_id', p_form_version_id,
      'item_id', p_item_id, 'mime_type', mime, 'byte_size', p_byte_size, 'sha256', sha)::text, 'UTF8'), 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(ctx.internal_identity_id::text || p_request_id::text, 0));
    select * into prior from app_private.form_media_upload_tickets t
    where t.internal_identity_id = ctx.internal_identity_id and t.request_id = p_request_id for update;
    if prior.asset_id is not null then
      if prior.request_hash <> request_hash then raise unique_violation using detail='FORM_MEDIA_REPLAY_MISMATCH'; end if;
      select * into asset from public.media_assets where id = prior.asset_id;
    else
      object_key := 'tenants/' || target.institution_id::text || '/forms/form/' || target.id::text
        || '/question-image/' || new_asset_id::text || '/original/' || gen_random_uuid()::text
        || case mime when 'image/jpeg' then '.jpg' when 'image/png' then '.png' else '.webp' end;
      insert into public.media_assets(id, institution_id, form_id, owner_internal_identity_id, catalog_kind,
        media_purpose, storage_provider, bucket_id, object_key, original_name, upload_request_id, mime_type, status)
      values (new_asset_id, target.institution_id, target.id, ctx.internal_identity_id, 'form-image',
        'question-image', 'r2', 'coelo-media-prod', object_key, '', p_request_id::text, mime, 'pending')
      returning * into asset;
      select coalesce(max(b.position), -1) + 1 into next_position from public.media_bindings b
      join public.media_assets a on a.id = b.media_asset_id
      where b.item_id = p_item_id and b.form_version_id = p_form_version_id and b.purpose = 'question-image'
        and a.status <> 'deleted';
      insert into public.media_bindings(media_asset_id, form_version_id, item_id, purpose, position)
      values (asset.id, p_form_version_id, p_item_id, 'question-image', next_position);
      insert into app_private.form_media_upload_tickets(asset_id, internal_identity_id, internal_auth_link_id,
        internal_membership_id, session_id, institution_id, form_id, request_id, request_hash,
        expected_byte_size, expected_sha256, expires_at)
      values (asset.id, ctx.internal_identity_id, ctx.internal_auth_link_id, ctx.internal_membership_id,
        ctx.session_id, target.institution_id, target.id, p_request_id, request_hash,
        p_byte_size, sha, now() + interval '30 minutes')
      returning * into prior;
      perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id, ctx.internal_auth_link_id,
        ctx.internal_membership_id, ctx.session_id, 'forms.manage', ctx.aal, 'forms.media.prepare', 'success',
        null, correlation, target.institution_id, 'media_asset', asset.id);
    end if;
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR');
  end;
  if code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified('forms.manage', 'forms.media.prepare',
      code, correlation, target.institution_id);
    return app_private.form_media_envelope_error_v1(code, correlation);
  end if;
  return app_private.form_media_success_v1(jsonb_build_object(
    'asset_id', asset.id, 'form_id', asset.form_id, 'object_key', asset.object_key, 'bucket', asset.bucket_id,
    'mime_type', asset.mime_type, 'byte_size', prior.expected_byte_size, 'sha256', prior.expected_sha256, 'status', asset.status::text,
    'finalize_ticket', prior.finalize_ticket, 'expires_at', prior.expires_at,
    'replayed', prior.used_at is not null or asset.status <> 'pending'));
end $$;

-- 4. authorize_finalize ----------------------------------------------------------
create function public.superadmin_form_media_authorize_finalize_v2(p_asset_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid(); code text;
  ticket app_private.form_media_upload_tickets%rowtype; asset public.media_assets%rowtype;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.manage');
    select * into ticket from app_private.form_media_upload_tickets t
    where t.asset_id = p_asset_id and t.internal_identity_id = ctx.internal_identity_id
      and (ctx.scope_kind <> 'institution' or t.institution_id = ctx.scope_institution_id);
    if ticket.asset_id is null then raise no_data_found using detail='FORM_MEDIA_NOT_FOUND'; end if;
    select * into asset from public.media_assets where id = p_asset_id;
    if ticket.used_at is not null or ticket.expires_at < now() or asset.status <> 'pending' then
      raise object_not_in_prerequisite_state using detail='FORM_MEDIA_TICKET_INVALID';
    end if;
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR');
  end;
  if code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified('forms.manage', 'forms.media.authorize_finalize',
      code, correlation, ticket.institution_id);
    return app_private.form_media_envelope_error_v1(code, correlation);
  end if;
  return app_private.form_media_success_v1(jsonb_build_object('asset_id', asset.id, 'object_key', asset.object_key,
    'bucket', asset.bucket_id, 'mime_type', asset.mime_type, 'finalize_ticket', ticket.finalize_ticket,
    'expires_at', ticket.expires_at));
end $$;

-- 5. finalize (service_role) -------------------------------------------------------
create function public.form_media_finalize_question_r2_v1(
  p_asset_id uuid, p_finalize_ticket uuid, p_byte_size bigint, p_checksum_sha256 text,
  p_pixel_width integer, p_pixel_height integer
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare correlation uuid := gen_random_uuid(); code text; mismatch boolean := false;
  ticket app_private.form_media_upload_tickets%rowtype; asset public.media_assets%rowtype;
  sha text := lower(btrim(coalesce(p_checksum_sha256, '')));
begin
  begin
    if coalesce(nullif(current_setting('request.jwt.claim.role', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '') <> 'service_role' then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    select * into ticket from app_private.form_media_upload_tickets t
    where t.asset_id = p_asset_id and t.finalize_ticket = p_finalize_ticket for update;
    if ticket.asset_id is null then raise no_data_found using detail='FORM_MEDIA_NOT_FOUND'; end if;
    select * into asset from public.media_assets where id = p_asset_id for update;
    if ticket.used_at is not null or ticket.expires_at < now() or asset.status <> 'pending' then
      raise object_not_in_prerequisite_state using detail='FORM_MEDIA_TICKET_INVALID';
    end if;
    if p_byte_size is distinct from ticket.expected_byte_size or sha is distinct from ticket.expected_sha256
      or p_pixel_width is null or p_pixel_height is null
      or p_pixel_width not between 1 and 2560 or p_pixel_height not between 1 and 2560 then
      mismatch := true;
    end if;
    if not mismatch then
      update public.media_assets set byte_size = p_byte_size, checksum_sha256 = sha,
        pixel_width = p_pixel_width, pixel_height = p_pixel_height, status = 'ready', finalized_at = now()
      where id = asset.id returning * into asset;
      insert into public.media_variants(media_asset_id, rendition, bucket_id, object_key, mime_type,
        byte_size, checksum_sha256, pixel_width, pixel_height)
      values (asset.id, 'original', asset.bucket_id, asset.object_key, asset.mime_type,
        asset.byte_size, asset.checksum_sha256, asset.pixel_width, asset.pixel_height);
      update app_private.form_media_upload_tickets set used_at = now() where asset_id = asset.id;
      perform app_private.audit_append_superadmin_internal(ticket.internal_identity_id, ticket.internal_auth_link_id,
        ticket.internal_membership_id, ticket.session_id, 'forms.manage', 'aal1', 'forms.media.finalize', 'success',
        null, correlation, ticket.institution_id, 'media_asset', asset.id);
    end if;
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR');
  end;
  if code is null and mismatch then
    update public.media_assets set status = 'deleted' where id = asset.id;
    insert into app_private.form_media_r2_cleanup(asset_id, bucket_id, object_key, reason)
    values (asset.id, asset.bucket_id, asset.object_key, 'mismatch') on conflict do nothing;
    update app_private.form_media_upload_tickets set used_at = now() where asset_id = asset.id;
    perform app_private.audit_append_superadmin_internal(ticket.internal_identity_id, ticket.internal_auth_link_id,
      ticket.internal_membership_id, ticket.session_id, 'forms.manage', 'aal1', 'forms.media.finalize', 'failed',
      'FORM_MEDIA_MISMATCH', correlation, ticket.institution_id, 'media_asset', asset.id);
    code := 'FORM_MEDIA_MISMATCH';
  end if;
  if code is not null then return app_private.form_media_envelope_error_v1(code, correlation); end if;
  return app_private.form_media_success_v1(jsonb_build_object('asset_id', asset.id, 'status', asset.status::text,
    'finalized_at', asset.finalized_at));
end $$;

-- 6. resolve / download (question-image pronta) --------------------------------------
create function public.superadmin_form_media_resolve_v2(p_asset_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid(); code text;
  asset public.media_assets%rowtype; variant public.media_variants%rowtype;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.read');
    select a.* into asset from public.media_assets a
    where a.id = p_asset_id and a.catalog_kind = 'form-image' and a.media_purpose = 'question-image'
      and a.status <> 'deleted' and (ctx.scope_kind <> 'institution' or a.institution_id = ctx.scope_institution_id);
    if asset.id is null then raise no_data_found using detail='FORM_MEDIA_NOT_FOUND'; end if;
    if asset.status <> 'ready' then raise object_not_in_prerequisite_state using detail='FORM_MEDIA_NOT_READY'; end if;
    select v.* into variant from public.media_variants v where v.media_asset_id = asset.id and v.rendition = 'original';
    if variant.media_asset_id is null then raise object_not_in_prerequisite_state using detail='FORM_MEDIA_NOT_READY'; end if;
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id, ctx.internal_auth_link_id,
      ctx.internal_membership_id, ctx.session_id, 'forms.read', ctx.aal, 'forms.media.resolve', 'success',
      null, correlation, asset.institution_id, 'media_asset', asset.id);
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR');
  end;
  if code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified('forms.read', 'forms.media.resolve',
      code, correlation, asset.institution_id);
    return app_private.form_media_envelope_error_v1(code, correlation);
  end if;
  return app_private.form_media_success_v1(jsonb_build_object('asset_id', asset.id, 'form_id', asset.form_id,
    'rendition', 'original', 'bucket', variant.bucket_id, 'object_key', variant.object_key,
    'mime_type', variant.mime_type, 'byte_size', variant.byte_size, 'sha256', variant.checksum_sha256,
    'pixel_width', variant.pixel_width, 'pixel_height', variant.pixel_height, 'ttl_seconds', 300));
end $$;

-- 7. delete --------------------------------------------------------------------------
create function public.superadmin_form_media_delete_v2(p_request_id uuid, p_asset_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid(); code text;
  asset public.media_assets%rowtype; already boolean := false;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.manage');
    if p_request_id is null then raise invalid_parameter_value using detail='FORM_MEDIA_INVALID'; end if;
    select a.* into asset from public.media_assets a
    where a.id = p_asset_id and a.catalog_kind = 'form-image' and a.media_purpose = 'question-image'
      and (ctx.scope_kind <> 'institution' or a.institution_id = ctx.scope_institution_id) for update;
    if asset.id is null then raise no_data_found using detail='FORM_MEDIA_NOT_FOUND'; end if;
    if asset.status = 'deleted' then
      already := true;
    else
      update public.media_assets set status = 'deleted' where id = asset.id returning * into asset;
      insert into app_private.form_media_r2_cleanup(asset_id, bucket_id, object_key, reason)
      select asset.id, v.bucket_id, v.object_key, 'deleted' from public.media_variants v where v.media_asset_id = asset.id
      union select asset.id, asset.bucket_id, asset.object_key, 'deleted'
      on conflict do nothing;
      update app_private.form_media_upload_tickets set used_at = coalesce(used_at, now()) where asset_id = asset.id;
      perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id, ctx.internal_auth_link_id,
        ctx.internal_membership_id, ctx.session_id, 'forms.manage', ctx.aal, 'forms.media.delete', 'success',
        null, correlation, asset.institution_id, 'media_asset', asset.id);
    end if;
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR');
  end;
  if code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified('forms.manage', 'forms.media.delete',
      code, correlation, asset.institution_id);
    return app_private.form_media_envelope_error_v1(code, correlation);
  end if;
  return app_private.form_media_success_v1(jsonb_build_object('asset_id', asset.id, 'status', 'deleted', 'replayed', already));
end $$;

-- 8. expire e limpeza (service_role) ---------------------------------------------------
create function app_private.form_media_assert_worker_v1() returns void
language plpgsql stable security invoker set search_path='' as $$
begin
  if coalesce(nullif(current_setting('request.jwt.claim.role', true), ''),
      nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '') <> 'service_role' then
    raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
  end if;
end $$;

create function public.form_media_expire_question_r2_v1(p_limit integer default 100)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare expired integer := 0; item record;
begin
  perform app_private.form_media_assert_worker_v1();
  for item in
    select t.asset_id, a.bucket_id, a.object_key from app_private.form_media_upload_tickets t
    join public.media_assets a on a.id = t.asset_id
    where t.used_at is null and t.expires_at < now() and a.status = 'pending'
    order by t.expires_at limit least(greatest(coalesce(p_limit, 100), 1), 500) for update of t skip locked
  loop
    update public.media_assets set status = 'deleted' where id = item.asset_id;
    insert into app_private.form_media_r2_cleanup(asset_id, bucket_id, object_key, reason)
    values (item.asset_id, item.bucket_id, item.object_key, 'expired') on conflict do nothing;
    update app_private.form_media_upload_tickets set used_at = now() where asset_id = item.asset_id;
    expired := expired + 1;
  end loop;
  return app_private.form_media_success_v1(jsonb_build_object('expired', expired));
exception when insufficient_privilege then
  return app_private.form_media_envelope_error_v1('SAI_PERMISSION_DENIED', gen_random_uuid());
end $$;

create function public.form_media_claim_cleanup_r2_v1(p_limit integer default 50)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare items jsonb;
begin
  perform app_private.form_media_assert_worker_v1();
  with claimed as (
    select c.id from app_private.form_media_r2_cleanup c
    where c.purged_at is null and (c.claimed_at is null or c.claimed_at < now() - interval '10 minutes')
    order by c.queued_at limit least(greatest(coalesce(p_limit, 50), 1), 200) for update skip locked
  ), updated as (
    update app_private.form_media_r2_cleanup c set claimed_at = now() from claimed where c.id = claimed.id
    returning c.id, c.bucket_id, c.object_key
  )
  select coalesce(jsonb_agg(jsonb_build_object('cleanup_id', u.id, 'bucket', u.bucket_id, 'object_key', u.object_key)), '[]'::jsonb)
  into items from updated u;
  return app_private.form_media_success_v1(jsonb_build_object('items', items));
exception when insufficient_privilege then
  return app_private.form_media_envelope_error_v1('SAI_PERMISSION_DENIED', gen_random_uuid());
end $$;

create function public.form_media_mark_purged_r2_v1(p_cleanup_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
begin
  perform app_private.form_media_assert_worker_v1();
  update app_private.form_media_r2_cleanup set purged_at = now() where id = p_cleanup_id and purged_at is null;
  return app_private.form_media_success_v1(jsonb_build_object('cleanup_id', p_cleanup_id, 'purged', found));
exception when insufficient_privilege then
  return app_private.form_media_envelope_error_v1('SAI_PERMISSION_DENIED', gen_random_uuid());
end $$;

-- 9. Donos e privilegios ----------------------------------------------------------------
alter table app_private.form_media_upload_tickets owner to postgres;
alter table app_private.form_media_r2_cleanup owner to postgres;
do $grants$ declare p regprocedure; begin
  foreach p in array array[
    'app_private.form_media_envelope_error_v1(text,uuid)'::regprocedure,
    'app_private.form_media_success_v1(jsonb)'::regprocedure,
    'app_private.form_media_assert_worker_v1()'::regprocedure,
    'public.superadmin_form_media_prepare_v2(uuid,uuid,uuid,uuid,text,bigint,text)'::regprocedure,
    'public.superadmin_form_media_authorize_finalize_v2(uuid)'::regprocedure,
    'public.form_media_finalize_question_r2_v1(uuid,uuid,bigint,text,integer,integer)'::regprocedure,
    'public.superadmin_form_media_resolve_v2(uuid)'::regprocedure,
    'public.superadmin_form_media_delete_v2(uuid,uuid)'::regprocedure,
    'public.form_media_expire_question_r2_v1(integer)'::regprocedure,
    'public.form_media_claim_cleanup_r2_v1(integer)'::regprocedure,
    'public.form_media_mark_purged_r2_v1(uuid)'::regprocedure
  ] loop
    execute format('alter function %s owner to postgres', p);
    execute format('revoke all on function %s from public, anon, authenticated, service_role', p);
  end loop;
end $grants$;
grant execute on function public.superadmin_form_media_prepare_v2(uuid,uuid,uuid,uuid,text,bigint,text),
  public.superadmin_form_media_authorize_finalize_v2(uuid),
  public.superadmin_form_media_resolve_v2(uuid),
  public.superadmin_form_media_delete_v2(uuid,uuid) to authenticated;
grant execute on function public.form_media_finalize_question_r2_v1(uuid,uuid,bigint,text,integer,integer),
  public.form_media_expire_question_r2_v1(integer),
  public.form_media_claim_cleanup_r2_v1(integer),
  public.form_media_mark_purged_r2_v1(uuid) to service_role;

commit;
