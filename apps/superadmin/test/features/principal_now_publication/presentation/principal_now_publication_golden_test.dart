import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:coelo_superadmin/features/principal_now_publication/presentation/principal_now_publication_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <({String name, Size size, ThemeData theme})>[
    (name: 'light_375', size: const Size(375, 900), theme: CoeloTheme.light),
    (name: 'dark_375', size: const Size(375, 900), theme: CoeloTheme.dark),
    (name: 'light_768', size: const Size(768, 1024), theme: CoeloTheme.light),
    (name: 'dark_768', size: const Size(768, 1024), theme: CoeloTheme.dark),
    (name: 'light_1440', size: const Size(1440, 1000), theme: CoeloTheme.light),
    (name: 'dark_1440', size: const Size(1440, 1000), theme: CoeloTheme.dark),
  ];

  for (final testCase in cases) {
    testWidgets('matches Agora composer ${testCase.name}', (tester) async {
      await tester.binding.setSurfaceSize(testCase.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = InMemoryNowPublicationRepository()
        ..savedDraft = NowPublicationDraft(
          media: NowMediaDraft.image(
            localId: 'golden',
            name: 'registro.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList([1]),
          ),
          audiences: const {NowAudience.families},
        );
      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme,
          home: PrincipalNowPublicationPage(repository: repository),
        ),
      );
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
    final repository = InMemoryNowPublicationRepository()
      ..savedDraft = NowPublicationDraft(
        media: NowMediaDraft.image(
          localId: 'golden-hover',
          name: 'registro.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList([1]),
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage(repository: repository),
      ),
    );
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
}
