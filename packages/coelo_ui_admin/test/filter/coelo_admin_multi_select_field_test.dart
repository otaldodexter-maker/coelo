import 'dart:ui' as ui;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps a draft until Apply and matches the trigger width', (tester) async {
    var selected = <String>{'Asma'};
    await _pumpField(tester, selectedValues: selected, onChanged: (values) => selected = values);

    await tester.tap(find.text('Asma'));
    await tester.pumpAndSettle();

    final anchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
    final triggerWidth = tester.getSize(find.byType(InputDecorator)).width;
    expect(anchor.crossAxisUnconstrained, isFalse);
    expect(anchor.style!.minimumSize!.resolve({})!.width, triggerWidth);
    expect(anchor.style!.maximumSize!.resolve({})!.width, triggerWidth);

    await tester.tap(find.text('Diabetes'));
    await tester.pumpAndSettle();
    expect(selected, {'Asma'});

    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(selected, {'Asma', 'Diabetes'});
  });

  testWidgets('Escape discards the draft and restores focus to the field', (tester) async {
    await _pumpField(tester);

    await tester.tap(find.text('Selecionar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asma'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Aplicar'), findsNothing);
    final trigger = tester.widget<InkWell>(find.byType(InkWell));
    expect(trigger.focusNode!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final asma = find.ancestor(of: find.text('Asma').last, matching: find.byType(MenuItemButton));
    expect(
      tester.widget<Checkbox>(find.descendant(of: asma, matching: find.byType(Checkbox))).value,
      isFalse,
    );
  });

  testWidgets('supports optional search and semantic checked state', (tester) async {
    await _pumpField(tester, searchable: true);

    await tester.tap(find.text('Selecionar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('coelo-admin-multi-select-search')), 'dia');
    await tester.pump();

    expect(find.text('Diabetes'), findsOneWidget);
    expect(find.text('Asma'), findsNothing);
    await tester.tap(find.text('Diabetes'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Diabetes')).flagsCollection.isChecked,
      ui.CheckedState.isTrue,
    );
  });
}

Future<void> _pumpField(
  WidgetTester tester, {
  Set<String> selectedValues = const {},
  ValueChanged<Set<String>>? onChanged,
  bool searchable = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: CoeloAdminMultiSelectField<String>(
              label: 'Condi??es de cuidado',
              options: const ['Asma', 'Diabetes', 'Epilepsia'],
              selectedValues: selectedValues,
              optionLabel: (value) => value,
              onChanged: onChanged ?? (_) {},
              searchable: searchable,
            ),
          ),
        ),
      ),
    ),
  );
}
