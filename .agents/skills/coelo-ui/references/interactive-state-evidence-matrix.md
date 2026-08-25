---
source: "Aprovações visuais do Owner Coelo; arbitragem visual de 2026-08-24; implementação, testes e goldens do Superadmin"
status: "active"
generated_at: "2026-08-04"
updated_at: "2026-08-24"
---

# Matriz de evidência dos estados interativos

Esta matriz é um gate anterior ao código. Para cada estado solicitado ou
alcançável no controle implementado, abrir a
implementação real, o componente reutilizável, o teste comportamental e a
evidência visual indicada. Um golden geral da página não substitui o golden do
estado. Se a evidência do estado estiver ausente, parar e propor a referência;
não completar a lacuna com Material default, memória ou aproximação.

## Instituições: baseline de diretórios

| Estado | Implementação real | Componente/contrato | Teste | Evidência visual canônica |
| --- | --- | --- | --- | --- |
| Cards default e responsivos | `institution_directory_cards.dart` | `CoeloAdminInteractiveCard` | `institution_directory_page_test.dart`; `coelo_admin_interactive_card_test.dart` | `institution_directory_cards_{light,dark}_{375,768,1024,1440}.png` |
| Card hover | `institution_directory_cards.dart` | `pattern.interaction-states` | `coelo_admin_interactive_card_test.dart` | `institution_directory_card_hover_light_1440.png` |
| Status compacto/expandido | `institution_status_presentation.dart` | `CoeloAdminExpandableStatusIndicator` | `coelo_admin_expandable_status_indicator_test.dart` | `institution_directory_status_expanded_light_1440.png` |
| Filtros fechados | `institution_directory_toolbar.dart` | `pattern.selection-controls` | `institution_directory_page_test.dart` | goldens base de cards |
| Opção de filtro hover | `institution_directory_toolbar.dart` | `pattern.interaction-states` | `institution_directory_page_test.dart` | `institution_directory_filter_option_hover_light_1440.png` |
| Seleção em rascunho | `institution_directory_toolbar.dart` | `pattern.selection-controls` | `institution_directory_page_test.dart` | `institution_directory_filter_selected_light_1440.png` |
| Arquivos aberto/hover | `institution_file_actions.dart` | `CoeloAdminFileActions`; `CoeloAdminFlyout` | `institution_file_actions_test.dart`; `coelo_admin_file_actions_test.dart` | `institution_directory_files_hover_light_1440.png` |
| Toggle Cards/Tabela | `institution_directory_toolbar.dart`; `superadmin_directory_view_toggle.dart` | `pattern.admin-directory` | `superadmin_directory_view_toggle_test.dart` | goldens base de cards e tabela |
| Tabs de status | `institution_directory_page.dart` | `SuperadminUnderlineTabs`; `pattern.directory-linear-tabs` | `institution_directory_page_test.dart` | `institution_directory_status_tabs_light_1440.png` |
| Flyout de visões aberto | `superadmin_directory_view_toggle.dart` | `CoeloAdminFlyout`; `pattern.flyout-actions` | `superadmin_directory_view_toggle_test.dart` | `institution_directory_table_flyout_open_light_1440.png` |
| Tabela default/responsiva | `institution_directory_table.dart` | `CoeloAdminResizableTable` | `coelo_admin_resizable_table_test.dart` | `institution_directory_table_{light,dark}_{375,768,1024,1440}.png` |
| Linha de tabela hover | `institution_directory_table.dart` | `pattern.interaction-states` | `coelo_admin_resizable_table_test.dart` | `institution_directory_table_row_hover_light_1440.png` |
| Paginação disabled/menu aberto | `institution_directory_pagination.dart`; `superadmin_listing_pagination_footer.dart` | `CoeloAdminPagination` | `coelo_admin_pagination_test.dart` | `institution_directory_pagination_disabled_light_1440.png`; `institution_directory_pagination_page_size_open_light_1440.png` |

Todos os goldens desta seção ficam em
`apps/superadmin/test/features/institutions/presentation/screens/goldens/` e
são gerados por `institution_directory_page_golden_test.dart`.

