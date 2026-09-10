import 'dart:convert';

import 'package:coelo_superadmin/features/activities/data/supabase_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('directory uses nominal v2 with every filter and parses the complete projection', () async {
    Request? captured;
    final repository = _repository((request) {
      captured = request;
      return _ok({
        'items': [_item()],
        'total': 41,
        'limit': 20,
        'offset': 20,
      });
    });
    final result = await repository.fetchPage(
      ActivityDirectoryQuery(
        search: 'Descrição',
        institutionIds: {'institution-1', 'institution-2'},
        unitIds: {'unit-1', 'unit-2'},
        groupIds: {'group-1', 'group-2'},
        statuses: {ActivityStatus.active, ActivityStatus.draft},
        origins: {ActivityOrigin.institution, ActivityOrigin.unit},
        page: 1,
        pageSize: 20,
        sortAscending: false,
      ),
    );
    expect(captured!.url.path, '/rest/v1/rpc/superadmin_activity_directory_v2');
    expect(jsonDecode(captured!.body), {
      'p_filters': {
        'search': 'Descrição',
        'institution_ids': ['institution-1', 'institution-2'],
        'unit_ids': ['unit-1', 'unit-2'],
        'group_ids': ['group-1', 'group-2'],
        'statuses': ['active', 'draft'],
        'origins': ['institution', 'unit'],
      },
      'p_limit': 20,
      'p_offset': 20,
      'p_sort': 'name',
      'p_sort_ascending': false,
    });
    expect(result.totalCount, 41);
    expect(result.page, 1);
    expect(result.pageSize, 20);
    final item = result.items.single;
    expect(item.id, 'activity-1');
    expect(item.origin, ActivityOrigin.unit);
    expect(item.distribution, ActivityDistribution.unitLocal);
    expect(item.governance, ActivityGovernance.mandatory);
    expect(item.description, 'Descrição preservada');
    expect(item.activeUnitCount, 1);
    expect(item.activeGroupCount, 1);
    expect(item.linkedUnits.single.name, 'Unidade sintética');
    expect(item.linkedGroups.single.unitName, 'Unidade sintética');
    expect(item.managementVersion, 3);
    expect(item.canonicalHandle, '@atividade-sintetica');
  });

  test('filter options use read-only v2 and retain hierarchy', () async {
    Request? captured;
    final repository = _repository((request) {
      captured = request;
      return _ok(_options());
    });
    final options = await repository.fetchFilterOptions();
    expect(captured!.url.path, '/rest/v1/rpc/superadmin_activity_filter_options_v2');
    expect(options.institutions.single.label, 'Instituição sintética');
    expect(options.units.single.parentId, 'institution-1');
    expect(options.groups.single.parentId, 'unit-1');
  });

  for (final code in [
    'SAI_AUTH_REQUIRED',
    'SAI_SESSION_INVALID',
    'SAI_INTERNAL_CONTEXT_DENIED',
    'SAI_MEMBERSHIP_SUSPENDED',
    'SAI_MEMBERSHIP_REVOKED',
    'SAI_PERMISSION_DENIED',
    'SAI_MFA_REQUIRED',
  ]) {
    test('both v2 reads preserve HTTP 200 authorization denial $code', () async {
      final repository = _repository(
        (_) => {
          'ok': false,
          'data': null,
          'error': {'code': code, 'message': 'Mensagem não confiável'},
        },
      );
      await expectLater(
        repository.fetchPage(ActivityDirectoryQuery()),
        throwsA(isA<ActivityDirectoryUnauthorizedException>()),
      );
      await expectLater(
        repository.fetchFilterOptions(),
        throwsA(isA<ActivityDirectoryUnauthorizedException>()),
      );
    });
  }

  for (final payload in <Object?>[
    null,
    [],
    {},
    {'data': <String, Object?>{}},
    {
      'ok': false,
      'data': null,
      'error': {'code': 'SAI_INTERNAL_ERROR'},
    },
    {'ok': true, 'data': null, 'error': null},
    {
      'ok': true,
      'data': <String, Object?>{},
      'error': {'code': 'SAI_PERMISSION_DENIED'},
    },
  ]) {
    test('both reads fail safely for invalid envelope $payload', () async {
      final repository = _repository((_) => payload);
      await expectLater(
        repository.fetchPage(ActivityDirectoryQuery()),
        throwsA(isA<ActivityDirectoryUnavailableException>()),
      );
      await expectLater(
        repository.fetchFilterOptions(),
        throwsA(isA<ActivityDirectoryUnavailableException>()),
      );
    });
  }

  for (final change in <Map<String, dynamic>>[
    {'items': null},
    {
      'items': ['invalid'],
    },
    {'total': -1},
    {'total': 1.5},
    {'limit': 100},
    {'offset': 11},
    {
      'items': [
        {..._item(), 'origin_scope_kind': null},
      ],
    },
    {
      'items': [
        {..._item(), 'governance_kind': 'unknown'},
      ],
    },
    {
      'items': [
        {..._item(), 'active_unit_count': null},
      ],
    },
    {
      'items': [
        {..._item(), 'linked_units': null},
      ],
    },
    {
      'items': [
        {..._item(), 'linked_units': <Object?>[]},
      ],
    },
    {
      'items': [
        {..._item(), 'linked_groups': <Object?>[]},
      ],
    },
    {
      'items': [
        {..._item(), 'management_version': 0},
      ],
    },
  ]) {
    test('directory rejects malformed projection ${change.keys} ${change.values}', () async {
      final repository = _repository(
        (_) => _ok({
          'items': [_item()],
          'total': 1,
          'limit': 11,
          'offset': 0,
          ...change,
        }),
      );
      await expectLater(
        repository.fetchPage(ActivityDirectoryQuery()),
        throwsA(isA<ActivityDirectoryUnavailableException>()),
      );
    });
  }

  test('empty authorized responses stay distinct from unavailable', () async {
    final repository = _repository(
      (request) => _ok(
        request.url.path.endsWith('filter_options_v2')
            ? {'institutions': <Object?>[], 'units': <Object?>[], 'groups': <Object?>[]}
            : {'items': <Object?>[], 'total': 0, 'limit': 11, 'offset': 0},
      ),
    );
    expect((await repository.fetchPage(ActivityDirectoryQuery())).items, isEmpty);
    expect((await repository.fetchFilterOptions()).institutions, isEmpty);
  });

  test('filter options reject incomplete or malformed collections', () async {
    for (final change in <Map<String, dynamic>>[
      {'units': null},
      {
        'groups': ['invalid'],
      },
      {
        'institutions': [
          {'id': 'institution-1'},
        ],
      },
      {
        'units': [
          {'id': 'unit-1', 'label': 'Unidade', 'parent_id': null},
        ],
      },
    ]) {
      final repository = _repository((_) => _ok({..._options(), ...change}));
      await expectLater(
        repository.fetchFilterOptions(),
        throwsA(isA<ActivityDirectoryUnavailableException>()),
      );
    }
  });

  test('falha de rede vira indisponibilidade nos tres metodos remotos', () async {
    // Os status HTTP acima ja eram mapeados. O que escapava era a falha de
    // TRANSPORTE: o repositorio capturava PostgrestException, FormatException,
    // TypeError e StateError, e um ClientException chegava cru a UI.
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async => throw ClientException('synthetic network failure')),
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
      repository.fetchTemplateOptions(),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
  });

  for (final status in [401, 403, 500]) {
    test('v2 transport error $status is mapped for both reads', () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient(
          (request) async => Response(
            jsonEncode({'code': status == 500 ? 'XX000' : '42501', 'message': 'untrusted'}),
            status,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      final repository = SupabaseActivityDirectoryRepository(client);
      final matcher = status == 500
          ? isA<ActivityDirectoryUnavailableException>()
          : isA<ActivityDirectoryUnauthorizedException>();
      await expectLater(repository.fetchPage(ActivityDirectoryQuery()), throwsA(matcher));
      await expectLater(repository.fetchFilterOptions(), throwsA(matcher));
    });
  }

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

SupabaseActivityDirectoryRepository _repository(Object? Function(Request) response) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'publishable-key',
    httpClient: MockClient(
      (request) async => Response(
        jsonEncode(response(request)),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    ),
  );
  addTearDown(client.dispose);
  return SupabaseActivityDirectoryRepository(client);
}

