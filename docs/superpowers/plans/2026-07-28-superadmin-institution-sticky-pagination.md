---
source: "docs/superpowers/specs/2026-07-28-superadmin-institution-sticky-pagination-design.md"
status: "approved"
generated_at: "2026-07-28"
---

# Superadmin Institution Sticky Pagination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduzir a tabela de Instituições a 8 itens por página e manter a paginação de cards e tabela fixa no rodapé, sobre uma faixa translúcida com blur.

**Architecture:** `InstitutionDirectoryPage` mantém a paginação como composição local e separa o conteúdo rolável do rodapé posicionado em um `Stack`. A altura real do rodapé é medida após o layout e vira inset inferior da `ListView`, cobrindo quebras responsivas sem esconder o último item; `CoeloAdminPagination` permanece inalterado.

**Tech Stack:** Flutter, Dart, `coelo_tokens`, `coelo_ui_admin`, `flutter_test`, goldens Flutter.

## Global Constraints

- Não alterar a API pública ou o visual interno de `CoeloAdminPagination`.
- Não criar componente, variante, dependência ou token global.
- Cards preservam 11 itens e opções `11, 20, 50, 100`.
- Tabela usa 8 itens e opções `8, 20, 50, 100`.
- Blur restrito à faixa do rodapé, baseado em `CoeloSpacing.space2`.
- Superfície usa `colorScheme.surface` com opacidade local `0.88` e divisor `outlineVariant`.
- Inset inferior acompanha a altura renderizada do rodapé e acrescenta `CoeloSpacing.space4`.
- Preservar todas as alterações locais não relacionadas.
- Verificar 375, 768, 1024 e 1440 px em light e dark.

---

## File Map

- Modify `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`: tamanho da tabela, `Stack`, medição do rodapé, blur e inset rolável.
- Modify `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`: contagem, opções, posição fixa, scroll seguro e responsividade.
- Modify `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart`: referência visual focada do rodapé fixo.
- Update `apps/superadmin/test/features/institutions/presentation/screens/goldens/*.png`: baselines afetados pela nova composição.
- Modify `docs/knowledge/team/superadmin-institution-directory.md`: projetar o comportamento aprovado e o novo tamanho da tabela.

### Task 1: Tamanho de página da tabela

**Files:**
- Modify: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`

**Interfaces:**
- Consumes: `_InstitutionDirectoryPageState._changeDisplay(InstitutionDirectoryDisplay)`.
- Preserves: cards com `pageSize == 11`.
- Produces: tabela com `pageSize == 8` e `pageSizeOptions == [8, 20, 50, 100]`.

- [ ] **Step 1: Write the failing table-size test**

Replace the existing test name and final assertion with:

```dart
testWidgets('starts with eleven card items and switches to eight table rows', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();

  expect(_institutionCards(), findsNWidgets(11));
  expect(find.byKey(const Key('create-institution-card')), findsOneWidget);

  await tester.tap(find.byKey(const Key('institution-view-table')));
  await tester.pumpAndSettle();

  expect(_institutionTableRows(), findsNWidgets(8));
  await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('coelo-admin-pagination-page-size-8')), findsOneWidget);
  expect(find.byKey(const Key('coelo-admin-pagination-page-size-9')), findsNothing);
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run from `apps/superadmin`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/institutions/presentation/screens/institution_directory_page_test.dart --plain-name "starts with eleven card items and switches to eight table rows"
```

Expected: FAIL because the table still renders 9 rows.

- [ ] **Step 3: Implement the 8-item table size**

In `_changeDisplay`, use:

```dart
_viewModel.setPageSize(
  display == InstitutionDirectoryDisplay.cards ? 11 : 8,
  resetSort: display == InstitutionDirectoryDisplay.cards,
);
```

In the table branch of `pageSizeOptions`, use:

```dart
const [8, 20, 50, 100]
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the command from Step 2.

Expected: PASS with 8 table rows and the `8` page-size option.

### Task 2: Rodapé fixo com blur e inset medido

**Files:**
- Modify: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`

**Interfaces:**
- Consumes: `InstitutionDirectoryPagination`, `CoeloSpacing`, `Theme.of(context).colorScheme`.
- Produces: keys `institution-directory-pagination-footer` and `institution-directory-pagination-footer-surface`.
- Produces: `_InstitutionDirectoryContentState._footerHeight` atualizado pela altura real do rodapé.

- [ ] **Step 1: Write failing fixed-footer tests**

Add `import 'dart:ui';` to the test and add:

```dart
testWidgets('keeps pagination fixed at the bottom while cards scroll', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();

  final footer = find.byKey(const Key('institution-directory-pagination-footer'));
  final scroll = find.byKey(const Key('institution-directory-content-scroll'));
  expect(footer, findsOneWidget);
  final bottomBefore = tester.getBottomLeft(footer).dy;

  await tester.drag(scroll, const Offset(0, -500));
  await tester.pumpAndSettle();

  expect(tester.getBottomLeft(footer).dy, closeTo(bottomBefore, 1));
});

