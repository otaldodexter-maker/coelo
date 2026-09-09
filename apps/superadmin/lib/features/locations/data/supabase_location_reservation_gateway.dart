import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/location_catalog_reader.dart';
import '../domain/location_reservation_gateway.dart';

typedef LocationReservationRpc = Future<Object?> Function(String name, Map<String, Object?> params);

/// Stateless transport for the six reservation operations.
final class SupabaseLocationReservationGateway implements LocationReservationGateway {
  SupabaseLocationReservationGateway(SupabaseClient client)
    : _rpc = ((name, params) => client.rpc<Object?>(name, params: params));

  const SupabaseLocationReservationGateway.withRpc(this._rpc);

  final LocationReservationRpc _rpc;

  @override
  bool get available => true;

  @override
  Future<LocationReservationAssessment> assess(LocationReservationDraft draft) async {
    _validateDraft(draft);
    final payload = _encodeDraft(draft);
    return _safe(() async {
      final data = _successData(
        await _rpc('superadmin_location_reservation_assess_v2', {'p_payload': payload}),
      );
      return decodeLocationReservationAssessmentV2(
        data,
        requestedLocationId: draft.locationId,
        requestedConsumer: draft.consumer,
      );
    });
  }

  @override
  Future<LocationReservation> create({
    required LocationReservationDraft draft,
    required String requestId,
  }) async {
    _validateDraft(draft);
    _validateId(requestId);
    final payload = _encodeDraft(draft);
    return _safe(() async {
      final data = _successData(
        await _rpc('superadmin_location_reservation_create_v2', {
          'p_payload': payload,
          'p_request_id': requestId,
        }),
      );
      return decodeLocationReservationV2(
        data,
        requestedLocationId: draft.locationId,
        requestedConsumer: draft.consumer,
      );
    });
  }

  @override
  Future<LocationReservation> cancel({
    required String locationId,
    required LocationReservationConsumer consumer,
    required String reservationId,
    required int expectedVersion,
    required String requestId,
  }) async {
    _validateId(locationId);
    _validateConsumer(consumer);
    _validateId(reservationId);
    _validateId(requestId);
    if (expectedVersion < 1) _rejected();
    return _safe(() async {
      final data = _successData(
        await _rpc('superadmin_location_reservation_cancel_v2', {
          'p_location_id': locationId,
          'p_payload': {
            'consumer': _encodeConsumer(consumer),
            'reservation_id': reservationId,
            'expected_version': expectedVersion,
          },
          'p_request_id': requestId,
        }),
      );
      final result = decodeLocationReservationV2(
        data,
        requestedLocationId: locationId,
        requestedConsumer: consumer,
      );
      if (result.id != _normalizedId(reservationId) ||
          result.state != LocationReservationState.cancelled ||
          result.managementVersion != expectedVersion + 1) {
        _invalid();
      }
      return result;
    });
  }

  @override
  Future<LocationReservationPage> listPaged({
    required String locationId,
    required LocationReservationConsumer consumer,
    String? afterId,
    int limit = 50,
  }) async {
    _validateId(locationId);
    _validateConsumer(consumer);
    if (afterId != null) _validateId(afterId);
    if (limit < 1 || limit > 100) _rejected();
    return _safe(() async {
      final data = _exactMap(
        _successData(
          await _rpc('superadmin_location_reservations_v2', {
            'p_location_id': locationId,
            'p_consumer': _encodeConsumer(consumer),
            'p_after_id': afterId,
            'p_limit': limit,
          }),
        ),
        const {'location_id', 'consumer', 'items', 'next_id'},
      );
      _correlateLocationAndConsumer(data, locationId, consumer);
      final rawItems = data['items'];
      if (rawItems is! List || rawItems.length > limit) _invalid();
      final items = rawItems
          .map(
            (raw) => decodeLocationReservationV2(
              raw,
              requestedLocationId: locationId,
              requestedConsumer: consumer,
            ),
          )
          .toList(growable: false);
      if (items.map((item) => item.id).toSet().length != items.length) _invalid();
      if (afterId != null && items.any((item) => item.id == _normalizedId(afterId))) _invalid();
      final rawNext = data['next_id'];
      final nextId = rawNext == null ? null : _wireId(rawNext);
      if (nextId != null && (items.length != limit || nextId != items.last.id)) _invalid();
      return LocationReservationPage(
        locationId: _normalizedId(locationId),
        consumer: LocationReservationConsumer(kind: consumer.kind, id: _normalizedId(consumer.id)),
        items: items,
        nextId: nextId,
      );
    });
  }

  @override
  Future<LocationSchedulingPolicyState> getPolicy({
    required String locationId,
    required LocationScope scope,
  }) async {
    _validateId(locationId);
    _validateScope(scope);
    return _safe(() async {
      final data = _successData(
        await _rpc('superadmin_location_scheduling_policy_v2', {'p_location_id': locationId}),
      );
      return _decodePolicy(data, scope: scope);
    });
  }

  @override
  Future<LocationSchedulingPolicyState> setPolicy({
    required String locationId,
    required LocationScope scope,
    required LocationSchedulingPolicy policy,
    required int expectedVersion,
    required String requestId,
  }) async {
    _validateId(locationId);
    _validateScope(scope);
    _validateId(requestId);
    if (expectedVersion < 0) _rejected();
    return _safe(() async {
      final data = _successData(
        await _rpc('superadmin_location_scheduling_policy_set_v2', {
          'p_location_id': locationId,
          'p_payload': {'policy': policy.name, 'expected_version': expectedVersion},
          'p_request_id': requestId,
        }),
      );
      final result = _decodePolicy(data, scope: scope);
      if (result.policy != policy || result.managementVersion != expectedVersion + 1) _invalid();
      return result;
    });
  }

