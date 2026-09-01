import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/circulars/presentation/circular_directory_page.dart';
import 'package:coelo_superadmin/features/circulars/presentation/development_circular_composer_host.dart';
import 'package:coelo_superadmin/features/circulars/presentation/superadmin_circular_composer_page.dart';
import 'package:coelo_superadmin/features/circulars/presentation/superadmin_circular_detail_page.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('keeps production and development Circular routes explicit', () {
    expect(SuperadminRoutes.circulars, '/circulars');
    expect(SuperadminRoutes.circularCreate, '/circulars/new');
    expect(SuperadminRoutes.circularDetail, '/circulars/:circularId/read');
    expect(SuperadminRoutes.circularEdit, '/circulars/:circularId/edit');
    expect(SuperadminRoutes.devCirculars, '/dev/circulars');
    expect(SuperadminRoutes.devCircularCreate, '/dev/circulars/new');
    expect(SuperadminRoutes.devCircularDetail, '/dev/circulars/:circularId/read');
    expect(SuperadminRoutes.devCircularEdit, '/dev/circulars/:circularId/edit');
  });

  testWidgets('production detail stays inside the admin shell and fails closed', (tester) async {
    final fixture = await _pumpRouter(tester, size: const Size(375, 900), authenticated: true);
    fixture.router.go('/circulars/circular-1/read');
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminCircularDetailPage), findsOneWidget);
    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);
  });

  testWidgets('development Circular opens an administrative detail and returns', (tester) async {
    final fixture = await _pumpRouter(tester, size: const Size(375, 900));
    fixture.router.go(SuperadminRoutes.devCirculars);
    await tester.pumpAndSettle();

    tester
        .widget<CircularDirectoryPage>(find.byType(CircularDirectoryPage))
        .onOpen('renovacao-2027');
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminCircularDetailPage), findsOneWidget);
    expect(find.text('Renovação de matrícula 2027'), findsOneWidget);
    expect(find.textContaining('Confirme a renovação até 30 de setembro'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);

    await tester.tap(find.byKey(const Key('circular-detail-back')));
    await tester.pumpAndSettle();
    expect(fixture.router.routeInformationProvider.value.uri.path, SuperadminRoutes.devCirculars);
  });

  testWidgets('Escape closes the compact administrative Circular detail', (tester) async {
    final fixture = await _pumpRouter(tester, size: const Size(375, 900));
    fixture.router.go('/dev/circulars/renovacao-2027/read');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(fixture.router.routeInformationProvider.value.uri.path, SuperadminRoutes.devCirculars);
    expect(find.byType(CircularDirectoryPage), findsOneWidget);
  });

  testWidgets('production directory, create and edit remain fail closed', (tester) async {
    final fixture = await _pumpRouter(tester, size: const Size(1440, 900), authenticated: true);
    fixture.router.go(SuperadminRoutes.circulars);
    await tester.pumpAndSettle();

    expect(find.text('Sem permissão'), findsOneWidget);
    expect(find.text('Nova circular'), findsNothing);

    for (final location in [SuperadminRoutes.circularCreate, '/circulars/circular-1/edit']) {
      fixture.router.go(location);
      await tester.pumpAndSettle();
      expect(
        fixture.router.routeInformationProvider.value.uri.path,
        '/errors/mutation-capability-unavailable',
      );
      expect(find.byType(SuperadminErrorScreen), findsOneWidget);
      expect(find.byType(DevelopmentCircularComposerHost), findsNothing);
    }
  });

  testWidgets('directory reaches the administrative composer and cancel returns', (tester) async {
    final fixture = await _pumpRouter(tester, size: const Size(1024, 900));
    fixture.router.go(SuperadminRoutes.devCirculars);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-circular-banner')));
    await tester.pumpAndSettle();

    expect(
      fixture.router.routeInformationProvider.value.uri.path,
      SuperadminRoutes.devCircularCreate,
    );
    expect(find.byType(SuperadminCircularComposerPage), findsOneWidget);
    await tester.tap(find.byKey(const Key('circular-cancel')));
    await tester.pumpAndSettle();
    expect(fixture.router.routeInformationProvider.value.uri.path, SuperadminRoutes.devCirculars);
  });

  testWidgets('development create persists a draft and reloads the directory', (tester) async {
    final fixture = await _pumpRouter(tester, size: const Size(768, 1000));
    fixture.router.go(SuperadminRoutes.devCircularCreate);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('circular-title')), 'Feira de Ciências 2026');
    await tester.enterText(
      find.byKey(const Key('circular-body')),
      'Programação das oficinas, apresentações e horários de visitação.',
    );
    await tester.tap(find.byKey(const Key('circular-save-draft')));
    await tester.pumpAndSettle();
    expect(find.text('Rascunho salvo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('circular-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Feira de Ciências 2026'), findsWidgets);
  });

  testWidgets('development detail edits and reloads the same Circular', (tester) async {
    final fixture = await _pumpRouter(tester, size: const Size(1024, 1000));
    fixture.router.go('/dev/circulars/renovacao-2027/read');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('circular-detail-edit')));
    await tester.pumpAndSettle();
    expect(
      fixture.router.routeInformationProvider.value.uri.path,
      '/dev/circulars/renovacao-2027/edit',
    );

    await tester.enterText(
      find.byKey(const Key('circular-title')),
      'Renovação de matrícula 2027 — prazo ampliado',
    );
    await tester.tap(find.byKey(const Key('circular-save-draft')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('circular-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('Renovação de matrícula 2027 — prazo ampliado'), findsOneWidget);
  });

  testWidgets('development navigation exposes the Circulares directory', (tester) async {
    final fixture = await _pumpRouter(tester, size: const Size(1440, 900));
    fixture.router.go(SuperadminRoutes.devNotices);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-navigation-circulars')));
    await tester.pumpAndSettle();

    expect(fixture.router.routeInformationProvider.value.uri.path, SuperadminRoutes.devCirculars);
    expect(find.byType(CircularDirectoryPage), findsOneWidget);
  });
}

Future<({GoRouter router, SuperadminSession session})> _pumpRouter(
  WidgetTester tester, {
  required Size size,
  bool authenticated = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final session = SuperadminSession();
  if (authenticated) session.signIn();
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
  await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
  return (router: router, session: session);
}
