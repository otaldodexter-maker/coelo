import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:test/test.dart';

const id = '10000000-0000-4000-8000-000000000001';
const otherId = '10000000-0000-4000-8000-0000000000ff';
const institutionId = '20000000-0000-4000-8000-000000000001';
const otherInstitutionId = '20000000-0000-4000-8000-0000000000ff';
const unitId = '30000000-0000-4000-8000-000000000001';

const institutionScope = LocationScope.institution(institutionId: institutionId);
const unitScope = LocationScope.unit(institutionId: institutionId, unitId: unitId);

Map<String, Object?> entryJson({
  String entryId = id,
  String status = 'active',
  int version = 2,
  String scopeKind = 'institution',
  String? unit,
  String entryInstitutionId = institutionId,
}) => {
  'id': entryId,
  'scope_kind': scopeKind,
  'institution_id': entryInstitutionId,
  'unit_id': unit,
  'name': 'Sala',
  'description': null,
  'kind': 'internal',
  'floor': null,
  'address': null,
  'visibility': 'team',
  'status': status,
  'management_version': version,
  'created_at': '2026-09-07T10:00:00+00:00',
  'updated_at': '2026-09-07T11:00:00+00:00',
};

Map<String, Object?> envelope(Object? data) => {'ok': true, 'data': data, 'error': null};

LocationWriteDraft draft({LocationScope scope = institutionScope, String name = 'Sala'}) =>
    LocationWriteDraft(
      scope: scope,
      kind: LocationKind.internal,
      name: name,
      visibility: LocationVisibility.team,
    );

