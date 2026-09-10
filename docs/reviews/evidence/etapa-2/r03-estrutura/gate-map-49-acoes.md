---
title: "Estrutura — o que separa cada uma das 49 ações de 'verificada'"
source: "apps/superadmin/lib/app/router/superadmin_router.dart; superadmin_routes.dart; core/config/superadmin_auth_scope.dart; main.dart; packages/coelo_database/migrations; inventario-etapa-2.json"
status: "levantamento do executor do grupo estrutura, Rodada 3"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# O gate que vem antes de tudo: o router

A régua do MVP começa em "a rota normal abre sem fixture nem fail-closed". Em
`superadmin_router.dart:737` existe um `redirect` que, antes de qualquer tela,
manda toda rota de mutação de produção para `_productionMutationUnavailablePath`
quando a capacidade correspondente estiver desligada.

São três capacidades, e duas delas estão **fixadas em falso no código**:

| Capacidade | Valor real hoje | Origem |
| --- | --- | --- |
| `hasStructureMutationCapability()` | `false` | `superadmin_auth_scope.dart:375` fixa `structureMutationsEnabled: false`, com a justificativa OQ-032/OQ-043 escrita ao lado |
| `hasAssessmentMutationCapability()` | `false` | `superadmin_app_config.dart:12`, `bool.fromEnvironment('COELO_ENABLE_ASSESSMENT_MUTATIONS')` sem `defaultValue`, ou seja falso em qualquer build que não passe o define |
| `hasAuthoritativeMutationCapability(location)` | `false` para tudo que não seja `/invites`, `/notices`, `/circulars` ou o Perfil do Principal | `superadmin_router.dart:591` |

`_isStructureMutationLocation` cobre `/institutions/`, `/units/`, `/groups/` e
`/activities/`. `_isProductionMutationLocation` marca como mutação toda rota que
termine em `/new`, `/edit`, `/duplicate`, `/assessment-settings`, `/manage`, mais
`/assessments/entry` e `/assessments/closing`.

**Consequência:** hoje, num build normal, essas rotas não abrem a tela. Elas
renderizam a página de mutação indisponível. Nenhuma delas pode ser declarada
verificada, e isso independe de o SQL existir e do repositório estar composto.

## As 49 ações por gate

### Bloqueadas no router (12)

`institutions.create` (`/institutions/new`), `institutions.edit`,
`units.create` (`/units/new`), `units.edit`,
`groups.create` (`/groups/new`), `groups.edit`,
`activities.create` (`/activities/new`), `activities.edit`,
`activities.assessment` (`/activities/:id/assessment-settings`),
`assessments.entry` (`/assessments/entry`), `assessments.close`
(`/assessments/closing`), `assessments.reopen` (sob `/assessments/closing/`).

Destravar exige ligar `structureMutationsEnabled` e
`COELO_ENABLE_ASSESSMENT_MUTATIONS`. Ligar essas chaves sem o backend por trás
só troca uma indisponibilidade honesta por um erro, então a ordem é: SQL
aplicado, repositório composto, chave ligada.

### Bloqueadas na composição, mesmo sem passar pelo router (11)

Todas as ações de diretório e leitura de Unidades e Turmas:
`units.list`, `units.filter`, `units.status`, `units.error`,
`units.access-denied`, `units.reload`, `units.locations-map`,
`units.copy-institution-location`, `groups.list`, `groups.members`,
`groups.location`.

Motivo: `superadmin_auth_scope.dart:367` e `:370` compõem
`groupDirectoryRepository` e `unitDirectoryRepository` como `Unavailable*`.
`unitDetailRepository` e `groupDetailRepository`, esses sim, apontam para o
Supabase — por isso o detalhe funciona e o diretório não.

### Bloqueadas no banco (13 RPCs, ver a sonda de `pg_proc`)

`units.*` depende de treze RPCs que nenhuma migration cria. Duas delas
(`list_units_for_superadmin`, `unit_directory_filter_options`) sustentam também o
diretório de Turmas. A decisão exige leitura de catálogo em produção, que é do
coordenador.

### Adiadas por decisão (6)

`institutions.import`, `institutions.export`, `units.import`, `units.export`,
`units.people-export`, `groups.import`, `groups.export`. Import/export ficam para
depois do MVP; o botão permanece visível e honesto, sem picker, parser nem job.

### Dependentes de pacote SQL já verde, faltando aplicar e ligar (4)

`activities.location`, `groups.location`, `locations.detail-links`,
`locations.schedule`. Os três pacotes estão verdes em pgTAP local (109
asserções); falta o coordenador aplicar em produção e ligar as chaves de
composição listadas em `composition-keys.md`.

### Sem gate conhecido além da Fase 0 e da prova E2E (13)

`institutions.list`, `institutions.filter`, `institutions.detail`,
`institutions.status`, `institutions.files`, `institutions.error`,
`institutions.access-denied`, `institutions.reload`,
`institutions.locations-map`, `activities.list`, `activities.detail`,
`activities.publish`, `locations.list`, `locations.create-edit`,
`assessments.gradebook`, `assessments.detail`.

Estas têm repositório Supabase composto de verdade e não passam pelo redirect de
mutação. São as candidatas naturais a fechar primeiro na régua do MVP, assim que
a base da Fase 0 sair e houver credencial para abrir a rota normal contra
produção.

## O que isso muda para a fila do coordenador

A ordem que fecha mais ações por unidade de esforço não é a ordem das telas. É:

1. Ligar `structureMutationsEnabled` (depois do SQL e da composição) — destrava
   oito ações de uma vez.
2. Resolver as treze RPCs de Unidades — destrava Unidades e metade de Turmas.
3. Compor `SupabaseUnitDirectoryRepository` e `SupabaseGroupDirectoryRepository`
   no lugar dos `Unavailable*`.
4. Aplicar os três pacotes verdes e ligar as chaves — destrava quatro ações.
5. `COELO_ENABLE_ASSESSMENT_MUTATIONS` — destrava as quatro de Avaliações.
