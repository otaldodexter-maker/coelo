import '../../../support/activities/fake_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_directory_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('limits groups to the selected institutions even without a selected unit', () async {
    final viewModel = ActivityDirectoryViewModel(_RelationalFilterRepository());
    addTearDown(viewModel.dispose);
    await viewModel.load();
    expect(viewModel.groupOptions.map((option) => option.id), {
      'institution-1-group-1',
      'institution-2-group-1',
    });
    await viewModel.setInstitutions({'institution-1'});
    expect(viewModel.selectedUnitIds, isEmpty);
    expect(viewModel.unitOptions.map((option) => option.id), ['institution-1-unit-1']);
    expect(viewModel.groupOptions.map((option) => option.id), ['institution-1-group-1']);
    await viewModel.setInstitutions({'institution-2'});
    expect(viewModel.groupOptions.map((option) => option.id), ['institution-2-group-1']);
  });

  test('isolates loading, success, no-results and empty states', () async {
    final viewModel = ActivityDirectoryViewModel(
      _RelationalFilterRepository(),
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

  test('maps page and filter decoding Errors to a retryable failure', () async {
    for (final source in _DecodingErrorSource.values) {
      final viewModel = ActivityDirectoryViewModel(_DecodingErrorRepository(source));
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.state, ActivityDirectoryLoadState.failure, reason: source.name);
    }
  });

  test('clears descendant unit and group filters when the institution changes', () async {
    final viewModel = ActivityDirectoryViewModel(
      _RelationalFilterRepository(),
      searchDebounce: Duration.zero,
    );
    addTearDown(viewModel.dispose);
    await viewModel.load();

    await viewModel.setInstitutions({'institution-1'});
    final unit = viewModel.unitOptions.first;
    viewModel.setUnits({unit.id});
    final group = viewModel.groupOptions.first;
    viewModel.setGroups({group.id});
    expect(viewModel.selectedUnitIds, {unit.id});
    expect(viewModel.selectedGroupIds, {group.id});
    expect(viewModel.query.unitIds, {unit.id});
    expect(viewModel.query.groupIds, {group.id});
    expect(viewModel.visibleItems, viewModel.page.items);

    await viewModel.setInstitutions({'institution-2'});
    expect(viewModel.selectedUnitIds, isEmpty);
    expect(viewModel.selectedGroupIds, isEmpty);
  });
}

final class _EmptyRepository implements ActivityDirectoryRepository {
  @override
  Future<ActivityDetail?> fetchById(String activityId) async => null;

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() async => const ActivityFilterOptions();

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) async =>
      const ActivityFormOptions();

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) async =>
      const ActivityTemplateOptions();

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) async => const [];

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) async =>
      ActivityDirectoryResult(
        items: const [],
        totalCount: 0,
        page: query.page,
        pageSize: query.pageSize,
      );
}

final class _RelationalFilterRepository implements ActivityDirectoryRepository {
  final FakeActivityDirectoryRepository _delegate = FakeActivityDirectoryRepository();

  @override
  Future<ActivityDetail?> fetchById(String activityId) => _delegate.fetchById(activityId);

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() async => const ActivityFilterOptions(
    institutions: [
      ActivityFilterOption(id: 'institution-1', label: 'Casa Nuvem'),
      ActivityFilterOption(id: 'institution-2', label: 'Casa Sol'),
    ],
    units: [
      ActivityFilterOption(
        id: 'institution-1-unit-1',
        label: 'Unidade Centro',
        parentId: 'institution-1',
      ),
      ActivityFilterOption(
        id: 'institution-2-unit-1',
        label: 'Unidade Sul',
        parentId: 'institution-2',
      ),
    ],
    groups: [
      ActivityFilterOption(
        id: 'institution-1-group-1',
        label: 'Turma 1',
        parentId: 'institution-1-unit-1',
      ),
      ActivityFilterOption(
        id: 'institution-2-group-1',
        label: 'Turma 2',
        parentId: 'institution-2-unit-1',
      ),
    ],
  );

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) =>
      _delegate.fetchFormOptions(institutionId: institutionId);

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) =>
      _delegate.fetchTemplateOptions(institutionId: institutionId);

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) => _delegate.searchProfessionals(institutionId: institutionId, query: query, limit: limit);

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) =>
      _delegate.fetchPage(query);
}

final class _ThrowingRepository implements ActivityDirectoryRepository {
  const _ThrowingRepository({this.unauthorized = false});

  final bool unauthorized;

  @override
  Future<ActivityDetail?> fetchById(String activityId) => _fail();

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() => _fail();

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) => _fail();

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) => _fail();

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) => _fail();

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) => _fail();

  Future<T> _fail<T>() => Future<T>.error(
    unauthorized
        ? const ActivityDirectoryUnauthorizedException()
        : const ActivityDirectoryUnavailableException(),
  );
}

enum _DecodingErrorSource { page, filters }

final class _DecodingErrorRepository implements ActivityDirectoryRepository {
  const _DecodingErrorRepository(this.source);

  final _DecodingErrorSource source;

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) async {
    if (source == _DecodingErrorSource.page) {
      return _decodeWithRawCast<ActivityDirectoryResult>();
    }
    return ActivityDirectoryResult(
      items: const [],
      totalCount: 0,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() async {
    if (source == _DecodingErrorSource.filters) {
      return _decodeWithRawCast<ActivityFilterOptions>();
    }
    return const ActivityFilterOptions();
  }

  @override
  Future<ActivityDetail?> fetchById(String activityId) async => null;

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) async =>
      const ActivityFormOptions();

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) async =>
      const ActivityTemplateOptions();

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) async => const [];
}

T _decodeWithRawCast<T>() {
  final row = <String, Object?>{'id': 42};
  final id = row['id']! as String;
  throw StateError('expected a decoding cast error, got $id');
}
