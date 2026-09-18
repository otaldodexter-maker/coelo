---
title: "Estado atual do trabalho do Coelo"
source: "Owner em 2026-09-17 (ADR 0043, ADR 0044, Foco da R16, fechamento da execução da R16); docs/reviews/etapa-2-operacao/ETAPA-2-estado-atual.md; R16-pendencias.md; R16-checkpoint-20260917.md; decisions/0035-etapa3-mvp-contextual-access-and-app-delivery.md"
status: "active"
lifecycle: "current"
generated_at: "2026-09-14"
updated_at: "2026-09-18"
audience: "team"
---

# Estado atual

## Agora (18/09/2026)

- **Etapa 2 fechada; foco no MVP inteiro (ADR 0045).** O Owner dividiu o que
  falta em **Etapa 3** (correções da revisão tela a tela com a reserva R16, tour,
  acesso contextual de funcionários, specs 065–069) e **Etapa 4** (publicação,
  `apps/admin`, `apps/principal` com spec 064, push preparado, analytics, IA).
  Importação, MFA e lojas: V1. Regra de trabalho leve da Etapa 3 na ADR 0045 §7.
- Em 18/09 a Sessão RESERVA fechou owner.r12-04/05/06/08/33/49 (Owner 45/53),
  lotes **82 e 83** em produção (sino v2 com responsável, Celular E.164, fixtures
  QA R15, `can_remove` segue a RPC), 21 testes funcionais corrigidos (0 vermelhos
  funcionais; só goldens). "Publicar lançamento" fica no Histórico (spec 052 §3).
- Sessão TOUR em execução (tour do menu e cabeçalho, `R16-prompt-tour-20260918.md`).
- Próximo: o Owner abre o app e monta o bloco de notas da revisão de telas; as
  correções seguem a regra de trabalho da Etapa 3.

## Estado de 17/09/2026 (noite, histórico)

- **Etapa 2 do MVP concluída em FE/BE/E2E**: FE 199/199 (100%), BE 186/186
  (100%), E2E 186/186 (100%), provados na rota real em produção
  (`R16-checkpoint-20260917.md`, `dev` `21f4485ad`). A execução da R16 rodou com
  duas sessões paralelas (`R16-execucao.md`, histórico): `agora.publish` (lote
  81, spec 070 — o leitor do Agora reconhece o responsável por vínculo, sem
  membership) e `forms.location-answer` (v4 publicada, ocorrência única,
  resposta com Local pela tela).
- **A R16 continua vigente só como reserva** (ADR 0043; decisão do Owner de
  17/09, "Foco da R16"): 14 Owner items abertos/parciais, 19 resíduos H, 2 itens
  da ADR 0038, dívida técnica da Mesa R16 (ADR 0044) e resíduos operacionais,
  todos em `R16-pendencias.md`. Eles são apresentados na **revisão de telas
  antes da Etapa 3** (o Owner aprova cada tela ou manda a correção para a
  Etapa 3). Não executar a reserva sem pedido; não abrir R17.
- **Etapa 3** (ADR 0035): nada implementado. Abre só por decisão explícita do
  Owner, com proposta consolidada (escopo, ordem, dependências, aceites,
  estimativa). O que já está predefinido e o que falta decidir estão em
  `backlog.md`.
- Produção: lotes 75–83 aplicados (82/83 em 18/09); Edges `chat-media`,
  `child-safety-media` v2, `meal-plan-media`, `meal-plan-image-cleanup`,
  `now-media`, `form-media` v23. Conta `qa-r15-responsavel@coelo.me` (responsável
  ativa com 2 crianças, sem membership — OQ-048). Candidato
  `20260917113000_qa_r15_guardian_membership_v1` não aplicado.
- Repositório: **só `dev`** no GitHub; worktrees e branches `r15-*`/`r16-*`
  removidas com bundles em `Coelo-backups/r15-fechamento` e `r16-fechamento`.
  Documentação arrumada em 17/09 (`archive-manifest-20260917.md`): históricos em
  `docs/archive/` e `docs/reviews/archive/`.
- Regras duráveis: PT409 (nunca 40001); rito de produção por lote com
  autorização nominal do Owner (`docs/knowledge/team/stale-version-pt409-and-production-rite.md`);
  busca de pessoa minimizada (ADR 0041 B5); conta só-responsável não abre tela
  (OQ-048); leitor do Agora reconhece responsável por vínculo
  (`docs/knowledge/team/agora-guardian-reader-without-membership.md`).
- Decisões vigentes do Owner: ADR 0038, 0039, 0040, 0041, 0042 (+ adendo
  E10–E14), 0043, 0044, **0045**. Não reabrir.

## Fonte da fila atual

1. [Fila única R16 (reserva)](../reviews/etapa-2-operacao/next-round/R16-pendencias.md);
2. [Estado atual da Etapa 2](../reviews/etapa-2-operacao/ETAPA-2-estado-atual.md) —
   percentuais canônicos;
3. [Inventário por action_id](../reviews/inventario-etapa-2.json) — estados
   mudam só por `apply-tracker-delta.cjs`;
4. [Checkpoint da R16](../reviews/etapa-2-operacao/next-round/R16-checkpoint-20260917.md)
   — delta do último corte.

Os três rastreadores (`docs/reviews/coelo-*-pendencias.md`) são projeções do
inventário. Rodadas anteriores: `RODADAS.md` (índice) e `docs/reviews/archive/rounds/`.

## Regra de passagem entre rodadas

A cada fechamento: itens `done` não voltam; itens `open`/`partial`/bloqueados
seguem com o mesmo ID; nunca criar cópia concorrente; atualizar este arquivo,
`RODADAS.md`, inventário e rastreadores no mesmo ciclo; só então declarar a
rodada nova aberta — e só com decisão explícita do Owner.

## Fora do trabalho corrente

Etapa 3, V1, V2, pós-MVP e históricos R01–R16 não são trabalho corrente.
Consulte [backlog.md](backlog.md) apenas quando a tarefa tratar desses
horizontes. Limpeza de artefatos: [artifact-cleanup-backlog-20260914.md](artifact-cleanup-backlog-20260914.md)
e [archive-manifest-20260917.md](archive-manifest-20260917.md).
