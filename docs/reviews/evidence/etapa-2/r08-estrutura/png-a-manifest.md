---
fonte: docs/reviews/etapa-2-operacao/next-round/R07-decisoes-owner-20260912.md
status: 45 PNGs A regravados e verificados
data: 2026-09-12
rodada: E2-R08-20260912
---

## Pré-checagem de arquivos

Em 12/09, a listagem local confirmou 31 PNGs em `test/goldens/activities`, os 12 nomes de detalhe de Unidade/Turma em `test/app/router/goldens` e os 2 nomes de paginação de Instituições no teste proprietário. Esta checagem só confirma a base dos arquivos; comparação e eventual regravação continuam dependentes da posse Flutter.

O `git ls-files -s` filtrado pelos nomes nominais também retornou exatamente 45 blobs rastreados. A comparação futura deve partir desta base e não deve incluir PNGs A+/R nem qualquer arquivo do frame de G3.

## Comparação e regravação

Em 12/09, os três testes proprietários falharam inicialmente somente nos 45 alvos A: 31 de Atividades, 12 de detalhe de Unidade/Turma e 2 de paginação de Instituições. As regravações usaram exclusivamente os três testes proprietários com `--update-goldens`. A repetição combinada sem atualização passou 20/20, em `--concurrency=1`. O `git diff --name-only` confirmou exatamente 45 PNGs modificados e nenhum A+/R ou arquivo do frame compartilhado.

# PNGs A nominais — Estrutura

P53=A autoriza a regravação, não dispensa comparação. A base contém os 45 alvos: 31 de Atividades, 12 de detalhe de Unidade/Turma e 2 de diretório de Instituições. Nenhum arquivo foi regravado nesta preparação, pois a fila global de `flutter test` ainda pertence a G3.

| Família | Alvos A | Teste proprietário |
| --- | ---: | --- |
| Atividades | 31 | `test/features/activities/presentation/activity_golden_test.dart` |
| Detalhe de Unidade/Turma | 12 | `test/app/router/structure_detail_golden_test.dart` (posse G1) |
| Diretório de Instituições | 2 | `test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart` |
| Total | 45 | — |

## Lista nominal conferida

- Atividades: `activity_detail_{dark_1440,light_375}`, `activity_directory_{bug_open,card_hover,filter_open,models,pagination_open,profile_open,table_row_hover,text_200,tour_open}_light_1440` (o estado `text_200` é `light_375`), os oito `cards_{light,dark}_{375,768,1024,1440}`, os oito `table_{light,dark}_{375,768,1024,1440}`, `activity_form_{create_light_375,edit_dark_1440,location_dialog_light_375,professionals_dark_1440}`.
- Detalhe: `unit_detail_{light_375,dark_1440}_{ready,focus,reload}` e `group_detail_{light_375,dark_1440}_{ready,focus,reload}`.
- Instituições: `institution_directory_{pagination_disabled,pagination_page_size_open}_light_1440`.

## Procedimento autorizado quando o slot for cedido

1. Rodar os três testes proprietários sem `--update-goldens` e registrar PASS/FAIL por alvo.
2. Inspecionar somente as diferenças dos 45 alvos aprovados; não alterar `superadmin_form_frame.dart`, que pertence à G3.
3. Regravar apenas os alvos A que diferirem, com `--update-goldens`, e repetir os mesmos testes.
4. Registrar hashes/resultado e separar qualquer falha não-A ou não relacionada como bloqueio, sem promover ação de CRUD por golden.
