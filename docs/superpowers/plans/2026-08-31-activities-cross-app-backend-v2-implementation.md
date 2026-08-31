---
title: "Activities cross-app backend v2 implementation plan"
source: "docs/superpowers/specs/2026-08-31-activities-cross-app-backend-v2-design.md; decisions/0014-contextual-activities-and-delegated-unit-creation.md; decisions/0019-superadmin-internal-identity.md; decisions/0022-superadmin-activities-and-identity-storage.md; specs/014-atividade-contextual.md; specs/039-superadmin-internal-auth-session-context.md; Owner approval 2026-08-31"
status: "approved-execution-plan"
generated_at: "2026-08-31"
---

# Activities Cross-App Backend v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a locally reproducible Activities backend for internal Superadmin list/create/detail/edit/publish, including advanced participants, professionals, granular permissions, RLS and tenant A/B, while preserving Admin legacy behavior and preparing—not authorizing—future Principal access.

**Architecture:** Public Activity entities and actor-agnostic invariants are shared, but each actor realm has nominal gateways. Superadmin v2 resolves only the private internal identity/session context; legacy Admin remains people-based; Principal receives no new endpoint or grant. Four forward-only migrations separate public provenance, private receipts/permissions, internal gateways, and final ACL/RLS closure.

**Tech Stack:** PostgreSQL 15, Supabase CLI 2.116.0 through `npx.cmd`, pgTAP, PL/pgSQL, PowerShell replay harness, Docker only for disposable local proof.

## Global Constraints

- Work only in `C:\Users\adrie\Documents\Coelo\.worktrees\supabase-cross-app-foundation` on `codex/supabase-cross-app-foundation`.
- Do not change `apps/**`, Flutter, UI/UX, `packages/coelo_ui_*`, import/export, files, uploads, downloads, Storage, media or Edge Functions.
- Preserve the active visual worktree and all user changes; do not merge, push or mutate `dev` during these tasks.
- Remote project `coelo` remains `blocked-environment` and read-only. No remote DDL, DML, Auth configuration, migration or deploy.
- Create every migration with `npx.cmd --yes supabase@2.116.0 migration new`; never invent or edit a timestamp manually.
- Never edit a migration applied remotely. These new migrations are local-only and forward-only.
- TDD is mandatory: focused RED on the preceding green target, minimal migration, focused GREEN, accumulated regression, then commit.
- Superadmin authorization uses only spec-039 internal identity/session context. Never call `current_person_id()`, `has_platform_permission()`, `platform_memberships`, `user_metadata` or a synthetic `people` row from v2.
- Public rows expose only generated `actor_kind`; exact internal identity stays in private receipt/audit.
- All privileged functions use `SECURITY DEFINER`, owner `postgres`, `search_path=''`, explicit ACLs and nominal public wrappers.
- Error envelopes, receipts and audit must not contain JWT, session ID raw, names, descriptions, child/person IDs, memberships, payloads, secrets or PII.
- A command accepts untrusted IDs/filters only to narrow scope; tenant B and random UUIDs use indistinguishable domain errors.
- Flutter, E2E, `remote-green` and `done` remain unchanged without their own proofs.

## File Map

Create tests:

- `packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_actor_contract_test.sql`
- `packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_security_contract_test.sql`
- `packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_read_test.sql`
- `packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_commands_test.sql`
- `packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_relationships_test.sql`
- `packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_permissions_publish_test.sql`

Create harness:

- `packages/coelo_database/scripts/Test-ActivityV2Concurrency.ps1`

Modify harness/profile:

- `packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1`
- `packages/coelo_database/scripts/Test-FoundationReplayProfile.ps1`
- `packages/coelo_database/replay/foundation-migrations.sha256`

Create via CLI, retaining the CLI-generated timestamp exactly:

- `packages/coelo_database/migrations/*_activities_v2_actor_attribution.sql`
- `packages/coelo_database/migrations/*_activities_v2_permissions_receipts.sql`
- `packages/coelo_database/migrations/*_activities_v2_internal_gateways.sql`
- `packages/coelo_database/migrations/*_activities_v2_rls_grants.sql`

Generate/verify only through the existing sync script:

- `packages/coelo_database/supabase/migrations/**`

Update after backend evidence:

