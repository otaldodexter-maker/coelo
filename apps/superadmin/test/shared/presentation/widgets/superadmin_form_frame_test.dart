import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';

void main() {
  testWidgets('keeps a 248 px rail at 768 and 1024 with the canonical gap', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in [768.0, 1024.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(_app(width));

      final rail = tester.getRect(find.byKey(const Key('test-form-rail')));
      final body = tester.getRect(find.byKey(const Key('test-form-body')));
      expect(rail.width, 248, reason: 'viewport $width');
      expect(rail.left, CoeloSpacing.space6, reason: 'medium inset at $width');
      expect(body.left - rail.right, CoeloSpacing.space6, reason: 'viewport $width');
    }
  });

  testWidgets('uses the compact summary below 768 without reserving a rail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(375));

    final navigation = tester.getRect(find.byKey(const Key('test-form-rail')));
    final body = tester.getRect(find.byKey(const Key('test-form-body')));
    expect(navigation.width, body.width);
    expect(navigation.left, CoeloSpacing.space4);
    expect(navigation.bottom, lessThanOrEqualTo(body.top));
  });

  testWidgets('centers editable content at a maximum width of 880', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(1440));

    expect(tester.getSize(find.byKey(const Key('test-form-body'))).width, 880);
    expect(tester.getRect(find.byKey(const Key('test-form-rail'))).left, CoeloSpacing.space10);
  });

  testWidgets('keeps the rail at 768 even under narrower local constraints', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 620, height: 800, child: _app(768)),
      ),
    );

    final navigation = tester.getRect(find.byKey(const Key('test-form-rail')));
    final body = tester.getRect(find.byKey(const Key('test-form-body')));
    expect(navigation.width, 248);
    expect(body.left - navigation.right, CoeloSpacing.space6);
  });
}

Widget _app(double width) => MaterialApp(
  theme: CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(size: Size(width, 800)),
    child: child!,
  ),
  home: Scaffold(
    body: SuperadminFormFrame(
      viewportWidth: width,
      navigation: const ColoredBox(
        key: Key('test-form-rail'),
        color: Colors.orange,
        child: SizedBox(width: 248, height: 120),
      ),
      body: const ColoredBox(
        key: Key('test-form-body'),
        color: Colors.white,
        child: SizedBox(width: double.infinity, height: 120),
      ),
      footer: const SizedBox(key: Key('test-form-footer'), height: 64),
    ),
  ),
);
