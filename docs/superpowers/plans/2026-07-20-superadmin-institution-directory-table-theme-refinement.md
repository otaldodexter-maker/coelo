---
source: docs/superpowers/specs/2026-07-20-superadmin-institution-directory-table-theme-refinement-design.md
status: approved-plan
generated_at: 2026-07-20
---

# Institution Directory Table and Theme Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refinar cards, conter e tornar redimensionável a tabela e substituir o menu de tema por um toggle claro/escuro responsivo.

**Architecture:** Preservar view model, repositórios e shell atuais. Mapear os campos de endereço já expostos pela view, substituir somente a apresentação tabular por linhas Flutter com larguras controladas no estado e manter o tema compartilhado pelo `SuperadminThemeModeScope`.

**Tech Stack:** Flutter Material 3, Dart, `coelo_tokens`, `flutter_test`, Supabase/PostgreSQL já existente.

## Global Constraints

- Não adicionar dependências nem cores hexadecimais locais.
- O banner permanece fora da rolagem; somente a tabela rola horizontalmente.
- O tema inicia em `ThemeMode.system`, mas o controle oferece apenas claro e escuro.
- Não persistir tema ou larguras das colunas.
- Não criar migration: `street`, `number` e `complement` já existem na view.
- Preservar mouse, teclado, toque, tooltips e semântica.

---

### Task 1: Campos do endereço legal no modelo

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/domain/institution_directory_item.dart`
- Modify: `apps/superadmin/lib/features/institutions/data/fake_institution_directory_repository.dart`
- Test: `apps/superadmin/test/features/institutions/domain/institution_directory_item_test.dart`

**Interfaces:**
- Produces: `String? street`, `String? addressNumber`, `String? complement` em `InstitutionDirectoryItem`.

- [ ] **Step 1: Write the failing JSON mapping test**

```dart
expect(item.street, 'Rua das Flores');
expect(item.addressNumber, '120');
expect(item.complement, 'Sala 4');
```

- [ ] **Step 2: Run test to verify RED**

Run: `flutter test test/features/institutions/domain/institution_directory_item_test.dart`
Expected: FAIL porque os getters ainda não existem.

- [ ] **Step 3: Implement the minimal model mapping**

```dart
street: _optionalString(json['street']),
addressNumber: _optionalString(json['number']),
complement: _optionalString(json['complement']),
```

Adicionar os três argumentos opcionais ao construtor e preencher valores realistas nos registros fictícios.

- [ ] **Step 4: Run test to verify GREEN**

Run: `flutter test test/features/institutions/domain/institution_directory_item_test.dart`
Expected: PASS.

### Task 2: Densidade e status dos cards

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`
- Test: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`

**Interfaces:**
- Consumes: `InstitutionDirectoryItem` existente.
- Produces: status recolhido de 24 px e card com detalhes espaçados.

- [ ] **Step 1: Write failing widget assertions**

```dart
expect(tester.getSize(status).width, 24);
expect(tester.getSize(find.byKey(const Key('institution-card-demo-institution-aurora'))).height, lessThan(232));
expect(detailLabelBottom, lessThan(detailValueTop));
```

- [ ] **Step 2: Run the card tests to verify RED**

Run: `flutter test test/features/institutions/presentation/screens/institution_directory_page_test.dart --plain-name "uses a compact expandable status and centered card details"`
Expected: FAIL com status de 12 px e card de 232 px.

- [ ] **Step 3: Apply the minimal layout changes**

```dart
height: 216,
padding: const EdgeInsets.symmetric(
  horizontal: CoeloSpacing.space6,
  vertical: CoeloSpacing.space4,
),
```

Usar 24 px no estado recolhido do status e `SizedBox(height: CoeloSpacing.spaceHalf)` entre rótulo e valor.

- [ ] **Step 4: Run the focused card tests to verify GREEN**

Run: `flutter test test/features/institutions/presentation/screens/institution_directory_page_test.dart`
Expected: PASS.

### Task 3: Tabela contida, ordenada e redimensionável

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`
- Test: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`

**Interfaces:**
- Consumes: todos os campos de `InstitutionDirectoryItem`.
- Produces: `_ResizableInstitutionTable` com `Map<_InstitutionColumn, double>` local e divisores arrastáveis.

- [ ] **Step 1: Write failing containment, order and resize tests**

```dart
expect(tester.getSize(find.byKey(const Key('create-institution-banner'))).width,
    lessThanOrEqualTo(tester.getSize(find.byKey(const Key('institution-directory-table-viewport'))).width));
