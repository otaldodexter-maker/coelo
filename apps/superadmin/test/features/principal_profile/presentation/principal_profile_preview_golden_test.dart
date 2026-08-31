import 'dart:io';

import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  final cases = <({String name, Size size, ThemeData theme})>[
    (name: 'light_375', size: const Size(375, 1100), theme: CoeloTheme.light),
    (name: 'light_768', size: const Size(768, 1100), theme: CoeloTheme.light),
    (name: 'light_1024', size: const Size(1024, 1100), theme: CoeloTheme.light),
    (name: 'light_1440', size: const Size(1440, 1100), theme: CoeloTheme.light),
    (name: 'dark_375', size: const Size(375, 1100), theme: CoeloTheme.dark),
    (name: 'dark_768', size: const Size(768, 1100), theme: CoeloTheme.dark),
    (name: 'dark_1024', size: const Size(1024, 1100), theme: CoeloTheme.dark),
    (name: 'dark_1440', size: const Size(1440, 1100), theme: CoeloTheme.dark),
  ];

  for (final testCase in cases) {
    testWidgets('matches complete profile ${testCase.name}', (tester) async {
      await _pump(tester, size: testCase.size, theme: testCase.theme);
      await expectLater(
        find.byType(PrincipalProfilePreviewPage),
        matchesGoldenFile('goldens/principal_profile_${testCase.name}.png'),
      );
    });
  }

  for (final testCase in [
    (name: 'text_200_light_375', size: const Size(375, 1200), theme: CoeloTheme.light),
    (name: 'text_200_dark_1440', size: const Size(1440, 1200), theme: CoeloTheme.dark),
  ]) {
    testWidgets('matches complete profile ${testCase.name}', (tester) async {
      await _pump(tester, size: testCase.size, theme: testCase.theme, textScale: 2);
      await expectLater(
        find.byType(PrincipalProfilePreviewPage),
        matchesGoldenFile('goldens/principal_profile_${testCase.name}.png'),
      );
    });
  }

  testWidgets('matches the Acontece editorial feed', (tester) async {
    await _pump(tester, size: const Size(375, 1100), theme: CoeloTheme.light);
    await tester.ensureVisible(find.byKey(const Key('principal-profile-tab-acontece')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PrincipalProfilePreviewPage),
      matchesGoldenFile('goldens/principal_profile_editorial_light_375.png'),
    );
  });

  testWidgets('matches the selected Momentos feed and desktop context', (tester) async {
    await _pump(tester, size: const Size(1440, 1100), theme: CoeloTheme.dark);
    await tester.ensureVisible(find.byKey(const Key('principal-profile-tab-momentos')));
    await tester.tap(find.byKey(const Key('principal-profile-tab-momentos')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PrincipalProfilePreviewPage),
      matchesGoldenFile('goldens/principal_profile_moments_dark_1440.png'),
    );
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required ThemeData theme,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: textScale > 1),
        child: child!,
      ),
      home: PrincipalProfilePreviewPage(onOpenAgenda: () {}),
    ),
  );
  final context = tester.element(find.byType(PrincipalProfilePreviewPage));
  for (final asset in const [
    'assets/principal_profile/institution-cover.png',
    'assets/principal_profile/institution-crest.png',
    'assets/principal_profile/highlights-strip.png',
    'assets/principal_happens/feed-strip.png',
    'assets/principal_moments/moments-strip.png',
  ]) {
    await tester.runAsync(() => precacheImage(AssetImage(asset), context));
  }
  await tester.pumpAndSettle();
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
