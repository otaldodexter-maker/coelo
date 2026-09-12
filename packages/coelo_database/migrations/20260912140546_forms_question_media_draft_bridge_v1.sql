-- R08 G5/G3: ponte focal de question-image para o editor produtivo.
-- Mantem a autoria people-based criada por form_save_draft e exige o mesmo
-- ator interno autorizado, resolvido pela ponte vigente. Nao fabrica pessoa,
-- nao converte realm e nao devolve object_key, URL ou segredo no editor.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'forms question media bridge must run as postgres';
  end if;
  if to_regprocedure('app_private.form_replace_working_definition(uuid,jsonb)') is null
    or to_regprocedure('app_private.form_get_editor(uuid)') is null
    or to_regprocedure('public.superadmin_form_media_prepare_v2(uuid,uuid,uuid,uuid,text,bigint,text)') is null
    or to_regprocedure('app_private.person_id_for_auth_user(uuid)') is null
    or to_regclass('public.media_bindings') is null then
    raise object_not_in_prerequisite_state using
      message = 'forms, internal actor bridge and question media must exist';
  end if;
end
$preflight$;

-- O replace apaga e recria a arvore dentro da mesma transacao. O FK pode ser
-- adiado somente nesse bloco; ao final volta a imediato. Se um item com midia
-- sumir do payload, a operacao falha fechada ate a exclusao nominal do asset.
alter table public.media_bindings
  drop constraint media_bindings_item_id_fkey;
alter table public.media_bindings
  add constraint media_bindings_item_id_fkey
  foreign key (item_id) references public.form_items(id)
  on delete restrict deferrable initially immediate;

