import 'package:coelo_superadmin/features/principal_now/domain/principal_now_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_now/presentation/principal_now_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// R14 S7 / ADR 0040: remocao imediata pela rota normal do Agora. A opcao so
// existe quando o servidor projetou can_remove + management_version e a
// composicao entregou um repositorio de remocao; o feed e relido depois.
void main() {
  const scope = PrincipalNowFeedScope(institutionId: 'institution-coelo');

  Future<void> pump(
    WidgetTester tester, {
    required PrincipalNowFeedRepository feed,
    PrincipalNowRemovalRepository? removal,
  }) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: PrincipalNowPreviewPage.authorized(
            feedRepository: feed,
            feedScope: scope,
            removalRepository: removal,
            onCreate: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openOptions(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('principal-now-options')));
    await tester.pumpAndSettle();
  }

  testWidgets('sem projecao do servidor a opcao de remover nao existe', (tester) async {
    final removal = _FakeRemoval();
    await pump(
      tester,
      feed: _FakeFeed(items: [_item(canRemove: false, version: null)]),
      removal: removal,
    );
    await openOptions(tester);
    expect(find.text('Publicar no Agora'), findsOneWidget);
    expect(find.byKey(const Key('principal-now-remove-option')), findsNothing);
  });

  testWidgets('can_remove sem repositorio de remocao nao oferece a opcao', (tester) async {
    await pump(tester, feed: _FakeFeed(items: [_item(canRemove: true, version: 2)]));
    await openOptions(tester);
    expect(find.byKey(const Key('principal-now-remove-option')), findsNothing);
  });

  testWidgets('remover confirma, envia a versao esperada e rele o feed sem o item', (tester) async {
    final removal = _FakeRemoval();
    final feed = _FakeFeed(items: [_item(canRemove: true, version: 2)]);
    await pump(tester, feed: feed, removal: removal);
    expect(find.text('R14 S7 Agora'), findsOneWidget);

    await openOptions(tester);
    await tester.tap(find.byKey(const Key('principal-now-remove-option')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-now-remove-dialog')), findsOneWidget);

    // Cancelar mantem publicado e nao chama o servidor.
    await tester.tap(find.byKey(const Key('principal-now-remove-cancel')));
    await tester.pumpAndSettle();
    expect(removal.calls, isEmpty);
    expect(find.text('R14 S7 Agora'), findsOneWidget);

    feed.items = const [];
    await openOptions(tester);
    await tester.tap(find.byKey(const Key('principal-now-remove-option')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-now-remove-confirm')));
    await tester.pumpAndSettle();

    expect(removal.calls, [('publication-1', 2)]);
    expect(find.text('Agora removido.'), findsOneWidget);
    expect(feed.loads, 2);
    expect(find.text('Nada novo no Agora'), findsOneWidget);
    expect(find.text('R14 S7 Agora'), findsNothing);
  });

  for (final (failure, message) in [
    (const PrincipalNowRemovalDenied(), 'Você não tem permissão para remover este Agora.'),
    (
      const PrincipalNowRemovalConflict(),
      'Este Agora mudou antes da remoção. Recarregue e tente novamente.',
    ),
    (const PrincipalNowRemovalUnavailable(), 'Não foi possível remover agora. Tente novamente.'),
  ]) {
    testWidgets('falha ${failure.runtimeType} e anunciada sem mutar o feed', (tester) async {
      final removal = _FakeRemoval(failure: failure);
      final feed = _FakeFeed(items: [_item(canRemove: true, version: 3)]);
      await pump(tester, feed: feed, removal: removal);
      await openOptions(tester);
      await tester.tap(find.byKey(const Key('principal-now-remove-option')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('principal-now-remove-confirm')));
      await tester.pumpAndSettle();
      expect(removal.calls, [('publication-1', 3)]);
      expect(find.text(message), findsOneWidget);
      expect(feed.loads, 1, reason: 'falha nao rele o feed');
      expect(find.text('R14 S7 Agora'), findsOneWidget);
    });
  }
}

PrincipalNowFeedItem _item({required bool canRemove, required int? version}) =>
    PrincipalNowFeedItem(
      publicationId: 'publication-1',
      author: 'Operador interno',
      authorInitials: 'O',
      contextLabel: 'QA R04 Cuidado',
      timeLabel: 'Agora',
      caption: 'R14 S7 Agora',
      publishedAt: DateTime.utc(2026, 9, 16, 15),
      expiresAt: DateTime.utc(2026, 9, 17, 15),
      media: const PrincipalNowMediaDescriptor(
        readTicket: 'ticket-1',
        mimeType: 'image/png',
        kind: PrincipalNowMediaKind.media,
      ),
      managementVersion: version,
      canRemove: canRemove,
    );

final class _FakeFeed implements PrincipalNowFeedRepository {
  _FakeFeed({required this.items});

  List<PrincipalNowFeedItem> items;
  var loads = 0;

  @override
  Future<List<PrincipalNowFeedItem>> listVisibleStories(PrincipalNowFeedScope scope) async {
    loads += 1;
    return items;
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
}

final class _FakeRemoval implements PrincipalNowRemovalRepository {
  _FakeRemoval({this.failure});

  final PrincipalNowRemovalFailure? failure;
  final calls = <(String, int)>[];

  @override
  Future<PrincipalNowRemovalReceipt> removeStory({
    required String publicationId,
    required int expectedVersion,
    String? reason,
  }) async {
    calls.add((publicationId, expectedVersion));
    final failure = this.failure;
    if (failure != null) throw failure;
    return PrincipalNowRemovalReceipt(
      publicationId: publicationId,
      managementVersion: expectedVersion + 1,
      purgeStatus: 'purged',
    );
  }
}
