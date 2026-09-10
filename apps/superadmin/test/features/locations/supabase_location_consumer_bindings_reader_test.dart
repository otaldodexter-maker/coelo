import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/data/supabase_location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/data/supabase_location_consumer_bindings_reader.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const consumer = LocationReservationConsumer(
  kind: LocationReservationConsumerKind.group,
  id: '10000000-0000-4000-8000-000000000001',
);
const locationId = '20000000-0000-4000-8000-000000000001';
const institutionId = '30000000-0000-4000-8000-000000000001';

Map<String, Object?> response({List<Object?>? items, String? next}) => {
  'ok': true,
  'error': null,
  'data': {
    'consumer': {'kind': consumer.kind.name, 'id': consumer.id},
    'items': items ?? [reference()],
    'next_location_id': next,
  },
};
Map<String, Object?> reference({String id = locationId, String status = 'inactive'}) => {
  'location': {
    'id': id,
    'scope_kind': 'institution',
    'institution_id': institutionId,
    'unit_id': null,
    'kind': 'internal',
    'name': 'Sala anterior',
    'status': status,
  },
};

void main() {
  test('nominal reader sends real consumer and bounded cursor; keeps inactive history', () async {
    final reader = SupabaseLocationConsumerBindingsReader.withRpc((name, params) async {
      expect(name, 'superadmin_location_consumer_bindings_v2');
      expect(params, {
        'p_consumer': {'kind': 'group', 'id': consumer.id},
        'p_after_location_id': null,
        'p_limit': 1,
      });
      return response(next: locationId);
    });
    final page = await reader.fetchPage(consumer: consumer, limit: 1);
    expect(page.consumer, consumer);
    expect(page.items.single.location.id, locationId);
    expect(page.items.single.status, LocationCatalogStatus.inactive);
    expect(page.nextLocationId, locationId);
    expect(() => page.items.clear(), throwsUnsupportedError);
  });

  test('empty authorized history has no fabricated selection', () async {
    final reader = SupabaseLocationConsumerBindingsReader.withRpc(
      (_, _) async => response(items: []),
    );
    final page = await reader.fetchPage(consumer: consumer);
    expect(page.items, isEmpty);
    expect(page.nextLocationId, isNull);
  });

  for (final invalid in [
    'foreign consumer',
    'duplicate',
    'bad cursor',
    'mixed scope',
    'unknown status',
    'extra field',
    'unsorted',
    'backwards page',
  ]) {
    test('malformed history fails closed: $invalid', () async {
      final payload = response();
      final data = payload['data'] as Map<String, Object?>;
      switch (invalid) {
        case 'foreign consumer':
          data['consumer'] = {'kind': 'activity', 'id': consumer.id};
        case 'duplicate':
          data['items'] = [reference(), reference()];
        case 'bad cursor':
          data['next_location_id'] = consumer.id;
        case 'mixed scope':
          ((data['items'] as List).single as Map)['location']['unit_id'] = consumer.id;
        case 'unknown status':
          data['items'] = [reference(status: 'unknown')];
        case 'extra field':
          data['selected_location_id'] = locationId;
        case 'unsorted':
          data['items'] = [reference(id: institutionId), reference()];
        case 'backwards page':
          break;
      }
      final reader = SupabaseLocationConsumerBindingsReader.withRpc((_, _) async => payload);
      await expectLater(
        reader.fetchPage(
          consumer: consumer,
          afterLocationId: invalid == 'backwards page' ? locationId : null,
        ),
        throwsA(isA<LocationCatalogUnavailableException>()),
      );
    });
  }

  test('invalid consumer and page bounds do not reach transport', () async {
    var calls = 0;
    final reader = SupabaseLocationConsumerBindingsReader.withRpc((_, _) async {
      calls++;
      return response();
    });
    for (final limit in [0, 101]) {
      await expectLater(
        reader.fetchPage(consumer: consumer, limit: limit),
        throwsA(isA<LocationCatalogUnavailableException>()),
      );
    }
    await expectLater(
      reader.fetchPage(
        consumer: const LocationReservationConsumer(
          kind: LocationReservationConsumerKind.group,
          id: 'draft',
        ),
      ),
      throwsA(isA<LocationCatalogUnavailableException>()),
    );
    await expectLater(
      reader.fetchPage(
        consumer: LocationReservationConsumer(
          kind: LocationReservationConsumerKind.event,
          id: consumer.id,
        ),
      ),
      throwsA(isA<LocationCatalogUnavailableException>()),
    );
    expect(calls, 0);
  });

  for (final code in ['SAI_PERMISSION_DENIED', 'SAI_MEMBERSHIP_REVOKED', 'SAI_SESSION_INVALID']) {
    test('denial envelope is sanitized: $code', () async {
      final reader = SupabaseLocationConsumerBindingsReader.withRpc(
        (_, _) async => {
          'ok': false,
          'data': null,
          'error': {
            'code': code,
            'message': 'secret SQL detail',
            'correlation_id': locationId,
            'http_status': 403,
          },
        },
      );
      await expectLater(
        reader.fetchPage(consumer: consumer),
        throwsA(isA<LocationCatalogAccessDeniedException>()),
      );
    });
  }
  test('missing production RPC is unavailable, never fallback or raw error', () async {
    var calls = 0;
    final reader = SupabaseLocationConsumerBindingsReader.withRpc((_, _) async {
      calls++;
      throw const PostgrestException(message: 'private SQL detail', code: 'PGRST202');
    });
    await expectLater(
      reader.fetchPage(consumer: consumer),
      throwsA(isA<LocationCatalogUnavailableException>()),
    );
    expect(calls, 1);
  });
}
