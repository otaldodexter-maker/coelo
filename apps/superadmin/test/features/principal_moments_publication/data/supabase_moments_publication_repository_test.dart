import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_moments_publication/data/supabase_moments_publication_repository.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/domain/moments_publication.dart';
import 'package:coelo_superadmin/shared/data/edge_media_bytes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Bytes pela Edge (ADR 0032, mesmo desenho do entity-media): o navegador
// nunca faz PUT/GET direto ao R2. O upload é um POST binário com o envelope
// no cabeçalho `x-coelo-media-envelope`; a leitura devolve os bytes inline.
void main() {
  test('upload recusado pela Edge não finaliza nem publica', () async {
    final actions = <String>[];
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/save_moments_draft')) {
          return _json({'id': 'publication-1', 'version': 1}, request);
        }
        if (request.url.path.contains('/functions/v1/moments-media')) {
          actions.add(request.headers.containsKey(edgeMediaEnvelopeHeader) ? 'upload' : 'json');
          return http.Response(
            jsonEncode({'error': 'uploaded_media_mismatch'}),
            422,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        actions.add('rpc:${request.url.pathSegments.last}');
        return _json({}, request);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseMomentsPublicationRepository(client);
    await expectLater(
      repository.publish(
        MomentsPublicationContext.demo,
        MomentsDraft(
          audiences: const {MomentsAudienceKind.families},
          media: [
            MomentsMediaDraft.local(
              localId: 'local-1',
              name: 'image.png',
              mimeType: 'image/png',
              bytes: Uint8List(8),
            ),
          ],
        ),
      ),
      throwsA(isA<EdgeMediaException>()),
    );
    expect(actions, ['upload'], reason: 'sem finalize nem publish_moment');
  });

  test('salva, envia os bytes pela Edge e publica sem URL assinada', () async {
    final uploads = <http.Request>[];
    final rpcBodies = <String, Map<String, dynamic>>{};
    final requestIds = <String>[
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
      '33333333-3333-4333-8333-333333333333',
      '44444444-4444-4444-8444-444444444444',
    ];
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/functions/v1/moments-media')) {
          uploads.add(request);
          return _json({'asset_id': 'asset-1', 'status': 'ready'}, request);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final rpc = request.url.pathSegments.last;
        rpcBodies[rpc] = body;
        if (rpc == 'save_moments_draft') {
          return _json({'id': 'publication-1', 'version': 1, 'receipt_id': 'receipt-1'}, request);
        }
        return _json({
          'publication_id': 'publication-1',
          'status': 'published',
          'version': 2,
          'published_at': '2026-08-21T12:00:00Z',
          'receipt_id': 'receipt-2',
        }, request);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseMomentsPublicationRepository(
      client,
      requestIdFactory: () => requestIds.removeAt(0),
    );
    final draft = MomentsDraft(
      caption: 'Feira de ciências',
      audiences: const {MomentsAudienceKind.families},
      media: [
        MomentsMediaDraft.local(
          localId: 'local-1',
          name: 'experimento.mp4',
          mimeType: 'video/mp4',
          bytes: Uint8List.fromList([1, 2, 3]),
          durationMilliseconds: 12000,
        ),
      ],
    );

    final publication = await repository.publish(MomentsPublicationContext.demo, draft);

    expect(publication.id, 'publication-1');
    expect(publication.status, MomentsStatus.published);
    final upload = uploads.single;
    expect(upload.method, 'POST');
    expect(upload.headers['content-type'], startsWith('application/octet-stream'));
    expect(upload.bodyBytes, [1, 2, 3]);
    final envelope = _envelope(upload);
    expect(envelope.containsKey('action'), isFalse, reason: 'a Edge é quem decide a ação do binário');
    expect(envelope['publication_id'], 'publication-1');
    expect(envelope['mime_type'], 'video/mp4');
    expect(envelope['size_bytes'], 3);
    expect(envelope['duration_milliseconds'], 12000);
    expect(envelope['finalize_request_id'], '33333333-3333-4333-8333-333333333333');
    expect(envelope.containsKey('content_base64'), isFalse);
    expect(rpcBodies['save_moments_draft']?['p_request_id'], '11111111-1111-4111-8111-111111111111');
    expect(rpcBodies['publish_moment']?['p_publication_id'], 'publication-1');
  });

  test('mantém IDs da operação durante retry e lê a mídia gravada pela Edge', () async {
    final uploadIds = <String>[];
    final saveIds = <String>[];
    var uploadAttempts = 0;
    var generated = 0;
    final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]);
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/load_moments_draft')) {
          return _json({
            'id': 'publication-1',
            'version': 1,
            'caption': 'Esporte',
            'audiences': ['families'],
            'media': [
              {'asset_id': 'asset-ready', 'name': 'foto.png', 'mime_type': 'image/png', 'display_order': 0},
            ],
          }, request);
        }
        if (request.url.path.contains('/functions/v1/moments-media')) {
          if (request.headers.containsKey(edgeMediaEnvelopeHeader)) {
            uploadIds.add(_envelope(request)['request_id'] as String);
            uploadAttempts++;
            if (uploadAttempts == 1) throw http.ClientException('offline', request.url);
            return _json({'asset_id': 'asset-1', 'status': 'ready'}, request);
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body, {'action': 'read', 'asset_id': 'asset-ready', 'inline': true});
          return http.Response.bytes(
            png,
            200,
            headers: {'content-type': 'application/octet-stream'},
            request: request,
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('/rpc/save_moments_draft')) {
          saveIds.add(body['p_request_id'] as String);
          return _json({'id': 'publication-1', 'version': 1}, request);
        }
        return _json({'publication_id': 'publication-1', 'status': 'published'}, request);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseMomentsPublicationRepository(
      client,
      requestIdFactory: () => '00000000-0000-4000-8000-${(++generated).toString().padLeft(12, '0')}',
    );
    final local = MomentsMediaDraft.local(
      localId: 'local-retry',
      name: 'foto.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList([1]),
    );
    final draft = MomentsDraft(audiences: const {MomentsAudienceKind.families}, media: [local]);

    await expectLater(repository.publish(MomentsPublicationContext.demo, draft), throwsException);
    await repository.publish(MomentsPublicationContext.demo, draft);
    final loaded = await repository.loadDraft(MomentsPublicationContext.demo);

    expect(uploadIds, hasLength(2));
    expect(uploadIds.toSet(), hasLength(1), reason: 'o retry reaproveita o request_id');
    expect(saveIds, hasLength(2));
    expect(saveIds.toSet(), hasLength(1));
    expect(
      loaded?.media.single.remoteUrl,
      startsWith('data:image/png;base64,'),
      reason: 'URL local a partir dos bytes (blob: no navegador)',
    );
    expect(loaded?.media.single.bytes, isEmpty);
  });
}

Map<String, dynamic> _envelope(http.Request request) {
  final raw = request.headers[edgeMediaEnvelopeHeader]!;
  final padded = raw + '=' * ((4 - raw.length % 4) % 4);
  return jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>;
}

http.Response _json(Object body, http.Request request) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);
