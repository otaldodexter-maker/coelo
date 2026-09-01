import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('real Acontece resolves authenticated context and never uses demo fixtures', (
    tester,
  ) async {
    final session = SuperadminSession(isAuthenticated: true);
    final feed = _RecordingFeedRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      principalRuntimeContextRepository: const _ContextRepository(),
      principalHappensFeedRepository: feed,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.principalHappens);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    final page = tester.widget<PrincipalHappensPreviewPage>(
      find.byType(PrincipalHappensPreviewPage),
    );
    expect(page.data, same(PrincipalHappensPreviewData.empty));
    expect(feed.lastScope?.institutionId, 'institution-real');
    expect(feed.lastScope?.unitId, 'unit-real');
    expect(feed.lastScope?.groupId, 'group-real');
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.principalHappens);
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsNothing);

    await tester.tap(find.byKey(const Key('principal-happens-publish-now-action')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      SuperadminRoutes.principalNowPublication,
    );
    expect(router.routeInformationProvider.value.uri.path, isNot(startsWith('/dev/')));

    router.go(SuperadminRoutes.principalMomentsPublish);
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      SuperadminRoutes.principalMomentsPublish,
    );
    expect(router.routeInformationProvider.value.uri.path, isNot(startsWith('/dev/')));
  });
}

final class _ContextRepository implements PrincipalRuntimeContextRepository {
  const _ContextRepository();

  @override
  Future<List<PrincipalRuntimeContext>> listAvailableContexts() async => const [
    PrincipalRuntimeContext(
      membershipId: 'membership-real',
      personId: 'person-real',
      institutionId: 'institution-real',
      institutionName: 'Instituição Real',
      roleCode: 'guardian',
      scopeKind: 'group',
      unitId: 'unit-real',
      unitName: 'Unidade Real',
      groupId: 'group-real',
      groupName: 'Turma Real',
    ),
  ];
}

final class _RecordingFeedRepository implements PrincipalHappensFeedRepository {
  PrincipalHappensFeedScope? lastScope;

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) async {
    lastScope = scope;
    return const [];
  }

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) =>
      throw UnimplementedError();
}
