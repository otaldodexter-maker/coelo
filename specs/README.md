# Specs

Specs SDD iniciais da fundacao Coelo. Elas organizam escopo, fontes, dados, permissoes, UX states, testes esperados e o status pratico de cada fatia.

## Sequencia atual

| Spec | Status | Uso |
| --- | --- | --- |
| `003-superadmin-core.md` | approved-for-technical-spec | Escopo aprovado do Superadmin MVP. |
| `010-superadmin-completo-v1-technical-spec.md` | draft-for-review | Visao tecnica/SDD geral do Superadmin MVP; permanece como documento de desenho macro da entrega. |
| `011-superadmin-database-rls.md` | approved-for-initial-migration | Referencia aprovada da foundation de banco/RLS; gerou a migration `20260623191021_superadmin_foundation_v1.sql`, a migration incremental `20260623203230_schema_boundaries_catalog_v1.sql`, seed e validacoes SQL em `packages/coelo_database`. |

## Estado pratico

- A foundation inicial do banco do Superadmin ja possui migration versionada em `packages/coelo_database/migrations/20260623191021_superadmin_foundation_v1.sql`.
- A separacao de schemas `public`, `app_private`, `audit` e `analytics`, junto com o preenchimento amplo de `schema_tables/schema_columns`, esta versionada em `packages/coelo_database/migrations/20260623203230_schema_boundaries_catalog_v1.sql`.
- Segundo o contexto de trabalho de 2026-06-23, essa base ja foi criada no Supabase.
- Proximas alteracoes estruturais no banco devem atualizar a spec correspondente e gerar novas migrations incrementais.
- Codigo de produto Flutter, deploy e fluxos funcionais conectados ao banco continuam dependendo de specs/planos proprios antes da implementacao.
