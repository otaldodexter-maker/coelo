import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/data/supabase_location_reservation_gateway.dart';
import 'package:coelo_superadmin/features/locations/domain/location_reservation_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _institutionId = '10000000-0000-4000-8000-000000000001';
const _otherInstitutionId = '10000000-0000-4000-8000-000000000002';
const _unitId = '20000000-0000-4000-8000-000000000001';
const _locationId = '30000000-0000-4000-8000-000000000001';
const _reservationId = '50000000-0000-4000-8000-000000000001';
const _requestId = '60000000-0000-4000-8000-000000000001';
const _consumer = LocationReservationConsumer(
  kind: LocationReservationConsumerKind.activity,
  id: '40000000-0000-4000-8000-000000000001',
);
const _scope = LocationScope.unit(institutionId: _institutionId, unitId: _unitId);

final _draft = LocationReservationDraft(
  locationId: _locationId,
  consumer: _consumer,
  firstOccurrence: LocationReservationOccurrence(
    startsAt: DateTime.utc(2026, 9, 10, 13),
    endsAt: DateTime.utc(2026, 9, 10, 14),
  ),
  recurrence: const LocationReservationRecurrence.once(),
);

Map<String, Object?> _ok(Object? data) => {'ok': true, 'data': data, 'error': null};

Map<String, Object?> _error(String code) => {
  'ok': false,
  'data': null,
  'error': {
    'code': code,
    'message': 'private server detail',
    'correlation_id': _requestId,
    'http_status': code == 'SAI_INVALID_ARGUMENT' ? 400 : 403,
  },
};

Map<String, Object?> _consumerJson({String id = '40000000-0000-4000-8000-000000000001'}) => {
  'kind': 'activity',
  'id': id,
};

Map<String, Object?> _reservation({String id = _reservationId, String locationId = _locationId}) =>
    {
      'id': id,
      'location_id': locationId,
      'consumer': _consumerJson(),
      'state': 'active',
      'recurrence': {'kind': 'once'},
      'occurrences': [
        {'starts_at': '2026-09-10T13:00:00Z', 'ends_at': '2026-09-10T14:00:00Z'},
      ],
      'management_version': 1,
      'confirmed_over_conflict': false,
    };

