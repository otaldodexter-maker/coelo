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

## Próximos gates por ação — leitura focal

Este mapa não certifica nenhuma ação pelos lotes `11/11` e `14/14`. Os cinco
IDs continuam `pending-verification` nas três camadas de `escopo.json`; o painel
R01 exige critérios próprios por ação, persistência/reload e negativas reais.

| Ação | Critério aberto e fonte | Código observado | Classificação / próximo gate |
| --- | --- | --- | --- |
| `daily-routine.list` | Diretório, estados, busca/filtros, paginação e matriz visual; `specs/021-superadmin-daily-routine-prototype.md` e painel R01 linhas 259–263. | `daily_routine_pages.dart` monta tabs, busca, estados e paginação; `routine_directory_controller.dart` descarta resposta antiga e falha fechado. Na rota normal, `superadmin_router.dart:1693` recebe repository indisponível e callbacks de criar/editar nulos. | Bugs focais de erro inesperado e recibo de página já foram corrigidos, sem concluir a ação. Próximo gate produtivo é reader interno 039, composição normal, autorização, reload e negativas. `READ01` (`bd946025`) é proposta e não pode ser promovida a contrato/migration. |
| `daily-routine.create` | Criar e validar modelo/rotina, mostrar falha e confirmar resultado após reload; spec 021 e painel R01 linha 260. | `_newEntry` cria modelo local ou aplicação somente a partir de modelo autorizado; `_saveModel` e `_saveApplication` validam o agregado antes do repository. | A validação representável no FE foi fechada no delta abaixo. Permanecem command interno 039, recibo idempotente, composição e reload reais. |
| `daily-routine.edit` | Editar/salvar/falhar/abandonar e texto 200%; painel R01 linha 261 e testes exigidos da spec 021. | O editor valida o agregado, tipo/ID carregado e recibo divergente. `daily_routine_golden_test.dart` pula dirty-exit porque a UI atual não possui cancelar/confirmar saída. | O comportamento de abandonar/dirty-exit exige reconciliação nominal: o painel cobra o critério, mas a referência visual atual o declara removido. Persistência, concorrência por versão, autorização e reload seguem no backend/E2E. |
| `daily-routine.apply` | Aplicar/cancelar/falhar e observar o resultado após reload; painel R01 linha 262. A spec 021 exige criar rotina a partir de modelo preservando campos/tipo/herança. | Cards de modelo expõem `onCreateFromModel`; `_newEntry` busca o modelo, confere o ID, cria `RoutineApplication` e o save valida o agregado. Isso só está conectado no `/dev`; a rota normal não fornece callback e o repository é indisponível. | Cancelamento e navegação normal precisam de decisão de UX/reserva de router; aplicação produtiva exige comando interno 039, escopo/hierarquia, receipt e reload. |
| `daily-routine.publish` | Publicar/cancelar/falhar/repetir e reload; painel R01 linha 263. A projeção de conhecimento validada exige versão imutável, autorização server-side e bloqueio por obrigatórios pendentes. | `RoutineCommandRepository` declara `saveLaunchDraft`, `publishLaunch` e `correctLaunch`; `RoutineLaunch` existe. A tela `_launchView` é somente leitura e não há ação no footer. Apenas `DevelopmentRoutineRepository` implementa transições locais. | Não há correção segura isolada sem definir se este ID publica modelo, aplicação ou lançamento e sem contrato interno de transição/capability/AAL/auditoria. A antiga spec 025 foi removida em `f71b6a9c`; serve como proveniência histórica, não como autorização para restaurar implementação. Próximo gate é decisão nominal + contrato backend interno 039; depois UI, retry idempotente, reload e negativas. |

Dependências exauridas para adapter/composição produtivos: o catálogo remoto
SELECT-only não possui RPC pública `superadmin_routine_%` nem
`superadmin_daily_routine_%`; `superadmin_auth_scope.dart:360` injeta
`UnavailableRoutineRepository`. Não existe DTO aprovado do reader/commands
internos. Restaurar a cadeia people-based removida ou construir bridge de
identidade violaria o gate registrado.

## Validação de aplicação antes do comando

O gate FE executável identificado no mapa foi fechado localmente sem promover
`daily-routine.create`, `edit` ou `apply`. O RED comprovou que validade invertida
e horário inicial inválido chegavam a `saveApplication`: `0 PASS / 2 FAIL`, log
`C:/Users/adrie/AppData/Local/Temp/coelo-d03-daily-routine-application-validation-red.log`.

`_saveApplication` agora constrói o draft dentro do tratamento seguro, preserva
a checagem de contexto já existente e chama `RoutineApplication.validate()`
antes de ativar o estado de salvamento ou invocar o repository. Os dois casos
exigem a mensagem já definida pelo domínio, zero chamada e valores preservados.

Verificação focal: `2 PASS / 0 FAIL`, log
`C:/Users/adrie/AppData/Local/Temp/coelo-d03-daily-routine-application-validation-green.log`.
Arquivo completo: `16 PASS / 0 FAIL`, log
`C:/Users/adrie/AppData/Local/Temp/coelo-d03-daily-routine-application-validation-full.log`.
Analyzer dos dois arquivos: `No issues found`, log
`C:/Users/adrie/AppData/Local/Temp/coelo-d03-daily-routine-application-validation-analyze.log`.
Formatter alterou zero arquivos.

Primeiro gate restante: decidir/reconciliar `abandonar` versus dirty-exit
removido no FE, ou aprovar o contrato interno 039 para reader/commands e então
compor as rotas normais. `daily-routine.publish` continua dependente de decisão
nominal sobre o agregado/transição e do contrato de autorização/auditoria. O
segundo callsite da validação é tratado abaixo.

### Segundo callsite: alteração da herança

`_saveApplicationMode` também persistia o draft inteiro sem validação e o
construía fora do tratamento de falhas. O RED editou o horário para `08:7` e
alternou a herança: `0 PASS / 1 FAIL`, log
`C:/Users/adrie/AppData/Local/Temp/coelo-d03-daily-routine-inheritance-validation-red.log`.

O callsite agora constrói e valida o mesmo `RoutineApplication` dentro do
`try`, antes do repository. O focal material incluiu o sucesso já existente da
troca de modo e o novo negativo: `2 PASS / 0 FAIL`, log
`C:/Users/adrie/AppData/Local/Temp/coelo-d03-daily-routine-inheritance-validation-green.log`.
O negativo exige mensagem segura existente, nenhuma chamada ao repository e
preservação do valor digitado. Analyzer dos dois arquivos: `No issues found`,
log
`C:/Users/adrie/AppData/Local/Temp/coelo-d03-daily-routine-inheritance-validation-analyze.log`.
Não houve reexecução do lote de 16 casos, conforme corte focal definido.
Depois dos dois callsites, não há outro bug feature-local independente
comprovado neste corte.
