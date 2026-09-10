import 'dart:convert';

import 'package:coelo_superadmin/features/chat/data/supabase_chat_repository.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const assetId = '9b400000-0000-4000-8000-000000000001';
  for (final sample in <({String name, Object? value, bool valid})>[
    (name: 'legacy', value: null, valid: true),
    (name: 'canonical', value: assetId.toUpperCase(), valid: true),
    (name: 'empty', value: '', valid: false),
    (name: 'malformed', value: 'not-an-asset', valid: false),
    (name: 'wrong type', value: 42, valid: false),
  ]) {
    test('attachment distinguishes metadata id from canonical asset (${sample.name})', () async {
      var requests = 0;
      final client = _client((request) async {
        requests++;
        expect(request.url.path, endsWith('/rpc/superadmin_chat_thread_v2'));
        return _json({
          'ok': true,
          'data': {
            'items': [
              {
                'message_id': 'message-1',
                'body_text': 'Anexo sintético',
                'author_name': 'Equipe',
                'is_mine': false,
                'message_type': 'file',
                'created_at': '2026-09-07T12:00:00Z',
                'attachments': [
                  {
                    'id': 'legacy-metadata-id',
                    if (sample.value != null) 'asset_id': sample.value,
                    'file_name': 'imagem.jpg',
                    'content_type': 'image/jpeg',
                    'byte_size': 42,
                    'download_url': 'https://untrusted.invalid/permanent',
                    'object_key': 'must-not-be-used',
                  },
                ],
              },
            ],
            'total': 1,
            'has_more': false,
            'next_cursor': null,
          },
          'error': null,
        }, request);
      });
      addTearDown(client.dispose);
      final pending = SupabaseChatRepository(
        client,
      ).fetchThread(const ChatThreadQuery(conversationId: 'conversation-1'));
      if (!sample.valid) {
        await expectLater(pending, throwsA(isA<ChatFailureException>()));
        expect(requests, 1);
        return;
      }
      final page = await pending;
      final attachment = page.items.single.attachments.single;
      expect(attachment.id, 'legacy-metadata-id');
      expect(attachment.assetId, sample.value != null ? assetId : isNull);
      expect(attachment.downloadUrl, isNull);
      expect(requests, 1);
    });
  }

  test('fetches the inbox through the authorised typed cursor RPC only', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json({
        'ok': true,
        'data': {
          'items': [
            {
              'conversation_id': 'conversation-1',
              'title': 'Turma Girassol',
              'conversation_type': 'group',
              'scope_kind': 'unit',
              'latest_message_id': 'message-1',
              'latest_message_text': 'Mensagem recente',
              'latest_message_at': '2026-08-11T12:00:00Z',
              'unread_count': 3,
              'activity_at': '2026-08-11T12:00:00Z',
              'is_read_only': false,
            },
          ],
          'total': 17,
          'total_unread': 12,
          'has_more': true,
          'next_cursor': {'timestamp': '2026-08-11T12:00:00Z', 'id': 'conversation-1'},
        },
        'error': null,
      }, request);
    });
    addTearDown(client.dispose);

    final page = await SupabaseChatRepository(client).fetchInbox(
      ChatInboxQuery(
        search: 'girassol',
        cursor: ChatCursor(DateTime.utc(2026, 8, 10, 10), 'conversation-before'),
        pageSize: 20,
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_chat_inbox_v2'));
    expect(jsonDecode(captured!.body), {
      'p_search': 'girassol',
      'p_cursor_activity_at': '2026-08-10T10:00:00.000Z',
      'p_cursor_conversation_id': 'conversation-before',
      'p_limit': 20,
      'p_unread_only': false,
    });
    expect(page.items.single.id, 'conversation-1');
    expect(page.items.single.unreadCount, 3);
    expect(page.items.single.isReadOnly, isFalse);
    expect(page.nextCursor, ChatCursor(DateTime.utc(2026, 8, 11, 12), 'conversation-1'));
    expect(page.totalUnread, 12);
    expect(page.totalCount, 17);
    expect(page.hasMore, isTrue);
  });

  test('fetches the authorised global unread total through its dedicated RPC', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json({
        'ok': true,
        'data': {'total_unread': 12},
        'error': null,
      }, request);
    });
    addTearDown(client.dispose);

    expect(await SupabaseChatRepository(client).fetchUnreadTotal(), 12);
    expect(captured!.url.path, endsWith('/rpc/superadmin_chat_unread_total_v2'));
    expect(jsonDecode(captured!.body), isNull);
  });
  test(
    'loads a thread and accepts the authorised message returned by an idempotent send',
    () async {
      var threadFetches = 0;
      final client = _client((request) async {
        final rpc = request.url.pathSegments.last;
        final response = switch (rpc) {
          'superadmin_chat_thread_v2' => {
            'ok': true,
            'data': {
              'items': [
                if (++threadFetches == 1)
                  {
                    'message_id': 'message-1',
                    'body_text': 'Ola',
                    'author_person_id': 'person-1',
                    'author_name': 'Marina',
                    'is_mine': false,
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
                    'author_name': 'Eu',
                    'is_mine': true,
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
                        'sha256':
                            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                        'upload_status': 'ready',
                      },
                    ],
                    'next_cursor_created_at': '2026-08-11T12:01:00Z',
                    'next_cursor_message_id': 'message-2',
                  },
              ],
              'total': 2,
              'has_more': false,
              'next_cursor': null,
            },
            'error': null,
          },
          'superadmin_chat_send_message_v2' => {
            'ok': true,
            'data': {
              'message_id': 'message-2',
              'body_text': 'Oi!',
              'message_type': 'text',
              'created_at': '2026-08-11T12:01:00Z',
              'updated_at': '2026-08-11T12:01:00Z',
              'author_name': 'Equipe Coelo',
              'is_mine': true,
              'attachments': <Object?>[],
              'replayed': false,
            },
            'error': null,
          },
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

      expect(thread.items.single.authorName, 'Marina');
      expect(thread.items.single.isMine, isFalse);
      expect(sent.id, 'message-2');
      expect(sent.authorName, 'Equipe Coelo');
      expect(sent.isMine, isTrue);
      expect(sent.attachments, isEmpty);
      expect(threadFetches, 1);
    },
  );

  test(
    'marks read with the contract through id and maps authorization failure without fallback',
    () async {
      Request? captured;
      final client = _client((request) async {
        captured = request;
        return _json({
          'ok': true,
          'data': {'updated_count': 1, 'read_at': '2026-08-11T12:03:00Z'},
          'error': null,
        }, request);
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

  for (final unsupported in ['attachments', 'child contexts']) {
    test('does not silently send text after dropping requested $unsupported', () async {
      var requests = 0;
      final client = _client((request) async {
        requests++;
        return _json({
          'ok': true,
          'data': {
            'message_id': 'message-2',
            'body_text': 'Leia o contexto enviado.',
            'message_type': 'text',
            'created_at': '2026-09-07T12:01:00Z',
            'author_name': 'Equipe Coelo',
            'is_mine': true,
            'attachments': <Object?>[],
          },
          'error': null,
        }, request);
      });
      addTearDown(client.dispose);

      await expectLater(
        SupabaseChatRepository(client).sendMessage(
          ChatSendMessageCommand(
            conversationId: 'conversation-1',
            body: 'Leia o contexto enviado.',
            idempotencyKey: 'f4e6daaa-1544-4c8f-b2fe-27da5839e4f1',
            attachmentIds: unsupported == 'attachments' ? ['attachment-1'] : const [],
            childContextIds: unsupported == 'child contexts' ? ['context-1'] : const [],
          ),
        ),
        throwsA(isA<ChatFailureException>()),
      );
      expect(requests, 0, reason: 'The text-only RPC cannot preserve this command.');
    });
  }

  test('markRead rejects a revoked membership returned in an HTTP 200 envelope', () async {
    final client = _client(
      (request) async => _json({
        'ok': false,
        'data': null,
        'error': {'code': 'SAI_MEMBERSHIP_REVOKED', 'http_status': 403},
      }, request),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseChatRepository(
        client,
      ).markRead(conversationId: 'conversation-1', upToMessageId: 'message-1'),
      throwsA(isA<ChatUnauthorizedException>()),
    );
  });

  test('markRead rejects malformed or unsuccessful envelopes', () async {
    for (final body in <Object?>[
      null,
      [],
      {'ok': true},
      {
        'ok': false,
        'error': {'code': 'UNEXPECTED'},
      },
    ]) {
      final client = _client((request) async => _json(body, request));
      addTearDown(client.dispose);
      await expectLater(
        SupabaseChatRepository(
          client,
        ).markRead(conversationId: 'conversation-1', upToMessageId: 'message-1'),
        throwsA(isA<ChatFailureException>()),
      );
    }
  });

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

  test('maps a denied internal envelope without using HTTP status as authorization', () async {
    final client = _client(
      (request) async => _json({
        'ok': false,
        'data': null,
        'error': {
          'code': 'SAI_MEMBERSHIP_REVOKED',
          'message': 'Acesso não autorizado.',
          'http_status': 403,
          'correlation_id': '8d4217e0-f215-49df-97c6-72db3ea93880',
        },
      }, request),
    );
    addTearDown(client.dispose);

    expect(
      () => SupabaseChatRepository(client).fetchUnreadTotal(),
      throwsA(isA<ChatUnauthorizedException>()),
    );
  });

  test('normalises the typed setof refresh payload returned after a realtime signal', () async {
    final client = _client(
      (request) async => _json({
        'ok': true,
        'data': {
          'conversation_id': 'conversation-1',
          'latest_message_at': '2026-08-11T12:03:00Z',
          'unread_count': 9,
        },
        'error': null,
      }, request),
    );
    addTearDown(client.dispose);

    final refresh = await SupabaseChatRepository(
      client,
    ).refreshAfterRealtime(conversationId: 'conversation-1');

    expect(refresh.conversationId, 'conversation-1');
    expect(refresh.latestMessageId, isNull);
    expect(refresh.unreadCount, 9);
  });

  test('projects the server receipt of a received message without inferring it', () async {
    final client = _client(
      (request) async => _json({
        'ok': true,
        'data': {
          'items': [
            {
              'message_id': 'message-1',
              'body_text': 'Bom dia',
              'author_name': 'Marina',
              'is_mine': false,
              'message_type': 'text',
              'created_at': '2026-09-07T12:00:00Z',
              'attachments': <Object?>[],
              'receipt': {
                'is_mine': true,
                'delivered_at': '2026-09-07T12:00:30Z',
                'read_at': '2026-09-07T12:01:00Z',
                'recipient_count': 0,
                'delivered_count': 0,
                'read_count': 0,
              },
            },
          ],
          'total': 1,
          'has_more': false,
          'next_cursor': null,
        },
        'error': null,
      }, request),
    );
    addTearDown(client.dispose);

    final message = (await SupabaseChatRepository(
      client,
    ).fetchThread(const ChatThreadQuery(conversationId: 'conversation-1'))).items.single;
    final receipt = message.receipt!;

    expect(message.isMine, isFalse);
    // Authorship comes from the message row; a receipt envelope cannot flip it.
    expect(receipt.isMine, isFalse);
    expect(receipt.deliveredAt, DateTime.utc(2026, 9, 7, 12, 0, 30));
    expect(receipt.readAt, DateTime.utc(2026, 9, 7, 12, 1));
    expect(receipt.isDeliveredToMe, isTrue);
    expect(receipt.isReadByMe, isTrue);
    expect(receipt.isReadByEveryone, isFalse);
  });

  for (final sample in <({String name, int recipients, int read, bool everyone})>[
    (name: 'every active recipient read it', recipients: 3, read: 3, everyone: true),
    (name: 'one recipient is missing', recipients: 3, read: 2, everyone: false),
    (name: 'no active recipient exists', recipients: 0, read: 0, everyone: false),
  ]) {
    test('aggregates the receipt counts of a sent message: ${sample.name}', () async {
      final client = _client(
        (request) async => _json({
          'ok': true,
          'data': {
            'items': [
              {
                'message_id': 'message-2',
                'body_text': 'Enviado por mim',
                'author_name': 'Eu',
                'is_mine': true,
                'message_type': 'text',
                'created_at': '2026-09-07T12:02:00Z',
                'attachments': <Object?>[],
                'receipt': {
                  'recipient_count': sample.recipients,
                  'delivered_count': sample.recipients,
                  'read_count': sample.read,
                },
              },
            ],
            'total': 1,
            'has_more': false,
            'next_cursor': null,
          },
          'error': null,
        }, request),
      );
      addTearDown(client.dispose);

      final receipt = (await SupabaseChatRepository(
        client,
      ).fetchThread(const ChatThreadQuery(conversationId: 'conversation-1'))).items.single.receipt!;

      expect(receipt.isMine, isTrue);
      expect(receipt.recipientCount, sample.recipients);
      expect(receipt.deliveredCount, sample.recipients);
      expect(receipt.readCount, sample.read);
      expect(receipt.isReadByEveryone, sample.everyone);
      expect(receipt.isDeliveredToEveryone, sample.recipients > 0);
      // The caller's own read state is meaningless for a message it sent.
      expect(receipt.isReadByMe, isFalse);
      expect(receipt.isDeliveredToMe, isFalse);
    });
  }

  test('never fabricates receipt, edit or management state the server omitted', () async {
    final client = _client(
      (request) async => _json({
        'ok': true,
        'data': {
          'items': [
            {
              'message_id': 'message-1',
              'body_text': 'Gateway antigo',
              'author_name': 'Marina',
              'is_mine': false,
              'message_type': 'text',
              'created_at': '2026-09-07T12:00:00Z',
              'attachments': <Object?>[],
            },
          ],
          'total': 1,
          'has_more': false,
          'next_cursor': null,
        },
        'error': null,
      }, request),
    );
    addTearDown(client.dispose);

    final message = (await SupabaseChatRepository(
      client,
    ).fetchThread(const ChatThreadQuery(conversationId: 'conversation-1'))).items.single;

    expect(message.receipt, isNull, reason: 'Absence is not "unread".');
    expect(message.editedAt, isNull);
    expect(message.isEdited, isFalse);
    expect(message.canManage, isFalse, reason: 'An omitted grant is never an affordance.');
  });

  for (final sample in <({String name, Map<String, Object?> overrides})>[
    (name: 'receipt is not an object', overrides: {'receipt': 'read'}),
    (name: 'receipt is a list', overrides: {'receipt': <Object?>[]}),
    (name: 'edited_at is unparseable', overrides: {'edited_at': 'ontem'}),
    (name: 'edited_at is not a string', overrides: {'edited_at': 1757246400}),
  ]) {
    test('refuses a malformed message envelope instead of degrading it (${sample.name})', () async {
      final client = _client(
        (request) async => _json({
          'ok': true,
          'data': {
            'items': [
              {
                'message_id': 'message-1',
                'body_text': 'Envelope inválido',
                'author_name': 'Marina',
                'is_mine': false,
                'message_type': 'text',
                'created_at': '2026-09-07T12:00:00Z',
                'attachments': <Object?>[],
                ...sample.overrides,
              },
            ],
            'total': 1,
            'has_more': false,
            'next_cursor': null,
          },
          'error': null,
        }, request),
      );
      addTearDown(client.dispose);

      await expectLater(
        SupabaseChatRepository(
          client,
        ).fetchThread(const ChatThreadQuery(conversationId: 'conversation-1')),
        throwsA(isA<ChatFailureException>()),
      );
    });
  }

  test('edits a message through its dedicated idempotent RPC', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json({
        'ok': true,
        'data': {
          'message_id': 'message-2',
          'body_text': 'Texto corrigido',
          'author_name': 'Eu',
          'is_mine': true,
          'message_type': 'text',
          'created_at': '2026-09-07T12:02:00Z',
          'edited_at': '2026-09-07T12:05:00Z',
          'can_manage': true,
          'attachments': <Object?>[],
        },
        'error': null,
      }, request);
    });
    addTearDown(client.dispose);

    final edited = await SupabaseChatRepository(client).editMessage(
      const ChatEditMessageCommand(
        conversationId: 'conversation-1',
        messageId: 'message-2',
        body: '  Texto corrigido  ',
        idempotencyKey: 'b1c0f0f4-4e0e-4b0a-9a0e-2f6d1b8b0c11',
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_chat_edit_message_v2'));
    expect(jsonDecode(captured!.body), {
      'p_conversation_id': 'conversation-1',
      'p_message_id': 'message-2',
      'p_body_text': 'Texto corrigido',
      'p_request_id': 'b1c0f0f4-4e0e-4b0a-9a0e-2f6d1b8b0c11',
    });
    expect(edited.id, 'message-2');
    expect(edited.conversationId, 'conversation-1');
    expect(edited.body, 'Texto corrigido');
    expect(edited.editedAt, DateTime.utc(2026, 9, 7, 12, 5));
    expect(edited.isEdited, isTrue);
    expect(edited.canManage, isTrue);
  });

  test('revokes a message and returns the server-recorded revocation', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json({
        'ok': true,
        'data': {'message_id': 'message-2', 'revoked_at': '2026-09-07T12:06:00Z'},
        'error': null,
      }, request);
    });
    addTearDown(client.dispose);

    final revocation = await SupabaseChatRepository(client).revokeMessage(
      const ChatRevokeMessageCommand(
        conversationId: 'conversation-1',
        messageId: 'message-2',
        idempotencyKey: 'c2d1a1b5-5f1f-4c1b-8b1f-3e7d2c9c1d22',
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_chat_revoke_message_v2'));
    expect(jsonDecode(captured!.body), {
      'p_conversation_id': 'conversation-1',
      'p_message_id': 'message-2',
      'p_request_id': 'c2d1a1b5-5f1f-4c1b-8b1f-3e7d2c9c1d22',
    });
    expect(revocation.messageId, 'message-2');
    expect(revocation.revokedAt, DateTime.utc(2026, 9, 7, 12, 6));
  });

  for (final sample in <({String code, ChatConflictReason reason})>[
    (code: 'CHAT_EDIT_WINDOW_CLOSED', reason: ChatConflictReason.editWindowClosed),
    (code: 'CHAT_ALREADY_REVOKED', reason: ChatConflictReason.alreadyRevoked),
  ]) {
    test('reports ${sample.code} as a state conflict, never as a lost session', () async {
      final client = _client(
        (request) async => _json({
          'ok': false,
          'data': null,
          'error': {
            'code': sample.code,
            'message': 'A mensagem recusou a alteração.',
            'http_status': 409,
          },
        }, request),
      );
      addTearDown(client.dispose);
      final repository = SupabaseChatRepository(client);

      for (final command in <Future<Object?> Function()>[
        () => repository.editMessage(
          const ChatEditMessageCommand(
            conversationId: 'conversation-1',
            messageId: 'message-2',
            body: 'Tarde demais',
            idempotencyKey: 'd3e2b2c6-6a2a-4d2c-9c2a-4f8e3d0d2e33',
          ),
        ),
        () => repository.revokeMessage(
          const ChatRevokeMessageCommand(
            conversationId: 'conversation-1',
            messageId: 'message-2',
            idempotencyKey: 'e4f3c3d7-7b3b-4e3d-8d3b-5a9f4e1e3f44',
          ),
        ),
      ]) {
        final error = await command().then<Object?>((_) => null, onError: (Object it) => it);
        expect(error, isA<ChatConflictException>());
        expect((error! as ChatConflictException).reason, sample.reason);
        // The command was refused by the message's own state; the session lives.
        expect(error, isNot(isA<ChatUnauthorizedException>()));
      }
    });
  }

  test('reports CHAT_READ_ONLY on send as a state conflict, never as a lost session', () async {
    // A conversa fechada para escrita nao e sessao perdida. As duas superficies
    // ja escondem o composer quando `isReadOnly`, entao esta recusa so chega
    // quando a conversa fechou DEPOIS da leitura: instantaneo velho. Mapear
    // como negacao fazia a pagina apagar inbox, thread, selecao e busca do
    // operador porque UMA conversa deixou de aceitar escrita.
    final client = _client(
      (request) async => _json({
        'ok': false,
        'data': null,
        'error': {
          'code': 'CHAT_READ_ONLY',
          'message': 'A conversa nao aceita novas mensagens.',
          'http_status': 409,
        },
      }, request),
    );
    addTearDown(client.dispose);
    final repository = SupabaseChatRepository(client);

    final error = await repository
        .sendMessage(
          const ChatSendMessageCommand(
            conversationId: 'conversation-1',
            body: 'Tudo bem?',
            idempotencyKey: 'f5a4d4e8-8c4c-4f4e-9e4c-6b0a5f2f4a55',
          ),
        )
        .then<Object?>((_) => null, onError: (Object it) => it);

    expect(error, isA<ChatConflictException>());
    expect((error! as ChatConflictException).reason, ChatConflictReason.readOnly);
    expect(error, isNot(isA<ChatUnauthorizedException>()));
  });

  test('treats CHAT_NOT_AUTHOR as unauthorized even inside an HTTP 200 envelope', () async {
    final client = _client(
      (request) async => _json({
        'ok': false,
        'data': null,
        'error': {
          'code': 'CHAT_NOT_AUTHOR',
          'message': 'Somente o autor pode alterar a mensagem.',
          'http_status': 200,
        },
      }, request),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseChatRepository(client).editMessage(
        const ChatEditMessageCommand(
          conversationId: 'conversation-1',
          messageId: 'message-de-outro-autor',
          body: 'Não é minha',
          idempotencyKey: 'f5a4d4e8-8c4c-4f4e-9e4c-6b0a5f2f4a55',
        ),
      ),
      throwsA(isA<ChatUnauthorizedException>()),
    );
  });
  test('a inbox carrega a preferencia da propria identidade', () async {
    // Fixar e bandeira sumiram da tela quando a inbox passou a vir do servidor.
    // Voltam pelo servidor: o cliente le o que a RPC projeta, sem estado local.
    final client = _client(
      (request) async => _json({
        'ok': true,
        'data': {
          'items': [
            {
              'conversation_id': 'conversa-1',
              'title': 'Familias',
              'latest_message_text': 'Bom dia',
              'scope_kind': 'institution',
              'conversation_type': 'institution',
              'unread_count': 0,
              'activity_at': '2026-09-10T12:00:00Z',
              'is_read_only': false,
              'pinned_at': '2026-09-10T11:00:00Z',
              'flag': 'red',
            },
          ],
          'total': 1,
          'total_unread': 0,
          'has_more': false,
          'next_cursor': null,
        },
        'error': null,
      }, request),
    );
    addTearDown(client.dispose);

    final page = await SupabaseChatRepository(
      client,
    ).fetchInbox(const ChatInboxQuery(pageSize: 30));

    expect(page.items.single.isPinned, isTrue);
    expect(page.items.single.flag, ChatConversationFlag.red);
  });

  test('bandeira desconhecida nao derruba a inbox', () async {
    final client = _client(
      (request) async => _json({
        'ok': true,
        'data': {
          'items': [
            {
              'conversation_id': 'conversa-1',
              'title': 'Familias',
              'latest_message_text': '',
              'scope_kind': 'institution',
              'conversation_type': 'institution',
              'unread_count': 0,
              'activity_at': '2026-09-10T12:00:00Z',
              'is_read_only': false,
              'flag': 'turquesa',
            },
          ],
          'total': 1,
          'total_unread': 0,
          'has_more': false,
          'next_cursor': null,
        },
        'error': null,
      }, request),
    );
    addTearDown(client.dispose);

    final page = await SupabaseChatRepository(
      client,
    ).fetchInbox(const ChatInboxQuery(pageSize: 30));

    expect(page.items.single.flag, ChatConversationFlag.none);
    expect(page.items.single.isPinned, isFalse);
  });

  test('fixar e sinalizar chamam as RPCs do realm interno', () async {
    final calls = <String>[];
    final client = _client((request) async {
      calls.add('${request.url.path}|${request.body}');
      return _json({
        'ok': true,
        'data': {
          'conversation_id': 'conversa-1',
          'pinned_at': '2026-09-10T11:00:00Z',
          'flag': 'blue',
        },
        'error': null,
      }, request);
    });
    addTearDown(client.dispose);
    final repository = SupabaseChatRepository(client);

    final pinned = await repository.setPinned(conversationId: 'conversa-1', pinned: true);
    final flagged = await repository.setFlag(
      conversationId: 'conversa-1',
      flag: ChatConversationFlag.blue,
    );

    expect(pinned.pinnedAt, isNotNull);
    expect(flagged.flag, ChatConversationFlag.blue);
    expect(calls.first, contains('superadmin_chat_set_pinned_v2'));
    expect(calls.first, contains('"p_pinned":true'));
    expect(calls.last, contains('superadmin_chat_set_flag_v2'));
    expect(calls.last, contains('"p_flag":"blue"'));
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
