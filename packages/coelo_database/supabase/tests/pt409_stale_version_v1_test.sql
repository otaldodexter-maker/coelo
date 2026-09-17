-- Somente replay LOCAL descartavel. Nenhuma fixture de negocio; nenhuma conta real.
-- Prova estrutural da migration 20260917090000_pt409_stale_version_v1 (R15 Bloco B, OQ-047,
-- ADR 0042 E1): nenhuma RPC das familias abaixo sinaliza versao defasada/conflito otimista com
-- SQLSTATE 40001 (serialization_failure, reexecutado sem limite pelo PostgREST 14.5); todas
-- usam PT409 (HTTP 409 sem retentativa) e os wrappers que capturavam o 40001 interno para o
-- envelope SAI_CONCURRENT_CHANGE capturam tambem PT409. Assinatura, security definer,
-- search_path, ACL, dono, volatilidade e tipo de retorno de cada uma das 126 funcoes sao os do
-- dump de producao de 17/09 (SHA-256 c87f4d67), capturados no espelho antes da migration.
-- A prova comportamental (versao defasada -> PT409 sem mutacao; caminho feliz intacto) e feita
-- pelas suites por familia ja existentes, ajustadas de 40001 para PT409 (forms_behavioral_rpc,
-- forms_response_edit_validation_v1, forms_xlsx_private_r2_v1, happens_post_withdrawal,
-- institution_system_model_delete_v1, superadmin_plans_behavior_v1, superadmin_support_assignees_v1,
-- ap_models_nominal_rollback) e pelas suites de envelope (SAI_CONCURRENT_CHANGE) das familias
-- activities/locations/group_location/invites/institution/structure/forms v2, comparadas antes e
-- depois da migration no espelho (evidencia r15-bloco-b/oq047-pt409-20260917.md).
begin;
create extension if not exists pgtap with schema extensions;
select plan(37);

