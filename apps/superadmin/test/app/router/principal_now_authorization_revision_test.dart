import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_image_repository.dart';
import 'package:coelo_superadmin/features/principal_now/domain/principal_now_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Revisao de autorizacao no visualizador do Agora.
///
/// Acontece e Momentos releem o feed quando a autorizacao do ator e invalidada;
/// o Agora nao relia, e mantinha em tela conteudo obtido sob um contexto que ja
/// nao valia. Estas provas fixam a mesma invariante para a rota normal.
void main() {
  testWidgets('a rota do Agora consome o feed sob o escopo real do contexto', (tester) async {
    final feed = _NowFeedRepository();
    final fixture = await _pumpRouter(tester, feed);
    fixture.router.go(SuperadminRoutes.principalNow);
    await tester.pumpAndSettle();

    expect(feed.scopes, hasLength(1));
    expect(feed.scopes.single.institutionId, 'institution-real');
    expect(feed.scopes.single.unitId, 'unit-real');
    expect(feed.scopes.single.groupId, 'group-real');
  });

  testWidgets('a revisao de autorizacao relê o Agora em vez de manter o anterior', (tester) async {
    final feed = _NowFeedRepository();
    final fixture = await _pumpRouter(tester, feed);
    fixture.router.go(SuperadminRoutes.principalNow);
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

    expect(
      feed.scopes.length,
      greaterThan(1),
      reason: 'o Agora precisa reler quando a autorizacao muda',
    );
  });
}

Future<({GoRouter router, SuperadminSession session})> _pumpRouter(
  WidgetTester tester,
  PrincipalNowFeedRepository feed,
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
    principalNowFeedRepository: feed,
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

final class _NowFeedRepository implements PrincipalNowFeedRepository {
  final scopes = <PrincipalNowFeedScope>[];

  @override
  Future<List<PrincipalNowFeedItem>> listVisibleStories(PrincipalNowFeedScope scope) async {
    scopes.add(scope);
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
