import 'dart:ui';

import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('uses the approved borderless glass in ${brightness.name}', (tester) async {
      await tester.pumpWidget(_app(brightness: brightness, childHeight: 40));

      final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(filter.filter.toString(), contains('${CoeloSpacing.space3}'));

      final surface = find
          .descendant(
            of: find.byKey(const Key('pagination-footer')),
            matching: find.byType(Container),
          )
          .first;
      final decoration = tester.widget<Container>(surface).decoration! as BoxDecoration;
      final colors = brightness == Brightness.light
          ? CoeloTheme.light.colorScheme
          : CoeloTheme.dark.colorScheme;
      expect(
        decoration.color,
        colors.surface.withValues(alpha: brightness == Brightness.light ? 0.84 : 0.88),
      );
      expect(decoration.border, isNull);
      expect(find.byType(SafeArea), findsOneWidget);
    });
  }

  testWidgets('tracks a child whose height changes', (tester) async {
    await tester.pumpWidget(_app(brightness: Brightness.light, childHeight: 40));
    final compact = tester.getSize(find.byKey(const Key('pagination-footer'))).height;

    await tester.pumpWidget(_app(brightness: Brightness.light, childHeight: 96));
    await tester.pump();
    final expanded = tester.getSize(find.byKey(const Key('pagination-footer'))).height;

    expect(expanded, greaterThan(compact));
  });

  testWidgets('compact layout keeps page summary and semantic chevrons', (tester) async {
    var previousCalls = 0;
    var nextCalls = 0;
    await _setSurfaceSize(tester, const Size(375, 240));
    await tester.pumpWidget(
      _responsiveApp(
        currentPage: 2,
        totalPages: 4,
        onPrevious: () => previousCalls++,
        onNext: () => nextCalls++,
      ),
    );
    expect(find.text('P\u00e1gina 2 de 4'), findsOneWidget);
    expect(find.text('Itens por p\u00e1gina'), findsNothing);
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
    final previous = find.bySemanticsLabel('P\u00e1gina anterior');
    final next = find.bySemanticsLabel('Pr\u00f3xima p\u00e1gina');
    expect(tester.getSemantics(previous).getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(tester.getSemantics(next).getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    final previousButton = tester.widget<IconButton>(find.byType(IconButton).first);
    final colors = CoeloTheme.light.colorScheme;
    expect(
      previousButton.style?.backgroundColor?.resolve({WidgetState.hovered}),
      colors.primaryContainer,
    );
    expect(previousButton.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
    expect(find.text('Anterior'), findsNothing);
    expect(find.text('Pr\u00f3xima'), findsNothing);
    await tester.tap(previous);
    await tester.tap(next);
    expect((previousCalls, nextCalls), (1, 1));
  });

  testWidgets('compact layout stays on one row at 200 percent text', (tester) async {
    await _setSurfaceSize(tester, const Size(375, 240));
    await tester.pumpWidget(
      _responsiveApp(currentPage: 12, totalPages: 24, textScaler: const TextScaler.linear(2)),
    );
    expect(tester.takeException(), isNull);
    final y = tester.getCenter(find.text('P\u00e1gina 12 de 24')).dy;
    expect(tester.getCenter(find.bySemanticsLabel('P\u00e1gina anterior')).dy, y);
    expect(tester.getCenter(find.bySemanticsLabel('Pr\u00f3xima p\u00e1gina')).dy, y);
  });

  testWidgets('medium breakpoint preserves complete child', (tester) async {
    await _setSurfaceSize(tester, Size(CoeloBreakpoints.medium.minWidth, 240));
    await tester.pumpWidget(_responsiveApp(currentPage: 2, totalPages: 4));
    expect(find.text('Itens por p\u00e1gina'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Anterior'), findsOneWidget);
    expect(find.text('Pr\u00f3xima'), findsOneWidget);
    expect(find.text('P\u00e1gina 2 de 4'), findsNothing);
  });
}

Widget _app({required Brightness brightness, required double childHeight}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: SuperadminListingPaginationFooter(
          key: const Key('pagination-footer'),
          horizontalPadding: CoeloSpacing.space4,
          child: SizedBox(height: childHeight, child: const Text('Paginação')),
        ),
      ),
    ),
  );
}

Widget _responsiveApp({
  required int currentPage,
  required int totalPages,
  VoidCallback? onPrevious,
  VoidCallback? onNext,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: SuperadminListingPaginationFooter(
        horizontalPadding: CoeloSpacing.space4,
        compactCurrentPage: currentPage,
        compactTotalPages: totalPages,
        compactOnPrevious: onPrevious,
        compactOnNext: onNext,
        child: const Row(
          children: [
            Text('Itens por p\u00e1gina'),
            Text('1'),
            Text('2'),
            Text('Anterior'),
            Text('Pr\u00f3xima'),
          ],
        ),
      ),
    ),
  ),
);

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
