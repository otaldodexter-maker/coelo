/// Contract for contextual conversations.
///
/// Implementations must obtain every value through server-authorised endpoints;
/// a conversation id supplied by the client is never sufficient authorization.
library;

import 'dart:typed_data';

enum ChatInboxLoadState { loading, ready, empty, noResults, failure, unauthorized, offline }

final class ChatCursor {
  /// A typed keyset cursor. The timestamp and id always travel together so
  /// Postgres can use its ordered composite cursor without string parsing.
  const ChatCursor(this.timestamp, this.id) : assert(id != '');

  final DateTime timestamp;
  final String id;

  /// SQL's textual cursor representation, retained for persisted navigation
  /// state. RPC calls use [timestamp] and [id] as separate typed parameters.
  String get value => '${timestamp.toUtc().toIso8601String()}|$id';

  static ChatCursor? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    final pieces = value.split('|');
    if (pieces.length != 2 || pieces.any((piece) => piece.isEmpty)) return null;
    final timestamp = DateTime.tryParse(pieces.first);
    return timestamp == null ? null : ChatCursor(timestamp, pieces.last);
  }

  @override
  bool operator ==(Object other) =>
      other is ChatCursor && other.timestamp == timestamp && other.id == id;

  @override
  int get hashCode => Object.hash(timestamp, id);
}

final class ChatInboxQuery {
  const ChatInboxQuery({this.search = '', this.cursor, this.pageSize = 30, this.unreadOnly = false})
    : assert(pageSize > 0 && pageSize <= 100);

  final String search;
  final ChatCursor? cursor;
  final int pageSize;
  final bool unreadOnly;
}

final class ChatConversationSummary {
  const ChatConversationSummary({
    required this.id,
    required this.title,
    required this.preview,
    required this.contextLabel,
    required this.kind,
    required this.unreadCount,
    required this.updatedAt,
    required this.isReadOnly,
    this.pinnedAt,
    this.flag = ChatConversationFlag.none,
  });

  final String id;
  final String title;
  final String preview;
  final String contextLabel;
  final String kind;
  final int unreadCount;
  final DateTime updatedAt;
  final bool isReadOnly;

  /// Preferencia da propria identidade interna, vinda do servidor. Duas pessoas
  /// na mesma conversa fixam e sinalizam de forma independente.
  final DateTime? pinnedAt;
  final ChatConversationFlag flag;

  bool get isPinned => pinnedAt != null;
}

/// Sinalizador de cor da conversa. Os nomes acompanham o dominio do banco.
enum ChatConversationFlag { none, red, yellow, green, blue, pink, restricted }

final class ChatConversationPreference {
  const ChatConversationPreference({
    required this.conversationId,
    required this.pinnedAt,
    required this.flag,
  });

  final String conversationId;
  final DateTime? pinnedAt;
  final ChatConversationFlag flag;
}

final class ChatInboxPage {
  const ChatInboxPage({
    required this.items,
    required this.totalUnread,
    this.nextCursor,
    this.totalCount = 0,
    this.hasMore = false,
  });

  final List<ChatConversationSummary> items;
  final ChatCursor? nextCursor;
  final int totalUnread;
  final int totalCount;
  final bool hasMore;
}

/// State that lets the UI remain actionable when a real inbox has no rows.
final class ChatInboxState {
  const ChatInboxState._(this.kind, {this.page, this.error});

  const ChatInboxState.loading() : this._(ChatInboxLoadState.loading);
  const ChatInboxState.failure(Object error) : this._(ChatInboxLoadState.failure, error: error);
  const ChatInboxState.unauthorized(Object error)
    : this._(ChatInboxLoadState.unauthorized, error: error);
  const ChatInboxState.offline(Object error) : this._(ChatInboxLoadState.offline, error: error);

  factory ChatInboxState.loaded(ChatInboxPage page, {required String search}) {
    if (page.items.isNotEmpty) return ChatInboxState._(ChatInboxLoadState.ready, page: page);
    return ChatInboxState._(
      search.trim().isEmpty ? ChatInboxLoadState.empty : ChatInboxLoadState.noResults,
      page: page,
    );
  }

  final ChatInboxLoadState kind;
  final ChatInboxPage? page;
  final Object? error;
}

final class ChatThreadQuery {
  const ChatThreadQuery({required this.conversationId, this.cursor, this.pageSize = 50})
    : assert(conversationId != ''),
      assert(pageSize > 0 && pageSize <= 100);

  final String conversationId;
  final ChatCursor? cursor;
  final int pageSize;
}

final class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.fileName,
    required this.mediaType,
    required this.byteSize,
    this.assetId,
    this.downloadUrl,
  });

  final String id;
  final String fileName;
  final String mediaType;
  final int byteSize;

  /// Canonical media catalog reference, distinct from metadata [id].
  /// Null for legacy metadata; never infer it from an id, key or URL.
  final String? assetId;

  /// Short-lived URL supplied only by an authorised server gateway.
  final Uri? downloadUrl;
}

