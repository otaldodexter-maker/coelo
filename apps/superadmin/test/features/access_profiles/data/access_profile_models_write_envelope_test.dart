import 'dart:convert';

import 'package:coelo_superadmin/features/access_profiles/data/supabase_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Exact wrapper shape: migrations 20260901193000 -> 20260901170731.
// In-memory transport only; never a real command or an authorization proof.
void main() {
  for (final operation in _operations) {
    for (final replayed in [false, true]) {
      test('$operation accepts SQL receipt replayed=$replayed and preserves request', () async {
        final requests = <Request>[];
        final result = await _invoke(
          _repository(_success(_receipt(operation, replayed: replayed)), requests),
          operation,
        );
        expect(requests, hasLength(1));
        expect(requests.single.url.path, '/rest/v1/rpc/superadmin_access_profile_model_$operation');
        expect(
          jsonDecode(requests.single.body),
          operation == 'delete'
              ? {
                  'p_request_id': _requestId,
                  'p_model_id': _modelId,
                  'p_expected_version': 3,
                  'p_reason': 'Revisão nominal',
                }
              : {'p_request_id': _requestId, 'p_draft': _draft.toJson()},
        );
        if (operation != 'delete') {
          final model = result as AccessProfileModel;
          expect(model.id, _modelId);
          expect(model.version, 4);
          expect(model.capabilities.single.effect, AccessProfileModelEffect.deny);
        }
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
      test('$operation rejects HTTP200 $code without reporting success', () async {
        var reportedSuccess = false;
        final future = _invoke(_repository(_failure(code)), operation).then((value) {
          reportedSuccess = true;
          return value;
        });
        await expectLater(future, throwsA(isA<AccessProfileUnauthorizedException>()));
        expect(reportedSuccess, isFalse);
      });
    }

    test('$operation maps envelope concurrency to typed conflict', () async {
      await expectLater(
        _invoke(_repository(_failure('SAI_CONCURRENT_CHANGE')), operation),
        throwsA(isA<AccessProfileConflictException>()),
      );
    });

    for (final transport in [(403, '42501'), (409, '40001')]) {
      test('$operation preserves typed PostgREST ${transport.$2}', () async {
        await expectLater(
          _invoke(
            _repository(
              {'code': transport.$2, 'message': 'Untrusted backend detail'},
              null,
              transport.$1,
            ),
            operation,
          ),
          throwsA(
            transport.$1 == 403
                ? isA<AccessProfileUnauthorizedException>()
                : isA<AccessProfileConflictException>(),
          ),
        );
      });
    }

    for (final invalid in <String, Object?>{
      'raw receipt': _receipt(operation),
      'string ok': {'ok': 'true', 'data': _receipt(operation), 'error': null},
      'missing data': {'ok': true, 'error': null},
      'list data': _success(<Object>[]),
      'empty receipt': _success(<String, Object?>{}),
      'contradictory error': {
        'ok': true,
        'data': _receipt(operation),
        'error': {'code': 'SAI_PERMISSION_DENIED'},
      },
      'invalid argument': _failure('SAI_INVALID_ARGUMENT'),
      'internal error': _failure('SAI_INTERNAL_ERROR'),
      'unknown error': _failure('UNRECOGNIZED'),
    }.entries) {
      test('$operation rejects ${invalid.key} with a safe typed error', () async {
        await expectLater(
          _invoke(_repository(invalid.value), operation),
          throwsA(
            isA<AccessProfileException>().having(
              (error) => error.message,
              'message',
              isNot(contains('Untrusted backend detail')),
            ),
          ),
        );
      });
    }
  }

  for (final malformed in <String, Object?>{
    'model_id': 'different-model',
    'status': 'active',
    'version': '4',
    'replayed': 'false',
  }.entries) {
    test('delete rejects malformed receipt ${malformed.key}', () async {
      await expectLater(
        _invoke(
          _repository(_success({..._receipt('delete'), malformed.key: malformed.value})),
          'delete',
        ),
        throwsA(isA<AccessProfileException>()),
      );
    });
  }
}

const _operations = ['delete', 'create', 'update', 'duplicate'];
const _requestId = '00000000-0000-4000-8000-000000000001';
const _modelId = '00000000-0000-4000-8000-000000000002';
const _draft = AccessProfileModelDraft(
  id: _modelId,
  sourceModelId: '00000000-0000-4000-8000-000000000003',
  domain: AccessProfileDomain.platform,
  name: 'Modelo nominal',
  description: '',
  maxScopeKind: 'platform',
  status: AccessProfileStatus.inactive,
  capabilities: [
    AccessProfileModelCapability(code: 'platform.read', effect: AccessProfileModelEffect.deny),
  ],
  expectedVersion: 3,
  reason: ' Revisão nominal ',
);

Future<Object?> _invoke(SupabaseAccessProfileRepository repository, String operation) async {
  switch (operation) {
    case 'create':
      return repository.createModel(_requestId, _draft);
    case 'update':
      return repository.updateModel(_requestId, _draft);
    case 'duplicate':
      return repository.duplicateModel(_requestId, _draft);
    case 'delete':
      await repository.deleteModel(
        requestId: _requestId,
        modelId: _modelId,
        expectedVersion: 3,
        reason: ' Revisão nominal ',
      );
      return null;
    default:
      throw StateError('Unknown test operation');
  }
}

SupabaseAccessProfileRepository _repository(
  Object? response, [
  List<Request>? requests,
  int status = 200,
]) {
  final client = SupabaseClient(
    'https://models-contract.invalid',
    'test-publishable-key',
    httpClient: MockClient((request) async {
      requests?.add(request);
      return Response(
        jsonEncode(response),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  addTearDown(client.dispose);
  return SupabaseAccessProfileRepository(client);
}

Map<String, Object?> _success(Object data) => {'ok': true, 'data': data, 'error': null};
Map<String, Object?> _failure(String code) => {
  'ok': false,
  'data': null,
  'error': {'code': code, 'message': 'Untrusted backend detail', 'correlation_id': _requestId},
};
Map<String, Object?> _receipt(String operation, {bool replayed = false}) => {
  'model_id': _modelId,
  'version': 4,
  'replayed': replayed,
  if (operation == 'delete') 'status': 'inactive' else 'model': _model,
};
const _model = {
  'id': _modelId,
  'domain': 'platform',
  'application_code': 'superadmin',
  'code': 'nominal-model',
  'name': 'Modelo nominal',
  'description': '',
  'status': 'inactive',
  'max_scope_kind': 'platform',
  'version': 4,
  'is_system': false,
  'capabilities': [
    {'code': 'platform.read', 'effect': 'deny'},
  ],
};
