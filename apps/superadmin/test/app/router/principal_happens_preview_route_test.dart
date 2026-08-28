import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/presentation/principal_happens_publication_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the Acontece preview on a dedicated development route', () {
    expect(SuperadminRoutes.devPrincipalHappens, '/dev/principal-happens');
    expect(SuperadminRoutes.devPrincipalHappensName, 'dev-principal-happens');
    expect(SuperadminRoutes.devPrincipalHappens, isNot(SuperadminRoutes.devPrincipalProfile));
  });

  testWidgets('opens Acontece and its Perfil tab navigates to the profile preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
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

    router.go(SuperadminRoutes.devPrincipalHappens);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalHappensPreviewPage), findsOneWidget);
    expect(
      tester.widget<PrincipalHappensPreviewPage>(find.byType(PrincipalHappensPreviewPage)).embedded,
      isTrue,
    );
    expect(find.byKey(const Key('principal-happens-local-title')), findsNothing);
    await tester.tap(find.byKey(const Key('principal-happens-tab-perfil')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalProfile);
  });

  testWidgets('keeps Acontece embedded in one responsive shell at 200 percent text', (
    tester,
  ) async {
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
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      router.go(SuperadminRoutes.devPrincipalHappens);
      await tester.pumpWidget(
        MaterialApp.router(
          key: ValueKey(width),
          theme: CoeloTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      final page = tester.widget<PrincipalHappensPreviewPage>(
        find.byType(PrincipalHappensPreviewPage),
      );
      expect(page.embedded, isTrue, reason: '$width');
      expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);
      final content = find.byKey(const Key('superadmin-content-transition'));
      expect(content, findsOneWidget);
      expect(
        find.descendant(of: content, matching: find.byType(PrincipalHappensPreviewPage)),
        findsOneWidget,
      );
      expect(find.byKey(const Key('principal-happens-local-title')), findsNothing);
      expect(tester.takeException(), isNull, reason: '$width');

      if (width == 1440) {
        final sidebar = find.byKey(const Key('superadmin-sidebar'));
        expect(sidebar, findsOneWidget);
        expect(find.byKey(const Key('superadmin-floating-content')), findsOneWidget);
        expect(tester.getTopLeft(content).dx, greaterThan(tester.getTopRight(sidebar).dx));
      }
    }
  });

  testWidgets('composes the Acontece publisher inside the persistent shell container', (
    tester,
  ) async {
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

    router.go(SuperadminRoutes.devPrincipalHappensPublish);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    final page = tester.widget<PrincipalHappensPublicationPage>(
      find.byType(PrincipalHappensPublicationPage),
    );
    expect(page.embedded, isTrue);
  });
}
