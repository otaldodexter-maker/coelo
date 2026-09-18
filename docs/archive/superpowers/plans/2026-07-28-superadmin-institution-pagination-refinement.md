---
source: "docs/superpowers/specs/2026-07-28-superadmin-institution-pagination-refinement-design.md"
status: "approved"
generated_at: "2026-07-28"
---

# Superadmin Institution Pagination Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralizar a paginação de Instituições nos modos cards e tabela e substituir o dropdown cinza de quantidade por página por um single-select compacto conforme o Design System Coelo.

**Architecture:** `CoeloAdminPagination` mantém sua API pública e passa a centralizar o próprio `Wrap`. Um widget privado no mesmo arquivo compõe o seletor com `MenuAnchor`, tokens existentes e opções fornecidas pelo consumidor; Instituições remove o alinhamento à direita e o catálogo passa a demonstrar o estado completo.

**Tech Stack:** Flutter, Dart, `coelo_tokens`, `coelo_ui_admin`, `flutter_test`, goldens Flutter.

## Global Constraints

- Não criar API pública, variante, dependência ou token novo.
- Preservar `CoeloAdminPagination` como `StatelessWidget` público e `const`.
- Usar apenas tokens Coelo para dimensões visuais.
- Menu usa `colorScheme.surface`, `surfaceTintColor: Colors.transparent`, borda `outlineVariant`, `CoeloRadius.lg` e elevação semântica.
- Single-select acompanha exatamente a largura do gatilho e não usa check nem checkbox.
- Seleção, hover e foco usam `primaryContainer` com conteúdo `primary`.
- Opções têm alvo mínimo de `CoeloSize.touchMin`.
- O conjunto completo e cada quebra do `Wrap` ficam centralizados.
- Preservar cards em `11, 20, 50, 100` e tabela em `9, 20, 50, 100`.
- Verificar 375, 768, 1024 e 1440 px em light e dark.
- Preservar todas as alterações locais não relacionadas.

---

## File Map

- Modify `packages/coelo_ui_admin/lib/src/listing/coelo_admin_pagination.dart`: centralização e seletor privado baseado em `MenuAnchor`.
- Modify `packages/coelo_ui_admin/test/listing/coelo_admin_pagination_test.dart`: contratos de alinhamento, superfície, largura, seleção, teclado e callback.
- Modify `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`: remover alinhamento local à direita.
- Modify `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`: centralização abaixo de cards e tabela.
- Modify `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart`: proteger o menu aberto.
- Create `apps/superadmin/test/features/institutions/presentation/screens/goldens/institution_directory_pagination_page_size_open_light_1440.png`: baseline do seletor aberto.
- Modify `apps/superadmin/test/features/institutions/presentation/screens/goldens/institution_directory_pagination_disabled_light_1440.png`: baseline centralizado.
- Modify `apps/catalog/lib/catalog/catalog_registry.dart`: demonstrar quantidade por página na amostra oficial.
- Modify `apps/catalog/assets/coelo-ui.index.jsonl`: registrar estados, tokens e acessibilidade do contrato aprovado.
- Modify `apps/catalog/test/catalog/catalog_registry_examples_test.dart`: exigir o seletor no exemplo real.
- Create `docs/knowledge/team/superadmin-institution-directory.md`: projetar a regra aprovada para consulta interna.

---

### Task 1: Centralização e single-select do componente compartilhado

**Files:**
- Modify: `packages/coelo_ui_admin/lib/src/listing/coelo_admin_pagination.dart`
- Test: `packages/coelo_ui_admin/test/listing/coelo_admin_pagination_test.dart`

**Interfaces:**
- Consumes: `CoeloSpacing`, `CoeloSize`, `CoeloRadius`, `CoeloElevation` e `Theme.of(context).colorScheme`.
- Preserves: `CoeloAdminPagination({currentPage, totalPages, onPrevious, onNext, onPageSelected, pageSize, pageSizeOptions, onPageSizeChanged})`.
- Produces: chaves privadas de teste `coelo-admin-pagination-content`, `coelo-admin-pagination-page-size-anchor` e `coelo-admin-pagination-page-size-{option}`.

