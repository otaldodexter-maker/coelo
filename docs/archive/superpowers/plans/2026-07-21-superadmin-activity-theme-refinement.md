---
title: "Refinamento de arquivos, notificações, tema e tours do Superadmin"
source: "docs/superpowers/specs/2026-07-21-superadmin-import-activity-theme-prototype-design.md"
status: "ready"
generated_at: "2026-07-21"
---

# Superadmin Activity and Theme Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refinar os fluxos demonstrativos de arquivos, a central de atividades, os controles de aparência e tours, removendo o hover duplicado dos filtros e corrigindo a transição light/dark e o roubo de foco do sininho.

**Architecture:** Manter `SuperadminActivityController` como fonte única das atividades e manter o protótipo sem I/O real. Integrar `InstitutionFileActions` à toolbar do diretório, concentrar padrões visuais nos widgets já existentes e tornar cada overlay responsável por seu próprio foco, hover e feedback demonstrativo.

**Tech Stack:** Flutter 3.38+, Dart, Material 3, `coelo_tokens`, `ChangeNotifier`, `MenuAnchor`, Widget Preview, `flutter_test`.

## Global Constraints

- Não criar upload, parsing, download real, persistência, serviço assíncrono, Supabase, migration ou RLS.
- Preservar filtros, cards, tabela, paginação e hierarquia do diretório de Instituições.
- Usar Nunito Sans, `#D63C00` via tokens semânticos, temas light/dark e alvos interativos mínimos de 48 px.
- Usar hover/foco em `primaryContainer`, conteúdo destacado em `primary` e overlay transparente conforme o menu OC.
- Manter responsividade em 375, 768, 1024 e 1440 px e suporte a texto ampliado.
- Manter reduced motion: nenhuma animação de tema, cenoura ou ovo quando `MediaQuery.disableAnimations` for `true`.
- Manter downloads e tours estritamente demonstrativos, com mensagens específicas.

## File Map

- `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart`: composição da toolbar e comportamento visual dos filtros.
- `apps/superadmin/lib/features/institutions/presentation/widgets/institution_file_actions.dart`: menu único Arquivos, modal neutro e exportação simulada do modelo.
- `apps/superadmin/lib/app/activity/superadmin_activity.dart`: timestamps determinísticos para testes e criação de atividades.
- `apps/superadmin/lib/app/shell/superadmin_activity_center.dart`: lista, scrollbar, hover, divisores, timestamp, clique e foco do sininho.
- `apps/superadmin/lib/app/shell/superadmin_shell.dart`: submenu de tours, ovo, cenoura, raio do controle de aparência e animações locais.
- `apps/superadmin/lib/app/superadmin_app.dart`: transição global e única de `ThemeData`.
- Arquivos `_test.dart` correspondentes: contratos de widget e regressões.

---

### Task 1: Remover o hover independente do checkbox dos filtros

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart:490-510,623-643`
- Test: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart:205-235`

**Interfaces:**
- Consumes: `_toggle(T value)` e `_filterMenuItemStyle(ColorScheme, {required bool selected})`.
- Produces: `_FilterSelectionIndicator({required bool selected, required bool enabled})`, sem hit test ou semântica duplicada.

- [ ] **Step 1: Escrever o teste vermelho do hover único**

Adicionar ao teste existente de hover dos filtros:

```dart
final row = tester.widget<MenuItemButton>(
  find.ancestor(of: find.text('Ativa'), matching: find.byType(MenuItemButton)),
);
final checkbox = tester.widget<Checkbox>(
  find.descendant(
    of: find.ancestor(of: find.text('Ativa'), matching: find.byType(MenuItemButton)),
    matching: find.byType(Checkbox),
  ),
);

expect(row.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.primaryContainer);
expect(checkbox.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
expect(checkbox.splashRadius, 0);
expect(checkbox.materialTapTargetSize, MaterialTapTargetSize.shrinkWrap);
```

- [ ] **Step 2: Executar o teste e confirmar a falha**

Run:

```powershell
flutter test test/features/institutions/presentation/screens/institution_directory_page_test.dart --plain-name "uses distinct semantic backgrounds for hover and selected options"
```

Expected: FAIL porque o `Checkbox` atual ainda usa overlay e splash padrão.

