import 'dart:async';

import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_directory_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ignores a stale activity response that completes after a newer filter request', () async {
    final first = _DeferredActivityLoad();
    final second = _DeferredActivityLoad();
    final repository = _OrderedActivityRepository([first, second]);
    final viewModel = ActivityDirectoryViewModel(repository);
    addTearDown(viewModel.dispose);

    final firstLoad = viewModel.load();
    final secondLoad = viewModel.setStatuses({ActivityStatus.active});

    second.complete('newer');
    await secondLoad;
    expect(viewModel.page.items.single.id, 'newer');

    first.complete('stale');
    await firstLoad;
    expect(viewModel.page.items.single.id, 'newer');
    expect(viewModel.query.statuses, {ActivityStatus.active});
  });
}

final class _DeferredActivityLoad {
  final page = Completer<ActivityDirectoryResult>();
  final filters = Completer<ActivityFilterOptions>();

  void complete(String id) {
    page.complete(
      ActivityDirectoryResult(
        items: [_item(id)],
        totalCount: 1,
        page: 0,
        pageSize: ActivityDirectoryQuery.defaultPageSize,
      ),
    );
    filters.complete(const ActivityFilterOptions());
  }
}

final class _OrderedActivityRepository implements ActivityDirectoryRepository {
  _OrderedActivityRepository(this.loads);

  final List<_DeferredActivityLoad> loads;
  int _pageIndex = 0;
  int _filterIndex = 0;

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) =>
      loads[_pageIndex++].page.future;

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() => loads[_filterIndex++].filters.future;

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
  Future<ActivityDetail?> fetchById(String activityId) async => null;
}

ActivityDirectoryItem _item(String id) => ActivityDirectoryItem(
  id: id,
  institutionId: 'institution-1',
  institutionName: 'Instituição',
  name: id,
  description: null,
  status: ActivityStatus.active,
  origin: ActivityOrigin.institution,
  distribution: ActivityDistribution.institutionStandard,
  governance: ActivityGovernance.optional,
  activeUnitCount: 0,
  activeGroupCount: 0,
  updatedAt: DateTime.utc(2026),
);
