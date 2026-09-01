import 'dart:convert';

import 'package:coelo_superadmin/features/platform_users/data/supabase_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('loads the protected directory and keeps the server projection cached', () async {
    final paths = <String>[];
    final client = _client(paths);
    addTearDown(client.dispose);
    final repository = SupabasePlatformUserRepository(client);

    final page = await repository.fetchPage(const PlatformUserQuery());

    expect(page.totalCount, 1);
    expect(page.items.single.fullName, 'Ana Lima');
    expect(page.items.single.membership.scopeIds, isNotEmpty);
    expect(repository.findById(_identityId), same(page.items.single));
    expect(paths, contains(endsWith('/rpc/superadmin_internal_users_list')));
    expect(paths, everyElement(contains('/rest/v1/rpc/superadmin_')));
  });

  test('deep link fetches detail before a directory cache exists', () async {
    final paths = <String>[];
    final client = _client(paths);
    addTearDown(client.dispose);
    final repository = SupabasePlatformUserRepository(client);

    final record = await repository.fetchById(_identityId);

    expect(record?.email, 'ana.lima@coelo.me');
    expect(paths, contains(endsWith('/rpc/superadmin_internal_user_detail')));
  });

  test('update and suspension use guarded versioned RPC commands', () async {
    final requests = <Request>[];
    final client = _client(<String>[], requests: requests);
    addTearDown(client.dispose);
    final repository = SupabasePlatformUserRepository(client);
    final current = await repository.fetchById(_identityId);

    await repository.update(
      _identityId,
      PlatformUserDraft(
        identity: current!.identity.copyWith(jobTitle: 'Líder de operações'),
        profile: current.profile,
        scope: current.scope,
        scopeIds: current.membership.scopeIds,
        scopeNames: current.membership.scopeNames,
      ),
    );
    await repository.suspend(_identityId);

    final update = requests.singleWhere(
      (request) => request.url.path.endsWith('superadmin_internal_user_update'),
    );
    final suspend = requests.singleWhere(
      (request) => request.url.path.endsWith('superadmin_internal_user_change_status'),
    );
    final updateBody = jsonDecode(update.body) as Map<String, dynamic>;
    final suspendBody = jsonDecode(suspend.body) as Map<String, dynamic>;
    expect(updateBody['p_expected_version'], 3);
    expect(updateBody['p_draft']['identity']['job_title'], 'Líder de operações');
    expect(suspendBody['p_status'], 'suspended');
    expect(suspendBody['p_reason'], isNotEmpty);
  });

  test('productive creation and invitation actions stay fail closed', () async {
    final client = _client(<String>[]);
    addTearDown(client.dispose);
    final repository = SupabasePlatformUserRepository(client);
    final record = await repository.fetchById(_identityId);

    expect(
      () => repository.create(
        PlatformUserDraft(identity: record!.identity, profile: record.profile, scope: record.scope),
      ),
      throwsA(
        isA<PlatformUserRuleException>().having(
          (error) => error.code,
          'code',
          'invitation-contract',
        ),
      ),
    );
    expect(
      () => repository.resendInvitation(_identityId),
      throwsA(isA<PlatformUserRuleException>()),
    );
  });

  test('maps a successful HTTP denial envelope without exposing backend details', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({
            'ok': false,
            'data': null,
            'error': {
              'code': 'SAI_PERMISSION_DENIED',
              'message': 'Acesso não autorizado.',
              'correlation_id': '97000000-0000-4000-8000-000000000009',
              'http_status': 403,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    final repository = SupabasePlatformUserRepository(client);

    await expectLater(
      repository.fetchById(_identityId),
      throwsA(
        isA<PlatformUserRuleException>()
            .having((error) => error.code, 'code', 'unauthorized')
            .having((error) => error.message, 'message', 'Acesso não autorizado.'),
      ),
    );
  });
}

SupabaseClient _client(List<String> paths, {List<Request>? requests}) => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient((request) async {
    paths.add(request.url.path);
    requests?.add(request);
    final body = request.url.path.endsWith('superadmin_internal_user_profiles')
        ? {
            'items': [_profileJson],
            'total': 1,
            'page': 1,
            'page_size': 100,
          }
        : request.url.path.endsWith('superadmin_internal_users_list')
        ? {
            'items': [_recordJson],
            'total': 1,
            'page': 1,
            'page_size': 11,
          }
        : _recordJson;
    return Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }),
);

const _identityId = '30000000-0000-4000-8000-000000000001';
const _profileId = '50000000-0000-4000-8000-000000000001';
const _institutionId = '60000000-0000-4000-8000-000000000001';

const _profileJson = <String, Object?>{
  'id': _profileId,
  'code': 'operations',
  'name': 'Operations',
  'status': 'active',
  'max_scope_kind': 'platform',
  'permissions': ['platform.read', 'platform.member.update'],
};

const _recordJson = <String, Object?>{
  'id': _identityId,
  'version': 3,
  'identity': {
    'id': _identityId,
    'first_name': 'Ana',
    'last_name': 'Lima',
    'display_name': 'Ana Lima',
    'birth_date': '1990-05-12',
    'cpf': '52998224725',
    'professional_email': 'ana.lima@coelo.me',
    'mobile': '11999999999',
    'additional_phone': '',
    'job_title': 'Operações',
    'department': 'Operações',
    'internal_function': 'Atendimento',
    'professional_notes': '',
    'postal_code': '01310100',
    'street': 'Avenida Paulista',
    'number': '1000',
    'complement': '',
    'neighborhood': 'Bela Vista',
    'city': 'São Paulo',
    'state': 'SP',
    'country': 'Brasil',
  },
  'credential': {'status': 'active'},
  'memberships': [
    {
      'id': '70000000-0000-4000-8000-000000000001',
      'status': 'active',
      'scope': 'limited',
      'scope_ids': [_institutionId],
      'scope_names': ['Instituição Aurora'],
      'started_at': '2026-08-01T12:00:00Z',
      'ended_at': null,
      'profile': _profileJson,
    },
  ],
  'invitation': {
    'id': '80000000-0000-4000-8000-000000000001',
    'email': 'ana.lima@coelo.me',
    'status': 'accepted',
    'attempts': 1,
    'updated_at': '2026-08-01T12:00:00Z',
  },
  'history': [],
};