- [ ] **Step 3: Fazer a linha ser o único alvo interativo**

Substituir o `leadingIcon: Checkbox(...)` por:

```dart
leadingIcon: _FilterSelectionIndicator(
  selected: selected,
  enabled: widget.onApply != null,
),
```

Adicionar:

```dart
class _FilterSelectionIndicator extends StatelessWidget {
  const _FilterSelectionIndicator({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Checkbox(
          value: selected,
          onChanged: enabled ? (_) {} : null,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashRadius: 0,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
```

Envolver cada `MenuItemButton` em `Semantics(checked: selected, enabled: widget.onApply != null, child: ...)` para preservar o estado selecionado sem duplicar o checkbox na árvore semântica.

- [ ] **Step 4: Confirmar seleção por linha e ausência de hover secundário**

Run:

```powershell
flutter test test/features/institutions/presentation/screens/institution_directory_page_test.dart
```

Expected: PASS, incluindo aplicação e descarte do rascunho multiselect.

- [ ] **Step 5: Commitar a correção isolada**

```powershell
git add apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart
git commit -m "fix(superadmin): remove filter checkbox hover layer"
```

---

### Task 2: Mover arquivos do cabeçalho para a toolbar e unificar o menu

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart:61-86,90-160,269-292`
- Modify: `apps/superadmin/lib/features/institutions/presentation/widgets/institution_file_actions.dart:7-112`
- Test: `apps/superadmin/test/features/institutions/presentation/widgets/institution_file_actions_test.dart`
- Test: `apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart`

**Interfaces:**
- Consumes: `SuperadminActivityController.completeDemoExport(SuperadminExportFormat)` e `_showImportDialog`.
- Produces: `InstitutionFileActions({required SuperadminActivityController activityController, bool compact = false})` como um único `MenuAnchor` rotulado `Arquivos` ou icon-only no compacto.

- [ ] **Step 1: Escrever testes vermelhos para posição e menu único**

Atualizar `institution_file_actions_test.dart`:

```dart
expect(find.byKey(const Key('institution-files-action')), findsOneWidget);
expect(find.text('Arquivos'), findsOneWidget);
expect(find.byKey(const Key('institution-import-action')), findsNothing);
expect(find.byKey(const Key('institution-export-action')), findsNothing);

