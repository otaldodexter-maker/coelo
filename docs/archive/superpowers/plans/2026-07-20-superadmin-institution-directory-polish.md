---
source: docs/superpowers/specs/2026-07-20-superadmin-institution-directory-polish-design.md
status: approved
generated_at: 2026-07-20
---

# Institution Directory Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refinar os cards, conter a rolagem da tabela, corrigir menus e oferecer seleção Sistema/Claro/Escuro no menu lateral.

**Architecture:** O estado de tema permanece em `SuperadminApp` e será exposto abaixo de `MaterialApp.router` por um `InheritedWidget` pequeno. Card, tabela e shell continuam nos componentes existentes, sem alterar domínio, repositórios ou Supabase.

**Tech Stack:** Flutter, Material 3, `coelo_tokens`, `flutter_test`.

## Global Constraints

- Usar somente cores, tipografia, raios, espaçamentos e movimentos do design system Coelo.
- Cada nova sessão começa em `ThemeMode.system`; não persistir a preferência.
- Hover não pode ser o único caminho para informação importante; status também responde a foco e toque.
- A rolagem horizontal pertence ao viewport da tabela, nunca à página inteira.
- Não adicionar dependências.

---

### Task 1: Tema compartilhado e seletor no menu

**Files:**
- Create: `apps/superadmin/lib/app/theme/superadmin_theme_mode_scope.dart`
- Modify: `apps/superadmin/lib/app/superadmin_app.dart`
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Test: `apps/superadmin/test/app/superadmin_app_test.dart`
- Test: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`

**Interfaces:**
- Produces: `SuperadminThemeModeScope.of(BuildContext)` com `ThemeMode mode` e `ValueChanged<ThemeMode> onChanged`.
- Consumes: `_SuperadminAppState._themeMode` e `_setThemeMode(ThemeMode)` existentes.

- [ ] **Step 1: Escrever testes que falham**

```dart
expect(find.byKey(const Key('superadmin-theme-mode-control')), findsOneWidget);
await tester.tap(find.text('Escuro'));
expect(selectedMode, ThemeMode.dark);
await tester.tap(find.text('Seguir o sistema'));
expect(selectedMode, ThemeMode.system);
```

Cobrir menu expandido, recolhido e drawer mobile; confirmar que uma nova instância de `SuperadminApp` nasce em `ThemeMode.system`.

- [ ] **Step 2: Executar RED**

Run: `flutter test --no-pub test/app/superadmin_app_test.dart test/app/shell/superadmin_shell_test.dart`

Expected: FAIL porque o escopo e `superadmin-theme-mode-control` ainda não existem.

- [ ] **Step 3: Implementar o escopo mínimo**

```dart
class SuperadminThemeModeScope extends InheritedWidget {
  const SuperadminThemeModeScope({
    required this.mode,
    required this.onChanged,
    required super.child,
    super.key,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  static SuperadminThemeModeScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SuperadminThemeModeScope>()!;

  @override
  bool updateShouldNotify(SuperadminThemeModeScope oldWidget) => mode != oldWidget.mode;
}
```

Adicionar o escopo em `MaterialApp.router.builder` e um controle de três opções no rodapé de `_NavigationContent`. No estado recolhido, o mesmo controle abre um menu compacto.

- [ ] **Step 4: Executar GREEN**

Run: `flutter test --no-pub test/app/superadmin_app_test.dart test/app/shell/superadmin_shell_test.dart`

Expected: PASS.

---

### Task 2: Card equilibrado e status progressivo

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`
- Test: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`

**Interfaces:**
- Produces: `_ExpandableStatusIndicator`, recolhido por padrão e expandido em hover/foco/toque.
- Consumes: `InstitutionStatus` e `CoeloStatusColors` já usados por `_StatusChip`.

- [ ] **Step 1: Escrever testes que falham**

```dart
final indicator = find.byKey(const Key('institution-status-demo-institution-aurora'));
expect(tester.getSize(indicator).width, lessThan(CoeloSpacing.space6));
await gesture.moveTo(tester.getCenter(indicator));
await tester.pumpAndSettle();
expect(find.text('Ativa'), findsOneWidget);
expect(tester.getSize(indicator).width, greaterThan(CoeloSpacing.space10));
```

Também verificar `FontWeight.w700`, alinhamento vertical entre ícone e categoria e menor diferença entre espaços superior/inferior do conteúdo.

- [ ] **Step 2: Executar RED**

Run: `flutter test --no-pub test/features/institutions/presentation/screens/institution_directory_page_test.dart --plain-name "uses a compact expandable status and centered card details"`

Expected: FAIL porque o status atual sempre exibe o chip completo.

- [ ] **Step 3: Implementar o mínimo**

Usar `MouseRegion`, `FocusableActionDetector`, `GestureDetector` e `AnimatedContainer` com `CoeloMotion.standard`. Centralizar a coluna do card com `mainAxisAlignment: MainAxisAlignment.center`, usar `CrossAxisAlignment.center` no detalhe e `FontWeight.w700` nos rótulos.

- [ ] **Step 4: Executar GREEN**

Run: `flutter test --no-pub test/features/institutions/presentation/screens/institution_directory_page_test.dart`

Expected: PASS.

---

### Task 3: Viewport horizontal contido da tabela

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`
- Test: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`

**Interfaces:**
- Produces: `_InstitutionTable` limitado por `LayoutBuilder`, com `Scrollbar` e `ScrollController` horizontal.
- Consumes: banner e `DataTable` existentes.

- [ ] **Step 1: Escrever teste que falha**

```dart
final viewport = find.byKey(const Key('institution-directory-table-viewport'));
expect(tester.getSize(viewport).width, lessThanOrEqualTo(tester.getSize(find.byType(Scaffold)).width));
await tester.drag(viewport, const Offset(-600, 0));
await tester.pumpAndSettle();
expect(controller.offset, greaterThan(0));
```

- [ ] **Step 2: Executar RED**

Run: `flutter test --no-pub test/features/institutions/presentation/screens/institution_directory_page_test.dart --plain-name "keeps table scrolling inside the page viewport"`

Expected: FAIL porque ainda não existe a chave do viewport nem barra de rolagem controlada.

- [ ] **Step 3: Implementar o mínimo**

Transformar `_InstitutionTable` em `StatefulWidget`, criar e descartar um `ScrollController`, envolver banner+tabela em `ClipRect > ScrollConfiguration > Scrollbar > SingleChildScrollView`, mantendo `SizedBox(width: 3200)` apenas dentro do scroll.

- [ ] **Step 4: Executar GREEN**

Run: `flutter test --no-pub test/features/institutions/presentation/screens/institution_directory_page_test.dart`

Expected: PASS sem overflow.

---

### Task 4: Menus e estados de interação

**Files:**
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`
- Test: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`
- Test: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`

**Interfaces:**
- Consumes: `_ProfileSummary`, `_HeaderUtilityActions` e `_DirectoryFilterMenu` existentes.

- [ ] **Step 1: Escrever testes que falham**

```dart
final profileMenu = tester.widget<PopupMenuButton<_ProfileAction>>(
  find.byKey(const Key('superadmin-profile-menu')),
);
expect(profileMenu.position, PopupMenuPosition.under);
expect(profileMenu.borderRadius, BorderRadius.circular(CoeloRadius.full));
```

Verificar também hover/foco laranja suave nos itens de filtro e forma circular consistente nos `IconButton` de bug e sino.

- [ ] **Step 2: Executar RED**

Run: `flutter test --no-pub test/app/shell/superadmin_shell_test.dart test/features/institutions/presentation/screens/institution_directory_page_test.dart`

Expected: FAIL nas propriedades de posição e forma ainda ausentes.

- [ ] **Step 3: Implementar o mínimo**

Configurar `PopupMenuPosition.under`, `borderRadius`, `menuPadding` e shapes via tema local. Manter `IconButton` com forma circular, `overlayColor` derivada de `colorScheme.primaryContainer`, e usar o mesmo hover nos `MenuItemButton` dos filtros.

- [ ] **Step 4: Verificação final**

Run:

```powershell
flutter test --no-pub test/features/institutions test/app/shell/superadmin_shell_test.dart test/app/superadmin_app_test.dart
flutter analyze --no-pub
flutter build web --release --dart-define=COELO_DEV_MFA=true
```

Expected: todos os testes passam, análise sem issues e build concluído.

- [ ] **Step 5: Atualizar preview**

Copiar `build/web/index.html` para `build/web/dev/institutions/index.html`, manter somente uma porta local e validar cards/tabela em light e dark no navegador.
