import 'package:coelo_domain/locations.dart';
import 'package:test/test.dart';

void main() {
  test('catalog model copies address independently of the caller', () {
    final address = <String, String?>{'country': 'Brasil', 'city': null};
    final entry = LocationCatalogEntry(
      id: 'fixture',
      scope: const LocationScope.institution(institutionId: 'owner'),
      kind: LocationKind.internal,
      name: 'Sala',
      description: null,
      floor: null,
      address: address,
      visibility: LocationVisibility.team,
      status: LocationCatalogStatus.active,
      managementVersion: 1,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    address.clear();
    expect(entry.address, {'country': 'Brasil', 'city': null});
    expect(() => entry.address!.clear(), throwsUnsupportedError);
    final source = [entry];
    final result = LocationDirectoryResult(items: source, totalCount: 1);
    source.clear();
    expect(result.items, [entry]);
    expect(() => result.items.add(entry), throwsUnsupportedError);
  });
}
