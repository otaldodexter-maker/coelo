---
source: "rg scan of packages/coelo_database/supabase/tests; proposed-password-session-context.sql"
status: "impact-candidates-not-executed"
generated_at: "2026-09-09"
---

Sessao/AMR mencionado em 37 suites; zero suites existentes inserem AMR.
A lista indica candidatas a inspecao, nao falhas comprovadas nem autorizacao
para alterar todas. Dez suites referem explicitamente o helper ou seus RPCs.
Consumo indireto pode ampliar a necessidade de alinhar fixtures.

Candidatas por auth.sessions/mfa_amr_claims:

- packages/coelo_database/supabase/tests\access_profile_models_aal1_phase_policy_test.sql
- packages/coelo_database/supabase/tests\access_profile_models_crud_catalog_test.sql
- packages/coelo_database/supabase/tests\access_profile_models_read_authorization_test.sql
- packages/coelo_database/supabase/tests\access_profile_models_read_prelookup_regression_test.sql
- packages/coelo_database/supabase/tests\access_profiles_internal_read_contract_test.sql
- packages/coelo_database/supabase/tests\activity_template_unit_scope_test.sql
- packages/coelo_database/supabase/tests\forms_superadmin_media_read_r2_v1_test.sql
- packages/coelo_database/supabase/tests\forms_superadmin_operations_read_v2_test.sql
- packages/coelo_database/supabase/tests\forms_xlsx_private_r2_v1_test.sql
- packages/coelo_database/supabase/tests\superadmin_activity_save_v2_test.sql
- packages/coelo_database/supabase/tests\superadmin_agenda_read_v2_contract_test.sql
- packages/coelo_database/supabase/tests\superadmin_assessments_internal_v2_test.sql
- packages/coelo_database/supabase/tests\superadmin_forms_authoring_institution_context_v2_test.sql
- packages/coelo_database/supabase/tests\superadmin_forms_directory_internal_read_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_activities_v2_actor_contract_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_activities_v2_commands_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_activities_v2_directory_contract_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_activities_v2_hardening_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_activities_v2_permissions_publish_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_activities_v2_read_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_activities_v2_relationships_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_auth_context_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_chat_v2_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_circulars_v2_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_form_drafts_v2_repeatable_read_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_form_drafts_v2_serializable_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_form_drafts_v2_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_group_detail_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_institution_detail_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_institution_edit_core_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_institution_list_filter_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_invites_v2_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_notices_v2_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_person_detail_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_unit_detail_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_users_directory_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_users_read_minimization_test.sql

Referencias diretas ao helper/RPCs:

- packages/coelo_database/supabase/tests\access_profile_models_aal1_phase_policy_test.sql
- packages/coelo_database/supabase/tests\access_profile_models_crud_catalog_test.sql
- packages/coelo_database/supabase/tests\access_profiles_internal_read_contract_test.sql
- packages/coelo_database/supabase/tests\activity_template_unit_scope_test.sql
- packages/coelo_database/supabase/tests\superadmin_assessments_internal_v2_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_auth_context_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_institution_detail_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_institution_edit_core_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_institution_list_filter_test.sql
- packages/coelo_database/supabase/tests\superadmin_internal_structures_v2_scope_guard_test.sql
