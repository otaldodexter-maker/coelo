import 'package:coelo_superadmin/app/dev_menu/development_activity_fixture_repository.dart';
import 'package:coelo_superadmin/app/dev_menu/development_person_directory_repository.dart';
import 'package:coelo_superadmin/app/dev_menu/development_routine_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/daily_routine/domain/routine_contract.dart';
import 'package:coelo_superadmin/features/groups/data/fake_group_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('development dataset preserves the agreed realistic scale and hierarchy', () async {
    final institutions = FakeInstitutionDirectoryRepository();
    final groups = FakeGroupDirectoryRepository(institutions);
    final people = DevelopmentPersonDirectoryRepository();
    final activities = DevelopmentActivityFixtureRepository();
    final routines = DevelopmentRoutineRepository.content();

    expect(institutions.records.length, inInclusiveRange(8, 14));
    for (final institution in institutions.records) {
      expect(institution.units.length, inInclusiveRange(1, 4));
      for (final unit in institution.units) {
        expect(unit.groups.length, inInclusiveRange(1, 20));
        expect(
          groups.records.where((group) => group.unitId == unit.id),
          hasLength(unit.groups.length),
        );
      }
    }

    expect(people.people, hasLength(400));
    expect(people.people.where((person) => person.linkedChildrenCount > 1), isNotEmpty);
    expect(
      people.people.where(
        (person) =>
            person.memberships.any((membership) => membership.role == 'guardian') &&
            person.memberships.any((membership) => membership.role == 'educator'),
      ),
      isNotEmpty,
    );

    final activityPage = await activities.fetchPage(ActivityDirectoryQuery(pageSize: 100));
    final activityOptions = await activities.fetchFormOptions(
      institutionId: institutions.records.first.id,
    );
    expect(activityPage.totalCount, inInclusiveRange(1, 30));
    expect(activityPage.totalCount, 30);
    expect(activityOptions.templates, hasLength(10));

    final routinePage = await routines.fetchPage(
      const RoutineDirectoryQuery(kind: RoutineEntryKind.model, pageSize: 20),
    );
    expect(routinePage.totalCount, 6);
  });
}
