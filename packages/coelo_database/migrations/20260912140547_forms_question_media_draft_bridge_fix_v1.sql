-- Correcao forward-only do candidato 140546, ja consumido pelo espelho G0.
-- Mantem a raiz deny-by-default do lote 49: consumidores que conhecem a
-- instituicao devem passa-la explicitamente a has_platform_permission.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
declare
  fk_action "char";
  fk_deferred boolean;
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'forms question media bridge fix must run as postgres';
  end if;
  if to_regprocedure('app_private.has_platform_permission(text,uuid)') is null
    or to_regprocedure('app_private.form_replace_working_definition(uuid,jsonb)') is null
    or to_regprocedure('app_private.form_get_editor(uuid)') is null
    or to_regprocedure('app_private.form_save_draft(uuid,bigint,jsonb)') is null
    or to_regprocedure('public.superadmin_form_media_prepare_v2(uuid,uuid,uuid,uuid,text,bigint,text)') is null then
    raise object_not_in_prerequisite_state using
      message = 'forms question media bridge 140546 and institution-aware permission must exist';
  end if;
  select constraint_record.confdeltype, constraint_record.condeferrable
    into fk_action, fk_deferred
    from pg_catalog.pg_constraint constraint_record
   where constraint_record.conrelid = 'public.media_bindings'::regclass
     and constraint_record.conname = 'media_bindings_item_id_fkey';
  if fk_action is distinct from 'r' or fk_deferred is distinct from true then
    raise object_not_in_prerequisite_state using
      message = 'forms question media bridge 140546 FK baseline drift';
  end if;
end
$preflight$;

-- RESTRICT executa a verificacao imediatamente mesmo em constraint marcada
-- deferrable. NO ACTION permite o delete/reinsert atomico e continua falhando
-- no SET CONSTRAINTS IMMEDIATE se o item vinculado sumir do payload.
alter table public.media_bindings
  drop constraint media_bindings_item_id_fkey;
alter table public.media_bindings
  add constraint media_bindings_item_id_fkey
  foreign key (item_id) references public.form_items(id)
  on delete no action deferrable initially immediate;

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
  -- Resolve somente o tenant do recurso antes do gate; nenhuma projecao ou
  -- dado do formulario sai antes da autorizacao.
  select form_row.institution_id, form_row.working_version_id
    into form_institution_id, working_version_id
    from public.forms form_row
   where form_row.id = p_form_id
     and not app_private.superadmin_form_is_internal_draft_v2(form_row.id);
  if not found then
    raise no_data_found using message = 'form unavailable';
  end if;

  actor := app_private.current_person_id();
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  if not app_private.has_platform_permission('forms.manage', form_institution_id)
     and not app_private.has_platform_permission('forms.read', form_institution_id) then
    raise insufficient_privilege using message = 'forms.read required';
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

