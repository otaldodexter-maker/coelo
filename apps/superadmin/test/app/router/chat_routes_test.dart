import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/chat/data/development_chat_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('protects conversations and exposes a sessionless dev preview', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
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

    router.go(SuperadminRoutes.conversations);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);

    router.go(SuperadminRoutes.devConversations);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devConversations);
    expect(find.text('Turma Girassol'), findsWidgets);
    expect(find.text('Coordenação Pedagógica'), findsWidgets);
    expect(find.text('Nao foi possivel carregar'), findsNothing);
    expect(find.byTooltip('Abrir menu de desenvolvimento'), findsOneWidget);
    expect(find.byTooltip('Voltar'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devInstitutions);
  });

  testWidgets('launcher in the persistent shell opens the conversations URI', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
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

    router.go(SuperadminRoutes.devInstitutions);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
    expect(launcher, findsOneWidget);
    await tester.tap(launcher);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devConversations);
    expect(launcher, findsNothing);
  });

  testWidgets('Coelo Principal Chat reuses the dev conversations route and repository', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1200);
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

    router.go(SuperadminRoutes.devPrincipalHappens);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    final navigationScroll = find.descendant(
      of: find.byKey(const Key('superadmin-navigation-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('superadmin-navigation-section-principal')),
      240,
      scrollable: navigationScroll,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('superadmin-navigation-principal-chat')),
      120,
      scrollable: navigationScroll,
    );
    await tester.tap(find.byKey(const Key('superadmin-navigation-principal-chat')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devConversations);
    expect(router.routeInformationProvider.value.uri.queryParameters['from'], 'principal');
    expect(find.text('Turma Girassol'), findsWidgets);
    expect(find.text('Coordenação Pedagógica'), findsWidgets);
    expect(
      find.byKey(const Key('superadmin-chat-launcher-surface')),
      findsNothing,
      reason: 'O Chat aberto por Coelo (Principal) já é a superfície de conversas.',
    );

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalHappens);
  });

  testWidgets('sidebar item opens conversations without replacing the development shell', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
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

    router.go(SuperadminRoutes.devInstitutions);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    final shellBefore = tester.state(find.byKey(const Key('superadmin-persistent-shell')));

    final navigationScroll = find.descendant(
      of: find.byKey(const Key('superadmin-navigation-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('superadmin-navigation-section-communication')),
      240,
      scrollable: navigationScroll,
    );
    await tester.tap(find.byKey(const Key('superadmin-navigation-section-communication')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('superadmin-navigation-conversations')),
      120,
      scrollable: navigationScroll,
    );
    await tester.tap(find.byKey(const Key('superadmin-navigation-conversations')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devConversations);
    expect(tester.state(find.byKey(const Key('superadmin-persistent-shell'))), same(shellBefore));
  });

  testWidgets('conversation sidebar can navigate to activities in dev and production', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final authenticated in <bool>[false, true]) {
      final session = SuperadminSession();
      if (authenticated) session.signIn();
      final router = createSuperadminRouter(
        session: session,
        login: (_) async => const LoginResult.success(),
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);

      router.go(authenticated ? SuperadminRoutes.conversations : SuperadminRoutes.devConversations);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('superadmin-navigation-section-structure')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('superadmin-navigation-activities')));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        authenticated ? SuperadminRoutes.activities : SuperadminRoutes.devActivities,
      );
    }
  });

  testWidgets('opens protected conversations for an authenticated session', (tester) async {
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: (_) async => const LoginResult.success(),
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.conversations);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.conversations);
    expect(find.text('Nao foi possivel carregar'), findsOneWidget);
    expect(find.byTooltip('Voltar'), findsOneWidget);
    expect(find.byTooltip('Abrir menu de desenvolvimento'), findsNothing);
  });

  testWidgets('protected conversations use the injected production repository', (tester) async {
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: (_) async => const LoginResult.success(),
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      chatRepository: DevelopmentChatRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.conversations);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Turma Girassol'), findsWidgets);
    expect(find.text('Nao foi possivel carregar'), findsNothing);
  });
}
