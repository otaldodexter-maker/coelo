import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/activity_directory.dart';

final class ActivityHierarchyFilterOption {
  const ActivityHierarchyFilterOption({
    required this.id,
    required this.label,
    required this.parentId,
  });

  final String id;
  final String label;
  final String parentId;

  @override
  bool operator ==(Object other) => other is ActivityHierarchyFilterOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

final class ActivityDirectoryHierarchy {
  const ActivityDirectoryHierarchy({required this.unit, required this.group});

  factory ActivityDirectoryHierarchy.from(ActivityDirectoryItem item) {
    final index = int.tryParse(RegExp(r'\d+').firstMatch(item.id)?.group(0) ?? '') ?? 1;
    final unitNumber = index % 2 + 1;
    final unitId = '${item.institutionId}-unit-$unitNumber';
    return ActivityDirectoryHierarchy(
      unit: ActivityHierarchyFilterOption(
        id: unitId,
        label: unitNumber == 1 ? 'Unidade Centro' : 'Unidade Norte',
        parentId: item.institutionId,
      ),
      group: ActivityHierarchyFilterOption(
        id: '$unitId-group-${index % 3 + 1}',
        label: 'Grupo ${index % 3 + 1}',
        parentId: unitId,
      ),
    );
  }

  final ActivityHierarchyFilterOption unit;
  final ActivityHierarchyFilterOption group;
}

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
  Set<String> _selectedUnitIds = const {};
  Set<String> _selectedGroupIds = const {};

  ActivityDirectoryQuery get query => _query;
  ActivityDirectoryResult get page => _page;
  ActivityFilterOptions get filterOptions => _filterOptions;
  ActivityDirectoryLoadState get state => _state;
  Set<String> get selectedUnitIds => _selectedUnitIds;
  Set<String> get selectedGroupIds => _selectedGroupIds;

  List<ActivityHierarchyFilterOption> get unitOptions =>
      _uniqueOptions(_page.items.map((item) => ActivityDirectoryHierarchy.from(item).unit));

  List<ActivityHierarchyFilterOption> get groupOptions {
    final options = _uniqueOptions(
      _page.items.map((item) => ActivityDirectoryHierarchy.from(item).group),
    );
    return _selectedUnitIds.isEmpty
        ? options
        : options.where((option) => _selectedUnitIds.contains(option.parentId)).toList();
  }

  List<ActivityDirectoryItem> get visibleItems => _page.items
      .where((item) {
        final hierarchy = ActivityDirectoryHierarchy.from(item);
        return (_selectedUnitIds.isEmpty || _selectedUnitIds.contains(hierarchy.unit.id)) &&
            (_selectedGroupIds.isEmpty || _selectedGroupIds.contains(hierarchy.group.id));
      })
      .toList(growable: false);

  Future<void> load() => _load(_query);
  Future<void> retry() => _load(_query);

  void setSearch(String value) {
    _query = _copy(search: value);
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () => _load(_query));
    notifyListeners();
  }

  Future<void> setInstitutions(Set<String> value) => _replace(_copy(institutionIds: value));
  void setUnits(Set<String> value) {
    _selectedUnitIds = Set.unmodifiable(value);
    final allowedGroups = groupOptions.map((option) => option.id).toSet();
    _selectedGroupIds = Set.unmodifiable(_selectedGroupIds.intersection(allowedGroups));
    notifyListeners();
  }

  void setGroups(Set<String> value) {
    _selectedGroupIds = Set.unmodifiable(value);
    notifyListeners();
  }

  Future<void> setStatuses(Set<ActivityStatus> value) => _replace(_copy(statuses: value));
  Future<void> setOrigins(Set<ActivityOrigin> value) => _replace(_copy(origins: value));
  Future<void> setSort(bool ascending) => _replace(_copy(sortAscending: ascending));
  Future<void> setPage(int value) =>
      value < 0 ? Future.value() : _replace(_copy(page: value, keepPage: true));
  Future<void> setPageSize(int value) => ActivityDirectoryQuery.allowedPageSizes.contains(value)
      ? _replace(_copy(pageSize: value))
      : Future.value();

  Future<void> clearFilters() {
    _selectedUnitIds = const {};
    _selectedGroupIds = const {};
    return _replace(
      _copy(search: '', institutionIds: const {}, statuses: const {}, origins: const {}),
    );
  }

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
      _pruneHierarchy();
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

  void _pruneHierarchy() {
    final units = unitOptions.map((option) => option.id).toSet();
    _selectedUnitIds = Set.unmodifiable(_selectedUnitIds.intersection(units));
    final groups = groupOptions.map((option) => option.id).toSet();
    _selectedGroupIds = Set.unmodifiable(_selectedGroupIds.intersection(groups));
  }

  List<ActivityHierarchyFilterOption> _uniqueOptions(
    Iterable<ActivityHierarchyFilterOption> options,
  ) {
    final unique = <String, ActivityHierarchyFilterOption>{};
    for (final option in options) {
      unique[option.id] = option;
    }
    final values = unique.values.toList()..sort((left, right) => left.label.compareTo(right.label));
    return values;
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}
