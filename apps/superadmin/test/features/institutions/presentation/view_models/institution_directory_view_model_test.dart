import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_page.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/presentation/view_models/institution_directory_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads the first page and available filters', () async {
    final repository = _StubRepository();
    final viewModel = InstitutionDirectoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    final loading = viewModel.load();

    expect(viewModel.isLoading, isTrue);
    await loading;

    expect(repository.queries, [InstitutionDirectoryQuery()]);
    expect(viewModel.state, InstitutionDirectoryLoadState.success);
    expect(viewModel.page.items, hasLength(1));
    expect(viewModel.filterOptions.plans.single.label, 'Essencial');
    expect(viewModel.isLoading, isFalse);
  });

  test('debounces search for three hundred milliseconds and resets the page', () async {
    final repository = _StubRepository();
    final viewModel = InstitutionDirectoryViewModel(
      repository: repository,
      searchDebounce: const Duration(milliseconds: 300),
    );
    addTearDown(viewModel.dispose);

    await viewModel.goToPage(1);
    viewModel.setSearch('Aurora');

    expect(viewModel.query.page, 0);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(repository.queries, hasLength(1));

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(repository.queries, hasLength(2));
    expect(repository.queries.last.search, 'Aurora');
    expect(repository.queries.last.page, 0);
  });

  test('applies multiple statuses in one load and restarts pagination', () async {
    final repository = _StubRepository();
    final viewModel = InstitutionDirectoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.goToPage(1);
    final requestsBeforeApply = repository.queries.length;
    await viewModel.setStatuses({InstitutionStatus.active, InstitutionStatus.onboarding});

    expect(repository.queries, hasLength(requestsBeforeApply + 1));
    expect(repository.queries.last.statuses, {
      InstitutionStatus.active,
      InstitutionStatus.onboarding,
    });
    expect(repository.queries.last.page, 0);
  });

  test('changes page size, preserves filters, and restarts pagination in one load', () async {
    final repository = _StubRepository();
    final viewModel = InstitutionDirectoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.setStatuses({InstitutionStatus.active});
    await viewModel.goToPage(3);
    final requestsBeforePageSizeChange = repository.queries.length;
    await viewModel.setPageSize(50);

    expect(viewModel.query.statuses, {InstitutionStatus.active});
    expect(viewModel.query.page, 0);
    expect(viewModel.query.pageSize, 50);
    expect(repository.queries, hasLength(requestsBeforePageSizeChange + 1));
    expect(repository.queries.last.page, 0);
    expect(repository.queries.last.pageSize, 50);
  });

  test('ignores unsupported page sizes', () async {
    final repository = _StubRepository();
    final viewModel = InstitutionDirectoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.load();
    final requestsBeforeChange = repository.queries.length;
    await viewModel.setPageSize(25);

    expect(viewModel.query.pageSize, InstitutionDirectoryQuery.defaultPageSize);
    expect(repository.queries, hasLength(requestsBeforeChange));
  });

  test('cascades UF, municipality, and district filters', () async {
    final repository = _StubRepository();
    final viewModel = InstitutionDirectoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.setStates({'SP', 'PR'});
    await viewModel.setCities({'Campinas', 'Curitiba'});
    await viewModel.setDistricts({'Cambuí', 'Batel'});

    expect(viewModel.query.states, {'SP', 'PR'});
    expect(viewModel.query.cities, {'Campinas', 'Curitiba'});
    expect(viewModel.query.districts, {'Cambuí', 'Batel'});
    expect(repository.filterRequests.last.$1, {'SP', 'PR'});
    expect(repository.filterRequests.last.$2, {'Campinas', 'Curitiba'});

    await viewModel.setCities({'São Paulo'});
    expect(viewModel.query.districts, isEmpty);

    await viewModel.setStates({'RJ'});
    expect(viewModel.query.cities, isEmpty);
    expect(viewModel.query.districts, isEmpty);
  });

  test('removes invalid geographic selections and loads the sanitized query', () async {
    final repository = _StubRepository(
      onFetchFilterOptions: (states, cities) async => const InstitutionDirectoryFilterOptions(
        plans: [],
        types: [],
        states: [InstitutionDirectoryFilterOption(id: 'SP', label: 'SP')],
        cities: [InstitutionDirectoryFilterOption(id: 'Campinas', label: 'Campinas')],
        districts: [InstitutionDirectoryFilterOption(id: 'Centro', label: 'Centro')],
      ),
    );
    final viewModel = InstitutionDirectoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.setStates({'SP', 'RJ'});
    await viewModel.setCities({'Campinas', 'Curitiba'});
    await viewModel.setDistricts({'Centro', 'Jardins'});

    expect(viewModel.query.states, {'SP'});
    expect(viewModel.query.cities, {'Campinas'});
    expect(viewModel.query.districts, {'Centro'});
    expect(repository.queries.last, viewModel.query);
  });

  test('preserves unrelated multiselect filters when one filter is applied', () async {
    final repository = _StubRepository();
    final viewModel = InstitutionDirectoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.setTypes({'school', 'therapy'});
    await viewModel.setStatuses({InstitutionStatus.active});

    expect(viewModel.query.typeIds, {'school', 'therapy'});
    expect(viewModel.query.statuses, {InstitutionStatus.active});
  });

  test('clears all filters and restarts pagination', () async {
    final repository = _StubRepository();
    final viewModel = InstitutionDirectoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.setStates({'SP'});
    await viewModel.goToPage(1);
    await viewModel.clearFilters();

    expect(repository.queries.last, InstitutionDirectoryQuery());
  });

  test('shows a safe error and retries the same query', () async {
    var shouldFail = true;
    final repository = _StubRepository(
      onFetch: (query) async {
        if (shouldFail) {
          throw Exception('sensitive backend detail');
        }
        return _page(query);
      },
    );
    final viewModel = InstitutionDirectoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.load();

    expect(viewModel.state, InstitutionDirectoryLoadState.failure);
    expect(viewModel.errorMessage, InstitutionDirectoryViewModel.genericErrorMessage);
    expect(viewModel.errorMessage, isNot(contains('sensitive backend detail')));

    shouldFail = false;
    await viewModel.retry();

    expect(viewModel.state, InstitutionDirectoryLoadState.success);
  });

  test('shows the no-permission state returned by the repository', () async {
    final repository = _StubRepository(
      onFetch: (_) =>
          Future<InstitutionDirectoryPage>.error(const InstitutionDirectoryUnauthorizedException()),
    );
    final viewModel = InstitutionDirectoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.load();

    expect(viewModel.state, InstitutionDirectoryLoadState.unauthorized);
    expect(viewModel.errorMessage, InstitutionDirectoryViewModel.unauthorizedMessage);
  });

  test('distinguishes initial empty data from no search result', () async {
    final repository = _StubRepository(
      onFetch: (query) async => InstitutionDirectoryPage(
        items: const [],
        totalCount: 0,
        page: query.page,
        pageSize: query.pageSize,
      ),
    );
    final viewModel = InstitutionDirectoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.load();
    expect(viewModel.state, InstitutionDirectoryLoadState.empty);

    viewModel.setSearch('não encontrada');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(viewModel.state, InstitutionDirectoryLoadState.noResults);
  });
}

