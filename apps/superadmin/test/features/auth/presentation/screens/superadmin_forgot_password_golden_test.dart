import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/presentation/screens/superadmin_forgot_password_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  for (final themeCase in [
    (name: 'light', theme: CoeloTheme.light),
    (name: 'dark', theme: CoeloTheme.dark),
  ]) {
    testWidgets('renders the ${themeCase.name} password recovery form reference', (tester) async {
      _configureDesktopViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: themeCase.theme,
          home: SuperadminForgotPasswordScreen(
            requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
            onBackToLogin: () {},
            onThemeModeChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SuperadminForgotPasswordScreen),
        matchesGoldenFile('goldens/superadmin_forgot_password_${themeCase.name}.png'),
      );
    });

    testWidgets('renders the ${themeCase.name} password recovery success reference', (
      tester,
    ) async {
      _configureDesktopViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: themeCase.theme,
          home: SuperadminForgotPasswordScreen(
            requestPasswordRecovery: (_) async {
              return const PasswordRecoveryResult.success();
            },
            onBackToLogin: () {},
            onThemeModeChanged: (_) {},
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('superadmin-forgot-password-email')),
        'owner@coelo.me',
      );
      await tester.tap(find.text('Enviar link de recuperação'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SuperadminForgotPasswordScreen),
        matchesGoldenFile('goldens/superadmin_forgot_password_success_${themeCase.name}.png'),
      );
    });
  }
}

Future<void> _loadGoldenFonts() async {
  final fontLoader = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await fontLoader.load();

  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await materialIconsLoader.load();
}

void _configureDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
