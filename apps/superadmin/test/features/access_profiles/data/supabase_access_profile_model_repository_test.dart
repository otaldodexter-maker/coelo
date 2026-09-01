import 'dart:convert';

import 'package:coelo_superadmin/features/access_profiles/data/supabase_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('decodes cursor, detail and permission catalog payloads', () async {
    final client = _client((request, body) {
      if (request.url.path.endsWith('superadmin_access_profile_models_cursor')) {
        expect(body, {
          'p_query': 'gestão',
          'p_domain': 'institution',
          'p_status': 'active',
          'p_scope': 'unit',
          'p_limit': 20,
          'p_after_name': null,
          'p_after_id': null,
        });
        return {
          'items': [_modelJson(includeCapabilities: false)],
          'next_cursor': {'name': 'Gestão escolar', 'id': 'model-2'},
        };
      }
      if (request.url.path.endsWith('superadmin_access_permission_catalog')) {
        return {
          'items': [_catalogJson],
        };
      }
      return _modelJson();
    });
    addTearDown(client.dispose);
    final repository = SupabaseAccessProfileRepository(client);

    final page = await repository.fetchModels(
      const AccessProfileModelQuery(
        domain: AccessProfileDomain.institution,
        search: ' gestão ',
        status: AccessProfileStatus.active,
        scope: 'unit',
        limit: 20,
      ),
    );
    final detail = await repository.fetchModel('model-1');
    final catalog = await repository.fetchPermissionCatalog();

    expect(page.items.single.name, 'Gestão escolar');
    expect(page.nextId, 'model-2');
    expect(detail.capabilities.single.effect, AccessProfileModelEffect.allow);
    expect(catalog.single.actionCode, 'export');
    expect(catalog.single.requiresMfa, isTrue);
  });

  test('sends create and update drafts with capability effects and concurrency version', () async {
    final calls = <Map<String, dynamic>>[];
    final client = _client((request, body) {
      calls.add({'path': request.url.path, 'body': body});
      return {'model': _modelJson()};
    });
    addTearDown(client.dispose);
    final repository = SupabaseAccessProfileRepository(client);
    const draft = AccessProfileModelDraft(
      id: 'model-1',
      domain: AccessProfileDomain.institution,
      name: ' Gestão escolar ',
      description: ' Operação da unidade ',
      maxScopeKind: 'unit',
      status: AccessProfileStatus.active,
      capabilities: [
        AccessProfileModelCapability(
          code: 'admin.institutions.export',
          effect: AccessProfileModelEffect.allow,
        ),
      ],
      expectedVersion: 3,
      reason: ' Revisão trimestral ',
    );

    await repository.createModel('request-create', draft);
    await repository.updateModel('request-update', draft);

    final createBody = calls.first['body'] as Map<String, dynamic>;
    expect(createBody['p_request_id'], 'request-create');
    expect((createBody['p_draft'] as Map)['capabilities'], [
      {'code': 'admin.institutions.export', 'effect': 'allow'},
    ]);
    final updateDraft = (calls.last['body'] as Map)['p_draft'] as Map;
    expect(updateDraft['expected_version'], 3);
    expect(updateDraft['reason'], 'Revisão trimestral');
  });

  test('sends guarded delete, export and import contracts', () async {
    final calls = <String, Map<String, dynamic>>{};
    final client = _client((request, body) {
      calls[request.url.path.split('/').last] = body;
      if (request.url.path.endsWith('models_export')) {
        return {
          'format_version': 'access-profile-models-v1',
          'mime_type': 'text/csv',
          'csv': 'format_version,domain',
        };
      }
      if (request.url.path.endsWith('import_preview')) {
        return {'valid_count': 1, 'error_count': 0, 'rows': []};
      }
      return {'model_id': 'model-1', 'status': 'inactive', 'version': 4};
    });
    addTearDown(client.dispose);
    final repository = SupabaseAccessProfileRepository(client);
    final rows = <Map<String, dynamic>>[
      {'name': 'Secretaria', 'capabilities': <Object>[]},
    ];

    await repository.deleteModel(
      requestId: 'request-delete',
      modelId: 'model-1',
      expectedVersion: 3,
      reason: ' Desativação aprovada ',
    );
    final exported = await repository.exportModels(AccessProfileDomain.institution);
    final preview = await repository.previewModelImport(AccessProfileDomain.institution, rows);

    expect(calls['superadmin_access_profile_model_delete'], {
      'p_request_id': 'request-delete',
      'p_model_id': 'model-1',
      'p_expected_version': 3,
      'p_reason': 'Desativação aprovada',
    });
    expect(calls['superadmin_access_profile_models_export'], {'p_domain': 'institution'});
    expect(calls['superadmin_access_profile_models_import_preview'], {
      'p_domain': 'institution',
      'p_rows': rows,
    });
    expect(exported.mimeType, 'text/csv');
    expect(preview.validCount, 1);
  });

  test('maps denied and stale model responses to typed fail-closed errors', () async {
    var status = 403;
    var code = '42501';
    var message = 'permission denied';
    final client = _client(
      (request, body) => const {},
      response: (request) => Response(
        jsonEncode({'code': code, 'message': message}),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAccessProfileRepository(client);

    await expectLater(
      repository.fetchModel('model-1'),
      throwsA(isA<AccessProfileUnauthorizedException>()),
    );
    status = 409;
    code = '40001';
    message = 'stale access model version';
    await expectLater(
      repository.updateModel('request-update', _draft),
      throwsA(isA<AccessProfileConflictException>()),
    );
  });
}

SupabaseClient _client(
  Map<String, dynamic> Function(Request request, Map<String, dynamic> body) responder, {
  Response Function(Request request)? response,
}) => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient((request) async {
    if (response != null) return response(request);
    final decoded = request.body.isEmpty ? null : jsonDecode(request.body);
    final body = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    return Response(
      jsonEncode(responder(request, body)),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }),
);

Map<String, Object?> _modelJson({bool includeCapabilities = true}) => {
  'id': 'model-1',
  'domain': 'institution',
  'application_code': 'admin',
  'code': 'gestao-escolar',
  'name': 'Gestão escolar',
  'description': 'Operação da unidade.',
  'status': 'active',
  'max_scope_kind': 'unit',
  'version': 3,
  'is_system': false,
  if (includeCapabilities)
    'capabilities': [
      {'code': 'admin.institutions.export', 'effect': 'allow'},
    ],
};

const _catalogJson = <String, Object?>{
  'application_code': 'admin',
  'module_code': 'structure',
  'module_label': 'Estrutura',
  'screen_code': 'institutions',
  'screen_label': 'Instituições',
  'action_code': 'export',
  'action_label': 'Exportar',
  'code': 'admin.institutions.export',
  'description': 'Exportar instituições.',
  'risk_level': 'high',
  'requires_mfa': true,
};

const _draft = AccessProfileModelDraft(
  id: 'model-1',
  domain: AccessProfileDomain.institution,
  name: 'Gestão escolar',
  description: 'Operação da unidade.',
  maxScopeKind: 'unit',
  status: AccessProfileStatus.active,
  capabilities: [],
  expectedVersion: 3,
  reason: 'Revisão',
);
