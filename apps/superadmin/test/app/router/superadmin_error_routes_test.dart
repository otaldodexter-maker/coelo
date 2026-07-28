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
  testWidgets('unknown unauthenticated URL still redirects to login', (tester) async {
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

    router.go('/area/que-nao-existe');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
    expect(find.text('Acesse sua conta'), findsOneWidget);
  });

  testWidgets('unknown authenticated URL renders 404 and preserves the URL', (tester) async {
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go('/area/que-nao-existe');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/area/que-nao-existe');
    expect(find.text('404'), findsOneWidget);
    expect(find.text('Não encontramos a página que você procura.'), findsOneWidget);
  });

  for (final code in const ['403', '404', '500', '503']) {
    testWidgets('development error route renders $code', (tester) async {
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

      router.go(SuperadminRoutes.devErrorLocation(code));
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text(code), findsOneWidget);
    });
  }

  testWidgets('unsupported development error code falls back to 404', (tester) async {
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

    router.go(SuperadminRoutes.devErrorLocation('418'));
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('404'), findsOneWidget);
  });
}
