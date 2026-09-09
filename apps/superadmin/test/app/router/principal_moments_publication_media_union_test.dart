import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_image_repository.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/domain/moments_publication.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/presentation/principal_moments_publication_page.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/presentation/principal_moments_publication_route.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uniao de `embedded` e `mediaPicker` na publicacao de Momentos.
///
/// A entrega autoral L01 acrescentou a porta de selecao de midia mas removeu o
/// parametro `embedded` da rota, enquanto a base integrada usa `embedded: true`
/// para hospedar a composicao dentro do shell do Superadmin. Perder qualquer um
/// dos dois e regressao: estas provas fixam que os dois coexistem.
void main() {
  testWidgets('a rota produtiva mantem embedded e a porta de midia ao mesmo tempo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      principalRuntimeContextRepository: const _GroupScopedContext(),
      momentsPublicationRepository: InMemoryMomentsPublicationRepository(),
      allowDevelopmentPreview: false,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.principalMomentsPublish);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    final route = tester.widget<PrincipalMomentsPublicationRoute>(
      find.byType(PrincipalMomentsPublicationRoute),
    );
    expect(route.embedded, isTrue, reason: 'a hospedagem no shell nao pode ser perdida');

    final page = tester.widget<PrincipalMomentsPublicationPage>(
      find.byType(PrincipalMomentsPublicationPage),
    );
    expect(page.embedded, isTrue);
    expect(
      page.mediaPicker,
      isNotNull,
      reason: 'a porta de selecao de midia nao pode ser perdida',
    );
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);
  });

  testWidgets('a porta injetada alimenta o rascunho sem escolher destino no cliente', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalMomentsPublicationRoute(
          repository: InMemoryMomentsPublicationRepository(),
          publicationContext: const MomentsPublicationContext(
            institutionId: 'institution-real',
            institutionName: 'Colegio Horizonte',
            unitId: 'unit-real',
            unitName: 'Unidade Centro',
            groupId: 'group-real',
            groupName: 'Turma Girassol',
          ),
          embedded: true,
          mediaPicker: () async {
            calls += 1;
            return const <MomentsMediaCandidate>[];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final page = tester.widget<PrincipalMomentsPublicationPage>(
      find.byType(PrincipalMomentsPublicationPage),
    );
    expect(page.embedded, isTrue);
    expect(page.mediaPicker, isNotNull);
    await page.mediaPicker!();
    expect(calls, 1, reason: 'a porta injetada deve ser a usada, nao o seletor local');
  });
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
