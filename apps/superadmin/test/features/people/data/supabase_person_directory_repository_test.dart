import 'dart:convert';

import 'package:coelo_superadmin/features/people/data/supabase_person_directory_repository.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('list uses the server-side RPC with the complete authorized filter contract', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({'items': <Object>[], 'total_count': 0}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    await SupabasePersonDirectoryRepository(client).fetchPage(
      PersonDirectoryQuery(
        search: 'ana',
        types: {PersonType.adult},
        statuses: {PersonStatus.draft},
        institutionIds: {'i1'},
        unitIds: {'u1'},
        groupIds: {'g1'},
        contextualRoles: {'guardian'},
        authLinks: {AuthLinkStatus.unlinked},
        page: 1,
        pageSize: 20,
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_people_list'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_search'], 'ana');
    expect(body['p_types'], ['adult']);
    expect(body['p_statuses'], ['draft']);
    expect(body['p_institution_ids'], ['i1']);
    expect(body['p_unit_ids'], ['u1']);
    expect(body['p_group_ids'], ['g1']);
    expect(body['p_contextual_roles'], ['guardian']);
    expect(body['p_auth_links'], ['unlinked']);
    expect(body['p_offset'], 20);
    expect(body['p_limit'], 20);
  });

  test('create and update call draft and concurrent RPCs', () async {
    final paths = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        return Response(
          jsonEncode({
            'id': 'p1',
            'display_name': 'Ana',
            'person_type': 'adult',
            'status': 'draft',
            'has_active_login': false,
            'updated_at': request.url.path.endsWith('update')
                ? '2026-07-29T12:01:00Z'
                : '2026-07-29T12:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabasePersonDirectoryRepository(client);

    await repository.createDraft(
      const PersonDraft(
        type: PersonType.adult,
        firstName: 'Ana',
        lastName: 'Lima',
        displayName: 'Ana',
        legalName: 'Ana Lima',
      ),
    );
    await repository.updatePerson(
      PersonUpdate(
        personId: 'p1',
        expectedUpdatedAt: DateTime.utc(2026, 7, 29, 12),
        firstName: 'Ana',
        lastName: 'Lima',
        displayName: 'Ana',
        legalName: 'Ana Lima',
      ),
    );

    expect(paths, contains(endsWith('/rpc/superadmin_people_create_draft')));
    expect(paths, contains(endsWith('/rpc/superadmin_people_update')));
  });

  test('filter options use the contextual role code in commands', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({
            'institutions': <Object>[],
            'units': <Object>[],
            'groups': <Object>[],
            'roles': [
              {
                'id': 'role-uuid',
                'code': 'guardian',
                'label': 'Responsável',
                'institution_id': 'institution-1',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    final options = await SupabasePersonDirectoryRepository(client).fetchFilterOptions();

    expect(options.roles.single.id, 'guardian');
    expect(options.roles.single.institutionId, 'institution-1');
  });

  test('maps the backend read-only SQLSTATE and message', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({
            'code': '22023',
            'message': 'service people are read-only',
            'details': null,
            'hint': null,
          }),
          400,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    expect(
      () => SupabasePersonDirectoryRepository(client).fetchDetail('service-1'),
      throwsA(isA<PersonDirectoryReadOnlyException>()),
    );
  });

  test('detail and reload use the internal v2 envelope without extra PII', () async {
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return Response(
          jsonEncode({
            'ok': true,
            'data': {
              'id': 'person-1',
              'first_name': 'Ana',
              'last_name': 'Lima',
              'display_name': 'Ana Lima',
              'legal_name': null,
              'type': 'adult',
              'status': 'active',
              'auth_link': 'linked',
              'memberships': <Object>[],
              'child_contexts': <Object>[],
              'updated_at': '2026-09-01T18:00:00Z',
            },
            'error': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabasePersonDirectoryRepository(client);

    final first = await repository.fetchDetail('person-1');
    final reloaded = await repository.fetchDetail('person-1');

    expect(first.displayName, 'Ana Lima');
    expect(reloaded.authLink, AuthLinkStatus.linked);
    expect(requests, hasLength(2));
    expect(
      requests,
      everyElement(
        predicate<Request>((item) {
          final body = jsonDecode(item.body) as Map<String, dynamic>;
          return item.url.path.endsWith('/rpc/superadmin_person_detail_v2') &&
              body['p_person_id'] == 'person-1';
        }),
      ),
    );
  });

  test('detail v2 maps non-enumerating and invalid-session envelopes fail closed', () async {
    var code = 'SAI_PERMISSION_DENIED';
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({
            'ok': false,
            'data': null,
            'error': {
              'code': code,
              'message': 'Acesso negado.',
              'correlation_id': 'correlation-1',
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
    final repository = SupabasePersonDirectoryRepository(client);

    await expectLater(
      repository.fetchDetail('cross-tenant-id'),
      throwsA(isA<PersonDirectoryUnauthorizedException>()),
    );
    code = 'SAI_SESSION_INVALID';
    await expectLater(
      repository.fetchDetail('person-1'),
      throwsA(isA<PersonDirectoryUnauthorizedException>()),
    );
  });

  test('detail v2 rejects malformed or internal-error envelopes as unavailable', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({
            'ok': false,
            'data': null,
            'error': {'code': 'SAI_INTERNAL_ERROR'},
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabasePersonDirectoryRepository(client).fetchDetail('person-1'),
      throwsA(isA<PersonDirectoryUnavailableException>()),
    );
  });
}
