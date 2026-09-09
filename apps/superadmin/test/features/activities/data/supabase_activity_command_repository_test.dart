import 'dart:convert';

import 'package:coelo_domain/locations.dart';

import 'package:coelo_superadmin/features/activities/data/supabase_activity_command_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_command.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('catalogued Activity atomic create candidate', () {
    test('default gate rejects selection and orphan reservation before HTTP', () async {
      var calls = 0;
      final repo = _atomicRepository((_) async {
        calls++;
        throw StateError('unexpected transport');
      });
      await expectLater(
        repo.save(_atomicCommand()),
        throwsA(isA<ActivityCommandUnavailableException>()),
      );
      await expectLater(
        repo.save(_atomicCommand(select: false, reserve: true)),
        throwsA(isA<ActivityCommandUnavailableException>()),
      );
      expect(calls, 0);
    });
    test('open gate still rejects orphan reservation edit and publish before HTTP', () async {
      var calls = 0;
      final repo = _atomicRepository((_) async {
        calls++;
        throw StateError('unexpected transport');
      }, enabled: true);
      for (final command in [
        _atomicCommand(select: false, reserve: true),
        _atomicCommand(activityId: _activityId),
        _atomicCommand(intent: ActivityCommandIntent.publish),
      ]) {
        await expectLater(repo.save(command), throwsA(isA<ActivityCommandUnavailableException>()));
      }
      expect(calls, 0);
    });
    test('weekly intent encodes sorted days explicit zone and date without consumer', () async {
      final intent = ActivityCreateReservationIntent(
        firstOccurrence: LocationReservationOccurrence(
          startsAt: DateTime.utc(2026, 9, 10, 12),
          endsAt: DateTime.utc(2026, 9, 10, 13),
        ),
        recurrence: LocationReservationWeekly(
          weekdays: {4, 1},
          until: DateTime.utc(2026, 9, 30),
          timeZone: 'America/Sao_Paulo',
        ),
      );
      final repo = _atomicRepository((r) async {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        final reservation = body['p_reservation'] as Map<String, dynamic>;
        expect(reservation['recurrence'], {
          'kind': 'weekly',
          'weekdays': [1, 4],
          'until': '2026-09-30',
          'time_zone': 'America/Sao_Paulo',
        });
        final data = _atomicData(reserve: true);
        (data['reservation']! as Map)['recurrence'] = reservation['recurrence'];
        return _atomicResponse(r, data);
      }, enabled: true);
      await repo.save(_atomicCommand(reservationIntent: intent));
    });
    for (final mutation in <String, void Function(Map<String, Object?>)>{
      'consumer': (r) => r['consumer'] = {'kind': 'activity', 'id': _locationId},
      'location': (r) => r['location_id'] = _activityId,
      'cancelled': (r) => r['state'] = 'cancelled',
    }.entries) {
      test('reservation rejects mismatched ${mutation.key}', () async {
        final data = _atomicData(reserve: true);
        mutation.value(data['reservation']! as Map<String, Object?>);
        final repo = _atomicRepository((r) async => _atomicResponse(r, data), enabled: true);
        await expectLater(
          repo.save(_atomicCommand(reserve: true)),
          throwsA(isA<ActivityCommandUnavailableException>()),
        );
      });
    }
    test('malformed denial cannot classify as authorized negative', () async {
      final repo = _atomicRepository(
        (r) async => Response(
          jsonEncode({
            'ok': false,
            'data': null,
            'error': {
              'code': 'SAI_PERMISSION_DENIED',
              'message': 'secret',
              'correlation_id': 'bad',
              'http_status': 403,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        ),
        enabled: true,
      );
      await expectLater(
        repo.save(_atomicCommand()),
        throwsA(isA<ActivityCommandUnavailableException>()),
      );
    });
    test('one RPC preserves request and catalog choice across retries', () async {
      final requests = <Request>[];
      final repo = _atomicRepository((request) async {
        requests.add(request);
        return _atomicResponse(request, _atomicData());
      }, enabled: true);
      final first = await repo.save(_atomicCommand());
      await repo.save(_atomicCommand());
      expect(first.locationId, _locationId);
      expect(first.reservation, isNull);
      expect(requests, hasLength(2));
      expect(requests[0].body, requests[1].body);
      final payload = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect(requests.first.url.path, '/rest/v1/rpc/superadmin_activity_location_create_v2');
      expect(
        payload.keys,
        unorderedEquals(['p_request_id', 'p_location_id', 'p_activity_payload', 'p_reservation']),
      );
      expect(payload['p_request_id'], _requestId);
      expect(payload['p_location_id'], _locationId);
      expect(payload['p_reservation'], isNull);
    });
    test('optional reservation carries no consumer and decodes correlated result', () async {
      var calls = 0;
      final repo = _atomicRepository((request) async {
        calls++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final reservation = body['p_reservation'] as Map<String, dynamic>;
        expect(
          reservation.keys,
          unorderedEquals(['first_occurrence', 'recurrence', 'conflict_justification']),
        );
        expect(reservation['recurrence'], {'kind': 'once'});
        return _atomicResponse(request, _atomicData(reserve: true));
      }, enabled: true);
      final result = await repo.save(_atomicCommand(reserve: true));
      expect(result.reservation!.consumer.id, _activityId);
      expect(result.reservation!.locationId, _locationId);
      expect(calls, 1);
    });
    for (final mutate in <String, void Function(Map<String, Object?>)>{
      'activity ID': (d) => d['activity_id'] = 'bad',
      'location ID': (d) => d['location_id'] = _activityId,
      'zero version': (d) => d['management_version'] = 0,
      'unsafe version': (d) => d['management_version'] = 9007199254740992,
      'published status': (d) => d['status'] = 'active',
      'correlation': (d) => d['correlation_id'] = 'secret',
      'replay type': (d) => d['replayed'] = 'false',
      'missing reservation': (d) => d.remove('reservation'),
      'unexpected field': (d) => d['secret'] = 'value',
      'unrequested reservation': (d) => d['reservation'] = _reservationData(),
    }.entries) {
      test('rejects bad atomic ${mutate.key}', () async {
        final data = _atomicData();
        mutate.value(data);
        final repo = _atomicRepository((r) async => _atomicResponse(r, data), enabled: true);
        await expectLater(
          repo.save(_atomicCommand()),
          throwsA(isA<ActivityCommandUnavailableException>()),
        );
      });
    }
    for (final code in ['SAI_PERMISSION_DENIED', 'SAI_CONCURRENT_CHANGE', 'SAI_INTERNAL_ERROR']) {
      test('sanitizes negative $code without fallback', () async {
        var calls = 0;
        final repo = _atomicRepository((r) async {
          calls++;
          return Response(
            jsonEncode({
              'ok': false,
              'data': null,
              'error': {
                'code': code,
                'message': 'secret',
                'correlation_id': _requestId,
                'http_status': 403,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }, enabled: true);
        await expectLater(
          repo.save(_atomicCommand()),
          throwsA(switch (code) {
            'SAI_PERMISSION_DENIED' => isA<ActivityCommandUnauthorizedException>(),
            'SAI_CONCURRENT_CHANGE' => isA<ActivityCommandConflictException>(),
            _ => isA<ActivityCommandUnavailableException>(),
          }),
        );
        expect(calls, 1);
      });
    }
    test('unknown transport Object never exposes its detail', () async {
      final repo = _atomicRepository((_) async => throw StateError('secret'), enabled: true);
      await expectLater(
        repo.save(_atomicCommand()),
        throwsA(isA<ActivityCommandUnavailableException>()),
      );
    });
  });
  test('saves an activity snapshot through one aggregate v2 RPC', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({
            'ok': true,
            'data': {
              'activity_id': 'activity-created-1',
              'management_version': 6,
              'status': 'draft',
              'correlation_id': 'correlation-1',
              'replayed': false,
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

    final result = await SupabaseActivityCommandRepository(client).save(_saveCommand);

    expect(captured!.url.path, endsWith('/rpc/superadmin_activity_save_v2'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_request_id'], '8b200000-0000-4000-8000-000000000901');
    expect(body['p_activity_id'], isNull);
    expect(body['p_expected_version'], 0);
    expect(body['p_publish'], isFalse);
    final payload = body['p_payload'] as Map<String, dynamic>;
    expect(payload['institution_id'], 'institution-1');
    expect(payload['unit_ids'], ['unit-1']);
    expect(payload['group_ids'], <Object?>[]);
    expect(result.activityId, 'activity-created-1');
    expect(result.managementVersion, 6);
    expect(result.status, ActivityStatus.draft);
  });

  test('unsupported activity save variants fail closed before HTTP', () async {
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
    final repository = SupabaseActivityCommandRepository(client);

    await expectLater(
      repository.save(_unsupportedSaveCommand),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
    await expectLater(
      repository.copyTemplate(
        const ActivityTemplateCopyCommand(
          requestId: 'copy-1',
          templateId: 'template-1',
          institutionId: 'institution-1',
        ),
      ),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
    await expectLater(
      repository.createLocations(
        const ActivityLocationCommand(
          requestId: 'locations-1',
          institutionId: 'institution-1',
          unitIds: {'unit-1'},
          name: 'Piscina',
        ),
      ),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
    await expectLater(
      repository.requestExport(ActivityDirectoryQuery(), format: ActivityCommandExportFormat.csv),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );

    expect(requestCount, 0);
  });

  test('maps aggregate concurrency envelope without a second request', () async {
    var requestCount = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requestCount++;
        return Response(
          jsonEncode({
            'ok': false,
            'data': null,
            'error': {
              'code': 'SAI_CONCURRENT_CHANGE',
              'message': 'O estado mudou.',
              'http_status': 409,
              'correlation_id': 'correlation-2',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseActivityCommandRepository(client).save(_saveCommand),
      throwsA(isA<ActivityCommandConflictException>()),
    );
    expect(requestCount, 1);
  });

  test('edits fail closed before HTTP until complete snapshots are available', () async {
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

    await expectLater(
      SupabaseActivityCommandRepository(client).save(_editSaveCommand),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
    await expectLater(
      SupabaseActivityCommandRepository(client).save(_publishSaveCommand),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
    expect(requestCount, 0);
  });

  test('rejects a non-positive aggregate management version', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({
            'ok': true,
            'data': {
              'activity_id': 'activity-created-1',
              'management_version': 0,
              'status': 'draft',
              'correlation_id': 'correlation-invalid',
              'replayed': false,
            },
            'error': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseActivityCommandRepository(client).save(_saveCommand),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
  });

  test('creates a unit-scoped model through the internal gateway', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({
            'id': 'template-created-1',
            'institution_id': 'institution-1',
            'unit_id': 'unit-1',
            'name': 'Física',
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await SupabaseActivityCommandRepository(client).createTemplate(
      const ActivityTemplateCreateCommand(
        requestId: 'template-create-request-1',
        institutionId: 'institution-1',
        unitId: 'unit-1',
        name: ' Física ',
        description: ' Ciências exatas ',
        taxonomyId: 'taxonomy-exact-sciences',
        governance: ActivityGovernance.mandatory,
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_create_scoped_activity_template'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_unit_id'], 'unit-1');
    expect(body['p_name'], 'Física');
    expect(body['p_description'], 'Ciências exatas');
    expect(result.unitId, 'unit-1');
  });

  test('rejects a model response bound to another institution', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({
            'id': 'template-created-1',
            'institution_id': 'institution-tampered',
            'unit_id': 'unit-1',
            'name': 'Física',
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseActivityCommandRepository(client).createTemplate(
        const ActivityTemplateCreateCommand(
          requestId: 'template-create-request-2',
          institutionId: 'institution-1',
          unitId: 'unit-1',
          name: 'Física',
          description: 'Ciências exatas',
          taxonomyId: 'taxonomy-exact-sciences',
          governance: ActivityGovernance.mandatory,
        ),
      ),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
  });

  test('maps internal model authorization denial', () async {
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
      SupabaseActivityCommandRepository(client).createTemplate(
        const ActivityTemplateCreateCommand(
          requestId: 'create-1',
          institutionId: 'institution-1',
          name: 'Física',
          description: '',
          taxonomyId: 'taxonomy-1',
          governance: ActivityGovernance.optional,
        ),
      ),
      throwsA(isA<ActivityCommandUnauthorizedException>()),
    );
  });
}

const _requestId = '8b200000-0000-4000-8000-000000000901';
const _activityId = '8b200000-0000-4000-8000-000000000902';
const _locationId = '8b200000-0000-4000-8000-000000000903';
const _institutionId = '8b200000-0000-4000-8000-000000000904';
ActivitySaveCommand _atomicCommand({
  bool select = true,
  bool reserve = false,
  String? activityId,
  ActivityCommandIntent intent = ActivityCommandIntent.saveDraft,
  ActivityCreateReservationIntent? reservationIntent,
}) => ActivitySaveCommand(
  requestId: _requestId,
  intent: intent,
  activityId: activityId,
  name: 'Activity',
  description: '',
  taxonomyId: _activityId,
  taxonomyOtherDescription: '',
  governance: ActivityGovernance.optional,
  institutionId: _institutionId,
  unitIds: const {_institutionId},
  groupIds: const {},
  assignments: const [],
  identity: _saveCommand.identity,
  locationSelection: select
      ? const CataloguedLocationSelection(
          LocationReferenceSnapshot(
            id: _locationId,
            scope: LocationScope.institution(institutionId: _institutionId),
            kind: LocationKind.internal,
            label: 'Room',
          ),
        )
      : null,
  reservation:
      reservationIntent ??
      (reserve
          ? ActivityCreateReservationIntent(
              firstOccurrence: LocationReservationOccurrence(
                startsAt: DateTime.utc(2026, 9, 10, 12),
                endsAt: DateTime.utc(2026, 9, 10, 13),
              ),
              recurrence: const LocationReservationOnce(),
            )
          : null),
);
Map<String, Object?> _atomicData({bool reserve = false}) => {
  'activity_id': _activityId,
  'management_version': 3,
  'status': 'draft',
  'correlation_id': _requestId,
  'replayed': false,
  'location_id': _locationId,
  'reservation': reserve ? _reservationData() : null,
};
Map<String, Object?> _reservationData() => {
  'id': _requestId,
  'location_id': _locationId,
  'consumer': {'kind': 'activity', 'id': _activityId},
  'state': 'active',
  'recurrence': {'kind': 'once'},
  'occurrences': [
    {'starts_at': '2026-09-10T12:00:00Z', 'ends_at': '2026-09-10T13:00:00Z'},
  ],
  'management_version': 1,
  'confirmed_over_conflict': false,
};
Response _atomicResponse(Request r, Object data) => Response(
  jsonEncode({'ok': true, 'data': data, 'error': null}),
  200,
  headers: {'content-type': 'application/json'},
  request: r,
);
SupabaseActivityCommandRepository _atomicRepository(
  Future<Response> Function(Request) handler, {
  bool enabled = false,
}) {
  final client = SupabaseClient(
    'https://example.test',
    'public-test-key',
    httpClient: MockClient(handler),
  );
  addTearDown(client.dispose);
  return SupabaseActivityCommandRepository(client, activityLocationCreateAvailable: enabled);
}

const _saveCommand = ActivitySaveCommand(
  requestId: '8b200000-0000-4000-8000-000000000901',
  intent: ActivityCommandIntent.saveDraft,
  name: 'Natação',
  description: '',
  taxonomyId: 'taxonomy-1',
  taxonomyOtherDescription: '',
  governance: ActivityGovernance.optional,
  institutionId: 'institution-1',
  unitIds: {'unit-1'},
  groupIds: {},
  assignments: [],
  identity: ActivityCommandIdentity(
    kind: ActivityIdentityKind.initials,
    initials: 'NA',
    color: '#D63C00',
    icon: 'activity',
  ),
);

const _unsupportedSaveCommand = ActivitySaveCommand(
  requestId: '8b200000-0000-4000-8000-000000000902',
  intent: ActivityCommandIntent.saveDraft,
  name: 'Natação',
  description: '',
  taxonomyId: 'taxonomy-1',
  taxonomyOtherDescription: '',
  governance: ActivityGovernance.mandatory,
  institutionId: 'institution-1',
  unitIds: {'unit-1'},
  groupIds: {},
  assignments: [],
  identity: ActivityCommandIdentity(
    kind: ActivityIdentityKind.initials,
    initials: 'NA',
    color: '#D63C00',
    icon: 'activity',
  ),
);

const _editSaveCommand = ActivitySaveCommand(
  requestId: '8b200000-0000-4000-8000-000000000903',
  intent: ActivityCommandIntent.saveDraft,
  activityId: 'activity-expected',
  expectedVersion: 6,
  name: 'Natação',
  description: '',
  taxonomyId: 'taxonomy-1',
  taxonomyOtherDescription: '',
  governance: ActivityGovernance.optional,
  institutionId: 'institution-1',
  unitIds: {'unit-1'},
  groupIds: {},
  assignments: [],
  identity: ActivityCommandIdentity(
    kind: ActivityIdentityKind.initials,
    initials: 'NA',
    color: '#D63C00',
    icon: 'activity',
  ),
);

const _publishSaveCommand = ActivitySaveCommand(
  requestId: '8b200000-0000-4000-8000-000000000904',
  intent: ActivityCommandIntent.publish,
  activityId: 'activity-expected',
  expectedVersion: 6,
  name: 'Natação',
  description: '',
  taxonomyId: 'taxonomy-1',
  taxonomyOtherDescription: '',
  governance: ActivityGovernance.optional,
  institutionId: 'institution-1',
  unitIds: {'unit-1'},
  groupIds: {},
  assignments: [],
  identity: ActivityCommandIdentity(
    kind: ActivityIdentityKind.initials,
    initials: 'NA',
    color: '#D63C00',
    icon: 'activity',
  ),
);