- `docs/superpowers/specs/2026-08-31-activities-cross-app-backend-v2-design.md`
- `docs/open-questions.md`
- `decisions/0022-superadmin-activities-and-identity-storage.md`
- `docs/reviews/coelo-supabase-pendencias.md`
- `docs/reviews/coelo-flutter-integrado-supabase-pendencias.md`
- `docs/reviews/2026-08-31-worktree-commit-consolidation-ledger.md`

---

### Task 1: Actor provenance without leaking internal identities

**Files:**
- Create: `packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_actor_contract_test.sql`
- Create via CLI: `packages/coelo_database/migrations/*_activities_v2_actor_attribution.sql`
- Modify: `packages/coelo_database/replay/foundation-migrations.sha256`
- Modify: `packages/coelo_database/scripts/Test-FoundationReplayProfile.ps1`

**Interfaces:**
- Consumes: existing Activity tables and spec-039 `require_superadmin_internal_context` contract.
- Produces: generated `*_actor_kind`, guarded nullable people actor fields, and legacy-safe provenance consumed by later commands.

- [ ] **Step 1: Write the 26-assertion actor RED**

Start the file with the actual structural contract below, then add behavioral fixtures for a people actor, an internal marker, a forged NULL actor and a mismatched person. The transaction must end with `finish()` and `rollback`.

```sql
begin;
create extension if not exists pgtap with schema extensions;
select plan(26);
select has_column('public','activity_definitions','created_by_actor_kind');
select has_column('public','activity_unit_links','linked_by_actor_kind');
select has_column('public','activity_group_links','linked_by_actor_kind');
select has_column('public','activity_group_participants','added_by_actor_kind');
select has_column('public','activity_group_assignments','assigned_by_actor_kind');
select has_column('public','activity_admin_assignments','assigned_by_actor_kind');
select has_column('public','activity_assignment_capability_actions','changed_by_actor_kind');
select has_column('public','activity_capability_policies','changed_by_actor_kind');
select has_column('public','activity_group_capability_settings','changed_by_actor_kind');
select ok(not exists(select 1 from information_schema.columns
  where table_schema='public' and column_name like '%internal_identity_id'),
  'public Activity tables do not expose internal identity ids');
select results_eq($$select count(*)::bigint from information_schema.columns
 where table_schema='public' and column_name like '%_by_actor_kind'
   and is_generated='ALWAYS'$$, array[9::bigint], 'nine generated actor kinds');
select results_eq($$select count(*)::bigint from information_schema.columns
 where table_schema='public' and column_name in
 ('created_by_person_id','linked_by_person_id','added_by_person_id',
  'assigned_by_person_id','changed_by_person_id') and is_nullable='YES'$$,
 array[9::bigint], 'nine actor fields accept the internal path');
select has_function('app_private','guard_activity_v2_actor_provenance',array[]::text[]);
select has_function('app_private','require_activity_v2_internal_marker',array[]::text[]);
select results_eq($$select count(*)::bigint from pg_trigger t join pg_proc p on p.oid=t.tgfoid
 where not t.tgisinternal and p.proname='guard_activity_v2_actor_provenance'$$,
 array[9::bigint], 'guard attached to every dual actor table');
select has_index('public','activity_assignment_capability_actions',
 'activity_assignment_capability_actions_changed_by_person_idx');
select has_index('public','activity_admin_assignments',
 'activity_admin_assignments_assigned_by_person_idx');
select function_owner_is('app_private','guard_activity_v2_actor_provenance',array[]::text[],'postgres');
select function_owner_is('app_private','require_activity_v2_internal_marker',array[]::text[],'postgres');
select ok(pg_get_functiondef('app_private.guard_activity_v2_actor_provenance()'::regprocedure)
 like '%require_activity_v2_internal_marker%', 'null person requires validated marker');
select ok(pg_get_functiondef('app_private.require_activity_v2_internal_marker()'::regprocedure)
 like '%auth.sessions%', 'marker revalidates the live Auth session');
select ok(not has_function_privilege('authenticated',
 'app_private.guard_activity_v2_actor_provenance()','EXECUTE'),'guard is private');
select ok(not has_function_privilege('service_role',
 'app_private.require_activity_v2_internal_marker()','EXECUTE'),'marker helper is private');
select ok(pg_get_functiondef('app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
 like '%current_person_id%' and pg_get_functiondef(
 'app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
 not like '%superadmin_internal%', 'legacy aggregate stays people-based');
select ok(not exists(select 1 from public.activity_group_assignments
 where assignment_role='activity_admin' and created_at >= transaction_timestamp()),
 'v2 never creates group-scoped activity admins');
select ok(not exists(select 1 from public.activity_definitions
 where created_by_person_id is not null and created_by_actor_kind<>'person'),
 'legacy rows derive person provenance');
select * from finish();
rollback;
```