create temp table pt409_expected(sig text primary key, n_raise int, n_handler int);
insert into pt409_expected values
  ('app_private.access_profile_model_call(text,jsonb)',0,1),
  ('app_private.activity_v2_replay_or_error(app_private.superadmin_internal_context,uuid,uuid,uuid,text,bytea,uuid)',1,0),
  ('app_private.assessment_v2_activate_configuration(uuid,uuid,bigint)',1,0),
  ('app_private.assessment_v2_save_configuration(uuid,uuid,bigint,jsonb)',2,0),
  ('app_private.assessment_v2_save_gradebook(uuid,uuid,bigint,jsonb,text)',2,0),
  ('app_private.assessment_v2_transition_gradebook(uuid,uuid,bigint,text,text,text,timestamp with time zone)',1,0),
  ('app_private.change_unit_handle_for_superadmin(uuid,uuid,bigint,text)',1,0),
  ('app_private.child_safety_save_restriction(uuid,jsonb)',1,0),
  ('app_private.create_institution_for_superadmin(uuid,jsonb)',1,0),
  ('app_private.form_archive_or_delete(uuid,bigint,jsonb)',1,0),
  ('app_private.form_begin_command(uuid,uuid,text,bigint,jsonb)',1,0),
  ('app_private.form_complete_command(uuid,jsonb)',1,0),
  ('app_private.form_complete_notification_delivery(uuid,uuid,text,boolean,text)',1,0),
  ('app_private.form_copy_or_move(uuid,bigint,jsonb)',1,0),
  ('app_private.form_duplicate(uuid,bigint,jsonb)',1,0),
  ('app_private.form_fail_worker_job(uuid,text,text,integer,jsonb)',1,0),
  ('app_private.form_finalize_asset_upload(uuid,bigint,jsonb)',1,0),
  ('app_private.form_finish_worker_job(uuid,text,jsonb)',1,0),
  ('app_private.form_mutate_response(text,uuid,bigint,jsonb,boolean)',1,0),
  ('app_private.form_open_response_draft(uuid,bigint,jsonb)',1,0),
  ('app_private.form_prepare_asset_upload(uuid,bigint,jsonb)',1,0),
  ('app_private.form_publish(uuid,bigint,jsonb)',1,0),
  ('app_private.form_remove_schedule(uuid,bigint,jsonb)',1,0),
  ('app_private.form_request_export(uuid,bigint,jsonb,boolean)',1,0),
  ('app_private.form_save_application(uuid,bigint,jsonb)',2,0),
  ('app_private.form_save_draft(uuid,bigint,jsonb)',2,0),
  ('app_private.form_save_schedule(uuid,bigint,jsonb)',2,0),
  ('app_private.form_worker_abort_multipart(uuid,text,uuid,text)',1,0),
  ('app_private.form_worker_begin_export(uuid,text,uuid)',1,0),
  ('app_private.form_worker_begin_multipart(uuid,text,uuid,text,text,text)',2,0),
  ('app_private.form_worker_cleanup_snapshot(uuid,text,integer)',1,0),
  ('app_private.form_worker_complete_cleanup(uuid,text,uuid[])',2,0),
  ('app_private.form_worker_complete_export(uuid,text,uuid,text,bigint,jsonb)',1,0),
  ('app_private.form_worker_complete_multipart(uuid,text,uuid,text)',1,0),
  ('app_private.form_worker_complete_xlsx_r2_v1(uuid,text,uuid,uuid,bigint,text)',1,0),
  ('app_private.form_worker_fail_export(uuid,text,uuid,text,integer)',1,0),
  ('app_private.form_worker_multipart_snapshot(uuid,text,uuid)',1,0),
  ('app_private.form_worker_multipart_xlsx_r2_v1(jsonb,text,jsonb)',8,0),
  ('app_private.form_worker_record_multipart_part(uuid,text,uuid,text,integer,text,bigint,text)',3,0),
  ('app_private.forms_xlsx_worker_job_v1(uuid,text,uuid,uuid)',3,0),
  ('app_private.guard_superadmin_internal_auth_link_lifecycle()',1,0),
  ('app_private.guard_superadmin_internal_membership_lifecycle()',1,0),
  ('app_private.location_reservation_command_v2(text,uuid,jsonb,uuid)',5,1),
  ('app_private.superadmin_access_profile_assignment_link(uuid,jsonb)',3,0),
  ('app_private.superadmin_access_profile_assignment_overrides_save(uuid,uuid,bigint,jsonb,text)',3,0),
  ('app_private.superadmin_access_profile_assignment_unlink(uuid,uuid,bigint,text)',3,0),
  ('app_private.superadmin_access_profile_create_from_model(uuid,jsonb)',1,0),
  ('app_private.superadmin_access_profile_delete_and_reassign(uuid,text,uuid,bigint,uuid,text)',2,0),
  ('app_private.superadmin_access_profile_duplicate(uuid,jsonb)',1,0),
  ('app_private.superadmin_access_profile_import_confirm(uuid,uuid,bigint)',1,0),
  ('app_private.superadmin_access_profile_model_delete(uuid,uuid,bigint,text)',1,0),
  ('app_private.superadmin_access_profile_model_update(uuid,jsonb)',1,0),
  ('app_private.superadmin_access_profile_update(uuid,jsonb)',1,0),
  ('app_private.superadmin_form_request_xlsx_v2(uuid,bigint,jsonb)',1,0),
  ('app_private.superadmin_forms_save_draft_v2(uuid,bigint,jsonb)',2,1),
  ('app_private.superadmin_group_save(uuid,uuid,bigint,jsonb)',2,0),
  ('app_private.superadmin_health_care_save_profile(uuid,uuid,bigint,jsonb)',2,0),
  ('app_private.superadmin_institution_contacts_apply_v1(uuid,uuid,bigint,jsonb,bytea,app_private.superadmin_internal_context,uuid)',1,0),
  ('app_private.superadmin_institution_edit_core_apply_v2(uuid,uuid,bigint,jsonb,bytea,app_private.superadmin_internal_context,uuid)',1,0),
  ('app_private.superadmin_internal_user_denial_code(text,text)',0,1),
  ('app_private.superadmin_medication_plan_save(uuid,uuid,bigint,jsonb)',2,0),
  ('app_private.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb)',1,0),
  ('app_private.superadmin_routine_publish_launch(uuid,uuid,bigint)',1,0),
  ('app_private.superadmin_routine_revert_application(uuid,uuid,bigint)',1,0),
  ('app_private.superadmin_routine_save_application(uuid,uuid,bigint,jsonb)',2,0),
  ('app_private.superadmin_routine_save_launch_draft(uuid,uuid,bigint,jsonb)',2,0),
  ('app_private.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)',2,0),
  ('app_private.superadmin_upsert_activity(jsonb,uuid)',1,0),
  ('app_private.transfer_unit_institution_for_superadmin(uuid,uuid,uuid,bigint,boolean)',1,0),
  ('app_private.update_institution_for_superadmin(uuid,uuid,bigint,jsonb)',2,0),
  ('app_private.update_superadmin_person(uuid,timestamp with time zone,jsonb,jsonb)',1,0),
  ('app_private.update_unit_for_superadmin(uuid,jsonb,uuid,bigint)',1,0),
  ('public.close_circular_responses(uuid,uuid,bigint)',1,0),
  ('public.delete_circular(uuid,uuid,bigint)',1,0),
  ('public.publish_circular(uuid,uuid,bigint,timestamp with time zone)',1,0),
  ('public.publish_happens_post(uuid,uuid,bigint,timestamp with time zone)',1,0),
  ('public.publish_moment(uuid,uuid,bigint)',1,0),
  ('public.publish_now(uuid,uuid,bigint,timestamp with time zone)',1,0),
  ('public.publish_profile_about(text,uuid,bigint,uuid)',1,0),
  ('public.remove_now_publication(uuid,uuid,bigint,text)',1,0),
  ('public.save_circular_draft(uuid,jsonb,uuid,bigint)',1,0),
  ('public.save_circular_response_draft(uuid,uuid,jsonb,bigint)',2,0),
  ('public.save_happens_draft(uuid,jsonb,uuid,bigint)',1,0),
  ('public.save_moments_draft(uuid,jsonb,uuid,bigint)',1,0),
  ('public.save_now_draft(uuid,jsonb,uuid,bigint)',1,0),
  ('public.save_profile_about(text,uuid,jsonb,bigint,uuid,jsonb)',2,0),
  ('public.submit_circular_response(uuid,uuid,bigint)',1,0),
  ('public.superadmin_activity_location_create_v2(uuid,uuid,jsonb,jsonb)',4,1),
  ('public.superadmin_activity_publish_v2(uuid,uuid,bigint)',1,0),
  ('public.superadmin_activity_save_v2(uuid,uuid,bigint,boolean,jsonb)',1,0),
  ('public.superadmin_activity_set_groups_v2(uuid,uuid,bigint,uuid[],jsonb)',1,0),
  ('public.superadmin_activity_set_participants_v2(uuid,uuid,bigint,jsonb)',1,0),
  ('public.superadmin_activity_set_permissions_v2(uuid,uuid,bigint,jsonb,jsonb,jsonb)',1,0),
  ('public.superadmin_activity_set_professionals_v2(uuid,uuid,bigint,jsonb)',1,0),
  ('public.superadmin_activity_set_units_v2(uuid,uuid,bigint,uuid[])',1,0),
  ('public.superadmin_activity_update_v2(uuid,uuid,bigint,jsonb)',1,0),
  ('public.superadmin_agenda_command(uuid,uuid,bigint,text,text)',1,0),
  ('public.superadmin_agenda_save(uuid,uuid,bigint,jsonb,text,boolean)',1,0),
  ('public.superadmin_child_context_directory_v2(uuid,text,uuid,integer)',0,1),
  ('public.superadmin_circular_close_v2(uuid,uuid,bigint)',1,0),
  ('public.superadmin_circular_delete_v2(uuid,uuid,bigint)',1,0),
  ('public.superadmin_circular_publish_v2(uuid,uuid,bigint,timestamp with time zone)',1,0),
  ('public.superadmin_circular_save_draft_v2(uuid,uuid,uuid,uuid,uuid,jsonb)',1,0),
  ('public.superadmin_group_location_create_v2(uuid,uuid,jsonb,jsonb)',4,1),
  ('public.superadmin_institution_contacts_edit_v1(uuid,uuid,bigint,jsonb)',0,1),
  ('public.superadmin_institution_edit_core_v2(uuid,uuid,bigint,jsonb)',0,1),
  ('public.superadmin_internal_user_change_status(uuid,uuid,bigint,text,text)',1,0),
  ('public.superadmin_internal_user_update(uuid,uuid,bigint,text,jsonb)',1,0),
  ('public.superadmin_invite_issue_v2(uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer)',1,1),
  ('public.superadmin_invite_resend_v2(uuid,uuid,bigint)',2,1),
  ('public.superadmin_invite_revoke_v2(uuid,uuid,bigint,text)',2,1),
  ('public.superadmin_location_copy_v2(uuid,text,uuid,uuid,text,uuid)',1,1),
  ('public.superadmin_location_create_v2(jsonb,uuid)',1,1),
  ('public.superadmin_location_schedule_set_v2(uuid,jsonb,bigint,uuid)',3,1),
  ('public.superadmin_location_set_status_v2(uuid,text,bigint,uuid)',3,1),
  ('public.superadmin_location_update_v2(uuid,jsonb,bigint,uuid)',3,1),
  ('public.superadmin_notice_change_status_v2(uuid,uuid,bigint,text,text)',1,0),
  ('public.superadmin_notice_publish_v2(uuid,uuid,bigint)',1,0),
  ('public.superadmin_notice_save_draft_v2(uuid,uuid,bigint,jsonb)',2,0),
  ('public.superadmin_plan_save(uuid,uuid,bigint,jsonb,text)',1,0),
  ('public.superadmin_structure_handle_set_v1(uuid,text,uuid,bigint,text)',1,1),
  ('public.superadmin_support_reply(uuid,uuid,text,bigint)',1,0),
  ('public.superadmin_support_set_assignee(uuid,uuid,bigint,uuid)',1,0),
  ('public.superadmin_support_set_status(uuid,uuid,text,bigint)',1,0),
  ('public.withdraw_happens_post(uuid,uuid,bigint,text)',1,0),
  ('public.withdraw_moment(uuid,uuid,bigint,text)',1,0);
