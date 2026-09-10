import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_image_repository.dart';
import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_preview_data.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Estados e responsividade do feed de Momentos NA ROTA REAL.
///
/// A rota passou a consumir o repositorio autorizado, e o contrato de backend
/// dela ainda e candidato nao integrado. Por isso o estado de falha importa
/// tanto quanto o de sucesso: enquanto a RPC nao existir, e ele que a pessoa
/// vai ver, e ele nao pode mentir nem cair na fixture de demonstracao.
void main() {
  testWidgets('a falha do feed nao cai na demonstracao e oferece nova tentativa', (tester) async {
    final feed = _FailingFeed(const PrincipalMomentsFeedUnavailable());
    await _pumpRoute(tester, feed, size: const Size(1440, 1000));

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(
      find.text(PrincipalMomentsPreviewData.demo.moments.first.caption),
      findsNothing,
      reason: 'uma falha nunca pode virar conteudo de demonstracao',
    );
  });

  testWidgets('a negativa de vinculo nao oferece nova tentativa', (tester) async {
    final feed = _FailingFeed(const PrincipalMomentsFeedUnauthorized());
    await _pumpRoute(tester, feed, size: const Size(1440, 1000));

    expect(find.text('Momentos indisponíveis'), findsOneWidget);
    expect(
      find.text('Tentar novamente'),
      findsNothing,
      reason: 'insistir numa negativa de autorizacao e convite falso',
    );
  });

  testWidgets('feed autorizado e vazio diz que nao ha momentos', (tester) async {
    await _pumpRoute(tester, _EmptyFeed(), size: const Size(1440, 1000));

    expect(find.text('Nenhum momento por aqui'), findsOneWidget);
    expect(
      find.text(PrincipalMomentsPreviewData.demo.moments.first.caption),
      findsNothing,
      reason: 'vazio autorizado nao e demonstracao',
    );
  });

  for (final width in <double>[375, 768, 1440]) {
    testWidgets('os estados da rota nao transbordam em ${width.toInt()} px', (tester) async {
      await _pumpRoute(
        tester,
        _FailingFeed(const PrincipalMomentsFeedUnavailable()),
        size: Size(width, 1000),
      );

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('os estados da rota nao transbordam com texto a 200%', (tester) async {
    await _pumpRoute(
      tester,
      _FailingFeed(const PrincipalMomentsFeedUnavailable()),
      size: const Size(375, 1600),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpRoute(
  WidgetTester tester,
  PrincipalMomentsFeedRepository feed, {
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
    principalRuntimeContextRepository: const _GroupScopedContext(),
    principalMomentsFeedRepository: feed,
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
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  router.go(SuperadminRoutes.principalMoments);
  await tester.pumpAndSettle();
}

final class _FailingFeed implements PrincipalMomentsFeedRepository {
  const _FailingFeed(this.failure);

  final PrincipalMomentsFeedFailure failure;

  @override
  Future<List<PrincipalMomentPreviewItem>> listVisibleMoments(
    PrincipalMomentsFeedScope scope,
  ) => Future.error(failure);
}

final class _EmptyFeed implements PrincipalMomentsFeedRepository {
  @override
  Future<List<PrincipalMomentPreviewItem>> listVisibleMoments(
    PrincipalMomentsFeedScope scope,
  ) async => const [];
}

final class _GroupScopedContext implements PrincipalRuntimeContextRepository {
  const _GroupScopedContext();

  @override
  Future<List<PrincipalRuntimeContext>> listAvailableContexts() async => const [
    PrincipalRuntimeContext(
      membershipId: 'membership-real',
      personId: 'person-real',
      institutionId: 'institution-real',
      institutionName: 'Colegio Horizonte',
      roleCode: 'teacher',
      scopeKind: 'group',
      unitId: 'unit-real',
      unitName: 'Unidade Centro',
      groupId: 'group-real',
      groupName: 'Turma Girassol',
    ),
  ];
}

