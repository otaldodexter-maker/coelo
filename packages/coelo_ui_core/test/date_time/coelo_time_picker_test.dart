import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens from keyboard, applies HH:mm and restores focus', (tester) async {
    TimeOfDay? value;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: CoeloTimeField(value: value, onChanged: (next) => setState(() => value = next)),
          ),
        ),
      ),
    );

    expect(find.text('Horário'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('coelo-time-picker-dialog')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('coelo-time-picker-input')), '09:45');
    await tester.tap(find.byKey(const ValueKey('coelo-time-picker-apply')));
    await tester.pumpAndSettle();

    expect(find.text('09:45'), findsOneWidget);
    expect(value, const TimeOfDay(hour: 9, minute: 45));
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
  });

  testWidgets('keeps dialog open and announces invalid HH:mm', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(body: CoeloTimeField(value: null, onChanged: (_) {})),
      ),
    );

    await tester.tap(find.text('Selecionar hora'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('coelo-time-picker-input')), '29:70');
    await tester.tap(find.byKey(const ValueKey('coelo-time-picker-apply')));
    await tester.pump();

    expect(find.text('Informe um horário válido no formato HH:mm.'), findsOneWidget);
    expect(find.byKey(const ValueKey('coelo-time-picker-dialog')), findsOneWidget);
  });

  testWidgets('Escape cancels and disabled field cannot open', (tester) async {
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              CoeloTimeField(
                value: const TimeOfDay(hour: 8, minute: 0),
                onChanged: (_) => changes++,
              ),
              CoeloTimeField(value: null, onChanged: (_) => changes++, enabled: false),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('08:00'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coelo-time-picker-dialog')), findsNothing);
    expect(changes, 0);

    await tester.tap(find.text('Selecionar hora'));
    await tester.pump();
    expect(find.byKey(const ValueKey('coelo-time-picker-dialog')), findsNothing);
  });

  testWidgets('dialog reflows actions at 200 percent text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: CoeloTimeField(value: null, onChanged: (_) {})),
      ),
    );

    await tester.tap(find.text('Selecionar hora'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('coelo-time-picker-dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Aplicar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  for (final width in [768.0, 1024.0]) {
    testWidgets('opens without overflow at ${width.toInt()} with reduced motion', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: width == 768 ? CoeloTheme.light : CoeloTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: CoeloTimeField(value: const TimeOfDay(hour: 14, minute: 30), onChanged: (_) {}),
          ),
        ),
      );

      await tester.tap(find.text('14:30'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('coelo-time-picker-dialog')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
