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

  testWidgets('semantic toggle changes only the draft once and supports Escape and Apply', (
    tester,
  ) async {
    final changes = <Set<String>>[];
    await _pumpField(tester, onChanged: changes.add);
    await tester.tap(find.text('Selecionar'));
    await tester.pumpAndSettle();

    final option = find.bySemanticsLabel('Asma');
    expect(tester.getSemantics(option).label, 'Asma');
    expect(tester.getSemantics(option).flagsCollection.isChecked, ui.CheckedState.isFalse);
    expect(
      tester.getSemantics(option).getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isTrue,
    );
    _semanticTap(tester, option);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(option).flagsCollection.isChecked, ui.CheckedState.isTrue);
    expect(changes, isEmpty);
    expect(find.text('Aplicar'), findsOneWidget);

    _semanticTap(tester, option);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(option).flagsCollection.isChecked, ui.CheckedState.isFalse);
    expect(changes, isEmpty);

    _semanticTap(tester, option);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Aplicar'), findsNothing);
    expect(changes, isEmpty);
    expect(tester.widget<InkWell>(find.byType(InkWell)).focusNode!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(option).flagsCollection.isChecked, ui.CheckedState.isFalse);
    _semanticTap(tester, option);
    await tester.pumpAndSettle();
    _semanticTap(tester, find.bySemanticsLabel('Aplicar'));
    await tester.pumpAndSettle();
    expect(changes, [
      <String>{'Asma'},
    ]);
    expect(find.text('Aplicar'), findsNothing);
  });

  for (final unavailable in ['disabled', 'loading']) {
    testWidgets('$unavailable field cannot expose an actionable menu initially', (tester) async {
      final changes = <Set<String>>[];
      await _pumpField(
        tester,
        enabled: unavailable != 'disabled',
        isLoading: unavailable == 'loading',
        onChanged: changes.add,
      );
      final trigger = find.byType(InputDecorator);
      expect(
        tester.getSemantics(trigger).getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isFalse,
      );
      await tester.tap(find.text('Selecionar'));
      await tester.pump();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(changes, isEmpty);
    });

    testWidgets(
      '$unavailable transition blocks toggles and commits while preserving the open draft',
      (tester) async {
        final changes = <Set<String>>[];
        await _pumpField(tester, onChanged: changes.add);
        await tester.tap(find.text('Selecionar'));
        await tester.pumpAndSettle();
        final option = find.bySemanticsLabel('Asma');
        _semanticTap(tester, option);
        await tester.pumpAndSettle();
        expect(tester.getSemantics(option).flagsCollection.isChecked, ui.CheckedState.isTrue);
        final optionNodeId = tester.getSemantics(option).id;

        await _pumpField(
          tester,
          enabled: unavailable != 'disabled',
          isLoading: unavailable == 'loading',
          onChanged: changes.add,
        );
        await tester.pump();
        expect(
          tester.getSemantics(option).getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isFalse,
        );
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Aplicar'))
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          isFalse,
        );
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Limpar'))
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          isFalse,
        );
        tester.binding.performSemanticsAction(
          ui.SemanticsActionEvent(
            type: ui.SemanticsAction.tap,
            viewId: tester.view.viewId,
            nodeId: optionNodeId,
          ),
        );
        await tester.tap(find.text('Asma'));
        await tester.tap(find.text('Aplicar'));
        await tester.tap(find.text('Limpar'));
        await tester.pump();
        expect(tester.getSemantics(option).flagsCollection.isChecked, ui.CheckedState.isTrue);
        expect(changes, isEmpty);

        await _pumpField(tester, onChanged: changes.add);
        await tester.pumpAndSettle();
        expect(tester.getSemantics(option).flagsCollection.isChecked, ui.CheckedState.isTrue);
        _semanticTap(tester, find.bySemanticsLabel('Aplicar'));
        await tester.pumpAndSettle();
        expect(changes, [
          <String>{'Asma'},
        ]);
      },
    );
  }
}

void _semanticTap(WidgetTester tester, Finder finder) {
  final node = tester.getSemantics(finder);
  tester.binding.performSemanticsAction(
    ui.SemanticsActionEvent(
      type: ui.SemanticsAction.tap,
      viewId: tester.view.viewId,
      nodeId: node.id,
    ),
  );
}

Future<void> _pumpField(
  WidgetTester tester, {
  Set<String> selectedValues = const {},
  ValueChanged<Set<String>>? onChanged,
  bool searchable = false,
  bool enabled = true,
  bool isLoading = false,
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
              enabled: enabled,
              isLoading: isLoading,
            ),
          ),
        ),
      ),
    ),
  );
}
