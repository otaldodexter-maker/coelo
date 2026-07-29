import 'package:coelo_superadmin/features/people/data/fake_person_directory_repository.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/presentation/person_directory_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads people and switches the approved page size with layout', () async {
    final viewModel = PersonDirectoryViewModel(
      FakePersonDirectoryRepository(),
      searchDebounce: Duration.zero,
    );

    await viewModel.load();
    expect(viewModel.state, PersonDirectoryLoadState.success);
    expect(viewModel.query.pageSize, 11);

    await viewModel.setLayout(PersonDirectoryLayout.table);
    expect(viewModel.query.pageSize, 8);
  });

  test('distinguishes empty from filtered no-results', () async {
    final repository = FakePersonDirectoryRepository(seed: const []);
    final viewModel = PersonDirectoryViewModel(repository, searchDebounce: Duration.zero);
    await viewModel.load();
    expect(viewModel.state, PersonDirectoryLoadState.empty);

    viewModel.setSearch('ninguém');
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.state, PersonDirectoryLoadState.noResults);
  });

  test('changing institution removes incompatible dependent filters', () async {
    final viewModel = PersonDirectoryViewModel(
      FakePersonDirectoryRepository(),
      searchDebounce: Duration.zero,
    );
    await viewModel.load();
    await viewModel.setUnits({'unit-0'});
    await viewModel.setGroups({'group-0'});
    await viewModel.setRoles({'guardian'});

    await viewModel.setInstitutions({'institution-1'});

    expect(viewModel.query.institutionIds, {'institution-1'});
    expect(viewModel.query.unitIds, isEmpty);
    expect(viewModel.query.groupIds, isEmpty);
    expect(viewModel.query.contextualRoles, isEmpty);
  });
}
