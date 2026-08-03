---
source: "docs/superpowers/specs/2026-08-03-coelo-admin-visual-contract-enforcement-design.md"
status: "approved-for-implementation"
generated_at: "2026-08-03"
---

# Coelo Admin Visual Contract Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar hover, cards e flyouts administrativos aprovados em componentes reutilizáveis e em um gate bloqueante que impeça regressões Material genéricas.

**Architecture:** O pacote `coelo_ui_admin` passa a controlar a aparência de cards interativos e flyouts. Um validador Dart, executado pelo catálogo e pela skill, bloqueia widgets crus nas features do Superadmin usando uma allowlist contada e justificada para legado. As telas novas e os exemplos do catálogo consomem os componentes reais.

**Tech Stack:** Flutter/Dart, `flutter_test`, PowerShell para consulta do índice, JSONL do catálogo, Markdown com frontmatter.

## Global Constraints

- Preservar integralmente alterações não relacionadas já presentes no worktree.
- Instituições é a baseline visual canônica.
- Hover de card preserva `surface`; borda e sombra recebem ênfase primária.
- Flyout usa `surface`, tint transparente, `CoeloRadius.lg`, borda, elevação e `space2`.
- Item discreto usa `primaryContainer`/`primary`; item negativo usa `errorContainer`/`error`.
- Nenhum golden será atualizado para esconder regressão.
- Todo comportamento novo segue RED-GREEN e recebe verificação fresca antes de commit.
- Comandos de shell são executados por `rtk` conforme `RTK.md`.

---

## Mapa de arquivos

- `packages/coelo_ui_admin/lib/src/surface/coelo_admin_interactive_card.dart`: card canônico e seus estados.
- `packages/coelo_ui_admin/lib/src/overlay/coelo_admin_flyout.dart`: flyout, itens e grupos canônicos.
- `packages/coelo_ui_admin/lib/coelo_ui_admin.dart`: exports públicos.
- `packages/coelo_ui_admin/test/surface/coelo_admin_interactive_card_test.dart`: hover, foco, raio e reduced motion.
- `packages/coelo_ui_admin/test/overlay/coelo_admin_flyout_test.dart`: superfície e variantes de item.
- `apps/catalog/tool/validate_admin_visual_contracts.dart`: scanner bloqueante.
- `apps/catalog/assets/admin-visual-contract-allowlist.json`: legado contado e justificado.
- `apps/catalog/test/tool/validate_admin_visual_contracts_test.dart`: fixtures válidas e inválidas.
- `.agents/skills/coelo-ui/scripts/query-index.ps1`: fallback ranqueado.
- `.agents/skills/coelo-ui/tests/query-index.tests.ps1`: consulta natural combinada.
- `apps/superadmin/lib/features/institutions/presentation/widgets/institution_directory_cards.dart`: adoção do card canônico.
- `apps/superadmin/lib/features/daily_routine/daily_routine_pages.dart`: correção do card atual.
- `apps/superadmin/lib/features/health_safety/presentation/health_safety_directory_page.dart`: correção do card atual.
- `apps/superadmin/lib/features/attendance/attendance_pages.dart`: migração do menu de presença.
- `apps/superadmin/lib/features/support/presentation/screens/support_page.dart`: migração do menu de status.
- `apps/superadmin/lib/features/institutions/presentation/widgets/institution_form_sections.dart`: migração do popup local.
- Testes correspondentes nas features: comportamento e tipos canônicos.
- `apps/catalog/lib/catalog/approved_superadmin_catalog_foundation.dart`: exemplos executáveis.
- `apps/catalog/assets/coelo-ui.index.jsonl`: registro dos componentes e comandos.
- `.agents/skills/coelo-ui/SKILL.md`, referências, `docs/design/design-system.md`, `apps/catalog/README.md` e memória: gates persistentes.

### Task 1: Card administrativo interativo canônico

**Files:**
- Create: `packages/coelo_ui_admin/test/surface/coelo_admin_interactive_card_test.dart`
- Create: `packages/coelo_ui_admin/lib/src/surface/coelo_admin_interactive_card.dart`
- Modify: `packages/coelo_ui_admin/lib/coelo_ui_admin.dart`

