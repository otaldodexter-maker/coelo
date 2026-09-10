// Acontece / Feed: carregar mais pela paginacao do servidor (acontece.feed).
//
// O feed vinha com teto: a RPC aceitava um limite entre 1 e 50 e nao tinha
// cursor nenhum, entao quem tivesse mais publicacoes do que o teto nunca via o
// resto. O Owner respondeu em 10/09/2026 (D3 e D5) que nao existe previa: o
// feed funciona de verdade, com carregar mais pela paginacao do servidor.
//
// Estes casos provam o lado do cliente do contrato: o cursor sai do ultimo item
// recebido, o fim da lista e o servidor quem diz (pagina incompleta), e a falha
// da pagina seguinte nao apaga o que ja esta na tela.
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/principal_happens_mixed_feed.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scope = PrincipalHappensFeedScope(institutionId: 'institution-1', limit: 3);
  const loadMore = Key('principal-happens-load-more');

  Future<void> pumpFeed(WidgetTester tester, PrincipalHappensFeedRepository repository) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPreviewPage(feedRepository: repository, feedScope: scope),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a pagina cheia oferece carregar mais e o cursor vem do ultimo item', (tester) async {
    final repository = _PagedFeedRepository([_page(0, 3), _page(3, 2)]);
    await pumpFeed(tester, repository);

    expect(find.byKey(loadMore), findsOneWidget);
    await tester.ensureVisible(find.byKey(loadMore));
    await tester.tap(find.byKey(loadMore));
    await tester.pumpAndSettle();

    // Duas leituras: a primeira sem cursor, a segunda ancorada no ultimo item
    // da primeira pagina.
    expect(repository.scopes.length, 2);
    expect(repository.scopes.first.cursorPostId, isNull);
    expect(repository.scopes.last.cursorPostId, 'post-2');
    expect(repository.scopes.last.cursorPublishedAt, _publishedAt(2));
    // Pagina incompleta: o servidor disse que acabou.
    expect(find.byKey(loadMore), findsNothing);
  });

  testWidgets('o fim da lista e do servidor, nao do cliente', (tester) async {
    // Uma unica pagina incompleta: nao ha o que carregar, e o rodape nem
    // aparece.
    final repository = _PagedFeedRepository([_page(0, 2)]);
    await pumpFeed(tester, repository);

    expect(find.byKey(loadMore), findsNothing);
    expect(repository.scopes.length, 1);
  });

  testWidgets('no feed misto o carregar mais usa o nextCursor que o servidor ja devolvia', (
    tester,
  ) async {
    // list_visible_happens_feed devolve nextCursor desde 20260909214000. A tela
    // lia a primeira pagina e descartava o cursor, entao o resto do feed era
    // inalcancavel mesmo com o servidor pronto.
    final repository = _MixedPagedRepository();
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPreviewPage.mixed(
          mixedFeedRepository: repository,
          mixedFeedScope: const CircularScope(institutionId: 'institution-1'),
          mediaRepository: null,
          onOpenCircular: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(loadMore));
    await tester.tap(find.byKey(loadMore));
    await tester.pumpAndSettle();

    expect(repository.cursors.length, 2);
    expect(repository.cursors.first, isNull);
    expect(repository.cursors.last?.itemId, 'post-0');
    expect(find.byKey(loadMore), findsNothing);
  });

  testWidgets('falha na pagina seguinte preserva o que ja esta na tela', (tester) async {
    final repository = _PagedFeedRepository([_page(0, 3)], failAfterFirstPage: true);
    await pumpFeed(tester, repository);

    await tester.ensureVisible(find.byKey(loadMore));
    await tester.tap(find.byKey(loadMore));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-happens-load-more-error')), findsOneWidget);
    expect(find.text('Registro 0'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}

DateTime _publishedAt(int index) => DateTime.utc(2026, 9, 10, 12).subtract(Duration(minutes: index));

List<PrincipalPostPreviewItem> _page(int start, int count) => List.generate(
  count,
  (offset) => PrincipalPostPreviewItem(
    author: 'Equipe',
    context: 'Contexto',
    time: 'Agora',
    initials: 'EQ',
    body: 'Registro ${start + offset}',
    postId: 'post-${start + offset}',
    publishedAt: _publishedAt(start + offset),
  ),
);

final class _MixedPagedRepository implements PrincipalMixedFeedRepository {
  final List<PrincipalHappensFeedCursor?> cursors = [];

  @override
  Future<PrincipalHappensFeedPage> list(
    CircularScope scope, {
    PrincipalHappensFeedCursor? cursor,
    int limit = 20,
  }) async {
    cursors.add(cursor);
    final first = cursors.length == 1;
    return PrincipalHappensFeedPage(
      items: [
        PrincipalHappensPostItem(
          id: first ? 'post-0' : 'post-1',
          publishedAt: _publishedAt(first ? 0 : 1),
          authorName: 'Equipe',
          contextLabel: 'Contexto',
          caption: first ? 'Registro 0' : 'Registro 1',
          managementVersion: 1,
          canWithdraw: false,
          media: const [],
        ),
      ],
      nextCursor: first
          ? PrincipalHappensFeedCursor(
              publishedAt: _publishedAt(0),
              itemType: 'post',
              itemId: 'post-0',
            )
          : null,
    );
  }
}

final class _PagedFeedRepository implements PrincipalHappensFeedRepository {
  _PagedFeedRepository(this._pages, {this.failAfterFirstPage = false});

  final List<List<PrincipalPostPreviewItem>> _pages;
  final bool failAfterFirstPage;
  final List<PrincipalHappensFeedScope> scopes = [];

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(
    PrincipalHappensFeedScope scope,
  ) async {
    scopes.add(scope);
    if (scopes.length > 1 && failAfterFirstPage) {
      throw const PrincipalHappensFeedUnavailable();
    }
    final index = scopes.length - 1;
    return index < _pages.length ? _pages[index] : const [];
  }

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) async =>
      throw const PrincipalHappensFeedUnavailable();
}