await tester.tap(find.byKey(const Key('institution-files-action')));
await tester.pumpAndSettle();
expect(find.text('Importar'), findsOneWidget);
expect(find.text('Exportar CSV'), findsOneWidget);
expect(find.text('Exportar XLSX'), findsOneWidget);
```

No teste da página, exigir que o acionador seja descendente de `institution-filter-toolbar` e não de `SuperadminShell` actions.

- [ ] **Step 2: Executar e observar a falha de contrato**

Run:

```powershell
flutter test test/features/institutions/presentation/widgets/institution_file_actions_test.dart test/features/institutions/presentation/screens/institution_directory_page_test.dart
```

Expected: FAIL porque desktop ainda mostra dois botões no cabeçalho.

- [ ] **Step 3: Implementar um único `MenuAnchor` no padrão OC**

Fazer `InstitutionFileActions.build` retornar um único menu com estas opções:

```dart
MenuItemButton(
  key: const Key('institution-files-import'),
  style: _fileMenuItemStyle(colors),
  onPressed: () => _showImportDialog(context, activityController),
  leadingIcon: const Icon(Icons.upload_file_outlined),
  child: const Text('Importar'),
),
MenuItemButton(
  key: const Key('institution-files-export-csv'),
  style: _fileMenuItemStyle(colors),
  onPressed: () => activityController.completeDemoExport(SuperadminExportFormat.csv),
  leadingIcon: const Icon(Icons.table_rows_outlined),
  child: const Text('Exportar CSV'),
),
MenuItemButton(
  key: const Key('institution-files-export-xlsx'),
  style: _fileMenuItemStyle(colors),
  onPressed: () => activityController.completeDemoExport(SuperadminExportFormat.xlsx),
  leadingIcon: const Icon(Icons.grid_on_outlined),
  child: const Text('Exportar XLSX'),
),
```

Usar `_fileMenuItemStyle` com `primaryContainer`, `primary` e overlay transparente nos estados hovered/focused. O trigger desktop será `OutlinedButton.icon` com ícone `folder_open_outlined`; o compacto será `IconButton` de 48 px com tooltip `Arquivos`.

- [ ] **Step 4: Integrar o controlador à `_DirectoryToolbar`**

Remover `actions` e `compactActions` de `SuperadminShell`. Passar `activityController` por `_InstitutionDirectoryContent` até `_DirectoryToolbar` e inserir, depois do `SegmentedButton`:

```dart
InstitutionFileActions(
  activityController: activityController,
  compact: compact,
),
```

- [ ] **Step 5: Rodar os testes direcionados**

Run:

```powershell
flutter test test/features/institutions/presentation/widgets/institution_file_actions_test.dart test/features/institutions/presentation/screens/institution_directory_page_test.dart
```

Expected: PASS sem mudança em cards, tabela ou filtros.

- [ ] **Step 6: Commitar o reposicionamento**

```powershell
git add apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart apps/superadmin/lib/features/institutions/presentation/widgets/institution_file_actions.dart apps/superadmin/test/features/institutions/presentation/widgets/institution_file_actions_test.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart
git commit -m "refactor(superadmin): move file actions into directory toolbar"
```

---

### Task 3: Neutralizar o modal e adicionar Exportar modelo XLSX

**Files:**
- Modify: `apps/superadmin/lib/features/institutions/presentation/widgets/institution_file_actions.dart:114-286`
- Test: `apps/superadmin/test/features/institutions/presentation/widgets/institution_file_actions_test.dart`

**Interfaces:**
- Consumes: `_InstitutionImportDialog` e `ScaffoldMessenger`.
- Produces: ação `institution-import-template-export` com feedback `Modelo XLSX preparado para download demonstrativo.`.

- [ ] **Step 1: Escrever os testes vermelhos do modal**

```dart
await tester.tap(find.byKey(const Key('institution-files-action')));
await tester.pumpAndSettle();
await tester.tap(find.byKey(const Key('institution-files-import')));
await tester.pumpAndSettle();

final dialog = tester.widget<Dialog>(find.byType(Dialog));
expect(dialog.backgroundColor, CoeloTheme.light.colorScheme.surface);
expect(find.byKey(const Key('institution-import-template-export')), findsOneWidget);

await tester.tap(find.byKey(const Key('institution-import-template-export')));
await tester.pump();
expect(find.text('Modelo XLSX preparado para download demonstrativo.'), findsOneWidget);
```

Adicionar uma variante dark e verificar `CoeloTheme.dark.colorScheme.surface`.

- [ ] **Step 2: Executar e confirmar as falhas**

Run:

```powershell
flutter test test/features/institutions/presentation/widgets/institution_file_actions_test.dart
```

Expected: FAIL porque o modal não expõe cor semântica nem ação de modelo.

- [ ] **Step 3: Aplicar superfície neutra e overlay explícito**

Configurar:

```dart
return showDialog<void>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: 0.54),
  builder: (context) => _InstitutionImportDialog(activityController: controller),
);
```

No `Dialog`, usar `backgroundColor: colors.surface`, borda `outlineVariant`, raio `CoeloRadius.lg` e manter conteúdo responsivo com `maxWidth: 560`.

- [ ] **Step 4: Adicionar a exportação simulada do modelo**

Na etapa de arquivo, antes do seletor:

```dart
OutlinedButton.icon(
  key: const Key('institution-import-template-export'),
  onPressed: () => _showDemoDownload(
    context,
    'Modelo XLSX preparado para download demonstrativo.',
  ),
  icon: const Icon(Icons.file_download_outlined),
  label: const Text('Exportar modelo XLSX'),
),
```

Implementar `_showDemoDownload` com `ScaffoldMessenger.removeCurrentSnackBar()` seguido de `showSnackBar`.

- [ ] **Step 5: Atualizar previews e executar testes**

Os previews `Importação · selecionar arquivo` e `Importação · revisão · dark` devem renderizar a superfície neutra e a nova ação. Run:

```powershell
flutter test test/features/institutions/presentation/widgets/institution_file_actions_test.dart
```

Expected: PASS em light e dark.

- [ ] **Step 6: Commitar o modal refinado**

```powershell
git add apps/superadmin/lib/features/institutions/presentation/widgets/institution_file_actions.dart apps/superadmin/test/features/institutions/presentation/widgets/institution_file_actions_test.dart
git commit -m "feat(superadmin): refine import dialog and template action"
```

---

### Task 4: Refinar conteúdo e interação da central de atividades

**Files:**
- Modify: `apps/superadmin/lib/app/activity/superadmin_activity.dart:76-162`
- Modify: `apps/superadmin/lib/app/shell/superadmin_activity_center.dart:108-390`
- Test: `apps/superadmin/test/app/activity/superadmin_activity_test.dart`
- Test: `apps/superadmin/test/app/shell/superadmin_activity_center_test.dart`

**Interfaces:**
- Consumes: `SuperadminActivity.createdAt`, `kind`, `fileName`, `status` e `progress`.
- Produces: `SuperadminActivityController({Duration tickInterval, DateTime Function()? now})`; helper visual `_formatActivityTimestamp(DateTime)`.

- [ ] **Step 1: Escrever testes vermelhos para relógio determinístico e timestamp**

```dart
final now = DateTime(2026, 7, 21, 14, 35);
final controller = SuperadminActivityController(now: () => now);
controller.completeDemoExport(SuperadminExportFormat.xlsx);
expect(controller.activities.single.createdAt, now);
```

No widget test, abrir o painel e esperar `21/07/2026 · 14:35` sob a atividade.

- [ ] **Step 2: Escrever testes vermelhos para hover, divisor, scrollbar e clique**

Semear quatro atividades, abrir o painel e verificar:

```dart
expect(find.byKey(const Key('superadmin-activity-scrollbar')), findsOneWidget);
expect(find.byKey(const Key('superadmin-activity-divider-0')), findsOneWidget);

