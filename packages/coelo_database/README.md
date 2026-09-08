---
title: coelo_database
source: specs/011-superadmin-database-rls.md; packages/coelo_database/scripts; packages/coelo_database/replay/foundation-migrations.sha256
status: active
generated_at: 2026-09-07
---

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

Quando o objetivo for somente a fundacao interna aprovada, use
`-FoundationOnly`. Esse perfil usa o manifesto fechado e verificado por hash
`replay/foundation-migrations.sha256`: 67 migrations canônicas aprovadas e dois
preflights locais. O perfil inclui as bases Acontece/Circulares e os gateways internos
v2 de Comunicação; as oito migrations de produto explicitamente negadas e
qualquer migration futura não entram automaticamente. O alvo deve ser a última
versão do manifesto, impedindo teardown com o bridge de replay ainda ativo.
`Test-FoundationReplayProfile.ps1` valida contagem, limites, hashes e a lista
negativa. `-TestPath` aceita somente arquivos `.sql`, sem reparse point, abaixo
de `supabase/tests` e executa pgTAP antes do teardown:

Os SHA-256 do manifesto usam o texto UTF-8 normalizado para CRLF. Assim, um
checkout Git com LF ou CRLF produz a mesma prova, enquanto qualquer mudança no
SQL continua alterando o hash e bloqueando o replay.

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901200206 `
  -FoundationOnly `
  -TestPath packages/coelo_database/supabase/tests/superadmin_internal_auth_context_test.sql
```

Para Auth, use `-AuthOnly`: o perfil seleciona 45 migrations canônicas e os
dois preflights, com alvo obrigatório `20260901200206`. Os perfis
`-AuthOnly` e `-FoundationOnly` são mutuamente exclusivos.
Use `-RunAuthLifecycle` com `-AuthOnly` quando for necessário provar o ciclo
real do Supabase Auth. Esse modo mantém GoTrue, PostgREST, Kong e Mailpit na stack isolada,
executa cadastro sintético, login por senha, bootstrap do contexto interno,
refresh, logout e rejeição imediata da sessão revogada. E-mail, senha e tokens
existem apenas em memória; a fixture fica confinada ao volume descartável e o
wrapper confirma zero recurso Docker residual no teardown:

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901200206 `
  -AuthOnly `
  -TestPath packages/coelo_database/supabase/tests/superadmin_internal_auth_context_test.sql `
  -RunAuthLifecycle
```

Adicione `-RunLint` para executar `supabase db lint --local` no mesmo banco
descartavel antes do teardown. Erros fazem o wrapper falhar; warnings ficam
visiveis para classificacao do delta.

Para reproduzir somente os pré-requisitos históricos de Avisos, o seletor
`-NominalProfile N01PrerequisitesRed` fixa Auth45, cinco migrations canônicas
de Avisos e os dois preflights herdados: 52 arquivos, alvo `20260901200206`.
O descriptor em `replay/profiles/N01PrerequisitesRed/profile.json` e todos
os inputs são conferidos por SHA-256 normalizado antes de staging ou Docker.
O modo rejeita combinações com `AuthOnly`, `FoundationOnly`,
`AdditionalMigration`, `RunAuthLifecycle` e `RunActivityV2Concurrency`.

Esse perfil é um diagnóstico local: a falha esperada é `42P01` na migration
`20260812003000_notices_production.sql`, que exige `public.notice_events`
depois de a fronteira canônica ter movido a tabela para `analytics`.
Não acrescenta pontes nem a correção final de publicação. Uma execução que
registre esse erro comprova o pré-requisito ausente; não valida Avisos ponta a ponta.

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901200206 `
  -NominalProfile N01PrerequisitesRed
```

Para o RED do contrato do diretório de Atividades,
`-NominalProfile A01DirectoryContractRed` seleciona Auth45 e as sete migrations
Activities v2 entre `20260831192831` e `20260831234307`, mais os dois preflights:
54 arquivos, alvo `20260901200206`. O descriptor fechado fica em
`replay/profiles/A01DirectoryContractRed/profile.json`; os mesmos guards
nominais preservam hashes, nomes, contagem, alvo e confinamento.

A base não inclui a corretiva `20260907222911` nem pontes adicionais.
A fixture do contrato deve ser conferida pelo hash aprovado, executar os RPCs
como `authenticated` e emitir TAP depois de `RESET ROLE`. O replay da base
e o resultado desse teste são evidências distintas; a ausência de
`superadmin_activity_filter_options_v2` e os demais desvios do contrato
são o RED funcional esperado antes da corretiva.

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901200206 `
  -NominalProfile A01DirectoryContractRed `
  -TestPath packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_directory_contract_test.sql
```

Para reproduzir a base do diretório interno de Formulários,
`-NominalProfile FReadDirectoryContractRed` fixa Auth45, as duas migrations
Forms `20260813155005`/`20260813155116` e o helper institucional
`20260827235500`, mais os dois preflights: 50 arquivos, alvo
`20260901200206`. O descriptor fechado fica em
`replay/profiles/FReadDirectoryContractRed/profile.json`.

O replay real dessa base registra `42601` em
`20260813155005_forms_definition_and_capabilities.sql`, durante a criação de
`form_item_config_valid`, antes do target e da fixture. Esse resultado é um
bloqueio de sintaxe histórico; não demonstra o contrato do reader. O perfil
preserva os bytes canônicos e não inclui o reader futuro `20260908000049`
nem uma adaptação implícita para contornar a falha.

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901200206 `
  -NominalProfile FReadDirectoryContractRed `
  -TestPath packages/coelo_database/supabase/tests/superadmin_forms_directory_internal_read_test.sql
```

A seleção preparada `-NominalProfile FReadDirectoryContractGreen` acrescenta
somente o reader auditado `20260908000049` à base50: 51 arquivos, com target
único `20260908000049`. O nome não indica validação funcional: essa seleção
canônica continua sujeita ao `42601` histórico descrito acima. Sua execução
não foi realizada. O tratamento de uma base local derivada é um pacote
nominal separado, com hashes e aprovação próprios.

Nunca use
`Prepare-SafeMigrationReplay.ps1` diretamente em operacoes normais, nem use o
staging com `db push`, `migration repair` ou qualquer comando remoto. As
migrations sinteticas do replay nao pertencem ao ledger remoto.

Novas migrations nascem com `npx supabase migration new <nome>
--workdir packages/coelo_database`; o arquivo gerado deve ser movido para
`migrations/` sem alterar o timestamp.
