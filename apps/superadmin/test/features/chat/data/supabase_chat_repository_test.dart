import 'dart:convert';

import 'package:coelo_superadmin/features/chat/data/supabase_chat_repository.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('fetches the inbox through the authorised typed cursor RPC only', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json([
        {
          'conversation_id': 'conversation-1',
          'title': 'Turma Girassol',
          'conversation_type': 'group',
          'scope_kind': 'unit',
          'latest_message_id': 'message-1',
          'latest_message_text': 'Mensagem recente',
          'latest_message_at': '2026-08-11T12:00:00Z',
          'unread_count': 3,
          'next_cursor_activity_at': '2026-08-11T12:00:00Z',
          'next_cursor_conversation_id': 'conversation-1',
        },
      ], request);
    });
    addTearDown(client.dispose);

    final page = await SupabaseChatRepository(client).fetchInbox(
      ChatInboxQuery(
        search: 'girassol',
        cursor: ChatCursor(DateTime.utc(2026, 8, 10, 10), 'conversation-before'),
        pageSize: 20,
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/chat_inbox_page'));
    expect(jsonDecode(captured!.body), {
      'p_search': 'girassol',
      'p_cursor_activity_at': '2026-08-10T10:00:00.000Z',
      'p_cursor_conversation_id': 'conversation-before',
      'p_limit': 20,
      'p_unread_only': false,
    });
    expect(page.items.single.id, 'conversation-1');
    expect(page.items.single.unreadCount, 3);
    expect(page.nextCursor, ChatCursor(DateTime.utc(2026, 8, 11, 12), 'conversation-1'));
    expect(page.totalUnread, 3);
  });

  test(
    'loads a thread and re-fetches the authorised full message after an idempotent send',
    () async {
      var threadFetches = 0;
      final client = _client((request) async {
        final rpc = request.url.pathSegments.last;
        final response = switch (rpc) {
          'chat_thread_page' => [
            if (++threadFetches == 1)
              {
                'message_id': 'message-1',
                'body_text': 'Ola',
                'author_person_id': 'person-1',
                'message_type': 'text',
                'created_at': '2026-08-11T12:00:00Z',
                'updated_at': '2026-08-11T12:00:00Z',
                'attachments': <Object?>[],
                'next_cursor_created_at': '2026-08-11T12:00:00Z',
                'next_cursor_message_id': 'message-1',
              },
            if (threadFetches > 1)
              {
                'message_id': 'message-2',
                'author_person_id': 'person-self',
                'body_text': 'Oi!',
                'message_type': 'text',
                'created_at': '2026-08-11T12:01:00Z',
                'updated_at': '2026-08-11T12:01:00Z',
                'attachments': [
                  {
                    'id': 'attachment-1',
                    'file_name': 'agenda.pdf',
                    'content_type': 'application/pdf',
                    'byte_size': 42,
                    'sha256': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                    'upload_status': 'ready',
                  },
                ],
                'next_cursor_created_at': '2026-08-11T12:01:00Z',
                'next_cursor_message_id': 'message-2',
              },
          ],
          'chat_send_message' => [
            {'message_id': 'message-2', 'created_at': '2026-08-11T12:01:00Z', 'replayed': false},
          ],
          _ => <Object?>[],
        };
        return _json(response, request);
      });
      addTearDown(client.dispose);
      final repository = SupabaseChatRepository(client);

      final thread = await repository.fetchThread(
        const ChatThreadQuery(conversationId: 'conversation-1', pageSize: 50),
      );
      final sent = await repository.sendMessage(
        const ChatSendMessageCommand(
          conversationId: 'conversation-1',
          body: 'Oi!',
          idempotencyKey: 'f4e6daaa-1544-4c8f-b2fe-27da5839e4f1',
        ),
      );

      expect(thread.items.single.authorName, '');
      expect(sent.id, 'message-2');
      expect(sent.isMine, isTrue);
      expect(sent.attachments.single.downloadUrl, isNull);
      expect(threadFetches, 2);
    },
  );

  test(
    'marks read with the contract through id and maps authorization failure without fallback',
    () async {
      Request? captured;
      final client = _client((request) async {
        captured = request;
        return _json([
          {'updated_count': 1, 'read_at': '2026-08-11T12:03:00Z'},
        ], request);
      });
      addTearDown(client.dispose);

      await SupabaseChatRepository(
        client,
      ).markRead(conversationId: 'conversation-1', upToMessageId: 'message-1');

      expect(jsonDecode(captured!.body), {
        'p_conversation_id': 'conversation-1',
        'p_through_message_id': 'message-1',
      });
    },
  );

  test('maps authorization failure without leaking a fallback', () async {
    final client = _client(
      (request) async => Response(
        jsonEncode({
          'code': '42501',
          'message': 'permission denied',
          'details': null,
          'hint': null,
        }),
        403,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);

    expect(
      () => SupabaseChatRepository(
        client,
      ).markRead(conversationId: 'conversation-other-tenant', upToMessageId: 'message-1'),
      throwsA(isA<ChatUnauthorizedException>()),
    );
  });

  test('normalises the typed setof refresh payload returned after a realtime signal', () async {
    final client = _client(
      (request) async => _json([
        {
          'conversation_id': 'conversation-1',
          'latest_message_at': '2026-08-11T12:03:00Z',
          'unread_count': 9,
        },
      ], request),
    );
    addTearDown(client.dispose);

    final refresh = await SupabaseChatRepository(
      client,
    ).refreshAfterRealtime(conversationId: 'conversation-1');

    expect(refresh.conversationId, 'conversation-1');
    expect(refresh.latestMessageId, isNull);
    expect(refresh.unreadCount, 9);
  });
}

SupabaseClient _client(Future<Response> Function(Request request) handler) => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient(handler),
);

Response _json(Object? body, Request request) => Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);
