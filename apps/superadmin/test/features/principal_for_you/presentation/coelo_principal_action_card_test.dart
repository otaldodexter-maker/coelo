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
}
