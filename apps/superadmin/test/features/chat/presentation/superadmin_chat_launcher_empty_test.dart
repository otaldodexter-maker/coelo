import 'dart:ui';

import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_launcher.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty launcher routes a new conversation to the real conversations page', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var openCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: SuperadminChatLauncher(onOpenConversations: () => openCount += 1),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Abrir conversas, nenhuma mensagem não lida'), findsOneWidget);
    await tester.tap(find.byKey(const Key('superadmin-chat-launcher-surface')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-chat-launcher-header')), findsOneWidget);
    expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-chat-launcher-new-message')), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-chat-launcher-new-message')));
    expect(openCount, 1);
  });
}