final tileInk = tester.widget<InkWell>(
  find.descendant(
    of: find.byKey(const Key('superadmin-activity-demo-export')),
    matching: find.byType(InkWell),
  ),
);
expect(tileInk.hoverColor, CoeloTheme.light.colorScheme.primaryContainer);

await tester.tap(find.byKey(const Key('superadmin-activity-demo-export')));
await tester.pump();
expect(find.text('Download demonstrativo de instituicoes.xlsx preparado.'), findsOneWidget);
```

- [ ] **Step 3: Executar e confirmar as falhas**

Run:

```powershell
flutter test test/app/activity/superadmin_activity_test.dart test/app/shell/superadmin_activity_center_test.dart
```

Expected: FAIL por ausência de relógio injetável, timestamp, scrollbar e clique.

- [ ] **Step 4: Injetar o relógio sem alterar o contrato padrão**

```dart
SuperadminActivityController({
  this.tickInterval = const Duration(milliseconds: 600),
  DateTime Function()? now,
}) : _now = now ?? DateTime.now;

final DateTime Function() _now;
```

Usar `_now()` em importações e exportações. Atualizar também o construtor seeded:

```dart
SuperadminActivityController.seeded(
  Iterable<SuperadminActivity> activities, {
  this.tickInterval = const Duration(milliseconds: 600),
  DateTime Function()? now,
}) : _now = now ?? DateTime.now {
  _activities.addAll(activities);
}
```

- [ ] **Step 5: Tornar `_ActivityPanel` stateful e adicionar scrollbar**

Criar e descartar um `ScrollController`. Envolver `ListView.separated` em:

```dart
Scrollbar(
  key: const Key('superadmin-activity-scrollbar'),
  controller: _scrollController,
  thumbVisibility: widget.controller.activities.length > 3,
  child: ListView.separated(
    controller: _scrollController,
    primary: false,
    itemCount: widget.controller.activities.length,
    separatorBuilder: (context, index) => Padding(
      key: Key('superadmin-activity-divider-$index'),
      padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space5),
      child: const Divider(height: 1),
    ),
    itemBuilder: (context, index) => _ActivityTile(
      activity: widget.controller.activities[index],
    ),
  ),
),
```

- [ ] **Step 6: Adicionar timestamp, hover e download simulado**

Adicionar um formatador determinístico sem nova dependência:

```dart
String _formatActivityTimestamp(DateTime value) {
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year}'
      ' · ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
