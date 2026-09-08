import 'dart:typed_data';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/chat/data/supabase_chat_repository.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The chat consumer bridged onto the approved common upload core.
///
/// A controlled gateway proves the client side only: there is still no
/// authorised chat endpoint, so production keeps failing closed.
void main() {
  final draft = ChatAttachmentDraft(
    fileName: 'registro.png',
    mediaType: 'image/png',
    bytes: List<int>.filled(64, 7),
  );

  ChatAttachmentUploadCommand command() => ChatAttachmentUploadCommand(
    conversationId: _conversationId,
    draft: draft,
    idempotencyKey: _requestId,
    finalizeIdempotencyKey: _finalizeRequestId,
  );

  test('stays unavailable while no uploader is injected', () async {
    final client = _client();
    addTearDown(client.dispose);
    await expectLater(
      SupabaseChatRepository(client).uploadAttachment(command()),
      throwsA(isA<ChatAttachmentUnavailableException>()),
    );
  });

  test('refuses an invalid file before touching the uploader', () async {
    final client = _client();
    addTearDown(client.dispose);
    final gateway = _RecordingGateway();
    await expectLater(
      SupabaseChatRepository(client, attachmentUploader: _uploader(gateway)).uploadAttachment(
        ChatAttachmentUploadCommand(
          conversationId: _conversationId,
          draft: ChatAttachmentDraft(
            fileName: 'planilha.xlsx',
            mediaType: 'application/vnd.ms-excel',
            bytes: List<int>.filled(8, 1),
          ),
          idempotencyKey: _requestId,
          finalizeIdempotencyKey: _finalizeRequestId,
        ),
      ),
      throwsA(isA<ChatAttachmentRejectedException>()),
    );
    expect(gateway.prepared, isEmpty);
  });

  test('declares the measured checksum and keeps both intent ids', () async {
    final client = _client();
    addTearDown(client.dispose);
    final gateway = _RecordingGateway();
    final attachment = await SupabaseChatRepository(
      client,
      attachmentUploader: _uploader(gateway),
    ).uploadAttachment(command());

    expect(gateway.prepared.single.mimeType, 'image/png');
    expect(gateway.prepared.single.byteLength, 64);
    expect(
      gateway.prepared.single.checksumSha256,
      sha256.convert(List<int>.filled(64, 7)).toString(),
    );
    expect(gateway.prepareRequestIds.single, _requestId);
    expect(
      gateway.finalizeRequestIds.single,
      _finalizeRequestId,
      reason: 'prepare and finalize must not share an intent id',
    );

    // The stored attachment reflects the server receipt, not the local file.
    expect(attachment.assetId, _assetId);
    expect(attachment.mediaType, 'image/jpeg');
    expect(attachment.byteSize, 32);
    expect(attachment.fileName, 'registro.png');
  });

  for (final state in const [
    MediaUploadState.processing,
    MediaUploadState.expired,
    MediaUploadState.unavailable,
  ]) {
    test('a ${state.name} result never becomes a stored attachment', () async {
      final client = _client();
      addTearDown(client.dispose);
      await expectLater(
        SupabaseChatRepository(
          client,
          attachmentUploader: _uploader(_RecordingGateway(finalState: state)),
        ).uploadAttachment(command()),
        throwsA(isA<ChatAttachmentUnavailableException>()),
      );
    });
  }
}

const _conversationId = '11111111-1111-4111-8111-111111111111';
const _requestId = '22222222-2222-4222-8222-222222222222';
const _finalizeRequestId = '55555555-5555-4555-8555-555555555555';
const _assetId = '33333333-3333-4333-8333-333333333333';

final _target = MediaUploadTarget(
  institutionId: '44444444-4444-4444-8444-444444444444',
  resourceId: _conversationId,
  domain: 'chat',
  purpose: 'attachment',
);

SessionMediaUploader _uploader(_RecordingGateway gateway) =>
    SessionMediaUploader(gateway: gateway, session: MediaSession(), put: (transfer) async {});

SupabaseClient _client() => SupabaseClient(
  'https://coelo.test',
  'publishable-key',
  httpClient: MockClient(
    (request) async =>
        http.Response('{}', 200, headers: {'content-type': 'application/json'}, request: request),
  ),
);

final class _RecordingGateway implements MediaUploadGateway {
  _RecordingGateway({this.finalState = MediaUploadState.ready});

  final MediaUploadState finalState;
  final List<MediaUploadMetadata> prepared = [];
  final List<String> prepareRequestIds = [];
  final List<String> finalizeRequestIds = [];

  @override
  MediaUploadTarget get target => _target;

  @override
  Future<MediaUploadPreparation> prepare({
    required String requestId,
    required MediaUploadMetadata sourceMetadata,
  }) async {
    prepared.add(sourceMetadata);
    prepareRequestIds.add(requestId);
    return MediaUploadPreparation.fromJson({
      'request_id': requestId,
      'state': 'uploadRequired',
      'target': _target.toJson(),
      'asset_id': _assetId,
      'ticket': {
        'url': 'https://media.example/put',
        'headers': {'content-type': sourceMetadata.mimeType},
        'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
      },
    });
  }

  @override
  Future<MediaUploadResult> finalize({required String requestId, required String assetId}) async {
    finalizeRequestIds.add(requestId);
    return _result(finalState);
  }

  @override
  Future<MediaUploadResult> reconcile({required String assetId}) async => _result(finalState);

  @override
  Future<void> discard({required String requestId, required String assetId}) async {}

  MediaUploadResult _result(MediaUploadState state) => MediaUploadResult.fromJson({
    'target': _target.toJson(),
    'asset_id': _assetId,
    'state': state.name,
    if (state == MediaUploadState.ready)
      'receipt': {
        'mime_type': 'image/jpeg',
        'byte_length': 32,
        'checksum_sha256': sha256.convert(Uint8List(32)).toString(),
      },
  });
}
