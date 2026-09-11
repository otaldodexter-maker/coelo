-- R05 realm-interno (9): answer-image no R2 — uploads de resposta de Formularios
-- (forms.respond) passam a ter entrada no catalogo privado (230007) desde o
-- prepare, sem mudar a identidade/ownership/segredo anonimo que continuam em
-- public.form_assets (form_prepare_asset_upload / form_finalize_asset_upload
-- / form_discard_asset da baseline seguem iguais).
--
--   * form_prepare_asset_upload_r2_v1 (authenticated): chama o prepare legado
--     (mesma autorizacao, quota, replay, segredo anonimo) e cria o espelho
--     media_assets(form-image, answer-image, pending, source_form_asset_id,
--     owner_person_id = prepared_by_person_id, chave R2 na convencao do
--     catalogo) + binding (item, versao, posicao seguinte); devolve o legado
--     mais bucket/object_key. O storage_path legado fica como esta.
--   * form_asset_r2_descriptor_v1(p_asset_id) [service_role]: a Edge Function
--     form-media obtem bucket/object_key/esperados para assinar o PUT e medir
--     o objeto (apos o form_finalize_asset_upload do usuario).
--   * form_media_finalize_answer_r2_v1(p_asset_id, p_byte_size, p_sha256,
--     p_pixel_width, p_pixel_height) [service_role]: chama
--     form_finalize_asset_for_worker (form_assets -> finalized ou discarded)
--     e, se finalizou, grava a variante original e deixa o media_asset ready;
--     divergencia -> media_asset deleted + fila de limpeza.
--   * gatilho AFTER UPDATE em form_assets (state -> discarded|expired):
--     media_asset deleted + fila de limpeza (o worker apaga no R2).
--   * a leitura ja existe: superadmin_form_authorize_media_read_v2 (230011)
--     e form_redeem_media_read_r2_v1 exigem exatamente esta forma
--     (asset ready + binding answer-image + variante original).
--
-- Reversao: drop do gatilho form_assets_answer_media_discard_v1, das funcoes
-- app_private.form_assets_answer_media_*_v1, public.form_prepare_asset_upload_r2_v1,
-- public.form_asset_r2_descriptor_v1 e public.form_media_finalize_answer_r2_v1.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'answer media migration must run as postgres';
  end if;
  if to_regclass('public.form_assets') is null or to_regclass('public.media_assets') is null
    or to_regclass('public.media_bindings') is null or to_regclass('public.media_variants') is null
    or to_regclass('app_private.form_media_r2_cleanup') is null
    or to_regprocedure('app_private.form_finalize_asset_for_worker(uuid,bigint,text,text)') is null
    or to_regprocedure('app_private.form_media_assert_worker_v1()') is null
    or to_regprocedure('app_private.form_media_envelope_error_v1(text,uuid)') is null then
    raise object_not_in_prerequisite_state using
      message = 'form_assets, private media catalog (230007) and forms_question_media_r2_v1 (210300) are required';
  end if;
end
$preflight$;

-- 1. prepare: legado + espelho no catalogo ---------------------------------------
-- Wrapper explicito (nao gatilho) para nao mudar o comportamento de
-- form_prepare_asset_upload nem das suites que inserem form_assets e
-- media_assets a mao; a Edge Function form-media passa a chamar este.
create function app_private.form_assets_answer_media_mirror_v1(p_form_asset_id uuid)
returns public.media_assets language plpgsql volatile security definer set search_path='' as $$
declare source public.form_assets%rowtype; occ public.form_occurrences%rowtype;
  asset public.media_assets%rowtype; new_asset_id uuid := gen_random_uuid(); next_position integer;
