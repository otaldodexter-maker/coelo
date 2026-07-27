import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/help_center/presentation/screens/superadmin_help_center_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches the empty Help Center in desktop light and mobile dark', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final configuration in [
      (name: 'light_1440', size: const Size(1440, 900), mode: ThemeMode.light),
      (name: 'dark_375', size: const Size(375, 900), mode: ThemeMode.dark),
    ]) {
      tester.view.physicalSize = configuration.size;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: CoeloTheme.light,
          darkTheme: CoeloTheme.dark,
          themeMode: configuration.mode,
          themeAnimationStyle: AnimationStyle.noAnimation,
          home: RepaintBoundary(
            key: const Key('help-center-golden'),
            child: const SuperadminHelpCenterPage(logout: _logout),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('help-center-golden')),
        matchesGoldenFile('goldens/help_center_empty_${configuration.name}.png'),
      );
    }
  });
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

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