create temp table pt409_props(sig text primary key, secdef boolean, config text, acl text, owner text, volatile text, rettype text);
-- Bloco pt409_props com as propriedades REAIS das 126 funcoes (ACL de producao), lido do espelho
-- coelo_mirror_r15_b_apoio restaurado do dump pos-lote 75 (schema-producao-20260917-b-apoio-pos-lote75.sql,
-- SHA-256 66f8bacc) com os default privileges locais revogados antes da restauracao (anon executa 0 funcoes
insert into pt409_props values
  ('app_private.access_profile_model_call(text,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.activity_v2_replay_or_error(app_private.superadmin_internal_context,uuid,uuid,uuid,text,bytea,uuid)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.assessment_v2_activate_configuration(uuid,uuid,bigint)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.assessment_v2_save_configuration(uuid,uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.assessment_v2_save_gradebook(uuid,uuid,bigint,jsonb,text)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.assessment_v2_transition_gradebook(uuid,uuid,bigint,text,text,text,timestamp with time zone)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.change_unit_handle_for_superadmin(uuid,uuid,bigint,text)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.child_safety_save_restriction(uuid,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('app_private.create_institution_for_superadmin(uuid,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_archive_or_delete(uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_begin_command(uuid,uuid,text,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_complete_command(uuid,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_complete_notification_delivery(uuid,uuid,text,boolean,text)',true,'search_path=""','{postgres=X/postgres}','postgres','v','void'),
  ('app_private.form_copy_or_move(uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_duplicate(uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_fail_worker_job(uuid,text,text,integer,jsonb)',true,'search_path=""','{postgres=X/postgres,service_role=X/postgres}','postgres','v','void'),
  ('app_private.form_finalize_asset_upload(uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_finish_worker_job(uuid,text,jsonb)',true,'search_path=""','{postgres=X/postgres,service_role=X/postgres}','postgres','v','void'),
  ('app_private.form_mutate_response(text,uuid,bigint,jsonb,boolean)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_open_response_draft(uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_prepare_asset_upload(uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_publish(uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_remove_schedule(uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_request_export(uuid,bigint,jsonb,boolean)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_save_application(uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_save_draft(uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_save_schedule(uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_worker_abort_multipart(uuid,text,uuid,text)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_worker_begin_export(uuid,text,uuid)',true,'search_path=""','{postgres=X/postgres}','postgres','v','void'),
  ('app_private.form_worker_begin_multipart(uuid,text,uuid,text,text,text)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_worker_cleanup_snapshot(uuid,text,integer)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_worker_complete_cleanup(uuid,text,uuid[])',true,'search_path=""','{postgres=X/postgres}','postgres','v','void'),
  ('app_private.form_worker_complete_export(uuid,text,uuid,text,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','void'),
  ('app_private.form_worker_complete_multipart(uuid,text,uuid,text)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_worker_complete_xlsx_r2_v1(uuid,text,uuid,uuid,bigint,text)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_worker_fail_export(uuid,text,uuid,text,integer)',true,'search_path=""','{postgres=X/postgres}','postgres','v','void'),
  ('app_private.form_worker_multipart_snapshot(uuid,text,uuid)',true,'search_path=""','{postgres=X/postgres}','postgres','s','jsonb'),
  ('app_private.form_worker_multipart_xlsx_r2_v1(jsonb,text,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.form_worker_record_multipart_part(uuid,text,uuid,text,integer,text,bigint,text)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.forms_xlsx_worker_job_v1(uuid,text,uuid,uuid)',true,'search_path=""','{postgres=X/postgres}','postgres','v','form_file_jobs'),
  ('app_private.guard_superadmin_internal_auth_link_lifecycle()',true,'search_path=""','{postgres=X/postgres}','postgres','v','trigger'),
  ('app_private.guard_superadmin_internal_membership_lifecycle()',true,'search_path=""','{postgres=X/postgres}','postgres','v','trigger'),
  ('app_private.location_reservation_command_v2(text,uuid,jsonb,uuid)',true,'search_path="",TimeZone=UTC','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_access_profile_assignment_link(uuid,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_access_profile_assignment_overrides_save(uuid,uuid,bigint,jsonb,text)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_access_profile_assignment_unlink(uuid,uuid,bigint,text)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_access_profile_create_from_model(uuid,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_access_profile_delete_and_reassign(uuid,text,uuid,bigint,uuid,text)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_access_profile_duplicate(uuid,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_access_profile_import_confirm(uuid,uuid,bigint)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_access_profile_model_delete(uuid,uuid,bigint,text)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_access_profile_model_update(uuid,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_access_profile_update(uuid,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_form_request_xlsx_v2(uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_forms_save_draft_v2(uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_group_save(uuid,uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_health_care_save_profile(uuid,uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_institution_contacts_apply_v1(uuid,uuid,bigint,jsonb,bytea,app_private.superadmin_internal_context,uuid)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_institution_edit_core_apply_v2(uuid,uuid,bigint,jsonb,bytea,app_private.superadmin_internal_context,uuid)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_internal_user_denial_code(text,text)',false,'search_path=""','{postgres=X/postgres}','postgres','i','text'),
  ('app_private.superadmin_medication_plan_save(uuid,uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_routine_publish_launch(uuid,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_routine_revert_application(uuid,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_routine_save_application(uuid,uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_routine_save_launch_draft(uuid,uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}','postgres','v','jsonb'),
  ('app_private.superadmin_upsert_activity(jsonb,uuid)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.transfer_unit_institution_for_superadmin(uuid,uuid,uuid,bigint,boolean)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.update_institution_for_superadmin(uuid,uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('app_private.update_superadmin_person(uuid,timestamp with time zone,jsonb,jsonb)',true,'search_path=""','{postgres=X/postgres,service_role=X/postgres}','postgres','v','jsonb'),
  ('app_private.update_unit_for_superadmin(uuid,jsonb,uuid,bigint)',true,'search_path=""','{postgres=X/postgres}','postgres','v','jsonb'),
  ('public.close_circular_responses(uuid,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.delete_circular(uuid,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.publish_circular(uuid,uuid,bigint,timestamp with time zone)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.publish_happens_post(uuid,uuid,bigint,timestamp with time zone)',true,'search_path=""','{postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.publish_moment(uuid,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.publish_now(uuid,uuid,bigint,timestamp with time zone)',true,'search_path=""','{postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.publish_profile_about(text,uuid,bigint,uuid)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.remove_now_publication(uuid,uuid,bigint,text)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.save_circular_draft(uuid,jsonb,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.save_circular_response_draft(uuid,uuid,jsonb,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.save_happens_draft(uuid,jsonb,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.save_moments_draft(uuid,jsonb,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.save_now_draft(uuid,jsonb,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.save_profile_about(text,uuid,jsonb,bigint,uuid,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.submit_circular_response(uuid,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_activity_location_create_v2(uuid,uuid,jsonb,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_activity_publish_v2(uuid,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_activity_save_v2(uuid,uuid,bigint,boolean,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_activity_set_groups_v2(uuid,uuid,bigint,uuid[],jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_activity_set_participants_v2(uuid,uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_activity_set_permissions_v2(uuid,uuid,bigint,jsonb,jsonb,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_activity_set_professionals_v2(uuid,uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_activity_set_units_v2(uuid,uuid,bigint,uuid[])',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_activity_update_v2(uuid,uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_agenda_command(uuid,uuid,bigint,text,text)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_agenda_save(uuid,uuid,bigint,jsonb,text,boolean)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_child_context_directory_v2(uuid,text,uuid,integer)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_circular_close_v2(uuid,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_circular_delete_v2(uuid,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_circular_publish_v2(uuid,uuid,bigint,timestamp with time zone)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_circular_save_draft_v2(uuid,uuid,uuid,uuid,uuid,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_group_location_create_v2(uuid,uuid,jsonb,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_institution_contacts_edit_v1(uuid,uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_institution_edit_core_v2(uuid,uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_internal_user_change_status(uuid,uuid,bigint,text,text)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_internal_user_update(uuid,uuid,bigint,text,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_invite_issue_v2(uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_invite_resend_v2(uuid,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_invite_revoke_v2(uuid,uuid,bigint,text)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_location_copy_v2(uuid,text,uuid,uuid,text,uuid)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_location_create_v2(jsonb,uuid)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_location_schedule_set_v2(uuid,jsonb,bigint,uuid)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_location_set_status_v2(uuid,text,bigint,uuid)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_location_update_v2(uuid,jsonb,bigint,uuid)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_notice_change_status_v2(uuid,uuid,bigint,text,text)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_notice_publish_v2(uuid,uuid,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_notice_save_draft_v2(uuid,uuid,bigint,jsonb)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_plan_save(uuid,uuid,bigint,jsonb,text)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_structure_handle_set_v1(uuid,text,uuid,bigint,text)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_support_reply(uuid,uuid,text,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_support_set_assignee(uuid,uuid,bigint,uuid)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}','postgres','v','jsonb'),
  ('public.superadmin_support_set_status(uuid,uuid,text,bigint)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}','postgres','v','jsonb'),
  ('public.withdraw_happens_post(uuid,uuid,bigint,text)',true,'search_path=""','{postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}','postgres','v','jsonb'),
  ('public.withdraw_moment(uuid,uuid,bigint,text)',true,'search_path=""','{postgres=X/postgres,authenticated=X/postgres}','postgres','v','jsonb');

-- 1. Nenhum raise serialization_failure sobrou fora do catalogo do sistema.
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname not in ('pg_catalog','information_schema','extensions')
    and p.prosrc ~* 'raise\s+serialization_failure'),0,
  'nenhuma funcao levanta serialization_failure (40001) por raise');
-- 2. Nenhum raise exception using errcode=40001 sobrou.
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname not in ('pg_catalog','information_schema','extensions')
    and p.prosrc ~* 'errcode\s*=\s*''40001'''),0,
  'nenhuma funcao levanta errcode 40001 explicitamente');
-- 3. Todas as 126 funcoes existem com a assinatura do dump.
select is((select count(*)::int from pt409_expected where to_regprocedure(sig) is null),0,
  'as 126 funcoes da migration existem com a assinatura do dump de producao');
-- 4. Cada funcao tem exatamente o numero esperado de raises PT409 (175 no total).
select is((select count(*)::int from pt409_expected e join pg_proc p on p.oid=e.sig::regprocedure
  where (length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''') <> e.n_raise),0,
  'cada funcao contem exatamente o numero esperado de raise errcode=PT409 (175 raises)');
-- 5. Cada handler que capturava 40001 agora captura tambem PT409 (18 handlers).
select is((select coalesce(sum(
    (length(p.prosrc)-length(replace(p.prosrc,'serialization_failure or sqlstate ''PT409''','')))/length('serialization_failure or sqlstate ''PT409''')
   +(length(p.prosrc)-length(replace(p.prosrc,'in(''40001'',''23505'',''PT409'')','')))/length('in(''40001'',''23505'',''PT409'')')
   +(length(p.prosrc)-length(replace(p.prosrc,'in(''40001'',''PT409'')','')))/length('in(''40001'',''PT409'')')),0)::int
  from pt409_expected e join pg_proc p on p.oid=e.sig::regprocedure),18,
  'os 18 handlers de 40001 capturam tambem PT409');
-- 6. Nenhum handler ficou so com serialization_failure (sem PT409) nas funcoes tocadas.
select is((select count(*)::int from pt409_expected e join pg_proc p on p.oid=e.sig::regprocedure
  where p.prosrc ~* 'when[^\n]*serialization_failure' and p.prosrc !~* 'serialization_failure or sqlstate ''PT409'''),0,
  'nenhum handler when serialization_failure ficou sem PT409');
-- 7. Nenhuma funcao (public/app_private/audit) mapeia 40001 sem mapear tambem PT409.
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','app_private','audit') and p.prosrc like '%''40001''%'
    and p.prosrc not like '%''PT409''%'),0,
  'nenhuma funcao mapeia 40001 sem mapear tambem PT409');
-- 8. Propriedades preservadas (security definer, search_path, ACL, dono, volatilidade, retorno).
select is((select count(*)::int from pt409_props x join pg_proc p on p.oid=x.sig::regprocedure
  where p.prosecdef<>x.secdef or coalesce(array_to_string(p.proconfig,','),'')<>x.config
     or coalesce(p.proacl::text,'')<>x.acl or pg_get_userbyid(p.proowner)<>x.owner
     or p.provolatile::text<>x.volatile or p.prorettype::regtype::text<>x.rettype),0,
  'security definer, search_path, ACL, dono, volatilidade e retorno preservados nas 126 funcoes');
-- 9. Detail presente em todo raise PT409 (codigo por familia ou o detail original do envelope).
select is((select count(*)::int from pt409_expected e join pg_proc p on p.oid=e.sig::regprocedure
  where e.n_raise>0 and (length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')
    > (select count(*) from regexp_matches(p.prosrc,'errcode=''PT409''[^;]*detail\s*=','g'))),0,
  'todo raise PT409 carrega detail (codigo da familia ou detail original)');
-- familia ACCESS_PROFILE: 11 funcoes, 17 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.access_profile_model_call(text,jsonb)','app_private.superadmin_access_profile_assignment_link(uuid,jsonb)','app_private.superadmin_access_profile_assignment_overrides_save(uuid,uuid,bigint,jsonb,text)','app_private.superadmin_access_profile_assignment_unlink(uuid,uuid,bigint,text)','app_private.superadmin_access_profile_create_from_model(uuid,jsonb)','app_private.superadmin_access_profile_delete_and_reassign(uuid,text,uuid,bigint,uuid,text)','app_private.superadmin_access_profile_duplicate(uuid,jsonb)','app_private.superadmin_access_profile_import_confirm(uuid,uuid,bigint)','app_private.superadmin_access_profile_model_delete(uuid,uuid,bigint,text)','app_private.superadmin_access_profile_model_update(uuid,jsonb)','app_private.superadmin_access_profile_update(uuid,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),17,
  'familia ACCESS_PROFILE: 17 raises PT409, nenhum raise 40001 (11 funcoes)');
-- familia ACTIVITY: 11 funcoes, 14 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.activity_v2_replay_or_error(app_private.superadmin_internal_context,uuid,uuid,uuid,text,bytea,uuid)','app_private.superadmin_upsert_activity(jsonb,uuid)','public.superadmin_activity_location_create_v2(uuid,uuid,jsonb,jsonb)','public.superadmin_activity_publish_v2(uuid,uuid,bigint)','public.superadmin_activity_save_v2(uuid,uuid,bigint,boolean,jsonb)','public.superadmin_activity_set_groups_v2(uuid,uuid,bigint,uuid[],jsonb)','public.superadmin_activity_set_participants_v2(uuid,uuid,bigint,jsonb)','public.superadmin_activity_set_permissions_v2(uuid,uuid,bigint,jsonb,jsonb,jsonb)','public.superadmin_activity_set_professionals_v2(uuid,uuid,bigint,jsonb)','public.superadmin_activity_set_units_v2(uuid,uuid,bigint,uuid[])','public.superadmin_activity_update_v2(uuid,uuid,bigint,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),14,
  'familia ACTIVITY: 14 raises PT409, nenhum raise 40001 (11 funcoes)');
-- familia AGENDA: 2 funcoes, 2 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['public.superadmin_agenda_command(uuid,uuid,bigint,text,text)','public.superadmin_agenda_save(uuid,uuid,bigint,jsonb,text,boolean)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),2,
  'familia AGENDA: 2 raises PT409, nenhum raise 40001 (2 funcoes)');
-- familia ASSESSMENT: 4 funcoes, 6 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.assessment_v2_activate_configuration(uuid,uuid,bigint)','app_private.assessment_v2_save_configuration(uuid,uuid,bigint,jsonb)','app_private.assessment_v2_save_gradebook(uuid,uuid,bigint,jsonb,text)','app_private.assessment_v2_transition_gradebook(uuid,uuid,bigint,text,text,text,timestamp with time zone)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),6,
  'familia ASSESSMENT: 6 raises PT409, nenhum raise 40001 (4 funcoes)');
-- familia CHILD_CONTEXT: 1 funcoes, 0 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['public.superadmin_child_context_directory_v2(uuid,text,uuid,integer)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),0,
  'familia CHILD_CONTEXT: 0 raises PT409, nenhum raise 40001 (1 funcoes)');
-- familia CHILD_SAFETY: 1 funcoes, 1 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.child_safety_save_restriction(uuid,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),1,
  'familia CHILD_SAFETY: 1 raises PT409, nenhum raise 40001 (1 funcoes)');
-- familia CIRCULAR: 10 funcoes, 11 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['public.close_circular_responses(uuid,uuid,bigint)','public.delete_circular(uuid,uuid,bigint)','public.publish_circular(uuid,uuid,bigint,timestamp with time zone)','public.save_circular_draft(uuid,jsonb,uuid,bigint)','public.save_circular_response_draft(uuid,uuid,jsonb,bigint)','public.submit_circular_response(uuid,uuid,bigint)','public.superadmin_circular_close_v2(uuid,uuid,bigint)','public.superadmin_circular_delete_v2(uuid,uuid,bigint)','public.superadmin_circular_publish_v2(uuid,uuid,bigint,timestamp with time zone)','public.superadmin_circular_save_draft_v2(uuid,uuid,uuid,uuid,uuid,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),11,
  'familia CIRCULAR: 11 raises PT409, nenhum raise 40001 (10 funcoes)');
-- familia FORMS: 17 funcoes, 21 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.form_archive_or_delete(uuid,bigint,jsonb)','app_private.form_begin_command(uuid,uuid,text,bigint,jsonb)','app_private.form_complete_command(uuid,jsonb)','app_private.form_copy_or_move(uuid,bigint,jsonb)','app_private.form_duplicate(uuid,bigint,jsonb)','app_private.form_finalize_asset_upload(uuid,bigint,jsonb)','app_private.form_mutate_response(text,uuid,bigint,jsonb,boolean)','app_private.form_open_response_draft(uuid,bigint,jsonb)','app_private.form_prepare_asset_upload(uuid,bigint,jsonb)','app_private.form_publish(uuid,bigint,jsonb)','app_private.form_remove_schedule(uuid,bigint,jsonb)','app_private.form_request_export(uuid,bigint,jsonb,boolean)','app_private.form_save_application(uuid,bigint,jsonb)','app_private.form_save_draft(uuid,bigint,jsonb)','app_private.form_save_schedule(uuid,bigint,jsonb)','app_private.superadmin_form_request_xlsx_v2(uuid,bigint,jsonb)','app_private.superadmin_forms_save_draft_v2(uuid,bigint,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),21,
  'familia FORMS: 21 raises PT409, nenhum raise 40001 (17 funcoes)');
-- familia FORMS_WORKER: 16 funcoes, 29 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.form_complete_notification_delivery(uuid,uuid,text,boolean,text)','app_private.form_fail_worker_job(uuid,text,text,integer,jsonb)','app_private.form_finish_worker_job(uuid,text,jsonb)','app_private.form_worker_abort_multipart(uuid,text,uuid,text)','app_private.form_worker_begin_export(uuid,text,uuid)','app_private.form_worker_begin_multipart(uuid,text,uuid,text,text,text)','app_private.form_worker_cleanup_snapshot(uuid,text,integer)','app_private.form_worker_complete_cleanup(uuid,text,uuid[])','app_private.form_worker_complete_export(uuid,text,uuid,text,bigint,jsonb)','app_private.form_worker_complete_multipart(uuid,text,uuid,text)','app_private.form_worker_complete_xlsx_r2_v1(uuid,text,uuid,uuid,bigint,text)','app_private.form_worker_fail_export(uuid,text,uuid,text,integer)','app_private.form_worker_multipart_snapshot(uuid,text,uuid)','app_private.form_worker_multipart_xlsx_r2_v1(jsonb,text,jsonb)','app_private.form_worker_record_multipart_part(uuid,text,uuid,text,integer,text,bigint,text)','app_private.forms_xlsx_worker_job_v1(uuid,text,uuid,uuid)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),29,
  'familia FORMS_WORKER: 29 raises PT409, nenhum raise 40001 (16 funcoes)');
-- familia GROUP: 1 funcoes, 2 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.superadmin_group_save(uuid,uuid,bigint,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),2,
  'familia GROUP: 2 raises PT409, nenhum raise 40001 (1 funcoes)');
-- familia GROUP_LOCATION: 1 funcoes, 4 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['public.superadmin_group_location_create_v2(uuid,uuid,jsonb,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),4,
  'familia GROUP_LOCATION: 4 raises PT409, nenhum raise 40001 (1 funcoes)');
-- familia HAPPENS: 3 funcoes, 3 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['public.publish_happens_post(uuid,uuid,bigint,timestamp with time zone)','public.save_happens_draft(uuid,jsonb,uuid,bigint)','public.withdraw_happens_post(uuid,uuid,bigint,text)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),3,
  'familia HAPPENS: 3 raises PT409, nenhum raise 40001 (3 funcoes)');
-- familia HEALTH_CARE: 1 funcoes, 2 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.superadmin_health_care_save_profile(uuid,uuid,bigint,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),2,
  'familia HEALTH_CARE: 2 raises PT409, nenhum raise 40001 (1 funcoes)');
