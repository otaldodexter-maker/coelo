import 'dart:io';
import 'dart:ui';

import 'package:coelo_superadmin/features/principal_moments/presentation/principal_moments_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  final cases = <({String name, Size size, ThemeData theme})>[
    (name: 'light_1440', size: const Size(1440, 1000), theme: CoeloTheme.light),
    (name: 'light_375', size: const Size(375, 900), theme: CoeloTheme.light),
    (name: 'light_768', size: const Size(768, 1024), theme: CoeloTheme.light),
    (name: 'light_1024', size: const Size(1024, 1000), theme: CoeloTheme.light),
    (name: 'dark_375', size: const Size(375, 900), theme: CoeloTheme.dark),
    (name: 'dark_768', size: const Size(768, 1024), theme: CoeloTheme.dark),
    (name: 'dark_1024', size: const Size(1024, 1000), theme: CoeloTheme.dark),
    (name: 'dark_1440', size: const Size(1440, 1000), theme: CoeloTheme.dark),
  ];

  for (final testCase in cases) {
    testWidgets('matches approved Momentos composition ${testCase.name}', (tester) async {
      await tester.binding.setSurfaceSize(testCase.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(theme: testCase.theme, home: const PrincipalMomentsPreviewPage()),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/principal_moments/moments-strip.png'),
          tester.element(find.byType(PrincipalMomentsPreviewPage)),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PrincipalMomentsPreviewPage),
        matchesGoldenFile('goldens/principal_moments_${testCase.name}.png'),
      );
    });
  }

  for (final testCase in [
    (name: 'text_200_light_375', size: const Size(375, 1100), theme: CoeloTheme.light),
    (name: 'text_200_dark_1440', size: const Size(1440, 1200), theme: CoeloTheme.dark),
  ]) {
    testWidgets('matches approved Momentos composition ${testCase.name}', (tester) async {
      await tester.binding.setSurfaceSize(testCase.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2), disableAnimations: true),
            child: child!,
          ),
          home: const PrincipalMomentsPreviewPage(),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/principal_moments/moments-strip.png'),
          tester.element(find.byType(PrincipalMomentsPreviewPage)),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PrincipalMomentsPreviewPage),
        matchesGoldenFile('goldens/principal_moments_${testCase.name}.png'),
      );
    });
  }

  testWidgets('matches the approved Coelo like hover state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: CoeloTheme.light, home: const PrincipalMomentsPreviewPage()),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/principal_moments/moments-strip.png'),
        tester.element(find.byType(PrincipalMomentsPreviewPage)),
      ),
    );
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byTooltip('Curtir')));
    await tester.pump();

    await expectLater(
      find.byType(PrincipalMomentsPreviewPage),
      matchesGoldenFile('goldens/principal_moments_like_hover_light_1440.png'),
    );
  });
}

Future<void> _loadGoldenFonts() async {
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunitoSans.load();
  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await materialIconsLoader.load();
}
