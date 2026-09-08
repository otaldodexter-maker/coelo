---
title: "Localização dos handoffs R01"
source: "Owner R01; docs/reviews/coelo-etapa-2-coordenacao.md; docs/reviews/inventario-etapa-2.json; AGENTS.md"
status: "active"
generated_at: "2026-09-08T12:19:18-03:00"
timezone: "America/Sao_Paulo"
---

# Handoffs exclusivos dos executores

C00 não fabrica entregas nem confirma recebimento antecipado. Cada executor cria `CXX.md` somente em sua própria worktree, no caminho registrado em assignments/CXX.md. C00 lê pelo caminho absoluto e registra acknowledgements na assignment viva. Esta pasta C00 é só referência de formato; nenhuma cópia é usada como fonte concorrente.

Campos: rodada, conversa/ID, revisão, última instrução, timestamp/fuso, branch/baseline, SHAs de código, push/ponta remota, action_ids, arquivos, testes/resultado/ambiente, evidências minimizadas, bloqueios, primeiro critério aberto, próximo passo, ETA fundamentada por categoria e propostas de delta FE/BE/E2E.
