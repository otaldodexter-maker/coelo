---
title: "Mapa de horizontes e pendências Coelo"
source: "docs/agent/current-state.md; decisões e PRDs canônicos"
status: "active"
generated_at: "2026-09-14"
updated_at: "2026-09-14"
audience: "team"
---

# Horizontes de trabalho

## Trabalho atual — Etapa 2 / R13

É a única fila executável neste momento. Use [current-state.md](current-state.md)
e os documentos R13 apontados nele.

## Pendências do MVP

Use os itens não terminais do estado R13 e o inventário por `action_id`. Itens
explicitamente `deferred-post-mvp` continuam registrados, mas não bloqueiam o
MVP e não devem ser implementados por inferência.

## V1 e V2

Não há uma fila operacional V1/V2 única autorizada neste índice. Para entender
intenção de produto, consulte os PRDs:

- [PRD Master](../product/prd-master.md);
- [PRD Superadmin](../product/prd-superadmin.md);
- [PRD Admin](../product/prd-admin.md);
- [PRD Principal](../product/prd-app.md).

Uma tarefa V1/V2 só se torna executável quando o Owner a abrir, uma spec for
aprovada e o estado atual a apontar.

## Pendências gerais e conflitos

- [Perguntas abertas](../open-questions.md) reúne conflitos e decisões ainda
  necessárias.
- [ADRs](../../decisions/README.md) guardam decisões persistentes.
- [Specs](../../specs/README.md) guardam escopo e contratos, mas só specs
  marcadas como ativas/aprovadas para a tarefa autorizam implementação.

## Limpeza de artefatos

Não faz parte da fila de produto. Os lotes concluídos e os itens retidos estão
em [artifact-cleanup-backlog-20260914.md](artifact-cleanup-backlog-20260914.md).

## Histórico

R01–R12, checkpoints, prompts, handoffs e os arquivos em
`docs/reviews/archive/` preservam proveniência. Não são filas alternativas.
