# Coelo no Claude Code

@AGENTS.md

## Ajustes do ambiente Claude

- Use PowerShell no Windows.
- Skills compartilhadas ficam em `.agents/skills`; os diretórios em
  `.claude/skills` são junctions. Edite sempre a origem compartilhada.
- O estado do trabalho está em `docs/agent/current-state.md`; não trate
  sessões, caches, backups, worktrees ou artefatos como fonte do produto.
- Etapa 2 concluída em 17/09/2026 (FE/BE/E2E 100%). A R16 é a vigente só
  como reserva (`R16-pendencias.md`, ADR 0043/0044); não abra R17 nem a
  Etapa 3 sem decisão explícita do Owner.
- Sessões paralelas: antes de criar worktree, `ListAgents` e pedir
  identificação às sessões pares; uma worktree por escritor, criada de `dev`,
  integrada por cherry-pick pela coordenadora.
