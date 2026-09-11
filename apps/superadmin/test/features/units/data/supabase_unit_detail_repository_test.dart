import 'dart:async';
import 'dart:convert';

import 'package:coelo_superadmin/features/units/data/supabase_unit_detail_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _id = '11111111-1111-4111-8111-111111111111';
const _otherId = '22222222-2222-4222-8222-222222222222';

void main() {
  test('missing institutional type remains absent without changing unit type', () async {
    final repository = _repository(
      (_) async => _json({
        'ok': true,
        'data': {
          ..._data(),
          'institution': {'id': _otherId, 'name': 'Instituição', 'type': null},
        },
      }),
    );
    final detail = await repository.fetchById(_id);
    expect(detail.institutionType, isNull);
    expect(detail.unitType.name, 'Escola');
  });
  for (final status in ['draft', 'active', 'inactive', 'suspended', 'archived']) {
    test('preserves unit status $status', () async {
      final repository = _repository(
        (_) async => _json({
          'ok': true,
          'data': {..._data(), 'status': status},
        }),
      );
      expect((await repository.fetchById(_id)).status, status);
    });
  }
  for (final envelope in <Object?>[
    null,
    [],
    {},
    {'ok': 'true', 'data': _data()},
    {
      'ok': false,
      'error': {'code': 'SAI_INTERNAL_ERROR'},
    },
  ]) {
    test('invalid unit envelope ${jsonEncode(envelope)} fails closed', () async {
      final repository = _repository((_) async => _json(envelope));
      await expectLater(
        repository.fetchById(_id),
        throwsA(
          isA<UnitDetailException>().having(
            (e) => e.failure,
            'failure',
            UnitDetailFailure.unavailable,
          ),
        ),
      );
    });
  }
  for (final error in [ClientException('network'), TimeoutException('timeout')]) {
    test('unit transport ${error.runtimeType} is unavailable', () async {
      final repository = _repository((_) async => throw error);
      await expectLater(
        repository.fetchById(_id),
        throwsA(
          isA<UnitDetailException>().having(
            (e) => e.failure,
            'failure',
            UnitDetailFailure.unavailable,
          ),
        ),
      );
    });
  }
  test('unit transport denial is minimized', () async {
    final repository = _repository(
      (_) async => Response(
        jsonEncode({'code': '42501', 'message': 'sensitive'}),
        403,
        headers: {'content-type': 'application/json'},
      ),
    );
    await expectLater(
      repository.fetchById(_id),
      throwsA(
        isA<UnitDetailException>()
            .having((e) => e.failure, 'failure', UnitDetailFailure.denied)
            .having((e) => e.toString(), 'minimized', isNot(contains('sensitive'))),
      ),
    );
  });

  test('detail/reload use only internal v2 and observe fresh data', () async {
    var calls = 0;
    final repository = _repository((request) async {
      calls++;
      expect(request.url.path, '/rest/v1/rpc/superadmin_unit_detail_v2');
      expect(jsonDecode(request.body), {'p_unit_id': _id});
      return _json({
        'ok': true,
        'data': {..._data(), 'name': 'Unidade $calls'},
      });
    });
    expect((await repository.fetchById(_id)).name, 'Unidade 1');
    final detail = await repository.fetchById(_id);
    expect(detail.name, 'Unidade 2');
    expect(detail.unitType.name, 'Escola');
    expect(detail.institutionType!.id, _otherId);
    expect(detail.address, isNull);
    expect(detail.contact, isNull);
    expect(detail.effectivePlan, isNull);
    expect(calls, 2);
  });
  for (final inherited in [true, false]) {
    test('preserves server-side plan inherited=$inherited and nullable fields', () async {
      final repository = _repository(
        (_) async => _json({
          'ok': true,
          'data': {
            ..._data(),
            'effective_plan': {
              'id': _otherId,
              'code': 'plan-code',
              'name': 'Plano',
              'inherited': inherited,
            },
            'address': {
              'country': 'Brasil',
              'state': null,
              'city': 'Cidade',
              'district': null,
              'street': null,
              'number': null,
              'complement': null,
              'postal_code': null,
            },
            'contact': {'email': null, 'phone': null, 'mobile_phone': '+5511999999999'},
          },
        }),
      );
      final detail = await repository.fetchById(_id);
      expect(detail.effectivePlan!.inherited, inherited);
      expect(detail.effectivePlan!.code, 'plan-code');
      expect(detail.address!['state'], isNull);
      expect(detail.address!['city'], 'Cidade');
      expect(detail.contact!['mobile_phone'], '+5511999999999');
      expect(() => detail.address!['city'] = 'Alterada', throwsUnsupportedError);
    });
  }
  for (final code in [
    'SAI_AUTH_REQUIRED',
    'SAI_SESSION_INVALID',
    'SAI_INTERNAL_CONTEXT_DENIED',
    'SAI_MEMBERSHIP_SUSPENDED',
    'SAI_MEMBERSHIP_REVOKED',
    'SAI_PERMISSION_DENIED',
    'SAI_MFA_REQUIRED',
  ]) {
    test('reload after $code does not reuse a successful payload', () async {
      var calls = 0;
      final repository = _repository(
        (_) async => _json(
          ++calls == 1
              ? {'ok': true, 'data': _data()}
              : {
                  'ok': false,
                  'error': {'code': code},
                  'data': _data(),
                },
        ),
      );
      await repository.fetchById(_id);
      await expectLater(
        repository.fetchById(_id),
        throwsA(
          isA<UnitDetailException>().having((e) => e.failure, 'failure', UnitDetailFailure.denied),
        ),
      );
      expect(calls, 2);
    });
  }
  for (final id in ['', 'other', ' $_id', '$_id/other']) {
    test('invalid ID $id does not call transport', () async {
      var calls = 0;
      final repository = _repository((_) async {
        calls++;
        return _json({});
      });
      await expectLater(
        repository.fetchById(id),
        throwsA(
          isA<UnitDetailException>().having(
            (e) => e.failure,
            'failure',
            UnitDetailFailure.invalidId,
          ),
        ),
      );
      expect(calls, 0);
    });
  }
  final invalid = <Object?>[
    null,
    {},
    {..._data(), 'id': _otherId},
    {..._data(), 'unit_type': null},
    {..._data(), 'status': 'unknown'},
    {
      ..._data(),
      'address': {'country': 'Brasil'},
    },
    {
      ..._data(),
      'contact': {'email': 1, 'phone': null, 'mobile_phone': null},
    },
    {
      ..._data(),
      'effective_plan': {'id': _otherId, 'code': 'plan', 'name': 'Plano', 'inherited': 'true'},
    },
  ];
  test('additive keys from the server (handle, handle_last_changed_at) are ignored', () async {
    // R05: superadmin_unit_detail_v2 passou a devolver o @ (regra do @);
    // chave nova nao pode derrubar Locais da unidade.
    final repository = _repository(
      (_) async => _json({
        'ok': true,
        'data': {..._data(), 'handle': 'unidade.escola', 'handle_last_changed_at': null},
      }),
    );
    final detail = await repository.fetchById(_id);
    expect(detail.id, _id);
  });
  for (var index = 0; index < invalid.length; index++) {
    test('malformed or divergent unit payload $index fails closed', () async {
      final repository = _repository((_) async => _json({'ok': true, 'data': invalid[index]}));
      await expectLater(
        repository.fetchById(_id),
        throwsA(
          isA<UnitDetailException>().having(
            (e) => e.failure,
            'failure',
            UnitDetailFailure.unavailable,
          ),
        ),
      );
    });
  }
}

SupabaseUnitDetailRepository _repository(Future<Response> Function(Request) handler) {
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
  return SupabaseUnitDetailRepository(client);
}

Response _json(Object? data) =>
    Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});
Map<String, Object?> _data() => {
  'id': _id,
  'name': 'Unidade',
  'slug': 'unidade',
  'status': 'active',
  'institution': {
    'id': _otherId,
    'name': 'Instituição',
    'type': {'id': _otherId, 'name': 'Escola'},
  },
  'unit_type': {'id': _otherId, 'name': 'Escola'},
  'address': null,
  'contact': null,
  'effective_plan': null,
};