final class _StubRepository implements InstitutionDirectoryRepository {
  _StubRepository({this.onFetch, this.onFetchFilterOptions});

  final Future<InstitutionDirectoryPage> Function(InstitutionDirectoryQuery query)? onFetch;
  final Future<InstitutionDirectoryFilterOptions> Function(Set<String> states, Set<String> cities)?
  onFetchFilterOptions;
  final queries = <InstitutionDirectoryQuery>[];
  final filterRequests = <(Set<String>, Set<String>)>[];

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) async {
    filterRequests.add((Set.of(states), Set.of(cities)));
    final dynamicOptions = onFetchFilterOptions?.call(states, cities);
    if (dynamicOptions != null) {
      return dynamicOptions;
    }
    return const InstitutionDirectoryFilterOptions(
      plans: [InstitutionDirectoryFilterOption(id: 'plan-1', label: 'Essencial')],
      types: [],
      states: [
        InstitutionDirectoryFilterOption(id: 'PR', label: 'PR'),
        InstitutionDirectoryFilterOption(id: 'SP', label: 'SP'),
      ],
      cities: [
        InstitutionDirectoryFilterOption(id: 'Campinas', label: 'Campinas'),
        InstitutionDirectoryFilterOption(id: 'Curitiba', label: 'Curitiba'),
      ],
      districts: [
        InstitutionDirectoryFilterOption(id: 'Batel', label: 'Batel'),
        InstitutionDirectoryFilterOption(id: 'Cambuí', label: 'Cambuí'),
      ],
    );
  }

  @override
  Future<InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) async {
    queries.add(query);
    return onFetch?.call(query) ?? _page(query);
  }
}

InstitutionDirectoryPage _page(InstitutionDirectoryQuery query) {
  return InstitutionDirectoryPage(
    items: const [
      InstitutionDirectoryItem(
        id: 'institution-1',
        publicName: 'Instituição Aurora',
        tradeName: null,
        legalName: null,
        primaryDomain: null,
        status: InstitutionStatus.active,
        typeId: null,
        typeName: null,
        city: null,
        state: null,
        planId: null,
        planName: null,
        unitsCount: 0,
        groupsCount: 0,
      ),
    ],
    totalCount: 1,
    page: query.page,
    pageSize: query.pageSize,
  );
}
