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
| — | — | — | — |

## Avisos para a outra sessão

- Nenhum lote ou fatia entregue ainda.

## Sobra para a R15

- Nenhuma ainda; `owner.r12-38` (imagem R2 de Cardápios) permanece fora desta reivindicação e aberto conforme a fila.

## Contadores

FE 164/231, BE 164/224, E2E 137/199, Owner 9/53 (base `origin/dev 0c8add8a7`, sem delta desta sessão).
