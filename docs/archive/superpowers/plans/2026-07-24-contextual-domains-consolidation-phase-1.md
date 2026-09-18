---
title: "Contextual Domains Consolidation Phase 1 Implementation Plan"
source: "docs/superpowers/specs/2026-07-24-contextual-people-access-activities-attendance-design.md; remote audit of project evvbomzejfijozbtgvpt on 2026-07-24; Supabase CLI and migration documentation; Supabase CLI 2.109.1 execution evidence on 2026-07-27"
status: "ready-for-execution"
generated_at: "2026-07-27"
---

# Contextual Domains Consolidation Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the approved contextual-domain documentation and restore one
deterministic local/remote Supabase migration history without changing the
remote product schema.

**Architecture:** This phase performs no product DDL. Canonical migrations
remain in `packages/coelo_database/migrations`, while a deterministic
PowerShell helper mirrors them into the directory expected by Supabase CLI.
The official CLI may execute idempotent internal DDL in
`supabase_migrations` to ensure its ledger schema, table and columns before
repairing history; this does not authorize DDL in product schemas. The remote
migration ledger is repaired only after a before-state snapshot proves each
remote-only version has the same semantic name and order as one local-only
version; product-schema fingerprints before and after must remain identical.

**Tech Stack:** Supabase hosted project `coelo`, PostgreSQL 17.6, Supabase CLI 2.109.1, Supabase MCP, PowerShell 7-compatible scripts, Markdown.

## Global Constraints

- Remote project name: `coelo`.
- Remote project ref: `evvbomzejfijozbtgvpt`.
- Confirm the project is `ACTIVE_HEALTHY` immediately before every remote mutation.
- This phase must not execute product DDL, DML against product tables,
  `db reset`, `db push`, or `apply_migration`. The only permitted DDL is the
  idempotent internal-ledger bootstrap intrinsically executed by the official
  CLI inside `supabase_migrations` during `migration repair`.
- Repair only `supabase_migrations.schema_migrations`; verify the product schema fingerprint is unchanged.
- Never invent or rename a migration timestamp.
- Canonical versioned SQL remains in `packages/coelo_database/migrations`.
- Supabase CLI mirror files under `packages/coelo_database/supabase/migrations` are generated and must not be committed.
- Preserve every unrelated workspace change; stage only paths named in each task.
- Do not implement Admin, Principal, Superadmin, or chat UI in this phase.
- Do not expose secrets, database passwords, access tokens, CPF, or child data in reports.
- All documentation keeps frontmatter with source, status, and generation date.
- If semantic names, ordering, or fingerprints do not match the expectations below, stop before `migration repair`.

---

## Delivery Decomposition

This approved domain is too broad for one implementation plan. Execute it in
the following order:

1. **Phase 1 — this plan:** documentation alignment and migration-history
   reconciliation.
2. **Phase 2:** critical RLS, dynamic chat revocation, least-privilege grants,
   cross-tenant constraints, function hardening, FK indexes, and `updated_at`.
3. **Phase 3:** adult/child pre-registration, exact institutional discovery,
   link requests, invitation acceptance, and duplicate review.
4. **Phase 4:** reusable private trusted people and independent
   child-unit authorizations.
5. **Phase 5:** single conversation-inbox query contract, contextual chat
   creation/reuse, routing, Realtime, and revocation lifecycle.
6. **Phase 6:** partial transfers, attendance session workflows, notification
   dispatcher, reminders, and operational dashboards.

Each later phase receives its own reviewed plan and independently testable
migration set.

---

### Task 1: Make the Supabase CLI mirror deterministic

**Files:**
- Create: `packages/coelo_database/scripts/Sync-SupabaseCliMigrations.ps1`
- Create: `packages/coelo_database/supabase/config.toml`
- Modify: `.gitignore`
- Modify: `packages/coelo_database/README.md`

**Interfaces:**
- Consumes: canonical `*.sql` files from
  `packages/coelo_database/migrations`.
- Produces: an exact generated mirror in
  `packages/coelo_database/supabase/migrations` for Supabase CLI commands.

- [ ] **Step 1: Add the failing ignore/structure verification**

Run:

