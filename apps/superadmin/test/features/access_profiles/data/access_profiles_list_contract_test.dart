import 'dart:convert';

import 'package:coelo_superadmin/features/access_profiles/data/supabase_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Consumer contract only: MockClient handles every request in memory.
// These assertions do not prove authorization, filtering or counts in SQL.
void main() {
  late List<Request> requests;
  late Map<String, Object?> response;
  late int statusCode;
  late SupabaseClient client;
  late SupabaseAccessProfileRepository repository;

  setUp(() {
    requests = [];
    response = {
      'items': [_row()],
      'total': 12,
      'page': 2,
      'page_size': 8,
      'demo': false,
    };
    statusCode = 200;
    client = SupabaseClient(
      'https://profiles-contract.invalid',
      'test-publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return Response(
          jsonEncode(response),
          statusCode,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    repository = SupabaseAccessProfileRepository(client);
  });
  tearDown(() => client.dispose());

  test('list sends exactly six arguments with one-based page and CSV sets', () async {
    final page = await repository.fetchProfiles(
      const AccessProfileQuery(
        search: '  Leitura nominal  ',
        statuses: {AccessProfileStatus.active, AccessProfileStatus.inactive},
        scopes: {AccessProfileScope.platform, AccessProfileScope.institution},
        page: 1,
        pageSize: 8,
      ),
    );

    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/rest/v1/rpc/superadmin_access_profiles_list');
    expect(jsonDecode(requests.single.body), {
      'p_domain': 'platform',
      'p_search': 'Leitura nominal',
      'p_status': 'active,inactive',
      'p_scope': 'platform,institution',
      'p_page': 2,
      'p_page_size': 8,
    });
    expect(page.page, 1);
    expect(page.pageSize, 8);
    expect(page.totalCount, 12);
    expect(page.isDemo, isFalse);
    expect(page.hasPrevious, isTrue);
    expect(page.hasNext, isFalse);
  });

  test('empty filters are null and the first request page is one', () async {
    await repository.fetchProfiles(const AccessProfileQuery());
    expect(jsonDecode(requests.single.body), {
      'p_domain': 'platform',
      'p_search': '',
      'p_status': null,
      'p_scope': null,
      'p_page': 1,
      'p_page_size': 11,
    });
  });

  test('membership_count wins over the incompatible legacy count key', () async {
    response['items'] = [
      {..._row(), 'membership_count': 7, 'linked_people_count': 99},
    ];
    final page = await repository.fetchProfiles(const AccessProfileQuery());
    expect(page.items.single.membershipCount, 7);
    expect(page.items.single.links, isEmpty);
  });

  test('explicit zero membership_count is retained', () async {
    response['items'] = [
      {..._row(), 'membership_count': 0},
    ];
    final page = await repository.fetchProfiles(const AccessProfileQuery());
    expect(page.items.single.membershipCount, 0);
  });

  test('institution global and local rows retain their supplied identity', () async {
    response['items'] = [
      {..._row(), 'id': 'global-role', 'max_scope_kind': 'institution'},
      {
        ..._row(),
        'id': 'local-role',
        'max_scope_kind': 'unit',
        'institution_id': 'institution-a',
        'membership_count': 3,
      },
    ];
    final page = await repository.fetchProfiles(
      const AccessProfileQuery(domain: AccessProfileDomain.institution),
    );
    expect(jsonDecode(requests.single.body)['p_domain'], 'institution');
    expect(page.items.map((item) => item.domain), everyElement(AccessProfileDomain.institution));
    expect(page.items.map((item) => item.id), ['global-role', 'local-role']);
    expect(page.items.map((item) => item.institutionId), [null, 'institution-a']);
    expect(page.items.map((item) => item.membershipCount), [7, 3]);
  });

  test('page beyond total remains empty without losing server total or page', () async {
    response.addAll({'items': <Object?>[], 'page': 3});
    final page = await repository.fetchProfiles(const AccessProfileQuery(page: 2, pageSize: 8));
    expect(page.items, isEmpty);
    expect(page.totalCount, 12);
    expect(page.page, 2);
    expect(page.hasPrevious, isTrue);
    expect(page.hasNext, isFalse);
  });

  test('PostgREST authorization denial remains an error, never an empty page', () async {
    statusCode = 403;
    response = {'code': '42501', 'message': 'SAI_PERMISSION_DENIED', 'details': null, 'hint': null};
    await expectLater(
      repository.fetchProfiles(const AccessProfileQuery()),
      throwsA(isA<AccessProfileUnauthorizedException>()),
    );
    expect(requests, hasLength(1));
  });

  test('principal does not silently call this list contract', () async {
    final page = await repository.fetchProfiles(
      const AccessProfileQuery(domain: AccessProfileDomain.principal),
    );
    expect(requests, isEmpty);
    expect(page.items, isEmpty);
  });
}

Map<String, Object?> _row() => {
  'id': 'nominal-role',
  'code': 'nominal-read',
  'name': 'Leitura nominal',
  'description': 'Fixture de contrato do consumidor.',
  'status': 'active',
  'max_scope_kind': 'platform',
  'version': 2,
  'membership_count': 7,
  'is_system': false,
};
