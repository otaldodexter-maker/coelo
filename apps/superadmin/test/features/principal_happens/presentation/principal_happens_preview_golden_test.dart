import 'dart:io';
import 'dart:ui';

import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);
  final cases = <({String name, Size size, ThemeData theme})>[
    (name: 'light_375', size: const Size(375, 900), theme: CoeloTheme.light),
    (name: 'dark_375', size: const Size(375, 900), theme: CoeloTheme.dark),
    (name: 'light_768', size: const Size(768, 1024), theme: CoeloTheme.light),
    (name: 'dark_768', size: const Size(768, 1024), theme: CoeloTheme.dark),
    (name: 'light_1024', size: const Size(1024, 900), theme: CoeloTheme.light),
    (name: 'dark_1024', size: const Size(1024, 900), theme: CoeloTheme.dark),
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
      await _precacheHappensImages(tester);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PrincipalHappensPreviewPage),
        matchesGoldenFile('goldens/principal_happens_${testCase.name}.png'),
      );
    });
  }

  testWidgets('matches Acontece at 200 percent text with reduced motion', (tester) async {
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
        home: const PrincipalHappensPreviewPage.demo(),
      ),
    );
    await _precacheHappensImages(tester);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PrincipalHappensPreviewPage),
      matchesGoldenFile('goldens/principal_happens_dark_375_text_200.png'),
    );
  });

  for (final testCase in cases) {
    testWidgets('matches approved Acontece gallery ${testCase.name}', (tester) async {
      await tester.binding.setSurfaceSize(testCase.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(theme: testCase.theme, home: const PrincipalHappensPreviewPage.demo()),
      );
      await _openGallery(tester);
      await expectLater(
        find.byKey(const Key('principal-happens-gallery')),
        matchesGoldenFile('goldens/principal_happens_gallery_${testCase.name}.png'),
      );
    });
  }

  testWidgets('matches Acontece gallery at 200 percent text', (tester) async {
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
        home: const PrincipalHappensPreviewPage.demo(),
      ),
    );
    await _openGallery(tester);
    await expectLater(
      find.byKey(const Key('principal-happens-gallery')),
      matchesGoldenFile('goldens/principal_happens_gallery_dark_375_text_200.png'),
    );
  });

  testWidgets('matches the honest unavailable video state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPreviewPage(
          feedRepository: const _VideoGoldenRepository(),
          feedScope: const PrincipalHappensFeedScope(institutionId: 'institution-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('principal-happens-feed')), const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-happens-media-post-0')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('principal-happens-gallery')),
      matchesGoldenFile('goldens/principal_happens_gallery_video_unavailable_light_375.png'),
    );
  });

  testWidgets('matches the approved orange hover for an Agora card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: CoeloTheme.light, home: const PrincipalHappensPreviewPage.demo()),
    );
    await _precacheHappensImages(tester);
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

final class _VideoGoldenRepository implements PrincipalHappensFeedRepository {
  const _VideoGoldenRepository();

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) async =>
      const [
        PrincipalPostPreviewItem(
          author: 'Equipe Coelo',
          context: 'Instituição',
          time: 'Agora',
          initials: 'EC',
          body: 'Registro em vídeo',
          media: [
            PrincipalHappensMediaDescriptor(
              readTicket: 'video-ticket',
              mimeType: 'video/mp4',
              displayOrder: 0,
            ),
          ],
        ),
      ];

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) async =>
      const PrincipalHappensMediaRead(
        signedUrl: 'https://example.test/video.mp4',
        mimeType: 'video/mp4',
        expiresIn: Duration(minutes: 2),
      );
}

Future<void> _openGallery(WidgetTester tester) async {
  await _precacheHappensImages(tester);
  await tester.pumpAndSettle();
  await tester.drag(find.byKey(const Key('principal-happens-feed')), const Offset(0, -420));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('principal-happens-media-post-0')));
  await tester.pumpAndSettle();
}

Future<void> _precacheHappensImages(WidgetTester tester) async {
  final context = tester.element(find.byType(PrincipalHappensPreviewPage));
  await tester.runAsync(() async {
    await Future.wait([
      precacheImage(const AssetImage('assets/principal_happens/now-strip.png'), context),
      precacheImage(const AssetImage('assets/principal_happens/feed-strip.png'), context),
    ]);
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