- [ ] **Step 1: Write failing alignment and menu-contract tests**

Add these assertions to `coelo_admin_pagination_test.dart`. Extend the existing
`selects a numbered page and changes the accessible page size` test so the
callback remains covered:

```dart
testWidgets('centers the pagination content and wrapped runs', (tester) async {
  await tester.binding.setSurfaceSize(const Size(520, 220));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: const Scaffold(
        body: CoeloAdminPagination(
          currentPage: 5,
          totalPages: 10,
          onPrevious: _noop,
          onNext: _noop,
          pageSize: 20,
          pageSizeOptions: [11, 20, 50, 100],
        ),
      ),
    ),
  );

  final content = tester.widget<Wrap>(
    find.byKey(const Key('coelo-admin-pagination-content')),
  );
  expect(content.alignment, WrapAlignment.center);
});

testWidgets('uses the approved compact single-select surface', (tester) async {
  var selectedPageSize = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: CoeloAdminPagination(
          currentPage: 1,
          totalPages: 2,
          onPrevious: null,
          onNext: _noop,
          pageSize: 20,
          pageSizeOptions: const [11, 20, 50, 100],
          onPageSizeChanged: (value) => selectedPageSize = value,
        ),
      ),
    ),
  );

  final trigger = find.byKey(const Key('coelo-admin-pagination-page-size'));
  expect(find.byType(DropdownButton<int>), findsNothing);
  await tester.tap(trigger);
  await tester.pumpAndSettle();

  final anchor = tester.widget<MenuAnchor>(
    find.byKey(const Key('coelo-admin-pagination-page-size-anchor')),
  );
  final triggerWidth = tester.getSize(trigger).width;
  expect(anchor.crossAxisUnconstrained, isFalse);
  expect(anchor.style!.backgroundColor!.resolve({}), CoeloTheme.light.colorScheme.surface);
  expect(anchor.style!.surfaceTintColor!.resolve({}), Colors.transparent);
  expect(anchor.style!.minimumSize!.resolve({})!.width, triggerWidth);
  expect(anchor.style!.maximumSize!.resolve({})!.width, triggerWidth);
  expect(find.byType(Checkbox), findsNothing);
  expect(find.byIcon(Icons.check_rounded), findsNothing);

  final selected = tester.widget<MenuItemButton>(
    find.byKey(const Key('coelo-admin-pagination-page-size-20')),
  );
  expect(
    selected.style!.backgroundColor!.resolve({}),
    CoeloTheme.light.colorScheme.primaryContainer,
  );

  await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size-50')));
  await tester.pumpAndSettle();
  expect(selectedPageSize, 50);
});

testWidgets('closes the page-size menu with Escape and returns focus', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: CoeloAdminPagination(
          currentPage: 1,
          totalPages: 2,
          onPrevious: null,
          onNext: _noop,
          pageSize: 20,
          pageSizeOptions: const [11, 20, 50, 100],
          onPageSizeChanged: (_) {},
        ),
      ),
    ),
  );

  final trigger = find.byKey(const Key('coelo-admin-pagination-page-size'));
  await tester.tap(trigger);
  await tester.pumpAndSettle();
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();

  expect(find.byType(MenuItemButton), findsNothing);
  expect(tester.widget<OutlinedButton>(trigger).focusNode!.hasFocus, isTrue);
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run from `packages/coelo_ui_admin`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/listing/coelo_admin_pagination_test.dart
```

Expected: FAIL because the current `Wrap` has no test key and uses
`WrapAlignment.end`, and the page-size control is still `DropdownButton<int>`.

- [ ] **Step 3: Implement the private page-size selector and centered Wrap**

In `_CoeloAdminPaginationContentState.build`, replace the page-size
`DropdownButton<int>` row child with:

