import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offers a logout button and invokes the injected action', (tester) async {
    var logoutCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SuperadminShell(
          logout: () async {
            logoutCount += 1;
            return const LogoutResult.success();
          },
        ),
      ),
    );

    final logoutButton = find.byTooltip('Sair');
    expect(logoutButton, findsOneWidget);

    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(logoutCount, 1);
  });

  testWidgets('shows safe feedback when logout fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SuperadminShell(
          logout: () async => const LogoutResult.failure(LogoutResult.genericFailureMessage),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();

    expect(find.text(LogoutResult.genericFailureMessage), findsOneWidget);
  });
}
