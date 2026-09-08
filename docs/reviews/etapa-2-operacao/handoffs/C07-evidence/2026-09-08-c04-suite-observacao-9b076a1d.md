---
title: "C07 — observação da suíte de Estruturas e pessoas no HEAD C04 9b076a1d (checkout destacado, não certifica)"
source: "flutter test em checkout destacado somente-leitura C:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c07-c04ro (9b076a1d); log minimizado no scratchpad da sessão"
status: "evidence-observation"
generated_at: "2026-09-08T18:01:05-03:00"
timezone: "America/Sao_Paulo"
---

# Observação — suíte C04 no SHA 9b076a1d

- SHA observado: 9b076a1d (HEAD de `claude/e2-r01-c04-estruturas` no corte 17:43); checkout destacado fora do baseline C07, sem cherry-pick/merge. Não certifica FE/BE/E2E e não substitui o snapshot nominal da C00.
- Ambiente: Windows 11, Flutter 3.44.2 / Dart 3.12.2, sem backend, sem /dev; início 17:54:56 / fim 17:59:47; duração 4m17s; exit=1
- Resultado: 1084 passaram / 21 falharam (21 testWidgets; 88 comparações de golden falharam porque vários testes percorrem mais de um golden)

## Comando

```
cd apps/superadmin
flutter test test/features/institutions test/features/units test/features/groups test/features/people test/features/children test/features/student_tracking test/features/locations test/app/router/structure_detail_golden_test.dart test/app/router/person_detail_golden_test.dart --reporter expanded
```

## Testes que falharam (21)

- test/features/groups/presentation/group_golden_test.dart: matches a hovered table row
- test/features/groups/presentation/group_golden_test.dart: matches card hover and selected filter references
- test/features/groups/presentation/group_golden_test.dart: matches critical create mobile and edit desktop forms
- test/features/groups/presentation/group_golden_test.dart: matches hover and focus for create actions
- test/features/groups/presentation/group_golden_test.dart: matches shell overlays integrated with the group directory
- test/features/groups/presentation/group_golden_test.dart: matches the group directory cards and table at supported widths and themes
- test/features/groups/presentation/group_golden_test.dart: matches the open page-size selector reference
- test/features/groups/presentation/group_golden_test.dart: matches the searchable institution filter flyout
- test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart: matches approved interactive directory state references
- test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart: matches disabled pagination references
- test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart: matches hover, focus, and selected filter references
- test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart: matches loading, empty, failure, and unauthorized references
- test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart: matches the collapsed navigation flyout reference
- test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart: matches the institution directory cards and table references
- test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart: matches the no-results reference
- test/features/institutions/presentation/screens/institution_form_page_golden_test.dart: matches critical create and edit form references
- test/features/institutions/presentation/screens/institution_form_page_golden_test.dart: matches the contained institution bio reference
- test/features/people/presentation/person_golden_test.dart: matches critical create mobile and edit desktop forms
- test/features/people/presentation/person_golden_test.dart: matches people cards light and table dark at supported widths
- test/features/units/presentation/unit_golden_test.dart: matches critical create mobile and edit desktop forms
- test/features/units/presentation/unit_golden_test.dart: matches the unit directory at the supported widths and themes

## Goldens divergentes (88)