```powershell
$ignore = Get-Content -LiteralPath '.gitignore' -Raw
if ($ignore -notmatch [regex]::Escape('packages/coelo_database/supabase/migrations/*.sql')) {
  throw 'Supabase CLI migration mirror is not ignored'
}
if (-not (Test-Path -LiteralPath 'packages/coelo_database/supabase/config.toml')) {
  throw 'Supabase CLI project is not initialized'
}
if (-not (Test-Path -LiteralPath 'packages/coelo_database/scripts/Sync-SupabaseCliMigrations.ps1')) {
  throw 'migration sync script is missing'
}
```

Expected: FAIL with `Supabase CLI migration mirror is not ignored`.

- [ ] **Step 2: Initialize the package as a Supabase CLI project**

Run:

```powershell
npx.cmd supabase init --workdir packages/coelo_database --yes
```

Expected: `Finished supabase init.` and a new versioned
`packages/coelo_database/supabase/config.toml`. Do not use `--force`.

- [ ] **Step 3: Create the mirror script**

Create `packages/coelo_database/scripts/Sync-SupabaseCliMigrations.ps1`:

```powershell
[CmdletBinding()]
param(
  [ValidateSet('Prepare', 'Verify', 'Clean')]
  [string]$Mode = 'Prepare'
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$canonicalRoot = Join-Path $packageRoot 'migrations'
$mirrorRoot = Join-Path $packageRoot 'supabase\migrations'

$packageFull = [System.IO.Path]::GetFullPath($packageRoot)
$canonicalFull = [System.IO.Path]::GetFullPath($canonicalRoot)
$mirrorFull = [System.IO.Path]::GetFullPath($mirrorRoot)

if (-not $canonicalFull.StartsWith($packageFull, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'canonical migration directory escaped package root'
}
if (-not $mirrorFull.StartsWith($packageFull, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'CLI mirror directory escaped package root'
}

New-Item -ItemType Directory -Path $mirrorFull -Force | Out-Null

$canonical = @(
  Get-ChildItem -LiteralPath $canonicalFull -File -Filter '*.sql' |
    Sort-Object Name
)

if ($canonical.Count -eq 0) {
  throw 'no canonical migrations found'
}

if ($Mode -eq 'Clean') {
  Get-ChildItem -LiteralPath $mirrorFull -File -Filter '*.sql' |
    ForEach-Object {
      $candidate = [System.IO.Path]::GetFullPath($_.FullName)
      if (-not $candidate.StartsWith($mirrorFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "refusing to remove file outside mirror: $candidate"
      }
      Remove-Item -LiteralPath $candidate -Force
    }
  return
}

if ($Mode -eq 'Prepare') {
  & $PSCommandPath -Mode Clean
  foreach ($source in $canonical) {
    Copy-Item -LiteralPath $source.FullName -Destination (Join-Path $mirrorFull $source.Name)
  }
}

$mirror = @(
  Get-ChildItem -LiteralPath $mirrorFull -File -Filter '*.sql' |
    Sort-Object Name
)

if ($canonical.Count -ne $mirror.Count) {
  throw "migration count mismatch: canonical=$($canonical.Count) mirror=$($mirror.Count)"
}

for ($index = 0; $index -lt $canonical.Count; $index++) {
  if ($canonical[$index].Name -ne $mirror[$index].Name) {
    throw "migration name mismatch at index $index"
  }
  $sourceHash = (Get-FileHash -LiteralPath $canonical[$index].FullName -Algorithm SHA256).Hash
  $mirrorHash = (Get-FileHash -LiteralPath $mirror[$index].FullName -Algorithm SHA256).Hash
  if ($sourceHash -ne $mirrorHash) {
    throw "migration content mismatch: $($canonical[$index].Name)"
  }
}

Write-Output "Verified $($canonical.Count) canonical migrations."
```

- [ ] **Step 4: Ignore generated CLI state**

Append these exact entries to `.gitignore`:

```gitignore

# Generated Supabase CLI workspace
packages/coelo_database/supabase/.temp/
packages/coelo_database/supabase/migrations/*.sql

# Local visual brainstorming state
.superpowers/
```

- [ ] **Step 5: Document the canonical/mirror rule**

Add to `packages/coelo_database/README.md`:

```markdown
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
```

- [ ] **Step 6: Verify the mirror**

Run:

```powershell
& packages/coelo_database/scripts/Sync-SupabaseCliMigrations.ps1 -Mode Prepare
& packages/coelo_database/scripts/Sync-SupabaseCliMigrations.ps1 -Mode Verify
git status --short -- packages/coelo_database/supabase/migrations
```

Expected:

```text
Verified 18 canonical migrations.
Verified 18 canonical migrations.
```

`git status` must print nothing for the generated mirror.

