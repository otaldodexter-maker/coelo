import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares production and development daily routine routes', () {
    expect(SuperadminRoutes.dailyRoutine, '/daily-routine');
    expect(SuperadminRoutes.dailyRoutineCreate, '/daily-routine/new');
    expect(SuperadminRoutes.dailyRoutineEdit, '/daily-routine/:modelId/edit');
    expect(SuperadminRoutes.devDailyRoutine, '/dev/daily-routine');
  });

  testWidgets('opens daily routine and preserves contextual create type', (tester) async {
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

    router.go('/daily-routine');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Modelos'), findsOneWidget);
    expect(find.text('Criar modelo'), findsWidgets);

    await tester.tap(find.text('Rotinas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova rotina').first);
    await tester.pumpAndSettle();
    expect(find.text('Nova rotina'), findsWidgets);

    router.go('/dev/daily-routine/new');
    await tester.pumpAndSettle();
    expect(find.text('Criar modelo'), findsWidgets);
  });
}
