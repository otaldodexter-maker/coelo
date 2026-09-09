import 'package:coelo_domain/locations.dart';
import 'package:test/test.dart';

LocationReservationOccurrence occurrence(int startHour, int endHour) =>
    LocationReservationOccurrence(
      startsAt: DateTime.utc(2026, 9, 14, startHour),
      endsAt: DateTime.utc(2026, 9, 14, endHour),
    );

void main() {
  group('an occurrence is a dated moment, not a clock rule', () {
    test('it is stored in UTC, because a wall clock does not survive a DST boundary', () {
      expect(
        () => LocationReservationOccurrence(
          startsAt: DateTime(2026, 9, 14, 8),
          endsAt: DateTime.utc(2026, 9, 14, 10),
        ),
        throwsArgumentError,
      );
    });

    test('it must last', () {
      expect(() => occurrence(8, 8), throwsArgumentError);
      expect(
        () => LocationReservationOccurrence(
          startsAt: DateTime.utc(2026, 9, 14, 10),
          endsAt: DateTime.utc(2026, 9, 14, 8),
        ),
        throwsArgumentError,
      );
    });

    test('touching occurrences do not overlap, matching the availability rule', () {
      expect(occurrence(8, 10).overlaps(occurrence(10, 12)), isFalse);
      expect(occurrence(8, 12).overlaps(occurrence(10, 14)), isTrue);
      expect(occurrence(8, 12).overlaps(occurrence(9, 10)), isTrue);
    });
  });

  group('recurrence', () {
    test('copies the weekdays so an outstanding request cannot change', () {
      final days = {1, 3};
      final weekly = LocationReservationWeekly(
        weekdays: days,
        timeZone: 'America/Sao_Paulo',
        until: DateTime.utc(2026, 12, 18),
      );
      days.clear();
      expect(weekly.weekdays, {1, 3});
      expect(() => weekly.weekdays.add(5), throwsUnsupportedError);
    });

    test('rejects empty or invalid weekdays and a non-date end boundary', () {
      for (final days in <Set<int>>[
        {},
        {-1},
        {7},
      ]) {
        expect(
          () => LocationReservationWeekly(
            weekdays: days,
            timeZone: 'America/Sao_Paulo',
            until: DateTime.utc(2026, 12, 18),
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => LocationReservationWeekly(
          weekdays: {1},
          timeZone: 'America/Sao_Paulo',
          until: DateTime.utc(2026, 12, 18, 12),
        ),
        throwsArgumentError,
      );
    });
    test('only the two approved shapes exist', () {
      const once = LocationReservationRecurrence.once();
      final weekly = LocationReservationRecurrence.weekly(
        weekdays: const {1, 3},
        timeZone: 'America/Sao_Paulo',
        until: DateTime.utc(2026, 12, 18),
      );
      expect(once, isA<LocationReservationOnce>());
      expect(weekly, isA<LocationReservationWeekly>());
      // An unbounded recurrence has no constructor at all: a room held forever
      // is a room nobody can plan around.
      expect((weekly as LocationReservationWeekly).until, DateTime.utc(2026, 12, 18));
    });

    test('weekday numbering matches the availability contract, so no translation is needed', () {
      final weekly =
          LocationReservationRecurrence.weekly(
                weekdays: const {0, 6},
                timeZone: 'America/Sao_Paulo',
                until: DateTime.utc(2026, 12, 18),
              )
              as LocationReservationWeekly;
      final window = LocationScheduleWindow(weekday: 0, startsMinute: 480, endsMinute: 720);
      expect(weekly.weekdays.contains(window.weekday), isTrue);
    });
  });

  group('the conflict answer belongs to the server', () {
    test('a justification is demanded only when an overlap is confirmable', () {
      for (final entry in {
        LocationReservationConflict.none: false,
        LocationReservationConflict.refused: false,
        LocationReservationConflict.confirmable: true,
        LocationReservationConflict.notConfirmable: false,
      }.entries) {
        final assessment = LocationReservationAssessment(
          policy: LocationSchedulingPolicy.warn,
          conflict: entry.key,
          conflicting: const [],
        );
        expect(assessment.requiresJustification, entry.value, reason: entry.key.name);
      }
    });

    test('the assessment never carries the other consumer, only the occupied moments', () {
      final assessment = LocationReservationAssessment(
        policy: LocationSchedulingPolicy.block,
        conflict: LocationReservationConflict.refused,
        conflicting: [occurrence(8, 10)],
      );
      expect(assessment.conflicting.single.startsAt, DateTime.utc(2026, 9, 14, 8));
      expect(() => assessment.conflicting.add(occurrence(12, 13)), throwsUnsupportedError);
    });
  });

  group('a reservation always belongs to something', () {
    test('the consumer is a kind plus that consumer own id', () {
      const consumer = LocationReservationConsumer(
        kind: LocationReservationConsumerKind.activity,
        id: '70000000-0000-4000-8000-000000000001',
      );
      expect(consumer.kind, LocationReservationConsumerKind.activity);
      expect(
        consumer,
        const LocationReservationConsumer(
          kind: LocationReservationConsumerKind.activity,
          id: '70000000-0000-4000-8000-000000000001',
        ),
      );
      expect(
        consumer ==
            const LocationReservationConsumer(
              kind: LocationReservationConsumerKind.event,
              id: '70000000-0000-4000-8000-000000000001',
            ),
        isFalse,
      );
    });

    test('occurrences come expanded from the server and cannot be edited locally', () {
      final reservation = LocationReservation(
        id: '80000000-0000-4000-8000-000000000001',
        locationId: '10000000-0000-4000-8000-000000000001',
        consumer: const LocationReservationConsumer(
          kind: LocationReservationConsumerKind.group,
          id: '90000000-0000-4000-8000-000000000001',
        ),
        state: LocationReservationState.active,
        recurrence: const LocationReservationRecurrence.once(),
        occurrences: [occurrence(8, 10)],
        managementVersion: 1,
      );
      expect(reservation.occurrences.length, 1);
      expect(reservation.confirmedOverConflict, isFalse);
      // Two clients expanding the same rule differently is how a double booking
      // becomes invisible, so the list is not the client's to change.
      expect(() => reservation.occurrences.add(occurrence(12, 13)), throwsUnsupportedError);
    });

    test('a confirmed overlap is visible on the reservation, not only in the audit trail', () {
      final reservation = LocationReservation(
        id: '80000000-0000-4000-8000-000000000002',
        locationId: '10000000-0000-4000-8000-000000000001',
        consumer: const LocationReservationConsumer(
          kind: LocationReservationConsumerKind.event,
          id: '90000000-0000-4000-8000-000000000002',
        ),
        state: LocationReservationState.active,
        recurrence: const LocationReservationRecurrence.once(),
        occurrences: [occurrence(8, 10)],
        managementVersion: 2,
        confirmedOverConflict: true,
      );
      expect(reservation.confirmedOverConflict, isTrue);
    });
  });

  test('availability and reservation answer different questions', () {
    // The contract exists precisely so nobody widens one into the other. A
    // window is a rule with no date; an occurrence is a dated instant.
    final window = LocationScheduleWindow(weekday: 1, startsMinute: 480, endsMinute: 720);
    expect(window.startsMinute, isA<int>());
    expect(occurrence(8, 12).startsAt, isA<DateTime>());
    expect(
      LocationSchedule(
        locationId: '10000000-0000-4000-8000-000000000001',
        managementVersion: 1,
        windows: [window],
      ).isPublished,
      isTrue,
    );
  });
}
