import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps the Coelo form anatomy across idle, hover and focus', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloFormTextField(
            controller: controller,
            labelText: 'E-mail',
            hintText: 'seu.email@coelo.me',
            prefixIcon: Icons.mail_outline_rounded,
          ),
        ),
      ),
    );

    final decoration = tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;
    expect(decoration.floatingLabelBehavior, FloatingLabelBehavior.always);
    expect(decoration.prefixIcon, isNotNull);
    expect(decoration.hintText, 'seu.email@coelo.me');

    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    expect(tester.widget<InputDecorator>(find.byType(InputDecorator)).isFocused, isTrue);
  });
}
