import 'package:coelo_domain/locations.dart';

enum LocationReadState { loading, ready, empty, noResults, denied, unavailable }

final class LocationDirectoryRequest {
  const LocationDirectoryRequest({
    required this.scope,
    this.search,
    this.limit = 11,
    this.offset = 0,
  });
  final LocationScope scope;
  final String? search;
  final int limit;
  final int offset;
}

/// Session availability is a render gate, never server authorization.
abstract interface class LocationCatalogReader {
  Future<LocationDirectoryResult> fetchDirectory(LocationDirectoryRequest request);
  Future<LocationCatalogEntry> fetchDetail(String id);
}

final class LocationCatalogAccessDeniedException implements Exception {
  const LocationCatalogAccessDeniedException();
}

final class UnavailableLocationCatalogReader implements LocationCatalogReader {
  const UnavailableLocationCatalogReader();
  @override
  Future<LocationDirectoryResult> fetchDirectory(LocationDirectoryRequest request) async =>
      throw StateError('Location reader unavailable');
  @override
  Future<LocationCatalogEntry> fetchDetail(String id) async =>
      throw StateError('Location reader unavailable');
}

bool sameLocationScope(LocationScope a, LocationScope b) =>
    a.runtimeType == b.runtimeType &&
    a.institutionId == b.institutionId &&
    (a is! UnitLocationScope || b is UnitLocationScope && a.unitId == b.unitId);

bool validLocationId(String id) =>
    RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(id);

bool validLocationScope(LocationScope scope) =>
    validLocationId(scope.institutionId) &&
    (scope is! UnitLocationScope || validLocationId(scope.unitId));