- [ ] **Step 2: Run the actor test against the preceding green target**

Run:

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260831164937 -FoundationOnly `
  -TestPath packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_actor_contract_test.sql
```

Expected: RED because `created_by_actor_kind` and the other generated provenance columns do not exist. The wrapper must still report zero residual `coelo_safe_*` resources.

- [ ] **Step 3: Create and relocate the migration using the pinned CLI**

```powershell
$mirrorRoot = [IO.Path]::GetFullPath('packages/coelo_database/supabase/migrations')
$canonicalRoot = [IO.Path]::GetFullPath('packages/coelo_database/migrations')
$before = @(Get-ChildItem -LiteralPath $mirrorRoot -File -Filter '*.sql').FullName
npx.cmd --yes supabase@2.116.0 migration new activities_v2_actor_attribution --workdir packages/coelo_database
if ($LASTEXITCODE -ne 0) { throw 'Supabase CLI failed to create actor migration' }
$generated = @(Get-ChildItem -LiteralPath $mirrorRoot -File -Filter '*_activities_v2_actor_attribution.sql' |
  Where-Object { $_.FullName -notin $before })
if ($generated.Count -ne 1) { throw 'actor migration was not created exactly once' }
$destination = [IO.Path]::GetFullPath((Join-Path $canonicalRoot $generated[0].Name))
if (-not $destination.StartsWith($canonicalRoot + [IO.Path]::DirectorySeparatorChar)) { throw 'migration escaped canonical root' }
Move-Item -LiteralPath $generated[0].FullName -Destination $destination
```

- [ ] **Step 4: Implement generated actor provenance and guard triggers**

The migration must make the nine approved people actor fields nullable, add generated stored kinds, backfill implicitly from the existing non-null person values, and install one private guard trigger function on all touched tables.

```sql
alter table public.activity_definitions
  alter column created_by_person_id drop not null,
  add column created_by_actor_kind text generated always as
    (case when created_by_person_id is null then 'superadmin_internal' else 'person' end) stored;

create function app_private.guard_activity_v2_actor_provenance()
returns trigger language plpgsql security definer set search_path = '' as $$
declare resolved_person uuid;
begin
  resolved_person := app_private.current_person_id();
  if to_jsonb(new)->>tg_argv[0] is null then
    perform app_private.require_activity_v2_internal_marker();
  elsif resolved_person is null
     or (to_jsonb(new)->>tg_argv[0])::uuid <> resolved_person then
    raise insufficient_privilege using message = 'activity actor provenance denied';
  end if;
  return new;
end $$;
```

Apply the equivalent generated column and trigger to unit links, group links, participants, instructor assignments, admin assignments, instructor actions, policies and group settings. The internal marker helper must revalidate spec-039 identity/auth-link/session and may not trust only `current_setting`. Add missing indexes on `activity_assignment_capability_actions.changed_by_person_id` and `activity_admin_assignments.assigned_by_person_id`. Reject new group-assignment role `activity_admin` while allowing updates that only revoke historical rows.

- [ ] **Step 5: Add normalized SHA-256 to the foundation profile and run GREEN**

Append the exact generated filename and normalized CRLF SHA-256 using the same `Get-NormalizedTextSha256` algorithm already present in `Test-FoundationReplayProfile.ps1`. Change the expected count from 52 to 53 and final boundary to the generated filename.

Run mirror Prepare/Verify, the profile test and the focused replay at the generated 14-digit version. Expected: 26/26 GREEN and profile 53/53.

- [ ] **Step 6: Commit the actor slice**

```powershell
rtk git add packages/coelo_database/migrations packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_actor_contract_test.sql packages/coelo_database/replay/foundation-migrations.sha256 packages/coelo_database/scripts/Test-FoundationReplayProfile.ps1
rtk git commit -m "feat(database): type activities v2 authorship"
```

---

### Task 2: Private receipts, admin actions and stable errors

**Files:**
- Create: `packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_security_contract_test.sql`
- Create via CLI: `packages/coelo_database/migrations/*_activities_v2_permissions_receipts.sql`
- Modify: foundation manifest/profile.

