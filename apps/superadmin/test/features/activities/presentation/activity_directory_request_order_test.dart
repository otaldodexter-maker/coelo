import 'dart:async';

import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_directory_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final deniedPage in [false, true]) {
    for (final lateFailure in [false, true]) {
      test(
        'denial clears immediately before sibling settles (page=$deniedPage error=$lateFailure)',
        () async {
          final first = _DeferredActivityLoad();
          final second = _DeferredActivityLoad();
          final viewModel = ActivityDirectoryViewModel(_OrderedActivityRepository([first, second]));
          addTearDown(viewModel.dispose);
          final initial = viewModel.load();
          first.complete(
            'previous',
            filters: const ActivityFilterOptions(
              institutions: [ActivityFilterOption(id: 'i', label: 'Institution')],
              units: [ActivityFilterOption(id: 'u', label: 'Unit', parentId: 'i')],
              groups: [ActivityFilterOption(id: 'g', label: 'Group', parentId: 'u')],
            ),
          );
          await initial;
          var finished = false;
          final loading = viewModel.retry().then((_) => finished = true);
          if (deniedPage) {
            second.page.completeError(const ActivityDirectoryUnauthorizedException());
          } else {
            second.filters.completeError(const ActivityDirectoryUnauthorizedException());
          }
          await Future<void>.delayed(Duration.zero);
          expect(viewModel.state, ActivityDirectoryLoadState.unauthorized);
          expect(finished, isTrue);
          expect(viewModel.visibleItems, isEmpty);
          expect(viewModel.filterOptions.institutions, isEmpty);
          expect(viewModel.filterOptions.units, isEmpty);
          expect(viewModel.filterOptions.groups, isEmpty);
          if (deniedPage) {
            if (lateFailure) {
              second.filters.completeError(const ActivityDirectoryUnavailableException());
            } else {
              second.filters.complete(const ActivityFilterOptions());
            }
          } else {
            if (lateFailure) {
              second.page.completeError(const ActivityDirectoryUnavailableException());
            } else {
              second.page.complete(
                ActivityDirectoryResult(
                  items: [_item('late')],
                  totalCount: 1,
                  page: 0,
                  pageSize: 12,
                ),
              );
            }
          }
          await loading;
          await Future<void>.delayed(Duration.zero);
          expect(viewModel.state, ActivityDirectoryLoadState.unauthorized);
          expect(viewModel.visibleItems, isEmpty);
        },
      );
    }
    test('authorization denial wins over another RPC failure (page=$deniedPage)', () async {
      final first = _DeferredActivityLoad();
      final second = _DeferredActivityLoad();
      final viewModel = ActivityDirectoryViewModel(_OrderedActivityRepository([first, second]));
      addTearDown(viewModel.dispose);
      final initial = viewModel.load();
      first.complete(
        'previous',
        filters: const ActivityFilterOptions(
          institutions: [ActivityFilterOption(id: 'institution-a', label: 'Previous institution')],
          units: [
            ActivityFilterOption(id: 'unit-a', label: 'Previous unit', parentId: 'institution-a'),
          ],
          groups: [
            ActivityFilterOption(id: 'group-a', label: 'Previous group', parentId: 'unit-a'),
          ],
        ),
      );
      await initial;
      expect(viewModel.filterOptions.institutions, hasLength(1));
      expect(viewModel.filterOptions.units, hasLength(1));
      expect(viewModel.filterOptions.groups, hasLength(1));
      final loading = viewModel.retry();
      if (deniedPage) {
        second.filters.completeError(const ActivityDirectoryUnavailableException());
      } else {
        second.page.completeError(const ActivityDirectoryUnavailableException());
      }
      await Future<void>.delayed(Duration.zero);
      if (deniedPage) {
        second.page.completeError(const ActivityDirectoryUnauthorizedException());
      } else {
        second.filters.completeError(const ActivityDirectoryUnauthorizedException());
      }
      await loading;
      expect(viewModel.state, ActivityDirectoryLoadState.unauthorized);
      expect(viewModel.visibleItems, isEmpty);
      expect(viewModel.filterOptions.institutions, isEmpty);
      expect(viewModel.filterOptions.units, isEmpty);
      expect(viewModel.filterOptions.groups, isEmpty);
    });
  }

  test('ignores a pending response as soon as search changes before debounce', () async {
    final first = _DeferredActivityLoad();
    final viewModel = ActivityDirectoryViewModel(
      _OrderedActivityRepository([first]),
      searchDebounce: const Duration(days: 1),
    );
    addTearDown(viewModel.dispose);
    final loading = viewModel.load();
    viewModel.setSearch('new query');
    first.complete('stale');
    await loading;
    expect(viewModel.query.search, 'new query');
    expect(viewModel.visibleItems, isEmpty);
    expect(viewModel.state, ActivityDirectoryLoadState.loading);
  });

  test('stale denial does not clear newer authorized filter data', () async {
    final first = _DeferredActivityLoad();
    final second = _DeferredActivityLoad();
    final viewModel = ActivityDirectoryViewModel(_OrderedActivityRepository([first, second]));
    addTearDown(viewModel.dispose);
    final initial = viewModel.load();
    final newer = viewModel.setStatuses({ActivityStatus.active});
    second.complete('authorized');
    await newer;
    first.filters.completeError(const ActivityDirectoryUnauthorizedException());
    await initial;
    expect(viewModel.state, ActivityDirectoryLoadState.success);
    expect(viewModel.visibleItems.single.id, 'authorized');
    first.page.completeError(const ActivityDirectoryUnavailableException());
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.visibleItems.single.id, 'authorized');
  });

  test('denial after dispose does not notify or apply', () async {
    final pending = _DeferredActivityLoad();
    final viewModel = ActivityDirectoryViewModel(_OrderedActivityRepository([pending]));
    var notifications = 0;
    viewModel.addListener(() => notifications++);
    final loading = viewModel.load();
    expect(notifications, 1);
    viewModel.dispose();
    pending.page.completeError(const ActivityDirectoryUnauthorizedException());
    await loading;
    pending.filters.completeError(const ActivityDirectoryUnavailableException());
    await Future<void>.delayed(Duration.zero);
    expect(notifications, 1);
    expect(viewModel.visibleItems, isEmpty);
  });

  test('does not apply or notify when a pending response completes after dispose', () async {
    final pending = _DeferredActivityLoad();
    final viewModel = ActivityDirectoryViewModel(_OrderedActivityRepository([pending]));
    final loading = viewModel.load();
    viewModel.dispose();
    pending.complete('late');
    await expectLater(loading, completes);
    expect(viewModel.visibleItems, isEmpty);
  });

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

  void complete(String id, {ActivityFilterOptions filters = const ActivityFilterOptions()}) {
    page.complete(
      ActivityDirectoryResult(
        items: [_item(id)],
        totalCount: 1,
        page: 0,
        pageSize: ActivityDirectoryQuery.defaultPageSize,
      ),
    );
    this.filters.complete(filters);
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
