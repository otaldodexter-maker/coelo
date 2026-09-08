---
title: "Modelos de Cardápios — metadados camelCase do contrato RPC"
source: "MealPlanTemplate.fromJson; migration 20260820160000_meal_plans_model_audience_availability.sql:724,783,901; review independente activities_contract_read"
status: "correção local-green; integração real aberta"
generated_at: "2026-09-08"
---

O SQL canônico de `meal_plan_template_list` e `meal_plan_template_get` retorna
`tenantId`, `institutionId`, `planVariant`, `audienceSegment`, `createdAt` e
`updatedAt`. `meal_plan_template_save` devolve o get. O parser lia exclusivamente
os aliases snake_case: perdia tenant/instituição, convertia simple em complete,
staff/all em students e substituía datas recebidas pelo horário atual.

Correção mínima: reconhecer camelCase prioritário com fallback snake_case nos
seis campos. Nenhuma mudança de SQL, ACL, autorização, UI, mídia ou formato
enviado. Ausência de ambas as formas conserva os fallbacks existentes, sem
afirmar validação estrita de todos os DTOs neste incremento.

## Evidência executada

- RED: três chamadas simuladas pelo adapter real — list/get/save com payload
  camelCase — falharam por tenant vazio/null. Três controles snake_case passaram.
  As demais asserções dos casos RED não foram alcançadas antes da primeira falha.
- GREEN: dados + wizard + diretório, **66 PASS, exit0**, incluindo os seis casos
  e todas as asserções dos seis campos. Analyzer dos dois arquivos: PASS.
- Review independente sem blocker; adicionada a contraprova de aliases
  conflitantes no mesmo payload, com camelCase prevalecendo. Suite final de
  serialização: **12 PASS**, contagem sobreposta à regressão, não somável.
- Gate de memória com Root explícito: PASS. A correção implementa o contrato
  canônico já existente; não introduz decisão de produto ou projeção nova.

Os valores sintéticos de tenant e instituição são distintos de propósito para
detectar campos trocados; não representam uma criação aceita pelo backend.
HTTP usa MockClient, sem acesso de rede. Nenhum SQL/Docker ou persistência real
foi executado. Backend People legado, auditoria e autorização039, R2, reload e
E2E continuam pendentes e não foram promovidos.