```
Golden "../../../goldens/groups/group_directory_bug_open_light_1440.png": Pixel test failed, 6.54%
Golden "../../../goldens/groups/group_directory_cards_dark_1024.png": Pixel test failed, 7.44%
Golden "../../../goldens/groups/group_directory_cards_dark_1440.png": Pixel test failed, 7.87%
Golden "../../../goldens/groups/group_directory_cards_dark_375.png": Pixel test failed, 17.37%
Golden "../../../goldens/groups/group_directory_cards_dark_768.png": Pixel test failed, 17.09%
Golden "../../../goldens/groups/group_directory_cards_light_1024.png": Pixel test failed, 7.62%
Golden "../../../goldens/groups/group_directory_cards_light_1440.png": Pixel test failed, 8.07%
Golden "../../../goldens/groups/group_directory_cards_light_375.png": Pixel test failed, 14.05%
Golden "../../../goldens/groups/group_directory_cards_light_768.png": Pixel test failed, 16.20%
Golden "../../../goldens/groups/group_directory_table_dark_1024.png": Pixel test failed, 1.60%
Golden "../../../goldens/groups/group_directory_table_dark_1440.png": Pixel test failed, 2.85%
Golden "../../../goldens/groups/group_directory_table_dark_375.png": Pixel test failed, 24.17%
Golden "../../../goldens/groups/group_directory_table_dark_768.png": Pixel test failed, 20.14%
Golden "../../../goldens/groups/group_directory_table_light_1024.png": Pixel test failed, 1.67%
Golden "../../../goldens/groups/group_directory_table_light_1440.png": Pixel test failed, 2.88%
Golden "../../../goldens/groups/group_directory_table_light_375.png": Pixel test failed, 21.02%
Golden "../../../goldens/groups/group_directory_table_light_768.png": Pixel test failed, 19.21%
Golden "../../../goldens/groups/group_directory_tour_open_light_1440.png": Pixel test failed, 7.54%
Golden "../../../goldens/groups/group_form_create_light_375.png": Pixel test failed, 18.57%
Golden "../../../goldens/people/person_directory_cards_light_1024.png": Pixel test failed, 19.87%
Golden "../../../goldens/people/person_directory_cards_light_1440.png": Pixel test failed, 16.83%
Golden "../../../goldens/people/person_directory_cards_light_375.png": Pixel test failed, 90.00%
Golden "../../../goldens/people/person_directory_cards_light_768.png": Pixel test failed, 74.11%
Golden "../../../goldens/people/person_directory_table_dark_1024.png": Pixel test failed, 25.52%
Golden "../../../goldens/people/person_directory_table_dark_1440.png": Pixel test failed, 23.99%
Golden "../../../goldens/people/person_directory_table_dark_375.png": Pixel test failed, 83.92%
Golden "../../../goldens/people/person_directory_table_dark_768.png": Pixel test failed, 68.87%
Golden "../../../goldens/people/person_form_create_light_375.png": Pixel test failed, 18.12%
Golden "../../../goldens/people/person_form_edit_dark_1440.png": Pixel test failed, 1.39%
Golden "goldens/institution_directory_card_hover_light_1440.png": Pixel test failed, 8.13%
Golden "goldens/institution_directory_cards_dark_1024.png": Pixel test failed, 7.35%
Golden "goldens/institution_directory_cards_dark_1440.png": Pixel test failed, 8.10%
Golden "goldens/institution_directory_cards_dark_375.png": Pixel test failed, 23.17%
Golden "goldens/institution_directory_cards_dark_768.png": Pixel test failed, 20.92%
Golden "goldens/institution_directory_cards_light_1024.png": Pixel test failed, 6.35%
Golden "goldens/institution_directory_cards_light_1440.png": Pixel test failed, 7.64%
Golden "goldens/institution_directory_cards_light_375.png": Pixel test failed, 20.42%
Golden "goldens/institution_directory_cards_light_768.png": Pixel test failed, 20.15%
Golden "goldens/institution_directory_empty_light_1440.png": Pixel test failed, 9.13%
Golden "goldens/institution_directory_failure_light_1440.png": Pixel test failed, 9.37%
Golden "goldens/institution_directory_files_hover_light_1440.png": Pixel test failed, 7.34%
Golden "goldens/institution_directory_filter_option_hover_light_1440.png": Pixel test failed, 6.62%
Golden "goldens/institution_directory_filter_selected_light_1440.png": Pixel test failed, 9.46%
Golden "goldens/institution_directory_loading_light_1440.png": Pixel test failed, 2.86%
Golden "goldens/institution_directory_logout_hover_light_1440.png": Pixel test failed, 7.41%
Golden "goldens/institution_directory_no_results_light_1440.png": Pixel test failed, 13.02%
Golden "goldens/institution_directory_pagination_disabled_light_1440.png": Pixel test failed, 3.67%
Golden "goldens/institution_directory_search_focus_light_1440.png": Pixel test failed, 7.64%
Golden "goldens/institution_directory_status_expanded_light_1440.png": Pixel test failed, 7.54%
Golden "goldens/institution_directory_status_tabs_light_1440.png": Pixel test failed, 4.55%
Golden "goldens/institution_directory_table_dark_1024.png": Pixel test failed, 20.40%
Golden "goldens/institution_directory_table_dark_1440.png": Pixel test failed, 22.53%
Golden "goldens/institution_directory_table_dark_375.png": Pixel test failed, 36.81%
Golden "goldens/institution_directory_table_dark_768.png": Pixel test failed, 23.43%
Golden "goldens/institution_directory_table_flyout_open_light_1440.png": Pixel test failed, 7.50%
Golden "goldens/institution_directory_table_light_1024.png": Pixel test failed, 18.42%
Golden "goldens/institution_directory_table_light_1440.png": Pixel test failed, 21.14%
Golden "goldens/institution_directory_table_light_375.png": Pixel test failed, 36.39%
Golden "goldens/institution_directory_table_light_768.png": Pixel test failed, 22.45%
Golden "goldens/institution_directory_table_row_hover_light_1440.png": Pixel test failed, 14.30%
Golden "goldens/institution_directory_unauthorized_light_1440.png": Pixel test failed, 4.13%
Golden "goldens/institution_form_bio_light_1440.png": Pixel test failed, 4.90%
Golden "goldens/institution_form_create_light_375.png": Pixel test failed, 26.08%
Golden "goldens/institution_form_edit_dark_1440.png": Pixel test failed, 7.23%
Golden "goldens/unit_directory_dark_1024.png": Pixel test failed, 12.96%
Golden "goldens/unit_directory_dark_1440.png": Pixel test failed, 10.45%
Golden "goldens/unit_directory_dark_375.png": Pixel test failed, 28.30%
Golden "goldens/unit_directory_dark_768.png": Pixel test failed, 22.57%
Golden "goldens/unit_directory_light_1024.png": Pixel test failed, 11.98%
Golden "goldens/unit_directory_light_1440.png": Pixel test failed, 9.70%
Golden "goldens/unit_directory_light_375.png": Pixel test failed, 25.59%
Golden "goldens/unit_directory_light_768.png": Pixel test failed, 21.69%
Golden "goldens/unit_directory_table_dark_1024.png": Pixel test failed, 21.91%
Golden "goldens/unit_directory_table_dark_1440.png": Pixel test failed, 19.91%
Golden "goldens/unit_directory_table_dark_375.png": Pixel test failed, 33.52%
Golden "goldens/unit_directory_table_dark_768.png": Pixel test failed, 26.82%
Golden "goldens/unit_directory_table_light_1024.png": Pixel test failed, 20.88%
Golden "goldens/unit_directory_table_light_1440.png": Pixel test failed, 18.91%
Golden "goldens/unit_directory_table_light_375.png": Pixel test failed, 32.26%
Golden "goldens/unit_directory_table_light_768.png": Pixel test failed, 25.96%
Golden "goldens/unit_form_create_light_375.png": Pixel test failed, 27.22%
Golden "goldens/unit_form_edit_dark_1440.png": Pixel test failed, 4.97%
```

