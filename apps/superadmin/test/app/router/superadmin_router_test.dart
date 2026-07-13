import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session notifies only when authentication changes', () {
    final session = SuperadminSession();
    var notifications = 0;
    session.addListener(() => notifications += 1);

    session.signOut();
    session.signIn();
    session.signIn();
    session.signOut();

    expect(notifications, 2);
    expect(session.isAuthenticated, isFalse);
  });

  testWidgets('starts on login and protects the shell without a session', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(session: session, login: unavailableSuperadminLogin);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Acesse sua conta'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);

    router.go(SuperadminRoutes.home);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
  });

  testWidgets('redirects authenticated sessions from login to the shell', (tester) async {
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: (_) async => const LoginResult.success(),
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.home);
    expect(find.text('Base inicial pronta'), findsOneWidget);
  });
}
