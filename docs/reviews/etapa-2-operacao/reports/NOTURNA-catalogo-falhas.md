---
title: "Catalogo das 182 falhas da base integrada"
source: "Coordenacao e Integracao — Claude; flutter test --reporter=json em apps/superadmin"
status: "active"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Catalogo das falhas na base integrada

Medido em 09/09/2026 as 20:40, sobre `dev` em `414b82b29`, com
`flutter test --reporter=json` em `apps/superadmin`. O relatorio compacto da
mesma arvore reportou 5871 PASS, 9 SKIP e 182 FAIL; o relatorio JSON conta
6559 PASS, 9 SKIP e as MESMAS 182 falhas. Os dois reporters divergem no total de
casos que passam e concordam no que falha, entao o catalogo abaixo usa o JSON.

Na base anterior `ecc8eae2b` eram 190 falhas. A rodada **reduziu 8** e somou
casos que passam.

A grande maioria e suite de golden. Falha de golden na base **nao e regressao da
frente que a encontrar**: o censo mediu 151 falhas de golden sobre `d784462c1`,
antes de qualquer lote desta rodada.

## Distribuicao por dono

### acessos-pessoas — 18 falhas

| Casos | Arquivo |
| ---: | --- |
| 5 | `test/features/invites/invite_golden_test.dart` |
| 3 | `test/features/access_profiles/presentation/access_profile_golden_test.dart` |
| 2 | `test/features/people/presentation/person_golden_test.dart` |
| 2 | `test/features/platform_users/presentation/platform_user_directory_page_golden_test.dart` |
| 2 | `test/features/platform_users/presentation/platform_user_pages_golden_test.dart` |
| 1 | `test/app/router/people_creation_requirements_red_test.dart` |
| 1 | `test/app/router/people_routes_test.dart` |
| 1 | `test/app/router/person_detail_golden_test.dart` |
| 1 | `test/app/router/safety_routes_test.dart` |

### chat-comunicacoes — 12 falhas

| Casos | Arquivo |
| ---: | --- |
| 9 | `test/features/chat/presentation/superadmin_chat_page_golden_test.dart` |
| 2 | `test/features/notices/notice_directory_golden_test.dart` |
| 1 | `test/features/notices/notice_form_golden_test.dart` |

### coordenacao — 8 falhas

| Casos | Arquivo |
| ---: | --- |
| 2 | `test/core/config/composition_root_sanitization_test.dart` |
| 2 | `test/shared/presentation/widgets/superadmin_form_action_footer_adoption_test.dart` |
| 1 | `test/app/router/composition_root_fail_closed_routes_test.dart` |
| 1 | `test/app/router/development_fixture_composition_test.dart` |
| 1 | `test/app/router/import_development_routes_test.dart` |
| 1 | `test/app/router/prototype_navigation_routes_test.dart` |

### estrutura — 47 falhas

| Casos | Arquivo |
| ---: | --- |
| 9 | `test/features/activities/presentation/activity_golden_test.dart` |
| 8 | `test/features/groups/presentation/group_golden_test.dart` |
| 6 | `test/app/router/institution_directory_routes_test.dart` |
| 6 | `test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart` |
| 4 | `test/features/institutions/presentation/screens/institution_form_page_test.dart` |
| 3 | `test/features/locations/location_read_panels_golden_test.dart` |
| 2 | `test/app/router/unit_routes_test.dart` |
| 2 | `test/core/config/unit_fail_closed_composition_source_test.dart` |
| 2 | `test/features/institutions/presentation/screens/institution_form_page_golden_test.dart` |
| 2 | `test/features/units/presentation/unit_golden_test.dart` |
| 1 | `test/app/router/activity_routes_test.dart` |
| 1 | `test/app/router/assessment_routes_test.dart` |
| 1 | `test/features/groups/presentation/group_form_page_test.dart` |

### formularios-cuidado — 15 falhas

| Casos | Arquivo |
| ---: | --- |
| 4 | `test/features/health_care/presentation/health_care_golden_test.dart` |
| 3 | `test/features/forms/presentation/directory/forms_directory_golden_test.dart` |
| 3 | `test/features/forms/presentation/editor/forms_editor_golden_test.dart` |
| 2 | `test/app/router/forms_composition_sanitization_source_test.dart` |
| 1 | `test/features/forms/presentation/editor/forms_editor_page_test.dart` |
| 1 | `test/features/forms/presentation/operations/forms_operations_golden_test.dart` |
| 1 | `test/features/forms/presentation/response/form_response_golden_test.dart` |

### operacoes-sistema — 46 falhas

| Casos | Arquivo |
| ---: | --- |
| 14 | `test/features/agenda/presentation/agenda_calendar_golden_test.dart` |
| 8 | `test/features/account/presentation/screens/account_pages_golden_test.dart` |
| 6 | `test/features/agenda/presentation/agenda_additional_surfaces_golden_test.dart` |
| 6 | `test/features/meal_plans/presentation/meal_plan_pages_golden_test.dart` |
| 3 | `test/features/imports/import_hub_golden_test.dart` |
| 2 | `test/features/audit/audit_directory_golden_test.dart` |
| 1 | `test/app/dev_menu_overlay_test.dart` |
| 1 | `test/app/dev_menu_test.dart` |
| 1 | `test/app/dev_menu/development_dataset_contract_test.dart` |
| 1 | `test/app/router/meal_plan_production_routes_test.dart` |
| 1 | `test/features/help_center/presentation/screens/superadmin_help_center_page_golden_test.dart` |
| 1 | `test/features/plans/plan_golden_test.dart` |
| 1 | `test/features/support/presentation/screens/support_page_golden_test.dart` |

### perfil-para-voce — 10 falhas

| Casos | Arquivo |
| ---: | --- |
| 10 | `test/features/principal_profile/presentation/principal_profile_preview_golden_test.dart` |

### publicacoes-midia — 26 falhas

| Casos | Arquivo |
| ---: | --- |
| 11 | `test/features/principal_moments/presentation/principal_moments_preview_golden_test.dart` |
| 10 | `test/features/principal_happens/presentation/principal_happens_preview_golden_test.dart` |
| 3 | `test/app/router/principal_real_route_test.dart` |
| 2 | `test/features/circulars/presentation/circular_directory_golden_test.dart` |

## Como ler

O roteamento acima e por caminho de arquivo e serve para dirigir atencao, nao
para atribuir culpa. Varias dessas falhas sao deriva de referencia visual
herdada e dependem da decisao de rebaseline do Owner; outras sao contratos
verdes e deliberados que so mudam por decisao de produto. Antes de mexer em
qualquer uma, confirme a causa na propria base.