Leitura preliminar, sem laudo: todas as falhas são comparação de pixel; nenhuma assertiva comportamental falhou. Instituições (baseline aprovada anexos 8–18), Unidades, Turmas e Pessoas divergem em bloco, com 20–36 % em 375 e 1,4–9 % em estados isolados de 1440, o que sugere causa compartilhada (shell/menu/rodapé) e não defeito por feature. Discriminação contra o baseline C07 7810e7c5 registrada no handoff.

## Discriminação contra o baseline C07 `7810e7c5` (mesmos cinco arquivos de golden)

- Janela: 18:00:52 → 18:01:22 na worktree C07 (branch `claude/e2-r01-c07-validacao-visual`, sem código C04); exit=1
- Resultado: 6 passaram / 20 falharam (`testWidgets`); 77 goldens divergentes
- 51 goldens divergem com **o mesmo percentual** no baseline e no HEAD C04 `9b076a1d` (Unidades, Turmas, Pessoas, formulário de Instituição): essas divergências **não nascem do lote C04**; a causa é anterior/compartilhada.
- Diretório de Instituições diverge nos dois, com percentuais **diferentes**: no baseline os diffs são maiores (ex.: cards_light_375 37,57 % vs 20,42 % no HEAD C04; table_dark_375 39,57 % vs 36,81 %). O lote C04 aproximou o diretório do master, sem alcançá-lo.
- Discriminação adicional contra o baseline R01 `479d1bd1` em execução; resultado no handoff.

