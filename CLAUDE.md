---
source: "AGENTS.md; configuração local de skills compartilhadas"
status: "active"
generated_at: "2026-09-09"
---

# Coelo - Claude Code

@AGENTS.md

## Cadeia De Instrucoes

`AGENTS.md` termina com `@RTK.md`, que resolve para `./RTK.md` na raiz do projeto.
Esse arquivo e um superset de `C:\Users\adrie\.codex\RTK.md`: contem todo o conteudo
do RTK global mais a secao "Coelo Decision". Por isso a cadeia canonica e
`CLAUDE.md -> AGENTS.md -> RTK.md` (profundidade 2, limite de 4 hops), sem importar o
RTK global separadamente, o que duplicaria conteudo e criaria um import externo.

## Ambiente Local

- Windows 11 + PowerShell. Comandos de shell devem usar sintaxe PowerShell.
- Skills do projeto ficam em `.claude/skills/`, junctions para `.agents/skills/` e
  para `.codex/skills/ui-ux-pro-max`. Editar sempre a origem, nunca o link.
- Skills pessoais ficam em `~/.claude/skills/`, junctions para `~/.agents/skills/` e
  para `~/.codex/skills/hatch-pet`.

## Nomes Canonicos Das Skills De Revisao

Os diretorios mantem nomes historicos, mas os nomes invocaveis sao os do frontmatter:

| Diretorio                      | Nome invocavel           |
| ------------------------------ | ------------------------ |
| `coelo-flutter-review`         | `coelo-frontend`         |
| `coelo-supabase`               | `coelo-backend`          |
| `coelo-flutter-supabase-review`| `coelo-frontend-backend` |
