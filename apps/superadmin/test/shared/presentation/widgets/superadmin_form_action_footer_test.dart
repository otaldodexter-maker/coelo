import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps tertiary left and continuation right on wide layouts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());

    final footer = tester.getRect(find.byKey(const Key('form-footer-surface')));
    final cancel = tester.getRect(find.byKey(const Key('cancel')));
    final continueAction = tester.getRect(find.byKey(const Key('continue')));
    final save = tester.getRect(find.byKey(const Key('save')));
    expect(cancel.left, closeTo(footer.left + CoeloSpacing.space3, 1));
    expect(save.right, closeTo(footer.right - CoeloSpacing.space3, 1));
    expect(cancel.right, lessThan(continueAction.left));
    expect(continueAction.right, lessThan(save.left));
    expect(find.widgetWithText(TextButton, 'Cancelar'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Continuar'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Salvar alterações'), findsOneWidget);
  });

  testWidgets('stacks full-width actions with primary first when compact', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());

    final saveRect = tester.getRect(find.byKey(const Key('save')));
    final previousRect = tester.getRect(find.byKey(const Key('continue')));
    final cancelRect = tester.getRect(find.byKey(const Key('cancel')));
    expect(saveRect.top, lessThan(previousRect.top));
    expect(previousRect.top, lessThan(cancelRect.top));
    expect(saveRect.width, closeTo(previousRect.width, 1));
    expect(previousRect.width, closeTo(cancelRect.width, 1));
  });

  testWidgets('stacks actions when text is amplified even with wide space', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(),
      ),
    );

    final saveRect = tester.getRect(find.byKey(const Key('save')));
    final continueRect = tester.getRect(find.byKey(const Key('continue')));
    final cancelRect = tester.getRect(find.byKey(const Key('cancel')));
    expect(saveRect.top, lessThan(continueRect.top));
    expect(continueRect.top, lessThan(cancelRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses semantic glass and reports height changes', (tester) async {
    double? height;
    await tester.pumpWidget(_app(onHeightChanged: (value) => height = value));
    await tester.pump();

    final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(filter.filter.toString(), contains('${CoeloSpacing.space3}'));
    final surface = tester.widget<Container>(find.byKey(const Key('form-footer-surface')));
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.color, CoeloTheme.light.colorScheme.surface.withValues(alpha: 0.84));
    expect(height, greaterThan(0));
  });
}

Widget _app({ValueChanged<double>? onHeightChanged}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: SuperadminFormActionFooter(
          surfaceKey: const Key('form-footer-surface'),
          onHeightChanged: onHeightChanged,
          tertiaryAction: TextButton(
            key: const Key('cancel'),
            onPressed: () {},
            child: const Text('Cancelar'),
          ),
          continuationActions: [
            OutlinedButton(
              key: const Key('continue'),
              onPressed: () {},
              child: const Text('Continuar'),
            ),
            FilledButton(
              key: const Key('save'),
              onPressed: () {},
              child: const Text('Salvar alterações'),
            ),
          ],
        ),
      ),
    ),
  );
}
