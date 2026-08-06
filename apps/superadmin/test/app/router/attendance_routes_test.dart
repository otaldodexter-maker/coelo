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
  test('declares production and development attendance routes', () {
    expect(SuperadminRoutes.attendance, '/attendance');
    expect(SuperadminRoutes.attendanceCreate, '/attendance/new');
    expect(SuperadminRoutes.attendanceCall, '/attendance/calls/:callId');
    expect(SuperadminRoutes.devAttendance, '/dev/attendance');
  });

  testWidgets('exposes Attendance inside Acompanhamento', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? destination;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: unavailableSuperadminLogout,
          currentDestination: 'attendance',
          onDestinationSelected: (value) => destination = value,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acompanhamento'), findsOneWidget);
    await tester.tap(find.byKey(const Key('superadmin-navigation-attendance')));
    expect(destination, 'attendance');
  });

  testWidgets('opens local attendance routes', (tester) async {
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.attendance);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Nova chamada'), findsOneWidget);

    router.go('/attendance/calls/call-progress');
    await tester.pumpAndSettle();
    expect(find.text('Lançar chamada'), findsWidgets);

    router.go('/dev/attendance');
    await tester.pumpAndSettle();
    expect(find.text('Nova chamada'), findsOneWidget);
  });
}
