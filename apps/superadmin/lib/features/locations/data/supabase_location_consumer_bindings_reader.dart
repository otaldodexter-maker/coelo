import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/location_catalog_reader.dart';
import '../domain/location_consumer_bindings_reader.dart';
import 'supabase_location_catalog_reader.dart';

/// Stateless reader; pending completions are invalidated by the consumer UI.
final class SupabaseLocationConsumerBindingsReader implements LocationConsumerBindingsReader {
  SupabaseLocationConsumerBindingsReader(SupabaseClient client)
    : _rpc = ((name, params) => client.rpc<Object?>(name, params: params));
  const SupabaseLocationConsumerBindingsReader.withRpc(this._rpc);
  final LocationReadRpc _rpc;

  @override
  Future<LocationConsumerBindingPage> fetchPage({
    required LocationReservationConsumer consumer,
    String? afterLocationId,
    int limit = 20,
  }) async {
    try {
      if (!validLocationId(consumer.id) ||
          !const {
            LocationReservationConsumerKind.group,
            LocationReservationConsumerKind.activity,
          }.contains(consumer.kind) ||
          afterLocationId != null && !validLocationId(afterLocationId) ||
          limit < 1 ||
          limit > 100) {
        throw const LocationCatalogUnavailableException();
      }
      final raw = await _rpc('superadmin_location_consumer_bindings_v2', {
        'p_consumer': {'kind': consumer.kind.name, 'id': consumer.id},
        'p_after_location_id': afterLocationId,
        'p_limit': limit,
      });
      return decodeLocationConsumerBindingsV2(
        raw,
        requestedConsumer: consumer,
        afterLocationId: afterLocationId,
        limit: limit,
      );
    } on LocationReadDeniedException {
      throw const LocationCatalogAccessDeniedException();
    } on PostgrestException catch (error) {
      if (const {'42501', 'PGRST301', 'PGRST302'}.contains(error.code)) {
        throw const LocationCatalogAccessDeniedException();
      }
      throw const LocationCatalogUnavailableException();
    } on Object {
      throw const LocationCatalogUnavailableException();
    }
  }
}