/// Server-computed receipt state for a single message.
///
/// The server decides which half of this record is meaningful: a message the
/// caller received carries the caller's own [readAt]/[deliveredAt], while a
/// message the caller sent carries aggregate counts over the conversation's
/// active recipients. The UI never derives one half from the other, and never
/// infers a receipt from the fact that a message is visible.
final class ChatMessageReceipt {
  const ChatMessageReceipt({
    required this.isMine,
    this.deliveredAt,
    this.readAt,
    this.recipientCount = 0,
    this.deliveredCount = 0,
    this.readCount = 0,
  }) : assert(recipientCount >= 0),
       assert(deliveredCount >= 0),
       assert(readCount >= 0);

  final bool isMine;

  /// The caller's own receipt, meaningful only for a received message.
  final DateTime? deliveredAt;
  final DateTime? readAt;

  /// Aggregates over active recipients, meaningful only for a sent message.
  final int recipientCount;
  final int deliveredCount;
  final int readCount;

  bool get isReadByMe => !isMine && readAt != null;
  bool get isDeliveredToMe => !isMine && deliveredAt != null;

  /// True only when every active recipient has read the message. A conversation
  /// with no active recipient never counts as fully read.
  bool get isReadByEveryone => isMine && recipientCount > 0 && readCount >= recipientCount;

  bool get isDeliveredToEveryone =>
      isMine && recipientCount > 0 && deliveredCount >= recipientCount;
}

final class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.body,
    required this.authorName,
    required this.sentAt,
    required this.isMine,
    required this.kind,
    this.attachments = const [],
    this.receipt,
    this.editedAt,
    this.canManage = false,
  });

  final String id;
  final String conversationId;
  final String body;
  final String authorName;
  final DateTime sentAt;
  final bool isMine;
  final String kind;
  final List<ChatAttachment> attachments;

  /// Null when the server projected no receipt. Absence is not "unread": the
  /// UI renders nothing rather than asserting a state the server did not send.
  final ChatMessageReceipt? receipt;

  /// Set only when the server recorded at least one edit for this message.
  final DateTime? editedAt;

  /// Whether the server authorises this caller to edit or revoke the message.
  /// It gates affordances only; every command is re-authorised server-side.
  final bool canManage;

  bool get isEdited => editedAt != null;
}

final class ChatEditMessageCommand {
  const ChatEditMessageCommand({
    required this.conversationId,
    required this.messageId,
    required this.body,
    required this.idempotencyKey,
  }) : assert(conversationId != ''),
       assert(messageId != ''),
       assert(idempotencyKey != '');

  final String conversationId;
  final String messageId;
  final String body;
  final String idempotencyKey;
}

final class ChatRevokeMessageCommand {
  const ChatRevokeMessageCommand({
    required this.conversationId,
    required this.messageId,
    required this.idempotencyKey,
  }) : assert(conversationId != ''),
       assert(messageId != ''),
       assert(idempotencyKey != '');

  final String conversationId;
  final String messageId;
  final String idempotencyKey;
}

final class ChatMessageRevocation {
  const ChatMessageRevocation({required this.messageId, required this.revokedAt});

  final String messageId;
  final DateTime revokedAt;
}

final class ChatThreadPage {
  const ChatThreadPage({
    required this.items,
    this.nextCursor,
    this.totalCount = 0,
    this.hasMore = false,
  });

  /// Messages are ordered newest-first, matching the keyset-paginated RPC.
  /// Presentation may render this list in reverse without reordering the data.
  final List<ChatMessage> items;
  final ChatCursor? nextCursor;
  final int totalCount;
  final bool hasMore;
}

final class ChatSendMessageCommand {
  const ChatSendMessageCommand({
    required this.conversationId,
    required this.body,
    required this.idempotencyKey,
    this.childContextIds = const [],
    this.attachmentIds = const [],
  }) : assert(conversationId != ''),
       assert(idempotencyKey != '');

  final String conversationId;
  final String body;
  final String idempotencyKey;
  final List<String> childContextIds;
  final List<String> attachmentIds;
}

/// A websocket notification is never rendered directly. The repository asks
/// the server to re-authorise and normalise it before the UI refreshes.
final class ChatRealtimeRefresh {
  const ChatRealtimeRefresh({
    required this.conversationId,
    required this.latestMessageId,
    required this.unreadCount,
    required this.occurredAt,
  });

  final String conversationId;
  final String? latestMessageId;
  final int unreadCount;
  final DateTime occurredAt;
}

/// Criar grupo (P8, ADR 0034 Decisao 12): contrato de
/// superadmin_chat_create_group_v2 publicado pelo grupo realm-interno.
/// O escopo e derivado no servidor (activity > group > unit > institution) e os
/// membros sao pessoas do realm de pessoas com vinculo ativo na instituicao.
final class ChatCreateGroupCommand {
  const ChatCreateGroupCommand({
    required this.requestId,
    required this.institutionId,
    required this.title,
    required this.personIds,
    this.unitId,
    this.groupId,
    this.activityId,
  }) : assert(requestId != ''),
       assert(institutionId != '');

