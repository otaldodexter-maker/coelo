import 'dart:ui';

import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

enum _View { grouped, units, groups }

void main() {
  testWidgets('keeps the approved compact segmented trigger without visible instruction', (
    tester,
  ) async {
    await tester.pumpWidget(_app(onSelected: (_) {}));

    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(find.byType(CoeloAdminFlyout<_View>), findsOneWidget);
    final toggle = find.byType(SegmentedButton<bool>);
    expect(tester.getSize(toggle), const Size(128, 48));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message?.contains('Mantenha pressionado') == true,
      ),
      findsNothing,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byKey(const Key('table-segment'))));
    await tester.pumpAndSettle();
    final menu = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
    expect(
      menu.style?.padding?.resolve(<WidgetState>{}),
      const EdgeInsets.all(CoeloSpacing.space2),
    );
  });

  testWidgets('selects grouped when the table segment is tapped directly', (tester) async {
    _View? selected;
    await tester.pumpWidget(_app(onSelected: (value) => selected = value));

    await tester.tap(find.byKey(const Key('table-segment')));
    await tester.pumpAndSettle();

    expect(selected, _View.grouped);
    expect(find.text('Detalhado por Unidades'), findsNothing);
  });

  testWidgets('opens table variations on hover and applies the chosen view', (tester) async {
    _View? selected;
    await tester.pumpWidget(_app(onSelected: (value) => selected = value));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    final toggleRect = tester.getRect(find.byType(SegmentedButton<bool>));
    await mouse.addPointer(location: Offset(toggleRect.right - 2, toggleRect.center.dy));
    await tester.pumpAndSettle();

    expect(find.text('Agrupado'), findsOneWidget);
    expect(find.text('Detalhado por Unidades'), findsOneWidget);
    await tester.tap(find.text('Detalhado por Grupos'));
    await tester.pumpAndSettle();
    expect(selected, _View.groups);
  });

  testWidgets('offers equivalent touch and keyboard paths to the variations', (tester) async {
    await tester.pumpWidget(_app(onSelected: (_) {}));

    final toggleRect = tester.getRect(find.byType(SegmentedButton<bool>));
    await tester.longPressAt(Offset(toggleRect.right - 2, toggleRect.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Detalhado por Unidades'), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('Detalhado por Unidades'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('Detalhado por Unidades'), findsOneWidget);
  });
}

Widget _app({required ValueChanged<_View> onSelected}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: Center(
        child: SuperadminDirectoryViewToggle<_View>(
          cardsSelected: true,
          groupedView: _View.grouped,
          selectedTableView: _View.grouped,
          cardsKey: const Key('cards-segment'),
          tableKey: const Key('table-segment'),
          onCardsSelected: () {},
          onTableViewSelected: onSelected,
          tableViews: const [
            SuperadminDirectoryTableViewOption(value: _View.grouped, label: 'Agrupado'),
            SuperadminDirectoryTableViewOption(value: _View.units, label: 'Detalhado por Unidades'),
            SuperadminDirectoryTableViewOption(value: _View.groups, label: 'Detalhado por Grupos'),
          ],
        ),
      ),
    ),
  );
}
