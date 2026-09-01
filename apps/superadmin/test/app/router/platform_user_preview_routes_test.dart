import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('recognizes only implemented internal-user preview routes', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final entry in <String, String>{
      SuperadminRoutes.devInternalUsers: SuperadminRoutes.devInternalUsers,
      SuperadminRoutes.devInternalUserCreate: SuperadminRoutes.devInternalUserCreate,
      '/dev/internal-users/dev-guardian-0001/edit': '/dev/internal-users/dev-guardian-0001/edit',
    }.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, entry.value);
      expect(find.textContaining('Usuário interno não encontrado'), findsNothing);
    }

    router.go('/dev/internal-users/dev-guardian-0001');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dev/internal-users/dev-guardian-0001');
    expect(find.text('404'), findsOneWidget);

    router.go('/dev/internal-users/dev-guardian-0001/edit');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devInternalUsers);
  });

  testWidgets('production internal-user routes fail closed without the fake repository', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    router.go('/internal-users');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.internalUsers);
    expect(find.text('503'), findsOneWidget);
    expect(find.text('Usuários internos'), findsNothing);

    router.go(SuperadminRoutes.internalUserCreate);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsOneWidget);

    router.go('/internal-users/unknown/edit');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsOneWidget);
  });
}
