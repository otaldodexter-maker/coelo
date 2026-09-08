import 'location_selection.dart';

/// Classification only; none of these values grants access to a reader.
enum LocationVisibility { team, guardians, students, all }

enum LocationCatalogStatus { draft, active, inactive, suspended, archived }

/// Read projection of the prepared catalog contract, not proof of access.
final class LocationCatalogEntry {
  LocationCatalogEntry({
    required this.id,
    required this.scope,
    required this.kind,
    required this.name,
    required this.description,
    required this.floor,
    required Map<String, String?>? address,
    required this.visibility,
    required this.status,
    required this.managementVersion,
    required this.createdAt,
    required this.updatedAt,
  }) : address = address == null ? null : Map.unmodifiable(address);

  final String id;
  final LocationScope scope;
  final LocationKind kind;
  final String name;
  final String? description;
  final String? floor;
  final Map<String, String?>? address;
  final LocationVisibility visibility;
  final LocationCatalogStatus status;
  final int managementVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class LocationDirectoryResult {
  LocationDirectoryResult({required List<LocationCatalogEntry> items, required this.totalCount})
    : items = List.unmodifiable(items);

  final List<LocationCatalogEntry> items;
  final int totalCount;
}
