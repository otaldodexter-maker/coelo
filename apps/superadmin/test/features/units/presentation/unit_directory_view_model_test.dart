import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_directory_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads units and clears descendant location filters', () async {
    final repository = FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository());
    final viewModel = UnitDirectoryViewModel(repository);
    addTearDown(viewModel.dispose);

    await viewModel.load();
    final state = viewModel.filterOptions.states.first.id;
    await viewModel.setStates({state});
    final city = viewModel.filterOptions.cities.first.id;
    await viewModel.setCities({city});
    final district = viewModel.filterOptions.districts.first.id;
    await viewModel.setDistricts({district});

    expect(viewModel.query.cities, {city});
    expect(viewModel.query.districts, {district});

    await viewModel.setStates({});

    expect(viewModel.query.cities, isEmpty);
    expect(viewModel.query.districts, isEmpty);
  });

  test('debounces search and exposes the unauthorized state', () async {
    final source = FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository());
    final repository = _RecordingRepository(source);
    final viewModel = UnitDirectoryViewModel(
      repository,
      searchDebounce: const Duration(milliseconds: 10),
    );
    addTearDown(viewModel.dispose);

    viewModel.setSearch('u');
    viewModel.setSearch('un');
    viewModel.setSearch('unidade');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(repository.pageRequests, 1);

    repository.unauthorized = true;
    await viewModel.retry();
    expect(viewModel.state, UnitDirectoryLoadState.unauthorized);
  });

  test('uses eleven cards and switches to eight table rows', () async {
    final repository = FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository());
    final viewModel = UnitDirectoryViewModel(repository);
    addTearDown(viewModel.dispose);

    await viewModel.load();
    expect(viewModel.query.pageSize, 11);
    expect(viewModel.page.items, hasLength(11));

    await viewModel.setPageSize(8);
    expect(viewModel.query.pageSize, 8);
    expect(viewModel.page.items, hasLength(8));
  });

  test('exposes loading, empty, no-results, and failure states', () async {
    final source = FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository());
    final repository = _RecordingRepository(source)
      ..pageOverride = const UnitDirectoryPage(items: [], totalCount: 0, page: 0);
    final viewModel = UnitDirectoryViewModel(repository);
    addTearDown(viewModel.dispose);

    final emptyLoad = viewModel.load();
    expect(viewModel.state, UnitDirectoryLoadState.loading);
    await emptyLoad;
    expect(viewModel.state, UnitDirectoryLoadState.empty);

    await viewModel.setStatuses({UnitStatus.draft});
    expect(viewModel.state, UnitDirectoryLoadState.noResults);

    repository.failure = true;
    await viewModel.retry();
    expect(viewModel.state, UnitDirectoryLoadState.failure);
  });
}

final class _RecordingRepository implements UnitDirectoryRepository {
  _RecordingRepository(this.delegate);

  final UnitDirectoryRepository delegate;
  int pageRequests = 0;
  bool unauthorized = false;
  bool failure = false;
  UnitDirectoryPage? pageOverride;

  @override
  List<UnitRecord> get records => delegate.records;

  @override
  String createId(String institutionId, String slug) => delegate.createId(institutionId, slug);

  @override
  UnitRecord? findById(String id) => delegate.findById(id);

  @override
  Future<UnitDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) {
    if (unauthorized) throw const UnitDirectoryUnauthorizedException();
    return delegate.fetchFilterOptions(states: states, cities: cities);
  }

  @override
  Future<UnitDirectoryPage> fetchPage(UnitDirectoryQuery query) {
    pageRequests += 1;
    if (unauthorized) throw const UnitDirectoryUnauthorizedException();
    if (failure) throw Exception('load failed');
    return pageOverride == null ? delegate.fetchPage(query) : Future.value(pageOverride);
  }

  @override
  Future<UnitFormData> loadForm({String? unitId}) => delegate.loadForm(unitId: unitId);

  @override
  Future<void> upsert(UnitRecord record) => delegate.upsert(record);
}
