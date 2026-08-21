import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_moments_publication/data/supabase_moments_publication_repository.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/domain/moments_publication.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('salva, envia ao R2 por PUT e publica sem expor credenciais', () async {
    final functionBodies = <Map<String, dynamic>>[];
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
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.contains('/functions/v1/moments-media')) {
          functionBodies.add(body);
          final response = body['action'] == 'prepare'
              ? {
                  'asset_id': 'asset-1',
                  'object_key': 'institution/moments/asset-1/original',
                  'upload_url': 'https://upload.test/object?signature=short-lived',
                  'required_headers': {'Content-Type': 'video/mp4'},
                }
              : {'asset_id': 'asset-1', 'object_key': 'institution/moments/asset-1/original'};
          return _json(response, request);
        }
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
    http.Request? upload;
    final repository = SupabaseMomentsPublicationRepository(
      client,
      httpClient: MockClient((request) async {
        upload = request;
        return http.Response('', 200, request: request);
      }),
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
    expect(upload?.method, 'PUT');
    expect(upload?.bodyBytes, [1, 2, 3]);
    expect(upload?.headers['content-type'], 'video/mp4');
    expect(functionBodies.map((body) => body['action']), ['prepare', 'finalize']);
    expect(functionBodies.first, isNot(contains('content_base64')));
    expect(functionBodies.last['asset_id'], 'asset-1');
    expect(functionBodies.last['finalize_request_id'], '33333333-3333-4333-8333-333333333333');
    expect(
      rpcBodies['save_moments_draft']?['p_request_id'],
      '11111111-1111-4111-8111-111111111111',
    );
    expect(rpcBodies['publish_moment']?['p_publication_id'], 'publication-1');
  });

  test('mantém IDs da operação durante retry e restaura URL de leitura curta', () async {
    final prepareIds = <String>[];
    final saveIds = <String>[];
    var uploadAttempts = 0;
    var generated = 0;
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('/rpc/load_moments_draft')) {
          return _json({
            'id': 'publication-1',
            'version': 1,
            'caption': 'Esporte',
            'audiences': ['families'],
            'media': [
              {
                'asset_id': 'asset-ready',
                'name': 'corrida.mp4',
                'mime_type': 'video/mp4',
                'duration_milliseconds': 8000,
                'display_order': 0,
              },
            ],
          }, request);
        }
        if (request.url.path.contains('/functions/v1/moments-media')) {
          if (body['action'] == 'read') {
            return _json({'signed_url': 'https://read.test/object?token=short'}, request);
          }
          if (body['action'] == 'prepare') {
            prepareIds.add(body['request_id'] as String);
            return _json({
              'asset_id': 'asset-1',
              'object_key': 'institution/moments/asset-1/original',
              'upload_url': 'https://upload.test/object?signature=short',
              'required_headers': {'Content-Type': 'image/png'},
            }, request);
          }
          return _json({'asset_id': 'asset-1'}, request);
        }
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
      httpClient: MockClient((request) async {
        uploadAttempts++;
        if (uploadAttempts == 1) throw http.ClientException('offline', request.url);
        return http.Response('', 200, request: request);
      }),
      requestIdFactory: () =>
          '00000000-0000-4000-8000-${(++generated).toString().padLeft(12, '0')}',
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

    expect(prepareIds, hasLength(2));
    expect(prepareIds.toSet(), hasLength(1));
    expect(saveIds, hasLength(2));
    expect(saveIds.toSet(), hasLength(1));
    expect(loaded?.media.single.remoteUrl, 'https://read.test/object?token=short');
    expect(loaded?.media.single.bytes, isEmpty);
  });
}

http.Response _json(Object body, http.Request request) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);
