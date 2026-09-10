import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/group_location_create.dart';

final class SupabaseGroupLocationCreateRepository implements GroupLocationCreateRepository {
  const SupabaseGroupLocationCreateRepository(this._client, {this.available = false});
  final SupabaseClient _client;
  @override
  final bool available;

  @override
  Future<GroupLocationCreateResult> create(GroupLocationCreateCommand command) async {
    if (!available) _fail(GroupLocationCreateFailure.unavailable);
    try {
      final requestId = _id(command.requestId, input: true);
      final institutionId = _id(command.institutionId, input: true);
      final unitId = _id(command.unitId, input: true);
      final snapshot = command.locationSelection.snapshot;
      final locationId = _id(snapshot.id, input: true);
      if (_id(snapshot.scope.institutionId, input: true) != institutionId ||
          command.name.trim().isEmpty ||
          command.groupType.trim().isEmpty ||
          (command.groupType.trim().toLowerCase() == 'other' &&
              (command.groupTypeOtherText?.trim().isEmpty ?? true))) {
        _fail(GroupLocationCreateFailure.invalidInput);
      }
      if (snapshot.scope case UnitLocationScope(unitId: final ownerUnit)) {
        if (_id(ownerUnit, input: true) != unitId) _fail(GroupLocationCreateFailure.invalidInput);
      }
      final envelope = _map(
        await _client.rpc<Object?>(
          'superadmin_group_location_create_v2',
          params: {
            'p_request_id': requestId,
            'p_location_id': locationId,
            'p_group_payload': {
              'institution_id': institutionId,
              'unit_id': unitId,
              'name': command.name.trim(),
              'group_type': command.groupType.trim().toLowerCase(),
              'group_type_other_text': _optionalText(command.groupTypeOtherText),
            },
            'p_reservation': command.reservation?.toJson(),
          },
        ),
        const {'ok', 'data', 'error'},
      );
      if (envelope['ok'] is! bool) _fail(GroupLocationCreateFailure.unavailable);
      if (envelope['ok'] == false) {
        if (envelope['data'] != null) _fail(GroupLocationCreateFailure.unavailable);
        final error = _map(envelope['error'], const {
          'code',
          'message',
          'correlation_id',
          'http_status',
        });
        final status = error['http_status'];
        if (error['code'] is! String ||
            (error['code'] as String).trim().isEmpty ||
            error['message'] is! String ||
            status is! int ||
            status < 400 ||
            status > 599) {
          _fail(GroupLocationCreateFailure.unavailable);
        }
        _id(error['correlation_id']);
        _fail(switch (error['code']) {
          'SAI_AUTH_REQUIRED' ||
          'SAI_SESSION_INVALID' ||
          'SAI_INTERNAL_CONTEXT_DENIED' ||
          'SAI_MEMBERSHIP_REVOKED' ||
          'SAI_MEMBERSHIP_SUSPENDED' ||
          'SAI_PERMISSION_DENIED' ||
          'SAI_MFA_REQUIRED' => GroupLocationCreateFailure.denied,
          'SAI_CONCURRENT_CHANGE' => GroupLocationCreateFailure.conflict,
          'SAI_INVALID_ARGUMENT' => GroupLocationCreateFailure.invalidInput,
          _ => GroupLocationCreateFailure.unavailable,
        });
      }
      if (envelope['error'] != null) _fail(GroupLocationCreateFailure.unavailable);
      final data = _map(envelope['data'], const {
        'group_id',
        'location_id',
        'status',
        'management_version',
        'correlation_id',
        'replayed',
        'reservation',
      });
      final groupId = _id(data['group_id']);
      _id(data['correlation_id']);
      final version = data['management_version'];
      if (_id(data['location_id']) != locationId ||
          data['status'] != 'draft' ||
          data['replayed'] is! bool ||
          version is! int ||
          version < 1 ||
          version > 9007199254740991 ||
          (command.reservation == null) != (data['reservation'] == null)) {
        _fail(GroupLocationCreateFailure.unavailable);
      }
      final reservation = data['reservation'] == null
          ? null
          : decodeLocationReservationV2(
              data['reservation'],
              requestedLocationId: locationId,
              requestedConsumer: LocationReservationConsumer(
                kind: LocationReservationConsumerKind.group,
                id: groupId,
              ),
            );
      if (reservation != null &&
          (reservation.state != LocationReservationState.active ||
              reservation.managementVersion > 9007199254740991)) {
        _fail(GroupLocationCreateFailure.unavailable);
      }
      if (reservation != null) {
        final intent = command.reservation!;
        requireLocationReservationIntentV2(
          reservation,
          firstOccurrence: intent.firstOccurrence,
          recurrence: intent.recurrence,
          conflictJustification: intent.conflictJustification,
        );
      }
      return GroupLocationCreateResult(
        groupId: groupId,
        managementVersion: version,
        status: 'draft',
        locationId: locationId,
        reservation: reservation,
      );
    } on GroupLocationCreateException {
      rethrow;
    } on PostgrestException catch (error) {
      _fail(switch (error.code) {
        '42501' || 'PGRST301' || 'PGRST302' => GroupLocationCreateFailure.denied,
        '40001' => GroupLocationCreateFailure.conflict,
        _ => GroupLocationCreateFailure.unavailable,
      });
    } on Object {
      _fail(GroupLocationCreateFailure.unavailable);
    }
  }
}

String? _optionalText(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
String _id(Object? value, {bool input = false}) {
  if (value is! String ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(value)) {
    _fail(input ? GroupLocationCreateFailure.invalidInput : GroupLocationCreateFailure.unavailable);
  }
  return value.toLowerCase();
}

Map<String, dynamic> _map(Object? value, Set<String> keys) {
  if (value is! Map || value.length != keys.length || !keys.every(value.containsKey)) {
    _fail(GroupLocationCreateFailure.unavailable);
  }
  return Map<String, dynamic>.from(value);
}

Never _fail(GroupLocationCreateFailure failure) => throw GroupLocationCreateException(failure);
