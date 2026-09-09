---
title: "C04 — lista nominal das falhas do app inteiro, para poder comparar depois"
source: "flutter test em apps/superadmin, rodada completa"
status: "medido em 2026-09-09 03:00 -03:00, ponta 73ab3e9d"
generated_at: "2026-09-09T03:00:00-03:00"
timezone: "America/Sao_Paulo"
---

# Por que esta lista existe

Na revisao 55 comparei **64 arquivos / 35 golden / 29 nao-golden** de ontem com
**64 / 36 / 28** de agora, e nao consegui explicar a diferenca de um arquivo
nao-golden. O motivo e simples: **eu tinha guardado o numero e nao a lista**.

Contagem sem lista nao se compara com nada. Esta aqui a lista nominal desta
medicao, para que a proxima seja um diff e nao uma suposicao.

`4670 passam, 5 pulados, 208 falham em 64 arquivos`, em 8min50.

# Nao-golden (28)

**Nenhum nas sete familias do C04.**

- `app/dev_menu/development_dataset_contract_test.dart`
- `app/dev_menu_overlay_test.dart`
- `app/dev_menu_test.dart`
- `app/router/access_profile_authorization_revision_test.dart`
- `app/router/access_profile_preview_routes_test.dart`
- `app/router/access_profile_routes_test.dart`
- `app/router/assessment_routes_test.dart`
- `app/router/attendance_routes_test.dart`
- `app/router/composition_root_fail_closed_routes_test.dart`
- `app/router/daily_routine_routes_test.dart`
- `app/router/forms_composition_sanitization_source_test.dart`
- `app/router/forms_fail_closed_routes_test.dart`
- `app/router/import_development_routes_test.dart`
- `app/router/institution_directory_routes_test.dart`
- `app/router/meal_plan_production_routes_test.dart`
- `app/router/people_creation_requirements_red_test.dart`
- `app/router/people_routes_test.dart`
- `app/router/persistent_shell_routes_test.dart`
- `app/router/prototype_navigation_routes_test.dart`
- `app/router/safety_routes_test.dart`
- `app/router/unit_fail_closed_routes_test.dart`
- `app/router/unit_routes_test.dart`
- `core/config/composition_root_sanitization_test.dart`
- `core/config/unit_fail_closed_composition_source_test.dart`
- `features/access_profiles/presentation/access_profile_pages_test.dart`
- `features/agenda/agenda_router_test.dart`
- `features/safety/presentation/safety_pages_test.dart`
- `shared/presentation/widgets/superadmin_form_action_footer_adoption_test.dart`

# Golden (36)

Congeladas desde `d9232a94`, com uma excecao: `features/locations/location_read_panels_golden_test.dart`
moveu por correcao minha, declarada na revisao 44 — 0,146%, 96x14 pixels no rodape.

- `app/router/structure_detail_golden_test.dart`
- `features/access_profiles/presentation/access_profile_golden_test.dart`
- `features/account/presentation/screens/account_pages_golden_test.dart`
- `features/activities/presentation/activity_golden_test.dart`
- `features/agenda/presentation/agenda_additional_surfaces_golden_test.dart`
- `features/agenda/presentation/agenda_calendar_golden_test.dart`
- `features/attendance/attendance_pages_golden_test.dart`
- `features/audit/audit_directory_golden_test.dart`
- `features/auth/presentation/screens/superadmin_login_golden_test.dart`
- `features/chat/presentation/superadmin_chat_page_golden_test.dart`
- `features/circulars/presentation/circular_directory_golden_test.dart`
- `features/daily_routine/daily_routine_golden_test.dart`
- `features/forms/presentation/directory/forms_directory_golden_test.dart`
- `features/forms/presentation/editor/forms_editor_golden_test.dart`
- `features/forms/presentation/operations/forms_operations_golden_test.dart`
- `features/forms/presentation/response/form_response_golden_test.dart`
- `features/groups/presentation/group_golden_test.dart`
- `features/health_care/presentation/health_care_golden_test.dart`
- `features/help_center/presentation/screens/superadmin_help_center_page_golden_test.dart`
- `features/imports/import_hub_golden_test.dart`
- `features/institutions/presentation/screens/institution_directory_page_golden_test.dart`
- `features/institutions/presentation/screens/institution_form_page_golden_test.dart`
- `features/invites/invite_golden_test.dart`
- `features/locations/location_read_panels_golden_test.dart`
- `features/meal_plans/presentation/meal_plan_pages_golden_test.dart`
- `features/notices/notice_directory_golden_test.dart`
- `features/notices/notice_form_golden_test.dart`
- `features/people/presentation/person_golden_test.dart`
- `features/plans/plan_golden_test.dart`
- `features/platform_users/presentation/platform_user_directory_page_golden_test.dart`
- `features/platform_users/presentation/platform_user_pages_golden_test.dart`
- `features/principal_happens/presentation/principal_happens_preview_golden_test.dart`
- `features/principal_moments/presentation/principal_moments_preview_golden_test.dart`
- `features/principal_profile/presentation/principal_profile_preview_golden_test.dart`
- `features/support/presentation/screens/support_page_golden_test.dart`
- `features/units/presentation/unit_golden_test.dart`
