import 'dart:ui';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preserves the rounded Coelo surface on hover', (tester) async {
    await _pumpCard(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byType(CoeloAdminInteractiveCard)));
    await tester.pumpAndSettle();

    final surface = tester.widget<AnimatedContainer>(
      find.byKey(const Key('interactive-card-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.color, CoeloTheme.light.colorScheme.surface);
    expect(decoration.borderRadius, BorderRadius.circular(CoeloRadius.lg));
    expect(
      (decoration.border! as Border).top.color,
      CoeloTheme.light.colorScheme.primary.withValues(alpha: 0.5),
    );
    expect((decoration.border! as Border).top.width, 1.5);
    expect(decoration.boxShadow, [
      BoxShadow(
        color: CoeloTheme.light.colorScheme.primary.withValues(alpha: 0.15),
        blurRadius: 12,
        spreadRadius: 2,
        offset: const Offset(0, 4),
      ),
    ]);

    final ink = tester.widget<InkWell>(find.byType(InkWell));
    expect(ink.borderRadius, BorderRadius.circular(CoeloRadius.lg));
    expect(ink.overlayColor!.resolve({WidgetState.hovered}), Colors.transparent);
  });

  testWidgets('uses the exact Institutions resting surface', (tester) async {
    await _pumpCard(tester);

    final surface = tester.widget<AnimatedContainer>(
      find.byKey(const Key('interactive-card-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(surface.duration, CoeloMotion.standard);
    expect((decoration.border! as Border).top.width, 1);
    expect((decoration.border! as Border).top.color, CoeloTheme.light.colorScheme.outlineVariant);
    expect(decoration.boxShadow, [
      BoxShadow(
        color: CoeloTheme.light.colorScheme.shadow.withValues(alpha: 0.03),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ]);
  });

  testWidgets('uses instant motion when animations are disabled', (tester) async {
    await _pumpCard(tester, disableAnimations: true);

    final surface = tester.widget<AnimatedContainer>(
      find.byKey(const Key('interactive-card-surface')),
    );
    expect(surface.duration, Duration.zero);
  });

  testWidgets('exposes the semantic button label and callback', (tester) async {
    var presses = 0;
    await _pumpCard(tester, semanticLabel: 'Abrir instituição', onPressed: () => presses++);

    expect(find.bySemanticsLabel('Abrir instituição'), findsOneWidget);
    await tester.tap(find.byType(CoeloAdminInteractiveCard));
    expect(presses, 1);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  bool disableAnimations = false,
  String? semanticLabel,
  VoidCallback? onPressed,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: CoeloAdminInteractiveCard(
                  semanticLabel: semanticLabel,
                  onPressed: onPressed ?? () {},
                  surfaceKey: const Key('interactive-card-surface'),
                  child: const Padding(padding: EdgeInsets.all(16), child: Text('Instituição')),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
