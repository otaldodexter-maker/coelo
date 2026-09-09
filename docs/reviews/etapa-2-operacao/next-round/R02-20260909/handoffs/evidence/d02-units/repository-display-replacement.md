---
title: "D02 Units — repository replacement preserves display pagination contract"
source: "D02 execution; observed Flutter outputs reconstructed after the runs"
status: "local-green"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Scope

Etapa 2 → `apps/superadmin` → Unidades → diretório/tabela → `units.list`,
`units.reload`.

Working directory for every command below:
`C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-d02-estrutura/apps/superadmin`.

# RED

Command:

```text
rtk flutter test test/features/units/presentation/unit_directory_page_test.dart --plain-name "reloads through the replacement repository after authorization changes"
```

Observed result reconstructed from the captured tool output (this is not a raw
log file): exit 1, 0 passed and 1 failed. After switching from cards to table
and replacing the repository, Flutter raised the product assertion
`pageSize == null || pageSizeOptions.contains(pageSize)`: the replacement view
model returned to page size 11 while the preserved table UI exposed
`[8, 20, 50, 100]`.

# Fix

`UnitDirectoryViewModel` now accepts a validated initial page size. When
`UnitDirectoryPage.didUpdateWidget` replaces the repository and view model, it
starts at 11 for cards or 8 for table. The selected display remains stable and
the new repository still reloads without retaining the old result.

# GREEN

Command:

```text
rtk flutter test test/features/units/presentation/unit_directory_page_test.dart --plain-name "reloads through the replacement repository after authorization changes"
```

Observed result reconstructed from the captured tool output: exit 0,
`00:02 +1: All tests passed!`.

Static analysis command:

```text
rtk flutter analyze lib/features/units/presentation/unit_directory_page.dart lib/features/units/presentation/unit_directory_view_model.dart test/features/units/presentation/unit_directory_page_test.dart
```

Observed result reconstructed from the captured tool output: exit 0,
`No issues found! (ran in 80.2s)`.

# Limits

This is local Flutter evidence for the directory lifecycle. It does not prove
the absent Unit RPCs, Supabase persistence, authorization/RLS, or E2E.
