import 'dart:io';

import 'package:coelo_superadmin/features/principal_happens_publication/domain/happens_publication.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/presentation/principal_happens_publication_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);
  final cases = <({String name, Size size, ThemeData theme, double textScale})>[
    (name: 'light_375', size: const Size(375, 1200), theme: CoeloTheme.light, textScale: 1),
    (name: 'dark_375', size: const Size(375, 1200), theme: CoeloTheme.dark, textScale: 1),
    (name: 'light_768', size: const Size(768, 1100), theme: CoeloTheme.light, textScale: 1),
    (name: 'dark_768', size: const Size(768, 1100), theme: CoeloTheme.dark, textScale: 1),
    (name: 'light_1024', size: const Size(1024, 1000), theme: CoeloTheme.light, textScale: 1),
    (name: 'dark_1024', size: const Size(1024, 1000), theme: CoeloTheme.dark, textScale: 1),
    (name: 'light_1440', size: const Size(1440, 1000), theme: CoeloTheme.light, textScale: 1),
    (name: 'dark_1440', size: const Size(1440, 1000), theme: CoeloTheme.dark, textScale: 1),
    (name: 'light_375_200', size: const Size(375, 1200), theme: CoeloTheme.light, textScale: 2),
    (name: 'dark_1440_200', size: const Size(1440, 1000), theme: CoeloTheme.dark, textScale: 2),
  ];

  for (final testCase in cases) {
    testWidgets('matches publication composition ${testCase.name}', (tester) async {
      await tester.binding.setSurfaceSize(testCase.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme,
          home: MediaQuery(
            data: MediaQueryData(
              size: testCase.size,
              textScaler: TextScaler.linear(testCase.textScale),
              disableAnimations: true,
            ),
            child: PrincipalHappensPublicationPage.demo(
              repository: InMemoryHappensPublicationRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PrincipalHappensPublicationPage),
        matchesGoldenFile('goldens/principal_happens_publication_${testCase.name}.png'),
      );
    });
  }

  testWidgets('matches persisted Acontece media without distortion', (tester) async {
    const size = Size(1440, 1000);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final data = await rootBundle.load('assets/principal_profile/institution-cover.png');
    final bytes = data.buffer.asUint8List();
    final media = HappensMediaDraft(
      localId: 'persisted',
      name: 'acontece.png',
      mimeType: 'image/png',
      bytes: bytes,
      assetId: 'persisted-asset',
      objectKey: 'private/acontece.png',
    );
    final repository = InMemoryHappensPublicationRepository()
      ..savedDraft = HappensPostDraft(media: [media]);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPublicationPage.demo(repository: repository),
      ),
    );
    final context = tester.element(find.byType(PrincipalHappensPublicationPage));
    await tester.runAsync(() => precacheImage(MemoryImage(media.bytes), context));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PrincipalHappensPublicationPage),
      matchesGoldenFile('goldens/principal_happens_publication_persisted_media_light_1440.png'),
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
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(materialIcons)))).load();
}
