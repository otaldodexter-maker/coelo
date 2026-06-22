---
title: "Monorepo"
status: "Accepted for planning"
generated_at: "2026-06-22"
---

# Monorepo

## Contexto

O Coelo tera multiplas superficies e pacotes compartilhados. O monorepo reduz duplicacao de contratos, tokens, dominio e auth.

## Decisao

Adotar monorepo com `apps/`, `packages/`, `docs/`, `specs/`, `decisions/` e `assets/`.

## Consequencias

- A decisao orienta specs futuras, mas nao cria codigo por si so.
- Qualquer divergencia com documento oficial deve ser registrada em `docs/open-questions.md`.
- Implementacao depende de spec aprovada.
