---
title: "Multitenancy"
status: "Accepted for planning"
generated_at: "2026-06-22"
---

# Multitenancy

## Contexto

O produto atende multiplas instituicoes e relacoes familiares. Isolamento precisa ser regra de fundacao.

## Decisao

Usar pessoa global, papel contextual e isolamento por `tenant_id`/`institution_id`, membership e RLS quando aplicavel.

## Consequencias

- A decisao orienta specs futuras, mas nao cria codigo por si so.
- Qualquer divergencia com documento oficial deve ser registrada em `docs/open-questions.md`.
- Implementacao depende de spec aprovada.
