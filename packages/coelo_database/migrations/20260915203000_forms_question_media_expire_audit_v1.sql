-- Registra cada expiração automática de question-image no diário de auditoria.
-- A transição continua sendo exclusiva do worker; a entrada usa o contexto da
-- instituição do próprio asset e não atribui a ação a uma pessoa inexistente.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'forms question media expire audit must run as postgres';
  end if;
  if to_regprocedure('public.form_media_expire_question_r2_v1(integer)') is null
    or to_regclass('public.media_assets') is null
    or to_regclass('audit.audit_logs') is null then
    raise object_not_in_prerequisite_state using
      message = 'forms question media expire function and audit log are required';
  end if;
end
$preflight$;

create or replace function public.form_media_expire_question_r2_v1(p_limit integer default 100)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare expired integer := 0; item record;
begin
  perform app_private.form_media_assert_worker_v1();
  for item in
    select t.asset_id, a.bucket_id, a.object_key, a.institution_id
    from app_private.form_media_upload_tickets t
    join public.media_assets a on a.id = t.asset_id
    where t.used_at is null and t.expires_at < now() and a.status = 'pending'
    order by t.expires_at limit least(greatest(coalesce(p_limit, 100), 1), 500) for update of t skip locked
  loop
    update public.media_assets set status = 'deleted' where id = item.asset_id;
    insert into app_private.form_media_r2_cleanup(asset_id, bucket_id, object_key, reason)
    values (item.asset_id, item.bucket_id, item.object_key, 'expired') on conflict do nothing;
    update app_private.form_media_upload_tickets set used_at = now() where asset_id = item.asset_id;
    insert into audit.audit_logs(
      actor_person_id, mfa_aal, action_code, object_type, object_id,
      institution_id, outcome, origin, context_kind, context_id,
      payload_contract_version, after_json
    ) values (
      null, null, 'forms.media.expire', 'media_asset', item.asset_id,
      item.institution_id, 'success', 'edge_function', 'institution',
      item.institution_id, 1, jsonb_build_object('state', 'deleted', 'reason', 'expired')
    );
    expired := expired + 1;
  end loop;
  return app_private.form_media_success_v1(jsonb_build_object('expired', expired));
exception when insufficient_privilege then
  return app_private.form_media_envelope_error_v1('SAI_PERMISSION_DENIED', gen_random_uuid());
end $$;

alter function public.form_media_expire_question_r2_v1(integer) owner to postgres;
revoke all on function public.form_media_expire_question_r2_v1(integer) from public, anon, authenticated;
grant execute on function public.form_media_expire_question_r2_v1(integer) to service_role;

commit;