-- familia INSTITUTION: 6 funcoes, 5 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.create_institution_for_superadmin(uuid,jsonb)','app_private.superadmin_institution_contacts_apply_v1(uuid,uuid,bigint,jsonb,bytea,app_private.superadmin_internal_context,uuid)','app_private.superadmin_institution_edit_core_apply_v2(uuid,uuid,bigint,jsonb,bytea,app_private.superadmin_internal_context,uuid)','app_private.update_institution_for_superadmin(uuid,uuid,bigint,jsonb)','public.superadmin_institution_contacts_edit_v1(uuid,uuid,bigint,jsonb)','public.superadmin_institution_edit_core_v2(uuid,uuid,bigint,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),5,
  'familia INSTITUTION: 5 raises PT409, nenhum raise 40001 (6 funcoes)');
-- familia INTERNAL_USER: 5 funcoes, 4 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.guard_superadmin_internal_auth_link_lifecycle()','app_private.guard_superadmin_internal_membership_lifecycle()','app_private.superadmin_internal_user_denial_code(text,text)','public.superadmin_internal_user_change_status(uuid,uuid,bigint,text,text)','public.superadmin_internal_user_update(uuid,uuid,bigint,text,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),4,
  'familia INTERNAL_USER: 4 raises PT409, nenhum raise 40001 (5 funcoes)');
