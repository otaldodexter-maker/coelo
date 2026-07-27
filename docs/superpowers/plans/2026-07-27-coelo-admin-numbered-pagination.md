# Coelo Admin Numbered Pagination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver shared numbered pagination with adaptive ellipses and page-size options 10, 50, 100, and 500, then use it consistently in the Superadmin institution Cards and Table views.

**Architecture:** `CoeloAdminPagination` remains a stateless, domain-neutral public component in `coelo_ui_admin`; a private pure pagination-window helper determines numbered pages and ellipses from available width. The institution query owns `pageSize`, repositories use it for server-side ranges, and the view model resets to page zero when page size changes. The institution page adapts the one-based UI API to the zero-based domain query.

**Tech Stack:** Dart, Flutter Material, `coelo_tokens`, `coelo_ui_admin`, Supabase/PostgREST, Flutter widget tests and goldens, Coelo catalog/index scripts.

## Global Constraints

- Default page size is exactly 10; allowed sizes are exactly 10, 50, 100, and 500.
- Do not add an unrestricted `Todas` option.
- Pagination remains server-side and switching Cards/Table preserves page and page size.
- The `Criar instituição` affordance never counts as an institution.
- The footer stays available for successful non-empty results even when there is one page.
- Use only existing Coelo semantic tokens; introduce no local HEX color, dependency, route, permission, database schema, or speculative token.
- Preserve unrelated user changes in the dirty worktree and stage only files intentionally changed by each task.

---

## File Map

- `packages/coelo_ui_admin/lib/src/listing/coelo_admin_pagination.dart`: public pagination API, responsive composition, numbered window, semantics, focus, and page-size selector.
- `packages/coelo_ui_admin/test/listing/coelo_admin_pagination_test.dart`: public contract, interaction, responsive window, keyboard, and semantics tests.
- `apps/superadmin/lib/features/institutions/domain/institution_directory_query.dart`: zero-based page plus dynamic page size and offset.
- `apps/superadmin/lib/features/institutions/domain/institution_directory_page.dart`: page boundary helpers based on the active page size.
- `apps/superadmin/lib/features/institutions/data/fake_institution_directory_repository.dart`: in-memory server-range equivalent.
- `apps/superadmin/lib/features/institutions/data/supabase_institution_directory_repository.dart`: PostgREST range derived from the query.
- `apps/superadmin/lib/features/institutions/presentation/view_models/institution_directory_view_model.dart`: page-size command and query propagation.
- `apps/superadmin/lib/features/institutions/presentation/widgets/institution_directory_pagination.dart`: institution-to-shared-component adapter.
- `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`: footer visibility and placement for both display modes.
- Focused institution domain, repository, view-model, page, and golden tests: regression coverage.
- `apps/catalog/lib/catalog/catalog_registry.dart`: interactive component example.
- `apps/catalog/assets/coelo-ui.index.jsonl` and `apps/catalog/assets/catalog-sync-report.json`: generated searchable UI contract.
- `docs/knowledge/team/coelo-admin-numbered-pagination.md`: durable internal usage rule if the memory gate classifies it as reusable.

---

### Task 1: Evolve the shared Coelo Admin pagination component

**Files:**
- Modify: `packages/coelo_ui_admin/lib/src/listing/coelo_admin_pagination.dart`
- Modify: `packages/coelo_ui_admin/test/listing/coelo_admin_pagination_test.dart`

**Interfaces:**
- Produces:

```dart
const CoeloAdminPagination({
  required int currentPage,
  required int totalPages,
  required int pageSize,
  required List<int> pageSizeOptions,
  required ValueChanged<int> onPageSelected,
  required ValueChanged<int> onPageSizeChanged,
  VoidCallback? onPrevious,
  VoidCallback? onNext,
  Key? key,
});
```

- `currentPage` and values sent to `onPageSelected` are one-based.
- Responsive window entries are either a page number or an ellipsis; first, current, and last pages are never omitted.

- [ ] **Step 1: Write failing public-contract and interaction tests**

Add widget tests that construct page 7 of 20 with size 10 and options
`const [10, 50, 100, 500]`, then assert:

```dart
expect(find.text('Itens por página'), findsOneWidget);
expect(find.text('7'), findsOneWidget);
expect(find.text('20'), findsOneWidget);
expect(find.text('…'), findsWidgets);
await tester.tap(find.byKey(const Key('coelo-pagination-page-8')));
expect(selectedPages, [8]);
await tester.tap(find.byKey(const Key('coelo-pagination-page-size')));
await tester.pumpAndSettle();
await tester.tap(find.text('50').last);
expect(selectedSizes, [50]);
```

Also cover page 1/1, boundary disabling, current-page no-op, compact width,
selected semantics, non-focusable ellipses, Enter/Space activation, and invalid
constructor assertions.

- [ ] **Step 2: Run the shared component tests and confirm RED**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test\listing\coelo_admin_pagination_test.dart
```

Working directory: `packages/coelo_ui_admin`.

Expected: compilation failures for missing `pageSize`, `pageSizeOptions`,
`onPageSelected`, and `onPageSizeChanged`.

- [ ] **Step 3: Implement the minimal responsive public component**

Implement the approved constructor assertions and keep
`CoeloAdminPagination extends StatelessWidget`. Use `LayoutBuilder` to choose a
compact or expanded window, `Wrap` for responsive layout, a labeled Material
dropdown for the size, `OutlinedButton`/`IconButton` controls with minimum
48-pixel targets, and explicit `Semantics`.

Use a private deterministic helper shaped as:

```dart
sealed class _PaginationEntry {
  const _PaginationEntry();
}

final class _PageEntry extends _PaginationEntry {
  const _PageEntry(this.page);
  final int page;
}

final class _EllipsisEntry extends _PaginationEntry {
  const _EllipsisEntry();
}

List<_PaginationEntry> _paginationEntries({
  required int currentPage,
  required int totalPages,
  required bool compact,
})
```

The helper must always emit ascending unique pages, replace every omitted
consecutive range with one ellipsis, and retain page 1, `currentPage`, and
`totalPages`.

- [ ] **Step 4: Run component tests and confirm GREEN**

Run the Task 1 test command again.

Expected: all `coelo_admin_pagination_test.dart` tests pass.

- [ ] **Step 5: Format and commit the shared contract**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\src\listing\coelo_admin_pagination.dart test\listing\coelo_admin_pagination_test.dart
git add packages/coelo_ui_admin/lib/src/listing/coelo_admin_pagination.dart packages/coelo_ui_admin/test/listing/coelo_admin_pagination_test.dart
git commit -m "feat(ui): add numbered admin pagination"
```

---

### Task 2: Add dynamic page size to the institution domain and repositories

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/domain/institution_directory_query.dart`
- Modify: `apps/superadmin/lib/features/institutions/domain/institution_directory_page.dart`
- Modify: `apps/superadmin/lib/features/institutions/data/fake_institution_directory_repository.dart`
- Modify: `apps/superadmin/lib/features/institutions/data/supabase_institution_directory_repository.dart`
- Modify: `apps/superadmin/test/features/institutions/domain/institution_directory_query_test.dart`
- Modify: `apps/superadmin/test/features/institutions/data/fake_institution_directory_repository_test.dart`

**Interfaces:**
- Produces:

```dart
static const defaultPageSize = 10;
static const allowedPageSizes = <int>[10, 50, 100, 500];
final int pageSize;
int get offset => page * pageSize;
```

- `InstitutionDirectoryPage` gains the page-size context required for
`hasNext`; prefer a required `pageSize` field rather than importing a mutable or
static default into its calculation.

- [ ] **Step 1: Write failing domain and fake-repository tests**

Assert that the default query has size 10, `page: 2, pageSize: 50` has offset
100, equality/hash include page size, and unsupported sizes assert. Build at
least 120 fake records and verify page sizes 10, 50, 100, and 500 return the
correct slices and `hasNext` values.

- [ ] **Step 2: Run focused tests and confirm RED**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test\features\institutions\domain\institution_directory_query_test.dart test\features\institutions\data\fake_institution_directory_repository_test.dart
```

Working directory: `apps/superadmin`.

Expected: compilation failures for `pageSize` and `allowedPageSizes`.

- [ ] **Step 3: Implement query, page, and repository range propagation**

Add `pageSize` to the constructor, equality, hash code, and offset. Replace:

```dart
.range(query.offset, query.offset + InstitutionDirectoryQuery.pageSize - 1)
```

with:

```dart
.range(query.offset, query.offset + query.pageSize - 1)
```

and replace the fake slice end with:

```dart
final end = (start + query.pageSize).clamp(start, filtered.length);
```

Return `InstitutionDirectoryPage(pageSize: query.pageSize, ...)` from both
repositories and use its own `pageSize` in `hasNext`.

- [ ] **Step 4: Run focused domain and repository tests and confirm GREEN**

Run the Task 2 test command again.

Expected: all focused tests pass.

- [ ] **Step 5: Format and commit dynamic server ranges**

Format only the six Task 2 files, stage only them, and commit:

```powershell
git commit -m "feat(superadmin): support institution page sizes"
```

---

### Task 3: Connect numbered pagination to Cards and Table

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/presentation/view_models/institution_directory_view_model.dart`
- Modify: `apps/superadmin/lib/features/institutions/presentation/widgets/institution_directory_pagination.dart`
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`
- Modify: `apps/superadmin/test/features/institutions/presentation/view_models/institution_directory_view_model_test.dart`
- Modify: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`

**Interfaces:**
- Consumes: the Task 1 `CoeloAdminPagination` API and Task 2 dynamic
`InstitutionDirectoryQuery.pageSize`.
- Produces:

```dart
Future<void> setPageSize(int value);
```

`setPageSize` validates membership in `allowedPageSizes`, preserves filters,
sets `page: 0`, and performs one load.

- [ ] **Step 1: Write failing view-model and screen tests**

Add view-model coverage:

```dart
await viewModel.goToPage(3);
await viewModel.setPageSize(50);
expect(viewModel.query.page, 0);
expect(viewModel.query.pageSize, 50);
expect(repository.queries.last.pageSize, 50);
```

Add screen tests asserting:

- the first Cards load renders at most 10 institution cards plus the create
  affordance;
- Table uses the same 10 result records;
- selecting page 2 issues the zero-based page 1 query;
- selecting 50 resets to page 1;
- switching Cards/Table preserves query page and size;
- a one-page non-empty result still shows the size selector;
- empty and no-results states do not show it.

- [ ] **Step 2: Run focused presentation tests and confirm RED**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test\features\institutions\presentation\view_models\institution_directory_view_model_test.dart test\features\institutions\presentation\screens\institution_directory_page_test.dart
```

Working directory: `apps/superadmin`.

Expected: failure because the view model and widget adapter do not expose
page-size or direct-page callbacks.

- [ ] **Step 3: Implement view-model propagation and footer integration**

Thread `pageSize` through `_queryWith` and `_sanitizeQuery`. Implement
`setPageSize`, keeping filters and setting page zero. In
`InstitutionDirectoryPagination`, calculate:

```dart
final totalPages = (page.totalCount / viewModel.query.pageSize).ceil();
```

Pass direct selection as:

```dart
onPageSelected: (oneBasedPage) => viewModel.goToPage(oneBasedPage - 1),
onPageSizeChanged: viewModel.setPageSize,
```

In `_InstitutionDirectoryResults`, render the footer whenever state is success
and `totalCount > 0`, not only when total pages exceeds one. Keep it outside the
table's horizontal scroller and below either display mode.

- [ ] **Step 4: Run focused presentation tests and confirm GREEN**

Run the Task 3 test command again.

Expected: all focused view-model and screen tests pass.

- [ ] **Step 5: Format and commit the institution integration**

Format only the five Task 3 files, stage only them, and commit:

```powershell
git commit -m "feat(superadmin): paginate institution views"
```

---

### Task 4: Update responsive goldens, catalog, index, and durable knowledge