create or replace function app_private.form_save_draft(
  p_request_id uuid,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid;
  target_form_id uuid;
  requested_institution_id uuid;
  authorization_institution_id uuid;
  form_row public.forms;
  version_id uuid;
  next_version_number integer;
  replay jsonb;
  result jsonb;
  before_state jsonb;
begin
  actor := app_private.current_person_id();
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  perform app_private.form_assert_payload_keys(
    p_payload,
    array['id','institution_id','kind','identity_mode','response_unit','title','description','sections'],
    'form draft'
  );
  target_form_id := coalesce((p_payload ->> 'id')::uuid, gen_random_uuid());
  requested_institution_id := (p_payload ->> 'institution_id')::uuid;
  select existing.institution_id into authorization_institution_id
    from public.forms existing where existing.id = target_form_id;
  authorization_institution_id := coalesce(authorization_institution_id, requested_institution_id);
  if not app_private.has_platform_permission('forms.manage', authorization_institution_id) then
    raise insufficient_privilege using message = 'forms.manage required';
  end if;

  perform app_private.superadmin_form_lock_legacy_resource_v2(target_form_id);
  replay := app_private.form_begin_command(
    p_request_id, actor, 'form_save_draft', p_expected_version, p_payload
  );
  if replay is not null then return replay; end if;

  perform pg_advisory_xact_lock(hashtextextended(target_form_id::text, 0));
  select * into form_row from public.forms where id = target_form_id for update;
  perform app_private.superadmin_form_assert_legacy_resource_v2(form_row.id);
  before_state := case when form_row.id is null then null else app_private.form_definition_projection(target_form_id) end;
  if form_row.id is null then
    if p_expected_version <> 0 then
      raise serialization_failure using message = 'expected_version mismatch';
    end if;
    insert into public.forms(
      id, institution_id, kind, identity_mode, response_unit, title, description,
      created_by_person_id, updated_by_person_id
    ) values (
      target_form_id, requested_institution_id, p_payload ->> 'kind',
      p_payload ->> 'identity_mode', p_payload ->> 'response_unit',
      btrim(p_payload ->> 'title'), nullif(btrim(p_payload ->> 'description'), ''),
      actor, actor
    ) returning * into form_row;
    next_version_number := 1;
    insert into public.form_versions(form_id, version_number, created_by_person_id)
    values (target_form_id, next_version_number, actor)
    returning id into version_id;
    update public.forms set working_version_id = version_id where id = target_form_id;
  else
    if form_row.management_version <> p_expected_version then
      raise serialization_failure using message = 'expected_version mismatch';
    end if;
    if form_row.institution_id <> requested_institution_id then
      raise check_violation using message = 'use form_copy_or_move for institution changes';
    end if;
    if form_row.first_published_at is not null
       and form_row.identity_mode <> p_payload ->> 'identity_mode' then
      raise check_violation using message = 'identity mode is immutable after first publication';
    end if;
    version_id := form_row.working_version_id;
    if version_id is null then
      select coalesce(max(fv.version_number), 0) + 1 into next_version_number
        from public.form_versions fv where fv.form_id = form_row.id;
      insert into public.form_versions(form_id, version_number, created_by_person_id)
      values (target_form_id, next_version_number, actor)
      returning id into version_id;
    end if;
    update public.forms
       set institution_id = requested_institution_id,
           kind = p_payload ->> 'kind',
           identity_mode = p_payload ->> 'identity_mode',
           response_unit = p_payload ->> 'response_unit',
           title = btrim(p_payload ->> 'title'),
           description = nullif(btrim(p_payload ->> 'description'), ''),
           working_version_id = version_id,
           management_version = management_version + 1,
           updated_by_person_id = actor,
           updated_at = now()
     where id = target_form_id;
  end if;

  perform app_private.form_replace_working_definition(version_id, p_payload -> 'sections');
  result := app_private.form_definition_projection(target_form_id);
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id,
    outcome, before_json, after_json
  ) values (
    actor, auth.jwt() ->> 'aal', 'forms.draft.save', 'form', target_form_id,
    requested_institution_id, 'success', before_state,
    jsonb_build_object('management_version', result -> 'management_version')
  );
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

-- O corpo permanece igual ao 140546 exceto pelo gate people-based, agora
-- escopado ao tenant real que ja foi filtrado pelo contexto interno.
create or replace function public.superadmin_form_media_prepare_v2(
  p_request_id uuid, p_form_id uuid, p_form_version_id uuid, p_item_id uuid,
  p_mime_type text, p_byte_size bigint, p_sha256 text
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid(); code text;
  target public.forms%rowtype; actor_person_id uuid;
  mime text := lower(btrim(coalesce(p_mime_type,''))); sha text := lower(btrim(coalesce(p_sha256,'')));
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
    where f.id = p_form_id
      and (ctx.scope_kind <> 'institution' or f.institution_id = ctx.scope_institution_id)
    for share;
    if target.id is null then raise no_data_found using detail='FORM_MEDIA_NOT_FOUND'; end if;
    if target.created_by_internal_identity_id is null then
      actor_person_id := app_private.current_person_id();
      if actor_person_id is null
        or not app_private.has_platform_permission('forms.manage', target.institution_id)
        or target.created_by_person_id is null then
        raise no_data_found using detail='FORM_MEDIA_NOT_FOUND';
      end if;
      perform app_private.superadmin_form_assert_legacy_resource_v2(target.id);
    end if;
    if not exists (select 1 from public.form_items item join public.form_versions v on v.id = item.form_version_id
      where item.id = p_item_id and item.form_version_id = p_form_version_id and v.form_id = target.id
        and v.state = 'working' and v.published_at is null) then
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
      insert into public.media_assets(id, institution_id, form_id, owner_person_id, owner_internal_identity_id,
        catalog_kind, media_purpose, storage_provider, bucket_id, object_key, original_name, upload_request_id, mime_type, status)
      values (new_asset_id, target.institution_id, target.id, actor_person_id,
        case when actor_person_id is null then ctx.internal_identity_id else null end,
        'form-image', 'question-image', 'r2', 'coelo-media-prod', object_key, '', p_request_id::text, mime, 'pending')
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
        p_byte_size, sha, now() + interval '30 minutes') returning * into prior;
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

alter function app_private.form_get_editor(uuid) owner to postgres;
alter function app_private.form_save_draft(uuid,bigint,jsonb) owner to postgres;
alter function public.superadmin_form_media_prepare_v2(uuid,uuid,uuid,uuid,text,bigint,text) owner to postgres;
revoke all on function app_private.form_get_editor(uuid),
  app_private.form_save_draft(uuid,bigint,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.superadmin_form_media_prepare_v2(uuid,uuid,uuid,uuid,text,bigint,text)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_form_media_prepare_v2(uuid,uuid,uuid,uuid,text,bigint,text)
  to authenticated;

commit;
