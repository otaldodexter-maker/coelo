import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exposes semantic value and opens from keyboard', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloDateTimeField(
            value: DateTime(2026, 8, 18, 9, 30),
            onChanged: (_) {},
            firstDate: DateTime(2026),
            lastDate: DateTime(2027),
            currentDate: DateTime(2026, 8, 12),
          ),
        ),
      ),
    );

    expect(find.text('18/08/2026 · 09:30'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coelo-date-range-title')), findsOneWidget);
  });

  testWidgets('disabled field cannot open', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloDateTimeField(
            value: null,
            onChanged: (_) {},
            firstDate: DateTime(2026),
            lastDate: DateTime(2027),
            enabled: false,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Publicar agora'));
    await tester.pump();
    expect(find.byKey(const ValueKey('coelo-date-range-title')), findsNothing);
  });
}
