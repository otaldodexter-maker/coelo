import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/data/supabase_location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/data/supabase_location_consumer_selection_reader.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/domain/location_consumer_selection_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const id = '10000000-0000-4000-8000-000000000001';
const group = LocationReservationConsumer(kind: LocationReservationConsumerKind.group, id: id);
Object result(String kind) => {
  'ok': true,
  'error': null,
  'data': {'${kind}_id': id, 'location': null},
};
void main() {
  test('closed default and unavailable reader perform zero RPCs', () async {
    var calls = 0;
    final reader = SupabaseLocationConsumerSelectionReader.withRpc((_, _) async {
      ++calls;
      return result('group');
    });
    expect(reader.available, isFalse);
    await expectLater(
      reader.fetchSelection(consumer: group),
      throwsA(isA<LocationCatalogUnavailableException>()),
    );
    await expectLater(
      const UnavailableLocationConsumerSelectionReader().fetchSelection(consumer: group),
      throwsStateError,
    );
    expect(calls, 0);
  });
  for (final kind in [
    LocationReservationConsumerKind.group,
    LocationReservationConsumerKind.activity,
  ]) {
    test('${kind.name} candidate calls exact getter once with persisted consumer', () async {
      var calls = 0;
      final consumer = LocationReservationConsumer(kind: kind, id: id);
      final reader = SupabaseLocationConsumerSelectionReader.withRpc((name, params) async {
        ++calls;
        expect(name, 'superadmin_${kind.name}_location_selection_v2');
        expect(params, {'p_${kind.name}_id': id});
        return result(kind.name);
      }, available: true);
      final value = await reader.fetchSelection(consumer: consumer);
      expect(value.consumer, consumer);
      expect(value.location, isNull);
      expect(calls, 1);
    });
  }
  for (final consumer in [
    const LocationReservationConsumer(kind: LocationReservationConsumerKind.group, id: 'local-id'),
    const LocationReservationConsumer(kind: LocationReservationConsumerKind.event, id: id),
    const LocationReservationConsumer(kind: LocationReservationConsumerKind.form, id: id),
  ]) {
    test('invalid consumer ${consumer.kind.name}${consumer.id} makes no request', () async {
      var calls = 0;
      final reader = SupabaseLocationConsumerSelectionReader.withRpc((_, _) async {
        ++calls;
        return result('group');
      }, available: true);
      await expectLater(
        reader.fetchSelection(consumer: consumer),
        throwsA(isA<LocationCatalogUnavailableException>()),
      );
      expect(calls, 0);
    });
  }
  for (final code in ['42501', 'PGRST301', 'PGRST302']) {
    test('transport $code stays denied without fallback', () async {
      var calls = 0;
      final reader = SupabaseLocationConsumerSelectionReader.withRpc((_, _) async {
        ++calls;
        throw PostgrestException(message: 'private response', code: code);
      }, available: true);
      await expectLater(
        reader.fetchSelection(consumer: group),
        throwsA(isA<LocationCatalogAccessDeniedException>()),
      );
      expect(calls, 1);
    });
  }
  test('negative envelope stays denied', () async {
    final reader = SupabaseLocationConsumerSelectionReader.withRpc(
      (_, _) async => {
        'ok': false,
        'data': null,
        'error': {
          'code': 'SAI_PERMISSION_DENIED',
          'message': 'private',
          'http_status': 403,
          'correlation_id': id,
        },
      },
      available: true,
    );
    await expectLater(
      reader.fetchSelection(consumer: group),
      throwsA(isA<LocationCatalogAccessDeniedException>()),
    );
  });
  test('malformed response is unavailable', () async {
    final reader = SupabaseLocationConsumerSelectionReader.withRpc(
      (_, _) async => {},
      available: true,
    );
    await expectLater(
      reader.fetchSelection(consumer: group),
      throwsA(isA<LocationCatalogUnavailableException>()),
    );
  });
  test('unknown Object sanitized without fallback', () async {
    var calls = 0;
    final reader = SupabaseLocationConsumerSelectionReader.withRpc((_, _) async {
      ++calls;
      throw StateError('private exception');
    }, available: true);
    await expectLater(
      reader.fetchSelection(consumer: group),
      throwsA(isA<LocationCatalogUnavailableException>()),
    );
    expect(calls, 1);
  });
}
