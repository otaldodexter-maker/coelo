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

    expect(repository.queries, [const InstitutionDirectoryQuery()]);
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

  test('changes a filter immediately and restarts pagination', () async {
    final repository = _StubRepository();
    final viewModel = InstitutionDirectoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.goToPage(1);
    await viewModel.setStatus(InstitutionStatus.active);

    expect(repository.queries.last.status, InstitutionStatus.active);
    expect(repository.queries.last.page, 0);
  });

  test('cascades UF, municipality, and district filters', () async {
    final repository = _StubRepository();
    final viewModel = InstitutionDirectoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.setState('SP');
    await viewModel.setCity('Campinas');
    await viewModel.setDistrict('Cambuí');

    expect(viewModel.query.state, 'SP');
    expect(viewModel.query.city, 'Campinas');
    expect(viewModel.query.district, 'Cambuí');
    expect(repository.filterRequests.last, ('SP', 'Campinas'));

    await viewModel.setCity('São Paulo');
    expect(viewModel.query.district, isNull);

    await viewModel.setState('RJ');
    expect(viewModel.query.city, isNull);
    expect(viewModel.query.district, isNull);
  });

  test('clears all filters and restarts pagination', () async {
    final repository = _StubRepository();
    final viewModel = InstitutionDirectoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.setState('SP');
    await viewModel.goToPage(1);
    await viewModel.clearFilters();

    expect(repository.queries.last, const InstitutionDirectoryQuery());
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
      onFetch: (query) async =>
          InstitutionDirectoryPage(items: const [], totalCount: 0, page: query.page),
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
  _StubRepository({this.onFetch});

  final Future<InstitutionDirectoryPage> Function(InstitutionDirectoryQuery query)? onFetch;
  final queries = <InstitutionDirectoryQuery>[];
  final filterRequests = <(String?, String?)>[];

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    String? state,
    String? city,
  }) async {
    filterRequests.add((state, city));
    return const InstitutionDirectoryFilterOptions(
      plans: [InstitutionDirectoryFilterOption(id: 'plan-1', label: 'Essencial')],
      types: [],
      cities: [InstitutionDirectoryFilterOption(id: 'Campinas', label: 'Campinas')],
      districts: [InstitutionDirectoryFilterOption(id: 'Cambuí', label: 'Cambuí')],
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
  );
}
