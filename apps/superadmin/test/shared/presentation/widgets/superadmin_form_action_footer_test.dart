import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps tertiary left and continuation right on wide layouts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());

    final cancel = tester.getCenter(find.byKey(const Key('cancel'))).dx;
    final previous = tester.getCenter(find.byKey(const Key('previous'))).dx;
    final save = tester.getCenter(find.byKey(const Key('save'))).dx;
    expect(cancel, lessThan(previous));
    expect(previous, lessThan(save));
  });

  testWidgets('stacks full-width actions with primary first when compact', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());

    final saveRect = tester.getRect(find.byKey(const Key('save')));
    final previousRect = tester.getRect(find.byKey(const Key('previous')));
    final cancelRect = tester.getRect(find.byKey(const Key('cancel')));
    expect(saveRect.top, lessThan(previousRect.top));
    expect(previousRect.top, lessThan(cancelRect.top));
    expect(saveRect.width, closeTo(previousRect.width, 1));
    expect(previousRect.width, closeTo(cancelRect.width, 1));
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
              key: const Key('previous'),
              onPressed: () {},
              child: const Text('Anterior'),
            ),
            FilledButton(key: const Key('save'), onPressed: () {}, child: const Text('Salvar')),
          ],
        ),
      ),
    ),
  );
}
