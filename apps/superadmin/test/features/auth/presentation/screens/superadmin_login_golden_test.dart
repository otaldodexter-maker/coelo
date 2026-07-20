import 'dart:io';

import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/presentation/screens/superadmin_login_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the desktop login reference', (tester) async {
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

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = SuperadminSession();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminLoginScreen(
          session: session,
          login: unavailableSuperadminLogin,
          onForgotPassword: () {},
          onThemeModeChanged: (_) {},
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/brand/logo-coelo-orange-complete.png'),
        tester.element(find.byType(SuperadminLoginScreen)),
      );
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SuperadminLoginScreen),
      matchesGoldenFile('goldens/superadmin_login_light.png'),
    );
  });
}
