---
title: "Governança das skills Coelo"
source: "AGENTS.md; .agents/skills/*/SKILL.md"
status: "active"
generated_at: "2026-09-14"
updated_at: "2026-09-14"
audience: "team"
---

# Skills

`.agents/skills` é a origem compartilhada. `.claude/skills` e `.codex/skills`
podem expor junctions ou skills locais, mas não devem conter cópias concorrentes
das instruções do projeto.

Uma skill deve conter somente gatilho, objetivo, pré-condições, fluxo mínimo,
critérios de saída e links para referências. Detalhes grandes, exemplos,
histórico e scripts ficam em `references/` ou `scripts/` e são lidos/executados
somente quando necessários.

Skills não são logs de rodada. Não colocar R01, R12, R13, R14, checkpoints ou
pendências específicas no corpo da skill. O estado atual pertence a
`docs/agent/current-state.md`.