## Menu, flyouts e ações negativas

| Estado | Implementação real | Componente/contrato | Teste | Evidência visual canônica |
| --- | --- | --- | --- | --- |
| Menu atual dentro do produto | `app/shell/superadmin_shell.dart` | `pattern.flyout-actions` | `superadmin_shell_test.dart` | goldens atuais de Instituições e Criar/Editar Instituição |
| Rail colapsado + Acessos hover | `superadmin_shell.dart` | `pattern.flyout-actions` | `superadmin_shell_test.dart` | `institution_directory_collapsed_flyout_hover_light_1024.png` |
| Tour aberto | `superadmin_shell.dart` | `pattern.flyout-actions` | `superadmin_shell_test.dart` | `apps/superadmin/test/goldens/activities/activity_directory_tour_open_light_1440.png` |
| Conta aberta | `superadmin_shell.dart` | `pattern.flyout-actions` | `superadmin_shell_test.dart` | `apps/superadmin/test/goldens/activities/activity_directory_profile_open_light_1440.png` |
| Sair negativo em hover | `superadmin_shell.dart` | `pattern.negative-actions` | `superadmin_shell_test.dart` | `institution_directory_logout_hover_light_1440.png` |
| Popup de Bug aberto | `app/shell/superadmin_bug_report_dialog.dart` | `CoeloAdminDialogShell`; `pattern.overlay-surfaces` | `superadmin_shell_test.dart` | `apps/superadmin/test/goldens/activities/activity_directory_bug_open_light_1440.png` |

## Criar e editar

| Estado | Implementação real | Componentes | Teste | Evidência visual canônica |
| --- | --- | --- | --- | --- |
| Criar compacto light | `institution_form_page.dart`; navegação e seções | `CoeloFormTextField`; `CoeloAdminSingleSelectField`; `SuperadminFormActionFooter` | `institution_form_page_test.dart` | `institution_form_create_light_375.png` |
| Editar desktop dark com menu atual e chat | mesmos arquivos | mesmos componentes | `institution_form_page_test.dart` | `institution_form_edit_dark_1440.png` |
| Ajustar foto institucional | `institution_form_sections.dart` | `AvatarCropDialog`; `pattern.media-adjustment` | `institution_form_page_test.dart` | `institution_form_avatar_crop_open_light_1440.png` |

## Importações

| Estado | Implementação real | Componente/contrato | Teste | Evidência visual canônica |
| --- | --- | --- | --- | --- |
| Diálogo `Nova importação` aberto em 1440 light, com `X` preservado, uma única ação textual `Cancelar` negativa e sem ação textual `Fechar` | `_ImportDialog` em `import_directory_page.dart` | `CoeloAdminDialogShell`; `CoeloAdminInteractiveCard`; `pattern.negative-actions` | `import_hub_golden_test.dart` | `import_hub_new_dialog_light_1440.png`; `docs/design/coelo-ui-deep-review-confirmations-2026-08-06.md` |

## Lacunas controladas

Ausência de um golden específico não autoriza improvisação. Hover/foco dark,
menu em outros breakpoints e estados internos do popup de Bug permanecem
cobertos por contrato/teste, mas exigem aprovação e golden dedicado antes de
servir como nova referência visual.

Também existe dívida de convergência quando a implementação real ainda compõe
um controle local apesar de haver componente canônico. A matriz exige abrir os
dois e registrar a divergência; ela não autoriza refatorar telas fora do escopo.

## Hierarquia de superfície em mobile e tablet

Instagram e Airbnb são referências conceituais aprovadas para a limpeza da
arquitetura mobile: conteúdo sobre base clara, hierarquia por espaço, divisores
e superfícies locais. No tema claro de Superadmin, Admin e Principal, a base de
página mobile/tablet usa `colorScheme.surface`; cinza não é fundo-base padrão.
`surfaceContainer*` fica restrito a áreas secundárias com função explícita,
campos, estados, skeletons ou separação local. No tema escuro, usar os papéis
semânticos escuros do tema, sem branco literal. Isso não autoriza copiar marca,
cores, navegação ou componentes desses produtos.