```

Converter `_ActivityTile` em `InkWell` com chave `superadmin-activity-${activity.id}`, `hoverColor: colors.primaryContainer`, `focusColor: colors.primaryContainer`, raio `CoeloRadius.md` e `onTap` apenas para import/export. Anúncios ficam com `onTap: null`.

- [ ] **Step 7: Remover a bolinha aninhada do status**

No `AnimatedContainer`, usar:

```dart
decoration: BoxDecoration(
  color: expanded ? background : foreground,
  borderRadius: BorderRadius.circular(CoeloRadius.full),
),
child: expanded
    ? Text(label, style: theme.textTheme.labelSmall?.copyWith(color: foreground))
    : const SizedBox.square(dimension: CoeloSpacing.space2),
```

Manter o `ConstrainedBox` externo em 48 px e remover o `Container` circular interno.

- [ ] **Step 8: Executar testes e commit**

Run:

```powershell
flutter test test/app/activity/superadmin_activity_test.dart test/app/shell/superadmin_activity_center_test.dart
```

Expected: PASS para timestamps, status, hover, clique e rolagem.

```powershell
git add apps/superadmin/lib/app/activity/superadmin_activity.dart apps/superadmin/lib/app/shell/superadmin_activity_center.dart apps/superadmin/test/app/activity/superadmin_activity_test.dart apps/superadmin/test/app/shell/superadmin_activity_center_test.dart
git commit -m "feat(superadmin): refine activity center interactions"
```

---

### Task 5: Corrigir o roubo de foco do sininho

**Files:**
- Modify: `apps/superadmin/lib/app/shell/superadmin_activity_center.dart:20-88,108-165`
- Test: `apps/superadmin/test/app/shell/superadmin_activity_center_test.dart`
- Test: `apps/superadmin/test/app/shell/superadmin_shell_test.dart:504-529`

**Interfaces:**
- Consumes: `MenuController`, `_triggerFocusNode`, botão fechar e evento `Escape`.
- Produces: `_closeAndRestoreFocus()` usado somente pelo trigger, botão fechar e `Escape`.

- [ ] **Step 1: Escrever a regressão sininho → Bug e sininho → OC**

```dart
await tester.tap(find.byKey(const Key('superadmin-notifications')));
await tester.pumpAndSettle();
await tester.tap(find.byKey(const Key('superadmin-report-bug')));
await tester.pumpAndSettle();
expect(Focus.of(tester.element(find.byKey(const Key('superadmin-notifications')))).hasFocus, isFalse);
expect(find.text('O reporte de bugs será implementado em breve.'), findsOneWidget);
```

Repetir abrindo o sininho e clicando `superadmin-profile-menu`; o menu OC deve permanecer aberto e o sininho sem foco.

- [ ] **Step 2: Executar e confirmar a reprodução**

Run:

```powershell
flutter test test/app/shell/superadmin_shell_test.dart --plain-name "does not reactivate notifications when Bug or OC closes the panel"
```

Expected: FAIL porque `onClose` sempre executa `_triggerFocusNode.requestFocus()`.

- [ ] **Step 3: Restaurar foco apenas em fechamentos explícitos**

Adicionar `_restoreFocusOnClose = false`. No `onOpen`, zerar a flag. Criar:

```dart
void _closeAndRestoreFocus() {
  _restoreFocusOnClose = true;
  _menuController.close();
}
```

No `onClose`, chamar `setCenterOpen(false)` e requisitar foco somente se `_restoreFocusOnClose`; depois zerar a flag. Passar `onCloseRequested: _closeAndRestoreFocus` para `_ActivityPanel` e usá-lo no botão fechar e no `Escape`. O fechamento causado por clique fora não ativa a flag.

- [ ] **Step 4: Validar foco por teclado e ponteiro**

Run:

```powershell
flutter test test/app/shell/superadmin_activity_center_test.dart test/app/shell/superadmin_shell_test.dart
```

Expected: PASS para retorno por `Esc`/fechar e ausência de roubo de foco em Bug/OC.

- [ ] **Step 5: Commitar a regressão corrigida**

```powershell
git add apps/superadmin/lib/app/shell/superadmin_activity_center.dart apps/superadmin/test/app/shell/superadmin_activity_center_test.dart apps/superadmin/test/app/shell/superadmin_shell_test.dart
git commit -m "fix(superadmin): preserve focus outside activity center"
```

---

### Task 6: Transformar Fazer tour em submenu e redesenhar ovo e cenoura

**Files:**
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart:730-1145,1546-1600`
- Test: `apps/superadmin/test/app/shell/superadmin_shell_test.dart:531-595`

