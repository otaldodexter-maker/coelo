-- Fecha dois residuos medidos no fluxo question-image:
-- 1. resposta perdida depois do finalize deixava o retry preso, pois authorize
--    e finalize recusavam o ticket usado mesmo quando o asset ja estava ready;
-- 2. delete nominal nao removia media_bindings e a pergunta seguia presa ao FK.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
declare
  fk_action "char";
  fk_deferred boolean;
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'forms question media retry/delete must run as postgres';
  end if;
  if to_regprocedure('public.superadmin_form_media_authorize_finalize_v2(uuid)') is null
    or to_regprocedure('public.form_media_finalize_question_r2_v1(uuid,uuid,bigint,text,integer,integer)') is null
    or to_regprocedure('public.superadmin_form_media_delete_v2(uuid,uuid)') is null
    or to_regclass('app_private.form_media_upload_tickets') is null
    or to_regclass('public.media_bindings') is null then
    raise object_not_in_prerequisite_state using
      message = 'forms question media v1 and bridge are required';
  end if;
  select constraint_record.confdeltype, constraint_record.condeferrable
    into fk_action, fk_deferred
    from pg_catalog.pg_constraint constraint_record
   where constraint_record.conrelid = 'public.media_bindings'::regclass
     and constraint_record.conname = 'media_bindings_item_id_fkey';
  if fk_action is distinct from 'a' or fk_deferred is distinct from true then
    raise object_not_in_prerequisite_state using
      message = 'forms question media bridge fix 140547 must be applied first';
  end if;
end
$preflight$;

create or replace function public.superadmin_form_media_authorize_finalize_v2(p_asset_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid(); code text;
  ticket app_private.form_media_upload_tickets%rowtype; asset public.media_assets%rowtype;
  replayed boolean := false;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.manage');
    select * into ticket from app_private.form_media_upload_tickets t
    where t.asset_id = p_asset_id and t.internal_identity_id = ctx.internal_identity_id
      and (ctx.scope_kind <> 'institution' or t.institution_id = ctx.scope_institution_id);
    if ticket.asset_id is null then raise no_data_found using detail='FORM_MEDIA_NOT_FOUND'; end if;
    select * into asset from public.media_assets where id = p_asset_id;
    if ticket.used_at is null and ticket.expires_at >= now() and asset.status = 'pending' then
      replayed := false;
    elsif ticket.used_at is not null and asset.status = 'ready' then
      -- O mesmo ator pode reconciliar uma finalizacao ja confirmada. O ticket
      -- continua preso ao asset e o worker valida novamente as medidas.
      replayed := true;
    else
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
    'expires_at', ticket.expires_at, 'status', asset.status::text, 'replayed', replayed));
end $$;

create or replace function public.form_media_finalize_question_r2_v1(
  p_asset_id uuid, p_finalize_ticket uuid, p_byte_size bigint, p_checksum_sha256 text,
  p_pixel_width integer, p_pixel_height integer
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare correlation uuid := gen_random_uuid(); code text; mismatch boolean := false; replayed boolean := false;
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

    if ticket.used_at is not null then
      if asset.status = 'ready'
        and p_byte_size is not distinct from asset.byte_size
        and sha is not distinct from asset.checksum_sha256
        and p_pixel_width is not distinct from asset.pixel_width
        and p_pixel_height is not distinct from asset.pixel_height
        and exists (
          select 1 from public.media_variants variant
          where variant.media_asset_id = asset.id and variant.rendition = 'original'
            and variant.byte_size is not distinct from asset.byte_size
            and variant.checksum_sha256 is not distinct from asset.checksum_sha256
            and variant.pixel_width is not distinct from asset.pixel_width
            and variant.pixel_height is not distinct from asset.pixel_height
        ) then
        replayed := true;
      else
        raise object_not_in_prerequisite_state using detail='FORM_MEDIA_TICKET_INVALID';
      end if;
    elsif ticket.expires_at < now() or asset.status <> 'pending' then
      raise object_not_in_prerequisite_state using detail='FORM_MEDIA_TICKET_INVALID';
    else
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
    'finalized_at', asset.finalized_at, 'replayed', replayed));
