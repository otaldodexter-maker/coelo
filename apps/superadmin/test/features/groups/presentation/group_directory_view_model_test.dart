import 'package:coelo_superadmin/features/groups/data/fake_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:coelo_superadmin/features/groups/presentation/group_directory_view_model.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads groups and clears selected units that do not belong to institutions', () async {
    final repository = FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository());
    final viewModel = GroupDirectoryViewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();

    final first = repository.records.first;
    final anotherInstitution = repository.records
        .firstWhere((record) => record.institutionId != first.institutionId)
        .institutionId;
    await viewModel.setUnits({first.unitId});
    await viewModel.setInstitutions({anotherInstitution});

    expect(viewModel.state, GroupDirectoryLoadState.success);
    expect(viewModel.query.unitIds, isEmpty);
  });

  test('resets page when updating filters and supports requested page size and sorting', () async {
    final repository = FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository());
    final viewModel = GroupDirectoryViewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await viewModel.setPage(1);
    await viewModel.setTypes({'class'});
    await viewModel.setPageSize(8);
    await viewModel.setSort(GroupDirectorySortColumn.name, false);

    expect(viewModel.query.page, 0);
    expect(viewModel.query.pageSize, 8);
    expect(viewModel.query.sortAscending, isFalse);
    expect(viewModel.query.sortColumn, GroupDirectorySortColumn.name);
  });

  test('clears all filters', () async {
    final repository = FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository());
    final viewModel = GroupDirectoryViewModel(repository);
    addTearDown(viewModel.dispose);
    viewModel.setSearch('turma');
    await viewModel.clearFilters();

    expect(viewModel.query.hasActiveFilters, isFalse);
  });
}
