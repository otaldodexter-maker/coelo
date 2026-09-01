import 'dart:ui' show PointerDeviceKind;

import 'package:coelo_superadmin/features/principal_for_you/presentation/widgets/coelo_principal_action_card.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('is keyboard actionable and removes motion when requested', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: CoeloPrincipalActionCard(onPressed: () => presses++, child: const Text('Agenda')),
          ),
        ),
      ),
    );

    final animation = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(animation.duration, Duration.zero);
    tester.widget<TextButton>(find.byType(TextButton)).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(presses, 1);
  });

  testWidgets('exposes real hover, focus and pressed states to optional builders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloPrincipalActionCard(
            onPressed: () {},
            decoration: WidgetStateProperty.resolveWith(
              (states) => BoxDecoration(
                color: states.contains(WidgetState.hovered) ? Colors.orange : Colors.white,
              ),
            ),
            childBuilder: (context, states) => Text(
              states.contains(WidgetState.pressed)
                  ? 'pressed'
                  : states.contains(WidgetState.hovered)
                  ? 'hovered'
                  : states.contains(WidgetState.focused)
                  ? 'focused'
                  : 'idle',
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byType(CoeloPrincipalActionCard)));
    await tester.pump();
    expect(find.text('hovered'), findsOneWidget);

    await mouse.removePointer();
    tester.widget<TextButton>(find.byType(TextButton)).focusNode!.requestFocus();
    await tester.pump();
    expect(find.text('focused'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CoeloPrincipalActionCard)),
    );
    await tester.pump();
    expect(find.text('pressed'), findsOneWidget);
    await gesture.up();
  });

  testWidgets('merges selected into the states exposed to custom builders', (tester) async {
    Set<WidgetState>? decorationStates;
    Set<WidgetState>? childStates;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloPrincipalActionCard(
            selected: true,
            onPressed: () {},
            decoration: WidgetStateProperty.resolveWith((states) {
              decorationStates = {...states};
              return const BoxDecoration();
            }),
            childBuilder: (context, states) {
              childStates = {...states};
              return const Text('Selecionado');
            },
          ),
        ),
      ),
    );

    expect(decorationStates, contains(WidgetState.selected));
    expect(childStates, contains(WidgetState.selected));
  });
}