begin
  select * into source from public.form_assets where id = p_form_asset_id;
  if source.id is null then raise no_data_found using detail='FORM_MEDIA_NOT_FOUND'; end if;
  select * into asset from public.media_assets where source_form_asset_id = source.id and status <> 'deleted';
  if asset.id is not null then return asset; end if;
  select * into occ from public.form_occurrences where id = source.occurrence_id;
  insert into public.media_assets(id, institution_id, form_id, source_form_asset_id, owner_person_id, catalog_kind,
    media_purpose, storage_provider, bucket_id, object_key, original_name, upload_request_id, mime_type, status)
  values (new_asset_id, source.institution_id, occ.form_id, source.id, source.prepared_by_person_id, 'form-image',
    'answer-image', 'r2', 'coelo-media-prod',
    'tenants/' || source.institution_id::text || '/forms/form/' || occ.form_id::text || '/answer-image/'
      || new_asset_id::text || '/original/' || gen_random_uuid()::text
      || case source.mime_type when 'image/jpeg' then '.jpg' when 'image/png' then '.png' else '.webp' end,
    '', 'form-asset:' || source.id::text, source.mime_type, 'pending')
  returning * into asset;
  select coalesce(max(b.position), -1) + 1 into next_position from public.media_bindings b
  join public.media_assets a on a.id = b.media_asset_id
  where b.item_id = source.item_id and b.form_version_id = occ.form_version_id and b.purpose = 'answer-image'
    and a.status <> 'deleted' and a.owner_person_id is not distinct from source.prepared_by_person_id;
  insert into public.media_bindings(media_asset_id, form_version_id, item_id, purpose, position)
  values (asset.id, occ.form_version_id, source.item_id, 'answer-image', least(next_position, 4));
  return asset;
end $$;

