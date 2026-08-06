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

  testWidgets('renders the desktop context collapsed', (tester) async {
    _setGoldenView(tester, 1440);
    await _pumpChat(tester);
    await tester.tap(find.byTooltip('Fechar contexto'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(SuperadminChatPage),
      matchesGoldenFile('goldens/superadmin_chat_context_collapsed_light_1440.png'),
    );
  });

  testWidgets('renders the flag palette with accessible labels', (tester) async {
    _setGoldenView(tester, 1440);
    await _pumpChat(tester);
    await tester.tap(find.byKey(const Key('superadmin-chat-flag-girassol')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/superadmin_chat_flag_palette_open_light_1440.png'),
    );
  });

  testWidgets('renders the canonical create group popup', (tester) async {
    _setGoldenView(tester, 1440);
    await _pumpChat(tester);
    await tester.tap(find.byKey(const Key('superadmin-chat-action-create-group')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/superadmin_chat_create_group_light_1440.png'),
    );
  });

  testWidgets('renders the canonical bulk message popup', (tester) async {
    _setGoldenView(tester, 1440);
    await _pumpChat(tester);
    await tester.tap(find.byKey(const Key('superadmin-chat-action-new-message')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envio em massa'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/superadmin_chat_bulk_message_light_1440.png'),
    );
  });

  testWidgets('renders the canonical filters popup', (tester) async {
    _setGoldenView(tester, 1440);
    await _pumpChat(tester);
    await tester.tap(find.byKey(const Key('superadmin-chat-action-filter')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/superadmin_chat_filters_light_1440.png'),
    );
  });

  testWidgets('renders compact chat with reduced motion', (tester) async {
    _setGoldenView(tester, 375);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const SuperadminChatPage(logout: _logout, onBack: _back),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(SuperadminChatPage),
      matchesGoldenFile('goldens/superadmin_chat_reduced_motion_light_375.png'),
    );
  });
}

void _setGoldenView(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpChat(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: const SuperadminChatPage(logout: _logout, onBack: _back),
    ),
  );
  await tester.pumpAndSettle();
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
