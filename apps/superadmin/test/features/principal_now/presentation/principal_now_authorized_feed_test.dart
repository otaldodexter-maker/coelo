import 'dart:async';

import 'package:coelo_superadmin/features/principal_now/domain/principal_now_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_now/presentation/principal_now_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scope = PrincipalNowFeedScope(institutionId: 'institution-coelo');

  Future<void> pumpAuthorized(
    WidgetTester tester, {
    required PrincipalNowFeedRepository repository,
    PrincipalNowFeedRefreshSignal? refreshSignal,
    VoidCallback? onClose,
    bool settle = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: PrincipalNowPreviewPage.authorized(
            feedRepository: repository,
            feedScope: scope,
            refreshSignal: refreshSignal,
            onClose: onClose,
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

  testWidgets('mostra loading e vazio sem recorrer aos dados demo', (tester) async {
    final pending = Completer<List<PrincipalNowFeedItem>>();
    final repository = _FakeNowFeedRepository(list: (_) => pending.future);
    var closed = false;

    await pumpAuthorized(
      tester,
      repository: repository,
      onClose: () => closed = true,
      settle: false,
    );
    expect(find.bySemanticsLabel('Carregando Agora'), findsOneWidget);
    expect(find.text('Riverside School'), findsNothing);
    expect(find.byKey(const Key('principal-now-close')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closed, isTrue);

    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('Nada novo no Agora'), findsOneWidget);
    expect(find.byKey(const Key('principal-now-story')), findsNothing);
  });

  testWidgets('falha explicitamente quando o modo remoto recebe configuração incompleta', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        home: PrincipalNowPreviewPage(
          feedRepository: _FakeNowFeedRepository(list: (_) async => const []),
        ),
      ),
    );

    expect(find.text('Agora indisponível'), findsOneWidget);
    expect(find.text('Riverside School'), findsNothing);
  });

  testWidgets('nega acesso sem retry e permite retry de indisponibilidade', (tester) async {
    await pumpAuthorized(
      tester,
      repository: _FakeNowFeedRepository(
        list: (_) async => throw const PrincipalNowFeedUnauthorized(),
      ),
    );
    expect(find.text('Agora indisponível'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);

    var attempts = 0;
    await pumpAuthorized(
      tester,
      repository: _FakeNowFeedRepository(
        list: (_) async {
          attempts += 1;
          if (attempts == 1) throw const PrincipalNowFeedUnavailable();
          return [_story];
        },
      ),
    );
    expect(find.text('Não foi possível carregar'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text(_story.caption), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('resolve mídia sob demanda e recarrega após publicação confirmada', (tester) async {
    final refresh = PrincipalNowFeedRefreshSignal();
    addTearDown(refresh.dispose);
    var loads = 0;
    final resolved = <String>[];
    final repository = _FakeNowFeedRepository(
      list: (_) async {
        loads += 1;
        return [_story, _secondStory];
      },
      resolve: (media) async {
        resolved.add(media.readTicket);
        return PrincipalNowMediaRead(
          signedUrl: 'https://signed.test/${media.readTicket}',
          mimeType: media.mimeType,
          kind: media.kind,
          expiresIn: const Duration(seconds: 60),
        );
      },
    );

    await pumpAuthorized(tester, repository: repository, refreshSignal: refresh);
    expect(find.text(_story.caption), findsOneWidget);
    expect(resolved, containsAll(['ticket-1', 'audio-ticket-1', 'ticket-2']));
    expect(resolved, isNot(contains('audio-ticket-2')));
    final progressRow = tester.widget<Row>(
      find.descendant(
        of: find.byKey(const Key('principal-now-progress')),
        matching: find.byType(Row),
      ),
    );
    expect(progressRow.children, hasLength(2));

    refresh.markPublished('publication-confirmed');
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(find.text(_story.caption), findsOneWidget);
  });

  testWidgets('falha fechado quando o resgate da mídia perde autorização', (tester) async {
    final repository = _FakeNowFeedRepository(
      list: (_) async => [_story],
      resolve: (_) async => throw const PrincipalNowFeedUnauthorized(),
    );

    await pumpAuthorized(tester, repository: repository);
    expect(find.text('Agora indisponível'), findsOneWidget);
    expect(find.byKey(const Key('principal-now-story')), findsNothing);
  });

  testWidgets('expõe estado semântico quando vídeo ainda não possui player canônico', (
    tester,
  ) async {
    final repository = _FakeNowFeedRepository(
      list: (_) async => [_videoStory],
      resolve: (media) async => PrincipalNowMediaRead(
        signedUrl: 'https://signed.test/video',
        mimeType: media.mimeType,
        kind: media.kind,
        expiresIn: const Duration(seconds: 60),
      ),
    );

    await pumpAuthorized(tester, repository: repository);
    final unavailable = find.byKey(const Key('principal-now-media-unavailable'));
    expect(unavailable, findsOneWidget);
    expect(tester.getSemantics(unavailable).label, contains('Mídia do Agora indisponível'));
  });
}

final _story = PrincipalNowFeedItem(
  publicationId: 'publication-1',
  author: 'Colégio Coelo',
  authorInitials: 'CC',
  contextLabel: 'Turma Girassol',
  timeLabel: '2 h',
  caption: 'Ciência em ação',
  publishedAt: _publishedAt,
  expiresAt: _expiresAt,
  media: const PrincipalNowMediaDescriptor(
    readTicket: 'ticket-1',
    mimeType: 'image/webp',
    kind: PrincipalNowMediaKind.media,
  ),
  audio: const PrincipalNowMediaDescriptor(
    readTicket: 'audio-ticket-1',
    mimeType: 'audio/mpeg',
    kind: PrincipalNowMediaKind.audio,
  ),
);

final _secondStory = PrincipalNowFeedItem(
  publicationId: 'publication-2',
  author: 'Colégio Coelo',
  authorInitials: 'CC',
  contextLabel: 'Turma Girassol',
  timeLabel: '1 h',
  caption: 'Rotina da turma',
  publishedAt: _publishedAt,
  expiresAt: _expiresAt,
  media: const PrincipalNowMediaDescriptor(
    readTicket: 'ticket-2',
    mimeType: 'image/webp',
    kind: PrincipalNowMediaKind.media,
  ),
  audio: const PrincipalNowMediaDescriptor(
    readTicket: 'audio-ticket-2',
    mimeType: 'audio/mpeg',
    kind: PrincipalNowMediaKind.audio,
  ),
);

final _videoStory = PrincipalNowFeedItem(
  publicationId: 'publication-video',
  author: 'Colégio Coelo',
  authorInitials: 'CC',
  contextLabel: 'Esportes',
  timeLabel: 'Agora',
  caption: 'Momento esportivo',
  publishedAt: _publishedAt,
  expiresAt: _expiresAt,
  media: const PrincipalNowMediaDescriptor(
    readTicket: 'ticket-video',
    mimeType: 'video/mp4',
    kind: PrincipalNowMediaKind.media,
  ),
);

final _publishedAt = DateTime.utc(2026, 8, 21, 10);
final _expiresAt = DateTime.utc(2026, 8, 22, 10);

final class _FakeNowFeedRepository implements PrincipalNowFeedRepository {
  const _FakeNowFeedRepository({required this.list, this.resolve});

  final Future<List<PrincipalNowFeedItem>> Function(PrincipalNowFeedScope) list;
  final Future<PrincipalNowMediaRead> Function(PrincipalNowMediaDescriptor)? resolve;

  @override
  Future<List<PrincipalNowFeedItem>> listVisibleStories(PrincipalNowFeedScope scope) => list(scope);

  @override
  Future<PrincipalNowMediaRead> resolveMedia({
    required PrincipalNowFeedScope scope,
    required String publicationId,
    required PrincipalNowMediaDescriptor media,
  }) =>
      resolve?.call(media) ??
      Future.value(
        PrincipalNowMediaRead(
          signedUrl: 'https://signed.test/${media.readTicket}',
          mimeType: media.mimeType,
          kind: media.kind,
          expiresIn: const Duration(seconds: 60),
        ),
      );
}
