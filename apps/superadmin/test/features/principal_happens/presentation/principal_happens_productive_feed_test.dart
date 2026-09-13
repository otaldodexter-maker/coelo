import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scope = PrincipalHappensFeedScope(institutionId: 'institution-1');

  Future<void> pumpFeed(WidgetTester tester, PrincipalHappensFeedRepository repository) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPreviewPage(feedRepository: repository, feedScope: scope),
      ),
    );
  }

  for (final change in ['expiry', 'context', 'dispose']) {
    testWidgets('resolved image and decoded cache are removed on $change', (tester) async {
      const provider = NetworkImage('https://coelo.invalid/synthetic-cache-ticket');
      final decoded = await tester.runAsync(() async {
        final result = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          Uint8List.fromList(List.filled(64, 255)),
          4,
          4,
          ui.PixelFormat.rgba8888,
          result.complete,
        );
        return result.future;
      });
      PaintingBinding.instance.imageCache.putIfAbsent(
        provider,
        () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: decoded!))),
      );
      final repository = _FeedRepository(
        () async => [_galleryPost],
        resolve: (_) async => const PrincipalHappensMediaRead(
          signedUrl: 'https://coelo.invalid/synthetic-cache-ticket',
          mimeType: 'image/png',
          expiresIn: Duration(seconds: 60),
        ),
      );
      await pumpFeed(tester, repository);
      await tester.pumpAndSettle();
      final image = find.byWidgetPredicate((widget) => widget is Image && widget.image == provider);
      expect(image, findsOneWidget);
      expect(PaintingBinding.instance.imageCache.statusForKey(provider).keepAlive, isTrue);
      if (change == 'expiry') {
        await tester.pump(const Duration(seconds: 61));
      } else if (change == 'context') {
        await pumpFeed(tester, _FeedRepository(() async => []));
      } else {
        await tester.pumpWidget(const SizedBox.shrink());
      }
      await tester.pumpAndSettle();
      expect(image, findsNothing);
      final cached = PaintingBinding.instance.imageCache.statusForKey(provider);
      expect(cached.pending, isFalse);
      expect(cached.keepAlive, isFalse);
      expect(cached.live, isFalse);
      expect(repository.resolvedTickets, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('disposing feed removes only its gallery below another route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final navigator = GlobalKey<NavigatorState>();
    final repository = _FeedRepository(
      () async => [_galleryPost],
      resolve: (media) async => _videoRead(media),
    );
    Widget host(bool active) => MaterialApp(
      navigatorKey: navigator,
      theme: CoeloTheme.light,
      home: active
          ? PrincipalHappensPreviewPage(feedRepository: repository, feedScope: scope)
          : const Scaffold(body: Text('Origem')),
    );
    await tester.pumpWidget(host(true));
    await tester.pumpAndSettle();
    final media = find.byKey(const Key('principal-happens-media-post-0'));
    await tester.ensureVisible(media);
    await tester.tap(media);
    await tester.pumpAndSettle();
    unawaited(
      navigator.currentState!.push(
        DialogRoute<void>(
          context: navigator.currentContext!,
          builder: (_) => const Dialog(child: Text('Outra rota')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(false));
    await tester.pumpAndSettle();
    expect(find.text('Outra rota'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Origem'), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-gallery')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('context swap closes gallery and rejects its pending media result', (tester) async {
    final pending = Completer<PrincipalHappensMediaRead>();
    var reads = 0;
    final first = _FeedRepository(
      () async => [_galleryPost],
      resolve: (media) {
        reads++;
        return reads == 1 ? Future.value(_videoRead(media)) : pending.future;
      },
    );
    await pumpFeed(tester, first);
    await tester.pumpAndSettle();
    final media = find.byKey(const Key('principal-happens-media-post-0'));
    await tester.ensureVisible(media);
    await tester.tap(media);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(reads, 2);
    await pumpFeed(tester, _FeedRepository(() async => const []));
    await tester.pump();
    pending.complete(
      const PrincipalHappensMediaRead(
        signedUrl: 'https://coelo.invalid/obsolete-gallery-image',
        mimeType: 'image/png',
        expiresIn: Duration(seconds: 60),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-happens-gallery')), findsNothing);
    expect(find.text('Nenhuma publicação neste contexto'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url == 'https://coelo.invalid/obsolete-gallery-image',
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('context swap before gallery build does not redeem old media again', (tester) async {
    final first = _FeedRepository(
      () async => [_galleryPost],
      resolve: (media) async => _videoRead(media),
    );
    await pumpFeed(tester, first);
    await tester.pumpAndSettle();
    final media = find.byKey(const Key('principal-happens-media-post-0'));
    await tester.ensureVisible(media);
    await tester.tap(media);
    await pumpFeed(tester, _FeedRepository(() async => const []));
    await tester.pumpAndSettle();
    expect(first.resolvedTickets, hasLength(1));
    expect(find.byKey(const Key('principal-happens-gallery')), findsNothing);
  });

  testWidgets('keeps Agora visible while the productive feed loads', (tester) async {
    final completer = Completer<List<PrincipalPostPreviewItem>>();
    await pumpFeed(tester, _FeedRepository(() => completer.future));
    await tester.pump();

    expect(find.text('Agora'), findsWidgets);
    expect(find.byKey(const Key('principal-happens-now-card')), findsOneWidget);
    expect(find.byKey(const Key('principal-global-publish-now-label')), findsOneWidget);
    expect(find.text('Carregando publicações'), findsOneWidget);

    completer.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma publicação neste contexto'), findsOneWidget);
  });

  testWidgets('renders posts returned by the injected feed repository', (tester) async {
    await pumpFeed(
      tester,
      _FeedRepository(
        () async => const [
          PrincipalPostPreviewItem(
            author: 'Equipe Coelo',
            context: 'Colégio Horizonte',
            time: 'Agora',
            initials: 'EC',
            body: 'Publicação carregada do contexto autorizado.',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Publicação carregada do contexto autorizado.'), findsOneWidget);
    expect(find.text(PrincipalHappensPreviewData.demo.posts.first.body), findsNothing);
    expect(find.text('Publicado para a comunidade escolar'), findsNothing);
    expect(find.text('null'), findsNothing);
  });

  testWidgets('resolves an opaque media ticket only when the post media is built', (tester) async {
    const media = PrincipalHappensMediaDescriptor(
      readTicket: 'ticket-1',
      mimeType: 'image/jpeg',
      displayOrder: 0,
    );
    final repository = _FeedRepository(
      () async => const [
        PrincipalPostPreviewItem(
          author: 'Equipe Coelo',
          context: 'Colégio Horizonte',
          time: 'Agora',
          initials: 'EC',
          body: 'Registro autorizado.',
          media: [media],
        ),
      ],
    );
    await pumpFeed(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.resolvedTickets, ['ticket-1']);
  });

  testWidgets('offers retry after a transient feed error', (tester) async {
    var attempts = 0;
    await pumpFeed(
      tester,
      _FeedRepository(() async {
        attempts++;
        if (attempts == 1) throw const PrincipalHappensFeedUnavailable();
        return const [];
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar o Acontece'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Nenhuma publicação neste contexto'), findsOneWidget);
  });

  testWidgets('reloads the feed to obtain a fresh ticket after media read failure', (tester) async {
    var loads = 0;
    var reads = 0;
    final repository = _FeedRepository(
      () async {
        loads++;
        return [
          PrincipalPostPreviewItem(
            author: 'Equipe Coelo',
            context: 'Colégio Horizonte',
            time: 'Agora',
            initials: 'EC',
            body: 'Registro autorizado.',
            media: [
              PrincipalHappensMediaDescriptor(
                readTicket: 'ticket-$loads',
                mimeType: 'image/jpeg',
                displayOrder: 0,
              ),
            ],
          ),
        ];
      },
      resolve: (media) async {
        reads++;
        if (reads == 1) throw const PrincipalHappensFeedUnavailable();
        return PrincipalHappensMediaRead(
          signedUrl: 'https://coelo.invalid/${media.readTicket}',
          mimeType: media.mimeType,
          expiresIn: const Duration(seconds: 60),
        );
      },
    );
    await pumpFeed(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tentar carregar a mídia novamente'));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(repository.resolvedTickets, ['ticket-1', 'ticket-2']);
  });
}

const _galleryPost = PrincipalPostPreviewItem(
  author: 'Equipe A',
  context: 'Contexto A',
  time: 'Agora',
  initials: 'EA',
  body: 'Registro A',
  media: [
    PrincipalHappensMediaDescriptor(readTicket: 'ticket-a', mimeType: 'video/mp4', displayOrder: 0),
  ],
);

PrincipalHappensMediaRead _videoRead(PrincipalHappensMediaDescriptor media) =>
    PrincipalHappensMediaRead(
      signedUrl: 'https://coelo.invalid/${media.readTicket}',
      mimeType: media.mimeType,
      expiresIn: const Duration(seconds: 60),
    );

final class _FeedRepository implements PrincipalHappensFeedRepository {
  _FeedRepository(this.load, {this.resolve});

  final Future<List<PrincipalPostPreviewItem>> Function() load;
  final Future<PrincipalHappensMediaRead> Function(PrincipalHappensMediaDescriptor media)? resolve;
  final List<String> resolvedTickets = [];

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) =>
      load();

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) async {
    resolvedTickets.add(media.readTicket);
    if (resolve case final resolver?) return resolver(media);
    return PrincipalHappensMediaRead(
      signedUrl: 'https://coelo.invalid/${media.readTicket}',
      mimeType: media.mimeType,
      expiresIn: const Duration(seconds: 60),
    );
  }
}
