---
title: "Frontend Architecture"
status: "Accepted for planning"
generated_at: "2026-06-22"
---

# Frontend Architecture

## Contexto

Site publico e apps privados possuem objetivos, runtime e deploys diferentes.

## Decisao

Separar Astro para site publico e Flutter para apps privados, com pacotes compartilhados apenas quando fizer sentido.

## Consequencias

- A decisao orienta specs futuras, mas nao cria codigo por si so.
- Qualquer divergencia com documento oficial deve ser registrada em `docs/open-questions.md`.
- Implementacao depende de spec aprovada.
