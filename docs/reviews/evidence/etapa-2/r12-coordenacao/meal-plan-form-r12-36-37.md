---
source: R12-36/R12-37; R12-cardapios-owner.md
status: partial
generated_at: 2026-09-13
---

# R12-36/R12-37 — formulário de cardápio

O fluxo não exibe mais `Prioridade explícita` nem `Datas excluídas`, conforme
direção do Owner. Os campos e a serialização permanecem no domínio para
preservar dados históricos e compatibilidade com a RPC. Os testes do wizard e
diretório passaram 55/55.

R12-36 fica parcial: a publicação programada continua date-only no contrato
atual, portanto não foi rotulada indevidamente como data/hora persistida.
R12-34, R12-35 e R12-38 permanecem pendentes por exigirem mudança de modelo,
seletor múltiplo canônico ou gateway R2 real.
