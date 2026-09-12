import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/presentation/person_directory_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/people/fake_person_directory_repository.dart';

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

  test('progressive filters hide and clear descendants without a compatible parent', () async {
    final viewModel = PersonDirectoryViewModel(FakePersonDirectoryRepository());
    await viewModel.load();

    expect(viewModel.visibleUnits, isEmpty);
    expect(viewModel.visibleGroups, isEmpty);
    expect(viewModel.visibleActivities, isEmpty);
    expect(viewModel.visibleMunicipalities, isEmpty);
    expect(viewModel.visibleNeighborhoods, isEmpty);

    await viewModel.setInstitutions({'institution-0'});
    expect(viewModel.visibleUnits, isNotEmpty);
    await viewModel.setUnits({'unit-0'});
    expect(viewModel.visibleGroups, isNotEmpty);
    await viewModel.setGroups({'group-0'});
    expect(viewModel.visibleActivities, isNotEmpty);
    await viewModel.setActivities({'activity-0'});

    await viewModel.setInstitutions({'institution-1'});
    expect(viewModel.query.unitIds, isEmpty);
    expect(viewModel.query.groupIds, isEmpty);
    expect(viewModel.query.activityIds, isEmpty);

    await viewModel.setStates({'SP'});
    expect(viewModel.visibleMunicipalities, isNotEmpty);
    await viewModel.setMunicipalities({'municipality-sp'});
    expect(viewModel.visibleNeighborhoods, isNotEmpty);
    await viewModel.setNeighborhoods({'neighborhood-centro'});
    await viewModel.setStates({'RJ'});
    expect(viewModel.query.municipalityIds, isEmpty);
    expect(viewModel.query.neighborhoodIds, isEmpty);
  });

  test('revocation clears loaded people, filters and sensitive query state', () async {
    final repository = _RevocablePersonRepository();
    final viewModel = PersonDirectoryViewModel(repository, searchDebounce: Duration.zero);
    await viewModel.load();
    await viewModel.setInstitutions({'institution-0'});
    expect(viewModel.page.items, isNotEmpty);
    expect(viewModel.visibleUnits, isNotEmpty);
    final pageSize = viewModel.page.pageSize;

    repository.unauthorized = true;
    await viewModel.retry();

    expect(viewModel.state, PersonDirectoryLoadState.unauthorized);
    expect(viewModel.page.items, isEmpty);
    expect(viewModel.page.page, 0);
    expect(viewModel.page.pageSize, pageSize);
    expect(viewModel.query.hasActiveFilters, isFalse);
    expect(viewModel.filterOptions.institutions, isEmpty);
    expect(viewModel.filterOptions.units, isEmpty);
    expect(viewModel.filterOptions.groups, isEmpty);
    expect(viewModel.filterOptions.roles, isEmpty);
    expect(viewModel.filterOptions.activities, isEmpty);
    expect(viewModel.filterOptions.states, isEmpty);
    expect(viewModel.filterOptions.municipalities, isEmpty);
    expect(viewModel.filterOptions.neighborhoods, isEmpty);
    expect(viewModel.visibleUnits, isEmpty);
    expect(viewModel.visibleGroups, isEmpty);
    expect(viewModel.visibleActivities, isEmpty);
  });

  test('adding a second state preserves a compatible selected neighborhood', () async {
    final viewModel = PersonDirectoryViewModel(FakePersonDirectoryRepository());
    await viewModel.load();
    await viewModel.setStates({'SP'});
    await viewModel.setMunicipalities({'municipality-sp'});
    await viewModel.setNeighborhoods({'neighborhood-centro'});
    await viewModel.setStates({'SP', 'RJ'});
    expect(viewModel.query.neighborhoodIds, {'neighborhood-centro'});
  });

  test('keeps an activity when its alternate hierarchy link remains selected', () async {
    final viewModel = PersonDirectoryViewModel(_OptionsPersonRepository(_duplicateOptions()));
    await viewModel.load();
    await viewModel.setInstitutions({'institution-a'});
    await viewModel.setUnits({'unit-b'});
    await viewModel.setGroups({'group-b'});
    await viewModel.setActivities({'activity-x'});

    await viewModel.setInstitutions({'institution-a', 'institution-b'});

    expect(viewModel.query.unitIds, {'unit-b'});
    expect(viewModel.query.groupIds, {'group-b'});
    expect(viewModel.query.activityIds, {'activity-x'});
  });

  test('exposes a duplicate activity only once and permits deselection', () async {
    final viewModel = PersonDirectoryViewModel(_OptionsPersonRepository(_duplicateOptions()));
    await viewModel.load();
    await viewModel.setInstitutions({'institution-a'});
    await viewModel.setUnits({'unit-a', 'unit-b'});
    await viewModel.setGroups({'group-a', 'group-b'});

    expect(viewModel.visibleActivities.map((item) => item.id), ['activity-x']);

    await viewModel.setActivities({'activity-x'});
    await viewModel.setActivities({});
    expect(viewModel.query.activityIds, isEmpty);
  });

  test('does not retain a neighborhood through a municipality from another state', () async {
    final viewModel = PersonDirectoryViewModel(_OptionsPersonRepository(_duplicateOptions()));
    await viewModel.load();
    await viewModel.setStates({'SP'});
    await viewModel.setMunicipalities({'municipality-sp'});
    await viewModel.setNeighborhoods({'neighborhood-centro'});

    await viewModel.setMunicipalities({'municipality-rj'});

    expect(viewModel.query.neighborhoodIds, isEmpty);
  });
}

