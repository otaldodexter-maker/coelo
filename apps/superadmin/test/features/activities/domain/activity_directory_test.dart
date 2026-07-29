import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the physical activity enum values', () {
    expect(ActivityStatus.values.map((value) => value.databaseValue), [
      'draft',
      'active',
      'inactive',
      'suspended',
      'archived',
    ]);
    expect(ActivityOrigin.values.map((value) => value.databaseValue), ['institution', 'unit']);
    expect(ActivityDistribution.values.map((value) => value.databaseValue), [
      'institution_standard',
      'unit_local',
    ]);
    expect(ActivityGovernance.values.map((value) => value.databaseValue), [
      'optional',
      'mandatory',
      'fixed',
    ]);
  });

  test('calculates pagination and reports active filters', () {
    final query = ActivityDirectoryQuery(
      search: 'música',
      institutionIds: {'institution-1'},
      statuses: {ActivityStatus.active},
      origins: {ActivityOrigin.unit},
      page: 2,
      pageSize: 11,
    );

    expect(query.offset, 22);
    expect(query.hasActiveFilters, isTrue);
    expect(ActivityDirectoryQuery.allowedPageSizes, [8, 11, 20, 50, 100]);
  });

  test('maps a directory row without exposing people', () {
    final item = ActivityDirectoryItem.fromJson({
      'id': 'activity-1',
      'institution_id': 'institution-1',
      'name': 'Música',
      'description': 'Aulas de música.',
      'status': 'active',
      'origin_scope_kind': 'unit',
      'distribution_scope': 'unit_local',
      'governance_kind': 'optional',
      'updated_at': '2026-07-29T12:00:00Z',
      'institutions': {'name': 'Casa Nuvem'},
      'activity_unit_links': [
        {'id': 'unit-link-1', 'status': 'active'},
      ],
      'activity_group_links': [
        {'id': 'group-link-1', 'status': 'active'},
        {'id': 'group-link-2', 'status': 'inactive'},
      ],
    });

    expect(item.institutionName, 'Casa Nuvem');
    expect(item.activeUnitCount, 1);
    expect(item.activeGroupCount, 1);
    expect(item.origin, ActivityOrigin.unit);
  });
}
