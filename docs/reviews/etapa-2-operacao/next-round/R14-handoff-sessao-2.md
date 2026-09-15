---
title: "R14 — handoff da Sessão 2 (Blocos C e D)"
source: "R14-execucao-paralela.md; R14-pendencias.md; ADR 0038; review-scope.md"
status: "active"
lifecycle: "current"
generated_at: "2026-09-15"
updated_at: "2026-09-15"
audience: "team"
---

# R14 — handoff da Sessão 2

Sessão 2 (Luna), worktree `C:\Users\adrie\Documents\Coelo.worktrees\r14-cd`, branch
`r14/bloco-cd`, servidor `127.0.0.1:3015`, Chrome CDP `9415`, espelho
`Coelo-backups\mirror-r14`. Base inicial: `origin/dev 0c8add8a7`. Cada fatia provada
vai para `dev` por rebase + push. Esta sessão é a única autorizada a aplicar SQL
em produção e a atualizar a ordem de aplicação.

## Reivindicações

| Tela | action_ids | Owner items | Desde |
|---|---|---|---|
| Cardápios | meal-plans.create, meal-plans.edit, meal-plans.model-create, meal-plans.model-edit, meal-plans.publish | owner.r12-34, owner.r12-35, owner.r12-36, owner.r12-37 | 2026-09-15 |

## Fatias entregues

| SHA | action_ids → estados | Owner items | Evidência |
|---|---|---|---|
| 5fbee1774 | meal-plans.model-create, meal-plans.model-edit, meal-plans.create, meal-plans.edit, meal-plans.publish → FE verified, BE done (contrato existente), E2E verified-e2e | owner.r12-34, owner.r12-35, owner.r12-36, owner.r12-37 done | r14-sessao-2/meal-plans-20260915.md |

## Avisos para a outra sessão

- **Cardápios — 15/09/2026:** prova concluída em produção nos cinco action_ids. Sem SQL novo e sem lote/ledger nesta fatia; RPCs existentes persistiram modelo/cardápio e `meal_plan_get` confirmou `visibilityMode=scheduled`, `visibleFrom=2026-09-16T11:00:00Z`, status `published` e `specificDates=[2026-09-16]`. A outra sessão deve ler este handoff antes de reivindicar telas.

## Sobra para a R15

- Nenhuma ainda; `owner.r12-38` (imagem R2 de Cardápios) permanece fora desta reivindicação e aberto conforme a fila.

## Contadores

FE 182/231, BE 166/224, E2E 155/192, Owner 13/53 (após Cardápios; contadores reconciliados com `origin/dev 9d6636115`).