```dart
_PageSizeSelector(
  value: pageSize,
  options: widget.pageSizeOptions,
  onChanged: widget.onPageSizeChanged,
),
```

Change the existing `Wrap` declaration from:

```dart
return Wrap(
  alignment: WrapAlignment.end,
```

to:

```dart
return Wrap(
  key: const Key('coelo-admin-pagination-content'),
  alignment: WrapAlignment.center,
```

Add this private widget in the same file, before `_visiblePages`:

```dart
final class _PageSizeSelector extends StatefulWidget {
  const _PageSizeSelector({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int value;
  final List<int> options;
  final ValueChanged<int>? onChanged;

  @override
  State<_PageSizeSelector> createState() => _PageSizeSelectorState();
}

final class _PageSizeSelectorState extends State<_PageSizeSelector> {
  static const _width = CoeloSpacing.space20;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = widget.onChanged != null;
    return Semantics(
      label: 'Quantidade de itens por página',
      value: '${widget.value}',
      enabled: enabled,
      child: MenuAnchor(
        key: const Key('coelo-admin-pagination-page-size-anchor'),
        childFocusNode: _focusNode,
        crossAxisUnconstrained: false,
        alignmentOffset: const Offset(0, CoeloSpacing.space1),
        onClose: _focusNode.requestFocus,
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(CoeloElevation.level3),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          minimumSize: const WidgetStatePropertyAll(Size(_width, 0)),
          maximumSize: const WidgetStatePropertyAll(Size(_width, double.infinity)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              side: BorderSide(color: colors.outlineVariant),
            ),
          ),
        ),
        menuChildren: [
          for (final option in widget.options)
            SizedBox(
              width: _width,
              child: MenuItemButton(
                key: Key('coelo-admin-pagination-page-size-$option'),
                onPressed: enabled ? () => widget.onChanged!(option) : null,
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(
                    Size.fromHeight(CoeloSize.touchMin),
                  ),
                  shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        option == widget.value ||
                            states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused)
                        ? colors.primary
                        : colors.onSurface,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        option == widget.value ||
                            states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused)
                        ? colors.primaryContainer
                        : colors.surface,
                  ),
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                ),
                child: Text('$option'),
              ),
            ),
        ],
        builder: (context, menu, child) {
          final active = menu.isOpen;
          return OutlinedButton(
            key: const Key('coelo-admin-pagination-page-size'),
            focusNode: _focusNode,
            onPressed: enabled ? () => active ? menu.close() : menu.open() : null,
            style: ButtonStyle(
              fixedSize: const WidgetStatePropertyAll(
                Size(_width, CoeloSize.touchMin),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
              ),
              shape: const WidgetStatePropertyAll(StadiumBorder()),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    active ||
                        states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    active ||
                        states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)
                    ? colors.primaryContainer
                    : colors.surface,
              ),
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color:
                      active ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? colors.primary
                      : colors.outlineVariant,
                ),
              ),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${widget.value}'),
                Icon(
                  active
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Format and verify GREEN**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib/src/listing/coelo_admin_pagination.dart test/listing/coelo_admin_pagination_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/listing/coelo_admin_pagination_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze
```

Expected: format changes only the two files; test exits 0 with all pagination
tests passing; analysis exits 0 without issues.

- [ ] **Step 5: Commit the shared component**

```powershell
git add packages/coelo_ui_admin/lib/src/listing/coelo_admin_pagination.dart packages/coelo_ui_admin/test/listing/coelo_admin_pagination_test.dart
git commit -m "fix(ui): center and restyle admin pagination"
```

---

