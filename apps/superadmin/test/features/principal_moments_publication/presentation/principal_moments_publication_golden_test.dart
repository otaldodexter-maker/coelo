import 'dart:ui' show PointerDeviceKind;
import 'dart:io';

import 'package:coelo_superadmin/features/principal_moments_publication/presentation/principal_moments_publication_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  final cases = <({String name, Size size, ThemeData theme})>[
    (name: 'light_375', size: const Size(375, 900), theme: CoeloTheme.light),
    (name: 'light_768', size: const Size(768, 1024), theme: CoeloTheme.light),
    (name: 'light_1440', size: const Size(1440, 1000), theme: CoeloTheme.light),
    (name: 'dark_1440', size: const Size(1440, 1000), theme: CoeloTheme.dark),
  ];

  for (final testCase in cases) {
    testWidgets('matches approved publication composition ${testCase.name}', (tester) async {
      await tester.binding.setSurfaceSize(testCase.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(theme: testCase.theme, home: const PrincipalMomentsPublicationPage()),
      );
      final context = tester.element(find.byType(PrincipalMomentsPublicationPage));
      await tester.runAsync(
        () =>
            precacheImage(const AssetImage('assets/principal_moments/moments-strip.png'), context),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PrincipalMomentsPublicationPage),
        matchesGoldenFile('goldens/principal_moments_publication_${testCase.name}.png'),
      );
    });
  }

  testWidgets('matches the approved orange context hover', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: CoeloTheme.light, home: const PrincipalMomentsPublicationPage()),
    );
    await tester.pumpAndSettle();

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(tester.getCenter(find.byKey(const Key('moments-publication-context'))));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PrincipalMomentsPublicationPage),
      matchesGoldenFile('goldens/principal_moments_publication_context_hover_light_1440.png'),
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
