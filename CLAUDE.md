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

## Ajustes do ambiente Claude

- Use PowerShell no Windows.
- Skills compartilhadas ficam em `.agents/skills`; `.claude/skills` são
  junctions. Edite sempre a origem compartilhada.
- Sessões paralelas: todas em `dev`, cada uma num módulo diferente, commit e
  push pequenos. Não abra R17.
