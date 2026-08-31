import 'dart:io';
import 'dart:ui';

import 'package:coelo_superadmin/features/principal_now/presentation/principal_now_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  final cases = <({String name, Size size, ThemeData theme})>[
    (name: 'mobile_light_375', size: const Size(375, 900), theme: CoeloTheme.light),
    (name: 'mobile_dark_375', size: const Size(375, 900), theme: CoeloTheme.dark),
    (name: 'tablet_light_768', size: const Size(768, 1024), theme: CoeloTheme.light),
    (name: 'tablet_dark_768', size: const Size(768, 1024), theme: CoeloTheme.dark),
    (name: 'tablet_light_1024', size: const Size(1024, 900), theme: CoeloTheme.light),
    (name: 'tablet_dark_1024', size: const Size(1024, 900), theme: CoeloTheme.dark),
    (name: 'desktop_light_1440', size: const Size(1440, 1000), theme: CoeloTheme.light),
    (name: 'desktop_dark_1440', size: const Size(1440, 1000), theme: CoeloTheme.dark),
  ];

  for (final testCase in cases) {
    testWidgets('matches canonical Agora composition ${testCase.name}', (tester) async {
      await tester.binding.setSurfaceSize(testCase.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(theme: testCase.theme, home: const PrincipalNowPreviewPage()),
      );
      await _precacheStoryImage(tester);
      await tester.pump(const Duration(milliseconds: 900));

      await expectLater(
        find.byType(PrincipalNowPreviewPage),
        matchesGoldenFile('goldens/principal_now_${testCase.name}.png'),
      );
    });
  }

  testWidgets('matches Agora at 200 percent text with reduced motion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2), disableAnimations: true),
          child: child!,
        ),
        home: const PrincipalNowPreviewPage(),
      ),
    );
    await _precacheStoryImage(tester);
    await tester.pump();
    await expectLater(
      find.byType(PrincipalNowPreviewPage),
      matchesGoldenFile('goldens/principal_now_mobile_dark_375_text_200.png'),
    );
  });

  final enlargedCases = <({String name, Size size, ThemeData theme})>[
    (name: 'mobile_light_375_text_200', size: const Size(375, 1000), theme: CoeloTheme.light),
    (name: 'desktop_dark_1440_text_200', size: const Size(1440, 1100), theme: CoeloTheme.dark),
  ];

  for (final testCase in enlargedCases) {
    testWidgets('matches canonical Agora enlarged text ${testCase.name}', (tester) async {
      await tester.binding.setSurfaceSize(testCase.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: testCase.size,
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const PrincipalNowPreviewPage(),
        ),
      );
      await _precacheStoryImage(tester);
      await tester.pump();

      await expectLater(
        find.byType(PrincipalNowPreviewPage),
        matchesGoldenFile('goldens/principal_now_${testCase.name}.png'),
      );
    });
  }

  testWidgets('matches focused private reply with partial progress', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: CoeloTheme.dark, home: const PrincipalNowPreviewPage()),
    );
    await _precacheStoryImage(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const Key('principal-now-reply-field')));
    await tester.enterText(
      find.byKey(const Key('principal-now-reply-field')),
      'Que registro especial!',
    );
    await tester.pump();

    await expectLater(
      find.byType(PrincipalNowPreviewPage),
      matchesGoldenFile('goldens/principal_now_reply_focused_375.png'),
    );
  });

  testWidgets('matches desktop neighboring preview hover', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: CoeloTheme.dark, home: const PrincipalNowPreviewPage()),
    );
    await _precacheStoryImage(tester);
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-now-next-zone')));
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('principal-now-previous-preview'))));
    await tester.pump(CoeloMotion.fast);

    await expectLater(
      find.byType(PrincipalNowPreviewPage),
      matchesGoldenFile('goldens/principal_now_preview_hover_1440.png'),
    );
  });
}

Future<void> _precacheStoryImage(WidgetTester tester) async {
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage('assets/principal_now/story-strip.png'),
      tester.element(find.byType(PrincipalNowPreviewPage)),
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
