---
title: "Admin Context"
status: "planning-context"
generated_at: "2026-06-22"
---

# Admin Context

## Superficie

`apps/admin`, Flutter privado em `admin.coelo.me`.

## Objetivo

Gestao da instituicao: onboarding, usuarios, unidades, grupos, turmas, comunicacao, rotina, agenda, importacoes e permissoes.

## Fontes

- `docs/product/prd-admin.md`
- `docs/security/auth-multitenant-permissions.md`
- `docs/data/data-model.md`
- `docs/design/design-system.md`

## Regras

- Toda visibilidade deriva de instituicao, unidade, grupo, membership e papel contextual.
- Componentes administrativos ficam em `coelo_ui_admin`.
- Acesso a chats e midias privadas precisa de decisao especifica registrada.
