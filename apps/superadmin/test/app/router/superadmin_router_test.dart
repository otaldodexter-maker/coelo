import 'dart:async';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/reset_password_action.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session notifies only when authentication changes', () {
    final session = SuperadminSession();
    var notifications = 0;
    session.addListener(() => notifications += 1);

    session.signOut();
    session.signInForTesting();
    session.signInForTesting();
    session.signOut();

    expect(notifications, 2);
    expect(session.isAuthenticated, isFalse);
  });

  test('session ignores an unvalidated authenticated event and mirrors sign-out', () async {
    final authStates = StreamController<bool>();
    addTearDown(authStates.close);
    final session = SuperadminSession(authStateChanges: authStates.stream);
    addTearDown(session.dispose);

    expect(session.isAuthenticated, isFalse);

    authStates.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(session.isAuthenticated, isFalse);

    authStates.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(session.isAuthenticated, isFalse);
  });

  test('session preserves recovery separately from a normal authenticated session', () async {
    final authStates = StreamController<CoeloAuthSessionState>();
    addTearDown(authStates.close);
    final session = SuperadminSession(authSessionStateChanges: authStates.stream);
    addTearDown(session.dispose);

    authStates.add(const CoeloAuthSessionState.passwordRecovery());
    await Future<void>.delayed(Duration.zero);
    expect(session.isAuthenticated, isFalse);
    expect(session.isPasswordRecovery, isTrue);

    authStates.add(const CoeloAuthSessionState.authenticated());
    await Future<void>.delayed(Duration.zero);
    expect(session.isAuthenticated, isFalse);
    expect(session.isPasswordRecovery, isTrue);

    session.authorize(
      const SuperadminAuthContext(
        platformRoleCode: 'operations',
        scopeKind: SuperadminAuthScopeKind.platform,
        permissionCodes: {'platform.read'},
        aal: 'aal1',
      ),
      sessionId: '11111111-1111-4111-8111-111111111111',
    );
    expect(session.isPasswordRecovery, isFalse);
    expect(session.authContext?.platformRoleCode, 'operations');
  });

  test('session invalidates an authorized context when session_id changes', () async {
    final authStates = StreamController<CoeloAuthSessionState>();
    addTearDown(authStates.close);
    final session = SuperadminSession(authSessionStateChanges: authStates.stream)
      ..signInForTesting();
    addTearDown(session.dispose);

    authStates.add(
      const CoeloAuthSessionState.authenticated(sessionId: '22222222-2222-4222-8222-222222222222'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(session.isAuthenticated, isFalse);
    expect(session.authContext, isNull);
  });

  test('session clears an authorized context when password recovery starts', () async {
    final authStates = StreamController<CoeloAuthSessionState>();
    addTearDown(authStates.close);
    final session = SuperadminSession(authSessionStateChanges: authStates.stream)
      ..signInForTesting();
    addTearDown(session.dispose);
    final staleRevision = session.authorizationInvalidationRevision;

    authStates.add(const CoeloAuthSessionState.passwordRecovery());
    await Future<void>.delayed(Duration.zero);

    expect(session.isAuthenticated, isFalse);
    expect(session.isPasswordRecovery, isTrue);
    expect(session.authContext, isNull);
    expect(session.authorizationInvalidationRevision, greaterThan(staleRevision));
    expect(
      session.authorizeIfCurrent(
        const SuperadminAuthContext(
          platformRoleCode: 'operations',
          scopeKind: SuperadminAuthScopeKind.platform,
          permissionCodes: {'platform.read'},
          aal: 'aal1',
        ),
        sessionId: '33333333-3333-4333-8333-333333333333',
        expectedInvalidationRevision: staleRevision,
      ),
      isFalse,
    );
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

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Acesse sua conta'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);

    router.go(SuperadminRoutes.home);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
  });

  testWidgets('keeps profile and settings inside the development preview', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    router.go(SuperadminRoutes.devInstitutions);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dev/profile');

    router.go(SuperadminRoutes.devInstitutions);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configura\u00e7\u00f5es'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dev/settings');
  });

  testWidgets('protects development preview when it is disabled', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      allowDevelopmentPreview: false,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devHome);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
  });

  testWidgets('redirects authenticated sessions from login to Home', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: (_) async => const LoginResult.success(),
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.home);
    expect(find.text('Como podemos ajudar?'), findsOneWidget);
  });

  testWidgets('opens Home from the global navigation and brand', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-navigation-section-structure')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-navigation-institutions')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.institutions);

    await tester.tap(find.byKey(const Key('superadmin-brand-home')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.home);
    expect(find.text('Como podemos ajudar?'), findsOneWidget);
  });

  testWidgets('redirects to login when an authenticated session signs out', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: (_) async => const LoginResult.success(),
      logout: () async {
        session.signOut();
        return const LogoutResult.success();
      },
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.home);

    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('superadmin-logout-dialog')),
        matching: find.text('Sair'),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
    expect(find.text('Acesse sua conta'), findsOneWidget);
  });

  testWidgets('redirects an authorized shell to reset when recovery starts at runtime', (
    tester,
  ) async {
    final authStates = StreamController<CoeloAuthSessionState>();
    addTearDown(authStates.close);
    final session = SuperadminSession(authSessionStateChanges: authStates.stream)
      ..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      resetPassword: unavailableResetPassword,
      institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.home);

    authStates.add(const CoeloAuthSessionState.passwordRecovery());
    await tester.pumpAndSettle();

    expect(session.isAuthenticated, isFalse);
    expect(session.isPasswordRecovery, isTrue);
    expect(session.authContext, isNull);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.resetPassword);
    expect(find.text('Crie uma nova senha'), findsOneWidget);
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

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
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
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.forgotPassword);
    expect(find.text('Recupere seu acesso'), findsOneWidget);
  });

  testWidgets('shows an invalid state for direct reset access without recovery', (tester) async {
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
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.resetPassword);
    expect(find.text('Este link não é mais válido'), findsOneWidget);
  });

  testWidgets('keeps a valid recovery session on reset instead of redirecting home', (
    tester,
  ) async {
    final session = SuperadminSession(isPasswordRecovery: true);
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
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.resetPassword);
    expect(find.text('Crie uma nova senha'), findsOneWidget);
  });

  testWidgets('starts a recovery session on reset instead of the initial login route', (
    tester,
  ) async {
    final session = SuperadminSession(isPasswordRecovery: true);
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

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.resetPassword);
    expect(find.text('Crie uma nova senha'), findsOneWidget);
  });

  testWidgets('revokes a recovery session before returning to login', (tester) async {
    final session = SuperadminSession(isPasswordRecovery: true);
    var logoutCalls = 0;
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: () async {
        logoutCalls++;
        session.signOut();
        return const LogoutResult.success();
      },
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      resetPassword: unavailableResetPassword,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar para entrar'));
    await tester.pumpAndSettle();

    expect(logoutCalls, 1);
    expect(session.isPasswordRecovery, isFalse);
    expect(session.isAuthenticated, isFalse);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
  });

  testWidgets('keeps recovery confined when revocation before login fails', (tester) async {
    final session = SuperadminSession(isPasswordRecovery: true);
    var logoutCalls = 0;
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: () async {
        logoutCalls++;
        return const LogoutResult.failure(LogoutResult.genericFailureMessage);
      },
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      resetPassword: unavailableResetPassword,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar para entrar'));
    await tester.pumpAndSettle();

    expect(logoutCalls, 1);
    expect(session.isPasswordRecovery, isTrue);
    expect(session.isAuthenticated, isFalse);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.resetPassword);
  });

  testWidgets('confines a recovery session to reset when Home is requested', (tester) async {
    final session = SuperadminSession(isPasswordRecovery: true);
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

    router.go(SuperadminRoutes.home);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.resetPassword);
    expect(find.text('Crie uma nova senha'), findsOneWidget);
  });

  testWidgets('confines a recovery session to reset when a protected route is requested', (
    tester,
  ) async {
    final session = SuperadminSession(isPasswordRecovery: true);
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      resetPassword: unavailableResetPassword,
      institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.institutions);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.resetPassword);
    expect(find.text('Crie uma nova senha'), findsOneWidget);
  });

  testWidgets('confines a recovery session before development preview routes', (tester) async {
    final session = SuperadminSession(isPasswordRecovery: true);
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      resetPassword: unavailableResetPassword,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devHome);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.resetPassword);
    expect(find.text('Crie uma nova senha'), findsOneWidget);
  });

  testWidgets('redirects authenticated recovery visits to the shell', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.forgotPassword);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.home);
  });
}
