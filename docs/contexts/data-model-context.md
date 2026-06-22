---
title: "Data Model Context"
status: "planning-context"
generated_at: "2026-06-22"
---

# Data Model Context

## Objetivo

Manter coerencia entre entidades, relacoes, eventos, auditoria, midia, notificacoes e futuras migrations.

## Fontes

- `docs/data/data-model.md`
- `docs/architecture/domain-map.md`
- `docs/architecture/macro-architecture.md`
- `docs/security/auth-multitenant-permissions.md`

## Entidades iniciais

`people`, `auth.users`, `user_profiles`, `usernames`, `institutions`, `units`, `groups`, `memberships`, `child_contexts`, `guardian_links`, `guardian_context_permissions`, `social_profiles`, `follows`, `flow_posts`, `now_items`, `moments`, `media_assets`, `conversations`, `messages`, `agenda_events`, `routine_entries`, `notifications`, `audit_logs`, `analytics_events`, `plans`, `entitlements`, `import_jobs`.

## Regras

- Modelo conceitual antes de migration.
- Separar ownership, visibilidade e auditoria.
- Definir schema fisico em spec tecnica antes da primeira migration.