- [ ] **Step 7: Commit only the CLI workflow**

```powershell
git add -- .gitignore packages/coelo_database/README.md packages/coelo_database/scripts/Sync-SupabaseCliMigrations.ps1 packages/coelo_database/supabase/config.toml
git diff --cached --check
git commit -m "chore(database): make Supabase CLI migrations deterministic"
```

---

### Task 2: Align the canonical contextual-domain documents

**Files:**
- Modify: `decisions/0015-contextual-people-authorizations-attendance.md`
- Modify: `specs/015-contextual-people-access-attendance.md`
- Modify: `docs/data/data-model.md`
- Modify: `docs/security/auth-multitenant-permissions.md`
- Modify: `docs/product/prd-app.md`
- Modify: `docs/product/prd-admin.md`
- Modify: `docs/open-questions.md`
- Modify: `docs/design/design-system.md`

**Interfaces:**
- Consumes: approved design in
  `docs/superpowers/specs/2026-07-24-contextual-people-access-activities-attendance-design.md`.
- Produces: one non-contradictory product and architecture contract for later
  migrations and apps.

- [ ] **Step 1: Capture the current contradictory statements**

Run:

```powershell
rg -n "29 tabelas|chat institucional unificado|Somente instituicao ou unidade pode cadastrar|@username.*crianca|pessoas autorizadas" decisions/0015-contextual-people-authorizations-attendance.md specs/015-contextual-people-access-attendance.md docs/data/data-model.md docs/security/auth-multitenant-permissions.md docs/product/prd-app.md docs/product/prd-admin.md docs/open-questions.md
```

Expected: at least the stale `29 tabelas` claim and earlier chat/child wording.

- [ ] **Step 2: Update ADR 0015**

Add the approved decisions:

```markdown
### Cadastro E Solicitacao De Vinculo

- Adulto pode criar conta global antes de qualquer instituicao.
- Instituicao ou unidade tambem pode iniciar convite para conta nova ou
  existente.
- Conta, e-mail ou `@identificador` nao concedem acesso por si mesmos.
- Responsavel autenticado pode localizar exatamente instituicao/unidade por
  `@`, e-mail, link ou QR e solicitar vinculo.
- A solicitacao permanece sem acesso ate validacao institucional.
- Cadastro infantil e hibrido: responsavel ou instituicao inicia; instituicao
  valida e cria seu contexto.
- A aprovacao cria primeiro o vinculo crianca-unidade; turma e opcional naquele
  momento.

### Pessoas De Confianca

- Pessoa de confianca e um registro privado e reutilizavel do responsavel.
- Cada uso cria autorizacao independente para crianca e unidade.
- Autorizacao de retirada nao pertence a turma.
- Reutilizacao entre instituicoes nunca compartilha status, suspensao ou
  visibilidade entre tenants.

### Caixa De Conversas

- `Conversas` e uma unica caixa de entrada visual.
- `Todas` e a visao padrao.
- `Instituicoes e unidades`, `Turmas` e `Atividades` sao filtros opcionais.
- Filtro de crianca pertence a um nivel separado.
- Cada conversa continua independente e contextual no banco.
```

- [ ] **Step 3: Update spec 015 and correct the verified table count**

Add states and tests for pre-registration, link request, duplicate review,
unit-without-group, trusted-person reuse, independent suspension, inbox
filtering, and dynamic revocation. Replace every claim of `29` contextual
tables with `30`.

- [ ] **Step 4: Update data, security, product, and design documents**

Apply these exact semantic rules:

```text
people = global adult/child identity
auth user = optional credential; child has none in MVP
child_context = institution-owned child context
child_unit_link = first institutional placement after approval
child_group_link = optional later allocation
trusted person = guardian-private reusable source
authorization = institution + child_context + unit independent decision
conversation inbox = aggregate query only; never a shared authorization scope
presence dot = service/team availability for collective contexts
Now ring = visual publication state around the avatar
gradient = not used in Coelo visual surfaces
```

The design-system entry must also state that presence cannot be conveyed by
color alone and needs text/semantics for accessibility.

- [ ] **Step 5: Resolve open questions without closing deferred topics**

Mark onboarding, child hybrid registration, child-unit-first placement,
trusted-person reuse, unit-level pickup authorization, and conversation inbox
organization as resolved. Keep legal retention, child login, and commercial
guardian limits open/deferred.

- [ ] **Step 6: Run the documentation consistency checks**