**Files:**
- Modify: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart`
- Modify: affected files under `apps/superadmin/test/features/institutions/presentation/screens/goldens/`
- Modify: `apps/catalog/lib/catalog/catalog_registry.dart`
- Modify: `apps/catalog/assets/coelo-ui.index.jsonl`
- Modify: `apps/catalog/assets/catalog-sync-report.json`
- Modify: relevant catalog tests if the generated example contract changes
- Create if approved by memory gate: `docs/knowledge/team/coelo-admin-numbered-pagination.md`

**Interfaces:**
- Consumes: the completed shared API and institution integration.
- Produces: discoverable `admin.pagination` catalog/index documentation and
verified responsive references.

- [ ] **Step 1: Update the interactive catalog example**

Make `_PaginationExample` hold `_page` and `_pageSize`, set `totalPages: 20`,
wire direct selection and size selection, and expose the approved options:

```dart
pageSize: _pageSize,
pageSizeOptions: InstitutionDirectoryQuery.allowedPageSizes,
onPageSelected: (page) => setState(() => _page = page),
onPageSizeChanged: (size) => setState(() {
  _pageSize = size;
  _page = 1;
}),
```

Do not import institution domain into the catalog; define
`const [10, 50, 100, 500]` locally in the example.

- [ ] **Step 2: Run and intentionally review responsive goldens**

Run the established institution golden command with the repository's approved
golden-update flag, limited to:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test\features\institutions\presentation\screens\institution_directory_page_golden_test.dart --update-goldens
```

Working directory: `apps/superadmin`.

Inspect every changed image at 375, 768, 1024, and 1440 in light and dark.
Confirm the footer wraps without clipping, the selected page is visible, the
table scroller does not capture the footer, and only the intended pagination
region changes.

- [ ] **Step 3: Synchronize and validate the Coelo UI index**

Use the existing catalog synchronization commands documented in
`apps/catalog/README.md` or its tool help to regenerate
`apps/catalog/assets/coelo-ui.index.jsonl` and
`apps/catalog/assets/catalog-sync-report.json`. Then run the catalog boundary,
index, and sync validators. Expected: `admin.pagination` remains owned by
`coelo_ui_admin`, has current source/example hashes, and all validators exit 0.

- [ ] **Step 4: Run the Coelo knowledge memory gate**

Run:

```powershell
& '.agents\skills\coelo-knowledge\scripts\Search-CoeloKnowledge.ps1' -Query 'paginação administrativa tamanho por página'
```

Because the user approved a reusable Coelo UI behavior, create the team
projection only if the search confirms no equivalent entry. Its frontmatter
must point to
`docs/superpowers/specs/2026-07-27-coelo-admin-numbered-pagination-design.md`,
state the 10/50/100/500 contract, and contain no activity log or tenant data.
Validate with:

```powershell
& '.agents\skills\coelo-knowledge\scripts\Test-CoeloKnowledge.ps1'
& '.agents\skills\coelo-knowledge\tests\Test-CoeloKnowledge.ps1'
```

Expected: both memory validators pass, or report a documented no-op if an
equivalent projection already exists.

- [ ] **Step 5: Run proportional verification**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed packages\coelo_ui_admin\lib packages\coelo_ui_admin\test apps\superadmin\lib\features\institutions apps\superadmin\test\features\institutions apps\catalog\lib\catalog
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze
```

Run `dart analyze` from `packages/coelo_ui_admin`, `apps/superadmin`, and
`apps/catalog`, then run the full tests for `packages/coelo_ui_admin` and the
focused institution and catalog suites. Search affected Dart files for local
`Color(0x`, HEX, unthemed `TextStyle`, and fixed viewport assumptions. Review
`git diff --check`, `git diff --stat`, and the complete scoped diff.

Expected: format check, analysis, tests, validators, memory gate, and diff check
all pass; no unrelated files are staged.

- [ ] **Step 6: Commit catalog, references, and knowledge**

Stage only the intentional Task 4 files and commit:

```powershell
git commit -m "docs(ui): catalog numbered pagination"
```

Report the exact tests run, responsive references reviewed, index validation,
knowledge entry or no-op, and any unrelated pre-existing worktree changes left
untouched.

---

## Plan Self-Review

- Spec coverage: Tasks 1–4 cover public API, adaptive numbering, exact sizes,
  server ranges, both display modes, one-page footer, accessibility,
  responsiveness, catalog/index, knowledge, and verification.
- Placeholder scan: no deferred implementation steps or unspecified test
  categories remain.
- Type consistency: UI pages are one-based; institution queries remain
  zero-based; `pageSize` is an `int` everywhere; callbacks use
  `ValueChanged<int>`.
- Scope: one shared component evolution plus its first consumer migration;
  unrelated listings are explicitly excluded.
