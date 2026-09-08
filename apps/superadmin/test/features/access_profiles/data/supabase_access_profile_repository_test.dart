import 'dart:convert';

import 'package:coelo_superadmin/features/access_profiles/data/supabase_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('profile detail accepts canonical casing of a requested UUID', () async {
    const id = 'aaaaaaaa-0000-4000-8000-000000000001';
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-test',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({..._profileJson, 'id': id}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    final profile = await SupabaseAccessProfileRepository(
      client,
    ).fetchDetail(AccessProfileDomain.platform, id.toUpperCase());
    expect(profile.id, id);
  });

  test('profile detail rejects a different profile ID', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-test',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({..._profileJson, 'id': 'different-profile'}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseAccessProfileRepository(
        client,
      ).fetchDetail(AccessProfileDomain.platform, 'profile-1'),
      throwsA(isA<AccessProfileException>()),
    );
  });

  for (final action in ['list', 'detail', 'template', 'capabilities', 'save', 'delete']) {
    test('sanitizes lost transport response for profile $action', () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-test',
        httpClient: MockClient((request) async {
          throw ClientException('synthetic-private-detail', request.url);
        }),
      );
      addTearDown(client.dispose);
      await expectLater(
        _invoke(SupabaseAccessProfileRepository(client), action),
        throwsA(
          isA<AccessProfileException>().having(
            (error) => error.message,
            'message',
            'Não foi possível concluir a operação. Tente novamente.',
          ),
        ),
      );
    });
  }

  for (final code in ['42501', '40001']) {
    test('preserves typed profile command rejection $code', () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-test',
        httpClient: MockClient(
          (request) async => Response(
            jsonEncode({'code': code, 'message': 'synthetic-private-detail'}),
            code == '42501' ? 403 : 409,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        _invoke(SupabaseAccessProfileRepository(client), 'save'),
        throwsA(
          code == '42501'
              ? isA<AccessProfileUnauthorizedException>()
              : isA<AccessProfileConflictException>(),
        ),
      );
    });
  }

  test('production repository uses only the five guarded RPC contracts', () async {
    final paths = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        final path = request.url.path;
        final body = path.endsWith('superadmin_access_profiles_list')
            ? {
                'items': [_profileJson],
                'total': 1,
                'page': 1,
                'page_size': 11,
                'demo': false,
              }
            : path.endsWith('superadmin_principal_capabilities_summary')
            ? {
                'items': [
                  {
                    'id': 'capability-1',
                    'code': 'view_context',
                    'name': 'Visualizar contexto',
                    'description': 'Visualizar dados autorizados.',
                    'context_count': 2,
                  },
                ],
              }
            : path.endsWith('superadmin_access_profile_delete_and_reassign')
            ? {'deleted_profile_id': 'profile-1'}
            : _profileJson;
        return Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAccessProfileRepository(client);

    final page = await repository.fetchProfiles(const AccessProfileQuery());
    await repository.fetchDetail(AccessProfileDomain.platform, 'profile-1');
    await repository.fetchTemplate(AccessProfileDomain.platform);
    await repository.fetchPrincipalCapabilities();
    await repository.save(
      requestId: '00000000-0000-4000-8000-000000000001',
      expectedVersion: 1,
      reason: 'Teste',
      draft: page.items.single,
    );
    await repository.deleteAndReassign(
      requestId: '00000000-0000-4000-8000-000000000002',
      domain: AccessProfileDomain.platform,
      profileId: 'profile-1',
      expectedVersion: 1,
      replacementProfileId: null,
      reason: 'Teste',
    );

    expect(paths, everyElement(contains('/rest/v1/rpc/superadmin_')));
    expect(paths, contains(endsWith('/rpc/superadmin_access_profiles_list')));
    expect(paths, contains(endsWith('/rpc/superadmin_access_profile_save')));
    expect(paths, contains(endsWith('/rpc/superadmin_access_profile_delete_and_reassign')));
  });

  test('fails closed when the integration is unavailable', () {
    const repository = UnavailableAccessProfileRepository();

    expect(
      () => repository.fetchProfiles(const AccessProfileQuery()),
      throwsA(isA<AccessProfileUnavailableException>()),
    );
  });
}

Future<void> _invoke(SupabaseAccessProfileRepository repository, String action) async {
  switch (action) {
    case 'list':
      await repository.fetchProfiles(const AccessProfileQuery());
    case 'detail':
      await repository.fetchDetail(AccessProfileDomain.platform, 'profile-1');
    case 'template':
      await repository.fetchTemplate(AccessProfileDomain.platform);
    case 'capabilities':
      await repository.fetchPrincipalCapabilities();
    case 'save':
      await repository.save(
        requestId: '00000000-0000-4000-8000-000000000001',
        expectedVersion: 1,
        reason: 'Teste sintético',
        draft: AccessProfile.fromJson(AccessProfileDomain.platform, _profileJson),
      );
    case 'delete':
      await repository.deleteAndReassign(
        requestId: '00000000-0000-4000-8000-000000000002',
        domain: AccessProfileDomain.platform,
        profileId: 'profile-1',
        expectedVersion: 1,
        replacementProfileId: null,
        reason: 'Teste sintético',
      );
    default:
      throw ArgumentError.value(action);
  }
}

const _profileJson = <String, Object?>{
  'id': 'profile-1',
  'code': 'owner',
  'name': 'Owner',
  'description': 'Autoridade total.',
  'status': 'active',
  'max_scope_kind': 'platform',
  'version': 1,
  'membership_count': 1,
  'is_system': true,
  'permissions': [
    {
      'code': 'platform.read',
      'module': 'platform',
      'name': 'Visualizar plataforma',
      'selected': true,
      'grantable': true,
    },
  ],
};
