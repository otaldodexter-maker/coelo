import 'dart:convert';

import 'package:coelo_superadmin/features/groups/data/supabase_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('uses the protected group directory RPC with real search and pagination', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json({
        'items': [_groupRow()],
        'total_count': 1,
      }, request);
    });
    addTearDown(client.dispose);

    final page = await SupabaseGroupDirectoryRepository(
      client,
    ).fetchPage(GroupDirectoryQuery(search: 'girassol', page: 1, pageSize: 20));

    expect(captured!.url.path, endsWith('/rpc/superadmin_group_directory'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_search'], 'girassol');
    expect(body['p_offset'], 20);
    expect(page.items.single.name, 'Turma Girassol');
  });

  test('saves group composition through one idempotent authoritative command', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json(_groupRow(), request);
    });
    addTearDown(client.dispose);
    final record = GroupRecord(
      id: '33333333-3333-4333-8333-333333333333',
      institutionId: '11111111-1111-4111-8111-111111111111',
      institutionName: 'Casa Nuvem',
      unitId: '22222222-2222-4222-8222-222222222222',
      unitName: 'Unidade Centro',
      name: 'Turma Girassol',
      groupType: 'class',
      status: GroupStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      managementVersion: 2,
    );

    final result = await SupabaseGroupDirectoryRepository(
      client,
    ).saveComposition(GroupDirectorySaveRequest(requestId: 'group-save-edit-123', record: record));

    expect(captured!.url.path, endsWith('/rpc/superadmin_group_save'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_group_id'], record.id);
    expect(body['p_expected_version'], 2);
    expect(body['p_request_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(result.isSuccess, isTrue);
  });

  test('maps authorization denials without falling back to fake data', () async {
    final client = _client(
      (request) async => Response(
        jsonEncode({'code': '42501', 'message': 'permission denied'}),
        403,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);

    expect(
      () => SupabaseGroupDirectoryRepository(client).fetchPage(GroupDirectoryQuery()),
      throwsA(isA<GroupDirectoryUnauthorizedException>()),
    );
  });
}

Map<String, Object?> _groupRow() => {
  'id': '33333333-3333-4333-8333-333333333333',
  'institution_id': '11111111-1111-4111-8111-111111111111',
  'institution_name': 'Casa Nuvem',
  'unit_id': '22222222-2222-4222-8222-222222222222',
  'unit_name': 'Unidade Centro',
  'name': 'Turma Girassol',
  'group_type': 'class',
  'status': 'active',
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
  'management_version': 2,
};

SupabaseClient _client(Future<Response> Function(Request request) handler) => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient(handler),
);

Response _json(Object? body, Request request) => Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);