```
# goldens divergentes no baseline 7810e7c5
Golden "../../../goldens/groups/group_directory_bug_open_light_1440.png": Pixel test failed, 6.54%
Golden "../../../goldens/groups/group_directory_cards_dark_1024.png": Pixel test failed, 7.44%
Golden "../../../goldens/groups/group_directory_cards_dark_1440.png": Pixel test failed, 7.87%
Golden "../../../goldens/groups/group_directory_cards_dark_375.png": Pixel test failed, 17.37%
Golden "../../../goldens/groups/group_directory_cards_dark_768.png": Pixel test failed, 17.09%
Golden "../../../goldens/groups/group_directory_cards_light_1024.png": Pixel test failed, 7.62%
Golden "../../../goldens/groups/group_directory_cards_light_1440.png": Pixel test failed, 8.07%
Golden "../../../goldens/groups/group_directory_cards_light_375.png": Pixel test failed, 14.05%
Golden "../../../goldens/groups/group_directory_cards_light_768.png": Pixel test failed, 16.20%
Golden "../../../goldens/groups/group_directory_table_dark_1024.png": Pixel test failed, 1.60%
Golden "../../../goldens/groups/group_directory_table_dark_1440.png": Pixel test failed, 2.85%
Golden "../../../goldens/groups/group_directory_table_dark_375.png": Pixel test failed, 24.17%
Golden "../../../goldens/groups/group_directory_table_dark_768.png": Pixel test failed, 20.14%
Golden "../../../goldens/groups/group_directory_table_light_1024.png": Pixel test failed, 1.67%
Golden "../../../goldens/groups/group_directory_table_light_1440.png": Pixel test failed, 2.88%
Golden "../../../goldens/groups/group_directory_table_light_375.png": Pixel test failed, 21.02%
Golden "../../../goldens/groups/group_directory_table_light_768.png": Pixel test failed, 19.21%
Golden "../../../goldens/groups/group_directory_tour_open_light_1440.png": Pixel test failed, 7.54%
Golden "../../../goldens/groups/group_form_create_light_375.png": Pixel test failed, 18.57%
Golden "../../../goldens/people/person_directory_cards_light_1024.png": Pixel test failed, 19.87%
Golden "../../../goldens/people/person_directory_cards_light_1440.png": Pixel test failed, 16.83%
Golden "../../../goldens/people/person_directory_cards_light_375.png": Pixel test failed, 90.00%
Golden "../../../goldens/people/person_directory_cards_light_768.png": Pixel test failed, 74.11%
Golden "../../../goldens/people/person_directory_table_dark_1024.png": Pixel test failed, 25.52%
Golden "../../../goldens/people/person_directory_table_dark_1440.png": Pixel test failed, 23.99%
Golden "../../../goldens/people/person_directory_table_dark_375.png": Pixel test failed, 83.92%
Golden "../../../goldens/people/person_directory_table_dark_768.png": Pixel test failed, 68.87%
Golden "../../../goldens/people/person_form_create_light_375.png": Pixel test failed, 18.12%
Golden "../../../goldens/people/person_form_edit_dark_1440.png": Pixel test failed, 1.39%
Golden "goldens/institution_directory_card_hover_light_1440.png": Pixel test failed, 14.62%
Golden "goldens/institution_directory_cards_dark_1024.png": Pixel test failed, 15.68%
Golden "goldens/institution_directory_cards_dark_1440.png": Pixel test failed, 14.50%
Golden "goldens/institution_directory_cards_dark_375.png": Pixel test failed, 40.18%
Golden "goldens/institution_directory_cards_dark_768.png": Pixel test failed, 29.46%
Golden "goldens/institution_directory_cards_light_1024.png": Pixel test failed, 14.87%
Golden "goldens/institution_directory_cards_light_1440.png": Pixel test failed, 14.13%
Golden "goldens/institution_directory_cards_light_375.png": Pixel test failed, 37.57%
Golden "goldens/institution_directory_cards_light_768.png": Pixel test failed, 28.89%
Golden "goldens/institution_directory_empty_light_1440.png": Pixel test failed, 3.46%
Golden "goldens/institution_directory_failure_light_1440.png": Pixel test failed, 3.68%
Golden "goldens/institution_directory_filter_selected_light_1440.png": Pixel test failed, 15.16%
Golden "goldens/institution_directory_loading_light_1440.png": Pixel test failed, 2.87%
Golden "goldens/institution_directory_no_results_light_1440.png": Pixel test failed, 7.35%
Golden "goldens/institution_directory_pagination_disabled_light_1440.png": Pixel test failed, 9.47%
Golden "goldens/institution_directory_search_focus_light_1440.png": Pixel test failed, 14.13%
Golden "goldens/institution_directory_status_tabs_light_1440.png": Pixel test failed, 11.21%
Golden "goldens/institution_directory_table_dark_1024.png": Pixel test failed, 22.49%
Golden "goldens/institution_directory_table_dark_1440.png": Pixel test failed, 22.54%
Golden "goldens/institution_directory_table_dark_375.png": Pixel test failed, 39.57%
Golden "goldens/institution_directory_table_dark_768.png": Pixel test failed, 29.84%
Golden "goldens/institution_directory_table_flyout_open_light_1440.png": Pixel test failed, 13.95%
Golden "goldens/institution_directory_table_light_1024.png": Pixel test failed, 20.14%
Golden "goldens/institution_directory_table_light_1440.png": Pixel test failed, 21.14%
Golden "goldens/institution_directory_table_light_375.png": Pixel test failed, 35.53%
Golden "goldens/institution_directory_table_light_768.png": Pixel test failed, 27.61%
Golden "goldens/institution_directory_unauthorized_light_1440.png": Pixel test failed, 4.15%
Golden "goldens/institution_form_bio_light_1440.png": Pixel test failed, 4.90%
Golden "goldens/institution_form_create_light_375.png": Pixel test failed, 26.08%
Golden "goldens/institution_form_edit_dark_1440.png": Pixel test failed, 7.23%
Golden "goldens/unit_directory_dark_1024.png": Pixel test failed, 12.96%
Golden "goldens/unit_directory_dark_1440.png": Pixel test failed, 10.45%
Golden "goldens/unit_directory_dark_375.png": Pixel test failed, 28.30%
Golden "goldens/unit_directory_dark_768.png": Pixel test failed, 22.57%
Golden "goldens/unit_directory_light_1024.png": Pixel test failed, 11.98%
Golden "goldens/unit_directory_light_1440.png": Pixel test failed, 9.70%
Golden "goldens/unit_directory_light_375.png": Pixel test failed, 25.59%
Golden "goldens/unit_directory_light_768.png": Pixel test failed, 21.69%
Golden "goldens/unit_directory_table_dark_1024.png": Pixel test failed, 21.91%
Golden "goldens/unit_directory_table_dark_1440.png": Pixel test failed, 19.91%
Golden "goldens/unit_directory_table_dark_375.png": Pixel test failed, 33.52%
Golden "goldens/unit_directory_table_dark_768.png": Pixel test failed, 26.82%
Golden "goldens/unit_directory_table_light_1024.png": Pixel test failed, 20.88%
Golden "goldens/unit_directory_table_light_1440.png": Pixel test failed, 18.91%
Golden "goldens/unit_directory_table_light_375.png": Pixel test failed, 32.26%
Golden "goldens/unit_directory_table_light_768.png": Pixel test failed, 25.96%
Golden "goldens/unit_form_create_light_375.png": Pixel test failed, 27.22%
Golden "goldens/unit_form_edit_dark_1440.png": Pixel test failed, 4.97%
```

## Discriminação contra o baseline R01 `479d1bd1` (mesmos cinco arquivos, checkout destacado)

- Janela: 18:03:26 → 18:04:24; 6 passaram / 20 falharam; 77 goldens divergentes; exit=1
- Os 77 goldens e seus percentuais são **idênticos** aos do baseline C07 `7810e7c5`. Conclusão: as divergências de Instituições/Unidades/Turmas/Pessoas existem no baseline R01, antes de qualquer lote C04 ou C05.
- 51 dos 77 permanecem idênticos no HEAD C04 `9b076a1d`; os 26 restantes (diretório de Instituições) mudam de percentual no HEAD C04 (diffs menores), sem alcançar o master.
- Hipótese de causa (do laudo de Chat, a confirmar nominalmente em Estruturas): `d9232a94` (2026-09-01) alterou o app bar compacto e o `_PageHeader` do `SuperadminShell` sem regenerar os goldens das telas que renderizam o shell.
