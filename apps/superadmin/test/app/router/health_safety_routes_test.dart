import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares the authenticated health and safety routes', () {
    expect(SuperadminRoutes.healthSafety, '/health-safety');
    expect(SuperadminRoutes.healthSafetyDetail, '/health-safety/:childId');
  });

  testWidgets('exposes Health and Safety as an active Operations destination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? selectedDestination;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: unavailableSuperadminLogout,
          currentDestination: 'health-safety',
          onDestinationSelected: (destination) => selectedDestination = destination,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final destination = find.byKey(const Key('superadmin-navigation-health-safety'));
    expect(destination, findsOneWidget);
    await tester.tap(destination);
    expect(selectedDestination, 'health-safety');
  });

  testWidgets('protects and opens directory and child detail', (tester) async {
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

    router.go(SuperadminRoutes.healthSafety);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);

    session.signIn();
    router.go(SuperadminRoutes.healthSafety);
    await tester.pumpAndSettle();
    expect(find.text('Saúde e Segurança'), findsWidgets);

    router.go('/health-safety/child-demo-a');
    await tester.pumpAndSettle();
    expect(find.text('Medicamentos'), findsOneWidget);
  });
}
