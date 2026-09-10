import 'package:coelo_domain/locations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coelo_superadmin/features/activities/domain/activity_command.dart';
import 'package:coelo_superadmin/features/groups/domain/group_location_create.dart';

void main() {
  final first = LocationReservationOccurrence(
    startsAt: DateTime.utc(2026, 9, 10, 12),
    endsAt: DateTime.utc(2026, 9, 10, 13),
  );
  for (final group in [false, true]) {
    Map<String, Object?> encode(String? value) => group
        ? GroupLocationReservationIntent(
            firstOccurrence: first,
            recurrence: const LocationReservationOnce(),
            conflictJustification: value,
          ).toJson()
        : ActivityCreateReservationIntent(
            firstOccurrence: first,
            recurrence: const LocationReservationOnce(),
            conflictJustification: value,
          ).toJson();
    for (final symbol in ['a', '😀']) {
      test('justification group=$group accepts 1000 codepoints ${symbol.runes.first}', () {
        final value = symbol * 1000;
        expect(encode('  $value  ')['conflict_justification'], value);
      });
      test('justification group=$group rejects 1001 codepoints ${symbol.runes.first}', () {
        expect(
          () => encode(symbol * 1001),
          throwsA(
            group
                ? isA<GroupLocationCreateException>()
                : isA<ActivityCommandUnavailableException>(),
          ),
        );
      });
    }
    test('justification group=$group preserves null and rejects blank', () {
      expect(encode(null)['conflict_justification'], isNull);
      expect(
        () => encode('   '),
        throwsA(
          group ? isA<GroupLocationCreateException>() : isA<ActivityCommandUnavailableException>(),
        ),
      );
    });
  }
}
