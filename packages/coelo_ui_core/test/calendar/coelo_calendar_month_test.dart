import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('navigates, selects a day and exposes event semantics', (tester) async {
    DateTime? selected;
    var previous = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoeloCalendarMonth(
            displayedMonth: DateTime(2026, 8),
            selectedDate: DateTime(2026, 8, 24),
            events: [
              CoeloCalendarEventMarker(
                id: 'event-1',
                date: DateTime(2026, 8, 25),
                semanticLabel: 'Prova de matemática',
              ),
            ],
            onPreviousMonth: () => previous = true,
            onNextMonth: () {},
            onDateSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-calendar-previous-month')));
    await tester.tap(find.byKey(const ValueKey('coelo-calendar-day-2026-08-25')));

    expect(previous, isTrue);
    expect(selected, DateTime(2026, 8, 25));
    expect(find.bySemanticsLabel('25 de Agosto de 2026, Prova de matemática'), findsOneWidget);
  });

  testWidgets('fits a 375 wide surface with 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: CoeloCalendarMonth(
              displayedMonth: DateTime(2026, 8),
              selectedDate: DateTime(2026, 8, 24),
              events: const [],
              onDateSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
