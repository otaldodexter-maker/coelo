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

// Spec 058 (ADR 0042 E3): um lote de arquivos = UMA mensagem. prepare recebe
// items[], depois PUT + finalize por item; falha parcial não derruba o lote e
// o descarte de um item vai pela ação discard do gateway.
void main() {
  final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  final pdf = Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 52]);
  ChatAttachmentUpload item(String name, String type, Uint8List bytes) => ChatAttachmentUpload(
    conversationId: 'conversation-1',
    requestId: 'item-$name',
    fileName: name,
    contentType: type,
    bytes: bytes,
  );
  ChatAttachmentBatchUpload batch() => ChatAttachmentBatchUpload(
    conversationId: 'conversation-1',
    requestId: '9b400000-0000-4000-8000-000000000010',
    items: [item('a.png', 'image/png', png), item('b.pdf', 'application/pdf', pdf)],
  );
  String expiry() => DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String();

  test(
    'batch uses one prepare with items, then one binary upload through the Edge per item in order',
    () async {
      final actions = <String>[];
      var finalizeCount = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/functions/v1/chat-media');
          final body = _body(request);
          actions.add('${body['action']}:${body['attachment_id'] ?? ''}');
          if (body['action'] == 'prepare') {
            expect(body, {
              'action': 'prepare',
              'request_id': batch().requestId,
              'conversation_id': 'conversation-1',
              'items': [
                {
                  'file_name': 'a.png',
                  'content_type': 'image/png',
                  'byte_size': png.length,
                  'sha256': sha256.convert(png).toString(),
                },
                {
                  'file_name': 'b.pdf',
                  'content_type': 'application/pdf',
                  'byte_size': pdf.length,
                  'sha256': sha256.convert(pdf).toString(),
                },
              ],
            });
            return _json({
              'message_id': 'message-batch',
              'message_status': 'draft',
              'replayed': false,
              'items': [
                {
                  'index': 0,
                  'attachment_id': 'attachment-a',
                  'upload_url': 'https://private.example/a',
                  'required_headers': {'content-type': 'image/png'},
                  'expires_at': expiry(),
                  'upload_status': 'pending',
                  'replayed': false,
                },
                {
                  'index': 1,
                  'attachment_id': 'attachment-b',
                  'upload_url': 'https://private.example/b',
                  'required_headers': {'content-type': 'application/pdf'},
                  'expires_at': expiry(),
                  'upload_status': 'pending',
                  'replayed': false,
                },
              ],
            });
          }
          expect(body['action'], 'upload');
          expect(request.headers['content-type'], startsWith('application/octet-stream'));
          expect(request.bodyBytes, body['attachment_id'] == 'attachment-a' ? png : pdf);
          finalizeCount++;
          return _json({
            'message_id': 'message-batch',
            'attachment_id': body['attachment_id'],
            'upload_status': 'ready',
            'message_status': finalizeCount == 2 ? 'active' : 'draft',
          });
        }),
      );
      addTearDown(client.dispose);
      final progress = <String>[];
      final result = await SupabaseChatRepository(client)
          .uploadAttachmentBatch(
            batch(),
            onProgress: (snapshot) =>
                progress.add(snapshot.items.map((i) => i.state.name).join(',')),
          );
      expect(actions, ['prepare:', 'upload:attachment-a', 'upload:attachment-b']);
      expect(result.messageId, 'message-batch');
      expect(result.isPublished, isTrue);
      expect(result.items.map((i) => i.attachmentId), ['attachment-a', 'attachment-b']);
      expect(result.items.every((i) => i.state == ChatAttachmentBatchItemState.ready), isTrue);
      expect(progress, ['sending,waiting', 'ready,waiting', 'ready,sending', 'ready,ready']);
    },
  );

  test(
    'a failed Edge upload marks only that item failed, keeps going and leaves the message unpublished',
    () async {
      final actions = <String>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient((request) async {
          final body = _body(request);
          actions.add('${body['action']}:${body['attachment_id'] ?? ''}');
          if (body['action'] == 'prepare') {
            return _json({
              'message_id': 'message-batch',
              'message_status': 'draft',
              'items': [
                {
                  'index': 0,
                  'attachment_id': 'attachment-a',
                  'upload_url': 'https://private.example/a',
                  'required_headers': {'content-type': 'image/png'},
                  'expires_at': expiry(),
                  'upload_status': 'pending',
                },
                {
                  'index': 1,
                  'attachment_id': 'attachment-b',
                  'upload_url': 'https://private.example/b',
                  'required_headers': {'content-type': 'application/pdf'},
                  'expires_at': expiry(),
                  'upload_status': 'pending',
                },
              ],
            });
          }
          if (body['attachment_id'] == 'attachment-a') {
            return Response(
              jsonEncode({'error': 'uploaded_attachment_mismatch'}),
              422,
              headers: {'content-type': 'application/json'},
            );
          }
          return _json({
            'message_id': 'message-batch',
            'attachment_id': body['attachment_id'],
            'upload_status': 'ready',
            'message_status': 'draft',
          });
        }),
      );
      addTearDown(client.dispose);
      final result = await SupabaseChatRepository(client).uploadAttachmentBatch(batch());
      expect(actions, ['prepare:', 'upload:attachment-a', 'upload:attachment-b']);
      expect(result.isPublished, isFalse);
      expect(result.items[0].state, ChatAttachmentBatchItemState.failed);
      expect(result.items[0].error, isA<ChatFailureException>());
      expect(result.items[1].state, ChatAttachmentBatchItemState.ready);
      expect(result.failed.map((i) => i.attachmentId), ['attachment-a']);
    },
  );

  test(
    '11th item refused by the gateway maps to the per-message limit before any upload',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient(
          (request) async => Response(
            jsonEncode({'error': 'chat_attachment_limit'}),
            422,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      var uploads = 0;
      final upload = MockClient((_) async {
        uploads++;
        return Response('', 200);
      });
      final eleven = ChatAttachmentBatchUpload(
        conversationId: 'conversation-1',
        requestId: '9b400000-0000-4000-8000-000000000011',
        items: [for (var i = 0; i < 11; i++) item('f$i.png', 'image/png', png)],
      );
      await expectLater(
        SupabaseChatRepository(client, uploadClient: upload).uploadAttachmentBatch(eleven),
        throwsA(isA<ChatAttachmentLimitException>()),
      );
      expect(uploads, 0);
    },
  );

  test(
    'discard goes through the gateway and reports the message status decided by the server',
    () async {
      late Map<String, dynamic> sent;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({
            'attachment_id': 'attachment-a',
            'message_id': 'message-batch',
            'upload_status': 'deleted',
            'message_status': 'active',
            'attachments': const [],
          });
        }),
      );
      addTearDown(client.dispose);
      final result = await SupabaseChatRepository(client).discardAttachment('attachment-a');
      expect(sent, {'action': 'discard', 'attachment_id': 'attachment-a'});
      expect(result.messageId, 'message-batch');
      expect(result.messageStatus, 'active');
    },
  );

  test('a replayed item already ready is not uploaded nor finalized again', () async {
    final actions = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = _body(request);
        actions.add(body['action'] as String);
        if (body['action'] == 'prepare') {
          return _json({
            'message_id': 'message-batch',
            'message_status': 'draft',
            'replayed': true,
            'items': [
              {
                'index': 0,
                'attachment_id': 'attachment-a',
                'upload_url': 'https://private.example/a',
                'required_headers': {'content-type': 'image/png'},
                'expires_at': expiry(),
                'upload_status': 'ready',
                'replayed': true,
              },
              {
                'index': 1,
                'attachment_id': 'attachment-b',
                'upload_url': 'https://private.example/b',
                'required_headers': {'content-type': 'application/pdf'},
                'expires_at': expiry(),
                'upload_status': 'pending',
                'replayed': false,
              },
            ],
          });
        }
        return _json({
          'message_id': 'message-batch',
          'attachment_id': body['attachment_id'],
          'upload_status': 'ready',
          'message_status': 'active',
        });
      }),
    );
    addTearDown(client.dispose);
    final result = await SupabaseChatRepository(client).uploadAttachmentBatch(batch());
    expect(actions, ['prepare', 'upload'], reason: 'só o item pendente sobe');
    expect(result.isPublished, isTrue);
  });
}

/// Corpo lógico do pedido: o JSON, ou o envelope do upload binário com `action: upload`.
Map<String, dynamic> _body(Request request) {
  final raw = request.headers[edgeMediaEnvelopeHeader];
  if (raw == null) return jsonDecode(request.body) as Map<String, dynamic>;
  final padded = raw + '=' * ((4 - raw.length % 4) % 4);
  return {...jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>, 'action': 'upload'};
}

Response _json(Map<String, Object?> body) =>
    Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
