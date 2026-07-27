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
- `tests/2026-07-24-contextual-authorization-core-validation.sql`
- `tests/2026-07-24-family-authorizations-transfers-validation.sql`
- `tests/2026-07-24-activity-governance-participation-validation.sql`
- `tests/2026-07-24-contextual-chat-validation.sql`
- `tests/2026-07-24-attendance-assiduity-validation.sql`

Fundacao de Atividades Contextuais:

- `migrations/20260724120307_contextual_activities_foundation.sql`
- `migrations/20260724122545_contextual_activities_fk_index_hardening.sql`

## Dominios Contextuais 2026-07-24

A fundacao remota de autorizacao, familia, atividades, chat e assiduidade foi
aplicada ao projeto `coelo` (`evvbomzejfijozbtgvpt`). As migrations locais
foram geradas pelo Supabase CLI e cobrem:

- autorizacao contextual, deny individual e atribuicao profissional-crianca;
- catalogo familiar, pessoas autorizadas e transferencia entre unidades;
- governanca, promocao e participacao individual em atividades;
- chat contextual, equipes, snapshots de autoria e historico somente leitura;
- avisos familiares, presenca oficial, revisoes e agregados de assiduidade;
- compatibilidade, indices de FKs e endurecimento de policies/triggers.

O historico remoto foi reconciliado em 2026-07-27 pelo fluxo oficial de
`supabase migration repair`. As 19 versoes e nomes remotos agora coincidem com
as migrations canonicas locais, e `supabase db push --dry-run` informa que o
banco remoto esta atualizado. O repair alterou somente o ledger interno de
migrations; detalhes e fingerprints antes/depois estao em
`docs/reviews/2026-07-24-contextual-migration-history-reconciliation.md`.

## Fluxo Oficial Do Supabase CLI

`migrations/` e a fonte canonica versionada. Antes de comandos CLI que leem
migrations, execute:

```powershell
& packages/coelo_database/scripts/Sync-SupabaseCliMigrations.ps1 -Mode Prepare
```

O script copia e verifica nomes e SHA-256 em
`supabase/migrations/`, diretorio gerado e ignorado pelo Git. Depois do comando
CLI, a limpeza opcional e:

```powershell
& packages/coelo_database/scripts/Sync-SupabaseCliMigrations.ps1 -Mode Clean
```

Novas migrations nascem com `npx supabase migration new <nome>
--workdir packages/coelo_database`; o arquivo gerado deve ser movido para
`migrations/` sem alterar o timestamp.
