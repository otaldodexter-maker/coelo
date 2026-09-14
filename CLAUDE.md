---
source: "AGENTS.md; docs/agent/*.md"
status: "active"
generated_at: "2026-09-14"
---

# Coelo no Claude Code

@AGENTS.md

## Ajustes do ambiente Claude

- Use PowerShell no Windows.
- Skills compartilhadas ficam em `.agents/skills`; os diretórios em
  `.claude/skills` são junctions. Edite sempre a origem compartilhada.
- O estado do trabalho está em `docs/agent/current-state.md`; não trate
  sessões, caches, backups, worktrees ou artefatos como fonte do produto.
- Não abra uma nova rodada automaticamente: R14 é a vigente (fila única em
  `R14-pendencias.md`); uma R15 exige fechamento e abertura explícita do Owner.
