import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Client acceptance for `chat.receipts`, write side.
///
/// The authorised thread arrives newest first and the list renders it reversed,
/// so the message the operator ends up looking at is `items.first`. Marking read
/// up to the wrong end is not a cosmetic slip: marking up to the oldest leaves
/// the newer messages unread forever, and the unread badge never clears no
/// matter how many times the conversation is opened.
void main() {
  testWidgets('a receipt marks up to the newest message in the thread', (tester) async {
    final repository = _ChatRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: SuperadminChatPage(logout: unavailableSuperadminLogout, chatRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.receipts, hasLength(1));
    expect(
      repository.receipts.single.upToMessageId,
      'message-newest',
      reason: 'the receipt must cover the newest message, not the oldest',
    );
    expect(repository.receipts.single.conversationId, 'conversation-1');
  });

  testWidgets('an empty thread produces no receipt at all', (tester) async {
    final repository = _ChatRepository(empty: true);
    await tester.pumpWidget(
      MaterialApp(
        home: SuperadminChatPage(logout: unavailableSuperadminLogout, chatRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing was read, so nothing is confirmed as read — and the conversation
    // still opens. Confirming a receipt over an empty thread would throw on the
    // missing message, the surrounding catch would swallow it, and the operator
    // would get a load failure for a conversation that simply has no messages.
    expect(repository.receipts, isEmpty);
    expect(find.text('Nao foi possivel carregar'), findsNothing);
    expect(find.textContaining('Turma Girassol'), findsWidgets);
  });
}

typedef _Receipt = ({String conversationId, String upToMessageId});

final class _ChatRepository implements ChatRepository {
  _ChatRepository({this.empty = false});

  final bool empty;
  final List<_Receipt> receipts = [];

  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async => ChatInboxPage(
    totalUnread: 2,
    items: [
      ChatConversationSummary(
        id: 'conversation-1',
        title: 'Turma Girassol',
        preview: 'Previa da conversa',
        contextLabel: 'Unidade Cambui',
        kind: 'group',
        unreadCount: 2,
        updatedAt: DateTime.utc(2026, 8, 12, 12),
        isReadOnly: false,
      ),
    ],
  );

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async => ChatThreadPage(
    // The authorised RPC orders newest first; the double reproduces that.
    items: empty
        ? const []
        : [
            ChatMessage(
              id: 'message-newest',
              conversationId: 'conversation-1',
              body: 'Mensagem recente',
              authorName: 'Marina',
              sentAt: DateTime.utc(2026, 8, 12, 12),
              isMine: false,
              kind: 'text',
            ),
            ChatMessage(
              id: 'message-oldest',
              conversationId: 'conversation-1',
              body: 'Mensagem antiga',
              authorName: 'Marina',
              sentAt: DateTime.utc(2026, 8, 12, 10),
              isMine: false,
              kind: 'text',
            ),
          ],
  );

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {
    receipts.add((conversationId: conversationId, upToMessageId: upToMessageId));
  }

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());

  @override
  Future<ChatAttachment> uploadAttachment(ChatAttachmentUploadCommand command) =>
      Future<ChatAttachment>.error(const ChatAttachmentUnavailableException());
}