testWidgets('keeps the final card above the fixed pagination', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1024, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();

  final scroll = find.byKey(const Key('institution-directory-content-scroll'));
  await tester.drag(scroll, const Offset(0, -5000));
  await tester.pumpAndSettle();

  final footer = find.byKey(const Key('institution-directory-pagination-footer'));
  expect(
    tester.getBottomLeft(_institutionCards().last).dy,
    lessThanOrEqualTo(tester.getTopLeft(footer).dy - CoeloSpacing.space4),
  );
});

testWidgets('uses the approved glass footer surface in light and dark', (tester) async {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    await tester.binding.setSurfaceSize(const Size(1440, 700));
    await tester.pumpWidget(_app(brightness: brightness));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('institution-directory-pagination-footer')),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    final surface = tester.widget<Container>(
      find.byKey(const Key('institution-directory-pagination-footer-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    final colors = brightness == Brightness.light
        ? CoeloTheme.light.colorScheme
        : CoeloTheme.dark.colorScheme;
    expect(decoration.color, colors.surface.withValues(alpha: 0.88));
    expect(decoration.border!.top.color, colors.outlineVariant);
  }
  addTearDown(() => tester.binding.setSurfaceSize(null));
});
```

- [ ] **Step 2: Run the three tests and verify RED**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/institutions/presentation/screens/institution_directory_page_test.dart --plain-name "keeps pagination fixed at the bottom while cards scroll"
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/institutions/presentation/screens/institution_directory_page_test.dart --plain-name "keeps the final card above the fixed pagination"
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/institutions/presentation/screens/institution_directory_page_test.dart --plain-name "uses the approved glass footer surface in light and dark"
```

Expected: FAIL because the footer keys and `BackdropFilter` do not exist and pagination still scrolls inline.

- [ ] **Step 3: Move pagination out of `_InstitutionDirectoryResults`**

Convert `_InstitutionDirectoryContent` to `StatefulWidget`. Its state owns:

```dart
final GlobalKey _footerKey = GlobalKey();
double _footerHeight = 0;

void _measureFooter() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) {
      return;
    }
    final renderObject = _footerKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }
    final nextHeight = renderObject.size.height;
    if ((nextHeight - _footerHeight).abs() < 0.5) {
      return;
    }
    setState(() => _footerHeight = nextHeight);
  });
}
```

Wrap the existing layout in one `AnimatedBuilder` and build:

```dart
final showPagination =
    widget.viewModel.state == InstitutionDirectoryLoadState.success;
if (showPagination) {
  _measureFooter();
}
final footerInset = showPagination
    ? _footerHeight + CoeloSpacing.space4
    : 0.0;

return Stack(
  fit: StackFit.expand,
  children: [
    ListView(
      key: const Key('institution-directory-content-scroll'),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        horizontalPadding,
        horizontalPadding,
        horizontalPadding + footerInset,
      ),
      children: [
        InstitutionDirectoryToolbar(
          viewModel: widget.viewModel,
          activityController: widget.activityController,
          searchController: widget.searchController,
          display: widget.display,
          onDisplayChanged: widget.onDisplayChanged,
          onClearFilters: widget.onClearFilters,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _InstitutionDirectoryResults(
          viewModel: widget.viewModel,
          display: widget.display,
          onCreate: widget.onCreate,
          onEdit: widget.onEdit,
        ),
      ],
    ),
    if (showPagination)
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (_) {
            _measureFooter();
            return true;
          },
          child: SizeChangedLayoutNotifier(
            key: _footerKey,
            child: _InstitutionDirectoryPaginationFooter(
              viewModel: widget.viewModel,
              display: widget.display,
              horizontalPadding: horizontalPadding,
            ),
          ),
        ),
      ),
  ],
);
```

Remove the pagination and its preceding gap from
`_InstitutionDirectoryResults`. Remove its nested `AnimatedBuilder`, because the
parent now listens to the view model.

- [ ] **Step 4: Add the private glass footer**

Add `import 'dart:ui';` to `institution_directory_page.dart`, then add:

```dart
final class _InstitutionDirectoryPaginationFooter extends StatelessWidget {
  const _InstitutionDirectoryPaginationFooter({
    required this.viewModel,
    required this.display,
    required this.horizontalPadding,
  });

  final InstitutionDirectoryViewModel viewModel;
  final InstitutionDirectoryDisplay display;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRect(
      key: const Key('institution-directory-pagination-footer'),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: CoeloSpacing.space2,
          sigmaY: CoeloSpacing.space2,
        ),
        child: Container(
          key: const Key('institution-directory-pagination-footer-surface'),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            CoeloSpacing.space3,
            horizontalPadding,
            CoeloSpacing.space3,
          ),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.88),
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: InstitutionDirectoryPagination(
              viewModel: viewModel,
              pageSizeOptions: display == InstitutionDirectoryDisplay.cards
                  ? const [11, 20, 50, 100]
                  : const [8, 20, 50, 100],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the fixed-footer tests and verify GREEN**

Run the three commands from Step 2.

Expected: all three PASS.

- [ ] **Step 6: Adapt existing pagination interaction tests**

Remove `scrollUntilVisible` calls whose target is
`coelo-admin-pagination-content`; the footer is no longer a descendant of the
`ListView`. Preserve the page navigation assertions and horizontal centering
assertions directly against the always-visible footer.

- [ ] **Step 7: Run the complete Institution widget test**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/institutions/presentation/screens/institution_directory_page_test.dart
```

Expected: PASS with no layout exceptions at the approved viewport matrix.

### Task 3: Visual regression and memory

**Files:**
- Modify: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart`
- Update: `apps/superadmin/test/features/institutions/presentation/screens/goldens/*.png`
- Modify: `docs/knowledge/team/superadmin-institution-directory.md`

**Interfaces:**
- Consumes: keys from Task 2.
- Produces: golden coverage for the fixed glass footer.
- Produces: validated knowledge projection sourced from the approved sticky-pagination spec.

- [ ] **Step 1: Update the focused golden test for the always-visible footer**

In `matches disabled pagination references`, remove the
`scrollUntilVisible` block and assert:

```dart
expect(
  find.byKey(const Key('institution-directory-pagination-footer')),
  findsOneWidget,
);
```

Keep both existing golden assertions for the closed and open page-size states.

- [ ] **Step 2: Run the golden suite and verify expected mismatch**

Run from `apps/superadmin`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart
```

Expected: FAIL with golden mismatches because the pagination moved to the fixed glass footer and table row count changed.

- [ ] **Step 3: Regenerate the Institution goldens**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart --update-goldens
```

Expected: PASS and update only Institution golden PNGs.

- [ ] **Step 4: Inspect representative outputs**

Inspect at minimum:

- `institution_directory_cards_light_1440.png`
- `institution_directory_table_light_1440.png`
- `institution_directory_cards_dark_375.png`
- `institution_directory_pagination_page_size_open_light_1440.png`

Confirm fixed bottom alignment, restrained blur surface, complete last row/card,
compact wrapping, menu visibility, and no overlap with the chat launcher.

- [ ] **Step 5: Update durable knowledge**

Change the projection frontmatter source to:

```yaml
source: docs/superpowers/specs/2026-07-28-superadmin-institution-sticky-pagination-design.md
```

Replace the page-size paragraph and add the fixed-footer rule:

```markdown
O seletor de itens por página é compacto, usa gatilho pill e menu neutro com a
mesma largura do gatilho. A opção selecionada, hover e foco usam
`primaryContainer` e `primary`, sem check ou checkbox. Cards oferecem
`11, 20, 50, 100`; tabela oferece `8, 20, 50, 100`.

Nos modos cards e tabela, a paginação permanece fixa no limite inferior da área
útil sobre uma faixa local translúcida com blur. O conteúdo rolável reserva a
altura real do rodapé mais o espaçamento de segurança, mantendo o último item
totalmente visível. Essa composição é específica do diretório e não cria
variante pública no Coelo UI.
```

- [ ] **Step 6: Run formatting, analysis, tests, and knowledge gates**

From the repository root:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart
& '.agents\skills\coelo-knowledge\scripts\Test-CoeloKnowledge.ps1'
& '.agents\skills\coelo-knowledge\tests\Test-CoeloKnowledge.ps1'
git diff --check
```

Expected: format unchanged, both test files PASS, analysis reports no issues,
both knowledge gates PASS, and `git diff --check` exits 0.

- [ ] **Step 7: Review the final diff**

Run:

```powershell
git status --short
git diff -- apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart docs/knowledge/team/superadmin-institution-directory.md
```

Confirm no public component/token changes and no unrelated files.
