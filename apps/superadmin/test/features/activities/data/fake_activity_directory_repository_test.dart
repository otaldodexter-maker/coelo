import '../../../support/activities/fake_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('searches name and description and applies real filters', () async {
    final repository = FakeActivityDirectoryRepository();

    final byDescription = await repository.fetchPage(
      ActivityDirectoryQuery(search: 'expressão corporal'),
    );
    final filtered = await repository.fetchPage(
      ActivityDirectoryQuery(
        institutionIds: {'institution-1'},
        statuses: {ActivityStatus.active},
        origins: {ActivityOrigin.institution},
      ),
    );

    expect(byDescription.items, hasLength(1));
    expect(byDescription.items.single.name, 'Dança');
    expect(
      filtered.items.every(
        (item) =>
            item.institutionId == 'institution-1' &&
            item.status == ActivityStatus.active &&
            item.origin == ActivityOrigin.institution,
      ),
      isTrue,
    );
  });

  test('paginates with stable name ordering and loads a minimized detail', () async {
    final repository = FakeActivityDirectoryRepository();
    final page = await repository.fetchPage(
      ActivityDirectoryQuery(pageSize: 8, sortAscending: false),
    );
    final detail = await repository.fetchById('activity-1');

    expect(page.items, hasLength(8));
    expect(page.items.first.name.compareTo(page.items.last.name), greaterThanOrEqualTo(0));
    expect(detail, isNotNull);
    expect(detail!.groups.first.assigneeCount, greaterThanOrEqualTo(0));
    expect(detail.groups.first.participantCount, greaterThanOrEqualTo(0));
  });

  test('returns institutions as filter options', () async {
    final repository = FakeActivityDirectoryRepository();
    final options = await repository.fetchFilterOptions();

    expect(options.institutions, isNotEmpty);
    expect(
      options.institutions.map((option) => option.label),
      orderedEquals(['Casa Nuvem', 'Centro Bem-Te-Vi', 'Colégio Maré Alta']),
    );
  });

  test('returns institutions and active units for the visual form prototype', () async {
    final repository = FakeActivityDirectoryRepository();
    final options = await repository.fetchFormOptions(institutionId: 'institution-1');

    expect(options.institutions, isNotEmpty);
    expect(options.units, isNotEmpty);
    expect(
      options.unitsFor('institution-1').every((unit) => unit.institutionId == 'institution-1'),
      isTrue,
    );
  });
}
