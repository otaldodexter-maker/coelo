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

  test('creates and edits local groups without allowing hierarchy moves', () async {
    final repository = FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository());
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

    expect(repository.findById(id)!.name, 'Turma atualizada');
    expect(() => created.copyWith(unitId: 'other-unit'), throwsArgumentError);
  });
}