-- familia INVITE: 3 funcoes, 5 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['public.superadmin_invite_issue_v2(uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer)','public.superadmin_invite_resend_v2(uuid,uuid,bigint)','public.superadmin_invite_revoke_v2(uuid,uuid,bigint,text)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),5,
  'familia INVITE: 5 raises PT409, nenhum raise 40001 (3 funcoes)');
-- familia LOCATION: 6 funcoes, 16 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.location_reservation_command_v2(text,uuid,jsonb,uuid)','public.superadmin_location_copy_v2(uuid,text,uuid,uuid,text,uuid)','public.superadmin_location_create_v2(jsonb,uuid)','public.superadmin_location_schedule_set_v2(uuid,jsonb,bigint,uuid)','public.superadmin_location_set_status_v2(uuid,text,bigint,uuid)','public.superadmin_location_update_v2(uuid,jsonb,bigint,uuid)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),16,
  'familia LOCATION: 16 raises PT409, nenhum raise 40001 (6 funcoes)');
-- familia MEDICATION: 1 funcoes, 2 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.superadmin_medication_plan_save(uuid,uuid,bigint,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),2,
  'familia MEDICATION: 2 raises PT409, nenhum raise 40001 (1 funcoes)');
-- familia MOMENTS: 3 funcoes, 3 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['public.publish_moment(uuid,uuid,bigint)','public.save_moments_draft(uuid,jsonb,uuid,bigint)','public.withdraw_moment(uuid,uuid,bigint,text)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),3,
  'familia MOMENTS: 3 raises PT409, nenhum raise 40001 (3 funcoes)');