```powershell
rg -n "29 tabelas" decisions/0015-contextual-people-authorizations-attendance.md specs/015-contextual-people-access-attendance.md docs/data/data-model.md docs/security/auth-multitenant-permissions.md docs/product/prd-app.md docs/product/prd-admin.md docs/open-questions.md docs/design/design-system.md
rg -n "30 tabelas" specs/015-contextual-people-access-attendance.md docs/data/data-model.md docs/security/auth-multitenant-permissions.md
rg -n "TBD|TODO|FIXME" decisions/0015-contextual-people-authorizations-attendance.md specs/015-contextual-people-access-attendance.md docs/data/data-model.md docs/security/auth-multitenant-permissions.md docs/product/prd-app.md docs/product/prd-admin.md docs/open-questions.md docs/design/design-system.md
git diff --check -- decisions specs docs
```

Expected:

- no `29 tabelas` result;
- `30 tabelas` in the three implementation-status documents;
- no placeholders introduced;
- no whitespace errors.

- [ ] **Step 7: Commit only the canonical documentation**

```powershell
git add -- decisions/0015-contextual-people-authorizations-attendance.md specs/015-contextual-people-access-attendance.md docs/data/data-model.md docs/security/auth-multitenant-permissions.md docs/product/prd-app.md docs/product/prd-admin.md docs/open-questions.md docs/design/design-system.md
git diff --cached --check
git commit -m "docs: align contextual onboarding and conversation contracts"
```

---

### Task 3: Record a migration and schema baseline

**Files:**
- Create: `docs/reviews/2026-07-24-contextual-migration-history-reconciliation.md`

**Interfaces:**
- Consumes: local migration names, remote MCP migration list, PostgreSQL
  catalog.
- Produces: immutable before/after evidence for a history-only repair.

- [ ] **Step 1: Confirm the remote project**

Use Supabase `list_projects`. Assert:

```text
name = coelo
ref = evvbomzejfijozbtgvpt
status = ACTIVE_HEALTHY
region = sa-east-1
postgres = 17.6.1.127
```

Stop if any value except patch version differs.

- [ ] **Step 2: Record the expected semantic mapping**

Create the report with this frontmatter and section structure:

```markdown
---
title: "Contextual Migration History Reconciliation"
source: "Supabase project evvbomzejfijozbtgvpt; packages/coelo_database/migrations; Supabase CLI 2.109.1"
status: "baseline-recorded"
generated_at: "2026-07-24"
---

# Escopo

Reconciliar somente o ledger de migrations. Nenhuma estrutura ou dado de
produto pode mudar.

# Projeto Confirmado

# Mapeamento Semantico

# Ledger Remoto Antes

# Fingerprint Do Schema

# Advisors Antes

# Reparacao Executada

# Ledger Remoto Depois

# Testes E Advisors Depois

# Resultado
```

Write this table under `# Mapeamento Semantico`:

| Local version | Remote version before repair | Name |
| --- | --- | --- |
| 20260720103023 | 20260720133448 | institution_contact_directory_refinement |
| 20260720180000 | 20260720183531 | people_context_foundation |
| 20260720190000 | 20260720183750 | people_context_advisor_hardening |
| 20260724120307 | 20260724121904 | contextual_activities_foundation |
| 20260724122545 | 20260724122630 | contextual_activities_fk_index_hardening |
| 20260724152628 | 20260724153426 | contextual_authorization_core |
| 20260724152707 | 20260724155243 | family_authorizations_and_transfers |
| 20260724152713 | 20260724155913 | activity_governance_and_participation |
| 20260724152722 | 20260724160402 | contextual_chat_foundation |
| 20260724152731 | 20260724161043 | attendance_assiduity_foundation |
| 20260724161334 | 20260724161414 | contextual_domains_compatibility_hardening |
| 20260724161706 | 20260724161917 | contextual_domains_advisor_hardening |
| 20260724162210 | 20260724162436 | contextual_chat_lifecycle_hardening |
| 20260724162604 | 20260724162735 | contextual_chat_trigger_hardening |
| 20260724162900 | 20260724163017 | contextual_chat_audit_schema_hardening |

Also record the three already aligned versions:

```text
20260623191021 superadmin_foundation_v1
20260623203230 schema_boundaries_catalog_v1
20260717151609 institution_directory_foundation
```

- [ ] **Step 3: Query and save the remote migration ledger**

Use Supabase `execute_sql` with:

