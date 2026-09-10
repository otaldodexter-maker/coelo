import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_preview_data.dart';
import 'package:coelo_superadmin/features/principal_moments/presentation/principal_moments_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A confirmacao de retirada pertence ao feed que estava em tela.
///
/// O dialogo e assincrono, e `didUpdateWidget` troca repositorio e escopo sem
/// destruir o State, entao um `mounted` sozinho nao percebe que o contexto
/// mudou enquanto a pessoa lia a confirmacao. A retirada do Acontece ja se
/// protegia disso conferindo geracao, repositorio e escopo; a de Momentos nao.
/// O servidor reautoriza toda retirada, entao isto nao era brecha de
/// autorizacao: era aplicar em outro contexto uma confirmacao dada para este.
void main() {
  const first = PrincipalMomentsFeedScope(institutionId: 'institution-a');
  const second = PrincipalMomentsFeedScope(institutionId: 'institution-b');

  const own = PrincipalMomentPreviewItem(
    author: 'Equipe Coelo',
    context: '3 ano A',
    time: 'Agora',
    caption: 'Momento da propria autoria.',
    likes: 0,
    comments: 0,
    shares: 0,
    saves: 0,
    imageIndex: 0,
    publicationId: 'publication-1',
    canWithdraw: true,
  );

  Future<void> pump(
    WidgetTester tester,
    PrincipalMomentsFeedScope scope,
    PrincipalMomentsFeedRepository feed,
    PrincipalMomentsWithdrawalRepository withdrawal,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalMomentsPreviewPage(
          feedRepository: feed,
          feedScope: scope,
          withdrawalRepository: withdrawal,
        ),
      ),
    );
  }

  testWidgets('trocar de contexto com a confirmacao aberta cancela a retirada', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final withdrawn = <String>[];
    final scopes = <PrincipalMomentsFeedScope>[];
    final feed = _FakeFeed((scope) async {
      scopes.add(scope);
      return const [own];
    });
    final withdrawal = _FakeWithdrawal((id) async => withdrawn.add(id));

    await pump(tester, first, feed, withdrawal);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-moments-withdraw')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-moments-withdraw-dialog')), findsOneWidget);

    // O contexto de runtime muda enquanto a confirmacao esta aberta.
    await pump(tester, second, feed, withdrawal);
    await tester.pump();

    await tester.tap(find.byKey(const Key('principal-moments-withdraw-confirm')));
    await tester.pumpAndSettle();

    expect(
      withdrawn,
      isEmpty,
      reason: 'a confirmacao pertencia ao contexto anterior e nao pode ser aplicada no novo',
    );
    expect(scopes.first.institutionId, 'institution-a');
    expect(scopes.last.institutionId, 'institution-b');
  });

  testWidgets('sem troca de contexto a retirada segue funcionando', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final withdrawn = <String>[];
    final feed = _FakeFeed((_) async => withdrawn.isEmpty ? const [own] : const []);
    final withdrawal = _FakeWithdrawal((id) async => withdrawn.add(id));

    await pump(tester, first, feed, withdrawal);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-moments-withdraw')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-moments-withdraw-confirm')));
    await tester.pumpAndSettle();

    expect(withdrawn, ['publication-1']);
  });
}

final class _FakeFeed implements PrincipalMomentsFeedRepository {
  _FakeFeed(this._load);

  final Future<List<PrincipalMomentPreviewItem>> Function(PrincipalMomentsFeedScope scope) _load;

  @override
  Future<List<PrincipalMomentPreviewItem>> listVisibleMoments(PrincipalMomentsFeedScope scope) =>
      _load(scope);
}

final class _FakeWithdrawal implements PrincipalMomentsWithdrawalRepository {
  _FakeWithdrawal(this._withdraw);

  final Future<void> Function(String publicationId) _withdraw;

  @override
  Future<void> withdrawMoment(String publicationId, {String? reason}) => _withdraw(publicationId);
}
