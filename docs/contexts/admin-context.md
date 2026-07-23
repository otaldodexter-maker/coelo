---
title: "Admin Context"
status: "planning-context"
generated_at: "2026-06-22"
---

# Admin Context

## Superficie

`apps/admin`, Flutter privado em `admin.coelo.me`.

## Objetivo

Gestao da instituicao: onboarding, usuarios, unidades, grupos, turmas, atividades, comunicacao, rotina, agenda, importacoes e permissoes.

## Fontes

- `docs/product/prd-admin.md`
- `docs/security/auth-multitenant-permissions.md`
- `docs/data/data-model.md`
- `docs/design/design-system.md`

## Regras

- Toda visibilidade deriva de instituicao, unidade, grupo, membership e papel contextual.
- Atividade e um conceito contextual do grupo, reutilizavel dentro da mesma instituicao, com permissao por turma.
- A unidade pode criar atividade somente com capacidade explicita habilitada na gestao do perfil; a atividade herda a instituicao-mae, e a instituicao mantem autoridade integral de ajuste.
- Componentes administrativos ficam em `coelo_ui_admin`.
- Acesso a chats e midias privadas precisa de decisao especifica registrada.