  Map<String, Object?> _encodeDraft(LocationReservationDraft draft) {
    try {
      return encodeLocationReservationDraftV2(draft);
    } on Object {
      _rejected();
    }
  }

  Future<T> _safe<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on LocationReservationDeniedException {
      rethrow;
    } on LocationReservationRejectedException {
      rethrow;
    } on LocationReservationConflictException {
      rethrow;
    } on PostgrestException catch (error) {
      if (const {'42501', 'PGRST301', 'PGRST302'}.contains(error.code)) {
        throw const LocationReservationDeniedException();
      }
      throw const LocationReservationGatewayUnavailableException();
    } on Object {
      throw const LocationReservationGatewayUnavailableException();
    }
  }
}

LocationSchedulingPolicyState _decodePolicy(Object? raw, {required LocationScope scope}) {
  final data = _exactMap(raw, const {'scope_kind', 'owner_id', 'policy', 'management_version'});
  final expectedKind = scope is UnitLocationScope ? 'unit' : 'institution';
  final expectedOwner = switch (scope) {
    UnitLocationScope(:final unitId) => _normalizedId(unitId),
    InstitutionLocationScope(:final institutionId) => _normalizedId(institutionId),
  };
  if (data['scope_kind'] != expectedKind || _wireId(data['owner_id']) != expectedOwner) _invalid();
  final policy = switch (data['policy']) {
    null => null,
    'block' => LocationSchedulingPolicy.block,
    'warn' => LocationSchedulingPolicy.warn,
    _ => _invalid(),
  };
  final version = data['management_version'];
  if (version is! int || version < 0 || (policy == null) != (version == 0)) _invalid();
  return LocationSchedulingPolicyState(scope: scope, policy: policy, managementVersion: version);
}

Object? _successData(Object? raw) {
  final envelope = _exactMap(raw, const {'ok', 'data', 'error'});
  final ok = envelope['ok'];
  if (ok is! bool) _invalid();
  if (ok) {
    if (envelope['error'] != null) _invalid();
    return envelope['data'];
  }
  if (envelope['data'] != null) _invalid();
  final error = _exactMap(envelope['error'], const {
    'code',
    'message',
    'correlation_id',
    'http_status',
  });
  final code = error['code'];
  final status = error['http_status'];
  if (code is! String ||
      error['message'] is! String ||
      status is! int ||
      status < 400 ||
      status > 599) {
    _invalid();
  }
  _wireId(error['correlation_id']);
  switch (code) {
    case 'SAI_AUTH_REQUIRED':
    case 'SAI_SESSION_INVALID':
    case 'SAI_INTERNAL_CONTEXT_DENIED':
    case 'SAI_MEMBERSHIP_SUSPENDED':
    case 'SAI_MEMBERSHIP_REVOKED':
    case 'SAI_PERMISSION_DENIED':
    case 'SAI_MFA_REQUIRED':
      throw const LocationReservationDeniedException();
    case 'SAI_INVALID_ARGUMENT':
      throw const LocationReservationRejectedException();
    case 'SAI_CONCURRENT_CHANGE':
      throw const LocationReservationConflictException();
    default:
      throw const LocationReservationGatewayUnavailableException();
  }
}

void _validateDraft(LocationReservationDraft draft) {
  _validateId(draft.locationId);
  _validateConsumer(draft.consumer);
}

void _validateConsumer(LocationReservationConsumer consumer) {
  _validateId(consumer.id);
  if (consumer.kind != LocationReservationConsumerKind.group &&
      consumer.kind != LocationReservationConsumerKind.activity) {
    _rejected();
  }
}

void _validateScope(LocationScope scope) {
  if (!validLocationScope(scope)) _rejected();
}

void _validateId(String id) {
  if (!validLocationId(id)) _rejected();
}

Map<String, Object?> _encodeConsumer(LocationReservationConsumer consumer) => {
  'kind': consumer.kind.name,
  'id': _normalizedId(consumer.id),
};

void _correlateLocationAndConsumer(
  Map<String, Object?> data,
  String locationId,
  LocationReservationConsumer consumer,
) {
  if (_wireId(data['location_id']) != _normalizedId(locationId)) _invalid();
  final actual = _exactMap(data['consumer'], const {'kind', 'id'});
  if (actual['kind'] != consumer.kind.name || _wireId(actual['id']) != _normalizedId(consumer.id)) {
    _invalid();
  }
}

String _normalizedId(String id) => id.toLowerCase();

String _wireId(Object? raw) {
  if (raw is! String || !validLocationId(raw)) _invalid();
  return _normalizedId(raw);
}

Map<String, Object?> _exactMap(Object? raw, Set<String> keys) {
  if (raw is! Map ||
      raw.length != keys.length ||
      raw.keys.any((key) => key is! String || !keys.contains(key))) {
    _invalid();
  }
  return Map<String, Object?>.from(raw);
}

Never _rejected() => throw const LocationReservationRejectedException();
Never _invalid() => throw const FormatException('Invalid location reservation response');
