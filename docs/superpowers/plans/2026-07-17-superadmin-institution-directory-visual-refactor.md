---
source:
  - docs/superpowers/specs/2026-07-17-superadmin-institution-directory-visual-refactor-design.md
status: executing
generated_at: 2026-07-17
---

# Superadmin Institution Directory Precision Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the approved precision visual pass for the institution directory without changing its Supabase-backed architecture.

**Architecture:** Keep the view model, repositories, router, database, and global theme unchanged. Refactor only the reusable shell and directory presentation widgets, using existing Coelo tokens and Flutter platform APIs.

**Tech Stack:** Flutter, Dart, Material 3, `coelo_tokens`, `flutter_test`, `Clipboard`.

## Global Constraints

- The supplied screenshots and attached Flutter prototypes are the visual contract.
- Cards remain the initial view; switching to Table preserves query and page.
- Use only Coelo theme tokens; add no local HEX colors and no dependencies.
- Search names only; preserve Status, Plan, UF, and Type filters.
- Remove the import-institutions action from header and toolbar.
- Render `Grupos (Turmas)` consistently in cards and table.
- Preserve pagination, debounce, authorization, loading/error/empty/retry states, protected routes, fake `/dev/*` data, and the floating developer menu.
- Do not modify Supabase, repositories, view model, router, authentication, or password recovery.
- The worktree is shared and dirty. Do not stage or commit.

## File Map

- Modify `apps/superadmin/lib/app/shell/superadmin_shell.dart`.
- Modify `apps/superadmin/test/app/shell/superadmin_shell_test.dart`.
- Modify `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`.
- Modify `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`.

---

### Task 1: Exact Sidebar Composition and Interaction

**Interfaces:**
- Keep the public `SuperadminShell` constructor unchanged.
- Keep keys `superadmin-sidebar`, `superadmin-sidebar-collapse`, and `superadmin-mobile-menu`.
- Add keys `superadmin-navigation-institutions` and `superadmin-navigation-settings`.

- [ ] **Step 1: Write failing shell tests**

Add assertions for a 260 px expanded sidebar, 88 px collapsed sidebar, 24 px overlaid toggle, solid-primary active item, primary-container hover item, the reference navigation order, and a footer containing only Configurações:

```dart
expect(tester.getSize(find.byKey(const Key('superadmin-sidebar'))).width, 260);
await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
await tester.pumpAndSettle();
expect(tester.getSize(find.byKey(const Key('superadmin-sidebar'))).width, 88);
expect(find.text('Configurações'), findsNothing); // collapsed label
expect(find.text('Menu Dev'), findsNothing);
expect(find.text('Owner Coelo'), findsOneWidget);
```

Use `tester.createGesture(kind: PointerDeviceKind.mouse)` and `gesture.addPointer/moveTo` over the Avisos item, then assert its decorated background resolves to `colorScheme.primaryContainer`.

- [ ] **Step 2: Verify RED**

Run from `apps/superadmin`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/app/shell/superadmin_shell_test.dart
```

Expected: failures for 80 px collapsed width, disabled inactive items, missing Settings footer, incorrect mark, and standard 48 px toggle.

- [ ] **Step 3: Implement minimal shell changes**

Use:

```dart
const _collapsedSidebarWidth = CoeloSpacing.space20 + CoeloSpacing.space2;
```

Wrap the sidebar in a `Stack(clipBehavior: Clip.none)` and place one 24 px circular toggle at `right: -12`, `top: 32`. Build the mark as a 48 px `colorScheme.onSurface` block with `CoeloRadius.lg`, containing the existing official PNG through `ColorFiltered(colorFilter: ColorFilter.mode(colorScheme.surface, BlendMode.srcIn))`.

Implement stateful mouse/focus navigation controls:

```dart
final background = isActive
    ? colors.primary
    : highlighted
        ? colors.primaryContainer
        : Colors.transparent;
