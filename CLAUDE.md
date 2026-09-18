# Coelo no Claude Code

@AGENTS.md

## Ajustes do ambiente Claude

- Use PowerShell no Windows.
- Skills compartilhadas ficam em `.agents/skills`; os diretórios em
  `.claude/skills` são junctions. Edite sempre a origem compartilhada.
- O estado do trabalho está em `docs/agent/current-state.md`; não trate
  sessões, caches, backups, worktrees ou artefatos como fonte do produto.
- Etapa 2 fechada (17/09). Em 18/09 a ADR 0045 definiu o MVP e o corte
  Etapa 3 × Etapa 4, com regra de trabalho leve (§7): uma lista só, prova por
  teste, rito só para contrato, docs congeladas até o fechamento. Não abra R17.
- Sessões paralelas: antes de criar worktree, `ListAgents` e pedir
  identificação às sessões pares; uma worktree por escritor, criada de `dev`,
  integrada por cherry-pick pela coordenadora.
