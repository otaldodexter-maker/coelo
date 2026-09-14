---
title: "Artefatos e isolamento do harness Coelo"
source: "AGENTS.md; inspeção de diretórios em 2026-09-14"
status: "active"
generated_at: "2026-09-14"
updated_at: "2026-09-14"
audience: "team"
---

# Artefatos

## Regra

Artefato de execução não é fonte de produto. Patches, logs, screenshots,
snapshots, worktrees, sessões, caches, prompts e backups só entram numa tarefa
quando o pedido for especificamente sobre aquela evidência.

## Diretórios identificados

- `.codex/`: runtime local; contém previews, patches, logs, validações e um
  `AGENTS.md` legado em `activity-patch-tree`.
- `.claude/`: configurações e junctions de skills do Claude; não é fonte de
  domínio.
- `.superpowers/`: brainstorms, SDD, planos e diffs; histórico de processo.
- `.preserved/` e `.recovery-archives/`: retenção local de recuperação.
- `C:/Users/adrie/Documents/Coelo.artifacts`: scripts e resultados de rodadas.
- `C:/Users/adrie/Documents/Coelo.preserved`: evidências e worktrees retidos.
- `C:/Users/adrie/Documents/Coelo-backups`: backups, dumps e capturas.

Esses diretórios permanecem preservados nesta fase. Nenhum arquivo será
excluído, movido ou reclassificado sem manifesto e aprovação posterior do
Owner. Antes da fase de exclusão, verificar também segredos, dados sintéticos,
dependências de scripts e possibilidade de recuperação.
