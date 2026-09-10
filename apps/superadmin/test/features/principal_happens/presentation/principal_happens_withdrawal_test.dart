import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Retirada de publicação do Acontece (Etapa 2 → apps/superadmin →
/// Coelo (Principal) → Acontece → Feed → `acontece.remove`).
///
/// O servidor decide quem retira; a interface só oferece a ação quando a
/// projeção autorizada trouxe identidade, versão e permissão, e só declara
/// sucesso depois da resposta autorizada.
void main() {
  const scope = PrincipalHappensFeedScope(institutionId: 'institution-1');

  PrincipalPostPreviewItem post({
    String author = 'Prof. Rafael Souza',
    String? postId = 'post-1',
    int? version = 3,
    bool canWithdraw = true,
  }) => PrincipalPostPreviewItem(
    author: author,
    context: 'História · 6º ano A',
    time: '2 h',
    initials: 'RS',
    body: 'Aula prática sobre civilizações antigas.',
    postId: postId,
    managementVersion: version,
    canWithdraw: canWithdraw,
  );

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

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('principal-happens-options-post-0')));
    await tester.pumpAndSettle();
  }

  testWidgets('a repository without the withdrawal contract never offers the action', (
    tester,
  ) async {
    await pumpFeed(tester, _ReadOnlyRepository([post()]));

    expect(find.byKey(const Key('principal-happens-options-post-0')), findsNothing);
    expect(find.text('Retirar publicação'), findsNothing);
  });

  testWidgets('the action stays closed when the server did not authorize this actor', (
    tester,
  ) async {
    final repository = _WithdrawalRepository([post(canWithdraw: false)]);
    await pumpFeed(tester, repository);

    expect(find.byKey(const Key('principal-happens-options-post-0')), findsNothing);
    expect(repository.withdrawals, isEmpty);
  });

  testWidgets('the action stays closed when the projection carries no version', (tester) async {
    final repository = _WithdrawalRepository([post(version: null)]);
    await pumpFeed(tester, repository);

    expect(find.byKey(const Key('principal-happens-options-post-0')), findsNothing);
  });

  testWidgets('cancelling the confirmation never reaches the server', (tester) async {
    final repository = _WithdrawalRepository([post()]);
    await pumpFeed(tester, repository);
    await openMenu(tester);
    await tester.tap(find.byKey(const Key('principal-happens-withdraw-label')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-happens-withdraw-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('principal-happens-withdraw-cancel')));
    await tester.pumpAndSettle();

    expect(repository.withdrawals, isEmpty);
    expect(find.text('Publicação retirada do feed.'), findsNothing);
  });

  testWidgets('confirming sends the post identity and version once and re-reads the feed', (
    tester,
  ) async {
    final repository = _WithdrawalRepository([post()])..nextPosts = const [];
    await pumpFeed(tester, repository);
    expect(repository.loads, 1);

    await openMenu(tester);
    await tester.tap(find.byKey(const Key('principal-happens-withdraw-label')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-happens-withdraw-confirm')));
    await tester.pumpAndSettle();

    expect(repository.withdrawals, [('post-1', 3)]);
    expect(repository.loads, 2, reason: 'the feed is re-read instead of patched in memory');
    expect(find.text('Publicação retirada do feed.'), findsOneWidget);
    expect(find.text('Aula prática sobre civilizações antigas.'), findsNothing);
  });

  testWidgets('a denied withdrawal keeps the post and never claims success', (tester) async {
    final repository = _WithdrawalRepository([post()])
      ..failure = const PrincipalHappensFeedUnauthorized();
    await pumpFeed(tester, repository);

    await openMenu(tester);
    await tester.tap(find.byKey(const Key('principal-happens-withdraw-label')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-happens-withdraw-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Você não tem permissão para retirar esta publicação.'), findsOneWidget);
    expect(find.text('Publicação retirada do feed.'), findsNothing);
    expect(find.text('Aula prática sobre civilizações antigas.'), findsOneWidget);
    expect(repository.loads, 1, reason: 'a denial does not trigger a re-read');
  });

  testWidgets('a version conflict re-reads the feed without claiming success', (tester) async {
    final repository = _WithdrawalRepository([post()])
      ..failure = const PrincipalHappensWithdrawalConflict();
    await pumpFeed(tester, repository);

    await openMenu(tester);
    await tester.tap(find.byKey(const Key('principal-happens-withdraw-label')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-happens-withdraw-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('A publicação mudou desde a última leitura. Feed atualizado.'), findsOneWidget);
    expect(repository.loads, 2);
  });

  testWidgets('switching context while the confirmation is open never withdraws', (tester) async {
    final first = _WithdrawalRepository([post()]);
    final second = _WithdrawalRepository([post(postId: 'post-9', version: 1)]);
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget host(PrincipalHappensFeedRepository repository, String institutionId) => MaterialApp(
      theme: CoeloTheme.light,
      home: PrincipalHappensPreviewPage(
        feedRepository: repository,
        feedScope: PrincipalHappensFeedScope(institutionId: institutionId),
      ),
    );

    await tester.pumpWidget(host(first, 'institution-1'));
    await tester.pumpAndSettle();
    await openMenu(tester);
    await tester.tap(find.byKey(const Key('principal-happens-withdraw-label')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-happens-withdraw-dialog')), findsOneWidget);

    // O contexto troca embaixo do diálogo: outra instituição, outro repositório.
    await tester.pumpWidget(host(second, 'institution-2'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-happens-withdraw-confirm')));
    await tester.pumpAndSettle();

    expect(first.withdrawals, isEmpty, reason: 'the stale repository is never called');
    expect(second.withdrawals, isEmpty, reason: 'the new context never inherits the decision');
    expect(find.text('Publicação retirada do feed.'), findsNothing);
  });

  testWidgets('a transport failure reports honestly and keeps the post', (tester) async {
    final repository = _WithdrawalRepository([post()])
      ..failure = const PrincipalHappensFeedUnavailable();
    await pumpFeed(tester, repository);

    await openMenu(tester);
    await tester.tap(find.byKey(const Key('principal-happens-withdraw-label')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-happens-withdraw-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível retirar agora. Tente novamente.'), findsOneWidget);
    expect(find.text('Aula prática sobre civilizações antigas.'), findsOneWidget);
  });
}

final class _ReadOnlyRepository implements PrincipalHappensFeedRepository {
  _ReadOnlyRepository(this.posts);

  final List<PrincipalPostPreviewItem> posts;

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) async =>
      posts;

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) async =>
      throw const PrincipalHappensFeedUnavailable();
}

final class _WithdrawalRepository
    implements PrincipalHappensFeedRepository, PrincipalHappensPostWithdrawal {
  _WithdrawalRepository(this.posts);

  List<PrincipalPostPreviewItem> posts;
  List<PrincipalPostPreviewItem>? nextPosts;
  Exception? failure;
  final withdrawals = <(String, int)>[];
  var loads = 0;

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) async {
    loads += 1;
    return posts;
  }

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) async =>
      throw const PrincipalHappensFeedUnavailable();

  @override
  Future<void> withdrawPost({
    required String postId,
    required int expectedVersion,
    String? reason,
  }) async {
    if (failure case final error?) throw error;
    withdrawals.add((postId, expectedVersion));
    if (nextPosts case final replacement?) posts = replacement;
  }
}
