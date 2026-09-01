import 'dart:convert';

import 'package:coelo_superadmin/features/activities/data/supabase_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('non-equivalent activity reads fail closed before any legacy RPC', () async {
    var requestCount = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requestCount++;
        return Response('{}', 200, request: request);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseActivityDirectoryRepository(client);

    await expectLater(
      repository.fetchPage(ActivityDirectoryQuery()),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
    await expectLater(
      repository.fetchFilterOptions(),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
    await expectLater(
      repository.fetchFormOptions(institutionId: 'institution-1'),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
    await expectLater(
      repository.searchProfessionals(institutionId: 'institution-1', query: 'Marina'),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
    await expectLater(
      repository.fetchById('activity-1'),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );

    expect(requestCount, 0);
  });

  test('keeps internal template options with institution and unit scope', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({
            'institutions': [
              {'id': 'institution-1', 'name': 'Casa Nuvem'},
            ],
            'units': [
              {'id': 'unit-1', 'institution_id': 'institution-1', 'name': 'Centro'},
            ],
            'taxonomy': <Object?>[],
            'templates': [
              {
                'id': 'template-robotics',
                'name': 'Robótica',
                'taxonomy_id': 'taxonomy-science',
                'subtype_id': 'subtype-robotics',
                'description': 'Modelo Coelo.',
                'scope_kind': 'unit',
                'institution_id': 'institution-1',
                'unit_id': 'unit-1',
                'governance_kind': 'mandatory',
                'status': 'active',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final options = await SupabaseActivityDirectoryRepository(
      client,
    ).fetchTemplateOptions(institutionId: 'institution-1');

    expect(captured!.url.path, endsWith('/rpc/superadmin_activity_template_options'));
    expect(jsonDecode(captured!.body), {'p_institution_id': 'institution-1'});
    expect(options.units.single.id, 'unit-1');
    expect(options.templates.single.scopeKind, ActivityTemplateScopeKind.unit);
    expect(options.templates.single.unitId, 'unit-1');
  });

  test('maps internal template authorization denial', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          '{"code":"42501","message":"permission denied","details":null,"hint":null}',
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseActivityDirectoryRepository(client).fetchTemplateOptions(),
      throwsA(isA<ActivityDirectoryUnauthorizedException>()),
    );
  });
}
