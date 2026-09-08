---
title: "E2E5 — preservação de tema nos diálogos de decisão"
source: "review do helper Agenda; agenda_collection_context_test; assessment_entry_page_test"
status: "regressão local corrigida; sem promoção E2E"
generated_at: "2026-09-07"
---

A revisão de DialogRoute em Agenda revelou o mesmo risco nos pacotes locais de
Aprovações e Fechamento de Avaliações: abrir rota no navigator raiz perdia o
Theme local. Escopo: somente paridade visual e teclado desses diálogos, sem
alterar decisões ou backend. Ordem RED → captura de tema → regressão/review;
parada desta fatia: dois testes verdes e analyzer limpo. Cerca de 4 minutos.

Dois RED reais: app raiz claro + página sob tema escuro abria decisão clara.
Agora ambas as rotas capturam InheritedTheme da página para navigator raiz,
respeitam barrierColor local (fallback scrim semântico) e traversal closedLoop.
Ownership da rota e guards de contexto permanecem inalterados.

- Coleção Agenda + todas as suítes Avaliações: **36/36 PASS**.
- Analyzer dos quatro arquivos: sem issues; visual validator exit0.
- Nenhuma baseline alterada; sem execução de banco ou publicação real.
- Gate de memória no-op: correção de regra visual existente, sem novo conhecimento.

Esta correção complementa os pacotes bc4432b e4b03ea73; não os promove a E2E.
