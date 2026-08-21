import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <({String name, Size size, ThemeData theme})>[
    (name: 'light_375', size: const Size(375, 900), theme: CoeloTheme.light),
    (name: 'light_768', size: const Size(768, 1024), theme: CoeloTheme.light),
    (name: 'light_1440', size: const Size(1440, 1000), theme: CoeloTheme.light),
    (name: 'dark_1440', size: const Size(1440, 1000), theme: CoeloTheme.dark),
  ];

  for (final testCase in cases) {
    testWidgets('matches canonical Acontece composition ${testCase.name}', (tester) async {
      await tester.binding.setSurfaceSize(testCase.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(theme: testCase.theme, home: const PrincipalHappensPreviewPage.demo()),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PrincipalHappensPreviewPage),
        matchesGoldenFile('goldens/principal_happens_${testCase.name}.png'),
      );
    });
  }

  testWidgets('matches the approved orange hover for an Agora card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: CoeloTheme.light, home: const PrincipalHappensPreviewPage.demo()),
    );
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.text('Beatriz L.')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PrincipalHappensPreviewPage),
      matchesGoldenFile('goldens/principal_happens_now_hover_light_1440.png'),
    );
  });
}
