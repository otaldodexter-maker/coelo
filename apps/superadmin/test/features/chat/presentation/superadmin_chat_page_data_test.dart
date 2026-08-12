import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a usable empty inbox from the real repository result', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SuperadminChatPage(
          logout: unavailableSuperadminLogout,
          chatRepository: _ChatRepository(inbox: const ChatInboxPage(items: [], totalUnread: 0)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('conversas'), findsOneWidget);
    expect(find.text('Atualizar'), findsOneWidget);
  });

  testWidgets('loads a selected thread, marks it read and sends through the repository', (
    tester,
  ) async {
    final repository = _ChatRepository(
      inbox: ChatInboxPage(
        totalUnread: 1,
        items: [
          ChatConversationSummary(
            id: 'conversation-1',
            title: 'Turma Girassol',
            preview: 'OlÃ¡',
            contextLabel: 'Unidade CambuÃ­',
            kind: 'group',
            unreadCount: 1,
            updatedAt: DateTime.utc(2026, 8, 11),
            isReadOnly: false,
          ),
        ],
      ),
      thread: ChatThreadPage(
        items: [
          ChatMessage(
            id: 'message-1',
            conversationId: 'conversation-1',
            body: 'OlÃ¡',
            authorName: 'Marina',
            sentAt: DateTime.utc(2026, 8, 11),
            isMine: false,
            kind: 'text',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SuperadminChatPage(logout: unavailableSuperadminLogout, chatRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Turma Girassol'), findsWidgets);
    expect(find.text('OlÃ¡'), findsWidgets);
    expect(repository.markedConversationIds, ['conversation-1']);

    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pumpAndSettle();

    expect(repository.sent.single.body, 'Tudo bem?');
    expect(find.text('Tudo bem?'), findsOneWidget);
  });
  testWidgets('uses a safe unavailable state when Supabase is not initialized', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SuperadminChatPage(logout: unavailableSuperadminLogout)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nao foi possivel carregar'), findsOneWidget);
  });
}

final class _ChatRepository implements ChatRepository {
  _ChatRepository({required this.inbox, this.thread = const ChatThreadPage(items: [])});

  final ChatInboxPage inbox;
  final ChatThreadPage thread;
  final List<String> markedConversationIds = [];
  final List<ChatSendMessageCommand> sent = [];

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async => inbox;

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async => thread;

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {
    markedConversationIds.add(conversationId);
  }

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) async {
    sent.add(command);
    return ChatMessage(
      id: 'message-${sent.length}',
      conversationId: command.conversationId,
      body: command.body,
      authorName: 'Eu',
      sentAt: DateTime.utc(2026, 8, 11, 12, sent.length),
      isMine: true,
      kind: 'text',
    );
  }
}
