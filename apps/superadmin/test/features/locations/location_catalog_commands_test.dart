import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/data/supabase_location_catalog_writer.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

const _requestId = '40000000-0000-4000-8000-000000000001';

Map<String, Object?> _entryJson({
  String id = locationA,
  String scopeKind = 'institution',
  String institutionId = institutionA,
  String? unitId,
  String status = 'active',
  int version = 2,
}) => {
  'id': id,
  'scope_kind': scopeKind,
  'institution_id': institutionId,
  'unit_id': unitId,
  'name': 'Sala de leitura',
  'description': null,
  'kind': 'internal',
  'floor': null,
  'address': null,
  'visibility': 'team',
  'status': status,
  'management_version': version,
  'created_at': '2026-09-07T00:00:00Z',
  'updated_at': '2026-09-07T00:00:00Z',
};

Map<String, Object?> _ok(Object? data) => {'ok': true, 'data': data, 'error': null};

Map<String, Object?> _error(String code) => {
  'ok': false,
  'data': null,
  'error': {
    'code': code,
    'message': 'server detail that must not surface',
    'correlation_id': '50000000-0000-4000-8000-000000000001',
    'http_status': 403,
  },
};

Map<String, Object?> _scheduleJson({
  String id = locationA,
  int version = 3,
  List<Map<String, Object?>> windows = const [],
}) => {'location_id': id, 'management_version': version, 'windows': windows};

const _draft = LocationWriteDraft(
  scope: scopeA,
  kind: LocationKind.internal,
  name: 'Sala de leitura',
  visibility: LocationVisibility.team,
);

/// Records every call so a test can assert the name and the arguments the
/// adapter chose, which is the part of the contract the server cannot check for
/// the client.
final class _RecordingRpc {
  final names = <String>[];
  final params = <Map<String, Object?>>[];
  Object? response;
  Object? failure;

  Future<Object?> call(String name, Map<String, Object?> parameters) async {
    names.add(name);
    params.add(parameters);
    if (failure != null) throw failure!;
    return response;
  }
}

