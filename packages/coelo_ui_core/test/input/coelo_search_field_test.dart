import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (name, theme) in <(String, ThemeData)>[
    ('light', CoeloTheme.light),
    ('dark', CoeloTheme.dark),
  ]) {
    testWidgets('renders the approved search decoration in $name theme', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _TestApp(
          theme: theme,
          child: CoeloSearchField(
            controller: controller,
            onChanged: (_) {},
            semanticLabel: 'Buscar instituições',
            hintText: 'Buscar por nome',
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Buscar por nome'), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      final border = textField.decoration!.enabledBorder! as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(CoeloRadius.full));
      expect(border.borderSide.color, theme.colorScheme.outline);

      final semantics = tester.getSemantics(find.byType(TextField));
      expect(semantics.label, contains('Buscar instituições'));
    });
  }

  testWidgets('forwards text changes and accepts keyboard focus', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    String? value;

    await tester.pumpWidget(
      _TestApp(
        child: CoeloSearchField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (nextValue) => value = nextValue,
          semanticLabel: 'Buscar',
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Coelo');

    expect(focusNode.hasFocus, isTrue);
    expect(value, 'Coelo');
  });

  testWidgets('disables text input when enabled is false', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var changes = 0;

    await tester.pumpWidget(
      _TestApp(
        child: CoeloSearchField(
          controller: controller,
          onChanged: (_) => changes++,
          semanticLabel: 'Buscar',
          enabled: false,
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.enabled, isFalse);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'ignorado');
    expect(changes, 0);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child, this.theme});

  final Widget child;
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: theme ?? CoeloTheme.light,
      home: Scaffold(
        body: Center(child: SizedBox(width: 300, child: child)),
      ),
    );
  }
}
