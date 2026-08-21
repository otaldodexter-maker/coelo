import 'dart:convert';

import 'package:coelo_superadmin/features/principal_circulars/data/supabase_circular_auxiliary_repositories.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('media prepare uses the server-side gateway', () async {
    late Map<String, dynamic> requestBody;
    final client = _client((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'asset_id': 'asset-1',
          'upload_url': 'https://storage.test/upload',
          'required_headers': {'content-type': 'application/pdf'},
          'expires_at': '2026-08-21T12:02:00Z',
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    addTearDown(client.dispose);

    final intent = await SupabaseCircularMediaRepository(client).prepare(
      requestId: '00000000-0000-0000-0000-000000000001',
      institutionId: 'institution-1',
      circularId: 'circular-1',
      name: 'circular.pdf',
      mimeType: 'application/pdf',
      byteSize: CircularLimits.pdfBytes,
    );

    expect(requestBody['action'], 'prepare');
    expect(requestBody['display_order'], 0);
    expect(intent.assetId, 'asset-1');
  });

  test('response draft keeps selected option ids separate from comments', () async {
    late Map<String, dynamic> requestBody;
    final client = _client((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'session_id': 'session-1', 'version': 3, 'status': 'partial'}),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    addTearDown(client.dispose);

    final result = await SupabaseCircularResponseRepository(client).saveDraft(
      requestId: '00000000-0000-0000-0000-000000000001',
      revisionId: 'revision-1',
      childContextId: 'child-1',
      answers: const {
        'question-1': ['option-1', 'option-2'],
      },
      expectedVersion: 2,
    );

    final payload = requestBody['p_answers'] as Map<String, dynamic>;
    expect(payload.containsKey('comment'), isFalse);
    expect(result.state, CircularResponseState.partial);
  });
}

SupabaseClient _client(Future<http.Response> Function(http.Request request) handler) =>
    SupabaseClient('https://coelo.test', 'publishable-key', httpClient: MockClient(handler));