create or replace function app_private.form_replace_working_definition(
  p_version_id uuid,
  p_sections jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  section_json jsonb;
  item_json jsonb;
  option_json jsonb;
  condition_json jsonb;
  source_section_id text;
  source_item_id text;
  source_option_id text;
  stable_item_id uuid;
  section_ids jsonb := '{}'::jsonb;
  item_ids jsonb := '{}'::jsonb;
  option_ids jsonb := '{}'::jsonb;
begin
  if jsonb_typeof(p_sections) <> 'array' then
    raise invalid_parameter_value using message = 'sections must be an array';
  end if;
  if jsonb_array_length(p_sections) > 20 then
    raise check_violation using message = 'maximum 20 form sections';
  end if;

  -- Valida e resolve IDs antes do delete. Somente um UUID que ja pertence ao
  -- mesmo working version e reutilizado; IDs novos, publicados ou estrangeiros
  -- recebem UUID novo.
  for section_json in select value from jsonb_array_elements(p_sections) loop
    perform app_private.form_assert_payload_keys(
      section_json,
      array['id','title','description','position','items'],
      'form section'
    );
    source_section_id := nullif(section_json ->> 'id', '');
    if source_section_id is null or section_ids ? source_section_id then
      raise invalid_parameter_value using message = 'unique section id required';
    end if;
    section_ids := section_ids || jsonb_build_object(source_section_id, gen_random_uuid()::text);
    if jsonb_typeof(section_json -> 'items') <> 'array' then
      raise invalid_parameter_value using message = 'section items must be an array';
    end if;
    for item_json in select value from jsonb_array_elements(section_json -> 'items') loop
      perform app_private.form_assert_payload_keys(
        item_json,
        array['id','kind','label','help_text','position','is_required','config','options','conditions'],
        'form item'
      );
      source_item_id := nullif(item_json ->> 'id', '');
      if source_item_id is null or item_ids ? source_item_id then
        raise invalid_parameter_value using message = 'unique item id required';
      end if;
      stable_item_id := null;
      if source_item_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
        select item.id into stable_item_id
        from public.form_items item
        where item.id = source_item_id::uuid
          and item.form_version_id = p_version_id;
      end if;
      item_ids := item_ids || jsonb_build_object(
        source_item_id,
        coalesce(stable_item_id, gen_random_uuid())::text
      );
      if jsonb_typeof(coalesce(item_json -> 'options', '[]'::jsonb)) <> 'array'
         or jsonb_typeof(coalesce(item_json -> 'conditions', '[]'::jsonb)) <> 'array' then
        raise invalid_parameter_value using message = 'item options and conditions must be arrays';
      end if;
      if jsonb_array_length(coalesce(item_json -> 'options', '[]'::jsonb)) > 50 then
        raise check_violation using message = 'maximum 50 form options per item';
      end if;
      for option_json in select value from jsonb_array_elements(coalesce(item_json -> 'options', '[]'::jsonb)) loop
        perform app_private.form_assert_payload_keys(
          option_json, array['id','label','position'], 'form option'
        );
        source_option_id := nullif(option_json ->> 'id', '');
        if source_option_id is null or option_ids ? source_option_id then
          raise invalid_parameter_value using message = 'unique option id required';
        end if;
        option_ids := option_ids || jsonb_build_object(source_option_id, gen_random_uuid()::text);
      end loop;
    end loop;
  end loop;

  if (select count(*) from jsonb_object_keys(item_ids)) > 200 then
    raise check_violation using message = 'maximum 200 form items';
  end if;

  set constraints public.media_bindings_item_id_fkey deferred;
  delete from public.form_sections where form_version_id = p_version_id;

  for section_json in select value from jsonb_array_elements(p_sections) loop
    source_section_id := section_json ->> 'id';
    insert into public.form_sections(id, form_version_id, title, description, position)
    values (
      (section_ids ->> source_section_id)::uuid,
      p_version_id,
      btrim(section_json ->> 'title'),
      nullif(btrim(section_json ->> 'description'), ''),
      (section_json ->> 'position')::integer
    );
    for item_json in select value from jsonb_array_elements(section_json -> 'items') loop
      source_item_id := item_json ->> 'id';
      insert into public.form_items(
        id, form_version_id, section_id, kind, label, help_text, is_required, position, config_jsonb
      ) values (
        (item_ids ->> source_item_id)::uuid,
        p_version_id,
        (section_ids ->> source_section_id)::uuid,
        item_json ->> 'kind',
        btrim(item_json ->> 'label'),
        nullif(btrim(item_json ->> 'help_text'), ''),
        coalesce((item_json ->> 'is_required')::boolean, false),
        (item_json ->> 'position')::integer,
        coalesce(item_json -> 'config', '{}'::jsonb)
      );
      for option_json in select value from jsonb_array_elements(coalesce(item_json -> 'options', '[]'::jsonb)) loop
        source_option_id := option_json ->> 'id';
        insert into public.form_question_options(id, form_version_id, item_id, label, position)
        values (
          (option_ids ->> source_option_id)::uuid,
          p_version_id,
          (item_ids ->> source_item_id)::uuid,
          btrim(option_json ->> 'label'),
          (option_json ->> 'position')::integer
        );
      end loop;
    end loop;
  end loop;

  for section_json in select value from jsonb_array_elements(p_sections) loop
    for item_json in select value from jsonb_array_elements(section_json -> 'items') loop
      source_item_id := item_json ->> 'id';
      for condition_json in select value from jsonb_array_elements(coalesce(item_json -> 'conditions', '[]'::jsonb)) loop
        perform app_private.form_assert_payload_keys(
          condition_json,
          array['source_item_id','kind','expected_yes_no','option_ids'],
          'form condition'
        );
        if not item_ids ? (condition_json ->> 'source_item_id') then
          raise invalid_parameter_value using message = 'condition source item not found';
        end if;
        for source_option_id in
          select value from jsonb_array_elements_text(
            case when condition_json ->> 'kind' = 'choice'
              then condition_json -> 'option_ids' else '[null]'::jsonb end
          )
        loop
          if condition_json ->> 'kind' = 'choice' and not option_ids ? source_option_id then
            raise invalid_parameter_value using message = 'condition source option not found';
          end if;
          insert into public.form_question_conditions(
            form_version_id, target_item_id, source_item_id, condition_kind,
            expected_yes_no, source_option_id
          ) values (
            p_version_id,
            (item_ids ->> source_item_id)::uuid,
            (item_ids ->> (condition_json ->> 'source_item_id'))::uuid,
            condition_json ->> 'kind',
            (condition_json ->> 'expected_yes_no')::boolean,
            case when source_option_id is null then null
                 else (option_ids ->> source_option_id)::uuid end
          );
        end loop;
      end loop;
    end loop;
  end loop;
  perform app_private.validate_form_definition(p_version_id);
  set constraints public.media_bindings_item_id_fkey immediate;
end;
$$;

-- O editor produtivo preserva o envelope legado e acrescenta somente contexto
-- de catalogo da versao de trabalho ja autorizada.
create or replace function app_private.form_get_editor(p_form_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  definition_projection jsonb;
  application_projection jsonb;
  form_institution_id uuid;
  working_version_id uuid;
  question_images jsonb;
begin
  if app_private.has_platform_permission('forms.manage') then
    perform app_private.require_forms_actor('forms.manage');
  else
    perform app_private.require_forms_actor('forms.read');
  end if;

  select app_private.form_definition_projection(form_row.id),
         form_row.institution_id,
         form_row.working_version_id
    into definition_projection, form_institution_id, working_version_id
    from public.forms form_row
   where form_row.id = p_form_id
     and not app_private.superadmin_form_is_internal_draft_v2(form_row.id);

  if definition_projection is null then
    raise no_data_found using message = 'form unavailable';
  end if;

  if app_private.has_platform_permission('forms.manage_applications') then
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
    'media_context', jsonb_build_object(
      'form_version_id', working_version_id,
      'question_images', question_images
    )
  );
end;
$$;

-- Prepare aceita os dois realms ja existentes. Para formulario people-based,
-- o ator continua sendo a pessoa resolvida pela ponte e precisa conservar
-- forms.manage; o ticket/auditoria continuam presos a identidade interna.
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
      if actor_person_id is null or not app_private.has_platform_permission('forms.manage')
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

alter function app_private.form_replace_working_definition(uuid,jsonb) owner to postgres;
alter function app_private.form_get_editor(uuid) owner to postgres;
alter function public.superadmin_form_media_prepare_v2(uuid,uuid,uuid,uuid,text,bigint,text) owner to postgres;
revoke all on function app_private.form_replace_working_definition(uuid,jsonb),
  app_private.form_get_editor(uuid) from public,anon,authenticated,service_role;
revoke all on function public.superadmin_form_media_prepare_v2(uuid,uuid,uuid,uuid,text,bigint,text)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_form_media_prepare_v2(uuid,uuid,uuid,uuid,text,bigint,text)
  to authenticated;

commit;
