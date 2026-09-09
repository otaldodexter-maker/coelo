import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/circulars/presentation/superadmin_circular_detail_page.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_image_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/principal_happens_mixed_feed.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_detail_page.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Leitor Principal de Circular a partir do feed misto de Acontece.
///
/// O feed misto ja estava injetado, mas abrir um card de Circular apenas
/// informava indisponibilidade. Estas provas fixam o contrato de abertura:
/// sem capacidade de leitura a afordancia permanece honestamente fechada, e
/// com ela o leitor aberto e o da familia Principal, dentro do shell do
/// Superadmin (decisao do Owner de 09/09/2026), nunca o detalhe administrativo.
void main() {
  test('mantem a rota do leitor Principal explicita e separada da administrativa', () {
    expect(SuperadminRoutes.principalHappensCircular, '/principal-happens/circular/:circularId');
    expect(SuperadminRoutes.principalHappensCircularName, 'principal-happens-circular');
    expect(SuperadminRoutes.circularDetail, '/circulars/:circularId/read');
  });

  testWidgets('sem capacidade de leitura a rota falha fechada e nao vaza conteudo', (tester) async {
    final fixture = await _pumpRouter(tester, authenticated: true);
    fixture.router.go('/principal-happens/circular/circular-1');
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalCircularDetailPage), findsNothing);
    expect(find.byType(SuperadminCircularDetailPage), findsNothing);
  });

  testWidgets('sessao encerrada nao entrega o leitor Principal', (tester) async {
    final fixture = await _pumpRouter(
      tester,
      circularRepository: _ReaderRepository(),
      responseRepository: _ResponseRepository(),
    );
    fixture.router.go('/principal-happens/circular/circular-1');
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalCircularDetailPage), findsNothing);
    expect(find.text('Renovacao de matricula 2027'), findsNothing);
  });

  testWidgets('a rota direta entrega o leitor Principal dentro do shell', (tester) async {
    final fixture = await _pumpRouter(
      tester,
      authenticated: true,
      circularRepository: _ReaderRepository(),
      responseRepository: _ResponseRepository(),
    );
    fixture.router.go('/principal-happens/circular/circular-1');
    await tester.pumpAndSettle();

    expect(
      fixture.router.routerDelegate.currentConfiguration.uri.path,
      '/principal-happens/circular/circular-1',
    );
    expect(find.byType(PrincipalCircularDetailPage), findsOneWidget);
    expect(find.byType(SuperadminCircularDetailPage), findsNothing);
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);
    expect(find.text('Renovacao de matricula 2027'), findsWidgets);
  });

  testWidgets('abrir a Circular do feed misto entrega o leitor Principal no shell', (
    tester,
  ) async {
    final fixture = await _pumpRouter(
      tester,
      authenticated: true,
      circularRepository: _ReaderRepository(),
      responseRepository: _ResponseRepository(),
      mixedFeedRepository: _MixedFeedRepository(),
    );
    fixture.router.go(SuperadminRoutes.principalHappens);
    await tester.pumpAndSettle();

    // A previa contextual do card so existe quando a area de conteudo do shell
    // ainda e larga; abaixo disso a composicao aprovada leva direto ao leitor.
    await tester.tap(find.byKey(const Key('principal-happens-circular-circular-1')));
    await tester.pumpAndSettle();
    if (find.byKey(const Key('principal-circular-preview-read')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('principal-circular-preview-read')));
      await tester.pumpAndSettle();
    }

    expect(find.byType(PrincipalCircularDetailPage), findsOneWidget);
    expect(find.byType(SuperadminCircularDetailPage), findsNothing);
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);
    expect(find.text('Renovacao de matricula 2027'), findsWidgets);
    expect(find.textContaining('Confirme a renovacao'), findsWidgets);
  });
}

Future<({GoRouter router, SuperadminSession session})> _pumpRouter(
  WidgetTester tester, {
  bool authenticated = false,
  CircularRepository? circularRepository,
  CircularResponseRepository? responseRepository,
  PrincipalMixedFeedRepository? mixedFeedRepository,
}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final session = SuperadminSession();
  if (authenticated) session.signInForTesting();
  final router = createSuperadminRouter(
    session: session,
    login: unavailableSuperadminLogin,
    logout: unavailableSuperadminLogout,
    requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
    mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
    principalRuntimeContextRepository: const _RuntimeContextRepository(),
    principalMixedFeedRepository: mixedFeedRepository,
    principalHappensFeedRepository: mixedFeedRepository == null ? null : _HappensMediaRepository(),
    principalCircularRepository: circularRepository,
    principalCircularResponseRepository: responseRepository,
    allowDevelopmentPreview: false,
    onThemeModeChanged: (_) {},
  );
  addTearDown(router.dispose);
  addTearDown(session.dispose);
  await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
  await tester.pumpAndSettle();
  return (router: router, session: session);
}

final class _RuntimeContextRepository implements PrincipalRuntimeContextRepository {
  const _RuntimeContextRepository();

  @override
  Future<List<PrincipalRuntimeContext>> listAvailableContexts() async => const [
    PrincipalRuntimeContext(
      membershipId: 'membership-1',
      personId: 'person-1',
      institutionId: '11111111-1111-4111-8111-111111111111',
      institutionName: 'Colegio Horizonte',
      roleCode: 'guardian',
      scopeKind: 'group',
      unitId: '22222222-2222-4222-8222-222222222222',
      unitName: 'Unidade Centro',
      groupId: '33333333-3333-4333-8333-333333333333',
      groupName: 'Turma Girassol',
    ),
  ];
}

final class _MixedFeedRepository implements PrincipalMixedFeedRepository {
  @override
  Future<PrincipalHappensFeedPage> list(
    CircularScope scope, {
    PrincipalHappensFeedCursor? cursor,
    int limit = 20,
  }) async => PrincipalHappensFeedPage(
    items: [
      PrincipalHappensCircularItem(
        id: 'circular-1',
        publishedAt: DateTime.utc(2026, 9, 1),
        authorName: 'Equipe Coelo',
        contextLabel: 'Turma Girassol',
        summary: CircularSummary(
          id: 'circular-1',
          title: 'Renovacao de matricula 2027',
          excerpt: 'Confirme a renovacao ate 30 de setembro.',
          authorName: 'Equipe Coelo',
          contextLabel: 'Turma Girassol',
          publishedAt: DateTime.utc(2026, 9, 1),
          attachmentCount: 0,
          questionCount: 0,
          responseState: CircularResponseState.unanswered,
        ),
      ),
    ],
    nextCursor: null,
  );
}

/// So existe para satisfazer a composicao da rota: o feed misto vem do
/// repositorio proprio e a resolucao de midia nao e exercida por estas provas.
final class _HappensMediaRepository implements PrincipalHappensFeedRepository {
  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(
    PrincipalHappensFeedScope scope,
  ) async => const [];

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) =>
      Future.error(const PrincipalHappensFeedUnavailable());
}

final class _ReaderRepository implements CircularRepository {
  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) async =>
      CircularDetail(
        id: circularId,
        revisionId: 'revision-1',
        title: 'Renovacao de matricula 2027',
        authorName: 'Equipe Coelo',
        contextLabel: 'Turma Girassol',
        publishedAt: DateTime.utc(2026, 9, 1),
        blocks: const [
          CircularTextBlock(id: 'block-1', text: 'Confirme a renovacao ate 30 de setembro.'),
        ],
        status: CircularStatus.published,
        responseState: CircularResponseState.unanswered,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ResponseRepository implements CircularResponseRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
