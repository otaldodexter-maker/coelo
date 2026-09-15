# Agora Immediate Removal Implementation Plan

**Goal:** Implement and prove `agora.remove` with immediate feed revocation and idempotent private-media purge.

**Architecture:** Postgres remains authoritative for actor, tenant, ownership, state, receipts, audit, read-ticket invalidation and purge jobs. The `now-media` Edge Function calls the authorized RPC, deletes only server-selected R2 objects, records purge outcomes, and returns a sanitized receipt. The existing 24-hour expiry path remains unchanged.

**Tech Stack:** Supabase Postgres/pgTAP, Supabase Edge Function/Deno, Cloudflare R2, Flutter/Dart repository and Principal Agora feed.

## Global Constraints

- Action: `agora.remove` only.
- R2 remains private master; no public bucket, client-selected path, token, signed URL, CPF, child data or secret in logs/Git.
- Removal is author/authorized-role and tenant/context checked server-side.
- Removal is logical immediately; R2 purge is idempotent and catalog/audit remain.
- Every production change is forward-only, versioned, tested and separately verified.

### Task 1: Database contract and failing tests

**Files:**
- Create: `packages/coelo_database/migrations/<supabase-generated-agora-remove>.sql`
- Test: `packages/coelo_database/supabase/tests/now_publication_removal_test.sql`

- [x] Write the failing contract test.
- [x] Verify the current linked catalog reports no `removed` status and no removal RPC.
- [ ] Add `removed` status, removal columns, `now_media_purge_jobs`, capability `now.publications.remove`, and the authorized idempotent RPC.
- [ ] Add the service-role purge result RPC with no client grant.
- [ ] Run the contract test against the local/authorized integration database.

### Task 2: Edge media purge

**Files:**
- Modify: `packages/coelo_database/supabase/functions/now-media/index.ts`
- Test: `packages/coelo_database/supabase/functions/now-media/index_test.ts`

- [ ] Write tests for authenticated remove, invalid request, R2 delete success, delete retry/error and sanitized response.
- [ ] Add the `remove` envelope and call `remove_now_publication`.
- [ ] Delete only returned R2 jobs and record each outcome through the service-role RPC.
- [ ] Return no bucket, object key, signed URL or secret.
- [ ] Run the focused Deno test suite.

### Task 3: Principal feed/repository behavior

**Files:**
- Modify: `apps/superadmin/lib/features/principal_now/domain/principal_now_feed_repository.dart`
- Modify: `apps/superadmin/lib/features/principal_now/data/supabase_principal_now_feed_repository.dart`
- Modify: `apps/superadmin/lib/features/principal_now/presentation/principal_now_preview_page.dart`
- Tests: matching Principal Agora unit/widget tests.

- [ ] Add an explicit removal command/result model and map authorization/conflict failures.
- [ ] Add the existing-scope remove action only for an item whose backend says it is removable.
- [ ] Remove the item from the active feed after success and reload from the server.
- [ ] Prove that no UI-only removal can bypass the backend.

### Task 4: Production migration, Edge deployment and proof

- [ ] Review migration order and run advisors/security checks.
- [ ] Apply the migration to production only after the versioned package is reviewed.
- [ ] Deploy the versioned `now-media` Edge Function.
- [ ] Run positive/negative production proof using the synthetic QA actor and CDP route `3017`/`9417`.
- [ ] Verify catalog/audit persistence, ticket denial, R2 purge/retry outcome and immediate reload absence.
- [ ] Commit small explicit deltas and update only the Session E handoff; C0 reconciles central ledger and delivery gate.
