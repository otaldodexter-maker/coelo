import 'package:coelo_superadmin/app/dev_menu/development_activity_fixture_repository.dart';
import 'package:coelo_superadmin/app/dev_menu/development_access_health_fixture_catalog.dart';
import 'package:coelo_superadmin/app/dev_menu/development_person_directory_repository.dart';
import 'package:coelo_superadmin/app/dev_menu/development_routine_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/daily_routine/domain/routine_contract.dart';
import 'package:coelo_superadmin/features/groups/data/fake_group_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
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

    expect(people.people, hasLength(462));
    expect(people.people.where((person) => person.type == PersonType.child), hasLength(180));
    expect(people.people.where((person) => person.isGuardian), hasLength(270));
    expect(
      people.people.where((person) => person.matchesSegment(PersonDirectorySegment.dualProfile)),
      hasLength(54),
    );
    expect(people.people.map((person) => person.id).toSet(), hasLength(people.people.length));

    final linkedGuardian = people.people.firstWhere(
      (person) => person.isGuardian && person.childContexts.isNotEmpty,
    );
    expect(linkedGuardian.linkedChildrenCount, linkedGuardian.childContexts.length);
    final guardianInstitutionIds = linkedGuardian.memberships
        .map((membership) => membership.institutionId)
        .toSet();
    expect(
      linkedGuardian.childContexts.every(
        (context) => guardianInstitutionIds.contains(context.institutionId),
      ),
      isTrue,
    );
    expect(
      linkedGuardian.childContexts.every(
        (context) => people.people.any(
          (person) => person.id == context.id && person.type == PersonType.child,
        ),
      ),
      isTrue,
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

  test('access and health fixture preserves approved scale and structural links', () {
    final data = DevelopmentAccessHealthFixtureCatalog.standard();

    expect(data.children, hasLength(180));
    expect(data.guardians, hasLength(270));
    expect(data.teamMembers, hasLength(42));
    expect(data.safetyRecords, hasLength(164));
    expect(
      data.safetyRecords.where((item) => item.status == DevelopmentSafetyStatus.authorized),
      hasLength(126),
    );
    expect(
      data.safetyRecords.where((item) => item.status == DevelopmentSafetyStatus.awaitingApproval),
      hasLength(18),
    );
    expect(
      data.safetyRecords.where((item) => item.status == DevelopmentSafetyStatus.attention),
      hasLength(11),
    );
    expect(
      data.safetyRecords.where((item) => item.status == DevelopmentSafetyStatus.noAuthorization),
      hasLength(9),
    );
    expect(
      data.children.every((child) => data.institutionIds.contains(child.institutionId)),
      isTrue,
    );
    expect(data.children.where((child) => child.guardianIds.length >= 3), hasLength(9));
    expect(data.guardians.where((guardian) => guardian.profileCodes.length > 1), hasLength(54));
  });
}
