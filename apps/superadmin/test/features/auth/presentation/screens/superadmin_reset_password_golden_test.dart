import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/reset_password_action.dart';
import 'package:coelo_superadmin/features/auth/presentation/screens/superadmin_reset_password_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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
  });

  for (final themeCase in [
    (name: 'light', theme: CoeloTheme.light),
    (name: 'dark', theme: CoeloTheme.dark),
  ]) {
    testWidgets('renders the ${themeCase.name} reset password form', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: themeCase.theme,
          home: SuperadminResetPasswordScreen(
            resetPassword: unavailableResetPassword,
            onBackToLogin: () {},
            onThemeModeChanged: (_) {},
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/brand/logo-coelo-orange-complete.png'),
          tester.element(find.byType(SuperadminResetPasswordScreen)),
        );
      });
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SuperadminResetPasswordScreen),
        matchesGoldenFile('goldens/superadmin_reset_password_${themeCase.name}.png'),
      );
    });
  }
}
