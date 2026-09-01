import 'dart:convert';

import 'package:coelo_superadmin/features/circulars/data/supabase_superadmin_circular_repository.dart';
import 'package:coelo_superadmin/features/circulars/domain/superadmin_circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('unavailable production fallback fails closed', () async {
    await expectLater(
      const UnavailableSuperadminCircularRepository().loadDraftById(_circularId),
      throwsA(isA<CircularUnavailable>()),
    );
  });

  test('directory uses internal RPC and maps authorized aggregates', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _ok(request, {
        'items': [_directoryJson()],
        'next_cursor_updated_at': '2026-09-01T10:00:00Z',
        'next_cursor_id': _circularId,
      });
    });
    addTearDown(client.dispose);

    final page = await SupabaseSuperadminCircularRepository(client).fetchDirectory(
      const SuperadminCircularDirectoryQuery(
        institutionId: _institutionId,
        search: 'matrícula',
        statuses: {CircularStatus.published},
        limit: 8,
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_circular_directory_v2'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_institution_id'], _institutionId);
    expect(body['p_statuses'], ['published']);
    expect(body['p_limit'], 8);
    expect(page.items.single.responseCount, 84);
    expect(page.items.single.title, 'Renovação de matrícula');
    expect(captured!.body, isNot(contains('service_role')));
  });

  test('save draft sends scope, idempotency and versioned structured payload', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _ok(request, _saveJson());
    });
    addTearDown(client.dispose);

    final result = await SupabaseSuperadminCircularRepository(client).saveDraft(
      requestId: _requestId,
      scope: const CircularScope(institutionId: _institutionId),
      draft: CircularDraft(
        id: _circularId,
        title: 'Renovação de matrícula',
        expectedVersion: 3,
        audiences: const {CircularAudienceKind.guardiansOnly},
        blocks: const [CircularTextBlock(id: _blockId, text: 'Confirme até setembro.')],
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_circular_save_draft_v2'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_request_id'], _requestId);
    expect(body['p_institution_id'], _institutionId);
    expect((body['p_payload'] as Map<String, dynamic>)['version'], 3);
    expect(result.version, 4);
  });

  test('detail maps internal envelope to current Circular detail screen contract', () async {
    final client = _client(
      (request) async => _ok(request, {
        'revision_id': _revisionId,
        'author_name': 'Equipe Coelo',
        'context_label': 'Colégio Horizonte',
        'effective_at': '2026-09-02T12:00:00Z',
        'draft': _draftJson(status: 'scheduled'),
      }),
    );
    addTearDown(client.dispose);

    final detail = await SupabaseSuperadminCircularRepository(client).getVisible(_circularId);
    expect(detail.status, CircularStatus.scheduled);
    expect(detail.blocks.single, isA<CircularTextBlock>());
    expect(detail.contextLabel, 'Colégio Horizonte');
  });

  test('loadDraftById reuses authorized detail contract for the edit screen', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _ok(request, {
        'revision_id': _revisionId,
        'institution_id': _institutionId,
        'unit_id': null,
        'group_id': null,
        'activity_id': null,
        'effective_at': '2026-09-02T12:00:00Z',
        'draft': _draftJson(),
      });
    });
    addTearDown(client.dispose);

    final editable = await SupabaseSuperadminCircularRepository(client).loadDraftById(_circularId);
    expect(captured!.url.path, endsWith('/rpc/superadmin_circular_detail_v2'));
    expect(editable.draft.id, _circularId);
    expect(editable.draft.expectedVersion, 4);
    expect(editable.scope.institutionId, _institutionId);
  });

  test('maps MFA, IDOR/not-found and conflict envelopes without leaking detail', () async {
    for (final entry in {
      'SAI_MFA_REQUIRED': isA<CircularUnauthorized>(),
      'CIRCULAR_NOT_FOUND': isA<CircularNotAvailable>(),
      'CIRCULAR_CONFLICT': isA<CircularVersionConflict>(),
    }.entries) {
      final client = _client(
        (request) async => Response(
          jsonEncode({
            'ok': false,
            'data': null,
            'error': {'code': entry.key, 'message': 'segredo de backend'},
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      await expectLater(
        SupabaseSuperadminCircularRepository(client).getVisible(_circularId),
        throwsA(entry.value),
      );
      client.dispose();
    }
  });

  test('response screen receives only authorized aggregate counts', () async {
    final client = _client(
      (request) async => _ok(request, {
        'response_count': 84,
        'submitted_count': 79,
        'partial_count': 5,
        'closed': false,
      }),
    );
    addTearDown(client.dispose);

    final result = await SupabaseSuperadminCircularRepository(
      client,
    ).fetchResponseSummary(_circularId);
    expect(result.submittedCount, 79);
    expect(result.partialCount, 5);
  });
}

SupabaseClient _client(Future<Response> Function(Request) handler) => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient(handler),
);

Response _ok(Request request, Object? data) => Response(
  jsonEncode({'ok': true, 'data': data, 'error': null}),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);

Map<String, Object?> _directoryJson() => {
  'id': _circularId,
  'institution_id': _institutionId,
  'title': 'Renovação de matrícula',
  'excerpt': 'Confirme até setembro.',
  'author_name': 'Equipe Coelo',
  'context_label': 'Colégio Horizonte',
  'status': 'published',
  'effective_at': '2026-09-01T09:00:00Z',
  'updated_at': '2026-09-01T10:00:00Z',
  'attachment_count': 0,
  'question_count': 2,
  'response_count': 84,
  'management_version': 4,
};

Map<String, Object?> _saveJson() => {
  'id': _circularId,
  'revision_id': _revisionId,
  'version': 4,
  'status': 'draft',
};

Map<String, Object?> _draftJson({String status = 'draft'}) => {
  'id': _circularId,
  'title': 'Renovação de matrícula',
  'version': 4,
  'status': status,
  'response_policy': 'per_person',
  'audiences': ['guardians_only'],
  'blocks': [
    {'id': _blockId, 'kind': 'text', 'text': 'Confirme até setembro.'},
  ],
};

const _requestId = '10000000-0000-4000-8000-000000000001';
const _institutionId = '20000000-0000-4000-8000-000000000001';
const _circularId = '30000000-0000-4000-8000-000000000001';
const _revisionId = '40000000-0000-4000-8000-000000000001';
const _blockId = '50000000-0000-4000-8000-000000000001';
