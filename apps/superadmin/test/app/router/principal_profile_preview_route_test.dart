import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the principal profile preview separate from the account profile', () {
    expect(SuperadminRoutes.devPrincipalProfile, '/dev/principal-profile');
    expect(SuperadminRoutes.devPrincipalProfileName, 'dev-principal-profile');
    expect(SuperadminRoutes.devPrincipalProfile, isNot(SuperadminRoutes.devProfile));
  });

  testWidgets('opens the preview route and navigates its agenda entry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
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

    router.go(SuperadminRoutes.devPrincipalProfile);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(PrincipalProfilePreviewPage), findsOneWidget);
    expect(
      tester.widget<PrincipalProfilePreviewPage>(find.byType(PrincipalProfilePreviewPage)).embedded,
      isFalse,
    );
    await tester.ensureVisible(find.byKey(const Key('principal-profile-open-agenda')));
    await tester.tap(find.byKey(const Key('principal-profile-open-agenda')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devAgenda);
  });

  testWidgets('keeps Perfil in its Principal surface at 200 percent text', (tester) async {
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
      router.go(SuperadminRoutes.devPrincipalProfile);
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

      final page = tester.widget<PrincipalProfilePreviewPage>(
        find.byType(PrincipalProfilePreviewPage),
      );
      expect(page.embedded, isFalse, reason: '$width');
      expect(find.byKey(const Key('superadmin-persistent-shell')), findsNothing);
      expect(find.byKey(const Key('principal-global-dock')), findsOneWidget);
      for (final key in [
        'principal-profile-logo',
        'principal-profile-report-problem',
        'principal-profile-notifications',
        'principal-profile-context-avatar',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: '$width');
      }
      expect(tester.takeException(), isNull, reason: '$width');
    }
  });
}
