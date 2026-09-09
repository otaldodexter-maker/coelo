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

## `daily-routine.create` — recibo vazio de criação

Os fluxos de criação de modelo e rotina aplicada aceitavam o identificador
vazio ou composto apenas por espaços devolvido pelo repository. A interface
mostrava sucesso, mantinha a entidade sem identidade válida e permitia uma nova
criação no clique seguinte.

O RED cobriu os dois fluxos:

```text
rtk flutter test test/features/daily_routine/daily_routine_application_editor_test.dart --plain-name "rejects an empty id returned while creating"
```

Resultado antes da correção: `0 PASS / 2 FAIL`. O transcript foi salvo em
`C:/Users/adrie/AppData/Local/Temp/coelo-d03-daily-routine-empty-id-red.log`.

Correção mínima: ambos os saves agora rejeitam `id.trim().isEmpty` antes de
mostrar sucesso ou atualizar o estado local. O erro específico permanece no
tratamento existente de `FormatException`; nenhum formato adicional de ID foi
imposto ao contrato.

Verificação focal após a correção: `2 PASS / 0 FAIL`, com transcript em
`C:/Users/adrie/AppData/Local/Temp/coelo-d03-daily-routine-empty-id-green.log`.
Uma primeira tentativa intermediária falhou somente porque as expectativas
novas tinham sido gravadas com mojibake; as duas strings do fixture foram
corrigidas para o texto Unicode já emitido pela implementação.

Verificação serializada do arquivo completo:

```text
rtk flutter test test/features/daily_routine/daily_routine_application_editor_test.dart
```

Resultado: `14 PASS / 0 FAIL`, exit code 0. Transcript em
`C:/Users/adrie/AppData/Local/Temp/coelo-d03-daily-routine-application-editor-full-serialized.log`.
Uma execução anterior também passou `14/14`, mas coincidiu com o início de um
lote de Attendance e não foi usada como evidência nominal.

```text
rtk flutter analyze lib/features/daily_routine/daily_routine_form_sections.dart test/features/daily_routine/daily_routine_application_editor_test.dart
```

Resultado: `No issues found`, exit code 0. Transcript em
`C:/Users/adrie/AppData/Local/Temp/coelo-d03-daily-routine-empty-id-analyze.log`.
`dart format` alterou zero arquivos e `git diff --check` permaneceu limpo.