```sql
select
  version,
  name,
  coalesce(array_length(statements, 1), 0) as statement_count,
  md5(coalesce(array_to_string(statements, E'\n'), '')) as statements_md5
from supabase_migrations.schema_migrations
order by version;
```

Copy the 18 returned rows into the report. Do not copy the SQL statements.

- [ ] **Step 4: Calculate the product-schema fingerprint**

Use Supabase `execute_sql` with:

```sql
with catalog_items as (
  select 'column' as item_kind,
         table_schema || '.' || table_name || '.' || column_name || ':' ||
         data_type || ':' || is_nullable || ':' ||
         coalesce(column_default, '') as definition
  from information_schema.columns
  where table_schema in ('public', 'app_private', 'audit', 'analytics')
  union all
  select 'constraint',
         n.nspname || '.' || c.relname || '.' || con.conname || ':' ||
         pg_get_constraintdef(con.oid, true)
  from pg_constraint con
  join pg_class c on c.oid = con.conrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('public', 'app_private', 'audit', 'analytics')
  union all
  select 'policy',
         schemaname || '.' || tablename || '.' || policyname || ':' ||
         cmd || ':' || coalesce(qual, '') || ':' || coalesce(with_check, '')
  from pg_policies
  where schemaname in ('public', 'app_private', 'audit', 'analytics')
  union all
  select 'function',
         n.nspname || '.' || p.proname || '(' ||
         pg_get_function_identity_arguments(p.oid) || '):' ||
         pg_get_functiondef(p.oid)
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'app_private', 'audit', 'analytics')
)
select
  count(*) as catalog_item_count,
  md5(string_agg(item_kind || ':' || definition, E'\n'
                 order by item_kind, definition)) as schema_fingerprint
from catalog_items;
```

Record `catalog_item_count` and `schema_fingerprint` as `before`.

- [ ] **Step 5: Record baseline advisors**

Run Supabase security and performance advisors. Record only:

- issue code;
- severity;
- affected object;
- remediation URL;
- total count by category.

Do not attempt corrections in this phase.

- [ ] **Step 6: Commit the before-state report**

```powershell
git add -- docs/reviews/2026-07-24-contextual-migration-history-reconciliation.md
git diff --cached --check
git commit -m "docs: record contextual migration reconciliation baseline"
```

---

### Task 4: Reconcile the remote migration ledger

**Files:**
- Modify: `docs/reviews/2026-07-24-contextual-migration-history-reconciliation.md`

**Interfaces:**
- Consumes: exact 15-pair mapping and before fingerprint from Task 3.
- Produces: remote migration ledger using all 18 canonical local timestamps,
  with no product-schema change.

- [ ] **Step 1: Prepare the CLI migration mirror**

```powershell
& packages/coelo_database/scripts/Sync-SupabaseCliMigrations.ps1 -Mode Prepare
npx.cmd supabase --version
```

Expected: `2.109.1` and `Verified 18 canonical migrations.`

- [ ] **Step 2: Link only to the confirmed project**

```powershell
npx.cmd supabase link --project-ref evvbomzejfijozbtgvpt --workdir packages/coelo_database
```

Expected: successful link to `evvbomzejfijozbtgvpt`. Do not place the database
password in shell history, reports, or commits.

- [ ] **Step 3: Reconfirm the ledger before mutation**

Use Supabase `list_migrations`. Compare all 18 rows with Task 3. Stop if any
version or name changed.

- [ ] **Step 4: Mark the 15 remote-only versions reverted**

Run one CLI repair command:

```powershell
npx.cmd supabase migration repair 20260720133448 20260720183531 20260720183750 20260724121904 20260724122630 20260724153426 20260724155243 20260724155913 20260724160402 20260724161043 20260724161414 20260724161917 20260724162436 20260724162735 20260724163017 --status reverted --linked --workdir packages/coelo_database
```

Expected: each listed version reported as `reverted`. This changes migration
history only.

- [ ] **Step 5: Mark the 15 canonical local versions applied**

```powershell
npx.cmd supabase migration repair 20260720103023 20260720180000 20260720190000 20260724120307 20260724122545 20260724152628 20260724152707 20260724152713 20260724152722 20260724152731 20260724161334 20260724161706 20260724162210 20260724162604 20260724162900 --status applied --linked --workdir packages/coelo_database
```

Expected: each listed version reported as `applied`.

- [ ] **Step 6: Verify local and remote histories align**

