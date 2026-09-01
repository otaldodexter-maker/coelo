import 'dart:async';

import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_preview_data.dart';
import 'package:coelo_superadmin/features/principal_moments/presentation/principal_moments_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpMoments(
    WidgetTester tester, {
    required Size size,
    VoidCallback? onOpenHappens,
    VoidCallback? onOpenProfile,
    VoidCallback? onCreateMoment,
    double textScale = 1,
    bool disableAnimations = false,
    PrincipalMomentsFeedRepository? feedRepository,
    PrincipalMomentsFeedScope? feedScope,
    PrincipalMomentsFeedRefreshSignal? refreshSignal,
    bool settle = true,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: disableAnimations,
            textScaler: TextScaler.linear(textScale),
          ),
          child: PrincipalMomentsPreviewPage(
            onOpenHappens: onOpenHappens,
            onOpenProfile: onOpenProfile,
            onCreateMoment: onCreateMoment,
            feedRepository: feedRepository,
            feedScope: feedScope,
            refreshSignal: refreshSignal,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  const scope = PrincipalMomentsFeedScope(institutionId: 'institution-coelo');

  testWidgets('renders the canonical immersive mobile anatomy and social states', (tester) async {
    await pumpMoments(tester, size: const Size(375, 900));

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('principal-moments-back')), findsOneWidget);
    expect(find.text('Momentos'), findsOneWidget);
    expect(find.byKey(const Key('principal-global-dock')), findsNothing);
    expect(find.byKey(const Key('principal-moments-mobile-nav')), findsNothing);
    expect(find.byKey(const Key('principal-moments-desktop-aside')), findsNothing);

    await tester.tap(find.byKey(const Key('principal-moments-like')));
    await tester.tap(find.byKey(const Key('principal-moments-save')));
    await tester.tap(find.byKey(const Key('principal-moments-mute')));
    await tester.pump();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fills the viewport with cover media at every supported width', (tester) async {
    for (final size in [const Size(375, 900), const Size(768, 1024), const Size(1440, 1000)]) {
      await pumpMoments(tester, size: size);

      expect(
        tester.getRect(find.byKey(const Key('principal-moments-page-view'))),
        Offset.zero & size,
      );
      final media = tester.widget<Image>(find.byType(Image).first);
      expect(media.fit, BoxFit.cover);
      expect(media.alignment, Alignment.topCenter);
      expect(PrincipalMomentsPreviewData.demo.moments.first.caption, endsWith('.'));
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('returns to the Acontece origin from the visible back action', (tester) async {
    var happensOpened = false;
    await pumpMoments(
      tester,
      size: const Size(768, 1024),
      onOpenHappens: () => happensOpened = true,
    );

    await tester.tap(find.byKey(const Key('principal-moments-back')));

    expect(happensOpened, isTrue);
  });

  testWidgets('returns to the Acontece origin with Escape', (tester) async {
    final invoked = <String>[];
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalMomentsPreviewPage(onOpenHappens: () => invoked.add('happens')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(invoked, ['happens']);
  });

  testWidgets('pages vertically through moments', (tester) async {
    await pumpMoments(tester, size: const Size(375, 900));

    expect(find.text('Música que inspira, conexão que transforma.'), findsOneWidget);
    await tester.drag(find.byKey(const Key('principal-moments-page-view')), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Ciência na prática é descoberta que fica para a vida toda.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pages through moments with the keyboard', (tester) async {
    await pumpMoments(tester, size: const Size(768, 1024), disableAnimations: true);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.text('Ciência na prática é descoberta que fica para a vida toda.'), findsOneWidget);
  });

  testWidgets('pages through moments with the mouse wheel', (tester) async {
    await pumpMoments(tester, size: const Size(1440, 1000));

    final pager = find.byKey(const Key('principal-moments-page-view'));
    await tester.sendEventToBinding(
      PointerScrollEvent(position: tester.getCenter(pager), scrollDelta: const Offset(0, 600)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ciência na prática é descoberta que fica para a vida toda.'), findsOneWidget);
  });

  testWidgets('suspends the global navigation while Momentos is open', (tester) async {
    await pumpMoments(tester, size: const Size(1440, 1000));

    expect(find.byKey(const Key('principal-global-dock')), findsNothing);
    expect(find.byKey(const Key('principal-moments-back')), findsOneWidget);
    expect(find.byKey(const Key('principal-moments-desktop-nav')), findsNothing);
  });

  testWidgets('keeps the desktop viewer immersive without a contextual aside', (tester) async {
    await pumpMoments(tester, size: const Size(1440, 1000));

    expect(find.byKey(const Key('principal-moments-mobile-nav')), findsNothing);
    expect(find.byKey(const Key('principal-global-dock')), findsNothing);
    expect(find.byKey(const Key('principal-moments-desktop-nav')), findsNothing);
    expect(find.byKey(const Key('principal-moments-desktop-aside')), findsNothing);
    expect(find.byKey(const Key('principal-moments-create')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded web preview remains an immersive viewer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: CoeloTheme.light, home: const PrincipalMomentsPreviewPage(embedded: true)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('principal-moments-desktop-nav')), findsNothing);
    expect(find.byKey(const Key('principal-moments-mobile-nav')), findsNothing);
    expect(find.byKey(const Key('principal-moments-desktop-aside')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the canonical loading and empty states for an authorized feed', (
    tester,
  ) async {
    final pending = Completer<List<PrincipalMomentPreviewItem>>();
    final repository = _FakeMomentsFeedRepository((_) => pending.future);

    await pumpMoments(
      tester,
      size: const Size(375, 900),
      feedRepository: repository,
      feedScope: scope,
      settle: false,
    );

    expect(find.bySemanticsLabel('Carregando momentos'), findsOneWidget);
    expect(find.byKey(const Key('principal-moments-page-view')), findsNothing);

    pending.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('Nenhum momento por aqui'), findsOneWidget);
    expect(
      find.text('Novos momentos aparecerão quando forem publicados para você.'),
      findsOneWidget,
    );
  });

  testWidgets('keeps unauthorized failures fail-closed and without retry', (tester) async {
    final repository = _FakeMomentsFeedRepository(
      (_) async => throw const PrincipalMomentsFeedUnauthorized(),
    );

    await pumpMoments(
      tester,
      size: const Size(768, 1024),
      feedRepository: repository,
      feedScope: scope,
    );

    expect(find.text('Momentos indisponíveis'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.byKey(const Key('principal-moments-page-view')), findsNothing);
  });

  testWidgets('retries an unavailable feed', (tester) async {
    var attempts = 0;
    final repository = _FakeMomentsFeedRepository((_) async {
      attempts += 1;
      if (attempts == 1) throw const PrincipalMomentsFeedUnavailable();
      return const [_refreshedMoment];
    });

    await pumpMoments(
      tester,
      size: const Size(375, 900),
      feedRepository: repository,
      feedScope: scope,
    );

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text(_refreshedMoment.caption), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('reloads the authorized feed after a publication signal', (tester) async {
    final refreshSignal = PrincipalMomentsFeedRefreshSignal();
    addTearDown(refreshSignal.dispose);
    var loads = 0;
    final repository = _FakeMomentsFeedRepository((_) async {
      loads += 1;
      return loads == 1
          ? [PrincipalMomentsPreviewData.demo.moments.first]
          : const [_refreshedMoment];
    });

    await pumpMoments(
      tester,
      size: const Size(375, 900),
      feedRepository: repository,
      feedScope: scope,
      refreshSignal: refreshSignal,
    );

    refreshSignal.markPublished('moment-confirmed-42');
    await tester.pumpAndSettle();

    expect(find.text(_refreshedMoment.caption), findsOneWidget);
    expect(loads, 2);
    expect(refreshSignal.lastPublishedMomentId, 'moment-confirmed-42');
  });

  testWidgets('fails closed when the repository configuration is incomplete', (tester) async {
    final repository = _FakeMomentsFeedRepository((_) async => const [_refreshedMoment]);

    await pumpMoments(
      tester,
      size: const Size(375, 900),
      feedRepository: repository,
      settle: false,
    );

    expect(find.text('Momentos indisponíveis'), findsOneWidget);
    expect(find.text(PrincipalMomentsPreviewData.demo.moments.first.caption), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ignores a stale load after returning to preview data', (tester) async {
    final pending = Completer<List<PrincipalMomentPreviewItem>>();
    final repository = _FakeMomentsFeedRepository((_) => pending.future);

    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget app({PrincipalMomentsFeedRepository? source}) => MaterialApp(
      theme: CoeloTheme.light,
      home: PrincipalMomentsPreviewPage(
        feedRepository: source,
        feedScope: source == null ? null : scope,
      ),
    );

    await tester.pumpWidget(app(source: repository));
    await tester.pump();
    await tester.pumpWidget(app());
    pending.complete(const [_refreshedMoment]);
    await tester.pumpAndSettle();

    expect(find.text(PrincipalMomentsPreviewData.demo.moments.first.caption), findsOneWidget);
    expect(find.text(_refreshedMoment.caption), findsNothing);
  });

  testWidgets('does not render fixture trending content for a repository feed', (tester) async {
    final repository = _FakeMomentsFeedRepository((_) async => const [_refreshedMoment]);

    await pumpMoments(
      tester,
      size: const Size(1440, 1000),
      feedRepository: repository,
      feedScope: scope,
    );

    expect(find.text('Em alta na escola'), findsNothing);
    expect(find.byKey(const Key('principal-moments-create')), findsNothing);
  });

  for (final width in [375.0, 768.0, 1440.0]) {
    testWidgets('has no overflow at ${width.toInt()} px with enlarged text', (tester) async {
      await pumpMoments(tester, size: Size(width, 1000), textScale: 2);

      expect(find.byKey(const Key('principal-moments-page-view')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

const _refreshedMoment = PrincipalMomentPreviewItem(
  author: 'Colégio Coelo',
  context: 'Projeto de ciências',
  time: 'Agora',
  caption: 'Momento confirmado e recarregado.',
  likes: 0,
  comments: 0,
  shares: 0,
  saves: 0,
  imageIndex: 1,
);

final class _FakeMomentsFeedRepository implements PrincipalMomentsFeedRepository {
  _FakeMomentsFeedRepository(this._load);

  final Future<List<PrincipalMomentPreviewItem>> Function(PrincipalMomentsFeedScope scope) _load;

  @override
  Future<List<PrincipalMomentPreviewItem>> listVisibleMoments(PrincipalMomentsFeedScope scope) =>
      _load(scope);
}
