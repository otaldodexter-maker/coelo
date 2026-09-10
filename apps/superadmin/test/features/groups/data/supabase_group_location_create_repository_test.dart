import 'dart:convert';

import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/groups/data/supabase_group_location_create_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_location_create.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const requestId = '11000000-0000-4000-8000-000000000001';
const institutionId = '22000000-0000-4000-8000-000000000001';
const unitId = '33000000-0000-4000-8000-000000000001';
const locationId = '44000000-0000-4000-8000-000000000001';
const groupId = '55000000-0000-4000-8000-000000000001';

void main() {
  test('reservation canonical DST and justified override remain server authoritative', () async {
    final intent = GroupLocationReservationIntent(
      firstOccurrence: LocationReservationOccurrence(
        startsAt: DateTime.utc(2026, 10, 30, 12),
        endsAt: DateTime.utc(2026, 10, 30, 13),
      ),
      recurrence: LocationReservationRecurrence.weekly(
        weekdays: {5},
        until: DateTime.utc(2026, 11, 6),
        timeZone: 'America/New_York',
      ),
      conflictJustification: 'Approved exception',
    );
    final result = _reservation()
      ..['recurrence'] = intent.toJson()['recurrence']
      ..['confirmed_over_conflict'] = true
      ..['occurrences'] = [
        {'starts_at': '2026-10-30T12:00:00Z', 'ends_at': '2026-10-30T13:00:00Z'},
        {'starts_at': '2026-11-06T13:00:00Z', 'ends_at': '2026-11-06T14:00:00Z'},
      ];
    final repo = _repo(
      (r) async => _success(r, {..._data(), 'reservation': result}),
      available: true,
    );
    final saved = (await repo.create(_command(reservationIntent: intent))).reservation!;
    expect(saved.confirmedOverConflict, isTrue);
    expect(saved.occurrences.last.startsAt.hour, 13);
  });
  for (final mismatch in ['start', 'end', 'kind', 'days', 'until', 'zone', 'override']) {
    test('reservation intent correlation Group rejects $mismatch', () async {
      final weekly = ['days', 'until', 'zone'].contains(mismatch);
      final recurrence = weekly
          ? LocationReservationRecurrence.weekly(
              weekdays: {5},
              until: DateTime.utc(2026, 9, 30),
              timeZone: 'America/Sao_Paulo',
            )
          : const LocationReservationRecurrence.once();
      final intent = GroupLocationReservationIntent(
        firstOccurrence: _occurrence(),
        recurrence: recurrence,
      );
      final result = _reservation();
      result['recurrence'] = intent.toJson()['recurrence'];
      switch (mismatch) {
        case 'start':
          (result['occurrences'] as List).first['starts_at'] = '2026-09-11T12:30:00Z';
        case 'end':
          (result['occurrences'] as List).first['ends_at'] = '2026-09-11T14:00:00Z';
        case 'kind':
          result['recurrence'] = {
            'kind': 'weekly',
            'weekdays': [5],
            'until': '2026-09-30',
            'time_zone': 'America/Sao_Paulo',
          };
        case 'days':
          (result['recurrence'] as Map)['weekdays'] = [4];
        case 'until':
          (result['recurrence'] as Map)['until'] = '2026-10-01';
        case 'zone':
          (result['recurrence'] as Map)['time_zone'] = 'UTC';
        case 'override':
          result['confirmed_over_conflict'] = true;
      }
      final repo = _repo(
        (r) async => _success(r, {..._data(), 'reservation': result}),
        available: true,
      );
      await expectLater(
        repo.create(_command(reservationIntent: intent)),
        _failure(GroupLocationCreateFailure.unavailable),
      );
    });
  }
  test(
    'reservation intent correlation Group accepts normalized instants and weekly expansion',
    () async {
      final intent = GroupLocationReservationIntent(
        firstOccurrence: _occurrence(),
        recurrence: LocationReservationRecurrence.weekly(
          weekdays: {5, 1},
          until: DateTime.utc(2026, 9, 30),
          timeZone: 'America/Sao_Paulo',
        ),
        conflictJustification: 'approved reason',
      );
      final result = _reservation()..['recurrence'] = intent.toJson()['recurrence'];
      result['occurrences'] = [
        {'starts_at': '2026-09-11T12:00:00.000+00:00', 'ends_at': '2026-09-11T13:00:00.000+00:00'},
        {'starts_at': '2026-09-14T12:00:00Z', 'ends_at': '2026-09-14T13:00:00Z'},
      ];
      final repo = _repo(
        (r) async => _success(r, {..._data(), 'reservation': result}),
        available: true,
      );
      expect(
        (await repo.create(_command(reservationIntent: intent))).reservation!.occurrences,
        hasLength(2),
      );
    },
  );
  test('default gate and unavailable repository perform no request', () async {
    var calls = 0;
    final repo = _repo((r) async {
      calls++;
      return _success(r, _data());
    });
    expect(repo.available, isFalse);
    await expectLater(repo.create(_command()), _failure(GroupLocationCreateFailure.unavailable));
    await expectLater(
      const UnavailableGroupLocationCreateRepository().create(_command()),
      _failure(GroupLocationCreateFailure.unavailable),
    );
    expect(calls, 0);
  });
  test('catalog-only create uses one RPC and retains request on retry', () async {
    final requests = <Request>[];
    final repo = _repo((r) async {
      requests.add(r);
      return _success(r, _data());
    }, available: true);
    final result = await repo.create(_command());
    await repo.create(_command());
    expect(result.groupId, groupId);
    expect(result.locationId, locationId);
    expect(result.status, 'draft');
    expect(result.managementVersion, 1);
    expect(result.reservation, isNull);
    expect(requests, hasLength(2));
    expect(requests[0].body, requests[1].body);
    expect(requests.first.method, 'POST');
    expect(requests.first.url.path, '/rest/v1/rpc/superadmin_group_location_create_v2');
    expect(jsonDecode(requests.first.body), {
      'p_request_id': requestId,
      'p_location_id': locationId,
      'p_reservation': null,
      'p_group_payload': {
        'institution_id': institutionId,
        'unit_id': unitId,
        'name': 'Group',
        'group_type': 'class',
        'group_type_other_text': null,
      },
    });
  });
  test('reservation has three keys and returned consumer is the new Group', () async {
    var calls = 0;
    final command = _command(reserve: true);
    final repo = _repo((r) async {
      calls++;
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body['p_reservation'], command.reservation!.toJson());
      expect(
        (body['p_reservation'] as Map).keys,
        unorderedEquals(['first_occurrence', 'recurrence', 'conflict_justification']),
      );
      return _success(r, _data(reserve: true));
    }, available: true);
    final result = await repo.create(command);
    expect(result.reservation!.consumer.kind, LocationReservationConsumerKind.group);
    expect(result.reservation!.consumer.id, groupId);
    expect(calls, 1);
  });
  test('weekly intent preserves sorted weekdays zone and calendar date', () {
    final intent = GroupLocationReservationIntent(
      firstOccurrence: _occurrence(),
      recurrence: LocationReservationWeekly(
        weekdays: {4, 1},
        until: DateTime.utc(2026, 9, 30),
        timeZone: 'America/Sao_Paulo',
      ),
      conflictJustification: ' reason ',
    );
    expect(intent.toJson()['recurrence'], {
      'kind': 'weekly',
      'weekdays': [1, 4],
      'until': '2026-09-30',
      'time_zone': 'America/Sao_Paulo',
    });
    expect(intent.toJson()['conflict_justification'], 'reason');
  });
  for (final invalid in ['id', 'institution', 'unit', 'name', 'other']) {
    test('invalid $invalid fails before HTTP', () async {
      var calls = 0;
      final repo = _repo((r) async {
        calls++;
        return _success(r, _data());
      }, available: true);
      await expectLater(
        repo.create(_command(invalid: invalid)),
        _failure(GroupLocationCreateFailure.invalidInput),
      );
      expect(calls, 0);
    });
  }
  for (final entry in <String, void Function(Map<String, Object?>)>{
    'id': (d) => d['group_id'] = 'bad',
    'location': (d) => d['location_id'] = groupId,
    'version': (d) => d['management_version'] = 0,
    'unsafe version': (d) => d['management_version'] = 9007199254740992,
    'status': (d) => d['status'] = 'active',
    'correlation': (d) => d['correlation_id'] = 'bad',
    'replayed': (d) => d['replayed'] = 'false',
    'missing': (d) => d.remove('reservation'),
    'extra': (d) => d['extra'] = 'secret',
    'unsolicited reservation': (d) => d['reservation'] = _reservation(),
  }.entries) {
    test('malformed result ${entry.key} fails closed', () async {
      final data = _data();
      entry.value(data);
      await expectLater(
        _repo((r) async => _success(r, data), available: true).create(_command()),
        _failure(GroupLocationCreateFailure.unavailable),
      );
    });
  }
  for (final entry in <String, void Function(Map<String, Object?>)>{
    'consumer': (r) => r['consumer'] = {'kind': 'group', 'id': locationId},
    'location': (r) => r['location_id'] = groupId,
    'state': (r) => r['state'] = 'cancelled',
  }.entries) {
    test('reservation ${entry.key} mismatch rejected', () async {
      final data = _data(reserve: true);
      entry.value(data['reservation']! as Map<String, Object?>);
      await expectLater(
        _repo((r) async => _success(r, data), available: true).create(_command(reserve: true)),
        _failure(GroupLocationCreateFailure.unavailable),
      );
    });
  }
  for (final code in [
    'SAI_PERMISSION_DENIED',
    'SAI_CONCURRENT_CHANGE',
    'SAI_INVALID_ARGUMENT',
    'SAI_INTERNAL_ERROR',
  ]) {
    test('sanitized negative $code and no followup', () async {
      var calls = 0;
      final repo = _repo((r) async {
        calls++;
        return _response(r, {
          'ok': false,
          'data': null,
          'error': {
            'code': code,
            'message': 'secret',
            'correlation_id': requestId,
            'http_status': 403,
          },
        });
      }, available: true);
      await expectLater(
        repo.create(_command()),
        _failure(switch (code) {
          'SAI_PERMISSION_DENIED' => GroupLocationCreateFailure.denied,
          'SAI_CONCURRENT_CHANGE' => GroupLocationCreateFailure.conflict,
          'SAI_INVALID_ARGUMENT' => GroupLocationCreateFailure.invalidInput,
          _ => GroupLocationCreateFailure.unavailable,
        }),
      );
      expect(calls, 1);
    });
  }
  test('malformed negative never becomes a known denial', () async {
    final repo = _repo(
      (r) async => _response(r, {
        'ok': false,
        'data': null,
        'error': {'code': 'SAI_PERMISSION_DENIED'},
      }),
      available: true,
    );
    await expectLater(repo.create(_command()), _failure(GroupLocationCreateFailure.unavailable));
  });
  test('unknown transport Object is sanitized', () async {
    await expectLater(
      _repo((_) async => throw StateError('secret'), available: true).create(_command()),
      _failure(GroupLocationCreateFailure.unavailable),
    );
  });
}

