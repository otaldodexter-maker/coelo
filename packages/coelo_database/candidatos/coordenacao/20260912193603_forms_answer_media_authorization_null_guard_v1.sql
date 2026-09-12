-- R09 C0: NULL de ownership/segredo anonimo nunca constitui autorizacao.
-- Mesmo contrato e grants minimos; nenhuma mudanca em dados ou identidade.
create or replace function public.form_media_authorize_for_worker(
  p_asset_id uuid, p_actor_person_id uuid, p_edit_secret text
) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare asset_row public.form_assets;
begin
  select * into asset_row from public.form_assets
   where id = p_asset_id and state in ('uploaded', 'finalized');
  if asset_row.id is null or (
    (asset_row.prepared_by_person_id = p_actor_person_id)
    or (
      asset_row.prepared_by_person_id is null
      and app_private.form_verify_anonymous_edit_secret(
        p_edit_secret, asset_row.anonymous_upload_secret_hash
      )
    )
    or (asset_row.state = 'finalized'
      and exists (
        select 1 from public.form_answer_assets answer_asset
         where answer_asset.asset_id = asset_row.id
      )
      and app_private.audit_actor_has_permission(
        p_actor_person_id, 'forms.responses.read', asset_row.institution_id, false
      ))
  ) is not true then
    raise no_data_found using message = 'form asset unavailable';
  end if;
  return jsonb_build_object(
    'asset_id', asset_row.id, 'storage_path', asset_row.storage_path,
    'mime_type', asset_row.mime_type, 'byte_length', asset_row.actual_byte_length,
    'state', asset_row.state
  );
end;
$$;
revoke execute on function public.form_media_authorize_for_worker(uuid,uuid,text)
  from public, anon, authenticated;
grant execute on function public.form_media_authorize_for_worker(uuid,uuid,text)
  to service_role;
