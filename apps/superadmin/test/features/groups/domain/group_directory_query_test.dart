import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates offsets and reports active filters', () {
    final query = GroupDirectoryQuery(
      search: 'Girassol',
      institutionIds: {'institution'},
      unitIds: {'unit'},
      typeIds: {'class'},
      statuses: {GroupStatus.active},
      page: 2,
      pageSize: 11,
    );

    expect(query.offset, 22);
    expect(query.hasActiveFilters, isTrue);
    expect(GroupDirectoryQuery.allowedPageSizes, [8, 11, 20, 50, 100]);
  });

  test('presents the physical class type as Turma', () {
    expect(GroupRecord.groupTypeLabelFor('class'), 'Turma');
    expect(GroupRecord.groupTypeLabelFor('Oficina'), 'Oficina');
  });

  test('group statuses match record_status values', () {
    expect(GroupStatus.values.skip(1).map((status) => status.databaseValue), [
      'draft',
      'active',
      'inactive',
      'suspended',
      'archived',
    ]);
  });
}
