import 'dart:convert';

import 'package:coelo_superadmin/features/groups/data/supabase_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'reload preserves the flat role payload used by group management',
    () async {
      final client = _client(
        (request) async => _json({
          ..._groupRow(),
          'effective_access': [
            {
              'person_id': '44444444-4444-4444-8444-444444444444',
              'display_name': 'Pessoa sintética',
              'origin': 'group_local',
              'inherited': false,
              'profile_id': '55555555-5555-4555-8555-555555555555',
              'profile_code': 'guardian',
              'profile_name': 'Responsável',
              'capabilities': ['groups.read'],
              'restrictions': <String>[],
            },
          ],
        }, request),
      );
      addTearDown(client.dispose);

      final record = await SupabaseGroupDirectoryRepository(
        client,
      ).findById('33333333-3333-4333-8333-333333333333');
      final access = record!.effectiveAccess.single;
      expect(access.profileCode, 'guardian');
      expect(access.profileId, '55555555-5555-4555-8555-555555555555');
      expect(access.profileName, 'Responsável');
      expect(access.inherited, isFalse);
      expect(access.capabilities, ['groups.read']);
    },
  );

  test('reload maps the child context used to preserve student links', () async {
    final client = _client(
      (request) async => _json({
        ..._groupRow(),
        'students': [
          {
            'child_context_id': '66666666-6666-4666-8666-666666666666',
            'person_id': '44444444-4444-4444-8444-444444444444',
            'display_name': 'Crianca sintetica',
            'status': 'active',
          },
        ],
      }, request),
    );
    addTearDown(client.dispose);

    final record = await SupabaseGroupDirectoryRepository(
      client,
    ).findById('33333333-3333-4333-8333-333333333333');

    expect(record!.students, hasLength(1));
    expect(record.students.single.childContextId, '66666666-6666-4666-8666-666666666666');
    expect(record.students.single.personId, '44444444-4444-4444-8444-444444444444');
    expect(record.students.single.displayName, 'Crianca sintetica');
  });

  test(
    'uses the protected group directory RPC with real search and pagination',
    () async {
      Request? captured;
      final client = _client((request) async {
        captured = request;
        return _json({
          'items': [_groupRow()],
          'total_count': 1,
        }, request);
      });
      addTearDown(client.dispose);

      final page = await SupabaseGroupDirectoryRepository(client).fetchPage(
        GroupDirectoryQuery(search: 'girassol', page: 1, pageSize: 20),
      );

      expect(captured!.url.path, endsWith('/rpc/superadmin_group_directory'));
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['p_search'], 'girassol');
      expect(body['p_offset'], 20);
      expect(page.items.single.name, 'Turma Girassol');
    },
  );

  test(
    'saves group composition through one idempotent authoritative command',
    () async {
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

      final result = await SupabaseGroupDirectoryRepository(client)
          .saveComposition(
            GroupDirectorySaveRequest(
              requestId: 'group-save-edit-123',
              record: record,
            ),
          );

      expect(captured!.url.path, endsWith('/rpc/superadmin_group_save'));
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['p_group_id'], record.id);
      expect(body['p_expected_version'], 2);
      expect(body['p_request_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(result.isSuccess, isTrue);
      expect(result.steps, hasLength(1));
      expect(result.steps.single.stage, GroupDirectorySaveStage.group);
      expect(result.steps.single.status, GroupDirectorySaveStepStatus.success);
    },
  );

  test('recibo de outra turma na atualizacao nao entra no cache', () async {
    // Mesma guarda aplicada em Unidades e ja existente em Instituicoes: em
    // atualizacao o recibo tem de corresponder a turma pedida.
    final client = _client((request) async {
      final outra = Map<String, Object?>.from(_groupRow());
      outra['id'] = '44444444-4444-4444-8444-444444444444';
      return _json(outra, request);
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

    await expectLater(
      SupabaseGroupDirectoryRepository(client).saveComposition(
        GroupDirectorySaveRequest(
          requestId: 'group-save-edit-123',
          record: record,
        ),
      ),
      throwsA(isA<GroupDirectoryUnavailableException>()),
    );
  });

  test(
    'reports an individual student-link failure without discarding saved composition',
    () async {
      final requests = <Request>[];
      final client = _client((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/rpc/superadmin_group_save')) {
          return _json(_groupRow(), request);
        }
        if (requests
                .where(
                  (item) => item.url.path.endsWith(
                    '/rpc/superadmin_group_student_link',
                  ),
                )
                .length ==
            1) {
          return Response(
            jsonEncode({
              'code': 'P0002',
              'message': 'student link unavailable',
            }),
            404,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return _json(<String, Object?>{}, request);
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

      final result = await SupabaseGroupDirectoryRepository(client)
          .saveComposition(
            GroupDirectorySaveRequest(
              requestId: 'group-save-partial-students',
              record: record,
              studentPersonIds: const [
                '44444444-4444-4444-8444-444444444444',
                '55555555-5555-4555-8555-555555555555',
              ],
            ),
          );

      expect(result.hasFailure, isTrue);
      expect(result.steps.map((step) => step.status), [
        GroupDirectorySaveStepStatus.success,
        GroupDirectorySaveStepStatus.failure,
        GroupDirectorySaveStepStatus.success,
      ]);
      expect(
        requests.where(
          (request) =>
              request.url.path.endsWith('/rpc/superadmin_group_student_link'),
        ),
        hasLength(2),
      );
    },
  );

  test(
    'reconciles original and desired students without relinking retained children',
    () async {
      final requests = <Request>[];
      final client = _client((request) async {
        requests.add(request);
        return _json(
          request.url.path.endsWith('/rpc/superadmin_group_save')
              ? _groupRow()
              : <String, Object?>{},
          request,
        );
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

      final result = await SupabaseGroupDirectoryRepository(client)
          .saveComposition(
            GroupDirectorySaveRequest(
              requestId: 'group-save-student-reconciliation',
              record: record,
              studentPersonIds: const [
                '77777777-7777-4777-8777-777777777777',
                '55555555-5555-4555-8555-555555555555',
              ],
              originalStudentLinks: const [
                GroupDirectoryStudentBinding(
                  childContextId: '66666666-6666-4666-8666-666666666666',
                  personId: '44444444-4444-4444-8444-444444444444',
                  displayName: 'Crianca anterior',
                  status: 'active',
                ),
                GroupDirectoryStudentBinding(
                  childContextId: '88888888-8888-4888-8888-888888888888',
                  personId: '77777777-7777-4777-8777-777777777777',
                  displayName: 'Crianca mantida',
                  status: 'active',
                ),
              ],
            ),
          );

      expect(result.isSuccess, isTrue);
      expect(
        requests.map((request) => request.url.path),
        containsAllInOrder([
          endsWith('/rpc/superadmin_group_save'),
          endsWith('/rpc/superadmin_group_student_unlink'),
          endsWith('/rpc/superadmin_group_student_link'),
        ]),
      );
      final unlinkBody = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(
        unlinkBody['p_child_context_id'],
        '66666666-6666-4666-8666-666666666666',
      );
      expect(unlinkBody['p_group_id'], record.id);
      final linkBody = jsonDecode(requests[2].body) as Map<String, dynamic>;
      expect(linkBody['p_person_id'], '55555555-5555-4555-8555-555555555555');
    },
  );

  test('retries lost student operation responses with deterministic request ids', () async {
    final requests = <Request>[];
    var unlinkCalls = 0;
    var linkCalls = 0;
    final client = _client((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/rpc/superadmin_group_save')) {
        return _json(_groupRow(), request);
      }
      if (request.url.path.endsWith('/rpc/superadmin_group_student_unlink')) {
        unlinkCalls++;
        if (unlinkCalls == 1) {
          return Response(
            jsonEncode({'code': 'P0002', 'message': 'response lost after write'}),
            404,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
      }
      if (request.url.path.endsWith('/rpc/superadmin_group_student_link')) {
        linkCalls++;
        if (linkCalls == 1) {
          return Response(
            jsonEncode({'code': 'P0002', 'message': 'response lost after write'}),
            404,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
      }
      return _json(<String, Object?>{}, request);
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
    final request = GroupDirectorySaveRequest(
      requestId: 'group-save-retry-unlink',
      record: record,
      studentPersonIds: const ['55555555-5555-4555-8555-555555555555'],
      originalStudentLinks: const [
        GroupDirectoryStudentBinding(
          childContextId: '66666666-6666-4666-8666-666666666666',
          personId: '44444444-4444-4444-8444-444444444444',
          displayName: 'Crianca removida',
          status: 'active',
        ),
      ],
    );

    final first = await SupabaseGroupDirectoryRepository(client).saveComposition(request);
    final second = await SupabaseGroupDirectoryRepository(client).saveComposition(request);

    expect(first.hasFailure, isTrue);
    expect(second.isSuccess, isTrue);
    final unlinkRequests = requests
        .where((item) => item.url.path.endsWith('/rpc/superadmin_group_student_unlink'))
        .toList();
    expect(unlinkRequests, hasLength(2));
    final firstBody = jsonDecode(unlinkRequests.first.body) as Map<String, dynamic>;
    final secondBody = jsonDecode(unlinkRequests.last.body) as Map<String, dynamic>;
    expect(secondBody['p_request_id'], firstBody['p_request_id']);
    final linkRequests = requests
        .where((item) => item.url.path.endsWith('/rpc/superadmin_group_student_link'))
        .toList();
    expect(linkRequests, hasLength(2));
    final firstLinkBody = jsonDecode(linkRequests.first.body) as Map<String, dynamic>;
    final secondLinkBody = jsonDecode(linkRequests.last.body) as Map<String, dynamic>;
    expect(secondLinkBody['p_request_id'], firstLinkBody['p_request_id']);
  });

  test(
    'maps authorization denials without falling back to fake data',
    () async {
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
        () => SupabaseGroupDirectoryRepository(
          client,
        ).fetchPage(GroupDirectoryQuery()),
        throwsA(isA<GroupDirectoryUnauthorizedException>()),
      );
    },
  );
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

SupabaseClient _client(Future<Response> Function(Request request) handler) =>
    SupabaseClient(
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
