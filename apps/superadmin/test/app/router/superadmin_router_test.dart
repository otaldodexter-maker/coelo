import 'dart:async';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/reset_password_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
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
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
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
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: const FakeInstitutionDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.institutions);
    expect(find.text('Instituto Aurora'), findsOneWidget);
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
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: const FakeInstitutionDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.institutions);

    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-logout-action')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
    expect(find.text('Acesse sua conta'), findsOneWidget);
  });

  testWidgets('opens password recovery publicly and returns to login', (tester) async {
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

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.forgotPassword);
    expect(find.text('Recupere seu acesso'), findsOneWidget);

    await tester.tap(find.text('Voltar para entrar'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
  });

  testWidgets('allows direct public access to password recovery', (tester) async {
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

    router.go(SuperadminRoutes.forgotPassword);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.forgotPassword);
    expect(find.text('Recupere seu acesso'), findsOneWidget);
  });

  testWidgets('allows direct public access to reset password', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      resetPassword: unavailableResetPassword,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.resetPassword);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.resetPassword);
    expect(find.text('Crie uma nova senha'), findsOneWidget);
  });

  testWidgets('redirects authenticated recovery visits to the shell', (tester) async {
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: const FakeInstitutionDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.forgotPassword);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.institutions);
  });
}
