import 'package:coelo_superadmin/features/units/domain/unit_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports active filters and calculates the selected page-size offset', () {
    final query = UnitDirectoryQuery(
      search: 'Centro',
      institutionIds: {'institution'},
      page: 2,
      pageSize: 11,
    );

    expect(query.hasActiveFilters, isTrue);
    expect(query.offset, 22);
    expect(UnitDirectoryQuery.allowedPageSizes, containsAll([8, 11, 20, 50, 100]));
  });

  test('unit status exposes only values supported by record_status', () {
    expect(UnitStatus.values.map((status) => status.databaseValue), [
      'draft',
      'active',
      'inactive',
      'suspended',
      'archived',
    ]);
  });

  test('keeps institution and unit type filters independent', () {
    final query = UnitDirectoryQuery(institutionTypeIds: {'school'}, typeIds: {'campus'});

    expect(query.institutionTypeIds, {'school'});
    expect(query.unitTypeIds, {'campus'});
    expect(query.typeIds, same(query.unitTypeIds));
    expect(query.hasActiveFilters, isTrue);

    final explicitUnitTypes = UnitDirectoryQuery(unitTypeIds: {'support'});
    expect(explicitUnitTypes.institutionTypeIds, isEmpty);
    expect(explicitUnitTypes.typeIds, {'support'});
    expect(explicitUnitTypes.hasActiveFilters, isTrue);
  });
}
