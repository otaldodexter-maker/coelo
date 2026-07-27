import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('preserves content order without overflow at ${width.toInt()} px', (tester) async {
      await _pumpToolbar(tester, width: width);

      expect(
        find.descendant(
          of: find.byType(CoeloAdminListingToolbar),
          matching: find.byWidgetPredicate((widget) => widget.key is ValueKey<String>),
        ),
        findsNWidgets(5),
      );
      expect(tester.takeException(), isNull);

      final positions = [
        'search',
        'filter-one',
        'filter-two',
        'action-one',
        'action-two',
      ].map((key) => tester.getTopLeft(find.byKey(ValueKey(key)))).toList(growable: false);
      expect(_isInReadingOrder(positions), isTrue);
      if (width < CoeloBreakpoints.medium.minWidth) {
        expect(positions[3].dy, greaterThan(positions[0].dy));
      } else {
        expect(positions[3].dy, positions[0].dy);
      }
    });
  }

  testWidgets('places actions on a separate compact row', (tester) async {
    await _pumpToolbar(tester, width: 375);

    final search = tester.getTopLeft(find.byKey(const ValueKey('search')));
    final action = tester.getTopLeft(find.byKey(const ValueKey('action-one')));
    expect(action.dy, greaterThan(search.dy));
  });
}

bool _isInReadingOrder(List<Offset> positions) {
  for (var index = 1; index < positions.length; index += 1) {
    final previous = positions[index - 1];
    final current = positions[index];
    if (current.dy < previous.dy || (current.dy == previous.dy && current.dx < previous.dx)) {
      return false;
    }
  }
  return true;
}

Future<void> _pumpToolbar(WidgetTester tester, {required double width}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 500);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: CoeloAdminListingToolbar(
          search: const SizedBox(key: ValueKey('search'), width: 180, height: 48),
          filters: const [
            SizedBox(key: ValueKey('filter-one'), width: 120, height: 48),
            SizedBox(key: ValueKey('filter-two'), width: 120, height: 48),
          ],
          actions: const [
            SizedBox(key: ValueKey('action-one'), width: 48, height: 48),
            SizedBox(key: ValueKey('action-two'), width: 48, height: 48),
          ],
        ),
      ),
    ),
  );
}
