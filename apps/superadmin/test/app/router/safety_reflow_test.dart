import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety.dart';
import 'package:coelo_superadmin/features/safety/presentation/safety_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [375.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('development safety loads without overflow at $width text $scale', (
        tester,
      ) async {
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
          allowDevelopmentPreview: true,
        );
        addTearDown(router.dispose);
        addTearDown(session.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: CoeloTheme.light,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        );
        router.go(SuperadminRoutes.devSafety);
        // Bounded pumps also expose a directory that never leaves loading.
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        final page = tester.widget<SafetyLandingPage>(find.byType(SafetyLandingPage));
        expect(page.controller.state, ChildSafetyLoadState.ready);
        expect(find.text('Todos (164)'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Alice Duarte'),
          300,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('safety-directory-surface')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Alice Duarte'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
