import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('production notices use real logout while development stays isolated', (
    tester,
  ) async {
    final session = SuperadminSession()..signIn();
    var productionLogoutCalls = 0;
    Future<LogoutResult> logout() async {
      productionLogoutCalls++;
      return const LogoutResult.success();
    }

    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: logout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go('/notices');
    await tester.pumpAndSettle();
    expect(find.byType(SuperadminShell), findsWidgets);
    await tester.widget<SuperadminShell>(find.byType(SuperadminShell).last).logout();
    expect(productionLogoutCalls, 1);

    for (final path in const ['/notices/new', '/notices/notice-1/edit']) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.byType(SuperadminShell), findsNothing, reason: path);
      expect(find.byType(SuperadminErrorScreen), findsOneWidget, reason: path);
      expect(productionLogoutCalls, 1, reason: path);
    }

    router.go('/dev/notices');
    await tester.pumpAndSettle();
    expect(find.byType(SuperadminShell), findsWidgets);
    await tester.widget<SuperadminShell>(find.byType(SuperadminShell).last).logout();
    expect(productionLogoutCalls, 1);
  });
}