**Interfaces:**
- Consumes: Task 1 actor provenance and spec-039 internal identities.
- Produces: `activity_admin_capability_actions`, private receipts, canonical request hashing and Activity error envelopes.

- [ ] **Step 1: Write and prove the 30-assertion security RED**

Assert the new table/receipt/helper absence, then exact owners, ACLs, FORCE RLS, 32-byte hash constraint, FK indexes, no PII columns, error allowlist and deterministic hash. Run against Task 1 target; expected RED at `activity_admin_capability_actions` absence.

- [ ] **Step 2: Create `activities_v2_permissions_receipts` with the CLI relocation procedure from Task 1**

Expected: one timestamped canonical file and no manually constructed timestamp.

- [ ] **Step 3: Implement the physical contracts**

```sql
create table public.activity_admin_capability_actions (
  id uuid primary key default gen_random_uuid(),
  activity_admin_assignment_id uuid not null references public.activity_admin_assignments(id) on delete cascade,
  capability_id uuid not null references public.activity_capabilities(id) on delete restrict,
  can_view boolean not null,
  can_edit boolean not null,
  changed_by_person_id uuid references public.people(id) on delete restrict,
  changed_by_actor_kind text generated always as
    (case when changed_by_person_id is null then 'superadmin_internal' else 'person' end) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(activity_admin_assignment_id, capability_id)
);

create table app_private.superadmin_internal_activity_command_receipts (
  request_id uuid primary key,
  internal_identity_id uuid not null references app_private.superadmin_internal_identities(id) on delete restrict,
  institution_id uuid not null references public.institutions(id) on delete restrict,
  activity_id uuid,
  command_kind text not null,
  request_hash bytea not null check (octet_length(request_hash)=32),
  resulting_version bigint,
  resulting_status text,
  correlation_id uuid not null,
  result_counts jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
```

Add command-kind allowlist for the eight mutation wrappers, exact indexes, owner `postgres`, FORCE RLS and zero client grants. Implement `activity_v2_error_envelope` with only `code/message/http_status/correlation_id` and the approved 422/404/409 mappings. Implement canonical SHA-256 over command kind, institution, activity, expected version and normalized payload; never store the payload.

- [ ] **Step 4: Update profile to 54, mirror, run 30/30 GREEN and accumulated Task 1 regression**

Expected: both new test files GREEN, legacy schema unchanged, no new lint error in this delta.

- [ ] **Step 5: Commit**

```powershell
rtk git commit -m "feat(database): add activities v2 permissions receipts"
```

---

### Task 3: Internal read and command gateways

**Files:**
- Create: four remaining pgTAP files listed in File Map.
- Create via CLI: `packages/coelo_database/migrations/*_activities_v2_internal_gateways.sql`
- Modify: foundation manifest/profile.

**Interfaces:**
- Consumes: Tasks 1–2 provenance, receipt, error and spec-039 context.
- Produces: the exact eleven v2 wrappers from the approved design and private actor-specific apply helpers.

- [ ] **Step 1: Write focused REDs before the migration**

Use these exact plan counts:

- read: `plan(28)`;
- commands: `plan(28)`;
- relationships: `plan(24)`;
- permissions/publish: `plan(18)`.

Each test creates only synthetic tenant A/B fixtures in a transaction. Include unauthenticated, expired session, revoked link, Owner AAL1, capability inactive/deny, institutional scope, people-only cross-app, sibling unit, random UUID and tenant B negatives. Run all four against Task 2 target. Expected: RED because the first v2 read signature is absent.

- [ ] **Step 2: Create `activities_v2_internal_gateways` using the pinned CLI**

- [ ] **Step 3: Implement context, scope, marker and audit helpers first**

Private helpers must accept the private spec-039 context type, never a caller-constructible generic actor. Validate all requested permissions independently and revalidate identity/auth-link/JWT session/auth.sessions before each command and replay. Install a transaction-local marker containing identity/action/permission/correlation; `audit_activity_change()` suppresses legacy v1 only after independently revalidating it. Every accepted mutation appends one minimized internal domain audit before receipt; audit failure rolls back everything.

- [ ] **Step 4: Implement exact read wrappers and allowlisted builders**