**Interfaces:**
- Consumes: `_showMessage`, `MediaQuery.disableAnimations`, `_coeloMotionCurve` e tokens Coelo.
- Produces: chaves `superadmin-tour-screen`, `superadmin-tour-menu`, `superadmin-tour-complete`; ciclo do ovo de 900 ms + repouso de 3,5 s.

- [ ] **Step 1: Escrever testes vermelhos do submenu**

```dart
await tester.tap(find.byKey(const Key('superadmin-onboarding-tour')));
await tester.pumpAndSettle();
expect(find.byKey(const Key('superadmin-tour-screen')), findsOneWidget);
expect(find.byKey(const Key('superadmin-tour-menu')), findsOneWidget);
expect(find.byKey(const Key('superadmin-tour-complete')), findsOneWidget);

await tester.tap(find.byKey(const Key('superadmin-tour-screen')));
await tester.pump();
expect(find.text('O tour desta tela será implementado na etapa final.'), findsOneWidget);
```

Testar também as mensagens `O tour do menu será implementado na etapa final.` e `O tour completo será implementado na etapa final.`.

- [ ] **Step 2: Escrever o teste vermelho do novo ciclo do ovo**

```dart
final motion = find.byKey(const Key('superadmin-onboarding-egg-motion'));
final resting = tester.widget<Transform>(motion).transform.clone();
await tester.pump(const Duration(milliseconds: 3500));
await tester.pump(const Duration(milliseconds: 180));
expect(tester.widget<Transform>(motion).transform, isNot(resting));
await tester.pump(const Duration(milliseconds: 900));
expect(tester.widget<Transform>(motion).transform, resting);
```

Com `disableAnimations: true`, bombear 6 segundos e exigir matriz inalterada.

- [ ] **Step 3: Executar e confirmar as falhas**

Run:

```powershell
flutter test test/app/shell/superadmin_shell_test.dart --plain-name "opens the three demonstration tour options"
flutter test test/app/shell/superadmin_shell_test.dart --plain-name "swings and rests the onboarding egg"
```

Expected: FAIL porque o trigger ainda mostra uma única mensagem e o ciclo atual é 4 s/8 s/360 ms.

- [ ] **Step 4: Implementar o submenu OC**

Envolver o trigger em `MenuAnchor` com o mesmo `MenuStyle` e `MenuItemButton` do perfil OC. Cada item usa hover/foco `primaryContainer`, foreground/icon `primary`, overlay transparente e uma das três mensagens aprovadas. No modo recolhido, preservar somente o ovo e o tooltip.

- [ ] **Step 5: Implementar a animação de 900 ms**

Configurar o controller para 900 ms e usar:

```dart
_rotation = TweenSequence<double>([
  TweenSequenceItem(tween: Tween(begin: 0, end: 4 * math.pi / 180), weight: 20),
  TweenSequenceItem(tween: Tween(begin: 4 * math.pi / 180, end: -4 * math.pi / 180), weight: 25),
  TweenSequenceItem(tween: Tween(begin: -4 * math.pi / 180, end: 2 * math.pi / 180), weight: 20),
  TweenSequenceItem(tween: Tween(begin: 2 * math.pi / 180, end: -2 * math.pi / 180), weight: 20),
  TweenSequenceItem(tween: Tween(begin: -2 * math.pi / 180, end: 0), weight: 15),
]).animate(_animationController);
```

Agendar a primeira execução após 3,5 s e reagendar o próximo ciclo 3,5 s após cada conclusão. O brilho usa `TweenSequence` 0→1→0 durante os mesmos 900 ms. Cancelar timer e controller em `dispose` e com reduced motion.

- [ ] **Step 6: Redesenhar os painters com tokens Coelo**

