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
