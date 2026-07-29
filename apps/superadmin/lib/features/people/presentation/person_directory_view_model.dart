import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/person_directory.dart';

enum PersonDirectoryLoadState { initial, loading, success, empty, noResults, failure, unauthorized }

final class PersonDirectoryViewModel extends ChangeNotifier {
  PersonDirectoryViewModel(
    this._repository, {
    this.searchDebounce = const Duration(milliseconds: 300),
  });

  final PersonDirectoryRepository _repository;
  final Duration searchDebounce;
  PersonDirectoryLayout _layout = PersonDirectoryLayout.cards;
  PersonDirectoryQuery _query = PersonDirectoryQuery.cards();
  PersonDirectoryPage _page = const PersonDirectoryPage(
    items: [],
    totalCount: 0,
    page: 0,
    pageSize: PersonDirectoryQuery.cardsPageSize,
  );
  PersonDirectoryFilterOptions _filterOptions = const PersonDirectoryFilterOptions();
  PersonDirectoryLoadState _state = PersonDirectoryLoadState.initial;
  Timer? _searchTimer;
  int _requestVersion = 0;

  PersonDirectoryLayout get layout => _layout;
  PersonDirectoryQuery get query => _query;
  PersonDirectoryPage get page => _page;
  PersonDirectoryFilterOptions get filterOptions => _filterOptions;
  PersonDirectoryLoadState get state => _state;

  Future<void> load() => _load(_query);
  Future<void> retry() => _load(_query);

  void setSearch(String value) {
    _query = _copy(search: value);
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () => _load(_query));
    notifyListeners();
  }

  Future<void> setLayout(PersonDirectoryLayout value) {
    _layout = value;
    return _replace(
      _copy(
        pageSize: value == PersonDirectoryLayout.cards
            ? PersonDirectoryQuery.cardsPageSize
            : PersonDirectoryQuery.tablePageSize,
      ),
    );
  }

  Future<void> setTypes(Set<PersonType> value) => _replace(_copy(types: value));
  Future<void> setStatuses(Set<PersonStatus> value) => _replace(_copy(statuses: value));
  Future<void> setInstitutions(Set<String> value) {
    final units = _query.unitIds.where((id) {
      final option = _filterOptions.units.where((item) => item.id == id).firstOrNull;
      return option != null && (value.isEmpty || value.contains(option.institutionId));
    }).toSet();
    final groups = _query.groupIds.where((id) {
      final option = _filterOptions.groups.where((item) => item.id == id).firstOrNull;
      if (option == null || (value.isNotEmpty && !value.contains(option.institutionId))) {
        return false;
      }
      return _query.unitIds.isEmpty || units.contains(option.unitId);
    }).toSet();
    final roles = _query.contextualRoles.where((id) {
      final option = _filterOptions.roles.where((item) => item.id == id).firstOrNull;
      return option != null && (value.isEmpty || value.contains(option.institutionId));
    }).toSet();
    return _replace(
      _copy(institutionIds: value, unitIds: units, groupIds: groups, contextualRoles: roles),
    );
  }

  Future<void> setUnits(Set<String> value) {
    final groups = _query.groupIds.where((id) {
      final option = _filterOptions.groups.where((item) => item.id == id).firstOrNull;
      if (option == null) return false;
      final matchesInstitution =
          _query.institutionIds.isEmpty || _query.institutionIds.contains(option.institutionId);
      return matchesInstitution && (value.isEmpty || value.contains(option.unitId));
    }).toSet();
    return _replace(_copy(unitIds: value, groupIds: groups));
  }

  Future<void> setGroups(Set<String> value) => _replace(_copy(groupIds: value));
  Future<void> setRoles(Set<String> value) => _replace(_copy(contextualRoles: value));
  Future<void> setAuthLinks(Set<AuthLinkStatus> value) => _replace(_copy(authLinks: value));
  Future<void> goToPage(int value) => value < 0 ? Future.value() : _replace(_copy(page: value));
  Future<void> setPageSize(int value) => PersonDirectoryQuery.allowedPageSizes.contains(value)
      ? _replace(_copy(pageSize: value))
      : Future.value();
  Future<void> setSort(PersonDirectorySortColumn column) => _replace(
    _copy(
      sortColumn: column,
      sortAscending: _query.sortColumn == column ? !_query.sortAscending : true,
    ),
  );
  Future<void> clearFilters() => _replace(
    PersonDirectoryQuery(
      pageSize: _layout == PersonDirectoryLayout.cards
          ? PersonDirectoryQuery.cardsPageSize
          : PersonDirectoryQuery.tablePageSize,
    ),
  );

  PersonDirectoryQuery _copy({
    String? search,
    Set<PersonType>? types,
    Set<PersonStatus>? statuses,
    Set<String>? institutionIds,
    Set<String>? unitIds,
    Set<String>? groupIds,
    Set<String>? contextualRoles,
    Set<AuthLinkStatus>? authLinks,
    int page = 0,
    int? pageSize,
    PersonDirectorySortColumn? sortColumn,
    bool? sortAscending,
  }) => PersonDirectoryQuery(
    search: search ?? _query.search,
    types: types ?? _query.types,
    statuses: statuses ?? _query.statuses,
    institutionIds: institutionIds ?? _query.institutionIds,
    unitIds: unitIds ?? _query.unitIds,
    groupIds: groupIds ?? _query.groupIds,
    contextualRoles: contextualRoles ?? _query.contextualRoles,
    authLinks: authLinks ?? _query.authLinks,
    page: page,
    pageSize: pageSize ?? _query.pageSize,
    sortColumn: sortColumn ?? _query.sortColumn,
    sortAscending: sortAscending ?? _query.sortAscending,
  );

  Future<void> _replace(PersonDirectoryQuery value) {
    _searchTimer?.cancel();
    _query = value;
    return _load(value);
  }

  Future<void> _load(PersonDirectoryQuery value) async {
    final version = ++_requestVersion;
    _state = PersonDirectoryLoadState.loading;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _repository.fetchPage(value),
        _repository.fetchFilterOptions(),
      ]);
      if (version != _requestVersion) return;
      _page = results.first as PersonDirectoryPage;
      _filterOptions = results.last as PersonDirectoryFilterOptions;
      _state = _page.items.isNotEmpty
          ? PersonDirectoryLoadState.success
          : value.hasActiveFilters
          ? PersonDirectoryLoadState.noResults
          : PersonDirectoryLoadState.empty;
    } on PersonDirectoryUnauthorizedException {
      if (version == _requestVersion) _state = PersonDirectoryLoadState.unauthorized;
    } on Exception {
      if (version == _requestVersion) _state = PersonDirectoryLoadState.failure;
    }
    if (version == _requestVersion) notifyListeners();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}