No ovo, desenhar base `primaryContainer`, duas faixas curvas alternando `tertiaryContainer`/`secondaryContainer` e três pontos `primary`; manter contraste no dark via cores recebidas pelo painter. Na cenoura, desenhar corpo laranja inclinado, três folhas com `CoeloStatusColors.successContainer/onSuccessContainer` e três traços claros no corpo. Passar as cores aos painters e retornar `true` em `shouldRepaint` somente quando alguma cor mudar.

- [ ] **Step 7: Corrigir o raio do controle Aparência**

Trocar o raio expandido de `CoeloRadius.md` para `CoeloRadius.lg`, tanto no `InkWell` quanto na decoração. Manter `CoeloRadius.full` somente no recolhido.

- [ ] **Step 8: Rodar testes e commit**

Run:

```powershell
flutter test test/app/shell/superadmin_shell_test.dart
```

Expected: PASS para submenu, mensagens, animação, reduced motion, cenoura e tamanhos.

```powershell
git add apps/superadmin/lib/app/shell/superadmin_shell.dart apps/superadmin/test/app/shell/superadmin_shell_test.dart
git commit -m "feat(superadmin): refine tour and appearance controls"
```

---

### Task 7: Tornar a transição light/dark contínua

**Files:**
- Modify: `apps/superadmin/lib/app/superadmin_app.dart:78-96`
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart:915-1095`
- Test: `apps/superadmin/test/app/superadmin_app_test.dart`
- Test: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`

**Interfaces:**
- Consumes: `CoeloTheme.light`, `CoeloTheme.dark`, `CoeloMotion.standard`, `_coeloMotionCurve`.
- Produces: uma transição global de 220 ms; `AnimationStyle.noAnimation` em reduced motion; marcador alinhado pela mesma duração e curva.

- [ ] **Step 1: Escrever o teste vermelho do frame intermediário**

Criar um harness com `MaterialApp(theme, darkTheme, themeMode, themeAnimationStyle)` e uma superfície com chave. Registrar cor e tamanho light, tocar o controle, bombear 110 ms e verificar:

```dart
final middleColor = tester.widget<ColoredBox>(surface).color;
expect(middleColor, isNot(lightColor));
expect(middleColor, isNot(darkColor));
expect(tester.getSize(surface), lightSize);

await tester.pump(const Duration(milliseconds: 110));
expect(tester.widget<ColoredBox>(surface).color, darkColor);
expect(tester.getSize(surface), lightSize);
```

No reduced motion, um único `pump()` deve produzir `darkColor` sem intermediário.

- [ ] **Step 2: Executar e reproduzir o salto**

Run:

```powershell
flutter test test/app/superadmin_app_test.dart test/app/shell/superadmin_shell_test.dart --plain-name "interpolates theme colors without changing geometry"
```

Expected: FAIL se a superfície ou o conteúdo trocar instantaneamente ou se animações locais concorrentes impedirem a interpolação.

- [ ] **Step 3: Manter uma única animação de tema**

Preservar no `MaterialApp.router`:

```dart
themeAnimationStyle: reduceMotion
    ? AnimationStyle.noAnimation
    : const AnimationStyle(
        duration: Duration(milliseconds: 220),
        curve: Cubic(0.2, 0, 0, 1),
      ),
```

No controle Aparência, substituir o `AnimatedContainer` externo por `Container`; as cores serão interpoladas pelo `ThemeData` global. Manter animação local apenas no `AnimatedAlign` da cenoura e em um `AnimatedSwitcher` de 220 ms para ícone/texto, com a mesma curva.

- [ ] **Step 4: Cobrir reduced motion e ausência de animações concorrentes**

Quando `disableAnimations` for verdadeiro, usar `Duration.zero` no `AnimatedAlign` e `AnimatedSwitcher`. Verificar que o raio e as dimensões do controle não mudam durante nenhum frame intermediário.

- [ ] **Step 5: Rodar testes e commit**

Run:

```powershell
flutter test test/app/superadmin_app_test.dart test/app/shell/superadmin_shell_test.dart
```

Expected: PASS com cor intermediária aos 110 ms, destino aos 220 ms e troca instantânea com reduced motion.

