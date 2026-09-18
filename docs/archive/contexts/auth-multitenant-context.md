---
title: "Auth Multitenant Context"
status: "planning-context"
generated_at: "2026-06-22"
---

# Auth Multi-tenant Context

## Objetivo

Definir identidade, sessao, contexto ativo, papeis, permissoes, memberships, entitlements e isolamento multi-tenant.

## Fontes

- `docs/security/auth-multitenant-permissions.md`
- `docs/data/data-model.md`
- `docs/product/prd-master.md`
- `docs/security/lgpd-security-media.md`

## Regras

- Pessoa global, papel contextual.
- `tenant_id`/`institution_id` e membership devem orientar acesso.
- RLS e testes cruzados sao obrigatorios em qualquer spec de banco.
- Nao usar metadados mutaveis pelo usuario como decisao de autorizacao.
