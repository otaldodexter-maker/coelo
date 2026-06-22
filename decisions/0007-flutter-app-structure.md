---
title: "Flutter App Structure"
status: "Accepted for planning"
generated_at: "2026-06-22"
---

# Flutter App Structure

## Contexto

Admin, Superadmin e Principal podem ter web e mobile no futuro, mas nao devem carregar telas uns dos outros.

## Decisao

Organizar Flutter por superficies independentes e pacotes compartilhados de tokens, UI, dominio, API e auth.

## Consequencias

- A decisao orienta specs futuras, mas nao cria codigo por si so.
- Qualquer divergencia com documento oficial deve ser registrada em `docs/open-questions.md`.
- Implementacao depende de spec aprovada.
