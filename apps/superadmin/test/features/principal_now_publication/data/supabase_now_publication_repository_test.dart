import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_now_publication/data/supabase_now_publication_repository.dart';
import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('envia mídia por upload assinado sem base64 na Edge Function', () async {
    final functionBodies = <Map<String, dynamic>>[];
    http.Request? storageRequest;
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/functions/v1/now-media')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          functionBodies.add(body);
          final response = body['action'] == 'prepare'
              ? {
                  'asset_id': 'asset-1',
                  'object_key': 'institution/publication/media',
                  'upload_token': 'short-lived-token',
                }
              : {'asset_id': 'asset-1', 'object_key': 'institution/publication/media'};
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        storageRequest = request;
        return http.Response(
          jsonEncode({'Key': 'institution/publication/media'}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseNowPublicationRepository(client);

    final uploaded = await repository.uploadMedia(
      NowPublicationContext.demo,
      'publication-1',
      NowMediaDraft.image(
        localId: 'local-1',
        name: 'foto.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    );

    expect(functionBodies.map((body) => body['action']), ['prepare', 'finalize']);
    expect(functionBodies.first, isNot(contains('content_base64')));
    expect(functionBodies.last, isNot(contains('content_base64')));
    expect(storageRequest?.url.path, contains('/object/upload/sign/coelo-now-mvp/'));
    expect(storageRequest?.url.queryParameters['token'], 'short-lived-token');
    expect(storageRequest, isNotNull);
    expect(storageRequest?.headers['content-type'], startsWith('multipart/form-data;'));
    expect(uploaded.remoteAssetId, 'asset-1');
  });

  test('no R2 envia os bytes por PUT assinado e nunca toca o Supabase Storage', () async {
    final functionBodies = <Map<String, dynamic>>[];
    http.Request? storageRequest;
    http.Request? putRequest;
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/functions/v1/now-media')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          functionBodies.add(body);
          final response = body['action'] == 'prepare'
              ? {
                  'asset_id': 'asset-1',
                  'storage_provider': 'r2',
                  'upload_url': 'https://r2.test/put?X-Amz-Signature=abc',
                  'required_headers': {'content-length': '3'},
                  'expires_at': '2099-01-01T00:00:00Z',
                }
              : {'asset_id': 'asset-1', 'storage_provider': 'r2', 'object_key': 'opaque'};
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        storageRequest = request;
        return http.Response('{}', 500, request: request);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseNowPublicationRepository(
      client,
      httpClient: MockClient((request) async {
        putRequest = request;
        return http.Response('', 200, request: request);
      }),
    );

    final uploaded = await repository.uploadMedia(
      NowPublicationContext.demo,
      'publication-1',
      NowMediaDraft.image(
        localId: 'local-1',
        name: 'foto.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    );

    expect(functionBodies.map((body) => body['action']), ['prepare', 'finalize']);
    expect(storageRequest, isNull, reason: 'o ramo R2 nunca chama o Supabase Storage');
    expect(putRequest?.method, 'PUT');
    expect(putRequest?.url.host, 'r2.test');
    expect(putRequest?.headers['content-type'], 'image/png');
    expect(putRequest?.headers['content-length'], '3');
    expect(putRequest?.bodyBytes, [1, 2, 3]);
    expect(uploaded.remoteAssetId, 'asset-1');
  });

  test('restaura mídia do rascunho com URL assinada exclusiva do autor', () async {
    final requests = <Map<String, dynamic>>[];
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/load_now_draft')) {
          return http.Response(
            jsonEncode({
              'id': 'publication-1',
              'version': 2,
              'caption': 'Registro',
              'overlay_text': '',
              'audiences': ['families'],
              'media': {
                'asset_id': 'asset-1',
                'name': 'foto.png',
                'mime_type': 'image/png',
                'duration_seconds': null,
                'crop_scale': 1.45,
                'crop_x': -0.3,
                'crop_y': 0.25,
                'cover_position': 0.7,
              },
              'audio': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        return http.Response(
          jsonEncode({'signed_url': 'https://signed.test/draft?token=short-lived'}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final draft = await SupabaseNowPublicationRepository(
      client,
    ).loadDraft(NowPublicationContext.demo);

    expect(requests.single, {
      'action': 'read-draft',
      'institution_id': NowPublicationContext.demo.institutionId,
      'asset_id': 'asset-1',
    });
    expect(draft?.media?.remoteAssetId, 'asset-1');
    expect(draft?.media?.remoteUrl, 'https://signed.test/draft?token=short-lived');
    expect(draft?.media?.bytes, isEmpty);
    expect(draft?.media?.cropScale, 1.45);
    expect(draft?.media?.cropX, -0.3);
    expect(draft?.media?.cropY, 0.25);
    expect(draft?.media?.coverPosition, 0.7);
  });
}
