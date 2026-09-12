import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_happens_publication/application/happens_publication_controller.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/data/supabase_happens_publication_repository.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/domain/happens_publication.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final scenario in ['ready', 'redirect', 'wrong-mime']) {
    test('R2 signed upload $scenario preserves intent and refuses unsafe transfer', () async {
      final actions = <String>[];
      var puts = 0;
      final client = SupabaseClient(
        'https://coelo.test',
        'publishable-key',
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          actions.add(body['action'] as String);
          expect(body['asset_id'], 'asset-1');
          expect(body['post_id'], 'post-1');
          expect(body['institution_id'], 'institution-1');
          expect(body['request_id'], 'request-1');
          return http.Response(
            jsonEncode({'asset_id': 'asset-1', 'object_key': 'opaque'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseHappensPublicationRepository(
        client,
        httpClient: MockClient((request) async {
          puts++;
          expect(request.followRedirects, isFalse);
          expect(request.headers, {'content-type': 'image/png', 'x-amz-meta-purpose': 'test'});
          return http.Response(
            '',
            scenario == 'redirect' ? 307 : 200,
            headers: {'location': 'https://other.invalid/file'},
          );
        }),
      );
      final result = repository.finalizeMedia(
        HappensUploadIntent(
          assetId: 'asset-1',
          institutionId: 'institution-1',
          postId: 'post-1',
          requestId: 'request-1',
          displayOrder: 0,
          storageProvider: 'r2',
          uploadUrl: Uri.parse('https://private.test/signed'),
          requiredHeaders: {
            'content-type': scenario == 'wrong-mime' ? 'image/jpeg' : 'image/png',
            'x-amz-meta-purpose': 'test',
          },
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
        HappensMediaDraft(
          localId: 'local-1',
          name: 'image.png',
          mimeType: 'image/png',
          bytes: Uint8List(8),
        ),
      );
      if (scenario == 'ready') {
        expect((await result).assetId, 'asset-1');
        expect(actions, ['finalize']);
      } else {
        await expectLater(result, throwsException);
        expect(actions, isEmpty);
      }
      expect(puts, scenario == 'wrong-mime' ? 0 : 1);
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
