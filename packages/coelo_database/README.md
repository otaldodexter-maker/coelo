# coelo_database

Schema fisico, migrations, seeds, testes de RLS, policies, outbox e ownership por contexto.

Status: pacote ativo. A primeira migration real nasceu de `specs/011-superadmin-database-rls.md`.

## Estrutura

- `migrations/`: migrations SQL aplicaveis no Supabase.
- `plans/`: planos tecnicos antes da execucao.
- `tests/`: queries de validacao e futuros testes SQL/RLS.

## Schemas iniciais

- `public`: dados operacionais do produto, sempre com RLS/grants quando expostos.
- `app_private`: helpers, RPCs e funcoes privilegiadas.
- `audit`: logs, evidencias e acoes sensiveis, sem grants diretos para clientes.
- `analytics`: eventos minimizados, contadores e snapshots para dashboards, sem grants diretos para clientes.

Validacoes principais:

- `tests/2026-06-23-superadmin-foundation-validation.sql`
- `tests/2026-06-23-schema-boundaries-catalog-validation.sql`
- `tests/2026-07-24-contextual-activities-foundation-validation.sql`

Fundacao de Atividades Contextuais:

- `migrations/20260724120307_contextual_activities_foundation.sql`
- `migrations/20260724122545_contextual_activities_fk_index_hardening.sql`
