import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders continuous options with semantic selected styling', (tester) async {
    var value = 'Rascunho';
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: CoeloAdminSingleSelectField<String>(
              label: 'Status',
              value: value,
              options: const ['Rascunho', 'Ativa'],
              optionLabel: (option) => option,
              onChanged: (option) => setState(() => value = option),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rascunho'));
    await tester.pumpAndSettle();
    final selected = tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, 'Rascunho'));
    final triggerWidth = tester.getSize(find.byType(InputDecorator)).width;
    final anchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
    expect(anchor.crossAxisUnconstrained, isFalse);
    expect(anchor.alignmentOffset, const Offset(0, CoeloSpacing.space1));
    expect(anchor.style!.minimumSize!.resolve({})!.width, triggerWidth);
    expect(anchor.style!.maximumSize!.resolve({})!.width, triggerWidth);
    expect(
      find.descendant(
        of: find.widgetWithText(MenuItemButton, 'Rascunho'),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsNothing,
    );
    expect(
      selected.style!.backgroundColor!.resolve({}),
      CoeloTheme.light.colorScheme.primaryContainer,
    );

    await tester.tap(find.text('Ativa'));
    await tester.pumpAndSettle();
    expect(value, 'Ativa');
  });
}
