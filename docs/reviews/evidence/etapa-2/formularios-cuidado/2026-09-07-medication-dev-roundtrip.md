---
title: "MED-DEV01 — round-trip, contexto e replay local"
source: "reserva LOCAL do Coordenador; spec 020; contratos existentes; testes Flutter"
status: "local-green-partial"
generated_at: "2026-09-07"
---

# Contrato e reserva

Superadmin, Medicação, `medication.create` e `medication.edit`, exclusivamente
DEV em memória. Reserva compartilhada limitada aos helpers de router
`saveDevelopmentMedicationPlanDraft` e `developmentMedicationDraft`, import
necessário e consumo já existente. Não altera rotas produtivas, capabilities,
ações clínicas, Supabase, Cloudflare, schema ou migrations. Root único writer;
subagentes somente análise/revisão.

## Causas e implementação

- O save DEV reativava qualquer plano. Edição agora conserva status existente;
  criação conserva o default DEV anterior, sem estabelecer política clínica.
- Hidratação/save conservavam apenas o primeiro horário e descartavam contexto,
  timezone, instruções e detalhes da via. Snapshot imutável carrega esses valores;
  mapper DEV atualiza somente campos editáveis do primeiro horário, preserva
  frequência literalmente, metadados e horários seguintes.
- Criação resolve o filho no catálogo sintético existente. Edição exige snapshot
  correspondente a plano/criança e contexto conhecido; não inventa horários em
  registro lido com lista vazia. Contexto histórico do create pode ter planId
  nulo; lookup/hidratação conferem associação e criança.
- Snapshot de receipt vem do resultado e command da mesma chamada, nunca de
  lookup mutável após await. Defaults de criação confirmados só preenchem os
  controles ainda vazios, preservando escolhas posteriores.
- Falha de navegação sem edição repete apenas navegação. Nova edição gera nova
  intenção. Receipts obsoletos continuam ignorados; edições durante save/replay
  não são descartadas nem misturadas com campos capturados antes do await.

## Evidência

RED observado: três status reativados indevidamente; perda do segundo horário na
rota; dois retries após criação/defaults; dois casos de edição durante await.
O teste de rótulo institucional inicialmente presumiu vínculo visual dinâmico;
a leitura mostrou resolver placeholder fixo. Foi corrigido para verificar o
contexto realmente armazenado, sem alegar correção daquele rótulo.

Execução final de quatro arquivos:

```text
flutter test --no-pub
  test/features/health_care/data/dev/dev_medication_plan_form_mapper_test.dart
  test/features/health_care/data/dev/dev_medication_plan_repository_test.dart
  test/features/health_care/presentation/medication_plan_ui_contract_test.dart
  test/app/router/health_care_routes_test.dart
60/60 passaram; exit 0
```

São 13 testes do mapper, 11 de repository, 26 de contrato UI e 10 de rotas.
Os testes de rotas incluem tripwire produtivo e create/edit/reabertura DEV.
Analyzer focal em nove arquivos: sem problemas, exit 0. Validador visual
administrativo: exit 0. Diff check sem problemas.
Review independente aprovou MED-DEV01 após resolver o P2 de defaults/retry.

## Limites que permanecem

- Backend e E2E produtivos continuam `blocked-decision`; DEV não é autorização.
- Label institucional do diretório continua placeholder, embora o command
  conserve o contexto correto. Seletor da criança ainda reflete modo da rota
  após criação sem navegação; identidade divergente é rejeitada pelo mapper.
- Responsáveis não ganharam destino novo no command por inferência.
- Nenhuma semântica de frequência, aprovação, dose, retenção ou regra clínica
  foi criada. Nenhum dado real foi usado; nenhum BD/RPC/Worker/R2 foi executado.
- Goldens preexistentes de Saúde continuam pendentes conforme evidência
  `2026-09-07-medication-stale-receipts.md`; não alterados nesta fatia sem
  redesign. Sem alegação de visual ou E2E concluídos.

Coelo Knowledge: no-op, preservação dos contratos existentes sem nova decisão
durável. Nenhuma projeção de atividade criada. Deltas oficiais ao Coordenador.
