import 'dart:ui' show PointerDeviceKind, SemanticsAction;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('activates by pointer, Enter and Space and disables with null callback', (
    tester,
  ) async {
    var calls = 0;
    await _pumpAction(tester, onPressed: () => calls += 1);

    await tester.tap(find.text('Criar instituição'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(calls, 3);

    await _pumpAction(tester, onPressed: null);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
  });

  testWidgets('uses semantic label, hover state and reduced motion', (tester) async {
    await _pumpAction(tester, disableAnimations: true);

    final semantics = tester.getSemantics(find.text('Criar instituição'));
    expect(semantics.label, contains('Criar instituição'));
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byType(InkWell)));
    await tester.pump();

    var animation = tester.widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>).first,
    );
    expect(animation.tween.end, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    animation = tester.widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>).first,
    );
    expect(animation.duration, Duration.zero);
  });

  testWidgets('uses the supplied icon', (tester) async {
    await _pumpAction(tester, icon: Icons.add_business_outlined);
    expect(find.byIcon(Icons.add_business_outlined), findsOneWidget);
  });

  testWidgets('removes semantic activation when disabled', (tester) async {
    await _pumpAction(tester, onPressed: null);

    final semantics = tester.getSemantics(find.text('Criar instituição'));
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
  });

  testWidgets('keeps the approved public widget stateless', (tester) async {
    await _pumpAction(tester);

    expect(
      tester.widget<CoeloAdminCreateAction>(find.byType(CoeloAdminCreateAction)),
      isA<StatelessWidget>(),
    );
  });
}

Future<void> _pumpAction(
  WidgetTester tester, {
  VoidCallback? onPressed = _noop,
  IconData icon = Icons.add,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 216,
          child: CoeloAdminCreateAction(
            label: 'Criar instituição',
            onPressed: onPressed,
            icon: icon,
          ),
        ),
      ),
    ),
  );
}

void _noop() {}