void main() {
  test('assess and create use nominal payloads and caller-owned request id', () async {
    final calls = <Map<String, Object?>>[];
    final gateway = SupabaseLocationReservationGateway.withRpc((name, params) async {
      calls.add({'name': name, ...params});
      if (name.endsWith('_assess_v2')) {
        return _ok({
          'location_id': _locationId,
          'consumer': _consumerJson(),
          'policy': 'warn',
          'conflict': 'none',
          'conflicting': <Object?>[],
        });
      }
      return _ok(_reservation());
    });

    expect(gateway.available, isTrue);
    expect((await gateway.assess(_draft)).conflict, LocationReservationConflict.none);
    expect((await gateway.create(draft: _draft, requestId: _requestId)).id, _reservationId);
    expect(calls[0]['name'], 'superadmin_location_reservation_assess_v2');
    expect(calls[0].keys.toSet(), {'name', 'p_payload'});
    expect((calls[0]['p_payload'] as Map)['location_id'], _locationId);
    expect(calls[1]['name'], 'superadmin_location_reservation_create_v2');
    expect(calls[1]['p_request_id'], _requestId);
    expect(calls[1].keys.toSet(), {'name', 'p_payload', 'p_request_id'});
  });

  test('cancel carries exact consumer, version and stable request id', () async {
    final gateway = SupabaseLocationReservationGateway.withRpc((name, params) async {
      expect(name, 'superadmin_location_reservation_cancel_v2');
      expect(params, {
        'p_location_id': _locationId,
        'p_payload': {
          'consumer': _consumerJson(),
          'reservation_id': _reservationId,
          'expected_version': 1,
        },
        'p_request_id': _requestId,
      });
      return _ok({..._reservation(), 'state': 'cancelled', 'management_version': 2});
    });

    final result = await gateway.cancel(
      locationId: _locationId,
      consumer: _consumer,
      reservationId: _reservationId,
      expectedVersion: 1,
      requestId: _requestId,
    );
    expect(result.state, LocationReservationState.cancelled);
    expect(result.managementVersion, 2);
  });

  test('list uses all four public arguments and validates page correlations', () async {
    var call = 0;
    final gateway = SupabaseLocationReservationGateway.withRpc((name, params) async {
      call++;
      expect(name, 'superadmin_location_reservations_v2');
      expect(
        params,
        call == 1
            ? {
                'p_location_id': _locationId,
                'p_consumer': _consumerJson(),
                'p_after_id': null,
                'p_limit': 50,
              }
            : {
                'p_location_id': _locationId,
                'p_consumer': _consumerJson(),
                'p_after_id': _reservationId,
                'p_limit': 100,
              },
      );
      return _ok({
        'location_id': _locationId,
        'consumer': _consumerJson(),
        'items': call == 1 ? [_reservation()] : <Object?>[],
        'next_id': null,
      });
    });

    final page = await gateway.listPaged(locationId: _locationId, consumer: _consumer);
    expect(page.items.single.id, _reservationId);
    expect(page.nextId, isNull);
    expect(
      (await gateway.listPaged(
        locationId: _locationId,
        consumer: _consumer,
        afterId: _reservationId,
        limit: 100,
      )).items,
      isEmpty,
    );
  });

  test('policy get preserves unset and set correlates scope, owner and policy', () async {
    var call = 0;
    final gateway = SupabaseLocationReservationGateway.withRpc((name, params) async {
      call++;
      if (call == 1) {
        expect(name, 'superadmin_location_scheduling_policy_v2');
        expect(params, {'p_location_id': _locationId});
        return _ok({
          'scope_kind': 'unit',
          'owner_id': _unitId,
          'policy': null,
          'management_version': 0,
        });
      }
      expect(name, 'superadmin_location_scheduling_policy_set_v2');
      expect(params, {
        'p_location_id': _locationId,
        'p_payload': {'policy': 'warn', 'expected_version': 0},
        'p_request_id': _requestId,
      });
      return _ok({
        'scope_kind': 'unit',
        'owner_id': _unitId,
        'policy': 'warn',
        'management_version': 1,
      });
    });

    final unset = await gateway.getPolicy(locationId: _locationId, scope: _scope);
    expect(unset.policy, isNull);
    expect(unset.managementVersion, 0);
    final set = await gateway.setPolicy(
      locationId: _locationId,
      scope: _scope,
      policy: LocationSchedulingPolicy.warn,
      expectedVersion: 0,
      requestId: _requestId,
    );
    expect(set.policy, LocationSchedulingPolicy.warn);
    expect(set.managementVersion, 1);
  });

  test('invalid consumer scope, ids, cursor and limit never invoke transport', () async {
    var calls = 0;
    final gateway = SupabaseLocationReservationGateway.withRpc((_, _) async {
      calls++;
      return _ok(_reservation());
    });
    const form = LocationReservationConsumer(
      kind: LocationReservationConsumerKind.form,
      id: '40000000-0000-4000-8000-000000000001',
    );

    await expectLater(
      gateway.listPaged(locationId: _locationId, consumer: form),
      throwsA(isA<LocationReservationRejectedException>()),
    );
    await expectLater(
      gateway.listPaged(locationId: _locationId, consumer: _consumer, afterId: 'bad'),
      throwsA(isA<LocationReservationRejectedException>()),
    );
    await expectLater(
      gateway.listPaged(locationId: _locationId, consumer: _consumer, limit: 101),
      throwsA(isA<LocationReservationRejectedException>()),
    );
    await expectLater(
      gateway.getPolicy(
        locationId: _locationId,
        scope: const LocationScope.unit(institutionId: _institutionId, unitId: 'bad'),
      ),
      throwsA(isA<LocationReservationRejectedException>()),
    );
    expect(calls, 0);
  });

  test('error envelopes stay typed while malformed and mismatched data are unavailable', () async {
    Future<void> expectCode(String code, Matcher matcher) async {
      final gateway = SupabaseLocationReservationGateway.withRpc((_, _) async => _error(code));
      await expectLater(gateway.assess(_draft), throwsA(matcher));
    }

    await expectCode('SAI_MEMBERSHIP_REVOKED', isA<LocationReservationDeniedException>());
    await expectCode('SAI_INVALID_ARGUMENT', isA<LocationReservationRejectedException>());
    await expectCode('SAI_CONCURRENT_CHANGE', isA<LocationReservationConflictException>());
    await expectCode('SAI_INTERNAL_ERROR', isA<LocationReservationGatewayUnavailableException>());

    final wrongOwner = SupabaseLocationReservationGateway.withRpc(
      (_, _) async => _ok({
        'scope_kind': 'institution',
        'owner_id': _otherInstitutionId,
        'policy': null,
        'management_version': 0,
      }),
    );
    await expectLater(
      wrongOwner.getPolicy(
        locationId: _locationId,
        scope: const LocationScope.institution(institutionId: _institutionId),
      ),
      throwsA(isA<LocationReservationGatewayUnavailableException>()),
    );

    final badPage = SupabaseLocationReservationGateway.withRpc(
      (_, _) async => _ok({
        'location_id': _locationId,
        'consumer': _consumerJson(),
        'items': [_reservation()],
        'next_id': '70000000-0000-4000-8000-000000000001',
      }),
    );
    await expectLater(
      badPage.listPaged(locationId: _locationId, consumer: _consumer),
      throwsA(isA<LocationReservationGatewayUnavailableException>()),
    );

    final rawFailure = SupabaseLocationReservationGateway.withRpc(
      (_, _) async => throw const PostgrestException(message: 'private SQL', code: 'XX000'),
    );
    await expectLater(
      rawFailure.assess(_draft),
      throwsA(isA<LocationReservationGatewayUnavailableException>()),
    );
  });
}
