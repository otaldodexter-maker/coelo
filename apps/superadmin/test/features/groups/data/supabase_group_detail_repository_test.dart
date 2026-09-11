import 'dart:async';
import 'dart:convert';

import 'package:coelo_superadmin/features/groups/data/supabase_group_detail_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _id = '11111111-1111-4111-8111-111111111111';

void main() {
  for (final envelope in <Object?>[
    null,
    [],
    {},
    {'ok': 'true', 'data': _data()},
    {
      'ok': false,
      'error': {'code': 'UNKNOWN'},
      'data': _data(),
    },
  ]) {
    test('invalid envelope ${jsonEncode(envelope)} fails closed', () async {
      final repository = _repository((_) async => _json(envelope));
      await expectLater(
        repository.fetchById(_id),
        throwsA(
          isA<GroupDetailException>().having(
            (e) => e.failure,
            'failure',
            GroupDetailFailure.unavailable,
          ),
        ),
      );
    });
  }
  for (final error in [ClientException('network'), TimeoutException('timeout')]) {
    test('transport ${error.runtimeType} is unavailable', () async {
      final repository = _repository((_) async => throw error);
      await expectLater(
        repository.fetchById(_id),
        throwsA(
          isA<GroupDetailException>().having(
            (e) => e.failure,
            'failure',
            GroupDetailFailure.unavailable,
          ),
        ),
      );
    });
  }
  test('free-form group type and its nullable complement are not reinterpreted', () async {
    final repository = _repository(
      (_) async => _json({
        'ok': true,
        'data': {..._data(), 'group_type': 'other', 'group_type_other_text': 'Oficina'},
      }),
    );
    final detail = await repository.fetchById(_id);
    expect(detail.groupType, 'other');
    expect(detail.groupTypeOtherText, 'Oficina');
  });

  test('detail and reload call only internal v2 and preserve physical fields', () async {
    final requests = <Request>[];
    final repository = _repository((request) async {
      requests.add(request);
      return _json({'ok': true, 'data': _data(name: 'Grupo ${requests.length}')});
    });
    final first = await repository.fetchById(_id);
    final second = await repository.fetchById(_id);
    expect(first.name, 'Grupo 1');
    expect(second.name, 'Grupo 2');
    expect(second.groupType, 'class');
    expect(second.groupTypeOtherText, isNull);
    expect(second.managementVersion, 3);
    expect(second.inheritAccess, isFalse);
    for (final request in requests) {
      expect(request.url.path, '/rest/v1/rpc/superadmin_group_detail_v2');
      expect(request.method, 'POST');
      expect(jsonDecode(request.body), {'p_group_id': _id});
    }
  });

  for (final code in [
    'SAI_AUTH_REQUIRED',
    'SAI_SESSION_INVALID',
    'SAI_INTERNAL_CONTEXT_DENIED',
    'SAI_MEMBERSHIP_SUSPENDED',
    'SAI_MEMBERSHIP_REVOKED',
    'SAI_PERMISSION_DENIED',
    'SAI_MFA_REQUIRED',
  ]) {
    test('reload after $code cannot return previously authorized detail', () async {
      var calls = 0;
      final repository = _repository(
        (_) async => ++calls == 1
            ? _json({'ok': true, 'data': _data()})
            : _json({
                'ok': false,
                'error': {'code': code, 'http_status': 403},
                'data': _data(),
              }),
      );
      await repository.fetchById(_id);
      await expectLater(
        repository.fetchById(_id),
        throwsA(
          isA<GroupDetailException>().having(
            (e) => e.failure,
            'failure',
            GroupDetailFailure.denied,
          ),
        ),
      );
      expect(calls, 2);
    });
  }

  for (final id in ['', 'not-a-uuid', ' $_id', '$_id/other']) {
    test('invalid ID $id never reaches transport', () async {
      var calls = 0;
      final repository = _repository((_) async {
        calls++;
        return _json({});
      });
      await expectLater(
        repository.fetchById(id),
        throwsA(
          isA<GroupDetailException>().having(
            (e) => e.failure,
            'failure',
            GroupDetailFailure.invalidId,
          ),
        ),
      );
      expect(calls, 0);
    });
  }

  for (final status in ['draft', 'active', 'inactive', 'suspended', 'archived']) {
    test('preserves physical status $status without lifecycle filtering', () async {
      final repository = _repository(
        (_) async => _json({
          'ok': true,
          'data': {..._data(), 'status': status},
        }),
      );
      expect((await repository.fetchById(_id)).status, status);
    });
  }

  test('additive keys from the server (handle) are ignored', () async {
    // R05: superadmin_group_detail_v2 passou a devolver o @ (regra do @).
    final repository = _repository(
      (_) async => _json({
        'ok': true,
        'data': {..._data(), 'handle': 'turma.unidade', 'handle_last_changed_at': null},
      }),
    );
    final detail = await repository.fetchById(_data()['id'] as String);
    expect(detail.id, _data()['id']);
  });
  final invalidPayloads = <Object?>[
    null,
    [],
    {},
    {..._data(), 'id': '22222222-2222-4222-8222-222222222222'},
    {..._data(), 'status': 'unknown'},
    {..._data(), 'unit': null},
    {..._data(), 'inherit_access': 'true'},
    {..._data(), 'management_version': 1.5},
    {..._data(), 'created_at': 'bad-date'},
  ];

  for (var index = 0; index < invalidPayloads.length; index++) {
    test('malformed or divergent payload $index fails closed', () async {
      final repository = _repository(
        (_) async => _json({'ok': true, 'data': invalidPayloads[index]}),
      );
      await expectLater(
        repository.fetchById(_id),
        throwsA(
          isA<GroupDetailException>().having(
            (e) => e.failure,
            'failure',
            GroupDetailFailure.unavailable,
          ),
        ),
      );
    });
  }

  test('transport errors expose no server message or synthetic fallback', () async {
    final repository = _repository(
      (_) async => Response(
        jsonEncode({'code': '42501', 'message': 'sensitive server detail'}),
        403,
        headers: {'content-type': 'application/json'},
      ),
    );
    await expectLater(
      repository.fetchById(_id),
      throwsA(
        isA<GroupDetailException>()
            .having((e) => e.failure, 'failure', GroupDetailFailure.denied)
            .having((e) => e.toString(), 'minimized', isNot(contains('sensitive'))),
      ),
    );
  });
}

SupabaseGroupDetailRepository _repository(Future<Response> Function(Request) handler) {
  final client = SupabaseClient(
    'https://example.test',
    'public-test-key',
    httpClient: MockClient((request) async {
      final response = await handler(request);
      return Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }),
  );
  addTearDown(client.dispose);
  return SupabaseGroupDetailRepository(client);
}

Response _json(Object? data) =>
    Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});

Map<String, Object?> _data({String name = 'Grupo'}) => {
  'id': _id,
  'institution': {'id': '22222222-2222-4222-8222-222222222222', 'name': 'Instituição'},
  'unit': {'id': '33333333-3333-4333-8333-333333333333', 'name': 'Unidade'},
  'name': name,
  'group_type': 'class',
  'group_type_other_text': null,
  'status': 'active',
  'inherit_appearance': true,
  'inherit_access': false,
  'inherit_activities': true,
  'management_version': 3,
  'created_at': '2026-09-01T10:00:00Z',
  'updated_at': '2026-09-02T10:00:00Z',
};
