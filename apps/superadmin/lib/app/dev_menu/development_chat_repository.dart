import '../../features/chat/domain/chat_repository.dart';

/// Deterministic, stateful repository used exclusively by `/dev/conversations`.
final class DevelopmentChatRepository implements ChatRepository {
  DevelopmentChatRepository.content()
    : _summaries = [
        ChatConversationSummary(
          id: 'dev-conversation-turma-girassol',
          title: 'Turma Girassol',
          preview: 'A atividade de hoje já está disponível.',
          contextLabel: 'Instituto Aurora · Unidade Centro',
          kind: 'group',
          unreadCount: 2,
          updatedAt: DateTime.utc(2026, 9, 1, 12),
          isReadOnly: false,
        ),
        ChatConversationSummary(
          id: 'dev-conversation-robotica',
          title: 'Robótica',
          preview: 'Materiais confirmados para a próxima aula.',
          contextLabel: 'Instituto Aurora · Atividade',
          kind: 'activity',
          unreadCount: 0,
          updatedAt: DateTime.utc(2026, 9, 1, 11),
          isReadOnly: false,
        ),
      ],
      _messages = {
        'dev-conversation-turma-girassol': [
          ChatMessage(
            id: 'dev-message-1',
            conversationId: 'dev-conversation-turma-girassol',
            body: 'Bom dia! A atividade de hoje já está disponível.',
            authorName: 'Marina Costa',
            sentAt: DateTime.utc(2026, 9, 1, 11, 58),
            isMine: false,
            kind: 'text',
          ),
        ],
        'dev-conversation-robotica': [
          ChatMessage(
            id: 'dev-message-2',
            conversationId: 'dev-conversation-robotica',
            body: 'Materiais confirmados para a próxima aula.',
            authorName: 'Rafael Lima',
            sentAt: DateTime.utc(2026, 9, 1, 10, 45),
            isMine: false,
            kind: 'text',
          ),
        ],
      };

  final List<ChatConversationSummary> _summaries;
  final Map<String, List<ChatMessage>> _messages;
  int _sequence = 2;

  @override
  Future<int> fetchUnreadTotal() async =>
      _summaries.fold<int>(0, (total, item) => total + item.unreadCount);

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async {
    final search = query.search.trim().toLowerCase();
    final filtered = _summaries
        .where(
          (item) =>
              (!query.unreadOnly || item.unreadCount > 0) &&
              (search.isEmpty ||
                  item.title.toLowerCase().contains(search) ||
                  item.preview.toLowerCase().contains(search) ||
                  item.contextLabel.toLowerCase().contains(search)),
        )
        .take(query.pageSize)
        .toList(growable: false);
    return ChatInboxPage(items: filtered, totalUnread: await fetchUnreadTotal());
  }

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async {
    final messages = _messages[query.conversationId];
    if (messages == null) throw const ChatUnauthorizedException();
    return ChatThreadPage(items: messages.take(query.pageSize).toList(growable: false));
  }

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) async {
    final messages = _messages[command.conversationId];
    if (messages == null) throw const ChatUnauthorizedException();
    final message = ChatMessage(
      id: 'dev-message-${++_sequence}',
      conversationId: command.conversationId,
      body: command.body.trim(),
      authorName: 'Owner Coelo',
      sentAt: DateTime.utc(2026, 9, 1, 12, _sequence),
      isMine: true,
      kind: 'text',
    );
    messages.add(message);
    return message;
  }

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {
    final index = _summaries.indexWhere((item) => item.id == conversationId);
    if (index < 0) throw const ChatUnauthorizedException();
    final item = _summaries[index];
    _summaries[index] = ChatConversationSummary(
      id: item.id,
      title: item.title,
      preview: item.preview,
      contextLabel: item.contextLabel,
      kind: item.kind,
      unreadCount: 0,
      updatedAt: item.updatedAt,
      isReadOnly: item.isReadOnly,
    );
  }

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) async {
    final messages = _messages[conversationId];
    if (messages == null) throw const ChatUnauthorizedException();
    return ChatRealtimeRefresh(
      conversationId: conversationId,
      latestMessageId: messages.lastOrNull?.id,
      unreadCount: _summaries.firstWhere((item) => item.id == conversationId).unreadCount,
      occurredAt: DateTime.utc(2026, 9, 1, 12, _sequence),
    );
  }
}