```sql
-- Signatures are binding; bodies return the approved {ok,data,error} jsonb.
public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean)
public.superadmin_activity_detail_v2(uuid,text[])
public.superadmin_activity_form_options_v2(uuid,text[],text,integer)
```

Directory filters/sorts/limits, detail sections and form-option sections must match the design literally. Builders construct named JSON keys; `to_jsonb(row)` is forbidden. Requested sensitive sections require `assign_people` or `manage_permissions` and fail whole-call when unauthorized.

- [ ] **Step 5: Implement create/update/publish and structure wrappers**

```sql
public.superadmin_activity_create_v2(uuid,jsonb)
public.superadmin_activity_update_v2(uuid,uuid,bigint,jsonb)
public.superadmin_activity_publish_v2(uuid,uuid,bigint)
public.superadmin_activity_set_units_v2(uuid,uuid,bigint,uuid[])
public.superadmin_activity_set_groups_v2(uuid,uuid,bigint,uuid[],jsonb)
```

All commands follow: reauthorize → advisory request lock → receipt check → activity `FOR UPDATE` → version check → reference locks → one atomic mutation → exactly one version increment → audit → receipt. Create forces institution origin and atomically links at least one unit. Unit/group removals fail while active dependencies remain. Publish accepts only draft with valid taxonomy, unit, group, relations and explicit actions.

- [ ] **Step 6: Implement participant, professional and permission snapshots**

```sql
public.superadmin_activity_set_participants_v2(uuid,uuid,bigint,jsonb)
public.superadmin_activity_set_professionals_v2(uuid,uuid,bigint,jsonb)
public.superadmin_activity_set_permissions_v2(uuid,uuid,bigint,jsonb,jsonb,jsonb)
```

Apply the literal schemas/cardinality from the design. Derive children through active child-group → child-unit → child-context. Derive adult professionals only from active same-institution memberships. A revoked assignment is never reactivated. Omitted action/settings entries clear stale permissions. Enforce the approved prohibited/legacy-deny/action/legacy-allow/required/setting/default/profile precedence; `required` rejects explicit `none`.

- [ ] **Step 7: Close private/public function ACLs inside this migration**

Before commit, revoke every new helper/wrapper from `PUBLIC, anon, authenticated, service_role`; Task 4 later grants only nominal public wrappers after final RLS verification. This prevents a permissive intermediate migration.

- [ ] **Step 8: Update profile to 55 and run accumulated GREEN**

Expected: the six v2 pgTAP files total 154/154; Tasks 1–2 remain GREEN; no synthetic person, no actor-null audit, no second version bump or audit on replay.

- [ ] **Step 9: Commit**

```powershell
rtk git commit -m "feat(database): add internal activities v2 gateways"
```

---

### Task 4: RLS/ACL closure and real concurrency

**Files:**
- Create via CLI: `packages/coelo_database/migrations/*_activities_v2_rls_grants.sql`
- Create: `packages/coelo_database/scripts/Test-ActivityV2Concurrency.ps1`
- Modify: `packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1`
- Modify: foundation manifest/profile.

**Interfaces:**
- Consumes: all Task 3 wrappers.
- Produces: final authenticated-only public execution surface, reproducible two-session concurrency proof and profile target 56.

- [ ] **Step 1: Extend the existing security test with the final ACL/RLS RED**

Prove public wrappers currently lack authenticated EXECUTE, then assert final owners/search paths, no helper execution, no anon/service-role/public access, FORCE RLS, safe default privileges, people-policy isolation and FK/predicate indexes.

- [ ] **Step 2: Create and implement `activities_v2_rls_grants`**

Revoke all helper access again, grant EXECUTE only on the eleven nominal public wrappers to `authenticated`, retain legacy people-based grants required by Admin, and prove an internal account cannot pass them. Do not add `OR internal` to legacy policies. Set safe default function privileges and qualify every schema reference.

- [ ] **Step 3: Add the two-session concurrency harness**

Add `-RunActivityV2Concurrency` to the wrapper. The new script must receive the disposable project root/identity, open two independent SQL sessions against the generated local database, issue the same expected version concurrently with distinct request IDs, and assert exactly one successful version increment plus one `SAI_CONCURRENT_CHANGE`, no deadlock and no leaked credentials/output. Fixtures live only in the disposable volume.

- [ ] **Step 4: Update profile to 56 and run the final local gate**