end $$;

create or replace function public.superadmin_form_media_delete_v2(p_request_id uuid, p_asset_id uuid)
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
    -- O delete nominal encerra o uso no rascunho. Em replay, tambem cura um
    -- binding residual criado pelo corpo anterior.
    delete from public.media_bindings binding
    where binding.media_asset_id = asset.id and binding.purpose = 'question-image';
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

-- Recurso inexistente, rascunho interno e recurso fora do tenant compartilham
-- a mesma resposta externa; a selecao antecipada da instituicao nao vira
-- oraculo de existencia.
create or replace function app_private.form_get_editor(p_form_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid;
  definition_projection jsonb;
  application_projection jsonb;
  form_institution_id uuid;
  working_version_id uuid;
  question_images jsonb;
begin
  select form_row.institution_id, form_row.working_version_id
    into form_institution_id, working_version_id
    from public.forms form_row
   where form_row.id = p_form_id
     and not app_private.superadmin_form_is_internal_draft_v2(form_row.id);
  if not found then
    raise no_data_found using message = 'form unavailable';
  end if;

  actor := app_private.current_person_id();
  if actor is null or (
    not app_private.has_platform_permission('forms.manage', form_institution_id)
    and not app_private.has_platform_permission('forms.read', form_institution_id)
  ) then
    raise no_data_found using message = 'form unavailable';
  end if;

  select app_private.form_definition_projection(form_row.id)
    into definition_projection
    from public.forms form_row
   where form_row.id = p_form_id;
  if definition_projection is null then
    raise no_data_found using message = 'form unavailable';
  end if;

  if app_private.has_platform_permission('forms.manage_applications', form_institution_id) then
    select app_private.form_application_projection(application.id)
      into application_projection
      from public.form_applications application
     where application.form_id = p_form_id
       and application.institution_id = form_institution_id
     order by (application.status = 'archived'), application.updated_at desc, application.id desc
     limit 1;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'item_id', binding.item_id,
    'asset_id', asset.id,
    'status', asset.status::text,
    'mime_type', asset.mime_type,
    'position', binding.position
  ) order by binding.position, asset.id), '[]'::jsonb)
  into question_images
  from public.media_bindings binding
  join public.media_assets asset on asset.id = binding.media_asset_id
  where binding.form_version_id = working_version_id
    and binding.purpose = 'question-image'
    and asset.form_id = p_form_id
    and asset.media_purpose = 'question-image'
    and asset.status <> 'deleted';

  return jsonb_build_object(
    'definition', definition_projection,
    'application', application_projection,
    'media_context', case when working_version_id is null then 'null'::jsonb
      else jsonb_build_object(
        'form_version_id', working_version_id,
        'question_images', question_images
      ) end
  );
end;
$$;

alter function public.superadmin_form_media_authorize_finalize_v2(uuid) owner to postgres;
alter function public.form_media_finalize_question_r2_v1(uuid,uuid,bigint,text,integer,integer) owner to postgres;
alter function public.superadmin_form_media_delete_v2(uuid,uuid) owner to postgres;
alter function app_private.form_get_editor(uuid) owner to postgres;
revoke all on function public.superadmin_form_media_authorize_finalize_v2(uuid),
  public.form_media_finalize_question_r2_v1(uuid,uuid,bigint,text,integer,integer),
  public.superadmin_form_media_delete_v2(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.superadmin_form_media_authorize_finalize_v2(uuid),
  public.superadmin_form_media_delete_v2(uuid,uuid) to authenticated;
grant execute on function public.form_media_finalize_question_r2_v1(uuid,uuid,bigint,text,integer,integer)
  to service_role;
revoke all on function app_private.form_get_editor(uuid) from public,anon,authenticated,service_role;

commit;
