---
title: "R02 D03 — evidência focal de Rotina diária"
source: "apps/superadmin/lib/features/daily_routine/presentation/routine_directory_controller.dart; teste focal executado em 2026-09-09"
status: "local-green; awaiting-parent-review"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# `daily-routine.list` — erro inesperado no diretório

Base: `56eb3f19de23e364ea5f7e4f73a6fbd9a851e230` na branch
`codex/e2-r02-d03-acompanhamento`.

O RED reproduziu um erro de decodificação que é `Error`, fora do `on Exception`
do controller. Comando:

```text
rtk flutter test test/features/daily_routine/routine_directory_controller_test.dart --plain-name "unexpected decoding errors become a safe failure state"
```

Resultado antes da correção: `0 PASS / 1 FAIL`, exit code 1, com
`type 'String' is not a subtype of type 'RoutineDirectoryPage' in type cast`.
O transcript existe apenas na sessão Codex; nenhum arquivo de log externo foi
criado antes da execução.

Correção mínima: o catch externo de `RoutineDirectoryController.load` passou de
`on Exception` para `on Object`, preservando o mapeamento específico das falhas
de repository, o descarte de respostas antigas e a ausência de dados no estado
de falha.

Verificação após a correção:

```text
rtk flutter test test/features/daily_routine/routine_directory_controller_test.dart
```

Resultado: `11 PASS / 0 FAIL`, exit code 0. Inclui o caso novo
`unexpected decoding errors become a safe failure state`.

```text
rtk flutter analyze lib/features/daily_routine/presentation/routine_directory_controller.dart test/features/daily_routine/routine_directory_controller_test.dart
```

Resultado: `No issues found`, exit code 0. `dart format --output=none
--set-exit-if-changed` alterou zero arquivos e `git diff --check` ficou limpo.

O adapter Supabase não foi criado: os endpoints históricos pertencem ao realm
people based removido, `READ01` permanece proposta e o catálogo remoto
SELECT-only não contém RPC pública de Rotina diária. O estado produtivo
`UnavailableRoutineRepository` continua correto até contrato interno 039 e
pacote nominal aprovados. Nenhum backend, composição comum ou remoto foi
alterado; FE completo, BE e E2E permanecem abertos.
