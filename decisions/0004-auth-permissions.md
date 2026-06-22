---
title: "Auth Permissions"
status: "Accepted for planning"
generated_at: "2026-06-22"
---

# Auth Permissions

## Contexto

Autorizacao deve ser compartilhada sem duplicar regras entre apps privados.

## Decisao

Centralizar sessao, contexto ativo, roles, guards, memberships, permissoes familiares e entitlements em `coelo_auth`.

## Consequencias

- A decisao orienta specs futuras, mas nao cria codigo por si so.
- Qualquer divergencia com documento oficial deve ser registrada em `docs/open-questions.md`.
- Implementacao depende de spec aprovada.
