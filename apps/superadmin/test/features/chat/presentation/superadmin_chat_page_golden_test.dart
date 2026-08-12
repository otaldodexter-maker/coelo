import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
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
      testWidgets('renders authorised chat data at $width in ${themeCase.name}', (tester) async {
        _setGoldenView(tester, width.toDouble());
        await _pumpChat(tester, theme: themeCase.theme);

        await expectLater(
          find.byType(SuperadminChatPage),
          matchesGoldenFile('goldens/superadmin_chat_${themeCase.name}_$width.png'),
        );
      });
    }
  }

  testWidgets('renders authorised chat data with reduced motion', (tester) async {
    _setGoldenView(tester, 375);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: SuperadminChatPage(logout: _logout, chatRepository: _GoldenChatRepository()),
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

Future<void> _pumpChat(WidgetTester tester, {required ThemeData theme}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: SuperadminChatPage(logout: _logout, chatRepository: _GoldenChatRepository()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

final class _GoldenChatRepository implements ChatRepository {
  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async => ChatInboxPage(
    totalUnread: 1,
    items: [
      ChatConversationSummary(
        id: 'conversation-1',
        title: 'Turma Girassol',
        preview: 'Mensagem autorizada',
        contextLabel: 'Unidade Cambui',
        kind: 'group',
        unreadCount: 1,
        updatedAt: DateTime.utc(2026, 8, 12, 12),
        isReadOnly: false,
      ),
    ],
  );

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async => ChatThreadPage(
    items: [
      ChatMessage(
        id: 'message-1',
        conversationId: 'conversation-1',
        body: 'Mensagem autorizada',
        authorName: 'Marina',
        sentAt: DateTime.utc(2026, 8, 12, 12),
        isMine: false,
        kind: 'text',
      ),
    ],
  );

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {}

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) => throw UnimplementedError();
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
