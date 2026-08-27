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
- `tests/2026-07-29-superadmin-people-directory-validation.sql`

## Diretório de Pessoas do Superadmin

- `migrations/20260729141839_superadmin_people_directory.sql`
- `migrations/20260729153000_superadmin_people_directory_policy_hardening.sql`
- `migrations/20260729153100_child_context_lifecycle_trigger_hardening.sql`
- `supabase/tests/superadmin_people_directory_test.sql`

A migration adiciona as permissões `people.*`, mantém o grant inicial somente
no Owner e expõe RPCs compatíveis com o repositório Flutter. Criação permanece
em draft, sem Auth; edição usa `expected_updated_at` e patches de vínculos. A
aplicação remota fica bloqueada até reset/dry-run, testes transacionais,
advisors e revisão explícita de autorização.

## Perfis e Permissões

- `migrations/20260729144440_profiles_permissions_governance.sql`
- `supabase/tests/profiles_permissions_governance_test.sql`

A migration adiciona escopo máximo e versão otimista aos perfis Superadmin e
Admin, remove o bypass implícito do Owner, aplica `deny` antes de `allow` e
expõe as cinco RPCs auditadas da central. As permissões
`platform.roles.manage` e `institution.roles.manage` nascem somente no Owner.
O catálogo do Principal permanece contextual e somente leitura.

A aplicação remota permanece bloqueada até reset local, pgTAP, revisão dos
advisors e aprovação explícita; nenhum comando desta entrega grava no projeto
remoto.

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

Replays locais completos que alcancem a migration historica de Grupos devem ser
executados por `Invoke-SafeLocalMigrationReplay.ps1`. O wrapper cria projeto,
identidade Docker e portas descartaveis fora do repositorio, prepara um
preflight imediatamente antes de Grupos, executa somente `db reset --local` e
remove a stack e o staging no teardown. Ele serializa execucoes locais e fixa o
Supabase CLI 2.116.0 validado neste historico. Exemplo:

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260812001975
```

Nunca use
`Prepare-SafeMigrationReplay.ps1` diretamente em operacoes normais, nem use o
staging com `db push`, `migration repair` ou qualquer comando remoto. As
migrations sinteticas do replay nao pertencem ao ledger remoto.

Novas migrations nascem com `npx supabase migration new <nome>
--workdir packages/coelo_database`; o arquivo gerado deve ser movido para
`migrations/` sem alterar o timestamp.