void main() {
  group('edit', () {
    test('sends exactly what a create sends, because the server validates it the same way', () {
      expect(encodeLocationUpdateV2(draft()), encodeLocationCreateV2(draft()));
    });

    test('accepts an answer whose version moved', () {
      final entry = decodeLocationUpdateV2(
        envelope(entryJson(version: 3)),
        requestedId: id,
        expectedVersion: 2,
      );
      expect(entry.managementVersion, 3);
    });

    test('refuses an answer whose version did not move', () {
      // A server that echoed the old row would otherwise look like success
      // while nothing had been written.
      expect(
        () => decodeLocationUpdateV2(
          envelope(entryJson(version: 2)),
          requestedId: id,
          expectedVersion: 2,
        ),
        throwsFormatException,
      );
    });

    test('refuses an answer about another location', () {
      expect(
        () => decodeLocationUpdateV2(
          envelope(entryJson(entryId: otherId, version: 3)),
          requestedId: id,
          expectedVersion: 2,
        ),
        throwsFormatException,
      );
    });
  });

  group('status', () {
    test('encodes the three states a place can be put in', () {
      expect(encodeLocationStatusV2(LocationCatalogStatus.active), 'active');
      expect(encodeLocationStatusV2(LocationCatalogStatus.inactive), 'inactive');
      expect(encodeLocationStatusV2(LocationCatalogStatus.archived), 'archived');
    });

    for (final refused in [LocationCatalogStatus.draft, LocationCatalogStatus.suspended]) {
      test('refuses ${refused.name} without spending a round trip', () {
        expect(
          () => encodeLocationStatusV2(refused),
          throwsA(isA<LocationWriteRejectedException>()),
        );
      });
    }

    test('accepts an answer that landed on the asked status', () {
      final entry = decodeLocationStatusV2(
        envelope(entryJson(status: 'archived', version: 3)),
        requestedId: id,
        requestedStatus: LocationCatalogStatus.archived,
        expectedVersion: 2,
      );
      expect(entry.status, LocationCatalogStatus.archived);
    });

    test('refuses an answer that landed somewhere else', () {
      expect(
        () => decodeLocationStatusV2(
          envelope(entryJson(status: 'inactive', version: 3)),
          requestedId: id,
          requestedStatus: LocationCatalogStatus.archived,
          expectedVersion: 2,
        ),
        throwsFormatException,
      );
    });
  });

  group('copy', () {
    test('carries only where it is going and what it will be called', () {
      expect(
        encodeLocationCopyV2(
          sourceId: id,
          sourceInstitutionId: institutionId,
          targetScope: unitScope,
          name: '  Sala nova  ',
        ),
        {
          'p_source_location_id': id,
          'p_scope_kind': 'unit',
          'p_institution_id': institutionId,
          'p_unit_id': unitId,
          'p_name': 'Sala nova',
        },
      );
    });

    test('refuses crossing institutions before transport', () {
      expect(
        () => encodeLocationCopyV2(
          sourceId: id,
          sourceInstitutionId: otherInstitutionId,
          targetScope: unitScope,
          name: 'Sala nova',
        ),
        throwsA(isA<LocationWriteRejectedException>()),
      );
    });

    test('refuses a blank name', () {
      expect(
        () => encodeLocationCopyV2(
          sourceId: id,
          sourceInstitutionId: institutionId,
          targetScope: unitScope,
          name: '   ',
        ),
        throwsA(isA<LocationWriteRejectedException>()),
      );
    });

    test('accepts a new row at the target', () {
      final entry = decodeLocationCopyV2(
        envelope(entryJson(entryId: otherId, scopeKind: 'unit', unit: unitId)),
        sourceId: id,
        targetScope: unitScope,
      );
      expect(entry.id, otherId);
      expect((entry.scope as UnitLocationScope).unitId, unitId);
    });

    test('refuses an answer that is the source itself', () {
      expect(
        () => decodeLocationCopyV2(
          envelope(entryJson(scopeKind: 'unit', unit: unitId)),
          sourceId: id,
          targetScope: unitScope,
        ),
        throwsFormatException,
      );
    });

    test('refuses an answer that landed on another owner', () {
      expect(
        () => decodeLocationCopyV2(
          envelope(entryJson(entryId: otherId)),
          sourceId: id,
          targetScope: unitScope,
        ),
        throwsFormatException,
      );
    });
  });

  group('schedule', () {
    LocationScheduleWindow window(int weekday, int starts, int ends) =>
        LocationScheduleWindow(weekday: weekday, startsMinute: starts, endsMinute: ends);

    test('the domain refuses a window that is not a window', () {
      expect(() => window(7, 0, 60), throwsArgumentError);
      expect(() => window(-1, 0, 60), throwsArgumentError);
      expect(() => window(1, 600, 600), throwsArgumentError);
      expect(() => window(1, 0, 1441), throwsArgumentError);
      expect(() => window(1, 1440, 1440), throwsArgumentError);
    });

    test('midnight at the end of the day is a valid end', () {
      expect(window(1, 1380, 1440).endsMinute, 1440);
    });

    test('touching windows are not overlapping', () {
      expect(window(1, 480, 720).overlaps(window(1, 720, 900)), isFalse);
      expect(window(1, 480, 720).overlaps(window(2, 600, 660)), isFalse);
      expect(window(1, 480, 720).overlaps(window(1, 600, 900)), isTrue);
    });

    test('encodes canonically ordered, so equal weeks send equal bytes', () {
      final scrambled = encodeLocationScheduleV2([
        window(3, 480, 720),
        window(1, 780, 1020),
        window(1, 480, 720),
      ]);
      final ordered = encodeLocationScheduleV2([
        window(1, 480, 720),
        window(1, 780, 1020),
        window(3, 480, 720),
      ]);
      expect(scrambled, ordered);
      expect(scrambled.first, {'weekday': 1, 'starts_minute': 480, 'ends_minute': 720});
    });

    test('an empty week encodes as an empty week', () {
      expect(encodeLocationScheduleV2(const []), isEmpty);
    });

    test('refuses overlapping windows rather than merging them', () {
      expect(
        () => encodeLocationScheduleV2([window(1, 480, 600), window(1, 540, 660)]),
        throwsA(isA<LocationWriteRejectedException>()),
      );
    });

    test('refuses a week longer than the catalog accepts', () {
      expect(
        () => encodeLocationScheduleV2([
          for (var index = 0; index < 71; index++) window(index % 7, index * 2, index * 2 + 1),
        ]),
        throwsA(isA<LocationWriteRejectedException>()),
      );
    });

    test('decodes a published week', () {
      final schedule = decodeLocationScheduleV2(
        envelope({
          'location_id': id,
          'management_version': 4,
          'windows': [
            {'weekday': 1, 'starts_minute': 480, 'ends_minute': 720},
            {'weekday': 3, 'starts_minute': 480, 'ends_minute': 720},
          ],
        }),
        requestedId: id,
      );
      expect(schedule.managementVersion, 4);
      expect(schedule.windows.length, 2);
      expect(schedule.isPublished, isTrue);
    });

    test('an empty week decodes as nothing published, not as always open', () {
      final schedule = decodeLocationScheduleV2(
        envelope({'location_id': id, 'management_version': 1, 'windows': const []}),
        requestedId: id,
      );
      expect(schedule.windows, isEmpty);
      expect(schedule.isPublished, isFalse);
    });

    test('refuses a week about another location', () {
      expect(
        () => decodeLocationScheduleV2(
          envelope({'location_id': otherId, 'management_version': 1, 'windows': const []}),
          requestedId: id,
        ),
        throwsFormatException,
      );
    });

    test('refuses a server week that arrives out of order', () {
      // The catalog promises ordered, non-overlapping windows. Catching a broken
      // promise here beats rendering a schedule that is quietly wrong.
      expect(
        () => decodeLocationScheduleV2(
          envelope({
            'location_id': id,
            'management_version': 1,
            'windows': [
              {'weekday': 3, 'starts_minute': 480, 'ends_minute': 720},
              {'weekday': 1, 'starts_minute': 480, 'ends_minute': 720},
            ],
          }),
          requestedId: id,
        ),
        throwsFormatException,
      );
    });

    test('refuses a server week that overlaps itself', () {
      expect(
        () => decodeLocationScheduleV2(
          envelope({
            'location_id': id,
            'management_version': 1,
            'windows': [
              {'weekday': 1, 'starts_minute': 480, 'ends_minute': 720},
              {'weekday': 1, 'starts_minute': 600, 'ends_minute': 900},
            ],
          }),
          requestedId: id,
        ),
        throwsFormatException,
      );
    });

    test('refuses a server window the domain would not hold', () {
      expect(
        () => decodeLocationScheduleV2(
          envelope({
            'location_id': id,
            'management_version': 1,
            'windows': [
              {'weekday': 9, 'starts_minute': 480, 'ends_minute': 720},
            ],
          }),
          requestedId: id,
        ),
        throwsFormatException,
      );
    });
  });

  group('every command maps the same refusals', () {
    Object? denial(String code) => {
      'ok': false,
      'data': null,
      'error': {
        'code': code,
        'message': 'denied',
        'correlation_id': '90000000-0000-4000-8000-000000000001',
        'http_status': 403,
      },
    };

    final commands = <String, void Function(Object?)>{
      'edit': (value) =>
          decodeLocationUpdateV2(value, requestedId: id, expectedVersion: 1),
      'status': (value) => decodeLocationStatusV2(
        value,
        requestedId: id,
        requestedStatus: LocationCatalogStatus.archived,
        expectedVersion: 1,
      ),
      'copy': (value) => decodeLocationCopyV2(value, sourceId: id, targetScope: unitScope),
      'schedule': (value) => decodeLocationScheduleV2(value, requestedId: id),
    };

    for (final entry in commands.entries) {
      test('${entry.key} hides whether the resource exists', () {
        expect(
          () => entry.value(denial('SAI_PERMISSION_DENIED')),
          throwsA(isA<LocationWriteDeniedException>()),
        );
      });
      test('${entry.key} separates a rejection from a conflict', () {
        expect(
          () => entry.value(denial('SAI_INVALID_ARGUMENT')),
          throwsA(isA<LocationWriteRejectedException>()),
        );
        expect(
          () => entry.value(denial('SAI_CONCURRENT_CHANGE')),
          throwsA(isA<LocationWriteConflictException>()),
        );
      });
    }
  });
}
