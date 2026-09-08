---
title: "E2E5 — nova tentativa de Cardápio após conflito confirmado"
source: "meal_plan_wizard_page.dart; development_meal_plan_wizard_test.dart; review activities_contract_read"
status: "correção local verificada; E2E aberto"
generated_at: "2026-09-07"
---

# Recorte e evidência

Objetivo: não duplicar criação quando o rascunho foi confirmado pelo repository,
mas a verificação subsequente bloqueou publicação por conflito. Inclui somente
essa resposta confirmada; não altera protocolo de recuperação de transporte,
upload, review/publicação parciais, SQL ou autorização. Ordem RED → correção →
regressão → review. Parada desta fatia: ID/revisão preservados, nova operação
para payload corrigido e nenhuma publicação automática. Tempo: cerca de 6 min.

RED real: após publicar, receber rascunho `dev-meal-plan-13` e conflito, voltar,
alterar refeição e repetir, a segunda gravação enviava `mealPlanId: null`.

A corretiva mantém o cardápio confirmado como `_original` ao detectar conflito.
A montagem seguinte usa esse ID e revisão. A resposta de update é validada
contra o ID efetivamente enviado, inclusive em criação que já teve sucesso
parcial. O conflito continua limpando a operação antiga: alteração de payload
usa uma nova chave, sem reutilizar uma requisição idempotente diferente.

- Wizard: **9/9 PASS**; um novo teste prova mesmo ID, revisão retornada, chave
  diferente e zero chamadas review/publish/onSaved enquanto conflito persiste.
- Regressão `test/features/meal_plans/data`, wizard e diretório: **32/32 PASS**.
- Analyzer dos dois arquivos: sem issues; visual validator e diff check: PASS.
- Review independente read-only: sem blocker; criação a partir de modelo não
  passa a sobrescrever o modelo-base. Nenhuma baseline visual alterada.

Sem execução de BD ou prova de persistência real. Gate de memória: no-op,
correção de integridade já exigida, sem decisão de produto nova. Atualização dos
rastreadores centrais delegada ao Coordenador no handoff nominal.
