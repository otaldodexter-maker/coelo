import 'dart:ui' show PointerDeviceKind;

import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHappens(
    WidgetTester tester, {
    required Size size,
    VoidCallback? onOpenMoments,
    VoidCallback? onOpenProfile,
    VoidCallback? onOpenAgenda,
    VoidCallback? onOpenNow,
    VoidCallback? onOpenForYou,
    VoidCallback? onCreatePost,
    VoidCallback? onPublishNow,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPreviewPage.demo(
          onOpenMoments: onOpenMoments,
          onOpenProfile: onOpenProfile,
          onOpenAgenda: onOpenAgenda,
          onOpenNow: onOpenNow,
          onOpenForYou: onOpenForYou,
          onCreatePost: onCreatePost,
          onPublishNow: onPublishNow,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders as framed shell content without duplicate chrome', (tester) async {
    await pumpHappens(tester, size: const Size(375, 900));

    expect(find.byKey(const Key('principal-happens-bug')), findsNothing);
    expect(find.byKey(const Key('principal-happens-logo')), findsOneWidget);
    expect(find.byTooltip('Abrir menu'), findsOneWidget);
    expect(find.byTooltip('Notificações'), findsOneWidget);
    expect(find.byTooltip('Abrir perfil'), findsOneWidget);
    expect(find.text('Acontece'), findsOneWidget);
    expect(find.text('Agora'), findsWidgets);
    expect(find.text('Ver tudo'), findsNothing);
    expect(find.byKey(const Key('principal-happens-publish-now-card')), findsOneWidget);
    expect(find.byKey(const Key('principal-global-dock')), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-desktop-rail')), findsNothing);
    expect(find.byKey(const Key('principal-happens-context-column')), findsNothing);

    final like = find.byKey(const Key('principal-happens-like-post-0'));
    await tester.drag(find.byKey(const Key('principal-happens-feed')), const Offset(0, -520));
    await tester.pumpAndSettle();
    await tester.tap(like);
    await tester.pump();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    final save = find.byKey(const Key('principal-happens-save-post-0'));
    await tester.tap(save);
    await tester.pump();
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses callbacks for the sibling surfaces', (tester) async {
    var momentsOpened = false;
    var profileOpened = false;
    var agendaOpened = false;
    var nowOpened = false;
    await pumpHappens(
      tester,
      size: const Size(1440, 1000),
      onOpenMoments: () => momentsOpened = true,
      onOpenProfile: () => profileOpened = true,
      onOpenAgenda: () => agendaOpened = true,
      onOpenNow: () => nowOpened = true,
    );

    await tester.tap(find.byTooltip('Momentos'));
    await tester.tap(find.byTooltip('Abrir perfil'));
    expect(momentsOpened, isTrue);
    expect(profileOpened, isTrue);

    await tester.tap(find.text('Beatriz L.'));
    expect(nowOpened, isTrue);

    await tester.ensureVisible(find.byKey(const Key('principal-happens-open-agenda')));
    await tester.tap(find.byKey(const Key('principal-happens-open-agenda')));
    expect(agendaOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps Agora card hover in the orange Coelo hierarchy', (tester) async {
    await pumpHappens(tester, size: const Size(1440, 1000));

    final card = find.ancestor(of: find.text('Beatriz L.'), matching: find.byType(TextButton));
    final button = tester.widget<TextButton>(card.first);
    final scheme = CoeloTheme.light.colorScheme;

    expect(button.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
    expect(button.style?.side?.resolve({WidgetState.hovered})?.color, scheme.primary);
    expect(button.style?.side?.resolve(<WidgetState>{})?.color, scheme.outlineVariant);
  });

  testWidgets('opens Para você as a sibling surface', (tester) async {
    var forYouOpened = false;
    await pumpHappens(tester, size: const Size(768, 1024), onOpenForYou: () => forYouOpened = true);

    await tester.tap(find.byTooltip('Para você'));
    expect(forYouOpened, isTrue);
  });

  testWidgets('uses the publication CTA inside the framed content', (tester) async {
    var nowCreated = false;
    var happensCreated = false;
    await pumpHappens(
      tester,
      size: const Size(375, 900),
      onCreatePost: () => happensCreated = true,
      onPublishNow: () => nowCreated = true,
    );

    await tester.tap(find.byKey(const Key('principal-happens-publish-now-card')));
    expect(nowCreated, isTrue);
    expect(happensCreated, isFalse);
    await tester.tap(find.byKey(const Key('principal-global-publish-now')));
    expect(nowCreated, isTrue);
    expect(happensCreated, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the dashed publish now card and promotes its action on hover', (tester) async {
    await pumpHappens(tester, size: const Size(1440, 1000));

    final card = find.byKey(const Key('principal-happens-publish-now-card'));
    expect(find.byKey(const Key('principal-happens-publish-now-dashed-border')), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-publish-now-action')), findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(card));
    await tester.pump();

    final action = tester.widget<DecoratedBox>(
      find.byKey(const Key('principal-happens-publish-now-action')),
    );
    expect((action.decoration as BoxDecoration).color, CoeloTheme.light.colorScheme.primary);
  });

  testWidgets('opens post media in an accessible gallery and navigates between items', (
    tester,
  ) async {
    await pumpHappens(tester, size: const Size(375, 900));
    await tester.drag(find.byKey(const Key('principal-happens-feed')), const Offset(0, -430));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('principal-happens-media-post-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-happens-gallery')), findsOneWidget);
    expect(find.text('1 de 3'), findsOneWidget);
    expect(find.byTooltip('Próxima mídia'), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-gallery-compact-return')), findsOneWidget);

    await tester.tap(find.byTooltip('Próxima mídia'));
    await tester.pump();
    expect(find.text('2 de 3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-happens-gallery')), findsNothing);
  });

  testWidgets('opens post media gallery from the keyboard', (tester) async {
    await pumpHappens(tester, size: const Size(375, 900));
    await tester.drag(find.byKey(const Key('principal-happens-feed')), const Offset(0, -430));
    await tester.pumpAndSettle();

    final media = find.byKey(const Key('principal-happens-media-post-0'));
    final gesture = find.descendant(of: media, matching: find.byType(GestureDetector));
    Focus.of(tester.element(gesture)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-happens-gallery')), findsOneWidget);
    expect(find.text('1 de 3'), findsOneWidget);
  });

  testWidgets('gallery supports arrow keys and restores focus after Escape', (tester) async {
    await pumpHappens(tester, size: const Size(375, 900));
    await tester.drag(find.byKey(const Key('principal-happens-feed')), const Offset(0, -430));
    await tester.pumpAndSettle();

    final media = find.byKey(const Key('principal-happens-media-post-0'));
    final gesture = find.descendant(of: media, matching: find.byType(GestureDetector));
    Focus.of(tester.element(gesture)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('2 de 3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('1 de 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-happens-gallery')), findsNothing);
    expect(Focus.of(tester.element(gesture)).hasPrimaryFocus, isTrue);
  });

  testWidgets('gallery is contextual fullscreen on compact and modal on wide layouts', (
    tester,
  ) async {
    await pumpHappens(tester, size: const Size(375, 900));
    await tester.drag(find.byKey(const Key('principal-happens-feed')), const Offset(0, -430));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-happens-media-post-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-happens-gallery-compact-return')), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-gallery-wide-close')), findsNothing);
    await tester.tap(find.byKey(const Key('principal-happens-gallery-compact-return')));
    await tester.pumpAndSettle();

    await pumpHappens(tester, size: const Size(1024, 900));
    await tester.drag(find.byKey(const Key('principal-happens-feed')), const Offset(0, -430));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-happens-media-post-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-happens-gallery-wide-close')), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-gallery-compact-return')), findsNothing);
    final dialog = tester.widget<Dialog>(find.byKey(const Key('principal-happens-gallery')));
    expect(dialog.insetPadding, isNot(EdgeInsets.zero));
  });

  testWidgets('gallery responds to a 375 to 768 resize while it remains open', (tester) async {
    await pumpHappens(tester, size: const Size(375, 900));
    await tester.drag(find.byKey(const Key('principal-happens-feed')), const Offset(0, -430));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-happens-media-post-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-happens-gallery-compact-return')), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-gallery-wide-close')), findsNothing);

    await tester.binding.setSurfaceSize(const Size(768, 900));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-happens-gallery-wide-close')), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-gallery-compact-return')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery explains unavailable video playback and offers a safe return', (
    tester,
  ) async {
    final repository = _VideoRepository();
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPreviewPage(
          feedRepository: repository,
          feedScope: const PrincipalHappensFeedScope(institutionId: 'institution-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('principal-happens-feed')), const Offset(0, -430));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-happens-media-post-0')));
    await tester.pumpAndSettle();

    final gallery = find.byKey(const Key('principal-happens-gallery'));
    expect(
      find.descendant(
        of: gallery,
        matching: find.text('Reprodução de vídeo indisponível nesta prévia.'),
      ),
      findsOneWidget,
    );
    final retry = find.descendant(
      of: gallery,
      matching: find.byKey(const Key('principal-happens-video-unavailable-action')),
    );
    expect(retry, findsOneWidget);
    expect(find.byTooltip('Mídia anterior'), findsNothing);
    expect(find.byTooltip('Próxima mídia'), findsNothing);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-happens-gallery')), findsNothing);
    expect(repository.listCalls, 1);
  });

  testWidgets('reports unavailable gallery actions instead of simulating success', (tester) async {
    await pumpHappens(tester, size: const Size(375, 900));
    await tester.drag(find.byKey(const Key('principal-happens-feed')), const Offset(0, -430));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-happens-media-post-0')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Compartilhar mídia'));
    await tester.pump();
    expect(find.text('Compartilhamento indisponível nesta prévia.'), findsOneWidget);
  });

  testWidgets('keeps tablet anatomy without desktop side columns', (tester) async {
    await pumpHappens(tester, size: const Size(768, 1024));

    expect(find.byKey(const Key('principal-happens-mobile-nav')), findsNothing);
    expect(find.byKey(const Key('principal-happens-desktop-rail')), findsNothing);
    expect(find.byKey(const Key('principal-happens-context-column')), findsNothing);
    expect(find.byKey(const Key('principal-happens-feed')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the desktop feed and context inside the shell content', (tester) async {
    await pumpHappens(tester, size: const Size(1440, 1000));

    expect(find.byKey(const Key('principal-happens-desktop-rail')), findsNothing);
    expect(find.byKey(const Key('principal-happens-feed')), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-context-column')), findsOneWidget);
    expect(find.text('Próximos eventos'), findsOneWidget);
    expect(find.text('Avisos importantes'), findsOneWidget);
    expect(find.text('Aniversariantes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [600.0, 839.0, 840.0, 1024.0]) {
    testWidgets('has no layout exception at ${width.toInt()} px', (tester) async {
      await pumpHappens(tester, size: Size(width, 1000));
      expect(find.byKey(const Key('principal-happens-feed')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('supports 200 percent text and reduced motion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2), disableAnimations: true),
          child: child!,
        ),
        home: const PrincipalHappensPreviewPage.demo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-happens-feed')), findsOneWidget);
    final dockLabels = <Finder>[
      for (final label in const ['Home', 'Para você', 'Momentos', 'Pesquisar'])
        find.descendant(of: find.byTooltip(label), matching: find.text(label)),
      find.byKey(const Key('principal-global-publish-now-label')),
    ];
    for (var index = 0; index < dockLabels.length; index += 1) {
      expect(dockLabels[index], findsOneWidget);
      for (var other = index + 1; other < dockLabels.length; other += 1) {
        expect(
          tester.getRect(dockLabels[index]).overlaps(tester.getRect(dockLabels[other])),
          isFalse,
          reason: 'Rótulos do dock não podem colidir a 375 px com texto a 200%.',
        );
      }
    }
    expect(tester.takeException(), isNull);
  });
}

final class _VideoRepository implements PrincipalHappensFeedRepository {
  var listCalls = 0;

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) async {
    listCalls++;
    return const [
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
  }

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) async =>
      const PrincipalHappensMediaRead(
        signedUrl: 'https://example.test/video.mp4',
        mimeType: 'video/mp4',
        expiresIn: Duration(minutes: 2),
      );
}
