import 'dart:convert';

import 'package:coelo_superadmin/features/health_care/data/supabase_health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final actor = HealthCareActor(id: 'actor-1', profile: HealthCareAccessProfile.owner);

  test('directory maps server pagination and keeps filters server-side', () async {
    late Request captured;
    final client = _client((request) async {
      captured = request;
      return _ok(request, {
        'items': [
          {
            'profile_id': 'profile-1',
            'child_person_id': 'child-1',
            'display_name': 'Helena Costa',
            'operational_status': 'active',
            'current_version': 3,
          },
        ],
        'total': 147,
      });
    });
    addTearDown(client.dispose);
    final repository = SupabaseHealthCareRepository(client, actor: actor);

    final page = await repository.fetchDirectory(
      const HealthCareDirectoryQuery(
        search: 'Helena',
        institutionIds: {'institution-1'},
        unitIds: {'unit-1'},
        page: 2,
        pageSize: 11,
      ),
      actor: actor,
    );

    expect(page.totalCount, 147);
    expect(page.items.single.displayName, 'Helena Costa');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['p_offset'], 22);
    expect(body['p_institution_ids'], ['institution-1']);
    expect(captured.url.pathSegments.last, 'superadmin_care_profile_directory_v2');
  });

  test('detail maps only minimized care data and context links', () async {
    final client = _client(
      (request) async => _ok(request, {
        'profile_id': 'profile-1',
        'child_person_id': 'child-1',
        'display_name': 'Helena Costa',
        'operational_status': 'implementation',
        'current_version': 4,
        'contexts': [
          {'institution_id': 'institution-1', 'unit_id': 'unit-1'},
        ],
        'items': [
          {'catalog_item_id': 'asthma', 'other_text': null},
        ],
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseHealthCareRepository(client, actor: actor);

    final child = await repository.findChild('profile-1', actor: actor);

    expect(child?.careProfile.single.catalogItemId, 'asthma');
    expect(child?.links.single.unitId, 'unit-1');
    expect(child?.operationalStatus, HealthCareOperationalStatus.implementation);
  });

  test('create uses an opaque UUID request and no client-side authority fields', () async {
    late Request captured;
    final client = _client((request) async {
      captured = request;
      return _ok(request, {'profile_id': 'profile-1', 'current_version': 1});
    });
    addTearDown(client.dispose);
    final repository = SupabaseHealthCareRepository(client, actor: actor);

    await repository.updateCareProfile(
      childId: 'child-1',
      items: [HealthCareProfileItem(catalogItemId: 'asthma')],
      justification: 'Cadastro inicial validado',
      actor: actor,
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(captured.url.pathSegments.last, 'superadmin_create_care_profile_v2');
    expect(body['p_request_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(body, isNot(contains('actor_id')));
    expect(body, isNot(contains('institution_id')));
  });

  test('semantic denial remains fail closed', () async {
    final client = _client((request) async => _error(request, 'SAI_PERMISSION_DENIED'));
    addTearDown(client.dispose);
    final repository = SupabaseHealthCareRepository(client, actor: actor);

    await expectLater(
      repository.fetchDirectory(const HealthCareDirectoryQuery(), actor: actor),
      throwsStateError,
    );
  });

  test('does not fabricate an authenticated actor', () async {
    final client = _client((request) async => _ok(request, const {}));
    addTearDown(client.dispose);
    final repository = SupabaseHealthCareRepository(client);

    expect(repository.defaultActor, isNull);
    await expectLater(repository.loadCareProfileDraft('profile-1'), throwsStateError);
  });
}

SupabaseClient _client(Future<Response> Function(Request) handler) => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient(handler),
);

Response _ok(Request request, Map<String, dynamic> data) => Response(
  jsonEncode({'ok': true, 'data': data, 'error': null}),
  200,
  request: request,
  headers: {'content-type': 'application/json'},
);

Response _error(Request request, String code) => Response(
  jsonEncode({
    'ok': false,
    'data': null,
    'error': {'code': code},
  }),
  200,
  request: request,
  headers: {'content-type': 'application/json'},
);
