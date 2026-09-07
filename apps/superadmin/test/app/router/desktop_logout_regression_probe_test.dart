import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Opt-in diagnostic: the layout hang can prevent the fake-async timeout from
// firing. Run separately and interrupt the process if it stalls at logout.
// flutter test --dart-define=RUN_DESKTOP_LOGOUT_PROBE=true
//   test/app/router/desktop_logout_regression_probe_test.dart
void main() {
  testWidgets(
    'Home desktop logout layout regression without D01 pages',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
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
    },
    skip: !const bool.fromEnvironment('RUN_DESKTOP_LOGOUT_PROBE'),
  );
}
