---
title: "R14 — handoff da Sessão 9 (visual: goldens do cabeçalho, cards de Rotina, Arquivar modelos)"
source: "Sessão 9 da R14 (Opus 5), 16/09/2026; briefing comum da coordenadora; ADR 0041 B1/C1/C3; R14-pendencias.md; docs/reviews/evidence/etapa-2/r14-sessao-9/"
status: "active"
lifecycle: "current"
generated_at: "2026-09-16"
updated_at: "2026-09-16"
audience: "team"
---

# R14 — handoff da Sessão 9

Worktree `Coelo.worktrees\r14-visual-arquivar`, branch `r14/visual-arquivar` (base `dev` `e6b8d6f63`).
Porta 3021 / CDP 9421 reservados, **não usados**: produção em incidente (PostgREST 504 `PGRST003`), toda a
sessão é trabalho local (Flutter, testes, goldens, pgTAP em espelho). Nenhuma escrita em produção; nenhum
estado por `action_id` alterado (nenhum delta aplicado).

## Reivindicações

- Fatia 1 (goldens do cabeçalho global) — entregue.
- Fatia 2 (`owner.r12-01`, cards de Modelos de rotina) — em andamento.
- Fatia 3 (`owner.r12-02`, Arquivar modelos de Atividade/Rotina) — a seguir.

## Fatias entregues

| SHA | Fatia | action_ids → estados | Owner items | Evidência |
|---|---|---|---|---|
| (ver git) | Goldens — deriva do cabeçalho global (ADR 0041 C1): causa observada (`3945394f3` trocou `OC`/"Owner Coelo" estáticos por `headerProfile` da sessão; sem host os goldens renderizavam o placeholder `–`/`Conta`, deslocando sino e Bug); estabilização por `SuperadminHeaderProfileScope` + `SuperadminHeaderProfile.preview()` + `test/support/golden_header_profile.dart`; 30 referências regravadas nas três famílias; suítes 30/30 verdes; shell 72/72. | nenhum (golden não promove) | `owner.r12-10` → `partial / FE local-green …`; `owner.r12-11` já done (só citado) | `r14-sessao-9/goldens-cabecalho-global-20260916.md` (+ `capturas/`, `goldens-outras-suites-preexistentes-20260916.tsv`) |

## Avisos para as outras sessões e para a coordenadora

1. `SuperadminShell` agora resolve o perfil do cabeçalho em três níveis: parâmetro → host persistente →
   `SuperadminHeaderProfileScope` → placeholder. Produção não muda. Goldens/páginas montadas sem host podem
   envolver a árvore com `withGoldenHeaderProfile` (`apps/superadmin/test/support/golden_header_profile.dart`).
2. 391 goldens em outras 34 suítes do superadmin **já falhavam** antes desta fatia (assinatura do cabeçalho em
   249 deles — 194/3.058/3.068 px — e causas já triadas nos demais). Não regravados: a C1 cobre nominalmente
   Segurança/Perfis/Rotina. Lista completa no TSV da evidência.
3. `entrega-atual.json` e `R12-owner-items.json` mudaram apenas por `sync-r12-owner-records.cjs` (projeção).

## Sobra para a R15 (sugestão)

- Aplicar `withGoldenHeaderProfile` às demais suítes administrativas e regravar as que ficarem só com a
  assinatura do cabeçalho, com autorização explícita do Owner (estende a C1).

## Bloqueios

- ambiente: rota real indisponível (PostgREST 504 `PGRST003`) — nenhuma prova FE/E2E na rota real nesta sessão.

## Contadores

`validate-trackers.cjs`: PASS — FE 189/232, BE 171/219, E2E 162/186 (ativo), Owner 21/53 (inalterados).
