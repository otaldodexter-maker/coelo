---
source: "AGENTS.md; docs/contexts/admin-context.md; docs/product/prd-admin.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Admin Flutter

Aplicacao privada da instituicao em `admin.coelo.me`. O Admin configura e
mantem unidades, grupos, pessoas, vinculos, permissoes, importacoes,
conteudo, rotina, agenda e canais.

## Estrutura planejada

- `lib/app`: composicao do app, shell e rotas.
- `lib/core`: configuracoes, guards e infraestrutura local.
- `lib/features`: modulos de produto do Admin.

## Padroes Flutter obrigatorios

- Usar `MaterialApp.router` com `go_router` quando o app ganhar codigo
  executavel.
- Manter rotas em `lib/app/router` e guards em `lib/core/guards`.
- Manter `lib/core/isolates` para parsing grande, importacoes, validacoes em
  massa, filtros custosos, exportacoes e outras computacoes fora da UI.
- Componentizar telas por feature: `presentation/screens`,
  `presentation/widgets` e `presentation/view_models`.
- Usar `const`, builders/slivers para listas grandes e layout por constraints.
- Nao carregar imagens grandes sem variante apropriada, placeholder/erro e
  regra de cache.

## Contextos iniciais

- `onboarding`: checklist de ativacao institucional.
- `units`: unidades, sedes e operacoes locais.
- `groups`: grupos, turmas, equipes ou atendimentos.
- `people`: pessoas, responsaveis, equipe e criancas.
- `permissions`: papeis, escopos e permissao familiar.
- `imports`: importacao CSV/XLSX com previa e validacoes.
- `content`: Flow, comunicados, Now, Moments e agenda.
- `routine_templates`: modelos de diario de rotina.

## Por que assim

O Admin nao deve virar ERP pesado. A estrutura por feature preserva foco em
onboarding, governanca, rotina e comunicacao, mantendo permissoes e dados
infantis isolados por instituicao, unidade, grupo e vinculo.
