---
title: "Estado atual do trabalho do Coelo"
source: "Owner em 2026-09-14; docs/reviews/etapa-2-operacao/ETAPA-2-estado-atual.md; R14-pendencias.md; RODADAS.md"
status: "active"
generated_at: "2026-09-14"
updated_at: "2026-09-15"
audience: "team"
---

# Estado atual

## Agora

- A Etapa 2 está na R14, aberta em 14/09/2026 por decisão do Owner como **fila única
  consolidada** (R12/R13 congeladas como histórico; IDs preservados; itens `done`
  não retornam).
- A fila vive em um só lugar: `docs/reviews/etapa-2-operacao/next-round/R14-pendencias.md`
  (Owner items, resíduos H, itens da ADR 0038 e ações não terminais por família).
- Último delta de execução: 14/09 ~18:00 — Saúde/Cuidado provado na rota real;
  contadores FE 164/231, BE 164/224, E2E 137/199, Owner 9/53.
- Próximo gate executável (ordem ajustada pelo Owner em 14/09: mais fácil primeiro):
  Bloco A de `R14-pendencias.md` — ações que só precisam de E2E e fecham a tela
  (`circulars.attach`, `agenda.request`, `attendance.create`, `daily-routine.apply`,
  `acontece.create`, …); Cardápios vem no Bloco C.
- Na retomada da R14, manter visíveis os temas listados em `docs/agent/backlog.md`
  (decisões de 14/09); não reabrir decisões já registradas na ADR 0038.

## Fonte da fila atual

Use, nesta ordem:

1. [Fila única R14](../reviews/etapa-2-operacao/next-round/R14-pendencias.md) — Owner
   items (fonte do sync), H, itens da ADR 0038 e ações não terminais;
2. [Estado atual da Etapa 2](../reviews/etapa-2-operacao/ETAPA-2-estado-atual.md) —
   percentuais canônicos;
3. [Inventário por action_id](../reviews/inventario-etapa-2.json) — detalhe e
   certificação por ação (estados só mudam por `apply-tracker-delta.cjs`);
4. [Último checkpoint](../reviews/etapa-2-operacao/next-round/R13-checkpoint-20260914-1800.md)
   — apenas para o delta da última execução.

Os três rastreadores grandes são projeções do inventário para auditoria; não são a
entrada inicial. `R12-pendencias.md`, `R13-pendencias.md`, `R14-catalogo.md`,
`R13-projecao-atual.md` e `R13-owner-items-atual.json` são históricos/derivados.

## Regra de passagem entre rodadas (aplicada em 14/09 na R13 → R14)

A cada fechamento de rodada:

- itens `done` ou aceitos não são transferidos nem reabertos;
- itens `open`, `partial`, bloqueados ou sem prova são levados para a R14 com o
  mesmo `action_id`/Owner ID e nova referência de rodada;
- não criar cópia concorrente em R12, R13 ou R14;
- atualizar este arquivo, `RODADAS.md`, o catálogo corrente, o inventário e os
  rastreadores no mesmo ciclo;
- somente depois registrar que a R14 está aberta.

## Fora do trabalho corrente

Etapa 3, V1, V2, pós-MVP, históricos R01–R13 e artefatos de execução não são
trabalho corrente. Consulte [backlog.md](backlog.md) apenas quando a tarefa
explicitamente tratar desses horizontes.

Para uma tarefa explícita de limpeza, use o
[backlog de artefatos](artifact-cleanup-backlog-20260914.md), não a fila R14.
