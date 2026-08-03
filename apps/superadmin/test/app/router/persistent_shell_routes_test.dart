import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('keeps one shell instance and its geometry between protected destinations', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.institutions);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    final shell = find.byKey(const Key('superadmin-persistent-shell'));
    final initialState = tester.state(shell);
    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('superadmin-sidebar'))).width, 88);

    router.go(SuperadminRoutes.support);
    await tester.pumpAndSettle();
    await tester.pump();

    expect(tester.state(shell), same(initialState));
    expect(tester.getSize(find.byKey(const Key('superadmin-sidebar'))).width, 88);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-page-content')), findsOneWidget);
  });

  testWidgets('swaps protected content without a perceptible opacity transition', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.institutions);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    router.go(SuperadminRoutes.support);
    await tester.pumpAndSettle();
    final content = find.byKey(const Key('superadmin-content-transition'));
    expect(content, findsOneWidget);
    expect(tester.widget(content), isA<KeyedSubtree>());
    expect(find.byKey(const Key('support-page-content')), findsOneWidget);
  });

  testWidgets('switches protected content immediately under reduced motion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.institutions);
    await tester.pumpWidget(_app(router, disableAnimations: true));
    await tester.pump();

    router.go(SuperadminRoutes.support);
    await tester.pump();
    await tester.pump();

    final content = find.byKey(const Key('superadmin-content-transition'));
    expect(content, findsOneWidget);
    expect(tester.widget(content), isA<KeyedSubtree>());
    expect(find.byKey(const Key('support-page-content')), findsOneWidget);
  });

  testWidgets('routes Support and Catalog consistently from the persistent navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go(SuperadminRoutes.unitCreate);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-navigation-section-governance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-navigation-support')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.support);

    await tester.tap(find.byKey(const Key('superadmin-navigation-section-structure')));
    await tester.pumpAndSettle();
    final catalog = find.byKey(const Key('superadmin-navigation-catalog'));
    await tester.tap(catalog);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.governanceCatalog);
  });
}

GoRouter _router(SuperadminSession session) => createSuperadminRouter(
  session: session,
  login: (_) async => const LoginResult.success(),
  logout: unavailableSuperadminLogout,
  requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
  institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
  onThemeModeChanged: (_) {},
);

Widget _app(GoRouter router, {bool disableAnimations = false}) {
  return MaterialApp.router(
    theme: CoeloTheme.light,
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
  );
}
