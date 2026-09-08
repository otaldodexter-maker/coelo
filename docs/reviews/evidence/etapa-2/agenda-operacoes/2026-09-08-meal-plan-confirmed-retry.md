---
title: "Cardápios — recurso confirmado após rejeição de continuação"
source: "meal_plan_wizard_page.dart; development_meal_plan_wizard_test.dart; revisão independente"
status: "local-green; integração real aberta"
generated_at: "2026-09-08"
---

# Causa e recorte

O ramo de lista de conflitos já preservava o rascunho salvo. Porém, se a consulta de conflitos, a revisão ou a publicação lançasse `MealPlanConflictException`/`MealPlanValidationException`, o catch descartava a chave da operação sem conservar o ID e a revisão que já tinham sido confirmados. Na criação, a próxima gravação voltava com ID nulo.

Seis REDs reproduziram essa perda: três etapas × duas rejeições de domínio. A tentativa seguinte enviou `null` em vez do ID `dev-meal-plan-13` retornado no save anterior.

## Correção

Guardar localmente a última resposta confirmada após validação de contexto e ID, incluindo revisão e gravação de metadados de mídia quando esse caminho existe. Somente no catch que já descartava a operação por conflito/validação, conservar esse recurso em `_original` antes de abrir uma nova chave na próxima tentativa.

Não atribuir `_original` antecipadamente para falhas incertas: isso alteraria o payload de criação durante replay da mesma chave. `MealPlanUnavailableException` conserva a chave, o ID de criação original e a revisão original. Três controles adicionais exercitam essa distinção nas mesmas etapas.

## Evidência

- 6 REDs por ID perdido, antes da correção.
- 9 casos focados PASS depois da correção: ID/revisão confirmados e chave nova nas rejeições; mesma chave/payload nas indisponibilidades.
- Data + wizard + diretório: 48/48 PASS.
- Analyzer dos dois arquivos, validador visual e diff check: PASS.
- Revisão independente read-only: sem blocker.

## Limites

Consulta de conflitos controlada por fake; não comprova consulta real após revisão, upload, modelos ou resposta perdida após commit. Não implementa retomada automática, reconciliação remota ou novo protocolo de idempotência. Nenhum SQL/Docker executado pelo root. Conhecimento: no-op, sem nova regra durável aprovada.
