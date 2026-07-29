import 'package:coelo_catalog/catalog/catalog_foundations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registers the indexed surface interaction foundations', () {
    final foundations = buildCatalogFoundationRegistry();

    expect(
      foundations.keys,
      containsAll(<String>[
        'pattern.overlay-surfaces',
        'pattern.interaction-states',
        'pattern.admin-directory',
        'pattern.flyout-actions',
        'pattern.negative-actions',
        'pattern.dialog-actions',
        'admin.resizable-table',
      ]),
    );
    expect(
      foundations['pattern.overlay-surfaces']!.referencedComponentIds,
      contains('admin.dialog-shell'),
    );
    expect(
      foundations['pattern.form-controls']!.referencedComponentIds,
      contains('admin.dialog-shell'),
    );
  });

  for (final themeCase in <({String name, ThemeData theme})>[
    (name: 'light', theme: CoeloTheme.light),
    (name: 'dark', theme: CoeloTheme.dark),
  ]) {
    testWidgets('uses neutral popup and close contracts in ${themeCase.name}', (tester) async {
      await _pumpFoundation(tester, 'pattern.overlay-surfaces', themeCase.theme);

      await tester.tap(find.byKey(const Key('surface-interaction-open-dialog')));
      await tester.pumpAndSettle();

      expect(find.byType(CoeloAdminDialogShell), findsOneWidget);
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      final close = tester.widget<IconButton>(find.byKey(const Key('surface-interaction-close')));
      final theme = Theme.of(tester.element(find.byType(Dialog)));

      expect(dialog.backgroundColor, theme.colorScheme.surface);
      expect(close.icon, isA<Icon>());
      expect((close.icon as Icon).icon, Icons.close_rounded);
      expect(close.tooltip, 'Fechar demonstração');
      expect(
        tester.getSize(find.byKey(const Key('surface-interaction-close'))),
        const Size.square(CoeloSize.touchMin),
      );
      expect(close.style?.foregroundColor?.resolve(<WidgetState>{}), theme.colorScheme.error);
      expect(
        close.style?.backgroundColor?.resolve(<WidgetState>{WidgetState.hovered}),
        theme.colorScheme.errorContainer,
      );
    });
  }

  testWidgets('distinguishes discrete items from continuous filter and table rows', (tester) async {
    await _pumpFoundation(tester, 'pattern.interaction-states', CoeloTheme.light);
    final theme = Theme.of(
      tester.element(find.byKey(const Key('surface-interaction-discrete-item'))),
    );
    final discrete = tester.widget<TextButton>(
      find.byKey(const Key('surface-interaction-discrete-item')),
    );
    final continuousFilter = tester.widget<TextButton>(
      find.byKey(const Key('surface-interaction-continuous-filter-row')),
    );
    final continuousTable = tester.widget<TextButton>(
      find.byKey(const Key('surface-interaction-continuous-table-row')),
    );

    expect(
      discrete.style?.backgroundColor?.resolve(<WidgetState>{WidgetState.hovered}),
      theme.colorScheme.primaryContainer,
    );
    expect(
      discrete.style?.foregroundColor?.resolve(<WidgetState>{WidgetState.hovered}),
      theme.colorScheme.primary,
    );
    expect(discrete.style?.shape?.resolve(<WidgetState>{}), isA<RoundedRectangleBorder>());
    expect(
      tester.getSize(find.byKey(const Key('surface-interaction-discrete-gap'))).height,
      CoeloSpacing.spaceHalf,
    );
    expect(continuousFilter.style?.shape?.resolve(<WidgetState>{}), isA<RoundedRectangleBorder>());
    expect(continuousTable.style?.shape?.resolve(<WidgetState>{}), isA<RoundedRectangleBorder>());
    expect(
      (continuousFilter.style!.shape!.resolve(<WidgetState>{})! as RoundedRectangleBorder)
          .borderRadius,
      BorderRadius.zero,
    );
    expect(
      (continuousTable.style!.shape!.resolve(<WidgetState>{})! as RoundedRectangleBorder)
          .borderRadius,
      BorderRadius.zero,
    );
    expect(
      continuousFilter.style?.backgroundColor?.resolve(<WidgetState>{WidgetState.hovered}),
      theme.colorScheme.primaryContainer,
    );
    expect(
      continuousTable.style?.backgroundColor?.resolve(<WidgetState>{WidgetState.hovered}),
      theme.colorScheme.primaryContainer,
    );
    expect(find.byKey(const Key('surface-interaction-continuous-gap')), findsNothing);

    await tester.tap(find.byKey(const Key('surface-interaction-single-select-trigger')));
    await tester.pumpAndSettle();
    expect(find.text('Instituições'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('preserves brand hierarchy for primary, tonal and send actions', (tester) async {
    await _pumpFoundation(tester, 'pattern.interaction-states', CoeloTheme.light);
    final theme = Theme.of(
      tester.element(find.byKey(const Key('surface-interaction-primary-action'))),
    );
    final primary = tester.widget<FilledButton>(
      find.byKey(const Key('surface-interaction-primary-action')),
    );
    final tonal = tester.widget<ActionChip>(
      find.byKey(const Key('surface-interaction-tonal-action')),
    );
    final send = tester.widget<IconButton>(
      find.byKey(const Key('surface-interaction-send-action')),
    );

    expect(
      primary.style?.backgroundColor?.resolve(<WidgetState>{WidgetState.hovered}),
      theme.colorScheme.primary,
    );
    expect(
      primary.style?.overlayColor?.resolve(<WidgetState>{WidgetState.hovered}),
      Colors.transparent,
    );
    expect(
      tonal.color?.resolve(<WidgetState>{WidgetState.hovered}),
      theme.colorScheme.primaryContainer,
    );
    expect(
      send.style?.backgroundColor?.resolve(<WidgetState>{WidgetState.disabled}),
      theme.colorScheme.primaryContainer,
    );
    expect(
      send.style?.foregroundColor?.resolve(<WidgetState>{WidgetState.disabled}),
      theme.colorScheme.onPrimaryContainer,
    );
    expect(
      tester.getSize(find.byKey(const Key('surface-interaction-send-action'))),
      const Size.square(CoeloSize.touchMin),
    );
    expect(
      tester.getSize(find.byKey(const Key('surface-interaction-send-icon-box'))),
      const Size.square(CoeloSize.iconMd),
    );
  });

  testWidgets('uses real filters and the canonical institutions table', (tester) async {
    await _pumpFoundation(tester, 'pattern.selection-controls', CoeloTheme.light);
    expect(find.byType(CoeloAdminMultiSelectFilter<String>), findsOneWidget);

    await _pumpFoundation(tester, 'admin.resizable-table', CoeloTheme.light);
    expect(find.byWidgetPredicate((widget) => widget is CoeloAdminResizableTable), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-pinned-column')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-scroll')), findsOneWidget);
    expect(find.text('Centro Horizonte'), findsWidgets);
    expect(find.text('Em implantação'), findsWidgets);
    expect(find.byTooltip('Copiar e-mail'), findsWidgets);
  });

  testWidgets('documents the composed directory anatomy without a new public widget', (
    tester,
  ) async {
    await _pumpFoundation(tester, 'pattern.admin-directory', CoeloTheme.light);

    expect(find.byType(CoeloAdminListingToolbar), findsOneWidget);
    expect(find.byType(CoeloAdminFileActions), findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is CoeloAdminResizableTable), findsOneWidget);
    expect(find.byType(CoeloAdminPagination), findsOneWidget);
    expect(find.byKey(const Key('admin-directory-view-toggle')), findsOneWidget);
    expect(find.byKey(const Key('admin-directory-create-table-gap')), findsOneWidget);

    await tester.tap(find.byTooltip('Visualizar em cards'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-directory-hover-card')), findsOneWidget);

    final theme = Theme.of(tester.element(find.byKey(const Key('admin-directory-hover-card'))));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('admin-directory-hover-card'))));
    await tester.pumpAndSettle();

    final hoveredCard = tester.widget<AnimatedContainer>(
      find.byKey(const Key('admin-directory-hover-card-container')),
    );
    final decoration = hoveredCard.decoration! as BoxDecoration;
    expect(decoration.color, theme.colorScheme.surface);
    expect(decoration.border, isA<Border>());
    expect(
      (decoration.border! as Border).top.color,
      theme.colorScheme.primary.withValues(alpha: 0.5),
    );
  });

  testWidgets('documents standard and destructive flyout groups', (tester) async {
    await _pumpFoundation(tester, 'pattern.flyout-actions', CoeloTheme.light);

    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Configurações'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
    expect(find.byKey(const Key('flyout-destructive-action')), findsOneWidget);
  });

  testWidgets('keeps every enabled negative action in the error hierarchy', (tester) async {
    await _pumpFoundation(tester, 'pattern.negative-actions', CoeloTheme.light);
    final theme = Theme.of(tester.element(find.byKey(const Key('negative-close-action'))));

    for (final key in const [
      Key('negative-close-action'),
      Key('negative-exit-action'),
      Key('negative-delete-action'),
    ]) {
      final button = tester.widget<ButtonStyleButton>(find.byKey(key));
      expect(
        button.style?.foregroundColor?.resolve(const <WidgetState>{}),
        theme.colorScheme.error,
      );
      expect(
        button.style?.backgroundColor?.resolve(const <WidgetState>{WidgetState.hovered}),
        theme.colorScheme.errorContainer,
      );
    }
  });

  testWidgets('gives two and three dialog actions equal widths', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpFoundation(tester, 'pattern.dialog-actions', CoeloTheme.light);

    final twoCancel = tester.getSize(find.byKey(const Key('dialog-two-cancel')));
    final twoConfirm = tester.getSize(find.byKey(const Key('dialog-two-confirm')));
    expect(twoCancel.width, twoConfirm.width);

    final threeCancel = tester.getSize(find.byKey(const Key('dialog-three-cancel')));
    final threeSave = tester.getSize(find.byKey(const Key('dialog-three-save')));
    final threeDelete = tester.getSize(find.byKey(const Key('dialog-three-delete')));
    expect(threeCancel.width, threeSave.width);
    expect(threeSave.width, threeDelete.width);
  });

  testWidgets('stacks every dialog action at full equal width on compact constraints', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpFoundation(tester, 'pattern.dialog-actions', CoeloTheme.light);

    final cancel = tester.getRect(find.byKey(const Key('dialog-three-cancel')));
    final save = tester.getRect(find.byKey(const Key('dialog-three-save')));
    final delete = tester.getRect(find.byKey(const Key('dialog-three-delete')));
    expect(cancel.width, save.width);
    expect(save.width, delete.width);
    expect(cancel.bottom, lessThan(save.top));
    expect(save.bottom, lessThan(delete.top));
  });
}

Future<void> _pumpFoundation(WidgetTester tester, String id, ThemeData theme) async {
  final foundation = buildCatalogFoundationRegistry()[id]!;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Builder(builder: foundation.builder),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
