import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/chat/data/supabase_chat_repository.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  ChatAttachmentUpload command() => ChatAttachmentUpload(
    conversationId: 'conversation-1',
    requestId: '9b400000-0000-4000-8000-000000000002',
    fileName: 'imagem.png',
    contentType: 'image/png',
    bytes: bytes,
  );

  test('upload uses prepare, isolated signed PUT and finalize before returning', () async {
    final actions = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/functions/v1/chat-media');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        actions.add(body['action'] as String);
        if (body['action'] == 'prepare') {
          expect(body, {
            'action': 'prepare',
            'request_id': command().requestId,
            'conversation_id': 'conversation-1',
            'file_name': 'imagem.png',
            'content_type': 'image/png',
            'byte_size': bytes.length,
            'sha256': sha256.convert(bytes).toString(),
          });
          return _json({
            'message_id': 'message-1',
            'attachment_id': 'attachment-1',
            'upload_url': 'https://private.example/signed',
            'required_headers': {'content-type': 'image/png', 'x-amz-meta-upload': 'required'},
            'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
            'replayed': false,
          });
        }
        expect(body, {'action': 'finalize', 'attachment_id': 'attachment-1'});
        return _json({'message_id': 'message-1', 'attachment_id': 'attachment-1'});
      }),
    );
    addTearDown(client.dispose);
    final upload = MockClient((request) async {
      actions.add('PUT');
      expect(request.method, 'PUT');
      expect(request.followRedirects, isFalse);
      expect(request.url.toString(), 'https://private.example/signed');
      expect(request.bodyBytes, bytes);
      expect(request.headers['content-type'], 'image/png');
      expect(request.headers['x-amz-meta-upload'], 'required');
      expect(request.headers.containsKey('authorization'), false);
      expect(request.headers.containsKey('apikey'), false);
      return Response('', 200);
    });
    expect(
      await SupabaseChatRepository(client, uploadClient: upload).uploadAttachment(command()),
      'message-1',
    );
    expect(actions, ['prepare', 'PUT', 'finalize']);
  });

  test('failed PUT never finalizes or reports a sent message', () async {
    final actions = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        actions.add(body['action'] as String);
        return _json({
          'message_id': 'message-1',
          'attachment_id': 'attachment-1',
          'upload_url': 'https://private.example/signed',
          'required_headers': {'content-type': 'image/png'},
          'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
          'replayed': false,
        });
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseChatRepository(
      client,
      uploadClient: MockClient((_) async => Response('', 403)),
    );
    await expectLater(repository.uploadAttachment(command()), throwsA(isA<ChatFailureException>()));
    expect(actions, ['prepare']);
  });

  test('read reauthorizes by binding without fabricating a canonical asset', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        calls++;
        expect(jsonDecode(request.body), {'action': 'read', 'attachment_id': 'attachment-1'});
        return _json({
          'attachment_id': 'attachment-1',
          'signed_url': 'https://private.example/read',
          'content_type': 'image/png',
          'expires_in': 300,
        });
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseChatRepository(client);
    final result = await repository.readAttachment('attachment-1');
    expect(result.url.toString(), 'https://private.example/read');
    expect(result.expiresAt.isAfter(DateTime.now().toUtc()), true);
    await repository.readAttachment('attachment-1');
    expect(calls, 2);
  });

  for (final ready in [true, false]) {
    test('replayed upload confirms ready=$ready by an authorized read without PUT', () async {
      final actions = <String>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          actions.add(body['action'] as String);
          if (body['action'] == 'prepare') {
            return _json({
              'message_id': 'message-1',
              'attachment_id': 'attachment-1',
              'replayed': true,
            });
          }
          if (!ready) {
            return Response(
              '{"error":"chat_attachment_not_ready"}',
              403,
              headers: {'content-type': 'application/json'},
            );
          }
          return _json({
            'attachment_id': 'attachment-1',
            'signed_url': 'https://private.example/read',
            'expires_in': 300,
          });
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseChatRepository(
        client,
        uploadClient: MockClient((_) async => throw StateError('must not PUT again')),
      );
      if (ready) {
        expect(await repository.uploadAttachment(command()), 'message-1');
      } else {
        await expectLater(
          repository.uploadAttachment(command()),
          throwsA(isA<ChatUnauthorizedException>()),
        );
      }
      expect(actions, ['prepare', 'read']);
    });
  }

  for (final scenario in ['redirect', 'wrong-mime']) {
    test('signed upload refuses $scenario without finalize', () async {
      final actions = <String>[];
      var puts = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient((request) async {
          actions.add((jsonDecode(request.body) as Map<String, dynamic>)['action'] as String);
          return _json({
            'message_id': 'message-1',
            'attachment_id': 'attachment-1',
            'upload_url': 'https://private.example/signed',
            'required_headers': {
              'content-type': scenario == 'wrong-mime' ? 'application/pdf' : 'image/png',
            },
            'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
            'replayed': false,
          });
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseChatRepository(
        client,
        uploadClient: MockClient((request) async {
          puts++;
          expect(request.followRedirects, isFalse);
          expect(request.headers, {'content-type': 'image/png'});
          return Response('', 307, headers: {'location': 'https://other.invalid/file'});
        }),
      );
      await expectLater(
        repository.uploadAttachment(command()),
        throwsA(isA<ChatFailureException>()),
      );
      expect(actions, ['prepare']);
      expect(puts, scenario == 'wrong-mime' ? 0 : 1);
    });
  }

  for (final code in ['chat_read_only', 'sai_permission_denied']) {
    test('maps lowercase gateway refusal $code from status422', () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient(
          (_) async => Response(
            jsonEncode({'error': code}),
            422,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseChatRepository(client).uploadAttachment(command()),
        throwsA(
          code == 'chat_read_only'
              ? isA<ChatConflictException>()
              : isA<ChatUnauthorizedException>(),
        ),
      );
    });
  }

  test('image size limit rejects before any remote write', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((_) async => throw StateError('must not call')),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseChatRepository(client).uploadAttachment(
        ChatAttachmentUpload(
          conversationId: 'conversation-1',
          requestId: command().requestId,
          fileName: 'grande.png',
          contentType: 'image/png',
          bytes: Uint8List(4 * 1024 * 1024 + 1),
        ),
      ),
      throwsA(isA<ChatAttachmentInvalidException>()),
    );
  });
}

Response _json(Object body) =>
    Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
