---
title: "Superadmin Context"
status: "planning-context"
generated_at: "2026-06-22"
---

# Superadmin Context

## Superficie

`apps/superadmin`, Flutter privado em `superadmin.coelo.me`.

## Objetivo

Operacao interna Coelo: instituicoes, planos, entitlements, suporte auditado, logs, incidentes e governanca da plataforma.

## Fontes

- `docs/product/prd-superadmin.md`
- `docs/security/auth-multitenant-permissions.md`
- `docs/security/lgpd-security-media.md`
- `docs/data/data-model.md`

## Regras

- Acesso interno sempre auditado.
- Evitar privilegio amplo por padrao.
- Nunca expor `service_role` no cliente.
- Acoes sensiveis exigem caminho server-side e trilha de auditoria.
