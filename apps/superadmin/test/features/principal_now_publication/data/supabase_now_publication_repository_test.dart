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
  });
}