### Task 2: Integrar Instituições e proteger a referência visual

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`
- Modify: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`
- Modify: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart`
- Create: `apps/superadmin/test/features/institutions/presentation/screens/goldens/institution_directory_pagination_page_size_open_light_1440.png`
- Modify: `apps/superadmin/test/features/institutions/presentation/screens/goldens/institution_directory_pagination_disabled_light_1440.png`

**Interfaces:**
- Consumes: `coelo-admin-pagination-content` and `coelo-admin-pagination-page-size` from Task 1.
- Preserves: `InstitutionDirectoryPagination` and the existing view-model callbacks.
- Produces: centered layout in `InstitutionDirectoryDisplay.cards` and `InstitutionDirectoryDisplay.table`.

- [ ] **Step 1: Write a failing integration test for both display modes**

Add a test using the same 21-item repository construction already used by
`paginates the directory in groups of twenty items`:

```dart
testWidgets('centers pagination below cards and table', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _app(
      repository: FakeInstitutionDirectoryRepository(
        items: List.generate(
          21,
          (index) => InstitutionDirectoryItem(
            id: 'centered-institution-$index',
            publicName: 'Instituição ${index + 1}',
            tradeName: null,
            legalName: null,
            primaryDomain: null,
            status: InstitutionStatus.active,
            typeId: null,
            typeName: null,
            city: null,
            state: null,
            planId: null,
            planName: null,
            unitsCount: 0,
            groupsCount: 0,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final pagination = find.byKey(const Key('coelo-admin-pagination-content'));
  await tester.scrollUntilVisible(
    pagination,
    600,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('institution-directory-content-scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  expect(
    tester.getCenter(pagination).dx,
    closeTo(tester.getCenter(find.byKey(const Key('institution-card-grid'))).dx, 1),
  );

  await tester.ensureVisible(find.byKey(const Key('institution-view-table')));
  await tester.tap(find.byKey(const Key('institution-view-table')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    pagination,
    600,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('institution-directory-content-scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  expect(
    tester.getCenter(pagination).dx,
    closeTo(
      tester.getCenter(find.byKey(const Key('institution-directory-table-viewport'))).dx,
      1,
    ),
  );
});
```

- [ ] **Step 2: Run the integration test and verify RED**

Run from `apps/superadmin`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/institutions/presentation/screens/institution_directory_page_test.dart --plain-name "centers pagination below cards and table"
```

Expected: FAIL because `Alignment.centerRight` constrains the pagination to its
intrinsic width at the right side.

- [ ] **Step 3: Remove the local right alignment**

Replace:

```dart
Align(
  alignment: Alignment.centerRight,
  child: InstitutionDirectoryPagination(
    viewModel: viewModel,
    pageSizeOptions: display == InstitutionDirectoryDisplay.cards
        ? const [11, 20, 50, 100]
        : const [9, 20, 50, 100],
  ),
),
```

with:

```dart
InstitutionDirectoryPagination(
  viewModel: viewModel,
  pageSizeOptions: display == InstitutionDirectoryDisplay.cards
      ? const [11, 20, 50, 100]
      : const [9, 20, 50, 100],
),
```

- [ ] **Step 4: Add the failing open-menu golden expectation**

At the end of `matches no-results and disabled pagination references`, after
the existing disabled-pagination golden:

```dart
await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size')));
await tester.pumpAndSettle();
await expectLater(
  find.byKey(const Key('institution-directory-golden-root')),
  matchesGoldenFile(
    'goldens/institution_directory_pagination_page_size_open_light_1440.png',
  ),
);
```

Run without updating:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart --plain-name "matches no-results and disabled pagination references"
```

Expected: FAIL because the new open-menu golden does not exist and the previous
pagination baseline still reflects right alignment.

- [ ] **Step 5: Generate and visually inspect the focused goldens**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib/features/institutions/presentation/screens/institution_directory_page.dart test/features/institutions/presentation/screens/institution_directory_page_test.dart test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart --plain-name "matches no-results and disabled pagination references" --update-goldens
```

Inspect
`test/features/institutions/presentation/screens/goldens/institution_directory_pagination_disabled_light_1440.png`
and
`test/features/institutions/presentation/screens/goldens/institution_directory_pagination_page_size_open_light_1440.png`.
Confirm centered composition, neutral menu surface, pill trigger, orange selected
row, continuous options, no check, and no overlap with the chat launcher.

- [ ] **Step 6: Verify integration and the full institution golden matrix**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/institutions/presentation/screens/institution_directory_page_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze
```

Expected: both test files exit 0; the 375/768/1024/1440 light/dark matrix has no
golden mismatch or layout exception; analysis exits 0.

- [ ] **Step 7: Commit the Institutions integration**

```powershell
git add apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart apps/superadmin/test/features/institutions/presentation/screens/goldens/institution_directory_pagination_disabled_light_1440.png apps/superadmin/test/features/institutions/presentation/screens/goldens/institution_directory_pagination_page_size_open_light_1440.png
git commit -m "fix(superadmin): center institution pagination"
```

---

### Task 3: Atualizar catálogo, índice e memória interna

**Files:**
- Modify: `apps/catalog/lib/catalog/catalog_registry.dart`
- Modify: `apps/catalog/assets/coelo-ui.index.jsonl`
- Modify: `apps/catalog/test/catalog/catalog_registry_examples_test.dart`
- Create: `docs/knowledge/team/superadmin-institution-directory.md`

**Interfaces:**
- Consumes: `CoeloAdminPagination` sem mudança de assinatura.
- Produces: exemplo interativo com `pageSize` e entrada `admin.pagination` sincronizada.
- Produces: conhecimento interno `superadmin-institution-directory`, derivado do design aprovado.

- [ ] **Step 1: Write a failing catalog-example test**

Add to `catalog_registry_examples_test.dart`:

```dart
testWidgets('pagination example exposes the approved page-size selector', (tester) async {
  final example = buildCatalogRegistry()['admin.pagination']!;
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(body: _ExampleHost(example: example)),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('coelo-admin-pagination-page-size')), findsOneWidget);
  expect(find.text('Itens por página'), findsOneWidget);
});
```

- [ ] **Step 2: Run the catalog test and verify RED**

Run from `apps/catalog`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/catalog/catalog_registry_examples_test.dart --plain-name "pagination example exposes the approved page-size selector"
```

Expected: FAIL because `_PaginationExampleState` does not provide `pageSize`.

- [ ] **Step 3: Complete the catalog example and index entry**

Replace `_PaginationExampleState` with:

```dart
final class _PaginationExampleState extends State<_PaginationExample> {
  var _page = 1;
  var _pageSize = 20;

  @override
  Widget build(BuildContext context) {
    return CoeloAdminPagination(
      currentPage: _page,
      totalPages: 4,
      onPrevious: _page == 1 ? null : () => setState(() => _page--),
      onNext: _page == 4 ? null : () => setState(() => _page++),
      pageSize: _pageSize,
      pageSizeOptions: const [11, 20, 50, 100],
      onPageSizeChanged: (value) => setState(() {
        _pageSize = value;
        _page = 1;
      }),
    );
  }
}
```

Replace the complete `admin.pagination` JSONL entry with:

```json
{"id":"admin.pagination","name":"CoeloAdminPagination","category":"component","status":"implemented","ownerPackage":"coelo_ui_admin","consumers":["superadmin"],"purpose":"Navegar por paginas de listagens administrativas.","useWhen":"A fonte informa pagina atual e total de paginas.","doNotUseWhen":"A lista usa carregamento continuo.","variants":[],"states":["enabled","focused","disabled","open","hovered","selected","wrapped"],"tokens":["size.touch-min","spacing.1","spacing.2","spacing.3","spacing.20","radius.full","radius.lg","color.surface","color.outline-variant","color.primary","color.primary-container","elevation.level3"],"accessibility":"Acoes e seletor possuem rotulos semanticos, foco visivel e estado disabled; Enter e Espaco acionam o controle focado, Esc fecha o menu e as quebras permanecem centralizadas.","publicFile":"packages/coelo_ui_admin/lib/coelo_ui_admin.dart","tests":["packages/coelo_ui_admin/test/listing/coelo_admin_pagination_test.dart"],"example":"CoeloAdminPagination(currentPage: page, totalPages: totalPages, onPrevious: previous, onNext: next, pageSize: pageSize, pageSizeOptions: const [11, 20, 50, 100], onPageSizeChanged: changePageSize)","replacement":null}
```

- [ ] **Step 4: Create the validated knowledge projection**

Create `docs/knowledge/team/superadmin-institution-directory.md`:

```markdown
---
title: Diretório de instituições do Superadmin
knowledge_id: superadmin-institution-directory
source: docs/superpowers/specs/2026-07-28-superadmin-institution-pagination-refinement-design.md
status: validated
generated_at: 2026-07-28
audience: team
surfaces: [superadmin, institutions]
visibility: internal
review_owner: Coelo Product
---

# Diretório de instituições do Superadmin

A paginação do diretório de Instituições usa `CoeloAdminPagination` nos modos de
cards e tabela. O conjunto completo fica centralizado e mantém cada quebra
responsiva centralizada.

O seletor de itens por página é compacto, usa gatilho pill e menu neutro com a
mesma largura do gatilho. A opção selecionada, hover e foco usam
`primaryContainer` e `primary`, sem check ou checkbox. Cards oferecem
`11, 20, 50, 100`; tabela oferece `9, 20, 50, 100`.

O contrato reutilizável está em `admin.pagination` e
`pattern.selection-controls` no índice Coelo UI. Não existe variante pública
específica de Instituições.
```

- [ ] **Step 5: Format and verify catalog plus knowledge gates**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib/catalog/catalog_registry.dart test/catalog/catalog_registry_examples_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/catalog/catalog_registry_examples_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_catalog_index.dart assets/coelo-ui.index.jsonl ..\..
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_package_boundaries.dart assets/coelo-ui.index.jsonl ..\..
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_catalog_sync.dart assets/coelo-ui.index.jsonl lib/catalog/catalog_registry.dart assets/catalog-sync-report.json ..\..
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze
```

From the repository root:

```powershell
& '.agents\skills\coelo-knowledge\scripts\Test-CoeloKnowledge.ps1'
& '.agents\skills\coelo-knowledge\tests\Test-CoeloKnowledge.ps1'
```

Expected: focused catalog tests, three catalog validators, catalog analysis and
both knowledge validators exit 0.

- [ ] **Step 6: Run final verification and inspect the exact diff**

From the repository root:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed packages/coelo_ui_admin/lib/src/listing/coelo_admin_pagination.dart packages/coelo_ui_admin/test/listing/coelo_admin_pagination_test.dart apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart apps/catalog/lib/catalog/catalog_registry.dart apps/catalog/test/catalog/catalog_registry_examples_test.dart
git diff --check
git status --short
git diff -- packages/coelo_ui_admin/lib/src/listing/coelo_admin_pagination.dart packages/coelo_ui_admin/test/listing/coelo_admin_pagination_test.dart apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart apps/catalog/lib/catalog/catalog_registry.dart apps/catalog/assets/coelo-ui.index.jsonl apps/catalog/test/catalog/catalog_registry_examples_test.dart docs/knowledge/team/superadmin-institution-directory.md
```

Confirm only the intended source, tests, two pagination goldens, catalog entry,
catalog example and knowledge projection are in scope. Do not stage the
pre-existing unrelated failure images or documentation changes.

- [ ] **Step 7: Commit catalog and memory**

```powershell
git add apps/catalog/lib/catalog/catalog_registry.dart apps/catalog/assets/coelo-ui.index.jsonl apps/catalog/test/catalog/catalog_registry_examples_test.dart docs/knowledge/team/superadmin-institution-directory.md
git commit -m "docs(ui): register centered pagination contract"
```
