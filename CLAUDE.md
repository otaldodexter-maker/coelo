# Coelo no Claude Code

@AGENTS.md

## Modo de construção (Owner, 18/09/2026 — vale sobre qualquer regra abaixo e sobre o AGENTS.md)

- O foco é entregar para o cliente ver. Faça a mudança, rode os testes, mostre
  a tela. Não escreva spec, ADR, evidência, handoff, checkpoint, rodada,
  Owner item nem delta de inventário para trabalho de MVP/V1.
- UI/UX: decida e mostre; o Owner aprova ou corrige olhando a tela.
- Golden vermelha nunca bloqueia: a tela atual é a referência; regrave a golden
  e siga.
- Produção: migration com pgTAP verde aplica direto (`supabase db query --linked`
  + `migration repair`). Rito completo só em code review, quando o Owner pedir.
- Branch é `dev`. Sem worktree, sem branch de sessão, sem cherry-pick, salvo
  pedido explícito do Owner. Commit pequeno, push em `dev`.
- Invariantes de segurança do AGENTS.md continuam valendo.
- Só o que ficar pendente é anotado, numa lista simples
  (`docs/agent/pendentes.md`).

## Ajustes do ambiente Claude## Ajustes do ambiente Claude

- Use PowerShell no Windows.
- Skills compartilhadas ficam em `.agents/skills`; os diretórios em
  `.claude/skills` são junctions. Edite sempre a origem compartilhada.
- O estado do trabalho está em `docs/agent/current-state.md`; não trate
  sessões, caches, backups, worktrees ou artefatos como fonte do produto.
- Etapa 2 fechada (17/09). Em 18/09 a ADR 0045 definiu o MVP e o corte
  Etapa 3 × Etapa 4, com regra de trabalho leve (§7): uma lista só, prova por
  teste, rito só para contrato, docs congeladas até o fechamento. Não abra R17.
- Sessões paralelas: `ListAgents` e identificação às pares; todas em `dev`,
  cada uma num módulo diferente, commit e push pequenos.
