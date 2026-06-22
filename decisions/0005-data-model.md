---
title: "Data Model"
status: "Accepted for planning"
generated_at: "2026-06-22"
---

# Data Model

## Contexto

O modelo de dados e transversal e deve preservar rastreabilidade, tenant e auditoria.

## Decisao

Manter modelo conceitual em `docs/data/` e futuras migrations/policies em `packages/coelo_database`.

## Consequencias

- A decisao orienta specs futuras, mas nao cria codigo por si so.
- Qualquer divergencia com documento oficial deve ser registrada em `docs/open-questions.md`.
- Implementacao depende de spec aprovada.