PersonDirectoryFilterOptions _duplicateOptions() => const PersonDirectoryFilterOptions(
  institutions: [
    PersonFilterOption('institution-a', 'Institui\u00e7\u00e3o A'),
    PersonFilterOption('institution-b', 'Institui\u00e7\u00e3o B'),
  ],
  units: [
    PersonFilterOption('unit-a', 'Unidade A', institutionId: 'institution-a'),
    PersonFilterOption('unit-b', 'Unidade B', institutionId: 'institution-a'),
  ],
  groups: [
    PersonFilterOption('group-a', 'Grupo A', institutionId: 'institution-a', unitId: 'unit-a'),
    PersonFilterOption('group-b', 'Grupo B', institutionId: 'institution-a', unitId: 'unit-b'),
  ],
  activities: [
    PersonFilterOption(
      'activity-x',
      'Atividade X',
      institutionId: 'institution-a',
      unitId: 'unit-a',
      groupId: 'group-a',
    ),
    PersonFilterOption(
      'activity-x',
      'Atividade X',
      institutionId: 'institution-a',
      unitId: 'unit-b',
      groupId: 'group-b',
    ),
  ],
  states: [PersonFilterOption('SP', 'S\u00e3o Paulo'), PersonFilterOption('RJ', 'Rio de Janeiro')],
  municipalities: [
    PersonFilterOption('municipality-sp', 'Cidade A', stateCode: 'SP'),
    PersonFilterOption('municipality-rj', 'Cidade B', stateCode: 'RJ'),
  ],
  neighborhoods: [
    PersonFilterOption(
      'neighborhood-centro',
      'Centro',
      stateCode: 'SP',
      municipalityId: 'municipality-sp',
    ),
    PersonFilterOption(
      'neighborhood-centro',
      'Centro',
      stateCode: 'RJ',
      municipalityId: 'municipality-rj',
    ),
  ],
);

final class _OptionsPersonRepository implements PersonDirectoryRepository {
  _OptionsPersonRepository(this._options);

  final _delegate = FakePersonDirectoryRepository();
  final PersonDirectoryFilterOptions _options;

  @override
  Future<PersonDirectoryPage> fetchPage(PersonDirectoryQuery query) => _delegate.fetchPage(query);

  @override
  Future<PersonDirectoryFilterOptions> fetchFilterOptions() async => _options;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RevocablePersonRepository implements PersonDirectoryRepository {
  final _delegate = FakePersonDirectoryRepository();
  var unauthorized = false;

  @override
  Future<PersonDirectoryPage> fetchPage(PersonDirectoryQuery query) {
    if (unauthorized) throw const PersonDirectoryUnauthorizedException();
    return _delegate.fetchPage(query);
  }

  @override
  Future<PersonDirectoryFilterOptions> fetchFilterOptions() {
    if (unauthorized) throw const PersonDirectoryUnauthorizedException();
    return _delegate.fetchFilterOptions();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