```powershell
git add apps/superadmin/lib/app/superadmin_app.dart apps/superadmin/lib/app/shell/superadmin_shell.dart apps/superadmin/test/app/superadmin_app_test.dart apps/superadmin/test/app/shell/superadmin_shell_test.dart
git commit -m "fix(superadmin): smooth light and dark theme transition"
```

---

### Task 8: Atualizar previews e executar a matriz final

**Files:**
- Modify: `apps/superadmin/lib/app/shell/superadmin_activity_center.dart:390-end`
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart:1546-end`
- Modify: `apps/superadmin/lib/features/institutions/presentation/widgets/institution_file_actions.dart:250-end`
- Test: todos os testes direcionados do Superadmin alterados nas Tasks 1-7.

**Interfaces:**
- Consumes: todos os widgets refinados.
- Produces: previews light/dark para Arquivos, modal, atividades, Aparência expandida/recolhida e tours.

- [ ] **Step 1: Atualizar fixtures e previews**

Usar timestamps fixos `DateTime(2026, 7, 21, 14, 35)` nos previews. Garantir previews para painel vazio, progresso, sucesso, parcial, falha, anúncio, modal selecionar/revisar, toolbar compacta, Aparência expandida/recolhida e submenu de tours.

- [ ] **Step 2: Formatar somente os arquivos tocados**

Run:

```powershell
dart format lib/app/activity/superadmin_activity.dart lib/app/shell/superadmin_activity_center.dart lib/app/shell/superadmin_shell.dart lib/app/superadmin_app.dart lib/features/institutions/presentation/screens/institution_directory_page.dart lib/features/institutions/presentation/widgets/institution_file_actions.dart test/app/activity/superadmin_activity_test.dart test/app/shell/superadmin_activity_center_test.dart test/app/shell/superadmin_shell_test.dart test/app/superadmin_app_test.dart test/features/institutions/presentation/screens/institution_directory_page_test.dart test/features/institutions/presentation/widgets/institution_file_actions_test.dart
```

Expected: formatter concluído sem tocar arquivos fora da lista.

- [ ] **Step 3: Executar análise estática**

Run:

```powershell
dart analyze
```

Expected: `No issues found!`.

- [ ] **Step 4: Executar a suíte direcionada completa**

Run:

```powershell
flutter test test/app/activity/superadmin_activity_test.dart test/app/shell/superadmin_activity_center_test.dart test/app/shell/superadmin_shell_test.dart test/app/superadmin_app_test.dart test/features/institutions/presentation/widgets/institution_file_actions_test.dart test/features/institutions/presentation/screens/institution_directory_page_test.dart
```

Expected: todos os testes aprovados, sem overflow nem exceções pendentes.

- [ ] **Step 5: Executar matriz responsiva e reduced motion**

Confirmar nos testes parametrizados 375, 768, 1024 e 1440 px, light/dark, `textScaler: TextScaler.linear(1.5)` e `disableAnimations: true`. Cada combinação deve terminar com `tester.takeException() == null`.

- [ ] **Step 6: Validar previews e app web**

Run:

```powershell
flutter widget-preview start --web-server --no-pub
```

Se o DTD local continuar sem `Lsp.dart/workspace/getFlutterWidgetPreviews`, registrar a limitação e executar:

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8766 --dart-define=COELO_DEV_MFA=true
```

Inspecionar toolbar, modal, sininho e menu lateral sem alterar dados reais.

- [ ] **Step 7: Revisar o diff e commit final de previews/testes**

Run:

```powershell
git diff --check
git status --short
```

Expected: sem whitespace errors; alterações alheias preexistentes continuam preservadas.

```powershell
git add apps/superadmin/lib/app/shell/superadmin_activity_center.dart apps/superadmin/lib/app/shell/superadmin_shell.dart apps/superadmin/lib/features/institutions/presentation/widgets/institution_file_actions.dart apps/superadmin/test/app/activity/superadmin_activity_test.dart apps/superadmin/test/app/shell/superadmin_activity_center_test.dart apps/superadmin/test/app/shell/superadmin_shell_test.dart apps/superadmin/test/app/superadmin_app_test.dart apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_test.dart apps/superadmin/test/features/institutions/presentation/widgets/institution_file_actions_test.dart
git commit -m "test(superadmin): cover refined activity and theme experience"
```
