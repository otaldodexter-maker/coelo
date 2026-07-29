import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/activity_directory.dart';

enum ActivityDirectoryLoadState {
  initial,
  loading,
  success,
  empty,
  noResults,
  failure,
  unauthorized,
}

final class ActivityDirectoryViewModel extends ChangeNotifier {
  ActivityDirectoryViewModel(
    this._repository, {
    this.searchDebounce = const Duration(milliseconds: 300),
  });

  final ActivityDirectoryRepository _repository;
  final Duration searchDebounce;
  ActivityDirectoryQuery _query = ActivityDirectoryQuery();
  ActivityDirectoryResult _page = const ActivityDirectoryResult(
    items: [],
    totalCount: 0,
    page: 0,
    pageSize: ActivityDirectoryQuery.defaultPageSize,
  );
  ActivityFilterOptions _filterOptions = const ActivityFilterOptions();
  ActivityDirectoryLoadState _state = ActivityDirectoryLoadState.initial;
  Timer? _searchTimer;
  int _requestVersion = 0;

  ActivityDirectoryQuery get query => _query;
  ActivityDirectoryResult get page => _page;
  ActivityFilterOptions get filterOptions => _filterOptions;
  ActivityDirectoryLoadState get state => _state;

  Future<void> load() => _load(_query);
  Future<void> retry() => _load(_query);

  void setSearch(String value) {
    _query = _copy(search: value);
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () => _load(_query));
    notifyListeners();
  }

  Future<void> setInstitutions(Set<String> value) => _replace(_copy(institutionIds: value));
  Future<void> setStatuses(Set<ActivityStatus> value) => _replace(_copy(statuses: value));
  Future<void> setOrigins(Set<ActivityOrigin> value) => _replace(_copy(origins: value));
  Future<void> setSort(bool ascending) => _replace(_copy(sortAscending: ascending));
  Future<void> setPage(int value) =>
      value < 0 ? Future.value() : _replace(_copy(page: value, keepPage: true));
  Future<void> setPageSize(int value) => ActivityDirectoryQuery.allowedPageSizes.contains(value)
      ? _replace(_copy(pageSize: value))
      : Future.value();

  Future<void> clearFilters() =>
      _replace(_copy(search: '', institutionIds: const {}, statuses: const {}, origins: const {}));

  ActivityDirectoryQuery _copy({
    String? search,
    Set<String>? institutionIds,
    Set<ActivityStatus>? statuses,
    Set<ActivityOrigin>? origins,
    int? page,
    int? pageSize,
    bool? sortAscending,
    bool keepPage = false,
  }) => ActivityDirectoryQuery(
    search: search ?? _query.search,
    institutionIds: institutionIds ?? _query.institutionIds,
    statuses: statuses ?? _query.statuses,
    origins: origins ?? _query.origins,
    page: keepPage ? page ?? _query.page : 0,
    pageSize: pageSize ?? _query.pageSize,
    sortAscending: sortAscending ?? _query.sortAscending,
  );

  Future<void> _replace(ActivityDirectoryQuery value) {
    _searchTimer?.cancel();
    _query = value;
    return _load(value);
  }

  Future<void> _load(ActivityDirectoryQuery value) async {
    final version = ++_requestVersion;
    _state = ActivityDirectoryLoadState.loading;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _repository.fetchPage(value),
        _repository.fetchFilterOptions(),
      ]);
      if (version != _requestVersion) return;
      _page = results[0] as ActivityDirectoryResult;
      _filterOptions = results[1] as ActivityFilterOptions;
      _state = _page.items.isNotEmpty
          ? ActivityDirectoryLoadState.success
          : value.hasActiveFilters
          ? ActivityDirectoryLoadState.noResults
          : ActivityDirectoryLoadState.empty;
    } on ActivityDirectoryUnauthorizedException {
      if (version == _requestVersion) {
        _state = ActivityDirectoryLoadState.unauthorized;
      }
    } on Exception {
      if (version == _requestVersion) {
        _state = ActivityDirectoryLoadState.failure;
      }
    }
    if (version == _requestVersion) notifyListeners();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}