**Interfaces:**
- Produces: `CoeloAdminInteractiveCard({Widget child, VoidCallback? onPressed, String? semanticLabel, Key? surfaceKey, double? minHeight})`.
- The surface key resolves to an `AnimatedContainer` whose `BoxDecoration` is inspectable by tests.

- [ ] **Step 1: Write the failing widget tests**

```dart
testWidgets('preserves surface and rounds the entire hover target', (tester) async {
  await pumpCard(tester);
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer();
  await mouse.moveTo(tester.getCenter(find.byType(CoeloAdminInteractiveCard)));
  await tester.pumpAndSettle();
  final surface = tester.widget<AnimatedContainer>(find.byKey(const Key('surface')));
  final decoration = surface.decoration! as BoxDecoration;
  expect(decoration.color, CoeloTheme.light.colorScheme.surface);
  expect(decoration.borderRadius, BorderRadius.circular(CoeloRadius.lg));
  expect((decoration.border! as Border).top.color,
      CoeloTheme.light.colorScheme.primary.withValues(alpha: 0.5));
  final ink = tester.widget<InkWell>(find.byType(InkWell));
  expect(ink.borderRadius, BorderRadius.circular(CoeloRadius.lg));
  expect(ink.overlayColor!.resolve({WidgetState.hovered}), Colors.transparent);
});
```

- [ ] **Step 2: Run RED**

Run: `rtk test C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test packages/coelo_ui_admin/test/surface/coelo_admin_interactive_card_test.dart`

Expected: FAIL because `CoeloAdminInteractiveCard` does not exist.

- [ ] **Step 3: Implement the minimal component**

Use `MouseRegion`, `InkWell.onFocusChange`, `AnimatedContainer`, semantic theme colors, `CoeloRadius.lg`, transparent overlay and duration zero when `MediaQuery.disableAnimationsOf(context)` is true. Do not expose color, border, radius, overlay or elevation parameters.

- [ ] **Step 4: Run GREEN and package analysis**

Run the targeted test and `rtk proxy C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze packages/coelo_ui_admin --fatal-infos`.

- [ ] **Step 5: Commit only Task 1 files**

Commit: `feat(ui-admin): add canonical interactive card`

### Task 2: Flyout administrativo canônico

**Files:**
- Create: `packages/coelo_ui_admin/test/overlay/coelo_admin_flyout_test.dart`
- Create: `packages/coelo_ui_admin/lib/src/overlay/coelo_admin_flyout.dart`
- Modify: `packages/coelo_ui_admin/lib/coelo_ui_admin.dart`

**Interfaces:**
- Produces: `enum CoeloAdminFlyoutTone { standard, negative }`.
- Produces: `CoeloAdminFlyoutItem<T>({required T value, required String label, IconData? icon, bool selected = false, bool enabled = true, bool startsGroup = false, CoeloAdminFlyoutTone tone = standard})`.
- Produces: `CoeloAdminFlyout<T>({required List<CoeloAdminFlyoutItem<T>> items, required ValueChanged<T> onSelected, required Widget Function(BuildContext, MenuController) builder, double itemWidth = 220, Offset alignmentOffset = const Offset(0, CoeloSpacing.space1)})`.

- [ ] **Step 1: Write failing tests for shell and item states**

```dart
expect(anchor.style?.backgroundColor?.resolve({}), colors.surface);
expect(anchor.style?.surfaceTintColor?.resolve({}), Colors.transparent);
expect(normal.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.primaryContainer);
expect(negative.style?.foregroundColor?.resolve({}), colors.error);
expect(negative.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.errorContainer);
expect(find.byType(Divider), findsOneWidget);
```

- [ ] **Step 2: Run RED**

Expected: FAIL because the flyout API does not exist.

- [ ] **Step 3: Implement with `MenuAnchor` and `MenuItemButton` internally**

Only this package implementation owns `MenuStyle` and `ButtonStyle`. `startsGroup` inserts a divider and spacing before the item. Selection remains textual and semantic; no automatic check icon.

- [ ] **Step 4: Run GREEN in light and dark**

Run the test file and the full `coelo_ui_admin` test directory.

- [ ] **Step 5: Commit only Task 2 files**

Commit: `feat(ui-admin): add canonical flyout`

### Task 3: Validador visual bloqueante

