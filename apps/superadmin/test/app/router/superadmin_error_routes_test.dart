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
  testWidgets('development errors remain disabled without the preview flag', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      allowDevelopmentPreview: false,
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.devErrorLocation('503'));
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('503'), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
  });
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
        allowDevelopmentPreview: true,
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
      expect(find.text('Tentar novamente'), findsNothing);
      await tester.tap(find.text('Voltar ao início'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devHome);
    });
  }

  for (final path in const [
    SuperadminRoutes.institutionCreate,
    SuperadminRoutes.healthMedicationPlans,
    SuperadminRoutes.profileModels,
    '/students/synthetic-context/manage',
    SuperadminRoutes.support,
  ]) {
    testWidgets('unavailable $path labels and performs home navigation', (tester) async {
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
      router.go(path);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('503'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsNothing);
      await tester.tap(find.text('Voltar ao início'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.home);
    });
  }

  testWidgets('unavailable student preview returns only to preview home', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      allowDevelopmentPreview: true,
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go('/dev/students/synthetic-context/manage');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('503'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    await tester.tap(find.text('Voltar ao início'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devHome);
  });

  testWidgets('unsupported development error code falls back to 404', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      allowDevelopmentPreview: true,
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
