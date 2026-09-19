import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_now_publication/data/supabase_now_publication_repository.dart';
import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:coelo_superadmin/shared/data/edge_media_bytes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Bytes pela Edge (ADR 0032): o navegador nunca faz PUT ao R2 nem ao Supabase
// Storage; a Edge decide o provedor. Upload = POST binário com o envelope no
// cabeçalho `x-coelo-media-envelope`; leitura do rascunho = bytes inline.
void main() {
  test('upload recusado pela Edge não finaliza', () async {
    final calls = <String>[];
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        calls.add(request.url.path);
        return http.Response(
          jsonEncode({'error': 'invalid_asset_signature'}),
          422,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseNowPublicationRepository(client).uploadMedia(
        NowPublicationContext.demo,
        'publication-1',
        NowMediaDraft.image(
          localId: 'local-1',
          name: 'foto.png',
          mimeType: 'image/png',
          bytes: Uint8List(8),
        ),
      ),
      throwsA(isA<EdgeMediaException>()),
    );
    expect(calls, hasLength(1));
    expect(calls.single, contains('/functions/v1/now-media'));
  });

  test('envia os bytes pela Edge num único POST binário, sem base64 e sem Storage', () async {
    final uploads = <http.Request>[];
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          contains('/functions/v1/now-media'),
          reason: 'nada vai ao Storage nem ao R2',
        );
        uploads.add(request);
        return http.Response(
          jsonEncode({'asset_id': 'asset-1', 'status': 'ready'}),
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

    final upload = uploads.single;
    expect(upload.method, 'POST');
    expect(upload.headers['content-type'], startsWith('application/octet-stream'));
    expect(upload.bodyBytes, [1, 2, 3]);
    final envelope = _envelope(upload);
    expect(envelope['publication_id'], 'publication-1');
    expect(envelope['institution_id'], NowPublicationContext.demo.institutionId);
    expect(envelope['kind'], 'media');
    expect(envelope['mime_type'], 'image/png');
    expect(envelope['size_bytes'], 3);
    expect(envelope.containsKey('content_base64'), isFalse);
    expect(uploaded.remoteAssetId, 'asset-1');
  });

  test('restaura mídia do rascunho com bytes lidos pela Edge (sem URL assinada)', () async {
    final requests = <Map<String, dynamic>>[];
    final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]);
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
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response.bytes(
          png,
          200,
          headers: {'content-type': 'application/octet-stream'},
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
      'inline': true,
    });
    expect(draft?.media?.remoteAssetId, 'asset-1');
    expect(draft?.media?.remoteUrl, startsWith('data:image/png;base64,'));
    expect(draft?.media?.bytes, isEmpty);
    expect(draft?.media?.cropScale, 1.45);
    expect(draft?.media?.cropX, -0.3);
    expect(draft?.media?.cropY, 0.25);
    expect(draft?.media?.coverPosition, 0.7);
  });
}

Map<String, dynamic> _envelope(http.Request request) {
  final raw = request.headers[edgeMediaEnvelopeHeader]!;
  final padded = raw + '=' * ((4 - raw.length % 4) % 4);
  return jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>;
}
