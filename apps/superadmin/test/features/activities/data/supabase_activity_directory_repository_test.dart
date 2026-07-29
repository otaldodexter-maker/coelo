import 'dart:convert';

import 'package:coelo_superadmin/features/activities/data/supabase_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('uses exact server pagination, stable ordering and real filters', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          '[]',
          200,
          headers: {'content-range': '*/0', 'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final page = await SupabaseActivityDirectoryRepository(client).fetchPage(
      ActivityDirectoryQuery(
        search: 'música',
        institutionIds: {'institution-1'},
        statuses: {ActivityStatus.active, ActivityStatus.draft},
        origins: {ActivityOrigin.unit},
        page: 2,
        pageSize: 20,
        sortAscending: false,
      ),
    );

    final parameters = captured!.url.queryParameters;
    expect(parameters['offset'], '40');
    expect(parameters['limit'], '20');
    expect(parameters['order'], allOf(startsWith('name.desc'), contains('id.asc')));
    expect(parameters['or'], allOf(contains('name.ilike'), contains('description.ilike')));
    expect(parameters['institution_id'], contains('institution-1'));
    expect(parameters['status'], allOf(contains('active'), contains('draft')));
    expect(parameters['origin_scope_kind'], contains('unit'));
    expect(page.totalCount, 0);
  });

  test('maps a minimized detail and only exposes aggregate people counts', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        final body = switch (table) {
          'activity_definitions' => [
            {
              'id': 'activity-1',
              'institution_id': 'institution-1',
              'name': 'Música',
              'description': 'Expressão sonora',
              'origin_scope_kind': 'unit',
              'origin_unit_id': 'unit-1',
              'status': 'active',
              'distribution_scope': 'unit_local',
              'governance_kind': 'optional',
              'created_at': '2026-07-01T10:00:00Z',
              'updated_at': '2026-07-29T10:00:00Z',
              'archived_at': null,
              'institutions': {'name': 'Casa Nuvem'},
              'activity_unit_links': [
                {
                  'id': 'link-unit-1',
                  'unit_id': 'unit-1',
                  'status': 'active',
                  'starts_at': '2026-07-01T10:00:00Z',
                  'ends_at': null,
                  'units': {'name': 'Unidade Centro'},
                },
              ],
              'activity_group_links': [
                {
                  'id': 'link-group-1',
                  'group_id': 'group-1',
                  'unit_id': 'unit-1',
                  'status': 'active',
                  'participation_mode': 'selected',
                  'groups': {'name': 'Grupo Azul'},
                  'units': {'name': 'Unidade Centro'},
                  'activity_group_assignments': [
                    {'id': 'assignment-1', 'status': 'active'},
                  ],
                  'activity_group_participants': [
                    {'id': 'participant-1', 'status': 'active'},
                    {'id': 'participant-2', 'status': 'active'},
                  ],
                },
              ],
            },
          ],
          _ => <Map<String, Object?>>[],
        };
        return Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final detail = await SupabaseActivityDirectoryRepository(client).fetchById('activity-1');

    expect(detail?.originUnitName, 'Unidade Centro');
    expect(detail?.groups.single.name, 'Grupo Azul');
    expect(detail?.groups.single.assigneeCount, 1);
    expect(detail?.groups.single.participantCount, 2);
  });

  test('maps PostgREST authorization errors', () async {
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

    expect(
      () => SupabaseActivityDirectoryRepository(client).fetchFilterOptions(),
      throwsA(isA<ActivityDirectoryUnauthorizedException>()),
    );
  });
}
