---
title: "R14 Sessão 2 — Cardápios — prova de rota real"
source: "R14-execucao-paralela.md; R14-pendencias.md; ADR 0038; review-scope.md"
status: "evidence"
lifecycle: "current"
recorded_at: "2026-09-15"
environment: "producao"
---

# Cardápios — prova em produção

Sessão 2 (Luna), build QA da worktree `r14/bloco-cd`, rota real em `127.0.0.1:3015`, autenticada com o usuário sintético da frente de Operações. A prova foi executada em 15/09/2026; não houve mudança de código nem lote SQL nesta fatia.

IDs persistidos usados na releitura:

- modelo: `bef18a8c-c208-4eea-97bf-a2051e400789`
- cardápio: `40ab10ca-60bf-4e8f-b914-a79bedaf59bb`

## Matriz de aceite

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| `meal-plans.model-create` | `/meal-plans` → Cardápios → criar modelo (`/meal-plans/models/new`) | Criado, associado ao catálogo real autorizado e publicado; RPC `meal_plan_template_get` retornou status `published`, versão 3 e conteúdo persistido | Modelo editado e recarregado na rota `/meal-plans/models/bef18a8c-c208-4eea-97bf-a2051e400789/edit` com nome, instituição e conteúdo mantidos | Seletor de instituição exibiu somente os catálogos autorizados ao ator; nenhum catálogo de tenant alheio foi oferecido |
| `meal-plans.model-edit` | `/meal-plans/models/bef18a8c-c208-4eea-97bf-a2051e400789/edit` | Renomeado, duplicado, refeição renomeada e ordem alterada; publicação da revisão concluída | Reload mostrou `Jantar R14` antes de `Almoco R14`; RPC confirmou `updatedAt` e versão 3 | Mesmo escopo autorizado permaneceu selecionado após reload |
| `meal-plans.create` | `/meal-plans` → Cardápios → criar cardápio (`/meal-plans/new`) | Criado a partir do modelo publicado, com abrangência da instituição sintética real e recorrência configurada | Reload da edição preservou nome, abrangência e programação | O fluxo só permitiu a instituição retornada para o ator; não houve opção cross-tenant |
| `meal-plans.edit` | `/meal-plans/40ab10ca-60bf-4e8f-b914-a79bedaf59bb/edit` | Nome alterado; recorrência trocada para `Datas específicas`; duas datas foram adicionadas, uma removida e a alteração publicada | Reload preservou somente o chip `16/09/2026`, sem restaurar a data removida | Escopo institucional continuou autorizado e estável após reload |
| `meal-plans.publish` | Revisão dos wizards de modelo/cardápio → `Publicar modelo` / `Enviar e publicar` | Diretório retornou os dois cards publicados; cardápio ficou com `visibility_mode=scheduled` e `status=published` | Releitura RPC confirmou a publicação e o payload final | Publicação manteve o vínculo ao tenant/instituição autorizados |

## Instante e visibilidade agendada

Na rota de produção, o horário local escolhido foi `16/09/2026 08:00` (America/Sao_Paulo). A releitura direta por `meal_plan_get` retornou `visibilityMode=scheduled`, `visibleFrom=2026-09-16T11:00:00+00:00`, isto é, o mesmo instante em UTC, além de `status=published`, `recurrence.kind=specificDates` e `specificDates=[2026-09-16]`. A tela de revisão exibiu a programação antes do envio; após o envio, o diretório exibiu o card e o reload da edição reidratou a programação.

## Capturas

- Modelo: `capturas/cardapios-model-institution-options-20260915.png`, `cardapios-model-review-after-reorder-20260915.png`, `cardapios-model-reload-content-20260915.png`.
- Cardápio: `capturas/cardapios-plan-scheduled-set-20260915.png`, `cardapios-plan-specific-dates-two-chips-20260915.png`, `cardapios-plan-specific-date-removed-20260915.png`, `cardapios-plan-specific-review-20260915.png`, `cardapios-plan-after-publish-20260915.png`, `cardapios-plan-reload-specific-schedule2-20260915.png`.

## Verificações locais

`flutter test test/features/meal_plans`: 127 casos, 122 pass; 5 falhas somente de golden da diretoria (diferenças visuais já identificadas, sem falha funcional). O build QA foi concluído; `flutter analyze` não foi necessário porque não houve correção de código nesta fatia.

## Resultado

FE `verified` e E2E `verified-e2e` nos cinco action_ids; BE permanece `done` pelo contrato SQL existente, sem candidato ou aplicação de lote. O item `owner.r12-38` (imagem privada R2) permanece aberto.
