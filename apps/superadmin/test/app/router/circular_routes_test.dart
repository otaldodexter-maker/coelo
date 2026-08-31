import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/circulars/presentation/circular_directory_page.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_composer_page.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps Circulares on explicit development routes', () {
    expect(SuperadminRoutes.circulars, '/circulars');
    expect(SuperadminRoutes.circularCreate, '/circulars/new');
    expect(SuperadminRoutes.circularDetail, '/circulars/:circularId/read');
    expect(SuperadminRoutes.devCirculars, '/dev/circulars');
    expect(SuperadminRoutes.devCircularCreate, '/dev/circulars/new');
    expect(SuperadminRoutes.devCircularDetail, '/dev/circulars/:circularId/read');
  });

  testWidgets('production Circular detail route is reachable and fails closed honestly', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go('/circulars/circular-1/read');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalCircularDetailPage), findsOneWidget);
    expect(find.text('Não foi possível carregar esta Circular.'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsNothing);
  });

  testWidgets('published Circular opens its reader and returns to the directory', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devCirculars);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    final trigger = find.bySemanticsLabel('Abrir Circular Renovação de matrícula');
    await tester.ensureVisible(trigger);
    final card = find.descendant(of: trigger, matching: find.byType(InkWell));
    final originFocus = tester.widget<InkWell>(card.first).focusNode!;
    originFocus.requestFocus();
    await tester.pump();
    tester
        .widget<CircularDirectoryPage>(find.byType(CircularDirectoryPage))
        .onOpen('circular-published');
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalCircularDetailPage), findsOneWidget);
    expect(find.textContaining('Confirme a renovação para o próximo ano'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsNothing);

    await tester.tap(find.byKey(const Key('principal-circular-contextual-return')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devCirculars);
    expect(find.byType(CircularDirectoryPage), findsOneWidget);
    expect(originFocus.hasFocus, isTrue);
  });

  testWidgets('Escape closes the compact Circular reader and restores its trigger focus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devCirculars);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    final trigger = find.bySemanticsLabel('Abrir Circular Renovação de matrícula');
    await tester.ensureVisible(trigger);
    final card = find.descendant(of: trigger, matching: find.byType(InkWell));
    final originFocus = tester.widget<InkWell>(card.first).focusNode!;
    originFocus.requestFocus();
    await tester.pump();
    tester
        .widget<CircularDirectoryPage>(find.byType(CircularDirectoryPage))
        .onOpen('circular-published');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devCirculars);
    expect(find.byType(CircularDirectoryPage), findsOneWidget);
    expect(originFocus.hasFocus, isTrue);
  });

  testWidgets('production navigation reaches the fail-closed directory and blocks creation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.notices);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-navigation-circulars')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.circulars);
    expect(find.byType(CircularDirectoryPage), findsOneWidget);
    expect(find.text('Sem permissão'), findsOneWidget);
    expect(find.text('Nova circular'), findsNothing);

    router.go(SuperadminRoutes.circularCreate);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/errors/mutation-capability-unavailable',
    );
    expect(find.byType(SuperadminErrorScreen), findsOneWidget);
    expect(find.byType(PrincipalCircularComposerPage), findsNothing);
  });

  testWidgets('directory reaches the Circular composer and cancel returns to origin', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devCirculars);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(CircularDirectoryPage), findsOneWidget);
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-circular-banner')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devCircularCreate);
    expect(find.byType(PrincipalCircularComposerPage), findsOneWidget);
    await tester.tap(find.byKey(const Key('circular-cancel')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devCirculars);
  });

  testWidgets('development navigation exposes the Circulares directory', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devNotices);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-navigation-circulars')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devCirculars);
    expect(find.byType(CircularDirectoryPage), findsOneWidget);
  });

  testWidgets('composer route is explicitly local and fails closed on save', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devCircularCreate);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('circular-save-draft')));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível concluir. Tente novamente.'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devCircularCreate);
  });
}
