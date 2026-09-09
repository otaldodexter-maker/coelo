---
source: Supabase CLI v2.116.0 source; first live receipt 84568; D00 delegated local transport qualification
status: prepared-v2-offline-only; live two-gate proof pending
generated_at: 2026-09-09
---

First live 84568 failed before either atomicity marker. Its generic SQL error does not establish SQLSTATE or cause. Original qualifier B77D0B23F1C87C3BD71E8C6127AD1EE750C8D832802058E2788DC27741B32551 and runner D6AAFAFF1363005A23B3D688D373028D6CC39473444DC940B420CCFDE8FE959B are unchanged.

Source facts: legacyApplyMigrations returns before legacyCreateMigrationTable when pending.length===0. legacyCreateMigrationTable itself explicitly BEGINs and COMMITs history initialization before migration batch execution. Thus empty reset does not establish the promised initialized ledger. V2 bootstrap uses only pinned CLI with an intentionally failing synthetic migration, witnesses its exact sentinel and nonzero exit, removes only its own SQL file, then requires a present empty ledger. It neither creates nor repairs history by manual SQL. Bootstrap is a precondition, not a third product/atomicity PASS. This behavior is source-supported and offline-orchestrated; its real CLI result remains pending.

Official source:
- https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-migration-apply.ts
- https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-migration-history.ts
- https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-migrate-and-seed.ts

V2 adds psql verbose error capture and emits only nominal phase plus allowlisted SQLSTATE; unknown states remain UNKNOWN. No SQL/DETAIL/context/raw output is emitted. All SQL calls have phase labels. SUPABASE_EXPERIMENTAL is now rejected to prevent alternate schema-path execution semantics.

Offline evidence: diagnostics-v1-red.log = original implementation 3 PASS / 2 FAIL for missing sanitized diagnostics; diagnostics-v2-green.log = 5 PASS / 0 FAIL. Test-CliBootstrapV2.Tests.ps1 = 3 PASS / 0 FAIL for absent ledger bootstrap, present ledger skip, unexpected CLI success fail-closed. Native commands in these tests only emit synthetic local sentinels; Docker and npx are stubbed. V2 PowerShell parser zero errors. No actual SQL/Docker/network credential use.

V2 qualifier SHA256: 9B671F4C98FC1389E9F546CCD4DB9B65BA43E94A2ADBFBFF2B8B037860FA4055.
Use the unchanged Invoke-OwnedCliAtomicity.ps1 with QualifierPath ending Test-ProposedCliLedgerAtomicityV2.ps1 and ExpectedQualifierSha256 above, in D00's exclusive local slot. The two expected success markers remain unchanged. This qualification cannot authorize production or certify the product AMR flow.
