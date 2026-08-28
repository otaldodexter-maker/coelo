import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps selection as draft until Apply is activated', (tester) async {
    DateTimeRange? committed;

    await tester.pumpWidget(
      _testApp(
        width: 1024,
        child: CoeloDateRangePicker(
          value: null,
          onChanged: (value) => committed = value,
          firstDate: DateTime(2026, 8),
          lastDate: DateTime(2026, 9, 30),
          currentDate: DateTime(2026, 8, 13),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('coelo-date-2026-08-13')));
    await tester.tap(find.byKey(const ValueKey('coelo-date-2026-08-15')));
    await tester.pump();

    expect(committed, isNull);

    await tester.tap(find.byKey(const ValueKey('coelo-date-range-apply')));
    await tester.pump();

    expect(committed?.start, DateTime(2026, 8, 13));
    expect(committed?.end, DateTime(2026, 8, 15));
  });

  testWidgets('offers pt-BR quick ranges and clears the committed value', (tester) async {
    DateTimeRange? committed = DateTimeRange(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 2),
    );

    await tester.pumpWidget(
      _testApp(
        width: 768,
        child: CoeloDateRangePicker(
          value: committed,
          onChanged: (value) => committed = value,
          firstDate: DateTime(2026),
          lastDate: DateTime(2026, 12, 31),
          currentDate: DateTime(2026, 8, 13),
        ),
      ),
    );

    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('Esta semana'), findsOneWidget);
    expect(find.text('Este mês'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('coelo-date-range-clear')));
    await tester.pump();

    expect(committed, isNull);
  });

  testWidgets('rejects a range that crosses an unavailable day', (tester) async {
    DateTimeRange? committed;

    await tester.pumpWidget(
      _testApp(
        width: 1024,
        child: CoeloDateRangePicker(
          value: null,
          onChanged: (value) => committed = value,
          firstDate: DateTime(2026, 8),
          lastDate: DateTime(2026, 8, 31),
          currentDate: DateTime(2026, 8, 13),
          selectableDayPredicate: (day) => day.day != 14,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('coelo-date-2026-08-13')));
    await tester.tap(find.byKey(const ValueKey('coelo-date-2026-08-15')));
    await tester.pump();

    expect(find.text('O intervalo inclui uma data indisponível.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const ValueKey('coelo-date-range-apply'))).onPressed,
      isNull,
    );
    expect(committed, isNull);
  });

  testWidgets('uses two months only when the panel constraints fit', (tester) async {
    await tester.pumpWidget(
      _testApp(
        width: 1024,
        child: CoeloDateRangePicker(
          value: null,
          onChanged: (_) {},
          firstDate: DateTime(2026, 8),
          lastDate: DateTime(2026, 12, 31),
          currentDate: DateTime(2026, 8, 13),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('coelo-date-range-month')), findsNWidgets(2));

    await tester.pumpWidget(
      _testApp(
        width: 375,
        child: CoeloDateRangePicker(
          value: null,
          onChanged: (_) {},
          firstDate: DateTime(2026, 8),
          lastDate: DateTime(2026, 12, 31),
          currentDate: DateTime(2026, 8, 13),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('coelo-date-range-month')), findsOneWidget);
  });

  testWidgets('Escape dismisses the dialog without committing draft changes', (tester) async {
    DateTimeRange? result = DateTimeRange(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 2));

    await tester.pumpWidget(
      _testApp(
        width: 1024,
        child: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showCoeloDateRangePicker(
                context: context,
                value: result,
                firstDate: DateTime(2026, 8),
                lastDate: DateTime(2026, 9, 30),
                currentDate: DateTime(2026, 8, 13),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('coelo-date-2026-08-13')));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(CoeloDateRangePicker), findsNothing);
    expect(result?.start, DateTime(2026, 8, 1));
    expect(result?.end, DateTime(2026, 8, 2));
  });

  testWidgets('field dismiss preserves the value, callback, and trigger focus', (tester) async {
    var changes = 0;
    final value = DateTimeRange(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 2));

    await tester.pumpWidget(
      _testApp(
        width: 768,
        child: CoeloDateRangeField(
          value: value,
          onChanged: (_) => changes += 1,
          firstDate: DateTime(2026, 8),
          lastDate: DateTime(2026, 9, 30),
          currentDate: DateTime(2026, 8, 13),
        ),
      ),
    );

    await tester.tap(find.text('01/08/2026 – 02/08/2026'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(changes, 0);
    expect(
      tester
          .widget<FocusableActionDetector>(find.byType(FocusableActionDetector))
          .focusNode
          ?.hasFocus,
      isTrue,
    );
  });

  testWidgets('navigates between day month and year views in pt-BR', (tester) async {
    await tester.pumpWidget(
      _testApp(
        width: 375,
        child: CoeloDateRangePicker(
          value: null,
          onChanged: (_) {},
          firstDate: DateTime(2020),
          lastDate: DateTime(2030, 12, 31),
          currentDate: DateTime(2026, 8, 13),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('coelo-date-range-title')));
    await tester.pump();
    expect(find.text('Jan'), findsOneWidget);
    expect(find.text('Dez'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('coelo-date-range-title')));
    await tester.pump();
    expect(find.text('2020–2029'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('coelo-year-2027')));
    await tester.pump();
    expect(find.text('2027'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('coelo-month-2027-11')));
    await tester.pump();
    expect(find.text('Novembro de 2027'), findsWidgets);
    expect(find.byKey(const ValueKey('coelo-date-2027-11-01')), findsOneWidget);
  });

  testWidgets('field formats a normalized range and stays closed when disabled', (tester) async {
    DateTimeRange? changed;
    await tester.pumpWidget(
      _testApp(
        width: 768,
        child: CoeloDateRangeField(
          value: DateTimeRange(start: DateTime(2026, 8, 13, 22), end: DateTime(2026, 8, 15, 23)),
          onChanged: (value) => changed = value,
          firstDate: DateTime(2026),
          lastDate: DateTime(2026, 12, 31),
          enabled: false,
        ),
      ),
    );

    expect(find.text('13/08/2026 – 15/08/2026'), findsOneWidget);
    await tester.tap(find.byType(CoeloDateRangeField));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloDateRangePicker), findsNothing);
    expect(changed, isNull);
  });

  testWidgets('field supports a single-date calendar without range copy', (tester) async {
    await tester.pumpWidget(
      _testApp(
        width: 375,
        child: CoeloDateRangeField(
          value: DateTimeRange(start: DateTime(2014, 5, 9), end: DateTime(2014, 5, 9)),
          onChanged: (_) {},
          firstDate: DateTime(1900),
          lastDate: DateTime(2026, 8, 28),
          currentDate: DateTime(2026, 8, 28),
          selectionMode: CoeloDateSelectionMode.single,
          labelText: 'Data de nascimento',
        ),
      ),
    );

    expect(find.text('09/05/2014'), findsOneWidget);
    expect(find.textContaining('–'), findsNothing);
    await tester.tap(find.byType(CoeloDateRangeField));
    await tester.pumpAndSettle();
    final picker = tester.widget<CoeloDateRangePicker>(find.byType(CoeloDateRangePicker));
    expect(picker.selectionMode, CoeloDateSelectionMode.single);
  });

  testWidgets('day hover and focus stay in the semantic primary palette', (tester) async {
    await tester.pumpWidget(
      _testApp(
        width: 768,
        child: CoeloDateRangePicker(
          value: null,
          onChanged: (_) {},
          firstDate: DateTime(2026, 8),
          lastDate: DateTime(2026, 8, 31),
          currentDate: DateTime(2026, 8, 13),
        ),
      ),
    );

    final context = tester.element(find.byType(CoeloDateRangePicker));
    final colors = Theme.of(context).colorScheme;
    final button = tester.widget<TextButton>(find.byKey(const ValueKey('coelo-date-2026-08-15')));

    expect(button.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.primaryContainer);
    expect(button.style?.foregroundColor?.resolve({WidgetState.focused}), colors.primary);
  });

  testWidgets('compact picker remains usable with text scaled to 200 percent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 900),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: SizedBox(
              width: 375,
              child: CoeloDateRangePicker(
                value: null,
                onChanged: (_) {},
                firstDate: DateTime(2026, 8),
                lastDate: DateTime(2026, 12, 31),
                currentDate: DateTime(2026, 8, 13),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Hoje'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('coelo-date-range-apply')), findsOneWidget);
  });
}

Widget _testApp({required double width, required Widget child}) => MaterialApp(
  theme: CoeloTheme.light,
  home: MediaQuery(
    data: MediaQueryData(size: Size(width, 900)),
    child: Scaffold(
      body: SizedBox(width: width, child: child),
    ),
  ),
);
