import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/group_directory.dart';

enum GroupDirectoryLoadState { initial, loading, success, empty, noResults, failure, unauthorized }

final class GroupDirectoryViewModel extends ChangeNotifier {
  GroupDirectoryViewModel(
    this._repository, {
    this.searchDebounce = const Duration(milliseconds: 300),
  });

  final GroupDirectoryRepository _repository;
  final Duration searchDebounce;
  GroupDirectoryQuery _query = GroupDirectoryQuery();
  GroupDirectoryPage _page = const GroupDirectoryPage(
    items: [],
    totalCount: 0,
    page: 0,
    pageSize: 11,
  );
  GroupDirectoryFilterOptions _filterOptions = const GroupDirectoryFilterOptions();
  GroupDirectoryLoadState _state = GroupDirectoryLoadState.initial;
  Timer? _searchTimer;
  int _requestVersion = 0;

  GroupDirectoryQuery get query => _query;
  GroupDirectoryPage get page => _page;
  GroupDirectoryFilterOptions get filterOptions => _filterOptions;
  GroupDirectoryLoadState get state => _state;
  bool get isLoading => _state == GroupDirectoryLoadState.loading;

  Future<void> load() => _load(_query);
  Future<void> retry() => _load(_query);

  Future<void> clearFilters() => _replace(
    _copy(
      search: '',
      institutionIds: const {},
      unitIds: const {},
      typeIds: const {},
      statuses: const {},
    ),
  );

  void setSearch(String value) {
    _query = _copy(search: value);
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () => _load(_query));
    notifyListeners();
  }

  Future<void> setInstitutions(Set<String> value) {
    final allowedUnits = {
      for (final record in _repository.records)
        if (value.isEmpty || value.contains(record.institutionId)) record.unitId,
    };
    return _replace(
      _copy(institutionIds: value, unitIds: _query.unitIds.intersection(allowedUnits)),
    );
  }

  Future<void> setUnits(Set<String> value) => _replace(_copy(unitIds: value));
  Future<void> setTypes(Set<String> value) => _replace(_copy(typeIds: value));
  Future<void> setStatuses(Set<GroupStatus> value) => _replace(_copy(statuses: value));
  Future<void> setSort(GroupDirectorySortColumn column, bool ascending) =>
      _replace(_copy(sortColumn: column, sortAscending: ascending));
  Future<void> setPage(int value) =>
      value < 0 ? Future.value() : _replace(_copy(page: value, keepPage: true));
  Future<void> setPageSize(int value) => GroupDirectoryQuery.allowedPageSizes.contains(value)
      ? _replace(_copy(pageSize: value))
      : Future.value();
  Future<void> setStatusCategory(GroupDirectoryStatusCategory category) =>
      setStatuses(category.statuses);

  GroupDirectoryQuery _copy({
    String? search,
    Set<String>? institutionIds,
    Set<String>? unitIds,
    Set<String>? typeIds,
    Set<GroupStatus>? statuses,
    int? page,
    int? pageSize,
    GroupDirectorySortColumn? sortColumn,
    bool? sortAscending,
    bool keepPage = false,
  }) => GroupDirectoryQuery(
    search: search ?? _query.search,
    institutionIds: institutionIds ?? _query.institutionIds,
    unitIds: unitIds ?? _query.unitIds,
    typeIds: typeIds ?? _query.typeIds,
    statuses: statuses ?? _query.statuses,
    page: keepPage ? page ?? _query.page : 0,
    pageSize: pageSize ?? _query.pageSize,
    sortColumn: sortColumn ?? _query.sortColumn,
    sortAscending: sortAscending ?? _query.sortAscending,
  );

  Future<void> _replace(GroupDirectoryQuery value) {
    _searchTimer?.cancel();
    _query = value;
    return _load(value);
  }

  Future<void> _load(GroupDirectoryQuery value) async {
    final version = ++_requestVersion;
    _state = GroupDirectoryLoadState.loading;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _repository.fetchPage(value),
        _repository.fetchFilterOptions(institutionIds: value.institutionIds),
      ]);
      if (version != _requestVersion) return;
      _page = results[0] as GroupDirectoryPage;
      _filterOptions = results[1] as GroupDirectoryFilterOptions;
      _state = _page.items.isNotEmpty
          ? GroupDirectoryLoadState.success
          : value.hasActiveFilters
          ? GroupDirectoryLoadState.noResults
          : GroupDirectoryLoadState.empty;
    } on GroupDirectoryUnauthorizedException {
      if (version == _requestVersion) {
        _state = GroupDirectoryLoadState.unauthorized;
      }
    } on Exception {
      if (version == _requestVersion) {
        _state = GroupDirectoryLoadState.failure;
      }
    }
    if (version == _requestVersion) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}
