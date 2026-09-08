import 'package:coelo_superadmin/features/principal_now/domain/principal_now_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_now/presentation/principal_now_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Client acceptance for `agora.expire`.
///
/// The Owner decided expiration is governed by authorised profiles through
/// hierarchy and RLS, so the client never derives the permission: it renders the
/// affordance only when the authorised projection already granted it, and the
/// server revalidates the command. The authorised command does not exist yet, so
/// production keeps failing closed.
void main() {
  const scope = PrincipalNowFeedScope(institutionId: 'institution-coelo');

  Future<void> pump(WidgetTester tester, _FeedRepository repository) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: PrincipalNowPreviewPage.authorized(feedRepository: repository, feedScope: scope),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder expireButton() => find.byKey(const Key('principal-now-expire'));

  Future<void> confirmWithReason(WidgetTester tester, String reason) async {
    await tester.tap(expireButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('principal-now-expire-reason')), reason);
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-now-expire-confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('no affordance while the projection does not grant expiration', (tester) async {
    await pump(tester, _FeedRepository([_item(canExpire: false)]));

    expect(find.byKey(const Key('principal-now-story')), findsOneWidget);
    expect(find.byKey(const Key('principal-now-options')), findsOneWidget);
    expect(expireButton(), findsNothing);
  });

  testWidgets('no affordance when the projection omits the publication id', (tester) async {
    await pump(tester, _FeedRepository([_item(id: '', canExpire: true)]));

    expect(find.byKey(const Key('principal-now-options')), findsOneWidget);
    expect(expireButton(), findsNothing);
  });

  testWidgets('the affordance follows the story on screen', (tester) async {
    final repository = _FeedRepository([
      _item(canExpire: false),
      _item(id: 'publication-2', canExpire: true, caption: 'Segundo Agora'),
    ], expirationSucceeds: true);
    await pump(tester, repository);

    // The first story was not granted, so nothing is offered for it.
    expect(expireButton(), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Segundo Agora'), findsOneWidget);
    expect(expireButton(), findsOneWidget);

    await confirmWithReason(tester, 'Publicado por engano');

    // The command carries the Agora the operator is looking at, never the one
    // the viewer opened on.
    expect(repository.expirations.single.publicationId, 'publication-2');
  });

  testWidgets('a granted expiration requires a recorded reason', (tester) async {
    await pump(tester, _FeedRepository([_item(canExpire: true)]));

    await tester.tap(expireButton());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-now-expire-dialog')), findsOneWidget);
    final blocked = tester.widget<FilledButton>(
      find.byKey(const Key('principal-now-expire-confirm')),
    );
    expect(blocked.onPressed, isNull, reason: 'audit must not depend on an optional field');

    await tester.enterText(
      find.byKey(const Key('principal-now-expire-reason')),
      'Publicado por engano',
    );
    await tester.pump();
    final allowed = tester.widget<FilledButton>(
      find.byKey(const Key('principal-now-expire-confirm')),
    );
    expect(allowed.onPressed, isNotNull);
  });

  testWidgets('cancelling sends nothing', (tester) async {
    final repository = _FeedRepository([_item(canExpire: true)]);
    await pump(tester, repository);

    await tester.tap(expireButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('principal-now-expire-reason')), 'Desisti');
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-now-expire-cancel')));
    await tester.pumpAndSettle();

    expect(repository.expirations, isEmpty);
    expect(repository.loads, 1, reason: 'a cancelled expiration must not reload the feed');
  });

  testWidgets('confirming sends the publication id and reason, then reloads the feed', (
    tester,
  ) async {
    final repository = _FeedRepository([_item(canExpire: true)], expirationSucceeds: true);
    await pump(tester, repository);

    await confirmWithReason(tester, 'Publicado por engano');

    expect(repository.expirations.single.publicationId, 'publication-1');
    expect(repository.expirations.single.reason, 'Publicado por engano');
    expect(repository.expirations.single.requestId, isNotEmpty);
    // Absence is proved by the server on the next read: while this projection
    // still returns the Agora, the client keeps showing it.
    expect(repository.loads, 2);
    expect(find.text('Agora autorizado'), findsOneWidget);
  });

  testWidgets('an unavailable command keeps the Agora and says so', (tester) async {
    final repository = _FeedRepository([_item(canExpire: true)]);
    await pump(tester, repository);

    await confirmWithReason(tester, 'Tentativa');

    expect(repository.loads, 1, reason: 'nothing expired, so nothing is refetched');
    expect(find.text('Agora autorizado'), findsOneWidget);
    expect(find.text('Expiracao aguarda o comando autorizado.'), findsOneWidget);
  });

  testWidgets('a denied expiration is reported without hiding the Agora', (tester) async {
    final repository = _FeedRepository([_item(canExpire: true)], denyExpiration: true);
    await pump(tester, repository);

    await confirmWithReason(tester, 'Tentativa');

    expect(repository.loads, 1);
    expect(find.text('Agora autorizado'), findsOneWidget);
    expect(expireButton(), findsOneWidget);
    expect(find.text('Voce nao pode expirar este Agora.'), findsOneWidget);
  });

  testWidgets('a retry replays the same request id instead of expiring twice', (tester) async {
    final repository = _FeedRepository([_item(canExpire: true)]);
    await pump(tester, repository);

    await confirmWithReason(tester, 'Primeira tentativa');
    await confirmWithReason(tester, 'Segunda tentativa');

    expect(repository.expirations.length, 2);
    expect(
      repository.expirations.first.requestId,
      repository.expirations.last.requestId,
      reason: 'the same intent must replay, not duplicate the expiration',
    );
  });
}

PrincipalNowFeedItem _item({
  String id = 'publication-1',
  required bool canExpire,
  String caption = 'Agora autorizado',
}) => PrincipalNowFeedItem(
  publicationId: id,
  author: 'Colégio Coelo',
  authorInitials: 'CC',
  contextLabel: 'Turma Girassol',
  timeLabel: '2 h',
  caption: caption,
  canExpire: canExpire,
  publishedAt: DateTime.utc(2026, 8, 21, 10),
  expiresAt: DateTime.utc(2026, 8, 22, 10),
  media: const PrincipalNowMediaDescriptor(
    readTicket: 'ticket-1',
    mimeType: 'image/webp',
    kind: PrincipalNowMediaKind.media,
  ),
);

final class _FeedRepository implements PrincipalNowFeedRepository {
  _FeedRepository(this._items, {this.expirationSucceeds = false, this.denyExpiration = false});

  final List<PrincipalNowFeedItem> _items;
  final bool expirationSucceeds;
  final bool denyExpiration;
  final List<PrincipalNowExpireCommand> expirations = [];
  var loads = 0;

  @override
  Future<List<PrincipalNowFeedItem>> listVisibleStories(PrincipalNowFeedScope scope) async {
    loads++;
    return _items;
  }

  @override
  Future<PrincipalNowMediaRead> resolveMedia({
    required PrincipalNowFeedScope scope,
    required String publicationId,
    required PrincipalNowMediaDescriptor media,
  }) async => PrincipalNowMediaRead(
    signedUrl: 'https://signed.test/${media.readTicket}',
    mimeType: media.mimeType,
    kind: media.kind,
    expiresIn: const Duration(seconds: 60),
  );

  @override
  Future<void> expireNow(PrincipalNowExpireCommand command) async {
    expirations.add(command);
    if (denyExpiration) throw const PrincipalNowFeedUnauthorized();
    if (!expirationSucceeds) throw const PrincipalNowExpireUnavailable();
  }
}
