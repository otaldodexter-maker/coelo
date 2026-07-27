import 'dart:io';
import 'dart:ui';

import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_launcher.dart';
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
    testWidgets('renders collapsed launcher in ${themeCase.name}', (tester) async {
      _configureViewport(tester);
      await tester.pumpWidget(_stage(themeCase.theme));
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('chat-launcher-golden-stage')),
        matchesGoldenFile('goldens/superadmin_chat_launcher_${themeCase.name}.png'),
      );
    });
  }

  testWidgets('renders the launcher orange hover', (tester) async {
    _configureViewport(tester);
    await tester.pumpWidget(_stage(CoeloTheme.light));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('superadmin-chat-launcher-surface'))),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const Key('chat-launcher-golden-stage')),
      matchesGoldenFile('goldens/superadmin_chat_launcher_hover_light.png'),
    );
  });

  testWidgets('renders compact inbox and thread references', (tester) async {
    _configureViewport(tester);
    await tester.pumpWidget(_stage(CoeloTheme.light));
    await tester.tap(find.text('Mensagens'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('chat-launcher-golden-stage')),
      matchesGoldenFile('goldens/superadmin_chat_launcher_inbox_light.png'),
    );

    await tester.tap(find.text('Turma Girassol'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('chat-launcher-golden-stage')),
      matchesGoldenFile('goldens/superadmin_chat_launcher_thread_light.png'),
    );
  });
}

Widget _stage(ThemeData theme) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Stack(
        key: const Key('chat-launcher-golden-stage'),
        children: [
          Positioned(
            right: CoeloSpacing.space4,
            bottom: CoeloSpacing.space4,
            child: SuperadminChatLauncher(onExpand: _ignore),
          ),
        ],
      ),
    ),
  );
}

void _ignore() {}

void _configureViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
