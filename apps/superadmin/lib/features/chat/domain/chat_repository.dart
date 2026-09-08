/// Contract for contextual conversations.
///
/// Implementations must obtain every value through server-authorised endpoints;
/// a conversation id supplied by the client is never sufficient authorization.
library;

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
    this.institutionId,
  });

  final String id;

  /// Institution the conversation belongs to, as projected by the inbox RPC.
  /// It correlates an upload target; it never authorises one.
  final String? institutionId;
  final String title;
  final String preview;
  final String contextLabel;
  final String kind;
  final int unreadCount;
  final DateTime updatedAt;
  final bool isReadOnly;
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
    this.canEdit = false,
    this.canRevoke = false,
    this.isEdited = false,
    this.editedAt,
    this.isRevoked = false,
    this.revokedAt,
  });

  final String id;
  final String conversationId;
  final String body;
  final String authorName;
  final DateTime sentAt;
  final bool isMine;
  final String kind;
  final List<ChatAttachment> attachments;

  /// Affordances already granted by the authorised projection for this caller.
  ///
  /// They are never derived on the client from [isMine], authorship, age or any
  /// other local signal: profile, hierarchy and RLS decide on the server, which
  /// revalidates on every command. A payload that omits them means "not
  /// granted", so both default to false.
  final bool canEdit;
  final bool canRevoke;

  /// A body the server replaced through an authorised revision. An edit is
  /// never applied silently: the surface states that the message changed.
  final bool isEdited;
  final DateTime? editedAt;

  /// Logical revocation, i.e. a tombstone rather than a delete. The message
  /// keeps its place in the conversation and its attachments stay marked, never
  /// purged by the client; only the server decides to stop projecting it.
  final bool isRevoked;
  final DateTime? revokedAt;
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

/// A locally selected file that has not been authorised or stored yet.
final class ChatAttachmentDraft {
  const ChatAttachmentDraft({required this.fileName, required this.mediaType, required this.bytes});

  final String fileName;
  final String mediaType;
  final List<int> bytes;
}

enum ChatAttachmentIssue { emptyFile, unsupportedMediaType, tooLarge, nameTooLong }

/// Client-side pre-checks for a chat attachment.
///
/// They exist to fail fast and explain the refusal, never as authorisation: the
/// server revalidates actor, scope, real MIME, bytes and checksum before the
/// asset is linked to a message.
abstract final class ChatAttachmentPolicy {
  /// Mirrors the approved Circular media envelope. Video stays out of Chat:
  /// ADR 0032 does not require Stream for Chat in the MVP.
  static const maximumBytesByMediaType = <String, int>{
    'image/jpeg': 10 * 1024 * 1024,
    'image/png': 10 * 1024 * 1024,
    'image/webp': 10 * 1024 * 1024,
    'application/pdf': 5 * 1024 * 1024,
  };

  static const maximumNameLength = 240;

  /// One attachment per message. The batch limit is an open decision, so this
  /// stays at the most conservative value instead of guessing an upper bound.
  static const maximumPerMessage = 1;

  static ChatAttachmentIssue? validate(ChatAttachmentDraft draft) {
    if (draft.bytes.isEmpty) return ChatAttachmentIssue.emptyFile;
    if (draft.fileName.trim().isEmpty || draft.fileName.length > maximumNameLength) {
      return ChatAttachmentIssue.nameTooLong;
    }
    final maximumBytes = maximumBytesByMediaType[draft.mediaType];
    if (maximumBytes == null) return ChatAttachmentIssue.unsupportedMediaType;
    if (draft.bytes.length > maximumBytes) return ChatAttachmentIssue.tooLarge;
    return null;
  }
}

final class ChatAttachmentUploadCommand {
  const ChatAttachmentUploadCommand({
    required this.conversationId,
    required this.draft,
    required this.idempotencyKey,
    required this.finalizeIdempotencyKey,
  }) : assert(conversationId != ''),
       assert(idempotencyKey != ''),
       assert(finalizeIdempotencyKey != ''),
       assert(idempotencyKey != finalizeIdempotencyKey);

  final String conversationId;
  final ChatAttachmentDraft draft;

  /// Intent id for preparing the upload.
  final String idempotencyKey;

  /// Distinct intent id for finalising it. The shared upload core requires both
  /// to be real identifiers, so a retry replays each step instead of creating a
  /// second asset.
  final String finalizeIdempotencyKey;
}

enum ChatMessageBodyIssue { empty, tooLong }

