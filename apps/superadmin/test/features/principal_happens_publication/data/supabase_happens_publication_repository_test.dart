import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_happens_publication/application/happens_publication_controller.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/data/supabase_happens_publication_repository.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/domain/happens_publication.dart';
import 'package:coelo_superadmin/shared/data/edge_media_bytes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // Bytes pela Edge (ADR 0032): o navegador nunca faz PUT ao R2; a Edge
  // prepara, grava e finaliza num único POST binário com envelope no cabeçalho.
  for (final scenario in ['ready', 'refused']) {
    test('upload pela Edge $scenario: um POST binário com o envelope, sem PUT assinado', () async {
      final uploads = <http.Request>[];
      final client = SupabaseClient(
        'https://coelo.test',
        'publishable-key',
        httpClient: MockClient((request) async {
          uploads.add(request);
          expect(request.url.path, contains('/functions/v1/happens-media'));
          if (scenario == 'refused') {
            return http.Response(
              jsonEncode({'error': 'invalid_media_signature'}),
              422,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            jsonEncode({'asset_id': 'asset-1', 'object_key': 'opaque'}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseHappensPublicationRepository(client);
      final intent = await repository.prepareMedia(
        const HappensPublicationContext(institutionId: 'institution-1', institutionName: 'Instituição 1'),
        'post-1',
        HappensMediaDraft(localId: 'request-1', name: 'image.png', mimeType: 'image/png', bytes: Uint8List(8)),
        0,
      );
      expect(uploads, isEmpty, reason: 'preparar não fala com a Edge: a janela assinada não existe mais');
      final result = repository.finalizeMedia(
        intent,
        HappensMediaDraft(localId: 'request-1', name: 'image.png', mimeType: 'image/png', bytes: Uint8List(8)),
      );
      if (scenario == 'ready') {
        expect((await result).assetId, 'asset-1');
      } else {
        await expectLater(result, throwsA(isA<EdgeMediaException>()));
      }
      final upload = uploads.single;
      expect(upload.method, 'POST');
      expect(upload.headers['content-type'], startsWith('application/octet-stream'));
      expect(upload.bodyBytes, hasLength(8));
      final raw = upload.headers[edgeMediaEnvelopeHeader]!;
      final envelope = jsonDecode(utf8.decode(base64Url.decode(raw + '=' * ((4 - raw.length % 4) % 4)))) as Map;
      expect(envelope['post_id'], 'post-1');
      expect(envelope['institution_id'], 'institution-1');
      expect(envelope['request_id'], 'request-1');
      expect(envelope['mime_type'], 'image/png');
      expect(envelope['size_bytes'], 8);
      expect(envelope['display_order'], 0);
    });
  }

  test('ambiguous 422 preserves the draft and permits explicit removal retry', () async {
    var requests = 0;
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests++;
        expect(request.url.path, '/functions/v1/happens-media');
        expect(jsonDecode(request.body)['action'], 'delete');
        return http.Response(
          requests == 1 ? '{"error":"media_delete_denied"}' : '{"deleted":true}',
          requests == 1 ? 422 : 200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final controller =
        HappensPublicationController(
            repository: SupabaseHappensPublicationRepository(client),
            context: HappensPublicationContext.demo,
          )
          ..setCaption('Rascunho preservado')
          ..toggleAudience(HappensAudienceKind.families)
          ..addMedia(_media);
    addTearDown(controller.dispose);
    await controller.removeMedia(0);
    expect(controller.state.phase, HappensPublicationPhase.failure);
    expect(controller.state.draft.caption, 'Rascunho preservado');
    expect(controller.state.draft.audiences, contains(HappensAudienceKind.families));
    expect(controller.state.draft.media.single.assetId, _media.assetId);
    expect(requests, 1);
    await controller.removeMedia(0);
    expect(requests, 2);
    expect(controller.state.draft.media, isEmpty);
    expect(controller.state.draft.caption, 'Rascunho preservado');
  });

  for (final entry in [
    (401, 'authentication_required', true),
    (403, 'origin_not_allowed', true),
    (422, 'media_delete_denied', false),
    (422, 'media_delete_failed', false),
    (503, 'media_delete_denied', false),
  ]) {
    test('media delete maps only contracted denial ${entry.$1}/${entry.$2}', () async {
      var requests = 0;
      final client = SupabaseClient(
        'https://coelo.test',
        'publishable-key',
        httpClient: MockClient((request) async {
          requests++;
          expect(request.url.path, '/functions/v1/happens-media');
          expect(jsonDecode(request.body)['action'], 'delete');
          return http.Response(
            jsonEncode({'error': entry.$2}),
            entry.$1,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseHappensPublicationRepository(
          client,
        ).removeMedia(HappensPublicationContext.demo, _media),
        entry.$3
            ? throwsA(isA<HappensPublicationUnauthorized>())
            : throwsA(isNot(isA<HappensPublicationUnauthorized>())),
      );
      expect(requests, 1);
    });
  }
}

final _media = HappensMediaDraft(
  localId: 'local-1',
  name: 'synthetic.png',
  mimeType: 'image/png',
  bytes: Uint8List(0),
  assetId: '11111111-1111-4111-8111-111111111111',
);
