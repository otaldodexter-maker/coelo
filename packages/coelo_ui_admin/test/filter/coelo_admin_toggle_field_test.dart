import 'dart:ui' as ui;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exposes label, toggled state and a 48 px target', (tester) async {
    var value = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: CoeloAdminToggleField(
              label: 'Publicar no Happens',
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(CoeloAdminToggleField));
    expect(semantics.label, 'Publicar no Happens');
    expect(semantics.flagsCollection.isToggled, isNot(ui.Tristate.none));
    expect(semantics.flagsCollection.isToggled, ui.Tristate.isTrue);
    expect(tester.getSize(find.byType(CoeloAdminToggleField)).height, greaterThanOrEqualTo(48));

    await tester.tap(find.byType(CoeloAdminToggleField));
    await tester.pump();
    expect(value, isFalse);
  });

  testWidgets('disabled state remains announced', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        home: const Scaffold(
          body: CoeloAdminToggleField(label: 'Chat', value: false, onChanged: null),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(CoeloAdminToggleField));
    expect(semantics.label, 'Chat');
    expect(semantics.flagsCollection.isEnabled, ui.Tristate.isFalse);
  });
  testWidgets('uses approved tonal hover and supports description', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloAdminToggleField(
            label: 'Aviso obrigatório',
            description: 'O aviso precisa de uma ação antes de fechar.',
            value: false,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('O aviso precisa de uma ação antes de fechar.'), findsOneWidget);
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byType(CoeloAdminToggleField)));
    await tester.pumpAndSettle();
    final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, CoeloTheme.light.colorScheme.primaryContainer);
    expect(decoration.borderRadius, BorderRadius.circular(CoeloRadius.md));
    final switchTheme = tester.widget<SwitchTheme>(find.byType(SwitchTheme));
    expect(switchTheme.data.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
  });

  testWidgets('Enter and Space activate the single keyboard stop exactly once', (tester) async {
    final fixture = _ToggleFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    fixture.before.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(fixture.changes, [true], reason: 'the first Tab stop must activate with Enter');

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(fixture.changes, [true, false]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(fixture.after.hasPrimaryFocus, isTrue, reason: 'the nested Switch is not another stop');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(fixture.changes, [true, false, true]);
  });

  testWidgets('semantic action and direct switch tap each toggle once', (tester) async {
    final fixture = _ToggleFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    final field = find.byType(CoeloAdminToggleField);
    final node = tester.getSemantics(field);
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    tester.binding.performSemanticsAction(
      ui.SemanticsActionEvent(
        type: ui.SemanticsAction.tap,
        viewId: tester.view.viewId,
        nodeId: node.id,
      ),
    );
    await tester.pumpAndSettle();
    expect(fixture.changes, [true]);
    expect(tester.getSemantics(field).flagsCollection.isToggled, ui.Tristate.isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(fixture.changes, [true, false]);
    expect(tester.getSemantics(field).flagsCollection.isToggled, ui.Tristate.isFalse);
  });

  testWidgets('disabled transition blocks keyboard, pointer and an earlier semantic callback', (
    tester,
  ) async {
    final fixture = _ToggleFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    fixture.before.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final semanticsWidget = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Receber avisos',
      ),
    );
    final previousTap = semanticsWidget.properties.onTap!;
    fixture.enabled.value = false;
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.byType(CoeloAdminToggleField));
    expect(node.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isFalse);

    previousTap();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(fixture.changes, isEmpty);
    expect(tester.takeException(), isNull);

    fixture.before.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(fixture.after.hasPrimaryFocus, isTrue, reason: 'disabled toggle is skipped');

    fixture.enabled.value = true;
    await tester.pump();
    fixture.before.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(fixture.changes, [true]);
  });

  testWidgets('keyboard focus keeps tonal highlight after hover leaves and clears when disabled', (
    tester,
  ) async {
    final previousStrategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = previousStrategy);
    final fixture = _ToggleFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    fixture.before.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    Color fieldColor() =>
        (tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration!
                as BoxDecoration)
            .color!;
    expect(fieldColor(), CoeloTheme.light.colorScheme.primaryContainer);

    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byType(CoeloAdminToggleField)));
    await tester.pumpAndSettle();
    await mouse.moveTo(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(fieldColor(), CoeloTheme.light.colorScheme.primaryContainer);

    fixture.enabled.value = false;
    await tester.pumpAndSettle();
    expect(fieldColor(), CoeloTheme.light.colorScheme.surface);
    expect(fixture.changes, isEmpty);
  });
}

final class _ToggleFixture {
  final before = FocusNode();
  final after = FocusNode();
  final value = ValueNotifier(false);
  final enabled = ValueNotifier(true);
  final changes = <bool>[];

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: AnimatedBuilder(
              animation: Listenable.merge([value, enabled]),
              builder: (context, child) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(focusNode: before, onPressed: () {}, child: const Text('Antes')),
                  CoeloAdminToggleField(
                    label: 'Receber avisos',
                    value: value.value,
                    onChanged: enabled.value
                        ? (next) {
                            changes.add(next);
                            value.value = next;
                          }
                        : null,
                  ),
                  TextButton(focusNode: after, onPressed: () {}, child: const Text('Depois')),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  void dispose() {
    before.dispose();
    after.dispose();
    value.dispose();
    enabled.dispose();
  }
}
