import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('directory single selection uses the filter pill ($dark)', (tester) async {
      var value = 'Todas';
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? CoeloTheme.dark : CoeloTheme.light,
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SizedBox(
                width: 300,
                child: CoeloAdminSingleSelectField<String>(
                  label: 'Origem',
                  value: value,
                  isFilter: true,
                  unselectedValue: 'Todas',
                  options: const ['Todas', 'Coelo', 'Institucional'],
                  optionLabel: (option) => option,
                  onChanged: (option) => setState(() => value = option),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(InputDecorator), findsNothing);
      final trigger = find.widgetWithText(OutlinedButton, 'Origem');
      expect(tester.getSize(trigger).height, greaterThanOrEqualTo(CoeloSize.touchMin));
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Aplicar'), findsNothing);
      await tester.tap(find.widgetWithText(MenuItemButton, 'Coelo'));
      await tester.pumpAndSettle();
      expect(value, 'Coelo');
      expect(find.widgetWithText(OutlinedButton, 'Coelo'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Coelo'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(value, 'Coelo');
      expect(find.byType(MenuItemButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