/// Client-side pre-checks for a message body.
///
/// A courtesy only: it explains a refusal before a pointless round trip and
/// never authorises anything. The server revalidates the actor, the
/// conversation, the ownership, the revision window and the body itself.
abstract final class ChatMessageBodyPolicy {
  /// Mirrors the server refusal in `superadmin_chat_send_message_v2`
  /// (`length(normalized_body) > 4000`). The composer does not cap typing
  /// today, so this is the only cap the client can honestly claim.
  static const maximumCharacters = 4000;

  static ChatMessageBodyIssue? validate(String body) {
    final normalized = body.trim();
    if (normalized.isEmpty) return ChatMessageBodyIssue.empty;
    // Postgres `length()` counts characters, not UTF-16 code units.
    if (normalized.runes.length > maximumCharacters) return ChatMessageBodyIssue.tooLong;
    return null;
  }
}

/// `chat.edit`: replaces the body of a message the server already authorised
/// this caller to revise.
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

  /// Preserved intent id. A retry of the same edit replays the recorded
  /// revision instead of writing a second one.
  final String idempotencyKey;
}

/// `chat.revoke`: turns a sent message into a tombstone. It is a logical
/// revocation, so the row keeps its place and its attachments stay marked.
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

  /// Preserved intent id, for the same reason as an edit: a retry must replay
  /// the recorded revocation instead of recording a second one.
  final String idempotencyKey;
}

/// Server-authorised revision commands over an already sent message.
///
/// Deliberately separate from [ChatRepository]: an adapter with no authorised
/// revision endpoint must not be forced to declare a capability it cannot
/// honour, and a surface must be able to tell "not offered here" from
/// "offered and refused". Consumers that cannot see this interface treat the
/// action as unavailable, never as permitted.
abstract interface class ChatMessageRevisionRepository {
  /// Returns the server's re-projection of the edited message. The client never
  /// rewrites a body locally, and the projection carries [ChatMessage.isEdited].
  Future<ChatMessage> editMessage(ChatEditMessageCommand command);

  /// Records the tombstone. Nothing is returned on purpose: the new state is
  /// proved by re-reading the thread from the server, never by dropping the row.
  Future<void> revokeMessage(ChatRevokeMessageCommand command);
}

abstract interface class ChatRepository {
  Future<int> fetchUnreadTotal();
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query);
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query);
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command);

  /// Stores an attachment through the authorised server gateway and returns the
  /// catalogued asset. The client never signs, names or reaches the bucket.
  Future<ChatAttachment> uploadAttachment(ChatAttachmentUploadCommand command);
  Future<void> markRead({required String conversationId, required String upToMessageId});
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId});
}

final class UnavailableChatRepository implements ChatRepository, ChatMessageRevisionRepository {
  const UnavailableChatRepository();

  @override
  Future<ChatMessage> editMessage(ChatEditMessageCommand command) =>
      Future<ChatMessage>.error(const ChatEditUnavailableException());

  @override
  Future<void> revokeMessage(ChatRevokeMessageCommand command) =>
      Future<void>.error(const ChatRevokeUnavailableException());

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
  Future<ChatAttachment> uploadAttachment(ChatAttachmentUploadCommand command) =>
      Future<ChatAttachment>.error(const ChatAttachmentUnavailableException());

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) =>
      Future<void>.error(const ChatFailureException());

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      Future<ChatRealtimeRefresh>.error(const ChatFailureException());
}

final class ChatUnauthorizedException implements Exception {
  const ChatUnauthorizedException();
}

/// The authorised attachment gateway is not wired yet. It is raised instead of
/// pretending an upload succeeded, so the surface can stay honest.
final class ChatAttachmentUnavailableException implements Exception {
  const ChatAttachmentUnavailableException();
}

final class ChatAttachmentRejectedException implements Exception {
  const ChatAttachmentRejectedException(this.issue);

  final ChatAttachmentIssue issue;
}

/// No authorised edit endpoint exists yet. Raised instead of inventing an RPC
/// name, forging a receipt or letting the surface believe the body changed.
final class ChatEditUnavailableException implements Exception {
  const ChatEditUnavailableException();
}

/// The body was refused by the client pre-check, before any round trip.
final class ChatEditRejectedException implements Exception {
  const ChatEditRejectedException(this.issue);

  final ChatMessageBodyIssue issue;
}

/// No authorised revocation endpoint exists yet. Raised instead of removing the
/// message locally, which would only hide it from this device.
final class ChatRevokeUnavailableException implements Exception {
  const ChatRevokeUnavailableException();
}

final class ChatOfflineException implements Exception {
  const ChatOfflineException();
}

final class ChatFailureException implements Exception {
  const ChatFailureException([this.cause]);

  final Object? cause;
}