```powershell
npx.cmd supabase migration list --linked --workdir packages/coelo_database
```

Expected: 18 rows with equal `LOCAL` and `REMOTE` versions and no one-sided
row.

- [ ] **Step 7: Prove no migration is pending**

```powershell
npx.cmd supabase db push --dry-run --linked --workdir packages/coelo_database
```

Expected:

```text
Remote database is up to date.
```

Do not run `db push` without `--dry-run` in this phase.

- [ ] **Step 8: Prove the product schema did not change**

Run the exact fingerprint SQL from Task 3 again. Assert:

```text
after.catalog_item_count = before.catalog_item_count
after.schema_fingerprint = before.schema_fingerprint
```

If either differs, stop, preserve all evidence, and do not begin Phase 2.

- [ ] **Step 9: Update and commit the reconciliation report**

Record:

- CLI version;
- exact repair commands;
- final 18-version list;
- before/after fingerprints;
- dry-run output;
- timestamp and project ref.

Then:

```powershell
git add -- docs/reviews/2026-07-24-contextual-migration-history-reconciliation.md
git diff --cached --check
git commit -m "docs: confirm contextual migration history reconciliation"
```

---

### Task 5: Validate the reconciled baseline

**Files:**
- Modify: `docs/reviews/2026-07-24-contextual-migration-history-reconciliation.md`

**Interfaces:**
- Consumes: aligned migration ledger from Task 4.
- Produces: test/advisor evidence and the go/no-go gate for Phase 2.

- [ ] **Step 1: Execute every existing SQL validation in a transaction**

Execute these files against `evvbomzejfijozbtgvpt` in filename order using
Supabase `execute_sql`:

```text
packages/coelo_database/tests/2026-06-23-superadmin-foundation-validation.sql
packages/coelo_database/tests/2026-06-23-schema-boundaries-catalog-validation.sql
packages/coelo_database/tests/2026-07-17-institution-directory-validation.sql
packages/coelo_database/tests/2026-07-20-institution-contact-directory-validation.sql
packages/coelo_database/tests/2026-07-20-people-context-foundation-validation.sql
packages/coelo_database/tests/2026-07-24-contextual-activities-foundation-validation.sql
packages/coelo_database/tests/2026-07-24-contextual-authorization-core-validation.sql
packages/coelo_database/tests/2026-07-24-family-authorizations-transfers-validation.sql
packages/coelo_database/tests/2026-07-24-activity-governance-participation-validation.sql
packages/coelo_database/tests/2026-07-24-contextual-chat-validation.sql
packages/coelo_database/tests/2026-07-24-attendance-assiduity-validation.sql
```

Expected: all 11 scripts complete successfully and roll back their fixtures.

- [ ] **Step 2: Re-run advisors**

Run Supabase security and performance advisors. The issue counts must be equal
to the Task 3 baseline because no product DDL occurred; the CLI's idempotent
ledger bootstrap is confined to `supabase_migrations`. Any difference blocks
Phase 2 until explained.

- [ ] **Step 3: Verify the remote structural baseline directly**

Use Supabase `execute_sql`:

```sql
select
  count(*) filter (where table_schema = 'public') as public_tables,
  count(*) filter (where table_schema = 'audit') as audit_tables,
  count(*) filter (where table_schema = 'analytics') as analytics_tables
from information_schema.tables
where table_type = 'BASE TABLE'
  and table_schema in ('public', 'audit', 'analytics');

select count(*) as rls_tables
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r'
  and c.relrowsecurity
  and n.nspname in ('public', 'audit', 'analytics');

select count(*) as contextual_catalog_tables
from public.schema_tables
where table_name in (
  'family_relationship_types',
  'guardian_permission_capabilities',
  'authorized_people',
  'authorized_person_authorizations',
  'activity_group_participants',
  'conversation_participants',
  'attendance_sessions'
);
```

Record the returned counts without claiming that logical gaps are fixed.

- [ ] **Step 4: Add the Phase 2 go/no-go statement**

The report may say `GO` only if:

- all 18 migration versions align;
- schema fingerprints match;
- all 11 SQL scripts pass;
- advisor counts are unchanged;
- project remains `ACTIVE_HEALTHY`;
- no unrelated file was staged or committed.

- [ ] **Step 5: Commit the final evidence**

```powershell
git add -- docs/reviews/2026-07-24-contextual-migration-history-reconciliation.md
git diff --cached --check
git commit -m "test(database): validate reconciled contextual baseline"
```
