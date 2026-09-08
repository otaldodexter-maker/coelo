import 'package:coelo_superadmin/app/navigation/superadmin_navigation.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final width in [839.0, 840.0, 1440.0]) {
    testWidgets('logout removes authenticated navigation at width $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
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
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.home);
      session.signOut();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
      expect(find.byType(CoeloNavigationContent), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('navigation without router uses production availability', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: CoeloTheme.light, home: _navigationHost()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Cardápios');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum item de navegação encontrado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mounted navigation follows production preview production URI changes', (
    tester,
  ) async {
    final navigationKey = GlobalKey();
    final navigation = _navigationHost(key: navigationKey);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => navigation,
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
            GoRoute(path: '/dev/home', builder: (_, _) => const SizedBox()),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    final originalElement = navigationKey.currentContext;
    await tester.enterText(find.byType(TextField), 'Cardápios');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum item de navegação encontrado.'), findsOneWidget);
    router.go('/dev/home');
    await tester.pumpAndSettle();
    expect(navigationKey.currentContext, same(originalElement));
    expect(
      find.descendant(
        of: find.byKey(const Key('superadmin-navigation-scroll')),
        matching: find.text('Cardápios'),
      ),
      findsOneWidget,
    );
    router.go('/home');
    await tester.pumpAndSettle();
    expect(navigationKey.currentContext, same(originalElement));
    expect(find.text('Nenhum item de navegação encontrado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('mounted navigation follows MaterialApp router replacement', (tester) async {
    final navigationKey = GlobalKey();
    final navigation = _navigationHost(key: navigationKey);
    GoRouter createRouter(String path) => GoRouter(
      initialLocation: path,
      routes: [
        ShellRoute(
          builder: (_, _, _) => navigation,
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
            GoRoute(path: '/dev/home', builder: (_, _) => const SizedBox()),
          ],
        ),
      ],
    );
    final first = createRouter('/home');
    final second = createRouter('/dev/home');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: first));
    await tester.pumpAndSettle();
    final element = navigationKey.currentContext;
    await tester.enterText(find.byType(TextField), 'Cardápios');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum item de navegação encontrado.'), findsOneWidget);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: second));
    await tester.pumpAndSettle();
    expect(navigationKey.currentContext, same(element));
    expect(find.text('Nenhum item de navegação encontrado.'), findsNothing);
    second.go('/home');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum item de navegação encontrado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('router replacement and removal detach navigation listeners', (tester) async {
    GoRouter createRouter(String path) => GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/dev/home', builder: (_, _) => const SizedBox()),
      ],
    );
    final first = createRouter('/home');
    final second = createRouter('/dev/home');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    expect(_hasListeners(first), isFalse);
    expect(_hasListeners(second), isFalse);
    final navigationKey = GlobalKey();
    final navigation = _navigationHost(key: navigationKey);
    Widget host(GoRouter? router) => MaterialApp(
      theme: CoeloTheme.light,
      home: router == null
          ? navigation
          : InheritedGoRouter(key: ObjectKey(router), goRouter: router, child: navigation),
    );
    await tester.pumpWidget(host(first));
    await tester.pumpAndSettle();
    final element = navigationKey.currentContext;
    await tester.enterText(find.byType(TextField), 'Cardápios');
    await tester.pumpAndSettle();
    expect(_hasListeners(first), isTrue);
    expect(find.text('Nenhum item de navegação encontrado.'), findsOneWidget);
    await tester.pumpWidget(host(second));
    await tester.pumpAndSettle();
    expect(navigationKey.currentContext, same(element));
    expect(_hasListeners(first), isFalse);
    expect(_hasListeners(second), isTrue);
    expect(find.text('Nenhum item de navegação encontrado.'), findsNothing);
    await tester.pumpWidget(host(null));
    await tester.pumpAndSettle();
    expect(navigationKey.currentContext, same(element));
    expect(_hasListeners(second), isFalse);
    expect(find.text('Nenhum item de navegação encontrado.'), findsOneWidget);
    await tester.pumpWidget(host(first));
    await tester.pumpAndSettle();
    expect(_hasListeners(first), isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(_hasListeners(first), isFalse);
    first.go('/dev/home');
    second.go('/home');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

// Test-only leak probe: a standalone provider has no framework listeners.
// ignore: invalid_use_of_protected_member
bool _hasListeners(GoRouter router) => router.routeInformationProvider.hasListeners;

Widget _navigationHost({Key? key}) => Scaffold(
  key: key,
  body: const SizedBox(
    width: 320,
    child: CoeloNavigationContent(
      collapsed: false,
      currentDestination: 'home',
      onDestinationSelected: null,
    ),
  ),
);