Matcher _failure(GroupLocationCreateFailure failure) => throwsA(
  isA<GroupLocationCreateException>()
      .having((e) => e.failure, 'failure', failure)
      .having((e) => e.toString().contains('secret'), 'leaks secret', isFalse),
);
LocationReservationOccurrence _occurrence() => LocationReservationOccurrence(
  startsAt: DateTime.utc(2026, 9, 11, 12),
  endsAt: DateTime.utc(2026, 9, 11, 13),
);
GroupLocationCreateCommand _command({
  bool reserve = false,
  String? invalid,
  GroupLocationReservationIntent? reservationIntent,
}) => GroupLocationCreateCommand(
  requestId: invalid == 'id' ? 'bad' : requestId,
  institutionId: institutionId,
  unitId: unitId,
  name: invalid == 'name' ? ' ' : ' Group ',
  groupType: invalid == 'other' ? 'other' : 'CLASS',
  groupTypeOtherText: null,
  locationSelection: CataloguedLocationSelection(
    LocationReferenceSnapshot(
      id: locationId,
      label: 'Room',
      kind: LocationKind.internal,
      scope: invalid == 'unit'
          ? const LocationScope.unit(institutionId: institutionId, unitId: groupId)
          : LocationScope.institution(
              institutionId: invalid == 'institution' ? groupId : institutionId,
            ),
    ),
  ),
  reservation:
      reservationIntent ??
      (reserve
          ? GroupLocationReservationIntent(
              firstOccurrence: _occurrence(),
              recurrence: const LocationReservationOnce(),
            )
          : null),
);
Map<String, Object?> _data({bool reserve = false}) => {
  'group_id': groupId,
  'location_id': locationId,
  'management_version': 1,
  'status': 'draft',
  'correlation_id': requestId,
  'replayed': false,
  'reservation': reserve ? _reservation() : null,
};
Map<String, Object?> _reservation() => {
  'id': requestId,
  'location_id': locationId,
  'consumer': {'kind': 'group', 'id': groupId},
  'state': 'active',
  'recurrence': {'kind': 'once'},
  'occurrences': [
    {'starts_at': '2026-09-11T12:00:00Z', 'ends_at': '2026-09-11T13:00:00Z'},
  ],
  'management_version': 1,
  'confirmed_over_conflict': false,
};
Response _response(Request r, Object? data) =>
    Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'}, request: r);
Response _success(Request r, Object data) =>
    _response(r, {'ok': true, 'data': data, 'error': null});
SupabaseGroupLocationCreateRepository _repo(
  Future<Response> Function(Request) handle, {
  bool available = false,
}) {
  final client = SupabaseClient(
    'https://example.test',
    'public-test-key',
    httpClient: MockClient(handle),
  );
  addTearDown(client.dispose);
  return SupabaseGroupLocationCreateRepository(client, available: available);
}
