import 'package:coelo_superadmin/features/activities/data/fake_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_directory_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isolates loading, success, no-results and empty states', () async {
    final viewModel = ActivityDirectoryViewModel(
      FakeActivityDirectoryRepository(),
      searchDebounce: Duration.zero,
    );
    addTearDown(viewModel.dispose);

    await viewModel.load();
    expect(viewModel.state, ActivityDirectoryLoadState.success);

    await viewModel.setStatuses({ActivityStatus.archived});
    expect(viewModel.state, ActivityDirectoryLoadState.success);

    viewModel.setSearch('resultado inexistente');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.state, ActivityDirectoryLoadState.noResults);

    final empty = ActivityDirectoryViewModel(_EmptyRepository());
    addTearDown(empty.dispose);
    await empty.load();
    expect(empty.state, ActivityDirectoryLoadState.empty);
  });

  test('keeps the query while alternating cards and table page sizes', () async {
    final viewModel = ActivityDirectoryViewModel(FakeActivityDirectoryRepository());
    addTearDown(viewModel.dispose);

    await viewModel.setInstitutions({'institution-1'});
    await viewModel.setPageSize(8);
    expect(viewModel.query.institutionIds, {'institution-1'});
    expect(viewModel.query.pageSize, 8);

    await viewModel.setPageSize(11);
    expect(viewModel.query.institutionIds, {'institution-1'});
    expect(viewModel.query.pageSize, 11);
  });

  test('maps unauthorized and retryable failures independently', () async {
    final unauthorized = ActivityDirectoryViewModel(_ThrowingRepository(unauthorized: true));
    addTearDown(unauthorized.dispose);
    await unauthorized.load();
    expect(unauthorized.state, ActivityDirectoryLoadState.unauthorized);

    final failure = ActivityDirectoryViewModel(_ThrowingRepository());
    addTearDown(failure.dispose);
    await failure.load();
    expect(failure.state, ActivityDirectoryLoadState.failure);
  });
}

final class _EmptyRepository implements ActivityDirectoryRepository {
  @override
  Future<ActivityDetail?> fetchById(String activityId) async => null;

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() async => const ActivityFilterOptions();

  @override
  Future<ActivityFormOptions> fetchFormOptions() async => const ActivityFormOptions();

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) async =>
      ActivityDirectoryResult(
        items: const [],
        totalCount: 0,
        page: query.page,
        pageSize: query.pageSize,
      );
}

final class _ThrowingRepository implements ActivityDirectoryRepository {
  const _ThrowingRepository({this.unauthorized = false});

  final bool unauthorized;

  @override
  Future<ActivityDetail?> fetchById(String activityId) => _fail();

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() => _fail();

  @override
  Future<ActivityFormOptions> fetchFormOptions() => _fail();

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) => _fail();

  Future<T> _fail<T>() => Future<T>.error(
    unauthorized
        ? const ActivityDirectoryUnauthorizedException()
        : const ActivityDirectoryUnavailableException(),
  );
}
