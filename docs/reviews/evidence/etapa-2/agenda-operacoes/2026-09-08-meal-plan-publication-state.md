---
title: "Cardápios — confirmação honesta do estado publicado"
source: "20260820150000_meal_plans_tenant_conflict_hardening.sql; 20260820230000_meal_plan_media_lifecycle_receipts.sql; wizard e testes Flutter"
status: "local-green; backend e E2E abertos"
generated_at: "2026-09-08"
---

# Contrato e correção

A RPC legada `meal_plan_publish` atualiza `status=published`, `is_draft=false` e `requires_review=false`; o wrapper de receipts preserva o payload. A leitura de arquivos não substitui execução desse SQL.

O wizard conferia somente o ID retornado antes de chamar `onSaved`. Quatro negativos reproduziram sucesso indevido para o mesmo ID em draft, inReview ou published com flags incoerentes. Um controle positivo publicado coerente passou antes e depois.

A correção confere as três pós-condições depois da validação de contexto/ID. Resposta incoerente produz `MealPlanUnavailableException` com mensagem de publicação não confirmada, sem `onSaved`. O fake pending foi ajustado para retornar estado publicado coerente por padrão; parâmetros negativos testam cada desvio explicitamente.

## Verificação

- RED focado: 4 falhas por callback de sucesso indevido; 1 controle positivo PASS.
- Wizard completo depois da correção: 16/16 PASS.
- Analyzer de dois arquivos e validador de contratos visuais: PASS.
- Revisão independente read-only: sem achados acionáveis.
- Diff check: PASS.

## Limites

Não altera SQL, comandos de modelos, mídia, autorização, idempotência ou política de retry. O backend legado permanece people-based; nenhuma persistência remota foi executada. A validação do estado recebido não resolve efeitos parciais de tentativas anteriores nem prova E2E. Memória de conhecimento: no-op, correção em conformidade com contrato existente, sem nova decisão de produto.