```powershell
$tests = @(
 'packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_actor_contract_test.sql',
 'packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_security_contract_test.sql',
 'packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_read_test.sql',
 'packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_commands_test.sql',
 'packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_relationships_test.sql',
 'packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_permissions_publish_test.sql',
 'packages/coelo_database/supabase/tests/superadmin_internal_auth_context_test.sql',
 'packages/coelo_database/supabase/tests/activity_management_end_to_end_test.sql',
 'packages/coelo_database/supabase/tests/public_client_privileges_test.sql',
 'packages/coelo_database/supabase/tests/default_function_execute_privileges_test.sql',
 'packages/coelo_database/supabase/tests/superadmin_people_directory_test.sql'
)
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion $finalVersion -FoundationOnly -TestPath $tests -RunActivityV2Concurrency
```

Expected: all v2 assertions and compatible regressions GREEN; one concurrency winner; zero Docker residual.

- [ ] **Step 5: Run lint separately and classify, never hide, historical errors**

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion $finalVersion -FoundationOnly -TestPath $tests -RunLint
```

Expected: no new Activity v2 lint error. The four already documented import/export/file errors may keep the global lint RED; record exact unchanged signatures and do not edit those products.

- [ ] **Step 6: Run Auth lifecycle, mirror, profile, secret and diff gates**

```powershell
& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion $finalVersion -FoundationOnly -RunAuthLifecycle
& packages/coelo_database/scripts/Test-FoundationReplayProfile.ps1
& packages/coelo_database/scripts/Sync-SupabaseCliMigrations.ps1 -Mode Prepare
& packages/coelo_database/scripts/Sync-SupabaseCliMigrations.ps1 -Mode Verify
rtk git grep -n -E "X-Amz-Signature|sk-[A-Za-z0-9_-]{20,}|github_pat_|ghp_|SUPABASE_SERVICE_ROLE_KEY=.{12,}|R2_SECRET_ACCESS_KEY=.{24,}" -- ':!docs/**' ':!specs/**' ':!decisions/**'
rtk git diff --check
rtk git status --short
```

Expected: Auth lifecycle GREEN, profile 56/56, canonical/mirror equal, no secret in the delta, diff clean and only intended files pending.

- [ ] **Step 7: Commit**

```powershell
rtk git commit -m "feat(database): close activities v2 authorization"
```

---

### Task 5: Canonical documentation and resumable checkpoint

**Files:** all documentation paths listed in File Map.

**Interfaces:**
- Consumes: verified test, lint, mirror, Auth and cleanup evidence.
- Produces: canonical state and consolidation ledger without promoting Flutter/E2E/remote/done.

- [ ] **Step 1: Update canonical sources first**

Mark the design `implemented-local-green` only if every Task 4 gate passed. Append to ADR 0022 that shared domain invariants use nominal actor-realm gateways and that Principal receives no new grant. Mark OQ-043 resolved specifically for Activities v2; do not generalize resolution to other legacy CRUD domains.

- [ ] **Step 2: Update trackers in order**

Append a Supabase checkpoint containing objective, exact paths/migrations/hashes, first RED, final GREEN, assertions, regression, lint classification, environment, local/remote state, elapsed time, ETA, blockers and next safe command. Then append the integrated tracker only with backend dependency state; leave Flutter and `verified_e2e` unchanged.

- [ ] **Step 3: Run the coelo-knowledge gate**

Project only durable approved knowledge. If the existing team Activity pages already state the cross-app rule, record `no-op` in the tracker rather than creating activity logs as knowledge.

- [ ] **Step 4: Update the worktree/commit ledger**

Classify `f793867d` and every new commit as exclusive, patch-equivalent or superseded. Do not touch the visual branch, `dev`, push, merge or remove worktrees in this task.

- [ ] **Step 5: Verify docs and commit**

```powershell
rtk git diff --check
rtk git status --short
rtk git commit -m "docs(supabase): record activities v2 local checkpoint"
```

Expected: clean backend worktree after commit; remote still read-only/blocked-environment; Flutter/E2E/remote-green/done unchanged.

## Final Review

After Tasks 1–5 pass their per-task spec and quality reviews:

1. generate one whole-branch review package from the backend branch merge-base;
2. dispatch the final reviewer using the requesting-code-review template;
3. fix every Critical/Important finding in one reviewed fix wave;
4. repeat focused/full verification affected by fixes;
5. use `finishing-a-development-branch` only for the local consolidation decision already authorized—never push.
