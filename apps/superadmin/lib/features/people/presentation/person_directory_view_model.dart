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
  PersonDirectoryTableView _tableView = PersonDirectoryTableView.grouped;
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
  PersonDirectoryTableView get tableView => _tableView;
  PersonDirectoryQuery get query => _query;
  PersonDirectoryPage get page => _page;
  PersonDirectoryFilterOptions get filterOptions => _filterOptions;
  PersonDirectoryLoadState get state => _state;
  List<PersonFilterOption> get visibleUnits => _query.institutionIds.isEmpty
      ? const []
      : _filterOptions.units
            .where((item) => _query.institutionIds.contains(item.institutionId))
            .toList(growable: false);
  List<PersonFilterOption> get visibleGroups => _query.unitIds.isEmpty
      ? const []
      : _filterOptions.groups
            .where((item) => _query.unitIds.contains(item.unitId))
            .toList(growable: false);
  List<PersonFilterOption> get visibleActivities => _query.groupIds.isEmpty
      ? const []
      : {
          for (final item in _filterOptions.activities.where(
            (item) => _query.groupIds.contains(item.groupId),
          ))
            item.id: item,
        }.values.toList(growable: false);
  List<PersonFilterOption> get visibleMunicipalities => _query.stateCodes.isEmpty
      ? const []
      : _filterOptions.municipalities
            .where((item) => _query.stateCodes.contains(item.stateCode))
            .toList(growable: false);
  List<PersonFilterOption> get visibleNeighborhoods => _query.municipalityIds.isEmpty
      ? const []
      : _filterOptions.neighborhoods
            .where((item) => _query.municipalityIds.contains(item.municipalityId))
            .toList(growable: false);

  Future<void> load() => _load(_query);
  Future<void> retry() => _load(_query);

  void setSearch(String value) {
    _query = _copy(search: value);
    _searchTimer?.cancel();
    ++_requestVersion;
    _page = PersonDirectoryPage(items: const [], totalCount: 0, page: 0, pageSize: _query.pageSize);
    _filterOptions = const PersonDirectoryFilterOptions();
    _state = PersonDirectoryLoadState.loading;
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

  Future<void> setTableView(PersonDirectoryTableView value) {
    _tableView = value;
    return setLayout(PersonDirectoryLayout.table);
  }

  Future<void> setSegment(PersonDirectorySegment value) => _replace(_copy(segment: value));
  Future<void> setTypes(Set<PersonType> value) => _replace(_copy(types: value));
  Future<void> setStatuses(Set<PersonStatus> value) => _replace(_copy(statuses: value));
  Future<void> setInstitutions(Set<String> value) {
    final units = _query.unitIds.where((id) {
      return _filterOptions.units.any(
        (item) => item.id == id && value.contains(item.institutionId),
      );
    }).toSet();
    final groups = _query.groupIds.where((id) {
      return _filterOptions.groups.any(
        (item) =>
            item.id == id &&
            value.contains(item.institutionId) &&
            (_query.unitIds.isEmpty || units.contains(item.unitId)),
      );
    }).toSet();
    final roles = _query.contextualRoles.where((id) {
      final option = _filterOptions.roles.where((item) => item.id == id).firstOrNull;
      return option != null && value.contains(option.institutionId);
    }).toSet();
    final activities = _query.activityIds.where((id) {
      return _filterOptions.activities.any(
        (item) =>
            item.id == id &&
            value.contains(item.institutionId) &&
            units.contains(item.unitId) &&
            groups.contains(item.groupId),
      );
    }).toSet();
    return _replace(
      _copy(
        institutionIds: value,
        unitIds: units,
        groupIds: groups,
        activityIds: activities,
        contextualRoles: roles,
      ),
    );
  }

  Future<void> setUnits(Set<String> value) {
    final groups = _query.groupIds.where((id) {
      return _filterOptions.groups.any(
        (item) =>
            item.id == id &&
            (_query.institutionIds.isEmpty || _query.institutionIds.contains(item.institutionId)) &&
            value.contains(item.unitId),
      );
    }).toSet();
    final activities = _query.activityIds.where((id) {
      return _filterOptions.activities.any(
        (item) => item.id == id && value.contains(item.unitId) && groups.contains(item.groupId),
      );
    }).toSet();
    return _replace(_copy(unitIds: value, groupIds: groups, activityIds: activities));
  }

  Future<void> setGroups(Set<String> value) {
    final activities = _query.activityIds.where((id) {
      return _filterOptions.activities.any((item) => item.id == id && value.contains(item.groupId));
    }).toSet();
    return _replace(_copy(groupIds: value, activityIds: activities));
  }

  Future<void> setActivities(Set<String> value) => _replace(_copy(activityIds: value));
  Future<void> setStates(Set<String> value) {
    final municipalities = _query.municipalityIds.where((id) {
      return _filterOptions.municipalities.any(
        (item) => item.id == id && value.contains(item.stateCode),
      );
    }).toSet();
    final neighborhoods = _query.neighborhoodIds.where((id) {
      return _filterOptions.neighborhoods.any(
        (item) =>
            item.id == id &&
            value.contains(item.stateCode) &&
            municipalities.contains(item.municipalityId),
      );
    }).toSet();
    return _replace(
      _copy(stateCodes: value, municipalityIds: municipalities, neighborhoodIds: neighborhoods),
    );
  }

  Future<void> setMunicipalities(Set<String> value) {
    final neighborhoods = _query.neighborhoodIds.where((id) {
      final option = _filterOptions.neighborhoods.where((item) => item.id == id).firstOrNull;
      return option != null && value.contains(option.municipalityId);
    }).toSet();
    return _replace(_copy(municipalityIds: value, neighborhoodIds: neighborhoods));
  }

  Future<void> setNeighborhoods(Set<String> value) => _replace(_copy(neighborhoodIds: value));
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
    Set<String>? activityIds,
    Set<String>? stateCodes,
    Set<String>? municipalityIds,
    Set<String>? neighborhoodIds,
    Set<String>? contextualRoles,
    Set<AuthLinkStatus>? authLinks,
    int page = 0,
    int? pageSize,
    PersonDirectorySortColumn? sortColumn,
    bool? sortAscending,
    PersonDirectorySegment? segment,
  }) => PersonDirectoryQuery(
    search: search ?? _query.search,
    types: types ?? _query.types,
    statuses: statuses ?? _query.statuses,
    institutionIds: institutionIds ?? _query.institutionIds,
    unitIds: unitIds ?? _query.unitIds,
    groupIds: groupIds ?? _query.groupIds,
    activityIds: activityIds ?? _query.activityIds,
    stateCodes: stateCodes ?? _query.stateCodes,
    municipalityIds: municipalityIds ?? _query.municipalityIds,
    neighborhoodIds: neighborhoodIds ?? _query.neighborhoodIds,
    contextualRoles: contextualRoles ?? _query.contextualRoles,
    authLinks: authLinks ?? _query.authLinks,
    page: page,
    pageSize: pageSize ?? _query.pageSize,
    sortColumn: sortColumn ?? _query.sortColumn,
    sortAscending: sortAscending ?? _query.sortAscending,
    segment: segment ?? _query.segment,
  );

  Future<void> _replace(PersonDirectoryQuery value) {
    _searchTimer?.cancel();
    _query = value;
    return _load(value);
  }

  Future<void> _load(PersonDirectoryQuery value) async {
    final version = ++_requestVersion;
    _page = const PersonDirectoryPage(items: [], totalCount: 0, page: 0, pageSize: 11);
    _filterOptions = const PersonDirectoryFilterOptions();
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
      if (version == _requestVersion) {
        // Revocation is the one case where the query itself is cleared, and it
        // is deliberate: the filters name institutions, units and groups the
        // actor may no longer be allowed to see, so leaving them on screen
        // would keep describing a scope that was just taken away. Pinned by
        // 'revocation clears loaded people, filters and sensitive query state'.
        //
        // An ordinary failure is not that, and used to do the same thing. See
        // the catch below.
        _query = PersonDirectoryQuery(pageSize: value.pageSize);
        _page = PersonDirectoryPage(
          items: const [],
          totalCount: 0,
          page: 0,
          pageSize: value.pageSize,
        );
        _filterOptions = const PersonDirectoryFilterOptions();
        _state = PersonDirectoryLoadState.unauthorized;
      }
      // Anything else, including an Error, has to reach the failure state: a
      // load that throws and leaves the spinner on screen is a silent hang.
    } on Object {
      if (version == _requestVersion) {
        // The query survives an ordinary failure. Resetting it here meant the
        // retry asked a different question from the one the operator asked,
        // while the search field still showed their term: the whole directory
        // came back under an apparently active search. Nothing about a timeout
        // makes the filters sensitive, so nothing about it justifies discarding
        // them. The three sibling directories only assign their query in
        // setters, never in a catch.
        _page = PersonDirectoryPage(
          items: const [],
          totalCount: 0,
          page: 0,
          pageSize: value.pageSize,
        );
        _filterOptions = const PersonDirectoryFilterOptions();
        _state = PersonDirectoryLoadState.failure;
      }
    }
    if (version == _requestVersion) notifyListeners();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    ++_requestVersion;
    super.dispose();
  }
}
