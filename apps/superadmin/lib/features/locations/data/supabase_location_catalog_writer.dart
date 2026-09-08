import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/location_catalog_reader.dart';
import '../domain/location_catalog_writer.dart';

typedef LocationWriteRpc = Future<Object?> Function(String name, Map<String, Object?> params);

/// Stateless transport for the catalog commands. Authorization stays server-side.
///
/// The payload is built and validated before transport, and the answer is only
/// accepted when it belongs to the scope that was asked for. Server messages
/// and payloads are never retained.
final class SupabaseLocationCatalogWriter implements LocationCatalogWriter {
  SupabaseLocationCatalogWriter(SupabaseClient client)
    : _rpc = ((name, params) => client.rpc<Object?>(name, params: params));

  const SupabaseLocationCatalogWriter.withRpc(this._rpc);

  final LocationWriteRpc _rpc;

  @override
  Future<LocationCatalogEntry> create({
    required LocationWriteDraft draft,
    required String requestId,
  }) async {
    if (!validLocationScope(draft.scope) || !validLocationId(requestId)) {
      throw const LocationWriteRejectedException();
    }
    final payload = encodeLocationCreateV2(draft);
    try {
      final response = await _rpc('superadmin_location_create_v2', {
        'p_payload': payload,
        'p_request_id': requestId,
      });
      return decodeLocationCreateV2(response, requestedScope: draft.scope);
    } on LocationWriteDeniedException {
      rethrow;
    } on LocationWriteRejectedException {
      rethrow;
    } on LocationWriteConflictException {
      rethrow;
    } on Object catch (error) {
      throw _transportFailure(error);
    }
  }

  @override
  Future<LocationCatalogEntry> update({
    required String locationId,
    required LocationWriteDraft draft,
    required int expectedVersion,
    required String requestId,
  }) async {
    if (!validLocationScope(draft.scope) ||
        !validLocationId(locationId) ||
        !validLocationId(requestId) ||
        expectedVersion < 1) {
      throw const LocationWriteRejectedException();
    }
    final payload = encodeLocationUpdateV2(draft);
    try {
      final response = await _rpc('superadmin_location_update_v2', {
        'p_location_id': locationId,
        'p_payload': payload,
        'p_expected_version': expectedVersion,
        'p_request_id': requestId,
      });
      return decodeLocationUpdateV2(
        response,
        requestedId: locationId,
        expectedVersion: expectedVersion,
      );
    } on Object catch (error) {
      throw _transportFailure(error);
    }
  }

  @override
  Future<LocationCatalogEntry> setStatus({
    required String locationId,
    required LocationCatalogStatus status,
    required int expectedVersion,
    required String requestId,
  }) async {
    if (!validLocationId(locationId) || !validLocationId(requestId) || expectedVersion < 1) {
      throw const LocationWriteRejectedException();
    }
    final encoded = encodeLocationStatusV2(status);
    try {
      final response = await _rpc('superadmin_location_set_status_v2', {
        'p_location_id': locationId,
        'p_status': encoded,
        'p_expected_version': expectedVersion,
        'p_request_id': requestId,
      });
      return decodeLocationStatusV2(
        response,
        requestedId: locationId,
        requestedStatus: status,
        expectedVersion: expectedVersion,
      );
    } on Object catch (error) {
      throw _transportFailure(error);
    }
  }

  @override
  Future<LocationCatalogEntry> copy({
    required String sourceId,
    required String sourceInstitutionId,
    required LocationScope targetScope,
    required String name,
    required String requestId,
  }) async {
    if (!validLocationScope(targetScope) ||
        !validLocationId(sourceId) ||
        !validLocationId(requestId)) {
      throw const LocationWriteRejectedException();
    }
    final arguments = encodeLocationCopyV2(
      sourceId: sourceId,
      sourceInstitutionId: sourceInstitutionId,
      targetScope: targetScope,
      name: name,
    );
    try {
      final response = await _rpc('superadmin_location_copy_v2', {
        ...arguments,
        'p_request_id': requestId,
      });
      return decodeLocationCopyV2(response, sourceId: sourceId, targetScope: targetScope);
    } on Object catch (error) {
      throw _transportFailure(error);
    }
  }

  @override
  Future<LocationSchedule> readSchedule({required String locationId}) async {
    if (!validLocationId(locationId)) throw const LocationWriteRejectedException();
    try {
      final response = await _rpc('superadmin_location_schedule_v2', {
        'p_location_id': locationId,
      });
      return decodeLocationScheduleV2(response, requestedId: locationId);
    } on Object catch (error) {
      throw _transportFailure(error);
    }
  }

  @override
  Future<LocationSchedule> setSchedule({
    required String locationId,
    required List<LocationScheduleWindow> windows,
    required int expectedVersion,
    required String requestId,
  }) async {
    if (!validLocationId(locationId) || !validLocationId(requestId) || expectedVersion < 1) {
      throw const LocationWriteRejectedException();
    }
    final encoded = encodeLocationScheduleV2(windows);
    try {
      final response = await _rpc('superadmin_location_schedule_set_v2', {
        'p_location_id': locationId,
        'p_windows': encoded,
        'p_expected_version': expectedVersion,
        'p_request_id': requestId,
      });
      return decodeLocationScheduleV2(response, requestedId: locationId);
    } on Object catch (error) {
      throw _transportFailure(error);
    }
  }

  /// One translation for every command, so no command can be the one that
  /// leaks. A refusal the contract already named travels unchanged; anything
  /// else becomes unavailability without its message, its SQL or its payload.
  Object _transportFailure(Object error) {
    if (error is LocationWriteDeniedException ||
        error is LocationWriteRejectedException ||
        error is LocationWriteConflictException) {
      return error;
    }
    if (error is PostgrestException &&
        const {'42501', 'PGRST301', 'PGRST302'}.contains(error.code)) {
      return const LocationWriteDeniedException();
    }
    return const LocationCatalogWriteUnavailableException();
  }
}
