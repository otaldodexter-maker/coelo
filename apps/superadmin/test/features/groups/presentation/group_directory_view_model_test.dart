import 'dart:async';

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

  test('surfaces a page authorization failure while filter options remain pending', () async {
    final repository = _MixedFailureGroupRepository();
    final viewModel = GroupDirectoryViewModel(repository);
    addTearDown(viewModel.dispose);

    await viewModel.load().timeout(const Duration(milliseconds: 250));

    expect(viewModel.state, GroupDirectoryLoadState.unauthorized);
  });
}

final class _MixedFailureGroupRepository implements GroupDirectoryRepository {
  Future<T> _unavailable<T>() => Future<T>.error(const GroupDirectoryUnavailableException());

  @override
  Future<GroupDirectoryPage> fetchPage(GroupDirectoryQuery query) =>
      Future<GroupDirectoryPage>.error(const GroupDirectoryUnauthorizedException());

  @override
  Future<GroupDirectoryFilterOptions> fetchFilterOptions({Set<String> institutionIds = const {}}) =>
      Completer<GroupDirectoryFilterOptions>().future;

  @override
  Future<GroupRecord?> findById(String id) => _unavailable();

  @override
  String createId(String institutionId, String unitId, String name) =>
      throw const GroupDirectoryUnavailableException();

  @override
  Future<void> upsert(GroupRecord record) => _unavailable();

  @override
  Future<GroupDirectorySaveResult> saveComposition(GroupDirectorySaveRequest request) =>
      _unavailable();

  @override
  Future<GroupDirectoryFormContext> fetchFormContext({String? institutionId}) => _unavailable();

  @override
  Future<GroupDirectoryExportResult> requestExport(GroupDirectoryQuery query) => _unavailable();
}