**Files:**
- Create: `apps/catalog/test/tool/validate_admin_visual_contracts_test.dart`
- Create: `apps/catalog/tool/validate_admin_visual_contracts.dart`
- Create: `apps/catalog/assets/admin-visual-contract-allowlist.json`
- Modify: `apps/catalog/README.md`

**Interfaces:**
- Produces: `List<AdminVisualDiagnostic> validateAdminVisualContracts({required Directory root, required File allowlist})`.
- CLI: `dart run tool/validate_admin_visual_contracts.dart <repo-root> <allowlist.json>`.
- Allowlist item: `{ "path": "relative/path.dart", "symbol": "InkWell", "maxOccurrences": 2, "reason": "Existing non-card interaction with explicit Coelo states" }`.

- [ ] **Step 1: Write failing fixture tests**

Cover prohibited `PopupMenuButton`, `PopupMenuItem`, `MenuAnchor`, `MenuItemButton` and card-like `InkWell`; valid canonical import; missing file; empty reason; exceeded count; and a repository fixture with zero diagnostics.

- [ ] **Step 2: Run RED**

Expected: FAIL because the validator and allowlist parser do not exist.

- [ ] **Step 3: Implement deterministic scanning**

Scan `apps/superadmin/lib/features/**/*.dart`. Count exact constructor tokens after stripping line/block comments and string literals sufficiently for deterministic fixtures. Emit sorted diagnostics containing path, line, symbol and replacement. Validate every allowlist entry before applying it.

- [ ] **Step 4: Inventory legacy intentionally**

Run the validator, inspect every finding and add only current justified legacy occurrences with exact maximum counts. Do not allowlist Assiduidade, Rotina diária, Saúde e segurança or the three raw popup menus scheduled for migration.

- [ ] **Step 5: Run GREEN and prove regression detection**

Run targeted tests, run the real repository validator expecting exit 0, temporarily add a forbidden fixture occurrence and confirm nonzero exit, then restore and rerun expecting zero.

- [ ] **Step 6: Commit only validator files**

Commit: `test(ui): block raw admin interaction widgets`

### Task 4: Descoberta robusta no índice

**Files:**
- Modify: `.agents/skills/coelo-ui/tests/query-index.tests.ps1`
- Modify: `.agents/skills/coelo-ui/scripts/query-index.ps1`

**Interfaces:**
- Exact all-term matches remain first.
- When exact results are empty, return entries matching at least one term ordered by descending matched-term count and then `id`.

- [ ] **Step 1: Add the failing natural-language query**

```powershell
Assert-QueryContains -Query 'hover cinza reto flyout instituições card' `
  -ExpectedId 'pattern.admin-directory'
Assert-QueryContains -Query 'hover cinza reto flyout instituições card' `
  -ExpectedId 'pattern.flyout-actions'
```

- [ ] **Step 2: Run RED**

Expected: the query returns zero entries.

- [ ] **Step 3: Implement ranked fallback without changing filtered exact queries**

Track matched terms for each entry, apply fallback only when the exact result set is empty and preserve existing `Id`, consumer, owner and status filters.

- [ ] **Step 4: Run GREEN and all query tests**

Run: `rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File .agents\skills\coelo-ui\tests\query-index.tests.ps1`.

- [ ] **Step 5: Commit**

Commit: `fix(ui-index): rank broad visual queries`

### Task 5: Migrar cards atuais

