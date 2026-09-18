---
title: "R02 D02 — granular Location capabilities and revocation"
source: "Candidates 6e25a20a and eafc2e18; focal verification in D02 worktree"
status: "local-green"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Acceptance

Etapa 2 → apps/superadmin → Estrutura → Locais → catálogo/detalhe →
`locations.list`, `locations.create-edit`, `locations.detail-links`,
`units.copy-institution-location`.

The UI now accepts separate create, update, status, copy and schedule grants.
When a grant is withdrawn, an open create form, edit form or institution-copy
panel closes immediately. A grant unrelated to the open surface does not throw
away the operator's work. Backend authorization remains the final control.

# Provenance

- `6e25a20a`: granular capability object and separate rendering of write actions.
- `eafc2e18`: close only the open surface whose grant was withdrawn.

The candidates were reapplied only to `features/locations` production and test
files. Router, shared components, scheduling section, SQL and providers were
not changed by this package.

# RED

Working directory:
`C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-d02-estrutura/apps/superadmin`.

Command:

`rtk flutter test test/features/locations/location_capability_revocation_test.dart`

Result: 2 passed, 3 failed. The failed cases showed that withdrawing create,
copy or update left respectively `locations-form`, `locations-bring-panel` or
the keyed edit form mounted.

# GREEN

Command:

`rtk flutter test test/features/locations/location_capabilities_test.dart test/features/locations/location_capability_revocation_test.dart`

Result: 20/20 passed.

Static analysis command covered the four production paths and two tests:

`rtk flutter analyze lib/features/locations/domain/location_capabilities.dart lib/features/locations/presentation/location_detail_panel.dart lib/features/locations/presentation/locations_page.dart lib/features/locations/presentation/unit_locations_gate.dart test/features/locations/location_capabilities_test.dart test/features/locations/location_capability_revocation_test.dart`

Result: `No issues found! (ran in 25.6s)`.

# Limits

This is local Flutter evidence. The catalog still needs reserved production
routing/composition and the nominal Supabase/RLS package before FE/BE/E2E can
be promoted.
