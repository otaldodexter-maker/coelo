import 'dart:io';

import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:coelo_superadmin/features/principal_now_publication/presentation/principal_now_publication_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
    testWidgets('matches Agora composer ${testCase.name}', (tester) async {
      await tester.binding.setSurfaceSize(testCase.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final imageBytes = await _loadNowImageBytes();
      final repository = InMemoryNowPublicationRepository()
        ..savedDraft = NowPublicationDraft(
          media: NowMediaDraft.image(
            localId: 'golden',
            name: 'registro.png',
            mimeType: 'image/png',
            bytes: imageBytes,
          ),
          audiences: const {NowAudience.families},
        );
      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme,
          home: MediaQuery(
            data: MediaQueryData(
              size: testCase.size,
              textScaler: TextScaler.linear(testCase.textScale),
              disableAnimations: true,
            ),
            child: PrincipalNowPublicationPage.demo(repository: repository),
          ),
        ),
      );
      final context = tester.element(find.byType(PrincipalNowPublicationPage));
      await tester.runAsync(() => precacheImage(MemoryImage(imageBytes), context));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PrincipalNowPublicationPage),
        matchesGoldenFile('goldens/principal_now_publication_${testCase.name}.png'),
      );
    });
  }

  testWidgets('matches Agora audience hover', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final imageBytes = await _loadNowImageBytes();
    final repository = InMemoryNowPublicationRepository()
      ..savedDraft = NowPublicationDraft(
        media: NowMediaDraft.image(
          localId: 'golden-hover',
          name: 'registro.png',
          mimeType: 'image/png',
          bytes: imageBytes,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: repository),
      ),
    );
    final context = tester.element(find.byType(PrincipalNowPublicationPage));
    await tester.runAsync(() => precacheImage(MemoryImage(imageBytes), context));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(pointer.removePointer);
    await pointer.addPointer(location: Offset.zero);
    await pointer.moveTo(tester.getCenter(find.byKey(const Key('now-context-surface'))));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PrincipalNowPublicationPage),
      matchesGoldenFile('goldens/principal_now_publication_audience_hover_light_1440.png'),
    );
  });

  testWidgets('matches honest unavailable media without demo fallback', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryNowPublicationRepository()
      ..savedDraft = NowPublicationDraft(
        media: NowMediaDraft.image(
          localId: 'broken-golden',
          name: 'indisponivel.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-media-unavailable')), findsNWidgets(2));
    await expectLater(
      find.byType(PrincipalNowPublicationPage),
      matchesGoldenFile('goldens/principal_now_publication_media_unavailable_light_1440.png'),
    );
  });

  testWidgets('matches Agora recoverable failure state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: _FailingNowGoldenRepository()),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PrincipalNowPublicationPage),
      matchesGoldenFile('goldens/principal_now_publication_failure_light_1440.png'),
    );
  });

  for (final editor in <({String tooltip, String golden})>[
    (tooltip: 'Cortar', golden: 'crop_open_light_1440'),
    (tooltip: 'Capa', golden: 'cover_open_light_1440'),
  ]) {
    testWidgets('matches Agora ${editor.tooltip} editor', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final imageBytes = await _loadNowImageBytes();
      final media = editor.tooltip == 'Capa'
          ? NowMediaDraft.video(
              localId: 'golden-video',
              name: 'registro.mp4',
              mimeType: 'video/mp4',
              bytes: imageBytes,
              duration: const Duration(seconds: 8),
            ).copyWith(coverPosition: .65)
          : NowMediaDraft.image(
              localId: 'golden-crop',
              name: 'registro.png',
              mimeType: 'image/png',
              bytes: imageBytes,
            ).copyWith(cropScale: 1.35, cropX: -.2, cropY: .25);
      final repository = InMemoryNowPublicationRepository()
        ..savedDraft = NowPublicationDraft(media: media);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: CoeloTheme.light,
          home: PrincipalNowPublicationPage.demo(repository: repository),
        ),
      );
      if (!media.isVideo) {
        final context = tester.element(find.byType(PrincipalNowPublicationPage));
        await tester.runAsync(() => precacheImage(MemoryImage(imageBytes), context));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(editor.tooltip));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/principal_now_publication_${editor.golden}.png'),
      );
    });
  }
}

final class _FailingNowGoldenRepository implements NowPublicationRepository {
  @override
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context) async =>
      throw Exception('load failed');

  @override
  Future<NowPublicationDraft> saveDraft(
    NowPublicationContext context,
    NowPublicationDraft draft,
  ) async => draft;

  @override
  Future<NowMediaDraft> uploadMedia(
    NowPublicationContext context,
    String publicationId,
    NowMediaDraft media,
  ) async => media;

  @override
  Future<NowAudioDraft> uploadAudio(
    NowPublicationContext context,
    String publicationId,
    NowAudioDraft audio,
  ) async => audio;

  @override
  Future<NowPublication> publish(NowPublicationContext context, NowPublicationDraft draft) async =>
      const NowPublication(id: 'unused', publishAt: null);
}

Future<Uint8List> _loadNowImageBytes() async {
  final data = await rootBundle.load('assets/principal_now/story-strip.png');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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
