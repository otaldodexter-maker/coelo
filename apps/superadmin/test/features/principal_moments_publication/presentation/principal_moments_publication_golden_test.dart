import 'dart:ui' show PointerDeviceKind;
import 'dart:io';

import 'package:coelo_superadmin/features/principal_moments_publication/presentation/principal_moments_publication_page.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/application/moments_publication_controller.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/domain/moments_publication.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  final cases = <({String name, Size size, ThemeData theme, double textScale})>[
    (name: 'light_375', size: const Size(375, 900), theme: CoeloTheme.light, textScale: 1),
    (name: 'dark_375', size: const Size(375, 900), theme: CoeloTheme.dark, textScale: 1),
    (name: 'light_768', size: const Size(768, 1024), theme: CoeloTheme.light, textScale: 1),
    (name: 'dark_768', size: const Size(768, 1024), theme: CoeloTheme.dark, textScale: 1),
    (name: 'light_1024', size: const Size(1024, 1000), theme: CoeloTheme.light, textScale: 1),
    (name: 'dark_1024', size: const Size(1024, 1000), theme: CoeloTheme.dark, textScale: 1),
    (name: 'light_1440', size: const Size(1440, 1000), theme: CoeloTheme.light, textScale: 1),
    (name: 'dark_1440', size: const Size(1440, 1000), theme: CoeloTheme.dark, textScale: 1),
    (name: 'light_375_200', size: const Size(375, 900), theme: CoeloTheme.light, textScale: 2),
    (name: 'dark_1440_200', size: const Size(1440, 1000), theme: CoeloTheme.dark, textScale: 2),
  ];

  for (final testCase in cases) {
    testWidgets('matches approved publication composition ${testCase.name}', (tester) async {
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
            child: const PrincipalMomentsPublicationPage.demo(),
          ),
        ),
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
      MaterialApp(theme: CoeloTheme.light, home: const PrincipalMomentsPublicationPage.demo()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-publication-continue')));
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

  testWidgets('matches persisted Momentos media without distortion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final data = await rootBundle.load('assets/principal_profile/institution-cover.png');
    final bytes = data.buffer.asUint8List();
    final media = MomentsMediaDraft.local(
      localId: 'persisted',
      name: 'momento.png',
      mimeType: 'image/png',
      bytes: bytes,
    );
    final controller = MomentsPublicationController(
      repository: InMemoryMomentsPublicationRepository(draft: MomentsDraft(media: [media])),
      context: MomentsPublicationContext.demo,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1440, 1000), disableAnimations: true),
          child: PrincipalMomentsPublicationPage(controller: controller),
        ),
      ),
    );
    final context = tester.element(find.byType(PrincipalMomentsPublicationPage));
    await tester.runAsync(() => precacheImage(MemoryImage(media.bytes), context));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PrincipalMomentsPublicationPage),
      matchesGoldenFile('goldens/principal_moments_publication_persisted_media_light_1440.png'),
    );
  });

  testWidgets('matches honest empty productive Momentos state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = MomentsPublicationController(
      repository: InMemoryMomentsPublicationRepository(draft: MomentsDraft()),
      context: MomentsPublicationContext.demo,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalMomentsPublicationPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PrincipalMomentsPublicationPage),
      matchesGoldenFile('goldens/principal_moments_publication_empty_light_1440.png'),
    );
  });

  testWidgets('matches Momentos recoverable failure state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = MomentsPublicationController(
      repository: _FailingMomentsGoldenRepository(),
      context: MomentsPublicationContext.demo,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalMomentsPublicationPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PrincipalMomentsPublicationPage),
      matchesGoldenFile('goldens/principal_moments_publication_failure_light_1440.png'),
    );
  });
}

final class _FailingMomentsGoldenRepository implements MomentsPublicationRepository {
  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) async =>
      throw Exception('load failed');

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) async =>
      draft;

  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) async =>
      const MomentsPublication(id: 'unused', status: MomentsStatus.published);
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
