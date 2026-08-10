import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/reset_password_action.dart';
import 'package:coelo_superadmin/features/auth/presentation/screens/superadmin_forgot_password_screen.dart';
import 'package:coelo_superadmin/features/auth/presentation/screens/superadmin_login_screen.dart';
import 'package:coelo_superadmin/features/auth/presentation/screens/superadmin_reset_password_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

enum _AuthSurface { login, forgotPassword, resetPassword }

void main() {
  final viewports = [
    (name: '375', size: const Size(375, 844)),
    (name: '768', size: const Size(768, 900)),
    (name: '1024', size: const Size(1024, 900)),
    (name: '1440', size: const Size(1440, 900)),
  ];
  final themes = [(name: 'light', data: CoeloTheme.light), (name: 'dark', data: CoeloTheme.dark)];

  for (final surface in _AuthSurface.values) {
    for (final theme in themes) {
      for (final viewport in viewports) {
        testWidgets('${surface.name} supports ${viewport.name} in ${theme.name}', (tester) async {
          await _pumpSurface(tester, surface: surface, theme: theme.data, size: viewport.size);

          expect(tester.takeException(), isNull);
          expect(_primaryContentFinder(surface), findsOneWidget);
          expect(
            tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
            theme.data.colorScheme.surface,
            reason: '${surface.name} uses the semantic page surface in ${theme.name}',
          );
        });
      }

      testWidgets('${surface.name} supports 375 at 200% text in ${theme.name}', (tester) async {
        await _pumpSurface(
          tester,
          surface: surface,
          theme: theme.data,
          size: viewports.first.size,
          textScaler: const TextScaler.linear(2),
        );

        expect(tester.takeException(), isNull);
        expect(_primaryContentFinder(surface), findsOneWidget);
      });
    }
  }
}

Future<void> _pumpSurface(
  WidgetTester tester, {
  required _AuthSurface surface,
  required ThemeData theme,
  required Size size,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final session = SuperadminSession();
  addTearDown(session.dispose);

  final child = switch (surface) {
    _AuthSurface.login => SuperadminLoginScreen(
      session: session,
      login: unavailableSuperadminLogin,
      onForgotPassword: () {},
      onThemeModeChanged: (_) {},
    ),
    _AuthSurface.forgotPassword => SuperadminForgotPasswordScreen(
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onBackToLogin: () {},
      onThemeModeChanged: (_) {},
    ),
    _AuthSurface.resetPassword => SuperadminResetPasswordScreen(
      resetPassword: unavailableResetPassword,
      onBackToLogin: () {},
      onThemeModeChanged: (_) {},
    ),
  };

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _primaryContentFinder(_AuthSurface surface) {
  return switch (surface) {
    _AuthSurface.login => find.text('Acesse sua conta'),
    _AuthSurface.forgotPassword => find.text('Recupere seu acesso'),
    _AuthSurface.resetPassword => find.text('Crie uma nova senha'),
  };
}
