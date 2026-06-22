---
source: "AGENTS.md; docs/contexts/superadmin-context.md; docs/product/prd-superadmin.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Superadmin Flutter

Aplicacao privada para operacao interna Coelo em `superadmin.coelo.me`.
Controla instituicoes, planos manuais, usuarios internos, avisos, suporte
auditado, logs e governanca da plataforma.

## Estrutura planejada

- `lib/app`: composicao do app, shell e rotas.
- `lib/core`: configuracoes, guards e infraestrutura local do app.
- `lib/features`: modulos de produto do Superadmin.

## Contextos iniciais

- `institutions`: ativacao e gestao de instituicoes.
- `platform_users`: usuarios internos Coelo.
- `plans`: planos, status e limites manuais.
- `notices`: avisos globais ou segmentados.
- `support`: sessoes de suporte auditadas.
- `audit`: logs e evidencias de acoes sensiveis.

## Por que assim

O Superadmin concentra poder operacional. A estrutura por feature ajuda a
manter cada fluxo isolado, auditavel e pronto para receber autorizacao
server-side/RLS sem misturar telas de Admin ou Principal.
