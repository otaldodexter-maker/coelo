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
  for (final entry in [
    (401, 'authentication_required', true),
    (403, 'origin_not_allowed', true),
    (422, 'media_delete_denied', true),
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
