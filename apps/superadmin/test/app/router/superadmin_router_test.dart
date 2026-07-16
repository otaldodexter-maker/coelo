import 'dart:async';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
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

  test('session mirrors authentication state changes from a bound auth stream', () async {
    final authStates = StreamController<bool>();
    addTearDown(authStates.close);
    final session = SuperadminSession(authStateChanges: authStates.stream);
    addTearDown(session.dispose);

    expect(session.isAuthenticated, isFalse);

    authStates.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(session.isAuthenticated, isTrue);

    authStates.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(session.isAuthenticated, isFalse);
  });

  testWidgets('starts on login and protects the shell without a session', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      onThemeModeChanged: (_) {},
    );
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
      logout: unavailableSuperadminLogout,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.home);
    expect(find.text('Base inicial pronta'), findsOneWidget);
  });

  testWidgets('redirects to login when an authenticated session signs out', (tester) async {
    final session = SuperadminSession(isAuthenticated: true);
    final router = createSuperadminRouter(
      session: session,
      login: (_) async => const LoginResult.success(),
      logout: () async {
        session.signOut();
        return const LogoutResult.success();
      },
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.home);

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
    expect(find.text('Acesse sua conta'), findsOneWidget);
  });
}
