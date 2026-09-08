---
title: "Avaliações — classificação do erro interno"
source: "packages/coelo_database/migrations/20260901182838_superadmin_assessments_internal_v2.sql"
status: "local-green; integração E2E aberta"
generated_at: "2026-09-07"
---

O adapter classificava todo prefixo SAI_ (exceto conflito) como unauthorized.
O contrato assessment_v2_error define SAI_INTERNAL_ERROR como 500. Um teste RED
confirmou a classificação incorreta; a correção usa os sete códigos nominais de
autorização, preservando status 401/403 e concorrência. Erro interno ou código
desconhecido continua sem dados, agora no estado operacional Offline existente.

Doze testes de repository e controller passaram. Matriz cobre erro interno,
desconhecido, sete negativas sem depender do status e conflito. Analyzer limpo;
review independente read-only sem achados. Não houve mudança visual, flag,
router, SQL ou execução remota. Memória no-op: aplica contrato canônico existente.

Comando: flutter test --no-pub test/features/assessments/data
test/features/assessments/assessment_controller_test.dart (cwd apps/superadmin).

Gate E2E: a composição injeta o adapter, mas enableAssessmentMutations mantém
rotas sensíveis bloqueadas por padrão. Não habilitado neste pacote. Persistência,
reload, autorização real e promoção de action_id permanecem sem prova nesta frente.
