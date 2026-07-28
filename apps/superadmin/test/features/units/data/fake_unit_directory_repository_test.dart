import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_record.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes only fake units owned by the fake institutions', () {
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeUnitDirectoryRepository(institutions);

    final expectedUnitIds = {
      for (final institution in institutions.records)
        for (final unit in institution.units) unit.id,
    };

    expect(repository.records.map((record) => record.id).toSet(), expectedUnitIds);
    expect(
      repository.records.every(
        (record) =>
            institutions
                .findById(record.institutionId)
                ?.units
                .any((unit) => unit.id == record.id) ??
            false,
      ),
      isTrue,
    );
  });

  test('uses the institution plan until the unit receives an override', () async {
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeUnitDirectoryRepository(institutions);
    final original = repository.records.first;
    final institution = institutions.findById(original.institutionId)!;

    expect(original.planOverride, isNull);
    expect(original.effectivePlan, institution.plan);

    final inheritedChange = institution.plan == InstitutionPlan.complete
        ? InstitutionPlan.professional
        : InstitutionPlan.complete;
    await institutions.upsert(institution.copyWith(plan: inheritedChange));
    expect(repository.findById(original.id)!.effectivePlan, inheritedChange);

    await repository.upsert(original.copyWith(planOverride: InstitutionPlan.custom));

    final updated = repository.findById(original.id)!;
    expect(updated.planOverride, InstitutionPlan.custom);
    expect(updated.effectivePlan, InstitutionPlan.custom);
  });

  test('creates and edits a child in the institution source of truth', () async {
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeUnitDirectoryRepository(institutions);
    final source = repository.records.first;
    final parent = institutions.findById(source.institutionId)!;
    final initialCount = parent.units.length;
    final id = repository.createId(source.institutionId, 'nova-unidade');

    await repository.upsert(source.copyWith(id: id, name: 'Nova unidade', slug: 'nova-unidade'));

    expect(institutions.findById(source.institutionId)!.units, hasLength(initialCount + 1));
    expect(repository.findById(id)!.name, 'Nova unidade');

    await repository.upsert(repository.findById(id)!.copyWith(name: 'Unidade atualizada'));

    expect(repository.findById(id)!.name, 'Unidade atualizada');
    expect(institutions.findById(source.institutionId)!.units, hasLength(initialCount + 1));
  });

  test('intersects institution, location, type, status, and effective plan filters', () async {
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeUnitDirectoryRepository(institutions);
    final item = repository.records.first;

    final page = await repository.fetchPage(
      UnitDirectoryQuery(
        institutionIds: {item.institutionId},
        typeIds: {item.typeId},
        statuses: {item.status},
        planIds: {item.effectivePlan.id},
        states: {item.state},
        cities: {item.city},
        districts: {item.district},
      ),
    );

    expect(page.items, isNotEmpty);
    expect(
      page.items.every(
        (candidate) =>
            candidate.institutionId == item.institutionId &&
            candidate.typeId == item.typeId &&
            candidate.status == item.status &&
            candidate.effectivePlan.id == item.effectivePlan.id &&
            candidate.state == item.state &&
            candidate.city == item.city &&
            candidate.district == item.district,
      ),
      isTrue,
    );
  });

  test('rejects a duplicate slug inside the same institution', () async {
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeUnitDirectoryRepository(institutions);
    final source = repository.records.first;

    expect(
      () => repository.upsert(
        source.copyWith(
          id: repository.createId(source.institutionId, 'duplicate'),
          name: 'Outra unidade',
          slug: source.slug,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('does not allow moving an existing unit to another institution', () {
    final repository = FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository());
    final source = repository.records.first;
    final anotherInstitution = repository.records
        .firstWhere((record) => record.institutionId != source.institutionId)
        .institutionId;

    expect(() => source.copyWith(institutionId: anotherInstitution), throwsArgumentError);
  });

  test('paginates the directory in groups of twenty', () async {
    final repository = FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository());
    final first = await repository.fetchPage(UnitDirectoryQuery());
    final second = await repository.fetchPage(UnitDirectoryQuery(page: 1));

    expect(first.items, hasLength(UnitDirectoryQuery.pageSize));
    expect(second.items, isNotEmpty);
    expect(first.items.map((item) => item.id).toSet(), isNot(contains(second.items.first.id)));
    expect(first.totalCount, repository.records.length);
  });
}
