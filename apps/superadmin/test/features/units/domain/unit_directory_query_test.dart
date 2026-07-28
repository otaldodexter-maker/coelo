import 'package:coelo_superadmin/features/units/domain/unit_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports active filters and calculates a twenty-item offset', () {
    final query = UnitDirectoryQuery(search: 'Centro', institutionIds: {'institution'}, page: 2);

    expect(query.hasActiveFilters, isTrue);
    expect(query.offset, 40);
    expect(UnitDirectoryQuery.pageSize, 20);
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
}
