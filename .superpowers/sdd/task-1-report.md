---
source: .superpowers/sdd/task-1-brief.md
status: completed
generated_at: 2026-07-29
---

# Task 1 — Institution table page size

## RED

The test was changed first to `starts with eleven card items and switches to eight table rows`. It asserts eleven initial cards, eight table rows after switching mode, and that the table page-size menu includes `coelo-admin-pagination-page-size-8` but excludes `coelo-admin-pagination-page-size-9`.

The focused command failed as expected before production edits. The failure reported `Expected: exactly 8 matching candidates` and `Found 9 widgets` for table rows at `institution_directory_page_test.dart:80`.

## GREEN

The smallest production change updates `_changeDisplay` to use `11` for cards and `8` for table mode, and changes the table options to `[8, 20, 50, 100]`. Card options remain `[11, 20, 50, 100]`.

After formatting, the focused command passed:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/institutions/presentation/screens/institution_directory_page_test.dart --plain-name "starts with eleven card items and switches to eight table rows"
```

Result: `00:01 +1: All tests passed!`

## Files changed

- `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`
- `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`

No shared-package code or public `CoeloAdminPagination` API was changed. Sticky footer work was intentionally not implemented.

## Validation and self-review

- Ran `dart format` on both changed Dart files.
- Ran `git diff --check` with no whitespace errors.
- Reviewed the diff: production changes are limited to the mode-switch page size and table-only option list; card behavior remains unchanged.
- Ran both Coelo knowledge validation scripts successfully. Memory capture is a no-op: this small implementation adjustment does not add approved, durable reusable product knowledge.

## Commit

`fix(superadmin): show eight institution table rows`

## Concerns

None. Flutter reported 11 outdated transitive packages while resolving dependencies; this is pre-existing environment information and did not affect the focused test.