expect(headers, ['Instituição', 'Tipo', 'Unidades', 'Grupos', 'Plano', 'Status', 'E-mail',
  'Telefone', 'Celular', 'Domínio', 'Logradouro', 'Número', 'Complemento', 'Bairro', 'Município', 'UF']);
await tester.drag(find.byKey(const Key('institution-column-resizer-name')), const Offset(80, 0));
expect(tester.getSize(find.byKey(const Key('institution-column-name'))).width, greaterThan(oldWidth));
```

- [ ] **Step 2: Run tests to verify RED**

Run: `flutter test test/features/institutions/presentation/screens/institution_directory_page_test.dart`
Expected: FAIL porque banner e tabela compartilham o conteúdo de 3200 px, a ordem diverge e não há divisor.

- [ ] **Step 3: Move banner outside the horizontal scroll**

```dart
Column(
  children: [
    SizedBox(width: constraints.maxWidth, child: _CreateInstitutionBanner(onPressed: widget.onCreate)),
    const SizedBox(height: CoeloSpacing.space4),
    SizedBox(width: constraints.maxWidth, child: _ResizableInstitutionTable(...)),
  ],
)
```

- [ ] **Step 4: Implement a lightweight resizable header and rows**

Usar `enum _InstitutionColumn`, larguras iniciais/mínimas, `GestureDetector(onHorizontalDragUpdate:)` e `MouseRegion(cursor: SystemMouseCursors.resizeColumn)`. Cada célula será um `SizedBox(width: widths[column])`; o total interno será a soma das larguras.

- [ ] **Step 5: Preserve copy actions and table hover**

Reutilizar `_CopyValueButton` em E-mail, Telefone, Celular e Domínio. Implementar cada linha com `InkWell` e `overlayColor: colors.primaryContainer`, mantendo o comportamento já aprovado.

- [ ] **Step 6: Run tests to verify GREEN**

Run: `flutter test test/features/institutions/presentation/screens/institution_directory_page_test.dart`
Expected: PASS, sem overflow e com a largura da primeira coluna alterada após o drag.

### Task 4: Hover do cabeçalho e toggle de tema

**Files:**
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Test: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`
- Test: `apps/superadmin/test/app/superadmin_app_test.dart`

**Interfaces:**
- Consumes: `SuperadminThemeModeScope.mode` e `onChanged`.
- Produces: `_ThemeModeToggle` horizontal/vertical e hover baseado em `CoeloActionColors.primaryHover`.

- [ ] **Step 1: Write failing toggle and hover tests**

```dart
expect(find.text('Seguir o sistema'), findsNothing);
expect(tester.getSize(find.byKey(const Key('superadmin-theme-mode-control'))).width,
    greaterThan(tester.getSize(find.byKey(const Key('superadmin-theme-mode-control'))).height));
expect(bugStyle.foregroundColor?.resolve({WidgetState.hovered}), actionColors.primaryHover);
```

Após recolher o menu, verificar que a altura do toggle é maior que a largura e que um toque muda de claro para escuro ou vice-versa.

- [ ] **Step 2: Run tests to verify RED**

Run: `flutter test test/app/shell/superadmin_shell_test.dart test/app/superadmin_app_test.dart`
Expected: FAIL porque o controle atual é um menu com três opções.

- [ ] **Step 3: Implement the binary animated toggle**

```dart
final effectiveDark = mode == ThemeMode.dark ||
    (mode == ThemeMode.system && Theme.of(context).brightness == Brightness.dark);
void toggle() => scope?.onChanged(effectiveDark ? ThemeMode.light : ThemeMode.dark);
```

Usar `AnimatedAlign` dentro de cápsula semântica, sol/lua nos extremos e `_OfficialCoeloMark` no indicador. Direção horizontal quando `collapsed == false` e vertical quando `collapsed == true`.

- [ ] **Step 4: Apply semantic header hover**

Resolver `CoeloActionColors` no tema e definir `foregroundColor` hover/focus/pressed como `primaryHover`, mantendo `primaryContainer` como overlay.

- [ ] **Step 5: Run focused tests to verify GREEN**

Run: `flutter test test/app/shell/superadmin_shell_test.dart test/app/superadmin_app_test.dart`
Expected: PASS.

### Task 5: Verification

**Files:**
- Verify all modified app and test files.

- [ ] **Step 1: Format**

Run: `dart format lib test`
Expected: exit 0.

- [ ] **Step 2: Analyze**

Run: `dart analyze`
Expected: `No issues found!`.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 4: Build web**

Run: `flutter build web --dart-define=COELO_DEV_MFA=true`
Expected: `Built build/web`.

- [ ] **Step 5: Inspect the final diff**

Run: `git diff --check`
Expected: exit 0 sem erros de whitespace.