void main() {
  late _RecordingRpc rpc;
  late SupabaseLocationCatalogWriter writer;

  setUp(() {
    rpc = _RecordingRpc();
    writer = SupabaseLocationCatalogWriter.withRpc(rpc.call);
  });

  group('edit', () {
    test('calls the edit function with the version the actor was looking at', () async {
      rpc.response = _ok(_entryJson(version: 3));
      final entry = await writer.update(
        locationId: locationA,
        draft: _draft,
        expectedVersion: 2,
        requestId: _requestId,
      );
      expect(rpc.names.single, 'superadmin_location_update_v2');
      expect(rpc.params.single['p_location_id'], locationA);
      expect(rpc.params.single['p_expected_version'], 2);
      expect(rpc.params.single['p_request_id'], _requestId);
      expect(entry.managementVersion, 3);
    });

    test('a version that cannot exist is refused without a round trip', () async {
      await expectLater(
        writer.update(
          locationId: locationA,
          draft: _draft,
          expectedVersion: 0,
          requestId: _requestId,
        ),
        throwsA(isA<LocationWriteRejectedException>()),
      );
      expect(rpc.names, isEmpty);
    });

    test('a malformed id is refused without a round trip', () async {
      await expectLater(
        writer.update(
          locationId: 'nao-e-uuid',
          draft: _draft,
          expectedVersion: 1,
          requestId: _requestId,
        ),
        throwsA(isA<LocationWriteRejectedException>()),
      );
      expect(rpc.names, isEmpty);
    });

    test('a stale version comes back as a conflict, not as a failure', () async {
      rpc.response = _error('SAI_CONCURRENT_CHANGE');
      await expectLater(
        writer.update(
          locationId: locationA,
          draft: _draft,
          expectedVersion: 2,
          requestId: _requestId,
        ),
        throwsA(isA<LocationWriteConflictException>()),
      );
    });
  });

  group('status', () {
    test('archiving calls the status function with the encoded state', () async {
      rpc.response = _ok(_entryJson(status: 'archived', version: 3));
      final entry = await writer.setStatus(
        locationId: locationA,
        status: LocationCatalogStatus.archived,
        expectedVersion: 2,
        requestId: _requestId,
      );
      expect(rpc.names.single, 'superadmin_location_set_status_v2');
      expect(rpc.params.single['p_status'], 'archived');
      expect(entry.status, LocationCatalogStatus.archived);
    });

    test('a state a place cannot be in never reaches the server', () async {
      await expectLater(
        writer.setStatus(
          locationId: locationA,
          status: LocationCatalogStatus.draft,
          expectedVersion: 2,
          requestId: _requestId,
        ),
        throwsA(isA<LocationWriteRejectedException>()),
      );
      expect(rpc.names, isEmpty);
    });
  });

  group('copy', () {
    test('calls the copy function with the target and the new name', () async {
      rpc.response = _ok(_entryJson(id: locationB, scopeKind: 'unit', unitId: unitA, version: 1));
      final entry = await writer.copy(
        sourceId: locationA,
        sourceInstitutionId: institutionA,
        targetScope: scopeUnitA,
        name: 'Sala nova',
        requestId: _requestId,
      );
      expect(rpc.names.single, 'superadmin_location_copy_v2');
      expect(rpc.params.single, {
        'p_source_location_id': locationA,
        'p_scope_kind': 'unit',
        'p_institution_id': institutionA,
        'p_unit_id': unitA,
        'p_name': 'Sala nova',
        'p_request_id': _requestId,
      });
      expect(entry.id, locationB);
    });

    test('crossing institutions never leaves the client', () async {
      await expectLater(
        writer.copy(
          sourceId: locationA,
          sourceInstitutionId: institutionA,
          targetScope: scopeB,
          name: 'Sala nova',
          requestId: _requestId,
        ),
        throwsA(isA<LocationWriteRejectedException>()),
      );
      expect(rpc.names, isEmpty);
    });
  });

  group('schedule', () {
    test('reading asks only for the location', () async {
      rpc.response = _ok(
        _scheduleJson(
          windows: const [
            {'weekday': 1, 'starts_minute': 480, 'ends_minute': 720},
          ],
        ),
      );
      final schedule = await writer.readSchedule(locationId: locationA);
      expect(rpc.names.single, 'superadmin_location_schedule_v2');
      expect(rpc.params.single, {'p_location_id': locationA});
      expect(schedule.windows.single.startsMinute, 480);
      expect(schedule.isPublished, isTrue);
    });

    test('publishing sends the week canonically ordered', () async {
      rpc.response = _ok(
        _scheduleJson(
          version: 4,
          windows: const [
            {'weekday': 1, 'starts_minute': 480, 'ends_minute': 720},
            {'weekday': 3, 'starts_minute': 480, 'ends_minute': 720},
          ],
        ),
      );
      final schedule = await writer.setSchedule(
        locationId: locationA,
        windows: [
          LocationScheduleWindow(weekday: 3, startsMinute: 480, endsMinute: 720),
          LocationScheduleWindow(weekday: 1, startsMinute: 480, endsMinute: 720),
        ],
        expectedVersion: 3,
        requestId: _requestId,
      );
      expect(rpc.names.single, 'superadmin_location_schedule_set_v2');
      expect(rpc.params.single['p_windows'], [
        {'weekday': 1, 'starts_minute': 480, 'ends_minute': 720},
        {'weekday': 3, 'starts_minute': 480, 'ends_minute': 720},
      ]);
      expect(schedule.managementVersion, 4);
    });

    test('an empty week is published, not skipped', () async {
      rpc.response = _ok(_scheduleJson(version: 4));
      final schedule = await writer.setSchedule(
        locationId: locationA,
        windows: const [],
        expectedVersion: 3,
        requestId: _requestId,
      );
      expect(rpc.params.single['p_windows'], isEmpty);
      expect(schedule.isPublished, isFalse);
    });

    test('overlapping windows never leave the client', () async {
      await expectLater(
        writer.setSchedule(
          locationId: locationA,
          windows: [
            LocationScheduleWindow(weekday: 1, startsMinute: 480, endsMinute: 600),
            LocationScheduleWindow(weekday: 1, startsMinute: 540, endsMinute: 660),
          ],
          expectedVersion: 3,
          requestId: _requestId,
        ),
        throwsA(isA<LocationWriteRejectedException>()),
      );
      expect(rpc.names, isEmpty);
    });
  });

  group('no command is the one that leaks', () {
    final calls = <String, Future<Object?> Function(SupabaseLocationCatalogWriter)>{
      'edit': (w) => w.update(
        locationId: locationA,
        draft: _draft,
        expectedVersion: 1,
        requestId: _requestId,
      ),
      'status': (w) => w.setStatus(
        locationId: locationA,
        status: LocationCatalogStatus.archived,
        expectedVersion: 1,
        requestId: _requestId,
      ),
      'copy': (w) => w.copy(
        sourceId: locationA,
        sourceInstitutionId: institutionA,
        targetScope: scopeUnitA,
        name: 'Sala nova',
        requestId: _requestId,
      ),
      'read schedule': (w) => w.readSchedule(locationId: locationA),
      'publish schedule': (w) => w.setSchedule(
        locationId: locationA,
        windows: const [],
        expectedVersion: 1,
        requestId: _requestId,
      ),
    };

    for (final entry in calls.entries) {
      test('${entry.key} hides whether the resource exists', () async {
        rpc.response = _error('SAI_PERMISSION_DENIED');
        await expectLater(entry.value(writer), throwsA(isA<LocationWriteDeniedException>()));
      });

      test('${entry.key} never carries a transport message outward', () async {
        rpc.failure = StateError('socket detail that must not surface');
        await expectLater(
          entry.value(writer),
          throwsA(isA<LocationCatalogWriteUnavailableException>()),
        );
      });

      test('${entry.key} refuses a response that is not the catalog contract', () async {
        rpc.response = _ok({'unexpected': true});
        await expectLater(
          entry.value(writer),
          throwsA(isA<LocationCatalogWriteUnavailableException>()),
        );
      });
    }

    test('the default writer refuses every command instead of pretending', () async {
      const unavailable = UnavailableLocationCatalogWriter();
      for (final call in <Future<Object?> Function()>[
        () => unavailable.update(
          locationId: locationA,
          draft: _draft,
          expectedVersion: 1,
          requestId: _requestId,
        ),
        () => unavailable.setStatus(
          locationId: locationA,
          status: LocationCatalogStatus.archived,
          expectedVersion: 1,
          requestId: _requestId,
        ),
        () => unavailable.copy(
          sourceId: locationA,
          sourceInstitutionId: institutionA,
          targetScope: scopeUnitA,
          name: 'Sala nova',
          requestId: _requestId,
        ),
        () => unavailable.readSchedule(locationId: locationA),
        () => unavailable.setSchedule(
          locationId: locationA,
          windows: const [],
          expectedVersion: 1,
          requestId: _requestId,
        ),
      ]) {
        await expectLater(call(), throwsA(isA<LocationCatalogWriteUnavailableException>()));
      }
    });
  });
}
