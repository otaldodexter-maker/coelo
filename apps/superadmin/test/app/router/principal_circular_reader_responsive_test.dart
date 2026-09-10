import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Responsividade, acessibilidade e retorno do leitor Principal de Circular
/// JA HOSPEDADO na rota real do Superadmin.
///
/// A hospedagem no shell e o embedding do leitor tinham cobertura isolada, mas
/// a superficie que a pessoa realmente abre — a rota, dentro do shell, nas
/// larguras canonicas e com texto ampliado — nao tinha. Ausencia de cobertura
/// nao e estado neutro: e onde o defeito se esconde.
void main() {
  for (final width in <double>[375, 768, 1024, 1440]) {
    testWidgets('o leitor roteado nao transborda em ${width.toInt()} px', (tester) async {
      await _pumpReader(tester, size: Size(width, 1200));

      expect(find.byType(PrincipalCircularDetailPage), findsOneWidget);
      expect(find.text('Renovacao de matricula 2027'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in <double>[375, 1440]) {
    testWidgets('o leitor roteado nao transborda em ${width.toInt()} px com texto a 200%', (
      tester,
    ) async {
      await _pumpReader(tester, size: Size(width, 2000), textScale: 2);

      expect(find.byType(PrincipalCircularDetailPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('o shell do Superadmin permanece visivel durante a leitura', (tester) async {
    await _pumpReader(tester, size: const Size(1440, 1200));

    expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);
  });

  testWidgets('Escape devolve ao Acontece sem sair do shell', (tester) async {
    final fixture = await _pumpReader(tester, size: const Size(1440, 1200));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(
      fixture.router.routerDelegate.currentConfiguration.uri.path,
      SuperadminRoutes.principalHappens,
    );
    expect(find.byType(PrincipalCircularDetailPage), findsNothing);
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);
  });

  testWidgets('o conteudo da Circular chega a arvore semantica', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpReader(tester, size: const Size(1440, 1200));

    expect(
      find.bySemanticsLabel(RegExp('Renovacao de matricula 2027')),
      findsWidgets,
      reason: 'o titulo precisa ser anunciavel, nao apenas desenhado',
    );
    handle.dispose();
  });
}

Future<({GoRouter router, SuperadminSession session})> _pumpReader(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final session = SuperadminSession()..signInForTesting();
  final router = createSuperadminRouter(
    session: session,
    login: unavailableSuperadminLogin,
    logout: unavailableSuperadminLogout,
    requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
    mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
    principalRuntimeContextRepository: const _RuntimeContextRepository(),
    principalMixedFeedRepository: _MixedFeedRepository(),
    principalHappensFeedRepository: _HappensMediaRepository(),
    principalCircularRepository: _ReaderRepository(),
    principalCircularResponseRepository: _ResponseRepository(),
    allowDevelopmentPreview: false,
    onThemeModeChanged: (_) {},
  );
  addTearDown(router.dispose);
  addTearDown(session.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: CoeloTheme.light,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
  );
  router.go('/principal-happens/circular/circular-1');
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
