---
fonte: user night scope; AGENTS.md; Safety contract at base 7ce41f86b
status: local-green; parent commit and integration pending
data_geracao: 2026-09-09
---

Safety composition: explicit mutation transport support

Path: apps/superadmin -> Segurança infantil -> detalhe/gerenciar -> edit/transition/suspend; wizard/deep-link -> save. Logical action mapping only; canonical action IDs are parent-owned.

Confirmed defect: management callbacks were enabled from status/onEdit alone and a deep-linked edit wizard could advance against the internal read-only adapter. Repository existence had no explicit transport support gate.

Correction: ChildSafetyMutationSupport expresses transport support only, never backend authorization. Controller defaults to false unless explicitly implemented; canCreate also requires transport support. Only Dev and test fixtures opt in. Both real Supabase adapters and Unavailable remain unqualified. Save/transition/suspend/export are rejected before repository dispatch. Existing edit/approve/reject/suspend buttons stay visible but disabled; wizard primary cannot advance. No bootstrap, router, shared, SQL or actual writes changed. Existing copy/layout and PNG remain unchanged.

Proof: red.txt has P0 F2 for the two new widget negatives. green.txt has P88 F0 B0 S0 U0 across the five directly affected controller/presentation suites, including the existing golden. default-deny.txt adds one distinct test proving zero repository invocations for all four commands without explicit support. Unique final P89 F0 B0 S0 U0 (do not sum RED attempts). Analyze exit0, no issues. Initial shell invocation failed before starting Flutter due to nested PowerShell variable interpolation; corrected invocation generated the RED log. Logs normalized to UTF8 without BOM, no rerun.

Tests changed: two widget regressions and one transport-negative unit test; existing five fixtures now opt in explicitly to preserve their qualified simulation. Analyzer covers Safety lib and tests. No HTTP34 or SQL rerun. Scope delta is local composition proof only: FE/BE/E2E full acceptance not promoted. Internal SQL deployment, cursor/lookup/write contracts and real E2E remain separate parent gates.

Next: parent review and publish these ten code/test paths plus this evidence directory; integrate on consolidated branch and retain real adapters without opt-in until nominal write qualification. Hashes in manifest.json. No Git action, remote operation, children, or persistent resources owned. Memory: existing user policy is enforced in canonical code; no new product decision or knowledge projection needed.