-- familia NOTICE: 3 funcoes, 4 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['public.superadmin_notice_change_status_v2(uuid,uuid,bigint,text,text)','public.superadmin_notice_publish_v2(uuid,uuid,bigint)','public.superadmin_notice_save_draft_v2(uuid,uuid,bigint,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),4,
  'familia NOTICE: 4 raises PT409, nenhum raise 40001 (3 funcoes)');
-- familia NOW: 3 funcoes, 3 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['public.publish_now(uuid,uuid,bigint,timestamp with time zone)','public.remove_now_publication(uuid,uuid,bigint,text)','public.save_now_draft(uuid,jsonb,uuid,bigint)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),3,
  'familia NOW: 3 raises PT409, nenhum raise 40001 (3 funcoes)');
-- familia PERSON: 1 funcoes, 1 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.update_superadmin_person(uuid,timestamp with time zone,jsonb,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),1,
  'familia PERSON: 1 raises PT409, nenhum raise 40001 (1 funcoes)');
-- familia PLAN: 1 funcoes, 1 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['public.superadmin_plan_save(uuid,uuid,bigint,jsonb,text)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),1,
  'familia PLAN: 1 raises PT409, nenhum raise 40001 (1 funcoes)');
-- familia PROFILE_ABOUT: 2 funcoes, 3 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['public.publish_profile_about(text,uuid,bigint,uuid)','public.save_profile_about(text,uuid,jsonb,bigint,uuid,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),3,
  'familia PROFILE_ABOUT: 3 raises PT409, nenhum raise 40001 (2 funcoes)');
