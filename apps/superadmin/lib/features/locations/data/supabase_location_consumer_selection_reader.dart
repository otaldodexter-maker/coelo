import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/location_catalog_reader.dart';
import '../domain/location_consumer_selection_reader.dart';
import 'supabase_location_catalog_reader.dart';

/// Stateless candidate getter. UI invalidates pending completions by context.
final class SupabaseLocationConsumerSelectionReader implements LocationConsumerSelectionReader {
  SupabaseLocationConsumerSelectionReader(SupabaseClient client, {this.available = false})
    : _rpc = ((name, params) => client.rpc<Object?>(name, params: params));
  const SupabaseLocationConsumerSelectionReader.withRpc(this._rpc, {this.available = false});
  final LocationReadRpc _rpc;
  @override
  final bool available;

  @override
  Future<LocationConsumerCurrentSelection> fetchSelection({
    required LocationReservationConsumer consumer,
  }) async {
    try {
      if (!available || !validLocationId(consumer.id)) {
        throw const LocationCatalogUnavailableException();
      }
      final (name, parameter) = switch (consumer.kind) {
        LocationReservationConsumerKind.group => (
          'superadmin_group_location_selection_v2',
          'p_group_id',
        ),
        LocationReservationConsumerKind.activity => (
          'superadmin_activity_location_selection_v2',
          'p_activity_id',
        ),
        _ => throw const LocationCatalogUnavailableException(),
      };
      return decodeLocationConsumerSelectionV2(
        await _rpc(name, {parameter: consumer.id}),
        requestedConsumer: consumer,
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
