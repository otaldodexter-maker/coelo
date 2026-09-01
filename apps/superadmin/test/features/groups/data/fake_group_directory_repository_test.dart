import 'package:coelo_superadmin/features/groups/data/fake_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes local groups for known institution units', () {
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeGroupDirectoryRepository(institutions);

    expect(repository.records, isNotEmpty);
    expect(
      repository.records.every(
        (record) =>
            institutions
                .findById(record.institutionId)
                ?.units
                .any((unit) => unit.id == record.unitId) ??
            false,
      ),
      isTrue,
    );
    expect(repository.records.any((record) => record.activityIds.isEmpty), isTrue);
    expect(repository.records.any((record) => record.activityIds.isNotEmpty), isTrue);
  });

  test('filters, paginates, and discards units outside selected institutions', () async {
    final repository = FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository());
    final first = repository.records.first;
    final anotherInstitution = repository.records
        .firstWhere((record) => record.institutionId != first.institutionId)
        .institutionId;

    final page = await repository.fetchPage(
      GroupDirectoryQuery(
        institutionIds: {first.institutionId},
        unitIds: {first.unitId},
        typeIds: {first.groupType},
        statuses: {first.status},
        pageSize: 8,
      ),
    );
    final options = await repository.fetchFilterOptions(institutionIds: {anotherInstitution});

    expect(page.items, isNotEmpty);
    expect(page.items.every((item) => item.institutionId == first.institutionId), isTrue);
    expect(page.pageSize, 8);
    expect(options.units.every((unit) => unit.institutionId == anotherInstitution), isTrue);
  });

  test('searches deterministic groups by group, institution, and unit name', () async {
    final repository = FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository());
    final target = repository.records.last;

    expect(
      (await repository.fetchPage(GroupDirectoryQuery(search: target.name))).items,
      isNotEmpty,
    );
    expect(
      (await repository.fetchPage(GroupDirectoryQuery(search: target.institutionName))).items,
      isNotEmpty,
    );
    expect(
      (await repository.fetchPage(GroupDirectoryQuery(search: target.unitName))).items,
      isNotEmpty,
    );
    expect((await repository.fetchPage(GroupDirectoryQuery(search: 'não existe'))).items, isEmpty);
  });

  test('creates and edits local groups without allowing hierarchy moves', () async {
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeGroupDirectoryRepository(institutions);
    final source = repository.records.first;
    final id = repository.createId(source.institutionId, source.unitId, 'nova-turma');
    final created = GroupRecord(
      id: id,
      institutionId: source.institutionId,
      institutionName: source.institutionName,
      unitId: source.unitId,
      unitName: source.unitName,
      name: 'Nova turma',
      groupType: 'class',
      status: GroupStatus.active,
      createdAt: DateTime(2026, 7, 29),
      updatedAt: DateTime(2026, 7, 29),
    );

    await repository.upsert(created);
    await repository.upsert(created.copyWith(name: 'Turma atualizada'));

    expect((await repository.findById(id))!.name, 'Turma atualizada');
    final otherUnit = institutions.records
        .expand((institution) => institution.units)
        .firstWhere((unit) => unit.id != created.unitId);
    final moved = GroupRecord(
      id: created.id,
      institutionId: institutions.records
          .firstWhere((institution) => institution.units.any((unit) => unit.id == otherUnit.id))
          .id,
      institutionName: created.institutionName,
      unitId: otherUnit.id,
      unitName: otherUnit.name,
      name: created.name,
      groupType: created.groupType,
      status: created.status,
      createdAt: created.createdAt,
      updatedAt: created.updatedAt,
    );

    await expectLater(repository.upsert(moved), throwsArgumentError);
    await expectLater(
      repository.upsert(
        GroupRecord(
          id: 'invalid-group',
          institutionId: 'missing-institution',
          institutionName: 'Unknown',
          unitId: 'missing-unit',
          unitName: 'Unknown',
          name: 'Invalid',
          groupType: 'class',
          status: GroupStatus.active,
          createdAt: created.createdAt,
          updatedAt: created.updatedAt,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('persists preview members, professionals, and invites across reloads', () async {
    final repository = FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository());
    final record = repository.records.first;

    await repository.saveComposition(
      GroupDirectorySaveRequest(
        requestId: 'preview-members-save',
        record: record,
        people: const [
          GroupDirectoryPersonBinding(
            id: 'person-student',
            name: 'Ana Estudante',
            identifier: '@ana',
            role: 'student',
          ),
        ],
        professionals: const [
          GroupDirectoryPersonBinding(
            id: 'person-teacher',
            name: 'Bia Professora',
            identifier: '@bia',
            role: 'professional',
            profile: 'Professora',
          ),
        ],
        invites: const [
          GroupDirectoryInviteBinding(
            id: 'invite-guardian',
            identifier: '@responsavel',
            role: 'guardian',
            profile: 'Responsável',
            status: 'Pendente',
          ),
        ],
      ),
    );

    final reloaded = await repository.findById(record.id);
    expect(reloaded, isNotNull);
    expect(
      reloaded!.effectiveAccess.map((access) => access.personId),
      containsAll(<String>['person-student', 'person-teacher']),
    );
    expect(reloaded.invites.single.identifier, '@responsavel');
  });
}