-- familia ROUTINE: 6 funcoes, 9 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb)','app_private.superadmin_routine_publish_launch(uuid,uuid,bigint)','app_private.superadmin_routine_revert_application(uuid,uuid,bigint)','app_private.superadmin_routine_save_application(uuid,uuid,bigint,jsonb)','app_private.superadmin_routine_save_launch_draft(uuid,uuid,bigint,jsonb)','app_private.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),9,
  'familia ROUTINE: 9 raises PT409, nenhum raise 40001 (6 funcoes)');
-- familia STRUCTURE: 1 funcoes, 1 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['public.superadmin_structure_handle_set_v1(uuid,text,uuid,bigint,text)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),1,
  'familia STRUCTURE: 1 raises PT409, nenhum raise 40001 (1 funcoes)');
-- familia SUPPORT: 3 funcoes, 3 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['public.superadmin_support_reply(uuid,uuid,text,bigint)','public.superadmin_support_set_assignee(uuid,uuid,bigint,uuid)','public.superadmin_support_set_status(uuid,uuid,text,bigint)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),3,
  'familia SUPPORT: 3 raises PT409, nenhum raise 40001 (3 funcoes)');
-- familia UNIT: 3 funcoes, 3 raises PT409.
select is((select coalesce(sum((length(p.prosrc)-length(replace(p.prosrc,'errcode=''PT409''','')))/length('errcode=''PT409''')),0)::int
  from pg_proc p where p.oid in (select s::regprocedure from unnest(array['app_private.change_unit_handle_for_superadmin(uuid,uuid,bigint,text)','app_private.transfer_unit_institution_for_superadmin(uuid,uuid,uuid,bigint,boolean)','app_private.update_unit_for_superadmin(uuid,jsonb,uuid,bigint)']) s)
  and p.prosrc !~* 'raise\s+serialization_failure'),3,
  'familia UNIT: 3 raises PT409, nenhum raise 40001 (3 funcoes)');

select * from finish();
rollback;