  final String requestId;
  final String institutionId;
  final String title;
  final List<String> personIds;
  final String? unitId;
  final String? groupId;
  final String? activityId;
}

final class ChatGroupCreated {
  const ChatGroupCreated({
    required this.conversationId,
    required this.title,
    required this.memberCount,
    this.replayed = false,
  });

  final String conversationId;
  final String title;
  final int memberCount;
  final bool replayed;
}

/// Membro invalido (sem vinculo ativo na instituicao): CHAT_MEMBER_INVALID 422.
final class ChatMemberInvalidException implements Exception {
  const ChatMemberInvalidException();
}

abstract interface class ChatRepository {
  Future<int> fetchUnreadTotal();
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query);
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query);
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command);
  Future<ChatMessage> editMessage(ChatEditMessageCommand command);
  Future<ChatMessageRevocation> revokeMessage(ChatRevokeMessageCommand command);
  Future<void> markRead({required String conversationId, required String upToMessageId});
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId});

  /// Um repositorio que ainda nao fala com o realm interno recusa a
  /// preferencia em vez de fingir um estado local, que era exatamente o que o
  /// reload apagava antes.
  Future<ChatConversationPreference> setPinned({
    required String conversationId,
    required bool pinned,
  });
  Future<ChatConversationPreference> setFlag({
    required String conversationId,
    required ChatConversationFlag flag,
  });
  Future<ChatGroupCreated> createGroup(ChatCreateGroupCommand command);
}

final class UnavailableChatRepository implements ChatRepository {
  const UnavailableChatRepository();

  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) =>
      Future<ChatInboxPage>.error(const ChatFailureException());

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) =>
      Future<ChatThreadPage>.error(const ChatFailureException());

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());

  @override
  Future<ChatMessage> editMessage(ChatEditMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());

  @override
  Future<ChatMessageRevocation> revokeMessage(ChatRevokeMessageCommand command) =>
      Future<ChatMessageRevocation>.error(const ChatFailureException());

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) =>
      Future<void>.error(const ChatFailureException());

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      Future<ChatRealtimeRefresh>.error(const ChatFailureException());

  @override
  Future<ChatConversationPreference> setPinned({
    required String conversationId,
    required bool pinned,
  }) => Future<ChatConversationPreference>.error(const ChatFailureException());

  @override
  Future<ChatConversationPreference> setFlag({
    required String conversationId,
    required ChatConversationFlag flag,
  }) => Future<ChatConversationPreference>.error(const ChatFailureException());

  @override
  Future<ChatGroupCreated> createGroup(ChatCreateGroupCommand command) =>
      Future<ChatGroupCreated>.error(const ChatFailureException());
}

final class ChatUnauthorizedException implements Exception {
  const ChatUnauthorizedException();
}

/// A command the caller may hold permission for, but that the message's own
/// state refuses right now: the edit window closed, or it is already revoked.
/// Distinct from [ChatUnauthorizedException] so the UI can explain the reason
/// without implying the session lost access.
enum ChatConflictReason { editWindowClosed, alreadyRevoked, readOnly }

final class ChatConflictException implements Exception {
  const ChatConflictException(this.reason);

  final ChatConflictReason reason;
}

final class ChatOfflineException implements Exception {
  const ChatOfflineException();
}

final class ChatFailureException implements Exception {
  const ChatFailureException([this.cause]);

  final Object? cause;
}

/// Explicit chat binding gateway. A binding id is not a canonical media asset.
abstract interface class ChatAttachmentRepository {
  Future<String> uploadAttachment(ChatAttachmentUpload command);
  Future<ChatAttachmentRead> readAttachment(String attachmentId);
}

final class ChatAttachmentUpload {
  ChatAttachmentUpload({
    required this.conversationId,
    required this.requestId,
    required this.fileName,
    required this.contentType,
    required Uint8List bytes,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final String conversationId;
  final String requestId;
  final String fileName;
  final String contentType;
  final Uint8List bytes;

  void validate() {
    final limit = contentType == 'application/pdf' ? 10 * 1024 * 1024 : 4 * 1024 * 1024;
    if (!const {'image/jpeg', 'image/png', 'image/webp', 'application/pdf'}.contains(contentType) ||
        bytes.isEmpty ||
        bytes.length > limit ||
        fileName.isEmpty ||
        fileName.length > 255 ||
        RegExp(r'[\x00-\x1f/\\]').hasMatch(fileName)) {
      throw const ChatAttachmentInvalidException();
    }
  }
}

final class ChatAttachmentRead {
  const ChatAttachmentRead({required this.url, required this.expiresAt});
  final Uri url;
  final DateTime expiresAt;
}

final class ChatAttachmentInvalidException implements Exception {
  const ChatAttachmentInvalidException();
}
