import 'dart:async';

import 'dart:typed_data';

import 'package:coelo_api/coelo_api.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/chat_repository.dart';

/// Supabase adapter for the internal-identity, RPC-only chat gateway.
///
/// It never queries a chat table directly. Conversation ids from the client are
/// passed only to RPCs that recompute the caller's authorised scope.
final class SupabaseChatRepository implements ChatRepository, ChatMessageRevisionRepository {
  const SupabaseChatRepository(this._client, {SessionMediaUploader? attachmentUploader})
    : _attachmentUploader = attachmentUploader;

  final SupabaseClient _client;

  /// Approved common upload core, injected by the composition root once an
  /// authorised chat gateway exists. While it is null the action stays honestly
  /// unavailable instead of inventing a transport.
  final SessionMediaUploader? _attachmentUploader;

  @override
  Future<int> fetchUnreadTotal() async {
    try {
      final row = _data(await _client.rpc<Object?>('superadmin_chat_unread_total_v2'));
      return _int(row['total_unread']);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async {
    try {
      final data = _data(
        await _client.rpc<Object?>(
          'superadmin_chat_inbox_v2',
          params: {
            'p_cursor_activity_at': _timestamp(query.cursor?.timestamp),
            'p_cursor_conversation_id': query.cursor?.id,
            'p_limit': query.pageSize,
            'p_search': query.search.trim(),
            'p_unread_only': query.unreadOnly,
          },
        ),
      );
      final rows = _rows(data['items']);
      return ChatInboxPage(
        items: rows.map(_conversation).toList(growable: false),
        nextCursor: _cursor(data['next_cursor']),
        totalUnread: _int(data['total_unread']),
        totalCount: _int(data['total']),
        hasMore: _bool(data['has_more']),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async {
    try {
      final data = await _threadData(query);
      final rows = _rows(data['items']);
      return ChatThreadPage(
        items: rows
            .map((row) => _message(row, conversationId: query.conversationId))
            .toList(growable: false),
        nextCursor: _cursor(data['next_cursor']),
        totalCount: _int(data['total']),
        hasMore: _bool(data['has_more']),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) async {
    // The internal v2 RPC is text-only. Do not turn a richer command into a
    // successful partial send by silently discarding its attachments/context.
    if (command.attachmentIds.isNotEmpty || command.childContextIds.isNotEmpty) {
      throw const ChatFailureException();
    }
    try {
      final response = _data(
        await _client.rpc<Object?>(
          'superadmin_chat_send_message_v2',
          params: {
            'p_conversation_id': command.conversationId,
            'p_body_text': command.body.trim(),
            'p_request_id': command.idempotencyKey,
          },
        ),
      );
      return _message(response, conversationId: command.conversationId);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ChatMessage> editMessage(ChatEditMessageCommand command) async {
    // The courtesy pre-check runs first so an obviously invalid body is named
    // as such instead of being reported as a missing service.
    final issue = ChatMessageBodyPolicy.validate(command.body);
    if (issue != null) throw ChatEditRejectedException(issue);
    // The internal-identity chat gateway (ADR 0019) exposes no authorised edit
    // RPC. Guessing a name would either 404 or reach an unreviewed surface, and
    // returning a receipt would be a lie, so `chat.edit` stays unavailable. The
    // message the caller holds is left exactly as the server projected it.
    throw const ChatEditUnavailableException();
  }

  @override
  Future<void> revokeMessage(ChatRevokeMessageCommand command) async {
    // Revocation is a server-side tombstone. There is no authorised RPC yet and
    // dropping the row locally would only hide the message on this device, so
    // the action fails closed instead.
    throw const ChatRevokeUnavailableException();
  }

  @override
  Future<ChatAttachment> uploadAttachment(ChatAttachmentUploadCommand command) async {
    final issue = ChatAttachmentPolicy.validate(command.draft);
    if (issue != null) throw ChatAttachmentRejectedException(issue);
    final uploader = _attachmentUploader;
    // No authorised chat gateway yet: the client must never sign or address the
    // bucket itself, so the action stays unavailable rather than faked.
    if (uploader == null) throw const ChatAttachmentUnavailableException();

    final bytes = Uint8List.fromList(command.draft.bytes);
    final source = MediaUploadSource(
      bytes: bytes,
      mimeType: command.draft.mediaType,
      // Declared only. The server measures the stored object and decides.
      checksumSha256: sha256.convert(bytes).toString(),
    );
    final MediaUploadResult result;
    try {
      result = await uploader.upload(
        // The caller owns both intents so a retry replays instead of duplicating.
        requestId: command.idempotencyKey,
        finalizeRequestId: command.finalizeIdempotencyKey,
        source: source,
      );
    } on ChatAttachmentUnavailableException {
      rethrow;
    } on Object {
      source.clear();
      rethrow;
    }
    source.clear();

    final receipt = result.receipt;
    // Only a measured READY receipt becomes an attachment. processing, expired
    // and unavailable are reported as such; none of them is a stored file.
    if (result.state != MediaUploadState.ready || receipt == null) {
      throw const ChatAttachmentUnavailableException();
    }
    return ChatAttachment(
      id: result.assetId,
      assetId: result.assetId,
      fileName: command.draft.fileName,
      mediaType: receipt.mimeType,
      byteSize: receipt.byteLength,
    );
  }

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {
    try {
      _data(
        await _client.rpc<Object?>(
          'superadmin_chat_mark_read_v2',
          params: {'p_conversation_id': conversationId, 'p_through_message_id': upToMessageId},
        ),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) async {
    try {
      final payload = _data(
        await _client.rpc<Object?>(
          'superadmin_chat_realtime_refresh_v2',
          params: {'p_conversation_id': conversationId},
        ),
      );
      return ChatRealtimeRefresh(
        conversationId: _string(payload, 'conversation_id'),
        latestMessageId: payload['latest_message_id'] as String?,
        unreadCount: _int(payload['unread_count']),
        occurredAt: _date(payload, 'latest_message_at'),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> _threadData(ChatThreadQuery query) async => _data(
    await _client.rpc<Object?>(
      'superadmin_chat_thread_v2',
      params: {
        'p_conversation_id': query.conversationId,
        'p_cursor_created_at': _timestamp(query.cursor?.timestamp),
        'p_cursor_message_id': query.cursor?.id,
        'p_limit': query.pageSize,
      },
    ),
  );
}

ChatConversationSummary _conversation(Map<String, dynamic> json) => ChatConversationSummary(
  id: _string(json, 'conversation_id'),
  institutionId: (json['institution_id'] as String?)?.trim().isEmpty ?? true
      ? null
      : json['institution_id'] as String,
  title: json['title'] as String? ?? '',
  preview: json['latest_message_text'] as String? ?? '',
  contextLabel: json['scope_kind'] as String? ?? '',
  kind: json['conversation_type'] as String? ?? '',
  unreadCount: _int(json['unread_count']),
  updatedAt: _date(json, 'activity_at'),
  isReadOnly: _bool(json['is_read_only']),
);

ChatMessage _message(Map<String, dynamic> json, {required String conversationId}) {
  final editedAt = _optionalDate(json['edited_at']);
  final revokedAt = _optionalDate(json['revoked_at']);
  final isRevoked = _bool(json['is_revoked']) || revokedAt != null;
  return ChatMessage(
    id: _string(json, 'message_id'),
    conversationId: conversationId,
    // A tombstone has no body to show. If a projection ever leaks one, it is
    // dropped here rather than rendered behind a "removida" label.
    body: isRevoked ? '' : json['body_text'] as String? ?? '',
    // Author presentation is supplied only by the contextual, authorised RPC.
    authorName: json['author_name'] as String? ?? '',
    sentAt: _date(json, 'created_at'),
    isMine: _bool(json['is_mine']),
    kind: json['message_type'] as String? ?? '',
    attachments: _rows(json['attachments']).map(_attachment).toList(growable: false),
    // Authorisation travels with the projection. An absent flag is a denial, and
    // a tombstone is never revised again.
    canEdit: !isRevoked && _bool(json['can_edit']),
    canRevoke: !isRevoked && _bool(json['can_revoke']),
    isEdited: _bool(json['is_edited']) || editedAt != null,
    editedAt: editedAt,
    isRevoked: isRevoked,
    revokedAt: revokedAt,
  );
}

ChatAttachment _attachment(Map<String, dynamic> json) => ChatAttachment(
  id: _string(json, 'id'),
  assetId: _assetId(json['asset_id']),
  fileName: _string(json, 'file_name'),
  mediaType: _string(json, 'content_type'),
  byteSize: _int(json['byte_size']),
  // R2 URLs are issued only by the server-side gateway and are not part of the
  // chat RPC. Metadata can render safely while upload/download remains gated.
  downloadUrl: null,
);

String? _assetId(Object? value) {
  if (value == null) return null;
  if (value is! String || !_canonicalAssetId.hasMatch(value)) {
    throw const ChatFailureException();
  }
  return value.toLowerCase();
}

final _canonicalAssetId = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

ChatCursor? _cursor(Object? value) {
  if (value == null) return null;
  if (value is! Map<Object?, Object?>) throw const ChatFailureException();
  final cursor = Map<String, dynamic>.from(value);
  return ChatCursor(_date(cursor, 'timestamp'), _string(cursor, 'id'));
}

String? _timestamp(DateTime? value) => value?.toUtc().toIso8601String();

Exception _mapError(Object error) {
  if (error is ChatUnauthorizedException) return error;
  if (error is ChatOfflineException) return error;
  if (error is ChatFailureException) return error;
  if (error is PostgrestException &&
      (error.code == '42501' || error.code == 'PGRST301' || error.code == 'PGRST116')) {
    return const ChatUnauthorizedException();
  }
  if (error is TimeoutException || error is ClientException) return const ChatOfflineException();
  return ChatFailureException(error);
}

Map<String, dynamic> _data(Object? value) {
  if (value is! Map<Object?, Object?>) throw const ChatFailureException();
  final envelope = Map<String, dynamic>.from(value);
  if (envelope['ok'] == true && envelope['data'] is Map<Object?, Object?>) {
    return Map<String, dynamic>.from(envelope['data'] as Map<Object?, Object?>);
  }
  final error = envelope['error'];
  if (error is Map<Object?, Object?>) {
    final code = error['code'];
    if (code is String &&
        const {
          'SAI_AUTH_REQUIRED',
          'SAI_SESSION_INVALID',
          'SAI_INTERNAL_CONTEXT_DENIED',
          'SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED',
          'SAI_PERMISSION_DENIED',
          'SAI_MFA_REQUIRED',
          'CHAT_NOT_FOUND',
          'CHAT_READ_ONLY',
        }.contains(code)) {
      throw const ChatUnauthorizedException();
    }
  }
  throw const ChatFailureException();
}

List<Map<String, dynamic>> _rows(Object? value) => value is List<dynamic>
    ? value
          .whereType<Map<Object?, Object?>>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false)
    : throw const ChatFailureException();

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw const ChatFailureException();
}

int _int(Object? value) => value is num ? value.toInt() : 0;

bool _bool(Object? value) => value is bool ? value : false;

/// A timestamp the projection may legitimately omit. A present but malformed
/// value is a contract breach, not an absence, so it still fails.
DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const ChatFailureException();
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const ChatFailureException();
  return parsed;
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return DateTime.parse(value);
  throw const ChatFailureException();
}
