import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:test/test.dart';

const _location = '10000000-0000-4000-8000-000000000001';
const _consumer = LocationReservationConsumer(
  kind: LocationReservationConsumerKind.activity,
  id: '20000000-0000-4000-8000-000000000001',
);

Map<String, Object?> _occurrence() => {
  'starts_at': '2026-09-14T11:00:00Z',
  'ends_at': '2026-09-14T12:00:00Z',
};

Map<String, Object?> _reservation() => {
  'id': '30000000-0000-4000-8000-000000000001',
  'location_id': _location,
  'consumer': {'kind': 'activity', 'id': _consumer.id},
  'state': 'active',
  'recurrence': {'kind': 'once'},
  'occurrences': [_occurrence()],
  'management_version': 1,
  'confirmed_over_conflict': false,
};

Map<String, Object?> _assessment() => {
  'location_id': _location,
  'consumer': {'kind': 'activity', 'id': _consumer.id},
  'policy': 'warn',
  'conflict': 'confirmable',
  'conflicting': [_occurrence()],
};

void main() {
  test('encodes explicit weekly zone and calendar end without expanding occurrences', () {
    final payload = encodeLocationReservationDraftV2(
      LocationReservationDraft(
        locationId: _location,
        consumer: _consumer,
        firstOccurrence: LocationReservationOccurrence(
          startsAt: DateTime.utc(2026, 9, 14, 11),
          endsAt: DateTime.utc(2026, 9, 14, 12),
        ),
        recurrence: LocationReservationRecurrence.weekly(
          weekdays: {3, 1},
          until: DateTime.utc(2026, 12, 18),
          timeZone: 'America/Sao_Paulo',
        ),
      ),
    );
    expect(payload['recurrence'], {
      'kind': 'weekly',
      'weekdays': [1, 3],
      'until': '2026-12-18',
      'time_zone': 'America/Sao_Paulo',
    });
    expect(payload.containsKey('policy'), isFalse);
    expect(payload.containsKey('occurrences'), isFalse);
    final decoded = decodeLocationReservationV2(
      {..._reservation(), 'recurrence': payload['recurrence']},
      requestedLocationId: _location,
      requestedConsumer: _consumer,
    );
    expect((decoded.recurrence as LocationReservationWeekly).timeZone, 'America/Sao_Paulo');
  });

  test('decodes a reservation bound to the requested location and consumer', () {
    final result = decodeLocationReservationV2(
      _reservation(),
      requestedLocationId: _location,
      requestedConsumer: _consumer,
    );
    expect(result.managementVersion, 1);
    expect(result.occurrences.single.startsAt, DateTime.utc(2026, 9, 14, 11));
  });

  for (final mutation in <String, void Function(Map<String, Object?>)>{
    'wrong location': (v) => v['location_id'] = _consumer.id,
    'wrong consumer kind': (v) => v['consumer'] = {'kind': 'group', 'id': _consumer.id},
    'wrong consumer id': (v) => v['consumer'] = {'kind': 'activity', 'id': _location},
    'unknown field': (v) => v['storage_key'] = 'must-never-be-accepted',
    'non-positive version': (v) => v['management_version'] = 0,
    'invalid boolean': (v) => v['confirmed_over_conflict'] = 'true',
    'empty occurrences': (v) => v['occurrences'] = [],
    'multiple once occurrences': (v) => v['occurrences'] = [_occurrence(), _occurrence()],
    'local timestamp': (v) => v['occurrences'] = [
      {..._occurrence(), 'starts_at': '2026-09-14T11:00:00'},
    ],
    'reversed duration': (v) => v['occurrences'] = [
      {..._occurrence(), 'ends_at': '2026-09-14T10:00:00Z'},
    ],
    'invalid recurrence date': (v) => v['recurrence'] = {
      'kind': 'weekly',
      'weekdays': [1],
      'until': '2026-02-31',
      'time_zone': 'UTC',
    },
    'duplicate weekdays': (v) => v['recurrence'] = {
      'kind': 'weekly',
      'weekdays': [1, 1],
      'until': '2026-12-18',
      'time_zone': 'UTC',
    },
    'unknown state': (v) => v['state'] = 'published',
  }.entries) {
    test('rejects ${mutation.key}', () {
      final data = _reservation();
      mutation.value(data);
      expect(
        () => decodeLocationReservationV2(
          data,
          requestedLocationId: _location,
          requestedConsumer: _consumer,
        ),
        throwsFormatException,
      );
    });
  }

  test('assessment keeps only conflict intervals and requires justification', () {
    final result = decodeLocationReservationAssessmentV2(
      _assessment(),
      requestedLocationId: _location,
      requestedConsumer: _consumer,
    );
    expect(result.requiresJustification, isTrue);
    expect(() => result.conflicting.clear(), throwsUnsupportedError);
  });

  for (final mutation in <String, void Function(Map<String, Object?>)>{
    'block cannot be confirmable': (v) => v['policy'] = 'block',
    'none cannot carry conflicts': (v) => v['conflict'] = 'none',
    'conflict must contain an interval': (v) => v['conflicting'] = [],
    'assessment cannot disclose holders': (v) => v['conflicting'] = [
      {..._occurrence(), 'consumer_id': _consumer.id},
    ],
    'assessment must correlate location': (v) => v['location_id'] = _consumer.id,
  }.entries) {
    test(mutation.key, () {
      final data = _assessment();
      mutation.value(data);
      expect(
        () => decodeLocationReservationAssessmentV2(
          data,
          requestedLocationId: _location,
          requestedConsumer: _consumer,
        ),
        throwsFormatException,
      );
    });
  }
}
