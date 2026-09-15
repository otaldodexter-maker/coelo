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
| 5fbee1774 | meal-plans.model-create, meal-plans.model-edit, meal-plans.create, meal-plans.edit, meal-plans.publish → FE verified, BE done (contrato existente), E2E verified-e2e | owner.r12-34, owner.r12-35, owner.r12-36, owner.r12-37 partial; aceite central do Owner ainda pendente | r14-sessao-2/meal-plans-20260915.md |
| 0ab6abd8f | health-care.create/detail/edit; account.profile; assessments.close/reopen → FE/BE local comprovados; E2E/rota conforme evidências | owner.r12-29, owner.r12-30, owner.r12-49; owner.r12-46 permanece parcial e fora do escopo de foto R2 | r14-sessao-2/block-d-20260915.md; r14-sessao-2/assessments-close-reopen-20260915.md |
| 7797a8cad | evidências e manifesto do espelho | mesmas fatias; sem promoção de contadores | r14-sessao-2/block-d-20260915.md |

## Avisos para a outra sessão

- **Cardápios — 15/09/2026:** prova concluída em produção nos cinco action_ids. Sem SQL novo e sem lote/ledger nesta fatia; RPCs existentes persistiram modelo/cardápio e `meal_plan_get` confirmou `visibilityMode=scheduled`, `visibleFrom=2026-09-16T11:00:00Z`, status `published` e `specificDates=[2026-09-16]`. A outra sessão deve ler este handoff antes de reivindicar telas.
- **Avaliações — 15/09/2026:** `assessments.close/reopen` usou o diário existente `d2c945d8-3809-4d84-b836-2bc6da7c381d`; a devolução e o reload conservaram Instituição → Unidade → Turma → período e não criaram diário, participante ou vínculo.
- **Saúde, Account e OQ-031 — 15/09/2026:** migrations aplicadas duas vezes no espelho próprio e, após autorização nominal do Owner nesta conversa, aplicadas em produção na ordem `20260915130000`, `20260915131500`, `20260915133000`; as três constam na ledger remota. PgTAP remoto: saúde 6/6, catálogos 11/11, Account self 6/6. Snapshot produtivo e capturas estão em `r14-sessao-2/block-d-20260915.md`. `owner.r12-29/30` recebeu coleção independente e limite backend 100; `account.profile` recebeu ACL self-only.
- **H08/H23/H13:** transferidos para R15 por autorização do Owner. O contrato produtivo de item relacionado e `action_id` continua ausente; não foi inventado payload, coluna ou ação.

## Sobra para a R15

- H08 Duplicar Aviso e consumidores H23/H13: R15 deve definir no contrato produtivo o item relacionado e a política de `action_id` antes de implementar.
- Reconciliação do gate produtivo do lote 70 e aceite central dos itens entregues.
- Aceite central dos itens `owner.r12-29`, `owner.r12-30` e `owner.r12-49`; `owner.r12-34/35/36/37` continuam partial até aceite central.
- `owner.r12-46` (A+/foto R2) e todos os itens explicitamente fora do escopo continuam abertos.

## Contadores

Não alterados por esta sessão; a coordenadora deve reconciliar após os commits
`0ab6abd8f` e `7797a8cad` contra o `origin/dev` vigente (`5839a0ef2`).
