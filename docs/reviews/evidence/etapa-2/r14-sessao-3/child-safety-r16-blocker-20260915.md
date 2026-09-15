---
status: blocked-r16
lifecycle: current
round: R14
session: 3
owner_items:
  - owner.r12-13
  - owner.r12-15
  - owner.r12-16
action_ids:
  - child-safety.create
  - child-safety.edit
  - child-safety.suspend
recorded_at: 2026-09-15T19:00:00-03:00
---

# Segurança infantil — retomada e transferência para R16

## Resultado verificado

- Não há reivindicação concorrente: Sessões 1 e 2 não mantêm a tela; o handoff
  da Sessão 3 a liberou explicitamente; o handoff da Sessão 4 declara este
  recorte fora do trabalho.
- FE local: `flutter test test/features/safety/application
  test/features/safety/data test/features/safety/domain
  test/features/safety/presentation/safety_pages_test.dart --exclude-tags golden
  test/app/router/safety_routes_test.dart test/app/router/safety_reflow_test.dart`
  executou 126 casos: 125 passaram e 1 falhou no golden
  `child_safety_directory_light_1440.png` (0,34%, 4.857 pixels). Essa falha é
  o Owner `owner.r12-10`, fora deste recorte; nenhum golden foi regenerado.
- BE local: o script oficial `Invoke-SafeLocalMigrationReplay.ps1`, com as
  suítes `child_safety_platform_decision_v1_test.sql` e
  `child_safety_production_test.sql`, não iniciou o replay porque a API Docker
  Linux (`dockerDesktopLinuxEngine`) está indisponível. Não houve SQL aplicado,
  fixture criado, alteração de ledger ou mudança remota.

## Bloqueio de rota/produção

O 504 de `child_safety_change_lifecycle` continua bloqueando a prova autenticada
de `child-safety.suspend` e a cadeia dependente de `edit`. O diário anterior
registra duas chamadas reais com 504; o espelho rebaselineado passou 25/25 e
63/63 e não reproduziu o timeout, portanto isso não certifica produção. Não há
causa raiz adicional comprovada e nenhum comportamento foi inventado.

A rota normal, persistência/reload, escopo/ownership/tenant negativo e E2E dos
três actions continuam não certificados: a sessão autenticada QA disponível
está em `127.0.0.1:3016/login`, mas não há sessão operável neste executor para
repetir a mutação. A origem 3016 também permanece fora da allowlist CORS já
registrada no handoff anterior.

## Transferência

Transferir para R16 os três actions e `owner.r12-13`, `owner.r12-15`,
`owner.r12-16`, condicionada a: Docker disponível para o replay oficial,
allowlist/contrato de origem corrigidos, sessão QA autenticada operável e nova
prova de create/edit/suspend pela rota normal com persistência, reload,
ownership/tenant negativo e auditoria. Não promover contadores R14.