create function public.form_prepare_asset_upload_r2_v1(p_request_id uuid, p_expected_version bigint, p_payload jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare legacy jsonb; asset public.media_assets%rowtype;
begin
  -- mesma autorizacao, quota, replay e segredo anonimo do legado
  legacy := app_private.form_prepare_asset_upload(p_request_id, p_expected_version, p_payload);
  asset := app_private.form_assets_answer_media_mirror_v1((legacy ->> 'asset_id')::uuid);
  return legacy || jsonb_build_object('media_asset_id', asset.id, 'bucket', asset.bucket_id,
    'object_key', asset.object_key, 'storage_provider', 'r2');
end $$;

-- 2. discard/expire: espelho apagado + fila -----------------------------------------
create function app_private.form_assets_answer_media_discard_v1()
returns trigger language plpgsql security definer set search_path='' as $$
declare asset public.media_assets%rowtype;
begin
  if new.state not in ('discarded','expired') or old.state = new.state then return new; end if;
  select * into asset from public.media_assets where source_form_asset_id = new.id and status <> 'deleted' for update;
  if asset.id is null then return new; end if;
  update public.media_assets set status = 'deleted' where id = asset.id;
  insert into app_private.form_media_r2_cleanup(asset_id, bucket_id, object_key, reason)
  select asset.id, v.bucket_id, v.object_key, case when new.state = 'expired' then 'expired' else 'deleted' end
  from public.media_variants v where v.media_asset_id = asset.id
  union select asset.id, asset.bucket_id, asset.object_key, case when new.state = 'expired' then 'expired' else 'deleted' end
  on conflict do nothing;
  return new;
end $$;
create trigger form_assets_answer_media_discard_v1
  after update of state on public.form_assets
  for each row execute function app_private.form_assets_answer_media_discard_v1();

-- 3. descritor para a Edge Function (service_role) ----------------------------------
create function public.form_asset_r2_descriptor_v1(p_asset_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare source public.form_assets%rowtype; asset public.media_assets%rowtype;
begin
  perform app_private.form_media_assert_worker_v1();
  select * into source from public.form_assets where id = p_asset_id;
  if source.id is null then return app_private.form_media_envelope_error_v1('FORM_MEDIA_NOT_FOUND', gen_random_uuid()); end if;
  select * into asset from public.media_assets where source_form_asset_id = source.id and status <> 'deleted';
  if asset.id is null then return app_private.form_media_envelope_error_v1('FORM_MEDIA_NOT_FOUND', gen_random_uuid()); end if;
  return app_private.form_media_success_v1(jsonb_build_object(
    'asset_id', source.id, 'media_asset_id', asset.id, 'bucket', asset.bucket_id, 'object_key', asset.object_key,
    'mime_type', source.mime_type, 'expected_byte_size', source.expected_byte_length,
    'expected_sha256', source.expected_checksum_sha256, 'state', source.state,
    'media_status', asset.status::text, 'expires_at', source.expires_at));
exception when insufficient_privilege then
  return app_private.form_media_envelope_error_v1('SAI_PERMISSION_DENIED', gen_random_uuid());
end $$;

-- 4. finalize (service_role) --------------------------------------------------------
create function public.form_media_finalize_answer_r2_v1(
  p_asset_id uuid, p_byte_size bigint, p_checksum_sha256 text, p_pixel_width integer, p_pixel_height integer
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare source public.form_assets%rowtype; asset public.media_assets%rowtype; worker jsonb; sha text := lower(btrim(coalesce(p_checksum_sha256,'')));
begin
  perform app_private.form_media_assert_worker_v1();
  select * into source from public.form_assets where id = p_asset_id for update;
  if source.id is null then return app_private.form_media_envelope_error_v1('FORM_MEDIA_NOT_FOUND', gen_random_uuid()); end if;
  select * into asset from public.media_assets where source_form_asset_id = source.id and status <> 'deleted' for update;
  if asset.id is null then return app_private.form_media_envelope_error_v1('FORM_MEDIA_NOT_FOUND', gen_random_uuid()); end if;
  if source.state = 'finalized' and asset.status = 'ready' then
    return app_private.form_media_success_v1(jsonb_build_object('asset_id', source.id, 'media_asset_id', asset.id,
      'state', 'finalized', 'media_status', 'ready', 'replayed', true));
  end if;
  -- o legado decide finalized/discarded pelas medidas; dimensoes so entram no catalogo
  worker := app_private.form_finalize_asset_for_worker(source.id, p_byte_size, source.mime_type, sha);
  if worker ->> 'state' <> 'finalized'
    or p_pixel_width is null or p_pixel_height is null
    or p_pixel_width not between 1 and 2560 or p_pixel_height not between 1 and 2560 then
    if worker ->> 'state' = 'finalized' then
      -- medidas certas mas pixels invalidos: descarta o legado tambem
      update public.form_assets set state = 'discarded', discarded_at = now() where id = source.id;
    end if;
    -- o gatilho de discard ja marcou o espelho e a fila
    return app_private.form_media_envelope_error_v1('FORM_MEDIA_MISMATCH', gen_random_uuid());
  end if;
  update public.media_assets set byte_size = p_byte_size, checksum_sha256 = sha,
    pixel_width = p_pixel_width, pixel_height = p_pixel_height, status = 'ready', finalized_at = now()
  where id = asset.id returning * into asset;
  insert into public.media_variants(media_asset_id, rendition, bucket_id, object_key, mime_type,
    byte_size, checksum_sha256, pixel_width, pixel_height)
  values (asset.id, 'original', asset.bucket_id, asset.object_key, asset.mime_type,
    asset.byte_size, asset.checksum_sha256, asset.pixel_width, asset.pixel_height);
  return app_private.form_media_success_v1(jsonb_build_object('asset_id', source.id, 'media_asset_id', asset.id,
    'state', 'finalized', 'media_status', 'ready', 'replayed', false));
exception when insufficient_privilege then
  return app_private.form_media_envelope_error_v1('SAI_PERMISSION_DENIED', gen_random_uuid());
end $$;

-- 5. Donos e privilegios -----------------------------------------------------------------
do $grants$ declare p regprocedure; begin
  foreach p in array array[
    'app_private.form_assets_answer_media_mirror_v1(uuid)'::regprocedure,
    'public.form_prepare_asset_upload_r2_v1(uuid,bigint,jsonb)'::regprocedure,
    'app_private.form_assets_answer_media_discard_v1()'::regprocedure,
    'public.form_asset_r2_descriptor_v1(uuid)'::regprocedure,
    'public.form_media_finalize_answer_r2_v1(uuid,bigint,text,integer,integer)'::regprocedure
  ] loop
    execute format('alter function %s owner to postgres', p);
    execute format('revoke all on function %s from public, anon, authenticated, service_role', p);
  end loop;
end $grants$;
grant execute on function public.form_asset_r2_descriptor_v1(uuid),
  public.form_media_finalize_answer_r2_v1(uuid,bigint,text,integer,integer) to service_role;
grant execute on function public.form_prepare_asset_upload_r2_v1(uuid,bigint,jsonb) to authenticated;

commit;
