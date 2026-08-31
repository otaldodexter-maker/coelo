import 'dart:io';

import 'package:coelo_superadmin/features/principal_for_you/presentation/principal_for_you_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);
  final cases = <({String name, Size size, ThemeData theme})>[
    (name: 'light_375', size: const Size(375, 900), theme: CoeloTheme.light),
    (name: 'light_768', size: const Size(768, 1024), theme: CoeloTheme.light),
    (name: 'light_1024', size: const Size(1024, 1000), theme: CoeloTheme.light),
    (name: 'light_1440', size: const Size(1440, 1000), theme: CoeloTheme.light),
    (name: 'dark_375', size: const Size(375, 900), theme: CoeloTheme.dark),
    (name: 'dark_768', size: const Size(768, 1024), theme: CoeloTheme.dark),
    (name: 'dark_1024', size: const Size(1024, 1000), theme: CoeloTheme.dark),
    (name: 'dark_1440', size: const Size(1440, 1000), theme: CoeloTheme.dark),
  ];

  for (final testCase in cases) {
    testWidgets('matches Para você ${testCase.name}', (tester) async {
      await tester.binding.setSurfaceSize(testCase.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: testCase.theme,
          home: const PrincipalForYouPreviewPage(),
        ),
      );
      await _precacheFixtures(tester);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PrincipalForYouPreviewPage),
        matchesGoldenFile('goldens/principal_for_you_${testCase.name}.png'),
      );
    });
  }

  for (final testCase in [
    (name: 'text_200_light_375', size: const Size(375, 1100), theme: CoeloTheme.light),
    (name: 'text_200_light_768', size: const Size(768, 1100), theme: CoeloTheme.light),
    (name: 'text_200_dark_1440', size: const Size(1440, 1200), theme: CoeloTheme.dark),
  ]) {
    testWidgets('matches Para você ${testCase.name}', (tester) async {
      await tester.binding.setSurfaceSize(testCase.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: testCase.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2), disableAnimations: true),
            child: child!,
          ),
          home: const PrincipalForYouPreviewPage(),
        ),
      );
      await _precacheFixtures(tester);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PrincipalForYouPreviewPage),
        matchesGoldenFile('goldens/principal_for_you_${testCase.name}.png'),
      );
    });
  }

  testWidgets('matches the open context selector', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: CoeloTheme.light,
        home: const PrincipalForYouPreviewPage(),
      ),
    );
    await _precacheFixtures(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-for-you-context-trigger')).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/principal_for_you_context_open_light_768.png'),
    );
  });

  testWidgets('matches the canonical shortcut hover state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: CoeloTheme.light,
        home: const PrincipalForYouPreviewPage(),
      ),
    );
    await _precacheFixtures(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('principal-for-you-shortcut-agenda'))),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PrincipalForYouPreviewPage),
      matchesGoldenFile('goldens/principal_for_you_shortcut_hover_light_1440.png'),
    );
  });
}

Future<void> _precacheFixtures(WidgetTester tester) async {
  final context = tester.element(find.byType(PrincipalForYouPreviewPage));
  for (final asset in const [
    'assets/principal_happens/now-strip.png',
    'assets/principal_happens/feed-strip.png',
    'assets/principal_profile/highlights-strip.png',
  ]) {
    await tester.runAsync(() => precacheImage(AssetImage(asset), context));
  }
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
