import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
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
    for (final width in [375, 768, 1024, 1440]) {
      testWidgets('renders chat at $width in ${themeCase.name}', (tester) async {
        tester.view.physicalSize = Size(width.toDouble(), 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: themeCase.theme,
            home: const SuperadminChatPage(logout: _logout, onBack: _back),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(SuperadminChatPage),
          matchesGoldenFile('goldens/superadmin_chat_${themeCase.name}_$width.png'),
        );
      });
    }
  }
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

void _back() {}

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
