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
    test('v2 reads preserve HTTP 200 authorization denial $code', () async {
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
      await expectLater(
        repository.fetchFormOptions(institutionId: 'institution-1'),
        throwsA(isA<ActivityDirectoryUnauthorizedException>()),
      );
      await expectLater(
        repository.searchProfessionals(institutionId: 'institution-1', query: 'Marina'),
        throwsA(isA<ActivityDirectoryUnauthorizedException>()),
      );
      await expectLater(
        repository.fetchById(_detailId),
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
    test('v2 reads fail safely for invalid envelope $payload', () async {
      final repository = _repository((_) => payload);
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
        repository.fetchById(_detailId),
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

  test('falha de rede vira indisponibilidade em todos os metodos remotos', () async {
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
    await expectLater(
      repository.fetchFormOptions(institutionId: 'institution-1'),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
    await expectLater(
      repository.searchProfessionals(institutionId: 'institution-1', query: 'Marina'),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
    await expectLater(
      repository.fetchById(_detailId),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
  });

  for (final status in [401, 403, 500]) {
    test('v2 transport error $status is mapped for every read', () async {
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
      await expectLater(repository.fetchById(_detailId), throwsA(matcher));
    });
  }

  test('detail read uses v2 with the editor sections and maps the complete projection', () async {
    Request? captured;
    final repository = _repository((request) {
      captured = request;
      return _ok(_detail());
    });

    final detail = (await repository.fetchById(_detailId))!;

    expect(captured!.url.path, '/rest/v1/rpc/superadmin_activity_detail_v2');
    expect(captured!.url.query, isEmpty);
    expect(jsonDecode(captured!.body), {
      'p_activity_id': _detailId,
      'p_sections': ['participants', 'professionals', 'permissions'],
    });

    expect(detail.item.id, _detailId);
    expect(detail.item.institutionId, 'institution-1');
    expect(detail.item.name, 'Robótica');
    expect(detail.item.description, 'Descrição preservada');
    expect(detail.item.status, ActivityStatus.active);
    expect(detail.item.managementVersion, 6);
    expect(detail.item.updatedAt, DateTime.parse('2026-09-11T12:00:00Z'));
    expect(detail.createdAt, DateTime.parse('2026-09-10T12:00:00Z'));
    expect(detail.item.activeUnitCount, 2);
    expect(detail.item.activeGroupCount, 2);
    expect(detail.item.activeParticipantCount, 2);
    expect(detail.item.linkedUnits.map((unit) => unit.id), ['unit-1', 'unit-2']);
    expect(detail.item.linkedUnits.first.institutionId, 'institution-1');
    expect(detail.item.linkedGroups.map((group) => group.unitName), [
      'Unidade Centro',
      'Unidade Norte',
    ]);
    expect(detail.taxonomyId, 'taxonomy-1');

    expect(detail.units.map((unit) => unit.name), ['Unidade Centro', 'Unidade Norte']);
    expect(detail.units.first.status, ActivityStatus.active);
    expect(detail.units.first.startsAt, detail.createdAt);
    expect(detail.units.first.endsAt, isNull);

    expect(detail.groups.map((group) => group.id), ['group-1', 'group-2']);
    expect(detail.groups.first.unitName, 'Unidade Centro');
    expect(detail.groups.first.participation, ActivityParticipation.selected);
    expect(detail.groups.first.participantCount, 2);
    expect(detail.groups.first.assigneeCount, 1);
    expect(detail.groups.last.participation, ActivityParticipation.all);
    expect(detail.groups.last.participantCount, 0);
    expect(detail.groups.last.assigneeCount, 0);

    expect(detail.participants.map((item) => item.childGroupLinkId), ['link-1', 'link-2']);
    expect(detail.participants.every((item) => item.groupId == 'group-1'), isTrue);
    expect(detail.participants.every((item) => item.belongs), isTrue);

    expect(detail.professionalAssignments, hasLength(2));
    final instructor = detail.professionalAssignments.first;
    expect(instructor.role, ActivityDetailProfessionalRole.instructor);
    expect(instructor.groupId, 'group-1');
    expect(instructor.membershipId, 'membership-1');
    expect(instructor.capabilities, {
      'attendance': 'both',
      'chat': 'view',
      'happens': 'edit',
      'moments': 'none',
      'now': 'both',
    });
    final admin = detail.professionalAssignments.last;
    expect(admin.role, ActivityDetailProfessionalRole.activityAdmin);
    expect(admin.groupId, isNull);
    expect(admin.membershipId, 'membership-2');
    expect(admin.capabilities['chat'], 'both');

    expect(detail.identity.kind, ActivityDetailIdentityKind.initials);
    expect(detail.identity.initials, 'RO');
    expect(detail.identity.icon, 'science');
    expect(detail.identity.color, isNull);
    expect(detail.identity.storageRef, isNull);

    // Campos que a RPC nao expoe ficam no default declarado, nunca inferidos.
    expect(detail.item.institutionName, 'Instituição não identificada');
    expect(detail.item.origin, ActivityOrigin.institution);
    expect(detail.item.distribution, ActivityDistribution.unitLocal);
    expect(detail.item.governance, ActivityGovernance.optional);
    expect(detail.item.handleStem, isNull);
    expect(detail.item.canonicalHandle, isNull);
    expect(detail.item.activeProfessionalCount, isNull);
    expect(detail.item.locationNames, isEmpty);
    expect(detail.subtypeId, isNull);
    expect(detail.templateId, isNull);
    expect(detail.taxonomyOtherDescription, isEmpty);
    expect(detail.pedagogicalConfiguration, isNull);
    expect(detail.originUnitName, isNull);
    expect(detail.archivedAt, isNull);
  });

  test('detail read keeps nullable activity fields and empty sections honest', () async {
    final data = _detail();
    final activity = data['activity'] as Map<String, Object?>;
    for (final key in ['description', 'taxonomy_id', 'taxonomy_name', 'icon_key', 'initials']) {
      activity[key] = null;
    }
    activity['status'] = 'draft';
    data['units'] = <Object?>[];
    data['groups'] = <Object?>[];
    data['participants'] = <Object?>[];
    data['professionals'] = <Object?>[];
    data['permissions'] = {
      'policies': <Object?>[],
      'group_settings': <Object?>[],
      'professional_actions': <Object?>[],
    };
    data['counts'] = {
      'units': 0,
      'groups': 0,
      'participants': 0,
      'instructors': 0,
      'activity_admins': 0,
    };
    final repository = _repository((_) => _ok(data));

    final detail = (await repository.fetchById(_detailId))!;

    expect(detail.item.description, isNull);
    expect(detail.item.status, ActivityStatus.draft);
    expect(detail.taxonomyId, isNull);
    expect(detail.identity.initials, isNull);
    expect(detail.identity.icon, isNull);
    expect(detail.identity.kind, ActivityDetailIdentityKind.initials);
    expect(detail.units, isEmpty);
    expect(detail.groups, isEmpty);
    expect(detail.participants, isEmpty);
    expect(detail.professionalAssignments, isEmpty);
    expect(detail.item.activeUnitCount, 0);
  });

  test('detail read derives the icon identity when only the icon key exists', () async {
    final data = _detail();
    (data['activity'] as Map<String, Object?>)['initials'] = null;
    final detail = (await _repository((_) => _ok(data)).fetchById(_detailId))!;
    expect(detail.identity.kind, ActivityDetailIdentityKind.icon);
    expect(detail.identity.icon, 'science');
  });

  test(
    'detail read leaves capabilities empty when the permissions section has no actions',
    () async {
      final data = _detail();
      (data['permissions'] as Map<String, Object?>)['professional_actions'] = <Object?>[];
      final detail = (await _repository((_) => _ok(data)).fetchById(_detailId))!;
      expect(
        detail.professionalAssignments.map((item) => item.capabilities),
        everyElement(isEmpty),
      );
    },
  );

  test('detail read returns null for ACTIVITY_NOT_FOUND without a second request', () async {
    var requestCount = 0;
    final repository = _repository((_) {
      requestCount++;
      return {
        'ok': false,
        'data': null,
        'error': {
          'code': 'ACTIVITY_NOT_FOUND',
          'message': 'Mensagem não confiável',
          'correlation_id': _detailId,
          'http_status': 404,
        },
      };
    });
    expect(await repository.fetchById(_detailId), isNull);
    expect(requestCount, 1);
  });

  for (final change in <String, void Function(Map<String, Object?>)>{
    'missing activity': (d) => d.remove('activity'),
    'uncorrelated activity id': (d) => (d['activity'] as Map<String, Object?>)['activity_id'] = 'x',
    'blank name': (d) => (d['activity'] as Map<String, Object?>)['name'] = ' ',
    'unknown status': (d) => (d['activity'] as Map<String, Object?>)['status'] = 'deleted',
    'zero version': (d) => (d['activity'] as Map<String, Object?>)['management_version'] = 0,
    'fractional version': (d) =>
        (d['activity'] as Map<String, Object?>)['management_version'] = 1.5,
    'bad created_at': (d) => (d['activity'] as Map<String, Object?>)['created_at'] = 'ontem',
    'missing counts': (d) => d.remove('counts'),
    'units count mismatch': (d) => (d['counts'] as Map<String, Object?>)['units'] = 3,
    'groups count mismatch': (d) => (d['counts'] as Map<String, Object?>)['groups'] = 1,
    'units not a list': (d) => d['units'] = null,
    'duplicate unit': (d) => (d['units'] as List).add((d['units'] as List).first),
    'group without unit': (d) => ((d['groups'] as List).first as Map)['unit_id'] = 'unit-9',
    'invalid participation': (d) =>
        ((d['groups'] as List).first as Map)['participation_mode'] = 'none',
    'missing participants section': (d) => d.remove('participants'),
    'participant of unknown group': (d) =>
        ((d['participants'] as List).first as Map)['group_id'] = 'group-9',
    'participant without link id': (d) =>
        ((d['participants'] as List).first as Map)['child_group_link_id'] = null,
    'missing professionals section': (d) => d.remove('professionals'),
    'professional with unknown role': (d) =>
        ((d['professionals'] as List).first as Map)['role'] = 'owner',
    'instructor without group': (d) =>
        ((d['professionals'] as List).first as Map)['group_id'] = null,
    'activity admin with group': (d) =>
        ((d['professionals'] as List).last as Map)['group_id'] = 'group-1',
    'professional without membership': (d) =>
        ((d['professionals'] as List).first as Map)['membership_id'] = '',
    'missing permissions section': (d) => d.remove('permissions'),
    'invalid access level': (d) =>
        ((((d['permissions'] as Map)['professional_actions'] as List).first as Map)['actions']
                as Map)['chat'] =
            'admin',
  }.entries) {
    test('detail read rejects malformed projection ${change.key}', () async {
      final data = _detail();
      change.value(data);
      await expectLater(
        _repository((_) => _ok(data)).fetchById(_detailId),
        throwsA(isA<ActivityDirectoryUnavailableException>()),
      );
    });
  }

  test('form options use v2 with the structure sections and map every collection', () async {
    Request? captured;
    final repository = _repository((request) {
      captured = request;
      return _ok(_formOptions());
    });

    final options = await repository.fetchFormOptions(institutionId: 'institution-1');

    expect(captured!.url.path, '/rest/v1/rpc/superadmin_activity_form_options_v2');
    expect(jsonDecode(captured!.body), {
      'p_institution_id': 'institution-1',
      'p_sections': ['structure', 'participants', 'professionals'],
      'p_limit': 100,
    });
    expect(options.institutions, isEmpty);
    expect(options.locations, isEmpty);
    // Taxonomia e modelos ficam vazios de proposito: o controller preserva a
    // arvore e os modelos carregados por superadmin_activity_template_options.
    expect(options.taxonomy, isEmpty);
    expect(options.templates, isEmpty);

    expect(options.units.map((unit) => unit.id), ['unit-1', 'unit-2']);
    expect(options.units.first.institutionId, 'institution-1');
    expect(options.units.first.name, 'Unidade Centro');
    expect(options.unitsFor('institution-1').length, 2);

    expect(options.groups.map((group) => group.id), ['group-1', 'group-2']);
    expect(options.groups.first.unitId, 'unit-1');
    expect(options.groups.first.name, 'Turma A');
    expect(options.groups.first.participantCount, 2);
    expect(options.groups.last.participantCount, 0);

    expect(options.students.map((student) => student.childGroupLinkId), ['link-1', 'link-2']);
    expect(options.students.first.id, 'link-1');
    expect(options.students.first.groupId, 'group-1');
    expect(options.students.first.name, 'Criança Um');
    expect(options.students.first.age, isNull);
    expect(options.students.first.gender, isNull);

    expect(options.professionals.single.id, 'membership-1');
    expect(options.professionals.single.name, 'Marina Sintética');
    expect(options.professionals.single.role, 'teacher');
    expect(options.professionals.single.personId, isNull);
  });

  test('professional search sends the trimmed query and the limit', () async {
    Request? captured;
    final repository = _repository((request) {
      captured = request;
      return _ok({
        'professionals': [
          {
            'membership_id': 'membership-1',
            'display_name': 'Marina Sintética',
            'role_code': 'teacher',
          },
          {
            'membership_id': 'membership-2',
            'display_name': 'Mariana Sintética',
            'role_code': 'owner',
          },
        ],
      });
    });

    final results = await repository.searchProfessionals(
      institutionId: 'institution-1',
      query: '  Mari  ',
      limit: 7,
    );

    expect(captured!.url.path, '/rest/v1/rpc/superadmin_activity_form_options_v2');
    expect(jsonDecode(captured!.body), {
      'p_institution_id': 'institution-1',
      'p_sections': ['professionals'],
      'p_search': 'Mari',
      'p_limit': 7,
    });
    expect(results.map((item) => item.id), ['membership-1', 'membership-2']);
    expect(results.first.name, 'Marina Sintética');
    expect(results.first.role, 'teacher');
    expect(results.last.role, 'owner');
  });

  test('professional search sends null for a blank query and keeps the limit in 1..100', () async {
    final bodies = <Map<String, dynamic>>[];
    final repository = _repository((request) {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return _ok({'professionals': <Object?>[]});
    });

    expect(
      await repository.searchProfessionals(institutionId: 'institution-1', query: '   ', limit: 0),
      isEmpty,
    );
    expect(
      await repository.searchProfessionals(
        institutionId: 'institution-1',
        query: 'x' * 130,
        limit: 500,
      ),
      isEmpty,
    );

    expect(bodies.first, {
      'p_institution_id': 'institution-1',
      'p_sections': ['professionals'],
      'p_search': null,
      'p_limit': 1,
    });
    expect(bodies.last['p_search'], 'x' * 120);
    expect(bodies.last['p_limit'], 100);
  });

  test('form options and professional search tolerate missing collections', () async {
    for (final data in <Map<String, dynamic>>[
      <String, Object?>{},
      {'structure': null, 'participants': null, 'professionals': null},
      {'structure': <String, Object?>{}, 'participants': <Object?>[], 'professionals': <Object?>[]},
      {
        'structure': {'units': null, 'groups': null},
      },
      {'structure': 'invalid', 'participants': 'invalid', 'professionals': 'invalid'},
    ]) {
      final repository = _repository((_) => _ok(data));
      final options = await repository.fetchFormOptions(institutionId: 'institution-1');
      expect(options.units, isEmpty, reason: '$data');
      expect(options.groups, isEmpty, reason: '$data');
      expect(options.students, isEmpty, reason: '$data');
      expect(options.professionals, isEmpty, reason: '$data');
      expect(
        await repository.searchProfessionals(institutionId: 'institution-1', query: 'Marina'),
        isEmpty,
        reason: '$data',
      );
    }
  });

  test('form options reject rows without the required identifiers', () async {
    for (final data in <Map<String, dynamic>>[
      {
        'structure': {
          'units': [
            {'name': 'Sem id'},
          ],
        },
      },
      {
        'structure': {
          'groups': [
            {'group_id': 'group-1', 'name': 'Sem unidade'},
          ],
        },
      },
      {
        'participants': [
          {'child_group_link_id': 'link-1', 'group_id': 'group-1', 'display_name': ' '},
        ],
      },
      {
        'professionals': [
          {'display_name': 'Sem membership', 'role_code': 'teacher'},
        ],
      },
      {
        'professionals': ['invalid'],
      },
    ]) {
      final repository = _repository((_) => _ok(data));
      await expectLater(
        repository.fetchFormOptions(institutionId: 'institution-1'),
        throwsA(isA<ActivityDirectoryUnavailableException>()),
        reason: '$data',
      );
    }
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

const _detailId = '8b200000-0000-4000-8000-000000000701';

/// Projecao de `superadmin_activity_detail_v2` com as tres secoes de edicao.
Map<String, Object?> _detail() => {
  'activity': <String, Object?>{
    'activity_id': _detailId,
    'institution_id': 'institution-1',
    'name': 'Robótica',
    'description': 'Descrição preservada',
    'taxonomy_id': 'taxonomy-1',
    'taxonomy_name': 'Robótica',
    'status': 'active',
    'management_version': 6,
    'icon_key': 'science',
    'initials': 'RO',
    'created_at': '2026-09-10T12:00:00Z',
    'updated_at': '2026-09-11T12:00:00Z',
  },
  'units': <Object?>[
    <String, Object?>{'unit_id': 'unit-1', 'name': 'Unidade Centro', 'status': 'active'},
    <String, Object?>{'unit_id': 'unit-2', 'name': 'Unidade Norte', 'status': 'active'},
  ],
  'groups': <Object?>[
    <String, Object?>{
      'group_id': 'group-1',
      'unit_id': 'unit-1',
      'name': 'Turma A',
      'status': 'active',
      'participation_mode': 'selected',
    },
    <String, Object?>{
      'group_id': 'group-2',
      'unit_id': 'unit-2',
      'name': 'Turma B',
      'status': 'active',
      'participation_mode': 'all',
    },
  ],
  'counts': <String, Object?>{
    'units': 2,
    'groups': 2,
    'participants': 2,
    'instructors': 1,
    'activity_admins': 1,
  },
  'participants': <Object?>[
    <String, Object?>{
      'child_group_link_id': 'link-1',
      'group_id': 'group-1',
      'display_name': 'Criança Um',
      'status': 'active',
    },
    <String, Object?>{
      'child_group_link_id': 'link-2',
      'group_id': 'group-1',
      'display_name': 'Criança Dois',
      'status': 'active',
    },
  ],
  'professionals': <Object?>[
    <String, Object?>{
      'membership_id': 'membership-1',
      'role': 'instructor',
      'group_id': 'group-1',
      'display_name': 'Marina Sintética',
      'status': 'active',
    },
    <String, Object?>{
      'membership_id': 'membership-2',
      'role': 'activity_admin',
      'group_id': null,
      'display_name': 'Mariana Sintética',
      'status': 'active',
    },
  ],
  'permissions': <String, Object?>{
    'policies': <Object?>[
      {'code': 'chat', 'mode': 'optional'},
    ],
    'group_settings': <Object?>[
      {'group_id': 'group-1', 'code': 'chat', 'enabled': true},
    ],
    'professional_actions': <Object?>[
      <String, Object?>{
        'membership_id': 'membership-2',
        'role': 'activity_admin',
        'group_id': null,
        'actions': <String, Object?>{
          'attendance': 'both',
          'chat': 'both',
          'happens': 'both',
          'moments': 'both',
          'now': 'both',
        },
      },
      <String, Object?>{
        'membership_id': 'membership-1',
        'role': 'instructor',
        'group_id': 'group-1',
        'actions': <String, Object?>{
          'attendance': 'both',
          'chat': 'view',
          'happens': 'edit',
          'moments': 'none',
          'now': 'both',
        },
      },
    ],
  },
};

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

Map<String, dynamic> _formOptions() => {
  'structure': {
    'units': [
      <String, Object?>{'unit_id': 'unit-1', 'name': 'Unidade Centro'},
      <String, Object?>{'unit_id': 'unit-2', 'name': 'Unidade Norte'},
    ],
    'groups': [
      {'group_id': 'group-1', 'unit_id': 'unit-1', 'name': 'Turma A'},
      {'group_id': 'group-2', 'unit_id': 'unit-2', 'name': 'Turma B'},
    ],
  },
  'participants': [
    {'child_group_link_id': 'link-1', 'group_id': 'group-1', 'display_name': 'Criança Um'},
    {'child_group_link_id': 'link-2', 'group_id': 'group-1', 'display_name': 'Criança Dois'},
  ],
  'professionals': [
    {'membership_id': 'membership-1', 'display_name': 'Marina Sintética', 'role_code': 'teacher'},
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
