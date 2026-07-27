import 'package:coelo_catalog/catalog/catalog_foundations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
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
        'admin.resizable-table',
      ]),
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

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      final close = tester.widget<IconButton>(find.byKey(const Key('surface-interaction-close')));
      final theme = Theme.of(tester.element(find.byType(Dialog)));

      expect(dialog.backgroundColor, theme.colorScheme.surface);
      expect(close.icon, isA<Icon>());
      expect((close.icon as Icon).icon, Icons.close_rounded);
      expect(close.tooltip, 'Fechar demonstração');
      expect(close.constraints?.minWidth, CoeloSize.touchMin);
      expect(close.constraints?.minHeight, CoeloSize.touchMin);
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