Map<String, dynamic> _ok(Object? data) => {'ok': true, 'data': data, 'error': null};

Map<String, dynamic> _options() => {
  'institutions': [
    {'id': 'institution-1', 'label': 'Instituição sintética'},
  ],
  'units': [
    {'id': 'unit-1', 'label': 'Unidade sintética', 'parent_id': 'institution-1'},
  ],
  'groups': [
    {'id': 'group-1', 'label': 'Grupo sintético', 'parent_id': 'unit-1'},
  ],
};

Map<String, dynamic> _item() => {
  'id': 'activity-1',
  'institution_id': 'institution-1',
  'institution_name': 'Instituição sintética',
  'name': 'Atividade sintética',
  'description': 'Descrição preservada',
  'status': 'active',
  'origin_scope_kind': 'unit',
  'distribution_scope': 'unit_local',
  'governance_kind': 'mandatory',
  'handle_stem': 'atividade-sintetica',
  'canonical_handle': '@atividade-sintetica',
  'active_unit_count': 1,
  'active_group_count': 1,
  'management_version': 3,
  'linked_units': [
    {'id': 'unit-1', 'name': 'Unidade sintética', 'institution_id': 'institution-1'},
  ],
  'linked_groups': [
    {
      'id': 'group-1',
      'name': 'Grupo sintético',
      'unit_id': 'unit-1',
      'unit_name': 'Unidade sintética',
    },
  ],
  'updated_at': '2026-09-07T12:00:00Z',
};
