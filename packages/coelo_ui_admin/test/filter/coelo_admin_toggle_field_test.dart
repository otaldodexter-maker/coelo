import 'dart:ui' as ui;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
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
}
