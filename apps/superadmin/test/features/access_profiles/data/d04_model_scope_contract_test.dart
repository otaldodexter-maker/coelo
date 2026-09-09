import 'dart:convert';

import 'package:coelo_superadmin/features/access_profiles/data/access_profile_model_repository_adapter.dart';
import 'package:coelo_superadmin/features/access_profiles/data/supabase_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final scopes in [
    <AccessProfileScope>{},
    {AccessProfileScope.unit},
    {AccessProfileScope.unit, AccessProfileScope.group},
  ]) {
    test('model filter preserves selected scopes $scopes across cursor pages', () async {
      final requests = <Map<String, dynamic>>[];
      final adapter = _adapter((path, body) {
        requests.add(body);
        return {
          'items': [_model()],
          'next_cursor': requests.length == 1 ? {'name': 'Modelo', 'id': 'model-1'} : null,
        };
      });

      await adapter.fetchProfiles(
        AccessProfileQuery(
          domain: AccessProfileDomain.institution,
          scopes: scopes,
          page: 1,
          pageSize: 1,
        ),
      );

      final expectedScope = scopes.isEmpty
          ? null
          : scopes.map((item) => item.databaseValue).join(',');
      expect(requests, hasLength(2));
      expect(requests.map((item) => item['p_scope']), [expectedScope, expectedScope]);
      expect(requests.last['p_after_id'], 'model-1');
    });
  }

  test('model capabilities never become person assignments in the shared profile UI', () async {
    final adapter = _adapter((path, body) {
      if (path.endsWith('superadmin_access_permission_catalog')) {
        return {'items': <Object>[]};
      }
      if (path.endsWith('superadmin_access_profile_model_detail')) {
        return {
          ..._model(),
          'capabilities': [
            {'code': 'admin.institutions.read', 'effect': 'allow'},
          ],
        };
      }
      return {
        'items': [
          {..._model(), 'capability_count': 7},
        ],
      };
    });
    final page = await adapter.fetchProfiles(
      const AccessProfileQuery(domain: AccessProfileDomain.institution),
    );
    final detail = await adapter.fetchDetail(AccessProfileDomain.institution, 'model-1');
    expect(page.items.single.membershipCount, 0);
    expect(detail.membershipCount, 0);
  });

  test('Principal model filter uses the server child context scope', () async {
    String? sentScope;
    final adapter = _adapter((path, body) {
      sentScope = body['p_scope'] as String?;
      return {'items': <Object>[]};
    });
    await adapter.fetchProfiles(
      const AccessProfileQuery(
        domain: AccessProfileDomain.principal,
        scopes: {AccessProfileScope.group},
      ),
    );
    expect(sentScope, 'child_context');
  });

  for (final operation in ['create', 'update', 'duplicate']) {
    test('Principal model $operation preserves child context at the RPC boundary', () async {
      Map<String, dynamic>? sentDraft;
      final adapter = _adapter((path, body) {
        if (path.endsWith('superadmin_access_permission_catalog')) {
          return {'items': <Object>[]};
        }
        final model = _model(domain: 'principal', scope: 'child_context');
        if (path.endsWith('superadmin_access_profile_model_detail')) return model;
        sentDraft = body['p_draft'] as Map<String, dynamic>;
        return {'model': model, 'model_id': 'model-1', 'version': 1, 'replayed': false};
      });
      if (operation == 'duplicate') {
        await adapter.duplicate(
          requestId: 'request-1',
          sourceProfileId: 'source-1',
          domain: AccessProfileDomain.principal,
          name: 'Modelo',
          reason: 'Revisão',
        );
      } else {
        final draft = operation == 'create'
            ? await adapter.fetchTemplate(AccessProfileDomain.principal)
            : await adapter.fetchDetail(AccessProfileDomain.principal, 'model-1');
        await adapter.save(
          requestId: 'request-1',
          expectedVersion: draft.version,
          reason: 'Revisão',
          draft: draft.copyWith(name: 'Modelo'),
        );
      }
      expect(sentDraft?['domain'], 'principal');
      expect(sentDraft?['max_scope_kind'], 'child_context');
    });
  }
}

AccessProfileModelRepositoryAdapter _adapter(
  Map<String, dynamic> Function(String path, Map<String, dynamic> body) response,
) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'publishable-key',
    httpClient: MockClient(
      (request) async => Response(
        jsonEncode({
          'ok': true,
          'data': response(
            request.url.path,
            request.body.isEmpty || request.body == 'null'
                ? {}
                : jsonDecode(request.body) as Map<String, dynamic>,
          ),
          'error': null,
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    ),
  );
  addTearDown(client.dispose);
  return AccessProfileModelRepositoryAdapter(SupabaseAccessProfileRepository(client));
}

Map<String, dynamic> _model({String domain = 'institution', String scope = 'unit'}) => {
  'id': 'model-1',
  'domain': domain,
  'code': 'model',
  'name': 'Modelo',
  'description': '',
  'status': 'active',
  'max_scope_kind': scope,
  'version': 1,
  'is_system': false,
};
