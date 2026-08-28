import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/principal_for_you/presentation/principal_for_you_preview_page.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps Para você on a dedicated development route', () {
    expect(SuperadminRoutes.devPrincipalForYou, '/dev/principal-for-you');
    expect(SuperadminRoutes.devPrincipalForYouName, 'dev-principal-for-you');
  });

  testWidgets('opens Para você from Acontece and returns through its navigation', (tester) async {
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

    await tester.tap(find.byKey(const Key('principal-happens-tab-for-you')));
    await tester.pumpAndSettle();
    expect(find.byType(PrincipalForYouPreviewPage), findsOneWidget);
    expect(
      tester.widget<PrincipalForYouPreviewPage>(find.byType(PrincipalForYouPreviewPage)).embedded,
      isTrue,
    );
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPrincipalForYou);

    await tester.tap(find.byKey(const Key('superadmin-mobile-menu')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('superadmin-navigation-search')), 'Acontece');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-navigation-principal-happens')));
    await tester.pumpAndSettle();
    expect(find.byType(PrincipalHappensPreviewPage), findsOneWidget);
  });

  testWidgets('keeps Para você embedded in one responsive shell at 200 percent text', (
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
      router.go(SuperadminRoutes.devPrincipalForYou);
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

      final page = tester.widget<PrincipalForYouPreviewPage>(
        find.byType(PrincipalForYouPreviewPage),
      );
      expect(page.embedded, isTrue, reason: '$width');
      expect(find.byKey(const Key('superadmin-persistent-shell')), findsOneWidget);
      final content = find.byKey(const Key('superadmin-content-transition'));
      expect(content, findsOneWidget);
      expect(
        find.descendant(of: content, matching: find.byType(PrincipalForYouPreviewPage)),
        findsOneWidget,
      );
      expect(find.byKey(const Key('principal-for-you-desktop-rail')), findsNothing);
      expect(find.byKey(const Key('principal-for-you-mobile-nav')), findsNothing);
      expect(tester.takeException(), isNull, reason: '$width');

      if (width == 1440) {
        final sidebar = find.byKey(const Key('superadmin-sidebar'));
        expect(sidebar, findsOneWidget);
        expect(find.byKey(const Key('superadmin-floating-content')), findsOneWidget);
        expect(tester.getTopLeft(content).dx, greaterThan(tester.getTopRight(sidebar).dx));
      }
    }
  });
}
