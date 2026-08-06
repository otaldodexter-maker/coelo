import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hosted page launcher stays above its requested bottom inset', (tester) async {
    const reservedHeight = 120.0;
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: _logout,
          currentDestination: 'people',
          onDestinationSelected: (_) {},
          child: SuperadminShell(
            key: const Key('hosted-page-shell'),
            logout: _logout,
            currentDestination: 'people',
            chatLauncherBottomInset: reservedHeight,
            child: const Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: reservedHeight,
                  child: ColoredBox(
                    key: Key('hosted-page-bottom-inset'),
                    color: Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final launchers = find.byKey(const Key('superadmin-chat-launcher-surface'));
    final launcherCount = launchers.evaluate().length;
    expect(launcherCount, 1, reason: 'O shell autenticado deve possuir um único launcher.');
    final launcherRects = [
      for (var index = 0; index < launcherCount; index++) tester.getRect(launchers.at(index)),
    ];
    final reservedInset = tester.getRect(find.byKey(const Key('hosted-page-bottom-inset')));
    final lowestLauncherBottom = launcherRects
        .map((rect) => rect.bottom)
        .reduce((current, next) => current > next ? current : next);

    expect(
      lowestLauncherBottom <= reservedInset.top - CoeloSpacing.space3,
      isTrue,
      reason:
          'Foram renderizados $launcherCount launchers, com limites inferiores '
          '${launcherRects.map((rect) => rect.bottom).toList()}; o inset reservado começa em '
          '${reservedInset.top}. Todos precisam respeitar o mesmo afastamento.',
    );
  });
}

Future<LogoutResult> _logout() async => const LogoutResult.success();
