-- Exclusao logica de Circulares no realm interno (superadmin_circular_delete_v2).
-- Renumeracao de 20260910120000_superadmin_internal_circular_delete_v1 (f15a9eec2)
-- para a faixa 2026091020xxxx do grupo publicacoes-agenda (colisao de carimbo com
-- meal_plan_image_delete_requires_revision_v1). Depende de 20260910200100.
-- Correcao sobre a baseline: circulars_check1 (status=draft ou publish_at not null)
-- impedia arquivar rascunho; a exclusao logica de rascunho mantem status e usa
-- deleted_at. Rodada 4 (E2-R04-20260911).
begin;

do $preflight$
begin
  if current_user <> 'postgres'
    or to_regprocedure('app_private.superadmin_circular_context(text,uuid)') is null
    or to_regprocedure('app_private.superadmin_circular_denied(text,text,text,uuid)') is null
    or to_regclass('public.circulars') is null
    or to_regclass('app_private.superadmin_circular_command_receipts') is null then
    raise object_not_in_prerequisite_state using
      message = 'superadmin internal circular delete prerequisites missing';
  end if;
end
$preflight$;

alter table app_private.superadmin_circular_command_receipts
  drop constraint if exists superadmin_circular_command_receipts_action_code_check,
  add constraint superadmin_circular_command_receipts_action_code_check
    check (action_code in ('save','publish','close','delete'));

create or replace function public.superadmin_circular_delete_v2(
  p_request_id uuid,
  p_circular_id uuid,
  p_expected_version bigint
) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := gen_random_uuid();
  target public.circulars%rowtype;
  result jsonb;
  prior record;
  code text;
  hash bytea := extensions.digest(
    convert_to(p_circular_id::text || p_expected_version::text, 'UTF8'),
    'sha256'
  );
begin
  begin
    select * into target
    from public.circulars c
    where c.id = p_circular_id
    for update;

    if target.id is null then
      raise no_data_found using detail = 'CIRCULAR_NOT_FOUND';
    end if;

    ctx := app_private.superadmin_circular_context(
      'circulars.manage', target.institution_id
    );

    select * into prior
    from app_private.superadmin_circular_command_receipts receipt
    where receipt.internal_identity_id = ctx.internal_identity_id
      and receipt.request_id = p_request_id
      and receipt.action_code = 'delete';

    if prior.result_json is not null then
      if prior.request_hash <> hash then
        raise unique_violation using detail = 'CIRCULAR_CONFLICT';
      end if;
      return jsonb_build_object('ok', true, 'data', prior.result_json, 'error', null);
    end if;

    if target.deleted_at is not null
      or target.management_version <> p_expected_version
      or target.status = 'archived' then
      raise serialization_failure using detail = 'CIRCULAR_CONFLICT';
    end if;

    if target.current_revision_id is null
      and not exists (
        select 1
        from public.circular_response_sessions response_session
        where response_session.circular_id = target.id
      ) then
      update public.circular_media_assets
      set status = 'orphaned'
      where circular_id = target.id
        and status in ('pending', 'ready');
    end if;

    -- producao exige status='draft' ou publish_at preenchido (circulars_check1):
    -- rascunho excluido mantem 'draft' e e ocultado por deleted_at.
    update public.circulars
    set status = case when target.publish_at is null then target.status else 'archived'::public.circular_status end,
        deleted_at = clock_timestamp(),
        management_version = management_version + 1,
        updated_at = clock_timestamp()
    where id = target.id
    returning * into target;

    result := jsonb_build_object(
      'id', target.id,
      'version', target.management_version,
      'status', target.status::text,
      'deleted', true
    );

    insert into app_private.superadmin_circular_command_receipts(
      internal_identity_id, request_id, action_code, request_hash, result_json, created_at
    ) values (
      ctx.internal_identity_id, p_request_id, 'delete', hash, result, clock_timestamp()
    );

    insert into app_private.circular_audit(
      circular_id, revision_id, institution_id, actor_internal_identity_id, event_code, detail
    ) values (
      target.id, target.current_revision_id, target.institution_id,
      ctx.internal_identity_id, 'internal_circular_deleted',
      jsonb_build_object('logical', true)
    );

    perform app_private.superadmin_circular_audit(
      ctx, 'delete', target.id, 'success', 'deleted', correlation
    );
    return jsonb_build_object('ok', true, 'data', result, 'error', null);
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    return app_private.superadmin_circular_denied(
      'circulars.manage', 'delete', code, correlation
    );
  end;
end
$$;

alter function public.superadmin_circular_delete_v2(uuid, uuid, bigint) owner to postgres;
revoke all on function public.superadmin_circular_delete_v2(uuid, uuid, bigint)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_circular_delete_v2(uuid, uuid, bigint)
  to authenticated;

commit;
