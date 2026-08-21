import 'dart:convert';

import 'package:coelo_superadmin/features/principal_circulars/data/supabase_circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('lists profile Circulars with a stable cursor', () async {
    late Map<String, dynamic> requestBody;
    final client = _client((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode([
          {
            'item_id': '00000000-0000-0000-0000-000000000001',
            'title': 'Renovação de matrícula',
            'excerpt': 'Confirme a renovação.',
            'author_name': 'Colégio Coelo',
            'context_label': 'Ensino Fundamental',
            'effective_published_at': '2026-08-21T12:00:00Z',
            'revised_at': null,
            'attachment_count': 2,
            'question_count': 1,
            'response_state': 'partial',
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    addTearDown(client.dispose);
    final repository = SupabaseCircularRepository(client);

    final page = await repository.listProfile(
      const CircularScope(institutionId: 'institution-1', unitId: 'unit-1'),
      limit: 1,
    );

    expect(requestBody['p_limit'], 1);
    expect(page.items.single.responseState, CircularResponseState.partial);
    expect(page.nextCursor?.itemId, '00000000-0000-0000-0000-000000000001');
  });

  test('sends the validated draft through the idempotent save RPC', () async {
    late Map<String, dynamic> requestBody;
    final client = _client((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'id': '00000000-0000-0000-0000-000000000001',
          'revision_id': '00000000-0000-0000-0000-000000000002',
          'version': 2,
          'status': 'draft',
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    addTearDown(client.dispose);
    final repository = SupabaseCircularRepository(client);

    final saved = await repository.saveDraft(
      requestId: '00000000-0000-0000-0000-000000000099',
      scope: const CircularScope(institutionId: 'institution-1'),
      draft: const CircularDraft(
        id: '00000000-0000-0000-0000-000000000001',
        title: 'Circular',
        audiences: {CircularAudienceKind.families},
        blocks: [CircularTextBlock(id: '00000000-0000-0000-0000-000000000010', text: 'Texto')],
        expectedVersion: 1,
      ),
    );

    expect(requestBody['p_request_id'], '00000000-0000-0000-0000-000000000099');
    expect((requestBody['p_draft'] as Map)['institution_id'], 'institution-1');
    expect(((requestBody['p_draft'] as Map)['audiences'] as List).single, {
      'kind': 'families',
      'scope': 'institution',
      'unit_id': null,
      'group_id': null,
      'activity_id': null,
    });
    expect(saved.version, 2);
  });

  test('loads current answers for the authorized child response unit', () async {
    late Map<String, dynamic> requestBody;
    final client = _client((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'id': '00000000-0000-0000-0000-000000000001',
          'revision_id': '00000000-0000-0000-0000-000000000002',
          'title': 'Circular',
          'author_name': 'Colégio Coelo',
          'context_label': 'Turma A',
          'published_at': '2026-08-21T12:00:00Z',
          'status': 'published',
          'response_policy': 'per_child_any_guardian',
          'response_state': 'partial',
          'response_session_id': '00000000-0000-0000-0000-000000000003',
          'response_version': 4,
          'answers': {
            '00000000-0000-0000-0000-000000000010': ['00000000-0000-0000-0000-000000000020'],
          },
          'blocks': [
            {
              'id': '00000000-0000-0000-0000-000000000011',
              'kind': 'text',
              'text': 'Texto',
              'order': 0,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    addTearDown(client.dispose);

    final detail = await SupabaseCircularRepository(client).getVisible(
      '00000000-0000-0000-0000-000000000001',
      childContextId: '00000000-0000-0000-0000-000000000099',
    );

    expect(requestBody['p_child_context_id'], '00000000-0000-0000-0000-000000000099');
    expect(detail.responseVersion, 4);
    expect(detail.initialAnswers.values.single, ['00000000-0000-0000-0000-000000000020']);
  });

  test('requests an audited optimistic logical delete', () async {
    late Uri requestUri;
    late Map<String, dynamic> requestBody;
    final client = _client((request) async {
      requestUri = request.url;
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'id': '00000000-0000-0000-0000-000000000001',
          'version': 5,
          'status': 'archived',
          'deleted': true,
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    addTearDown(client.dispose);

    final result = await SupabaseCircularRepository(client).delete(
      requestId: '00000000-0000-0000-0000-000000000099',
      circularId: '00000000-0000-0000-0000-000000000001',
      expectedVersion: 4,
    );

    expect(requestUri.path, endsWith('/rpc/delete_circular'));
    expect(requestBody['p_expected_version'], 4);
    expect(result.status, CircularStatus.archived);
  });
}

SupabaseClient _client(Future<http.Response> Function(http.Request request) handler) =>
    SupabaseClient('https://coelo.test', 'publishable-key', httpClient: MockClient(handler));
