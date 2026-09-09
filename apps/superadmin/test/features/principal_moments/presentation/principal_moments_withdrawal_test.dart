import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_preview_data.dart';
import 'package:coelo_superadmin/features/principal_moments/presentation/principal_moments_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _scope = PrincipalMomentsFeedScope(institutionId: 'institution-coelo');

const _own = PrincipalMomentPreviewItem(
  author: 'Equipe Coelo',
  context: '3º ano A',
  time: 'Agora',
  caption: 'Momento da própria autoria.',
  likes: 0,
  comments: 0,
  shares: 0,
  saves: 0,
  imageIndex: 0,
  publicationId: 'publication-1',
  canWithdraw: true,
);

const _other = PrincipalMomentPreviewItem(
  author: 'Outra pessoa',
  context: '3º ano A',
  time: 'Agora',
  caption: 'Momento de terceiro.',
  likes: 0,
  comments: 0,
  shares: 0,
  saves: 0,
  imageIndex: 1,
  publicationId: 'publication-2',
);

Future<void> _pump(
  WidgetTester tester, {
  required PrincipalMomentsFeedRepository feed,
  PrincipalMomentsWithdrawalRepository? withdrawal,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: PrincipalMomentsPreviewPage(
        feedRepository: feed,
        feedScope: _scope,
        withdrawalRepository: withdrawal,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('esconde a retirada quando o servidor não autoriza o ator', (tester) async {
    await _pump(
      tester,
      feed: _FakeFeed((_) async => const [_other]),
      withdrawal: _FakeWithdrawal((_) async {}),
    );

    expect(find.text(_other.caption), findsOneWidget);
    expect(find.byKey(const Key('principal-moments-withdraw')), findsNothing);
  });

  testWidgets('esconde a retirada sem contrato de retirada injetado', (tester) async {
    await _pump(tester, feed: _FakeFeed((_) async => const [_own]));

    expect(find.byKey(const Key('principal-moments-withdraw')), findsNothing);
  });

  testWidgets('retira uma vez, relê o feed e remove o momento da lista', (tester) async {
    final withdrawn = <String>[];
    var loads = 0;
    final feed = _FakeFeed((_) async {
      loads += 1;
      return withdrawn.isEmpty ? const [_own, _other] : const [_other];
    });
    final withdrawal = _FakeWithdrawal((id) async => withdrawn.add(id));

    await _pump(tester, feed: feed, withdrawal: withdrawal);
    expect(find.byKey(const Key('principal-moments-withdraw')), findsOneWidget);

    await tester.tap(find.byKey(const Key('principal-moments-withdraw')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-moments-withdraw-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('principal-moments-withdraw-confirm')));
    await tester.pumpAndSettle();

    expect(withdrawn, ['publication-1']);
    expect(loads, 2);
    expect(find.text('Momento retirado.'), findsOneWidget);
    expect(find.text(_own.caption), findsNothing);
    expect(find.text(_other.caption), findsOneWidget);
  });

  testWidgets('cancelar mantém o momento publicado e não chama o backend', (tester) async {
    final withdrawn = <String>[];
    await _pump(
      tester,
      feed: _FakeFeed((_) async => const [_own]),
      withdrawal: _FakeWithdrawal((id) async => withdrawn.add(id)),
    );

    await tester.tap(find.byKey(const Key('principal-moments-withdraw')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-moments-withdraw-cancel')));
    await tester.pumpAndSettle();

    expect(withdrawn, isEmpty);
    expect(find.text(_own.caption), findsOneWidget);
  });

  for (final failure in <PrincipalMomentsWithdrawalFailure>[
    const PrincipalMomentsWithdrawalDenied(),
    const PrincipalMomentsWithdrawalUnavailable(),
  ]) {
    testWidgets('${failure.runtimeType} preserva o momento e não anuncia sucesso', (tester) async {
      var loads = 0;
      final feed = _FakeFeed((_) async {
        loads += 1;
        return const [_own];
      });

      await _pump(
        tester,
        feed: feed,
        withdrawal: _FakeWithdrawal((_) async => throw failure),
      );

      await tester.tap(find.byKey(const Key('principal-moments-withdraw')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('principal-moments-withdraw-confirm')));
      await tester.pumpAndSettle();

      expect(find.text(_own.caption), findsOneWidget);
      expect(find.text('Momento retirado.'), findsNothing);
      expect(
        find.text(
          failure is PrincipalMomentsWithdrawalDenied
              ? 'Você não tem permissão para retirar este momento.'
              : 'Não foi possível retirar agora. Tente novamente.',
        ),
        findsOneWidget,
      );
      expect(loads, 1);
      expect(find.byKey(const Key('principal-moments-withdraw')), findsOneWidget);
    });
  }
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
