import 'dart:convert';

import 'package:coelo_superadmin/features/access_profiles/data/supabase_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Models READ accepts the canonical casing of a requested UUID', () async {
    const id = 'aaaaaaaa-0000-4000-8000-000000000001';
    final model = await _repository(_success({..._model, 'id': id})).fetchModel(id.toUpperCase());
    expect(model.id, id);
  });

  test('Models READ detail rejects a different model ID', () async {
    await expectLater(
      _repository(_success({..._model, 'id': 'different-model'})).fetchModel('nominal-model'),
      throwsA(isA<AccessProfileException>()),
    );
  });

  test('Models READ list unwraps the real SQL envelope and cursor', () async {
    final repository = _repository(
      _success({
        'items': [_model],
        'next_cursor': {'name': 'Modelo nominal', 'id': 'next-model'},
      }),
    );
    final page = await repository.fetchModels(_query);
    expect(page.items.single.id, 'nominal-model');
    expect(page.nextName, 'Modelo nominal');
    expect(page.nextId, 'next-model');
  });

  test('Models READ detail unwraps the real SQL envelope', () async {
    final model = await _repository(_success(_model)).fetchModel('nominal-model');
    expect(model.id, 'nominal-model');
    expect(model.domain, AccessProfileDomain.platform);
    expect(model.capabilities.single.code, 'platform.read');
    expect(model.capabilities.single.effect, AccessProfileModelEffect.deny);
  });

  test('Models READ catalog unwraps the real SQL envelope', () async {
    final items = await _repository(
      _success({
        'items': [_catalog],
      }),
    ).fetchPermissionCatalog();
    expect(items.single.code, 'platform.read');
    expect(items.single.applicationCode, 'superadmin');
    expect(items.single.requiresMfa, isFalse);
  });

  for (final read in _reads.entries) {
    for (final code in [
      'SAI_AUTH_REQUIRED',
      'SAI_SESSION_INVALID',
      'SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED',
      'SAI_MEMBERSHIP_REVOKED',
      'SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED',
    ]) {
      test('Models READ ${read.key} rejects HTTP 200 $code, never empty success', () async {
        final repository = _repository({
          'ok': false,
          'data': null,
          'error': {
            'code': code,
            'correlation_id': '00000000-0000-4000-8000-000000000001',
            // Deliberately untrusted text; the decoder must use its own message.
            'message': 'Untrusted server detail',
            'http_status': code == 'SAI_AUTH_REQUIRED' || code == 'SAI_SESSION_INVALID' ? 401 : 403,
          },
        });
        await expectLater(
          read.value(repository),
          throwsA(isA<AccessProfileUnauthorizedException>()),
        );
      });
    }

    for (final invalid in <String, Object?>{
      'missing envelope': {'items': <Object>[]},
      'string ok': {
        'ok': 'true',
        'data': {'items': <Object>[]},
        'error': null,
      },
      'missing data': {'ok': true, 'error': null},
      'list data': {'ok': true, 'data': <Object>[], 'error': null},
      'contradictory error': {
        'ok': true,
        'data': _model,
        'error': {'code': 'SAI_PERMISSION_DENIED'},
      },
      'malformed data': _success({'items': 'not a list', 'id': 17}),
      'empty data object': _success(<String, Object?>{}),
      'unknown failure': {
        'ok': false,
        'data': null,
        'error': {'code': 'NEW_CODE', 'message': 'Untrusted server detail'},
      },
    }.entries) {
      test('Models READ ${read.key} fails closed on ${invalid.key}', () async {
        await expectLater(
          read.value(_repository(invalid.value)),
          throwsA(
            isA<AccessProfileException>().having(
              (error) => error.message,
              'safe message',
              isNot(contains('Untrusted server detail')),
            ),
          ),
        );
      });
    }
  }

  test('Models READ accepts an explicitly empty authorized list', () async {
    final page = await _repository(
      _success({'items': <Object>[], 'next_cursor': null}),
    ).fetchModels(_query);
    expect(page.items, isEmpty);
    expect(page.nextId, isNull);
  });

  test('Models READ accepts an explicitly empty authorized catalog', () async {
    final items = await _repository(_success({'items': <Object>[]})).fetchPermissionCatalog();
    expect(items, isEmpty);
  });
}

const _query = AccessProfileModelQuery(domain: AccessProfileDomain.platform);
final _reads = <String, Future<Object?> Function(SupabaseAccessProfileRepository)>{
  'list': (repository) => repository.fetchModels(_query),
  'detail': (repository) => repository.fetchModel('nominal-model'),
  'catalog': (repository) => repository.fetchPermissionCatalog(),
};

SupabaseAccessProfileRepository _repository(Object? response) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'publishable-key',
    httpClient: MockClient(
      (request) async => Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    ),
  );
  addTearDown(client.dispose);
  return SupabaseAccessProfileRepository(client);
}

Map<String, Object?> _success(Object data) => {'ok': true, 'data': data, 'error': null};

const _model = <String, Object?>{
  'id': 'nominal-model',
  'domain': 'platform',
  'application_code': 'superadmin',
  'code': 'nominal-model',
  'name': 'Modelo nominal',
  'description': '',
  'status': 'active',
  'max_scope_kind': 'platform',
  'version': 1,
  'is_system': false,
  'capabilities': [
    {'code': 'platform.read', 'effect': 'deny'},
  ],
};

const _catalog = <String, Object?>{
  'application_code': 'superadmin',
  'module_code': 'platform',
  'module_label': 'Plataforma',
  'screen_code': 'platform',
  'screen_label': 'Plataforma',
  'action_code': 'read',
  'action_label': 'Visualizar',
  'code': 'platform.read',
  'description': '',
  'risk_level': 'normal',
  'requires_mfa': false,
};
