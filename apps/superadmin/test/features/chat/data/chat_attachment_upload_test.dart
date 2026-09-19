import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/chat/data/supabase_chat_repository.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/shared/data/edge_media_bytes.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Bytes pela Edge (ADR 0032): o navegador nunca faz PUT/GET direto ao R2. O
// anexo sobe num POST binário com `{attachment_id}` no cabeçalho
// `x-coelo-media-envelope` (a Edge autoriza pelo bilhete do dono, grava e
// finaliza); a leitura devolve os bytes inline.
void main() {
  final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  ChatAttachmentUpload command() => ChatAttachmentUpload(
    conversationId: 'conversation-1',
    requestId: '9b400000-0000-4000-8000-000000000002',
    fileName: 'imagem.png',
    contentType: 'image/png',
    bytes: bytes,
  );

  test('upload uses prepare and one binary upload through the Edge before returning', () async {
    final actions = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/functions/v1/chat-media');
        final body = _body(request);
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
        expect(body, {'action': 'upload', 'attachment_id': 'attachment-1'});
        expect(request.headers['content-type'], startsWith('application/octet-stream'));
        expect(request.bodyBytes, bytes);
        return _json({'message_id': 'message-1', 'attachment_id': 'attachment-1'});
      }),
    );
    addTearDown(client.dispose);
    expect(await SupabaseChatRepository(client).uploadAttachment(command()), 'message-1');
    expect(actions, ['prepare', 'upload'], reason: 'sem PUT assinado nem finalize à parte');
  });

  test('failed Edge upload never reports a sent message', () async {
    final actions = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = _body(request);
        actions.add(body['action'] as String);
        if (body['action'] == 'upload') {
          return Response(
            jsonEncode({'error': 'uploaded_attachment_mismatch'}),
            422,
            headers: {'content-type': 'application/json'},
          );
        }
        return _json({
          'message_id': 'message-1',
          'attachment_id': 'attachment-1',
          'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
          'replayed': false,
        });
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseChatRepository(client).uploadAttachment(command()),
      throwsA(isA<ChatFailureException>()),
    );
    expect(actions, ['prepare', 'upload']);
  });

  test('read reauthorizes by binding and returns a local URL from the bytes', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        calls++;
        expect(_body(request), {'action': 'read', 'attachment_id': 'attachment-1', 'inline': true});
        return Response.bytes(bytes, 200, headers: {'content-type': 'application/octet-stream'});
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseChatRepository(client);
    final result = await repository.readAttachment('attachment-1');
    expect(result.url.toString(), startsWith('data:image/png;base64,'));
    expect(result.expiresAt.isAfter(DateTime.now().toUtc()), true);
    await repository.readAttachment('attachment-1');
    expect(calls, 2);
  });

  test('replayed ready upload confirms by an authorized read without uploading again', () async {
    final actions = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = _body(request);
        actions.add(body['action'] as String);
        if (body['action'] == 'prepare') {
          return _json({
            'message_id': 'message-1',
            'attachment_id': 'attachment-1',
            'upload_status': 'ready',
            'replayed': true,
          });
        }
        return Response.bytes(bytes, 200, headers: {'content-type': 'application/octet-stream'});
      }),
    );
    addTearDown(client.dispose);
    expect(await SupabaseChatRepository(client).uploadAttachment(command()), 'message-1');
    expect(actions, ['prepare', 'read']);
  });

  test('replayed ready upload keeps a refused read unauthorized without uploading', () async {
    final actions = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = _body(request);
        actions.add(body['action'] as String);
        if (body['action'] == 'prepare') {
          return _json({
            'message_id': 'message-1',
            'attachment_id': 'attachment-1',
            'upload_status': 'ready',
            'replayed': true,
          });
        }
        return Response(
          '{"error":"chat_attachment_not_ready"}',
          403,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseChatRepository(client).uploadAttachment(command()),
      throwsA(isA<ChatUnauthorizedException>()),
    );
    expect(actions, ['prepare', 'read']);
  });

  test('legacy replay without a status confirms by read without uploading', () async {
    final actions = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = _body(request);
        actions.add(body['action'] as String);
        if (body['action'] == 'prepare') {
          return _json({'message_id': 'message-1', 'attachment_id': 'attachment-1', 'replayed': true});
        }
        return Response.bytes(bytes, 200, headers: {'content-type': 'application/octet-stream'});
      }),
    );
    addTearDown(client.dispose);
    expect(await SupabaseChatRepository(client).uploadAttachment(command()), 'message-1');
    expect(actions, ['prepare', 'read']);
  });

  for (final uploadStatus in ['failed', 'expired']) {
    test('replayed $uploadStatus upload never writes or finalizes', () async {
      final actions = <String>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient((request) async {
          final body = _body(request);
          actions.add(body['action'] as String);
          return _json({
            'message_id': 'message-1',
            'attachment_id': 'attachment-1',
            'upload_status': uploadStatus,
            'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
            'replayed': true,
          });
        }),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseChatRepository(client).uploadAttachment(command()),
        throwsA(isA<ChatFailureException>()),
      );
      expect(actions, ['prepare']);
    });
  }

  test('malformed non-replayed prepare never writes or finalizes', () async {
    final actions = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = _body(request);
        actions.add(body['action'] as String);
        return _json({
          'message_id': 'message-1',
          'attachment_id': 'attachment-1',
          'upload_status': 7,
          'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
          'replayed': false,
        });
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseChatRepository(client).uploadAttachment(command()),
      throwsA(isA<ChatFailureException>()),
    );
    expect(actions, ['prepare']);
  });

  test('expired prepare window never uploads', () async {
    final actions = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = _body(request);
        actions.add(body['action'] as String);
        return _json({
          'message_id': 'message-1',
          'attachment_id': 'attachment-1',
          'upload_status': 'pending',
          'expires_at': DateTime.now().toUtc().subtract(const Duration(minutes: 1)).toIso8601String(),
          'replayed': false,
        });
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseChatRepository(client).uploadAttachment(command()),
      throwsA(isA<ChatFailureException>()),
    );
    expect(actions, ['prepare']);
  });

  test('replayed pending upload resumes the existing ticket without a duplicate message', () async {
    final actions = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = _body(request);
        actions.add(body['action'] as String);
        if (body['action'] == 'prepare') {
          return _json({
            'message_id': 'message-1',
            'attachment_id': 'attachment-1',
            'upload_status': 'pending',
            'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
            'replayed': true,
          });
        }
        expect(body, {'action': 'upload', 'attachment_id': 'attachment-1'});
        expect(request.bodyBytes, bytes);
        return _json({'message_id': 'message-1', 'attachment_id': 'attachment-1'});
      }),
    );
    addTearDown(client.dispose);
    expect(await SupabaseChatRepository(client).uploadAttachment(command()), 'message-1');
    expect(actions, ['prepare', 'upload']);
  });

  test('maps chat_attachment_limit to the per-send limit exception', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (_) async => Response(
          jsonEncode({'error': 'chat_attachment_limit'}),
          422,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseChatRepository(client).uploadAttachment(command()),
      throwsA(isA<ChatAttachmentLimitException>()),
    );
  });

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

/// Corpo lógico do pedido: o JSON, ou o envelope do upload binário com `action: upload`.
Map<String, dynamic> _body(Request request) {
  final raw = request.headers[edgeMediaEnvelopeHeader];
  if (raw == null) return jsonDecode(request.body) as Map<String, dynamic>;
  final padded = raw + '=' * ((4 - raw.length % 4) % 4);
  return {...jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>, 'action': 'upload'};
}

Response _json(Object body) =>
    Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
