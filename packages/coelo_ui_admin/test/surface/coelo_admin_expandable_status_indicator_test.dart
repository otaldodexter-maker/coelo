import 'dart:ui';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts as a 24 pixel dot with its label hidden', (tester) async {
    await _pumpStatus(tester);

    final surface = find.byKey(const Key('expandable-status-surface'));
    expect(tester.getSize(surface), const Size.square(24));
    expect(find.text('Ativa'), findsNothing);
    expect(find.bySemanticsLabel('Status: Ativa'), findsOneWidget);
  });

  testWidgets('reveals the status on hover without a gray overlay', (tester) async {
    await _pumpStatus(tester);
    final surface = find.byKey(const Key('expandable-status-surface'));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(surface));
    await tester.pumpAndSettle();

    expect(find.text('Ativa'), findsOneWidget);
    expect(tester.getSize(surface).width, greaterThan(CoeloSpacing.space8));
    final decoration = tester.widget<Container>(surface).decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFE8F5EE));
    expect(decoration.borderRadius, BorderRadius.circular(CoeloRadius.full));
  });

  testWidgets('tap keeps the label expanded for touch users', (tester) async {
    await _pumpStatus(tester);
    final surface = find.byKey(const Key('expandable-status-surface'));

    await tester.tap(surface);
    await tester.pumpAndSettle();

    expect(find.text('Ativa'), findsOneWidget);
  });

  testWidgets('uses instant motion when animations are disabled', (tester) async {
    await _pumpStatus(tester, disableAnimations: true);

    final animation = tester.widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>),
    );
    expect(animation.duration, Duration.zero);
  });
}

Future<void> _pumpStatus(WidgetTester tester, {bool disableAnimations = false}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
          child: const Scaffold(
            body: Center(
              child: CoeloAdminExpandableStatusIndicator(
                label: 'Ativa',
                semanticLabel: 'Status: Ativa',
                backgroundColor: Color(0xFFE8F5EE),
                foregroundColor: Color(0xFF166534),
                surfaceKey: Key('expandable-status-surface'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