final foreground = isActive ? colors.onPrimary : highlighted ? colors.primary : colors.onSurfaceVariant;
```

Use the order Instituições, Planos, Usuários internos, Avisos, Importação, Suporte, Auditoria. Keep unfinished items on the current screen. Put only Configurações in the bottom section. Profile remains in the page header and Menu Dev remains only floating.

- [ ] **Step 4: Verify GREEN**

Run the focused shell test and `dart analyze`. Expected: all shell tests pass and no analyzer issues.

---

### Task 2: Pill Toolbar and Removed Import Action

**Interfaces:**
- Keep `_DirectoryDisplay { cards, table }` and existing query callbacks.
- Keep keys `institution-filter-toolbar`, `institution-view-cards`, and `institution-view-table`.

- [ ] **Step 1: Write failing toolbar tests**

Assert no Importar instituições text exists, the desktop search is 300 px wide, and search/dropdown enabled borders use `CoeloRadius.full`:

```dart
expect(find.text('Importar instituições'), findsNothing);
expect(tester.getSize(find.byType(TextField)).width, 300);
final decoration = tester.widget<TextField>(find.byType(TextField)).decoration!;
final border = decoration.enabledBorder! as OutlineInputBorder;
expect(border.borderRadius.topLeft.x, CoeloRadius.full);
```

- [ ] **Step 2: Verify RED**

Run the directory widget test file. Expected: import is present, search is 250 px, and fields inherit radius 12.

- [ ] **Step 3: Implement minimal toolbar changes**

Remove the page `actions`, `onImport`, and compact import button. Add one private helper:

```dart
InputDecoration _pillDecoration({String? hintText, Widget? prefixIcon}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(CoeloRadius.full),
    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
  );
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    isDense: true,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
    ),
  );
}
```

Apply it only to the directory search/dropdowns. Use 300 px desktop search and preserve responsive wrapping.

- [ ] **Step 4: Verify GREEN**

Run focused directory tests and analyzer. Expected: toolbar tests pass without theme-global changes.

---

### Task 3: Precise Cards, Transparent Create Affordance, and Clipboard

**Interfaces:**
- Consume existing `InstitutionDirectoryItem` fields only.
- Add `package:flutter/services.dart`.
- Add stable copy keys `copy-domain-<institution-id>`.

- [ ] **Step 1: Write failing card and clipboard tests**

Assert the card shows Município/UF and Domínio before the divider, then Tipo/Plano and Unidades/Grupos (Turmas); legal name is absent. Tap the domain copy key and read `SystemChannels.platform` through a mock method handler to verify `Clipboard.setData` receives the exact domain.

Assert create Material is transparent and hover changes its painter/container to semantic primary colors. Assert institution card hover uses an animated decorated container with a primary-tinted shadow.

- [ ] **Step 2: Verify RED**

Run the focused directory tests. Expected: field order, copy key, transparent create surface, and animated hover assertions fail.

- [ ] **Step 3: Implement minimal card hierarchy**

Use 24 px padding and a 48 px avatar. The upper block is:

```dart
Row(children: [avatar, Expanded(name + _location(city, state)), status]);
domain row with copy IconButton;
Divider();
_CardDetailRow(first: Tipo, second: Plano);
_CardDetailRow(first: Unidades, second: Grupos (Turmas));
```

Do not render legal name. Copy with:

```dart
await Clipboard.setData(ClipboardData(text: domain));
if (context.mounted) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Domínio copiado.')));
}
```

Use `AnimatedContainer(duration: CoeloMotion.standard)` with a light primary border and subtle primary shadow during hover/focus. Create tile/banner use `Colors.transparent`; their neutral circle becomes primary on hover/focus.

- [ ] **Step 4: Make the grid match wide references**

Use a 24 px gap and no four-column cap:

```dart
final columns = math.max(1, (constraints.maxWidth / 340).floor());
final cardWidth = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
```

Expected: one column on compact screens and five tiles on the widest supplied reference.

- [ ] **Step 5: Verify GREEN**

Run focused tests. Expected: hierarchy, clipboard, transparent create action, hover, and responsive grid tests pass.

---

### Task 4: Table Parity and Hover

**Interfaces:**
- Keep horizontal scrolling key `institution-directory-table-scroll`.
- Reuse the same domain-copy widget and status chip.

- [ ] **Step 1: Write failing table tests**

Switch to Table and assert exactly these headers: Instituição, Município/UF, Domínio, Tipo, Plano, Unidades, Grupos (Turmas), Status. Assert Razão social is absent, a copy control exists for each domain, and each `DataRow.onSelectChanged` is non-null.

- [ ] **Step 2: Verify RED**

Run focused tests. Expected: the old nine-column table, missing copy actions, and non-interactive rows fail.

- [ ] **Step 3: Implement table parity**

Build eight columns in the approved order. Put the shared copy control beside domain text. Set `onSelectChanged: (_) {}` on each row so the global `DataTableTheme` hover resolves to `primaryContainer`; do not add local row colors.

- [ ] **Step 4: Verify GREEN**

Run focused tests, including horizontal scroll at 375 px. Expected: all pass without overflow.

---

### Task 5: Full Verification and Visual Inspection

- [ ] Format the four changed Dart files with `dart format`.
- [ ] Run `dart analyze` from `apps/superadmin`; expect `No issues found!`.
- [ ] Run the complete Flutter test suite; expect all tests to pass.
- [ ] Build web with `--dart-define=COELO_DEV_MFA=true`.
- [ ] Scan the two production files for local HEX values, domain-search copy, generic school copy, and import-institutions UI.
- [ ] Inspect `/dev/institutions/` at desktop and compact widths, checking expanded/collapsed menu, active/hover items, normal/hover create tile, normal/hover institution cards, clipboard control, and table hover.
- [ ] Preserve the one requested localhost at port 8765 and keep all unrelated dirty-worktree changes untouched.