**Files:**
- Modify: `apps/superadmin/test/features/daily_routine/daily_routine_pages_test.dart`
- Modify: `apps/superadmin/test/features/health_safety/presentation/health_safety_directory_page_test.dart`
- Modify: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`
- Modify: corresponding production files.

**Interfaces:**
- Consumes: `CoeloAdminInteractiveCard` from Task 1.

- [ ] **Step 1: Add failing type and hover assertions**

Assert each directory renders `CoeloAdminInteractiveCard`, does not render a raw card `InkWell` for the migrated surface, and preserves `surface`, rounded radius and primary border during mouse hover.

- [ ] **Step 2: Run RED for all three features**

Expected: current screens still expose raw `InkWell` or the canonical type is absent.

- [ ] **Step 3: Migrate Rotina diária and Saúde e segurança**

Replace only the clickable card shell. Preserve width, content, callbacks, keys, permissions and domain behavior.

- [ ] **Step 4: Migrate Instituições without visual drift**

Replace `_InstitutionCardState` hover machinery with `CoeloAdminInteractiveCard`, preserving card keys, `minHeight: 216`, padding and content.

- [ ] **Step 5: Run GREEN and the Institutions card-hover golden**

The existing approved golden must pass unchanged. If it fails, inspect the diff; do not update the golden during this task.

- [ ] **Step 6: Commit only migrated card files and tests**

Commit: `refactor(superadmin): use canonical interactive cards`

### Task 6: Migrar flyouts atuais

**Files:**
- Modify tests for attendance, support and institution form sections.
- Modify: `apps/superadmin/lib/features/attendance/attendance_pages.dart`
- Modify: `apps/superadmin/lib/features/support/presentation/screens/support_page.dart`
- Modify: `apps/superadmin/lib/features/institutions/presentation/widgets/institution_form_sections.dart`

**Interfaces:**
- Consumes: `CoeloAdminFlyout<T>` and `CoeloAdminFlyoutItem<T>` from Task 2.

- [ ] **Step 1: Write failing tests**

Open each menu, assert `CoeloAdminFlyout`, assert absence of `PopupMenuButton`, inspect the open `MenuAnchor` surface and hover an item to assert `primaryContainer` with `CoeloRadius.md`.

- [ ] **Step 2: Run RED**

Expected: raw popup types remain.

- [ ] **Step 3: Migrate each menu without changing callbacks**

Map enum/string values to flyout items; selected state is textual/color semantic; preserve tooltips and keyboard activation. Use negative tone only for destructive or terminal actions.

- [ ] **Step 4: Run GREEN and real validator**

The feature tests and `validate_admin_visual_contracts.dart` must both exit 0.

- [ ] **Step 5: Commit only migrated flyout files and tests**

Commit: `refactor(superadmin): use canonical admin flyouts`

### Task 7: Catálogo, skill, Design System e memória

**Files:**
- Modify catalog foundation, index, sync report and tests.
- Modify `.agents/skills/coelo-ui/SKILL.md`, its references and tests.
- Modify `docs/design/design-system.md`, `apps/catalog/README.md` and `docs/knowledge/team/coelo-admin-interaction-hierarchy.md`.

**Interfaces:**
- Catalog foundation consumes the real package components.
- Skill gate names the exact validator command.

- [ ] **Step 1: Add failing catalog and documentation assertions**

Assert the foundation renders `CoeloAdminInteractiveCard` and `CoeloAdminFlyout`; query/index tests locate both public IDs; a documentation test or grep gate finds the exact validator command in the skill and README.

- [ ] **Step 2: Run RED**

Expected: new component IDs/examples and gate command are absent.

- [ ] **Step 3: Update canonical documentation first**

Design System records mandatory components, prohibited raw widgets, allowlist rule and validator command. Then update skill/reference, catalog entry/example and knowledge projection.

- [ ] **Step 4: Run GREEN and regenerate sync report**

Run catalog tests, index validator, package boundary validator, catalog sync validator and both knowledge gates.

- [ ] **Step 5: Commit only Task 7 files**

Commit: `docs(ui): enforce canonical admin interactions`

### Task 8: Verificação integral e entrega

**Files:** No production changes expected.

- [ ] **Step 1: Run format and static analysis**

Format only intentional Dart files. Analyze `coelo_ui_admin`, catalog and Superadmin with fatal infos.

- [ ] **Step 2: Run focused and full tests**

Run package tests, catalog full suite, affected Superadmin feature tests, approved Institutions goldens and the complete Superadmin test suite if the existing unrelated failures permit. Separate pre-existing failures from introduced failures with evidence.

- [ ] **Step 3: Run all blocking gates**

Run visual-contract validator, index query tests, catalog validators, package boundaries, sync report and knowledge gates. All new gates must exit 0.

- [ ] **Step 4: Review repository diff and commits**

Confirm no `failures/` artifact or unrelated worktree file is staged. Use exact pathspecs for any final commit.

- [ ] **Step 5: Verify localhost only after gates pass**

Restart the consolidated Superadmin server, confirm HTTP 200 and visually exercise one migrated card and one migrated flyout. Do not call the work complete if the interaction cannot be observed.
