import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/location_catalog_reader.dart';
import '../domain/location_map.dart';
import 'supabase_location_map_gateway.dart';

typedef LocationReadRpc = Future<Object?> Function(String name, Map<String, Object?> params);

final class LocationCatalogUnavailableException implements Exception {
  const LocationCatalogUnavailableException();
  @override
  String toString() => 'Location read unavailable';
}

/// Stateless transport adapter. Server authorization remains mandatory.
/// Controllers own session invalidation and discard obsolete completions.
final class SupabaseLocationCatalogReader implements LocationCatalogReader, LocationMapReader {
  SupabaseLocationCatalogReader(SupabaseClient client)
    : _rpc = ((name, params) => client.rpc<Object?>(name, params: params)),
      _mapGateway = SupabaseLocationMapGateway(client);

  const SupabaseLocationCatalogReader.withRpc(this._rpc) : _mapGateway = null;
  final LocationReadRpc _rpc;

  /// Mapa por imagem (spec 067); ausente no construtor de teste por RPC.
  final LocationMapReader? _mapGateway;

  @override
  Future<LocationMap> fetchMap(LocationScope scope) =>
      (_mapGateway ?? (throw const LocationMapUnavailableException())).fetchMap(scope);

  @override
  Future<LocationDirectoryResult> fetchDirectory(LocationDirectoryRequest request) =>
      _safe(() async {
        final search = request.search?.replaceAll(RegExp(r'^ +| +$'), '');
        if (!validLocationScope(request.scope) ||
            request.limit < 1 ||
            request.limit > 100 ||
            request.offset < 0 ||
            request.offset > 10000 ||
            search != null &&
                (search.runes.length > 120 ||
                    search.runes.any((rune) => rune >= 0xd800 && rune <= 0xdfff) ||
                    RegExp(r'[\x00-\x1f\x7f]').hasMatch(search))) {
          throw const LocationCatalogUnavailableException();
        }
        final response = await _rpc('superadmin_location_directory_v2', {
          'p_scope_kind': request.scope is UnitLocationScope ? 'unit' : 'institution',
          'p_institution_id': request.scope.institutionId,
          'p_unit_id': switch (request.scope) {
            UnitLocationScope(:final unitId) => unitId,
            InstitutionLocationScope() => null,
          },
          'p_search': search == null || search.isEmpty ? null : search,
          'p_limit': request.limit,
          'p_offset': request.offset,
        });
        final result = decodeLocationDirectoryV2(response, requestedScope: request.scope);
        if (result.items.length > request.limit) throw const LocationCatalogUnavailableException();
        return result;
      });

  @override
  Future<LocationCatalogEntry> fetchDetail(String id) => _safe(() async {
    if (!validLocationId(id)) throw const LocationCatalogUnavailableException();
    final response = await _rpc('superadmin_location_detail_v2', {'p_location_id': id});
    return decodeLocationDetailV2(response, requestedId: id);
  });

  Future<T> _safe<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on LocationReadDeniedException {
      throw const LocationCatalogAccessDeniedException();
    } on PostgrestException catch (error) {
      if (const {'42501', 'PGRST301', 'PGRST302'}.contains(error.code)) {
        throw const LocationCatalogAccessDeniedException();
      }
      throw const LocationCatalogUnavailableException();
    } on Object {
      // Do not retain server messages, SQL details or raw response payloads.
      throw const LocationCatalogUnavailableException();
    }
  }
}
