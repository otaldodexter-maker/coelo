import 'dart:async';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/chat_repository.dart';

/// Supabase adapter for the typed, security-invoker chat RPC surface.
///
/// It never queries a chat table directly. Conversation ids from the client are
/// passed only to RPCs that recompute the caller's authorised scope.
final class SupabaseChatRepository implements ChatRepository {
  const SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async {
    try {
      final rows = _rows(
        await _client.rpc<Object?>(
          'chat_inbox_page',
          params: {
            'p_cursor_activity_at': _timestamp(query.cursor?.timestamp),
            'p_cursor_conversation_id': query.cursor?.id,
            'p_limit': query.pageSize,
            'p_search': query.search.trim(),
            'p_unread_only': query.unreadOnly,
          },
        ),
      );
      return ChatInboxPage(
        items: rows.map(_conversation).toList(growable: false),
        nextCursor: _inboxCursor(rows),
        // The typed RPC returns the authoritative unread count for each row.
        // Summing this page never invents data; a global count would require a
        // separately contracted RPC rather than a direct table query.
        totalUnread: rows.fold(0, (total, row) => total + _int(row['unread_count'])),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async {
    try {
      final rows = await _threadRows(query);
      return ChatThreadPage(
        items: rows
            .map((row) => _message(row, conversationId: query.conversationId))
            .toList(growable: false),
        nextCursor: _threadCursor(rows),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) async {
    try {
      final response = _singleRow(
        _rows(
          await _client.rpc<Object?>(
            'chat_send_message',
            params: {
              'p_conversation_id': command.conversationId,
              'p_body_text': command.body.trim(),
              'p_idempotency_key': command.idempotencyKey,
              'p_child_context_ids': command.childContextIds,
            },
          ),
        ),
      );
      final messageId = _string(response, 'message_id');
      final message = await _findMessage(
        conversationId: command.conversationId,
        messageId: messageId,
      );
      // The send command is attributable to the current actor. Its table RPC
      // does not expose author identity, so retain this proven local fact only
      // for the returned command result; subsequent reads stay server-shaped.
      return _message(message, conversationId: command.conversationId, isMine: true);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {
    try {
      await _client.rpc<Object?>(
        'chat_mark_read',
        params: {'p_conversation_id': conversationId, 'p_through_message_id': upToMessageId},
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) async {
    try {
      final rows = _rows(
        await _client.rpc<Object?>(
          'chat_realtime_refresh',
          params: {'p_conversation_id': conversationId},
        ),
      );
      // A missing row is intentionally indistinguishable from an unauthorised
      // or deleted conversation so no presence information leaks over Realtime.
      final payload = _singleRow(rows, missing: const ChatUnauthorizedException());
      return ChatRealtimeRefresh(
        conversationId: _string(payload, 'conversation_id'),
        latestMessageId: null,
        unreadCount: _int(payload['unread_count']),
        occurredAt: _date(payload, 'latest_message_at'),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<Map<String, dynamic>>> _threadRows(ChatThreadQuery query) async => _rows(
    await _client.rpc<Object?>(
      'chat_thread_page',
      params: {
        'p_conversation_id': query.conversationId,
        'p_cursor_created_at': _timestamp(query.cursor?.timestamp),
        'p_cursor_message_id': query.cursor?.id,
        'p_limit': query.pageSize,
      },
    ),
  );

  Future<Map<String, dynamic>> _findMessage({
    required String conversationId,
    required String messageId,
  }) async {
    ChatCursor? cursor;
    do {
      final rows = await _threadRows(
        ChatThreadQuery(conversationId: conversationId, cursor: cursor, pageSize: 100),
      );
      for (final row in rows) {
        if (_string(row, 'message_id') == messageId) return row;
      }
      cursor = _threadCursor(rows);
    } while (cursor != null);
    throw const ChatUnauthorizedException();
  }
}

ChatConversationSummary _conversation(Map<String, dynamic> json) => ChatConversationSummary(
  id: _string(json, 'conversation_id'),
  title: json['title'] as String? ?? '',
  preview: json['latest_message_text'] as String? ?? '',
  contextLabel: json['scope_kind'] as String? ?? '',
  kind: json['conversation_type'] as String? ?? '',
  unreadCount: _int(json['unread_count']),
  updatedAt: _date(json, 'next_cursor_activity_at'),
  // The typed read RPC deliberately does not return this presentational flag.
  // Writes are still denied by chat_send_message when the conversation is read-only.
  isReadOnly: false,
);

ChatMessage _message(
  Map<String, dynamic> json, {
  required String conversationId,
  bool isMine = false,
}) => ChatMessage(
  id: _string(json, 'message_id'),
  conversationId: conversationId,
  body: json['body_text'] as String? ?? '',
  // Identity display remains a separate, authorised profile projection. Never
  // manufacture a name from a globally supplied person id.
  authorName: '',
  sentAt: _date(json, 'created_at'),
  isMine: isMine,
  kind: json['message_type'] as String? ?? '',
  attachments: _rows(json['attachments']).map(_attachment).toList(growable: false),
);

ChatAttachment _attachment(Map<String, dynamic> json) => ChatAttachment(
  id: _string(json, 'id'),
  fileName: _string(json, 'file_name'),
  mediaType: _string(json, 'content_type'),
  byteSize: _int(json['byte_size']),
  // R2 URLs are issued only by the server-side gateway and are not part of the
  // chat RPC. Metadata can render safely while upload/download remains gated.
  downloadUrl: null,
);

ChatCursor? _inboxCursor(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return null;
  final row = rows.last;
  return ChatCursor(
    _date(row, 'next_cursor_activity_at'),
    _string(row, 'next_cursor_conversation_id'),
  );
}

ChatCursor? _threadCursor(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return null;
  final row = rows.last;
  return ChatCursor(_date(row, 'next_cursor_created_at'), _string(row, 'next_cursor_message_id'));
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

Map<String, dynamic> _singleRow(
  List<Map<String, dynamic>> rows, {
  Exception missing = const ChatFailureException(),
}) {
  if (rows.length == 1) return rows.single;
  throw missing;
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

DateTime _date(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return DateTime.parse(value);
  throw const ChatFailureException();
}
