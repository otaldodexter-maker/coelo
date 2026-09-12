import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_image_repository.dart';
import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_preview_data.dart';
import 'package:coelo_superadmin/features/principal_moments/presentation/principal_moments_preview_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Feed de Momentos na rota normal `/principal-moments`.
///
/// A rota existia e devolvia composicao indisponivel mesmo havendo repositorio
/// autorizado. Estas provas fixam o contrato: sem repositorio a rota continua
/// honestamente fechada, com repositorio ela consome o feed autorizado pelo
/// escopo real do contexto, e nunca cai na fixture de demonstracao.
void main() {
  testWidgets('sem repositorio de feed a rota permanece honestamente indisponivel', (tester) async {
    final fixture = await _pumpRouter(tester, authenticated: true);
    fixture.router.go(SuperadminRoutes.principalMoments);
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalMomentsPreviewPage), findsNothing);
  });

  testWidgets('sessao encerrada nao entrega o feed de Momentos', (tester) async {
    final feed = _FeedRepository();
    final fixture = await _pumpRouter(tester, feedRepository: feed);
    fixture.router.go(SuperadminRoutes.principalMoments);
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalMomentsPreviewPage), findsNothing);
    expect(feed.scopes, isEmpty);
  });

  testWidgets('a rota consome o feed autorizado pelo escopo real do contexto', (tester) async {
    final feed = _FeedRepository();
    final fixture = await _pumpRouter(tester, authenticated: true, feedRepository: feed);
    fixture.router.go(SuperadminRoutes.principalMoments);
    await tester.pumpAndSettle();

    final page = tester.widget<PrincipalMomentsPreviewPage>(
      find.byType(PrincipalMomentsPreviewPage),
    );
    expect(page.embedded, isTrue);
    expect(page.feedRepository, same(feed));
    expect(page.withdrawalRepository, same(feed));
    expect(feed.scopes, hasLength(1));
    expect(feed.scopes.single.institutionId, 'institution-real');
    expect(feed.scopes.single.unitId, 'unit-real');
    expect(feed.scopes.single.groupId, 'group-real');

    expect(find.text('Piquenique da Turma Girassol'), findsWidgets);
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);
  });

  testWidgets('a revisao de autorizacao releitura o feed em vez de manter o anterior', (
    tester,
  ) async {
    final feed = _FeedRepository();
    final fixture = await _pumpRouter(tester, authenticated: true, feedRepository: feed);
    fixture.router.go(SuperadminRoutes.principalMoments);
    await tester.pumpAndSettle();
    expect(feed.scopes, hasLength(1));

    fixture.session.authorize(
      const SuperadminAuthContext(
        platformRoleCode: 'other-role',
        scopeKind: SuperadminAuthScopeKind.platform,
        permissionCodes: {'platform.read'},
        aal: 'aal2',
      ),
      sessionId: fixture.session.sessionId!,
    );
    await tester.pumpAndSettle();

    expect(feed.scopes.length, greaterThan(1));
  });
}

Future<({GoRouter router, SuperadminSession session})> _pumpRouter(
  WidgetTester tester, {
  bool authenticated = false,
  _FeedRepository? feedRepository,
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
    principalRuntimeContextRepository: const _GroupScopedContext(),
    principalMomentsFeedRepository: feedRepository,
    principalMomentsWithdrawalRepository: feedRepository,
    allowDevelopmentPreview: false,
    onThemeModeChanged: (_) {},
  );
  addTearDown(router.dispose);
  addTearDown(session.dispose);
  await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
  await tester.pumpAndSettle();
  return (router: router, session: session);
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

final class _FeedRepository
    implements PrincipalMomentsFeedRepository, PrincipalMomentsWithdrawalRepository {
  final scopes = <PrincipalMomentsFeedScope>[];

  @override
  Future<List<PrincipalMomentPreviewItem>> listVisibleMoments(
    PrincipalMomentsFeedScope scope,
  ) async {
    scopes.add(scope);
    return const [
      PrincipalMomentPreviewItem(
        author: 'Equipe Coelo',
        context: 'Turma Girassol',
        time: 'ha 2 horas',
        caption: 'Piquenique da Turma Girassol',
        likes: 3,
        comments: 0,
        shares: 0,
        saves: 0,
        imageIndex: 0,
        publicationId: 'moment-1',
      ),
    ];
  }

  @override
  Future<void> withdrawMoment(String publicationId, {String? reason}) async =>
      throw const PrincipalMomentsWithdrawalUnavailable();
}
