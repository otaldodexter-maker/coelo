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
