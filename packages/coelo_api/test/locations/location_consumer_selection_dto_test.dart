import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:test/test.dart';

const consumerId = '10000000-0000-4000-8000-000000000001';
const locationId = '20000000-0000-4000-8000-000000000001';
const institutionId = '30000000-0000-4000-8000-000000000001';
const unitId = '40000000-0000-4000-8000-000000000001';
const group = LocationReservationConsumer(
  kind: LocationReservationConsumerKind.group,
  id: consumerId,
);
Map<String, Object?> location() => {
  'id': locationId,
  'scope_kind': 'institution',
  'institution_id': institutionId,
  'unit_id': null,
  'kind': 'external',
  'name': 'Biblioteca',
  'status': 'active',
};
Map<String, Object?> envelope(Object? data) => {'ok': true, 'data': data, 'error': null};
Map<String, Object?> data({String kind = 'group', Object? value = false}) => {
  '${kind}_id': consumerId,
  'location': value == false ? location() : value,
};

void main() {
  for (final kind in [
    LocationReservationConsumerKind.group,
    LocationReservationConsumerKind.activity,
  ]) {
    final consumer = LocationReservationConsumer(kind: kind, id: consumerId);
    test('${kind.name} current selection retains real catalog reference', () {
      final result = decodeLocationConsumerSelectionV2(
        envelope(data(kind: kind.name)),
        requestedConsumer: consumer,
      );
      expect(result.consumer, consumer);
      expect(result.location!.id, locationId);
      expect(result.location!.scope.institutionId, institutionId);
      expect(result.location!.kind, LocationKind.external);
      expect(result.status, LocationCatalogStatus.active);
    });
    test('${kind.name} authorized absence remains absence', () {
      final result = decodeLocationConsumerSelectionV2(
        envelope(data(kind: kind.name, value: null)),
        requestedConsumer: consumer,
      );
      expect(result.consumer, consumer);
      expect(result.location, isNull);
      expect(result.status, isNull);
    });
  }
  test('inactive unit reference is retained without granting selection or reservation', () {
    final result = decodeLocationConsumerSelectionV2(
      envelope(
        data(
          value: location()
            ..addAll({'scope_kind': 'unit', 'unit_id': unitId, 'status': 'inactive'}),
        ),
      ),
      requestedConsumer: group,
    );
    expect((result.location!.scope as UnitLocationScope).unitId, unitId);
    expect(result.status, LocationCatalogStatus.inactive);
  });
  for (final change in <String, void Function(Map<String, Object?>)>{
    'consumer mismatch': (d) => d['group_id'] = unitId,
    'missing location': (d) => d.remove('location'),
    'unexpected payload': (d) => d['items'] = [],
    'wrong consumer family': (d) {
      d.remove('group_id');
      d['activity_id'] = consumerId;
    },
    'bad consumer UUID': (d) => d['group_id'] = 'local-id',
  }.entries) {
    test('rejects ${change.key}', () {
      final value = data();
      change.value(value);
      expect(
        () => decodeLocationConsumerSelectionV2(envelope(value), requestedConsumer: group),
        throwsFormatException,
      );
    });
  }
  for (final change in <String, void Function(Map<String, Object?>)>{
    'unknown kind': (d) => d['kind'] = 'remote',
    'unknown status': (d) => d['status'] = 'deleted',
    'bad location UUID': (d) => d['id'] = 'local-id',
    'bad institution UUID': (d) => d['institution_id'] = 'local-id',
    'unit absent': (d) => d['scope_kind'] = 'unit',
    'institution with unit': (d) => d['unit_id'] = unitId,
    'unknown owner': (d) => d['scope_kind'] = 'tenant',
    'blank name': (d) => d['name'] = ' ',
    'oversize name': (d) => d['name'] = 'x' * 121,
    'extra field': (d) => d['reservation'] = {},
  }.entries) {
    test('rejects location ${change.key}', () {
      final value = location();
      change.value(value);
      expect(
        () => decodeLocationConsumerSelectionV2(
          envelope(data(value: value)),
          requestedConsumer: group,
        ),
        throwsFormatException,
      );
    });
  }
  test('historical binding envelope never becomes current selection', () {
    expect(
      () => decodeLocationConsumerSelectionV2(
        envelope({
          'consumer': {'kind': 'group', 'id': consumerId},
          'items': [
            {'location': location()},
          ],
          'next_location_id': null,
        }),
        requestedConsumer: group,
      ),
      throwsFormatException,
    );
  });
  test('authorized denial remains denial and unknown errors stay sanitized', () {
    Object negative(String code) => {
      'ok': false,
      'data': null,
      'error': {
        'code': code,
        'message': 'private detail',
        'correlation_id': consumerId,
        'http_status': 403,
      },
    };
    expect(
      () => decodeLocationConsumerSelectionV2(
        negative('SAI_PERMISSION_DENIED'),
        requestedConsumer: group,
      ),
      throwsA(isA<LocationReadDeniedException>()),
    );
    expect(
      () => decodeLocationConsumerSelectionV2(
        negative('SAI_INTERNAL_ERROR'),
        requestedConsumer: group,
      ),
      throwsFormatException,
    );
  });
}
