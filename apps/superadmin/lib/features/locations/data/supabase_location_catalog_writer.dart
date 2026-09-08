import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/location_catalog_reader.dart';
import '../domain/location_catalog_writer.dart';

typedef LocationWriteRpc = Future<Object?> Function(String name, Map<String, Object?> params);

/// Stateless transport for the catalog create. Authorization stays server-side.
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
    } on PostgrestException catch (error) {
      if (const {'42501', 'PGRST301', 'PGRST302'}.contains(error.code)) {
        throw const LocationWriteDeniedException();
      }
      throw const LocationCatalogWriteUnavailableException();
    } on Object {
      // Do not retain server messages, SQL details or raw response payloads.
      throw const LocationCatalogWriteUnavailableException();
    }
  }
}
