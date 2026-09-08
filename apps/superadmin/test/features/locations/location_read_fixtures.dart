import 'dart:async';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';

const locationA = '10000000-0000-4000-8000-000000000001';
const locationB = '10000000-0000-4000-8000-000000000002';
const institutionA = '20000000-0000-4000-8000-000000000001';
const institutionB = '20000000-0000-4000-8000-000000000002';
const unitA = '30000000-0000-4000-8000-000000000001';
const scopeA = LocationScope.institution(institutionId: institutionA);
const scopeB = LocationScope.institution(institutionId: institutionB);
const scopeUnitA = LocationScope.unit(institutionId: institutionA, unitId: unitA);

LocationCatalogEntry locationFixture({
  String id = locationA,
  LocationScope scope = scopeA,
  String name = 'Sala de leitura',
  LocationKind kind = LocationKind.internal,
  LocationCatalogStatus status = LocationCatalogStatus.active,
  int managementVersion = 1,
  Map<String, String?>? address,
}) => LocationCatalogEntry(
  id: id,
  scope: scope,
  kind: kind,
  name: name,
  description: 'Espaço para atividades de leitura.',
  floor: 'Térreo',
  address:
      address ??
      (kind == LocationKind.external ? {'country': 'Brasil', 'city': 'Cidade exemplo'} : null),
  visibility: LocationVisibility.team,
  status: status,
  managementVersion: managementVersion,
  createdAt: DateTime.utc(2026, 9, 7),
  updatedAt: DateTime.utc(2026, 9, 7, 12),
);

LocationDirectoryResult locationPage({LocationScope scope = scopeA, int total = 1}) =>
    LocationDirectoryResult(
      items: [locationFixture(scope: scope)],
      totalCount: total,
    );

final class ControlledLocationReader implements LocationCatalogReader {
  final directories =
      <({LocationDirectoryRequest request, Completer<LocationDirectoryResult> result})>[];
  final details = <({String id, Completer<LocationCatalogEntry> result})>[];

  @override
  Future<LocationDirectoryResult> fetchDirectory(LocationDirectoryRequest request) {
    final result = Completer<LocationDirectoryResult>();
    directories.add((request: request, result: result));
    return result.future;
  }

  @override
  Future<LocationCatalogEntry> fetchDetail(String id) {
    final result = Completer<LocationCatalogEntry>();
    details.add((id: id, result: result));
    return result.future;
  }
}
