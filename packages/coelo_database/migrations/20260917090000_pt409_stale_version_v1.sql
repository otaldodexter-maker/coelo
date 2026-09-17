-- R15 Bloco B / OQ-047 (ADR 0042 E1): PT409 no lugar de SQLSTATE 40001 em toda RPC que sinaliza
-- versao defasada ou conflito de concorrencia otimista.
--
-- Causa (R14 Sessao 8, evidencia r14-sessao-8/child-safety-lifecycle-504-20260916.md): o PostgREST
-- 14.5 de producao trata 40001 (serialization_failure) como falha transitoria e reexecuta a
-- transacao sem limite (~500 tx/s) ate o 504 do gateway; o laco sobrevive ao 504. O lote 74 corrigiu
-- as familias child_safety e attendance; esta migration unica e forward-only corrige as demais.
--
-- Regra aplicada (dump de producao de 17/09/2026, schema-producao-20260917-r15-b-before.sql,
-- SHA-256 c87f4d67), gerada mecanicamente a partir do dump: em cada funcao abaixo, SOMENTE
--   (a) `raise serialization_failure using <clausulas>;` -> `raise exception using errcode='PT409',
--       <mesmas clausulas>[, detail='<FAMILIA>_STALE_VERSION' quando nao havia detail]`;
--   (b) `raise exception using errcode='40001', ...` -> `errcode='PT409'` (mesma regra de detail);
--   (c) handlers que capturavam o 40001 interno para devolver o envelope SAI_CONCURRENT_CHANGE passam a
--       capturar tambem PT409 (`when serialization_failure or sqlstate 'PT409'`,
--       `sqlstate in('40001','23505','PT409')`, `sql_state in('40001','PT409')`), preservando o
--       contrato dos wrappers (envelope 200 com SAI_CONCURRENT_CHANGE) e a captura de falhas de
--       serializacao reais do Postgres.
-- Assinaturas, SECURITY DEFINER, search_path, recibos, auditoria, notificacoes, grants e ownership
-- permanecem os do dump (create or replace com o mesmo corpo). Idempotente.
-- Funcoes: 126; raises trocados: 175; handlers ajustados: 18; familias: 28.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '300s';

do $preflight$
declare missing text[];
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'pt409 stale version fix must run as postgres';
  end if;
  select array_agg(s) into missing from unnest(array[
    'app_private.access_profile_model_call(text,jsonb)',
    'app_private.activity_v2_replay_or_error(app_private.superadmin_internal_context,uuid,uuid,uuid,text,bytea,uuid)',
    'app_private.assessment_v2_activate_configuration(uuid,uuid,bigint)',
    'app_private.assessment_v2_save_configuration(uuid,uuid,bigint,jsonb)',
    'app_private.assessment_v2_save_gradebook(uuid,uuid,bigint,jsonb,text)',
    'app_private.assessment_v2_transition_gradebook(uuid,uuid,bigint,text,text,text,timestamp with time zone)',
    'app_private.change_unit_handle_for_superadmin(uuid,uuid,bigint,text)',
    'app_private.child_safety_save_restriction(uuid,jsonb)',
    'app_private.create_institution_for_superadmin(uuid,jsonb)',
    'app_private.form_archive_or_delete(uuid,bigint,jsonb)',
    'app_private.form_begin_command(uuid,uuid,text,bigint,jsonb)',
    'app_private.form_complete_command(uuid,jsonb)',
    'app_private.form_complete_notification_delivery(uuid,uuid,text,boolean,text)',
    'app_private.form_copy_or_move(uuid,bigint,jsonb)',
    'app_private.form_duplicate(uuid,bigint,jsonb)',
    'app_private.form_fail_worker_job(uuid,text,text,integer,jsonb)',
    'app_private.form_finalize_asset_upload(uuid,bigint,jsonb)',
    'app_private.form_finish_worker_job(uuid,text,jsonb)',
    'app_private.form_mutate_response(text,uuid,bigint,jsonb,boolean)',
    'app_private.form_open_response_draft(uuid,bigint,jsonb)',
    'app_private.form_prepare_asset_upload(uuid,bigint,jsonb)',
    'app_private.form_publish(uuid,bigint,jsonb)',
    'app_private.form_remove_schedule(uuid,bigint,jsonb)',
    'app_private.form_request_export(uuid,bigint,jsonb,boolean)',
    'app_private.form_save_application(uuid,bigint,jsonb)',
    'app_private.form_save_draft(uuid,bigint,jsonb)',
    'app_private.form_save_schedule(uuid,bigint,jsonb)',
    'app_private.form_worker_abort_multipart(uuid,text,uuid,text)',
    'app_private.form_worker_begin_export(uuid,text,uuid)',
    'app_private.form_worker_begin_multipart(uuid,text,uuid,text,text,text)',
    'app_private.form_worker_cleanup_snapshot(uuid,text,integer)',
    'app_private.form_worker_complete_cleanup(uuid,text,uuid[])',
    'app_private.form_worker_complete_export(uuid,text,uuid,text,bigint,jsonb)',
    'app_private.form_worker_complete_multipart(uuid,text,uuid,text)',
    'app_private.form_worker_complete_xlsx_r2_v1(uuid,text,uuid,uuid,bigint,text)',
    'app_private.form_worker_fail_export(uuid,text,uuid,text,integer)',
    'app_private.form_worker_multipart_snapshot(uuid,text,uuid)',
    'app_private.form_worker_multipart_xlsx_r2_v1(jsonb,text,jsonb)',
    'app_private.form_worker_record_multipart_part(uuid,text,uuid,text,integer,text,bigint,text)',
    'app_private.forms_xlsx_worker_job_v1(uuid,text,uuid,uuid)',
    'app_private.guard_superadmin_internal_auth_link_lifecycle()',
    'app_private.guard_superadmin_internal_membership_lifecycle()',
    'app_private.location_reservation_command_v2(text,uuid,jsonb,uuid)',
    'app_private.superadmin_access_profile_assignment_link(uuid,jsonb)',
    'app_private.superadmin_access_profile_assignment_overrides_save(uuid,uuid,bigint,jsonb,text)',
    'app_private.superadmin_access_profile_assignment_unlink(uuid,uuid,bigint,text)',
    'app_private.superadmin_access_profile_create_from_model(uuid,jsonb)',
    'app_private.superadmin_access_profile_delete_and_reassign(uuid,text,uuid,bigint,uuid,text)',
    'app_private.superadmin_access_profile_duplicate(uuid,jsonb)',
    'app_private.superadmin_access_profile_import_confirm(uuid,uuid,bigint)',
    'app_private.superadmin_access_profile_model_delete(uuid,uuid,bigint,text)',
    'app_private.superadmin_access_profile_model_update(uuid,jsonb)',
    'app_private.superadmin_access_profile_update(uuid,jsonb)',
    'app_private.superadmin_form_request_xlsx_v2(uuid,bigint,jsonb)',
    'app_private.superadmin_forms_save_draft_v2(uuid,bigint,jsonb)',
    'app_private.superadmin_group_save(uuid,uuid,bigint,jsonb)',
    'app_private.superadmin_health_care_save_profile(uuid,uuid,bigint,jsonb)',
    'app_private.superadmin_institution_contacts_apply_v1(uuid,uuid,bigint,jsonb,bytea,app_private.superadmin_internal_context,uuid)',
    'app_private.superadmin_institution_edit_core_apply_v2(uuid,uuid,bigint,jsonb,bytea,app_private.superadmin_internal_context,uuid)',
    'app_private.superadmin_internal_user_denial_code(text,text)',
    'app_private.superadmin_medication_plan_save(uuid,uuid,bigint,jsonb)',
    'app_private.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb)',
    'app_private.superadmin_routine_publish_launch(uuid,uuid,bigint)',
    'app_private.superadmin_routine_revert_application(uuid,uuid,bigint)',
    'app_private.superadmin_routine_save_application(uuid,uuid,bigint,jsonb)',
    'app_private.superadmin_routine_save_launch_draft(uuid,uuid,bigint,jsonb)',
    'app_private.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)',
    'app_private.superadmin_upsert_activity(jsonb,uuid)',
    'app_private.transfer_unit_institution_for_superadmin(uuid,uuid,uuid,bigint,boolean)',
    'app_private.update_institution_for_superadmin(uuid,uuid,bigint,jsonb)',
    'app_private.update_superadmin_person(uuid,timestamp with time zone,jsonb,jsonb)',
    'app_private.update_unit_for_superadmin(uuid,jsonb,uuid,bigint)',
    'public.close_circular_responses(uuid,uuid,bigint)',
    'public.delete_circular(uuid,uuid,bigint)',
    'public.publish_circular(uuid,uuid,bigint,timestamp with time zone)',
    'public.publish_happens_post(uuid,uuid,bigint,timestamp with time zone)',
    'public.publish_moment(uuid,uuid,bigint)',
    'public.publish_now(uuid,uuid,bigint,timestamp with time zone)',
    'public.publish_profile_about(text,uuid,bigint,uuid)',
    'public.remove_now_publication(uuid,uuid,bigint,text)',
    'public.save_circular_draft(uuid,jsonb,uuid,bigint)',
    'public.save_circular_response_draft(uuid,uuid,jsonb,bigint)',
    'public.save_happens_draft(uuid,jsonb,uuid,bigint)',
    'public.save_moments_draft(uuid,jsonb,uuid,bigint)',
    'public.save_now_draft(uuid,jsonb,uuid,bigint)',
    'public.save_profile_about(text,uuid,jsonb,bigint,uuid,jsonb)',
    'public.submit_circular_response(uuid,uuid,bigint)',
    'public.superadmin_activity_location_create_v2(uuid,uuid,jsonb,jsonb)',
    'public.superadmin_activity_publish_v2(uuid,uuid,bigint)',
    'public.superadmin_activity_save_v2(uuid,uuid,bigint,boolean,jsonb)',
    'public.superadmin_activity_set_groups_v2(uuid,uuid,bigint,uuid[],jsonb)',
    'public.superadmin_activity_set_participants_v2(uuid,uuid,bigint,jsonb)',
    'public.superadmin_activity_set_permissions_v2(uuid,uuid,bigint,jsonb,jsonb,jsonb)',
    'public.superadmin_activity_set_professionals_v2(uuid,uuid,bigint,jsonb)',
    'public.superadmin_activity_set_units_v2(uuid,uuid,bigint,uuid[])',
    'public.superadmin_activity_update_v2(uuid,uuid,bigint,jsonb)',
    'public.superadmin_agenda_command(uuid,uuid,bigint,text,text)',
    'public.superadmin_agenda_save(uuid,uuid,bigint,jsonb,text,boolean)',
    'public.superadmin_child_context_directory_v2(uuid,text,uuid,integer)',
    'public.superadmin_circular_close_v2(uuid,uuid,bigint)',
    'public.superadmin_circular_delete_v2(uuid,uuid,bigint)',
    'public.superadmin_circular_publish_v2(uuid,uuid,bigint,timestamp with time zone)',
    'public.superadmin_circular_save_draft_v2(uuid,uuid,uuid,uuid,uuid,jsonb)',
    'public.superadmin_group_location_create_v2(uuid,uuid,jsonb,jsonb)',
    'public.superadmin_institution_contacts_edit_v1(uuid,uuid,bigint,jsonb)',
    'public.superadmin_institution_edit_core_v2(uuid,uuid,bigint,jsonb)',
    'public.superadmin_internal_user_change_status(uuid,uuid,bigint,text,text)',
    'public.superadmin_internal_user_update(uuid,uuid,bigint,text,jsonb)',
    'public.superadmin_invite_issue_v2(uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer)',
    'public.superadmin_invite_resend_v2(uuid,uuid,bigint)',
    'public.superadmin_invite_revoke_v2(uuid,uuid,bigint,text)',
    'public.superadmin_location_copy_v2(uuid,text,uuid,uuid,text,uuid)',
    'public.superadmin_location_create_v2(jsonb,uuid)',
    'public.superadmin_location_schedule_set_v2(uuid,jsonb,bigint,uuid)',
    'public.superadmin_location_set_status_v2(uuid,text,bigint,uuid)',
    'public.superadmin_location_update_v2(uuid,jsonb,bigint,uuid)',
    'public.superadmin_notice_change_status_v2(uuid,uuid,bigint,text,text)',
    'public.superadmin_notice_publish_v2(uuid,uuid,bigint)',
    'public.superadmin_notice_save_draft_v2(uuid,uuid,bigint,jsonb)',
    'public.superadmin_plan_save(uuid,uuid,bigint,jsonb,text)',
    'public.superadmin_structure_handle_set_v1(uuid,text,uuid,bigint,text)',
    'public.superadmin_support_reply(uuid,uuid,text,bigint)',
    'public.superadmin_support_set_assignee(uuid,uuid,bigint,uuid)',
    'public.superadmin_support_set_status(uuid,uuid,text,bigint)',
    'public.withdraw_happens_post(uuid,uuid,bigint,text)',
    'public.withdraw_moment(uuid,uuid,bigint,text)'
  ]) s where to_regprocedure(s) is null;
  if missing is not null then
    raise object_not_in_prerequisite_state using message = 'missing RPCs: ' || array_to_string(missing, ', ');
  end if;
end
$preflight$;

-- app_private.access_profile_model_call [ACCESS_PROFILE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 0, handlers: 1.
create or replace function "app_private"."access_profile_model_call"("p_operation" "text", "p_args" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare result jsonb;domain text;permission_action text;actor uuid;
  correlation uuid:=gen_random_uuid();error_code text;error_detail text;sql_state text;
  object_id uuid;
begin
  begin
    if p_operation in('list','detail','catalog') then
      perform app_private.access_profile_require_any_model_read();
    end if;
    domain:=case
      when p_operation in('list','create','export','import_preview','import_confirm')
        then coalesce(p_args->>'domain',p_args#>>'{draft,domain}')
      when p_operation='catalog' then 'platform'
      when p_operation in('detail','delete') then (
        select model.domain from public.access_profile_templates model
        where model.id=nullif(p_args->>'model_id','')::uuid)
      when p_operation='update' then (
        select model.domain from public.access_profile_templates model
        where model.id=nullif(p_args#>>'{draft,id}','')::uuid)
      when p_operation='duplicate' then (
        select model.domain from public.access_profile_templates model
        where model.id=nullif(p_args#>>'{draft,source_model_id}','')::uuid)
    end;
    permission_action:=case p_operation
      when 'list' then 'read' when 'detail' then 'read' when 'catalog' then 'read'
      when 'duplicate' then 'create' when 'import_preview' then 'import'
      when 'import_confirm' then 'import' else p_operation end;
    if p_operation='list' then
      result:=app_private.superadmin_access_profile_models_cursor(
        p_args->>'query',domain,p_args->>'status',p_args->>'scope',
        coalesce((p_args->>'limit')::integer,25),p_args->>'after_name',
        nullif(p_args->>'after_id','')::uuid);
    elsif p_operation='detail' then
      result:=app_private.access_profile_model_detail(
        nullif(p_args->>'model_id','')::uuid,true);
    elsif p_operation='create' then
      result:=app_private.superadmin_access_profile_model_create(
        nullif(p_args->>'request_id','')::uuid,p_args->'draft');
    elsif p_operation='update' then
      result:=app_private.superadmin_access_profile_model_update(
        nullif(p_args->>'request_id','')::uuid,p_args->'draft');
    elsif p_operation='delete' then
      result:=app_private.superadmin_access_profile_model_delete(
        nullif(p_args->>'request_id','')::uuid,
        nullif(p_args->>'model_id','')::uuid,(p_args->>'expected_version')::bigint,
        p_args->>'reason');
    elsif p_operation='duplicate' then
      result:=app_private.superadmin_access_profile_model_duplicate(
        nullif(p_args->>'request_id','')::uuid,p_args->'draft');
    elsif p_operation='export' then
      result:=app_private.superadmin_access_profile_models_export(domain);
    elsif p_operation='import_preview' then
      result:=app_private.superadmin_access_profile_models_import_preview(
        domain,p_args->'rows');
    elsif p_operation='import_confirm' then
      result:=app_private.superadmin_access_profile_models_import_confirm(
        nullif(p_args->>'request_id','')::uuid,domain,p_args->'rows',p_args->>'reason');
    elsif p_operation='catalog' then
      result:=app_private.superadmin_access_permission_catalog();
    else
      raise invalid_parameter_value using message='unsupported model operation';
    end if;
    if p_operation in('list','detail','catalog','import_preview') then
      actor:=app_private.access_profile_require_model_action(
        coalesce(domain,'platform'),permission_action,false);
      object_id:=case when p_operation='detail'
        then nullif(p_args->>'model_id','')::uuid else null end;
      perform app_private.access_profile_model_audit_success(
        actor,coalesce(domain,'platform'),permission_action,object_id);
    end if;
  exception when others then
    get stacked diagnostics error_detail=pg_exception_detail,sql_state=returned_sqlstate;
    error_code:=case
      when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID',
        'SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
        'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
        then error_detail
      when sql_state in('40001','PT409') then 'SAI_CONCURRENT_CHANGE'
      when sql_state in('22023','22P02','23514','23505','22001')
        then 'SAI_INVALID_ARGUMENT'
      when sql_state in('P0002','42501') then 'SAI_PERMISSION_DENIED'
      else 'SAI_INTERNAL_ERROR' end;
    perform app_private.audit_superadmin_internal_denial_if_identified(
      coalesce(case when domain in('platform','institution','principal')
        then domain else 'platform' end||'.role_models.'||
        coalesce(permission_action,'read'),'platform.role_models.read'),
      'superadmin.access-profile-models.'||coalesce(p_operation,'invalid'),
      error_code,correlation,null);
    return app_private.access_profile_model_error_envelope(error_code,correlation);
  end;
  return pg_catalog.jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

-- app_private.activity_v2_replay_or_error [ACTIVITY]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."activity_v2_replay_or_error"("p_ctx" "app_private"."superadmin_internal_context", "p_request_id" "uuid", "p_institution_id" "uuid", "p_activity_id" "uuid", "p_command_kind" "text", "p_request_hash" "bytea", "p_correlation_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare r app_private.superadmin_internal_activity_command_receipts%rowtype;
 fresh app_private.superadmin_internal_context; permission_code text;
begin
  permission_code:=case p_command_kind when 'activity.create' then 'activities.create'
   when 'activity.update' then 'activities.manage' when 'activity.publish' then 'activities.manage'
   when 'activity.set_units' then 'activities.link_units' when 'activity.set_groups' then 'activities.link_groups'
   when 'activity.set_participants' then 'activities.assign_people' when 'activity.set_professionals' then 'activities.assign_people'
   when 'activity.set_permissions' then 'activities.manage_permissions' end;
  if permission_code is null then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
  select * into strict fresh from app_private.activity_v2_require_context(permission_code,p_institution_id);
  if fresh.internal_identity_id<>p_ctx.internal_identity_id or fresh.internal_auth_link_id<>p_ctx.internal_auth_link_id
     or fresh.internal_membership_id<>p_ctx.internal_membership_id or fresh.session_id<>p_ctx.session_id then
    raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
  select * into r from app_private.superadmin_internal_activity_command_receipts x where x.request_id=p_request_id;
  if r.request_id is null then return null; end if;
  if r.internal_identity_id<>p_ctx.internal_identity_id then
    raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
  end if;
  if r.institution_id is distinct from p_institution_id
     or (p_command_kind<>'activity.create' and r.activity_id is distinct from p_activity_id)
     or r.command_kind<>p_command_kind or r.request_hash<>p_request_hash then
    raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE';
  end if;
  return app_private.activity_v2_success_envelope(pg_catalog.jsonb_build_object(
   'activity_id',r.activity_id,'management_version',r.resulting_version,'status',r.resulting_status,
   'correlation_id',r.correlation_id,'replayed',true));
end $$;

-- app_private.assessment_v2_activate_configuration [ASSESSMENT]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."assessment_v2_activate_configuration"("request_id" "uuid", "configuration_id" "uuid", "expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context;
  config public.activity_assessment_configurations%rowtype; request_hash bytea; replay jsonb;
begin
  select * into config from public.activity_assessment_configurations c
  where c.id = configuration_id;
  if not found then raise no_data_found using detail = 'ASSESSMENT_NOT_FOUND'; end if;
  select * into strict ctx
  from app_private.assessment_v2_require_context('activities.manage', config.institution_id);
  request_hash := app_private.assessment_v2_hash(jsonb_build_object(
    'configuration_id', configuration_id, 'expected_version', expected_version));
  replay := app_private.assessment_v2_replay(ctx, request_id, 'configuration.activate', request_hash);
  if replay is not null then return replay; end if;
  select * into config from public.activity_assessment_configurations c
  where c.id = configuration_id for update;
  if config.management_version <> expected_version then
    raise exception using errcode='PT409', detail = 'SAI_CONCURRENT_CHANGE';
  end if;
  if config.status <> 'draft'
    or (select coalesce(sum(i.weight), 0) from public.assessment_instruments i
      where i.configuration_id = config.id) <> 100
    or not exists (select 1 from public.assessment_periods p where p.configuration_id = config.id) then
    raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
  end if;
  update public.activity_assessment_configurations c set status = 'archived', updated_at = now()
  where c.activity_id = config.activity_id and c.unit_id is not distinct from config.unit_id
    and c.status = 'active';
  update public.activity_assessment_configurations c set status = 'active',
    management_version = c.management_version + 1, updated_at = now()
  where c.id = config.id returning * into config;
  update public.assessment_periods p set status = 'open', updated_at = now()
  where p.configuration_id = config.id;
  return app_private.assessment_v2_finish(ctx, request_id, config.institution_id,
    config.id, 'configuration.activate', request_hash, config.management_version,
    config.status, null);
end $$;

-- app_private.assessment_v2_save_configuration [ASSESSMENT]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."assessment_v2_save_configuration"("request_id" "uuid", "configuration_id" "uuid", "expected_version" bigint, "payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
-- Correcao R04: as consultas qualificam colunas por alias e usam as variaveis
-- institution_id/unit_id/activity_id sem qualificar; sem esta diretiva o
-- Postgres 17 aborta com 'column reference is ambiguous'.
#variable_conflict use_variable
declare
  ctx app_private.superadmin_internal_context; saved public.activity_assessment_configurations%rowtype;
  institution_id uuid; unit_id uuid; activity_id uuid; request_hash bytea; replay jsonb;
  instrument jsonb; concept jsonb; category jsonb; competency jsonb; period jsonb;
  v_category_id uuid; v_competency_id uuid; instrument_total numeric;
begin
  if payload is null or jsonb_typeof(payload) <> 'object'
    or exists (select 1 from jsonb_object_keys(payload) k where k not in (
      'activity_id','institution_id','unit_id','periodicity','result_scale_kind',
      'scale_options','concepts','periods','allow_final_override','instruments','categories'))
    or not (payload ?& array['activity_id','institution_id','periodicity','result_scale_kind',
      'scale_options','periods','allow_final_override','instruments','categories'])
    or jsonb_typeof(payload->'scale_options') <> 'object'
    or jsonb_typeof(payload->'periods') <> 'array'
    or jsonb_typeof(payload->'instruments') <> 'array'
    or jsonb_typeof(payload->'categories') <> 'array'
    or coalesce(jsonb_typeof(payload->'concepts'), 'array') <> 'array'
    or jsonb_array_length(payload->'periods') not between 1 and 12
    or jsonb_array_length(payload->'instruments') not between 1 and 30
    or jsonb_array_length(payload->'categories') > 30 then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;
  begin
    activity_id := (payload->>'activity_id')::uuid;
    institution_id := (payload->>'institution_id')::uuid;
    unit_id := nullif(payload->>'unit_id', '')::uuid;
  exception when others then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
  end;
  select * into strict ctx
  from app_private.assessment_v2_require_context('activities.manage', institution_id);
  if not exists (select 1 from public.activity_definitions a
    where a.id = activity_id and a.institution_id = institution_id
      and a.status in ('draft','active'))
    or (unit_id is not null and not exists (select 1 from public.units u
      where u.id = unit_id and u.institution_id = institution_id and u.status = 'active'))
    or payload->>'periodicity' not in ('bimonthly','trimester','semester','annual')
    or payload->>'result_scale_kind' not in (
      'numeric_0_10','numeric_0_100','concept','numeric_1_5','binary','stars_0_5') then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_REFERENCE';
  end if;
  request_hash := app_private.assessment_v2_hash(jsonb_build_object(
    'configuration_id', configuration_id, 'expected_version', expected_version, 'payload', payload));
  replay := app_private.assessment_v2_replay(ctx, request_id, 'configuration.save', request_hash);
  if replay is not null then return replay; end if;

  if configuration_id is null then
    if expected_version <> 0 then raise exception using errcode='PT409', detail = 'SAI_CONCURRENT_CHANGE'; end if;
    insert into public.activity_assessment_configurations(
      activity_id, institution_id, unit_id, periodicity, result_scale_kind,
      scale_options, allow_final_override)
    values (activity_id, institution_id, unit_id, payload->>'periodicity',
      payload->>'result_scale_kind', payload->'scale_options',
      coalesce((payload->>'allow_final_override')::boolean, false))
    returning * into saved;
  else
    select * into saved from public.activity_assessment_configurations c
    where c.id = configuration_id and c.institution_id = institution_id for update;
    if not found then raise no_data_found using detail = 'ASSESSMENT_NOT_FOUND'; end if;
    if saved.management_version <> expected_version then
      raise exception using errcode='PT409', detail = 'SAI_CONCURRENT_CHANGE';
    end if;
    if saved.status <> 'draft' or saved.activity_id <> activity_id
      or saved.unit_id is distinct from unit_id then
      raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
    end if;
    update public.activity_assessment_configurations c set
      periodicity = payload->>'periodicity', result_scale_kind = payload->>'result_scale_kind',
      scale_options = payload->'scale_options',
      allow_final_override = coalesce((payload->>'allow_final_override')::boolean, false),
      management_version = c.management_version + 1, updated_at = now()
    where c.id = saved.id returning * into saved;
    delete from public.assessment_instruments item where item.configuration_id = saved.id;
    delete from public.assessment_categories item where item.configuration_id = saved.id;
    delete from public.assessment_scale_concepts item where item.configuration_id = saved.id;
    delete from public.assessment_periods item where item.configuration_id = saved.id;
  end if;

  for instrument in select value from jsonb_array_elements(payload->'instruments') loop
    if jsonb_typeof(instrument) <> 'object'
      or not (instrument ?& array['name','weight','sort_order'])
      or exists (select 1 from jsonb_object_keys(instrument) k
        where k not in ('name','weight','sort_order')) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_instruments(configuration_id, name, weight, sort_order)
    values (saved.id, btrim(instrument->>'name'), (instrument->>'weight')::numeric,
      (instrument->>'sort_order')::integer);
  end loop;
  select sum(i.weight) into instrument_total from public.assessment_instruments i
  where i.configuration_id = saved.id;
  if instrument_total <> 100 then
    raise check_violation using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;

  for concept in select value from jsonb_array_elements(coalesce(payload->'concepts','[]'::jsonb)) loop
    if jsonb_typeof(concept) <> 'object' or not (concept ?& array['code','label','sort_order']) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_scale_concepts(configuration_id, code, label, sort_order)
    values (saved.id, btrim(concept->>'code'), btrim(concept->>'label'),
      (concept->>'sort_order')::integer);
  end loop;
  if saved.result_scale_kind = 'concept'
    and not exists (select 1 from public.assessment_scale_concepts s where s.configuration_id = saved.id) then
    raise check_violation using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;

  for category in select value from jsonb_array_elements(payload->'categories') loop
    if jsonb_typeof(category) <> 'object' or not (category ?& array['name','competencies'])
      or jsonb_typeof(category->'competencies') <> 'array' then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_categories(configuration_id, name, sort_order)
    values (saved.id, btrim(category->>'name'),
      coalesce((category->>'sort_order')::integer,
        (select count(*) from public.assessment_categories c where c.configuration_id = saved.id)))
    returning id into v_category_id;
    for competency in select value from jsonb_array_elements(category->'competencies') loop
      insert into public.assessment_competencies(category_id, configuration_id, name, sort_order)
      values (v_category_id, saved.id, btrim(competency->>'name'),
        coalesce((competency->>'sort_order')::integer, 0))
      returning id into v_competency_id;
      insert into public.assessment_configuration_competencies(configuration_id, competency_id, sort_order)
      values (saved.id, v_competency_id, coalesce((competency->>'sort_order')::integer, 0));
    end loop;
  end loop;

  for period in select value from jsonb_array_elements(payload->'periods') loop
    if jsonb_typeof(period) <> 'object'
      or not (period ?& array['name','ordinal','academic_year','starts_on','ends_on',
        'entry_closes_at','family_release_at']) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    if not exists (select 1 from pg_catalog.pg_timezone_names z
      where z.name = coalesce(nullif(period->>'timezone',''), 'America/Sao_Paulo')) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_periods(
      configuration_id, institution_id, unit_id, name, periodicity, ordinal,
      academic_year, starts_on, ends_on, entry_closes_at, family_release_at,
      timezone, status)
    values (saved.id, saved.institution_id, saved.unit_id, btrim(period->>'name'),
      saved.periodicity, (period->>'ordinal')::smallint, (period->>'academic_year')::integer,
      (period->>'starts_on')::date, (period->>'ends_on')::date,
      (period->>'entry_closes_at')::timestamptz, (period->>'family_release_at')::timestamptz,
      coalesce(nullif(period->>'timezone',''), 'America/Sao_Paulo'), 'draft');
  end loop;
  return app_private.assessment_v2_finish(ctx, request_id, saved.institution_id,
    saved.id, 'configuration.save', request_hash, saved.management_version,
    saved.status, null);
end $$;

-- app_private.assessment_v2_save_gradebook [ASSESSMENT]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."assessment_v2_save_gradebook"("request_id" "uuid", "gradebook_id" "uuid", "expected_version" bigint, "payload" "jsonb", "reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; book public.assessment_gradebooks%rowtype;
  group_link public.activity_group_links%rowtype; config public.activity_assessment_configurations%rowtype;
  period public.assessment_periods%rowtype; request_hash bytea; replay jsonb; normalized jsonb;
begin
  if payload is null or jsonb_typeof(payload) <> 'object'
    or not (payload ?& array['activity_group_link_id','period_id','configuration_id','students'])
    or exists (select 1 from jsonb_object_keys(payload) k
      where k not in ('activity_group_link_id','period_id','configuration_id','students')) then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;
  request_hash := app_private.assessment_v2_hash(jsonb_build_object(
    'gradebook_id', gradebook_id, 'expected_version', expected_version,
    'payload', payload, 'reason', coalesce(reason, '')));
  if gradebook_id is null then
    begin
      select * into group_link from public.activity_group_links gl
      where gl.id = (payload->>'activity_group_link_id')::uuid and gl.status = 'active';
      select * into config from public.activity_assessment_configurations c
      where c.id = (payload->>'configuration_id')::uuid and c.status = 'active';
      select * into period from public.assessment_periods p
      where p.id = (payload->>'period_id')::uuid and p.status = 'open';
    exception when others then raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT'; end;
    if group_link.id is null or config.id is null or period.id is null
      or group_link.activity_id <> config.activity_id
      or group_link.institution_id <> config.institution_id
      or (config.unit_id is not null and config.unit_id <> group_link.unit_id)
      or period.configuration_id <> config.id
      or period.institution_id <> group_link.institution_id
      or (period.unit_id is not null and period.unit_id <> group_link.unit_id) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_REFERENCE';
    end if;
    select * into strict ctx
    from app_private.assessment_v2_require_context('activities.manage', group_link.institution_id);
    replay := app_private.assessment_v2_replay(ctx, request_id, 'gradebook.save', request_hash);
    if replay is not null then return replay; end if;
    if expected_version <> 0 then raise exception using errcode='PT409', detail = 'SAI_CONCURRENT_CHANGE'; end if;
    select * into book from public.assessment_gradebooks b
    where b.activity_group_link_id = group_link.id and b.period_id = period.id for update;
    if not found then
      insert into public.assessment_gradebooks(
        institution_id, unit_id, activity_group_link_id, period_id, configuration_id,
        students_payload, family_release_at)
      values (group_link.institution_id, group_link.unit_id, group_link.id, period.id,
        config.id, app_private.assessment_v2_initial_students(group_link.id), period.family_release_at)
      returning * into book;
    end if;
  else
    select * into book from public.assessment_gradebooks b where b.id = gradebook_id;
    if not found then raise no_data_found using detail = 'ASSESSMENT_NOT_FOUND'; end if;
    select * into strict ctx
    from app_private.assessment_v2_require_context('activities.manage', book.institution_id);
    replay := app_private.assessment_v2_replay(ctx, request_id, 'gradebook.save', request_hash);
    if replay is not null then return replay; end if;
    select * into book from public.assessment_gradebooks b where b.id = gradebook_id for update;
    if book.management_version <> expected_version then
      raise exception using errcode='PT409', detail = 'SAI_CONCURRENT_CHANGE';
    end if;
    if book.status <> 'draft' then raise check_violation using detail = 'ASSESSMENT_INVALID_STATE'; end if;
    if (payload->>'activity_group_link_id')::uuid <> book.activity_group_link_id
      or (payload->>'period_id')::uuid <> book.period_id
      or (payload->>'configuration_id')::uuid <> book.configuration_id then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_REFERENCE';
    end if;
    normalized := app_private.assessment_v2_validate_students(book, payload->'students');
    update public.assessment_gradebooks b set students_payload = normalized,
      management_version = b.management_version + 1, updated_at = now()
    where b.id = book.id returning * into book;
  end if;
  return app_private.assessment_v2_finish(ctx, request_id, book.institution_id,
    book.id, 'gradebook.save', request_hash, book.management_version,
    book.status, reason);
end $$;

-- app_private.assessment_v2_transition_gradebook [ASSESSMENT]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."assessment_v2_transition_gradebook"("request_id" "uuid", "gradebook_id" "uuid", "expected_version" bigint, "target_status" "text", "command_kind" "text", "reason" "text", "publish_at" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; book public.assessment_gradebooks%rowtype;
  request_hash bytea; replay jsonb;
begin
  select * into book from public.assessment_gradebooks b where b.id = gradebook_id;
  if not found then raise no_data_found using detail = 'ASSESSMENT_NOT_FOUND'; end if;
  select * into strict ctx
  from app_private.assessment_v2_require_context('activities.manage', book.institution_id);
  request_hash := app_private.assessment_v2_hash(jsonb_build_object(
    'gradebook_id', gradebook_id, 'expected_version', expected_version,
    'target_status', target_status, 'command_kind', command_kind,
    'reason', coalesce(reason, ''), 'publish_at', publish_at));
  replay := app_private.assessment_v2_replay(ctx, request_id, command_kind, request_hash);
  if replay is not null then return replay; end if;
  select * into book from public.assessment_gradebooks b where b.id = gradebook_id for update;
  if book.management_version <> expected_version then
    raise exception using errcode='PT409', detail = 'SAI_CONCURRENT_CHANGE';
  end if;
  if command_kind = 'gradebook.submit' and (book.status <> 'draft'
      or exists (select 1 from jsonb_array_elements(book.students_payload) student
        where student->>'state' not in ('complete','absent'))) then
    raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
  elsif command_kind = 'gradebook.review' and book.status <> 'submitted' then
    raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
  elsif command_kind = 'gradebook.return' and book.status not in ('submitted','reviewed') then
    raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
  elsif command_kind = 'gradebook.publish' and book.status <> 'reviewed' then
    raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
  elsif command_kind = 'gradebook.schedule' and (book.status <> 'reviewed'
      or publish_at is null or publish_at <= now()) then
    raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
  end if;
  update public.assessment_gradebooks b set
    status = target_status,
    management_version = b.management_version + 1,
    submitted_at = case when command_kind = 'gradebook.submit' then now() else b.submitted_at end,
    reviewed_at = case when command_kind = 'gradebook.review' then now() else b.reviewed_at end,
    published_at = case when command_kind = 'gradebook.publish' then now() else b.published_at end,
    publish_scheduled_at = case when command_kind = 'gradebook.schedule' then publish_at
      when command_kind in ('gradebook.return','gradebook.publish') then null
      else b.publish_scheduled_at end,
    updated_at = now()
  where b.id = book.id returning * into book;
  return app_private.assessment_v2_finish(ctx, request_id, book.institution_id,
    book.id, command_kind, request_hash, book.management_version, book.status, reason);
end $$;

-- app_private.change_unit_handle_for_superadmin [UNIT]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."change_unit_handle_for_superadmin"("p_request_id" "uuid", "p_unit_id" "uuid", "p_expected_version" bigint, "p_requested_handle" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare actor uuid:=app_private.current_person_id();u public.units%rowtype;n text;prior public.unit_handle_history%rowtype;begin
select*into u from public.units where id=p_unit_id for update;if u.id is null then raise no_data_found using message='unit not found';end if;
if actor is null or not app_private.has_platform_permission('units.handle.manage')
or not app_private.has_scoped_platform_permission('units.update',u.institution_id)or not app_private.has_mfa_aal2()
then raise insufficient_privilege using message='units.handle.manage and AAL2 required';end if;
n:=lower(regexp_replace(btrim(p_requested_handle),'^@','','g'));select*into prior from public.unit_handle_history where request_id=p_request_id;
if prior.id is not null then if prior.unit_id<>p_unit_id or prior.new_handle<>n then raise invalid_parameter_value using message='request replay mismatch';end if;
return app_private.unit_form_payload(p_unit_id);end if;
if u.management_version<>p_expected_version then raise exception using errcode='PT409', message='stale unit version', detail='UNIT_STALE_VERSION';end if;
if u.handle_last_changed_at is not null and u.handle_last_changed_at>now()-interval'15 days'
then raise check_violation using message='unit handle can only change every 15 days';end if;
if n!~'^[a-z0-9][a-z0-9._]{1,28}[a-z0-9]$'then raise invalid_parameter_value using message='invalid handle';end if;
update public.units set handle=n,handle_last_changed_at=now(),management_version=management_version+1,updated_at=now()where id=p_unit_id;
insert into public.unit_handle_history(request_id,unit_id,institution_id,old_handle,new_handle,changed_by_person_id)
values(p_request_id,p_unit_id,u.institution_id,u.handle,n,actor);
insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome)
values(actor,'aal2','unit.handle.change','unit',p_unit_id,u.institution_id,'success');return app_private.unit_form_payload(p_unit_id);end$_$;

-- app_private.child_safety_save_restriction [CHILD_SAFETY]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."child_safety_save_restriction"("p_request_id" "uuid", "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$ declare
  actor uuid:=app_private.current_person_id(); request_hash bytea; replay jsonb;
  target_id uuid; target_context uuid; target_unit uuid; target_institution uuid;
  expected_version bigint; current_row public.child_safety_restrictions%rowtype;
  result jsonb; before_state jsonb; starts timestamptz; ends timestamptz;
begin
  if (select auth.uid()) is null or actor is null or p_request_id is null
    or not app_private.has_mfa_aal2()
    or jsonb_typeof(p_payload)<>'object' then
    raise insufficient_privilege using message='child safety restriction unavailable';
  end if;
  request_hash:=extensions.digest(convert_to(p_payload::text,'utf8'),'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,0));
  replay:=app_private.child_safety_receipt(p_request_id,actor,'save_restriction',request_hash);
  if replay is not null then return replay; end if;
  begin
    target_id:=nullif(p_payload->>'restriction_id','')::uuid;
    target_context:=(p_payload->>'child_context_id')::uuid;
    target_unit:=(p_payload->>'unit_id')::uuid;
    expected_version:=coalesce(nullif(p_payload->>'expected_version','')::bigint,1);
    starts:=coalesce(nullif(p_payload->>'valid_from','')::timestamptz,now());
    ends:=nullif(p_payload->>'valid_until','')::timestamptz;
  exception when others then raise invalid_parameter_value using message='invalid restriction'; end;
  select c.institution_id into target_institution from public.child_contexts c
  join public.child_unit_links l on l.child_context_id=c.id and l.unit_id=target_unit
    and l.status in ('active','awaiting_allocation')
  where c.id=target_context and c.status='active';
  if target_institution is null or not app_private.child_safety_can_administer(
    target_institution,target_unit,target_context
  ) then raise no_data_found using message='child safety record unavailable'; end if;
  if btrim(coalesce(p_payload->>'restriction_code','')) !~ '^[a-z][a-z0-9_]{2,63}$'
    or char_length(btrim(coalesce(p_payload->>'title',''))) not between 3 and 120
    or char_length(btrim(coalesce(p_payload->>'description',''))) not between 3 and 1000
    or char_length(btrim(coalesce(p_payload->>'reason',''))) not between 3 and 500
    or coalesce(p_payload->>'severity','') not in ('information','attention','high','critical')
    or (ends is not null and ends<=starts) then
    raise invalid_parameter_value using message='invalid restriction';
  end if;
  if target_id is null then
    insert into public.child_safety_restrictions(
      institution_id,unit_id,child_context_id,restriction_code,title,description,severity,reason,
      valid_from,valid_until,created_by_person_id,updated_by_person_id
    ) values(target_institution,target_unit,target_context,p_payload->>'restriction_code',
      btrim(p_payload->>'title'),btrim(p_payload->>'description'),
      (p_payload->>'severity')::public.child_safety_severity,btrim(p_payload->>'reason'),
      starts,ends,actor,actor) returning id into target_id;
  else
    select r.* into current_row from public.child_safety_restrictions r
    where r.id=target_id and (r.institution_id,r.unit_id,r.child_context_id)=
      (target_institution,target_unit,target_context) for update;
    if current_row.id is null then raise no_data_found using message='child safety record unavailable'; end if;
    if current_row.version<>expected_version then
      raise exception using errcode='PT409', message='stale child safety version', detail='CHILD_SAFETY_STALE_VERSION';
    end if;
    before_state:=jsonb_build_object('status',current_row.status,'severity',current_row.severity,
      'version',current_row.version);
    update public.child_safety_restrictions set restriction_code=p_payload->>'restriction_code',
      title=btrim(p_payload->>'title'),description=btrim(p_payload->>'description'),
      severity=(p_payload->>'severity')::public.child_safety_severity,
      reason=btrim(p_payload->>'reason'),valid_from=starts,valid_until=ends,
      updated_by_person_id=actor,version=version+1,updated_at=now() where id=target_id;
  end if;
  select jsonb_build_object('restriction_id',id,'status',status,'severity',severity,'version',version)
    into result from public.child_safety_restrictions where id=target_id;
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,
    institution_id,outcome,before_json,after_json)
  values(actor,auth.jwt()->>'aal','child_safety.restriction.save','child_safety_restriction',
    target_id,target_institution,'success',before_state,result);
  return app_private.child_safety_store_receipt(
    p_request_id,actor,'save_restriction',request_hash,target_id,result
  );
end $_$;

-- app_private.create_institution_for_superadmin [INSTITUTION]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."create_institution_for_superadmin"("p_request_id" "uuid", "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
#variable_conflict use_variable
declare
  actor_person_id uuid;
  institution_id uuid;
  institution_type_id uuid;
  plan_id uuid;
  plan_code text;
  requested_status public.institution_status;
  request_hash bytea;
  result jsonb;
  prior_hash bytea;
  prior_actor uuid;
  prior_command text;
  prior_institution_id uuid;
  prior_result_management_version bigint;
  changed_fields jsonb;
  effective_payload jsonb;
  subscription_changed boolean := false;
begin
  perform effective_payload, subscription_changed; -- Reserved for parity with the update command.
  if p_request_id is null then
    raise invalid_parameter_value using message = 'request_id is required';
  end if;
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then
    raise insufficient_privilege using message = 'active person identity required';
  end if;
  if not app_private.has_scoped_platform_permission('institution.activate', null) then
    raise insufficient_privilege using message = 'institution.activate required';
  end if;
  if not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message = 'MFA AAL2 required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  request_hash := app_private.institution_management_request_hash(p_payload);
  select receipt.request_hash, receipt.actor_person_id,
         receipt.command_kind, receipt.institution_id,
         receipt.result_management_version
    into prior_hash, prior_actor, prior_command, prior_institution_id,
         prior_result_management_version
  from app_private.institution_management_command_receipts receipt
  where receipt.request_id = p_request_id;
  if prior_institution_id is not null then
    if prior_actor is distinct from actor_person_id
       or prior_command is distinct from 'create'
       or prior_hash is distinct from request_hash then
      raise invalid_parameter_value using
        message = 'request_id already used with a different command payload';
    end if;
    result := app_private.institution_management_payload(prior_institution_id);
    if result is null then
      raise no_data_found using message = 'institution receipt target not found';
    end if;
    if (result ->> 'management_version')::bigint
       is distinct from prior_result_management_version then
      raise exception using errcode='PT409', message = 'receipt result version is no longer current', detail='INSTITUTION_STALE_VERSION';
    end if;
    return result;
  end if;

  perform app_private.assert_institution_management_payload(p_payload, true);
  requested_status := coalesce(p_payload ->> 'status', 'draft')
    ::public.institution_status;
  if requested_status <> 'draft'
     and not app_private.has_scoped_platform_permission('institution.status.change', null) then
    raise insufficient_privilege using
      message = 'institution.status.change required for non-draft create';
  end if;
  select type_record.id into institution_type_id
  from public.institution_types type_record
  where lower(type_record.name) = lower(btrim(p_payload ->> 'institution_type_name'))
    and type_record.status = 'active'
  limit 1;
  if institution_type_id is null then
    raise invalid_parameter_value using message = 'unknown or inactive institution type';
  end if;

  plan_id := null;
  if p_payload ? 'subscription' then
    if not app_private.has_scoped_platform_permission('plan.change', null) then
      raise insufficient_privilege using message = 'plan.change required';
    end if;
    plan_code := lower(btrim(p_payload -> 'subscription' ->> 'plan_code'));
    select plan_record.id into plan_id
    from public.plans plan_record
    where plan_record.code = plan_code and plan_record.status = 'active'
    limit 1;
    if plan_id is null then
      raise invalid_parameter_value using message = 'unknown or inactive plan';
    end if;
  end if;

  insert into public.institutions(
    public_name, trade_name, legal_name, slug, primary_domain, document_ref,
    document_type, status, timezone, locale, institution_type_id,
    created_by, management_version
  ) values (
    btrim(p_payload ->> 'public_name'),
    nullif(btrim(p_payload ->> 'trade_name'), ''),
    nullif(btrim(p_payload ->> 'legal_name'), ''),
    lower(btrim(p_payload ->> 'slug')),
    nullif(lower(btrim(p_payload ->> 'primary_domain')), ''),
    nullif(btrim(p_payload ->> 'document_ref'), ''),
    coalesce(nullif(btrim(p_payload ->> 'document_type'), ''), 'cnpj'),
    requested_status,
    coalesce(nullif(btrim(p_payload ->> 'timezone'), ''), 'America/Sao_Paulo'),
    coalesce(nullif(btrim(p_payload ->> 'locale'), ''), 'pt-BR'),
    institution_type_id, actor_person_id, 1
  ) returning id into institution_id;

  perform app_private.apply_institution_management_children(
    institution_id, actor_person_id, p_payload, plan_id
  );
  select coalesce(jsonb_agg(key_name order by key_name), '[]'::jsonb)
    into changed_fields from jsonb_object_keys(p_payload) key_name;
  result := app_private.institution_management_payload(institution_id);

  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, before_json, after_json
  ) values (
    actor_person_id, 'aal2', 'institution.create', 'institution', institution_id,
    institution_id, 'success', null,
    jsonb_build_object(
      'status', result ->> 'status',
      'plan_id', result -> 'subscription' -> 'plan_id',
      'plan_code', result -> 'subscription' -> 'plan_code',
      'changed_fields', changed_fields
    )
  );
  insert into app_private.institution_management_command_receipts(
    request_id, actor_person_id, command_kind, institution_id,
    request_hash, result_management_version
  ) values (
    p_request_id, actor_person_id, 'create', institution_id, request_hash,
    (result ->> 'management_version')::bigint
  );
  return result;
exception
  when invalid_text_representation or datetime_field_overflow
    or check_violation or not_null_violation or foreign_key_violation
    or unique_violation then
    raise invalid_parameter_value using message = 'invalid institution payload';
end;
$$;

-- app_private.form_archive_or_delete [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_archive_or_delete"("p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid := app_private.require_forms_actor('forms.manage');
declare form_row public.forms;
declare replay jsonb;
declare deleted boolean := false;
begin
  perform app_private.form_assert_payload_keys(p_payload, array['form_id','action'], 'form archive or delete');
  perform app_private.superadmin_form_lock_legacy_resource_v2((p_payload ->> 'form_id')::uuid);
  replay := app_private.form_begin_command(p_request_id, actor, 'form_archive_or_delete', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  select * into form_row from public.forms where id = (p_payload ->> 'form_id')::uuid for update;
  perform app_private.superadmin_form_assert_legacy_resource_v2(form_row.id);
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if form_row.management_version <> p_expected_version then
    raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION';
  end if;
  if p_payload ->> 'action' = 'delete'
     and form_row.first_published_at is null
     and not exists(select 1 from public.form_applications where form_id = form_row.id)
     and not exists(select 1 from public.form_responses where form_id = form_row.id) then
    delete from public.forms where id = form_row.id;
    deleted := true;
  elsif p_payload ->> 'action' in ('delete', 'archive') then
    update public.forms set status = 'archived', archived_at = now(),
      management_version = management_version + 1, updated_by_person_id = actor, updated_at = now()
    where id = form_row.id;
  else
    raise invalid_parameter_value using message = 'invalid archive action';
  end if;
  return app_private.form_complete_command(
    p_request_id, jsonb_build_object('form_id', form_row.id, 'deleted', deleted)
  );
end;
$$;

-- app_private.form_begin_command [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_begin_command"("p_request_id" "uuid", "p_actor" "uuid", "p_command" "text", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  receipt app_private.form_command_receipts;
  request_hash bytea := extensions.digest(
    pg_catalog.convert_to(p_command || ':' || p_expected_version::text || ':' || p_payload::text, 'UTF8'),
    'sha256'
  );
begin
  if p_request_id is null or p_expected_version < 0 then
    raise invalid_parameter_value using message = 'request_id and non-negative expected_version required';
  end if;
  select * into receipt
    from app_private.form_command_receipts
   where request_id = p_request_id
   for update;
  if receipt.request_id is not null then
    if receipt.actor_person_id <> p_actor
       or receipt.command_name <> p_command
       or receipt.request_hash <> request_hash
       or receipt.expected_version <> p_expected_version then
      raise unique_violation using message = 'form command replay mismatch';
    end if;
    if receipt.completed_at is null then
      raise exception using errcode='PT409', message = 'form command is already in progress', detail='FORMS_COMMAND_CONFLICT';
    end if;
    return receipt.result_jsonb;
  end if;
  insert into app_private.form_command_receipts(
    request_id, actor_person_id, command_name, request_hash, expected_version
  ) values (p_request_id, p_actor, p_command, request_hash, p_expected_version);
  return null;
end;
$$;

-- app_private.form_complete_command [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_complete_command"("p_request_id" "uuid", "p_result" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  update app_private.form_command_receipts
     set result_jsonb = p_result, completed_at = now()
   where request_id = p_request_id and completed_at is null;
  if not found then
    raise exception using errcode='PT409', message = 'form command receipt unavailable', detail='FORMS_COMMAND_CONFLICT';
  end if;
  return p_result;
end;
$$;

-- app_private.form_complete_notification_delivery [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_complete_notification_delivery"("p_event_id" "uuid", "p_person_id" "uuid", "p_worker_id" "text", "p_delivered" boolean, "p_error_code" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not coalesce(p_delivered, false) and nullif(btrim(p_error_code), '') is null then
    raise invalid_parameter_value using message = 'notification delivery error required';
  end if;
  update public.context_notification_recipients
     set delivery_state = case when p_delivered then 'delivered' else 'failed' end,
         delivered_at = case when p_delivered then now() else null end,
         last_delivery_error_code = case when p_delivered then null else left(p_error_code, 100) end,
         next_delivery_attempt_at = case when p_delivered then next_delivery_attempt_at
           else now() + make_interval(secs => least(3600, (30 * power(2, least(delivery_attempts, 7)))::integer)) end,
         delivery_lease_owner = null,
         delivery_lease_expires_at = null
   where event_id = p_event_id and person_id = p_person_id
     and delivery_state = 'processing'
     and delivery_lease_owner = p_worker_id
     and delivery_lease_expires_at >= now();
  if not found then raise exception using errcode='PT409', message = 'notification delivery lease unavailable', detail='FORMS_WORKER_CONFLICT'; end if;
end;
$$;

-- app_private.form_copy_or_move [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_copy_or_move"("p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid := app_private.require_forms_actor('forms.manage');
declare source_row public.forms;
declare target_id uuid;
declare replay jsonb;
declare mode text;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['form_id','target_institution_id','mode'], 'form copy or move'
  );
  mode := p_payload ->> 'mode';
  if mode not in ('copy', 'move') then raise invalid_parameter_value using message = 'invalid transfer mode'; end if;
  perform app_private.superadmin_form_lock_legacy_resource_v2((p_payload ->> 'form_id')::uuid);
  replay := app_private.form_begin_command(p_request_id, actor, 'form_copy_or_move', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  select * into source_row from public.forms where id = (p_payload ->> 'form_id')::uuid for update;
  perform app_private.superadmin_form_assert_legacy_resource_v2(source_row.id);
  if source_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if source_row.management_version <> p_expected_version then
    raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION';
  end if;
  if (p_payload ->> 'target_institution_id')::uuid <> source_row.institution_id
     and not app_private.has_platform_permission('forms.transfer_cross_institution') then
    raise insufficient_privilege using message = 'forms.transfer_cross_institution required';
  end if;
  if mode = 'move' and source_row.first_published_at is null
     and not exists(select 1 from public.form_applications where form_id = source_row.id)
     and not exists(select 1 from public.form_responses where form_id = source_row.id) then
    update public.forms
       set institution_id = (p_payload ->> 'target_institution_id')::uuid,
           management_version = management_version + 1,
           updated_by_person_id = actor, updated_at = now()
     where id = source_row.id;
    target_id := source_row.id;
  else
    target_id := app_private.form_clone(
      actor, source_row.id, (p_payload ->> 'target_institution_id')::uuid
    );
  end if;
  return app_private.form_complete_command(p_request_id, app_private.form_definition_projection(target_id));
end;
$$;

-- app_private.form_duplicate [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_duplicate"("p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid := app_private.require_forms_actor('forms.manage');
declare source_row public.forms;
declare target_id uuid;
declare replay jsonb;
begin
  perform app_private.form_assert_payload_keys(p_payload, array['form_id'], 'form duplicate');
  perform app_private.superadmin_form_lock_legacy_resource_v2((p_payload ->> 'form_id')::uuid);
  replay := app_private.form_begin_command(p_request_id, actor, 'form_duplicate', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  select * into source_row from public.forms where id = (p_payload ->> 'form_id')::uuid for share;
  perform app_private.superadmin_form_assert_legacy_resource_v2(source_row.id);
  if source_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if source_row.management_version <> p_expected_version then
    raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION';
  end if;
  target_id := app_private.form_clone(actor, source_row.id, source_row.institution_id);
  return app_private.form_complete_command(p_request_id, app_private.form_definition_projection(target_id));
end;
$$;

-- app_private.form_fail_worker_job [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_fail_worker_job"("p_job_id" "uuid", "p_worker_id" "text", "p_error_code" "text", "p_retry_after_seconds" integer DEFAULT 60, "p_progress" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  update app_private.form_worker_jobs
     set state = 'failed', last_error_code = left(p_error_code, 100),
         progress_jsonb = p_progress,
         available_at = now() + make_interval(secs => least(greatest(p_retry_after_seconds, 1), 86400)),
         lease_owner = null, lease_expires_at = null
   where id = p_job_id and state = 'processing' and lease_owner = p_worker_id
     and lease_expires_at >= now();
  if not found then raise exception using errcode='PT409', message = 'worker lease unavailable', detail='FORMS_WORKER_CONFLICT'; end if;
end;
$$;

-- app_private.form_finalize_asset_upload [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_finalize_asset_upload"("p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid := app_private.require_forms_actor('forms.respond');
declare asset_row public.form_assets;
declare replay jsonb;
declare result jsonb;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['asset_id','edit_secret'], 'finalize form asset'
  );
  select * into asset_row from public.form_assets
   where id = (p_payload ->> 'asset_id')::uuid for update;
  if asset_row.id is null or not (
       asset_row.prepared_by_person_id = actor
       or (asset_row.prepared_by_person_id is null and app_private.form_verify_anonymous_edit_secret(
         p_payload ->> 'edit_secret', asset_row.anonymous_upload_secret_hash
       ))
     ) or asset_row.state not in ('prepared','uploaded','finalized')
     or asset_row.expires_at <= now() then
    raise no_data_found using message = 'form asset unavailable';
  end if;
  if asset_row.prepared_by_person_id is not null then
    replay := app_private.form_begin_command(
      p_request_id, actor, 'form_finalize_asset_upload', p_expected_version, p_payload
    );
    if replay is not null then return replay; end if;
  end if;
  if p_expected_version <> 0 then raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION'; end if;
  if asset_row.state = 'prepared' then
    update public.form_assets set state = 'uploaded' where id = asset_row.id returning * into asset_row;
  end if;
  result := jsonb_build_object(
    'asset_id', asset_row.id, 'state', asset_row.state
  );
  if asset_row.prepared_by_person_id is null then return result; end if;
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

-- app_private.form_finish_worker_job [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_finish_worker_job"("p_job_id" "uuid", "p_worker_id" "text", "p_progress" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  update app_private.form_worker_jobs
     set state = 'succeeded', progress_jsonb = p_progress,
         completed_at = now(), lease_owner = null, lease_expires_at = null
   where id = p_job_id and state = 'processing' and lease_owner = p_worker_id
     and lease_expires_at >= now();
  if not found then raise exception using errcode='PT409', message = 'worker lease unavailable', detail='FORMS_WORKER_CONFLICT'; end if;
end;
$$;

-- app_private.form_mutate_response [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_mutate_response"("p_command" "text", "p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb", "p_submit" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid := app_private.require_forms_actor('forms.respond');
declare response_row public.form_responses;
declare occurrence_row public.form_occurrences;
declare participation_row public.form_participations;
declare replay jsonb;
declare revision_number integer;
declare result jsonb;
declare expected_action text;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['response_id','participation_id','edit_secret','answers'], 'form response mutation'
  );
  select * into response_row from public.form_responses
   where id = (p_payload ->> 'response_id')::uuid for update;
  if response_row.id is null then raise no_data_found using message = 'form response unavailable'; end if;
  perform app_private.form_assert_response_actor(response_row, actor, p_payload ->> 'edit_secret');
  if response_row.identity_mode = 'identified' then
    replay := app_private.form_begin_command(
      p_request_id, actor, p_command, p_expected_version, p_payload
    );
    if replay is not null then return replay; end if;
  else
    expected_action := case when p_submit then 'submitted'
      when p_command = 'form_edit_response' then 'edited' else 'draft_saved' end;
    if response_row.management_version = p_expected_version + 1
       and exists (
         select 1 from public.form_response_revisions revision
          where revision.response_id = response_row.id
            and revision.action = expected_action
            and revision.answers_snapshot = p_payload -> 'answers'
       ) then
      return app_private.form_response_draft_projection(response_row.id);
    end if;
  end if;
  if response_row.management_version <> p_expected_version then
    raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION';
  end if;
  select * into occurrence_row from public.form_occurrences
   where id = response_row.occurrence_id for update;
  if occurrence_row.status <> 'open' or now() not between occurrence_row.opens_at and occurrence_row.closes_at then
    raise no_data_found using message = 'form occurrence unavailable';
  end if;
  select participation.* into participation_row
    from public.form_participations participation
   where participation.id = (p_payload ->> 'participation_id')::uuid
     and participation.occurrence_id = response_row.occurrence_id
     and participation.eligibility_state = 'eligible'
     and (
       participation.person_id = actor
       or exists(select 1 from public.form_participation_responders responder
                 where responder.participation_id = participation.id and responder.person_id = actor)
     )
   for update;
  if participation_row.id is null then
    raise no_data_found using message = 'form participation unavailable';
  end if;
  if p_submit and response_row.status <> 'draft' then
    raise check_violation using message = 'only a draft response can be submitted';
  end if;
  if p_command = 'form_edit_response' and response_row.status <> 'submitted' then
    raise check_violation using message = 'only a submitted response can be edited';
  end if;
  if p_command = 'form_save_response_draft' and response_row.status <> 'draft' then
    raise check_violation using message = 'only a draft response can be saved';
  end if;
  perform app_private.form_replace_response_answers(
    response_row, p_payload -> 'answers', p_payload ->> 'edit_secret'
  );
  if p_submit or p_command = 'form_edit_response' then
    perform app_private.form_assert_required_response_answers(response_row);
  end if;
  if p_submit then
    if participation_row.response_state = 'responded' then
      raise no_data_found using message = 'form participation unavailable';
    end if;
    update public.form_responses
       set status = 'submitted', submitted_at = now(), updated_at = now(),
           management_version = management_version + 1
     where id = response_row.id returning * into response_row;
    update public.form_participations
       set response_state = 'responded', responded_at = now()
     where id = participation_row.id;
    perform app_private.form_rebuild_occurrence_metrics(response_row.occurrence_id);
  else
    update public.form_responses
       set updated_at = now(), management_version = management_version + 1
     where id = response_row.id returning * into response_row;
  end if;
  select coalesce(max(revision_row.revision_number), 0) + 1 into revision_number
    from public.form_response_revisions revision_row where revision_row.response_id = response_row.id;
  insert into public.form_response_revisions(
    response_id, revision_number, action, answers_snapshot, changed_by_person_id
  ) values (
    response_row.id, revision_number,
    case when p_submit then 'submitted'
         when p_command = 'form_edit_response' then 'edited'
         else 'draft_saved' end,
    p_payload -> 'answers', case when response_row.identity_mode = 'identified' then actor else null end
  );
  result := app_private.form_response_draft_projection(response_row.id);
  if response_row.identity_mode = 'anonymous' then return result; end if;
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

-- app_private.form_open_response_draft [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_open_response_draft"("p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid := app_private.require_forms_actor('forms.respond');
declare participation_row public.form_participations;
declare occurrence_row public.form_occurrences;
declare response_row public.form_responses;
declare replay jsonb;
declare result jsonb;
declare requested_identity_mode text;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['occurrence_id','participation_id','identity_mode','edit_secret'],
    'open form response draft'
  );
  if p_expected_version <> 0 then
    raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION';
  end if;
  select * into participation_row
    from public.form_participations
   where id = (p_payload ->> 'participation_id')::uuid
     and occurrence_id = (p_payload ->> 'occurrence_id')::uuid
   for update;
  if participation_row.id is null or participation_row.eligibility_state <> 'eligible'
     or not (
       participation_row.person_id = actor
       or exists(
         select 1 from public.form_participation_responders responder
         where responder.participation_id = participation_row.id and responder.person_id = actor
       )
     ) then
    raise no_data_found using message = 'form occurrence unavailable';
  end if;
  select * into occurrence_row from public.form_occurrences
   where id = participation_row.occurrence_id for update;
  if occurrence_row.status <> 'open' or now() not between occurrence_row.opens_at and occurrence_row.closes_at then
    raise no_data_found using message = 'form occurrence unavailable';
  end if;
  select identity_mode into requested_identity_mode
    from public.forms where id = occurrence_row.form_id;
  if p_payload ->> 'identity_mode' <> requested_identity_mode then
    raise check_violation using message = 'form identity mode mismatch';
  end if;
  if requested_identity_mode = 'identified' then
    replay := app_private.form_begin_command(
      p_request_id, actor, 'form_open_response_draft', p_expected_version, p_payload
    );
    if replay is not null then return replay; end if;
  end if;
  if requested_identity_mode = 'anonymous' then
    if char_length(coalesce(p_payload ->> 'edit_secret', '')) < 43 then
      raise invalid_parameter_value using message = 'anonymous edit secret required';
    end if;
    select * into response_row
      from public.form_responses candidate
     where candidate.occurrence_id = occurrence_row.id
       and candidate.identity_mode = 'anonymous'
       and candidate.status in ('draft', 'submitted')
       and app_private.form_verify_anonymous_edit_secret(
         p_payload ->> 'edit_secret', candidate.anonymous_edit_secret_hash
       )
     limit 1;
    if participation_row.response_state = 'responded' and response_row.id is null then
      raise no_data_found using message = 'form response unavailable';
    end if;
    if response_row.id is null then
      insert into public.form_responses(
        occurrence_id, institution_id, form_id, form_version_id, identity_mode,
        anonymous_edit_secret_hash
      ) values (
        occurrence_row.id, occurrence_row.institution_id, occurrence_row.form_id,
        occurrence_row.form_version_id, 'anonymous',
        app_private.form_hash_anonymous_edit_secret(p_payload ->> 'edit_secret')
      ) returning * into response_row;
    end if;
  else
    select * into response_row from public.form_responses
     where occurrence_id = occurrence_row.id and respondent_person_id = actor
       and status in ('draft', 'submitted')
     for update;
    if participation_row.response_state = 'responded' and response_row.id is null then
      raise no_data_found using message = 'form response unavailable';
    end if;
    if response_row.id is null then
      insert into public.form_responses(
        occurrence_id, institution_id, form_id, form_version_id, identity_mode, respondent_person_id
      ) values (
        occurrence_row.id, occurrence_row.institution_id, occurrence_row.form_id,
        occurrence_row.form_version_id, 'identified', actor
      ) returning * into response_row;
    end if;
  end if;
  update public.form_participations
     set response_state = case when response_row.status = 'submitted' then 'responded' else 'draft' end,
         responded_at = case when response_row.status = 'submitted'
           then coalesce(responded_at, response_row.submitted_at) else responded_at end
   where id = participation_row.id;
  result := app_private.form_response_draft_projection(response_row.id);
  if requested_identity_mode = 'anonymous' then return result; end if;
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

-- app_private.form_prepare_asset_upload [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_prepare_asset_upload"("p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid := app_private.require_forms_actor('forms.respond');
declare occurrence_row public.form_occurrences;
declare item_row public.form_items;
declare asset_row public.form_assets;
declare replay jsonb;
declare opaque_id uuid := gen_random_uuid();
declare identity_mode text;
declare result jsonb;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['occurrence_id','item_id','mime_type','byte_length','checksum','edit_secret'],
    'prepare form asset'
  );
  if p_expected_version <> 0 then raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION'; end if;
  select * into occurrence_row from public.form_occurrences
   where id = (p_payload ->> 'occurrence_id')::uuid;
  select * into item_row from public.form_items
   where id = (p_payload ->> 'item_id')::uuid
     and form_version_id = occurrence_row.form_version_id and kind in ('photo', 'gallery');
  if occurrence_row.id is null or item_row.id is null or occurrence_row.status <> 'open'
     or now() not between occurrence_row.opens_at and occurrence_row.closes_at
     or not exists(
       select 1 from public.form_participations participation
       where participation.occurrence_id = occurrence_row.id
         and participation.eligibility_state = 'eligible'
         and (participation.person_id = actor or exists(
           select 1 from public.form_participation_responders responder
           where responder.participation_id = participation.id and responder.person_id = actor
         ))
     ) then
    raise no_data_found using message = 'form asset target unavailable';
  end if;
  select form_row.identity_mode into identity_mode
    from public.forms form_row where form_row.id = occurrence_row.form_id;
  -- Serialize the per-respondent/question quota without holding a row lock
  -- across the later Storage request (the Edge function signs only after this
  -- transaction returns).
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      occurrence_row.id::text || ':' || item_row.id::text || ':' ||
      case when identity_mode = 'anonymous'
        then encode(extensions.digest(p_payload ->> 'edit_secret', 'sha256'), 'hex')
        else actor::text end,
      0
    )
  );
  if identity_mode = 'anonymous' then
    if not exists (
      select 1 from public.form_responses response
       where response.occurrence_id = occurrence_row.id
         and response.identity_mode = 'anonymous'
         and response.status = 'draft'
         and app_private.form_verify_anonymous_edit_secret(
           p_payload ->> 'edit_secret', response.anonymous_edit_secret_hash
         )
    ) then
      raise no_data_found using message = 'form asset target unavailable';
    end if;
    select * into asset_row from public.form_assets candidate
     where candidate.occurrence_id = occurrence_row.id
       and candidate.item_id = item_row.id
       and candidate.mime_type = p_payload ->> 'mime_type'
       and candidate.expected_byte_length = (p_payload ->> 'byte_length')::bigint
        and candidate.expected_checksum_sha256 = lower(p_payload ->> 'checksum')
        and candidate.state = 'prepared'
        and candidate.expires_at > now()
       and app_private.form_verify_anonymous_edit_secret(
         p_payload ->> 'edit_secret', candidate.anonymous_upload_secret_hash
       )
     limit 1;
    if asset_row.id is not null then
      return jsonb_build_object(
        'asset_id', asset_row.id, 'storage_path', asset_row.storage_path,
        'expires_at', asset_row.expires_at
      );
    end if;
  else
    replay := app_private.form_begin_command(
      p_request_id, actor, 'form_prepare_asset_upload', p_expected_version, p_payload
    );
    if replay is not null then return replay; end if;
  end if;
  if (select count(*) from public.form_assets candidate
      where candidate.occurrence_id = occurrence_row.id and candidate.item_id = item_row.id
        and candidate.state not in ('discarded','expired')
        and (
          candidate.prepared_by_person_id = actor
          or (identity_mode = 'anonymous' and app_private.form_verify_anonymous_edit_secret(
            p_payload ->> 'edit_secret', candidate.anonymous_upload_secret_hash
          ))
        )) >= 5 then
    raise check_violation using message = 'maximum five images per question';
  end if;
  insert into public.form_assets(
    id, institution_id, occurrence_id, item_id, prepared_by_person_id,
    anonymous_upload_secret_hash, storage_path,
    mime_type, expected_byte_length, expected_checksum_sha256
  ) values (
    opaque_id, occurrence_row.institution_id, occurrence_row.id, item_row.id,
    case when identity_mode = 'identified' then actor else null end,
    case when identity_mode = 'anonymous' then
      app_private.form_hash_anonymous_edit_secret(p_payload ->> 'edit_secret') else null end,
    substr(replace(opaque_id::text, '-', ''), 1, 2) || '/' || opaque_id::text,
    p_payload ->> 'mime_type', (p_payload ->> 'byte_length')::bigint,
    lower(p_payload ->> 'checksum')
  ) returning * into asset_row;
  result := jsonb_build_object(
    'asset_id', asset_row.id, 'storage_path', asset_row.storage_path,
    'expires_at', asset_row.expires_at
  );
  if identity_mode = 'anonymous' then return result; end if;
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

-- app_private.form_publish [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_publish"("p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  actor uuid := app_private.require_forms_actor('forms.publish');
  target_form_id uuid;
  form_row public.forms;
  replay jsonb;
  result jsonb;
begin
  perform app_private.form_assert_payload_keys(p_payload, array['form_id'], 'form publish');
  target_form_id := (p_payload ->> 'form_id')::uuid;
  perform app_private.superadmin_form_lock_legacy_resource_v2(target_form_id);
  replay := app_private.form_begin_command(
    p_request_id, actor, 'form_publish', p_expected_version, p_payload
  );
  if replay is not null then return replay; end if;
  perform pg_advisory_xact_lock(hashtextextended(target_form_id::text, 0));
  select * into form_row from public.forms where id = target_form_id for update;
  perform app_private.superadmin_form_assert_legacy_resource_v2(form_row.id);
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if form_row.management_version <> p_expected_version then
    raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION';
  end if;
  if form_row.working_version_id is null then
    raise check_violation using message = 'working version required';
  end if;
  perform app_private.form_apply_location_options_v1(form_row.working_version_id);
  perform app_private.validate_form_definition(form_row.working_version_id);
  update public.form_versions
     set state = 'superseded'
   where id = form_row.published_version_id and state = 'published';
  update public.form_versions
     set state = 'published', published_at = now()
   where id = form_row.working_version_id and state = 'working';
  update public.forms
     set status = 'published',
         published_version_id = working_version_id,
         working_version_id = null,
         first_published_at = coalesce(first_published_at, now()),
         management_version = management_version + 1,
         updated_by_person_id = actor,
         updated_at = now()
   where id = target_form_id;
  update public.form_occurrences
     set form_version_id = form_row.working_version_id,
         management_version = management_version + 1
   where form_occurrences.form_id = target_form_id
     and status = 'scheduled'
     and opens_at > now();
  result := app_private.form_definition_projection(target_form_id);
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id, outcome,
    after_json
  ) values (
    actor, auth.jwt() ->> 'aal', 'forms.publish', 'form', target_form_id,
    form_row.institution_id, 'success', jsonb_build_object('published_version_id', form_row.working_version_id)
  );
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

-- app_private.form_remove_schedule [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_remove_schedule"("p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid := app_private.require_forms_actor('forms.manage_applications');
declare schedule_row public.form_schedules;
declare replay jsonb;
begin
  perform app_private.form_assert_payload_keys(p_payload, array['schedule_id'], 'remove form schedule');
  perform app_private.superadmin_form_lock_legacy_resource_v2((select a.form_id from public.form_schedules s join public.form_applications a on a.id=s.application_id where s.id=(p_payload ->> 'schedule_id')::uuid));
  replay := app_private.form_begin_command(p_request_id, actor, 'form_remove_schedule', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  select * into schedule_row from public.form_schedules
   where id = (p_payload ->> 'schedule_id')::uuid for update;
  if schedule_row.id is null then raise no_data_found using message = 'form schedule unavailable'; end if;
  if schedule_row.status <> 'active' then raise no_data_found using message = 'form schedule unavailable'; end if;
  if schedule_row.management_version <> p_expected_version then
    raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION';
  end if;
  update public.form_schedules
     set status = 'archived', management_version = management_version + 1, updated_at = now()
   where id = schedule_row.id;
  update public.form_occurrences set status = 'cancelled'
   where schedule_id = schedule_row.id and status = 'scheduled';
  return app_private.form_complete_command(
    p_request_id, app_private.form_application_projection(schedule_row.application_id)
  );
end;
$$;

-- app_private.form_request_export [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_request_export"("p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb", "p_anonymous_participation" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid := app_private.require_forms_actor(
  case when p_anonymous_participation
       then 'forms.anonymous_participation.export'
       else 'forms.responses.export' end
);
declare form_row public.forms;
declare job_row public.form_file_jobs;
declare replay jsonb;
declare command_name text := case when p_anonymous_participation
  then 'form_request_anonymous_participation_export' else 'form_request_export' end;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['form_id','occurrence_id','kind','justification'], 'form export'
  );
  perform app_private.superadmin_form_lock_legacy_resource_v2((p_payload ->> 'form_id')::uuid);
  replay := app_private.form_begin_command(
    p_request_id, actor, command_name, p_expected_version, p_payload
  );
  if replay is not null then return replay; end if;
  select * into form_row from public.forms where id = (p_payload ->> 'form_id')::uuid;
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if form_row.management_version <> p_expected_version then
    raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION';
  end if;
  if p_anonymous_participation then
    perform app_private.form_require_owner(actor, 'forms.anonymous_participation.export');
    if char_length(btrim(coalesce(p_payload ->> 'justification', ''))) < 10 then
      raise invalid_parameter_value using message = 'auditable justification required';
    end if;
  end if;
  insert into public.form_file_jobs(
    institution_id, form_id, occurrence_id, requested_by_person_id, request_id, export_kind,
    manifest_jsonb
  ) values (
    form_row.institution_id, form_row.id, (p_payload ->> 'occurrence_id')::uuid,
    actor, p_request_id,
    case when p_anonymous_participation then 'anonymous_participation' else p_payload ->> 'kind' end,
    case when p_anonymous_participation
         then jsonb_build_object('justification', btrim(p_payload ->> 'justification'))
         else '{}'::jsonb end
  ) returning * into job_row;
  insert into app_private.form_worker_jobs(job_kind, aggregate_id, payload_jsonb)
  values (
    case job_row.export_kind
      when 'csv' then 'export_csv'
      when 'xlsx' then 'export_xlsx'
      when 'zip' then 'export_zip'
      else 'export_anonymous_participation'
    end,
    job_row.id,
    jsonb_build_object('file_job_id', job_row.id)
  );
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id,
    outcome, reason, after_json
  ) values (
    actor, auth.jwt() ->> 'aal', command_name, 'form_file_job', job_row.id,
    form_row.institution_id, 'success',
    case when p_anonymous_participation then btrim(p_payload ->> 'justification') else null end,
    jsonb_build_object('form_id', form_row.id, 'export_kind', job_row.export_kind)
  );
  return app_private.form_complete_command(p_request_id, jsonb_build_object(
    'id', job_row.id, 'status', job_row.state, 'progress', job_row.progress,
    'download_path', null, 'error_code', null
  ));
end;
$$;

-- app_private.form_save_application [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."form_save_application"("p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid := app_private.require_forms_actor('forms.manage_applications');
declare application_row public.form_applications;
declare rule_json jsonb;
declare replay jsonb;
declare application_id uuid := coalesce((p_payload ->> 'id')::uuid, gen_random_uuid());
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['id','form_id','institution_id','name','status','opens_for_days','rules'],
    'form application'
  );
  perform app_private.form_assert_application_payload_limits(p_payload);
  perform app_private.superadmin_form_lock_legacy_resource_v2((p_payload ->> 'form_id')::uuid);
  perform app_private.superadmin_form_lock_legacy_resource_v2((select a.form_id from public.form_applications a where a.id=application_id));
  replay := app_private.form_begin_command(p_request_id, actor, 'form_save_application', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  perform pg_advisory_xact_lock(hashtextextended(application_id::text, 11));
  select * into application_row from public.form_applications where id = application_id for update;
  if application_row.id is null then
    if p_expected_version <> 0 then raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION'; end if;
    insert into public.form_applications(
      id, form_id, institution_id, name, status, opens_for_days, created_by_person_id
    ) values (
      application_id, (p_payload ->> 'form_id')::uuid, (p_payload ->> 'institution_id')::uuid,
      btrim(p_payload ->> 'name'), coalesce(p_payload ->> 'status', 'active'),
      coalesce((p_payload ->> 'opens_for_days')::integer, 7), actor
    ) returning * into application_row;
  else
    if application_row.management_version <> p_expected_version then
      raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION';
    end if;
    update public.form_applications set name = btrim(p_payload ->> 'name'),
      status = coalesce(p_payload ->> 'status', status),
      opens_for_days = coalesce((p_payload ->> 'opens_for_days')::integer, opens_for_days),
      management_version = management_version + 1, updated_at = now()
    where id = application_id returning * into application_row;
  end if;
  delete from public.form_audience_rules audience_rule where audience_rule.application_id = application_row.id;
  for rule_json in select value from jsonb_array_elements(p_payload -> 'rules') loop
    perform app_private.form_assert_payload_keys(
      rule_json, array['kind','mode','target_id','filter','position'], 'form audience rule'
    );
    insert into public.form_audience_rules(
      application_id, institution_id, rule_kind, rule_mode, target_id, filter_jsonb, position
    ) values (
      application_row.id, application_row.institution_id, rule_json ->> 'kind', rule_json ->> 'mode',
      (rule_json ->> 'target_id')::uuid, coalesce(rule_json -> 'filter', '{}'::jsonb),
      (rule_json ->> 'position')::integer
    );
  end loop;
  return app_private.form_complete_command(
    p_request_id, app_private.form_application_projection(application_row.id)
  );
end;
$$;

-- app_private.form_save_draft [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."form_save_draft"("p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
      raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION';
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
      raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION';
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

-- app_private.form_save_schedule [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."form_save_schedule"("p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid := app_private.require_forms_actor('forms.manage_applications');
declare schedule_row public.form_schedules;
declare replay jsonb;
declare reminder_json jsonb;
declare target_schedule_id uuid := coalesce((p_payload ->> 'schedule_id')::uuid, gen_random_uuid());
declare target_application_id uuid := (p_payload ->> 'application_id')::uuid;
begin
  perform app_private.form_assert_payload_keys(
    p_payload,
    array['schedule_id','application_id','time_zone','starts_at_local','recurrence_kind','interval','weekdays',
          'monthly_day','monthly_last_day','end_kind','ends_on','occurrence_count','reminders'],
    'form schedule'
  );
  perform app_private.form_assert_schedule_payload_limits(p_payload);
  if not exists(select 1 from pg_timezone_names where name = p_payload ->> 'time_zone') then
    raise invalid_parameter_value using message = 'unknown IANA timezone';
  end if;
  perform app_private.superadmin_form_lock_legacy_resource_v2((select a.form_id from public.form_applications a where a.id=target_application_id));
  perform app_private.superadmin_form_lock_legacy_resource_v2((select a.form_id from public.form_schedules s join public.form_applications a on a.id=s.application_id where s.id=target_schedule_id));
  replay := app_private.form_begin_command(p_request_id, actor, 'form_save_schedule', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  perform pg_advisory_xact_lock(hashtextextended(target_application_id::text, 12));
  select * into schedule_row from public.form_schedules
   where id = target_schedule_id for update;
  if schedule_row.id is not null and schedule_row.application_id <> target_application_id then
    raise no_data_found using message = 'form schedule unavailable';
  end if;
  if schedule_row.id is not null and schedule_row.status <> 'active' then
    raise no_data_found using message = 'form schedule unavailable';
  end if;
  if schedule_row.id is null and p_expected_version <> 0 then
    raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION';
  elsif schedule_row.id is not null and schedule_row.management_version <> p_expected_version then
    raise exception using errcode='PT409', message = 'expected_version mismatch', detail='FORMS_STALE_VERSION';
  end if;
  perform app_private.form_assert_schedule_capacity(target_application_id, target_schedule_id);
  insert into public.form_schedules(
    id, application_id, time_zone, starts_at_local, recurrence_kind, interval_value, weekdays,
    monthly_day, monthly_last_day, end_kind, ends_on, occurrence_count
  ) values (
    target_schedule_id, target_application_id, p_payload ->> 'time_zone',
    (p_payload ->> 'starts_at_local')::timestamp, p_payload ->> 'recurrence_kind',
    coalesce((p_payload ->> 'interval')::integer, 1),
    coalesce(array(select jsonb_array_elements_text(p_payload -> 'weekdays')::smallint), '{}'),
    (p_payload ->> 'monthly_day')::smallint,
    coalesce((p_payload ->> 'monthly_last_day')::boolean, false),
    coalesce(p_payload ->> 'end_kind', 'never'), (p_payload ->> 'ends_on')::date,
    (p_payload ->> 'occurrence_count')::integer
  ) on conflict(id) do update set
    time_zone = excluded.time_zone, starts_at_local = excluded.starts_at_local,
    recurrence_kind = excluded.recurrence_kind, interval_value = excluded.interval_value,
    weekdays = excluded.weekdays, monthly_day = excluded.monthly_day,
    monthly_last_day = excluded.monthly_last_day, end_kind = excluded.end_kind,
    ends_on = excluded.ends_on, occurrence_count = excluded.occurrence_count,
    management_version = public.form_schedules.management_version + 1, updated_at = now()
  returning * into schedule_row;
  delete from public.form_schedule_reminders where schedule_id = schedule_row.id;
  for reminder_json in select value from jsonb_array_elements(coalesce(p_payload -> 'reminders', '[]'::jsonb)) loop
    perform app_private.form_assert_payload_keys(reminder_json, array['kind','amount','position'], 'form reminder');
    insert into public.form_schedule_reminders(schedule_id, reminder_kind, amount, position)
    values (schedule_row.id, reminder_json ->> 'kind', (reminder_json ->> 'amount')::integer,
            (reminder_json ->> 'position')::integer);
  end loop;
  insert into app_private.form_worker_jobs(job_kind, aggregate_id, payload_jsonb)
  values ('generate_occurrences', schedule_row.id, jsonb_build_object('schedule_id', schedule_row.id))
  on conflict do nothing;
  return app_private.form_complete_command(
    p_request_id, app_private.form_application_projection(schedule_row.application_id)
  );
end;
$$;

-- app_private.form_worker_abort_multipart [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_worker_abort_multipart"("p_job_id" "uuid", "p_worker_id" "text", "p_file_job_id" "uuid", "p_upload_id" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare worker_job app_private.form_worker_jobs;
declare upload_row app_private.form_multipart_uploads;
begin
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id and job_kind = 'export_zip'
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise exception using errcode='PT409', message = 'worker lease unavailable', detail='FORMS_WORKER_CONFLICT';
  end if;
  select * into upload_row from app_private.form_multipart_uploads
   where file_job_id = p_file_job_id and worker_job_id = p_job_id and upload_id = p_upload_id
   for update;
  if upload_row.id is null or upload_row.state = 'completed' then
    raise no_data_found using message = 'multipart upload unavailable';
  end if;
  if upload_row.state <> 'aborted' then
    update app_private.form_multipart_uploads
       set state = 'aborted', aborted_at = now(), updated_at = now()
     where id = upload_row.id
     returning * into upload_row;
  end if;
  update app_private.form_worker_jobs
     set progress_jsonb = progress_jsonb || jsonb_build_object(
       'multipart_upload_id', upload_row.id,
       'multipart_aborted', true,
       'uploaded_bytes', upload_row.uploaded_bytes
     )
   where id = worker_job.id;
  return jsonb_build_object(
    'multipart_upload_id', upload_row.id,
    'state', upload_row.state,
    'uploaded_bytes', upload_row.uploaded_bytes
  );
end;
$$;

-- app_private.form_worker_begin_export [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_worker_begin_export"("p_job_id" "uuid", "p_worker_id" "text", "p_file_job_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare worker_job app_private.form_worker_jobs;
begin
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id
     and job_kind in ('export_csv', 'export_xlsx', 'export_zip', 'export_anonymous_participation')
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise exception using errcode='PT409', message = 'worker lease unavailable', detail='FORMS_WORKER_CONFLICT';
  end if;
  update public.form_file_jobs
     set state = 'processing', started_at = coalesce(started_at, now()), progress = greatest(progress, 0.05),
         error_code = null
   where id = p_file_job_id and state in ('pending', 'processing', 'failed') and expires_at > now();
  if not found then
    raise no_data_found using message = 'form export job unavailable';
  end if;
end;
$$;

-- app_private.form_worker_begin_multipart [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."form_worker_begin_multipart"("p_job_id" "uuid", "p_worker_id" "text", "p_file_job_id" "uuid", "p_bucket_id" "text", "p_object_path" "text", "p_upload_id" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare worker_job app_private.form_worker_jobs;
declare file_job public.form_file_jobs;
declare upload_row app_private.form_multipart_uploads;
begin
  if p_bucket_id <> 'coelo-forms-private'
     or p_object_path is null or p_object_path !~ '^[0-9a-f]{2}/[0-9a-f-]{36}$'
     or nullif(btrim(p_upload_id), '') is null or length(p_upload_id) > 1024
     or p_upload_id ~ '[[:cntrl:]]' then
    raise invalid_parameter_value using message = 'invalid multipart upload';
  end if;
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id and job_kind = 'export_zip'
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise exception using errcode='PT409', message = 'worker lease unavailable', detail='FORMS_WORKER_CONFLICT';
  end if;
  select * into file_job from public.form_file_jobs
   where id = p_file_job_id and export_kind = 'zip' and state = 'processing' and expires_at > now()
   for update;
  if file_job.id is null then
    raise no_data_found using message = 'form export job unavailable';
  end if;
  select * into upload_row from app_private.form_multipart_uploads
   where file_job_id = p_file_job_id for update;
  if upload_row.id is null then
    insert into app_private.form_multipart_uploads(
      file_job_id, worker_job_id, bucket_id, object_path, upload_id
    ) values (
      p_file_job_id, p_job_id, p_bucket_id, p_object_path, p_upload_id
    ) returning * into upload_row;
  elsif upload_row.worker_job_id <> p_job_id
     or upload_row.bucket_id <> p_bucket_id
     or upload_row.object_path <> p_object_path
     or upload_row.upload_id <> p_upload_id then
    raise exception using errcode='PT409', message = 'multipart upload already initialized', detail='FORMS_WORKER_CONFLICT';
  end if;
  update app_private.form_worker_jobs
     set progress_jsonb = progress_jsonb || jsonb_build_object(
       'multipart_upload_id', upload_row.id,
       'next_part_number', upload_row.next_part_number,
       'uploaded_bytes', upload_row.uploaded_bytes
     )
   where id = worker_job.id;
  return jsonb_build_object(
    'multipart_upload_id', upload_row.id,
    'state', upload_row.state,
    'next_part_number', upload_row.next_part_number,
    'uploaded_bytes', upload_row.uploaded_bytes
  );
end;
$_$;

-- app_private.form_worker_cleanup_snapshot [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_worker_cleanup_snapshot"("p_job_id" "uuid", "p_worker_id" "text", "p_limit" integer DEFAULT 100) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare worker_job app_private.form_worker_jobs;
declare page_limit integer := least(greatest(coalesce(p_limit, 100), 1), 200);
declare result jsonb;
begin
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and job_kind in ('cleanup_uploads', 'cleanup_artifacts')
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise exception using errcode='PT409', message = 'worker lease unavailable', detail='FORMS_WORKER_CONFLICT';
  end if;
  if worker_job.job_kind = 'cleanup_uploads' then
    select jsonb_build_object(
      'kind', worker_job.job_kind,
      'items', coalesce(jsonb_agg(jsonb_build_object('id', id, 'storage_path', storage_path)), '[]'::jsonb)
    ) into result
      from (
        select id, storage_path from public.form_assets
         where (state in ('prepared', 'uploaded') and expires_at <= now())
            or (state = 'discarded' and discarded_at is not null)
         order by expires_at, id limit page_limit
      ) candidate;
  else
    select jsonb_build_object(
      'kind', worker_job.job_kind,
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'id', id,
        'storage_path', storage_path,
        'multipart_bucket', multipart_bucket,
        'multipart_path', multipart_path,
        'multipart_upload_id', multipart_upload_id
      )), '[]'::jsonb)
    ) into result
      from (
        select file_job.id, file_job.artifact_path as storage_path,
               multipart.bucket_id as multipart_bucket,
               multipart.object_path as multipart_path,
               multipart.upload_id as multipart_upload_id
          from public.form_file_jobs file_job
          left join app_private.form_multipart_uploads multipart
            on multipart.file_job_id = file_job.id
           and multipart.state in ('initiated', 'uploading')
         where file_job.artifact_provider = 'supabase_mvp'
           and file_job.state in ('pending', 'succeeded', 'partial', 'failed')
           and file_job.expires_at <= now()
         order by file_job.expires_at, file_job.id limit page_limit
      ) candidate;
  end if;
  return result;
end;
$$;

-- app_private.form_worker_complete_cleanup [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."form_worker_complete_cleanup"("p_job_id" "uuid", "p_worker_id" "text", "p_item_ids" "uuid"[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare worker_job app_private.form_worker_jobs;
declare completed_count integer;
declare requested_count integer := coalesce(cardinality(p_item_ids), 0);
begin
  if p_item_ids is null or requested_count > 200
     or requested_count <> (
       select count(distinct item_id) from unnest(p_item_ids) as items(item_id)
     ) then
    raise invalid_parameter_value using message = 'invalid cleanup items';
  end if;
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and job_kind in ('cleanup_uploads', 'cleanup_artifacts')
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise exception using errcode='PT409', message = 'worker lease unavailable', detail='FORMS_WORKER_CONFLICT';
  end if;
  if worker_job.job_kind = 'cleanup_uploads' then
    update public.form_assets
       set state = 'expired'
     where id = any(p_item_ids) and (
       (state in ('prepared', 'uploaded') and expires_at <= now())
       or (state = 'discarded' and discarded_at is not null)
     );
  else
    update app_private.form_multipart_uploads multipart
       set state = 'aborted', aborted_at = now(), updated_at = now()
      where multipart.file_job_id = any(p_item_ids)
        and multipart.state in ('initiated', 'uploading')
        and exists (
          select 1 from public.form_file_jobs file_job
           where file_job.id = multipart.file_job_id
             and file_job.artifact_provider = 'supabase_mvp'
             and file_job.expires_at <= now()
        );
    update public.form_file_jobs
       set state = 'expired', artifact_path = null, artifact_byte_length = null
     where id = any(p_item_ids) and artifact_provider = 'supabase_mvp'
       and state in ('pending', 'succeeded', 'partial', 'failed') and expires_at <= now();
  end if;
  get diagnostics completed_count = row_count;
  if completed_count <> requested_count then
    raise exception using errcode='PT409', message = 'cleanup items unavailable', detail='FORMS_WORKER_CONFLICT';
  end if;
  update app_private.form_worker_jobs
     set state = 'succeeded', progress_jsonb = jsonb_build_object('completed', true, 'items', completed_count),
         completed_at = now(), lease_owner = null, lease_expires_at = null
   where id = worker_job.id;
end;
$$;

-- app_private.form_worker_complete_export [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_worker_complete_export"("p_job_id" "uuid", "p_worker_id" "text", "p_file_job_id" "uuid", "p_artifact_path" "text", "p_artifact_byte_length" bigint, "p_manifest" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare worker_job app_private.form_worker_jobs;
begin
  if p_artifact_path is null or p_artifact_path !~ '^[0-9a-f]{2}/[0-9a-f-]{36}$'
     or p_artifact_byte_length is null or p_artifact_byte_length < 1
     or p_manifest is null or jsonb_typeof(p_manifest) <> 'object' then
    raise invalid_parameter_value using message = 'invalid export artifact';
  end if;
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id
     and job_kind in ('export_csv', 'export_xlsx', 'export_zip', 'export_anonymous_participation')
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise exception using errcode='PT409', message = 'worker lease unavailable', detail='FORMS_WORKER_CONFLICT';
  end if;
  update public.form_file_jobs
     set state = 'succeeded', progress = 1, artifact_path = p_artifact_path,
         artifact_byte_length = p_artifact_byte_length, manifest_jsonb = p_manifest,
         completed_at = now(), error_code = null
   where id = p_file_job_id and state = 'processing' and expires_at > now();
  if not found then
    raise no_data_found using message = 'form export job unavailable';
  end if;
  update app_private.form_worker_jobs
     set state = 'succeeded', progress_jsonb = jsonb_build_object('completed', true),
         completed_at = now(), lease_owner = null, lease_expires_at = null
   where id = worker_job.id;
end;
$_$;

-- app_private.form_worker_complete_multipart [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_worker_complete_multipart"("p_job_id" "uuid", "p_worker_id" "text", "p_file_job_id" "uuid", "p_upload_id" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare worker_job app_private.form_worker_jobs;
declare upload_row app_private.form_multipart_uploads;
begin
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id and job_kind = 'export_zip'
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise exception using errcode='PT409', message = 'worker lease unavailable', detail='FORMS_WORKER_CONFLICT';
  end if;
  select * into upload_row from app_private.form_multipart_uploads
   where file_job_id = p_file_job_id and worker_job_id = p_job_id and upload_id = p_upload_id
   for update;
  if upload_row.id is null or upload_row.state = 'aborted' then
    raise no_data_found using message = 'multipart upload unavailable';
  end if;
  if upload_row.state <> 'completed' then
    if not exists(
      select 1 from app_private.form_multipart_parts
       where multipart_upload_id = upload_row.id
    ) then
      raise check_violation using message = 'multipart upload has no parts';
    end if;
    update app_private.form_multipart_uploads
       set state = 'completed', completed_at = now(), updated_at = now()
     where id = upload_row.id
     returning * into upload_row;
  end if;
  update app_private.form_worker_jobs
     set progress_jsonb = progress_jsonb || jsonb_build_object(
       'multipart_upload_id', upload_row.id,
       'multipart_completed', true,
       'uploaded_bytes', upload_row.uploaded_bytes
     )
   where id = worker_job.id;
  update public.form_file_jobs set progress = greatest(progress, 0.95)
   where id = p_file_job_id;
  return jsonb_build_object(
    'multipart_upload_id', upload_row.id,
    'state', upload_row.state,
    'part_count', upload_row.next_part_number - 1,
    'uploaded_bytes', upload_row.uploaded_bytes
  );
end;
$$;

-- app_private.form_worker_complete_xlsx_r2_v1 [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_worker_complete_xlsx_r2_v1"("p_job_id" "uuid", "p_worker_id" "text", "p_file_job_id" "uuid", "p_asset_id" "uuid", "p_actual_byte_length" bigint, "p_actual_checksum_sha256" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare v_job public.form_file_jobs; v_worker app_private.form_worker_jobs;
  v_ctx app_private.superadmin_internal_context;
begin
  if p_asset_id is null or p_actual_byte_length is null or p_actual_byte_length<1
    or p_actual_checksum_sha256 is null or p_actual_checksum_sha256!~'^[0-9a-f]{64}$' then
    raise invalid_parameter_value using message='forms_xlsx_measurement_invalid';
  end if;
  v_job:=app_private.forms_xlsx_worker_job_v1(p_job_id,p_worker_id,p_file_job_id,p_asset_id);
  select * into strict v_worker from app_private.form_worker_jobs where id=p_job_id;
  perform 1 from public.media_assets where id=p_asset_id for update;
  perform app_private.forms_xlsx_worker_job_v1(p_job_id,p_worker_id,p_file_job_id,p_asset_id);
  if exists(select 1 from app_private.form_multipart_uploads m where m.media_asset_id=p_asset_id
    and m.artifact_provider='r2' and (m.state is distinct from 'completed'
      or m.uploaded_bytes is distinct from p_actual_byte_length
      or m.checksum_sha256 is distinct from p_actual_checksum_sha256)) then
    raise check_violation using message='forms_xlsx_multipart_finalization_mismatch';
  end if;
  -- Measurements come only from the service generating and writing the XLSX.
  -- No client grant and no caller-supplied path, MIME, tenant or manifest.
  update public.media_assets set status='ready',byte_size=p_actual_byte_length,
    checksum_sha256=p_actual_checksum_sha256,finalized_at=clock_timestamp() where id=p_asset_id;
  update public.form_file_jobs set state='succeeded',progress=1,artifact_byte_length=p_actual_byte_length,
    completed_at=clock_timestamp(),error_code=null,
    manifest_jsonb=jsonb_build_object('format_version',snapshot_format_version,'response_count',snapshot_row_count,
      'schema_sha256',snapshot_schema_sha256)
    where id=v_job.id;
  update app_private.form_worker_jobs set state='succeeded',completed_at=clock_timestamp(),
    lease_owner=null,lease_expires_at=null,progress_jsonb=jsonb_build_object('completed',true)
    where id=p_job_id;
  v_ctx:=app_private.forms_xlsx_context_from_session_v1(v_job.requested_by_internal_identity_id,v_job.requested_auth_link_id,
    v_job.requested_membership_id,v_job.requested_auth_session_id,v_job.requested_scope_kind,v_job.requested_scope_institution_id);
  perform app_private.audit_append_superadmin_internal(v_ctx.internal_identity_id,v_ctx.internal_auth_link_id,
    v_ctx.internal_membership_id,v_ctx.session_id,'forms.responses.export',v_ctx.aal,
    'superadmin.forms.export.complete','success',null,gen_random_uuid(),v_job.institution_id,'form_file_job',v_job.id);
  if v_worker.lease_expires_at<=clock_timestamp() or v_job.expires_at<=clock_timestamp() then
    raise exception using errcode='PT409', message='forms_xlsx_lease_unavailable', detail='FORMS_WORKER_CONFLICT';
  end if;
  return jsonb_build_object('job_id',v_job.id,'asset_id',p_asset_id,'state','succeeded',
    'byte_length',p_actual_byte_length,'checksum_sha256',p_actual_checksum_sha256,'expires_at',v_job.expires_at);
end;
$_$;

-- app_private.form_worker_fail_export [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_worker_fail_export"("p_job_id" "uuid", "p_worker_id" "text", "p_file_job_id" "uuid", "p_error_code" "text", "p_retry_after_seconds" integer DEFAULT 60) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare worker_job app_private.form_worker_jobs;
declare file_state text;
begin
  if nullif(btrim(p_error_code), '') is null then
    raise invalid_parameter_value using message = 'export error code required';
  end if;
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id
     and job_kind in ('export_csv', 'export_xlsx', 'export_zip', 'export_anonymous_participation')
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise exception using errcode='PT409', message = 'worker lease unavailable', detail='FORMS_WORKER_CONFLICT';
  end if;
  update public.form_file_jobs
     set state = case when expires_at <= now() then 'expired' else 'failed' end,
         error_code = left(p_error_code, 100)
   where id = p_file_job_id and state in ('pending', 'processing')
   returning state into file_state;
  if file_state is null then
    raise no_data_found using message = 'form export job unavailable';
  end if;
  update app_private.form_worker_jobs
     set state = case when file_state = 'expired' then 'succeeded' else 'failed' end,
         last_error_code = left(p_error_code, 100),
         progress_jsonb = jsonb_build_object('completed', false),
         available_at = now() + make_interval(secs => least(greatest(p_retry_after_seconds, 1), 86400)),
         completed_at = case when file_state = 'expired' then now() else null end,
         lease_owner = null, lease_expires_at = null
   where id = worker_job.id;
end;
$$;

-- app_private.form_worker_multipart_snapshot [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."form_worker_multipart_snapshot"("p_job_id" "uuid", "p_worker_id" "text", "p_file_job_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare worker_job app_private.form_worker_jobs;
declare upload_row app_private.form_multipart_uploads;
begin
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id and job_kind = 'export_zip'
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now();
  if worker_job.id is null then
    raise exception using errcode='PT409', message = 'worker lease unavailable', detail='FORMS_WORKER_CONFLICT';
  end if;
  select * into upload_row from app_private.form_multipart_uploads
   where file_job_id = p_file_job_id and worker_job_id = p_job_id and state <> 'aborted';
  if upload_row.id is null then return null; end if;
  return jsonb_build_object(
    'bucket_id', upload_row.bucket_id,
    'object_path', upload_row.object_path,
    'upload_id', upload_row.upload_id,
    'state', upload_row.state,
    'next_part_number', upload_row.next_part_number,
    'uploaded_bytes', upload_row.uploaded_bytes,
    'parts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'part_number', part.part_number,
        'etag', part.etag,
        'byte_length', part.byte_length,
        'checksum_sha256', part.checksum_sha256
      ) order by part.part_number)
      from app_private.form_multipart_parts part
      where part.multipart_upload_id = upload_row.id
    ), '[]'::jsonb)
  );
end;
$$;

-- app_private.form_worker_multipart_xlsx_r2_v1 [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 8, handlers: 0.
create or replace function "app_private"."form_worker_multipart_xlsx_r2_v1"("p_scope" "jsonb", "p_operation" "text", "p_payload" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare v_job public.form_file_jobs; v_asset public.media_assets; v_worker app_private.form_worker_jobs;
  v_upload app_private.form_multipart_uploads; v_part app_private.form_multipart_parts;
  v_job_id uuid; v_file_job_id uuid; v_asset_id uuid; v_owner text; v_expected jsonb;
  v_upload_id text; v_number integer; v_bytes bigint; v_etag text; v_checksum text; v_allowed text[];
begin
  if current_setting('transaction_isolation')<>'read committed' or p_scope is null or jsonb_typeof(p_scope)<>'object'
    or pg_column_size(p_scope)>4096 or p_payload is null or jsonb_typeof(p_payload)<>'object'
    or pg_column_size(p_payload)>4096 or p_operation is null
    or p_operation not in ('authorize','snapshot','begin','record_part','complete','reconcile') then
    raise invalid_parameter_value using message='forms_xlsx_multipart_input_invalid';
  end if;
  v_job_id:=(p_scope->>'worker_job_id')::uuid; v_file_job_id:=(p_scope->>'file_job_id')::uuid;
  v_asset_id:=(p_scope->>'asset_id')::uuid; v_owner:=p_scope->>'worker_id';
  if v_job_id is null or v_file_job_id is null or v_asset_id is null or v_owner is null then
    raise invalid_parameter_value using message='forms_xlsx_multipart_input_invalid';
  end if;
  if p_operation='reconcile' then
    select * into v_worker from app_private.form_worker_jobs where id=v_job_id
      and aggregate_id=v_file_job_id and job_kind='export_xlsx_r2_v1' for share;
    if v_worker.id is null then return null; end if;
    select * into v_upload from app_private.form_multipart_uploads where worker_job_id=v_job_id
      and file_job_id=v_file_job_id and media_asset_id=v_asset_id and artifact_provider='r2' for share;
    if v_upload.id is null then return null; end if;
    v_expected:=app_private.forms_xlsx_multipart_projection_v1(v_upload.id)->'scope';
    if p_scope is distinct from v_expected then raise exception using errcode='PT409', message='forms_xlsx_multipart_scope_mismatch', detail='FORMS_WORKER_CONFLICT'; end if;
  else
    v_job:=app_private.forms_xlsx_worker_job_v1(v_job_id,v_owner,v_file_job_id,v_asset_id);
    select * into strict v_worker from app_private.form_worker_jobs where id=v_job_id;
    select * into strict v_asset from public.media_assets where id=v_asset_id for update;
    v_expected:=jsonb_build_object('worker_job_id',v_job_id,'worker_id',v_owner,'file_job_id',v_file_job_id,
      'attempt',v_worker.attempts,'asset_id',v_asset_id,'bucket',v_asset.bucket_id,'object_key',v_asset.object_key,
      'snapshot_format_version',v_job.snapshot_format_version,'snapshot_row_count',v_job.snapshot_row_count);
    if p_scope is distinct from v_expected then raise exception using errcode='PT409', message='forms_xlsx_multipart_scope_mismatch', detail='FORMS_WORKER_CONFLICT'; end if;
    select * into v_upload from app_private.form_multipart_uploads
      where media_asset_id=v_asset_id and artifact_provider='r2' for update;
  end if;
  v_allowed:=case p_operation
    when 'begin' then array['upload_id']
    when 'record_part' then array['upload_id','part_number','etag','byte_length','checksum_sha256']
    when 'complete' then array['upload_id','byte_length','checksum_sha256']
    when 'reconcile' then array['upload_id','byte_length','checksum_sha256']
    else array[]::text[] end;
  if exists(select 1 from jsonb_object_keys(p_payload) k where not(k=any(v_allowed)))
    or exists(select 1 from unnest(v_allowed) k where not(p_payload?k)) then
    raise invalid_parameter_value using message='forms_xlsx_multipart_payload_invalid';
  end if;
  if p_operation in ('authorize','snapshot') then
    perform app_private.forms_xlsx_worker_job_v1(v_job_id,v_owner,v_file_job_id,v_asset_id);
    if p_operation='authorize' then return jsonb_build_object('authorized',true,'scope',v_expected); end if;
    return app_private.forms_xlsx_multipart_projection_v1(v_upload.id);
  end if;
  v_upload_id:=p_payload->>'upload_id';
  if jsonb_typeof(p_payload->'upload_id')<>'string' or v_upload_id is null
    or length(v_upload_id) not between 1 and 1024 or v_upload_id ~ '[[:space:][:cntrl:]]' then
    raise invalid_parameter_value using message='forms_xlsx_multipart_upload_id_invalid';
  end if;
  if p_operation='begin' then
    if v_upload.id is null then
      insert into app_private.form_multipart_uploads(file_job_id,worker_job_id,bucket_id,object_path,upload_id,
        artifact_provider,media_asset_id,worker_attempt,attempt_owner,snapshot_format_version,snapshot_row_count)
      values(v_file_job_id,v_job_id,v_asset.bucket_id,v_asset.object_key,v_upload_id,'r2',v_asset_id,
        v_worker.attempts,v_owner,v_job.snapshot_format_version,v_job.snapshot_row_count) returning * into v_upload;
    elsif v_upload.upload_id<>v_upload_id or v_upload.state='aborted' then
      raise exception using errcode='PT409', message='forms_xlsx_multipart_begin_mismatch', detail='FORMS_WORKER_CONFLICT';
    end if;
  else
    if v_upload.id is null or v_upload.upload_id<>v_upload_id or v_upload.state='aborted' then
      raise exception using errcode='PT409', message='forms_xlsx_multipart_upload_unavailable', detail='FORMS_WORKER_CONFLICT';
    end if;
    v_bytes:=(p_payload->>'byte_length')::bigint; v_checksum:=p_payload->>'checksum_sha256';
    if jsonb_typeof(p_payload->'byte_length')<>'number' or v_bytes is null or v_bytes<1
      or p_payload->'byte_length'<>to_jsonb(v_bytes) or jsonb_typeof(p_payload->'checksum_sha256')<>'string'
      or v_checksum is null or v_checksum!~'^[0-9a-f]{64}$' then
      raise invalid_parameter_value using message='forms_xlsx_measurement_invalid';
    end if;
    if p_operation='record_part' then
      v_number:=(p_payload->>'part_number')::integer; v_etag:=p_payload->>'etag';
      if jsonb_typeof(p_payload->'part_number')<>'number' or v_number is null or v_number not between 1 and 10000
        or p_payload->'part_number'<>to_jsonb(v_number) or jsonb_typeof(p_payload->'etag')<>'string'
        or v_etag is null or length(v_etag) not between 3 and 1024 or v_etag!~'^"[^"[:cntrl:]]+"$'
        or v_bytes>67108864 then raise invalid_parameter_value using message='forms_xlsx_multipart_part_invalid'; end if;
      select * into v_part from app_private.form_multipart_parts where multipart_upload_id=v_upload.id and part_number=v_number;
      if v_part.multipart_upload_id is not null then
        if (v_part.etag,v_part.byte_length,v_part.checksum_sha256) is distinct from (v_etag,v_bytes,v_checksum) then
          raise exception using errcode='PT409', message='forms_xlsx_multipart_part_replay_mismatch', detail='FORMS_WORKER_CONFLICT';
        end if;
      else
        if v_upload.state='completed' or v_number<>v_upload.next_part_number then
          raise exception using errcode='PT409', message='forms_xlsx_multipart_part_out_of_sequence', detail='FORMS_WORKER_CONFLICT';
        end if;
        -- Before another part, the preceding part must satisfy the provider's
        -- minimum and uniform non-final size. The final part may be smaller.
        if v_number>1 and (v_bytes>(select first.byte_length from app_private.form_multipart_parts first
          where first.multipart_upload_id=v_upload.id and first.part_number=1)
          or exists(select 1 from app_private.form_multipart_parts p
          where p.multipart_upload_id=v_upload.id and (p.byte_length<5242880 or p.byte_length<>
            (select first.byte_length from app_private.form_multipart_parts first
             where first.multipart_upload_id=v_upload.id and first.part_number=1)))) then
          raise check_violation using message='forms_xlsx_multipart_nonfinal_size_invalid';
        end if;
        insert into app_private.form_multipart_parts(multipart_upload_id,part_number,etag,byte_length,checksum_sha256)
          values(v_upload.id,v_number,v_etag,v_bytes,v_checksum);
        update app_private.form_multipart_uploads set state='uploading',next_part_number=next_part_number+1,
          uploaded_bytes=uploaded_bytes+v_bytes,updated_at=clock_timestamp() where id=v_upload.id returning * into v_upload;
      end if;
    elsif p_operation='complete' then
      if v_upload.uploaded_bytes<>v_bytes or v_upload.next_part_number<=1 then
        raise check_violation using message='forms_xlsx_multipart_measurement_mismatch';
      end if;
      if v_upload.state='completed' then
        if v_upload.checksum_sha256<>v_checksum then raise exception using errcode='PT409', message='forms_xlsx_multipart_complete_mismatch', detail='FORMS_WORKER_CONFLICT'; end if;
      else
        update app_private.form_multipart_uploads set state='completed',checksum_sha256=v_checksum,
          completed_at=clock_timestamp(),updated_at=clock_timestamp() where id=v_upload.id returning * into v_upload;
      end if;
    elsif p_operation='reconcile' then
      if v_upload.state<>'completed' then return null; end if;
      if v_upload.uploaded_bytes<>v_bytes or v_upload.checksum_sha256<>v_checksum then
        raise exception using errcode='PT409', message='forms_xlsx_multipart_complete_mismatch', detail='FORMS_WORKER_CONFLICT';
      end if;
      return app_private.forms_xlsx_multipart_projection_v1(v_upload.id);
    end if;
  end if;
  perform app_private.forms_xlsx_worker_job_v1(v_job_id,v_owner,v_file_job_id,v_asset_id);
  return app_private.forms_xlsx_multipart_projection_v1(v_upload.id);
end;
$_$;

-- app_private.form_worker_record_multipart_part [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 3, handlers: 0.
create or replace function "app_private"."form_worker_record_multipart_part"("p_job_id" "uuid", "p_worker_id" "text", "p_file_job_id" "uuid", "p_upload_id" "text", "p_part_number" integer, "p_etag" "text", "p_byte_length" bigint, "p_checksum_sha256" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare worker_job app_private.form_worker_jobs;
declare upload_row app_private.form_multipart_uploads;
declare part_row app_private.form_multipart_parts;
begin
  if p_part_number not between 1 and 10000
     or nullif(btrim(p_etag), '') is null or length(p_etag) > 1024 or p_etag ~ '[[:cntrl:]]'
     or p_byte_length is null or p_byte_length < 1
     or p_checksum_sha256 is null or p_checksum_sha256 !~ '^[0-9a-f]{64}$' then
    raise invalid_parameter_value using message = 'invalid multipart part';
  end if;
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and aggregate_id = p_file_job_id and job_kind = 'export_zip'
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise exception using errcode='PT409', message = 'worker lease unavailable', detail='FORMS_WORKER_CONFLICT';
  end if;
  select * into upload_row from app_private.form_multipart_uploads
   where file_job_id = p_file_job_id and worker_job_id = p_job_id and upload_id = p_upload_id
   for update;
  if upload_row.id is null or upload_row.state not in ('initiated', 'uploading') then
    raise no_data_found using message = 'multipart upload unavailable';
  end if;
  select * into part_row from app_private.form_multipart_parts
   where multipart_upload_id = upload_row.id and part_number = p_part_number;
  if part_row.multipart_upload_id is not null then
    if part_row.etag <> p_etag or part_row.byte_length <> p_byte_length
       or part_row.checksum_sha256 <> p_checksum_sha256 then
      raise exception using errcode='PT409', message = 'multipart part replay mismatch', detail='FORMS_WORKER_CONFLICT';
    end if;
  else
    if p_part_number <> upload_row.next_part_number then
      raise exception using errcode='PT409', message = 'multipart part out of sequence', detail='FORMS_WORKER_CONFLICT';
    end if;
    insert into app_private.form_multipart_parts(
      multipart_upload_id, part_number, etag, byte_length, checksum_sha256
    ) values (
      upload_row.id, p_part_number, p_etag, p_byte_length, p_checksum_sha256
    );
    update app_private.form_multipart_uploads
       set state = 'uploading', next_part_number = next_part_number + 1,
           uploaded_bytes = uploaded_bytes + p_byte_length, updated_at = now()
     where id = upload_row.id
     returning * into upload_row;
  end if;
  update app_private.form_worker_jobs
     set progress_jsonb = progress_jsonb || jsonb_build_object(
       'multipart_upload_id', upload_row.id,
       'next_part_number', upload_row.next_part_number,
       'uploaded_bytes', upload_row.uploaded_bytes
     )
   where id = worker_job.id;
  update public.form_file_jobs set progress = greatest(progress, 0.1)
   where id = p_file_job_id;
  return jsonb_build_object(
    'multipart_upload_id', upload_row.id,
    'state', upload_row.state,
    'next_part_number', upload_row.next_part_number,
    'uploaded_bytes', upload_row.uploaded_bytes
  );
end;
$_$;

-- app_private.forms_xlsx_worker_job_v1 [FORMS_WORKER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 3, handlers: 0.
create or replace function "app_private"."forms_xlsx_worker_job_v1"("p_job_id" "uuid", "p_worker_id" "text", "p_file_job_id" "uuid", "p_asset_id" "uuid" DEFAULT NULL::"uuid") RETURNS "public"."form_file_jobs"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_worker app_private.form_worker_jobs; v_job public.form_file_jobs;
  v_ctx app_private.superadmin_internal_context;
begin
  if current_setting('transaction_isolation')<>'read committed' or p_job_id is null or p_file_job_id is null
    or p_worker_id is null or length(p_worker_id) not between 1 and 240 then
    raise invalid_parameter_value using message='forms_xlsx_worker_input_invalid';
  end if;
  select * into v_worker from app_private.form_worker_jobs where id=p_job_id
    and aggregate_id=p_file_job_id and job_kind='export_xlsx_r2_v1'
    and state='processing' and lease_owner=p_worker_id and lease_expires_at>clock_timestamp() for update;
  if v_worker.id is null then raise exception using errcode='PT409', message='forms_xlsx_lease_unavailable', detail='FORMS_WORKER_CONFLICT'; end if;
  select j.* into v_job from public.form_file_jobs j join public.forms f on f.id=j.form_id and f.institution_id=j.institution_id
    join public.institutions i on i.id=j.institution_id and i.deleted_at is null
    where j.id=p_file_job_id and j.artifact_provider='r2' and j.export_kind='xlsx' and j.snapshot_ready
      and j.state in ('pending','processing','failed') and j.expires_at>clock_timestamp() for update of j;
  if v_job.id is null then raise no_data_found using message='forms_xlsx_job_unavailable'; end if;
  v_ctx:=app_private.forms_xlsx_context_from_session_v1(v_job.requested_by_internal_identity_id,v_job.requested_auth_link_id,
    v_job.requested_membership_id,v_job.requested_auth_session_id,v_job.requested_scope_kind,v_job.requested_scope_institution_id);
  if v_ctx.scope_kind='institution' and v_ctx.scope_institution_id is distinct from v_job.institution_id then
    raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
  end if;
  if p_asset_id is not null and (v_job.artifact_media_asset_id is distinct from p_asset_id
    or not exists(select 1 from public.media_assets a where a.id=p_asset_id and a.export_file_job_id=v_job.id
      and a.status='pending' and a.catalog_kind='form-xlsx'
      and a.upload_request_id='xlsx:'||v_worker.id::text||':'||v_worker.attempts::text)) then
    raise exception using errcode='PT409', message='forms_xlsx_attempt_unavailable', detail='FORMS_WORKER_CONFLICT';
  end if;
  if v_worker.lease_expires_at<=clock_timestamp() or v_job.expires_at<=clock_timestamp() then
    raise exception using errcode='PT409', message='forms_xlsx_lease_unavailable', detail='FORMS_WORKER_CONFLICT';
  end if;
  return v_job;
end;
$$;

-- app_private.guard_superadmin_internal_auth_link_lifecycle [INTERNAL_USER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."guard_superadmin_internal_auth_link_lifecycle"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if tg_op='DELETE' then
    raise object_not_in_prerequisite_state using message='internal auth link history is append-only';
  end if;
  if new.id is distinct from old.id or new.created_at is distinct from old.created_at
    or new.internal_identity_id is distinct from old.internal_identity_id
    or new.auth_user_id is distinct from old.auth_user_id then
    raise object_not_in_prerequisite_state using message='internal auth link identity is immutable';
  end if;
  if old.status='revoked' and new is distinct from old then
    raise object_not_in_prerequisite_state using message='revoked internal access is terminal';
  end if;
  if new is distinct from old and new.version<>old.version+1 then
    raise exception using errcode='PT409', message='internal auth link version mismatch', detail='INTERNAL_USER_STALE_VERSION';
  end if;
  return new;
end
$$;

-- app_private.guard_superadmin_internal_membership_lifecycle [INTERNAL_USER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."guard_superadmin_internal_membership_lifecycle"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if tg_op='DELETE' then
    raise object_not_in_prerequisite_state using message='internal membership history is append-only';
  end if;
  if new.id is distinct from old.id or new.created_at is distinct from old.created_at
    or new.internal_identity_id is distinct from old.internal_identity_id then
    raise object_not_in_prerequisite_state using message='internal membership identity is immutable';
  end if;
  if old.status='revoked' and new is distinct from old then
    raise object_not_in_prerequisite_state using message='revoked internal access is terminal';
  end if;
  if new is distinct from old and new.version<>old.version+1 then
    raise exception using errcode='PT409', message='internal membership version mismatch', detail='INTERNAL_USER_STALE_VERSION';
  end if;
  return new;
end
$$;

-- app_private.location_reservation_command_v2 [LOCATION]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 5, handlers: 1.
create or replace function "app_private"."location_reservation_command_v2"("p_operation" "text", "p_location_id" "uuid", "p_payload" "jsonb", "p_request_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    SET "TimeZone" TO 'UTC'
    AS $_$
declare ctx app_private.superadmin_internal_context; initial_actor uuid; initial_session uuid;
  target public.activity_locations%rowtype; target_reservation public.location_reservations%rowtype;
  v_owner_id uuid; owner_kind text; capability text; correlation uuid:=gen_random_uuid();
  policy_record public.location_scheduling_policies%rowtype;
  receipt app_private.location_reservation_receipts%rowtype;
  normalized jsonb; consumer jsonb; requested_hash bytea; result jsonb;
  conflicts jsonb; can_override boolean:=false; is_write boolean;
  error_code text; error_detail text; new_id uuid; expected_version bigint; audit_institution_id uuid;
  page_limit integer; after_id uuid; after_created timestamptz; page_ids uuid[];
begin
  is_write:=p_operation in('create','cancel','policy_set');
  capability:=case when is_write then 'locations.reservations.manage' else 'locations.reservations.read' end;
  begin
    if p_operation is null or p_operation not in('create','assess','cancel','list','policy_get','policy_set')
      or p_payload is null or jsonb_typeof(p_payload)<>'object'
      or current_setting('transaction_isolation')<>'read committed'
      or (is_write and p_request_id is null) then
      raise invalid_parameter_value using message='invalid reservation command';
    end if;
    select * into strict ctx from app_private.require_superadmin_internal_context(capability);
    initial_actor:=ctx.internal_identity_id; initial_session:=ctx.session_id;
    if p_operation in('create','assess') then
      normalized:=app_private.location_reservation_normalize_v2(p_payload);
      p_location_id:=(normalized->>'location_id')::uuid;
    end if;
    if p_location_id is null then raise invalid_parameter_value using message='location required'; end if;
    if is_write then
      requested_hash:=extensions.digest(convert_to(p_operation||':'||p_location_id::text||':'||p_payload::text,'UTF8'),'sha256');
      perform pg_advisory_xact_lock(hashtextextended('location-reservation-request:'||initial_actor::text||':'||p_request_id::text,0));
    end if;
    -- This first lookup yields only the owner lock key; no data is returned or
    -- effect performed before the canonical ownership check below.
    select l.scope_kind,coalesce(l.unit_id,l.institution_id) into owner_kind,v_owner_id
      from public.activity_locations l where l.id=p_location_id;
    if v_owner_id is null then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    if p_operation='policy_set' then
      perform pg_advisory_xact_lock(hashtextextended('location-reservation-owner:'||owner_kind||':'||v_owner_id::text,0));
    else
      perform pg_advisory_xact_lock_shared(hashtextextended('location-reservation-owner:'||owner_kind||':'||v_owner_id::text,0));
    end if;
    select * into strict ctx from app_private.require_superadmin_internal_context(capability);
    target:=app_private.superadmin_location_locked_v2(ctx,p_location_id);
    if target.scope_kind is distinct from owner_kind or coalesce(target.unit_id,target.institution_id) is distinct from v_owner_id then
      raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE';
    end if;
    if ctx.internal_identity_id is distinct from initial_actor or ctx.session_id is distinct from initial_session then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
    if not exists(select 1 from auth.sessions s where s.id=initial_session
      and (s.not_after is null or s.not_after>clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
    -- Set only after the canonical location lock has resolved and authorized
    -- ownership. Client location UUIDs are never institution audit targets.
    audit_institution_id:=target.institution_id;
    if p_operation in('create','assess') then
      if (normalized->>'location_id')::uuid is distinct from target.id then
        raise invalid_parameter_value using message='reservation location mismatch';
      end if;
      consumer:=normalized->'consumer';
    elsif p_operation in('cancel','list') then consumer:=p_payload->'consumer'; end if;
    if consumer is not null then
      perform app_private.location_reservation_consumer_v2(ctx,target,consumer,is_write);
    elsif p_operation in('create','assess','cancel','list') then
      raise invalid_parameter_value using message='reservation consumer required';
    end if;
    select p.* into policy_record from public.location_scheduling_policies p
      where p.scope_kind=owner_kind and p.owner_id=v_owner_id;
    if is_write then
      select r.* into receipt from app_private.location_reservation_receipts r
        where r.actor_id=initial_actor and r.request_id=p_request_id;
      if found and (receipt.operation is distinct from p_operation
        or receipt.request_hash is distinct from requested_hash or receipt.location_id is distinct from target.id) then
        raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE';
      end if;
    end if;
    if receipt.request_id is not null then
      result:=receipt.result;
      new_id:=receipt.reservation_id;
    elsif p_operation='policy_get' then
      if p_payload<>'{}'::jsonb then raise invalid_parameter_value; end if;
      result:=jsonb_build_object('scope_kind',owner_kind,'owner_id',v_owner_id,
        'policy',policy_record.policy,'management_version',coalesce(policy_record.management_version,0));
    elsif p_operation='policy_set' then
      if not(p_payload ?& array['policy','expected_version'])
        or (select count(*) from jsonb_object_keys(p_payload))<>2
        or coalesce(p_payload->>'policy','') not in('block','warn')
        or coalesce(p_payload->>'expected_version','') !~ '^(0|[1-9][0-9]{0,17})$' then
        raise invalid_parameter_value using message='invalid scheduling policy';
      end if;
      expected_version:=(p_payload->>'expected_version')::bigint;
      if expected_version<>coalesce(policy_record.management_version,0) then
        raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE';
      end if;
      insert into public.location_scheduling_policies(scope_kind,owner_id,institution_id,unit_id,policy,updated_by_internal_identity_id)
        values(owner_kind,v_owner_id,target.institution_id,target.unit_id,p_payload->>'policy',initial_actor)
      on conflict on constraint location_scheduling_policies_pkey do update set policy=excluded.policy,
        management_version=location_scheduling_policies.management_version+1,
        updated_at=clock_timestamp(),updated_by_internal_identity_id=excluded.updated_by_internal_identity_id
      returning * into policy_record;
      result:=jsonb_build_object('scope_kind',owner_kind,'owner_id',v_owner_id,
        'policy',policy_record.policy,'management_version',policy_record.management_version);
    elsif p_operation in('create','assess') then
      if target.status<>'active' or policy_record.policy is null then
        raise invalid_parameter_value using message='active location and explicit scheduling policy required';
      end if;
      select coalesce(jsonb_agg(jsonb_build_object('starts_at',x.starts_at,'ends_at',x.ends_at) order by x.starts_at,x.ends_at),'[]')
        into conflicts from (select distinct o.starts_at,o.ends_at
          from public.location_reservations r join public.location_reservation_occurrences o on o.reservation_id=r.id
          where r.location_id=target.id and r.state='active'
            and exists(select 1 from jsonb_array_elements(normalized->'occurrences') requested
              where tstzrange(o.starts_at,o.ends_at,'[)') && tstzrange((requested->>'starts_at')::timestamptz,(requested->>'ends_at')::timestamptz,'[)'))
          order by o.starts_at,o.ends_at limit 1000) x;
      if jsonb_array_length(conflicts)>0 and policy_record.policy='warn' then
        begin
          perform app_private.require_superadmin_internal_context('locations.reservations.override');
          can_override:=true;
        exception when insufficient_privilege then can_override:=false; end;
      end if;
      if p_operation='assess' then
        result:=jsonb_build_object('location_id',target.id,'consumer',consumer,'policy',policy_record.policy,
          'conflict',case when jsonb_array_length(conflicts)=0 then 'none'
            when policy_record.policy='block' then 'refused' when can_override then 'confirmable' else 'not_confirmable' end,
          'conflicting',conflicts);
      else
        if jsonb_array_length(conflicts)>0 then
          if policy_record.policy='block' then raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if;
          if not can_override then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
          if normalized->>'conflict_justification' is null then
            raise invalid_parameter_value using message='conflict justification required';
          end if;
        end if;
        insert into public.location_bindings(location_id,consumer_kind,consumer_id,group_id,activity_id)
          values(target.id,consumer->>'kind',(consumer->>'id')::uuid,
            case when consumer->>'kind'='group' then (consumer->>'id')::uuid end,
            case when consumer->>'kind'='activity' then (consumer->>'id')::uuid end)
          on conflict do nothing;
        insert into public.location_reservations(location_id,consumer_kind,consumer_id,recurrence,
          confirmed_over_conflict,conflict_justification,actor_internal_identity_id)
          values(target.id,consumer->>'kind',(consumer->>'id')::uuid,normalized->'recurrence',
            jsonb_array_length(conflicts)>0,case when jsonb_array_length(conflicts)>0 then normalized->>'conflict_justification' end,initial_actor)
          returning id into new_id;
        insert into public.location_reservation_occurrences(reservation_id,starts_at,ends_at)
          select new_id,(value->>'starts_at')::timestamptz,(value->>'ends_at')::timestamptz
          from jsonb_array_elements(normalized->'occurrences');
        result:=app_private.location_reservation_payload_v2(new_id);
      end if;
    elsif p_operation='cancel' then
      if not(p_payload ?& array['consumer','reservation_id','expected_version'])
        or (select count(*) from jsonb_object_keys(p_payload))<>3
        or coalesce(p_payload->>'expected_version','') !~ '^[1-9][0-9]{0,17}$' then raise invalid_parameter_value; end if;
      select r.* into target_reservation from public.location_reservations r
        where r.id=(p_payload->>'reservation_id')::uuid and r.location_id=target.id
          and r.consumer_kind=consumer->>'kind' and r.consumer_id=(consumer->>'id')::uuid for update;
      if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
      if target_reservation.management_version<>(p_payload->>'expected_version')::bigint
        or target_reservation.state<>'active' then raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if;
      update public.location_reservations set state='cancelled',management_version=management_version+1,updated_at=clock_timestamp()
        where id=target_reservation.id;
      new_id:=target_reservation.id;
      result:=app_private.location_reservation_payload_v2(new_id);
    elsif p_operation='list' then
      if not(p_payload ?& array['consumer','after_id','limit'])
        or (select count(*) from jsonb_object_keys(p_payload))<>3
        or coalesce(p_payload->>'limit','') !~ '^[1-9][0-9]{0,2}$' then raise invalid_parameter_value; end if;
      page_limit:=(p_payload->>'limit')::integer;
      if page_limit>100 then raise invalid_parameter_value; end if;
      after_id:=(p_payload->>'after_id')::uuid;
      if after_id is not null then
        select r.created_at into after_created from public.location_reservations r
          where r.id=after_id and r.location_id=target.id and r.consumer_kind=consumer->>'kind'
            and r.consumer_id=(consumer->>'id')::uuid;
        if not found then raise invalid_parameter_value using message='invalid reservation cursor'; end if;
      end if;
      select array_agg(x.id order by x.created_at,x.id) into page_ids
        from (select r.id,r.created_at from public.location_reservations r
          where r.location_id=target.id and r.consumer_kind=consumer->>'kind' and r.consumer_id=(consumer->>'id')::uuid
            and (after_id is null or (r.created_at,r.id)>(after_created,after_id))
          order by r.created_at,r.id limit page_limit+1) x;
      result:=jsonb_build_object('location_id',target.id,'consumer',consumer,
        'items',(select coalesce(jsonb_agg(app_private.location_reservation_payload_v2(x.id) order by x.position),'[]')
          from unnest(page_ids[1:page_limit]) with ordinality x(id,position)),
        'next_id',case when cardinality(page_ids)>page_limit then page_ids[page_limit] end);
    end if;
    if is_write and receipt.request_id is null then
      insert into app_private.location_reservation_receipts(actor_id,request_id,operation,request_hash,location_id,reservation_id,result)
        values(initial_actor,p_request_id,p_operation,requested_hash,target.id,new_id,result);
    end if;
    -- Audit can wait on the shared chain lock. Keep success records inside the
    -- same rollback boundary and authorize again AFTER every append completes.
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
      ctx.internal_membership_id,ctx.session_id,capability,ctx.aal,'location.reservation.'||p_operation,'success',null,
      correlation,target.institution_id,case when new_id is not null then 'location_reservation' else 'location' end,
      coalesce(new_id,target.id));
    if p_operation='create' and receipt.request_id is null and jsonb_array_length(conflicts)>0 then
      perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
        ctx.internal_membership_id,ctx.session_id,'locations.reservations.override',ctx.aal,
        'location.reservation.override','success','RESERVATION_CONFLICT_OVERRIDE',correlation,
        target.institution_id,'location_reservation',new_id);
    end if;
    -- Recheck after all potentially blocking writes/audits. Raising inside this
    -- subtransaction removes data, receipt, binding AND success audit records.
    select * into strict ctx from app_private.require_superadmin_internal_context(capability);
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    if consumer is not null then perform app_private.location_reservation_consumer_v2(ctx,target,consumer,is_write); end if;
    if p_operation in('create','assess') and can_override and jsonb_array_length(conflicts)>0 then
      perform app_private.require_superadmin_internal_context('locations.reservations.override');
    end if;
    select * into strict ctx from app_private.require_superadmin_internal_context(capability);
    if ctx.internal_identity_id is distinct from initial_actor or ctx.session_id is distinct from initial_session
      or not exists(select 1 from auth.sessions s where s.id=initial_session and (s.not_after is null or s.not_after>clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
  exception when insufficient_privilege then
    get stacked diagnostics error_detail=pg_exception_detail;
    error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then error_detail else 'SAI_PERMISSION_DENIED' end;
  when invalid_parameter_value or invalid_text_representation or numeric_value_out_of_range then error_code:='SAI_INVALID_ARGUMENT';
  when serialization_failure or sqlstate 'PT409' or unique_violation then error_code:='SAI_CONCURRENT_CHANGE';
  when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(capability,'location.reservation.'||p_operation,error_code,correlation,audit_institution_id);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$_$;

-- app_private.superadmin_access_profile_assignment_link [ACCESS_PROFILE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 3, handlers: 0.
create or replace function "app_private"."superadmin_access_profile_assignment_link"("p_request_id" "uuid", "p_draft" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare profile_id uuid:=nullif(p_draft->>'profile_id','')::uuid;domain text;actor uuid;replay jsonb;
  person_id uuid:=nullif(p_draft->>'person_id','')::uuid;membership public.institution_memberships%rowtype;
  assignment_id uuid;result jsonb;scope_kind text:=coalesce(p_draft->>'scope_kind','institution');
  template public.access_profile_templates%rowtype;context_record record;profile_version bigint;
  expected_profile_version bigint:=nullif(p_draft->>'profile_version','')::bigint;
  unit_id uuid:=nullif(p_draft->>'unit_id','')::uuid;group_id uuid:=nullif(p_draft->>'group_id','')::uuid;
begin
  domain:=case when exists(select 1 from public.platform_roles where id=profile_id) then 'platform'
    when exists(select 1 from public.institution_roles where id=profile_id) then 'institution'
    when exists(select 1 from public.access_profile_templates where id=profile_id and domain='principal') then 'principal' end;
  actor:=app_private.access_profile_require_mutation(domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'assignment_link',p_draft);if replay is not null then return replay;end if;
  perform app_private.assert_access_profile_assignment_delegable(domain,profile_id);
  if domain='platform' then
    select version into profile_version from public.platform_roles where id=profile_id and status='active' for update;
    if profile_version is null then raise no_data_found using message='active profile not found';end if;
    if expected_profile_version is null or expected_profile_version<>profile_version then
      raise exception using errcode='PT409', message='stale profile version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
    if scope_kind not in('platform','institution')
      or (scope_kind='platform' and nullif(p_draft->>'institution_id','') is not null)
      or (scope_kind='institution' and not exists(select 1 from public.institutions institution
        where institution.id=nullif(p_draft->>'institution_id','')::uuid and institution.status='active')) then
      raise invalid_parameter_value using message='invalid platform assignment scope';end if;
    perform 1 from public.people where id=person_id and status='active' and deleted_at is null for update;
    if not found then raise no_data_found using message='person not found';end if;
    insert into public.platform_memberships(person_id,role_id,status,scope_kind,scope_institution_id,mfa_required,invited_by)
    values(person_id,profile_id,'active',scope_kind,nullif(p_draft->>'institution_id','')::uuid,true,actor)
    returning id into assignment_id;
  elsif domain='institution' then
    select * into membership from public.institution_memberships where id=nullif(p_draft->>'membership_id','')::uuid for update;
    select version into profile_version from public.institution_roles role_record where role_record.id=profile_id
      and role_record.status='active' and (role_record.institution_id is null or role_record.institution_id=membership.institution_id) for update;
    if membership.id is null or membership.person_id<>person_id or membership.status<>'active' or membership.revoked_at is not null
      or profile_version is null then raise no_data_found using message='authorized membership or profile not found';end if;
    if expected_profile_version is null or expected_profile_version<>profile_version then
      raise exception using errcode='PT409', message='stale profile version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
    if scope_kind not in('institution','unit','group')
      or (scope_kind='institution' and (unit_id is not null or group_id is not null))
      or (scope_kind='unit' and (unit_id is null or group_id is not null or not exists(select 1 from public.units unit_record
        where unit_record.id=unit_id and unit_record.institution_id=membership.institution_id and unit_record.status='active')))
      or (scope_kind='group' and (group_id is null or not exists(select 1 from public.groups group_record
        where group_record.id=group_id and group_record.institution_id=membership.institution_id and group_record.status='active'
          and (unit_id is null or group_record.unit_id=unit_id)))) then
      raise invalid_parameter_value using message='invalid institution assignment scope';end if;
    insert into public.institution_role_assignments(membership_id,role_id,scope_kind,scope_unit_id,scope_group_id,
      starts_at,expires_at,granted_by,status) values(membership.id,profile_id,scope_kind,unit_id,group_id,
      nullif(p_draft->>'starts_at','')::timestamptz,nullif(p_draft->>'expires_at','')::timestamptz,actor,'active')
    returning id into assignment_id;
  elsif domain='principal' then
    select * into template from public.access_profile_templates
      where id=profile_id and domain='principal' and status='active' for update;
    if expected_profile_version is null or template.id is null or template.version<>expected_profile_version then
      raise exception using errcode='PT409', message='stale profile model version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
    select context_permission.*,guardian.guardian_person_id as selected_guardian_person_id,child_context.status as selected_child_context_status into context_record
    from public.guardian_context_permissions context_permission
    join public.guardian_links guardian on guardian.id=context_permission.guardian_link_id
      and guardian.status='active' and guardian.revoked_at is null
    join public.child_contexts child_context on child_context.id=context_permission.child_context_id
    where context_permission.id=nullif(p_draft->>'guardian_context_permission_id','')::uuid
      and context_permission.status='active' and (context_permission.expires_at is null or context_permission.expires_at>now())
    for update of context_permission;
    if context_record.id is null or context_record.selected_context_record.selected_guardian_person_id<>person_id or context_record.selected_context_record.selected_child_context_status<>'active' then
      raise no_data_found using message='authorized Principal context not found';end if;
    insert into public.guardian_context_permission_grants(guardian_context_permission_id,capability_id,effect,status,
      changed_by_person_id,reason) select context_record.id,item.capability_id,item.effect,'active',actor,
      coalesce(nullif(btrim(p_draft->>'reason'),''),'Modelo Principal copiado como snapshot.')
    from public.access_profile_template_principal_capabilities item where item.template_id=template.id
    on conflict(guardian_context_permission_id,capability_id) do update set effect=excluded.effect,status='active',
      changed_by_person_id=actor,reason=excluded.reason,revoked_at=null,updated_at=now();
    update public.guardian_context_permissions set source_template_id=template.id,source_template_version=template.version,
      starts_at=coalesce(nullif(p_draft->>'starts_at','')::timestamptz,starts_at),
      expires_at=coalesce(nullif(p_draft->>'expires_at','')::timestamptz,expires_at),version=version+1,updated_at=now()
    where id=context_record.id returning id,version into assignment_id,profile_version;
  else raise invalid_parameter_value using message='unsupported profile assignment';end if;
  result:=jsonb_build_object('assignment_id',assignment_id,'profile_id',profile_id,'domain',domain,'person_id',person_id,
    'membership_id',case when domain='institution' then membership.id end,
    'institution_id',case when domain='institution' then membership.institution_id
      when domain='platform' then nullif(p_draft->>'institution_id','')::uuid end,
    'unit_id',unit_id,'group_id',group_id,
    'guardian_context_permission_id',case when domain='principal' then assignment_id end,
    'scope_kind',case when domain='principal' then 'child_context' else scope_kind end,
    'starts_at',nullif(p_draft->>'starts_at',''),'expires_at',nullif(p_draft->>'expires_at',''),
    'version',case when domain='principal' then profile_version::text else '1' end,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,after_json)
  values(actor,'aal2','membership_changed',domain||'_access_profile_assignment',assignment_id,'success',
    coalesce(nullif(btrim(p_draft->>'reason'),''),'Vínculo de pessoa ao perfil.'),result);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'assignment_link',p_draft,result);return result;
end $$;

-- app_private.superadmin_access_profile_assignment_overrides_save [ACCESS_PROFILE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 3, handlers: 0.
create or replace function "app_private"."superadmin_access_profile_assignment_overrides_save"("p_request_id" "uuid", "p_assignment_id" "uuid", "p_expected_version" bigint, "p_overrides" "jsonb", "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare domain text;actor uuid;payload jsonb:=jsonb_build_object('assignment_id',p_assignment_id,
  'expected_version',p_expected_version,'overrides',p_overrides,'reason',p_reason);replay jsonb;
  assignment public.institution_role_assignments%rowtype;membership public.institution_memberships%rowtype;
  item jsonb;permission public.institution_permissions%rowtype;capability public.guardian_permission_capabilities%rowtype;
  current_version bigint;result jsonb;platform_membership public.platform_memberships%rowtype;platform_permission public.platform_permissions%rowtype;
begin
  if jsonb_typeof(p_overrides)<>'array' or nullif(btrim(p_reason),'') is null then raise invalid_parameter_value using message='invalid overrides';end if;
  domain:=case when exists(select 1 from public.platform_memberships where id=p_assignment_id) then 'platform'
    when exists(select 1 from public.institution_role_assignments where id=p_assignment_id) then 'institution'
    when exists(select 1 from public.guardian_context_permissions where id=p_assignment_id) then 'principal' end;
  actor:=app_private.access_profile_require_mutation(domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'overrides_save',payload);if replay is not null then return replay;end if;
  if domain='platform' then
    select * into platform_membership from public.platform_memberships where id=p_assignment_id for update;
    if platform_membership.version<>p_expected_version then raise exception using errcode='PT409', message='stale assignment version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
    for item in select value from jsonb_array_elements(p_overrides) loop
      if item->>'intent' not in('inherit','allow','deny') then raise invalid_parameter_value using message='invalid override intent';end if;
      select * into platform_permission from public.platform_permissions where code=item->>'capability_code' and status='active';
      if platform_permission.id is null then raise invalid_parameter_value using message='unknown capability';end if;
      if platform_membership.person_id=actor and item->>'intent'='allow' and not app_private.has_platform_permission(platform_permission.code) then
        raise insufficient_privilege using message='cannot elevate own access';end if;
      if item->>'intent'='inherit' then update public.platform_member_permission_overrides set status='inactive'
        where membership_id=p_assignment_id and permission_id=platform_permission.id;
      else insert into public.platform_member_permission_overrides(membership_id,permission_id,effect,conditions_json,granted_by,status)
        values(p_assignment_id,platform_permission.id,(item->>'intent')::public.permission_effect,'{}',actor,'active')
        on conflict(membership_id,permission_id) do update set effect=excluded.effect,status='active',granted_by=actor;end if;
    end loop;
    update public.platform_memberships set version=version+1 where id=p_assignment_id returning version into current_version;
  elsif domain='institution' then
    select * into assignment from public.institution_role_assignments where id=p_assignment_id for update;
    if assignment.version<>p_expected_version then raise exception using errcode='PT409', message='stale assignment version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
    select * into membership from public.institution_memberships where id=assignment.membership_id;
    for item in select value from jsonb_array_elements(p_overrides) loop
      if item->>'intent' not in('inherit','allow','deny') then raise invalid_parameter_value using message='invalid override intent';end if;
      select * into permission from public.institution_permissions where code=item->>'capability_code' and status='active';
      if permission.id is null then raise invalid_parameter_value using message='unknown capability';end if;
      if membership.person_id=actor and item->>'intent'='allow' and not app_private.has_context_permission(
        membership.institution_id,permission.code,assignment.scope_unit_id,assignment.scope_group_id) then
        raise insufficient_privilege using message='cannot elevate own access';end if;
      if item->>'intent'='inherit' then update public.institution_member_permission_overrides set status='inactive',revoked_at=now(),
        changed_by_person_id=actor where membership_id=membership.id and permission_code=permission.code
          and institution_id=membership.institution_id and scope_kind=assignment.scope_kind
          and scope_unit_id is not distinct from assignment.scope_unit_id and scope_group_id is not distinct from assignment.scope_group_id;
      else insert into public.institution_member_permission_overrides(membership_id,permission_code,effect,scope_kind,scope_id,
        reason,status,changed_by_person_id,institution_id,scope_unit_id,scope_group_id)
        values(membership.id,permission.code,(item->>'intent')::public.permission_effect,assignment.scope_kind,
          case assignment.scope_kind when 'unit' then assignment.scope_unit_id when 'group' then assignment.scope_group_id end,
          p_reason,'active',actor,membership.institution_id,assignment.scope_unit_id,assignment.scope_group_id)
        on conflict(membership_id,permission_code,scope_kind,(coalesce(scope_id,'00000000-0000-0000-0000-000000000000'::uuid)))
          where status='active' and revoked_at is null do update set effect=excluded.effect,reason=excluded.reason,
            changed_by_person_id=actor,updated_at=now();end if;
    end loop;
    update public.institution_role_assignments set version=version+1,updated_at=now() where id=p_assignment_id returning version into current_version;
  elsif domain='principal' then
    select version into current_version from public.guardian_context_permissions where id=p_assignment_id for update;
    if current_version<>p_expected_version then raise exception using errcode='PT409', message='stale assignment version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
    for item in select value from jsonb_array_elements(p_overrides) loop
      if item->>'intent' not in('inherit','allow','deny') then raise invalid_parameter_value using message='invalid override intent';end if;
      select * into capability from public.guardian_permission_capabilities where code=item->>'capability_code' and status='active';
      if capability.id is null then raise invalid_parameter_value using message='unknown capability';end if;
      if item->>'intent'='inherit' then update public.guardian_context_permission_grants set status='inactive',revoked_at=now(),
        changed_by_person_id=actor,updated_at=now() where guardian_context_permission_id=p_assignment_id and capability_id=capability.id;
      else insert into public.guardian_context_permission_grants(guardian_context_permission_id,capability_id,effect,status,
        changed_by_person_id,reason) values(p_assignment_id,capability.id,(item->>'intent')::public.permission_effect,'active',actor,p_reason)
        on conflict(guardian_context_permission_id,capability_id) do update set effect=excluded.effect,status='active',
          changed_by_person_id=actor,reason=p_reason,revoked_at=null,updated_at=now();end if;
    end loop;
    update public.guardian_context_permissions set version=version+1,updated_at=now() where id=p_assignment_id returning version into current_version;
  else raise no_data_found using message='assignment not found';end if;
  result:=jsonb_build_object('assignment_id',p_assignment_id,'domain',domain,'version',current_version,'replayed',false,
    'capabilities',app_private.superadmin_access_profile_capability_catalog(domain,null,p_assignment_id));
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,after_json)
  values(actor,'aal2','permission_changed',domain||'_access_profile_override',p_assignment_id,'success',p_reason,result-'capabilities');
  perform app_private.access_profile_store_receipt(p_request_id,actor,'overrides_save',payload,result);return result;
end $$;

-- app_private.superadmin_access_profile_assignment_unlink [ACCESS_PROFILE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 3, handlers: 0.
create or replace function "app_private"."superadmin_access_profile_assignment_unlink"("p_request_id" "uuid", "p_assignment_id" "uuid", "p_expected_version" bigint, "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare domain text;actor uuid;payload jsonb:=jsonb_build_object('assignment_id',p_assignment_id,
  'expected_version',p_expected_version,'reason',p_reason);replay jsonb;current_version bigint;result jsonb;
begin
  domain:=case when exists(select 1 from public.platform_memberships where id=p_assignment_id) then 'platform'
    when exists(select 1 from public.institution_role_assignments where id=p_assignment_id) then 'institution'
    when exists(select 1 from public.guardian_context_permissions where id=p_assignment_id) then 'principal' end;
  actor:=app_private.access_profile_require_mutation(domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'assignment_unlink',payload);if replay is not null then return replay;end if;
  if nullif(btrim(p_reason),'') is null then raise invalid_parameter_value using message='reason required';end if;
  if domain='platform' then
    perform pg_advisory_xact_lock(hashtextextended('access-profile-full-authority',0));
    select version into current_version from public.platform_memberships where id=p_assignment_id for update;
    if current_version is distinct from p_expected_version then raise exception using errcode='PT409', message='stale assignment version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
    update public.platform_memberships set status='inactive',revoked_at=now(),version=version+1 where id=p_assignment_id;
    perform app_private.assert_full_authority_remains();
  elsif domain='institution' then
    select version into current_version from public.institution_role_assignments where id=p_assignment_id for update;
    if current_version is distinct from p_expected_version then raise exception using errcode='PT409', message='stale assignment version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
    update public.institution_role_assignments set status='inactive',version=version+1,updated_at=now() where id=p_assignment_id;
  elsif domain='principal' then
    select version into current_version from public.guardian_context_permissions where id=p_assignment_id for update;
    if current_version is distinct from p_expected_version then raise exception using errcode='PT409', message='stale assignment version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
    update public.guardian_context_permissions set status='inactive',version=version+1,updated_at=now() where id=p_assignment_id;
  else raise no_data_found using message='assignment not found';end if;
  result:=jsonb_build_object('assignment_id',p_assignment_id,'domain',domain,'version',current_version+1,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,after_json)
  values(actor,'aal2','membership_changed',domain||'_access_profile_assignment',p_assignment_id,'success',p_reason,result);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'assignment_unlink',payload,result);return result;
end $$;

-- app_private.superadmin_access_profile_create_from_model [ACCESS_PROFILE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."superadmin_access_profile_create_from_model"("p_request_id" "uuid", "p_draft" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare template public.access_profile_templates%rowtype;actor uuid;replay jsonb;profile jsonb;result jsonb;
  capabilities jsonb;context_id uuid;before_data jsonb;expected_model_version bigint:=nullif(p_draft->>'model_version','')::bigint;
  guardian_person_id uuid;child_context_status public.record_status;
begin
  select * into template from public.access_profile_templates where id=nullif(p_draft->>'model_id','')::uuid for update;
  if template.id is null or template.status<>'active' then raise no_data_found using message='access profile model not found';end if;
  if expected_model_version is null or template.version<>expected_model_version then
    raise exception using errcode='PT409', message='stale access profile model version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
  actor:=app_private.access_profile_require_mutation(template.domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'create_from_model',p_draft);if replay is not null then return replay;end if;
  perform app_private.assert_access_profile_template_delegable(template.id,template.domain);
  if template.domain='platform' then
    select coalesce(jsonb_agg(jsonb_build_object('code',permission_record.code,'effect',item.effect::text) order by permission_record.code),'[]')
      into capabilities from public.access_profile_template_platform_permissions item
      join public.platform_permissions permission_record on permission_record.id=item.permission_id where item.template_id=template.id;
  elsif template.domain='institution' then
    select coalesce(jsonb_agg(jsonb_build_object('code',permission_record.code,'effect',item.effect::text) order by permission_record.code),'[]')
      into capabilities from public.access_profile_template_institution_permissions item
      join public.institution_permissions permission_record on permission_record.id=item.permission_id where item.template_id=template.id;
  else
    context_id:=nullif(p_draft->>'guardian_context_permission_id','')::uuid;
    select to_jsonb(context_permission),guardian.guardian_person_id,child_context.status
      into before_data,guardian_person_id,child_context_status
    from public.guardian_context_permissions context_permission
    join public.guardian_links guardian on guardian.id=context_permission.guardian_link_id
      and guardian.status='active' and guardian.revoked_at is null
    join public.child_contexts child_context on child_context.id=context_permission.child_context_id
    where context_permission.id=context_id and context_permission.status='active'
      and (context_permission.expires_at is null or context_permission.expires_at>now()) for update of context_permission;
    if before_data is null or child_context_status<>'active'
      or (nullif(p_draft->>'person_id','') is not null and guardian_person_id<>nullif(p_draft->>'person_id','')::uuid) then
      raise no_data_found using message='authorized Principal context not found';end if;
    insert into public.guardian_context_permission_grants(guardian_context_permission_id,capability_id,effect,status,changed_by_person_id,reason)
    select context_id,item.capability_id,item.effect,'active',actor,'Modelo copiado como snapshot.'
    from public.access_profile_template_principal_capabilities item where item.template_id=template.id
    on conflict(guardian_context_permission_id,capability_id) do update set effect=excluded.effect,status='active',
      changed_by_person_id=excluded.changed_by_person_id,reason=excluded.reason,revoked_at=null,updated_at=now();
    update public.guardian_context_permissions set source_template_id=template.id,source_template_version=template.version,
      version=version+1,updated_at=now() where id=context_id;
    profile:=jsonb_build_object('id',context_id,'domain','principal','version',
      (select version from public.guardian_context_permissions where id=context_id),
      'source_template_id',template.id,'source_template_version',template.version);
    result:=jsonb_build_object('profile',profile,'profile_id',context_id,'domain','principal','version',profile->'version','replayed',false);
    insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,before_json,after_json)
    values(actor,'aal2','permission_changed','principal_context_permissions',context_id,'success',
      coalesce(nullif(btrim(p_draft->>'reason'),''),'Aplicação de modelo Principal.'),before_data,profile);
    perform app_private.access_profile_store_receipt(p_request_id,actor,'create_from_model',p_draft,result);return result;
  end if;
  profile:=app_private.access_profile_create_internal(actor,jsonb_build_object('domain',template.domain,
    'name',coalesce(nullif(btrim(p_draft->>'name'),''),template.name),'description',coalesce(p_draft->>'description',template.description),
    'status','inactive','max_scope_kind',coalesce(p_draft->>'max_scope_kind',template.max_scope_kind),'capabilities',capabilities),
    template.id,template.version);
  result:=jsonb_build_object('profile',profile,'profile_id',profile->>'id','domain',template.domain,
    'version',(profile->>'version')::bigint,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,after_json)
  values(actor,'aal2','permission_changed',template.domain||'_access_profile',(profile->>'id')::uuid,'success',
    coalesce(nullif(btrim(p_draft->>'reason'),''),'Criação a partir de modelo.'),profile);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'create_from_model',p_draft,result);return result;
end $$;

-- app_private.superadmin_access_profile_delete_and_reassign [ACCESS_PROFILE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."superadmin_access_profile_delete_and_reassign"("p_request_id" "uuid", "p_domain" "text", "p_profile_id" "uuid", "p_expected_version" bigint, "p_replacement_profile_id" "uuid", "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid;payload jsonb:=jsonb_build_object('domain',p_domain,'profile_id',p_profile_id,
  'expected_version',p_expected_version,'replacement_profile_id',p_replacement_profile_id,'reason',p_reason);
  replay jsonb;current_version bigint;is_system boolean;link_count bigint;before_data jsonb;result jsonb;
begin
  actor:=app_private.access_profile_require_mutation(p_domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'delete_and_reassign',payload);if replay is not null then return replay;end if;
  if p_profile_id is null or p_expected_version is null or nullif(btrim(p_reason),'') is null
    or p_replacement_profile_id=p_profile_id then raise invalid_parameter_value using message='invalid delete request';end if;
  if p_domain='platform' then
    perform pg_advisory_xact_lock(hashtextextended('access-profile-full-authority',0));
    select version,platform_roles.is_system,to_jsonb(platform_roles) into current_version,is_system,before_data
      from public.platform_roles where id=p_profile_id for update;
    if current_version is null then raise no_data_found using message='access profile not found';end if;
    if is_system then raise insufficient_privilege using message='system profile is protected';end if;
    if current_version<>p_expected_version then raise exception using errcode='PT409', message='stale profile version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
    select count(*) into link_count from public.platform_memberships where role_id=p_profile_id and status='active' and revoked_at is null;
    if link_count>0 and not exists(select 1 from public.platform_roles where id=p_replacement_profile_id and status='active') then
      raise check_violation using message='active replacement required';end if;
    update public.platform_memberships set role_id=p_replacement_profile_id,version=version+1 where role_id=p_profile_id;
    delete from public.platform_roles where id=p_profile_id;perform app_private.assert_full_authority_remains();
  elsif p_domain='institution' then
    select version,institution_roles.is_system,to_jsonb(institution_roles) into current_version,is_system,before_data
      from public.institution_roles where id=p_profile_id for update;
    if current_version is null then raise no_data_found using message='access profile not found';end if;
    -- P45: modelo do sistema de Admin e excluido so pela hierarquia de plataforma (como owner).
    if is_system and not app_private.has_scoped_platform_permission('institution.roles.manage',null) then
      raise insufficient_privilege using message='system profile is protected';end if;
    if current_version<>p_expected_version then raise exception using errcode='PT409', message='stale profile version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
    select count(*) into link_count from public.institution_role_assignments where role_id=p_profile_id and status='active';
    if link_count>0 and not exists(select 1 from public.institution_roles replacement
      join public.institution_roles removed on removed.id=p_profile_id where replacement.id=p_replacement_profile_id
        and replacement.status='active' and (replacement.institution_id is null or replacement.institution_id=removed.institution_id)
        and not exists(select 1 from public.institution_role_assignments assignment where assignment.role_id=p_profile_id
          and app_private.access_scope_rank(assignment.scope_kind)>app_private.access_scope_rank(replacement.max_scope_kind))) then
      raise check_violation using message='compatible active replacement required';end if;
    update public.institution_role_assignments set role_id=p_replacement_profile_id,version=version+1,updated_at=now()
      where role_id=p_profile_id;delete from public.institution_roles where id=p_profile_id;
  else raise invalid_parameter_value using message='unsupported profile domain';end if;
  result:=jsonb_build_object('domain',p_domain,'deleted_profile_id',p_profile_id,
    'replacement_profile_id',p_replacement_profile_id,'reassigned_count',link_count,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,before_json,after_json)
  values(actor,'aal2','membership_changed',p_domain||'_access_profile',p_profile_id,'success',p_reason,before_data,result);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'delete_and_reassign',payload,result);return result;
end $$;

-- app_private.superadmin_access_profile_duplicate [ACCESS_PROFILE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."superadmin_access_profile_duplicate"("p_request_id" "uuid", "p_draft" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare source_id uuid:=nullif(p_draft->>'source_profile_id','')::uuid;domain text;actor uuid;replay jsonb;
  source jsonb;capabilities jsonb;profile jsonb;result jsonb;expected_version bigint:=nullif(p_draft->>'expected_version','')::bigint;
begin
  if p_draft ? 'source_model_id' then
    return app_private.superadmin_access_profile_create_from_model(p_request_id,
      (p_draft-'source_model_id')||jsonb_build_object('model_id',p_draft->>'source_model_id'));
  end if;
  select case when exists(select 1 from public.platform_roles where id=source_id) then 'platform'
    when exists(select 1 from public.institution_roles where id=source_id) then 'institution' end into domain;
  actor:=app_private.access_profile_require_mutation(domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'duplicate',p_draft);if replay is not null then return replay;end if;
  source:=app_private.access_profile_detail_v2(domain,source_id);
  if expected_version is null or (source->>'version')::bigint<>expected_version then
    raise exception using errcode='PT409', message='stale source profile version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
  perform app_private.assert_access_profile_assignment_delegable(domain,source_id);
  if domain='platform' then
    select coalesce(jsonb_agg(jsonb_build_object('code',permission_record.code,'effect',grant_record.effect::text)),'[]') into capabilities
    from public.platform_role_permissions grant_record join public.platform_permissions permission_record on permission_record.id=grant_record.permission_id
    where grant_record.role_id=source_id and grant_record.status='active' and grant_record.revoked_at is null;
  else
    select coalesce(jsonb_agg(jsonb_build_object('code',permission_record.code,'effect',grant_record.effect::text)),'[]') into capabilities
    from public.institution_role_permissions grant_record join public.institution_permissions permission_record on permission_record.id=grant_record.permission_id
    where grant_record.role_id=source_id and grant_record.status='active' and grant_record.revoked_at is null;
  end if;
  profile:=app_private.access_profile_create_internal(actor,jsonb_build_object('domain',domain,
    'name',coalesce(nullif(btrim(p_draft->>'name'),''),source->>'name'||' (cópia)'),
    'description',coalesce(p_draft->>'description',source->>'description'),'status','inactive',
    'max_scope_kind',source->>'max_scope_kind','capabilities',capabilities));
  result:=jsonb_build_object('profile',profile,'profile_id',profile->>'id','domain',domain,
    'version',(profile->>'version')::bigint,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,before_json,after_json)
  values(actor,'aal2','permission_changed',domain||'_access_profile',(profile->>'id')::uuid,'success',
    coalesce(nullif(btrim(p_draft->>'reason'),''),'Duplicação de perfil.'),source,profile);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'duplicate',p_draft,result);return result;
end $$;

-- app_private.superadmin_access_profile_import_confirm [ACCESS_PROFILE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."superadmin_access_profile_import_confirm"("p_request_id" "uuid", "p_job_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid:=app_private.current_person_id();job public.import_jobs%rowtype;row_record record;
  created_count int:=0;profile jsonb;result jsonb;payload jsonb:=jsonb_build_object('job_id',p_job_id,'version',p_expected_version);replay jsonb;
begin
  if actor is null or not app_private.has_mfa_aal2() then raise insufficient_privilege using message='MFA AAL2 required';end if;
  replay:=app_private.access_profile_replay(p_request_id,actor,'import_confirm',payload);if replay is not null then return replay;end if;
  select * into job from public.import_jobs where id=p_job_id for update;
  if job.id is null or job.target_domain<>'access_profiles_import' or job.created_by<>actor or job.summary->>'phase'<>'preview_ready' then
    raise no_data_found using message='import job unavailable';end if;
  if job.version<>p_expected_version then raise exception using errcode='PT409', message='stale import version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
  if exists(select 1 from public.import_errors where import_job_id=job.id) then raise check_violation using message='import validation errors must be resolved';end if;
  for row_record in select * from public.import_rows where import_job_id=job.id and error_code is null order by row_number loop
    if row_record.payload_json->>'domain'='platform' and not app_private.has_platform_permission('platform.roles.import') then
      raise insufficient_privilege using message='platform profile import permission required';
    elsif row_record.payload_json->>'domain'='institution' and not app_private.has_platform_permission('institution.roles.import') then
      raise insufficient_privilege using message='institution profile import permission required';end if;
    perform app_private.access_profile_require_mutation(row_record.payload_json->>'domain');
    profile:=app_private.access_profile_create_internal(actor,row_record.payload_json||jsonb_build_object('status','inactive'));
    created_count:=created_count+1;
  end loop;
  insert into public.import_results(import_job_id,created_count,completed_at) values(job.id,created_count,now())
    on conflict(import_job_id) do update set created_count=excluded.created_count,completed_at=excluded.completed_at;
  update public.import_jobs set processing_state='SUCESSO',status='active',finished_at=now(),version=version+1,updated_at=now(),
    summary=summary||jsonb_build_object('phase','completed','created_count',created_count) where id=job.id returning * into job;
  result:=jsonb_build_object('job_id',job.id,'status',job.processing_state,'version',job.version,
    'created_count',created_count,'format','csv','template_version','access-profiles-v1','replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,after_json)
  values(actor,'aal2','permission_changed','access_profile_import',job.id,'success','Confirmação de importação access-profiles-v1.',result);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'import_confirm',payload,result);return result;
end $$;

-- app_private.superadmin_access_profile_model_delete [ACCESS_PROFILE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."superadmin_access_profile_model_delete"("p_request_id" "uuid", "p_model_id" "uuid", "p_expected_version" bigint, "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  model_record public.access_profile_templates%rowtype;
  actor uuid;
  payload jsonb:=jsonb_build_object('model_id',p_model_id,'expected_version',p_expected_version,'reason',p_reason);
  replay jsonb;
  before_data jsonb;
  after_data jsonb;
  result jsonb;
begin
  select * into model_record from public.access_profile_templates model
  where model.id=p_model_id for update;
  if model_record.id is null then raise no_data_found using message='access profile model not found'; end if;
  actor:=app_private.access_profile_require_model_action(model_record.domain,'delete');
  replay:=app_private.access_profile_model_replay_internal(
    p_request_id,actor,'model_delete',payload);
  if replay is not null then return replay; end if;
  if model_record.is_system then raise insufficient_privilege using message='system access model is protected'; end if;
  if model_record.version is distinct from p_expected_version then
    raise exception using errcode='PT409', message='stale access model version', detail='ACCESS_PROFILE_STALE_VERSION';
  end if;
  if nullif(btrim(p_reason),'') is null or char_length(p_reason)>500 then
    raise invalid_parameter_value using message='audit reason required';
  end if;
  before_data:=app_private.access_profile_model_detail(model_record.id,false);
  update public.access_profile_templates set status='inactive',version=version+1,updated_at=now()
  where id=model_record.id;
  after_data:=app_private.access_profile_model_detail(model_record.id,false);
  result:=jsonb_build_object('model_id',model_record.id,'status','inactive',
    'version',(after_data->>'version')::bigint,'replayed',false);
  perform app_private.access_profile_model_audit_success(
    actor,model_record.domain,'delete',model_record.id);
  perform app_private.access_profile_model_store_receipt_internal(
    p_request_id,actor,'model_delete',payload,result);
  return result;
end
$$;

-- app_private.superadmin_access_profile_model_update [ACCESS_PROFILE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."superadmin_access_profile_model_update"("p_request_id" "uuid", "p_draft" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  model_record public.access_profile_templates%rowtype;
  actor uuid;
  replay jsonb;
  before_data jsonb;
  after_data jsonb;
  result jsonb;
  capability_item jsonb;
  capabilities jsonb:=coalesce(p_draft->'capabilities','[]'::jsonb);
  expected_version bigint:=nullif(p_draft->>'expected_version','')::bigint;
begin
  select * into model_record from public.access_profile_templates model
  where model.id=nullif(p_draft->>'id','')::uuid for update;
  if model_record.id is null then raise no_data_found using message='access profile model not found'; end if;
  actor:=app_private.access_profile_require_model_action(model_record.domain,'update');
  if nullif(btrim(p_draft->>'reason'),'') is null
    or char_length(p_draft->>'reason')>500
    or octet_length(pg_catalog.convert_to(p_draft::text,'UTF8'))>65536 then
    raise invalid_parameter_value using message='invalid access model update';
  end if;
  replay:=app_private.access_profile_model_replay_internal(
    p_request_id,actor,'model_update',p_draft);
  if replay is not null then return replay; end if;
  if model_record.is_system then raise insufficient_privilege using message='system access model is protected'; end if;
  if model_record.version is distinct from expected_version then
    raise exception using errcode='PT409', message='stale access model version', detail='ACCESS_PROFILE_STALE_VERSION';
  end if;
  if char_length(btrim(coalesce(p_draft->>'name',''))) not between 2 and 120
    or coalesce(nullif(p_draft->>'status',''),model_record.status::text) not in ('active','inactive')
    or jsonb_typeof(capabilities)<>'array' or jsonb_array_length(capabilities)>500 then
    raise invalid_parameter_value using message='invalid access model draft';
  end if;
  if jsonb_array_length(capabilities)<>(
    select count(distinct item.value->>'code')
    from jsonb_array_elements(capabilities) item
  ) then
    raise invalid_parameter_value using message='duplicate access model capability';
  end if;
  for capability_item in select value from jsonb_array_elements(capabilities) loop
    if capability_item->>'effect' not in ('allow','deny')
      or (model_record.domain='platform' and not exists(select 1 from public.platform_permissions p where p.code=capability_item->>'code' and p.status='active'))
      or (model_record.domain='institution' and not exists(select 1 from public.institution_permissions p where p.code=capability_item->>'code' and p.status='active'))
      or (model_record.domain='principal' and not exists(select 1 from public.guardian_permission_capabilities p where p.code=capability_item->>'code' and p.status='active')) then
      raise invalid_parameter_value using message='unknown or invalid access model capability';
    end if;
    if capability_item->>'effect'='allow'
      and not app_private.access_profile_model_internal_can_delegate(
        actor,model_record.domain,capability_item->>'code') then
      raise insufficient_privilege using message='cannot delegate capability operator does not hold';
    end if;
  end loop;
  before_data:=app_private.access_profile_model_detail(model_record.id,false);
  update public.access_profile_templates set
    name=btrim(p_draft->>'name'),
    description=nullif(btrim(p_draft->>'description'),''),
    max_scope_kind=coalesce(nullif(p_draft->>'max_scope_kind',''),max_scope_kind),
    status=coalesce(nullif(p_draft->>'status',''),status::text)::public.record_status,
    version=version+1,
    updated_at=now()
  where id=model_record.id;
  delete from public.access_profile_template_platform_permissions where template_id=model_record.id;
  delete from public.access_profile_template_institution_permissions where template_id=model_record.id;
  delete from public.access_profile_template_principal_capabilities where template_id=model_record.id;
  if model_record.domain='platform' then
    insert into public.access_profile_template_platform_permissions(template_id,permission_id,effect)
    select model_record.id,p.id,(item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.platform_permissions p on p.code=item.value->>'code';
  elsif model_record.domain='institution' then
    insert into public.access_profile_template_institution_permissions(template_id,permission_id,effect)
    select model_record.id,p.id,(item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.institution_permissions p on p.code=item.value->>'code';
  else
    insert into public.access_profile_template_principal_capabilities(template_id,capability_id,effect)
    select model_record.id,p.id,(item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.guardian_permission_capabilities p on p.code=item.value->>'code';
  end if;
  after_data:=app_private.access_profile_model_detail(model_record.id,false);
  result:=jsonb_build_object('model',after_data,'model_id',model_record.id,
    'version',(after_data->>'version')::bigint,'replayed',false);
  perform app_private.access_profile_model_audit_success(
    actor,model_record.domain,'update',model_record.id);
  perform app_private.access_profile_model_store_receipt_internal(
    p_request_id,actor,'model_update',p_draft,result);
  return result;
end
$$;

-- app_private.superadmin_access_profile_update [ACCESS_PROFILE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."superadmin_access_profile_update"("p_request_id" "uuid", "p_draft" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare domain text:=p_draft->>'domain';profile_id uuid:=nullif(p_draft->>'id','')::uuid;actor uuid;
  replay jsonb;before_data jsonb;profile jsonb;result jsonb;capability jsonb;
  expected_version bigint:=nullif(p_draft->>'expected_version','')::bigint;
begin
  actor:=app_private.access_profile_require_mutation(domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'update',p_draft);if replay is not null then return replay;end if;
  perform pg_advisory_xact_lock(hashtextextended('access-profile-full-authority',0));
  before_data:=app_private.access_profile_detail_v2(domain,profile_id);
  -- P31: modelos do sistema de Admin sao editados so pela plataforma (quem passa
  -- por access_profile_require_mutation('institution')); os de plataforma seguem protegidos.
  if (before_data->>'is_system')::boolean and domain<>'institution' then raise insufficient_privilege using message='system profile is protected';end if;
  if (before_data->>'version')::bigint is distinct from expected_version then raise exception using errcode='PT409', message='stale profile version', detail='ACCESS_PROFILE_STALE_VERSION';end if;
  if jsonb_typeof(coalesce(p_draft->'capabilities','[]'))<>'array' then raise invalid_parameter_value using message='invalid capabilities';end if;
  if domain='platform' then
    for capability in select value from jsonb_array_elements(coalesce(p_draft->'capabilities','[]')) loop
      if capability->>'effect' not in('allow','deny') or not exists(select 1 from public.platform_permissions where code=capability->>'code' and status='active') then
        raise invalid_parameter_value using message='unknown or invalid capability';end if;
      if capability->>'effect'='allow' and not app_private.has_platform_permission(capability->>'code') then
        raise insufficient_privilege using message='cannot delegate capability operator does not hold';end if;
    end loop;
    update public.platform_roles set name=btrim(p_draft->>'name'),description=nullif(btrim(p_draft->>'description'),''),
      status=coalesce(p_draft->>'status',status::text)::public.record_status,
      max_scope_kind=coalesce(p_draft->>'max_scope_kind',max_scope_kind),version=version+1,updated_at=now() where id=profile_id;
    update public.platform_role_permissions set status='inactive',revoked_at=now() where role_id=profile_id and status='active';
    insert into public.platform_role_permissions(role_id,permission_id,effect,conditions_json,granted_by,status)
    select profile_id,permission_record.id,(item.value->>'effect')::public.permission_effect,'{}',actor,'active'
    from jsonb_array_elements(coalesce(p_draft->'capabilities','[]')) item
    join public.platform_permissions permission_record on permission_record.code=item.value->>'code'
    on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null,granted_by=actor;
    perform app_private.assert_full_authority_remains();
  elsif domain='institution' then
    for capability in select value from jsonb_array_elements(coalesce(p_draft->'capabilities','[]')) loop
      if capability->>'effect' not in('allow','deny') or not exists(select 1 from public.institution_permissions where code=capability->>'code' and status='active') then
        raise invalid_parameter_value using message='unknown or invalid capability';end if;
    end loop;
    update public.institution_roles set name=btrim(p_draft->>'name'),description=nullif(btrim(p_draft->>'description'),''),
      status=coalesce(p_draft->>'status',status::text)::public.record_status,
      max_scope_kind=coalesce(p_draft->>'max_scope_kind',max_scope_kind),version=version+1,updated_at=now() where id=profile_id;
    update public.institution_role_permissions set status='inactive',revoked_at=now() where role_id=profile_id and status='active';
    insert into public.institution_role_permissions(role_id,permission_id,effect,conditions_json,granted_by,status)
    select profile_id,permission_record.id,(item.value->>'effect')::public.permission_effect,'{}',actor,'active'
    from jsonb_array_elements(coalesce(p_draft->'capabilities','[]')) item
    join public.institution_permissions permission_record on permission_record.code=item.value->>'code'
    on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null,granted_by=actor;
  else raise invalid_parameter_value using message='unsupported profile domain';end if;
  profile:=app_private.access_profile_detail_v2(domain,profile_id);
  result:=jsonb_build_object('profile',profile,'profile_id',profile_id,'domain',domain,
    'version',(profile->>'version')::bigint,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,before_json,after_json)
  values(actor,'aal2','permission_changed',domain||'_access_profile',profile_id,'success',
    coalesce(nullif(btrim(p_draft->>'reason'),''),'Atualização de perfil.'),before_data,profile);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'update',p_draft,result);return result;
end $$;

-- app_private.superadmin_form_request_xlsx_v2 [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."superadmin_form_request_xlsx_v2"("p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare ctx app_private.superadmin_internal_context; initial_ctx app_private.superadmin_internal_context;
  form_row public.forms; job public.form_file_jobs; target_form uuid; payload_hash text;
  captured_count bigint; captured_schema jsonb; invalid_capture boolean;
  error_code text; correlation uuid:=gen_random_uuid();
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.responses.export');
    initial_ctx:=ctx;
    if current_setting('transaction_isolation')<>'read committed' or p_request_id is null
      or p_expected_version is null or p_expected_version<0
      or jsonb_typeof(p_payload) is distinct from 'object' then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    if jsonb_typeof(p_payload->'form_id') is distinct from 'string'
      or not (p_payload->>'form_id' ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
      or exists(select 1 from jsonb_object_keys(p_payload) k where k<>'form_id') then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    if ctx.aal is null or ctx.aal not in ('aal1','aal2') or ctx.scope_kind is null
      or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and ctx.scope_institution_id is null) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    target_form:=(p_payload->>'form_id')::uuid;
    payload_hash:=encode(extensions.digest(convert_to(jsonb_build_object('form_id',target_form,
      'expected_version',p_expected_version)::text,'UTF8'),'sha256'),'hex');
    perform pg_advisory_xact_lock(hashtextextended(ctx.internal_identity_id::text||':'||p_request_id::text,0));
    select f.* into form_row from public.forms f join public.institutions i on i.id=f.institution_id
      where f.id=target_form and i.deleted_at is null
        and (ctx.scope_kind='platform' or f.institution_id=ctx.scope_institution_id) for share of f,i;
    if form_row.id is null then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    select * into job from public.form_file_jobs where requested_by_internal_identity_id=ctx.internal_identity_id
      and request_id=p_request_id for update;
    if job.id is not null then
      if job.request_payload_sha256 is distinct from payload_hash or job.form_id is distinct from form_row.id
        or job.institution_id is distinct from form_row.institution_id then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
    else
      if form_row.management_version<>p_expected_version then
        raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE';
      end if;
      insert into public.form_file_jobs(form_id,institution_id,request_id,export_kind,artifact_provider,
        requested_by_internal_identity_id,requested_auth_link_id,requested_membership_id,requested_auth_session_id,
        requested_scope_kind,requested_scope_institution_id,requested_management_version,request_payload_sha256,
        snapshot_format_version,snapshot_row_count,snapshot_ready)
      values(form_row.id,form_row.institution_id,p_request_id,'xlsx','r2',ctx.internal_identity_id,
        ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,ctx.scope_kind,ctx.scope_institution_id,
        p_expected_version,payload_hash,2,0,false) returning * into job;
      -- All source rows, the complete version graph and typed values share one
      -- MVCC statement snapshot. Invalid incoming/outgoing links reject the
      -- entire request; inner joins must never silently omit damaged history.
      with captured as materialized (
        select r.*,case when r.identity_mode='anonymous' then gen_random_uuid() else r.id end export_id
        from public.form_responses r where r.form_id=form_row.id and r.status='submitted'
      ), versions as materialized (
        select v.* from public.form_versions v where v.id in(select form_version_id from captured)
      ), sections as materialized (
        select s.* from public.form_sections s where s.form_version_id in(select id from versions)
      ), items as materialized (
        select i.* from public.form_items i where i.form_version_id in(select id from versions)
      ), options as materialized (
        select o.* from public.form_question_options o where o.form_version_id in(select id from versions)
      ), conditions as materialized (
        select c.* from public.form_question_conditions c where c.form_version_id in(select id from versions)
      ), graph as (
        select jsonb_build_object('formId',form_row.id,'formTitle',form_row.title,'versions',
          coalesce((select jsonb_agg(jsonb_build_object(
            'versionId',v.id,'versionNumber',v.version_number,'state',v.state,
            'sections',coalesce((select jsonb_agg(jsonb_build_object(
              'sectionId',s.id,'title',s.title,'description',s.description,'position',s.position,
              'items',coalesce((select jsonb_agg(jsonb_build_object(
                'itemId',i.id,'kind',i.kind,'label',i.label,'helpText',i.help_text,
                'position',i.position,'required',i.is_required,'config',i.config_jsonb,
                'options',coalesce((select jsonb_agg(jsonb_build_object(
                  'optionId',o.id,'label',o.label,'position',o.position) order by o.position,o.id)
                  from options o where o.item_id=i.id),'[]'::jsonb)) order by i.position,i.id)
                from items i where i.section_id=s.id),'[]'::jsonb)) order by s.position,s.id)
              from sections s where s.form_version_id=v.id),'[]'::jsonb),
            'conditions',coalesce((select jsonb_agg(jsonb_build_object(
              'sourceItemId',c.source_item_id,'targetItemId',c.target_item_id,'kind',c.condition_kind,
              'expectedYesNo',c.expected_yes_no,'sourceOptionId',c.source_option_id)
              order by c.target_item_id,c.source_item_id,c.id)
              from conditions c where c.form_version_id=v.id),'[]'::jsonb))
            order by v.version_number,v.id) from versions v),'[]'::jsonb)) body
      ), invalid as (
        select exists(select 1 from captured r
          left join public.form_occurrences o on o.id=r.occurrence_id and o.form_id=r.form_id
            and o.institution_id=r.institution_id and o.form_version_id=r.form_version_id
          left join public.form_applications app on app.id=o.application_id
            and app.form_id=r.form_id and app.institution_id=r.institution_id
          left join versions v on v.id=r.form_version_id and v.form_id=r.form_id
          where r.institution_id<>form_row.institution_id or r.identity_mode<>form_row.identity_mode
            or o.id is null or app.id is null or v.id is null)
        or exists(select 1 from public.form_items i join public.form_sections s on s.id=i.section_id
          where (i.form_version_id in(select id from versions) or s.form_version_id in(select id from versions))
            and i.form_version_id<>s.form_version_id)
        or exists(select 1 from public.form_question_options o join public.form_items i on i.id=o.item_id
          where (o.form_version_id in(select id from versions) or i.form_version_id in(select id from versions))
            and (o.form_version_id<>i.form_version_id or i.kind not in ('single_choice','multiple_choice','location')))
        or exists(select 1 from public.form_question_conditions c
          join public.form_items target on target.id=c.target_item_id
          join public.form_items source on source.id=c.source_item_id
          left join public.form_question_options o on o.id=c.source_option_id
          where (c.form_version_id in(select id from versions) or target.form_version_id in(select id from versions)
            or source.form_version_id in(select id from versions))
            and (c.form_version_id<>target.form_version_id or c.form_version_id<>source.form_version_id
              or (c.condition_kind='yes_no' and source.kind<>'yes_no')
              or (c.condition_kind='choice' and (source.kind not in ('single_choice','multiple_choice')
                or o.id is null or o.form_version_id<>c.form_version_id or o.item_id<>source.id))))
        or exists(select 1 from public.form_answers a join captured r on r.id=a.response_id
          left join items i on i.id=a.item_id and i.form_version_id=r.form_version_id
          left join sections s on s.id=i.section_id and s.form_version_id=r.form_version_id
          where a.form_version_id<>r.form_version_id or i.id is null or s.id is null or a.answer_kind<>i.kind
            or case a.answer_kind
              when 'short_text' then a.text_value is null
              when 'integer' then a.integer_value is null
              when 'decimal' then a.decimal_value is null
              when 'money' then a.money_minor_units is null or jsonb_typeof(i.config_jsonb->'currency') is distinct from 'string'
              when 'date' then a.date_value is null
              when 'yes_no' then a.yes_no_value is null
              when 'scale' then a.scale_value is null else false end)
        or exists(select 1 from public.form_answer_options ao
          join public.form_answers a on a.id=ao.answer_id join captured r on r.id=a.response_id
          left join options o on o.id=ao.option_id and o.item_id=a.item_id and o.form_version_id=r.form_version_id
          where o.id is null or a.answer_kind not in ('single_choice','multiple_choice','location'))
        or exists(select 1 from public.form_answer_assets aa
          join public.form_answers a on a.id=aa.answer_id join captured r on r.id=a.response_id
          left join public.form_assets asset on asset.id=aa.asset_id and asset.item_id=a.item_id
            and asset.occurrence_id=r.occurrence_id and asset.institution_id=r.institution_id
          where asset.id is null or asset.state<>'finalized' or a.answer_kind not in ('photo','gallery')
            or (r.identity_mode='identified' and asset.prepared_by_person_id is distinct from r.respondent_person_id)
            or (r.identity_mode='anonymous' and asset.prepared_by_person_id is not null)) bad
      ), inserted as (
        insert into app_private.form_xlsx_snapshot_rows(file_job_id,sequence_number,response_id,submission_jsonb)
        select job.id,row_number() over(order by r.export_id),r.id,jsonb_build_object(
          'responseId',r.export_id,'occurrenceId',r.occurrence_id,'versionId',r.form_version_id,
          'metadata',jsonb_build_object('form_id',r.form_id,'identity_mode',r.identity_mode)
            ||case when r.identity_mode='identified' then jsonb_build_object(
              'respondent',(select display_name from public.people where id=r.respondent_person_id),
              'submitted_at',r.submitted_at) else '{}'::jsonb end,
          'answers',coalesce((select jsonb_agg(jsonb_build_object('itemId',i.id,'values',case
            when a.answer_kind in ('single_choice','multiple_choice','location') then coalesce((
              select jsonb_agg(jsonb_build_object('kind','choice','optionId',ao.option_id) order by ao.position,ao.option_id)
              from public.form_answer_options ao where ao.answer_id=a.id),'[]'::jsonb)
            when a.answer_kind in ('photo','gallery') then coalesce((
              select jsonb_agg(jsonb_build_object('kind','media','assetId',aa.asset_id) order by aa.position,aa.asset_id)
              from public.form_answer_assets aa where aa.answer_id=a.id),'[]'::jsonb)
            else jsonb_build_array(case a.answer_kind
              when 'short_text' then jsonb_build_object('kind','text','value',a.text_value)
              when 'integer' then jsonb_build_object('kind','integer','value',a.integer_value::text)
              when 'decimal' then jsonb_build_object('kind','decimal','value',a.decimal_value::text)
              when 'money' then jsonb_build_object('kind','money','minorUnits',a.money_minor_units::text,'currency',i.config_jsonb->>'currency')
              when 'date' then jsonb_build_object('kind','date','value',a.date_value::text)
              when 'yes_no' then jsonb_build_object('kind','boolean','value',a.yes_no_value)
              when 'scale' then jsonb_build_object('kind','integer','value',a.scale_value::text) end) end)
            order by s.position,i.position,i.id)
            from public.form_answers a join items i on i.id=a.item_id
            join sections s on s.id=i.section_id where a.response_id=r.id),'[]'::jsonb))
          from captured r where not (select bad from invalid)
          returning 1
      ) select graph.body,invalid.bad,(select count(*) from inserted)
        into captured_schema,invalid_capture,captured_count from graph cross join invalid;
      if invalid_capture then raise check_violation using detail='SAI_UNAVAILABLE'; end if;
      update public.form_file_jobs set snapshot_ready=true,snapshot_row_count=captured_count,
        snapshot_schema=captured_schema,
        snapshot_schema_sha256=encode(extensions.digest(convert_to(captured_schema::text,'UTF8'),'sha256'),'hex')
        where id=job.id returning * into job;

      insert into app_private.form_worker_jobs(job_kind,aggregate_id,payload_jsonb)
        values('export_xlsx_r2_v1',job.id,jsonb_build_object('file_job_id',job.id));
    end if;
    -- Any wait or capture may span a revocation. Refresh before committing work.
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.responses.export');
    if row(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,ctx.scope_kind,ctx.scope_institution_id)
      is distinct from row(initial_ctx.internal_identity_id,initial_ctx.internal_auth_link_id,initial_ctx.internal_membership_id,
        initial_ctx.session_id,initial_ctx.scope_kind,initial_ctx.scope_institution_id)
      or not exists(select 1 from auth.sessions s where s.id=ctx.session_id and s.user_id=ctx.auth_user_id
        and (s.not_after is null or s.not_after>clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
      ctx.session_id,'forms.responses.export',ctx.aal,'superadmin.forms.export.request','success',null,
      correlation,job.institution_id,'form_file_job',job.id);
  exception when others then
    get stacked diagnostics error_code=pg_exception_detail;
    error_code:=app_private.superadmin_internal_error_envelope(error_code,correlation)#>>'{error,code}';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified('forms.responses.export',
      'superadmin.forms.export.request',error_code,correlation);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  return jsonb_build_object('ok',true,'error',null,'data',jsonb_build_object('id',job.id,'status',job.state,
    'progress',job.progress,'download_path',null,'error_code',job.error_code,'expires_at',job.expires_at,
    'download_available',job.state='succeeded' and job.expires_at>clock_timestamp()));
end;
$_$;

-- app_private.superadmin_forms_save_draft_v2 [FORMS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 1.
create or replace function "app_private"."superadmin_forms_save_draft_v2"("p_request_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  ctx app_private.superadmin_internal_context;
  initial_ctx app_private.superadmin_internal_context;
  f public.forms;
  receipt app_private.superadmin_internal_form_draft_receipts;
  correlation uuid:=pg_catalog.gen_random_uuid();
  error_code text;
  target_id uuid;
  target_institution uuid;
  working_id uuid;
  request_hash bytea;
  result jsonb;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.manage');
    if ctx.aal is null or ctx.aal not in ('aal1','aal2') or ctx.scope_kind is null or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and ctx.scope_institution_id is null) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    initial_ctx:=ctx;
    if pg_catalog.current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_request_id is null or p_expected_version is null or p_expected_version<0 then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    perform app_private.superadmin_form_validate_draft_payload_v2(p_payload);
    target_institution:=(p_payload->>'institution_id')::uuid;
    if (ctx.scope_kind='institution' and target_institution is distinct from ctx.scope_institution_id)
      or not exists(select 1 from public.institutions i where i.id=target_institution and i.deleted_at is null) then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    request_hash:=extensions.digest(pg_catalog.convert_to(p_expected_version::text||':'||p_payload::text,'UTF8'),'sha256');
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,6404));
    -- The request lock can wait before even the private receipt lookup.
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.manage');
    if row(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.auth_user_id,ctx.session_id,
           ctx.scope_kind,ctx.scope_institution_id)
       is distinct from row(initial_ctx.internal_identity_id,initial_ctx.internal_auth_link_id,initial_ctx.internal_membership_id,
           initial_ctx.auth_user_id,initial_ctx.session_id,initial_ctx.scope_kind,initial_ctx.scope_institution_id)
      or ctx.aal is null or ctx.aal not in ('aal1','aal2') or ctx.scope_kind is null or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and (ctx.scope_institution_id is null or target_institution is distinct from ctx.scope_institution_id)) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    if not exists(select 1 from auth.sessions s where s.id=initial_ctx.session_id and s.user_id=initial_ctx.auth_user_id
      and (s.not_after is null or s.not_after>pg_catalog.clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
    select * into receipt from app_private.superadmin_internal_form_draft_receipts where request_id=p_request_id;
    if receipt.request_id is not null then
      if receipt.actor_internal_identity_id is distinct from ctx.internal_identity_id
        or receipt.institution_id is distinct from target_institution
        or receipt.expected_version is distinct from p_expected_version
        or receipt.request_hash is distinct from request_hash then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
      target_id:=receipt.form_id;
    else
      target_id:=coalesce((p_payload->>'id')::uuid,pg_catalog.gen_random_uuid());
    end if;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(target_id::text,0));
    select * into f from public.forms where id=target_id for update;
    perform 1 from public.institutions i where i.id=target_institution and i.deleted_at is null for share;
    if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    -- Reauthorize after request, form-row and institution waits, before exposing
    -- a receipt snapshot or writing. Never migrate the in-flight actor/context.
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.manage');
    if row(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.auth_user_id,ctx.session_id,
           ctx.scope_kind,ctx.scope_institution_id)
       is distinct from row(initial_ctx.internal_identity_id,initial_ctx.internal_auth_link_id,initial_ctx.internal_membership_id,
           initial_ctx.auth_user_id,initial_ctx.session_id,initial_ctx.scope_kind,initial_ctx.scope_institution_id)
      or ctx.aal is null or ctx.aal not in ('aal1','aal2') or ctx.scope_kind is null or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and (ctx.scope_institution_id is null or target_institution is distinct from ctx.scope_institution_id)) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    if not exists(select 1 from auth.sessions s where s.id=initial_ctx.session_id and s.user_id=initial_ctx.auth_user_id
      and (s.not_after is null or s.not_after>pg_catalog.clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
    if f.id is not null then
      if f.institution_id is distinct from target_institution or f.created_by_internal_identity_id is null or f.status<>'draft'
        or f.first_published_at is not null or f.published_version_id is not null
        or exists(select 1 from public.form_versions v where v.form_id=f.id and (v.state<>'working' or v.published_at is not null))
        or exists(select 1 from public.form_applications a where a.form_id=f.id)
        or exists(select 1 from public.form_occurrences o where o.form_id=f.id)
        or exists(select 1 from public.form_file_jobs j where j.form_id=f.id) then
        raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
      end if;
    elsif receipt.request_id is not null then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    if receipt.request_id is not null then
      result:=receipt.result_jsonb;
    else
      if f.id is null then
        if p_expected_version<>0 then raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if;
        insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,description,
          created_by_internal_identity_id,updated_by_internal_identity_id)
        values(target_id,target_institution,p_payload->>'kind',p_payload->>'identity_mode',p_payload->>'response_unit',
          btrim(p_payload->>'title'),nullif(btrim(p_payload->>'description'),''),ctx.internal_identity_id,ctx.internal_identity_id)
        returning * into f;
        insert into public.form_versions(form_id,version_number,created_by_internal_identity_id)
        values(f.id,1,ctx.internal_identity_id) returning id into working_id;
        update public.forms set working_version_id=working_id where id=f.id;
      else
        if f.management_version is distinct from p_expected_version then raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if;
        working_id:=f.working_version_id;
        if working_id is null or not exists(select 1 from public.form_versions v where v.id=working_id and v.form_id=f.id and v.state='working') then
          raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
        end if;
        update public.forms set kind=p_payload->>'kind',identity_mode=p_payload->>'identity_mode',response_unit=p_payload->>'response_unit',
          title=btrim(p_payload->>'title'),description=nullif(btrim(p_payload->>'description'),''),management_version=management_version+1,
          updated_by_person_id=null,updated_by_internal_identity_id=ctx.internal_identity_id,updated_at=pg_catalog.now()
        where id=f.id;
      end if;
      perform app_private.superadmin_form_replace_draft_definition_v2(working_id,p_payload->'sections');
      result:=app_private.form_definition_projection(f.id);
      insert into app_private.superadmin_internal_form_draft_receipts(request_id,actor_internal_identity_id,form_id,institution_id,expected_version,request_hash,result_jsonb)
      values(p_request_id,ctx.internal_identity_id,f.id,target_institution,p_expected_version,request_hash,result);
    end if;
  exception
    when invalid_parameter_value or invalid_text_representation or numeric_value_out_of_range or check_violation or not_null_violation or foreign_key_violation or unique_violation then
      error_code:='SAI_INVALID_ARGUMENT';
    when serialization_failure or sqlstate 'PT409' then error_code:='SAI_CONCURRENT_CHANGE';
    when others then
      get stacked diagnostics error_code=pg_exception_detail;
      error_code:=app_private.superadmin_internal_error_envelope(error_code,correlation)#>>'{error,code}';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified('forms.manage','superadmin.forms.draft.save',error_code,correlation);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  -- Intentionally outside the inner exception block: audit failure rolls back
  -- business changes AND receipt rather than returning an unaudited denial.
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'forms.manage',ctx.aal,'superadmin.forms.draft.save','success',null,correlation,target_institution);
  return pg_catalog.jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

-- app_private.superadmin_group_save [GROUP]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."superadmin_group_save"("p_request_id" "uuid", "p_group_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  actor_person_id uuid;
  request_hash bytea;
  prior app_private.group_management_command_receipts%rowtype;
  unit_record public.units%rowtype;
  group_record public.groups%rowtype;
  payload_institution_id uuid;
  payload_unit_id uuid;
  local_person jsonb;
  activity_value text;
  invite_value jsonb;
  role_record_id uuid;
  target_membership_id uuid;
  target_person_id uuid;
  target_invitation_id uuid;
  enqueue_invite boolean;
  result jsonb;
begin
  if p_request_id is null or p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise invalid_parameter_value using message = 'request_id and payload are required';
  end if;
  if (select auth.uid()) is null then raise insufficient_privilege using message = 'authentication required'; end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then raise insufficient_privilege using message = 'active person required'; end if;
  if not app_private.has_platform_permission('groups.manage') then
    raise insufficient_privilege using message = 'groups.manage required';
  end if;
  if not app_private.has_mfa_aal2() then raise insufficient_privilege using message = 'MFA AAL2 required'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  request_hash := app_private.group_management_request_hash(p_payload);
  select receipt.* into prior from app_private.group_management_command_receipts receipt where receipt.request_id = p_request_id;
  if found then
    if prior.actor_person_id <> actor_person_id or prior.request_hash <> request_hash
       or (p_group_id is not null and prior.group_id is distinct from p_group_id) then
      raise invalid_parameter_value using message = 'request_id already used by another command';
    end if;
    result := app_private.group_management_payload(prior.group_id);
    if (result ->> 'management_version')::bigint <> prior.result_management_version then
      raise exception using errcode='PT409', message = 'receipt result is no longer current', detail='GROUP_STALE_VERSION';
    end if;
    return result;
  end if;

  if p_payload - array[
    'institution_id','unit_id','name','group_type','group_type_other_text','status',
    'inherit_appearance','inherit_access','inherit_activities','branding','local_people',
    'activity_ids','invites','type_request','handle'
  ] <> '{}'::jsonb then
    raise invalid_parameter_value using message = 'unknown group payload key';
  end if;
  payload_unit_id := nullif(p_payload ->> 'unit_id', '')::uuid;
  payload_institution_id := nullif(p_payload ->> 'institution_id', '')::uuid;
  select * into unit_record from public.units where id = payload_unit_id and status = 'active';
  if unit_record.id is null then raise invalid_parameter_value using message = 'unknown or inactive unit'; end if;
  if payload_institution_id is distinct from unit_record.institution_id then
    raise invalid_parameter_value using message = 'unit does not belong to institution';
  end if;
  if nullif(btrim(p_payload ->> 'name'), '') is null
     or nullif(btrim(p_payload ->> 'group_type'), '') is null then
    raise invalid_parameter_value using message = 'name and group_type are required';
  end if;

  if p_group_id is null then
    if coalesce(p_expected_version, 0) <> 0 then
      raise invalid_parameter_value using message = 'create expected_version must be zero';
    end if;
    -- Decisao 16: @ opcional na criacao; ausente -> padrao do gatilho groups_assign_handle
    if nullif(btrim(p_payload ->> 'handle'), '') is not null
       and app_private.structure_handle_in_use(app_private.structure_handle_normalize(p_payload ->> 'handle'), 'group', null) then
      raise unique_violation using message = 'handle already in use', detail = 'SAI_HANDLE_TAKEN';
    end if;
    insert into public.groups(
      institution_id, unit_id, name, group_type, group_type_other_text, status,
      inherit_appearance, inherit_access, inherit_activities, created_at, updated_at, handle
    ) values (
      unit_record.institution_id, unit_record.id, btrim(p_payload ->> 'name'),
      lower(btrim(p_payload ->> 'group_type')), nullif(btrim(p_payload ->> 'group_type_other_text'), ''),
      coalesce(p_payload ->> 'status', 'active')::public.record_status,
      coalesce((p_payload ->> 'inherit_appearance')::boolean, true),
      coalesce((p_payload ->> 'inherit_access')::boolean, true),
      coalesce((p_payload ->> 'inherit_activities')::boolean, true), now(), now(),
      nullif(app_private.structure_handle_normalize(p_payload ->> 'handle'), '')
    ) returning * into group_record;
  else
    select * into group_record from public.groups where id = p_group_id for update;
    if group_record.id is null then raise no_data_found using message = 'group not found'; end if;
    if group_record.institution_id <> unit_record.institution_id or group_record.unit_id <> unit_record.id then
      raise invalid_parameter_value using message = 'group hierarchy cannot be changed';
    end if;
    if group_record.management_version <> p_expected_version then
      raise exception using errcode='PT409', message = 'stale group version', detail='GROUP_STALE_VERSION';
    end if;
    -- a troca do @ passa por superadmin_structure_handle_set_v1 (trava de 30 dias)
    if nullif(btrim(p_payload ->> 'handle'), '') is not null
       and app_private.structure_handle_normalize(p_payload ->> 'handle') is distinct from group_record.handle then
      raise invalid_parameter_value using message = 'handle changes use superadmin_structure_handle_set_v1', detail = 'SAI_HANDLE_USE_SET';
    end if;
    update public.groups set
      name = btrim(p_payload ->> 'name'),
      group_type = lower(btrim(p_payload ->> 'group_type')),
      group_type_other_text = nullif(btrim(p_payload ->> 'group_type_other_text'), ''),
      status = coalesce(p_payload ->> 'status', status::text)::public.record_status,
      inherit_appearance = coalesce((p_payload ->> 'inherit_appearance')::boolean, inherit_appearance),
      inherit_access = coalesce((p_payload ->> 'inherit_access')::boolean, inherit_access),
      inherit_activities = coalesce((p_payload ->> 'inherit_activities')::boolean, inherit_activities),
      management_version = management_version + 1, updated_at = now()
    where id = p_group_id returning * into group_record;
  end if;

  if group_record.inherit_appearance then
    delete from public.group_branding where group_id = group_record.id;
  else
    if jsonb_typeof(p_payload -> 'branding') <> 'object' then
      raise invalid_parameter_value using message = 'local branding is required when appearance is customized';
    end if;
    insert into public.group_branding(
      group_id, accent_color, secondary_color, text_color, surface_color,
      updated_by_person_id, updated_at
    ) values (
      group_record.id, nullif(p_payload -> 'branding' ->> 'accent_color', ''),
      nullif(p_payload -> 'branding' ->> 'secondary_color', ''),
      nullif(p_payload -> 'branding' ->> 'text_color', ''),
      nullif(p_payload -> 'branding' ->> 'surface_color', ''), actor_person_id, now()
    ) on conflict (group_id) do update set
      accent_color = excluded.accent_color, secondary_color = excluded.secondary_color,
      text_color = excluded.text_color, surface_color = excluded.surface_color,
      updated_by_person_id = excluded.updated_by_person_id, updated_at = now();
  end if;

  if p_payload ? 'local_people' then
    if jsonb_typeof(p_payload -> 'local_people') <> 'array' then
      raise invalid_parameter_value using message = 'local_people must be an array';
    end if;
    update public.institution_role_assignments assignment
       set status = 'inactive', updated_at = now()
      from public.institution_memberships membership
     where assignment.membership_id = membership.id
       and assignment.scope_kind = 'group'
       and assignment.scope_group_id = group_record.id
       and assignment.status = 'active'
       and membership.institution_id = group_record.institution_id
       and membership.person_id not in (
         select (value ->> 'person_id')::uuid
           from jsonb_array_elements(p_payload -> 'local_people') value
       );
    for local_person in select value from jsonb_array_elements(p_payload -> 'local_people') loop
      target_person_id := nullif(local_person ->> 'person_id', '')::uuid;
      if target_person_id is null or not exists (
        select 1 from public.people where id = target_person_id and status = 'active'
      ) then
        raise invalid_parameter_value using message = 'local person must be an existing active global identity';
      end if;
      select id into role_record_id from public.institution_roles
      where code = local_person ->> 'role_code' and status = 'active'
        and (institution_id is null or institution_id = group_record.institution_id)
      order by institution_id nulls last limit 1;
      if role_record_id is null then raise invalid_parameter_value using message = 'unknown role_code'; end if;
      target_membership_id := null;
      select id into target_membership_id from public.institution_memberships
      where person_id = target_person_id
        and institution_id = group_record.institution_id
        and status = 'active' and revoked_at is null
      order by created_at desc limit 1;
      if target_membership_id is null then
        insert into public.institution_memberships(
          person_id, institution_id, role_code, status, scope_kind,
          scope_unit_id, scope_group_id, invited_by
        ) values (
          target_person_id, group_record.institution_id,
          local_person ->> 'role_code', 'active', 'group', group_record.unit_id,
          group_record.id, actor_person_id
        ) returning id into target_membership_id;
      end if;
      update public.institution_role_assignments set
        status = 'inactive', updated_at = now()
      where membership_id = target_membership_id and status = 'active'
        and scope_kind = 'group' and scope_group_id = group_record.id
        and role_id <> role_record_id;
      insert into public.institution_role_assignments(
        membership_id, role_id, scope_kind, scope_unit_id, scope_group_id,
        status, granted_by
      ) values (
        target_membership_id, role_record_id, 'group', group_record.unit_id,
        group_record.id, 'active', actor_person_id
      ) on conflict do nothing;
    end loop;
  end if;

  if p_payload ? 'activity_ids' then
    if jsonb_typeof(p_payload -> 'activity_ids') <> 'array' then
      raise invalid_parameter_value using message = 'activity_ids must be an array';
    end if;
    update public.activity_group_links set status = 'inactive', updated_at = now()
    where group_id = group_record.id and status = 'active'
      and activity_id not in (
        select value::uuid from jsonb_array_elements_text(p_payload -> 'activity_ids') value
      );
    for activity_value in select value from jsonb_array_elements_text(p_payload -> 'activity_ids') loop
      if not exists (
        select 1 from public.activity_definitions definition
        join public.activity_unit_links unit_link on unit_link.activity_id = definition.id
          and unit_link.unit_id = group_record.unit_id and unit_link.status = 'active'
        where definition.id = activity_value::uuid
          and definition.institution_id = group_record.institution_id
      ) then raise invalid_parameter_value using message = 'activity is outside group hierarchy'; end if;
      insert into public.activity_group_links(activity_id, group_id, institution_id, unit_id, linked_by_person_id, status)
      values (activity_value::uuid, group_record.id, group_record.institution_id, group_record.unit_id, actor_person_id, 'active')
      on conflict (activity_id, group_id) do update set status = 'active', updated_at = now();
    end loop;
  end if;

  if p_payload ? 'invites' then
    if jsonb_typeof(p_payload -> 'invites') <> 'array' then
      raise invalid_parameter_value using message = 'invites must be an array';
    end if;
    update public.invitations invitation
       set invitation_state = 'revoked', revoked_at = now(), status = 'inactive'
     where invitation.group_id = group_record.id
       and invitation.invitation_state = 'pending'
       and invitation.id not in (
         select (value ->> 'invitation_id')::uuid
           from jsonb_array_elements(p_payload -> 'invites') value
          where nullif(value ->> 'invitation_id', '') is not null
            and value ->> 'invitation_id' not like 'invite-%'
       );
    for invite_value in select value from jsonb_array_elements(p_payload -> 'invites') loop
      target_person_id := nullif(invite_value ->> 'person_id', '')::uuid;
      if target_person_id is null or not exists (
        select 1 from public.people where id = target_person_id and status = 'active'
      ) then
        raise invalid_parameter_value using message = 'invite target must be an existing active global identity';
      end if;
      if not exists (
        select 1 from public.institution_roles
         where code = invite_value ->> 'role_code' and status = 'active'
           and (institution_id is null or institution_id = group_record.institution_id)
      ) then
        raise invalid_parameter_value using message = 'unknown invitation role_code';
      end if;
      enqueue_invite := false;
      target_invitation_id := case
        when nullif(invite_value ->> 'invitation_id', '') is null
          or invite_value ->> 'invitation_id' like 'invite-%' then null
        else (invite_value ->> 'invitation_id')::uuid end;
      if target_invitation_id is null then
        insert into public.invitations(
          scope_kind, institution_id, unit_id, group_id, target_person_id,
          role_code, token_hash, expires_at, invitation_state, invited_by,
          send_count, sent_at, last_sent_at
        ) values (
          'group', group_record.institution_id, group_record.unit_id, group_record.id,
          target_person_id, invite_value ->> 'role_code',
          encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'),
          now() + interval '7 days', 'pending', actor_person_id, 1, now(), now()
        ) returning id into target_invitation_id;
        enqueue_invite := true;
      else
        update public.invitations
           set last_sent_at = case when invite_value ->> 'command' = 'resend' then now() else last_sent_at end,
               send_count = case when invite_value ->> 'command' = 'resend' then send_count + 1 else send_count end
         where id = target_invitation_id and group_id = group_record.id
           and institution_id = group_record.institution_id and invitation_state = 'pending';
        if not found then raise no_data_found using message = 'invitation not found in group scope'; end if;
        enqueue_invite := invite_value ->> 'command' = 'resend';
      end if;
      if enqueue_invite then
        insert into app_private.invitation_delivery_queue(invitation_id, requested_by_person_id)
      values (target_invitation_id, actor_person_id)
      on conflict (invitation_id) do update set
        state = 'pending', requested_by_person_id = excluded.requested_by_person_id,
        available_at = now(), updated_at = now();
      end if;
    end loop;
  end if;
  if p_payload ? 'type_request' and jsonb_typeof(p_payload -> 'type_request') = 'object' then
    insert into public.group_type_requests(
      institution_id, group_id, requested_label, justification, requested_by_person_id
    ) values (
      group_record.institution_id, group_record.id,
      p_payload -> 'type_request' ->> 'label',
      p_payload -> 'type_request' ->> 'justification', actor_person_id
    );
  end if;

  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor_person_id, auth.jwt() ->> 'aal',
    case when p_group_id is null then 'group.create' else 'group.update' end,
    'group', group_record.id, group_record.institution_id, 'success',
    jsonb_build_object(
      'management_version', group_record.management_version,
      'inherit_appearance', group_record.inherit_appearance,
      'inherit_access', group_record.inherit_access,
      'inherit_activities', group_record.inherit_activities
    )
  );
  insert into app_private.group_management_command_receipts(
    request_id, request_hash, actor_person_id, group_id, result_management_version
  ) values (
    p_request_id, request_hash, actor_person_id, group_record.id, group_record.management_version
  );
  return app_private.group_management_payload(group_record.id);
end $$;

-- app_private.superadmin_health_care_save_profile [HEALTH_CARE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."superadmin_health_care_save_profile"("p_request_id" "uuid", "p_profile_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  actor uuid;
  aggregate_id uuid := coalesce(p_profile_id, gen_random_uuid());
  profile_row public.health_care_profiles;
  child_context uuid;
  child_institution uuid;
  before_json jsonb;
  after_json jsonb;
  justification text := btrim(coalesce(p_payload->>'justification', ''));
  response jsonb;
  revision_no integer;
  item_entry jsonb;
  allergy_entry jsonb;
begin
  actor := app_private.require_health_care_actor('health_care.manage');
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text, 0));
  response := app_private.health_care_receipt(p_request_id, actor, 'save_profile');
  if response is not null then return response; end if;
  if justification = '' then
    raise check_violation using message='justification required';
  end if;

  if p_profile_id is not null then
    select * into profile_row
    from public.health_care_profiles
    where id = aggregate_id
      and app_private.health_care_scope_allowed(
        'health_care.manage', institution_id, null, null, child_context_id)
    for update;
    if profile_row.id is null then
      raise no_data_found using message='health care profile unavailable';
    end if;
    if profile_row.management_version <> p_expected_version then
      raise exception using errcode='PT409', message='expected_version mismatch', detail='HEALTH_CARE_STALE_VERSION';
    end if;
    before_json := to_jsonb(profile_row);
  else
    if p_expected_version <> 0 then
      raise exception using errcode='PT409', message='expected_version mismatch', detail='HEALTH_CARE_STALE_VERSION';
    end if;
    -- A instituicao vem do contexto infantil, nunca do payload: aceitar a
    -- instituicao enviada pelo cliente permitiria anexar a crianca de um
    -- tenant a um perfil de outro.
    child_context := app_private.health_care_resolve_child_context(
      (p_payload->>'child_context_id')::uuid,
      (p_payload->>'child_person_id')::uuid,
      (p_payload->>'institution_id')::uuid);
    child_institution := app_private.health_care_child_institution(child_context);
    if child_institution is null then
      raise no_data_found using message='health care profile unavailable';
    end if;
    if not app_private.health_care_scope_allowed(
      'health_care.manage', child_institution, null, null, child_context) then
      raise insufficient_privilege using message='health_care.manage required';
    end if;
    before_json := null;
  end if;

  if profile_row.id is null then
    insert into public.health_care_profiles(
      id, institution_id, child_context_id, operational_status,
      important_signs, adaptations, created_by_person_id
    ) values (
      aggregate_id, child_institution, child_context,
      coalesce(p_payload->>'operational_status','implementation'),
      coalesce(p_payload->>'important_signs',''),
      coalesce(p_payload->>'adaptations',''),
      actor
    ) returning * into profile_row;
  else
    -- A identidade da crianca fica travada na edicao (spec 020): o payload nao
    -- pode mover um perfil para outra crianca.
    update public.health_care_profiles set
      operational_status = coalesce(p_payload->>'operational_status', operational_status),
      important_signs = coalesce(p_payload->>'important_signs', important_signs),
      adaptations = coalesce(p_payload->>'adaptations', adaptations),
      management_version = management_version + 1,
      updated_at = now()
    where id = aggregate_id returning * into profile_row;
  end if;

  if p_payload ? 'items' then
    delete from public.health_care_profile_items where profile_id = aggregate_id;
    for item_entry in select value from jsonb_array_elements(p_payload->'items') loop
      insert into public.health_care_profile_items(
        profile_id, catalog_item_id, other_text
      ) values (
        aggregate_id,
        item_entry->>'catalog_item_id',
        nullif(btrim(coalesce(item_entry->>'other_text','')), '')
      );
    end loop;
  end if;

  if p_payload ? 'allergies' then
    for allergy_entry in select value from jsonb_array_elements(p_payload->'allergies') loop
      if allergy_entry ? 'id' then
        update public.health_care_allergies set
          label = coalesce(allergy_entry->>'label', label),
          allergy_type = coalesce(allergy_entry->>'allergy_type', allergy_type),
          status = coalesce(allergy_entry->>'status', status),
          active = coalesce((allergy_entry->>'active')::boolean, active),
          last_episode_at = coalesce(
            (allergy_entry->>'last_episode_at')::timestamptz, last_episode_at),
          episode_severity = coalesce(
            allergy_entry->>'episode_severity', episode_severity),
          observed_reaction = coalesce(
            allergy_entry->>'observed_reaction', observed_reaction),
          guidance = coalesce(allergy_entry->>'guidance', guidance),
          notes = coalesce(allergy_entry->>'notes', notes),
          inactivated_at = case
            when coalesce((allergy_entry->>'active')::boolean, active) then null
            else coalesce(inactivated_at, now()) end,
          inactivation_reason = case
            when coalesce((allergy_entry->>'active')::boolean, active) then null
            else justification end,
          updated_at = now()
        where id = (allergy_entry->>'id')::uuid
          and profile_id = aggregate_id;
      else
        insert into public.health_care_allergies(
          profile_id, label, allergy_type, status, last_episode_at,
          episode_severity, observed_reaction, guidance, notes,
          created_by_person_id
        ) values (
          aggregate_id,
          btrim(coalesce(allergy_entry->>'label','')),
          coalesce(allergy_entry->>'allergy_type','other'),
          coalesce(allergy_entry->>'status','active'),
          (allergy_entry->>'last_episode_at')::timestamptz,
          allergy_entry->>'episode_severity',
          coalesce(allergy_entry->>'observed_reaction',''),
          coalesce(allergy_entry->>'guidance',''),
          coalesce(allergy_entry->>'notes',''),
          actor
        );
      end if;
    end loop;
  end if;

  after_json := to_jsonb(profile_row);
  select coalesce(max(existing.revision_no), 0) + 1 into revision_no
  from public.health_care_profile_revisions existing
  where existing.profile_id = aggregate_id;
  insert into public.health_care_profile_revisions(
    profile_id, revision_no, subject, justification,
    before_json, after_json, changed_by_person_id
  ) values (
    aggregate_id, revision_no,
    coalesce(p_payload->>'subject','care_profile'), justification,
    before_json, after_json, actor
  );

  response := jsonb_build_object(
    'id', aggregate_id,
    'management_version', profile_row.management_version,
    'revision', revision_no
  );
  insert into app_private.health_care_command_receipts
    values (p_request_id, actor, 'save_profile', aggregate_id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, reason, before_json, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'health_care.profile.save', 'health_care_profile',
    aggregate_id, profile_row.institution_id, 'success', justification,
    before_json, after_json
  );
  return response;
end
$$;

-- app_private.superadmin_institution_contacts_apply_v1 [INSTITUTION]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."superadmin_institution_contacts_apply_v1"("p_request_id" "uuid", "p_institution_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb", "p_request_hash" "bytea", "p_context" "app_private"."superadmin_internal_context", "p_correlation_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  prior_receipt app_private.superadmin_internal_institution_edit_receipts%rowtype;
  institution_record public.institutions%rowtype;
  v_contact_child jsonb;
  v_entry jsonb;
  v_person_id uuid;
  v_membership_id uuid;
  v_role_code_value text;
  v_rep_status public.record_status;
  v_dob date;
  kept_representative_ids uuid[] := '{}';
  kept_administrator_ids uuid[] := '{}';
  result_version bigint;
  admin_role_codes constant text[] := array['owner','institution_admin','coordinator'];
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text, 0));

  select receipt.* into prior_receipt
  from app_private.superadmin_internal_institution_edit_receipts receipt
  where receipt.request_id = p_request_id;
  if prior_receipt.request_id is not null then
    if prior_receipt.actor_internal_identity_id is distinct from p_context.internal_identity_id
      or prior_receipt.institution_id is distinct from p_institution_id
      or prior_receipt.expected_version is distinct from p_expected_version
      or prior_receipt.request_hash is distinct from p_request_hash then
      raise invalid_parameter_value using
        message = 'request id already used', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    return pg_catalog.jsonb_build_object(
      'institution_id', prior_receipt.institution_id,
      'management_version', prior_receipt.result_management_version,
      'correlation_id', p_correlation_id,
      'replayed', true);
  end if;

  select institution.* into institution_record
  from public.institutions institution
  where institution.id = p_institution_id and institution.deleted_at is null
  for update;
  if institution_record.id is null then
    raise insufficient_privilege using
      message = 'internal institution access denied', detail = 'SAI_PERMISSION_DENIED';
  end if;
  if institution_record.management_version is distinct from p_expected_version then
    raise exception using errcode='PT409', message = 'stale institution version', detail = 'SAI_CONCURRENT_CHANGE';
  end if;

  -- documento
  if p_payload ? 'document' then
    update public.institutions set
      document_type = p_payload -> 'document' ->> 'document_type',
      document_ref = p_payload -> 'document' ->> 'document_ref'
    where id = p_institution_id;
  end if;

  -- contato
  if p_payload ? 'contact' then
    v_contact_child := p_payload -> 'contact';
    if pg_catalog.num_nonnulls(v_contact_child ->> 'email', v_contact_child ->> 'phone',
        v_contact_child ->> 'mobile_phone', v_contact_child ->> 'website_url',
        v_contact_child ->> 'whatsapp_number') = 0 then
      delete from public.institution_contacts where institution_id = p_institution_id;
    else
      insert into public.institution_contacts(
        institution_id, email, phone, mobile_phone, website_url, whatsapp_number, status)
      values (p_institution_id, v_contact_child ->> 'email', v_contact_child ->> 'phone',
        v_contact_child ->> 'mobile_phone', v_contact_child ->> 'website_url',
        v_contact_child ->> 'whatsapp_number', 'active')
      on conflict (institution_id) do update set
        email = excluded.email, phone = excluded.phone, mobile_phone = excluded.mobile_phone,
        website_url = excluded.website_url, whatsapp_number = excluded.whatsapp_number,
        status = 'active', updated_at = pg_catalog.now();
    end if;
  end if;

  -- administradores primeiro (definem a role da membership)
  if p_payload ? 'administrators' then
    for v_entry in select value from pg_catalog.jsonb_array_elements(p_payload -> 'administrators') loop
      v_person_id := app_private.superadmin_institution_contacts_upsert_person_v1(v_entry);
      if v_person_id = any(kept_administrator_ids) then
        raise invalid_parameter_value using
          message = 'duplicate administrator', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      v_role_code_value := case v_entry ->> 'level'
        when 'admin_master' then 'owner'
        when 'authorized_administrator' then 'institution_admin'
        else 'coordinator' end;
      select m.id into v_membership_id from public.institution_memberships m
      where m.person_id = v_person_id and m.institution_id = p_institution_id
        and m.status = 'active' and m.revoked_at is null
      for update;
      if v_membership_id is null then
        insert into public.institution_memberships(
          person_id, institution_id, role_code, status, scope_kind, invited_by)
        values (v_person_id, p_institution_id, v_role_code_value, 'active', 'institution', null)
        returning id into v_membership_id;
      else
        update public.institution_memberships set role_code = v_role_code_value
        where id = v_membership_id and role_code is distinct from v_role_code_value;
      end if;
      kept_administrator_ids := kept_administrator_ids || v_person_id;
    end loop;
  end if;

  -- representantes legais
  if p_payload ? 'representatives' then
    for v_entry in select value from pg_catalog.jsonb_array_elements(p_payload -> 'representatives') loop
      v_person_id := app_private.superadmin_institution_contacts_upsert_person_v1(v_entry);
      if v_person_id = any(kept_representative_ids) then
        raise invalid_parameter_value using
          message = 'duplicate representative', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      select m.id into v_membership_id from public.institution_memberships m
      where m.person_id = v_person_id and m.institution_id = p_institution_id
        and m.status = 'active' and m.revoked_at is null
      for update;
      if v_membership_id is null then
        insert into public.institution_memberships(
          person_id, institution_id, role_code, status, scope_kind)
        values (v_person_id, p_institution_id, 'legal_representative', 'active', 'institution')
        returning id into v_membership_id;
      end if;
      select date_of_birth into v_dob from public.people where id = v_person_id;
      v_rep_status := case
        when v_dob is not null and v_dob <= (current_date - interval '18 years')::date then 'active'
        else 'draft' end;
      -- fecha vinculos do mesmo par em estado diferente e reaproveita o igual
      update public.institution_legal_representatives r set
        status = 'inactive', ends_on = coalesce(r.ends_on, greatest(current_date, r.starts_on))
      where r.institution_id = p_institution_id and r.person_id = v_person_id
        and r.status in ('active','draft') and r.status <> v_rep_status;
      if exists (
        select 1 from public.institution_legal_representatives r
        where r.institution_id = p_institution_id and r.person_id = v_person_id and r.status = v_rep_status
      ) then
        update public.institution_legal_representatives r set
          is_primary = coalesce((v_entry ->> 'is_primary')::boolean, false),
          membership_id = v_membership_id
        where r.institution_id = p_institution_id and r.person_id = v_person_id and r.status = v_rep_status;
      else
        insert into public.institution_legal_representatives(
          institution_id, person_id, membership_id, is_primary, starts_on, status)
        values (p_institution_id, v_person_id, v_membership_id,
          coalesce((v_entry ->> 'is_primary')::boolean, false), current_date, v_rep_status);
      end if;
      kept_representative_ids := kept_representative_ids || v_person_id;
    end loop;
    -- quem saiu da lista e encerrado
    update public.institution_legal_representatives r set
      status = 'inactive', ends_on = coalesce(r.ends_on, greatest(current_date, r.starts_on))
    where r.institution_id = p_institution_id and r.status in ('active','draft')
      and not (r.person_id = any(kept_representative_ids));
  end if;

  -- administradores que sairam da lista: rebaixa ou encerra a membership
  if p_payload ? 'administrators' then
    for v_membership_id, v_person_id in
      select m.id, m.person_id from public.institution_memberships m
      where m.institution_id = p_institution_id and m.status = 'active' and m.revoked_at is null
        and m.role_code = any(admin_role_codes)
        and not (m.person_id = any(kept_administrator_ids))
    loop
      if exists (
        select 1 from public.institution_legal_representatives r
        where r.membership_id = v_membership_id and r.status in ('active','draft')
      ) then
        update public.institution_memberships set role_code = 'legal_representative'
        where id = v_membership_id;
      else
        update public.institution_memberships set status = 'inactive', revoked_at = pg_catalog.now()
        where id = v_membership_id;
      end if;
    end loop;
  end if;

  -- representantes sem papel administrativo que sairam: encerra a membership orfa
  if p_payload ? 'representatives' then
    update public.institution_memberships m set status = 'inactive', revoked_at = pg_catalog.now()
    where m.institution_id = p_institution_id and m.status = 'active' and m.revoked_at is null
      and m.role_code = 'legal_representative'
      and not exists (
        select 1 from public.institution_legal_representatives r
        where r.membership_id = m.id and r.status in ('active','draft'));
  end if;

  update public.institutions institution set
    management_version = institution.management_version + 1,
    updated_at = greatest(pg_catalog.clock_timestamp(),
      institution.updated_at + interval '1 microsecond')
  where institution.id = p_institution_id
  returning institution.management_version into result_version;

  insert into app_private.superadmin_internal_institution_edit_receipts(
    request_id, actor_internal_identity_id, institution_id, expected_version,
    request_hash, result_management_version, original_correlation_id)
  values (p_request_id, p_context.internal_identity_id, p_institution_id,
    p_expected_version, p_request_hash, result_version, p_correlation_id);

  return pg_catalog.jsonb_build_object(
    'institution_id', p_institution_id,
    'management_version', result_version,
    'correlation_id', p_correlation_id,
    'replayed', false);
end
$$;

-- app_private.superadmin_institution_edit_core_apply_v2 [INSTITUTION]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."superadmin_institution_edit_core_apply_v2"("p_request_id" "uuid", "p_institution_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb", "p_request_hash" "bytea", "p_context" "app_private"."superadmin_internal_context", "p_correlation_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  prior_receipt app_private.superadmin_internal_institution_edit_receipts%rowtype;
  institution_record public.institutions%rowtype;
  address_record public.institution_addresses%rowtype;
  requested_type_id uuid;
  requested_public_name text;
  requested_trade_name text;
  requested_legal_name text;
  requested_timezone text;
  requested_locale text;
  requested_country text;
  requested_state text;
  requested_city text;
  requested_district text;
  requested_street text;
  requested_number text;
  requested_complement text;
  requested_postal_code text;
  address_changed boolean:=false;
  root_changed boolean:=false;
  result_version bigint;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_request_id::text,0)
  );

  select receipt.* into prior_receipt
  from app_private.superadmin_internal_institution_edit_receipts receipt
  where receipt.request_id=p_request_id;

  if prior_receipt.request_id is not null then
    if prior_receipt.actor_internal_identity_id
         is distinct from p_context.internal_identity_id
      or prior_receipt.institution_id is distinct from p_institution_id
      or prior_receipt.expected_version is distinct from p_expected_version
      or prior_receipt.request_hash is distinct from p_request_hash then
      raise invalid_parameter_value using
        message='request id already used',detail='SAI_INVALID_ARGUMENT';
    end if;

    return pg_catalog.jsonb_build_object(
      'institution_id',prior_receipt.institution_id,
      'management_version',prior_receipt.result_management_version,
      'correlation_id',p_correlation_id,
      'replayed',true
    );
  end if;

  select institution.* into institution_record
  from public.institutions institution
  where institution.id=p_institution_id and institution.deleted_at is null
  for update;
  if institution_record.id is null then
    raise insufficient_privilege using
      message='internal institution access denied',detail='SAI_PERMISSION_DENIED';
  end if;
  if institution_record.management_version is distinct from p_expected_version then
    raise exception using errcode='PT409', message='stale institution version',detail='SAI_CONCURRENT_CHANGE';
  end if;

  requested_type_id:=institution_record.institution_type_id;
  if p_payload?'institution_type_id' then
    select institution_type.id into requested_type_id
    from public.institution_types institution_type
    where institution_type.id=(p_payload->>'institution_type_id')::uuid
      and institution_type.status='active'
    for share;
    if not found then
      raise invalid_parameter_value using
        message='invalid institution type',detail='SAI_INVALID_ARGUMENT';
    end if;
  end if;

  requested_public_name:=case when p_payload?'public_name'
    then p_payload->>'public_name' else institution_record.public_name end;
  requested_trade_name:=case when p_payload?'trade_name'
    then p_payload->>'trade_name' else institution_record.trade_name end;
  requested_legal_name:=case when p_payload?'legal_name'
    then p_payload->>'legal_name' else institution_record.legal_name end;
  requested_timezone:=case when p_payload?'timezone'
    then p_payload->>'timezone' else institution_record.timezone end;
  requested_locale:=case when p_payload?'locale'
    then p_payload->>'locale' else institution_record.locale end;

  root_changed:=requested_public_name is distinct from institution_record.public_name
    or requested_trade_name is distinct from institution_record.trade_name
    or requested_legal_name is distinct from institution_record.legal_name
    or requested_timezone is distinct from institution_record.timezone
    or requested_locale is distinct from institution_record.locale
    or requested_type_id is distinct from institution_record.institution_type_id;

  if p_payload?'address' then
    select address_item.* into address_record
    from public.institution_addresses address_item
    where address_item.institution_id=p_institution_id;
    if address_record.institution_id is null
      and (
        not((p_payload->'address')?'country')
        or p_payload->'address'->>'country'<>'Brasil'
      ) then
      raise invalid_parameter_value using
        message='country Brasil is required for a new institution address',
        detail='SAI_INVALID_ARGUMENT';
    end if;
    requested_country:=case when (p_payload->'address')?'country'
      then p_payload->'address'->>'country'
      else address_record.country end;
    requested_state:=case when (p_payload->'address')?'state'
      then p_payload->'address'->>'state' else address_record.state end;
    requested_city:=case when (p_payload->'address')?'city'
      then p_payload->'address'->>'city' else address_record.city end;
    requested_district:=case when (p_payload->'address')?'district'
      then p_payload->'address'->>'district' else address_record.district end;
    requested_street:=case when (p_payload->'address')?'street'
      then p_payload->'address'->>'street' else address_record.street end;
    requested_number:=case when (p_payload->'address')?'number'
      then p_payload->'address'->>'number' else address_record.number end;
    requested_complement:=case when (p_payload->'address')?'complement'
      then p_payload->'address'->>'complement' else address_record.complement end;
    requested_postal_code:=case when (p_payload->'address')?'postal_code'
      then p_payload->'address'->>'postal_code' else address_record.postal_code end;
    address_changed:=address_record.institution_id is null
      or requested_country is distinct from address_record.country
      or requested_state is distinct from address_record.state
      or requested_city is distinct from address_record.city
      or requested_district is distinct from address_record.district
      or requested_street is distinct from address_record.street
      or requested_number is distinct from address_record.number
      or requested_complement is distinct from address_record.complement
      or requested_postal_code is distinct from address_record.postal_code;
  end if;

  if not(root_changed or address_changed) then
    raise invalid_parameter_value using
      message='institution edit is a no-op',detail='SAI_INVALID_ARGUMENT';
  end if;

  update public.institutions institution set
    public_name=requested_public_name,
    trade_name=requested_trade_name,
    legal_name=requested_legal_name,
    timezone=requested_timezone,
    locale=requested_locale,
    institution_type_id=requested_type_id,
    management_version=institution.management_version+1,
    updated_at=greatest(
      pg_catalog.clock_timestamp(),institution.updated_at+interval '1 microsecond'
    )
  where institution.id=p_institution_id
  returning institution.management_version into result_version;

  if address_changed then
    insert into public.institution_addresses(
      institution_id,country,state,city,district,street,number,complement,
      postal_code,status,created_at,updated_at
    ) values(
      p_institution_id,requested_country,requested_state,requested_city,
      requested_district,requested_street,requested_number,requested_complement,
      requested_postal_code,'active',pg_catalog.now(),pg_catalog.now()
    )
    on conflict(institution_id) do update set
      country=excluded.country,state=excluded.state,city=excluded.city,
      district=excluded.district,street=excluded.street,number=excluded.number,
      complement=excluded.complement,postal_code=excluded.postal_code,
      updated_at=greatest(
        pg_catalog.clock_timestamp(),
        public.institution_addresses.updated_at+interval '1 microsecond'
      );
  end if;

  insert into app_private.superadmin_internal_institution_edit_receipts(
    request_id,actor_internal_identity_id,institution_id,expected_version,
    request_hash,result_management_version,original_correlation_id
  ) values(
    p_request_id,p_context.internal_identity_id,p_institution_id,
    p_expected_version,p_request_hash,result_version,p_correlation_id
  );

  return pg_catalog.jsonb_build_object(
    'institution_id',p_institution_id,
    'management_version',result_version,
    'correlation_id',p_correlation_id,
    'replayed',false
  );
end
$$;

-- app_private.superadmin_internal_user_denial_code [INTERNAL_USER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 0, handlers: 1.
create or replace function "app_private"."superadmin_internal_user_denial_code"("p_sqlstate" "text", "p_detail" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  select case
    when p_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED','SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE') then p_detail
    when p_sqlstate in('40001','PT409') then 'SAI_CONCURRENT_CHANGE'
    when p_sqlstate in('22023','23503','23514','22P02','22001') then 'SAI_INVALID_INPUT'
    when p_sqlstate in('P0002','42501') then 'SAI_PERMISSION_DENIED'
    else 'SAI_INTERNAL_ERROR' end
$$;

-- app_private.superadmin_medication_plan_save [MEDICATION]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."superadmin_medication_plan_save"("p_request_id" "uuid", "p_plan_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  actor uuid;
  aggregate_id uuid := coalesce(p_plan_id, gen_random_uuid());
  plan_row public.medication_plans;
  child_context uuid;
  child_institution uuid;
  version_id uuid;
  version_no integer;
  response jsonb;
  before_json jsonb;
  schedule_entry jsonb;
begin
  actor := app_private.require_health_care_actor('medication.manage');
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text, 0));
  response := app_private.health_care_receipt(p_request_id, actor, 'save_plan');
  if response is not null then return response; end if;
  if jsonb_typeof(p_payload->'schedules') <> 'array'
    or jsonb_array_length(p_payload->'schedules') = 0 then
    raise check_violation using message='medication plan requires schedules';
  end if;

  if p_plan_id is not null then
    select * into plan_row
    from public.medication_plans
    where id = aggregate_id
      and app_private.health_care_scope_allowed(
        'medication.manage', institution_id, unit_id, group_id, child_context_id)
    for update;
    if plan_row.id is null then
      raise no_data_found using message='medication plan unavailable';
    end if;
    if plan_row.management_version <> p_expected_version then
      raise exception using errcode='PT409', message='expected_version mismatch', detail='MEDICATION_STALE_VERSION';
    end if;
    before_json := to_jsonb(plan_row);
  else
    if p_expected_version <> 0 then
      raise exception using errcode='PT409', message='expected_version mismatch', detail='MEDICATION_STALE_VERSION';
    end if;
    child_context := app_private.health_care_resolve_child_context(
      (p_payload->>'child_context_id')::uuid,
      (p_payload->>'child_person_id')::uuid,
      (p_payload->>'institution_id')::uuid);
    child_institution := app_private.health_care_child_institution(child_context);
    if child_institution is null then
      raise no_data_found using message='medication plan unavailable';
    end if;
    if not app_private.health_care_scope_allowed(
      'medication.manage', child_institution,
      (p_payload->>'unit_id')::uuid, (p_payload->>'group_id')::uuid,
      child_context) then
      raise insufficient_privilege using message='medication.manage required';
    end if;
    insert into public.medication_plans(
      id, institution_id, child_context_id, scope_kind, unit_id, group_id,
      status, created_by_person_id
    ) values (
      aggregate_id, child_institution, child_context,
      coalesce(p_payload->>'scope_kind','institution'),
      (p_payload->>'unit_id')::uuid, (p_payload->>'group_id')::uuid,
      coalesce(p_payload->>'status','draft'), actor
    ) returning * into plan_row;
    before_json := null;
  end if;

  -- Mudanca relevante cria versao e invalida aprovacoes anteriores (spec 020).
  -- As versoes antigas ficam; nenhuma dose registrada perde referencia.
  update public.medication_plan_versions
    set review_status = 'invalidated',
        review_reason = 'nova versao do plano',
        approved_at = null,
        approved_by_person_id = null
  where plan_id = aggregate_id and review_status in ('pending','approved');

  select coalesce(max(existing.version), 0) + 1 into version_no
  from public.medication_plan_versions existing
  where existing.plan_id = aggregate_id;

  insert into public.medication_plan_versions(
    plan_id, version, medication_name, dose_amount, dose_unit,
    administration_route, route_details, instructions, reason,
    valid_from, valid_until, timezone, created_by_person_id
  ) values (
    aggregate_id, version_no,
    btrim(coalesce(p_payload->>'medication_name','')),
    (p_payload->>'dose_amount')::numeric,
    btrim(coalesce(p_payload->>'dose_unit','')),
    btrim(coalesce(p_payload->>'administration_route','')),
    nullif(btrim(coalesce(p_payload->>'route_details','')), ''),
    nullif(btrim(coalesce(p_payload->>'instructions','')), ''),
    btrim(coalesce(p_payload->>'reason','')),
    (p_payload->>'valid_from')::date,
    (p_payload->>'valid_until')::date,
    btrim(coalesce(p_payload->>'timezone','')),
    actor
  ) returning id into version_id;

  for schedule_entry in select value from jsonb_array_elements(p_payload->'schedules') loop
    insert into public.medication_plan_schedules(
      plan_version_id, time_of_day, weekdays, timezone, frequency_kind,
      start_date, end_date, max_occurrences_per_day, institution_id
    ) values (
      version_id,
      (schedule_entry->>'time_of_day')::time,
      (select array_agg(value::smallint)
         from jsonb_array_elements_text(schedule_entry->'weekdays')),
      btrim(coalesce(schedule_entry->>'timezone', p_payload->>'timezone')),
      coalesce(schedule_entry->>'frequency_kind','weekly'),
      (schedule_entry->>'start_date')::date,
      (schedule_entry->>'end_date')::date,
      (schedule_entry->>'max_occurrences_per_day')::smallint,
      (schedule_entry->>'institution_id')::uuid
    );
  end loop;

  update public.medication_plans set
    current_version_id = version_id,
    status = coalesce(p_payload->>'status', status),
    management_version = management_version + 1,
    updated_at = now()
  where id = aggregate_id returning * into plan_row;

  response := jsonb_build_object(
    'id', aggregate_id,
    'management_version', plan_row.management_version,
    'version', version_no,
    'version_id', version_id
  );
  insert into app_private.health_care_command_receipts
    values (p_request_id, actor, 'save_plan', aggregate_id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, reason, before_json, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'medication.plan.save', 'medication_plan',
    aggregate_id, plan_row.institution_id, 'success',
    nullif(btrim(coalesce(p_payload->>'reason','')), ''),
    before_json, to_jsonb(plan_row)
  );
  return response;
end
$$;

-- app_private.superadmin_routine_correct_launch [ROUTINE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."superadmin_routine_correct_launch"("uuid", "uuid", bigint, "text", "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare actor uuid:=app_private.current_person_id(); launch_row public.routine_launches; before_state jsonb; after_state jsonb; response jsonb; item jsonb; next_revision integer; supplied integer;
begin
  if actor is null then raise insufficient_privilege using message='authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended($2::text,0));
  response:=app_private.routine_receipt($1,actor,'correct_launch'); if response is not null then return response; end if;
  select l.* into launch_row from public.routine_launches l where l.id=$2
    and app_private.routine_scope_allowed('routine.correct',l.institution_id,l.unit_id,l.group_id) for update;
  if launch_row.id is null then raise insufficient_privilege using message='routine.correct required'; end if;
  if not app_private.has_mfa_aal2() then raise insufficient_privilege using message='MFA AAL2 required'; end if;
  if btrim(coalesce($4,''))='' then raise check_violation using message='correction reason required'; end if;
  if jsonb_typeof($5) <> 'array' or jsonb_array_length($5) not between 1 and 500 then raise invalid_parameter_value using message='invalid routine correction payload'; end if;
  supplied := jsonb_array_length($5);
  if supplied <> (select count(distinct payload_item.value->>'answer_id') from jsonb_array_elements($5) as payload_item(value) where payload_item.value ? 'answer_id')
    or supplied <> (select count(*) from public.routine_answers a join public.routine_child_entries e on e.id=a.child_entry_id
      where e.launch_id=$2 and a.id in (select (payload_item.value->>'answer_id')::uuid from jsonb_array_elements($5) as payload_item(value))) then
    raise check_violation using message='routine correction answer mismatch';
  end if;
  if launch_row.management_version<>$3 or launch_row.status not in ('published','corrected') then raise exception using errcode='PT409', message='expected_version mismatch', detail='ROUTINE_STALE_VERSION'; end if;
  select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]') into before_state from public.routine_answers a join public.routine_child_entries e on e.id=a.child_entry_id where e.launch_id=$2;
  for item in select value from jsonb_array_elements($5) loop
    update public.routine_answers a set value_json=item->'value',answered_by_person_id=actor,answered_at=now()
    from public.routine_child_entries e where a.id=(item->>'answer_id')::uuid and e.id=a.child_entry_id and e.launch_id=$2;
  end loop;
  perform app_private.validate_routine_launch_answers($2,true);
  select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]') into after_state from public.routine_answers a join public.routine_child_entries e on e.id=a.child_entry_id where e.launch_id=$2;
  select coalesce(max(revision_row.revision_no),0)+1 into next_revision from public.routine_launch_revisions revision_row where revision_row.launch_id=$2;
  insert into public.routine_launch_revisions(launch_id,revision_no,reason,before_json,after_json,changed_by_person_id) values($2,next_revision,btrim($4),before_state,after_state,actor);
  update public.routine_launches set status='corrected',corrected_at=now(),updated_at=now(),management_version=management_version+1 where id=$2 returning * into launch_row;
  response:=jsonb_build_object('id',$2,'management_version',launch_row.management_version,'status','corrected','revision',next_revision);
  insert into app_private.routine_command_receipts values($1,actor,'correct_launch',$2,response,now());
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,reason,before_json,after_json) values(actor,auth.jwt()->>'aal','routine.launch.correct','routine_launch',$2,launch_row.institution_id,'success',btrim($4),before_state,after_state);
  return response;
end $_$;

-- app_private.superadmin_routine_publish_launch [ROUTINE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."superadmin_routine_publish_launch"("p_request_id" "uuid", "p_launch_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  actor uuid := app_private.current_person_id();
  launch_row public.routine_launches;
  response jsonb;
begin
  if actor is null then
    raise insufficient_privilege using message='authentication required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_launch_id::text, 0));
  response := app_private.routine_receipt(p_request_id, actor, 'publish_launch');
  if response is not null then return response; end if;

  select launch.* into launch_row
  from public.routine_launches launch
  where launch.id = p_launch_id
    and app_private.routine_scope_allowed(
      'routine.publish', launch.institution_id, launch.unit_id, launch.group_id)
  for update;
  if launch_row.id is null then
    raise insufficient_privilege using message='routine.publish required';
  end if;
  if app_private.routine_mfa_phase_enforced() and not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message='MFA AAL2 required';
  end if;
  if launch_row.management_version <> p_expected_version
    or launch_row.status <> 'draft' then
    raise exception using errcode='PT409', message='expected_version mismatch', detail='ROUTINE_STALE_VERSION';
  end if;

  perform app_private.validate_routine_launch_answers(p_launch_id, true);

  update public.routine_launches set
    status = 'published',
    published_at = now(),
    published_by_person_id = actor,
    management_version = management_version + 1,
    updated_at = now()
  where id = p_launch_id returning * into launch_row;

  insert into public.context_notification_events(
    institution_id, unit_id, group_id, event_code, object_type, object_id,
    payload_json, created_by_person_id
  ) values (
    launch_row.institution_id, launch_row.unit_id, launch_row.group_id,
    'routine_launch_published', 'routine_launch', p_launch_id,
    jsonb_build_object('launch_date', launch_row.launch_date), actor
  );

  response := jsonb_build_object(
    'id', p_launch_id,
    'management_version', launch_row.management_version,
    'status', 'published'
  );
  insert into app_private.routine_command_receipts
    values (p_request_id, actor, 'publish_launch', p_launch_id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'routine.launch.publish', 'routine_launch',
    p_launch_id, launch_row.institution_id, 'success', response
  );
  return response;
end
$$;

-- app_private.superadmin_routine_revert_application [ROUTINE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."superadmin_routine_revert_application"("uuid", "uuid", bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare
  actor uuid;
  app_row public.routine_applications;
  parent_row public.routine_applications;
  response jsonb;
  revision_no integer;
begin
  actor:=app_private.require_routine_actor('routine.manage_applications',false);
  perform pg_advisory_xact_lock(hashtextextended($2::text,0));
  response:=app_private.routine_receipt($1,actor,'revert_application');
  if response is not null then return response; end if;
  select * into app_row
  from public.routine_applications
  where id=$2
    and app_private.routine_scope_allowed('routine.manage_applications', institution_id, unit_id, group_id)
  for update;
  if app_row.id is null then
    raise no_data_found using message='routine application unavailable';
  end if;
  if app_row.management_version<>$3 or app_row.parent_application_id is null then
    raise exception using errcode='PT409', message='expected_version mismatch', detail='ROUTINE_STALE_VERSION';
  end if;
  select * into parent_row from public.routine_applications
  where id=app_row.parent_application_id and institution_id=app_row.institution_id;
  if parent_row.id is null then
    raise no_data_found using message='routine application unavailable';
  end if;
  update public.routine_applications set source_model_version_id=parent_row.source_model_version_id,
    inheritance_mode='inherited',management_version=management_version+1,updated_at=now()
  where id=$2 returning * into app_row;
  select coalesce(max(revision_row.revision_no),0)+1 into revision_no
  from public.routine_application_revisions revision_row where revision_row.application_id=$2;
  insert into public.routine_application_revisions(
    application_id,revision_no,source_model_version_id,origin_application_id,effective_definition,created_by_person_id
  ) values ($2,revision_no,app_row.source_model_version_id,parent_row.id,
    app_private.routine_definition_json(app_row.source_model_version_id),actor);
  response:=jsonb_build_object('id',$2,'management_version',app_row.management_version,'inherited',true);
  insert into app_private.routine_command_receipts values($1,actor,'revert_application',$2,response,now());
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
  values(actor,auth.jwt()->>'aal','routine.application.revert','routine_application',$2,app_row.institution_id,'success',response);
  return response;
end $_$;

-- app_private.superadmin_routine_save_application [ROUTINE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."superadmin_routine_save_application"("p_request_id" "uuid", "p_application_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  actor uuid;
  aggregate_id uuid := coalesce(p_application_id, gen_random_uuid());
  app_row public.routine_applications;
  response jsonb;
  revision_id uuid;
  revision_no integer;
begin
  actor := app_private.require_routine_actor('routine.manage_applications', false);
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text, 0));
  response := app_private.routine_receipt(p_request_id, actor, 'save_application');
  if response is not null then return response; end if;

  if p_application_id is not null then
    select * into app_row
    from public.routine_applications
    where id = aggregate_id
      and app_private.routine_scope_allowed('routine.manage_applications', institution_id, unit_id, group_id)
    for update;
    if app_row.id is null then
      raise no_data_found using message = 'routine application unavailable';
    end if;
  end if;

  if app_row.id is null then
    if p_expected_version <> 0 then
      raise exception using errcode='PT409', message = 'expected_version mismatch', detail='ROUTINE_STALE_VERSION';
    end if;
    perform app_private.require_routine_scope(
      'routine.manage_applications',
      (p_payload->>'institution_id')::uuid,
      (p_payload->>'unit_id')::uuid,
      (p_payload->>'group_id')::uuid,
      false
    );
    insert into public.routine_applications(
      id,institution_id,unit_id,group_id,activity_id,scope_kind,source_model_version_id,
      parent_application_id,inheritance_mode,visibility,valid_from,valid_until,starts_at,
      ends_at,status,created_by_person_id
    ) values (
      aggregate_id,(p_payload->>'institution_id')::uuid,(p_payload->>'unit_id')::uuid,
      (p_payload->>'group_id')::uuid,(p_payload->>'activity_id')::uuid,p_payload->>'scope_kind',
      (p_payload->>'source_model_version_id')::uuid,(p_payload->>'parent_application_id')::uuid,
      coalesce(p_payload->>'inheritance_mode','inherited'),
      coalesce(p_payload->>'visibility','authorized_guardians'),(p_payload->>'valid_from')::date,
      (p_payload->>'valid_until')::date,(p_payload->>'starts_at')::time,
      (p_payload->>'ends_at')::time,coalesce(p_payload->>'status','draft'),actor
    ) returning * into app_row;
  else
    if app_row.management_version <> p_expected_version then
      raise exception using errcode='PT409', message = 'expected_version mismatch', detail='ROUTINE_STALE_VERSION';
    end if;
    update public.routine_applications set
      source_model_version_id=(p_payload->>'source_model_version_id')::uuid,
      parent_application_id=(p_payload->>'parent_application_id')::uuid,
      inheritance_mode=coalesce(p_payload->>'inheritance_mode',inheritance_mode),
      visibility=coalesce(p_payload->>'visibility',visibility),
      valid_from=(p_payload->>'valid_from')::date,valid_until=(p_payload->>'valid_until')::date,
      starts_at=(p_payload->>'starts_at')::time,ends_at=(p_payload->>'ends_at')::time,
      status=coalesce(p_payload->>'status',status),management_version=management_version+1,
      updated_at=now()
    where id=aggregate_id returning * into app_row;
  end if;

  select coalesce(max(revision_row.revision_no),0)+1 into revision_no
  from public.routine_application_revisions revision_row where revision_row.application_id=aggregate_id;
  insert into public.routine_application_revisions(
    application_id,revision_no,source_model_version_id,origin_application_id,effective_definition,created_by_person_id
  ) values (
    aggregate_id,revision_no,app_row.source_model_version_id,
    coalesce(app_row.parent_application_id,aggregate_id),
    app_private.routine_definition_json(app_row.source_model_version_id),actor
  ) returning id into revision_id;
  delete from public.routine_application_assignees where application_id=aggregate_id;
  insert into public.routine_application_assignees(application_id,institution_id,membership_id,responsibility)
  select aggregate_id,app_row.institution_id,(x->>'membership_id')::uuid,coalesce(x->>'responsibility','record')
  from jsonb_array_elements(coalesce(p_payload->'assignees','[]')) x;
  response:=jsonb_build_object('id',aggregate_id,'management_version',app_row.management_version,
    'revision_id',revision_id,'revision',revision_no);
  insert into app_private.routine_command_receipts values(p_request_id,actor,'save_application',aggregate_id,response,now());
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
  values(actor,auth.jwt()->>'aal','routine.application.save','routine_application',aggregate_id,app_row.institution_id,'success',response);
  return response;
end $$;

-- app_private.superadmin_routine_save_launch_draft [ROUTINE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."superadmin_routine_save_launch_draft"("p_request_id" "uuid", "p_launch_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  actor uuid;
  aggregate_id uuid := coalesce(p_launch_id, gen_random_uuid());
  launch_row public.routine_launches;
  application_row public.routine_applications;
  revision_row public.routine_application_revisions;
  author_membership uuid;
  entry_item jsonb;
  answer_item jsonb;
  entry_id uuid;
  response jsonb;
begin
  actor := app_private.require_routine_actor('routine.record', false);
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text, 0));
  response := app_private.routine_receipt(p_request_id, actor, 'save_launch_draft');
  if response is not null then return response; end if;

  if p_launch_id is not null then
    select * into launch_row
    from public.routine_launches
    where id = aggregate_id
      and app_private.routine_scope_allowed(
        'routine.record', institution_id, unit_id, group_id)
    for update;
    if launch_row.id is null then
      raise no_data_found using message='routine launch unavailable';
    end if;
    if launch_row.management_version <> p_expected_version then
      raise exception using errcode='PT409', message='expected_version mismatch', detail='ROUTINE_STALE_VERSION';
    end if;
    if launch_row.status <> 'draft' then
      raise check_violation using message='routine launch is not a draft';
    end if;
    select * into application_row from public.routine_applications
    where id = launch_row.application_id;
  else
    if p_expected_version <> 0 then
      raise exception using errcode='PT409', message='expected_version mismatch', detail='ROUTINE_STALE_VERSION';
    end if;
    select * into application_row from public.routine_applications
    where id = (p_payload->>'application_id')::uuid;
    if application_row.id is null then
      raise no_data_found using message='routine application unavailable';
    end if;
    perform app_private.require_routine_scope(
      'routine.record', application_row.institution_id,
      application_row.unit_id, application_row.group_id, false
    );
    select * into revision_row from public.routine_application_revisions
    where application_id = application_row.id
    order by revision_no desc limit 1;
    -- A autoria e derivada da sessao e do tenant do lancamento, nunca aceita
    -- do payload: aceitar deixaria um profissional lancar em nome de outro.
    select membership.id into author_membership
    from public.institution_memberships membership
    where membership.person_id = actor
      and membership.institution_id = application_row.institution_id
      and membership.status = 'active'
      and membership.revoked_at is null
    limit 1;
    insert into public.routine_launches(
      id, institution_id, unit_id, group_id, application_id,
      application_revision_id, author_membership_id, launch_date, status,
      created_by_person_id
    ) values (
      aggregate_id, application_row.institution_id, application_row.unit_id,
      application_row.group_id, application_row.id, revision_row.id,
      author_membership,
      coalesce((p_payload->>'launch_date')::date, current_date), 'draft', actor
    ) returning * into launch_row;
  end if;

  for entry_item in
    select value from jsonb_array_elements(coalesce(p_payload->'entries','[]'::jsonb))
  loop
    insert into public.routine_child_entries(
      launch_id, child_context_id, child_group_link_id, status
    ) values (
      aggregate_id,
      (entry_item->>'child_context_id')::uuid,
      (entry_item->>'child_group_link_id')::uuid,
      coalesce(entry_item->>'status','draft')
    )
    on conflict (launch_id, child_context_id) do update set
      child_group_link_id = excluded.child_group_link_id,
      status = excluded.status
    returning id into entry_id;

    for answer_item in
      select value from jsonb_array_elements(coalesce(entry_item->'answers','[]'::jsonb))
    loop
      insert into public.routine_answers(
        child_entry_id, field_id, value_json, answered_by_person_id, answered_at
      ) values (
        entry_id, (answer_item->>'field_id')::uuid, answer_item->'value', actor, now()
      )
      on conflict (child_entry_id, field_id) do update set
        value_json = excluded.value_json,
        answered_by_person_id = excluded.answered_by_person_id,
        answered_at = excluded.answered_at;
    end loop;
  end loop;

  perform app_private.validate_routine_launch_answers(aggregate_id, false);

  update public.routine_launches
    set management_version = management_version + 1, updated_at = now()
  where id = aggregate_id returning * into launch_row;

  response := jsonb_build_object(
    'id', aggregate_id,
    'management_version', launch_row.management_version,
    'status', launch_row.status
  );
  insert into app_private.routine_command_receipts
    values (p_request_id, actor, 'save_launch_draft', aggregate_id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'routine.launch.save_draft', 'routine_launch',
    aggregate_id, launch_row.institution_id, 'success', response
  );
  return response;
end
$$;

-- app_private.superadmin_routine_save_model [ROUTINE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."superadmin_routine_save_model"("p_request_id" "uuid", "p_model_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  actor uuid;
  aggregate_id uuid := coalesce(p_model_id, gen_random_uuid());
  model_row public.routine_models;
  before_json jsonb;
  after_json jsonb;
  response jsonb;
  version_id uuid;
  version_no integer;
  section_item jsonb;
  field_item jsonb;
  option_item jsonb;
  condition_item jsonb;
  section_id uuid;
  field_id uuid;
  option_id uuid;
  field_ids jsonb := '{}'::jsonb;
  option_ids jsonb := '{}'::jsonb;
begin
  actor := app_private.require_routine_actor('routine.manage_models', false);
  perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text, 0));
  response := app_private.routine_receipt(p_request_id, actor, 'save_model');
  if response is not null then return response; end if;

  if p_model_id is not null then
    select * into model_row
    from public.routine_models
    where id = aggregate_id
      and app_private.routine_scope_allowed(
        'routine.manage_models', institution_id, origin_unit_id, null)
    for update;
    if model_row.id is null then
      raise no_data_found using message = 'routine model unavailable';
    end if;
    if model_row.management_version <> p_expected_version then
      raise exception using errcode='PT409', message='expected_version mismatch', detail='ROUTINE_STALE_VERSION';
    end if;
    before_json := to_jsonb(model_row);
  else
    if p_expected_version <> 0 then
      raise exception using errcode='PT409', message='expected_version mismatch', detail='ROUTINE_STALE_VERSION';
    end if;
    perform app_private.require_routine_scope(
      'routine.manage_models',
      (p_payload->>'institution_id')::uuid,
      (p_payload->>'origin_unit_id')::uuid,
      null,
      false
    );
    before_json := null;
  end if;

  if model_row.id is null then
    insert into public.routine_models(
      id, institution_id, origin_scope, origin_unit_id, name, description,
      status, created_by_person_id
    ) values (
      aggregate_id,
      (p_payload->>'institution_id')::uuid,
      coalesce(p_payload->>'origin_scope','institution'),
      (p_payload->>'origin_unit_id')::uuid,
      btrim(coalesce(p_payload->>'name','')),
      coalesce(p_payload->>'description',''),
      coalesce(p_payload->>'status','draft'),
      actor
    ) returning * into model_row;
  else
    update public.routine_models set
      name = btrim(coalesce(p_payload->>'name', name)),
      description = coalesce(p_payload->>'description', description),
      status = coalesce(p_payload->>'status', status),
      management_version = management_version + 1,
      updated_at = now()
    where id = aggregate_id returning * into model_row;
  end if;

  if p_payload ? 'sections' then
    if jsonb_typeof(p_payload->'sections') <> 'array' then
      raise invalid_parameter_value using message='invalid routine definition payload';
    end if;
    select coalesce(max(existing.version), 0) + 1 into version_no
    from public.routine_model_versions existing
    where existing.model_id = aggregate_id;

    insert into public.routine_model_versions(
      model_id, version, created_by_person_id
    ) values (aggregate_id, version_no, actor) returning id into version_id;

    for section_item in select value from jsonb_array_elements(p_payload->'sections') loop
      insert into public.routine_sections(model_version_id, name, sort_order)
      values (
        version_id,
        btrim(coalesce(section_item->>'name','')),
        coalesce((section_item->>'sort_order')::integer, 0)
      ) returning id into section_id;

      for field_item in
        select value from jsonb_array_elements(coalesce(section_item->'fields','[]'::jsonb))
      loop
        insert into public.routine_fields(
          section_id, label, kind, sort_order, is_required,
          initial_value, minimum_value, maximum_value
        ) values (
          section_id,
          btrim(coalesce(field_item->>'label','')),
          coalesce(field_item->>'kind','short_text'),
          coalesce((field_item->>'sort_order')::integer, 0),
          coalesce((field_item->>'is_required')::boolean, false),
          field_item->'initial_value',
          (field_item->>'minimum_value')::numeric,
          (field_item->>'maximum_value')::numeric
        ) returning id into field_id;
        field_ids := field_ids || jsonb_build_object(
          coalesce(field_item->>'id', field_id::text), field_id::text);

        for option_item in
          select value from jsonb_array_elements(coalesce(field_item->'options','[]'::jsonb))
        loop
          insert into public.routine_field_options(field_id, label, sort_order)
          values (
            field_id,
            btrim(coalesce(option_item->>'label','')),
            coalesce((option_item->>'sort_order')::integer, 0)
          ) returning id into option_id;
          option_ids := option_ids || jsonb_build_object(
            coalesce(option_item->>'id', option_id::text), option_id::text);
        end loop;
      end loop;
    end loop;

    for section_item in select value from jsonb_array_elements(p_payload->'sections') loop
      for field_item in
        select value from jsonb_array_elements(coalesce(section_item->'fields','[]'::jsonb))
      loop
        for condition_item in
          select value from jsonb_array_elements(coalesce(field_item->'conditions','[]'::jsonb))
        loop
          insert into public.routine_field_conditions(
            parent_field_id, target_field_id, option_id, boolean_value, depth
          ) values (
            (field_ids->>(condition_item->>'parent_field_id'))::uuid,
            (field_ids->>(condition_item->>'target_field_id'))::uuid,
            (option_ids->>(condition_item->>'option_id'))::uuid,
            (condition_item->>'boolean_value')::boolean,
            coalesce((condition_item->>'depth')::integer, 1)
          );
        end loop;
      end loop;
    end loop;

    perform app_private.validate_routine_definition(version_id);
    update public.routine_model_versions
      set definition_json = app_private.routine_definition_json(version_id),
          published_at = now()
    where id = version_id;
    update public.routine_models
      set current_version_id = version_id, updated_at = now()
    where id = aggregate_id returning * into model_row;
  end if;

  after_json := to_jsonb(model_row);
  response := jsonb_build_object(
    'id', aggregate_id,
    'management_version', model_row.management_version,
    'version', coalesce(version_no, 0),
    'version_id', version_id
  );
  insert into app_private.routine_command_receipts
    values (p_request_id, actor, 'save_model', aggregate_id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, before_json, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'routine.model.save', 'routine_model', aggregate_id,
    model_row.institution_id, 'success', before_json, after_json
  );
  return response;
end
$$;

-- app_private.superadmin_upsert_activity [ACTIVITY]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."superadmin_upsert_activity"("p_payload" "jsonb", "p_idempotency_key" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid:=app_private.current_person_id(); request_hash bytea;
 receipt app_private.activity_management_command_receipts%rowtype;
 before_record public.activity_definitions%rowtype; saved public.activity_definitions%rowtype;
 target_activity_id uuid; target_institution_id uuid; target_taxonomy_id uuid;
 selected_unit_ids uuid[]; selected_group_ids uuid[]; expected_version bigint;
 is_create boolean; result jsonb; item jsonb; target_group_link_id uuid;
 target_assignment_id uuid; target_membership public.institution_memberships%rowtype;
 capability_record record; action_value text; professional_person_id uuid;
 admin_group record; revoked_instructors integer:=0; revoked_admins integer:=0;
 source_template public.activity_templates%rowtype; template_defaults jsonb;
begin

  perform admin_group; -- Reserved for effective-access diagnostics.
 if (select auth.uid()) is null or actor is null then
  raise insufficient_privilege using message='authentication required';
 end if;
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or p_idempotency_key is null
    or p_payload-array[
      'id','expected_version','institution_id','name','description','handle_stem',
      'origin_scope_kind','origin_unit_id','governance_kind','status','taxonomy_id',
      'taxonomy_other_description','identity_mode','identity_storage_bucket',
      'identity_storage_path','identity_initials','identity_color','identity_icon',
      'unit_ids','group_ids','participants','professional_assignments','template_id'
    ]<>'{}'::jsonb then
  raise invalid_parameter_value using message='invalid activity payload';
 end if;
 target_activity_id:=coalesce(nullif(p_payload->>'id','')::uuid,gen_random_uuid());
 select * into before_record from public.activity_definitions
  where id=target_activity_id for update;
 is_create:=before_record.id is null;
 if is_create then
  if not app_private.has_platform_permission('activities.create') then
   raise insufficient_privilege using message='activities.create required';
  end if;
 else
  if not app_private.has_platform_permission('activities.manage') then
   raise insufficient_privilege using message='activities.manage required';
  end if;
  expected_version:=nullif(p_payload->>'expected_version','')::bigint;
  if expected_version is null or expected_version<>before_record.management_version then
   raise exception using errcode='PT409', message='activity version conflict', detail='ACTIVITY_STALE_VERSION';
  end if;
 end if;
 if not app_private.has_mfa_aal2() then
  raise insufficient_privilege using message='MFA AAL2 required';
 end if;
 if is_create and nullif(p_payload->>'template_id','') is not null then
  select * into source_template from public.activity_templates template_record
  where template_record.id=(p_payload->>'template_id')::uuid
   and template_record.status='active'
   and (template_record.scope_kind='platform'
    or template_record.institution_id=nullif(p_payload->>'institution_id','')::uuid);
  if source_template.id is null then
   raise no_data_found using message='template not found';
  end if;
  select coalesce(jsonb_object_agg(entry.key,entry.value),'{}'::jsonb)
  into template_defaults
  from jsonb_each(source_template.template_payload) entry
  where entry.key in (
   'description','governance_kind','identity_mode',
   'identity_initials','identity_color','identity_icon'
  );
  p_payload:=template_defaults||jsonb_build_object(
   'name',source_template.name,
   'description',coalesce(
    template_defaults->>'description',source_template.description,''),
   'governance_kind',coalesce(
    template_defaults->>'governance_kind',source_template.governance_kind),
   'taxonomy_id',source_template.taxonomy_id,
   'identity_mode',coalesce(template_defaults->>'identity_mode','initials'),
   'identity_initials',coalesce(template_defaults->>'identity_initials',
    upper(left(regexp_replace(source_template.name,'[^[:alnum:]]','','g'),2))),
   'identity_color',coalesce(template_defaults->>'identity_color','#D63C00')
  )||p_payload;
 elsif not is_create and p_payload?'template_id'
    and nullif(p_payload->>'template_id','')::uuid
      is distinct from before_record.template_id then
  raise invalid_parameter_value using message='activity template origin cannot change';
 end if;
 if p_payload?'unit_ids'
    and not app_private.has_platform_permission('activities.link_units') then
  raise insufficient_privilege using message='activities.link_units required';
 end if;
 if p_payload?'group_ids'
    and not app_private.has_platform_permission('activities.link_groups') then
  raise insufficient_privilege using message='activities.link_groups required';
 end if;
 if (p_payload?'participants' or p_payload?'professional_assignments')
    and not app_private.has_platform_permission('activities.assign_people') then
  raise insufficient_privilege using message='activities.assign_people required';
 end if;
 if p_payload?'professional_assignments'
    and not app_private.has_platform_permission('activities.manage_permissions') then
  raise insufficient_privilege using message='activities.manage_permissions required';
 end if;
 request_hash:=extensions.digest(convert_to(p_payload::text,'UTF8'),'sha256');
 perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key::text,0));
 select * into receipt from app_private.activity_management_command_receipts
  where request_id=p_idempotency_key;
 if receipt.request_id is not null then
  if receipt.actor_person_id<>actor then
   raise insufficient_privilege using message='idempotency receipt actor mismatch';
  end if;
  if receipt.command_kind<>'upsert' or receipt.request_hash<>request_hash then
   raise invalid_parameter_value using message='idempotency key reused';
  end if;
  return receipt.result_json;
 end if;

 target_institution_id:=nullif(p_payload->>'institution_id','')::uuid;
 target_taxonomy_id:=nullif(p_payload->>'taxonomy_id','')::uuid;
 if target_institution_id is null or nullif(btrim(p_payload->>'name'),'') is null
    or length(btrim(p_payload->>'name'))>160 or target_taxonomy_id is null
    or coalesce(p_payload->>'origin_scope_kind','institution') not in ('institution','unit')
    or (coalesce(p_payload->>'governance_kind','optional') not in ('optional','mandatory')
     and not(not is_create and before_record.governance_kind='fixed'
      and p_payload->>'governance_kind'='fixed'))
    or coalesce(p_payload->>'status','draft') not in (
      'draft','active','inactive','suspended','archived')
    or coalesce(p_payload->>'identity_mode','initials') not in ('photo','initials','icon') then
  raise invalid_parameter_value using message='invalid activity fields';
 end if;
 if not exists(select 1 from public.institutions institution
   where institution.id=target_institution_id) then
  raise foreign_key_violation using message='institution not found';
 end if;
 if not exists(select 1 from public.activity_taxonomies taxonomy
   where taxonomy.id=target_taxonomy_id and taxonomy.status='active') then
  raise foreign_key_violation using message='taxonomy not found';
 end if;
 if exists(select 1 from public.activity_taxonomies taxonomy
    where taxonomy.id=target_taxonomy_id and taxonomy.code='outros')
    and nullif(btrim(p_payload->>'taxonomy_other_description'),'') is null then
  raise invalid_parameter_value using message='other taxonomy description required';
 end if;
 if coalesce(p_payload->>'origin_scope_kind','institution')='unit'
    and not exists(select 1 from public.units unit
      where unit.id=nullif(p_payload->>'origin_unit_id','')::uuid
       and unit.institution_id=target_institution_id) then
  raise foreign_key_violation using message='origin unit outside institution';
 end if;
 if not is_create and before_record.institution_id<>target_institution_id then
  raise insufficient_privilege using message='activity institution cannot change';
 end if;

 if is_create then
  insert into public.activity_definitions(
   id,institution_id,name,description,handle_stem,origin_scope_kind,origin_unit_id,
   governance_kind,status,taxonomy_id,taxonomy_other_description,identity_mode,
   identity_storage_bucket,identity_storage_path,identity_initials,identity_color,
   identity_icon,template_id,created_by_person_id
  ) values(
   target_activity_id,target_institution_id,btrim(p_payload->>'name'),
   nullif(btrim(p_payload->>'description'),''),
   coalesce(nullif(app_private.activity_slugify(coalesce(
    nullif(p_payload->>'handle_stem',''),p_payload->>'name')),''),
    'atividade-'||left(target_activity_id::text,6)),
   coalesce(p_payload->>'origin_scope_kind','institution')::public.activity_origin_scope,
   nullif(p_payload->>'origin_unit_id','')::uuid,
   coalesce(p_payload->>'governance_kind','optional'),
   coalesce(p_payload->>'status','draft')::public.record_status,target_taxonomy_id,
   nullif(btrim(p_payload->>'taxonomy_other_description'),''),
   coalesce(p_payload->>'identity_mode','initials'),
   nullif(p_payload->>'identity_storage_bucket',''),
   nullif(p_payload->>'identity_storage_path',''),
   nullif(upper(btrim(p_payload->>'identity_initials')),''),
   coalesce(nullif(p_payload->>'identity_color',''),'#D63C00'),
   nullif(p_payload->>'identity_icon',''),
   nullif(p_payload->>'template_id','')::uuid,actor
  ) returning * into saved;
 else
  update public.activity_definitions set
   name=btrim(p_payload->>'name'),
   description=nullif(btrim(p_payload->>'description'),''),
   handle_stem=coalesce(nullif(app_private.activity_slugify(coalesce(
    nullif(p_payload->>'handle_stem',''),p_payload->>'name')),''),
    'atividade-'||left(target_activity_id::text,6)),
   origin_scope_kind=coalesce(
    p_payload->>'origin_scope_kind',origin_scope_kind::text)::public.activity_origin_scope,
   origin_unit_id=nullif(p_payload->>'origin_unit_id','')::uuid,
   governance_kind=coalesce(p_payload->>'governance_kind',governance_kind),
   status=coalesce(p_payload->>'status',status::text)::public.record_status,
   taxonomy_id=target_taxonomy_id,
   taxonomy_other_description=nullif(btrim(p_payload->>'taxonomy_other_description'),''),
   identity_mode=coalesce(p_payload->>'identity_mode',identity_mode),
   identity_storage_bucket=case when p_payload?'identity_storage_bucket'
     then nullif(p_payload->>'identity_storage_bucket','') else identity_storage_bucket end,
   identity_storage_path=case when p_payload?'identity_storage_path'
     then nullif(p_payload->>'identity_storage_path','') else identity_storage_path end,
   identity_initials=case when p_payload?'identity_initials'
     then nullif(upper(btrim(p_payload->>'identity_initials')),'') else identity_initials end,
   identity_color=case when p_payload?'identity_color'
     then nullif(p_payload->>'identity_color','') else identity_color end,
   identity_icon=case when p_payload?'identity_icon'
     then nullif(p_payload->>'identity_icon','') else identity_icon end,
   management_version=management_version+1,updated_at=now(),
   archived_at=case when p_payload->>'status'='archived'
     then coalesce(archived_at,now()) else null end
  where id=target_activity_id returning * into saved;
 end if;

 if p_payload?'unit_ids' then
  if jsonb_typeof(p_payload->'unit_ids')<>'array' then
   raise invalid_parameter_value using message='unit_ids must be an array';
  end if;
  select coalesce(array_agg(distinct value::uuid),'{}'::uuid[]) into selected_unit_ids
   from jsonb_array_elements_text(p_payload->'unit_ids');
  if (select count(*) from public.units unit
       where unit.id=any(selected_unit_ids)
        and unit.institution_id=target_institution_id)<>cardinality(selected_unit_ids) then
   raise foreign_key_violation using message='unit outside institution';
  end if;
  update public.activity_group_links group_link
   set status='inactive',ends_at=coalesce(group_link.ends_at,now()),updated_at=now()
   where group_link.activity_id=target_activity_id and group_link.status='active'
    and not(group_link.unit_id=any(selected_unit_ids));
  update public.activity_unit_links unit_link
   set status='inactive',ends_at=coalesce(unit_link.ends_at,now()),updated_at=now()
   where unit_link.activity_id=target_activity_id and unit_link.status='active'
    and not(unit_link.unit_id=any(selected_unit_ids));
  insert into public.activity_unit_links(
   activity_id,institution_id,unit_id,linked_by_person_id,status,starts_at,ends_at
  ) select target_activity_id,target_institution_id,selected_unit_id,actor,'active',now(),null
    from unnest(selected_unit_ids) selected_unit_id
  on conflict(activity_id,unit_id) do update set status='active',ends_at=null,
   linked_by_person_id=excluded.linked_by_person_id,updated_at=now();
 end if;

 if p_payload?'group_ids' then
  if jsonb_typeof(p_payload->'group_ids')<>'array' then
   raise invalid_parameter_value using message='group_ids must be an array';
  end if;
  select coalesce(array_agg(distinct value::uuid),'{}'::uuid[]) into selected_group_ids
   from jsonb_array_elements_text(p_payload->'group_ids');
  if (select count(*) from public.groups group_record
      join public.activity_unit_links unit_link
       on unit_link.unit_id=group_record.unit_id
       and unit_link.activity_id=target_activity_id and unit_link.status='active'
      where group_record.id=any(selected_group_ids)
       and group_record.institution_id=target_institution_id)
       <>cardinality(selected_group_ids) then
   raise foreign_key_violation using message='group outside selected activity units';
  end if;
  update public.activity_group_links group_link
   set status='inactive',ends_at=coalesce(group_link.ends_at,now()),updated_at=now()
   where group_link.activity_id=target_activity_id and group_link.status='active'
    and not(group_link.group_id=any(selected_group_ids));
  insert into public.activity_group_links(
   activity_id,institution_id,unit_id,group_id,linked_by_person_id,status,starts_at,ends_at
  ) select target_activity_id,target_institution_id,group_record.unit_id,group_record.id,
    actor,'active',now(),null from public.groups group_record
    where group_record.id=any(selected_group_ids)
  on conflict(activity_id,group_id) do update set status='active',ends_at=null,
   unit_id=excluded.unit_id,linked_by_person_id=excluded.linked_by_person_id,updated_at=now();
 end if;

 if p_payload?'participants' then
  if not app_private.has_platform_permission('activities.assign_people') then
   raise insufficient_privilege using message='activities.assign_people required';
  end if;
  if jsonb_typeof(p_payload->'participants')<>'array' then
   raise invalid_parameter_value using message='participants must be an array';
  end if;
  for item in select value from jsonb_array_elements(p_payload->'participants') loop
   if item-array['group_id','child_group_link_id','belongs']<>'{}'::jsonb then
    raise invalid_parameter_value using message='invalid participant payload';
   end if;
   select link.id into target_group_link_id from public.activity_group_links link
    where link.activity_id=target_activity_id and link.group_id=(item->>'group_id')::uuid
     and link.status='active';
   if target_group_link_id is null then
    raise foreign_key_violation using message='activity group not found';
   end if;
   if coalesce((item->>'belongs')::boolean,false) then
    insert into public.activity_group_participants(
     activity_group_link_id,child_group_link_id,status,added_by_person_id
    ) values(target_group_link_id,(item->>'child_group_link_id')::uuid,'active',actor)
    on conflict(activity_group_link_id,child_group_link_id)
      where status='active' and removed_at is null do update set updated_at=now();
   else
    update public.activity_group_participants participant
     set status='inactive',removed_at=now(),updated_at=now()
     where participant.activity_group_link_id=target_group_link_id
      and participant.child_group_link_id=(item->>'child_group_link_id')::uuid
      and participant.status='active' and participant.removed_at is null;
   end if;
  end loop;
 end if;

 if p_payload?'professional_assignments' then
  if not app_private.has_platform_permission('activities.assign_people')
     or not app_private.has_platform_permission('activities.manage_permissions') then
   raise insufficient_privilege using message='activity people permissions required';
  end if;
  if jsonb_typeof(p_payload->'professional_assignments')<>'array' then
   raise invalid_parameter_value using message='professional_assignments must be an array';
  end if;
  update public.activity_group_assignments assignment
   set status='inactive',revoked_at=coalesce(assignment.revoked_at,now()),updated_at=now()
   from public.activity_group_links link
   where assignment.activity_group_link_id=link.id
    and link.activity_id=target_activity_id
    and assignment.assignment_role='instructor'
    and assignment.status='active'
    and not exists(
     select 1 from jsonb_array_elements(p_payload->'professional_assignments') submitted
      where submitted->>'role'='instructor'
       and nullif(submitted->>'group_id','')::uuid=link.group_id
       and nullif(submitted->>'membership_id','')::uuid=assignment.membership_id
    );
  get diagnostics revoked_instructors=row_count;
  update public.activity_admin_assignments assignment
   set status='inactive',revoked_at=coalesce(assignment.revoked_at,now()),updated_at=now()
   where assignment.activity_id=target_activity_id and assignment.status='active'
    and not exists(
     select 1 from jsonb_array_elements(p_payload->'professional_assignments') submitted
      where submitted->>'role'='activity_admin'
       and nullif(submitted->>'membership_id','')::uuid=assignment.membership_id
    );
  get diagnostics revoked_admins=row_count;
  for item in select value from jsonb_array_elements(p_payload->'professional_assignments') loop
   if item-array['group_id','person_id','membership_id','role','capabilities']<>'{}'::jsonb
      or item->>'role' not in ('instructor','activity_admin')
      or jsonb_typeof(item->'capabilities')<>'object' then
    raise invalid_parameter_value using message='invalid professional assignment';
   end if;
   select * into target_membership from public.institution_memberships membership
    where membership.id=(item->>'membership_id')::uuid
     and membership.institution_id=target_institution_id
     and membership.status='active' and membership.revoked_at is null;
   if target_membership.id is null then
    raise foreign_key_violation using message='membership outside institution';
   end if;
   professional_person_id:=target_membership.person_id;
   if nullif(item->>'person_id','') is not null
      and (item->>'person_id')::uuid<>professional_person_id then
    raise insufficient_privilege using message='person does not match membership';
   end if;

   if item->>'role'='activity_admin' then
    insert into public.activity_admin_assignments(
     activity_id,institution_id,person_id,membership_id,assignment_role,
     status,assigned_by_person_id
    ) values(target_activity_id,target_institution_id,professional_person_id,
      target_membership.id,'activity_admin','active',actor)
    on conflict(activity_id,person_id) where status='active' and revoked_at is null
    do update set membership_id=excluded.membership_id,
     assigned_by_person_id=excluded.assigned_by_person_id,updated_at=now();
    continue;
   end if;
   target_group_link_id:=null;
   select link.id into target_group_link_id from public.activity_group_links link
    where link.activity_id=target_activity_id and link.status='active'
     and link.group_id=nullif(item->>'group_id','')::uuid;
   if target_group_link_id is null then
    raise foreign_key_violation using message='professional assignment group not found';
   end if;
   target_assignment_id:=null;
   select assignment.id into target_assignment_id
    from public.activity_group_assignments assignment
    where assignment.activity_group_link_id=target_group_link_id
     and assignment.person_id=professional_person_id
     and assignment.assignment_role='instructor'
    order by assignment.created_at limit 1 for update;
   if target_assignment_id is null then
    insert into public.activity_group_assignments(
     activity_group_link_id,institution_id,person_id,membership_id,assignment_role,
     status,assigned_by_person_id
    ) values(target_group_link_id,target_institution_id,professional_person_id,
      target_membership.id,'instructor','active',actor)
    returning id into target_assignment_id;
   else
    update public.activity_group_assignments assignment set status='active',revoked_at=null,
     membership_id=target_membership.id,assigned_by_person_id=actor,updated_at=now()
    where assignment.id=target_assignment_id;
   end if;
   for capability_record in
    select capability.id,capability.code from public.activity_capabilities capability
     where capability.code in ('chat','now','happens','moments','attendance')
   loop
    action_value:=coalesce(item->'capabilities'->>capability_record.code,'both');
    if action_value not in ('none','view','edit','both') then
     raise invalid_parameter_value using message='invalid capability action';
    end if;
    insert into public.activity_assignment_capability_actions(
     assignment_id,capability_id,can_view,can_edit,changed_by_person_id
    ) values(target_assignment_id,capability_record.id,
      action_value in ('view','both'),action_value in ('edit','both'),actor)
    on conflict(assignment_id,capability_id) do update set
     can_view=excluded.can_view,can_edit=excluded.can_edit,
     changed_by_person_id=excluded.changed_by_person_id,updated_at=now();
   end loop;
  end loop;
  if revoked_instructors+revoked_admins>0 then
   insert into audit.audit_logs(
    actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,
    outcome,after_json
   ) values(actor,auth.jwt()->>'aal','activity.assignments.snapshot',
    'activity_definition',target_activity_id,target_institution_id,'success',
    jsonb_build_object('revoked_instructors',revoked_instructors,
     'revoked_admins',revoked_admins));
  end if;
 end if;

 if exists(select 1 from public.activity_taxonomies taxonomy
    where taxonomy.id=target_taxonomy_id and taxonomy.code='outros') then
  insert into public.activity_taxonomy_requests(
   institution_id,requested_name,requested_description,created_by_person_id
  ) values(target_institution_id,btrim(p_payload->>'name'),
    btrim(p_payload->>'taxonomy_other_description'),actor);
 end if;

 result:=app_private.activity_management_payload(target_activity_id);
 insert into app_private.activity_management_command_receipts(
  request_id,command_kind,request_hash,actor_person_id,activity_id,result_json
 ) values(p_idempotency_key,'upsert',request_hash,actor,target_activity_id,result);
 insert into audit.audit_logs(
  actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,
  outcome,before_json,after_json
 ) values(actor,auth.jwt()->>'aal',
  case when is_create then 'activity.create' else 'activity.update' end,
  'activity_definition',target_activity_id,target_institution_id,'success',
  case when is_create then null else to_jsonb(before_record) end,to_jsonb(saved));
 return result;
end $$;

-- app_private.transfer_unit_institution_for_superadmin [UNIT]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."transfer_unit_institution_for_superadmin"("p_request_id" "uuid", "p_unit_id" "uuid", "p_destination_institution_id" "uuid", "p_expected_version" bigint, "p_confirmed" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid:=app_private.current_person_id();u public.units%rowtype;impact jsonb;h bytea;prior app_private.unit_management_command_receipts%rowtype;begin
if p_request_id is null or not coalesce(p_confirmed,false)then raise invalid_parameter_value using message='explicit transfer confirmation required';end if;
if actor is null or not app_private.has_mfa_aal2()then raise insufficient_privilege using message='AAL2 required';end if;
h:=app_private.unit_management_hash(jsonb_build_object('unit_id',p_unit_id,'destination_institution_id',p_destination_institution_id,'expected_version',p_expected_version,'confirmed',true));
perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
select*into prior from app_private.unit_management_command_receipts where request_id=p_request_id;
if prior.request_id is not null then
 if prior.request_hash<>h or prior.actor_person_id<>actor or prior.command_kind<>'transfer' or prior.unit_id<>p_unit_id then raise invalid_parameter_value using message='request replay mismatch';end if;
 if not exists(select 1 from public.units where id=p_unit_id and app_private.has_scoped_platform_permission('units.read',institution_id))then raise insufficient_privilege using message='unit read scope required';end if;
 return app_private.unit_form_payload(p_unit_id);
end if;
select*into u from public.units where id=p_unit_id for update;if u.id is null then raise no_data_found using message='unit not found';end if;
if u.management_version<>p_expected_version then raise exception using errcode='PT409', message='stale unit version', detail='UNIT_STALE_VERSION';end if;
impact:=app_private.preview_unit_institution_transfer(p_unit_id,p_destination_institution_id);
if jsonb_array_length(impact->'incompatible_dependencies')>0 then raise check_violation using message='unit transfer blocked by incompatible dependencies';end if;
update public.units set institution_id=p_destination_institution_id,management_version=management_version+1,updated_at=now()where id=p_unit_id;
insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
values(actor,'aal2','unit.institution.transfer','unit',p_unit_id,p_destination_institution_id,'success',impact);
insert into app_private.unit_management_command_receipts(request_id,request_hash,actor_person_id,command_kind,unit_id,result_management_version)
values(p_request_id,h,actor,'transfer',p_unit_id,p_expected_version+1);
return app_private.unit_form_payload(p_unit_id);end$$;

-- app_private.update_institution_for_superadmin [INSTITUTION]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "app_private"."update_institution_for_superadmin"("p_request_id" "uuid", "p_institution_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
#variable_conflict use_variable
declare
  actor_person_id uuid;
  institution_record public.institutions%rowtype;
  institution_type_id uuid;
  current_plan_id uuid;
  current_plan_code text;
  current_subscription_status text;
  current_starts_at timestamptz;
  current_trial_ends_at timestamptz;
  current_manual_reason text;
  current_paused_at timestamptz;
  current_cancelled_at timestamptz;
  requested_plan_id uuid;
  requested_plan_code text;
  requested_status public.institution_status;
  request_hash bytea;
  result jsonb;
  prior_hash bytea;
  request_record jsonb;
  prior_actor uuid;
  prior_command text;
  prior_institution_id uuid;
  prior_result_management_version bigint;
  changed_fields jsonb;
  effective_payload jsonb;
  subscription_changed boolean := false;
begin
  if p_request_id is null or p_institution_id is null
     or p_expected_version is null or p_expected_version < 1 then
    raise invalid_parameter_value using
      message = 'request_id, institution_id and positive expected_version are required';
  end if;
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then
    raise insufficient_privilege using message = 'active person identity required';
  end if;
  if not app_private.has_scoped_platform_permission('institution.update', p_institution_id) then
    raise insufficient_privilege using message = 'institution.update required';
  end if;
  if not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message = 'MFA AAL2 required';
  end if;

  effective_payload := p_payload;
  request_record := jsonb_build_object(
    'institution_id', p_institution_id,
    'expected_version', p_expected_version,
    'payload', p_payload
  );
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  request_hash := app_private.institution_management_request_hash(request_record);
  select receipt.request_hash, receipt.actor_person_id,
         receipt.command_kind, receipt.institution_id,
         receipt.result_management_version
    into prior_hash, prior_actor, prior_command, prior_institution_id,
         prior_result_management_version
  from app_private.institution_management_command_receipts receipt
  where receipt.request_id = p_request_id;
  if prior_institution_id is not null then
    if prior_actor is distinct from actor_person_id
       or prior_command is distinct from 'update'
       or prior_hash is distinct from request_hash then
      raise invalid_parameter_value using
        message = 'request_id already used with a different command payload';
    end if;
    result := app_private.institution_management_payload(prior_institution_id);
    if result is null then
      raise no_data_found using message = 'institution receipt target not found';
    end if;
    if (result ->> 'management_version')::bigint
       is distinct from prior_result_management_version then
      raise exception using errcode='PT409', message = 'receipt result version is no longer current', detail='INSTITUTION_STALE_VERSION';
    end if;
    return result;
  end if;

  perform app_private.assert_institution_management_payload(p_payload, false);
  select institution_row.* into institution_record
  from public.institutions institution_row
  where institution_row.id = p_institution_id
    and institution_row.deleted_at is null
  for update;
  if institution_record.id is null then
    raise no_data_found using message = 'institution not found';
  end if;
  if institution_record.management_version is distinct from p_expected_version then
    raise exception using errcode='PT409', message = 'stale institution version', detail='INSTITUTION_STALE_VERSION';
  end if;

  requested_status := institution_record.status;
  if p_payload ? 'status' then
    requested_status := (p_payload ->> 'status')::public.institution_status;
    if requested_status is distinct from institution_record.status
       and not app_private.has_scoped_platform_permission('institution.status.change', p_institution_id) then
      raise insufficient_privilege using message = 'institution.status.change required';
    end if;
  end if;

  institution_type_id := institution_record.institution_type_id;
  if p_payload ? 'institution_type_name' then
    select type_record.id into institution_type_id
    from public.institution_types type_record
    where lower(type_record.name) = lower(btrim(p_payload ->> 'institution_type_name'))
      and type_record.status = 'active'
    limit 1;
    if institution_type_id is null then
      raise invalid_parameter_value using message = 'unknown or inactive institution type';
    end if;
  end if;

  select subscription_record.plan_id, plan_record.code,
         subscription_record.status::text, subscription_record.starts_at,
         subscription_record.trial_ends_at, subscription_record.manual_reason,
         subscription_record.paused_at, subscription_record.cancelled_at
    into current_plan_id, current_plan_code, current_subscription_status,
         current_starts_at, current_trial_ends_at, current_manual_reason,
         current_paused_at, current_cancelled_at
  from public.institution_subscriptions subscription_record
  left join public.plans plan_record on plan_record.id = subscription_record.plan_id
  where subscription_record.institution_id = p_institution_id
  order by subscription_record.created_at desc, subscription_record.id desc
  limit 1;
  requested_plan_id := current_plan_id;
  requested_plan_code := current_plan_code;
  if p_payload ? 'subscription' then
    requested_plan_code := lower(btrim(p_payload -> 'subscription' ->> 'plan_code'));
    select plan_record.id into requested_plan_id
    from public.plans plan_record
    where plan_record.code = requested_plan_code and plan_record.status = 'active'
    limit 1;
    if requested_plan_id is null then
      raise invalid_parameter_value using message = 'unknown or inactive plan';
    end if;
    subscription_changed := current_plan_id is null
      or requested_plan_id is distinct from current_plan_id
      or coalesce(p_payload -> 'subscription' ->> 'status', 'draft')
           is distinct from current_subscription_status
      or nullif(p_payload -> 'subscription' ->> 'starts_at', '')::timestamptz
           is distinct from current_starts_at
      or nullif(p_payload -> 'subscription' ->> 'trial_ends_at', '')::timestamptz
           is distinct from current_trial_ends_at
      or nullif(btrim(p_payload -> 'subscription' ->> 'manual_reason'), '')
           is distinct from current_manual_reason
      or nullif(p_payload -> 'subscription' ->> 'paused_at', '')::timestamptz
           is distinct from current_paused_at
      or nullif(p_payload -> 'subscription' ->> 'cancelled_at', '')::timestamptz
           is distinct from current_cancelled_at;
    if subscription_changed
       and not app_private.has_scoped_platform_permission('plan.change', p_institution_id) then
      raise insufficient_privilege using message = 'plan.change required';
    end if;
    if not subscription_changed then
      effective_payload := p_payload - 'subscription';
    end if;
  end if;

  update public.institutions institution_row set
    public_name = case when p_payload ? 'public_name'
      then btrim(p_payload ->> 'public_name') else institution_row.public_name end,
    trade_name = case when p_payload ? 'trade_name'
      then nullif(btrim(p_payload ->> 'trade_name'), '') else institution_row.trade_name end,
    legal_name = case when p_payload ? 'legal_name'
      then nullif(btrim(p_payload ->> 'legal_name'), '') else institution_row.legal_name end,
    slug = case when p_payload ? 'slug'
      then lower(btrim(p_payload ->> 'slug')) else institution_row.slug end,
    primary_domain = case when p_payload ? 'primary_domain'
      then nullif(lower(btrim(p_payload ->> 'primary_domain')), '')
      else institution_row.primary_domain end,
    document_ref = case when p_payload ? 'document_ref'
      then nullif(btrim(p_payload ->> 'document_ref'), '')
      else institution_row.document_ref end,
    document_type = case when p_payload ? 'document_type'
      then btrim(p_payload ->> 'document_type') else institution_row.document_type end,
    status = requested_status,
    timezone = case when p_payload ? 'timezone'
      then btrim(p_payload ->> 'timezone') else institution_row.timezone end,
    locale = case when p_payload ? 'locale'
      then btrim(p_payload ->> 'locale') else institution_row.locale end,
    institution_type_id = institution_type_id,
    management_version = institution_row.management_version + 1,
    updated_at = greatest(
      clock_timestamp(), institution_row.updated_at + interval '1 microsecond'
    )
  where institution_row.id = p_institution_id;

  perform app_private.apply_institution_management_children(
    p_institution_id, actor_person_id, effective_payload, requested_plan_id
  );
  select coalesce(jsonb_agg(key_name order by key_name), '[]'::jsonb)
    into changed_fields from jsonb_object_keys(p_payload) key_name;
  result := app_private.institution_management_payload(p_institution_id);

  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, before_json, after_json
  ) values (
    actor_person_id, 'aal2', 'institution.update', 'institution', p_institution_id,
    p_institution_id, 'success',
    jsonb_build_object(
      'status', institution_record.status::text,
      'plan_id', current_plan_id, 'plan_code', current_plan_code,
      'changed_fields', changed_fields
    ),
    jsonb_build_object(
      'status', result ->> 'status',
      'plan_id', result -> 'subscription' -> 'plan_id',
      'plan_code', result -> 'subscription' -> 'plan_code',
      'changed_fields', changed_fields
    )
  );
  insert into app_private.institution_management_command_receipts(
    request_id, actor_person_id, command_kind, institution_id,
    request_hash, result_management_version
  ) values (
    p_request_id, actor_person_id, 'update', p_institution_id,
    request_hash, (result ->> 'management_version')::bigint
  );
  return result;
exception
  when invalid_text_representation or datetime_field_overflow
    or check_violation or not_null_violation or foreign_key_violation
    or unique_violation then
    raise invalid_parameter_value using message = 'invalid institution payload';
end;
$$;

-- app_private.update_superadmin_person [PERSON]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."update_superadmin_person"("p_person_id" "uuid", "p_expected_updated_at" timestamp with time zone, "p_identity_patch" "jsonb" DEFAULT '{}'::"jsonb", "p_context_changes" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
#variable_conflict use_variable
declare
  current_person public.people;
  updated_person public.people;
  change jsonb;
  membership public.institution_memberships;
  assignment public.institution_role_assignments;
  child_context public.child_contexts;
  institution_id uuid;
  unit_id uuid;
  group_id uuid;
  role_id uuid;
  role_scope_kind text;
  child_unit_link_id uuid;
  child_group_link_id uuid;
  child_unit_link_count integer;
  child_group_link_count integer;
  changed_fields text[];
  actor_person_id uuid;
  actor_platform_membership_id uuid;
begin
  perform app_private.assert_people_permission('people.update');

  if jsonb_typeof(coalesce(p_identity_patch, '{}'::jsonb)) <> 'object'
     or jsonb_typeof(coalesce(p_context_changes, '[]'::jsonb)) <> 'array' then
    raise invalid_parameter_value using message = 'invalid patch shape';
  end if;
  if exists (
    select 1
    from jsonb_object_keys(coalesce(p_identity_patch, '{}'::jsonb)) key
    where key not in ('first_name', 'last_name', 'display_name', 'legal_name')
  ) then
    raise invalid_parameter_value using message = 'identity field is not editable';
  end if;

  select *
  into current_person
  from public.people person
  where person.id = p_person_id
    and person.deleted_at is null
  for update;
  if not found then
    raise no_data_found using message = 'person not found';
  end if;
  if current_person.person_type = 'service' then
    raise invalid_parameter_value using message = 'service people are read-only';
  end if;
  if current_person.updated_at <> p_expected_updated_at then
    raise exception using errcode='PT409', message = 'person was updated concurrently', detail='PERSON_STALE_VERSION';
  end if;

  select coalesce(array_agg(key order by key), array[]::text[])
  into changed_fields
  from jsonb_object_keys(coalesce(p_identity_patch, '{}'::jsonb)) key;

  if jsonb_array_length(coalesce(p_context_changes, '[]'::jsonb)) > 0 then
    if current_person.person_type = 'adult' then
      perform app_private.assert_people_permission('people.memberships.manage');
    else
      perform app_private.assert_people_permission('people.child_contexts.manage');
    end if;
  end if;

  actor_person_id := app_private.current_person_id();
  actor_platform_membership_id :=
    app_private.platform_permission_membership_id('people.update');

  update public.people person
  set
    first_name = case
      when p_identity_patch ? 'first_name'
        then coalesce(nullif(btrim(p_identity_patch ->> 'first_name'), ''), person.first_name)
      else person.first_name
    end,
    last_name = case
      when p_identity_patch ? 'last_name'
        then coalesce(nullif(btrim(p_identity_patch ->> 'last_name'), ''), person.last_name)
      else person.last_name
    end,
    display_name = case
      when p_identity_patch ? 'display_name'
        then coalesce(nullif(btrim(p_identity_patch ->> 'display_name'), ''), person.display_name)
      else person.display_name
    end,
    legal_name = case
      when p_identity_patch ? 'legal_name'
        then nullif(btrim(p_identity_patch ->> 'legal_name'), '')
      else person.legal_name
    end,
    updated_at = greatest(
      clock_timestamp(),
      person.updated_at + interval '1 microsecond'
    )
  where person.id = p_person_id
  returning * into updated_person;

  for change in
    select value
    from jsonb_array_elements(coalesce(p_context_changes, '[]'::jsonb))
  loop
    if current_person.person_type = 'adult'
       and change ->> 'kind' = 'institution_membership' then
      if change ->> 'operation' = 'add' then
        institution_id := nullif(change ->> 'institution_id', '')::uuid;
        unit_id := nullif(change ->> 'scope_unit_id', '')::uuid;
        group_id := nullif(change ->> 'scope_group_id', '')::uuid;
        if institution_id is null
           or nullif(btrim(change ->> 'role_code'), '') is null then
          raise invalid_parameter_value using message = 'membership context is incomplete';
        end if;
        if unit_id is not null and not exists (
          select 1 from public.units unit
          where unit.id = unit_id and unit.institution_id = institution_id
        ) then
          raise check_violation using message = 'unit belongs to another institution';
        end if;
        if group_id is not null and not exists (
          select 1 from public.groups group_row
          where group_row.id = group_id
            and group_row.institution_id = institution_id
            and (unit_id is null or group_row.unit_id = unit_id)
        ) then
          raise check_violation using message = 'group belongs to another context';
        end if;
        select role.id
        into role_id
        from public.institution_roles role
        where role.institution_id = institution_id
          and role.code = btrim(change ->> 'role_code')
          and role.status = 'active'
        limit 1;
        if role_id is null then
          raise foreign_key_violation using
            message = 'contextual role does not belong to institution';
        end if;
        role_scope_kind := case
          when group_id is not null then 'group'
          when unit_id is not null then 'unit'
          else 'institution'
        end;
        if nullif(change ->> 'membership_id', '') is not null then
          select *
          into membership
          from public.institution_memberships target
          where target.id = (change ->> 'membership_id')::uuid
            and target.person_id = p_person_id
            and target.institution_id = institution_id
            and target.status = 'active'
            and target.revoked_at is null
          for update;
          if not found then
            raise no_data_found using
              message = 'membership not found for person and institution';
          end if;
        else
          select *
          into membership
          from public.institution_memberships target
          where target.person_id = p_person_id
            and target.institution_id = institution_id
            and target.status = 'active'
            and target.revoked_at is null
          for update;
          if not found then
            insert into public.institution_memberships(
              person_id,
              institution_id,
              role_code,
              status,
              scope_kind,
              scope_unit_id,
              scope_group_id
            ) values (
              p_person_id,
              institution_id,
              btrim(change ->> 'role_code'),
              'active',
              role_scope_kind,
              unit_id,
              group_id
            )
            returning * into membership;
          end if;
        end if;
        insert into public.institution_role_assignments(
          membership_id,
          role_id,
          scope_kind,
          scope_unit_id,
          scope_group_id
        )
        values (
          membership.id,
          role_id,
          role_scope_kind,
          unit_id,
          group_id
        )
        returning * into assignment;
      elsif change ->> 'operation' in ('update', 'revoke') then
        select *
        into membership
        from public.institution_memberships target
        where target.id = nullif(change ->> 'membership_id', '')::uuid
          and target.person_id = p_person_id
        for update;
        if not found then
          raise no_data_found using message = 'membership not found for person';
        end if;
        select *
        into assignment
        from public.institution_role_assignments target
        where target.id = nullif(change ->> 'assignment_id', '')::uuid
          and target.membership_id = membership.id
        for update;
        if not found then
          raise no_data_found using message = 'role assignment not found for membership';
        end if;
        if change ->> 'operation' = 'revoke' then
          update public.institution_role_assignments target
          set status = 'inactive', updated_at = clock_timestamp()
          where target.id = assignment.id;
          if not exists (
            select 1
            from public.institution_role_assignments remaining
            where remaining.membership_id = membership.id
              and remaining.status = 'active'
          ) then
            update public.institution_memberships target
            set status = 'inactive', revoked_at = clock_timestamp()
            where target.id = membership.id;
          end if;
        else
          institution_id := membership.institution_id;
          unit_id := case
            when change ? 'scope_unit_id'
              then nullif(change ->> 'scope_unit_id', '')::uuid
            else assignment.scope_unit_id
          end;
          group_id := case
            when change ? 'scope_group_id'
              then nullif(change ->> 'scope_group_id', '')::uuid
            else assignment.scope_group_id
          end;
          if unit_id is not null and not exists (
            select 1 from public.units unit
            where unit.id = unit_id and unit.institution_id = institution_id
          ) then
            raise check_violation using message = 'unit belongs to another institution';
          end if;
          if group_id is not null and not exists (
            select 1 from public.groups group_row
            where group_row.id = group_id
              and group_row.institution_id = institution_id
              and (unit_id is null or group_row.unit_id = unit_id)
          ) then
            raise check_violation using message = 'group belongs to another context';
          end if;
          select role.id
          into role_id
          from public.institution_roles role
          where role.institution_id = institution_id
            and role.code = coalesce(
              nullif(btrim(change ->> 'role_code'), ''),
              (
                select assigned_role.code
                from public.institution_roles assigned_role
                where assigned_role.id = assignment.role_id
              )
            )
            and role.status = 'active'
          limit 1;
          if role_id is null then
            raise foreign_key_violation using
              message = 'contextual role does not belong to institution';
          end if;
          role_scope_kind := case
            when group_id is not null then 'group'
            when unit_id is not null then 'unit'
            else 'institution'
          end;
          update public.institution_role_assignments target
          set
            role_id = role_id,
            scope_kind = role_scope_kind,
            scope_unit_id = unit_id,
            scope_group_id = group_id,
            updated_at = clock_timestamp()
          where target.id = assignment.id
          returning * into assignment;
        end if;
      else
        raise invalid_parameter_value using message = 'unsupported membership operation';
      end if;
    elsif current_person.person_type = 'child'
          and change ->> 'kind' = 'child_context' then
      if change ->> 'operation' = 'add' then
        institution_id := nullif(change ->> 'institution_id', '')::uuid;
        unit_id := nullif(change ->> 'unit_id', '')::uuid;
        group_id := nullif(change ->> 'group_id', '')::uuid;
        if institution_id is null then
          raise invalid_parameter_value using message = 'child context requires institution';
        end if;
        if unit_id is not null and not exists (
          select 1 from public.units unit
          where unit.id = unit_id and unit.institution_id = institution_id
        ) then
          raise check_violation using message = 'unit belongs to another institution';
        end if;
        if group_id is not null and (
          unit_id is null or not exists (
            select 1 from public.groups group_row
            where group_row.id = group_id
              and group_row.institution_id = institution_id
              and group_row.unit_id = unit_id
          )
        ) then
          raise check_violation using message = 'group belongs to another context';
        end if;
        select *
        into child_context
        from public.child_contexts target
        where target.child_person_id = p_person_id
          and target.institution_id = institution_id
        for update;
        if found then
          update public.child_contexts target
          set
            status = 'active',
            archived_at = null,
            updated_at = clock_timestamp()
          where target.id = child_context.id
          returning * into child_context;
        else
          insert into public.child_contexts(child_person_id, institution_id)
          values (p_person_id, institution_id)
          returning * into child_context;
        end if;
        if unit_id is not null then
          insert into public.child_unit_links(child_context_id, unit_id, status)
          values (child_context.id, unit_id, 'pending')
          on conflict on constraint child_unit_links_child_context_id_unit_id_key
          do update set
            status = 'pending',
            accepted_by = null,
            accepted_at = null,
            revoked_at = null,
            updated_at = clock_timestamp()
          returning id into child_unit_link_id;
        end if;
        if group_id is not null then
          insert into public.child_group_links(
            child_unit_link_id,
            group_id,
            status
          )
          values (child_unit_link_id, group_id, 'active')
          on conflict on constraint child_group_links_child_unit_link_id_group_id_key
          do update set
            status = 'active',
            ends_at = null,
            updated_at = clock_timestamp()
          returning id into child_group_link_id;
        end if;
      elsif change ->> 'operation' in ('update', 'revoke') then
        select *
        into child_context
        from public.child_contexts target
        where target.id = nullif(change ->> 'child_context_id', '')::uuid
          and target.child_person_id = p_person_id
        for update;
        if not found then
          raise no_data_found using message = 'child context not found for person';
        end if;
        if change ->> 'operation' = 'revoke' then
          update public.child_group_links group_link
          set status = 'inactive', updated_at = clock_timestamp()
          where group_link.child_unit_link_id in (
            select child_unit_link.id
            from public.child_unit_links child_unit_link
            where child_unit_link.child_context_id = child_context.id
          );
          update public.child_unit_links unit_link
          set status = 'inactive', revoked_at = clock_timestamp()
          where unit_link.child_context_id = child_context.id;
          update public.child_contexts target
          set status = 'inactive', updated_at = clock_timestamp()
          where target.id = child_context.id;
        else
          unit_id := case
            when change ? 'unit_id'
              then nullif(change ->> 'unit_id', '')::uuid
            else null
          end;
          group_id := case
            when change ? 'group_id'
              then nullif(change ->> 'group_id', '')::uuid
            else null
          end;
          child_unit_link_id :=
            nullif(change ->> 'child_unit_link_id', '')::uuid;
          child_group_link_id :=
            nullif(change ->> 'child_group_link_id', '')::uuid;

          if unit_id is null then
            raise invalid_parameter_value using
              message = 'child context update requires unit';
          end if;
          if child_unit_link_id is null then
            select count(*)
            into child_unit_link_count
            from public.child_unit_links unit_link
            where unit_link.child_context_id = child_context.id
              and unit_link.status in (
                'pending', 'awaiting_allocation', 'active'
              )
              and unit_link.revoked_at is null;
            if child_unit_link_count > 1 then
              raise invalid_parameter_value using
                message = 'child unit link id is required for ambiguous context';
            elsif child_unit_link_count = 0 then
              insert into public.child_unit_links(
                child_context_id,
                unit_id,
                status
              )
              values (child_context.id, unit_id, 'pending')
              returning id into child_unit_link_id;
            else
              select unit_link.id
              into child_unit_link_id
              from public.child_unit_links unit_link
              where unit_link.child_context_id = child_context.id
                and unit_link.status in (
                  'pending', 'awaiting_allocation', 'active'
                )
                and unit_link.revoked_at is null
              order by unit_link.created_at, unit_link.id
              limit 1;
            end if;
          end if;
          if not exists (
            select 1
            from public.child_unit_links unit_link
            where unit_link.id = child_unit_link_id
              and unit_link.child_context_id = child_context.id
          ) then
            raise no_data_found using
              message = 'child unit link not found for context';
          end if;
          if not exists (
            select 1
            from public.units unit
            where unit.id = unit_id
              and unit.institution_id = child_context.institution_id
          ) then
            raise check_violation using
              message = 'unit belongs to another institution';
          end if;
          if group_id is not null and not exists (
            select 1
            from public.groups group_row
            where group_row.id = group_id
              and group_row.institution_id = child_context.institution_id
              and group_row.unit_id = unit_id
          ) then
            raise check_violation using
              message = 'group belongs to another context';
          end if;

          update public.child_unit_links unit_link
          set
            unit_id = unit_id,
            status = 'pending',
            accepted_by = null,
            accepted_at = null,
            revoked_at = null,
            updated_at = clock_timestamp()
          where unit_link.id = child_unit_link_id;

          if child_group_link_id is null then
            select count(*)
            into child_group_link_count
            from public.child_group_links group_link
            where group_link.child_unit_link_id = child_unit_link_id
              and group_link.status = 'active';
            if child_group_link_count > 1 then
              raise invalid_parameter_value using
                message = 'child group link id is required for ambiguous context';
            elsif child_group_link_count = 1 then
              select group_link.id
              into child_group_link_id
              from public.child_group_links group_link
              where group_link.child_unit_link_id = child_unit_link_id
                and group_link.status = 'active'
              order by group_link.created_at, group_link.id
              limit 1;
            end if;
          end if;
          if child_group_link_id is not null then
            if not exists (
              select 1
              from public.child_group_links group_link
              where group_link.id = child_group_link_id
                and group_link.child_unit_link_id = child_unit_link_id
            ) then
              raise no_data_found using
                message = 'child group link not found for unit link';
            end if;
            update public.child_group_links group_link
            set
              group_id = coalesce(group_id, group_link.group_id),
              status = case
                when group_id is null
                  then 'inactive'::public.record_status
                else 'active'::public.record_status
              end,
              updated_at = clock_timestamp()
            where group_link.id = child_group_link_id;
          elsif group_id is not null then
            insert into public.child_group_links(
              child_unit_link_id,
              group_id,
              status
            )
            values (child_unit_link_id, group_id, 'active')
            on conflict on constraint child_group_links_child_unit_link_id_group_id_key
            do update set
              status = 'active',
              updated_at = clock_timestamp()
            returning id into child_group_link_id;
          end if;
        end if;
      else
        raise invalid_parameter_value using message = 'unsupported child context operation';
      end if;
    else
      raise invalid_parameter_value using
        message = 'context change does not match person type';
    end if;

    insert into audit.audit_logs(
      actor_person_id,
      actor_membership_id,
      mfa_aal,
      action_code,
      object_type,
      object_id,
      institution_id,
      outcome,
      after_json
    )
    values (
      actor_person_id,
      case
        when current_person.person_type = 'adult'
          then app_private.platform_permission_membership_id(
            'people.memberships.manage'
          )
        else app_private.platform_permission_membership_id(
          'people.child_contexts.manage'
        )
      end,
      auth.jwt() ->> 'aal',
      case
        when current_person.person_type = 'adult'
          then 'people.membership.context.' || (change ->> 'operation')
        else 'people.child_context.context.' || (change ->> 'operation')
      end,
      case
        when current_person.person_type = 'adult'
          then 'institution_role_assignments'
        else 'child_contexts'
      end,
      case
        when current_person.person_type = 'adult' then assignment.id
        else child_context.id
      end,
      case
        when current_person.person_type = 'adult'
          then membership.institution_id
        else child_context.institution_id
      end,
      'success',
      jsonb_build_object(
        'operation', change ->> 'operation',
        'changed_fields', case
          when current_person.person_type = 'adult'
            then jsonb_build_array('role', 'scope')
          else jsonb_build_array('institution', 'unit', 'group')
        end
      )
    );
  end loop;

  insert into audit.audit_logs(
    actor_person_id,
    actor_membership_id,
    mfa_aal,
    action_code,
    object_type,
    object_id,
    outcome,
    before_json,
    after_json
  )
  values (
    actor_person_id,
    actor_platform_membership_id,
    auth.jwt() ->> 'aal',
    'people.update',
    'people',
    p_person_id,
    'success',
    jsonb_build_object('expected_updated_at', p_expected_updated_at),
    jsonb_build_object(
      'changed_fields', to_jsonb(changed_fields),
      'context_operation_count',
        jsonb_array_length(coalesce(p_context_changes, '[]'::jsonb))
    )
  );

  return jsonb_build_object(
    'id', updated_person.id,
    'person_type', updated_person.person_type,
    'display_name', updated_person.display_name,
    'status', updated_person.status,
    'updated_at', updated_person.updated_at
  );
end
$$;

-- app_private.update_unit_for_superadmin [UNIT]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "app_private"."update_unit_for_superadmin"("p_request_id" "uuid", "p_payload" "jsonb", "p_unit_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid:=app_private.current_person_id();u public.units%rowtype;plan_id uuid;type_id uuid;h bytea;
prior app_private.unit_management_command_receipts%rowtype;result jsonb;begin
select*into u from public.units where id=p_unit_id;if u.id is null then raise no_data_found using message='unit not found';end if;
if p_request_id is null or actor is null or(select auth.uid())is null or not app_private.has_scoped_platform_permission('units.update',u.institution_id)
or not app_private.has_mfa_aal2()then raise insufficient_privilege using message='units.update and AAL2 required';end if;
if p_payload?'institution_id'and(p_payload->>'institution_id')::uuid<>u.institution_id then raise invalid_parameter_value using message='use transfer command';end if;
if p_payload?'handle'then raise invalid_parameter_value using message='use handle command';end if;
perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
h:=app_private.unit_management_hash(jsonb_build_object('unit_id',p_unit_id,'expected_version',p_expected_version,'payload',p_payload));
select*into prior from app_private.unit_management_command_receipts where request_id=p_request_id;
if prior.request_id is not null then if prior.actor_person_id<>actor or prior.command_kind<>'update'or prior.unit_id<>p_unit_id or prior.request_hash<>h
then raise invalid_parameter_value using message='request replay mismatch';end if;return app_private.unit_form_payload(prior.unit_id);end if;
select*into u from public.units where id=p_unit_id for update;if u.management_version<>p_expected_version then raise exception using errcode='PT409', message='stale unit version', detail='UNIT_STALE_VERSION';end if;
plan_id:=case when p_payload?'plan_override_id'then nullif(p_payload->>'plan_override_id','')::uuid else u.plan_override_id end;
type_id:=case when p_payload?'unit_type_id'then(p_payload->>'unit_type_id')::uuid else u.unit_type_id end;
if plan_id is distinct from u.plan_override_id and(not app_private.has_platform_permission('units.plan.manage')
or(plan_id is not null and not app_private.unit_plan_is_available(plan_id,u.institution_id)))
then raise insufficient_privilege using message='units.plan.manage and available plan required';end if;
update public.units x set name=coalesce(nullif(btrim(p_payload->>'name'),''),x.name),
slug=coalesce(nullif(lower(btrim(p_payload->>'slug')),''),x.slug),
status=case when p_payload?'unit_status'then(p_payload->>'unit_status')::public.record_status else x.status end,
unit_type_id=type_id,unit_type_other_description=case when p_payload?'unit_type_other_description'
then nullif(btrim(p_payload->>'unit_type_other_description'),'')else x.unit_type_other_description end,
plan_override_id=plan_id,timezone=case when p_payload?'timezone'then p_payload->>'timezone'else x.timezone end,
public_discovery_enabled=coalesce((p_payload#>>'{public_profile,discovery_enabled}')::boolean,x.public_discovery_enabled),
public_address_visible=coalesce((p_payload#>>'{public_profile,address_visible}')::boolean,x.public_address_visible),
public_contact_visible=coalesce((p_payload#>>'{public_profile,contact_visible}')::boolean,x.public_contact_visible),
inherit_address=coalesce((p_payload#>>'{inheritance,address}')::boolean,x.inherit_address),
inherit_contact=coalesce((p_payload#>>'{inheritance,contact}')::boolean,x.inherit_contact),
inherit_branding=coalesce((p_payload#>>'{inheritance,branding}')::boolean,x.inherit_branding),
inherit_representatives=coalesce((p_payload#>>'{inheritance,representatives}')::boolean,x.inherit_representatives),
inherit_administrators=coalesce((p_payload#>>'{inheritance,administrators}')::boolean,x.inherit_administrators),
inherit_plan=plan_id is null,management_version=x.management_version+1,updated_at=now()where id=p_unit_id;
perform app_private.persist_unit_children(p_unit_id,actor,p_payload);result:=app_private.unit_form_payload(p_unit_id);
insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,before_json,after_json)
values(actor,'aal2','unit.update','unit',p_unit_id,u.institution_id,'success',jsonb_build_object('management_version',u.management_version),
jsonb_build_object('management_version',result->'management_version'));
insert into app_private.unit_management_command_receipts values(p_request_id,h,actor,'update',p_unit_id,(result->>'management_version')::bigint,now());return result;end$$;

-- public.close_circular_responses [CIRCULAR]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."close_circular_responses"("p_request_id" "uuid", "p_circular_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare target public.circulars%rowtype; actor record;
begin
  select * into target from public.circulars c where c.id=p_circular_id and c.deleted_at is null for update;
  select * into actor from app_private.circular_actor(target.institution_id,'circulars.circulars.manage',target.unit_id,target.group_id);
  if target.management_version<>p_expected_version or target.current_revision_id is null then raise exception using errcode='PT409', message='expected_version_conflict', detail='CIRCULAR_STALE_VERSION'; end if;
  update public.circulars set status='closed',responses_closed_at=now(),responses_closed_by=actor.person_id,management_version=management_version+1,updated_at=now() where id=target.id returning * into target;
  insert into app_private.circular_audit(circular_id,revision_id,institution_id,actor_person_id,event_code,detail) values(target.id,target.current_revision_id,target.institution_id,actor.person_id,'responses_closed',jsonb_build_object('request_id',p_request_id));
  return jsonb_build_object('id',target.id,'status',target.status,'version',target.management_version);
end $$;

-- public.delete_circular [CIRCULAR]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."delete_circular"("p_request_id" "uuid", "p_circular_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare target public.circulars%rowtype; actor record; response jsonb; fingerprint text; prior_fingerprint text;
begin
  select * into target from public.circulars c where c.id=p_circular_id for update;
  if target.id is null then raise insufficient_privilege using message='circular_not_found'; end if;
  select * into actor from app_private.circular_actor(target.institution_id,'circulars.circulars.create',target.unit_id,target.group_id);
  if target.author_person_id<>actor.person_id and not app_private.has_institution_permission(target.institution_id,'circulars.circulars.manage',target.unit_id,target.group_id,false)
  then raise insufficient_privilege using message='circular_manage_denied'; end if;
  fingerprint:=pg_catalog.encode(extensions.digest(pg_catalog.convert_to(p_circular_id::text||p_expected_version::text,'UTF8'),'sha256'),'hex');
  select receipt.response,receipt.request_fingerprint into response,prior_fingerprint
  from app_private.circular_command_receipts receipt
  where receipt.actor_person_id=actor.person_id and receipt.command_name='delete' and receipt.request_id=p_request_id;
  if response is not null then
    if prior_fingerprint<>fingerprint then raise unique_violation using message='request_id_conflict'; end if;
    return response;
  end if;
  if target.deleted_at is not null or target.management_version<>p_expected_version then raise exception using errcode='PT409', message='expected_version_conflict', detail='CIRCULAR_STALE_VERSION'; end if;
  if target.current_revision_id is null and not exists(select 1 from public.circular_response_sessions session where session.circular_id=target.id) then
    update public.circular_media_assets set status='orphaned' where circular_id=target.id and status in ('pending','ready');
  end if;
  update public.circulars set status='archived',deleted_at=now(),management_version=management_version+1,updated_at=now()
  where id=target.id returning * into target;
  response:=jsonb_build_object('id',target.id,'version',target.management_version,'status',target.status,'deleted',true);
  insert into app_private.circular_command_receipts(actor_person_id,command_name,request_id,request_fingerprint,response)
  values(actor.person_id,'delete',p_request_id,fingerprint,response);
  insert into app_private.circular_audit(circular_id,revision_id,institution_id,actor_person_id,event_code,detail)
  values(target.id,target.current_revision_id,target.institution_id,actor.person_id,'circular_deleted',jsonb_build_object('logical',true));
  return response;
end $$;

-- public.publish_circular [CIRCULAR]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."publish_circular"("p_request_id" "uuid", "p_circular_id" "uuid", "p_expected_version" bigint, "p_publish_at" timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare target public.circulars%rowtype; revision public.circular_revisions%rowtype; actor record; at timestamptz:=coalesce(p_publish_at,now()); next_status public.circular_status; response jsonb; fingerprint text; prior_fingerprint text;
begin
  select * into target from public.circulars c where c.id=p_circular_id and c.deleted_at is null for update;
  select * into actor from app_private.circular_actor(target.institution_id,'circulars.circulars.publish',target.unit_id,target.group_id);
  fingerprint:=pg_catalog.encode(extensions.digest(pg_catalog.convert_to(p_circular_id::text||p_expected_version::text||coalesce(p_publish_at::text,'immediate'),'UTF8'),'sha256'),'hex');
  select receipt.response,receipt.request_fingerprint into response,prior_fingerprint from app_private.circular_command_receipts receipt where receipt.actor_person_id=actor.person_id and receipt.command_name='publish' and receipt.request_id=p_request_id;
  if response is not null then
    if prior_fingerprint<>fingerprint then raise unique_violation using message='request_id_conflict'; end if;
    return response;
  end if;
  if target.management_version<>p_expected_version or target.working_revision_id is null then raise exception using errcode='PT409', message='expected_version_conflict', detail='CIRCULAR_STALE_VERSION'; end if;
  select * into revision from public.circular_revisions r where r.id=target.working_revision_id and r.status='working';
  if revision.id is null or not exists(select 1 from public.circular_audience_rules a where a.circular_id=target.id and a.revision_id=revision.id) then raise check_violation using message='circular_incomplete'; end if;
  if exists(select 1 from public.circular_questions q where q.revision_id=revision.id and (select count(*) from public.circular_question_options o where o.question_id=q.id) not between 2 and 10)
  then raise check_violation using message='circular_question_invalid'; end if;
  if exists(select 1 from public.circular_media_links l join public.circular_media_assets m on m.id=l.media_asset_id where l.revision_id=revision.id and m.status<>'ready')
  then raise check_violation using message='circular_media_not_ready'; end if;
  update public.circular_revisions set status='superseded' where circular_id=target.id and status='published';
  update public.circular_revisions set status='published',published_at=now() where id=revision.id;
  next_status:=case when at>now() then 'scheduled'::public.circular_status else 'published'::public.circular_status end;
  update public.circulars set status=next_status,current_revision_id=revision.id,working_revision_id=null,publish_at=case when published_at is null then at else publish_at end,
    published_at=coalesce(published_at,case when at<=now() then now() end),revised_at=case when published_at is not null then now() end,
    management_version=management_version+1,updated_at=now() where id=target.id returning * into target;
  response:=jsonb_build_object('id',target.id,'revision_id',revision.id,'version',target.management_version,'status',target.status,'publish_at',target.publish_at);
  insert into app_private.circular_command_receipts(actor_person_id,command_name,request_id,request_fingerprint,response)
  values(actor.person_id,'publish',p_request_id,fingerprint,response);
  insert into app_private.circular_audit(circular_id,revision_id,institution_id,actor_person_id,event_code,detail)
  values(target.id,revision.id,target.institution_id,actor.person_id,case when next_status='scheduled' then 'circular_scheduled' else 'circular_published' end,jsonb_build_object('publish_at',at));
  return response;
end $$;

-- public.publish_happens_post [HAPPENS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."publish_happens_post"("p_request_id" "uuid", "p_post_id" "uuid", "p_expected_version" bigint, "p_publish_at" timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare target public.posts%rowtype;actor record;at timestamptz:=coalesce(p_publish_at,now());next_status public.happens_post_status;
begin
  select * into target from public.posts where id=p_post_id for update;
  select * into actor from app_private.happens_actor(target.institution_id,'happens.posts.publish',target.unit_id,target.group_id);
  if target.author_person_id<>actor.person_id or target.management_version<>p_expected_version then raise exception using errcode='PT409', message='expected_version_conflict', detail='HAPPENS_STALE_VERSION';end if;
  if not exists(select 1 from public.post_audiences where post_id=target.id) then raise check_violation using message='audience_required';end if;
  if target.caption='' and not exists(select 1 from public.media_links where post_id=target.id) then raise check_violation using message='content_required';end if;
  next_status:=case when at>now() then 'scheduled'::public.happens_post_status else 'published'::public.happens_post_status end;
  update public.posts set status=next_status,publish_at=at,published_at=case when next_status='published' then now() end,management_version=management_version+1,updated_at=now() where id=target.id returning * into target;
  insert into app_private.happens_publication_audit(post_id,institution_id,actor_person_id,event_code,detail) values(target.id,target.institution_id,actor.person_id,case when next_status='scheduled' then 'post_scheduled' else 'post_published' end,jsonb_build_object('request_id',p_request_id,'publish_at',at));
  return jsonb_build_object('id',target.id,'status',target.status,'publish_at',target.publish_at);
end $$;

-- public.publish_moment [MOMENTS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."publish_moment"("p_request_id" "uuid", "p_publication_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  actor record;
  target public.moments_publications%rowtype;
  fingerprint text;
  prior record;
  receipt_id uuid := gen_random_uuid();
  result jsonb;
begin
  select * into target from public.moments_publications publication
  where publication.id = p_publication_id for update;
  if target.id is null then raise insufficient_privilege using message = 'publication_not_authorized'; end if;
  select * into actor from app_private.moments_actor(
    target.institution_id, 'moments.publications.publish', target.unit_id, target.group_id
  );
  fingerprint := app_private.moments_request_fingerprint(jsonb_build_object(
    'publication_id', p_publication_id,
    'expected_version', p_expected_version
  ));
  perform pg_advisory_xact_lock(hashtextextended(actor.person_id::text || p_request_id::text, 0));
  select receipt.request_fingerprint, receipt.response into prior
  from app_private.moments_command_receipts receipt
  where receipt.actor_person_id = actor.person_id
    and receipt.command_name = 'publish'
    and receipt.request_id = p_request_id;
  if prior.response is not null then
    if prior.request_fingerprint <> fingerprint then
      raise unique_violation using message = 'idempotency_key_reused';
    end if;
    return prior.response;
  end if;
  if target.author_person_id <> actor.person_id
    or target.status <> 'draft'
    or target.management_version <> p_expected_version then
    raise exception using errcode='PT409', message = 'expected_version_conflict', detail='MOMENTS_STALE_VERSION';
  end if;
  if not exists (
    select 1 from public.moments_publication_audiences audience
    where audience.publication_id = target.id
  ) then raise check_violation using message = 'audience_required'; end if;
  if not exists (
    select 1 from public.moments_media_links link
    join public.moments_media_assets asset on asset.id = link.media_asset_id
    where link.publication_id = target.id and asset.status = 'ready'
  ) then raise check_violation using message = 'media_required'; end if;

  update public.moments_publications publication set
    status = 'published',
    published_at = now(),
    management_version = publication.management_version + 1,
    updated_at = now()
  where publication.id = target.id
  returning * into target;
  result := jsonb_build_object(
    'publication_id', target.id,
    'status', target.status,
    'version', target.management_version,
    'published_at', target.published_at,
    'receipt_id', receipt_id
  );
  insert into app_private.moments_command_receipts (
    id, actor_person_id, institution_id, command_name,
    request_id, request_fingerprint, response
  ) values (
    receipt_id, actor.person_id, target.institution_id, 'publish',
    p_request_id, fingerprint, result
  );
  insert into app_private.moments_publication_audit (
    publication_id, institution_id, actor_person_id, receipt_id, event_code, detail
  ) values (
    target.id, target.institution_id, actor.person_id, receipt_id,
    'moment_published', jsonb_build_object('version', target.management_version)
  );
  return result;
end
$$;

-- public.publish_now [NOW]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."publish_now"("p_request_id" "uuid", "p_publication_id" "uuid", "p_expected_version" bigint, "p_publish_at" timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare target public.now_publications%rowtype;actor record;at timestamptz:=coalesce(p_publish_at,now());next_status public.now_publication_status;result jsonb;
begin
  select * into target from public.now_publications where id=p_publication_id for update;
  if target.id is null then raise insufficient_privilege using message='publication_not_authorized';end if;
  select * into actor from app_private.now_actor(target.institution_id,'now.publications.publish',target.unit_id,target.group_id);
  select response into result from app_private.now_publication_audit
    where actor_person_id=actor.person_id and event_code in('now_scheduled','now_published') and request_id=p_request_id;
  if result is not null then return result; end if;
  if target.author_person_id<>actor.person_id or target.management_version<>p_expected_version then raise exception using errcode='PT409', message='expected_version_conflict', detail='NOW_STALE_VERSION';end if;
  if not exists(select 1 from public.now_publication_audiences where publication_id=target.id) then raise check_violation using message='audience_required';end if;
  if not exists(select 1 from public.now_media_assets where publication_id=target.id and kind='media' and status='ready') then raise check_violation using message='media_required';end if;
  next_status:=case when at>now() then 'scheduled'::public.now_publication_status else 'published'::public.now_publication_status end;
  update public.now_publications set status=next_status,publish_at=at,published_at=case when next_status='published' then now() end,
    expires_at=case when next_status='published' then now()+interval '24 hours' else at+interval '24 hours' end,management_version=management_version+1,updated_at=now()
    where id=target.id returning * into target;
  result:=jsonb_build_object('id',target.id,'status',target.status,'publish_at',target.publish_at,'expires_at',target.expires_at);
  insert into app_private.now_publication_audit(publication_id,institution_id,actor_person_id,event_code,request_id,response,detail)
    values(target.id,target.institution_id,actor.person_id,case when next_status='scheduled' then 'now_scheduled' else 'now_published' end,p_request_id,result,jsonb_build_object('publish_at',at,'expires_at',target.expires_at));
  return result;
end $$;

-- public.publish_profile_about [PROFILE_ABOUT]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."publish_profile_about"("p_subject_type" "text", "p_subject_id" "uuid", "p_expected_version" bigint, "p_request_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor uuid:=app_private.current_person_id(); p public.profile_about_pages; next_version bigint;
 result jsonb; stored_hash text; request_hash text:=md5('publish:'||coalesce(p_subject_type,'')||':'||coalesce(p_subject_id::text,'')||':'||coalesce(p_expected_version::text,''));
begin
 if actor is null or p_request_id is null then raise insufficient_privilege; end if;
 if p_subject_type='person' then raise insufficient_privilege using message='person About is not released'; end if;
 select page.* into p from public.profile_about_pages page where page.subject_type=p_subject_type and
  case p_subject_type when 'institution' then page.institution_subject_id=p_subject_id
   when 'unit' then page.unit_subject_id=p_subject_id when 'group' then page.group_subject_id=p_subject_id
   when 'activity' then page.activity_subject_id=p_subject_id else false end for update;
 if p.id is null or not app_private.profile_about_can(p.institution_id,'profiles.about.publish',p.unit_subject_id,p.group_subject_id,p.activity_subject_id) then raise insufficient_privilege; end if;
 select r.result_json,r.request_hash into result,stored_hash from app_private.profile_about_command_receipts r
 where r.request_id=p_request_id and r.actor_person_id=actor;
 if result is not null then
  if stored_hash<>request_hash then raise unique_violation using message='request_id reused with different payload'; end if;
  return result;
 end if;
 if p.version<>p_expected_version then raise exception using errcode='PT409', message='profile about version conflict', detail='PROFILE_ABOUT_STALE_VERSION'; end if;
 next_version:=p.version+1;
 update public.profile_about_sections set state='published',revision=next_version,updated_by_person_id=actor,updated_at=now()
 where page_id=p.id and state='draft';
 update public.profile_about_pages set state='published',version=next_version,published_at=now(),updated_at=now(),updated_by_person_id=actor where id=p.id;
 insert into public.profile_about_revisions(page_id,version,actor_person_id,command_kind,snapshot)
 values(p.id,next_version,actor,'publish',jsonb_build_object('state','published','published_section_ids',coalesce((select jsonb_agg(s.id order by s.position) from public.profile_about_sections s where s.page_id=p.id and s.state='published'),'[]'::jsonb)));
 result:=jsonb_build_object('page_id',p.id,'version',next_version,'state','published');
 insert into app_private.profile_about_command_receipts values(p_request_id,actor,request_hash,result,now());
 insert into audit.profile_about_commands(request_id,actor_person_id,page_id,command_kind,destinations)
 values(p_request_id,actor,p.id,'publish',jsonb_build_object('about','published'));
 return result;
end$$;

-- public.remove_now_publication [NOW]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."remove_now_publication"("p_request_id" "uuid", "p_publication_id" "uuid", "p_expected_version" bigint, "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  target public.now_publications%rowtype;
  asset public.now_media_assets%rowtype;
  actor record;
  cached jsonb;
  normalized_reason text;
  purge_jobs integer:=0;
  purge_status text;
  result jsonb;
begin
  if p_request_id is null or p_publication_id is null then
    raise invalid_parameter_value using message='invalid_request';
  end if;
  select * into target from public.now_publications where id=p_publication_id for update;
  if not found then
    raise insufficient_privilege using message='now_remove_denied';
  end if;
  -- A autorizacao ocorre antes de qualquer resposta dependente do recurso.
  -- O ator deve ter a capacidade no mesmo tenant/contexto; a politica permite
  -- autor ou papel institucional explicitamente autorizado.
  select * into actor from app_private.now_actor(
    target.institution_id,'now.publications.remove',target.unit_id,target.group_id);
  select response into cached from app_private.now_publication_audit
    where actor_person_id=actor.person_id and event_code='publication_removed'
      and request_id=p_request_id;
  if cached is not null then return cached; end if;
  if p_expected_version is null or target.management_version is distinct from p_expected_version then
    raise exception using errcode='PT409', message='expected_version_conflict', detail='NOW_STALE_VERSION';
  end if;
  if target.status not in ('scheduled','published') then
    raise check_violation using message='publication_not_removable';
  end if;
  normalized_reason:=nullif(btrim(coalesce(p_reason,'')),'');
  if normalized_reason is not null and char_length(normalized_reason)>280 then
    raise check_violation using message='reason_too_long';
  end if;
  update public.now_publications
  set status='removed',removed_at=now(),removed_by_person_id=actor.person_id,
      removal_reason=normalized_reason,management_version=management_version+1,updated_at=now()
  where id=target.id returning * into target;

  -- Negacao logica imediata, inclusive para tickets ja emitidos. O catalogo
  -- de assets nao e apagado para preservar ownership e auditoria.
  delete from app_private.now_media_read_tickets
    where media_asset_id in (select id from public.now_media_assets where publication_id=target.id);
  for asset in
    select * from public.now_media_assets where publication_id=target.id and status<>'deleted' for update
  loop
    update public.now_media_assets set status='deleted' where id=asset.id;
    if asset.storage_provider in ('r2','supabase_mvp') then
      insert into app_private.now_media_purge_jobs(
        request_id,publication_id,media_asset_id,institution_id,storage_provider,bucket_id,object_key)
      values(p_request_id,target.id,asset.id,target.institution_id,asset.storage_provider,asset.bucket_id,asset.object_key)
      on conflict(publication_id,media_asset_id) do nothing;
      purge_jobs:=purge_jobs+1;
    end if;
  end loop;
  purge_status:=case when purge_jobs=0 then 'not_applicable' else 'queued' end;
  result:=jsonb_build_object(
    'id',target.id,'status',target.status,'removed_at',target.removed_at,
    'management_version',target.management_version,'purge_status',purge_status,
    'purge_job_count',purge_jobs);
  insert into app_private.now_publication_audit(
    publication_id,institution_id,actor_person_id,event_code,request_id,response,detail)
  values(target.id,target.institution_id,actor.person_id,'publication_removed',p_request_id,result,
    jsonb_build_object('action_id','agora.remove','outcome','success','request_id',p_request_id,
      'previous_version',p_expected_version,'management_version',target.management_version,
      'removal_reason',normalized_reason,'purge_status',purge_status,
      'purge_job_count',purge_jobs,'stream_status','not_applicable'));
  return result;
end $$;

-- public.save_circular_draft [CIRCULAR]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."save_circular_draft"("p_request_id" "uuid", "p_draft" "jsonb", "p_circular_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  actor record; target public.circulars%rowtype; revision public.circular_revisions%rowtype;
  institution uuid:=(p_draft->>'institution_id')::uuid; unit uuid:=nullif(p_draft->>'unit_id','')::uuid;
  grp uuid:=nullif(p_draft->>'group_id','')::uuid; activity uuid:=nullif(p_draft->>'activity_id','')::uuid;
  block jsonb; question jsonb; option jsonb; audience jsonb; audience_rule public.circular_audience_rules%rowtype; asset_id uuid;
  block_count int:=0; option_count int:=0; question_count int:=0; media_count int:=0; body text:=''; response jsonb; fingerprint text; prior_fingerprint text;
begin
  perform app_private.circular_validate_scope(institution,unit,grp,activity);
  select * into actor from app_private.circular_actor(institution,'circulars.circulars.create',unit,grp);
  fingerprint:=pg_catalog.encode(extensions.digest(pg_catalog.convert_to(coalesce(p_draft,'{}'::jsonb)::text,'UTF8'),'sha256'),'hex');
  select receipt.response,receipt.request_fingerprint into response,prior_fingerprint from app_private.circular_command_receipts receipt
  where receipt.actor_person_id=actor.person_id and receipt.command_name='save_draft' and receipt.request_id=p_request_id;
  if response is not null then
    if prior_fingerprint<>fingerprint then raise unique_violation using message='request_id_conflict'; end if;
    return response;
  end if;
  if char_length(btrim(coalesce(p_draft->>'title',''))) not between 1 and 120 then raise check_violation using message='circular_title_invalid'; end if;
  if jsonb_array_length(coalesce(p_draft->'blocks','[]'))>64 then raise check_violation using message='circular_blocks_invalid'; end if;
  for block in select value from jsonb_array_elements(coalesce(p_draft->'blocks','[]')) loop
    if block->>'kind'='text' then body:=body||coalesce(block->>'text',''); end if;
    if block->>'kind'='media' then media_count:=media_count+jsonb_array_length(coalesce(block->'asset_ids','[]')); end if;
    if block->>'kind'='question' then question_count:=question_count+1; end if;
  end loop;
  if char_length(body)>10000 then raise check_violation using message='circular_body_too_long'; end if;
  if media_count>4 then raise check_violation using message='circular_media_limit'; end if;
  if question_count>10 then raise check_violation using message='circular_question_limit'; end if;

  if p_circular_id is null then
    insert into public.circulars(institution_id,unit_id,group_id,activity_id,author_person_id,author_membership_id,response_policy,publish_at,responses_close_at)
    values(institution,unit,grp,activity,actor.person_id,actor.membership_id,(p_draft->>'response_policy')::public.circular_response_policy,nullif(p_draft->>'publish_at','')::timestamptz,nullif(p_draft->>'responses_close_at','')::timestamptz)
    returning * into target;
    insert into public.circular_revisions(circular_id,institution_id,revision_number,title,body_text,created_by_person_id)
    values(target.id,institution,1,btrim(p_draft->>'title'),body,actor.person_id) returning * into revision;
  else
    select * into target from public.circulars c where c.id=p_circular_id and c.institution_id=institution and c.deleted_at is null for update;
    if target.id is null or target.management_version<>p_expected_version then raise exception using errcode='PT409', message='expected_version_conflict', detail='CIRCULAR_STALE_VERSION'; end if;
    if target.unit_id is distinct from unit or target.group_id is distinct from grp or target.activity_id is distinct from activity
    then raise insufficient_privilege using message='circular_scope_immutable'; end if;
    if target.author_person_id<>actor.person_id and not app_private.has_institution_permission(institution,'circulars.circulars.manage',unit,grp,false)
    then raise insufficient_privilege using message='circular_manage_denied'; end if;
    if target.working_revision_id is null then
      insert into public.circular_revisions(circular_id,institution_id,revision_number,title,body_text,created_by_person_id)
      values(target.id,institution,(select coalesce(max(r.revision_number),0)+1 from public.circular_revisions r where r.circular_id=target.id),btrim(p_draft->>'title'),body,actor.person_id)
      returning * into revision;
    else
      select * into revision from public.circular_revisions r where r.id=target.working_revision_id and r.status='working';
      if revision.id is null then raise check_violation using message='published_revision_immutable'; end if;
      update public.circular_revisions set title=btrim(p_draft->>'title'),body_text=body where id=revision.id;
      delete from public.circular_blocks where revision_id=revision.id;
    end if;
    update public.circulars set response_policy=(p_draft->>'response_policy')::public.circular_response_policy,
      publish_at=nullif(p_draft->>'publish_at','')::timestamptz,responses_close_at=nullif(p_draft->>'responses_close_at','')::timestamptz,
      management_version=management_version+1,updated_at=now() where id=target.id returning * into target;
    delete from public.circular_audience_rules where revision_id=revision.id;
  end if;
  update public.circulars set working_revision_id=revision.id where id=target.id;

  for block in select value from jsonb_array_elements(coalesce(p_draft->'blocks','[]')) loop
    block_count:=block_count+1;
    if block->>'kind' not in ('text','media','question') then raise check_violation using message='circular_block_kind_invalid'; end if;
    insert into public.circular_blocks(id,revision_id,block_kind,display_order,text_content)
    values((block->>'id')::uuid,revision.id,(block->>'kind')::public.circular_block_kind,block_count-1,case when block->>'kind'='text' then coalesce(block->>'text','') end);
    if block->>'kind'='media' then
      for asset_id in select value::uuid from jsonb_array_elements_text(coalesce(block->'asset_ids','[]')) loop
        insert into public.circular_media_links(revision_id,block_id,media_asset_id,display_order)
        select revision.id,(block->>'id')::uuid,asset.id,(select count(*)::smallint from public.circular_media_links link where link.revision_id=revision.id)
        from public.circular_media_assets asset
        where asset.id=asset_id and asset.circular_id=target.id and asset.owner_person_id=actor.person_id and asset.status<>'deleted';
        if not found then raise insufficient_privilege using message='media_asset_scope_invalid'; end if;
      end loop;
    elsif block->>'kind'='question' then
      question:=block->'question';
      if char_length(btrim(coalesce(question->>'prompt',''))) not between 1 and 240 then raise check_violation using message='circular_question_invalid'; end if;
      if jsonb_array_length(coalesce(question->'options','[]')) not between 2 and 10 then raise check_violation using message='circular_option_count_invalid'; end if;
      insert into public.circular_questions(id,revision_id,block_id,question_kind,prompt,required)
      values((question->>'id')::uuid,revision.id,(block->>'id')::uuid,(question->>'kind')::public.circular_question_kind,btrim(question->>'prompt'),coalesce((question->>'required')::boolean,false));
      option_count:=0;
      for option in select value from jsonb_array_elements(question->'options') loop
        option_count:=option_count+1;
        insert into public.circular_question_options(id,question_id,label,display_order)
        values((option->>'id')::uuid,(question->>'id')::uuid,btrim(option->>'label'),option_count-1);
      end loop;
    end if;
  end loop;
  for audience in select value from jsonb_array_elements(coalesce(p_draft->'audiences','[]')) loop
    perform app_private.circular_validate_scope(
      institution,
      nullif(audience->>'unit_id','')::uuid,
      nullif(audience->>'group_id','')::uuid,
      nullif(audience->>'activity_id','')::uuid
    );
    audience_rule.circular_id:=target.id;
    audience_rule.revision_id:=revision.id;
    audience_rule.institution_id:=institution;
    audience_rule.audience_kind:=(audience->>'kind')::public.circular_audience_kind;
    audience_rule.scope_kind:=(audience->>'scope')::public.circular_scope_kind;
    audience_rule.unit_id:=nullif(audience->>'unit_id','')::uuid;
    audience_rule.group_id:=nullif(audience->>'group_id','')::uuid;
    audience_rule.activity_id:=nullif(audience->>'activity_id','')::uuid;
    if not app_private.circular_audience_scope_contained(target.unit_id,target.group_id,target.activity_id,audience_rule)
    then raise insufficient_privilege using message='circular_audience_scope_denied'; end if;
    perform * from app_private.circular_actor(
      institution,'circulars.circulars.create',
      coalesce(audience_rule.unit_id,case when audience_rule.scope_kind='activity' then target.unit_id end),
      coalesce(audience_rule.group_id,case when audience_rule.scope_kind='activity' then target.group_id end)
    );
    insert into public.circular_audience_rules(circular_id,revision_id,institution_id,audience_kind,scope_kind,unit_id,group_id,activity_id)
    values(audience_rule.circular_id,audience_rule.revision_id,audience_rule.institution_id,audience_rule.audience_kind,audience_rule.scope_kind,
      audience_rule.unit_id,audience_rule.group_id,audience_rule.activity_id);
  end loop;
  response:=jsonb_build_object('id',target.id,'revision_id',revision.id,'version',target.management_version,'status',target.status);
  insert into app_private.circular_command_receipts(actor_person_id,command_name,request_id,request_fingerprint,response)
  values(actor.person_id,'save_draft',p_request_id,fingerprint,response);
  insert into app_private.circular_audit(circular_id,revision_id,institution_id,actor_person_id,event_code,detail)
  values(target.id,revision.id,institution,actor.person_id,'draft_saved',jsonb_build_object('version',target.management_version));
  return response;
end $$;

-- public.save_circular_response_draft [CIRCULAR]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "public"."save_circular_response_draft"("p_request_id" "uuid", "p_revision_id" "uuid", "p_answers" "jsonb", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare target public.circulars%rowtype; actor record; unit record; session public.circular_response_sessions%rowtype; answer jsonb; option_id uuid; selected_count integer;
begin
  select c.* into target from public.circulars c join public.circular_revisions r on r.circular_id=c.id where r.id=p_revision_id and r.status='published';
  if target.id is null or target.responses_closed_at is not null or (target.responses_close_at is not null and target.responses_close_at<=now()) then raise check_violation using message='circular_responses_closed'; end if;
  select * into actor from app_private.circular_actor(target.institution_id,'circulars.circulars.respond',target.unit_id,target.group_id);
  if not app_private.circular_visible(target,actor.person_id,actor.role_code,target.unit_id,target.group_id,target.activity_id) then raise insufficient_privilege using message='circular_response_denied'; end if;
  select * into unit from app_private.circular_response_unit(p_revision_id,actor.person_id,p_answers);
  select * into session from public.circular_response_sessions s where s.revision_id=p_revision_id and s.response_unit_key=unit.unit_key for update;
  if session.id is null then
    if p_expected_version not in (0,1) then raise exception using errcode='PT409', message='expected_version_conflict', detail='CIRCULAR_STALE_VERSION'; end if;
    insert into public.circular_response_sessions(circular_id,revision_id,institution_id,response_unit_key,response_person_id,child_context_id,last_actor_person_id)
    values(target.id,p_revision_id,target.institution_id,unit.unit_key,unit.response_person_id,unit.child_context_id,actor.person_id) returning * into session;
  else
    if session.response_version<>p_expected_version then raise exception using errcode='PT409', message='expected_version_conflict', detail='CIRCULAR_STALE_VERSION'; end if;
    update public.circular_response_sessions set response_version=response_version+1,last_actor_person_id=actor.person_id,status='partial',updated_at=now() where id=session.id returning * into session;
    delete from public.circular_answers where session_id=session.id;
  end if;
  for answer in select value from jsonb_array_elements(coalesce(p_answers->'answers','[]')) loop
    if not exists(select 1 from public.circular_questions q where q.id=(answer->>'question_id')::uuid and q.revision_id=p_revision_id) then raise insufficient_privilege using message='question_scope_invalid'; end if;
    selected_count:=jsonb_array_length(coalesce(answer->'option_ids','[]'));
    if selected_count<1 or selected_count>10 then raise check_violation using message='answer_option_count_invalid'; end if;
    if (select q.question_kind from public.circular_questions q where q.id=(answer->>'question_id')::uuid)='single_choice' and selected_count<>1
    then raise check_violation using message='single_choice_invalid'; end if;
    insert into public.circular_answers(session_id,question_id) values(session.id,(answer->>'question_id')::uuid);
    for option_id in select value::uuid from jsonb_array_elements_text(coalesce(answer->'option_ids','[]')) loop
      insert into public.circular_answer_options(session_id,question_id,option_id) values(session.id,(answer->>'question_id')::uuid,option_id);
    end loop;
  end loop;
  insert into public.circular_response_revisions(session_id,response_version,actor_person_id,status,snapshot) values(session.id,session.response_version,actor.person_id,'partial',p_answers);
  return jsonb_build_object('session_id',session.id,'version',session.response_version,'status',session.status,'request_id',p_request_id);
end $$;

-- public.save_happens_draft [HAPPENS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."save_happens_draft"("p_request_id" "uuid", "p_draft" "jsonb", "p_post_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor record;target public.posts%rowtype;institution uuid:=(p_draft->>'institution_id')::uuid;unit uuid:=nullif(p_draft->>'unit_id','')::uuid;grp uuid:=nullif(p_draft->>'group_id','')::uuid;kind text;
begin
  if unit is not null and not exists(select 1 from public.units scoped_unit where scoped_unit.id=unit and scoped_unit.institution_id=institution) then raise insufficient_privilege using message='unit_scope_invalid';end if;
  if grp is not null and not exists(select 1 from public.groups scoped_group where scoped_group.id=grp and scoped_group.institution_id=institution and scoped_group.unit_id=unit) then raise insufficient_privilege using message='group_scope_invalid';end if;
  select * into actor from app_private.happens_actor(institution,'happens.posts.create',unit,grp);
  if char_length(coalesce(p_draft->>'caption',''))>2200 then raise check_violation using message='caption_too_long';end if;
  if p_post_id is null then
    insert into public.posts(institution_id,unit_id,group_id,author_person_id,author_membership_id,caption,publish_at)
    values(institution,unit,grp,actor.person_id,actor.membership_id,coalesce(p_draft->>'caption',''),nullif(p_draft->>'publish_at','')::timestamptz) returning * into target;
  else
    update public.posts set caption=coalesce(p_draft->>'caption',''),publish_at=nullif(p_draft->>'publish_at','')::timestamptz,
      management_version=management_version+1,updated_at=now()
    where id=p_post_id and institution_id=institution and author_person_id=actor.person_id and status='draft' and management_version=p_expected_version returning * into target;
    if target.id is null then raise exception using errcode='PT409', message='expected_version_conflict', detail='HAPPENS_STALE_VERSION';end if;
  end if;
  delete from public.post_audiences where post_id=target.id;
  for kind in select jsonb_array_elements_text(coalesce(p_draft->'audiences','[]')) loop
    insert into public.post_audiences(post_id,audience_kind,institution_id,unit_id,group_id) values(target.id,kind::public.happens_audience_kind,institution,unit,grp);
  end loop;
  insert into app_private.happens_publication_audit(post_id,institution_id,actor_person_id,event_code,detail) values(target.id,institution,actor.person_id,'draft_saved',jsonb_build_object('request_id',p_request_id,'version',target.management_version));
  return jsonb_build_object('id',target.id,'version',target.management_version);
end $$;

-- public.save_moments_draft [MOMENTS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."save_moments_draft"("p_request_id" "uuid", "p_draft" "jsonb", "p_publication_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  actor record;
  target public.moments_publications%rowtype;
  institution uuid := (p_draft ->> 'institution_id')::uuid;
  unit uuid := nullif(p_draft ->> 'unit_id', '')::uuid;
  scoped_group uuid := nullif(p_draft ->> 'group_id', '')::uuid;
  audience text;
  fingerprint text;
  prior record;
  receipt_id uuid := gen_random_uuid();
  result jsonb;
begin
  if p_request_id is null then raise invalid_parameter_value using message = 'request_id_required'; end if;
  if unit is not null and not exists (
    select 1 from public.units scoped_unit
    where scoped_unit.id = unit and scoped_unit.institution_id = institution
  ) then raise insufficient_privilege using message = 'unit_scope_invalid'; end if;
  if scoped_group is not null and not exists (
    select 1 from public.groups target_group
    where target_group.id = scoped_group
      and target_group.institution_id = institution
      and target_group.unit_id = unit
  ) then raise insufficient_privilege using message = 'group_scope_invalid'; end if;

  select * into actor from app_private.moments_actor(
    institution, 'moments.publications.create', unit, scoped_group
  );
  fingerprint := app_private.moments_request_fingerprint(jsonb_build_object(
    'draft', p_draft,
    'publication_id', p_publication_id,
    'expected_version', p_expected_version
  ));
  perform pg_advisory_xact_lock(hashtextextended(actor.person_id::text || p_request_id::text, 0));
  select receipt.request_fingerprint, receipt.response into prior
  from app_private.moments_command_receipts receipt
  where receipt.actor_person_id = actor.person_id
    and receipt.command_name = 'save_draft'
    and receipt.request_id = p_request_id;
  if prior.response is not null then
    if prior.request_fingerprint <> fingerprint then
      raise unique_violation using message = 'idempotency_key_reused';
    end if;
    return prior.response;
  end if;
  if char_length(coalesce(p_draft ->> 'caption', '')) > 2200 then
    raise check_violation using message = 'caption_too_long';
  end if;

  if p_publication_id is null then
    insert into public.moments_publications (
      institution_id, unit_id, group_id, author_person_id,
      author_membership_id, caption
    ) values (
      institution, unit, scoped_group, actor.person_id,
      actor.membership_id, coalesce(p_draft ->> 'caption', '')
    ) returning * into target;
  else
    update public.moments_publications publication set
      caption = coalesce(p_draft ->> 'caption', ''),
      management_version = publication.management_version + 1,
      updated_at = now()
    where publication.id = p_publication_id
      and publication.institution_id = institution
      and publication.author_person_id = actor.person_id
      and publication.status = 'draft'
      and publication.management_version = p_expected_version
    returning * into target;
    if target.id is null then
      raise exception using errcode='PT409', message = 'expected_version_conflict', detail='MOMENTS_STALE_VERSION';
    end if;
  end if;

  delete from public.moments_publication_audiences existing
  where existing.publication_id = target.id;
  for audience in
    select jsonb_array_elements_text(coalesce(p_draft -> 'audiences', '[]'))
  loop
    insert into public.moments_publication_audiences (
      publication_id, audience_kind, institution_id, unit_id, group_id
    ) values (
      target.id, audience::public.moments_audience_kind,
      institution, unit, scoped_group
    );
  end loop;

  result := jsonb_build_object(
    'id', target.id,
    'version', target.management_version,
    'receipt_id', receipt_id
  );
  insert into app_private.moments_command_receipts (
    id, actor_person_id, institution_id, command_name,
    request_id, request_fingerprint, response
  ) values (
    receipt_id, actor.person_id, institution, 'save_draft',
    p_request_id, fingerprint, result
  );
  insert into app_private.moments_publication_audit (
    publication_id, institution_id, actor_person_id, receipt_id, event_code, detail
  ) values (
    target.id, institution, actor.person_id, receipt_id, 'draft_saved',
    jsonb_build_object('version', target.management_version)
  );
  return result;
end
$$;

-- public.save_now_draft [NOW]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."save_now_draft"("p_request_id" "uuid", "p_draft" "jsonb", "p_publication_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor record;target public.now_publications%rowtype;institution uuid:=(p_draft->>'institution_id')::uuid;unit uuid:=nullif(p_draft->>'unit_id','')::uuid;grp uuid:=nullif(p_draft->>'group_id','')::uuid;kind text;result jsonb;
begin
  select * into actor from app_private.now_actor(institution,'now.publications.create',unit,grp);
  select response into result from app_private.now_publication_audit
    where actor_person_id=actor.person_id and event_code='draft_saved' and request_id=p_request_id;
  if result is not null then return result; end if;
  if char_length(coalesce(p_draft->>'caption',''))>60 or char_length(coalesce(p_draft->>'overlay_text',''))>60 then raise check_violation using message='text_too_long';end if;
  if p_publication_id is null then
    insert into public.now_publications(institution_id,unit_id,group_id,author_person_id,author_membership_id,caption,overlay_text,crop_scale,crop_x,crop_y,cover_position,publish_at)
    values(institution,unit,grp,actor.person_id,actor.membership_id,coalesce(p_draft->>'caption',''),coalesce(p_draft->>'overlay_text',''),
      coalesce((p_draft->>'crop_scale')::numeric,1),coalesce((p_draft->>'crop_x')::numeric,0),coalesce((p_draft->>'crop_y')::numeric,0),coalesce((p_draft->>'cover_position')::numeric,0),nullif(p_draft->>'publish_at','')::timestamptz) returning * into target;
  else
    update public.now_publications set caption=coalesce(p_draft->>'caption',''),overlay_text=coalesce(p_draft->>'overlay_text',''),
      crop_scale=coalesce((p_draft->>'crop_scale')::numeric,1),crop_x=coalesce((p_draft->>'crop_x')::numeric,0),crop_y=coalesce((p_draft->>'crop_y')::numeric,0),cover_position=coalesce((p_draft->>'cover_position')::numeric,0),
      publish_at=nullif(p_draft->>'publish_at','')::timestamptz,management_version=management_version+1,updated_at=now()
    where id=p_publication_id and institution_id=institution and author_person_id=actor.person_id and status='draft' and management_version=p_expected_version returning * into target;
    if target.id is null then raise exception using errcode='PT409', message='expected_version_conflict', detail='NOW_STALE_VERSION';end if;
  end if;
  delete from public.now_publication_audiences where publication_id=target.id;
  for kind in select jsonb_array_elements_text(coalesce(p_draft->'audiences','[]')) loop
    insert into public.now_publication_audiences(publication_id,audience_kind,institution_id,unit_id,group_id) values(target.id,kind::public.now_audience_kind,institution,unit,grp);
  end loop;
  result:=jsonb_build_object('id',target.id,'version',target.management_version,'max_video_seconds',app_private.now_max_video_seconds(institution));
  insert into app_private.now_publication_audit(publication_id,institution_id,actor_person_id,event_code,request_id,response,detail)
    values(target.id,institution,actor.person_id,'draft_saved',p_request_id,result,jsonb_build_object('version',target.management_version));
  return result;
end $$;

-- public.save_profile_about [PROFILE_ABOUT]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "public"."save_profile_about"("p_subject_type" "text", "p_subject_id" "uuid", "p_payload" "jsonb", "p_expected_version" bigint, "p_request_id" "uuid", "p_official_updates" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare actor uuid:=app_private.current_person_id(); p public.profile_about_pages; inst uuid; unit_id uuid; group_id uuid; activity_id uuid; item jsonb; next_version bigint; result jsonb; official jsonb:='[]'; stored_hash text; request_hash text:=md5(p_payload::text||p_official_updates::text);
begin
 if actor is null then raise insufficient_privilege; end if;
 if p_request_id is null or jsonb_typeof(p_payload)<>'object' or jsonb_typeof(coalesce(p_payload->'fields','[]'))<>'array' or jsonb_typeof(coalesce(p_payload->'sections','[]'))<>'array' then raise check_violation; end if;
 if coalesce(p_payload->>'state','draft')<>'draft' then raise check_violation using message='save_profile_about only accepts draft'; end if;
 if jsonb_array_length(coalesce(p_official_updates,'[]'))>0 and not app_private.has_mfa_aal2() then raise insufficient_privilege using message='MFA AAL2 required'; end if;
 if p_subject_type='person' then raise insufficient_privilege using message='person About is not released'; end if;
 select result_json,profile_about_command_receipts.request_hash into result,stored_hash from app_private.profile_about_command_receipts where request_id=p_request_id and actor_person_id=actor;
 if result is not null then
  if stored_hash<>request_hash then raise unique_violation using message='request_id reused with different payload'; end if;
  return result;
 end if;
 if p_subject_type='institution' then select id into inst from public.institutions where id=p_subject_id;
 elsif p_subject_type='unit' then select institution_id,id into inst,unit_id from public.units where id=p_subject_id;
 elsif p_subject_type='group' then select institution_id,unit_id,id into inst,unit_id,group_id from public.groups where id=p_subject_id;
 elsif p_subject_type='activity' then select institution_id,id into inst,activity_id from public.activity_definitions where id=p_subject_id;
 elsif p_subject_type='person' then select m.institution_id into inst from public.institution_memberships m where m.person_id=p_subject_id and m.status='active' and m.revoked_at is null order by m.created_at limit 1;
 end if;
 if inst is null or not app_private.profile_about_can(inst,'profiles.about.manage',unit_id,group_id,activity_id) then raise insufficient_privilege; end if;
 if jsonb_array_length(coalesce(p_official_updates,'[]'))>0 then
  if not app_private.profile_about_can(inst,'profiles.about.update_official_data',unit_id,group_id,activity_id) then raise insufficient_privilege using message='profiles.about.update_official_data required'; end if;
 end if;
 p:=app_private.profile_about_page_for(p_subject_type,p_subject_id);
 if p.id is null then
  if p_expected_version<>0 then raise exception using errcode='PT409', message='profile about version conflict', detail='PROFILE_ABOUT_STALE_VERSION'; end if;
  insert into public.profile_about_pages(institution_id,subject_type,institution_subject_id,unit_subject_id,group_subject_id,activity_subject_id,person_subject_id,created_by_person_id,updated_by_person_id)
  values(inst,p_subject_type,case when p_subject_type='institution' then p_subject_id end,unit_id,group_id,activity_id,case when p_subject_type='person' then p_subject_id end,actor,actor) returning * into p;
 elsif p.version<>p_expected_version then raise exception using errcode='PT409', message='profile about version conflict', detail='PROFILE_ABOUT_STALE_VERSION'; end if;
 next_version:=p.version+1;
 delete from public.profile_about_structured_fields where page_id=p.id;
 for item in select value from jsonb_array_elements(coalesce(p_payload->'fields','[]')) loop
  if not app_private.profile_about_allowed_field(p_subject_type,item->>'key') then raise check_violation using message='field not allowed for subject'; end if;
  insert into public.profile_about_structured_fields(page_id,field_key,value,latitude,longitude,visibility,origin,source_label,revision,created_by_person_id,updated_by_person_id)
  values(p.id,item->>'key',item->>'value',(item->>'latitude')::double precision,(item->>'longitude')::double precision,coalesce(item->>'visibility','profile_access'),coalesce(item->>'origin','manual'),item->>'source_label',next_version,actor,actor);
 end loop;
 delete from public.profile_about_sections where page_id=p.id;
 for item in select value from jsonb_array_elements(coalesce(p_payload->'sections','[]')) loop
  insert into public.profile_about_sections(id,page_id,section_type,title,body,items,position,visibility,state,origin,revision,created_by_person_id,updated_by_person_id)
  values(case when coalesce(item->>'id','')~*'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then (item->>'id')::uuid else gen_random_uuid() end,p.id,item->>'type',nullif(item->>'title',''),nullif(item->>'body',''),coalesce(array(select jsonb_array_elements_text(coalesce(item->'items','[]'))),'{}'),(item->>'position')::integer,coalesce(item->>'visibility','profile_access'),'draft',coalesce(item->>'origin','manual'),next_version,actor,actor);
 end loop;
 update public.profile_about_pages set version=next_version,state='draft',updated_by_person_id=actor,updated_at=now(),published_at=null where id=p.id;
 insert into public.profile_about_revisions(page_id,version,actor_person_id,command_kind,snapshot) values(p.id,next_version,actor,'save',p_payload);
 if jsonb_array_length(coalesce(p_official_updates,'[]'))>0 then
  for item in select value from jsonb_array_elements(p_official_updates) loop
   begin
    if p_subject_type='institution' and item->>'key' in('email','phone','mobile','website') then
     insert into public.institution_contacts(institution_id,email,phone,mobile_phone,website_url,status)
     values(inst,case when item->>'key'='email' then item->>'value' end,case when item->>'key'='phone' then item->>'value' end,case when item->>'key'='mobile' then item->>'value' end,case when item->>'key'='website' then item->>'value' end,'active')
     on conflict(institution_id) do update set email=coalesce(excluded.email,institution_contacts.email),phone=coalesce(excluded.phone,institution_contacts.phone),mobile_phone=coalesce(excluded.mobile_phone,institution_contacts.mobile_phone),website_url=coalesce(excluded.website_url,institution_contacts.website_url),updated_at=now();
    elsif p_subject_type='unit' and item->>'key' in('email','phone','mobile') then
     insert into public.unit_contacts(unit_id,email,phone,mobile_phone,status) values(unit_id,case when item->>'key'='email' then item->>'value' end,case when item->>'key'='phone' then item->>'value' end,case when item->>'key'='mobile' then item->>'value' end,'active')
     on conflict(unit_id) do update set email=coalesce(excluded.email,unit_contacts.email),phone=coalesce(excluded.phone,unit_contacts.phone),mobile_phone=coalesce(excluded.mobile_phone,unit_contacts.mobile_phone),updated_at=now();
    else raise feature_not_supported using message='official field has no approved mapping'; end if;
    official:=official||jsonb_build_array(jsonb_build_object('key',item->>'key','status','updated'));
   exception when others then official:=official||jsonb_build_array(jsonb_build_object('key',item->>'key','status','failed','message',sqlerrm)); end;
  end loop;
 end if;
 result:=jsonb_build_object('page_id',p.id,'version',next_version,'about','saved','official',official);
 insert into app_private.profile_about_command_receipts values(p_request_id,actor,request_hash,result,now());
 insert into audit.profile_about_commands(request_id,actor_person_id,page_id,command_kind,destinations) values(p_request_id,actor,p.id,'save',jsonb_build_object('about','saved','official',official));
 return result;
end$_$;

-- public.submit_circular_response [CIRCULAR]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."submit_circular_response"("p_request_id" "uuid", "p_session_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare session public.circular_response_sessions%rowtype; target public.circulars%rowtype; actor record; response_unit record;
begin
  select * into session from public.circular_response_sessions s where s.id=p_session_id for update;
  select * into target from public.circulars c where c.id=session.circular_id;
  select * into actor from app_private.circular_actor(target.institution_id,'circulars.circulars.respond',target.unit_id,target.group_id);
  if session.id is null or session.response_version<>p_expected_version or target.responses_closed_at is not null or (target.responses_close_at is not null and target.responses_close_at<=now())
  then raise exception using errcode='PT409', message='expected_version_conflict', detail='CIRCULAR_STALE_VERSION'; end if;
  select * into response_unit from app_private.circular_response_unit(
    session.revision_id,actor.person_id,jsonb_build_object('child_context_id',session.child_context_id)
  );
  if response_unit.unit_key is distinct from session.response_unit_key then raise insufficient_privilege using message='response_unit_denied'; end if;
  if exists(select 1 from public.circular_questions q where q.revision_id=session.revision_id and q.required and not exists(select 1 from public.circular_answers a where a.session_id=session.id and a.question_id=q.id))
  then raise check_violation using message='required_question_missing'; end if;
  update public.circular_response_sessions set status='submitted',submitted_at=now(),response_version=response_version+1,last_actor_person_id=actor.person_id,updated_at=now() where id=session.id returning * into session;
  insert into public.circular_response_revisions(session_id,response_version,actor_person_id,status,snapshot)
  values(session.id,session.response_version,actor.person_id,'submitted',jsonb_build_object('request_id',p_request_id,'submitted_at',session.submitted_at));
  return jsonb_build_object('session_id',session.id,'version',session.response_version,'status',session.status,'submitted_at',session.submitted_at);
end $$;

-- public.superadmin_activity_location_create_v2 [ACTIVITY]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 4, handlers: 1.
create or replace function "public"."superadmin_activity_location_create_v2"("p_request_id" "uuid", "p_location_id" "uuid", "p_activity_payload" "jsonb", "p_reservation" "jsonb" DEFAULT NULL::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
 ctx app_private.superadmin_internal_context; initial_ctx app_private.superadmin_internal_context;
 target public.activity_locations%rowtype;
 receipt app_private.activity_location_create_receipts%rowtype;
 required_permissions text[]:=array['activities.create','activities.read','activities.link_units',
   'activities.link_groups','activities.assign_people','activities.manage_permissions','locations.read'];
 save_request uuid; create_request uuid; reservation_request uuid; v_activity_id uuid;
 owner_kind text; v_owner_id uuid; v_hash bytea;
 aggregate_result jsonb; reservation_result jsonb; result jsonb; consumer jsonb;
 correlation uuid:=gen_random_uuid(); audit_institution_id uuid; error_code text; error_detail text;
begin
 begin
   if p_request_id is null or p_location_id is null or p_activity_payload is null
     or jsonb_typeof(p_activity_payload) is distinct from 'object'
     or current_setting('transaction_isolation')<>'read committed' then raise invalid_parameter_value; end if;
   if p_reservation is not null then
     if jsonb_typeof(p_reservation) is distinct from 'object' then raise invalid_parameter_value; end if;
     if not(p_reservation ?& array['first_occurrence','recurrence','conflict_justification'])
       or (select count(*) from jsonb_object_keys(p_reservation))<>3 then raise invalid_parameter_value; end if;
     required_permissions:=required_permissions||array['locations.reservations.manage','activities.manage'];
   end if;
   initial_ctx:=app_private.activity_location_authorize_v2(required_permissions);
   ctx:=initial_ctx;
   v_hash:=extensions.digest(convert_to(jsonb_build_object('location_id',p_location_id,
     'activity',p_activity_payload,'reservation',p_reservation)::text,'UTF8'),'sha256');
   save_request:=app_private.activity_request_uuid('activity-location-save:'||ctx.internal_identity_id::text,p_request_id);
   create_request:=app_private.activity_request_uuid('activity-save-create',save_request);
   reservation_request:=app_private.activity_request_uuid('activity-location-reserve:'||ctx.internal_identity_id::text,p_request_id);
   -- All request locks precede owner/location and consumer mutation locks.
   perform pg_advisory_xact_lock(hashtextextended('activity-location-request:'||ctx.internal_identity_id::text||':'||p_request_id::text,0));
   perform pg_advisory_xact_lock(hashtextextended(save_request::text,0));
   perform pg_advisory_xact_lock(hashtextextended(create_request::text,0));
   if p_reservation is not null then
     perform pg_advisory_xact_lock(hashtextextended('location-reservation-request:'||ctx.internal_identity_id::text||':'||reservation_request::text,0));
   end if;
   ctx:=app_private.activity_location_authorize_v2(required_permissions,initial_ctx);
   select l.scope_kind,coalesce(l.unit_id,l.institution_id) into owner_kind,v_owner_id
     from public.activity_locations l where l.id=p_location_id;
   if v_owner_id is null then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
   perform pg_advisory_xact_lock_shared(hashtextextended('location-reservation-owner:'||owner_kind||':'||v_owner_id::text,0));
   target:=app_private.superadmin_location_locked_v2(ctx,p_location_id);
   if target.scope_kind is distinct from owner_kind or coalesce(target.unit_id,target.institution_id) is distinct from v_owner_id then
     raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE';
   end if;
   audit_institution_id:=target.institution_id;
   ctx:=app_private.activity_location_authorize_v2(required_permissions,initial_ctx);
   if (p_activity_payload->>'institution_id')::uuid is distinct from target.institution_id then
     raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
   end if;
   select r.* into receipt from app_private.activity_location_create_receipts r
     where r.actor_id=ctx.internal_identity_id and r.request_id=p_request_id;
   if found then
     if receipt.request_hash is distinct from v_hash or receipt.location_id is distinct from target.id then
       raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE';
     end if;
     v_activity_id:=receipt.activity_id;
     if not exists(select 1 from public.activity_location_selections s
       where s.activity_id=v_activity_id and s.location_id=target.id) then
       raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE';
     end if;
     result:=receipt.result||jsonb_build_object('replayed',true);
   else
     if target.status<>'active' then raise invalid_parameter_value; end if;
     -- Public child gateways must not let a pre-existing unrelated save be
     -- adopted into this wrapper. Child locks above serialize this check.
     if exists(select 1 from app_private.superadmin_internal_activity_save_receipts r where r.request_id=save_request)
       or exists(select 1 from app_private.superadmin_internal_activity_command_receipts r where r.request_id=create_request)
       or (p_reservation is not null and exists(select 1 from app_private.location_reservation_receipts r
         where r.actor_id=ctx.internal_identity_id and r.request_id=reservation_request)) then
       raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE';
     end if;
     aggregate_result:=public.superadmin_activity_save_v2(save_request,null,0,false,p_activity_payload);
     if aggregate_result->>'ok' is distinct from 'true' then
       raise exception using detail=coalesce(aggregate_result#>>'{error,code}','SAI_INTERNAL_ERROR');
     end if;
     v_activity_id:=(aggregate_result#>>'{data,activity_id}')::uuid;
     consumer:=jsonb_build_object('kind','activity','id',v_activity_id);
     perform app_private.location_reservation_consumer_v2(ctx,target,consumer,p_reservation is not null);
     insert into public.activity_location_selections(activity_id,location_id,created_by_internal_identity_id)
       values(v_activity_id,target.id,ctx.internal_identity_id);
     if p_reservation is not null then
       reservation_result:=public.superadmin_location_reservation_create_v2(
         p_reservation||jsonb_build_object('location_id',target.id,'consumer',consumer),reservation_request);
       if reservation_result->>'ok' is distinct from 'true' then
         raise exception using detail=coalesce(reservation_result#>>'{error,code}','SAI_INTERNAL_ERROR');
       end if;
     end if;
     result:=(aggregate_result->'data')||jsonb_build_object('location_id',target.id,
       'reservation',reservation_result->'data','replayed',false);
     insert into app_private.activity_location_create_receipts(actor_id,request_id,request_hash,activity_id,location_id,result)
       values(ctx.internal_identity_id,p_request_id,v_hash,v_activity_id,target.id,result);
   end if;
   consumer:=jsonb_build_object('kind','activity','id',v_activity_id);
   perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
     ctx.internal_membership_id,ctx.session_id,'activities.create',ctx.aal,'activity.location.create','success',null,
     correlation,target.institution_id,'activity',v_activity_id);
   -- The outer audit can block after the child engine's final checks. Recheck
   -- all capabilities and hierarchy here; raising removes ALL child effects.
   perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
   perform app_private.location_reservation_consumer_v2(ctx,target,consumer,p_reservation is not null);
   if result#>>'{reservation,confirmed_over_conflict}'='true' then
     perform app_private.require_superadmin_internal_context('locations.reservations.override');
   end if;
   ctx:=app_private.activity_location_authorize_v2(required_permissions,initial_ctx);
 exception when others then
   get stacked diagnostics error_detail=pg_exception_detail;
   error_code:=case
     when sqlstate in('22023','22P02','22003') or error_detail in('ACTIVITY_INVALID_INPUT','ACTIVITY_INVALID_REFERENCE') then 'SAI_INVALID_ARGUMENT'
     when sqlstate in('40001','23505','PT409') or error_detail in('SAI_CONCURRENT_CHANGE','ACTIVITY_INVALID_STATE','ACTIVITY_DEPENDENCIES_ACTIVE') then 'SAI_CONCURRENT_CHANGE'
     when error_detail='ACTIVITY_NOT_FOUND' then 'SAI_PERMISSION_DENIED'
     when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
       'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED','SAI_INVALID_ARGUMENT') then error_detail
     else 'SAI_INTERNAL_ERROR' end;
 end;
 if error_code is not null then
   perform app_private.audit_superadmin_internal_denial_if_identified('activities.create','activity.location.create',error_code,correlation,audit_institution_id);
   return app_private.superadmin_internal_error_envelope(error_code,correlation);
 end if;
 return jsonb_build_object('ok',true,'data',result,'error',null);
end $$;

-- public.superadmin_activity_publish_v2 [ACTIVITY]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_activity_publish_v2"("p_request_id" "uuid", "p_activity_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text;
begin begin
 select * into strict ctx from app_private.activity_v2_require_context('activities.manage',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1 then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id);
 if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.manage',a.institution_id);
 h:=app_private.activity_v2_command_request_hash('activity.publish',a.institution_id,a.id,p_expected_version,'{}'); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,a.id,'activity.publish',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update;
 if a.management_version<>p_expected_version then raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if;
 perform 1 from public.activity_taxonomies t where t.id=a.taxonomy_id order by t.id for share;
 perform 1 from public.activity_unit_links ul where ul.activity_id=a.id order by ul.id for share;
 perform 1 from public.units u where u.id in(select ul.unit_id from public.activity_unit_links ul where ul.activity_id=a.id) order by u.id for share;
 perform 1 from public.activity_group_links gl where gl.activity_id=a.id order by gl.id for share;
 perform 1 from public.groups g where g.id in(select gl.group_id from public.activity_group_links gl where gl.activity_id=a.id) order by g.id for share;
 perform 1 from public.activity_group_participants p join public.activity_group_links gl on gl.id=p.activity_group_link_id where gl.activity_id=a.id order by p.id for share of p;
 perform 1 from public.child_group_links cgl where cgl.id in(select p.child_group_link_id from public.activity_group_participants p join public.activity_group_links gl on gl.id=p.activity_group_link_id where gl.activity_id=a.id and p.status='active') order by cgl.id for share;
 perform 1 from public.child_unit_links cul where cul.id in(select cgl.child_unit_link_id from public.child_group_links cgl where cgl.id in(select p.child_group_link_id from public.activity_group_participants p join public.activity_group_links gl on gl.id=p.activity_group_link_id where gl.activity_id=a.id and p.status='active')) order by cul.id for share;
 perform 1 from public.child_contexts cc where cc.id in(select cul.child_context_id from public.child_unit_links cul where cul.id in(select cgl.child_unit_link_id from public.child_group_links cgl where cgl.id in(select p.child_group_link_id from public.activity_group_participants p join public.activity_group_links gl on gl.id=p.activity_group_link_id where gl.activity_id=a.id and p.status='active'))) order by cc.id for share;
 perform 1 from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id where gl.activity_id=a.id order by ga.id for share of ga;
 perform 1 from public.activity_admin_assignments aa where aa.activity_id=a.id order by aa.id for share;
 perform 1 from public.institution_memberships m where m.id in(select ga.membership_id from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id where gl.activity_id=a.id and ga.status='active' union select aa.membership_id from public.activity_admin_assignments aa where aa.activity_id=a.id and aa.status='active') order by m.id for share;
 perform 1 from public.people person where person.id in(select m.person_id from public.institution_memberships m where m.id in(select ga.membership_id from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id where gl.activity_id=a.id and ga.status='active' union select aa.membership_id from public.activity_admin_assignments aa where aa.activity_id=a.id and aa.status='active')) order by person.id for share;
 perform 1 from public.activity_assignment_capability_actions action where action.assignment_id in(select ga.id from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id where gl.activity_id=a.id and ga.status='active') order by action.id for share;
 perform 1 from public.activity_admin_capability_actions action where action.activity_admin_assignment_id in(select aa.id from public.activity_admin_assignments aa where aa.activity_id=a.id and aa.status='active') order by action.id for share;
 perform 1 from public.activity_capability_policies p where p.activity_id=a.id order by p.id for share;
 perform 1 from public.activity_group_capability_settings s join public.activity_group_links gl on gl.id=s.activity_group_link_id where gl.activity_id=a.id order by s.id for share of s;
 if a.status<>'draft' or length(btrim(a.name)) not between 1 and 120 or not exists(select 1 from public.activity_taxonomies t where t.id=a.taxonomy_id and t.status='active' and t.code<>'outros')
 or not exists(select 1 from public.activity_unit_links ul join public.units u on u.id=ul.unit_id where ul.activity_id=a.id and ul.status='active' and ul.institution_id=a.institution_id and u.institution_id=a.institution_id and u.status='active')
 or exists(select 1 from public.activity_unit_links ul left join public.units u on u.id=ul.unit_id and u.institution_id=a.institution_id and u.status='active' where ul.activity_id=a.id and ul.status='active' and (ul.institution_id<>a.institution_id or u.id is null))
 or (a.origin_scope_kind='unit' and not exists(select 1 from public.activity_unit_links ul join public.units u on u.id=ul.unit_id where ul.activity_id=a.id and ul.unit_id=a.origin_unit_id and ul.status='active' and u.institution_id=a.institution_id and u.status='active'))
 or not exists(select 1 from public.activity_group_links gl join public.groups g on g.id=gl.group_id where gl.activity_id=a.id and gl.status='active' and gl.institution_id=a.institution_id and g.institution_id=a.institution_id and g.unit_id=gl.unit_id and g.status='active')
 or exists(select 1 from public.activity_group_links gl left join public.groups g on g.id=gl.group_id and g.institution_id=a.institution_id and g.unit_id=gl.unit_id and g.status='active' left join public.activity_unit_links ul on ul.activity_id=a.id and ul.unit_id=gl.unit_id and ul.status='active' where gl.activity_id=a.id and gl.status='active' and (gl.institution_id<>a.institution_id or g.id is null or ul.id is null))
 or exists(select 1 from public.activity_group_participants p join public.activity_group_links gl on gl.id=p.activity_group_link_id left join public.child_group_links cgl on cgl.id=p.child_group_link_id and cgl.group_id=gl.group_id and cgl.status='active' left join public.child_unit_links cul on cul.id=cgl.child_unit_link_id and cul.unit_id=gl.unit_id and cul.status='active' left join public.child_contexts cc on cc.id=cul.child_context_id and cc.institution_id=a.institution_id and cc.status='active' left join public.people child on child.id=cc.child_person_id and child.person_type='child' and child.status='active' where gl.activity_id=a.id and p.status='active' and (p.removed_at is not null or gl.status<>'active' or cgl.id is null or cul.id is null or cc.id is null or child.id is null))
 or exists(select 1 from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id left join public.institution_memberships m on m.id=ga.membership_id and m.institution_id=a.institution_id and m.person_id=ga.person_id and m.status='active' and m.revoked_at is null left join public.people person on person.id=ga.person_id and person.person_type='adult' and person.status='active' where gl.activity_id=a.id and ga.status='active' and ga.revoked_at is null and (gl.status<>'active' or ga.institution_id<>a.institution_id or m.id is null or person.id is null))
 or exists(select 1 from public.activity_admin_assignments aa left join public.institution_memberships m on m.id=aa.membership_id and m.institution_id=a.institution_id and m.person_id=aa.person_id and m.status='active' and m.revoked_at is null left join public.people person on person.id=aa.person_id and person.person_type='adult' and person.status='active' where aa.activity_id=a.id and aa.status='active' and aa.revoked_at is null and (aa.institution_id<>a.institution_id or m.id is null or person.id is null))
 or exists(select 1 from public.activity_capability_policies policy join public.activity_group_capability_settings setting on setting.capability_id=policy.capability_id join public.activity_group_links gl on gl.id=setting.activity_group_link_id where policy.activity_id=a.id and gl.activity_id=a.id and ((policy.policy_mode='prohibited' and setting.is_enabled) or (policy.policy_mode='required' and not setting.is_enabled)))
 or exists(select 1 from public.activity_capability_policies policy join public.activity_group_assignments ga on ga.status='active' and ga.revoked_at is null and ga.assignment_role='instructor' join public.activity_group_links gl on gl.id=ga.activity_group_link_id and gl.activity_id=policy.activity_id join public.activity_assignment_capability_actions action on action.assignment_id=ga.id and action.capability_id=policy.capability_id where policy.activity_id=a.id and policy.policy_mode='required' and not action.can_view and not action.can_edit)
 or exists(select 1 from public.activity_capability_policies policy join public.activity_admin_assignments aa on aa.activity_id=policy.activity_id and aa.status='active' and aa.revoked_at is null join public.activity_admin_capability_actions action on action.activity_admin_assignment_id=aa.id and action.capability_id=policy.capability_id where policy.activity_id=a.id and policy.policy_mode='required' and not action.can_view and not action.can_edit)
 or exists(select 1 from public.activity_group_assignments ga join public.activity_group_links gl on gl.id=ga.activity_group_link_id where gl.activity_id=a.id and ga.status='active' and ga.revoked_at is null and ga.assignment_role='instructor' and ((select count(*) from public.activity_assignment_capability_actions action where action.assignment_id=ga.id)<>5 or (select count(*) from public.activity_assignment_capability_actions action join public.activity_capabilities c on c.id=action.capability_id where action.assignment_id=ga.id and c.status='active' and c.code in('chat','now','happens','moments','attendance'))<>5))
 or exists(select 1 from public.activity_admin_assignments aa where aa.activity_id=a.id and aa.status='active' and aa.revoked_at is null and ((select count(*) from public.activity_admin_capability_actions action where action.activity_admin_assignment_id=aa.id)<>5 or (select count(*) from public.activity_admin_capability_actions action join public.activity_capabilities c on c.id=action.capability_id where action.activity_admin_assignment_id=aa.id and c.status='active' and c.code in('chat','now','happens','moments','attendance'))<>5))
 then raise invalid_parameter_value using detail='ACTIVITY_INVALID_STATE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.manage','manage',correlation); update public.activity_definitions x set status='active',management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.manage','activity.publish','{}'); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.publish',h,a.management_version,a.status::text,correlation,'{}');
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.manage','activity.publish',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

-- public.superadmin_activity_save_v2 [ACTIVITY]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_activity_save_v2"("p_request_id" "uuid", "p_activity_id" "uuid", "p_expected_version" bigint, "p_publish" boolean, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  ctx app_private.superadmin_internal_context;
  initial_ctx app_private.superadmin_internal_context;
  capability_ctx app_private.superadmin_internal_context;
  activity public.activity_definitions%rowtype;
  correlation_id uuid := gen_random_uuid();
  institution_id uuid;
  unit_ids uuid[];
  group_ids uuid[];
  definition jsonb;
  result jsonb;
  request_hash bytea;
  receipt app_private.superadmin_internal_activity_save_receipts%rowtype;
  current_activity_id uuid := p_activity_id;
  current_version bigint;
  groups_to_detach uuid[] := '{}'::uuid[];
  selected_to_all uuid[] := '{}'::uuid[];
  bridge_group_ids uuid[] := '{}'::uuid[];
  bridge_group_participation jsonb := '{}'::jsonb;
  prune_participants jsonb := '[]'::jsonb;
  prune_professionals jsonb := '[]'::jsonb;
  prune_group_settings jsonb := '[]'::jsonb;
  prune_professional_actions jsonb := '[]'::jsonb;
  needs_participant_prune boolean := false;
  needs_professional_prune boolean := false;
  needs_permission_prune boolean := false;
  needs_group_bridge boolean := false;
  required_capability text := case
    when p_activity_id is null then 'activities.create'
    else 'activities.manage'
  end;
  required_capabilities text[];
  error_code text;
begin
  begin
    select * into strict ctx
    from app_private.activity_v2_require_context(required_capability, null);

    if p_request_id is null
      or p_expected_version is null
      or p_publish is null
      or p_payload is null
      or jsonb_typeof(p_payload) <> 'object'
      or not (p_payload ?& array[
        'institution_id','definition','unit_ids','group_ids',
        'group_participation','participants','professional_assignments',
        'capability_policies','group_capability_settings',
        'professional_capability_actions'
      ])
      or exists(
        select 1 from jsonb_object_keys(p_payload) key
        where key not in(
          'institution_id','definition','unit_ids','group_ids',
          'group_participation','participants','professional_assignments',
          'capability_policies','group_capability_settings',
          'professional_capability_actions'
        )
      )
      or jsonb_typeof(p_payload->'institution_id') <> 'string'
      or jsonb_typeof(p_payload->'definition') <> 'object'
      or (p_payload->'definition') = '{}'::jsonb
      or exists(
        select 1 from jsonb_object_keys(p_payload->'definition') key
        where key not in('name','description','taxonomy_id','icon_key','initials','handle')
      )
      or jsonb_typeof(p_payload->'unit_ids') <> 'array'
      or jsonb_typeof(p_payload->'group_ids') <> 'array'
      or jsonb_typeof(p_payload->'group_participation') <> 'object'
      or jsonb_typeof(p_payload->'participants') <> 'array'
      or jsonb_typeof(p_payload->'professional_assignments') <> 'array'
      or jsonb_typeof(p_payload->'capability_policies') <> 'object'
      or jsonb_typeof(p_payload->'group_capability_settings') <> 'array'
      or jsonb_typeof(p_payload->'professional_capability_actions') <> 'array'
    then
      raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
    end if;

    begin
      institution_id := (p_payload->>'institution_id')::uuid;
      select coalesce(array_agg(item.value::uuid order by item.ordinality), '{}'::uuid[])
      into unit_ids
      from jsonb_array_elements_text(p_payload->'unit_ids') with ordinality item(value, ordinality);
      select coalesce(array_agg(item.value::uuid order by item.ordinality), '{}'::uuid[])
      into group_ids
      from jsonb_array_elements_text(p_payload->'group_ids') with ordinality item(value, ordinality);
    exception when others then
      raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
    end;

    if (
      select coalesce(array_agg(key order by key), '{}'::text[])
      from jsonb_object_keys(p_payload->'group_participation') key
    ) <> (
      select coalesce(array_agg(group_id::text order by group_id::text), '{}'::text[])
      from unnest(group_ids) group_id
    ) or exists(
      select 1
      from jsonb_each_text(p_payload->'group_participation') participation
      where participation.value is null
        or participation.value not in ('all', 'selected')
    ) then
      raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
    end if;

    definition := p_payload->'definition';
    if pg_catalog.current_setting('transaction_isolation') <> 'read committed' then
      raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
    end if;
    if p_activity_id is null then
      if p_expected_version <> 0 then
        raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
      end if;
      select * into strict ctx
      from app_private.activity_v2_require_context('activities.create', institution_id);
    else
      if p_expected_version < 1 then
        raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
      end if;
      select * into activity
      from public.activity_definitions candidate
      where candidate.id = p_activity_id
        and (ctx.scope_kind <> 'institution'
          or candidate.institution_id = ctx.scope_institution_id);
      if activity.id is null then
        raise no_data_found using detail = 'ACTIVITY_NOT_FOUND';
      end if;
      select * into strict ctx
      from app_private.activity_v2_require_context('activities.manage', activity.institution_id);
      if institution_id <> activity.institution_id then
        raise foreign_key_violation using detail = 'ACTIVITY_INVALID_REFERENCE';
      end if;
    end if;

    initial_ctx := ctx;
    required_capabilities := array[
      'activities.link_units','activities.link_groups',
      'activities.assign_people','activities.manage_permissions'
    ]::text[] || case when p_publish
      then array['activities.manage']::text[]
      else '{}'::text[]
    end;
    foreach required_capability in array required_capabilities loop
      perform app_private.activity_v2_require_context(required_capability, institution_id);
    end loop;

    required_capability := case
      when p_activity_id is null then 'activities.create'
      else 'activities.manage'
    end;
    request_hash := app_private.activity_v2_command_request_hash(
      'activity.save',institution_id,p_activity_id,p_expected_version,
      pg_catalog.jsonb_build_object('publish',p_publish,'payload',p_payload)
    );
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_request_id::text,0)
    );
    -- A request lock may wait behind another transaction. READ COMMITTED gives
    -- every statement below a fresh snapshot; bind it to the original actor and
    -- scope before a private receipt can be exposed or any child can mutate.
    select * into strict ctx
    from app_private.activity_v2_require_context(required_capability, institution_id);
    if row(
      ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
      ctx.auth_user_id,ctx.session_id,ctx.platform_role_id,ctx.platform_role_code,
      ctx.scope_kind,ctx.scope_institution_id,ctx.resolved_institution_id,
      ctx.aal,ctx.permission_code,ctx.requires_mfa
    ) is distinct from row(
      initial_ctx.internal_identity_id,initial_ctx.internal_auth_link_id,
      initial_ctx.internal_membership_id,initial_ctx.auth_user_id,initial_ctx.session_id,
      initial_ctx.platform_role_id,initial_ctx.platform_role_code,initial_ctx.scope_kind,
      initial_ctx.scope_institution_id,initial_ctx.resolved_institution_id,
      initial_ctx.aal,initial_ctx.permission_code,initial_ctx.requires_mfa
    ) then
      raise insufficient_privilege using detail = 'SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    foreach required_capability in array required_capabilities loop
      select * into strict capability_ctx
      from app_private.activity_v2_require_context(required_capability, institution_id);
      if row(
        capability_ctx.internal_identity_id,capability_ctx.internal_auth_link_id,
        capability_ctx.internal_membership_id,capability_ctx.auth_user_id,
        capability_ctx.session_id,capability_ctx.platform_role_id,
        capability_ctx.platform_role_code,
        capability_ctx.scope_kind,capability_ctx.scope_institution_id,
        capability_ctx.resolved_institution_id,capability_ctx.aal
      ) is distinct from row(
        initial_ctx.internal_identity_id,initial_ctx.internal_auth_link_id,
        initial_ctx.internal_membership_id,initial_ctx.auth_user_id,initial_ctx.session_id,
        initial_ctx.platform_role_id,initial_ctx.platform_role_code,initial_ctx.scope_kind,
        initial_ctx.scope_institution_id,initial_ctx.resolved_institution_id,initial_ctx.aal
      ) then
        raise insufficient_privilege using detail = 'SAI_INTERNAL_CONTEXT_DENIED';
      end if;
    end loop;
    if not exists(
      select 1
      from auth.sessions session_record
      where session_record.id = initial_ctx.session_id
        and session_record.user_id = initial_ctx.auth_user_id
        and (session_record.not_after is null
          or session_record.not_after > pg_catalog.clock_timestamp())
    ) then
      raise insufficient_privilege using detail = 'SAI_SESSION_INVALID';
    end if;
    required_capability := case
      when p_activity_id is null then 'activities.create'
      else 'activities.manage'
    end;
    select * into receipt
    from app_private.superadmin_internal_activity_save_receipts candidate
    where candidate.request_id = p_request_id;
    if receipt.request_id is not null then
      if receipt.internal_identity_id <> ctx.internal_identity_id then
        raise insufficient_privilege using detail = 'SAI_PERMISSION_DENIED';
      end if;
      if receipt.institution_id is distinct from institution_id
        or (p_activity_id is not null and receipt.activity_id is distinct from p_activity_id)
        or receipt.request_hash <> request_hash
      then
        raise exception using errcode='PT409', detail = 'SAI_CONCURRENT_CHANGE';
      end if;
      return app_private.activity_v2_success_envelope(pg_catalog.jsonb_build_object(
        'activity_id',receipt.activity_id,
        'management_version',receipt.resulting_version,
        'status',receipt.resulting_status,
        'correlation_id',receipt.correlation_id,
        'replayed',true
      ));
    end if;

    if p_activity_id is null then
      required_capability := 'activities.create';
      result := public.superadmin_activity_create_v2(
        app_private.activity_request_uuid('activity-save-create', p_request_id),
        definition || pg_catalog.jsonb_build_object(
          'institution_id', institution_id,
          'unit_ids', to_jsonb(unit_ids)
        )
      );
    else
      required_capability := 'activities.manage';
      -- Decisao 16: na edicao a troca do @ passa por
      -- superadmin_structure_handle_set_v1 (trava de 30 dias); um `handle`
      -- diferente do stem atual e recusado (ACTIVITY_INVALID_INPUT: o
      -- normalizador de codigos da familia so deixa passar a lista fechada) e
      -- um igual e simplesmente ignorado.
      if definition ? 'handle' then
        if nullif(pg_catalog.btrim(definition->>'handle'),'') is not null
           and app_private.activity_slugify(split_part(app_private.structure_handle_normalize(definition->>'handle'),'.',1))
             is distinct from activity.handle_stem then
          raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
        end if;
        definition := definition - 'handle';
      end if;
      result := public.superadmin_activity_update_v2(
        app_private.activity_request_uuid('activity-save-update', p_request_id),
        p_activity_id,
        p_expected_version,
        definition
      );
    end if;

    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_activity_id := (result#>>'{data,activity_id}')::uuid;
    current_version := (result#>>'{data,management_version}')::bigint;

    if p_activity_id is not null then
      select coalesce(array_agg(link.group_id order by link.group_id), '{}'::uuid[])
      into groups_to_detach
      from public.activity_group_links link
      where link.activity_id = current_activity_id
        and link.status = 'active'
        and (
          not (link.group_id = any(group_ids))
          or not (link.unit_id = any(unit_ids))
        );

      select coalesce(array_agg(link.group_id order by link.group_id), '{}'::uuid[])
      into selected_to_all
      from public.activity_group_links link
      where link.activity_id = current_activity_id
        and link.status = 'active'
        and link.group_id = any(group_ids)
        and link.unit_id = any(unit_ids)
        and link.participation_mode = 'selected'
        and (p_payload->'group_participation')->>(link.group_id::text) = 'all';

      select exists(
        select 1
        from public.activity_group_participants participant
        join public.activity_group_links link
          on link.id = participant.activity_group_link_id
        where link.activity_id = current_activity_id
          and participant.status = 'active'
          and (
            link.group_id = any(groups_to_detach)
            or link.group_id = any(selected_to_all)
          )
      ) into needs_participant_prune;

      select exists(
        select 1
        from public.activity_group_assignments assignment
        join public.activity_group_links link
          on link.id = assignment.activity_group_link_id
        where link.activity_id = current_activity_id
          and link.group_id = any(groups_to_detach)
          and assignment.assignment_role = 'instructor'
          and assignment.status = 'active'
          and assignment.revoked_at is null
      ) into needs_professional_prune;

      select exists(
        select 1
        from public.activity_group_capability_settings setting
        join public.activity_group_links link
          on link.id = setting.activity_group_link_id
        where link.activity_id = current_activity_id
          and link.group_id = any(groups_to_detach)
      ) into needs_permission_prune;

      select exists(
        select 1
        from public.activity_group_links link
        where link.activity_id = current_activity_id
          and link.status = 'active'
          and not (link.unit_id = any(unit_ids))
      ) into needs_group_bridge;

      if needs_participant_prune then
        select coalesce(
          jsonb_agg(
            element.value
            order by element.value->>'group_id', element.value->>'child_group_link_id'
          ),
          '[]'::jsonb
        )
        into prune_participants
        from jsonb_array_elements(p_payload->'participants') element(value)
        where element.value->'belongs' = 'true'::jsonb
          and exists(
            select 1
            from public.activity_group_links link
            where link.activity_id = current_activity_id
              and link.status = 'active'
              and link.group_id::text = element.value->>'group_id'
              and link.group_id = any(group_ids)
              and link.unit_id = any(unit_ids)
              and link.participation_mode = 'selected'
              and (p_payload->'group_participation')->>(link.group_id::text) = 'selected'
          );

        required_capability := 'activities.assign_people';
        result := public.superadmin_activity_set_participants_v2(
          app_private.activity_request_uuid('activity-save-participants-prune', p_request_id),
          current_activity_id,current_version,prune_participants
        );
        if result#>>'{ok}' is distinct from 'true' then
          raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
        end if;
        current_version := (result#>>'{data,management_version}')::bigint;
      end if;

      if needs_professional_prune then
        select coalesce(
          jsonb_agg(
            element.value
            order by element.value->>'role', element.value->>'group_id',
              element.value->>'membership_id'
          ),
          '[]'::jsonb
        )
        into prune_professionals
        from jsonb_array_elements(p_payload->'professional_assignments') element(value)
        where element.value->>'role' = 'activity_admin'
          or (
            element.value->>'role' = 'instructor'
            and exists(
              select 1
              from public.activity_group_links link
              where link.activity_id = current_activity_id
                and link.status = 'active'
                and link.group_id::text = element.value->>'group_id'
                and link.group_id = any(group_ids)
                and link.unit_id = any(unit_ids)
            )
          );

        required_capability := 'activities.assign_people';
        result := public.superadmin_activity_set_professionals_v2(
          app_private.activity_request_uuid('activity-save-professionals-prune', p_request_id),
          current_activity_id,current_version,prune_professionals
        );
        if result#>>'{ok}' is distinct from 'true' then
          raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
        end if;
        current_version := (result#>>'{data,management_version}')::bigint;
      end if;

      if needs_permission_prune then
        select coalesce(
          jsonb_agg(element.value order by element.value->>'group_id'),
          '[]'::jsonb
        )
        into prune_group_settings
        from jsonb_array_elements(p_payload->'group_capability_settings') element(value)
        where exists(
          select 1
          from public.activity_group_links link
          where link.activity_id = current_activity_id
            and link.status = 'active'
            and link.group_id::text = element.value->>'group_id'
            and link.group_id = any(group_ids)
            and link.unit_id = any(unit_ids)
        );

        select coalesce(
          jsonb_agg(
            element.value
            order by element.value->>'role', element.value->>'group_id',
              element.value->>'membership_id'
          ),
          '[]'::jsonb
        )
        into prune_professional_actions
        from jsonb_array_elements(p_payload->'professional_capability_actions') element(value)
        where (
          element.value->>'role' = 'activity_admin'
          and exists(
            select 1
            from public.activity_admin_assignments assignment
            where assignment.activity_id = current_activity_id
              and assignment.membership_id::text = element.value->>'membership_id'
              and assignment.status = 'active'
              and assignment.revoked_at is null
          )
        ) or (
          element.value->>'role' = 'instructor'
          and exists(
            select 1
            from public.activity_group_assignments assignment
            join public.activity_group_links link
              on link.id = assignment.activity_group_link_id
            where link.activity_id = current_activity_id
              and link.group_id::text = element.value->>'group_id'
              and assignment.membership_id::text = element.value->>'membership_id'
              and assignment.assignment_role = 'instructor'
              and assignment.status = 'active'
              and assignment.revoked_at is null
              and link.status = 'active'
          )
        );

        required_capability := 'activities.manage_permissions';
        result := public.superadmin_activity_set_permissions_v2(
          app_private.activity_request_uuid('activity-save-permissions-prune', p_request_id),
          current_activity_id,current_version,p_payload->'capability_policies',
          prune_group_settings,prune_professional_actions
        );
        if result#>>'{ok}' is distinct from 'true' then
          raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
        end if;
        current_version := (result#>>'{data,management_version}')::bigint;
      end if;

      if needs_group_bridge then
        select coalesce(array_agg(link.group_id order by link.group_id), '{}'::uuid[])
        into bridge_group_ids
        from public.activity_group_links link
        where link.activity_id = current_activity_id
          and link.status = 'active'
          and link.group_id = any(group_ids)
          and link.unit_id = any(unit_ids);

        select coalesce(
          jsonb_object_agg(
            link.group_id::text,
            (p_payload->'group_participation')->>(link.group_id::text)
            order by link.group_id::text
          ),
          '{}'::jsonb
        )
        into bridge_group_participation
        from public.activity_group_links link
        where link.activity_id = current_activity_id
          and link.status = 'active'
          and link.group_id = any(bridge_group_ids);

        required_capability := 'activities.link_groups';
        result := public.superadmin_activity_set_groups_v2(
          app_private.activity_request_uuid('activity-save-groups-prune', p_request_id),
          current_activity_id,current_version,bridge_group_ids,bridge_group_participation
        );
        if result#>>'{ok}' is distinct from 'true' then
          raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
        end if;
        current_version := (result#>>'{data,management_version}')::bigint;
      end if;

      required_capability := 'activities.link_units';
      result := public.superadmin_activity_set_units_v2(
        app_private.activity_request_uuid('activity-save-units', p_request_id),
        current_activity_id,current_version,unit_ids
      );
      if result#>>'{ok}' is distinct from 'true' then
        raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
      end if;
      current_version := (result#>>'{data,management_version}')::bigint;
    end if;

    required_capability := 'activities.link_groups';
    result := public.superadmin_activity_set_groups_v2(
      app_private.activity_request_uuid('activity-save-groups', p_request_id),
      current_activity_id,current_version,group_ids,p_payload->'group_participation'
    );
    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;

    required_capability := 'activities.assign_people';
    result := public.superadmin_activity_set_participants_v2(
      app_private.activity_request_uuid('activity-save-participants', p_request_id),
      current_activity_id,current_version,p_payload->'participants'
    );
    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;

    result := public.superadmin_activity_set_professionals_v2(
      app_private.activity_request_uuid('activity-save-professionals', p_request_id),
      current_activity_id,current_version,p_payload->'professional_assignments'
    );
    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;

    required_capability := 'activities.manage_permissions';
    result := public.superadmin_activity_set_permissions_v2(
      app_private.activity_request_uuid('activity-save-permissions', p_request_id),
      current_activity_id,current_version,p_payload->'capability_policies',
      p_payload->'group_capability_settings',p_payload->'professional_capability_actions'
    );
    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;

    if p_publish then
      required_capability := 'activities.manage';
      result := public.superadmin_activity_publish_v2(
        app_private.activity_request_uuid('activity-save-publish', p_request_id),
        current_activity_id,current_version
      );
      if result#>>'{ok}' is distinct from 'true' then
        raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
      end if;
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;
    correlation_id := (result#>>'{data,correlation_id}')::uuid;
    insert into app_private.superadmin_internal_activity_save_receipts(
      request_id,internal_identity_id,institution_id,activity_id,request_hash,
      resulting_version,resulting_status,correlation_id
    ) values(
      p_request_id,ctx.internal_identity_id,institution_id,current_activity_id,request_hash,
      current_version,result#>>'{data,status}',correlation_id
    );
    return app_private.activity_v2_success_envelope(pg_catalog.jsonb_build_object(
      'activity_id',current_activity_id,
      'management_version',current_version,
      'status',result#>>'{data,status}',
      'correlation_id',correlation_id,
      'replayed',false
    ));
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    error_code := coalesce(nullif(error_code, ''), 'SAI_INTERNAL_ERROR');
  end;

  return app_private.activity_v2_denied_envelope(
    required_capability,'activity.save',error_code,correlation_id,institution_id
  );
end
$$;

-- public.superadmin_activity_set_groups_v2 [ACTIVITY]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_activity_set_groups_v2"("p_request_id" "uuid", "p_activity_id" "uuid", "p_expected_version" bigint, "p_group_ids" "uuid"[], "p_group_participation" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text;
begin begin select * into strict ctx from app_private.activity_v2_require_context('activities.link_groups',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1 or p_group_ids is null or jsonb_typeof(p_group_participation) is distinct from 'object' then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id); if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.link_groups',a.institution_id);
 if coalesce(cardinality(p_group_ids),0)>200 or jsonb_typeof(p_group_participation)<>'object' or cardinality(p_group_ids)<>(select count(distinct x) from unnest(p_group_ids)x) or (select coalesce(array_agg(k order by k),'{}') from jsonb_object_keys(p_group_participation)k)<>(select coalesce(array_agg(x::text order by x::text),'{}') from unnest(p_group_ids)x) or exists(select 1 from jsonb_each_text(p_group_participation)x where value not in('all','selected')) then raise invalid_parameter_value using message='duplicate group',detail='ACTIVITY_INVALID_INPUT'; end if;
 h:=app_private.activity_v2_command_request_hash('activity.set_groups',a.institution_id,a.id,p_expected_version,pg_catalog.jsonb_build_object('group_ids',p_group_ids,'participation',p_group_participation)); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,a.id,'activity.set_groups',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update; if a.management_version<>p_expected_version then raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if;
 perform 1 from public.groups g where g.id=any(p_group_ids) order by g.id for share;
 perform 1 from public.activity_unit_links ul where ul.activity_id=a.id order by ul.id for share;
 perform 1 from public.activity_group_links gl where gl.activity_id=a.id order by gl.id for update;
 perform 1 from public.activity_group_participants participant where participant.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by participant.id for share;
 perform 1 from public.activity_group_assignments assignment where assignment.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by assignment.id for share;
 perform 1 from public.activity_group_capability_settings setting where setting.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by setting.id for share;
 if exists(select 1 from public.activity_group_links gl where gl.activity_id=a.id and gl.status='active' and not(gl.group_id=any(p_group_ids)) and (exists(select 1 from public.activity_group_participants p where p.activity_group_link_id=gl.id and p.status='active') or exists(select 1 from public.activity_group_assignments p where p.activity_group_link_id=gl.id and p.status='active') or exists(select 1 from public.activity_group_capability_settings p where p.activity_group_link_id=gl.id))) then raise integrity_constraint_violation using detail='ACTIVITY_DEPENDENCIES_ACTIVE'; end if;
 if exists(select 1 from unnest(p_group_ids)x left join public.groups g on g.id=x and g.institution_id=a.institution_id and g.status='active' left join public.activity_unit_links ul on ul.activity_id=a.id and ul.unit_id=g.unit_id and ul.status='active' where g.id is null or ul.id is null) then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 if exists(select 1 from public.activity_group_links gl join public.activity_group_participants p on p.activity_group_link_id=gl.id and p.status='active' where gl.activity_id=a.id and gl.group_id=any(p_group_ids) and gl.participation_mode='selected' and p_group_participation->>gl.group_id::text='all') then raise integrity_constraint_violation using detail='ACTIVITY_DEPENDENCIES_ACTIVE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.link_groups','link_groups',correlation); update public.activity_group_links gl set status='inactive',ends_at=greatest(pg_catalog.clock_timestamp(),gl.starts_at+interval '1 microsecond'),updated_at=now() where gl.activity_id=a.id and gl.status='active' and not(gl.group_id=any(p_group_ids));
 insert into public.activity_group_links(activity_id,institution_id,unit_id,group_id,linked_by_person_id,status,ends_at,participation_mode) select a.id,a.institution_id,g.unit_id,g.id,null,'active',null,p_group_participation->>g.id::text from public.groups g where g.id=any(p_group_ids) on conflict(activity_id,group_id) do update set status='active',ends_at=null,participation_mode=excluded.participation_mode,updated_at=now();
 update public.activity_definitions x set management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.link_groups','activity.set_groups',pg_catalog.jsonb_build_object('groups',cardinality(p_group_ids))); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.set_groups',h,a.management_version,a.status::text,correlation,pg_catalog.jsonb_build_object('groups',cardinality(p_group_ids)));
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.link_groups','activity.set_groups',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

-- public.superadmin_activity_set_participants_v2 [ACTIVITY]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_activity_set_participants_v2"("p_request_id" "uuid", "p_activity_id" "uuid", "p_expected_version" bigint, "p_participants" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text;
begin begin select * into strict ctx from app_private.activity_v2_require_context('activities.assign_people',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1 or jsonb_typeof(p_participants) is distinct from 'array' then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id); if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.assign_people',a.institution_id);
 if p_request_id is null or p_expected_version is null or p_expected_version<1 or app_private.activity_v2_validate_participants(a.institution_id,p_participants) is distinct from true then raise invalid_parameter_value using message='duplicate participant or invalid chain (max 1000)',detail='ACTIVITY_INVALID_INPUT'; end if;
 h:=app_private.activity_v2_command_request_hash('activity.set_participants',a.institution_id,a.id,p_expected_version,p_participants); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,a.id,'activity.set_participants',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update; if a.management_version<>p_expected_version then raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if;
 perform 1 from public.child_group_links cgl where cgl.id in(select (item->>'child_group_link_id')::uuid from jsonb_array_elements(p_participants) item where (item->>'belongs')::boolean) order by cgl.id for share;
 perform 1 from public.child_unit_links cul where cul.id in(select cgl.child_unit_link_id from public.child_group_links cgl where cgl.id in(select (item->>'child_group_link_id')::uuid from jsonb_array_elements(p_participants) item where (item->>'belongs')::boolean)) order by cul.id for share;
 perform 1 from public.child_contexts cc where cc.id in(select cul.child_context_id from public.child_unit_links cul where cul.id in(select cgl.child_unit_link_id from public.child_group_links cgl where cgl.id in(select (item->>'child_group_link_id')::uuid from jsonb_array_elements(p_participants) item where (item->>'belongs')::boolean))) order by cc.id for share;
 perform 1 from public.people person where person.id in(select cc.child_person_id from public.child_contexts cc where cc.id in(select cul.child_context_id from public.child_unit_links cul where cul.id in(select cgl.child_unit_link_id from public.child_group_links cgl where cgl.id in(select (item->>'child_group_link_id')::uuid from jsonb_array_elements(p_participants) item where (item->>'belongs')::boolean)))) order by person.id for share;
 perform 1 from public.activity_group_links gl where gl.activity_id=a.id order by gl.id for share;
 perform 1 from public.activity_group_participants participant where participant.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by participant.id for update;
 if app_private.activity_v2_validate_participants(a.institution_id,p_participants) is distinct from true then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 if exists(select 1 from jsonb_array_elements(p_participants)item left join public.activity_group_links gl on gl.activity_id=a.id and gl.group_id=(item->>'group_id')::uuid and gl.status='active' and gl.participation_mode='selected' where (item->>'belongs')::boolean and gl.id is null) then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.assign_people','assign_people',correlation); update public.activity_group_participants p set status='inactive',removed_at=now(),updated_at=now() where p.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) and p.status='active' and not exists(select 1 from jsonb_array_elements(p_participants)item where (item->>'belongs')::boolean and (item->>'child_group_link_id')::uuid=p.child_group_link_id);
 insert into public.activity_group_participants(activity_group_link_id,child_group_link_id,status,added_by_person_id) select gl.id,(item->>'child_group_link_id')::uuid,'active',null from jsonb_array_elements(p_participants)item join public.child_group_links cgl on cgl.id=(item->>'child_group_link_id')::uuid join public.activity_group_links gl on gl.activity_id=a.id and gl.group_id=(item->>'group_id')::uuid and gl.group_id=cgl.group_id and gl.status='active' where (item->>'belongs')::boolean on conflict(activity_group_link_id,child_group_link_id) where status='active' and removed_at is null do update set updated_at=now();
 update public.activity_definitions x set management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.assign_people','activity.set_participants',pg_catalog.jsonb_build_object('participants',jsonb_array_length(p_participants))); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.set_participants',h,a.management_version,a.status::text,correlation,pg_catalog.jsonb_build_object('participants',jsonb_array_length(p_participants)));
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.assign_people','activity.set_participants',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

-- public.superadmin_activity_set_permissions_v2 [ACTIVITY]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_activity_set_permissions_v2"("p_request_id" "uuid", "p_activity_id" "uuid", "p_expected_version" bigint, "p_capability_policies" "jsonb", "p_group_capability_settings" "jsonb", "p_professional_capability_actions" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text; item jsonb; entry record; cap uuid; gl uuid; ass uuid; counts jsonb; approved text[]:=array['attendance','chat','happens','moments','now'];
begin begin select * into strict ctx from app_private.activity_v2_require_context('activities.manage_permissions',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1
  or jsonb_typeof(p_capability_policies) is distinct from 'object'
  or jsonb_typeof(p_group_capability_settings) is distinct from 'array'
  or jsonb_typeof(p_professional_capability_actions) is distinct from 'array' then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id); if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.manage_permissions',a.institution_id);
 if (select array_agg(key order by key) from jsonb_object_keys(p_capability_policies)key) is distinct from approved
 or exists(select 1 from jsonb_each(p_capability_policies)x where x.value<>'null'::jsonb and (jsonb_typeof(x.value)<>'string' or x.value#>>'{}' not in('required','default_on','default_off','prohibited')))
 or jsonb_array_length(p_group_capability_settings)>200 or jsonb_array_length(p_professional_capability_actions)>500
 or exists(select 1 from jsonb_array_elements(p_group_capability_settings)x where not(x ?& array['group_id','capabilities']) or x-array['group_id','capabilities']<>'{}'::jsonb or jsonb_typeof(x->'group_id')<>'string' or jsonb_typeof(x->'capabilities')<>'object' or (select array_agg(key order by key) from jsonb_object_keys(x->'capabilities')key) is distinct from approved or exists(select 1 from jsonb_each(x->'capabilities')v where v.value<>'null'::jsonb and jsonb_typeof(v.value)<>'boolean'))
 or exists(select 1 from jsonb_array_elements(p_professional_capability_actions)x where not(x ?& array['membership_id','role','group_id','actions']) or x-array['membership_id','role','group_id','actions']<>'{}'::jsonb or jsonb_typeof(x->'membership_id')<>'string' or jsonb_typeof(x->'role')<>'string' or x->>'role' not in('instructor','activity_admin') or (x->>'role'='instructor' and jsonb_typeof(x->'group_id')<>'string') or (x->>'role'='activity_admin' and x->'group_id'<>'null'::jsonb) or jsonb_typeof(x->'actions')<>'object' or (select array_agg(key order by key) from jsonb_object_keys(x->'actions')key) is distinct from approved or exists(select 1 from jsonb_each_text(x->'actions')v where v.value not in('none','view','edit','both')))
 or (select count(*)<>count(distinct (x->>'membership_id',x->>'role',coalesce(x->>'group_id',''))) from jsonb_array_elements(p_professional_capability_actions)x)
 or (select count(*)<>count(distinct x->>'group_id') from jsonb_array_elements(p_group_capability_settings)x)
 then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 if exists(select 1 from jsonb_each_text(p_capability_policies)p join jsonb_array_elements(p_professional_capability_actions)x on x->'actions'->>p.key='none' where p.value='required') then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 if exists(select 1 from jsonb_each_text(p_capability_policies) policy join jsonb_array_elements(p_group_capability_settings) setting on true join jsonb_each(setting->'capabilities') capability on capability.key=policy.key where (policy.value='required' and capability.value='false'::jsonb) or (policy.value='prohibited' and capability.value='true'::jsonb)) then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 h:=app_private.activity_v2_command_request_hash('activity.set_permissions',a.institution_id,a.id,p_expected_version,pg_catalog.jsonb_build_object('policies',p_capability_policies,'settings',p_group_capability_settings,'actions',p_professional_capability_actions)); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,a.id,'activity.set_permissions',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update; if a.management_version<>p_expected_version then raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if; perform app_private.activity_v2_set_marker(ctx,'activities.manage_permissions','manage_permissions',correlation);
 perform 1 from public.activity_capabilities capability where capability.code=any(approved) order by capability.id for share;
 perform 1 from public.activity_group_links gl where gl.activity_id=a.id order by gl.id for share;
 perform 1 from public.activity_group_assignments assignment where assignment.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by assignment.id for share;
 perform 1 from public.activity_admin_assignments assignment where assignment.activity_id=a.id order by assignment.id for share;
 if (select count(*) from public.activity_capabilities capability where capability.code=any(approved) and capability.status='active')<>5 then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 delete from public.activity_assignment_capability_actions x using public.activity_group_assignments ga,public.activity_group_links gl where x.assignment_id=ga.id and ga.activity_group_link_id=gl.id and gl.activity_id=a.id; delete from public.activity_admin_capability_actions x using public.activity_admin_assignments aa where x.activity_admin_assignment_id=aa.id and aa.activity_id=a.id; delete from public.activity_group_capability_settings x using public.activity_group_links gl where x.activity_group_link_id=gl.id and gl.activity_id=a.id; delete from public.activity_capability_policies x where x.activity_id=a.id;
 for entry in select * from jsonb_each_text(p_capability_policies) loop if entry.value is not null then select c.id into cap from public.activity_capabilities c where c.code=entry.key and c.status='active'; insert into public.activity_capability_policies(activity_id,institution_id,capability_id,policy_mode,changed_by_person_id) values(a.id,a.institution_id,cap,entry.value,null); end if; end loop;
 for item in select element.value from jsonb_array_elements(p_group_capability_settings) element loop select x.id into gl from public.activity_group_links x where x.activity_id=a.id and x.group_id=app_private.activity_v2_safe_uuid(item->>'group_id') and x.status='active'; if gl is null then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if; for entry in select * from jsonb_each(item->'capabilities') loop if entry.value<>'null'::jsonb then select c.id into cap from public.activity_capabilities c where c.code=entry.key; insert into public.activity_group_capability_settings(activity_group_link_id,capability_id,is_enabled,changed_by_person_id) values(gl,cap,(entry.value#>>'{}')::boolean,null); end if; end loop; end loop;
 for item in select element.value from jsonb_array_elements(p_professional_capability_actions) element loop if item->>'role'='activity_admin' then select x.id into ass from public.activity_admin_assignments x join public.institution_memberships m on m.id=x.membership_id and m.person_id=x.person_id and m.institution_id=a.institution_id and m.status='active' and m.revoked_at is null join public.people person on person.id=x.person_id and person.person_type='adult' and person.status='active' where x.activity_id=a.id and x.institution_id=a.institution_id and x.membership_id=app_private.activity_v2_safe_uuid(item->>'membership_id') and x.status='active' and x.revoked_at is null; else select x.id into ass from public.activity_group_assignments x join public.activity_group_links y on y.id=x.activity_group_link_id and y.institution_id=a.institution_id and y.status='active' join public.institution_memberships m on m.id=x.membership_id and m.person_id=x.person_id and m.institution_id=a.institution_id and m.status='active' and m.revoked_at is null join public.people person on person.id=x.person_id and person.person_type='adult' and person.status='active' where y.activity_id=a.id and y.group_id=app_private.activity_v2_safe_uuid(item->>'group_id') and x.institution_id=a.institution_id and x.membership_id=app_private.activity_v2_safe_uuid(item->>'membership_id') and x.assignment_role='instructor' and x.status='active' and x.revoked_at is null; end if; if ass is null then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if; for entry in select * from jsonb_each_text(item->'actions') loop select c.id into cap from public.activity_capabilities c where c.code=entry.key and c.status='active'; if item->>'role'='activity_admin' then insert into public.activity_admin_capability_actions(activity_admin_assignment_id,capability_id,can_view,can_edit,changed_by_person_id) values(ass,cap,entry.value in('view','both'),entry.value in('edit','both'),null); else insert into public.activity_assignment_capability_actions(assignment_id,capability_id,can_view,can_edit,changed_by_person_id) values(ass,cap,entry.value in('view','both'),entry.value in('edit','both'),null); end if; end loop; end loop;
 update public.activity_definitions x set management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; counts:=pg_catalog.jsonb_build_object('settings',jsonb_array_length(p_group_capability_settings),'actions',jsonb_array_length(p_professional_capability_actions)); correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.manage_permissions','activity.set_permissions',counts); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.set_permissions',h,a.management_version,a.status::text,correlation,counts);
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.manage_permissions','activity.set_permissions',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

-- public.superadmin_activity_set_professionals_v2 [ACTIVITY]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_activity_set_professionals_v2"("p_request_id" "uuid", "p_activity_id" "uuid", "p_expected_version" bigint, "p_professional_assignments" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text; item jsonb; m public.institution_memberships%rowtype; gl uuid;
begin begin select * into strict ctx from app_private.activity_v2_require_context('activities.assign_people',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1 or jsonb_typeof(p_professional_assignments) is distinct from 'array' then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id); if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.assign_people',a.institution_id);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1 or app_private.activity_v2_validate_professionals(a.institution_id,p_professional_assignments) is distinct from true then raise invalid_parameter_value using message='duplicate professional or invalid active membership (max 100)',detail='ACTIVITY_INVALID_INPUT'; end if;
 h:=app_private.activity_v2_command_request_hash('activity.set_professionals',a.institution_id,a.id,p_expected_version,p_professional_assignments); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,a.id,'activity.set_professionals',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update; if a.management_version<>p_expected_version then raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if;
 perform 1 from public.institution_memberships membership where membership.id in(select (requested->>'membership_id')::uuid from jsonb_array_elements(p_professional_assignments) requested) order by membership.id for share;
 perform 1 from public.people person where person.id in(select membership.person_id from public.institution_memberships membership where membership.id in(select (requested->>'membership_id')::uuid from jsonb_array_elements(p_professional_assignments) requested)) order by person.id for share;
 perform 1 from public.activity_group_links gl where gl.activity_id=a.id order by gl.id for share;
 perform 1 from public.activity_group_assignments assignment where assignment.activity_group_link_id in(select gl.id from public.activity_group_links gl where gl.activity_id=a.id) order by assignment.id for update;
 perform 1 from public.activity_admin_assignments assignment where assignment.activity_id=a.id order by assignment.id for update;
 if app_private.activity_v2_validate_professionals(a.institution_id,p_professional_assignments) is distinct from true then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.assign_people','assign_people',correlation);
 update public.activity_group_assignments x set status='inactive',revoked_at=now(),updated_at=now()
 where x.activity_group_link_id in(select id from public.activity_group_links where activity_id=a.id)
   and x.status='active' and x.assignment_role='instructor' and not exists(
    select 1 from jsonb_array_elements(p_professional_assignments)desired_item
    join public.activity_group_links desired on desired.activity_id=a.id and desired.group_id=(desired_item->>'group_id')::uuid
    where desired_item->>'role'='instructor' and (desired_item->>'membership_id')::uuid=x.membership_id and desired.id=x.activity_group_link_id);
 update public.activity_admin_assignments x set status='inactive',revoked_at=now(),updated_at=now()
 where x.activity_id=a.id and x.status='active' and not exists(
  select 1 from jsonb_array_elements(p_professional_assignments)desired_item
  where desired_item->>'role'='activity_admin' and (desired_item->>'membership_id')::uuid=x.membership_id);
 for item in select element.value from jsonb_array_elements(p_professional_assignments) element loop
  select * into m from public.institution_memberships x where x.id=(item->>'membership_id')::uuid;
  if item->>'role'='activity_admin' then
   if not exists(select 1 from public.activity_admin_assignments x where x.activity_id=a.id and x.membership_id=m.id and x.status='active' and x.revoked_at is null) then
    insert into public.activity_admin_assignments(activity_id,institution_id,person_id,membership_id,assigned_by_person_id) values(a.id,a.institution_id,m.person_id,m.id,null);
   end if;
  else
   select id into gl from public.activity_group_links where activity_id=a.id and group_id=(item->>'group_id')::uuid and status='active';
   if gl is null then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
   if not exists(select 1 from public.activity_group_assignments x where x.activity_group_link_id=gl and x.membership_id=m.id and x.assignment_role='instructor' and x.status='active' and x.revoked_at is null) then
    insert into public.activity_group_assignments(activity_group_link_id,institution_id,person_id,membership_id,assignment_role,assigned_by_person_id) values(gl,a.institution_id,m.person_id,m.id,'instructor',null);
   end if;
  end if;
 end loop;
 update public.activity_definitions x set management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.assign_people','activity.set_professionals',pg_catalog.jsonb_build_object('professionals',jsonb_array_length(p_professional_assignments))); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.set_professionals',h,a.management_version,a.status::text,correlation,pg_catalog.jsonb_build_object('professionals',jsonb_array_length(p_professional_assignments)));
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.assign_people','activity.set_professionals',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

-- public.superadmin_activity_set_units_v2 [ACTIVITY]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_activity_set_units_v2"("p_request_id" "uuid", "p_activity_id" "uuid", "p_expected_version" bigint, "p_unit_ids" "uuid"[]) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text;
begin begin select * into strict ctx from app_private.activity_v2_require_context('activities.link_units',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1 or p_unit_ids is null then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id); if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.link_units',a.institution_id);
 if coalesce(cardinality(p_unit_ids),0) not between 1 and 100 or cardinality(p_unit_ids)<>(select count(distinct x) from unnest(p_unit_ids)x) then raise invalid_parameter_value using message='duplicate unit',detail='ACTIVITY_INVALID_INPUT'; end if;
 h:=app_private.activity_v2_command_request_hash('activity.set_units',a.institution_id,a.id,p_expected_version,to_jsonb(p_unit_ids)); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,a.id,'activity.set_units',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update; if a.management_version<>p_expected_version then raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if;
 perform 1 from public.units u where u.id=any(p_unit_ids) order by u.id for share;
 perform 1 from public.activity_unit_links ul where ul.activity_id=a.id order by ul.id for update;
 perform 1 from public.activity_group_links gl where gl.activity_id=a.id order by gl.id for share;
 if exists(select 1 from public.activity_group_links gl join public.activity_unit_links ul on ul.activity_id=gl.activity_id and ul.unit_id=gl.unit_id where gl.activity_id=a.id and gl.status='active' and not(gl.unit_id=any(p_unit_ids))) then raise integrity_constraint_violation using detail='ACTIVITY_DEPENDENCIES_ACTIVE'; end if;
 if (select count(*) from public.units u where u.id=any(p_unit_ids) and u.institution_id=a.institution_id and u.status='active')<>cardinality(p_unit_ids) then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.link_units','link_units',correlation); update public.activity_unit_links l set status='inactive',ends_at=greatest(pg_catalog.clock_timestamp(),l.starts_at+interval '1 microsecond'),updated_at=now() where l.activity_id=a.id and l.status='active' and not(l.unit_id=any(p_unit_ids));
 insert into public.activity_unit_links(activity_id,institution_id,unit_id,linked_by_person_id,status,ends_at) select a.id,a.institution_id,x,null,'active',null from unnest(p_unit_ids)x on conflict(activity_id,unit_id) do update set status='active',ends_at=null,updated_at=now();
 update public.activity_definitions x set management_version=x.management_version+1,updated_at=now() where x.id=a.id returning * into a; correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.link_units','activity.set_units',pg_catalog.jsonb_build_object('units',cardinality(p_unit_ids))); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.set_units',h,a.management_version,a.status::text,correlation,pg_catalog.jsonb_build_object('units',cardinality(p_unit_ids)));
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.link_units','activity.set_units',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

-- public.superadmin_activity_update_v2 [ACTIVITY]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_activity_update_v2"("p_request_id" "uuid", "p_activity_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); a public.activity_definitions%rowtype; h bytea; replay jsonb; code text;
begin begin
 select * into strict ctx from app_private.activity_v2_require_context('activities.manage',null);
 if p_request_id is null or p_activity_id is null or p_expected_version is null or p_expected_version<1
 or p_payload is null or jsonb_typeof(p_payload)<>'object' or p_payload='{}'::jsonb or p_payload-array['name','description','taxonomy_id','icon_key','initials']<>'{}'::jsonb
 or (p_payload?'name' and (jsonb_typeof(p_payload->'name')<>'string' or length(btrim(p_payload->>'name')) not between 1 and 120))
 or (p_payload?'description' and p_payload->'description'<>'null'::jsonb and (jsonb_typeof(p_payload->'description')<>'string' or length(p_payload->>'description')>500))
 or (p_payload?'taxonomy_id' and jsonb_typeof(p_payload->'taxonomy_id')<>'string')
 or (p_payload?'icon_key' and p_payload->'icon_key'<>'null'::jsonb and (jsonb_typeof(p_payload->'icon_key')<>'string' or length(p_payload->>'icon_key')>64))
 or (p_payload?'initials' and p_payload->'initials'<>'null'::jsonb and (jsonb_typeof(p_payload->'initials')<>'string' or length(btrim(p_payload->>'initials')) not between 1 and 2))
 then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id and (ctx.scope_kind<>'institution' or x.institution_id=ctx.scope_institution_id); if a.id is null then raise no_data_found using detail='ACTIVITY_NOT_FOUND'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.manage',a.institution_id); h:=app_private.activity_v2_command_request_hash('activity.update',a.institution_id,p_activity_id,p_expected_version,p_payload); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,a.institution_id,p_activity_id,'activity.update',h,correlation); if replay is not null then return replay; end if;
 select * into a from public.activity_definitions x where x.id=p_activity_id for update; if a.management_version<>p_expected_version then raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if;
 if p_payload?'taxonomy_id' then begin
   perform 1 from public.activity_taxonomies t where t.id=(p_payload->>'taxonomy_id')::uuid order by t.id for share;
  exception when invalid_text_representation then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end;
  if not exists(select 1 from public.activity_taxonomies t where t.id=(p_payload->>'taxonomy_id')::uuid and t.status='active' and t.code<>'outros') then raise foreign_key_violation using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.manage','manage',correlation);
 update public.activity_definitions x set name=case when p_payload?'name' then btrim(p_payload->>'name') else x.name end,description=case when p_payload?'description' then nullif(btrim(p_payload->>'description'),'') else x.description end,taxonomy_id=case when p_payload?'taxonomy_id' then (p_payload->>'taxonomy_id')::uuid else x.taxonomy_id end,identity_icon=case when p_payload?'icon_key' then nullif(p_payload->>'icon_key','') else x.identity_icon end,identity_initials=case when p_payload?'initials' then nullif(p_payload->>'initials','') else x.identity_initials end,management_version=x.management_version+1,updated_at=now() where x.id=p_activity_id returning * into a;
 correlation:=app_private.activity_v2_append_audit(ctx,a.institution_id,a.id,'activities.manage','activity.update','{}'); return app_private.activity_v2_finish_command(ctx,p_request_id,a.institution_id,a.id,'activity.update',h,a.management_version,a.status::text,correlation,'{}');
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 return app_private.activity_v2_denied_envelope('activities.manage','activity.update',code,correlation,case when a.id is null then null else a.institution_id end); end $$;

-- public.superadmin_agenda_command [AGENDA]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_agenda_command"("p_request_id" "uuid", "p_event_id" "uuid", "p_expected_revision" bigint, "p_action" "text", "p_reason" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_actor uuid; v_event public.agenda_events%rowtype; v_next text; v_request uuid;
begin
  if p_action not in ('cancel','restore','delete_draft','request_publication') then raise exception using errcode='22023',message='invalid_agenda_action'; end if;
  if exists(select 1 from public.agenda_history_receipts where request_id=p_request_id and action='delete_draft') then
    return jsonb_build_object('deleted',true,'id',p_event_id);
  end if;
  if exists(select 1 from public.agenda_history_receipts where request_id=p_request_id) then
    return public.superadmin_agenda_get(p_event_id);
  end if;
  v_actor:=app_private.assert_agenda_permission(case when p_action='request_publication' then 'agenda.edit_own' else 'agenda.cancel_restore' end,false);
  select * into v_event from public.agenda_events where id=p_event_id for update;
  if not found then raise exception using errcode='P0002',message='agenda_event_not_found'; end if;
  if p_expected_revision<>v_event.revision then raise exception using errcode='PT409', message='agenda_revision_conflict', detail='AGENDA_STALE_VERSION'; end if;
  if p_action='delete_draft' then
    if v_event.status<>'draft' then raise exception using errcode='22023',message='only_draft_can_be_deleted'; end if;
    insert into public.agenda_history_receipts(request_id,event_id,institution_id,actor_person_id,action,previous_revision,next_revision,reason) values(p_request_id,null,v_event.institution_id,v_actor,'delete_draft',v_event.revision,null,nullif(trim(p_reason),''));
    delete from public.agenda_events where id=v_event.id; return jsonb_build_object('deleted',true,'id',p_event_id);
  elsif p_action='request_publication' then
    if v_event.status<>'draft' then raise exception using errcode='22023',message='only_draft_can_request_publication'; end if;
    insert into public.agenda_publication_requests(event_id,institution_id,requested_by_person_id) values(v_event.id,v_event.institution_id,v_actor) returning id into v_request;
    insert into public.agenda_history_receipts(request_id,event_id,institution_id,actor_person_id,action,previous_revision,next_revision,reason) values(p_request_id,v_event.id,v_event.institution_id,v_actor,'request_publication',v_event.revision,v_event.revision,null);
    return jsonb_build_object('request_id',v_request,'event',public.superadmin_agenda_get(v_event.id));
  else
    if p_action='cancel' and v_event.status not in ('scheduled','published') then raise exception using errcode='22023',message='invalid_cancel_transition'; end if;
    if p_action='restore' and v_event.status<>'canceled' then raise exception using errcode='22023',message='invalid_restore_transition'; end if;
    v_next:=case when p_action='cancel' then 'canceled' else 'published' end;
    update public.agenda_events set status=v_next,revision=revision+1,updated_by_person_id=v_actor,updated_at=now() where id=v_event.id returning * into v_event;
    insert into public.agenda_history_receipts(request_id,event_id,institution_id,actor_person_id,action,previous_revision,next_revision,reason) values(p_request_id,v_event.id,v_event.institution_id,v_actor,p_action,v_event.revision-1,v_event.revision,nullif(trim(p_reason),''));
    return public.superadmin_agenda_get(v_event.id);
  end if;
end; $$;

-- public.superadmin_agenda_save [AGENDA]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_agenda_save"("p_request_id" "uuid", "p_event_id" "uuid", "p_expected_revision" bigint, "p_payload" "jsonb", "p_reason" "text" DEFAULT NULL::"text", "p_override_reservation" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_actor uuid; v_existing public.agenda_events%rowtype; v_event public.agenda_events%rowtype; v_action text; v_status text; v_conflict boolean;
begin
  if p_request_id is null then raise exception using errcode='22023',message='request_id_required'; end if;
  select e.* into v_existing from public.agenda_events e join public.agenda_history_receipts h on h.event_id=e.id where h.request_id=p_request_id;
  if found then return public.superadmin_agenda_get(v_existing.id); end if;
  v_actor:=app_private.assert_agenda_permission(case when p_event_id is null then 'agenda.create' else 'agenda.read' end,false);
  if coalesce(char_length(trim(p_payload->>'title')),0) not between 1 and 240 or (p_payload->>'startsAt')::timestamptz >= (p_payload->>'endsAt')::timestamptz then raise exception using errcode='22023',message='invalid_agenda_event'; end if;
  perform app_private.assert_agenda_context((p_payload->>'institutionId')::uuid,p_payload->>'contextKind',(p_payload->>'contextId')::uuid,coalesce(p_payload->'audience','{}'::jsonb));
  perform app_private.assert_agenda_questions(coalesce(p_payload->'questions','[]'::jsonb));
  v_status:=coalesce(p_payload->>'status','draft');
  if v_status not in ('draft','scheduled','published') then raise exception using errcode='22023',message='invalid_status'; end if;
  if v_status='published' and not app_private.agenda_has_permission('agenda.publish') then raise exception using errcode='42501',message='publish_permission_denied'; end if;
  select exists(select 1 from public.agenda_events e where e.id<>coalesce(p_event_id,gen_random_uuid()) and e.institution_id=(p_payload->>'institutionId')::uuid and e.item_type='resourceReservation' and e.status<>'canceled' and lower(trim(e.location))=lower(trim(p_payload->>'location')) and e.starts_at<(p_payload->>'endsAt')::timestamptz and e.ends_at>(p_payload->>'startsAt')::timestamptz) into v_conflict;
  if v_conflict and not p_override_reservation then raise exception using errcode='23P01',message='reservation_conflict'; end if;
  if v_conflict and (not app_private.agenda_has_permission('agenda.override_reservation') or not app_private.has_mfa_aal2() or coalesce(char_length(trim(p_reason)),0)<1) then raise exception using errcode='42501',message='reservation_override_denied'; end if;
  if p_event_id is null then
    insert into public.agenda_events(institution_id,context_kind,context_id,title,item_type,priority,status,origin,starts_at,ends_at,all_day,time_zone_id,location,description,response_mode,guardian_response_policy,recurrence,audience,reminders,questions,created_by_person_id,updated_by_person_id)
    values((p_payload->>'institutionId')::uuid,p_payload->>'contextKind',(p_payload->>'contextId')::uuid,trim(p_payload->>'title'),p_payload->>'type',coalesce(p_payload->>'priority','normal'),v_status,coalesce(p_payload->>'origin','institution'),(p_payload->>'startsAt')::timestamptz,(p_payload->>'endsAt')::timestamptz,coalesce((p_payload->>'allDay')::boolean,false),coalesce(p_payload->>'timeZoneId','America/Sao_Paulo'),coalesce(p_payload->>'location',''),coalesce(p_payload->>'description',''),coalesce(p_payload->>'responseMode','none'),coalesce(p_payload->>'guardianResponsePolicy','oneIsEnough'),p_payload->'recurrence',coalesce(p_payload->'audience','{}'::jsonb),coalesce(p_payload->'reminders','[]'::jsonb),coalesce(p_payload->'questions','[]'::jsonb),v_actor,v_actor) returning * into v_event;
    v_action:=case when v_conflict then 'override_reservation' else 'create' end;
  else
    select * into v_existing from public.agenda_events where id=p_event_id for update;
    if not found then raise exception using errcode='P0002',message='agenda_event_not_found'; end if;
    if not app_private.agenda_has_permission('agenda.edit_all') and not (v_existing.created_by_person_id=v_actor and app_private.agenda_has_permission('agenda.edit_own')) then raise exception using errcode='42501',message='edit_permission_denied'; end if;
    if p_expected_revision is null or p_expected_revision<>v_existing.revision then raise exception using errcode='PT409', message='agenda_revision_conflict', detail='AGENDA_STALE_VERSION'; end if;
    update public.agenda_events set institution_id=(p_payload->>'institutionId')::uuid,context_kind=p_payload->>'contextKind',context_id=(p_payload->>'contextId')::uuid,title=trim(p_payload->>'title'),item_type=p_payload->>'type',priority=coalesce(p_payload->>'priority','normal'),status=v_status,starts_at=(p_payload->>'startsAt')::timestamptz,ends_at=(p_payload->>'endsAt')::timestamptz,all_day=coalesce((p_payload->>'allDay')::boolean,false),time_zone_id=coalesce(p_payload->>'timeZoneId','America/Sao_Paulo'),location=coalesce(p_payload->>'location',''),description=coalesce(p_payload->>'description',''),response_mode=coalesce(p_payload->>'responseMode','none'),guardian_response_policy=coalesce(p_payload->>'guardianResponsePolicy','oneIsEnough'),recurrence=p_payload->'recurrence',audience=coalesce(p_payload->'audience','{}'::jsonb),reminders=coalesce(p_payload->'reminders','[]'::jsonb),questions=coalesce(p_payload->'questions','[]'::jsonb),updated_by_person_id=v_actor,revision=revision+1,updated_at=now() where id=p_event_id returning * into v_event;
    v_action:=case when v_conflict then 'override_reservation' else 'update' end;
  end if;
  insert into public.agenda_history_receipts(request_id,event_id,institution_id,actor_person_id,action,previous_revision,next_revision,reason) values(p_request_id,v_event.id,v_event.institution_id,v_actor,v_action,v_existing.revision,v_event.revision,nullif(trim(p_reason),''));
  return public.superadmin_agenda_get(v_event.id);
end; $$;

-- public.superadmin_child_context_directory_v2 [CHILD_CONTEXT]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 0, handlers: 1.
create or replace function "public"."superadmin_child_context_directory_v2"("p_institution_id" "uuid" DEFAULT NULL::"uuid", "p_after_name" "text" DEFAULT NULL::"text", "p_after_context_id" "uuid" DEFAULT NULL::"uuid", "p_limit" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  ctx app_private.superadmin_internal_context;
  fresh app_private.superadmin_internal_context;
  effective_institution_id uuid;
  correlation_id uuid := gen_random_uuid();
  error_code text;
  error_detail text;
  items jsonb := '[]'::jsonb;
  next_cursor jsonb := 'null'::jsonb;
  last_key text;
  last_id uuid;
  row_record record;
  row_count integer := 0;
  -- Same C0 + DEL contract as the existing DTO; no extra cadastral restriction.
  control_pattern text := '['||chr(1)||'-'||chr(31)||chr(127)||']';
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('people.read');
    if ctx.platform_role_code is distinct from 'owner'
      or ctx.scope_kind not in('platform','institution') then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;

    -- Stable lock order; hold actor authorization rows through append/return.
    perform 1 from auth.users u where u.id=ctx.auth_user_id for share;
    perform 1 from auth.sessions s where s.id=ctx.session_id and s.user_id=ctx.auth_user_id for share;
    perform 1 from app_private.superadmin_internal_auth_links l where l.id=ctx.internal_auth_link_id for share;
    perform 1 from app_private.superadmin_internal_memberships m where m.id=ctx.internal_membership_id for share;
    perform 1 from public.platform_roles r where r.id=ctx.platform_role_id for share;
    perform 1 from public.platform_permissions p where p.code='people.read' for share;
    perform 1 from public.platform_role_permissions g join public.platform_permissions p on p.id=g.permission_id
      where g.role_id=ctx.platform_role_id and p.code='people.read' for share of g;
    select * into strict fresh from app_private.require_superadmin_internal_context('people.read');
    if fresh is distinct from ctx then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;

    if ctx.scope_kind='institution' then
      if ctx.scope_institution_id is null or (p_institution_id is not null
        and p_institution_id <> ctx.scope_institution_id) then
        raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
      end if;
      effective_institution_id := ctx.scope_institution_id;
    else
      effective_institution_id := p_institution_id;
    end if;
    if effective_institution_id is not null then
      perform 1 from public.institutions i where i.id=effective_institution_id
        and i.deleted_at is null for share;
      if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    end if;
    if p_limit is null or p_limit < 1 or p_limit > 50
      or (p_after_name is null) <> (p_after_context_id is null)
      or (p_after_name is not null and (p_after_name='' or octet_length(p_after_name) > 8192
        or p_after_name ~ control_pattern)) then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;

    -- Materialize only limit+1 locked candidates, then sort the actual returned
    -- values again: READ COMMITTED can observe renamed rows after lock waits.
    -- No cross-page snapshot is promised; cursor never authorizes a resource.
    for row_record in
      with locked as materialized (
        select cc.id, cc.child_person_id, cc.institution_id, p.display_name, i.public_name,
          lower(p.display_name) collate "C" as sort_key
        from public.child_contexts cc join public.people p on p.id=cc.child_person_id
        join public.institutions i on i.id=cc.institution_id
        where cc.status = 'active' and p.person_type = 'child'
          and p.deleted_at is null and i.deleted_at is null
          and (effective_institution_id is null or cc.institution_id = effective_institution_id)
          and (p_after_name is null or (lower(p.display_name) collate "C", cc.id)
            > (p_after_name collate "C", p_after_context_id))
        order by lower(p.display_name) collate "C", cc.id
        limit (p_limit + 1) for share of cc, p, i
      ) select * from locked order by sort_key collate "C", id
    loop
      row_count := row_count + 1;
      if row_count > p_limit then
        if octet_length(last_key) > 8192 then
          raise program_limit_exceeded using message='child directory cursor exceeds transport budget';
        end if;
        next_cursor := jsonb_build_object('name',last_key,'context_id',last_id);
        exit;
      end if;
      if row_record.display_name='' or row_record.public_name=''
        or row_record.display_name ~ control_pattern or row_record.public_name ~ control_pattern then
        raise data_exception using message='child directory projection invalid';
      end if;
      items := items || jsonb_build_array(jsonb_build_object(
        'context_id', row_record.id, 'person_id', row_record.child_person_id,
        'person_name', row_record.display_name, 'institution_id', row_record.institution_id,
        'institution_name', row_record.public_name));
      last_key := row_record.sort_key;
      last_id := row_record.id;
    end loop;
    select * into strict fresh from app_private.require_superadmin_internal_context('people.read');
    if fresh is distinct from ctx then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    if not exists(select 1 from auth.sessions s where s.id=ctx.session_id
      and s.user_id=ctx.auth_user_id and (s.not_after is null or s.not_after > clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code := case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID',
        'SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value then error_code := 'SAI_INVALID_ARGUMENT';
    when serialization_failure or sqlstate 'PT409' or deadlock_detected then error_code := 'SAI_CONCURRENT_CHANGE';
    when others then error_code := 'SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    -- The inherited denial helper uses transaction time. Do not manufacture
    -- an audited actor for a session already expired by the actual wall clock.
    if exists(select 1 from auth.sessions s where s.id::text=auth.jwt()->>'session_id'
      and s.user_id=auth.uid() and (s.not_after is null or s.not_after > clock_timestamp())) then
      perform app_private.audit_superadmin_internal_denial_if_identified(
        'people.read', 'child_context.directory', error_code, correlation_id, null);
    end if;
    return app_private.superadmin_internal_error_envelope(error_code,correlation_id);
  end if;
  -- Outside the error-capture block: failed audit must never release data.
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'people.read',ctx.aal,'child_context.directory','success',null,
    correlation_id,effective_institution_id,'child_context_catalog', null);
  -- Append itself can wait on audit locks. Expiration during that wait must
  -- abort the successful append and response, not return a partial success.
  if not exists(select 1 from auth.sessions s where s.id=ctx.session_id
    and s.user_id=ctx.auth_user_id and (s.not_after is null or s.not_after > clock_timestamp())) then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_SESSION_INVALID';
  end if;
  return jsonb_build_object('ok',true,'data',jsonb_build_object('items',items,'next_cursor',next_cursor),'error',null);
end
$$;

-- public.superadmin_circular_close_v2 [CIRCULAR]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_circular_close_v2"("p_request_id" "uuid", "p_circular_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 target public.circulars%rowtype; result jsonb; prior record; code text;
 hash bytea:=extensions.digest(convert_to(p_circular_id::text||p_expected_version::text,'UTF8'),'sha256');
begin begin
 select * into target from public.circulars c where c.id=p_circular_id and c.deleted_at is null for update;
 if target.id is null then raise no_data_found using detail='CIRCULAR_NOT_FOUND'; end if;
 ctx:=app_private.superadmin_circular_context('circulars.manage',target.institution_id);
 select * into prior from app_private.superadmin_circular_command_receipts receipt
  where receipt.internal_identity_id=ctx.internal_identity_id and receipt.request_id=p_request_id and receipt.action_code='close';
 if prior.result_json is not null then
  if prior.request_hash<>hash then raise unique_violation using detail='CIRCULAR_CONFLICT'; end if;
  return jsonb_build_object('ok',true,'data',prior.result_json,'error',null);
 end if;
 if target.management_version<>p_expected_version then raise exception using errcode='PT409', detail='CIRCULAR_CONFLICT'; end if;
 if target.status not in ('published','scheduled') then raise invalid_parameter_value using detail='CIRCULAR_INVALID_STATE'; end if;
 update public.circulars set status='closed',responses_closed_at=clock_timestamp(),responses_closed_by=null,
  responses_closed_by_internal_identity_id=ctx.internal_identity_id,
  management_version=management_version+1,updated_at=clock_timestamp()
 where id=target.id returning * into target;
 result:=jsonb_build_object('id',target.id,'revision_id',target.current_revision_id,
  'version',target.management_version,'status',target.status::text);
 insert into app_private.superadmin_circular_command_receipts values(ctx.internal_identity_id,p_request_id,'close',hash,result,clock_timestamp());
 insert into app_private.circular_audit(circular_id,revision_id,institution_id,actor_internal_identity_id,event_code,detail)
 values(target.id,target.current_revision_id,target.institution_id,ctx.internal_identity_id,'internal_responses_closed','{}');
 perform app_private.superadmin_circular_audit(ctx,'close',target.id,'success','closed',correlation);
 return jsonb_build_object('ok',true,'data',result,'error',null);
exception when others then get stacked diagnostics code=pg_exception_detail;
 return app_private.superadmin_circular_denied('circulars.manage','close',code,correlation); end; end
$$;

-- public.superadmin_circular_delete_v2 [CIRCULAR]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_circular_delete_v2"("p_request_id" "uuid", "p_circular_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
      raise exception using errcode='PT409', detail = 'CIRCULAR_CONFLICT';
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

-- public.superadmin_circular_publish_v2 [CIRCULAR]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_circular_publish_v2"("p_request_id" "uuid", "p_circular_id" "uuid", "p_expected_version" bigint, "p_publish_at" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 target public.circulars%rowtype; revision public.circular_revisions%rowtype; result jsonb; prior record;
 at timestamptz:=coalesce(p_publish_at,clock_timestamp()); code text;
 hash bytea:=extensions.digest(convert_to(p_circular_id::text||p_expected_version::text||coalesce(p_publish_at::text,'now'),'UTF8'),'sha256');
begin begin
 select * into target from public.circulars c where c.id=p_circular_id and c.deleted_at is null for update;
 if target.id is null then raise no_data_found using detail='CIRCULAR_NOT_FOUND'; end if;
 ctx:=app_private.superadmin_circular_context('circulars.publish',target.institution_id);
 select * into prior from app_private.superadmin_circular_command_receipts receipt
  where receipt.internal_identity_id=ctx.internal_identity_id and receipt.request_id=p_request_id and receipt.action_code='publish';
 if prior.result_json is not null then
  if prior.request_hash<>hash then raise unique_violation using detail='CIRCULAR_CONFLICT'; end if;
  return jsonb_build_object('ok',true,'data',prior.result_json,'error',null);
 end if;
 if target.management_version<>p_expected_version then raise exception using errcode='PT409', detail='CIRCULAR_CONFLICT'; end if;
 if target.working_revision_id is null or target.status in ('closed','archived')
  or not exists(select 1 from public.circular_audience_rules a where a.circular_id=target.id) then
  raise invalid_parameter_value using detail='CIRCULAR_INVALID_STATE';
 end if;
 -- Midia liberada (20260911190300): os links da revisao ja foram validados no save
 -- (asset desta circular, ready, nao excluido).
 select * into revision from public.circular_revisions r where r.id=target.working_revision_id and r.status='working';
 update public.circular_revisions set status='superseded' where circular_id=target.id and status='published';
 update public.circular_revisions set status='published',published_at=clock_timestamp() where id=revision.id;
 update public.circulars set status=case when at>clock_timestamp() then 'scheduled' else 'published' end::public.circular_status,
  current_revision_id=revision.id,working_revision_id=null,publish_at=at,
  published_at=case when at<=clock_timestamp() then coalesce(published_at,clock_timestamp()) else published_at end,
  revised_at=case when published_at is not null then clock_timestamp() end,
  management_version=management_version+1,updated_at=clock_timestamp()
 where id=target.id returning * into target;
 result:=jsonb_build_object('id',target.id,'revision_id',revision.id,'version',target.management_version,'status',target.status::text);
 insert into app_private.superadmin_circular_command_receipts values(ctx.internal_identity_id,p_request_id,'publish',hash,result,clock_timestamp());
 insert into app_private.circular_audit(circular_id,revision_id,institution_id,actor_internal_identity_id,event_code,detail)
 values(target.id,revision.id,target.institution_id,ctx.internal_identity_id,'internal_published',jsonb_build_object('publish_at',at));
 perform app_private.superadmin_circular_audit(ctx,'publish',target.id,'success','published',correlation);
 return jsonb_build_object('ok',true,'data',result,'error',null);
exception when others then get stacked diagnostics code=pg_exception_detail;
 return app_private.superadmin_circular_denied('circulars.publish','publish',code,correlation); end; end
$$;

-- public.superadmin_circular_save_draft_v2 [CIRCULAR]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_circular_save_draft_v2"("p_request_id" "uuid", "p_institution_id" "uuid", "p_unit_id" "uuid", "p_group_id" "uuid", "p_activity_id" "uuid", "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 target public.circulars%rowtype; revision public.circular_revisions%rowtype;
 target_circular_id uuid:=nullif(p_payload->>'id','')::uuid; expected bigint:=coalesce((p_payload->>'version')::bigint,0);
 block jsonb; question jsonb; option jsonb; audience text; asset_id uuid; body text:=''; position int; option_position int;
 hash bytea:=extensions.digest(convert_to(coalesce(p_payload,'{}')::text,'UTF8'),'sha256');
 prior record; result jsonb; code text;
begin begin
 ctx:=app_private.superadmin_circular_context('circulars.manage',p_institution_id);
 perform app_private.superadmin_circular_validate_scope(p_institution_id,p_unit_id,p_group_id,p_activity_id);
 select * into prior from app_private.superadmin_circular_command_receipts receipt
  where receipt.internal_identity_id=ctx.internal_identity_id and receipt.request_id=p_request_id and receipt.action_code='save';
 if prior.result_json is not null then
  if prior.request_hash<>hash then raise unique_violation using detail='CIRCULAR_CONFLICT'; end if;
  return jsonb_build_object('ok',true,'data',prior.result_json,'error',null);
 end if;
 if jsonb_typeof(p_payload)<>'object' or char_length(btrim(coalesce(p_payload->>'title',''))) not between 1 and 120
  or p_payload->>'response_policy' not in ('per_person','per_child_any_guardian','per_child_each_guardian','per_staff_member')
  or jsonb_typeof(coalesce(p_payload->'blocks','[]'))<>'array'
  or jsonb_array_length(coalesce(p_payload->'blocks','[]'))>64
  or (select count(*) from jsonb_array_elements(coalesce(p_payload->'blocks','[]')) item
      where item->>'kind'='question')>10
  or jsonb_typeof(coalesce(p_payload->'audiences','[]'))<>'array' then
  raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT';
 end if;
 for block in select value from jsonb_array_elements(coalesce(p_payload->'blocks','[]')) loop
  if block->>'kind'='text' then body:=body||coalesce(block->>'text',''); end if;
  if block->>'kind' not in ('text','question','media') then raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT'; end if;
  if block->>'kind'='media' and (jsonb_typeof(coalesce(block->'asset_ids','[]'))<>'array'
   or jsonb_array_length(coalesce(block->'asset_ids','[]'))>4) then
   raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT';
  end if;
 end loop;
 if char_length(body)>4000 then raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT'; end if;
 if target_circular_id is null then
  insert into public.circulars(institution_id,unit_id,group_id,activity_id,
   author_internal_identity_id,author_internal_membership_id,response_policy,responses_close_at)
  values(p_institution_id,p_unit_id,p_group_id,p_activity_id,ctx.internal_identity_id,
   ctx.internal_membership_id,(p_payload->>'response_policy')::public.circular_response_policy,
   nullif(p_payload->>'responses_close_at','')::timestamptz) returning * into target;
  insert into public.circular_revisions(circular_id,institution_id,revision_number,title,body_text,
   created_by_internal_identity_id) values(target.id,p_institution_id,1,btrim(p_payload->>'title'),body,
   ctx.internal_identity_id) returning * into revision;
 else
  select * into target from public.circulars c where c.id=target_circular_id and c.institution_id=p_institution_id
   and c.deleted_at is null for update;
  if target.id is null then raise no_data_found using detail='CIRCULAR_NOT_FOUND'; end if;
  if target.management_version<>expected or target.status in ('closed','archived') then
   raise exception using errcode='PT409', detail=case when target.management_version<>expected then 'CIRCULAR_CONFLICT' else 'CIRCULAR_INVALID_STATE' end;
  end if;
  if target.working_revision_id is null then
   insert into public.circular_revisions(circular_id,institution_id,revision_number,title,body_text,
    created_by_internal_identity_id) values(target.id,p_institution_id,
    (select coalesce(max(r.revision_number),0)+1 from public.circular_revisions r where r.circular_id=target.id),
    btrim(p_payload->>'title'),body,ctx.internal_identity_id) returning * into revision;
  else
   select * into revision from public.circular_revisions r where r.id=target.working_revision_id and r.status='working';
   if revision.id is null then raise invalid_parameter_value using detail='CIRCULAR_INVALID_STATE'; end if;
   update public.circular_revisions set title=btrim(p_payload->>'title'),body_text=body where id=revision.id;
   delete from public.circular_media_links where revision_id=revision.id;
   delete from public.circular_blocks where revision_id=revision.id;
  end if;
  delete from public.circular_audience_rules where circular_id=target.id;
  update public.circulars set response_policy=(p_payload->>'response_policy')::public.circular_response_policy,
   responses_close_at=nullif(p_payload->>'responses_close_at','')::timestamptz,
   management_version=management_version+1,updated_at=clock_timestamp() where id=target.id returning * into target;
 end if;
 update public.circulars set working_revision_id=revision.id where id=target.id;
 position:=0;
 for block in select value from jsonb_array_elements(coalesce(p_payload->'blocks','[]')) loop
  insert into public.circular_blocks(id,revision_id,block_kind,display_order,text_content)
  values((block->>'id')::uuid,revision.id,(block->>'kind')::public.circular_block_kind,position,
   case when block->>'kind'='text' then coalesce(block->>'text','') end);
  if block->>'kind'='question' then
   question:=coalesce(block->'question',block);
   if char_length(btrim(coalesce(question->>'prompt',''))) not between 1 and 240
    or question->>'kind' not in ('single_choice','multiple_choice')
    or jsonb_array_length(coalesce(question->'options','[]')) not between 2 and 10 then
    raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT';
   end if;
   insert into public.circular_questions(id,revision_id,block_id,question_kind,prompt,required)
   values((question->>'id')::uuid,revision.id,(block->>'id')::uuid,
    (question->>'kind')::public.circular_question_kind,btrim(question->>'prompt'),
    coalesce((question->>'required')::boolean,false));
   option_position:=0;
   for option in select value from jsonb_array_elements(question->'options') loop
    insert into public.circular_question_options(id,question_id,label,display_order)
    values((option->>'id')::uuid,(question->>'id')::uuid,btrim(option->>'label'),option_position);
    option_position:=option_position+1;
   end loop;
  end if;
  if block->>'kind'='media' then
   -- Cada asset precisa pertencer a ESTA circular, estar finalizado (ready) e
   -- nao excluido; qualquer outro id e CIRCULAR_MEDIA_BLOCKED (nao vaza existencia).
   for asset_id in select value::uuid from jsonb_array_elements_text(coalesce(block->'asset_ids','[]')) loop
    if not exists(select 1 from public.circular_media_assets asset where asset.id=asset_id
      and asset.circular_id=target.id and asset.institution_id=p_institution_id and asset.status='ready') then
     raise invalid_parameter_value using detail='CIRCULAR_MEDIA_BLOCKED';
    end if;
    insert into public.circular_media_links(revision_id,block_id,media_asset_id,display_order)
    values(revision.id,(block->>'id')::uuid,asset_id,
     (select count(*)::smallint from public.circular_media_links link where link.revision_id=revision.id));
   end loop;
  end if;
  position:=position+1;
 end loop;
 for audience in select value from jsonb_array_elements_text(coalesce(p_payload->'audiences','[]')) loop
  if audience not in ('families','students','school_staff','guardians_only') then
   raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT';
  end if;
  insert into public.circular_audience_rules(circular_id,revision_id,institution_id,audience_kind,scope_kind,
   unit_id,group_id,activity_id) values(target.id,revision.id,p_institution_id,
   audience::public.circular_audience_kind,
   case when p_activity_id is not null then 'activity' when p_group_id is not null then 'group'
    when p_unit_id is not null then 'unit' else 'institution' end::public.circular_scope_kind,
   case when p_activity_id is null then p_unit_id end,
   case when p_activity_id is null then p_group_id end,p_activity_id);
 end loop;
 result:=jsonb_build_object('id',target.id,'revision_id',revision.id,
  'version',target.management_version,'status',target.status::text);
 insert into app_private.superadmin_circular_command_receipts
  values(ctx.internal_identity_id,p_request_id,'save',hash,result,clock_timestamp());
 insert into app_private.circular_audit(circular_id,revision_id,institution_id,
  actor_internal_identity_id,event_code,detail) values(target.id,revision.id,p_institution_id,
  ctx.internal_identity_id,'internal_draft_saved',jsonb_build_object('version',target.management_version));
 perform app_private.superadmin_circular_audit(ctx,'save',target.id,'success','saved',correlation);
 return jsonb_build_object('ok',true,'data',result,'error',null);
exception when others then get stacked diagnostics code=pg_exception_detail;
 return app_private.superadmin_circular_denied('circulars.manage','save',code,correlation); end; end
$$;

-- public.superadmin_group_location_create_v2 [GROUP_LOCATION]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 4, handlers: 1.
create or replace function "public"."superadmin_group_location_create_v2"("p_request_id" "uuid", "p_location_id" "uuid", "p_group_payload" "jsonb", "p_reservation" "jsonb" DEFAULT NULL::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
<<command>>
declare
 ctx app_private.superadmin_internal_context; initial_ctx app_private.superadmin_internal_context;
 target public.activity_locations%rowtype; target_unit public.units%rowtype; created_group public.groups%rowtype;
 receipt app_private.group_location_create_receipts%rowtype;
 permissions text[]:=array['groups.manage','groups.read','locations.read'];
 reservation_request uuid; institution_id uuid; unit_id uuid; group_id uuid;
 owner_kind text; owner_id uuid; request_hash bytea; consumer jsonb;
 result jsonb; reservation_result jsonb; correlation uuid:=gen_random_uuid();
 audit_institution_id uuid; error_code text; error_detail text;
begin
 begin
   if p_request_id is null or p_location_id is null or p_group_payload is null
     or jsonb_typeof(p_group_payload) is distinct from 'object'
     or current_setting('transaction_isolation')<>'read committed' then raise invalid_parameter_value; end if;
   if not(p_group_payload ?& array['institution_id','unit_id','name','group_type','group_type_other_text'])
     or (select count(*) from jsonb_object_keys(p_group_payload))<>5
     or jsonb_typeof(p_group_payload->'institution_id') is distinct from 'string'
     or jsonb_typeof(p_group_payload->'unit_id') is distinct from 'string'
     or jsonb_typeof(p_group_payload->'name') is distinct from 'string'
     or jsonb_typeof(p_group_payload->'group_type') is distinct from 'string'
     or jsonb_typeof(p_group_payload->'group_type_other_text') not in('string','null')
     or nullif(btrim(p_group_payload->>'name'),'') is null
     or nullif(btrim(p_group_payload->>'group_type'),'') is null
     or (lower(btrim(p_group_payload->>'group_type'))='other' and nullif(btrim(p_group_payload->>'group_type_other_text'),'') is null)
   then raise invalid_parameter_value; end if;
   institution_id:=(p_group_payload->>'institution_id')::uuid;
   unit_id:=(p_group_payload->>'unit_id')::uuid;
   if p_reservation is not null then
     if jsonb_typeof(p_reservation) is distinct from 'object' then raise invalid_parameter_value; end if;
     if not(p_reservation ?& array['first_occurrence','recurrence','conflict_justification'])
       or (select count(*) from jsonb_object_keys(p_reservation))<>3 then raise invalid_parameter_value; end if;
     permissions:=permissions||array['locations.reservations.manage'];
   end if;
   initial_ctx:=app_private.group_location_authorize_v2(permissions);
   ctx:=initial_ctx;
   request_hash:=extensions.digest(convert_to(jsonb_build_object('group',p_group_payload,'location_id',p_location_id,'reservation',p_reservation)::text,'UTF8'),'sha256');
   reservation_request:=app_private.group_location_reservation_request_v2(ctx.internal_identity_id,p_request_id);
   -- Request locks before owner/location, then the real unit and Group rows.
   perform pg_advisory_xact_lock(hashtextextended('group-location-request:'||ctx.internal_identity_id::text||':'||p_request_id::text,0));
   if p_reservation is not null then
     perform pg_advisory_xact_lock(hashtextextended('location-reservation-request:'||ctx.internal_identity_id::text||':'||reservation_request::text,0));
   end if;
   ctx:=app_private.group_location_authorize_v2(permissions,initial_ctx);
   select l.scope_kind,coalesce(l.unit_id,l.institution_id) into owner_kind,owner_id from public.activity_locations l where l.id=p_location_id;
   if owner_id is null then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
   perform pg_advisory_xact_lock_shared(hashtextextended('location-reservation-owner:'||owner_kind||':'||owner_id::text,0));
   target:=app_private.superadmin_location_locked_v2(ctx,p_location_id);
   if target.scope_kind is distinct from owner_kind or coalesce(target.unit_id,target.institution_id) is distinct from owner_id then
     raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if;
   audit_institution_id:=target.institution_id;
   if institution_id is distinct from target.institution_id or (target.scope_kind='unit' and unit_id is distinct from target.unit_id) then
     raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
   perform app_private.superadmin_location_owner_v2(ctx,'unit',institution_id,unit_id);
   select u.* into target_unit from public.units u where u.id=command.unit_id and u.institution_id=command.institution_id for share;
   if not found or target_unit.status<>'active' then raise invalid_parameter_value; end if;
   ctx:=app_private.group_location_authorize_v2(permissions,initial_ctx);
   select r.* into receipt from app_private.group_location_create_receipts r
     where r.actor_id=ctx.internal_identity_id and r.request_id=p_request_id;
   if found then
     if receipt.request_hash is distinct from request_hash or receipt.location_id is distinct from target.id then
       raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if;
     group_id:=receipt.group_id;
     select g.* into created_group from public.groups g where g.id=command.group_id for share;
     if not found or created_group.institution_id is distinct from institution_id or created_group.unit_id is distinct from unit_id
       or created_group.management_version is distinct from (receipt.result->>'management_version')::bigint
       or created_group.status::text is distinct from receipt.result->>'status'
       or not exists(select 1 from public.group_location_selections s where s.group_id=created_group.id and s.location_id=target.id)
     then raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if;
     result:=receipt.result||jsonb_build_object('replayed',true);
   else
     if target.status<>'active' then raise invalid_parameter_value; end if;
     if p_reservation is not null and exists(select 1 from app_private.location_reservation_receipts r
       where r.actor_id=ctx.internal_identity_id and r.request_id=reservation_request) then
       raise exception using errcode='PT409', detail='SAI_CONCURRENT_CHANGE'; end if;
     insert into public.groups(institution_id,unit_id,name,group_type,group_type_other_text,status,
       inherit_appearance,inherit_access,inherit_activities,management_version)
     values(command.institution_id,command.unit_id,btrim(p_group_payload->>'name'),lower(btrim(p_group_payload->>'group_type')),
       nullif(btrim(p_group_payload->>'group_type_other_text'),''),'draft',true,true,true,1)
       returning * into created_group;
     group_id:=created_group.id;
     consumer:=jsonb_build_object('kind','group','id',group_id);
     perform app_private.location_reservation_consumer_v2(ctx,target,consumer,p_reservation is not null);
     insert into public.group_location_selections(group_id,location_id,created_by_internal_identity_id)
       values(command.group_id,target.id,ctx.internal_identity_id);
     if p_reservation is not null then
       reservation_result:=public.superadmin_location_reservation_create_v2(
         p_reservation||jsonb_build_object('location_id',target.id,'consumer',consumer),reservation_request);
       if reservation_result->>'ok' is distinct from 'true' then
         raise exception using detail=coalesce(reservation_result#>>'{error,code}','SAI_INTERNAL_ERROR'); end if;
     end if;
     result:=jsonb_build_object('group_id',group_id,'management_version',created_group.management_version,
       'status',created_group.status,'location_id',target.id,'reservation',reservation_result->'data',
       'correlation_id',correlation,'replayed',false);
     insert into app_private.group_location_create_receipts(actor_id,request_id,request_hash,group_id,location_id,result)
       values(ctx.internal_identity_id,p_request_id,command.request_hash,command.group_id,target.id,command.result);
   end if;
   consumer:=jsonb_build_object('kind','group','id',group_id);
   perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
     ctx.internal_membership_id,ctx.session_id,'groups.manage',ctx.aal,'group.location.create','success',null,
     correlation,target.institution_id,'group',group_id);
   perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
   perform app_private.superadmin_location_owner_v2(ctx,'unit',institution_id,unit_id);
   perform app_private.location_reservation_consumer_v2(ctx,target,consumer,p_reservation is not null);
   if not exists(select 1 from public.units u where u.id=command.unit_id
     and u.institution_id=command.institution_id and u.status='active') then
     raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
   if result#>>'{reservation,confirmed_over_conflict}'='true' then
     perform app_private.require_superadmin_internal_context('locations.reservations.override'); end if;
   ctx:=app_private.group_location_authorize_v2(permissions,initial_ctx);
 exception when others then
   get stacked diagnostics error_detail=pg_exception_detail;
   error_code:=case when sqlstate in('22023','22P02','22003','23514') then 'SAI_INVALID_ARGUMENT'
     when sqlstate in('40001','23505','PT409') or error_detail='SAI_CONCURRENT_CHANGE' then 'SAI_CONCURRENT_CHANGE'
     when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
       'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED','SAI_INVALID_ARGUMENT') then error_detail
     when sqlstate='42501' then 'SAI_PERMISSION_DENIED' else 'SAI_INTERNAL_ERROR' end;
 end;
 if error_code is not null then
   perform app_private.audit_superadmin_internal_denial_if_identified('groups.manage','group.location.create',error_code,correlation,audit_institution_id);
   return app_private.superadmin_internal_error_envelope(error_code,correlation);
 end if;
 return jsonb_build_object('ok',true,'data',result,'error',null);
end $$;

-- public.superadmin_institution_contacts_edit_v1 [INSTITUTION]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 0, handlers: 1.
create or replace function "public"."superadmin_institution_contacts_edit_v1"("p_request_id" "uuid", "p_institution_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  context_record app_private.superadmin_internal_context;
  correlation_id uuid := gen_random_uuid();
  normalized_payload jsonb;
  request_hash bytea;
  response_data jsonb;
  error_code text;
  error_detail text;
begin
  begin
    select * into strict context_record
    from app_private.require_superadmin_internal_context('institution.update');

    if context_record.platform_role_code not in ('owner','operations') then
      raise insufficient_privilege using
        message = 'internal institution access denied', detail = 'SAI_PERMISSION_DENIED';
    end if;
    if p_institution_id is null
      or (context_record.scope_kind = 'institution'
        and context_record.scope_institution_id is distinct from p_institution_id) then
      raise insufficient_privilege using
        message = 'internal institution access denied', detail = 'SAI_PERMISSION_DENIED';
    end if;
    if p_request_id is null or p_expected_version is null or p_expected_version <= 0 then
      raise invalid_parameter_value using
        message = 'invalid institution contacts request', detail = 'SAI_INVALID_ARGUMENT';
    end if;

    normalized_payload := app_private.superadmin_institution_contacts_validate_v1(p_payload);
    request_hash := app_private.superadmin_institution_contacts_request_hash_v1(
      p_institution_id, p_expected_version, normalized_payload);
    response_data := app_private.superadmin_institution_contacts_apply_v1(
      p_request_id, p_institution_id, p_expected_version, normalized_payload,
      request_hash, context_record, correlation_id);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail in (
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED'
      ) then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation or unique_violation
      or foreign_key_violation or not_null_violation or invalid_text_representation then
      error_code := 'SAI_INVALID_ARGUMENT';
    when serialization_failure or sqlstate 'PT409' then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail = 'SAI_CONCURRENT_CHANGE'
        then error_detail else 'SAI_INTERNAL_ERROR' end;
    when others then
      error_code := 'SAI_INTERNAL_ERROR';
  end;

  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'institution.update', 'institution.edit_contacts', error_code, correlation_id,
      case when context_record.scope_kind = 'institution'
        then context_record.scope_institution_id end);
    return app_private.superadmin_internal_error_envelope(error_code, correlation_id);
  end if;

  perform app_private.audit_append_superadmin_internal(
    context_record.internal_identity_id,
    context_record.internal_auth_link_id,
    context_record.internal_membership_id,
    context_record.session_id,
    'institution.update',
    context_record.aal,
    case when (response_data ->> 'replayed')::boolean
      then 'institution.edit_contacts.replay' else 'institution.edit_contacts' end,
    'success',
    null,
    correlation_id,
    p_institution_id,
    'institution',
    p_institution_id
  );

  return pg_catalog.jsonb_build_object('ok', true, 'data', response_data, 'error', null);
end
$$;

-- public.superadmin_institution_edit_core_v2 [INSTITUTION]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 0, handlers: 1.
create or replace function "public"."superadmin_institution_edit_core_v2"("p_request_id" "uuid", "p_institution_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  context_record app_private.superadmin_internal_context;
  correlation_id uuid:=gen_random_uuid();
  normalized_payload jsonb;
  request_hash bytea;
  response_data jsonb;
  error_code text;
  error_detail text;
begin
  begin
    select * into strict context_record
    from app_private.require_superadmin_internal_context('institution.update');

    if context_record.platform_role_code not in('owner','operations') then
      raise insufficient_privilege using
        message='internal institution access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    if p_institution_id is null
      or (context_record.scope_kind='institution'
        and context_record.scope_institution_id is distinct from p_institution_id) then
      raise insufficient_privilege using
        message='internal institution access denied',detail='SAI_PERMISSION_DENIED';
    end if;

    if p_request_id is null or p_expected_version is null or p_expected_version<=0 then
      raise invalid_parameter_value using
        message='invalid institution edit request',detail='SAI_INVALID_ARGUMENT';
    end if;
    normalized_payload:=
      app_private.superadmin_institution_edit_core_validate_v2(p_payload);
    request_hash:=app_private.superadmin_institution_edit_core_request_hash_v2(
      p_institution_id,p_expected_version,normalized_payload
    );
    response_data:=app_private.superadmin_institution_edit_core_apply_v2(
      p_request_id,p_institution_id,p_expected_version,normalized_payload,
      request_hash,context_record,correlation_id
    );
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail in(
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED'
      ) then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation or unique_violation
      or foreign_key_violation then
      error_code:='SAI_INVALID_ARGUMENT';
    when serialization_failure or sqlstate 'PT409' then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail='SAI_CONCURRENT_CHANGE'
        then error_detail else 'SAI_INTERNAL_ERROR' end;
    when others then
      error_code:='SAI_INTERNAL_ERROR';
  end;

  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'institution.update','institution.edit_core',error_code,correlation_id,
      case when context_record.scope_kind='institution'
        then context_record.scope_institution_id end
    );
    return app_private.superadmin_internal_error_envelope(
      error_code,correlation_id
    );
  end if;

  perform app_private.audit_append_superadmin_internal(
    context_record.internal_identity_id,
    context_record.internal_auth_link_id,
    context_record.internal_membership_id,
    context_record.session_id,
    'institution.update',
    context_record.aal,
    case when (response_data->>'replayed')::boolean
      then 'institution.edit_core.replay' else 'institution.edit_core' end,
    'success',
    null,
    correlation_id,
    p_institution_id,
    'institution',
    p_institution_id
  );

  return pg_catalog.jsonb_build_object(
    'ok',true,'data',response_data,'error',null
  );
end
$$;

-- public.superadmin_internal_user_change_status [INTERNAL_USER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_internal_user_change_status"("p_request_id" "uuid", "p_internal_identity_id" "uuid", "p_expected_version" bigint, "p_status" "text", "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context;correlation uuid:=gen_random_uuid();
  membership_record app_private.superadmin_internal_memberships%rowtype;
  auth_link app_private.superadmin_internal_auth_links%rowtype;result jsonb;action_code text;
  fingerprint bytea;receipt app_private.superadmin_internal_user_command_receipts%rowtype;
  error_state text;error_detail text;reason_code text;audit_institution_id uuid;
begin
  select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.member.suspend');
  audit_institution_id:=case when ctx.scope_kind='institution'
    then ctx.scope_institution_id else null end;
  if p_request_id is null or p_internal_identity_id is null
    or p_expected_version is null or p_expected_version<1
    or p_status is null or p_status not in('active','suspended','revoked')
    or length(btrim(coalesce(p_reason,''))) not between 8 and 500 then
    raise invalid_parameter_value using message='invalid internal status command';
  end if;
  if not app_private.superadmin_internal_user_target_allowed(ctx,p_internal_identity_id) then
    raise insufficient_privilege using message='internal user unavailable',detail='SAI_PERMISSION_DENIED';
  end if;
  fingerprint:=extensions.digest(pg_catalog.convert_to(pg_catalog.jsonb_build_object(
    'identity_id',p_internal_identity_id,'expected_version',p_expected_version,
    'status',p_status,'reason',btrim(p_reason))::text,'UTF8'),'sha256');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('coelo.internal-user-command:'||p_request_id::text,0));
  select * into receipt from app_private.superadmin_internal_user_command_receipts
    where request_id=p_request_id;
  if receipt.request_id is not null then
    if receipt.actor_internal_identity_id is distinct from ctx.internal_identity_id
      or receipt.action_code<>'status' or receipt.request_hash<>fingerprint then
      raise invalid_parameter_value using message='idempotency key reused with another command';
    end if;
    return receipt.result;
  end if;
  select * into strict membership_record from app_private.superadmin_internal_memberships
    where internal_identity_id=p_internal_identity_id
    order by (status='active') desc,created_at desc limit 1 for update;
  select * into strict auth_link from app_private.superadmin_internal_auth_links
    where internal_identity_id=p_internal_identity_id
    order by (status='active') desc,created_at desc limit 1 for update;
  if greatest(membership_record.version,auth_link.version)<>p_expected_version then
    raise exception using errcode='PT409', message='concurrent internal user change',detail='SAI_CONCURRENT_CHANGE';
  end if;
  if membership_record.status='revoked' then
    raise object_not_in_prerequisite_state using message='revoked internal access is terminal';
  end if;
  update app_private.superadmin_internal_memberships set
    status=p_status::app_private.superadmin_internal_membership_status,
    suspended_at=case when p_status='suspended' then now() else null end,
    revoked_at=case when p_status='revoked' then now() else null end,
    changed_by_internal_identity_id=ctx.internal_identity_id,version=version+1
  where id=membership_record.id;
  update app_private.superadmin_internal_auth_links set
    status=p_status::app_private.superadmin_internal_auth_link_status,
    suspended_at=case when p_status='suspended' then now() else null end,
    revoked_at=case when p_status='revoked' then now() else null end,
    changed_by_internal_identity_id=ctx.internal_identity_id,version=version+1
  where id=auth_link.id;
  action_code:=case p_status when 'suspended' then 'superadmin.internal-users.suspend'
    when 'active' then 'superadmin.internal-users.reactivate'
    else 'superadmin.internal-users.revoke' end;
  result:=app_private.superadmin_internal_user_projection(p_internal_identity_id,true);
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
    ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'platform.member.suspend',ctx.aal,action_code,'success',null,correlation,
    null,'superadmin_internal_identity',p_internal_identity_id);
  insert into app_private.superadmin_internal_user_command_receipts(
    request_id,actor_internal_identity_id,action_code,request_hash,result
  ) values(p_request_id,ctx.internal_identity_id,'status',fingerprint,result);
  return result;
exception when others then
  get stacked diagnostics error_state=returned_sqlstate,error_detail=pg_exception_detail;
  reason_code:=app_private.superadmin_internal_user_denial_code(error_state,error_detail);
  perform app_private.audit_superadmin_internal_denial_if_identified(
    'platform.member.suspend','superadmin.internal-users.status',reason_code,correlation,
    audit_institution_id);
  return app_private.superadmin_internal_user_error_envelope(reason_code,correlation);
end
$$;

-- public.superadmin_internal_user_update [INTERNAL_USER]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_internal_user_update"("p_request_id" "uuid", "p_internal_identity_id" "uuid", "p_expected_version" bigint, "p_reason" "text", "p_draft" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context;correlation uuid:=gen_random_uuid();
  profile_record app_private.superadmin_internal_profiles%rowtype;
  membership_record app_private.superadmin_internal_memberships%rowtype;
  target_role public.platform_roles%rowtype;scope_id uuid;result jsonb;
  fingerprint bytea;receipt app_private.superadmin_internal_user_command_receipts%rowtype;
  error_state text;error_detail text;reason_code text;audit_institution_id uuid;
begin
  select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.member.update');
  audit_institution_id:=case when ctx.scope_kind='institution'
    then ctx.scope_institution_id else null end;
  if p_request_id is null or p_internal_identity_id is null
    or p_expected_version is null or p_expected_version<1
    or length(btrim(coalesce(p_reason,''))) not between 8 and 500
    or p_draft is null or pg_column_size(p_draft)>32768
    or jsonb_typeof(p_draft)<>'object' or jsonb_typeof(p_draft->'identity')<>'object'
    or (select array_agg(key order by key) from jsonb_object_keys(p_draft) key)
      is distinct from array['identity','profile_id','scope','scope_ids']::text[]
    or (select array_agg(key order by key) from jsonb_object_keys(p_draft->'identity') key)
      is distinct from array['additional_phone','birth_date','city','complement','country','cpf','department',
        'display_name','first_name','internal_function','job_title','last_name','mobile',
        'neighborhood','number','postal_code','professional_email','professional_notes','state',
        'street']::text[]
    or jsonb_typeof(p_draft->'profile_id')<>'string'
    or jsonb_typeof(p_draft->'scope')<>'string'
    or p_draft->>'scope' is null or p_draft->>'scope' not in('platform','limited')
    or jsonb_typeof(p_draft->'scope_ids')<>'array'
    or jsonb_array_length(p_draft->'scope_ids')>100
    or (select count(*)<>count(distinct value)
      from jsonb_array_elements_text(p_draft->'scope_ids')) then
    raise invalid_parameter_value using message='invalid internal user command';
  end if;
  if not app_private.superadmin_internal_user_target_allowed(ctx,p_internal_identity_id) then
    raise insufficient_privilege using message='internal user unavailable',detail='SAI_PERMISSION_DENIED';
  end if;
  if ctx.scope_kind='institution' and (
    p_draft->>'scope'<>'limited' or jsonb_array_length(p_draft->'scope_ids')<>1
    or (p_draft->'scope_ids'->>0)::uuid is distinct from ctx.scope_institution_id) then
    raise insufficient_privilege using message='internal user scope escalation denied',detail='SAI_PERMISSION_DENIED';
  end if;
  fingerprint:=extensions.digest(pg_catalog.convert_to(pg_catalog.jsonb_build_object(
    'identity_id',p_internal_identity_id,'expected_version',p_expected_version,
    'reason',btrim(p_reason),'draft',p_draft)::text,'UTF8'),'sha256');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('coelo.internal-user-command:'||p_request_id::text,0));
  select * into receipt from app_private.superadmin_internal_user_command_receipts
    where request_id=p_request_id;
  if receipt.request_id is not null then
    if receipt.actor_internal_identity_id is distinct from ctx.internal_identity_id
      or receipt.action_code<>'update' or receipt.request_hash<>fingerprint then
      raise invalid_parameter_value using message='idempotency key reused with another command';
    end if;
    return receipt.result;
  end if;
  select * into strict profile_record from app_private.superadmin_internal_profiles
    where internal_identity_id=p_internal_identity_id for update;
  select * into strict membership_record from app_private.superadmin_internal_memberships
    where internal_identity_id=p_internal_identity_id
    order by (status='active') desc,created_at desc limit 1 for update;
  if greatest(profile_record.version,membership_record.version)<>p_expected_version then
    raise exception using errcode='PT409', message='concurrent internal user change',detail='SAI_CONCURRENT_CHANGE';
  end if;
  if lower(btrim(p_draft#>>'{identity,professional_email}'))
      is distinct from profile_record.professional_email then
    raise object_not_in_prerequisite_state using
      message='active internal credential email is immutable';
  end if;
  select * into strict target_role from public.platform_roles
    where id=(p_draft->>'profile_id')::uuid and status='active';
  if target_role.code='owner' and p_draft->>'scope'<>'platform' then
    raise check_violation using message='owner requires platform scope';
  end if;
  update app_private.superadmin_internal_profiles set
    first_name=btrim(p_draft#>>'{identity,first_name}'),
    last_name=btrim(p_draft#>>'{identity,last_name}'),
    display_name=coalesce(btrim(p_draft#>>'{identity,display_name}'),''),
    birth_date=nullif(p_draft#>>'{identity,birth_date}','')::date,
    cpf=regexp_replace(coalesce(p_draft#>>'{identity,cpf}',''),'\D','','g'),
    professional_email=lower(btrim(p_draft#>>'{identity,professional_email}')),
    mobile=coalesce(btrim(p_draft#>>'{identity,mobile}'),''),
    additional_phone=coalesce(btrim(p_draft#>>'{identity,additional_phone}'),''),
    job_title=btrim(p_draft#>>'{identity,job_title}'),
    department=coalesce(btrim(p_draft#>>'{identity,department}'),''),
    internal_function=coalesce(btrim(p_draft#>>'{identity,internal_function}'),''),
    professional_notes=coalesce(btrim(p_draft#>>'{identity,professional_notes}'),''),
    postal_code=coalesce(btrim(p_draft#>>'{identity,postal_code}'),''),
    street=coalesce(btrim(p_draft#>>'{identity,street}'),''),
    address_number=coalesce(btrim(p_draft#>>'{identity,number}'),''),
    complement=coalesce(btrim(p_draft#>>'{identity,complement}'),''),
    neighborhood=coalesce(btrim(p_draft#>>'{identity,neighborhood}'),''),
    city=coalesce(btrim(p_draft#>>'{identity,city}'),''),
    state=coalesce(btrim(p_draft#>>'{identity,state}'),''),
    country=coalesce(nullif(btrim(p_draft#>>'{identity,country}'),''),'Brasil'),
    updated_at=now(),version=version+1
  where internal_identity_id=p_internal_identity_id;
  update app_private.superadmin_internal_memberships set
    platform_role_id=target_role.id,
    scope_kind=case when p_draft->>'scope'='platform' then 'platform'
      else 'institution' end::app_private.superadmin_internal_scope_kind,
    scope_institution_id=case when p_draft->>'scope'='platform' then null
      else (p_draft->'scope_ids'->>0)::uuid end,
    changed_by_internal_identity_id=ctx.internal_identity_id,version=version+1
  where id=membership_record.id;
  delete from app_private.superadmin_internal_membership_scopes
    where membership_id=membership_record.id;
  if p_draft->>'scope'='limited' then
    for scope_id in select value::uuid from pg_catalog.jsonb_array_elements_text(
      coalesce(p_draft->'scope_ids','[]'::jsonb)) loop
      if not exists(select 1 from public.institutions institution where institution.id=scope_id) then
        raise foreign_key_violation using message='unknown institution scope';
      end if;
      insert into app_private.superadmin_internal_membership_scopes(membership_id,institution_id)
        values(membership_record.id,scope_id) on conflict do nothing;
    end loop;
    if not exists(select 1 from app_private.superadmin_internal_membership_scopes
      where membership_id=membership_record.id) then
      raise check_violation using message='limited scope requires institution';
    end if;
  end if;
  result:=app_private.superadmin_internal_user_projection(p_internal_identity_id,true);
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
    ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'platform.member.update',ctx.aal,'superadmin.internal-users.update','success',null,
    correlation,null,'superadmin_internal_identity',p_internal_identity_id);
  insert into app_private.superadmin_internal_user_command_receipts(
    request_id,actor_internal_identity_id,action_code,request_hash,result
  ) values(p_request_id,ctx.internal_identity_id,'update',fingerprint,result);
  return result;
exception when others then
  get stacked diagnostics error_state=returned_sqlstate,error_detail=pg_exception_detail;
  reason_code:=app_private.superadmin_internal_user_denial_code(error_state,error_detail);
  perform app_private.audit_superadmin_internal_denial_if_identified(
    'platform.member.update','superadmin.internal-users.update',reason_code,correlation,
    audit_institution_id);
  return app_private.superadmin_internal_user_error_envelope(reason_code,correlation);
end
$$;

-- public.superadmin_invite_issue_v2 [INVITE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 1.
create or replace function "public"."superadmin_invite_issue_v2"("p_request_id" "uuid", "p_institution_id" "uuid", "p_unit_id" "uuid", "p_group_id" "uuid", "p_profile_id" "uuid", "p_target_person_id" "uuid", "p_recipient_email" "text", "p_channels" "text"[], "p_expires_in_hours" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare ctx app_private.superadmin_internal_context;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
  normalized_channels text[]; normalized_email text; target_hash text;
  masked_destination text; clear_token text; stored_token_hash text;
  request_hash bytea; invitation_id uuid:=gen_random_uuid(); invite_payload jsonb;
  result jsonb; receipt app_private.superadmin_internal_invite_receipts%rowtype;
  scope_kind text; profile_code text;
begin
  begin
    select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.invites.manage');
    if ctx.platform_role_code<>'owner' or ctx.scope_kind<>'platform'
      or ctx.scope_institution_id is not null then
      raise insufficient_privilege using
        message='internal invitation access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    select array_agg(distinct channel order by channel)
      into normalized_channels from unnest(p_channels) channel;
    normalized_email:=lower(btrim(p_recipient_email));
    if p_request_id is null or p_institution_id is null or p_profile_id is null
      or p_expires_in_hours not between 1 and 168
      or normalized_channels is null or cardinality(normalized_channels) not between 1 and 2
      or not(normalized_channels <@ array['email','link']::text[])
      or ((p_target_person_id is null)=(normalized_email is null or normalized_email=''))
      or (normalized_email is not null and(
        length(normalized_email)>254
        or normalized_email!~'^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
      )) then
      raise invalid_parameter_value using
        message='invalid invitation issue request',detail='SAI_INVALID_ARGUMENT';
    end if;
    scope_kind:=case when p_group_id is not null then 'group'
      when p_unit_id is not null then 'unit' else 'institution' end;
    if not exists(select 1 from public.institutions institution
      where institution.id=p_institution_id and institution.status='active')
      or (p_unit_id is not null and not exists(select 1 from public.units unit_record
        where unit_record.id=p_unit_id and unit_record.institution_id=p_institution_id
          and unit_record.status='active'))
      or (p_group_id is not null and(p_unit_id is null or not exists(
        select 1 from public.groups group_record where group_record.id=p_group_id
          and group_record.unit_id=p_unit_id
          and group_record.institution_id=p_institution_id
          and group_record.status='active'))) then
      raise insufficient_privilege using
        message='invitation hierarchy denied',detail='SAI_PERMISSION_DENIED';
    end if;
    select profile_record.code into profile_code
    from public.institution_roles profile_record
    where profile_record.id=p_profile_id and profile_record.status='active'
      and(profile_record.institution_id=p_institution_id
        or profile_record.institution_id is null)
      and app_private.access_scope_rank(scope_kind)
        <=app_private.access_scope_rank(profile_record.max_scope_kind);
    if profile_code is null or(p_target_person_id is not null and not exists(
      select 1 from public.people person_record
      where person_record.id=p_target_person_id and person_record.status='active'
        and person_record.person_type='adult'
    )) then
      raise insufficient_privilege using
        message='invitation target denied',detail='SAI_PERMISSION_DENIED';
    end if;

    request_hash:=extensions.digest(convert_to(jsonb_build_object(
      'institution_id',p_institution_id,'unit_id',p_unit_id,'group_id',p_group_id,
      'profile_id',p_profile_id,'target_person_id',p_target_person_id,
      'recipient_email',normalized_email,'channels',normalized_channels,
      'expires_in_hours',p_expires_in_hours
    )::text,'UTF8'),'sha256');
    select * into receipt from app_private.superadmin_internal_invite_receipts
      where request_id=p_request_id for update;
    if receipt.request_id is not null then
      if receipt.internal_identity_id<>ctx.internal_identity_id
        or receipt.command_kind<>'issue' or receipt.request_hash<>request_hash then
        raise exception using errcode='PT409', message='invitation request conflict',detail='SAI_CONCURRENT_CHANGE';
      end if;
      result:=receipt.result_json||jsonb_build_object('replayed',true,'link',null);
    else
      clear_token:=encode(extensions.gen_random_bytes(32),'hex');
      stored_token_hash:=encode(extensions.digest(convert_to(clear_token,'UTF8'),'sha256'),'hex');
      if normalized_email is not null then
        target_hash:=encode(extensions.digest(convert_to(normalized_email,'UTF8'),'sha256'),'hex');
        masked_destination:=left(normalized_email,1)||'***@'||split_part(normalized_email,'@',2);
      end if;
      insert into public.invitations(
        id,scope_kind,institution_id,unit_id,group_id,target_person_id,role_code,
        token_hash,expires_at,status,invitation_state,invited_by,
        invited_by_internal_identity_id,target_contact_hash,masked_destination,
        send_count,profile_id,channels,version,updated_at
      ) values(
        invitation_id,scope_kind,p_institution_id,p_unit_id,p_group_id,
        p_target_person_id,profile_code,stored_token_hash,
        now()+make_interval(hours=>p_expires_in_hours),'active','pending',null,
        ctx.internal_identity_id,target_hash,masked_destination,0,p_profile_id,
        normalized_channels,1,now()
      );
      invite_payload:=app_private.superadmin_invite_payload_v2(invitation_id);
      result:=jsonb_build_object(
        'invite',invite_payload,'replayed',false,
        'link','https://app.coelo.me/convites/'||clear_token
      );
      insert into app_private.superadmin_internal_invite_receipts(
        request_id,internal_identity_id,internal_auth_link_id,
        internal_membership_id,command_kind,invitation_id,request_hash,result_json
      ) values(
        p_request_id,ctx.internal_identity_id,ctx.internal_auth_link_id,
        ctx.internal_membership_id,'issue',invitation_id,request_hash,
        jsonb_build_object('invite',invite_payload,'replayed',false,'link',null)
      );
    end if;
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail like 'SAI_%' then error_detail
        else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation or foreign_key_violation
      then error_code:='SAI_INVALID_ARGUMENT';
    when serialization_failure or sqlstate 'PT409' or unique_violation then
      error_code:='SAI_CONCURRENT_CHANGE';
    when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'platform.invites.manage','invite.issue',error_code,correlation,null);
    return app_private.superadmin_invite_error_envelope_v2(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'platform.invites.manage',ctx.aal,'invite.issue','success',null,
    correlation,p_institution_id,'invitation',
    (result#>>'{invite,id}')::uuid);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$_$;

-- public.superadmin_invite_resend_v2 [INVITE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 1.
create or replace function "public"."superadmin_invite_resend_v2"("p_invite_id" "uuid", "p_request_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
  invitation_record public.invitations%rowtype; request_hash bytea;
  clear_token text; result jsonb; payload jsonb;
  receipt app_private.superadmin_internal_invite_receipts%rowtype;
begin
  begin
    select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.invites.manage');
    if ctx.platform_role_code<>'owner' or ctx.scope_kind<>'platform'
      or ctx.scope_institution_id is not null then
      raise insufficient_privilege using
        message='internal invitation access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    if p_invite_id is null or p_request_id is null or p_expected_version<=0 then
      raise invalid_parameter_value using
        message='invalid invitation resend request',detail='SAI_INVALID_ARGUMENT';
    end if;
    request_hash:=extensions.digest(convert_to(jsonb_build_object(
      'invitation_id',p_invite_id,'expected_version',p_expected_version
    )::text,'UTF8'),'sha256');
    select * into receipt from app_private.superadmin_internal_invite_receipts
      where request_id=p_request_id for update;
    if receipt.request_id is not null then
      if receipt.internal_identity_id<>ctx.internal_identity_id
        or receipt.command_kind<>'resend' or receipt.request_hash<>request_hash then
        raise exception using errcode='PT409', message='invitation request conflict',detail='SAI_CONCURRENT_CHANGE';
      end if;
      result:=receipt.result_json||jsonb_build_object('replayed',true,'link',null);
    else
      select * into invitation_record from public.invitations invitation
        where invitation.id=p_invite_id for update;
      if invitation_record.id is null
        or invitation_record.invited_by_internal_identity_id is null then
        raise insufficient_privilege using
          message='internal invitation access denied',detail='SAI_PERMISSION_DENIED';
      end if;
      if invitation_record.version is distinct from p_expected_version then
        raise exception using errcode='PT409', message='invitation version conflict',detail='SAI_CONCURRENT_CHANGE';
      end if;
      if not(invitation_record.invitation_state='expired'
        or(invitation_record.invitation_state='pending'
          and invitation_record.expires_at<=now())) then
        raise invalid_parameter_value using
          message='invitation cannot be resent',detail='SAI_INVALID_ARGUMENT';
      end if;
      clear_token:=encode(extensions.gen_random_bytes(32),'hex');
      update public.invitations set
        token_hash=encode(extensions.digest(convert_to(clear_token,'UTF8'),'sha256'),'hex'),
        invitation_state='pending',status='active',expires_at=now()+interval '48 hours',
        accepted_at=null,accepted_by=null,revoked_at=null,last_sent_at=now(),
        send_count=send_count+1,version=version+1,updated_at=now()
      where id=p_invite_id returning * into invitation_record;
      payload:=app_private.superadmin_invite_payload_v2(p_invite_id);
      result:=jsonb_build_object('invite',payload,'replayed',false,
        'link','https://app.coelo.me/convites/'||clear_token);
      insert into app_private.superadmin_internal_invite_receipts(
        request_id,internal_identity_id,internal_auth_link_id,
        internal_membership_id,command_kind,invitation_id,request_hash,result_json
      ) values(
        p_request_id,ctx.internal_identity_id,ctx.internal_auth_link_id,
        ctx.internal_membership_id,'resend',p_invite_id,request_hash,
        jsonb_build_object('invite',payload,'replayed',false,'link',null)
      );
    end if;
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail like 'SAI_%' then error_detail
        else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation then error_code:='SAI_INVALID_ARGUMENT';
    when serialization_failure or sqlstate 'PT409' or unique_violation then error_code:='SAI_CONCURRENT_CHANGE';
    when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'platform.invites.manage','invite.resend',error_code,correlation,null);
    return app_private.superadmin_invite_error_envelope_v2(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'platform.invites.manage',ctx.aal,'invite.resend','success',null,
    correlation,(result#>>'{invite,institution_id}')::uuid,'invitation',p_invite_id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

-- public.superadmin_invite_revoke_v2 [INVITE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 1.
create or replace function "public"."superadmin_invite_revoke_v2"("p_invite_id" "uuid", "p_request_id" "uuid", "p_expected_version" bigint, "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
  invitation_record public.invitations%rowtype; request_hash bytea;
  result jsonb; payload jsonb;
  receipt app_private.superadmin_internal_invite_receipts%rowtype;
begin
  begin
    select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.invites.manage');
    if ctx.platform_role_code<>'owner' or ctx.scope_kind<>'platform'
      or ctx.scope_institution_id is not null then
      raise insufficient_privilege using
        message='internal invitation access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    if p_invite_id is null or p_request_id is null or p_expected_version<=0
      or length(btrim(coalesce(p_reason,''))) not between 3 and 240 then
      raise invalid_parameter_value using
        message='invalid invitation revoke request',detail='SAI_INVALID_ARGUMENT';
    end if;
    request_hash:=extensions.digest(convert_to(jsonb_build_object(
      'invitation_id',p_invite_id,'expected_version',p_expected_version,
      'reason',btrim(p_reason)
    )::text,'UTF8'),'sha256');
    select * into receipt from app_private.superadmin_internal_invite_receipts
      where request_id=p_request_id for update;
    if receipt.request_id is not null then
      if receipt.internal_identity_id<>ctx.internal_identity_id
        or receipt.command_kind<>'revoke' or receipt.request_hash<>request_hash then
        raise exception using errcode='PT409', message='invitation request conflict',detail='SAI_CONCURRENT_CHANGE';
      end if;
      result:=receipt.result_json||jsonb_build_object('replayed',true,'link',null);
    else
      select * into invitation_record from public.invitations invitation
        where invitation.id=p_invite_id for update;
      if invitation_record.id is null
        or invitation_record.invited_by_internal_identity_id is null then
        raise insufficient_privilege using
          message='internal invitation access denied',detail='SAI_PERMISSION_DENIED';
      end if;
      if invitation_record.version is distinct from p_expected_version then
        raise exception using errcode='PT409', message='invitation version conflict',detail='SAI_CONCURRENT_CHANGE';
      end if;
      if invitation_record.invitation_state<>'pending'
        or invitation_record.expires_at<=now() then
        raise invalid_parameter_value using
          message='invitation cannot be revoked',detail='SAI_INVALID_ARGUMENT';
      end if;
      update public.invitations set
        invitation_state='revoked',status='inactive',revoked_at=now(),
        version=version+1,updated_at=now()
      where id=p_invite_id returning * into invitation_record;
      payload:=app_private.superadmin_invite_payload_v2(p_invite_id);
      result:=jsonb_build_object('invite',payload,'replayed',false,'link',null);
      insert into app_private.superadmin_internal_invite_receipts(
        request_id,internal_identity_id,internal_auth_link_id,
        internal_membership_id,command_kind,invitation_id,request_hash,result_json
      ) values(
        p_request_id,ctx.internal_identity_id,ctx.internal_auth_link_id,
        ctx.internal_membership_id,'revoke',p_invite_id,request_hash,result
      );
    end if;
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail like 'SAI_%' then error_detail
        else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation then error_code:='SAI_INVALID_ARGUMENT';
    when serialization_failure or sqlstate 'PT409' or unique_violation then error_code:='SAI_CONCURRENT_CHANGE';
    when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'platform.invites.manage','invite.revoke',error_code,correlation,null);
    return app_private.superadmin_invite_error_envelope_v2(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'platform.invites.manage',ctx.aal,'invite.revoke','success',null,
    correlation,(result#>>'{invite,institution_id}')::uuid,'invitation',p_invite_id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

-- public.superadmin_location_copy_v2 [LOCATION]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 1.
create or replace function "public"."superadmin_location_copy_v2"("p_source_location_id" "uuid", "p_scope_kind" "text", "p_institution_id" "uuid", "p_unit_id" "uuid", "p_name" "text", "p_request_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; normalized jsonb; result jsonb;
  receipt app_private.superadmin_location_write_receipts%rowtype;
  source public.activity_locations%rowtype; target public.activity_locations%rowtype;
  requested_hash bytea; created_id uuid; locked_actor_id uuid; initial_session_id uuid;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.copy');
    initial_session_id:=ctx.session_id;
    if current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using message='location isolation unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_request_id is null or p_source_location_id is null then
      raise invalid_parameter_value using message='location request incomplete',detail='SAI_INVALID_ARGUMENT';
    end if;
    requested_hash:=extensions.digest(convert_to(
      p_source_location_id::text||':'||coalesce(p_scope_kind,'')||':'||coalesce(p_institution_id::text,'')
      ||':'||coalesce(p_unit_id::text,'')||':'||coalesce(p_name,''),'UTF8'),'sha256');
    locked_actor_id:=ctx.internal_identity_id;
    perform pg_advisory_xact_lock(hashtextextended(locked_actor_id::text||':'||p_request_id::text,0));
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.copy');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    select r.* into receipt from app_private.superadmin_location_write_receipts r
      where r.actor_internal_identity_id=ctx.internal_identity_id and r.request_id=p_request_id;
    if found then
      if receipt.operation<>'copy' or receipt.request_hash is distinct from requested_hash then
        raise exception using errcode='PT409', message='location request already used',detail='SAI_CONCURRENT_CHANGE';
      end if;
      target:=app_private.superadmin_location_locked_v2(ctx,receipt.location_id);
      created_id:=target.id;
    else
      -- The source is authorized and locked first: a copy of a row the caller may
      -- not reach would read that row through its result.
      source:=app_private.superadmin_location_locked_v2(ctx,p_source_location_id);
      -- The target owner is a separate authorization, not an inference from the source.
      perform app_private.superadmin_location_owner_v2(ctx,p_scope_kind,p_institution_id,p_unit_id);
      -- A copy stays inside its institution. Carrying one tenant's configuration into
      -- another is a product decision, not a convenience of this command.
      if p_institution_id is distinct from source.institution_id then
        raise invalid_parameter_value using message='location copy stays inside its institution',
          detail='SAI_INVALID_ARGUMENT';
      end if;
      if p_scope_kind=source.scope_kind and p_unit_id is not distinct from source.unit_id
        and lower(btrim(coalesce(p_name,'')))=lower(source.name) then
        raise invalid_parameter_value using message='location copy needs a distinct name or owner',
          detail='SAI_INVALID_ARGUMENT';
      end if;
      -- Validation is the create package's normalizer, so a copy can never produce a
      -- row that a create would have refused. An archived source is a usable template;
      -- what it produces is a new active entry, never a second archived one.
      normalized:=app_private.superadmin_location_normalize_v2(jsonb_build_object(
        'scope_kind',p_scope_kind,'institution_id',p_institution_id,'unit_id',p_unit_id,
        'name',p_name,'description',source.description,'kind',source.kind,
        'floor',source.floor,'address',source.address,'visibility',source.visibility));
      if not app_private.superadmin_location_name_available_v2(
          null,normalized->>'scope_kind',(normalized->>'institution_id')::uuid,
          (normalized->>'unit_id')::uuid,normalized->>'name') then
        raise invalid_parameter_value using message='location name already used',detail='SAI_INVALID_ARGUMENT';
      end if;
      insert into public.activity_locations(scope_kind,institution_id,unit_id,name,description,kind,floor,
        address,visibility,created_by_internal_identity_id)
      values(normalized->>'scope_kind',(normalized->>'institution_id')::uuid,
        (normalized->>'unit_id')::uuid,normalized->>'name',normalized->>'description',
        normalized->>'kind',normalized->>'floor',nullif(normalized->'address','null'::jsonb),
        normalized->>'visibility',ctx.internal_identity_id)
      returning id into created_id;
      insert into app_private.superadmin_location_copy_lineage(
        location_id,source_location_id,copied_by_internal_identity_id)
        values(created_id,source.id,ctx.internal_identity_id);
      insert into app_private.superadmin_location_write_receipts(
        actor_internal_identity_id,request_id,operation,request_hash,location_id,resulting_version)
        values(ctx.internal_identity_id,p_request_id,'copy',requested_hash,created_id,1);
      select l.* into target from public.activity_locations l where l.id=created_id for share;
    end if;
    -- The insert and both writes beside it may have waited, so the authorization that
    -- opened the command is re-proved before it is reported as done.
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.copy');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    if ctx.session_id is distinct from initial_session_id or not exists(
      select 1 from auth.sessions session_record where session_record.id=initial_session_id
        and (session_record.not_after is null or session_record.not_after>clock_timestamp())) then
      raise insufficient_privilege using message='location session invalid',detail='SAI_SESSION_INVALID';
    end if;
    result:=app_private.superadmin_location_payload_v2(created_id);
    if result is null then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
  exception when insufficient_privilege then
    get stacked diagnostics error_detail=pg_exception_detail;
    error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
      then error_detail else 'SAI_INTERNAL_ERROR' end;
  when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
  when unique_violation or serialization_failure or sqlstate 'PT409' then error_code:='SAI_CONCURRENT_CHANGE';
  when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'locations.copy','location.copy',error_code,correlation,p_source_location_id);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
    ctx.internal_membership_id,ctx.session_id,'locations.copy',ctx.aal,'location.copy','success',null,
    correlation,target.institution_id,'location',created_id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

-- public.superadmin_location_create_v2 [LOCATION]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 1.
create or replace function "public"."superadmin_location_create_v2"("p_payload" "jsonb", "p_request_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; normalized jsonb; result jsonb;
  receipt app_private.superadmin_location_create_receipts%rowtype;
  target public.activity_locations%rowtype;
  requested_hash bytea; location_id uuid; institution_id uuid; unit_id uuid; locked_actor_id uuid;
  initial_session_id uuid;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.create');
    initial_session_id:=ctx.session_id;
    if current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using message='location isolation unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_request_id is null then
      raise invalid_parameter_value using message='location request id required',detail='SAI_INVALID_ARGUMENT';
    end if;
    normalized:=app_private.superadmin_location_normalize_v2(p_payload);
    institution_id:=(normalized->>'institution_id')::uuid;
    unit_id:=(normalized->>'unit_id')::uuid;
    perform app_private.superadmin_location_owner_v2(ctx,normalized->>'scope_kind',institution_id,unit_id);
    requested_hash:=extensions.digest(convert_to(normalized::text,'UTF8'),'sha256');
    locked_actor_id:=ctx.internal_identity_id;
    perform pg_advisory_xact_lock(hashtextextended(locked_actor_id::text||':'||p_request_id::text,0));
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.create');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,normalized->>'scope_kind',institution_id,unit_id);
    select r.* into receipt from app_private.superadmin_location_create_receipts r
      where r.actor_internal_identity_id=ctx.internal_identity_id and r.request_id=p_request_id;
    if found then
      if receipt.request_hash is distinct from requested_hash then
        raise exception using errcode='PT409', message='location request already used',detail='SAI_CONCURRENT_CHANGE';
      end if;
      location_id:=receipt.location_id;
      select l.* into target from public.activity_locations l where l.id=location_id
        and ctx.platform_role_code='owner'
        and (ctx.scope_kind='platform' or
          (ctx.scope_kind='institution' and ctx.scope_institution_id=l.institution_id)) for share;
      perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
      institution_id:=target.institution_id;
    else
      insert into public.activity_locations(scope_kind,institution_id,unit_id,name,description,kind,floor,address,
        visibility,created_by_internal_identity_id)
      values(normalized->>'scope_kind',institution_id,unit_id,normalized->>'name',normalized->>'description',
        normalized->>'kind',normalized->>'floor',nullif(normalized->'address','null'::jsonb),
        normalized->>'visibility',ctx.internal_identity_id)
      returning id into location_id;
      insert into app_private.superadmin_location_create_receipts(actor_internal_identity_id,request_id,request_hash,location_id)
        values(ctx.internal_identity_id,p_request_id,requested_hash,location_id);
    end if;
    -- Receipt/resource locks and INSERT may also wait after the advisory lock.
    select l.* into target from public.activity_locations l where l.id=location_id for share;
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.create');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    institution_id:=target.institution_id;
    if ctx.session_id is distinct from initial_session_id or not exists(
      select 1 from auth.sessions session_record where session_record.id=initial_session_id
        and (session_record.not_after is null or session_record.not_after>clock_timestamp())) then
      raise insufficient_privilege using message='location session invalid',detail='SAI_SESSION_INVALID';
    end if;
    result:=app_private.superadmin_location_payload_v2(location_id);
    if result is null then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
  exception when insufficient_privilege then
    get stacked diagnostics error_detail=pg_exception_detail;
    error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
      then error_detail else 'SAI_INTERNAL_ERROR' end;
  when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
  when unique_violation or serialization_failure or sqlstate 'PT409' then error_code:='SAI_CONCURRENT_CHANGE';
  when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'locations.create','location.create',error_code,correlation,null);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
    ctx.internal_membership_id,ctx.session_id,'locations.create',ctx.aal,'location.create','success',null,
    correlation,institution_id,'location',location_id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

-- public.superadmin_location_schedule_set_v2 [LOCATION]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 3, handlers: 1.
create or replace function "public"."superadmin_location_schedule_set_v2"("p_location_id" "uuid", "p_windows" "jsonb", "p_expected_version" bigint, "p_request_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; normalized jsonb; result jsonb;
  receipt app_private.superadmin_location_write_receipts%rowtype;
  target public.activity_locations%rowtype;
  requested_hash bytea; locked_actor_id uuid; initial_session_id uuid;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.schedule');
    initial_session_id:=ctx.session_id;
    if current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using message='location isolation unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_request_id is null or p_location_id is null
      or p_expected_version is null or p_expected_version<=0 then
      raise invalid_parameter_value using message='location request incomplete',detail='SAI_INVALID_ARGUMENT';
    end if;
    normalized:=app_private.superadmin_location_schedule_normalize_v2(p_windows);
    requested_hash:=extensions.digest(convert_to(
      p_location_id::text||':'||p_expected_version::text||':'||normalized::text,'UTF8'),'sha256');
    locked_actor_id:=ctx.internal_identity_id;
    perform pg_advisory_xact_lock(hashtextextended(locked_actor_id::text||':'||p_request_id::text,0));
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.schedule');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    select r.* into receipt from app_private.superadmin_location_write_receipts r
      where r.actor_internal_identity_id=ctx.internal_identity_id and r.request_id=p_request_id;
    if found then
      if receipt.operation<>'schedule' or receipt.request_hash is distinct from requested_hash
        or receipt.location_id is distinct from p_location_id then
        raise exception using errcode='PT409', message='location request already used',detail='SAI_CONCURRENT_CHANGE';
      end if;
      target:=app_private.superadmin_location_locked_v2(ctx,receipt.location_id);
    else
      -- The location row is the lock every schedule writer takes, so replacing a week
      -- is serialized per location and the windows cannot interleave.
      target:=app_private.superadmin_location_locked_v2(ctx,p_location_id);
      if target.status='archived' then
        raise invalid_parameter_value using message='archived location publishes no schedule',
          detail='SAI_INVALID_ARGUMENT';
      end if;
      if target.management_version is distinct from p_expected_version then
        raise exception using errcode='PT409', message='location version stale',detail='SAI_CONCURRENT_CHANGE';
      end if;
      delete from public.activity_location_schedules where location_id=target.id;
      insert into public.activity_location_schedules(
        location_id,weekday,starts_minute,ends_minute,created_by_internal_identity_id)
      select target.id,(value->>'weekday')::smallint,(value->>'starts_minute')::smallint,
        (value->>'ends_minute')::smallint,ctx.internal_identity_id
      from jsonb_array_elements(normalized);
      update public.activity_locations set
        management_version=management_version+1,updated_at=now()
      where id=target.id and management_version=p_expected_version
      returning * into target;
      if not found then
        raise exception using errcode='PT409', message='location version stale',detail='SAI_CONCURRENT_CHANGE';
      end if;
      insert into app_private.superadmin_location_write_receipts(
        actor_internal_identity_id,request_id,operation,request_hash,location_id,resulting_version)
        values(ctx.internal_identity_id,p_request_id,'schedule',requested_hash,target.id,
          target.management_version);
    end if;
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.schedule');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    if ctx.session_id is distinct from initial_session_id or not exists(
      select 1 from auth.sessions session_record where session_record.id=initial_session_id
        and (session_record.not_after is null or session_record.not_after>clock_timestamp())) then
      raise insufficient_privilege using message='location session invalid',detail='SAI_SESSION_INVALID';
    end if;
    result:=jsonb_build_object('location_id',target.id,
      'management_version',target.management_version,
      'windows',app_private.superadmin_location_schedule_payload_v2(target.id));
  exception when insufficient_privilege then
    get stacked diagnostics error_detail=pg_exception_detail;
    error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
      then error_detail else 'SAI_INTERNAL_ERROR' end;
  when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
  when unique_violation or serialization_failure or sqlstate 'PT409' then error_code:='SAI_CONCURRENT_CHANGE';
  when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'locations.schedule','location.schedule',error_code,correlation,p_location_id);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
    ctx.internal_membership_id,ctx.session_id,'locations.schedule',ctx.aal,'location.schedule','success',null,
    correlation,target.institution_id,'location',target.id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

-- public.superadmin_location_set_status_v2 [LOCATION]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 3, handlers: 1.
create or replace function "public"."superadmin_location_set_status_v2"("p_location_id" "uuid", "p_status" "text", "p_expected_version" bigint, "p_request_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; result jsonb;
  receipt app_private.superadmin_location_write_receipts%rowtype;
  target public.activity_locations%rowtype;
  requested_hash bytea; institution_id uuid; locked_actor_id uuid; initial_session_id uuid;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.status');
    initial_session_id:=ctx.session_id;
    if current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using message='location isolation unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_request_id is null or p_location_id is null
      or p_expected_version is null or p_expected_version<=0 then
      raise invalid_parameter_value using message='location request incomplete',detail='SAI_INVALID_ARGUMENT';
    end if;
    -- A place is available, temporarily unavailable, or retired. Draft and suspended
    -- belong to records that are negotiated, which a room is not.
    if p_status is null or p_status not in('active','inactive','archived') then
      raise invalid_parameter_value using message='location status unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    requested_hash:=extensions.digest(convert_to(
      p_location_id::text||':'||p_expected_version::text||':'||p_status,'UTF8'),'sha256');
    locked_actor_id:=ctx.internal_identity_id;
    perform pg_advisory_xact_lock(hashtextextended(locked_actor_id::text||':'||p_request_id::text,0));
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.status');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    select r.* into receipt from app_private.superadmin_location_write_receipts r
      where r.actor_internal_identity_id=ctx.internal_identity_id and r.request_id=p_request_id;
    if found then
      if receipt.operation<>'status' or receipt.request_hash is distinct from requested_hash
        or receipt.location_id is distinct from p_location_id then
        raise exception using errcode='PT409', message='location request already used',detail='SAI_CONCURRENT_CHANGE';
      end if;
      target:=app_private.superadmin_location_locked_v2(ctx,receipt.location_id);
    else
      target:=app_private.superadmin_location_locked_v2(ctx,p_location_id);
      if target.management_version is distinct from p_expected_version then
        raise exception using errcode='PT409', message='location version stale',detail='SAI_CONCURRENT_CHANGE';
      end if;
      -- Asking for the status the row already has is a client that lost track of it.
      -- Retries are covered by the receipt above, so this only fires on a real mistake.
      if target.status::text=p_status then
        raise invalid_parameter_value using message='location status unchanged',detail='SAI_INVALID_ARGUMENT';
      end if;
      -- Leaving the archive puts the name back under the partial unique indexes.
      if target.status='archived' and not app_private.superadmin_location_name_available_v2(
          target.id,target.scope_kind,target.institution_id,target.unit_id,target.name) then
        raise invalid_parameter_value using message='location name already used',detail='SAI_INVALID_ARGUMENT';
      end if;
      update public.activity_locations set
        status=p_status::public.record_status,
        management_version=management_version+1,
        updated_at=now()
      where id=target.id and management_version=p_expected_version
      returning * into target;
      if not found then
        raise exception using errcode='PT409', message='location version stale',detail='SAI_CONCURRENT_CHANGE';
      end if;
      insert into app_private.superadmin_location_write_receipts(
        actor_internal_identity_id,request_id,operation,request_hash,location_id,resulting_version)
        values(ctx.internal_identity_id,p_request_id,'status',requested_hash,target.id,target.management_version);
    end if;
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.status');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    institution_id:=target.institution_id;
    if ctx.session_id is distinct from initial_session_id or not exists(
      select 1 from auth.sessions session_record where session_record.id=initial_session_id
        and (session_record.not_after is null or session_record.not_after>clock_timestamp())) then
      raise insufficient_privilege using message='location session invalid',detail='SAI_SESSION_INVALID';
    end if;
    result:=app_private.superadmin_location_payload_v2(target.id);
    if result is null then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
  exception when insufficient_privilege then
    get stacked diagnostics error_detail=pg_exception_detail;
    error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
      then error_detail else 'SAI_INTERNAL_ERROR' end;
  when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
  when unique_violation or serialization_failure or sqlstate 'PT409' then error_code:='SAI_CONCURRENT_CHANGE';
  when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'locations.status','location.status',error_code,correlation,p_location_id);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
    ctx.internal_membership_id,ctx.session_id,'locations.status',ctx.aal,'location.status','success',null,
    correlation,institution_id,'location',target.id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

-- public.superadmin_location_update_v2 [LOCATION]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 3, handlers: 1.
create or replace function "public"."superadmin_location_update_v2"("p_location_id" "uuid", "p_payload" "jsonb", "p_expected_version" bigint, "p_request_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare ctx app_private.superadmin_internal_context; normalized jsonb; result jsonb;
  receipt app_private.superadmin_location_write_receipts%rowtype;
  target public.activity_locations%rowtype;
  requested_hash bytea; institution_id uuid; locked_actor_id uuid; initial_session_id uuid;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.update');
    initial_session_id:=ctx.session_id;
    if current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using message='location isolation unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_request_id is null or p_location_id is null
      or p_expected_version is null or p_expected_version<=0 then
      raise invalid_parameter_value using message='location request incomplete',detail='SAI_INVALID_ARGUMENT';
    end if;
    normalized:=app_private.superadmin_location_normalize_v2(p_payload);
    -- The version and the target belong to the request, so a replay that changed either
    -- is a different request and must not reuse the receipt.
    requested_hash:=extensions.digest(convert_to(
      p_location_id::text||':'||p_expected_version::text||':'||normalized::text,'UTF8'),'sha256');
    locked_actor_id:=ctx.internal_identity_id;
    perform pg_advisory_xact_lock(hashtextextended(locked_actor_id::text||':'||p_request_id::text,0));
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.update');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    select r.* into receipt from app_private.superadmin_location_write_receipts r
      where r.actor_internal_identity_id=ctx.internal_identity_id and r.request_id=p_request_id;
    if found then
      if receipt.operation<>'update' or receipt.request_hash is distinct from requested_hash
        or receipt.location_id is distinct from p_location_id then
        raise exception using errcode='PT409', message='location request already used',detail='SAI_CONCURRENT_CHANGE';
      end if;
      target:=app_private.superadmin_location_locked_v2(ctx,receipt.location_id);
    else
      target:=app_private.superadmin_location_locked_v2(ctx,p_location_id);
      -- The catalog never re-parents a location. Activities resolve it through its owner,
      -- so moving it between institutions or units would silently change their answer.
      if target.scope_kind is distinct from normalized->>'scope_kind'
        or target.institution_id is distinct from (normalized->>'institution_id')::uuid
        or target.unit_id is distinct from (normalized->>'unit_id')::uuid then
        raise invalid_parameter_value using message='location owner is immutable',detail='SAI_INVALID_ARGUMENT';
      end if;
      if target.status='archived' then
        raise invalid_parameter_value using message='archived location is read only',detail='SAI_INVALID_ARGUMENT';
      end if;
      if target.management_version is distinct from p_expected_version then
        raise exception using errcode='PT409', message='location version stale',detail='SAI_CONCURRENT_CHANGE';
      end if;
      if not app_private.superadmin_location_name_available_v2(
          target.id,target.scope_kind,target.institution_id,target.unit_id,normalized->>'name') then
        raise invalid_parameter_value using message='location name already used',detail='SAI_INVALID_ARGUMENT';
      end if;
      update public.activity_locations set
        name=normalized->>'name',
        description=normalized->>'description',
        kind=normalized->>'kind',
        floor=normalized->>'floor',
        address=nullif(normalized->'address','null'::jsonb),
        visibility=normalized->>'visibility',
        management_version=management_version+1,
        updated_at=now()
      where id=target.id and management_version=p_expected_version
      returning * into target;
      if not found then
        raise exception using errcode='PT409', message='location version stale',detail='SAI_CONCURRENT_CHANGE';
      end if;
      insert into app_private.superadmin_location_write_receipts(
        actor_internal_identity_id,request_id,operation,request_hash,location_id,resulting_version)
        values(ctx.internal_identity_id,p_request_id,'update',requested_hash,target.id,target.management_version);
    end if;
    -- The row lock, the receipt insert and the update may all have waited, so the
    -- authorization that opened the command is re-proved before it is reported as done.
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.update');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    institution_id:=target.institution_id;
    if ctx.session_id is distinct from initial_session_id or not exists(
      select 1 from auth.sessions session_record where session_record.id=initial_session_id
        and (session_record.not_after is null or session_record.not_after>clock_timestamp())) then
      raise insufficient_privilege using message='location session invalid',detail='SAI_SESSION_INVALID';
    end if;
    result:=app_private.superadmin_location_payload_v2(target.id);
    if result is null then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
  exception when insufficient_privilege then
    get stacked diagnostics error_detail=pg_exception_detail;
    error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
      then error_detail else 'SAI_INTERNAL_ERROR' end;
  when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
  when unique_violation or serialization_failure or sqlstate 'PT409' then error_code:='SAI_CONCURRENT_CHANGE';
  when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'locations.update','location.update',error_code,correlation,p_location_id);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
    ctx.internal_membership_id,ctx.session_id,'locations.update',ctx.aal,'location.update','success',null,
    correlation,institution_id,'location',target.id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

-- public.superadmin_notice_change_status_v2 [NOTICE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_notice_change_status_v2"("p_request_id" "uuid", "p_notice_id" "uuid", "p_expected_version" bigint, "p_status" "text", "p_reason" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare context_record app_private.superadmin_internal_context;
  notice_record public.platform_notices%rowtype; cached_record record;
  correlation_id uuid := gen_random_uuid(); error_code text;
  request_hash bytea; result_json jsonb; target_status public.notice_status;
begin
  begin
    context_record := app_private.superadmin_notice_context('notices.publish');
    if p_request_id is null or p_notice_id is null or p_expected_version is null then
      raise invalid_parameter_value using message = 'status command incomplete', detail = 'NOTICE_INVALID_INPUT';
    end if;
    if p_status not in ('paused', 'scheduled', 'inactive')
      or (p_status = 'inactive' and char_length(btrim(coalesce(p_reason, ''))) not between 3 and 500) then
      raise invalid_parameter_value using message = 'invalid status command', detail = 'NOTICE_INVALID_INPUT';
    end if;
    request_hash := extensions.digest(p_notice_id::text || '|' || coalesce(p_expected_version::text, '') ||
      '|' || p_status || '|' || coalesce(btrim(p_reason), ''), 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(
      context_record.internal_identity_id::text || p_request_id::text || 'notice.status', 0));
    select * into cached_record from app_private.superadmin_notice_command_receipts
      where internal_identity_id = context_record.internal_identity_id
        and request_id = p_request_id and action_code = 'status';
    if cached_record.request_id is not null then
      if cached_record.request_hash <> request_hash then
        raise unique_violation using message = 'idempotency conflict', detail = 'NOTICE_CONFLICT';
      end if;
      return cached_record.result_json;
    end if;
    select * into notice_record from public.platform_notices where id = p_notice_id for update;
    if notice_record.id is null then
      raise no_data_found using message = 'notice unavailable', detail = 'NOTICE_NOT_FOUND';
    end if;
    if notice_record.management_version <> p_expected_version then
      raise exception using errcode='PT409', message = 'version conflict', detail = 'NOTICE_CONFLICT';
    end if;
    if notice_record.status::text in ('expired', 'inactive') then
      raise object_not_in_prerequisite_state using message = 'terminal notice state', detail = 'NOTICE_TERMINAL';
    end if;
    if (p_status = 'paused' and notice_record.status::text <> 'active')
      or (p_status = 'scheduled' and notice_record.status::text <> 'paused') then
      raise object_not_in_prerequisite_state using message = 'invalid notice transition', detail = 'NOTICE_INVALID_TRANSITION';
    end if;
    target_status := case
      when p_status = 'scheduled' and notice_record.starts_at <= clock_timestamp()
        then 'active'::public.notice_status
      else p_status::public.notice_status end;
    update public.platform_notices set status = target_status,
      published_at = case when target_status::text = 'active'
        then coalesce(published_at, clock_timestamp()) else published_at end,
      silencing_policy = case when p_status = 'inactive'
        then silencing_policy || jsonb_build_object('inactive_reason', left(btrim(p_reason), 500))
        else silencing_policy end,
      management_version = management_version + 1,
      updated_by_internal_identity_id = context_record.internal_identity_id,
      updated_at = clock_timestamp()
    where id = p_notice_id returning * into notice_record;
    if p_status = 'scheduled' then
      insert into app_private.notice_publication_jobs(
        notice_id, notice_version, audience_snapshot, available_at
      ) values (notice_record.id, notice_record.management_version, notice_record.audience_json,
        greatest(coalesce(notice_record.starts_at, now()), now()))
      on conflict do nothing;
    end if;
    result_json := jsonb_build_object('ok', true,
      'data', app_private.superadmin_notice_json(notice_record), 'error', null);
    insert into app_private.superadmin_notice_command_receipts(
      internal_identity_id, request_id, action_code, request_hash, result_json
    ) values (context_record.internal_identity_id, p_request_id, 'status', request_hash, result_json);
    perform app_private.superadmin_notice_append_audit(context_record,
      'notice.status.' || p_status, notice_record.id, 'success',
      case when p_status = 'inactive' then 'NOTICE_INACTIVE_REASON_RECORDED' else null end,
      correlation_id);
    return result_json;
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_notice_denied(
      'notices.publish', 'notice.status.' || coalesce(p_status, 'invalid'),
      error_code, correlation_id);
  end;
end
$$;

-- public.superadmin_notice_publish_v2 [NOTICE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_notice_publish_v2"("p_request_id" "uuid", "p_notice_id" "uuid", "p_expected_version" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare context_record app_private.superadmin_internal_context;
  notice_record public.platform_notices%rowtype; cached_record record;
  correlation_id uuid := gen_random_uuid(); error_code text;
  request_hash bytea; result_json jsonb; next_status public.notice_status;
begin
  begin
    context_record := app_private.superadmin_notice_context('notices.publish');
    if p_request_id is null or p_notice_id is null or p_expected_version is null then
      raise invalid_parameter_value using message = 'publish command incomplete', detail = 'NOTICE_INVALID_INPUT';
    end if;
    request_hash := extensions.digest(p_notice_id::text || '|' || coalesce(p_expected_version::text, ''), 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(
      context_record.internal_identity_id::text || p_request_id::text || 'notice.publish', 0));
    select * into cached_record from app_private.superadmin_notice_command_receipts
      where internal_identity_id = context_record.internal_identity_id
        and request_id = p_request_id and action_code = 'publish';
    if cached_record.request_id is not null then
      if cached_record.request_hash <> request_hash then
        raise unique_violation using message = 'idempotency conflict', detail = 'NOTICE_CONFLICT';
      end if;
      return cached_record.result_json;
    end if;
    select * into notice_record from public.platform_notices where id = p_notice_id for update;
    if notice_record.id is null then
      raise no_data_found using message = 'notice unavailable', detail = 'NOTICE_NOT_FOUND';
    end if;
    if notice_record.management_version <> p_expected_version then
      raise exception using errcode='PT409', message = 'version conflict', detail = 'NOTICE_CONFLICT';
    end if;
    if notice_record.status::text <> 'draft' then
      raise object_not_in_prerequisite_state using message = 'notice cannot be published',
        detail = case when notice_record.status::text in ('expired', 'inactive')
          then 'NOTICE_TERMINAL' else 'NOTICE_INVALID_TRANSITION' end;
    end if;
    if notice_record.content_format <> 'text_background' then
      raise invalid_parameter_value using message = 'notice media blocked', detail = 'NOTICE_MEDIA_BLOCKED';
    end if;
    if notice_record.ends_at is not null and notice_record.ends_at <= clock_timestamp() then
      raise invalid_parameter_value using message = 'notice already ended', detail = 'NOTICE_INVALID_INPUT';
    end if;
    next_status := case when notice_record.starts_at > clock_timestamp()
      then 'scheduled'::public.notice_status else 'active'::public.notice_status end;
    update public.platform_notices set status = next_status,
      published_at = case when next_status::text = 'active' then clock_timestamp() else null end,
      published_by_internal_identity_id = context_record.internal_identity_id,
      updated_by_internal_identity_id = context_record.internal_identity_id,
      management_version = management_version + 1, updated_at = clock_timestamp()
    where id = p_notice_id returning * into notice_record;
    insert into app_private.notice_publication_jobs(
      notice_id, notice_version, audience_snapshot, available_at
    ) values (notice_record.id, notice_record.management_version, notice_record.audience_json,
      greatest(coalesce(notice_record.starts_at, now()), now()))
    on conflict do nothing;
    result_json := jsonb_build_object('ok', true,
      'data', app_private.superadmin_notice_json(notice_record), 'error', null);
    insert into app_private.superadmin_notice_command_receipts(
      internal_identity_id, request_id, action_code, request_hash, result_json
    ) values (context_record.internal_identity_id, p_request_id, 'publish', request_hash, result_json);
    perform app_private.superadmin_notice_append_audit(context_record, 'notice.publish',
      notice_record.id, 'success', null, correlation_id);
    return result_json;
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_notice_denied(
      'notices.publish', 'notice.publish', error_code, correlation_id);
  end;
end
$$;

-- public.superadmin_notice_save_draft_v2 [NOTICE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 2, handlers: 0.
create or replace function "public"."superadmin_notice_save_draft_v2"("p_request_id" "uuid", "p_notice_id" "uuid", "p_expected_version" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare context_record app_private.superadmin_internal_context;
  notice_record public.platform_notices%rowtype; cached_record record;
  correlation_id uuid := gen_random_uuid(); error_code text;
  request_hash bytea; result_json jsonb; canonical_type text;
begin
  begin
    context_record := app_private.superadmin_notice_context('notices.manage');
    if p_request_id is null then
      raise invalid_parameter_value using message = 'request id required', detail = 'NOTICE_INVALID_INPUT';
    end if;
    request_hash := extensions.digest(coalesce(p_notice_id::text, '') || '|' ||
      coalesce(p_expected_version::text, '') || '|' || p_payload::text, 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(
      context_record.internal_identity_id::text || p_request_id::text || 'notice.save', 0));
    select * into cached_record from app_private.superadmin_notice_command_receipts
      where internal_identity_id = context_record.internal_identity_id
        and request_id = p_request_id and action_code = 'save';
    if cached_record.request_id is not null then
      if cached_record.request_hash <> request_hash then
        raise unique_violation using message = 'idempotency conflict', detail = 'NOTICE_CONFLICT';
      end if;
      return cached_record.result_json;
    end if;
    perform app_private.superadmin_notice_validate_payload(p_payload);
    canonical_type := case p_payload ->> 'type'
      when 'notice' then 'popup' when 'critical_notice' then 'popup'
      else p_payload ->> 'type' end;
    if p_notice_id is null then
      if p_expected_version is not null then
        raise exception using errcode='PT409', message = 'version conflict', detail = 'NOTICE_CONFLICT';
      end if;
      insert into public.platform_notices(
        notice_type, status, title, body_text, cta_label, starts_at, ends_at,
        priority_code, audience_json, audience_label, behavior, target_device,
        content_format, background_color, text_color, button_color, popup_size,
        has_outer_inset, recurrence, recurrence_config, image_orientation,
        management_version, created_by_internal_identity_id,
        updated_by_internal_identity_id, created_at, updated_at, silencing_policy
      ) values (
        canonical_type::public.notice_type, 'draft', btrim(p_payload ->> 'title'),
        btrim(p_payload ->> 'body'), nullif(btrim(p_payload ->> 'button_label'), ''),
        (p_payload ->> 'starts_at')::timestamptz,
        nullif(p_payload ->> 'ends_at', '')::timestamptz,
        p_payload ->> 'priority', p_payload -> 'audience',
        btrim(p_payload ->> 'audience_label'), p_payload ->> 'behavior',
        p_payload ->> 'target_device', 'text_background',
        p_payload ->> 'background_color', p_payload ->> 'text_color',
        p_payload ->> 'button_color', p_payload ->> 'popup_size',
        coalesce((p_payload ->> 'has_outer_inset')::boolean, true),
        p_payload ->> 'recurrence', jsonb_strip_nulls(jsonb_build_object(
          'interval_days', p_payload -> 'interval_days',
          'weekly_days', coalesce(p_payload -> 'weekly_days', '[]'::jsonb),
          'day_of_month', p_payload -> 'day_of_month',
          'until', p_payload ->> 'recurrence_until')),
        coalesce(p_payload ->> 'image_orientation', 'vertical'), 1,
        context_record.internal_identity_id, context_record.internal_identity_id,
        clock_timestamp(), clock_timestamp(),
        jsonb_build_object('link_label', nullif(btrim(p_payload ->> 'link_label'), '')))
      returning * into notice_record;
    else
      select * into notice_record from public.platform_notices where id = p_notice_id for update;
      if notice_record.id is null then
        raise no_data_found using message = 'notice unavailable', detail = 'NOTICE_NOT_FOUND';
      end if;
      if p_expected_version is null or notice_record.management_version <> p_expected_version then
        raise exception using errcode='PT409', message = 'version conflict', detail = 'NOTICE_CONFLICT';
      end if;
      if notice_record.status::text not in ('draft', 'scheduled', 'paused') then
        raise object_not_in_prerequisite_state using message = 'notice cannot be edited',
          detail = case when notice_record.status::text in ('expired', 'inactive')
            then 'NOTICE_TERMINAL' else 'NOTICE_INVALID_TRANSITION' end;
      end if;
      update public.platform_notices set
        notice_type = canonical_type::public.notice_type,
        title = btrim(p_payload ->> 'title'), body_text = btrim(p_payload ->> 'body'),
        cta_label = nullif(btrim(p_payload ->> 'button_label'), ''),
        starts_at = (p_payload ->> 'starts_at')::timestamptz,
        ends_at = nullif(p_payload ->> 'ends_at', '')::timestamptz,
        priority_code = p_payload ->> 'priority', audience_json = p_payload -> 'audience',
        audience_label = btrim(p_payload ->> 'audience_label'),
        behavior = p_payload ->> 'behavior', target_device = p_payload ->> 'target_device',
        content_format = 'text_background', background_color = p_payload ->> 'background_color',
        text_color = p_payload ->> 'text_color', button_color = p_payload ->> 'button_color',
        popup_size = p_payload ->> 'popup_size',
        has_outer_inset = coalesce((p_payload ->> 'has_outer_inset')::boolean, true),
        recurrence = p_payload ->> 'recurrence',
        recurrence_config = jsonb_strip_nulls(jsonb_build_object(
          'interval_days', p_payload -> 'interval_days',
          'weekly_days', coalesce(p_payload -> 'weekly_days', '[]'::jsonb),
          'day_of_month', p_payload -> 'day_of_month',
          'until', p_payload ->> 'recurrence_until')),
        image_orientation = coalesce(p_payload ->> 'image_orientation', 'vertical'),
        silencing_policy = jsonb_build_object('link_label', nullif(btrim(p_payload ->> 'link_label'), '')),
        management_version = management_version + 1,
        updated_by_internal_identity_id = context_record.internal_identity_id,
        updated_at = clock_timestamp()
      where id = p_notice_id returning * into notice_record;
    end if;
    result_json := jsonb_build_object('ok', true,
      'data', app_private.superadmin_notice_json(notice_record), 'error', null);
    insert into app_private.superadmin_notice_command_receipts(
      internal_identity_id, request_id, action_code, request_hash, result_json
    ) values (context_record.internal_identity_id, p_request_id, 'save', request_hash, result_json);
    perform app_private.superadmin_notice_append_audit(context_record, 'notice.save',
      notice_record.id, 'success', null, correlation_id);
    return result_json;
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_notice_denied(
      'notices.manage', 'notice.save', error_code, correlation_id);
  end;
end
$$;

-- public.superadmin_plan_save [PLAN]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_plan_save"("p_request_id" "uuid", "p_plan_id" "uuid", "p_expected_revision" bigint, "p_payload" "jsonb", "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare
  v_actor uuid; v_plan public.plans%rowtype; v_existing public.plans%rowtype; v_key text; v_value jsonb; v_action text;
  v_status text := coalesce(p_payload->>'status','active');
begin
  v_actor:=app_private.assert_plan_permission('plan.change',true);
  if p_request_id is null then raise exception using errcode='22023',message='request_id_required'; end if;
  if coalesce(char_length(trim(p_reason)),0) not between 1 and 1000 then raise exception using errcode='22023',message='reason_required'; end if;
  if coalesce(char_length(trim(p_payload->>'name')),0) not between 1 and 160 or coalesce(char_length(trim(p_payload->>'description')),0) not between 1 and 2000 then
    raise exception using errcode='22023',message='invalid_plan_identity';
  end if;
  if v_status not in ('active','archived') then raise exception using errcode='22023',message='invalid_status'; end if;
  select p.* into v_existing from public.plans p join public.plan_change_receipts r on r.plan_id=p.id where r.request_id=p_request_id;
  if found then return public.superadmin_plan_get(v_existing.id); end if;
  if p_plan_id is null then
    if coalesce(p_payload->>'code','') !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then raise exception using errcode='22023',message='invalid_plan_code'; end if;
    insert into public.plans(code,name,description,status,billing_mode,revision,created_by_person_id,updated_by_person_id)
    values(p_payload->>'code',trim(p_payload->>'name'),trim(p_payload->>'description'),v_status::public.record_status,'manual',1,v_actor,v_actor)
    returning * into v_plan;
    v_action:='create';
  else
    select * into v_existing from public.plans where id=p_plan_id for update;
    if not found then raise exception using errcode='P0002',message='plan_not_found'; end if;
    if p_expected_revision is null or p_expected_revision<>v_existing.revision then raise exception using errcode='PT409', message='plan_revision_conflict', detail='PLAN_STALE_VERSION'; end if;
    if p_payload?'code' and p_payload->>'code'<>v_existing.code then raise exception using errcode='22023',message='plan_code_immutable'; end if;
    update public.plans set name=trim(p_payload->>'name'),description=trim(p_payload->>'description'),
      status=v_status::public.record_status,revision=revision+1,updated_at=now(),updated_by_person_id=v_actor
    where id=p_plan_id returning * into v_plan;
    v_action:=case when v_existing.status='active' and v_plan.status='archived' then 'archive'
      when v_existing.status='archived' and v_plan.status='active' then 'restore' else 'update' end;
  end if;
  delete from public.plan_entitlements where plan_id=v_plan.id;
  for v_key,v_value in select key,value from jsonb_each(coalesce(p_payload->'entitlements','{}'::jsonb)) loop
    if v_key not in ('feature.communication','feature.agenda','feature.invitations','feature.chat','feature.notices','feature.routine','feature.happens','feature.now','feature.moments','limit.units','limit.memberships','limit.storage_gb','limit.media_gb') then
      raise exception using errcode='22023',message='invalid_entitlement';
    end if;
    if v_key like 'feature.%' and jsonb_typeof(v_value->'enabled')<>'boolean' then raise exception using errcode='22023',message='invalid_feature_value'; end if;
    if v_key like 'limit.%' and (jsonb_typeof(v_value->'value')<>'number' or (v_value->>'value')::numeric<0 or (v_value->>'value')::numeric>100000000) then
      raise exception using errcode='22023',message='invalid_limit_value';
    end if;
    insert into public.plan_entitlements(plan_id,entitlement_key,value_kind,value_json,status)
    values(v_plan.id,v_key,case when v_key like 'feature.%' then 'boolean' else 'integer' end,v_value,'active');
  end loop;
  insert into public.plan_change_receipts(request_id,plan_id,actor_person_id,action,previous_revision,next_revision,reason)
  values(p_request_id,v_plan.id,v_actor,v_action,v_existing.revision,v_plan.revision,trim(p_reason));
  return public.superadmin_plan_get(v_plan.id);
exception when unique_violation then raise exception using errcode='23505',message='plan_code_or_request_conflict';
end; $_$;

-- public.superadmin_structure_handle_set_v1 [STRUCTURE]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 1.
create or replace function "public"."superadmin_structure_handle_set_v1"("p_request_id" "uuid", "p_kind" "text", "p_entity_id" "uuid", "p_expected_version" bigint, "p_handle" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare
  context_record app_private.superadmin_internal_context;
  correlation_id uuid := gen_random_uuid();
  normalized text;
  permission_code text;
  institution_of_entity uuid;
  current_version bigint;
  last_changed timestamptz;
  next_allowed timestamptz;
  result_version bigint;
  prior app_private.superadmin_structure_handle_receipts%rowtype;
  old_handle text;
  error_code text;
  error_detail text;
  cooldown constant interval := interval '30 days';
begin
  begin
    permission_code := case p_kind
      when 'unit' then 'units.update'
      when 'group' then 'groups.manage'
      when 'activity' then 'activities.manage'
      else null end;
    if permission_code is null then
      raise invalid_parameter_value using message = 'unknown handle kind', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    select * into strict context_record
    from app_private.require_superadmin_internal_context(permission_code);
    if context_record.platform_role_code not in ('owner', 'operations') then
      raise insufficient_privilege using message = 'structure handle denied', detail = 'SAI_PERMISSION_DENIED';
    end if;
    if p_request_id is null or p_entity_id is null or p_expected_version is null or p_expected_version <= 0 then
      raise invalid_parameter_value using message = 'invalid handle request', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    normalized := app_private.structure_handle_normalize(p_handle);
    if (p_kind = 'activity' and normalized !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
      or (p_kind <> 'activity' and normalized !~ '^[a-z0-9][a-z0-9._]{1,48}[a-z0-9]$') then
      raise invalid_parameter_value using message = 'invalid handle', detail = 'SAI_INVALID_ARGUMENT';
    end if;

    -- replay idempotente
    select * into prior from app_private.superadmin_structure_handle_receipts r where r.request_id = p_request_id;
    if prior.request_id is not null then
      if prior.actor_internal_identity_id <> context_record.internal_identity_id
        or prior.kind <> p_kind or prior.entity_id <> p_entity_id
        or prior.expected_version <> p_expected_version or prior.new_handle <> normalized then
        raise invalid_parameter_value using message = 'request replay mismatch', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      return pg_catalog.jsonb_build_object('ok', true, 'data', pg_catalog.jsonb_build_object(
        'kind', p_kind, 'entity_id', p_entity_id, 'handle', normalized,
        'management_version', prior.result_version, 'replayed', true, 'correlation_id', correlation_id),
        'error', null);
    end if;

    if p_kind = 'unit' then
      select u.institution_id, u.management_version, u.handle_last_changed_at, u.handle
        into institution_of_entity, current_version, last_changed, old_handle
      from public.units u where u.id = p_entity_id for update;
    elsif p_kind = 'group' then
      select g.institution_id, g.management_version, g.handle_last_changed_at, g.handle
        into institution_of_entity, current_version, last_changed, old_handle
      from public.groups g where g.id = p_entity_id for update;
    else
      select a.institution_id, a.management_version, a.handle_last_changed_at, a.handle_stem
        into institution_of_entity, current_version, last_changed, old_handle
      from public.activity_definitions a where a.id = p_entity_id for update;
    end if;
    if institution_of_entity is null
      or (context_record.scope_kind = 'institution'
        and context_record.scope_institution_id is distinct from institution_of_entity) then
      -- outro tenant e id inexistente sao indistinguiveis
      raise no_data_found using message = 'entity not found', detail = 'SAI_NOT_FOUND';
    end if;
    if current_version <> p_expected_version then
      raise exception using errcode='PT409', message = 'stale version', detail = 'SAI_CONCURRENT_CHANGE';
    end if;
    if last_changed is not null and last_changed + cooldown > pg_catalog.now() then
      next_allowed := last_changed + cooldown;
      raise check_violation using message = 'handle cooldown', detail = 'SAI_HANDLE_COOLDOWN';
    end if;
    if old_handle = normalized then
      raise invalid_parameter_value using message = 'handle unchanged', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    if p_kind <> 'activity' and app_private.structure_handle_in_use(normalized, p_kind, p_entity_id) then
      raise unique_violation using message = 'handle taken', detail = 'SAI_HANDLE_TAKEN';
    end if;

    if p_kind = 'unit' then
      update public.units set handle = normalized, handle_last_changed_at = pg_catalog.now(),
        management_version = management_version + 1, updated_at = pg_catalog.now()
      where id = p_entity_id returning management_version into result_version;
    elsif p_kind = 'group' then
      update public.groups set handle = normalized, handle_last_changed_at = pg_catalog.now(),
        management_version = management_version + 1, updated_at = pg_catalog.now()
      where id = p_entity_id returning management_version into result_version;
    else
      -- o gatilho set_activity_canonical_handle recompoe stem.unidade.instituicao
      update public.activity_definitions set handle_stem = normalized, handle_last_changed_at = pg_catalog.now(),
        management_version = management_version + 1, updated_at = pg_catalog.now()
      where id = p_entity_id returning management_version into result_version;
    end if;

    insert into app_private.superadmin_structure_handle_receipts
      (request_id, actor_internal_identity_id, kind, entity_id, expected_version, new_handle, result_version)
    values (p_request_id, context_record.internal_identity_id, p_kind, p_entity_id, p_expected_version, normalized, result_version);

    perform app_private.audit_append_superadmin_internal(
      context_record.internal_identity_id,
      context_record.internal_auth_link_id,
      context_record.internal_membership_id,
      context_record.session_id,
      permission_code,
      context_record.aal,
      p_kind || '.handle.change',
      'success',
      null,
      correlation_id,
      institution_of_entity,
      p_kind,
      p_entity_id
    );

    return pg_catalog.jsonb_build_object('ok', true, 'data', pg_catalog.jsonb_build_object(
      'kind', p_kind, 'entity_id', p_entity_id, 'handle', normalized,
      'management_version', result_version, 'replayed', false, 'correlation_id', correlation_id),
      'error', null);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail in (
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED'
      ) then error_detail else 'SAI_INTERNAL_ERROR' end;
    when no_data_found then
      error_code := 'SAI_NOT_FOUND';
    when serialization_failure or sqlstate 'PT409' then
      error_code := 'SAI_CONCURRENT_CHANGE';
    when check_violation then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail = 'SAI_HANDLE_COOLDOWN' then 'SAI_HANDLE_COOLDOWN' else 'SAI_INVALID_ARGUMENT' end;
    when unique_violation then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail = 'SAI_HANDLE_TAKEN' then 'SAI_HANDLE_TAKEN' else 'SAI_INVALID_ARGUMENT' end;
    when invalid_parameter_value or foreign_key_violation or invalid_text_representation then
      error_code := 'SAI_INVALID_ARGUMENT';
    when others then
      error_code := 'SAI_INTERNAL_ERROR';
  end;

  perform app_private.audit_superadmin_internal_denial_if_identified(
    coalesce(permission_code, 'structure.handle'), coalesce(p_kind, 'structure') || '.handle.change',
    error_code, correlation_id, institution_of_entity);
  if error_code = 'SAI_HANDLE_COOLDOWN' then
    return pg_catalog.jsonb_build_object('ok', false, 'data', null, 'error', pg_catalog.jsonb_build_object(
      'code', 'SAI_HANDLE_COOLDOWN',
      'message', 'O @ so pode ser alterado uma vez a cada 30 dias.',
      'http_status', 409,
      'correlation_id', correlation_id,
      'next_allowed_at', next_allowed));
  end if;
  if error_code in ('SAI_HANDLE_TAKEN', 'SAI_NOT_FOUND') then
    return pg_catalog.jsonb_build_object('ok', false, 'data', null, 'error', pg_catalog.jsonb_build_object(
      'code', error_code,
      'message', case error_code when 'SAI_HANDLE_TAKEN' then 'Este @ ja esta em uso.' else 'Registro nao encontrado.' end,
      'http_status', case error_code when 'SAI_HANDLE_TAKEN' then 409 else 404 end,
      'correlation_id', correlation_id));
  end if;
  return app_private.superadmin_internal_error_envelope(error_code, correlation_id);
end
$_$;

-- public.superadmin_support_reply [SUPPORT]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_support_reply"("p_request_id" "uuid", "p_session_id" "uuid", "p_message" "text", "p_expected_revision" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor_id uuid; current_revision bigint; result jsonb;
begin
  actor_id := app_private.assert_support_permission();
  if p_request_id is null or char_length(trim(coalesce(p_message,''))) not between 1 and 10000 then
    raise exception using errcode = '22023', message = 'invalid_support_message';
  end if;
  if exists(select 1 from public.support_command_receipts where request_id = p_request_id) then
    select response_json into result from public.support_command_receipts where request_id = p_request_id;
    return result;
  end if;
  select revision into current_revision from public.support_sessions where id = p_session_id for update;
  if current_revision is null then raise exception using errcode = 'P0002', message = 'support_session_not_found'; end if;
  if p_expected_revision is null or p_expected_revision <> current_revision then
    raise exception using errcode='PT409', message = 'support_revision_conflict', detail='SUPPORT_STALE_VERSION';
  end if;
  insert into public.support_messages(support_session_id, author_person_id, author_membership_id, message_text)
    values (p_session_id, actor_id, actor_id, trim(p_message));
  update public.support_sessions set revision = revision + 1, updated_at = now() where id = p_session_id;
  insert into audit.support_session_actions(support_session_id, action_code, object_type, object_id, metadata_json)
    values (p_session_id, 'support.reply', 'support_session', p_session_id, jsonb_build_object('actor_person_id', actor_id));
  result := public.superadmin_support_get(p_session_id);
  insert into public.support_command_receipts(request_id, support_session_id, actor_person_id, action_code, response_json)
    values (p_request_id, p_session_id, actor_id, 'reply', result);
  return result;
end;
$$;

-- public.superadmin_support_set_assignee [SUPPORT]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_support_set_assignee"("p_request_id" "uuid", "p_session_id" "uuid", "p_expected_revision" bigint, "p_assignee_membership_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor_id uuid; current_revision bigint; previous_assignee uuid; result jsonb;
begin
  actor_id := app_private.assert_support_permission();
  if p_request_id is null or p_session_id is null then
    raise exception using errcode = '22023', message = 'invalid_support_request';
  end if;
  if exists(select 1 from public.support_command_receipts where request_id = p_request_id) then
    select response_json into result from public.support_command_receipts where request_id = p_request_id;
    return result;
  end if;
  if p_assignee_membership_id is not null and not exists (
    select 1 from public.platform_memberships m
    where m.id = p_assignee_membership_id and m.status = 'active' and m.revoked_at is null
      and m.scope_kind = 'platform' and m.scope_institution_id is null
  ) then
    raise exception using errcode = '22023', message = 'assignee_invalid';
  end if;
  select revision, assigned_to_membership_id into current_revision, previous_assignee
    from public.support_sessions where id = p_session_id for update;
  if current_revision is null then raise exception using errcode = 'P0002', message = 'support_session_not_found'; end if;
  if p_expected_revision is null or p_expected_revision <> current_revision then
    raise exception using errcode='PT409', message = 'support_revision_conflict', detail='SUPPORT_STALE_VERSION';
  end if;
  update public.support_sessions set assigned_to_membership_id = p_assignee_membership_id,
    revision = revision + 1, updated_at = now() where id = p_session_id;
  insert into audit.support_session_actions(support_session_id, action_code, object_type, object_id, metadata_json)
    values (p_session_id, 'support.assign', 'support_session', p_session_id,
      jsonb_build_object('actor_person_id', actor_id,
        'assignee_membership_id', p_assignee_membership_id,
        'previous_assignee_membership_id', previous_assignee));
  result := public.superadmin_support_get(p_session_id);
  insert into public.support_command_receipts(request_id, support_session_id, actor_person_id, action_code, response_json)
    values (p_request_id, p_session_id, actor_id, 'assign', result);
  return result;
end;
$$;

-- public.superadmin_support_set_status [SUPPORT]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."superadmin_support_set_status"("p_request_id" "uuid", "p_session_id" "uuid", "p_status" "text", "p_expected_revision" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare actor_id uuid; result jsonb;
begin
  actor_id := app_private.assert_support_permission();
  if p_status not in ('new','in_progress','waiting_requester','completed') then
    raise exception using errcode = '22023', message = 'invalid_support_status';
  end if;
  if exists(select 1 from public.support_command_receipts where request_id = p_request_id) then
    select response_json into result from public.support_command_receipts where request_id = p_request_id; return result;
  end if;
  update public.support_sessions set ticket_status = p_status, revision = revision + 1,
    updated_at = now(), status = case p_status
      when 'completed' then 'resolved'::public.support_session_status
      when 'new' then 'open'::public.support_session_status
      else 'pending'::public.support_session_status end
    where id = p_session_id and revision = p_expected_revision;
  if not found then raise exception using errcode='PT409', message = 'support_revision_conflict', detail='SUPPORT_STALE_VERSION'; end if;
  insert into audit.support_session_actions(support_session_id, action_code, object_type, object_id, metadata_json)
    values (p_session_id, 'support.status', 'support_session', p_session_id, jsonb_build_object('actor_person_id', actor_id, 'status', p_status));
  result := public.superadmin_support_get(p_session_id);
  insert into public.support_command_receipts(request_id, support_session_id, actor_person_id, action_code, response_json)
    values (p_request_id, p_session_id, actor_id, 'status', result);
  return result;
end;
$$;

-- public.withdraw_happens_post [HAPPENS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."withdraw_happens_post"("p_request_id" "uuid", "p_post_id" "uuid", "p_expected_version" bigint, "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  target public.posts%rowtype;
  actor record;
  normalized_reason text;
begin
  select * into target from public.posts where id=p_post_id for update;
  -- A negacao e unificada DE PROPOSITO. Quem nao pode retirar recebe a mesma
  -- classe de erro e a mesma mensagem para "nao existe" e para "existe e nao e
  -- seu". Distinguir os dois entregaria informacao antes da autorizacao e daria
  -- ao ator autenticado um oraculo de existencia, inclusive atravessando tenant.
  -- E o mesmo que withdraw_moment e circulars_production fazem. Nao "restaurar"
  -- a granularidade achando que se perdeu qualidade de erro.
  if not found then
    raise insufficient_privilege using message='happens_permission_denied';
  end if;

  select * into actor from app_private.happens_actor(
    target.institution_id,'happens.posts.remove',target.unit_id,target.group_id);

  if target.author_person_id<>actor.person_id then
    raise insufficient_privilege using message='happens_permission_denied';
  end if;

  if target.withdrawn_at is not null then
    return jsonb_build_object(
      'id',target.id,
      'status',target.status,
      'withdrawn_at',target.withdrawn_at,
      'management_version',target.management_version
    );
  end if;

  if p_expected_version is null or target.management_version is distinct from p_expected_version then
    raise exception using errcode='PT409', message='expected_version_conflict', detail='HAPPENS_STALE_VERSION';
  end if;

  if target.status='draft' then
    raise check_violation using message='post_not_published';
  end if;

  normalized_reason:=nullif(btrim(coalesce(p_reason,'')),'');
  if normalized_reason is not null and char_length(normalized_reason)>280 then
    raise check_violation using message='reason_too_long';
  end if;

  update public.posts
  set withdrawn_at=now(),
      withdrawn_by_person_id=actor.person_id,
      withdrawal_reason=normalized_reason,
      management_version=management_version+1,
      updated_at=now()
  where id=target.id
  returning * into target;

  insert into app_private.happens_publication_audit(
    post_id,institution_id,actor_person_id,event_code,detail)
  values(
    target.id,target.institution_id,actor.person_id,'post_withdrawn',
    jsonb_build_object('request_id',p_request_id,'reason',normalized_reason));

  return jsonb_build_object(
    'id',target.id,
    'status',target.status,
    'withdrawn_at',target.withdrawn_at,
    'management_version',target.management_version
  );
end $$;

-- public.withdraw_moment [MOMENTS]: corpo do dump de producao 17/09 (SHA-256 c87f4d67); raises trocados: 1, handlers: 0.
create or replace function "public"."withdraw_moment"("p_request_id" "uuid", "p_publication_id" "uuid", "p_expected_version" bigint, "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  actor record;
  target public.moments_publications%rowtype;
  reason text := nullif(btrim(coalesce(p_reason, '')), '');
  fingerprint text;
  prior record;
  receipt_id uuid := gen_random_uuid();
  result jsonb;
begin
  select * into target from public.moments_publications publication
  where publication.id = p_publication_id for update;
  if target.id is null then
    raise insufficient_privilege using message = 'publication_not_authorized';
  end if;
  select * into actor from app_private.moments_actor(
    target.institution_id, 'moments.publications.remove', target.unit_id, target.group_id
  );
  if target.author_person_id <> actor.person_id then
    raise insufficient_privilege using message = 'publication_not_authorized';
  end if;
  if reason is not null and char_length(reason) > 280 then
    raise check_violation using message = 'withdrawal_reason_too_long';
  end if;

  fingerprint := app_private.moments_request_fingerprint(jsonb_build_object(
    'publication_id', p_publication_id,
    'expected_version', p_expected_version,
    'reason', reason
  ));
  perform pg_advisory_xact_lock(
    hashtextextended(actor.person_id::text || p_request_id::text, 0)
  );
  select receipt.request_fingerprint, receipt.response into prior
  from app_private.moments_command_receipts receipt
  where receipt.actor_person_id = actor.person_id
    and receipt.command_name = 'withdraw'
    and receipt.request_id = p_request_id;
  if prior.response is not null then
    if prior.request_fingerprint <> fingerprint then
      raise unique_violation using message = 'idempotency_key_reused';
    end if;
    return prior.response;
  end if;

  -- Already withdrawn: idempotent echo of the current state, no new audit row.
  if target.withdrawn_at is not null then
    return jsonb_build_object(
      'id', target.id,
      'status', target.status,
      'withdrawn_at', target.withdrawn_at,
      'version', target.management_version
    );
  end if;

  if target.status <> 'published' then
    raise check_violation using message = 'publication_not_published';
  end if;
  if p_expected_version is not null
    and target.management_version <> p_expected_version then
    raise exception using errcode='PT409', message = 'expected_version_conflict', detail='MOMENTS_STALE_VERSION';
  end if;

  update public.moments_publications publication set
    withdrawn_at = now(),
    withdrawn_by_person_id = actor.person_id,
    withdrawal_reason = reason,
    management_version = publication.management_version + 1,
    updated_at = now()
  where publication.id = target.id
  returning * into target;

  result := jsonb_build_object(
    'id', target.id,
    'status', target.status,
    'withdrawn_at', target.withdrawn_at,
    'version', target.management_version,
    'receipt_id', receipt_id
  );
  insert into app_private.moments_command_receipts (
    id, actor_person_id, institution_id, command_name,
    request_id, request_fingerprint, response
  ) values (
    receipt_id, actor.person_id, target.institution_id, 'withdraw',
    p_request_id, fingerprint, result
  );
  insert into app_private.moments_publication_audit (
    publication_id, institution_id, actor_person_id, receipt_id, event_code, detail
  ) values (
    target.id, target.institution_id, actor.person_id, receipt_id,
    'publication_withdrawn',
    jsonb_build_object(
      'request_id', p_request_id,
      'reason', reason,
      'version', target.management_version
    )
  );
  return result;
end
$$;

do $postcheck$
declare n_sf int; n_40001 int; n_pt int;
begin
  select count(*) into n_sf from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname not in ('pg_catalog','information_schema','extensions')
      and p.prosrc ~* 'raise\s+serialization_failure';
  select count(*) into n_40001 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname not in ('pg_catalog','information_schema','extensions')
      and p.prosrc ~* 'errcode\s*=\s*''40001''';
  select count(*) into n_pt from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public','app_private') and p.prosrc like '%PT409%';
  if n_sf <> 0 or n_40001 <> 0 then
    raise exception using message = format('pt409 fix incomplete: %s serialization_failure, %s errcode 40001 remaining', n_sf, n_40001);
  end if;
  if n_pt < 126 then
    raise exception using message = format('pt409 fix incomplete: only %s functions reference PT409', n_pt);
  end if;
end
$postcheck$;

commit;
